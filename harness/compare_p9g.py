"""Compare student support in England with PolicyEngine UK, 2026-27 (P9g).

1. The maintenance loan (SI 2011/1986 regs 80A, 80B, 80C, 105) for a given
   household income: every living arrangement, the standard and "entitled to
   benefits" schedules and students of 60 or over, at band edges and at random.
   PolicyEngine's `maintenance_loan_household_income` is set to the same figure.
   Agreement is to the pound; each difference must fall in one of the classes of
   findings #46 or the run fails:
   - "complete": PolicyEngine rounds the taper where the law counts complete
     steps (£1, £2 at most on the two-stage schedule);
   - "minimum": PolicyEngine's floor is a share of the maximum (44 %, 46.6 %,
     49.8 %; 37.3 %, 40.9 %, 45.7 %) where reg 105(6A), (6C) set sums (at most
     £6 a year);
   - "over 60": PolicyEngine pays nothing above £43,835 (the 2025-26 point)
     where the 2026-27 sums pay £50 to £55 up to £43,857.27.
2. Household income: parents' pay and pension contributions, a sibling, the
   student's term-time pay. The law's Sch 4 figure set against PolicyEngine's own
   proxy (net income of the benefit units); reported, not required to agree.
3. Adult Dependants' Grant and Parents' Learning Allowance (reg 47) against
   PolicyEngine's flat amounts below a cut-off: agreement required outside the
   taper bands, differences inside reported.

    uv run python compare_p9g.py [--binary ../.lake/build/bin/uktax] [--random 1000]
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
ARR = {"A": "LIVING_WITH_PARENTS", "B": "AWAY_IN_LONDON", "D": "AWAY_OUTSIDE_LONDON"}
MIN_LAW = {"A": 4_013, "B": 7_039, "D": 5_048}  # reg 105(6A), (6C)
EDGES = [0, 2_500_000, 2_500_001, 2_500_653, 2_500_654, 2_500_655, 3_000_000, 4_287_500, 4_287_501, 4_383_500,
         4_383_501, 4_385_000, 4_385_727, 4_385_728, 4_500_000, 5_500_000, 5_838_700, 6_000_000, 7_000_000, 10_000_000]
B0 = {"non_savings_pence": 0, "savings_pence": 0, "dividends_pence": 0}


def loans(args, rng, Simulation) -> tuple[list[dict], int]:
    cs = [{"sched": s, "cat": k, "hi": h} for s in ("standard", "benefits") for k in "ABD" for h in EDGES]
    cs += [{"sched": "over_60", "cat": "D", "hi": h} for h in EDGES]
    for _ in range(args.random):
        cs.append({"sched": rng.choice(["standard", "benefits", "over_60"]), "cat": rng.choice("ABD"),
                   "hi": rng.choice([rng.randint(2_400_000, 4_500_000), rng.randint(0, 12_000_000),
                                     rng.randint(4_383_000, 4_386_000)])})
    ln = run(args.binary, [{**B0, "student_support": {"schedule": c["sched"], "category": c["cat"],
                                                      "household_income_pence": c["hi"]}} for c in cs])
    people, hhs = {}, {}
    for i, c in enumerate(cs):
        people[f"p{i}"] = {"age": {YEAR: 61 if c["sched"] == "over_60" else 19},
                           "maintenance_loan_in_higher_education": {YEAR: True},
                           "maintenance_loan_household_income": {YEAR: c["hi"] / 100},
                           "maintenance_loan_living_arrangement": {YEAR: ARR[c["cat"]]},
                           "maintenance_loan_entitled_to_benefits": {YEAR: c["sched"] == "benefits"}}
        hhs[f"h{i}"] = {"members": [f"p{i}"], "region": {YEAR: "LONDON" if c["cat"] == "B" else "NORTH_WEST"}}
    pe = Simulation(situation={"people": people, "households": hhs}).calculate("maintenance_loan", YEAR)
    rows, bad, cls = [], 0, {"complete": [0, 0], "minimum": [0, 0], "over 60": [0, 0]}
    for c, r, v in zip(cs, ln, pe):
        mine, theirs = r["maintenance_loan_pounds"], round(float(v))
        d = theirs - mine
        kind = "agree"
        if d:
            if c["sched"] == "over_60" and theirs == 0:
                kind = "over 60" if 4_383_500 < c["hi"] < 4_385_728 and 50 <= mine <= 55 else "?"
            elif c["sched"] != "over_60" and (mine == MIN_LAW[c["cat"]] or theirs <= MIN_LAW[c["cat"]] + 6):
                kind = "minimum" if abs(d) <= 6 else "?"
            else:
                kind = "complete" if d == -1 or (c["sched"] == "benefits" and d == -2) else "?"
            if kind == "?":
                bad += 1
                if bad <= 10:
                    print(f"  unexplained {c}: lean {mine} pe {theirs}")
            else:
                cls[kind][0] += 1
                cls[kind][1] = max(cls[kind][1], abs(d))
        rows.append({"part": "loan", **c, "lean": mine, "pe": theirs, "class": kind})
    agree = sum(r["class"] == "agree" for r in rows)
    print(f"Maintenance loan: {agree}/{len(cs)} agree to the pound; "
          + "; ".join(f"{k} {n} (at most £{m})" for k, (n, m) in cls.items())
          + f"; {bad} unexplained")
    return rows, bad


def household(args, rng, Simulation) -> tuple[list[dict], int]:
    cs = []
    for _ in range(max(args.random // 5, 50)):
        cs.append({"p1": rng.choice([0, rng.randint(1_000_000, 9_000_000)]), "p2": rng.choice([0, rng.randint(0, 5_000_000)]),
                   "pension": rng.choice([0, rng.randint(0, 400_000)]), "sibling": rng.random() < 0.5,
                   "student": rng.choice([0, rng.randint(0, 600_000)])})
    lcases = []
    for c in cs:
        # Relief at source: the gross contribution comes off (Sch 4 para 5(2)(a)).
        res = [{"taxable_income_pence": c["p1"], "pension_contributions_pence": min(c["pension"], c["p1"])},
               {"taxable_income_pence": c["p2"]},
               {"taxable_income_pence": c["student"], "term_time_earnings_pence": c["student"]}]
        lcases.append({**B0, "student_support": {"category": "A", "residual_incomes": res,
                                                 "dependent_children": int(c["sibling"])}})
    ln = run(args.binary, lcases)
    people, bus, hhs = {}, {}, {}
    for i, c in enumerate(cs):
        par = [f"a{i}", f"b{i}"] + ([f"s{i}"] if c["sibling"] else [])
        people[f"a{i}"] = {"age": {YEAR: 50}, "employment_income": {YEAR: c["p1"] / 100},
                           "personal_pension_contributions": {YEAR: min(c["pension"], c["p1"]) / 100 * 0.8}}
        people[f"b{i}"] = {"age": {YEAR: 48}, "employment_income": {YEAR: c["p2"] / 100}}
        if c["sibling"]:
            people[f"s{i}"] = {"age": {YEAR: 12}}
        people[f"t{i}"] = {"age": {YEAR: 19}, "employment_income": {YEAR: c["student"] / 100},
                           "in_HE": {YEAR: True}, "maintenance_loan_in_higher_education": {YEAR: True}}
        bus[f"bu{i}"] = {"members": par}
        bus[f"bt{i}"] = {"members": [f"t{i}"]}
        hhs[f"h{i}"] = {"members": par + [f"t{i}"], "region": {YEAR: "NORTH_WEST"}}
    sim = Simulation(situation={"people": people, "benunits": bus, "households": hhs})
    names = list(people)
    hi = dict(zip(names, sim.calculate("maintenance_loan_household_income", YEAR)))
    ml = dict(zip(names, sim.calculate("maintenance_loan", YEAR)))
    rows, diffs, ldiffs, bad = [], [], [], 0
    for i, (c, r) in enumerate(zip(cs, ln)):
        law_hi, pe_hi = r["student_household_income_pence"], round(float(hi[f"t{i}"]) * 100)
        # What PolicyEngine's total-income proxy leaves out (findings #46): the gross
        # pension contribution, £1,130 for the sibling, the student's term-time pay.
        # Where the law's figure would go below nil the difference is smaller.
        omitted = min(c["pension"], c["p1"]) + 113_000 * c["sibling"] + c["student"]
        gross = c["p1"] + c["p2"] + c["student"]
        ok = abs(pe_hi - gross) <= 2 and law_hi == max(gross - omitted, 0)  # float32: findings #4
        bad += not ok
        if not ok and bad <= 10:
            print(f"  unexplained household {c}: lean {law_hi} pe {pe_hi}")
        diffs.append(pe_hi - law_hi)
        ldiffs.append(r["maintenance_loan_pounds"] - round(float(ml[f"t{i}"])))
        rows.append({"part": "household", **c, "lean_hi": law_hi, "pe_hi": pe_hi,
                     "lean": r["maintenance_loan_pounds"], "pe": round(float(ml[f"t{i}"])), "class": "proxy"})
    print(f"Household income: {sum(abs(d) <= 2 for d in diffs)}/{len(cs)} families agree; PolicyEngine higher in "
          f"{sum(d > 2 for d in diffs)} by exactly the pension contributions, the £1,130 for a sibling and the student's "
          f"term-time pay it does not take off (up to £{max(diffs) / 100:,.2f}; findings #46); its loan up to "
          f"£{max(ldiffs):,} lower; {bad} unexplained")
    return rows, bad


def grants(args, rng, Simulation) -> tuple[list[dict], int]:
    xs = [0, 874_600, 874_601, 1_200_000, 1_491_000, 1_500_000, 1_583_597, 1_583_598, 1_583_599, 1_850_000,
          1_895_000, 1_895_798, 1_895_799, 2_500_000]
    xs += [rng.randint(0, 2_200_000) for _ in range(args.random // 5)]
    ln = run(args.binary, [{**B0, "student_support": {"household_income_pence": x, "dependants_income_pence": x}}
                           for x in xs])
    people, bus, hhs = {}, {}, {}
    for i, x in enumerate(xs):
        people[f"s{i}"] = {"age": {YEAR: 30}, "maintenance_loan_in_higher_education": {YEAR: True}, "is_parent": {YEAR: True},
                           "maintenance_loan_household_income": {YEAR: x / 100}}
        people[f"q{i}"] = {"age": {YEAR: 30}}
        people[f"c{i}"] = {"age": {YEAR: 5}}
        bus[f"b{i}"] = {"members": [f"s{i}", f"q{i}", f"c{i}"]}
        hhs[f"h{i}"] = {"members": [f"s{i}", f"q{i}", f"c{i}"], "region": {YEAR: "NORTH_WEST"}}
    sim = Simulation(situation={"people": people, "benunits": bus, "households": hhs})
    names = list(people)
    adg = dict(zip(names, sim.calculate("adult_dependants_grant", YEAR)))
    pla = dict(zip(names, sim.calculate("parents_learning_allowance", YEAR)))
    rows, bad, band = [], 0, {"adg": [0, 0.0], "pla": [0, 0.0]}
    for i, (x, r) in enumerate(zip(xs, ln)):
        for k, mine, theirs, lo, hi in (
                ("adg", r["adult_dependants_grant_half_pence"] / 200, float(adg[f"s{i}"]), 874_600, 1_583_598),
                ("pla", r["parents_learning_allowance_half_pence"] / 200, float(pla[f"s{i}"]), 1_491_000, 1_895_798)):
            ok = abs(mine - theirs) < 0.005
            if not ok and lo < x <= hi:
                band[k][0] += 1
                band[k][1] = max(band[k][1], theirs - mine)
            elif not ok:
                bad += 1
                if bad <= 10:
                    print(f"  unexplained {k} at {x / 100:,.2f}: lean {mine} pe {theirs}")
            rows.append({"part": k, "hi": x, "lean": mine, "pe": theirs, "class": "agree" if ok else "taper"})
    n = len(xs)
    print(f"Adult Dependants' Grant: {n - band['adg'][0]}/{n} agree, {band['adg'][0]} in the taper band where PolicyEngine "
          f"pays the full £3,545 (up to £{band['adg'][1]:,.2f} a year more); Parents' Learning Allowance: {n - band['pla'][0]}/{n} "
          f"agree, {band['pla'][0]} in the band (up to £{band['pla'][1]:,.2f} more); {bad} unexplained")
    return rows, bad


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=2011)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_p9g.csv")
    args = ap.parse_args()
    rng = random.Random(args.seed)
    from policyengine_uk import Simulation

    lrows, lbad = loans(args, rng, Simulation)
    hrows, hbad = household(args, rng, Simulation)
    grows, gbad = grants(args, rng, Simulation)
    allrows = lrows + hrows + grows
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=sorted({k for r in allrows for k in r}))
        w.writeheader()
        w.writerows(allrows)
    return 1 if lbad or hbad or gbad else 0


if __name__ == "__main__":
    sys.exit(main())
