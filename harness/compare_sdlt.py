"""Compare Stamp Duty Land Tax (P8b) with PolicyEngine UK, 2026-27, England.

Purchases of a main home (`main_residential_property_purchased`, a first-time
buyer through `main_residential_property_purchased_is_first_home`), an additional
dwelling (`additional_residential_property_purchased`) and non-residential property
(`non_residential_property_purchased`), at random prices and 1p either side of each
band limit, the £500,000 first-time buyer limit and the £40,000 higher rates
threshold. Must agree within --steps float32 steps of the price, except at the two
cliffs: PolicyEngine holds the price in float32, which cannot tell £500,000.01 from
£500,000 (a step is 3.1p there), so a price within 2 steps of the first-time buyer
limit or the £40,000 threshold may land on the other side. Those are counted.

    uv run python compare_sdlt.py [--binary ../.lake/build/bin/uktax] [--random 1000]
"""

from __future__ import annotations

import argparse
import csv
import pathlib
import random
import sys

import numpy as np

from compare_pension import run

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_BINARY = HERE.parent / ".lake/build/bin/uktax"
YEAR = 2026
PE_INPUT = {"residential": "main_residential_property_purchased",
            "first_time_buyer": "main_residential_property_purchased",
            "additional_dwelling": "additional_residential_property_purchased",
            "non_residential": "non_residential_property_purchased"}
EDGES = [3_999_999, 4_000_000, 12_500_000, 15_000_000, 25_000_000, 30_000_000, 50_000_000, 92_500_000, 150_000_000]


def step(pence: float) -> float:
    return float(np.spacing(np.float32(max(pence / 100, 1.0)))) * 100


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=2003)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_sdlt.csv")
    args = ap.parse_args()
    rng = random.Random(args.seed)
    cs = [(k, e + d) for k in PE_INPUT for e in EDGES for d in (-1, 0, 1)]
    cs += [(rng.choice(list(PE_INPUT)), rng.choice([rng.randint(0, 60_000_000), rng.randint(0, 300_000_000)]))
           for _ in range(args.random)]
    from policyengine_uk import Simulation

    people, hhs = {}, {}
    for i, (k, p) in enumerate(cs):
        people[f"p{i}"] = {"age": {YEAR: 40}}
        hh = {"members": [f"p{i}"], "region": {YEAR: "NORTH_WEST"}, PE_INPUT[k]: {YEAR: p / 100}}
        if k in ("residential", "first_time_buyer"):
            hh["main_residential_property_purchased_is_first_home"] = {YEAR: k == "first_time_buyer"}
        hhs[f"h{i}"] = hh
    sim = Simulation(situation={"people": people, "households": hhs})
    pe = [float(x) for x in sim.calculate("stamp_duty_land_tax", YEAR)]
    ln = run(args.binary, [{"non_savings_pence": 0, "savings_pence": 0, "dividends_pence": 0,
                            "sdlt": {"kind": k, "consideration_pence": p}} for k, p in cs])
    rows, bad, cliff = [], 0, 0
    for (k, p), r, t in zip(cs, ln, pe):
        mine, theirs = r["sdlt_exact_ten_thousandths_pence"] / 10_000, t * 100
        ok = abs(mine - theirs) <= args.steps * step(p)
        limit = {"first_time_buyer": 50_000_000, "additional_dwelling": 4_000_000}.get(k)
        if not ok and limit is not None and abs(p - limit) <= args.steps * step(p):
            cliff += 1
            ok = True
        bad += not ok
        rows.append({"kind": k, "price_pence": p, "lean_pence": mine, "pe_pence": round(theirs, 4), "ok": ok})
        if not ok and bad <= 10:
            print(f"  {k} {p / 100:,.2f}: lean {mine / 100:,.4f} pe {theirs / 100:,.4f}")
    print(f"Stamp Duty Land Tax: {len(cs) - bad}/{len(cs)} agree ({cliff} at a cliff where float32 rounds the price "
          "to the other side)")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
