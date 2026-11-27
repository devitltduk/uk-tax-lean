"""Compare Universal Credit for the self-employed and the minimum income floor (P4b)
with PolicyEngine UK, 2026-27.

A claimant aged 30 with a trade (`self_employment_income` = receipts less
expenses, which may be a loss, and `self_employment_gross_receipts` for the
trading allowance) and perhaps pay, single or in a couple whose partner (30) has
pay only; 0 to 3 children aged 5. Edge cases put the claimant's earned income 1p
either side of the floor and make a loss beside pay.

Whether the floor applies (reg 62(1): gainful self-employment, all work-related
requirements, no start-up period) and the expected hours (reg 88) are determinations
DWP makes; they are read from PolicyEngine (`uc_mif_applies`, and the hours from
`uc_minimum_income_floor_gross` ÷ (£12.71 × 52)) and passed to the model, which
uses the threshold with the pence kept (`whole_pounds: false`), as PolicyEngine
does (reg 6(1A)(a) would round each month down to the pound; findings #33).

The Marriage Allowance is switched off. UC must agree within --steps float32 steps
of the larger of the yearly maximum amount and the household's pay and profit, plus
0.4p for PolicyEngine's NIC thresholds (findings #1) and 0.55p because the
partner's earned income is passed to the model in whole pence.

    uv run python compare_uc_se.py [--binary ../.lake/build/bin/uktax] [--random 1000]
"""

from __future__ import annotations

import argparse
import csv
import pathlib
import random
import sys

import numpy as np

from compare_pension import run
from compare_uc_full import partner_earned

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_BINARY = HERE.parent / ".lake/build/bin/uktax"
YEAR = 2026
MICRO = 1_000_000
NLW_YEAR_PER_HOUR = 1271 * 52  # pence


def step(pence: float) -> float:
    return float(np.spacing(np.float32(max(pence / 100, 1.0)))) * 100


def random_case(rng: random.Random) -> dict:
    couple = rng.random() < 0.35
    receipts = rng.choice([rng.randint(0, 1_500_000), rng.randint(0, 5_000_000)])
    expenses = rng.choice([0, rng.randint(0, receipts), rng.randint(0, receipts + 500_000)])
    return {"couple": couple, "kids": rng.choice([0, 0, 1, 2, 3]),
            "pay": rng.choice([0, 0, 0, rng.randint(0, 2_000_000)]),
            "receipts": receipts, "expenses": expenses,
            "partner_pay": rng.choice([0, rng.randint(0, 3_000_000)]) if couple else 0}


def edge_cases() -> list[dict]:
    base = {"couple": False, "kids": 1, "pay": 0, "expenses": 0, "partner_pay": 0}
    out = [{**base, "receipts": r} for r in (0, 100_000, 1_000_000, 2_400_000, 2_600_000, 4_000_000)]
    out += [{**base, "pay": 1_200_000, "receipts": 200_000, "expenses": 500_000}]
    out += [{**base, "couple": True, "kids": 2, "receipts": 600_000, "partner_pay": p}
            for p in (0, 1_200_000, 2_000_000, 3_000_000)]
    return out


def policyengine(cs: list[dict]) -> dict[str, list[float]]:
    from policyengine_uk import Simulation

    res: dict[str, list[float]] = {"universal_credit": [], "uc_maximum_amount": [], "mif": [], "gross": [],
                                   "partner_gross": []}
    for lo in range(0, len(cs), 400):
        part = cs[lo : lo + 400]
        people, bus, hhs = {}, {}, {}
        for i, c in enumerate(part):
            people[f"a{i}"] = {"age": {YEAR: 30}, "employment_income": {YEAR: c["pay"] / 100},
                               "self_employment_income": {YEAR: (c["receipts"] - c["expenses"]) / 100},
                               "self_employment_gross_receipts": {YEAR: c["receipts"] / 100},
                               "marriage_allowance": {YEAR: 0}}
            members = [f"a{i}"]
            if c["couple"]:
                people[f"p{i}"] = {"age": {YEAR: 30}, "employment_income": {YEAR: c["partner_pay"] / 100},
                                   "marriage_allowance": {YEAR: 0}}
                members.append(f"p{i}")
            for k in range(c["kids"]):
                people[f"c{i}_{k}"] = {"age": {YEAR: 5}}
                members.append(f"c{i}_{k}")
            bus[f"b{i}"] = {"members": members}
            hhs[f"h{i}"] = {"members": members, "region": {YEAR: "NORTH_WEST"}}
        sim = Simulation(situation={"people": people, "benunits": bus, "households": hhs})
        ids = list(people)
        idx = [ids.index(f"a{i}") for i in range(len(part))]
        pidx = [ids.index(f"p{i}") if c["couple"] else None for i, c in enumerate(part)]
        for v in ("universal_credit", "uc_maximum_amount"):
            res[v] += [float(x) for x in sim.calculate(v, YEAR)]
        mif = sim.calculate("uc_mif_applies", YEAR)
        gross = sim.calculate("uc_minimum_income_floor_gross", YEAR)
        res["mif"] += [bool(mif[j]) for j in idx]
        res["gross"] += [float(gross[j]) for j in idx]
        res["partner_gross"] += [float(gross[j]) if j is not None else 0.0 for j in pidx]
    return res


def hours(gross_pounds: float) -> int:
    h = gross_pounds * 100 / NLW_YEAR_PER_HOUR
    assert abs(h - round(h)) < 1e-3, gross_pounds
    return round(h)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=2062)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_uc_se.csv")
    args = ap.parse_args()
    rng = random.Random(args.seed)
    cs = edge_cases() + [random_case(rng) for _ in range(args.random)]
    pe = policyengine(cs)
    pp = partner_earned(args.binary, cs)
    payload = []
    for c, m, g, pg, p in zip(cs, pe["mif"], pe["gross"], pe["partner_gross"], pp):
        uc = {"couple": c["couple"], "children": c["kids"], "partner_earned_pence": p}
        if m:
            uc["minimum_income_floor"] = {"expected_hours": hours(g), "partner_expected_hours": hours(pg),
                                          "whole_pounds": False}
        payload.append({"non_savings_pence": c["pay"], "savings_pence": 0, "dividends_pence": 0,
                        "employment_pence": c["pay"], "trading_receipts_pence": c["receipts"],
                        "trading_expenses_pence": c["expenses"], "uc": uc})
    ln = run(args.binary, payload)
    rows, bad, worst, paid, floored = [], 0, 0.0, 0, 0
    for c, r, u, mx, m in zip(cs, ln, pe["universal_credit"], pe["uc_maximum_amount"], pe["mif"]):
        mine, theirs = r["uc_millionths_pence"] / MICRO, u * 100
        st = step(max(mx * 100, c["pay"] + c["partner_pay"] + abs(c["receipts"] - c["expenses"])))
        ok = abs(theirs - mine) <= args.steps * st + 0.4 + 0.55
        worst = max(worst, abs(theirs - mine) / st)
        paid += mine > 0
        mif_net = r["uc_minimum_income_floor_ten_thousandths_pence"]
        floored += m and mif_net is not None and r["uc_earned_income_ten_thousandths_pence"] < mif_net
        bad += not ok
        rows.append({**c, "mif": m, "lean_uc_pence": mine, "pe_uc_pence": round(theirs, 4),
                     "diff": round(theirs - mine, 4), "ok": ok})
        if not ok and bad <= 12:
            print(f"  {c} mif {m}: lean {mine:.2f} pe {theirs:.2f}")
    print(f"Universal Credit, self-employed: {len(cs) - bad}/{len(cs)} agree ({paid} with UC paid, {floored} "
          f"below their floor; worst {worst:.2f} float32 steps)")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
