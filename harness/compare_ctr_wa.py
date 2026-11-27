"""Compare Council Tax Reduction for working-age applicants in Wales or Scotland
(P7b) with PolicyEngine UK, 2026-27.

Working-age households in Wales (single aged 30, or 22: the under-25 allowance;
lone parents and couples aged 30 with 0 to 3 children aged 5) with pay, savings
(PolicyEngine's household `savings`) and the year's council tax bill (its household
`council_tax`). Some claim Universal Credit (`claims_universal_credit`); for them
the Welsh scheme takes the UC maximum amount as the applicable amount and the UC
income and award as income (WSI 2013/3029 Sch 6 paras 3, 9); the model is given
the same UC household. The others are assessed on the scheme's own rules. Whether
the £17.10 additional disregard's conditions are met is read from PolicyEngine
(`meets_housing_benefit_additional_earnings_disregard_conditions`, the same
conditions as Sch 8 para 17) and passed to the model.

The scheme works by the day over 365 days; PolicyEngine takes 52 weeks (findings
#27), so its withdrawal is 364/365 of the law's. Like with like, PolicyEngine's
reduction must equal the bill less 364/365 of the model's withdrawal, not below
nil, within --steps float32 steps of the larger of the bill and pay, plus 0.4p
for the NIC thresholds (findings #1), plus, on UC, 2 float32 steps of the yearly
UC amounts (the award, maximum and income enter the withdrawal at 73/364).

Scotland (--country scotland, SSI 2021/249): the same households, assessed on
Scotland's own applicable amount with or without UC; on UC, income is the UC
earned income less the Sch 3 disregards, the unearned and tariff income and the
relevant UC payments (child and childcare elements, or the award if lower), less
the childcare costs element × 100/85 × 12/52. Lone parents on UC may have
childcare costs (PolicyEngine's `childcare_expenses`, shared among the children so
that each has charges, as compare_uc_full.py does: PolicyEngine caps the UC
childcare element by the children with a child element, the model by the children
with charges; the model gets the same monthly costs). The comparison is with the reg 13 main reduction:
PolicyEngine models neither reg 14 (bands E to H) nor the second adult rebate
(findings #36), so no band and no second adult is given. Reg 78(3) rounds the
weekly childcare charges to the penny, which PolicyEngine does not: up to 0.5p a
week of income, 365/35 × 0.5p = 5.3p a year of reduction, added to the tolerance
where there are childcare costs.

    uv run python compare_ctr_wa.py [--binary ../.lake/build/bin/uktax] [--random 1000] [--country scotland]
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
CU = 364_000_000


def step(pence: float) -> float:
    return float(np.spacing(np.float32(max(pence / 100, 1.0)))) * 100


def random_case(rng: random.Random, childcare: bool) -> dict:
    kind = rng.choice(["single", "single", "lone", "couple"])
    c = {"kind": kind, "young": kind == "single" and rng.random() < 0.25,
         "kids": rng.choice([1, 2, 3]) if kind == "lone" else (rng.choice([0, 0, 1, 2]) if kind == "couple" else 0),
         "pay": rng.choice([0, rng.randint(0, 1_500_000), rng.randint(0, 4_000_000)]),
         "capital": rng.choice([0, 0, rng.randint(0, 1_700_000)]),
         "ct": rng.randint(100_000, 300_000), "uc": rng.random() < 0.5, "childcare": 0}
    if childcare and c["uc"] and kind == "lone":
        c["childcare"] = rng.choice([0, rng.randint(1, 150_000)])
    return c


def edge_cases(childcare: bool) -> list[dict]:
    base = {"childcare": 0, "kind": "single", "young": False, "kids": 0, "pay": 1_200_000, "capital": 0, "ct": 150_000, "uc": False}
    out = [{**base, "capital": c} for c in (600_000, 600_001, 1_600_000, 1_600_001)]
    out += [{**base, "uc": True, "kids": 1, "kind": "lone", "pay": p} for p in (0, 1_000_000, 2_000_000)]
    out += [{**base, "kind": "lone", "kids": 2, "pay": 1_500_000, "ct": 180_000}, {**base, "young": True}]
    if childcare:
        out += [{**base, "uc": True, "kind": "lone", "kids": k, "pay": p, "childcare": m}
                for k in (1, 2) for p in (600_000, 1_200_000, 2_500_000) for m in (40_000, 150_000)]
    return out


def policyengine(cs: list[dict], region: str) -> dict[str, list]:
    from policyengine_uk import Simulation

    res: dict[str, list] = {"ctr": [], "add": []}
    for lo in range(0, len(cs), 400):
        part = cs[lo : lo + 400]
        people, bus, hhs = {}, {}, {}
        for i, c in enumerate(part):
            people[f"a{i}"] = {"age": {YEAR: 22 if c["young"] else 30}, "employment_income": {YEAR: c["pay"] / 100},
                               "marriage_allowance": {YEAR: 0}}
            members = [f"a{i}"]
            if c["kind"] == "couple":
                people[f"p{i}"] = {"age": {YEAR: 30}, "marriage_allowance": {YEAR: 0}}
                members.append(f"p{i}")
            for k in range(c["kids"]):
                people[f"c{i}_{k}"] = {"age": {YEAR: 5},
                                       "childcare_expenses": {YEAR: 12 * c["childcare"] / 100 / c["kids"]}}
                members.append(f"c{i}_{k}")
            bus[f"b{i}"] = {"members": members, "claims_universal_credit": {YEAR: c["uc"]}}
            hhs[f"h{i}"] = {"members": members, "region": {YEAR: region}, "council_tax": {YEAR: c["ct"] / 100},
                            "savings": {YEAR: c["capital"] / 100}}
        sim = Simulation(situation={"people": people, "benunits": bus, "households": hhs})
        res["ctr"] += [float(x) for x in sim.calculate("council_tax_benefit", YEAR)]
        res["add"] += [bool(x) for x in sim.calculate(
            "meets_housing_benefit_additional_earnings_disregard_conditions", YEAR)]
    return res


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=2013)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--country", choices=["wales", "scotland"], default="wales")
    ap.add_argument("--out", type=pathlib.Path)
    args = ap.parse_args()
    scot = args.country == "scotland"
    out = args.out or HERE / ("out/compare_ctr_wa_scotland.csv" if scot else "out/compare_ctr_wa.csv")
    rng = random.Random(args.seed)
    cs = edge_cases(scot) + [random_case(rng, scot) for _ in range(args.random)]
    pe = policyengine(cs, "SCOTLAND" if scot else "WALES")
    payload = []
    for c, add in zip(cs, pe["add"]):
        ctr = {"council_tax_pence": c["ct"], "couple": c["kind"] == "couple", "lone_parent": c["kind"] == "lone",
               "under_25": c["young"], "children": c["kids"], "additional_disregard": add,
               "capital_pence": c["capital"]}
        x = {"non_savings_pence": c["pay"], "savings_pence": 0, "dividends_pence": 0, "employment_pence": c["pay"],
             "country": args.country, "council_tax_reduction_working_age": ctr}
        if c["uc"]:
            x["uc"] = {"couple": c["kind"] == "couple", "children": c["kids"], "under_25": c["young"],
                       "capital_pence": c["capital"]}
            if c["childcare"]:
                x["uc"] |= {"childcare_monthly_pence": c["childcare"], "childcare_children": min(c["kids"], 2)}
        payload.append(x)
    ln = run(args.binary, payload)
    rows, bad, paid, worst = [], 0, 0, 0.0
    for c, r, p in zip(cs, ln, pe["ctr"]):
        mine = r["council_tax_reduction_wa_364m_pence"] / CU
        w = r["council_tax_reduction_wa_withdrawal_364m_pence"]
        expected = 0.0 if w is None else max(0.0, c["ct"] - w / CU * 364 / 365)
        theirs = p * 100
        st = step(max(c["ct"], c["pay"]))
        tol = (args.steps * st + 0.4 + (args.steps * step(3_000_000) if c["uc"] else 0)
               + (5.3 if c["childcare"] else 0))
        ok = abs(theirs - expected) <= tol
        worst = max(worst, abs(theirs - expected) / st)
        paid += mine > 0
        bad += not ok
        rows.append({**c, "lean_pence": round(mine, 4), "lean_pe_basis_pence": round(expected, 4),
                     "pe_pence": round(theirs, 4), "ok": ok})
        if not ok and bad <= 12:
            print(f"  {c}: lean {mine:.2f} (PE basis {expected:.2f}) pe {theirs:.2f}")
    print(f"Council Tax Reduction, {args.country.title()}, working age: {len(cs) - bad}/{len(cs)} agree ({paid} paid, "
          f"{sum(c['uc'] for c in cs)} on UC; worst {worst:.2f} float32 steps)")
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
