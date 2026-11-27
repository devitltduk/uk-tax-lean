"""Compare the company car and car fuel benefits and the TV licence with
PolicyEngine UK, 2026-27 (P9d).

Company cars: random list prices, capital contributions, CO2 figures (every band
edge of ITEPA 2003 s139 and the s139(3) steps, 0 to 200 g/km), electric ranges
(each edge of the 1-50 g/km table), petrol or diesel not meeting Euro 6d, days
unavailable (PolicyEngine's `company_car_availability` is the share of the year,
(365 - U) / 365), payments for private use and private fuel. The model's whole
CO2 figure is given to PolicyEngine unchanged. Must agree within --steps float32
steps of the benefit.

TV licence: one-person households, blind or not, 75 or over with or without
Pension Credit (given to PolicyEngine as the benefit unit's `pension_credit`). Must
agree to the penny.

    uv run python compare_p9d.py [--binary ../.lake/build/bin/uktax] [--random 1000]
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
CO2_EDGES = [0, 1, 50, 51, 54, 55, 59, 60, 64, 65, 69, 70, 74, 75, 79, 80, 154, 155, 159, 160, 200]
RANGE_EDGES = [0, 29, 30, 39, 40, 69, 70, 129, 130, 200]


def step(pence: float) -> float:
    return float(np.spacing(np.float32(max(pence / 100, 1.0)))) * 100


def cars(rng: random.Random, n: int) -> list[dict]:
    out = [{"price": 4_000_000, "contrib": 0, "co2": c, "range": r, "diesel": False, "u": 0, "pay": 0, "fuel": True}
           for c in CO2_EDGES for r in ((0, 130) if 1 <= c <= 50 else (0,))]
    out += [{"price": 3_000_000, "contrib": 0, "co2": 30, "range": r, "diesel": False, "u": 0, "pay": 0, "fuel": False}
            for r in RANGE_EDGES]
    for _ in range(n):
        out.append({"price": rng.randint(1_500_000, 9_000_000),
                    "contrib": rng.choice([0, 0, rng.randint(0, 800_000)]),
                    "co2": rng.choice(CO2_EDGES + [rng.randint(0, 250)]),
                    "range": rng.choice(RANGE_EDGES + [rng.randint(0, 200)]),
                    "diesel": rng.random() < 0.25,
                    "u": rng.choice([0, 0, rng.randint(0, 365)]),
                    "pay": rng.choice([0, 0, rng.randint(0, 300_000)]),
                    "fuel": rng.random() < 0.4})
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=2003)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_p9d.csv")
    args = ap.parse_args()
    rng = random.Random(args.seed)
    from policyengine_uk import Simulation

    cs = cars(rng, args.random)
    ln = run(args.binary, [{"non_savings_pence": 0, "savings_pence": 0, "dividends_pence": 0, "company_car": {
        "list_price_pence": c["price"], "capital_contributions_pence": c["contrib"], "co2_g_km": c["co2"],
        "electric_range_miles": c["range"], "diesel_non_euro_6d": c["diesel"], "days_unavailable": c["u"],
        "private_use_payments_pence": c["pay"], "fuel_provided": c["fuel"]}} for c in cs])
    people, hhs = {}, {}
    for i, c in enumerate(cs):
        people[f"p{i}"] = {"age": {YEAR: 40}, "company_car_list_price": {YEAR: c["price"] / 100},
                           "company_car_capital_contributions": {YEAR: c["contrib"] / 100},
                           "company_car_co2_emissions": {YEAR: c["co2"]},
                           "company_car_electric_range": {YEAR: c["range"]},
                           "company_car_fuel_type": {YEAR: "DIESEL_NON_RDE2" if c["diesel"] else "PETROL"},
                           "company_car_availability": {YEAR: (365 - c["u"]) / 365},
                           "company_car_private_use_payments": {YEAR: c["pay"] / 100},
                           "company_car_private_fuel_provided": {YEAR: c["fuel"]}}
        hhs[f"h{i}"] = {"members": [f"p{i}"], "region": {YEAR: "NORTH_WEST"}}
    sim = Simulation(situation={"people": people, "households": hhs})
    pe = {v: [float(x) for x in sim.calculate(v, YEAR)]
          for v in ("company_car_benefit", "car_fuel_benefit", "company_car_appropriate_percentage")}
    rows, bad = [], 0
    for i, (c, r) in enumerate(zip(cs, ln)):
        mine = {"company_car_benefit": r["company_car_benefit_36500ths_pence"] / 36_500,
                "car_fuel_benefit": r["car_fuel_benefit_36500ths_pence"] / 36_500,
                "company_car_appropriate_percentage": r["company_car_percent"]}
        theirs = {"company_car_benefit": pe["company_car_benefit"][i] * 100,
                  "car_fuel_benefit": pe["car_fuel_benefit"][i] * 100,
                  "company_car_appropriate_percentage": round(pe["company_car_appropriate_percentage"][i] * 100, 4)}
        # PolicyEngine takes the payments off in float32 at the size of the benefit
        # before them, so the tolerance is at that size
        size = {k: mine[k] + (c["pay"] if k == "company_car_benefit" else 0) for k in mine}
        ok = all(abs(mine[k] - theirs[k]) <= args.steps * step(max(size[k], 1)) + 0.01 for k in mine)
        bad += not ok
        rows.append({"area": "company_car", **c, **{f"lean_{k}": round(v, 4) for k, v in mine.items()},
                     **{f"pe_{k}": round(v, 4) for k, v in theirs.items()}, "ok": ok})
        if not ok and bad <= 10:
            print(f"  car {c}: lean {mine} pe {theirs}")
    print(f"Company car and car fuel benefits: {len(cs) - bad}/{len(cs)} agree "
          f"({sum(c['fuel'] and c['co2'] > 0 for c in cs)} with fuel, {sum(c['diesel'] for c in cs)} diesel)")

    tvs = [(blind, age, pc) for blind in (False, True) for age in (40, 74, 75, 90) for pc in (False, True)]
    tl = run(args.binary, [{"non_savings_pence": 0, "savings_pence": 0, "dividends_pence": 0,
                            "tv_licence": {"blind": b, "over_75_with_pension_credit": a >= 75 and pc}}
                           for b, a, pc in tvs])
    people, bus, hhs = {}, {}, {}
    for i, (b, a, pc) in enumerate(tvs):
        people[f"t{i}"] = {"age": {YEAR: a}, "is_blind": {YEAR: b}}
        bus[f"b{i}"] = {"members": [f"t{i}"], "pension_credit": {YEAR: 1_000.0 if pc else 0.0}}
        hhs[f"h{i}"] = {"members": [f"t{i}"], "household_owns_tv": {YEAR: True},
                        "would_evade_tv_licence_fee": {YEAR: False}, "region": {YEAR: "NORTH_WEST"}}
    sim = Simulation(situation={"people": people, "benunits": bus, "households": hhs})
    ptv = [float(x) for x in sim.calculate("tv_licence", YEAR)]
    tbad = 0
    for (b, a, pc), r, v in zip(tvs, tl, ptv):
        ok = abs(r["tv_licence_pence"] - v * 100) < 0.5
        tbad += not ok
        rows.append({"area": "tv_licence", "price": "", "diesel": b, "co2": a, "fuel": pc,
                     "lean_company_car_benefit": r["tv_licence_pence"], "pe_company_car_benefit": round(v * 100, 2), "ok": ok})
        if not ok:
            print(f"  TV blind {b} age {a} PC {pc}: lean {r['tv_licence_pence']} pe {v * 100:.2f}")
    print(f"TV licence: {len(tvs) - tbad}/{len(tvs)} agree")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=sorted({k for r in rows for k in r}))
        w.writeheader()
        w.writerows(rows)
    return 1 if bad or tbad else 0


if __name__ == "__main__":
    sys.exit(main())
