"""Compare Vehicle Excise Duty for cars with PolicyEngine UK, 2026-27 (P9f).

Cars first registered from 1995 to March 2027, petrol, RDE2 diesel, other diesel,
alternative fuel or electric, with CO2 figures at every band edge and at random,
list prices around £40,000 and £50,000, and engines either side of 1,549cc. Both
sides take the duty for the twelve-month licence in force for the 2026-27 rate
year (1 April 2026 to 31 March 2027), renewed each year since first registration:
the licence year is 2026 less the year of registration, plus one for a car
registered in January to March (licence year 0 is the first licence, at the
first-year rate). Must agree to the pound.

    uv run python compare_p9f.py [--binary ../.lake/build/bin/uktax] [--random 1000]
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import pathlib
import random
import sys

from compare_pension import run

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_BINARY = HERE.parent / ".lake/build/bin/uktax"
YEAR = 2026
FUELS = ["PETROL", "DIESEL_RDE2", "DIESEL_NON_RDE2", "ALTERNATIVE_FUEL", "ELECTRIC"]
CO2 = [0, 1, 50, 51, 75, 76, 90, 91, 100, 101, 110, 111, 120, 121, 130, 131, 140, 141, 150, 151, 165, 166,
       170, 171, 175, 176, 185, 186, 190, 191, 200, 201, 225, 226, 255, 256, 300]
DATES = [dt.date(2001, 2, 28), dt.date(2001, 3, 1), dt.date(2006, 3, 22), dt.date(2006, 3, 23),
         dt.date(2017, 3, 31), dt.date(2017, 4, 1), dt.date(2021, 3, 31), dt.date(2021, 4, 1),
         dt.date(2025, 3, 31), dt.date(2025, 4, 1), dt.date(2026, 4, 1), dt.date(2027, 3, 31)]


def lean_case(c: dict) -> dict:
    d = c["date"]
    zev = c["fuel"] == "ELECTRIC"
    co2 = 0 if zev else c["co2"]
    if d >= dt.date(2017, 4, 1):
        v = {"registered": "from_april_2017", "co2_g_km": co2, "diesel_non_rde2": c["fuel"] == "DIESEL_NON_RDE2",
             "zero_emission": zev, "registered_before_april_2025": d < dt.date(2025, 4, 1),
             "list_price_pence": c["price"], "licence_year": YEAR - d.year + (d.month < 4)}
    elif d >= dt.date(2001, 3, 1):
        v = {"registered": "march_2001_to_march_2017", "co2_g_km": co2,
             "registered_before_23_march_2006": d < dt.date(2006, 3, 23)}
    else:
        v = {"registered": "before_march_2001", "engine_over_1549cc": c["engine"] > 1549 and not zev}
    return {"non_savings_pence": 0, "savings_pence": 0, "dividends_pence": 0, "vehicle_excise_duty": v}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=1994)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_p9f.csv")
    args = ap.parse_args()
    rng = random.Random(args.seed)
    from policyengine_uk import Simulation

    start = dt.date(1995, 1, 1).toordinal()
    end = dt.date(2027, 3, 31).toordinal()
    cs = [{"date": d, "fuel": f, "co2": c, "price": 4_500_000, "engine": 1600} for d in DATES for f in FUELS
          for c in (CO2 if d == dt.date(2026, 4, 1) or d == dt.date(2010, 6, 1) else [130])]
    cs += [{"date": dt.date(2010, 6, 1), "fuel": "PETROL", "co2": c, "price": 0, "engine": 1600} for c in CO2]
    cs += [{"date": dt.date(2022, 5, 1), "fuel": f, "co2": 120, "price": p, "engine": 1600}
           for f in FUELS for p in (4_000_000, 4_000_001, 5_000_000, 5_000_001)]
    for _ in range(args.random):
        cs.append({"date": rng.choice(DATES + [dt.date.fromordinal(rng.randint(start, end))]),
                   "fuel": rng.choice(FUELS), "co2": rng.choice(CO2 + [rng.randint(0, 320)]),
                   "price": rng.choice([rng.randint(1_000_000, 4_000_000), rng.randint(3_500_000, 12_000_000)]),
                   "engine": rng.choice([1549, 1550, rng.randint(800, 4000)])})
    ln = run(args.binary, [lean_case(c) for c in cs])
    people, hhs = {}, {}
    for i, c in enumerate(cs):
        people[f"p{i}"] = {"age": {YEAR: 40}, "car_first_registration_date": {YEAR: c["date"].isoformat()},
                           "car_co2_emissions": {YEAR: c["co2"]}, "car_engine_size": {YEAR: c["engine"]},
                           "car_list_price": {YEAR: c["price"] / 100}, "car_fuel_type": {YEAR: c["fuel"]},
                           "car_is_ved_exempt": {YEAR: False}}
        hhs[f"h{i}"] = {"members": [f"p{i}"], "region": {YEAR: "NORTH_WEST"}}
    sim = Simulation(situation={"people": people, "households": hhs})
    pe = [float(x) for x in sim.calculate("car_vehicle_excise_duty", YEAR)]
    rows, bad = [], 0
    for c, r, v in zip(cs, ln, pe):
        mine = r["vehicle_excise_duty_pounds"]
        ok = abs(mine - v) < 0.005
        bad += not ok
        rows.append({**c, "date": c["date"].isoformat(), "lean": mine, "pe": round(v, 2), "ok": ok})
        if not ok and bad <= 10:
            print(f"  {c}: lean {mine} pe {v}")
    print(f"Vehicle Excise Duty: {len(cs) - bad}/{len(cs)} agree "
          f"({sum(c['date'] >= dt.date(2017, 4, 1) for c in cs)} registered from April 2017)")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
