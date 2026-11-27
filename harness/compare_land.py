"""Compare Land and Buildings Transaction Tax (Scotland), Land Transaction Tax
(Wales) and the tax on lease rent (all three taxes) with PolicyEngine UK, 2026-27
(P8c).

Purchases of a main home (first-time buyers in Scotland too), an additional
dwelling and non-residential property, at random prices and 1p either side of each
band limit and of £40,000; and non-residential leases of 1 to 25 years at a level
yearly rent. The law taxes a lease's rent by its net present value at 3.5 % a year;
PolicyEngine taxes the value of its `non_residential_rent` input (with
`cumulative_non_residential_rent` nil) by the rent table, so it is given the NPV,
which compares the tables like with like. Must agree within --steps float32 steps
of the amount taxed.

Not like with like (findings #38): PolicyEngine charges Scotland's additional
dwelling supplement and Wales's higher rates on an additional dwelling of any price,
where both apply only from £40,000 (LBTT(S)A 2013 Sch 2A para 2(1)(b); LTTA 2017
Sch 5 para 3(2)(c)). Those purchases are counted, not compared. PolicyEngine has no
SDLT non-resident surcharge; the model's is checked by the golden cases and
`sdlt_nonResident`.

    uv run python compare_land.py [--binary ../.lake/build/bin/uktax] [--random 1000]
"""

from __future__ import annotations

import argparse
import csv
import pathlib
import random
import sys
from fractions import Fraction

import numpy as np

from compare_pension import run

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_BINARY = HERE.parent / ".lake/build/bin/uktax"
YEAR = 2026
REGION = {"sdlt": "NORTH_WEST", "lbtt": "SCOTLAND", "ltt": "WALES"}
OUTPUT = {"sdlt": "stamp_duty_land_tax", "lbtt": "land_and_buildings_transaction_tax", "ltt": "land_transaction_tax"}
PE_INPUT = {"residential": "main_residential_property_purchased",
            "first_time_buyer": "main_residential_property_purchased",
            "additional_dwelling": "additional_residential_property_purchased",
            "non_residential": "non_residential_property_purchased"}
EDGES = {"lbtt": [4_000_000, 14_500_000, 15_000_000, 17_500_000, 25_000_000, 32_500_000, 75_000_000],
         "ltt": [4_000_000, 18_000_000, 22_500_000, 25_000_000, 40_000_000, 75_000_000, 100_000_000, 150_000_000]}


def step(pence: float) -> float:
    return float(np.spacing(np.float32(max(pence / 100, 1.0)))) * 100


def cases(rng: random.Random, n: int) -> list[dict]:
    out = []
    for tax in ("lbtt", "ltt"):
        kinds = ["residential", "additional_dwelling", "non_residential"] + (["first_time_buyer"] if tax == "lbtt" else [])
        out += [{"tax": tax, "kind": k, "p": e + d, "years": 0, "rent": 0} for k in kinds for e in EDGES[tax] for d in (-1, 0, 1)]
    for _ in range(n):
        tax = rng.choice(["lbtt", "ltt", "sdlt"])
        if rng.random() < 0.3 or tax == "sdlt":
            out.append({"tax": tax, "kind": "non_residential", "p": 0, "years": rng.randint(1, 25),
                        "rent": rng.choice([rng.randint(0, 5_000_000), rng.randint(0, 40_000_000)])})
        else:
            kinds = ["residential", "additional_dwelling", "non_residential"] + (["first_time_buyer"] if tax == "lbtt" else [])
            out.append({"tax": tax, "kind": rng.choice(kinds), "years": 0, "rent": 0,
                        "p": rng.choice([rng.randint(0, 6_000_000), rng.randint(0, 60_000_000), rng.randint(0, 300_000_000)])})
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=2013)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_land.csv")
    args = ap.parse_args()
    cs = cases(random.Random(args.seed), args.random)
    payload = []
    for c in cs:
        lt = {"tax": c["tax"], "kind": c["kind"], "consideration_pence": c["p"]}
        if c["years"]:
            lt["lease_rents_pence"] = [c["rent"]] * c["years"]
        payload.append({"non_savings_pence": 0, "savings_pence": 0, "dividends_pence": 0, "land_tax": lt})
    ln = run(args.binary, payload)
    for c, r in zip(cs, ln):
        if c["years"]:
            c["npv"] = Fraction(r["land_tax_rent_npv_numerator_pence"], r["land_tax_rent_denominator"])
            c["lean"] = Fraction(r["land_tax_rent_scaled_ten_thousandths_pence"], 10_000 * r["land_tax_rent_denominator"])
        else:
            c["lean"] = Fraction(r["land_tax_exact_ten_thousandths_pence"], 10_000)
    from policyengine_uk import Simulation

    people, hhs = {}, {}
    for i, c in enumerate(cs):
        people[f"p{i}"] = {"age": {YEAR: 40}}
        hh = {"members": [f"p{i}"], "region": {YEAR: REGION[c["tax"]]}}
        if c["years"]:
            hh["non_residential_rent"] = {YEAR: float(c["npv"]) / 100}
            hh["cumulative_non_residential_rent"] = {YEAR: 0}
        else:
            hh[PE_INPUT[c["kind"]]] = {YEAR: c["p"] / 100}
            if c["kind"] in ("residential", "first_time_buyer"):
                hh["main_residential_property_purchased_is_first_home"] = {YEAR: c["kind"] == "first_time_buyer"}
        hhs[f"h{i}"] = hh
    sim = Simulation(situation={"people": people, "households": hhs})
    pe = {t: [float(x) for x in sim.calculate(v, YEAR)] for t, v in OUTPUT.items()}
    rows, bad, below40k, n = [], 0, 0, 0
    for i, c in enumerate(cs):
        theirs = pe[c["tax"]][i] * 100
        mine = float(c["lean"])
        if c["kind"] == "additional_dwelling" and c["tax"] != "sdlt" and c["p"] < 4_000_000 and not c["years"]:
            below40k += 1
            continue
        n += 1
        amount = float(c["npv"]) if c["years"] else c["p"]
        ok = abs(mine - theirs) <= args.steps * step(amount) * (0.02 if c["years"] else 0.17) + 0.01
        bad += not ok
        rows.append({**{k: v for k, v in c.items() if k not in ("lean", "npv")}, "npv_pence": float(c.get("npv", 0)),
                     "lean_pence": round(mine, 4), "pe_pence": round(theirs, 4), "ok": ok})
        if not ok and bad <= 12:
            print(f"  {c['tax']} {c['kind']} {amount / 100:,.2f} ({c['years']} years): lean {mine / 100:,.4f} pe {theirs / 100:,.4f}")
    print(f"LBTT, LTT and lease rent: {n - bad}/{n} agree ({sum(1 for c in cs if c['years'])} leases; "
          f"{below40k} additional dwellings under £40,000 left out, findings #38)")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
