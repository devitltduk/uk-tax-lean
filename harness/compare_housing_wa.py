"""Compare working-age Housing Benefit (P5c) with PolicyEngine UK, 2026-27.

Working-age renters of a council (no local housing allowance), single (aged 30,
or 22: the under-25 allowance and October disregard), lone parents and couples
(both 30) with 0 to 3 children aged 5, with pay (the claimant's), savings
(PolicyEngine's household `savings`) and the household's rent. Most live in
specified or temporary accommodation (PolicyEngine's one input for both,
`in_specified_or_temporary_accommodation`), the rest in general accommodation.
None claims Universal Credit (`claims_universal_credit` false), so the means test
applies, except a group that does, which PolicyEngine and the model both
passport to the maximum (SI 2006/213 Sch 5 para 4).

PolicyEngine leaves out the £87.88 a week child or young person amount (Sch 3
para 2), a limitation it documents (its open issue #2825, deferred in #2232; findings
#34). Families with children are compared on that basis: the model is run a second
time counting no children for the amount (the family premium and child premiums,
which PolicyEngine has, are not used here), and the gap the law makes is reported.
In general accommodation PolicyEngine pays only a continuing award, so those
households report one (`housing_benefit_reported`); Universal Credit claimants are
only in specified or temporary accommodation (elsewhere a UC claim ends the award,
SI 2014/1230 reg 8(2A)).

The benefit cap applies to Housing Benefit outside London, with Child Benefit
(PolicyEngine's, a week) as the other welfare benefit. In specified accommodation
the law counts Housing Benefit as nil for the cap (reg 75C(2)(a)); PolicyEngine's
input does not implement that, as its documentation says, so it treats both kinds
as temporary accommodation is treated. Specified accommodation is compared on that
basis (the model run as temporary accommodation), and the cases where the law
gives more are counted.

PolicyEngine also caps the year's total, at the annual limit unrounded; the law caps
each benefit week (reg 75G) at the limit ÷ 52 rounded to the penny (reg 75CA(1)).
The model's own award, its weekly cap included, is compared. Where the model's cap
binds and the two differ, the case counts as the capping method only if the model's
uncapped rates, weighted by PolicyEngine's day shares and capped PolicyEngine's way,
give PolicyEngine's figure; the count and the largest gap are reported. The law's
weekly cap gives about 8p a year less where it binds all year, more where it binds
only from October (findings #34).

Whether the £17.10 additional disregard's conditions (Sch 4 para 17(2): hours of
work) are met is read from PolicyEngine
(`meets_housing_benefit_additional_earnings_disregard_conditions`) and passed to
the model.

PolicyEngine splits the year at 5 October 2026 by days (182 / 365 before, 183 /
365 from it); the model takes 26 weeks of each rate. So the model's two 52-week
rates are weighted by PolicyEngine's day shares here, like with like (findings
#34). PolicyEngine pays an award in general accommodation for the whole year
(it does not apply the 1 July 2026 end, as its code says); that is compared at
the April rate. Must agree within --steps float32 steps of the larger of the
yearly rent and pay, plus 0.4p for the NIC thresholds (findings #1).

    uv run python compare_housing_wa.py [--binary ../.lake/build/bin/uktax] [--random 1000]
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
MICRO = 1_000_000


def step(pence: float) -> float:
    return float(np.spacing(np.float32(max(pence / 100, 1.0)))) * 100


def random_case(rng: random.Random) -> dict:
    kind = rng.choice(["single", "single", "lone", "couple"])
    return {"kind": kind, "young": kind == "single" and rng.random() < 0.25,
            "kids": rng.choice([1, 2, 3]) if kind == "lone" else (rng.choice([0, 0, 1, 2]) if kind == "couple" else 0),
            "pay": rng.choice([0, rng.randint(0, 1_500_000), rng.randint(0, 3_500_000)]),
            "capital": rng.choice([0, 0, rng.randint(0, 1_700_000)]),
            "rent": rng.randint(6_000, 30_000),
            "acc": (a := rng.choice(["specified", "specified", "temporary", "temporary", "general"])),
            "uc": a != "general" and rng.random() < 0.1}


def edge_cases() -> list[dict]:
    base = {"kind": "single", "young": False, "kids": 0, "pay": 1_200_000, "capital": 0, "rent": 12_000,
            "acc": "specified", "uc": False}
    out = [{**base, "capital": c} for c in (600_000, 600_001, 625_000, 625_001, 1_600_000, 1_600_001)]
    out += [{**base, "acc": "general"}, {**base, "young": True}, {**base, "pay": 0}]
    out += [{**base, "pay": 0, "rent": 30_000, "acc": a} for a in ("specified", "temporary", "general")]
    out += [{**base, "kind": "lone", "kids": 2, "pay": p} for p in (500_000, 1_800_000, 2_600_000)]
    out += [{**base, "kind": "couple", "kids": 1, "pay": 2_000_000}, {**base, "uc": True, "pay": 300_000}]
    return out


def policyengine(cs: list[dict]) -> dict[str, list]:
    from policyengine_uk import Simulation

    res: dict[str, list] = {"housing_benefit": [], "universal_credit": [], "add": [], "child_benefit": []}
    for lo in range(0, len(cs), 400):
        part = cs[lo : lo + 400]
        people, bus, hhs = {}, {}, {}
        for i, c in enumerate(part):
            age = 22 if c["young"] else 30
            people[f"a{i}"] = {"age": {YEAR: age}, "employment_income": {YEAR: c["pay"] / 100},
                               "marriage_allowance": {YEAR: 0}}
            members = [f"a{i}"]
            if c["kind"] == "couple":
                people[f"p{i}"] = {"age": {YEAR: 30}, "marriage_allowance": {YEAR: 0}}
                members.append(f"p{i}")
            for k in range(c["kids"]):
                people[f"c{i}_{k}"] = {"age": {YEAR: 5}}
                members.append(f"c{i}_{k}")
            bus[f"b{i}"] = {"members": members, "claims_universal_credit": {YEAR: c["uc"]},
                            "in_specified_or_temporary_accommodation": {YEAR: c["acc"] != "general"}}
            if c["acc"] == "general":
                people[f"a{i}"]["housing_benefit_reported"] = {YEAR: 1.0}
            hhs[f"h{i}"] = {"members": members, "region": {YEAR: "NORTH_WEST"},
                            "rent": {YEAR: c["rent"] * 52 / 100}, "tenure_type": {YEAR: "RENT_FROM_COUNCIL"},
                            "savings": {YEAR: c["capital"] / 100}}
        sim = Simulation(situation={"people": people, "benunits": bus, "households": hhs})
        res["housing_benefit"] += [float(x) for x in sim.calculate("housing_benefit", YEAR)]
        res["universal_credit"] += [float(x) for x in sim.calculate("universal_credit", YEAR)]
        res["child_benefit"] += [float(x) for x in sim.calculate("child_benefit", YEAR)]
        res["add"] += [bool(x) for x in sim.calculate(
            "meets_housing_benefit_additional_earnings_disregard_conditions", YEAR)]
    return res


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=2006)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_housing_wa.csv")
    args = ap.parse_args()
    rng = random.Random(args.seed)
    cs = edge_cases() + [random_case(rng) for _ in range(args.random)]
    pe = policyengine(cs)
    def payload_for(law: bool) -> list[dict]:
        return [one(c, uc, add, cb, law) for c, uc, add, cb in
                zip(cs, pe["universal_credit"], pe["add"], pe["child_benefit"])]

    def one(c: dict, uc: float, add: bool, cb: float, law: bool) -> dict:
        acc = c["acc"] if law or c["acc"] != "specified" else "temporary"
        return {"non_savings_pence": c["pay"], "savings_pence": 0, "dividends_pence": 0,
                        "employment_pence": c["pay"], "housing_benefit_working_age": {
                            "rent_weekly_pence": c["rent"], "couple": c["kind"] == "couple",
                            "lone_parent": c["kind"] == "lone", "under_25": c["young"],
                            "children": c["kids"] if law else 0, "cap_other_weekly_pence": round(cb * 100 / 52),
                            "additional_disregard": add, "passported": uc > 0, "capital_pence": c["capital"],
                            "accommodation": acc}}

    def pe_year(c: dict, r: dict, cb: float) -> float:
        """PolicyEngine's basis: the uncapped rates weighted by days, capped on the year."""
        u1 = r["housing_benefit_wa_uncapped_before_millionths_pence"] / MICRO
        u2 = r["housing_benefit_wa_uncapped_from_october_millionths_pence"] / MICRO
        a = u1 * 182 / 365 + u2 * 183 / 365 if c["acc"] != "general" else u1
        limit = (1_475_300 if c["kind"] == "single" and not c["kids"] else 2_202_000)
        excess = max(0.0, a + cb * 100 - limit)
        return a - min(excess, max(0.0, a - 52 * 50))

    def year(c: dict, r: dict) -> float:
        before = r["housing_benefit_wa_rate_before_millionths_pence"] / MICRO
        after = r["housing_benefit_wa_rate_from_october_millionths_pence"] / MICRO
        return before * 182 / 365 + after * 183 / 365 if c["acc"] != "general" else before

    def capped_by_model(r: dict) -> bool:
        """The model's benefit cap takes something off in at least one part of the year."""
        return (r["housing_benefit_wa_rate_before_millionths_pence"] < r["housing_benefit_wa_uncapped_before_millionths_pence"]
                or r["housing_benefit_wa_rate_from_october_millionths_pence"]
                < r["housing_benefit_wa_uncapped_from_october_millionths_pence"])

    law = run(args.binary, payload_for(True))
    pe_basis = run(args.binary, payload_for(False))
    rows, bad, worst, paid, passported, kids, gap, gap_max, capped = [], 0, 0.0, 0, 0, 0, 0.0, 0.0, 0
    cap_method, cap_gap_max = 0, 0.0
    for c, r, rl, hb, uc, cb in zip(cs, pe_basis, law, pe["housing_benefit"], pe["universal_credit"],
                                    pe["child_benefit"]):
        # The model's own award (its weekly benefit cap included), on PolicyEngine's basis
        # (no child amount; specified accommodation run as temporary), and in law.
        mine, in_law, pe_way = year(c, r), year(c, rl), pe_year(c, r, cb)
        if c["acc"] == "specified" and not c["kids"] and in_law > mine + 1:
            capped += 1
        if c["kids"]:
            kids += 1
            gap += in_law - mine
            gap_max = max(gap_max, in_law - mine)
        theirs = hb * 100
        st = step(max(c["rent"] * 52, c["pay"]))
        tol = args.steps * st + 0.4
        ok = abs(theirs - mine) <= tol
        cap_binds = capped_by_model(r)
        if not ok and cap_binds and abs(theirs - pe_way) <= tol:
            # The cap binds and PolicyEngine caps the year's total where the law caps each
            # week (reg 75G, 75CA(1)): the model's uncapped rates capped PolicyEngine's way
            # give PolicyEngine's figure, so the gap is the capping method alone.
            cap_method += 1
            cap_gap_max = max(cap_gap_max, abs(theirs - mine))
            ok = True
        else:
            worst = max(worst, abs(theirs - mine) / st)
        paid += mine > 0
        passported += uc > 0
        bad += not ok
        rows.append({**c, "lean_law_pence": round(in_law, 4), "lean_pence": round(mine, 4), "pe_pence": round(theirs, 4), "diff": round(theirs - mine, 4),
                     "ok": ok})
        if not ok and bad <= 12:
            print(f"  {c}: lean {mine:.2f} (law {in_law:.2f}) pe {theirs:.2f}")
    print(f"Working-age Housing Benefit: {len(cs) - bad}/{len(cs)} agree ({paid} paid, {passported} on UC; "
          f"worst {worst:.2f} float32 steps); {kids} families with children, where the law's £87.88 child amount "
          f"adds £{gap / 100:,.2f} in all, up to £{gap_max / 100:,.2f} a year; {capped} in specified accommodation "
          "capped on PolicyEngine's basis and not in law")
    print(f"  {sum(capped_by_model(r_) for r_ in pe_basis)} capped by the model; {cap_method} differ "
          f"only by the capping method (each week in law, the year in PolicyEngine), up to £{cap_gap_max / 100:,.2f} a year")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
