"""Compare the Childcare Grant and free school meals with PolicyEngine UK, 2026-27 (P9h).

1. Childcare Grant (SI 2011/1986 regs 45, 47(2)-(2C)): one child or two, weekly
   childcare charges below, at and above the caps, and the income of reg 47 at
   the band edges and at random, for a whole academic year (PolicyEngine has no
   input for the days qualifying, nor for reg 47(5)'s halving; golden cases check
   both). PolicyEngine's `childcare_grant_household_income` is set to the same
   income and the student's child's `childcare_expenses` to 52 weeks of the
   charges. Agreement is to half a penny: PolicyEngine works in float32, whose
   spacing is under 0.2p at the largest grant (£17,796.48). A difference is
   explained only if PolicyEngine's figure is exactly what its method gives with
   the law's sums (85 % of the charges up to 52 weeks of the cap, `A`, in full
   while the income is under the reg 47(2C) limit and nil from it) and the law's
   figure is exactly `A` less the income over the threshold (£9,727 or £11,118),
   not below nil: the class "taper" (findings #47; PolicyEngine #2604, open).
   Any other difference fails the run.
2. Free school meals: PolicyEngine's `free_school_meals` has no formula: it is
   an input, the value of the meals, with no eligibility of its own, so there is
   no eligibility logic to compare. The run fails if that changes (a formula
   appears), so the comparison is revisited. What can be compared is the use of
   the value: given the model's value for a household (its eligibility under
   s512ZB with the value of each pupil's lunches), PolicyEngine must add exactly
   that to `hbai_household_net_income`, as `netAllFsm` adds it to net income (to
   1p: the two net incomes are float32 sums of up to about £60,000, spaced
   0.4p apart).

    uv run python compare_p9h.py [--binary ../.lake/build/bin/uktax] [--random 1000]
"""

from __future__ import annotations

import argparse
import csv
import pathlib
import random
import sys
from fractions import Fraction

from compare_pension import run

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_BINARY = HERE.parent / ".lake/build/bin/uktax"
YEAR = 2026
B0 = {"non_savings_pence": 0, "savings_pence": 0, "dividends_pence": 0}
# The law's sums (SI 2011/1986 regs 45(5), 47(2A)-(2C) as substituted by SI 2025/162,
# unchanged by SI 2026/130; UkTax/Params.lean), pence.
CAP = {1: 19_962, 2: 34_224}
THRESHOLD = {1: 972_700, 2: 1_111_800}
LIMIT = {1: 2_010_723, 2: 2_891_447}
TOL = Fraction(1, 200)  # half a penny, in pounds


def law_pounds(n: int, w: int, x: int) -> tuple[Fraction, Fraction]:
    """(A, the law's grant) for a whole year, pounds."""
    a = Fraction(52 * min(85 * w, 100 * CAP[n]), 10_000)
    if x > LIMIT[n]:
        return a, Fraction(0)
    return a, max(Fraction(0), a - Fraction(max(x - THRESHOLD[n], 0), 100))


def childcare(args, rng, Simulation) -> tuple[list[dict], int]:
    cs = []
    for n in (1, 2):
        caps = [0, 10_000, (CAP[n] * 100 + 84) // 85 - 1, (CAP[n] * 100 + 84) // 85, 60_000]
        edges = [0, THRESHOLD[n] - 1, THRESHOLD[n], THRESHOLD[n] + 1, 1_500_000, LIMIT[n] - 1, LIMIT[n],
                 LIMIT[n] + 1, 3_500_000]
        cs += [{"n": n, "w": w, "x": x} for w in caps for x in edges]
    for _ in range(args.random):
        n = rng.choice((1, 2))
        cs.append({"n": n, "w": rng.choice([rng.randint(0, 60_000), rng.randint(20_000, 45_000)]),
                   "x": rng.choice([rng.randint(0, 3_500_000), rng.randint(THRESHOLD[n] - 1_000, LIMIT[n] + 1_000)])})
    ln = run(args.binary, [{**B0, "student_support": {"dependants_income_pence": c["x"], "childcare_grant": {
        "children": c["n"], "weekly_charges_pence": c["w"]}}} for c in cs])
    people, bus, hhs = {}, {}, {}
    for i, c in enumerate(cs):
        kids = [f"k{i}"] + ([f"j{i}"] if c["n"] == 2 else [])
        people[f"s{i}"] = {"age": {YEAR: 30}, "is_parent": {YEAR: True},
                           "childcare_grant_full_time_student": {YEAR: True},
                           "childcare_grant_student_finance_eligible": {YEAR: True},
                           "childcare_grant_household_income": {YEAR: c["x"] / 100}}
        people[f"k{i}"] = {"age": {YEAR: 4}, "childcare_expenses": {YEAR: 52 * c["w"] / 100}}
        if c["n"] == 2:
            people[f"j{i}"] = {"age": {YEAR: 8}, "childcare_expenses": {YEAR: 0}}
        bus[f"b{i}"] = {"members": [f"s{i}"] + kids}
        hhs[f"h{i}"] = {"members": [f"s{i}"] + kids, "region": {YEAR: "NORTH_WEST"}}
    sim = Simulation(situation={"people": people, "benunits": bus, "households": hhs})
    pe = dict(zip(people, sim.calculate("childcare_grant", YEAR)))
    rows, bad, taper, most = [], 0, 0, Fraction(0)
    for i, (c, r) in enumerate(zip(cs, ln)):
        mine = Fraction(r["childcare_grant_73000ths_pence"], 7_300_000)
        theirs = Fraction(float(pe[f"s{i}"])).limit_denominator(1_000_000)
        a, law = law_pounds(c["n"], c["w"], c["x"])
        assert mine == law, f"model {mine} differs from the law's sums {law} for {c}"
        kind = "agree"
        if abs(theirs - mine) > TOL:
            pe_way = a if c["x"] < LIMIT[c["n"]] else Fraction(0)
            # The known difference, exactly: PolicyEngine pays A (nil from the limit),
            # the law A less the income over the threshold.
            if (c["x"] > THRESHOLD[c["n"]] and abs(theirs - pe_way) <= TOL
                    and pe_way - mine == (min(Fraction(c["x"] - THRESHOLD[c["n"]], 100), a) if pe_way else -mine)):
                kind = "taper"
                taper += 1
                most = max(most, abs(theirs - mine))
            else:
                kind = "?"
                bad += 1
                if bad <= 10:
                    print(f"  unexplained {c}: law £{float(mine):,.2f} pe £{float(theirs):,.2f}")
        rows.append({"part": "childcare_grant", **c, "lean": float(mine), "pe": float(theirs), "class": kind})
    agree = sum(r["class"] == "agree" for r in rows)
    print(f"Childcare Grant: {agree}/{len(cs)} agree to half a penny; {taper} in the reg 47 taper band, where "
          f"PolicyEngine pays the full 85 % of the charges up to the cap and the law takes off the income over the "
          f"threshold (up to £{float(most):,.2f} apart); {bad} unexplained")
    return rows, bad


def meals(args, rng, Simulation) -> tuple[list[dict], int]:
    var = Simulation(situation={"people": {"p": {"age": {YEAR: 30}}}}).tax_benefit_system.variables["free_school_meals"]
    if var.formulas:
        print("free_school_meals now has a formula in PolicyEngine: compare its eligibility (P9h)")
        return [], 1
    cs = []
    for _ in range(max(args.random // 20, 20)):
        cs.append({"pay": rng.choice([rng.randint(0, 1_000_000), rng.randint(0, 5_000_000)]),
                   "infant": rng.random() < 0.3, "before": rng.randint(0, 30_000), "after": rng.randint(0, 60_000)})
    ln = run(args.binary, [{**B0, "non_savings_pence": c["pay"], "employment_pence": c["pay"], "uc": {"children": 2},
                            "school_meals": {"pupils": [{"infant": c["infant"], "value_before_pence": c["before"],
                                                         "value_after_pence": c["after"]}]}} for c in cs])
    rows, bad = [], 0
    for with_meals in (False, True):
        people, bus, hhs = {}, {}, {}
        for i, (c, r) in enumerate(zip(cs, ln)):
            people[f"a{i}"] = {"age": {YEAR: 35}, "employment_income": {YEAR: c["pay"] / 100}}
            people[f"c{i}"] = {"age": {YEAR: 6}, "free_school_meals": {
                YEAR: r["free_school_meals_pence"] / 100 if with_meals else 0}}
            bus[f"b{i}"] = {"members": [f"a{i}", f"c{i}"]}
            hhs[f"h{i}"] = {"members": [f"a{i}", f"c{i}"], "region": {YEAR: "NORTH_WEST"}}
        sim = Simulation(situation={"people": people, "benunits": bus, "households": hhs})
        net = list(sim.calculate("hbai_household_net_income", YEAR))
        if with_meals:
            for i, (c, r) in enumerate(zip(cs, ln)):
                added = round((float(net[i]) - float(base[i])) * 100)
                ok = abs(added - r["free_school_meals_pence"]) <= 1
                bad += not ok
                if not ok and bad <= 10:
                    print(f"  PolicyEngine added {added}p, the model's value is {r['free_school_meals_pence']}p: {c}")
                rows.append({"part": "free_school_meals", **c, "lean": r["free_school_meals_pence"], "pe": added,
                             "class": "agree" if ok else "?"})
        base = net
    print(f"Free school meals: PolicyEngine has no eligibility rule (`free_school_meals` is an input); given the "
          f"model's value it adds exactly that to net income in {len(rows) - bad}/{len(rows)} households; {bad} unexplained")
    return rows, bad


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=2026)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_p9h.csv")
    args = ap.parse_args()
    rng = random.Random(args.seed)
    from policyengine_uk import Simulation

    crows, cbad = childcare(args, rng, Simulation)
    mrows, mbad = meals(args, rng, Simulation)
    allrows = crows + mrows
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=sorted({k for r in allrows for k in r}))
        w.writeheader()
        w.writerows(allrows)
    return 1 if cbad or mbad else 0


if __name__ == "__main__":
    sys.exit(main())
