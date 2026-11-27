"""Compare ISAs, the minimum wage and the Warm Home Discount with PolicyEngine UK,
2026-27 (P9e).

* ISAs: ages 16 to 60 (with 17, 18, 49 and 50), subscriptions and Lifetime ISA
  payments around £20,000 and £4,000: `isa_subscriptions_above_limit` and
  `lifetime_isa_bonus` to the penny.
* The minimum wage: ages 15 to 30, apprentices or not: `minimum_wage` to the penny.
* The Warm Home Discount: one-person households in England, Wales and Scotland on
  each qualifying benefit or none (the benefit given to PolicyEngine as the benefit
  unit's amount, with `would_receive_warm_home_discount`): to the penny. Scotland
  has its own scheme (SI 2022/1073 and its 2026 successor), which neither side
  models, so both give nil there.

    uv run python compare_p9e.py [--binary ../.lake/build/bin/uktax] [--random 1000]
"""

from __future__ import annotations

import argparse
import csv
import pathlib
import random
import sys

from compare_pension import run

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_BINARY = HERE.parent / ".lake/build/bin/uktax"
YEAR = 2026
BENEFITS = [None, "pension_credit", "universal_credit", "housing_benefit", "esa_income"]
REGION = {"england": "NORTH_WEST", "wales": "WALES", "scotland": "SCOTLAND"}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=1998)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_p9e.csv")
    args = ap.parse_args()
    rng = random.Random(args.seed)
    from policyengine_uk import Simulation

    cs = [{"age": a, "subs": s, "lp": p, "mw_age": rng.randint(15, 30), "apprentice": rng.random() < 0.2,
           "country": rng.choice(list(REGION)), "benefit": rng.choice(BENEFITS)}
          for a in (17, 18, 49, 50) for s in (1_999_999, 2_000_000, 2_000_001) for p in (399_999, 400_000, 400_001)]
    for _ in range(args.random):
        cs.append({"age": rng.randint(16, 60), "subs": rng.choice([0, rng.randint(0, 3_000_000)]),
                   "lp": rng.choice([0, rng.randint(0, 600_000)]), "mw_age": rng.randint(15, 30),
                   "apprentice": rng.random() < 0.2, "country": rng.choice(list(REGION)),
                   "benefit": rng.choice(BENEFITS)})
    ln = run(args.binary, [{"non_savings_pence": 0, "savings_pence": 0, "dividends_pence": 0, "country": c["country"],
                            "isa": {"age": c["age"], "subscriptions_pence": c["subs"],
                                    "lifetime_isa_payments_pence": c["lp"]},
                            "minimum_wage": {"age": c["mw_age"], "apprentice": c["apprentice"]},
                            "warm_home_discount": {"qualifying_benefit": c["benefit"] is not None}} for c in cs])
    people, bus, hhs = {}, {}, {}
    for i, c in enumerate(cs):
        people[f"p{i}"] = {"age": {YEAR: c["age"]}, "isa_subscriptions": {YEAR: c["subs"] / 100},
                           "lifetime_isa_payments": {YEAR: c["lp"] / 100}}
        people[f"w{i}"] = {"age": {YEAR: c["mw_age"]},
                           "qualifies_for_apprentice_minimum_wage": {YEAR: c["apprentice"]}}
        bus[f"b{i}"] = {"members": [f"p{i}"]}
        bus[f"bw{i}"] = {"members": [f"w{i}"]}
        for b in BENEFITS[1:]:
            bus[f"b{i}"][b] = {YEAR: 500.0 if c["benefit"] == b else 0.0}
        hhs[f"h{i}"] = {"members": [f"p{i}"], "region": {YEAR: REGION[c["country"]]},
                        "would_receive_warm_home_discount": {YEAR: True}}
        hhs[f"hw{i}"] = {"members": [f"w{i}"], "region": {YEAR: "NORTH_WEST"}}
    sim = Simulation(situation={"people": people, "benunits": bus, "households": hhs})
    ids = list(people)
    pe = {v: dict(zip(ids, (float(x) for x in sim.calculate(v, YEAR))))
          for v in ("isa_subscriptions_above_limit", "lifetime_isa_bonus", "minimum_wage")}
    whd = [float(x) for x in sim.calculate("warm_home_discount", YEAR)]
    whd = dict(zip(hhs, whd))
    rows, bad = [], 0
    for i, (c, r) in enumerate(zip(cs, ln)):
        mine = {"isa_subscriptions_above_limit": r["isa_subscriptions_above_limit_pence"],
                "lifetime_isa_bonus": r["lifetime_isa_bonus_quarter_pence"] / 4,
                "minimum_wage": r["minimum_wage_pence"],
                "warm_home_discount": r["warm_home_discount_pence"]}
        theirs = {"isa_subscriptions_above_limit": pe["isa_subscriptions_above_limit"][f"p{i}"] * 100,
                  "lifetime_isa_bonus": pe["lifetime_isa_bonus"][f"p{i}"] * 100,
                  "minimum_wage": pe["minimum_wage"][f"w{i}"] * 100,
                  "warm_home_discount": whd[f"h{i}"] * 100}
        ok = all(abs(mine[k] - theirs[k]) < 0.5 for k in mine)
        bad += not ok
        rows.append({**c, **{f"lean_{k}": v for k, v in mine.items()}, **{f"pe_{k}": round(v, 2) for k, v in theirs.items()},
                     "ok": ok})
        if not ok and bad <= 10:
            print(f"  {c}: lean {mine} pe {theirs}")
    print(f"ISAs, the minimum wage and the Warm Home Discount: {len(cs) - bad}/{len(cs)} agree "
          f"({sum(r['lean_lifetime_isa_bonus'] > 0 for r in rows)} with a bonus, "
          f"{sum(r['lean_warm_home_discount'] > 0 for r in rows)} with the rebate)")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
