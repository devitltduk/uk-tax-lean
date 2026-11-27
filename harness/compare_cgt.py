"""Compare Capital Gains Tax (P8a) with PolicyEngine UK, 2026-27.

One taxpayer outside Scotland with pay, savings interest, dividends and Gift Aid
(passed to PolicyEngine as the amount given, the gross x 0.8), gains after losses
(`capital_gains`) of which some qualify for Business Asset Disposal Relief
(`capital_gains_badr`), with edge cases at the annual exempt amount and the basic
rate limit. Must agree within --steps float32 steps of the gains.

    uv run python compare_cgt.py [--binary ../.lake/build/bin/uktax] [--random 1000]
"""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import random
import sys

import numpy as np

from compare_pension import run

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_BINARY = HERE.parent / ".lake/build/bin/uktax"
YEAR = 2026


def step(pence: float) -> float:
    return float(np.spacing(np.float32(max(pence / 100, 1.0)))) * 100


def random_case(rng: random.Random) -> dict:
    gains = rng.choice([rng.randint(0, 600_000), rng.randint(0, 10_000_000), rng.randint(0, 50_000_000)])
    return {"pay": rng.choice([0, rng.randint(0, 3_000_000), rng.randint(0, 15_000_000)]),
            "savings": rng.choice([0, 0, rng.randint(0, 2_000_000)]),
            "dividends": rng.choice([0, 0, rng.randint(0, 3_000_000)]),
            "gift_aid": rng.choice([0, 0, 0, 5 * rng.randint(0, 100_000)]),
            "gains": gains, "badr": rng.choice([0, 0, rng.randint(0, gains)])}


def edge_cases() -> list[dict]:
    base = {"pay": 3_000_000, "savings": 0, "dividends": 0, "gift_aid": 0, "badr": 0}
    out = [{**base, "gains": g} for g in (299_999, 300_000, 300_001)]
    # pay £50,000 leaves £270 of band: gains putting the top of the band at the limit
    out += [{**base, "pay": 5_000_000, "gains": g} for g in (326_999, 327_000, 327_001)]
    out += [{**base, "gains": 2_000_000, "badr": b} for b in (0, 1_000_000, 2_000_000)]
    return out


def lean(binary: pathlib.Path, cs: list[dict]) -> list[dict]:
    return run(binary, [{"non_savings_pence": c["pay"], "savings_pence": c["savings"], "dividends_pence": c["dividends"],
                         "employment_pence": c["pay"], "gift_aid_gross_pence": c["gift_aid"],
                         "capital_gains_pence": c["gains"] - c["badr"], "badr_gains_pence": c["badr"]} for c in cs])


def policyengine(cs: list[dict]) -> list[float]:
    from policyengine_uk import Simulation

    out: list[float] = []
    for lo in range(0, len(cs), 500):
        people, hhs = {}, {}
        for i, c in enumerate(cs[lo : lo + 500]):
            people[f"p{i}"] = {"age": {YEAR: 40}, "employment_income": {YEAR: c["pay"] / 100},
                               "savings_interest_income": {YEAR: c["savings"] / 100},
                               "dividend_income": {YEAR: c["dividends"] / 100},
                               "gift_aid": {YEAR: c["gift_aid"] * 0.8 / 100},
                               "capital_gains": {YEAR: c["gains"] / 100},
                               "capital_gains_badr": {YEAR: c["badr"] / 100}}
            hhs[f"h{i}"] = {"members": [f"p{i}"], "region": {YEAR: "NORTH_WEST"}}
        sim = Simulation(situation={"people": people, "households": hhs})
        out += [float(x) for x in sim.calculate("capital_gains_tax", YEAR)]
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=1992)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_cgt.csv")
    args = ap.parse_args()
    rng = random.Random(args.seed)
    cs = edge_cases() + [random_case(rng) for _ in range(args.random)]
    pe = policyengine(cs)
    ln = lean(args.binary, cs)
    rows, bad, taxed, worst = [], 0, 0, 0.0
    for c, r, p in zip(cs, ln, pe):
        mine = r["cgt_exact_ten_thousandths_pence"] / 10_000
        theirs = p * 100
        st = step(max(c["gains"], c["pay"] + c["savings"] + c["dividends"]))
        ok = abs(theirs - mine) <= args.steps * st
        worst = max(worst, abs(theirs - mine) / st)
        bad += not ok
        taxed += mine > 0
        rows.append({**c, "lean_pence": mine, "pe_pence": round(theirs, 4), "diff": round(theirs - mine, 4), "ok": ok})
        if not ok and bad <= 10:
            print(f"  {c}: lean {mine:.2f} pe {theirs:.2f}")
    print(f"Capital Gains Tax: {len(cs) - bad}/{len(cs)} agree ({taxed} taxed; worst {worst:.2f} float32 steps)")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
