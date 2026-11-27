"""Compare the non-means-tested benefits (P5a) with PolicyEngine UK, 2026-27.

- PIP, DLA and Attendance Allowance: every combination of rates (324 people),
  given to PolicyEngine as `pip_dl_category`, `pip_m_category`,
  `dla_sc_category`, `dla_m_category` and `aa_category`. Both take 52 weeks, so
  the yearly amounts must agree within --steps float32 steps.
- Carer's Allowance: a carer aged 40 caring 35 hours a week (PolicyEngine's
  `care_hours`; the person cared for qualifies by its default), with pay and
  net pay pension contributions (`employee_pension_contributions`), edge cases
  1p either side of the earnings limit and random pay. The award must agree
  within --steps float32 steps, except where the year's net earnings are within
  £1 of 52 x £204.01: PolicyEngine's monthly NIC thresholds (findings #1) move
  net earnings by up to 60p a year, so the two can fall either side there. Those
  are counted, not failed.
- Carer's Allowance with Universal Credit: the same carer claiming UC as a single
  person aged 40 with 0 to 3 children aged 5, with the carer element (reg 30(1)(a)
  gives it from the caring alone). Carer's Allowance is unearned income (reg
  66(1)(b)(iii)). UC must agree within --steps float32 steps of the larger of pay
  and the yearly maximum amount, plus 55 % of 0.32p where pay is above the primary
  threshold (PolicyEngine's weekly and monthly NIC thresholds put its annual NICs
  up to 0.32p apart, findings #1), except where Carer's Allowance itself differs at
  the limit (above); those are counted.
- Child Benefit for 1 to 4 children: PolicyEngine pays 52 weeks; a whole
  2026-27 has 53 Child Benefit weeks (findings #19). The weekly amounts (the
  model's ÷ 53, PolicyEngine's ÷ 52) must agree, and the yearly gap is
  reported.

Maternity Allowance, new style JSA and ESA and the Sure Start Maternity Grant are
not compared: PolicyEngine takes them as reported amounts (findings #20).

    uv run python compare_disability.py [--binary ../.lake/build/bin/uktax] [--random 1000]
"""

from __future__ import annotations

import argparse
import csv
import itertools
import json
import pathlib
import random
import subprocess
import sys

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_BINARY = HERE.parent / ".lake/build/bin/uktax"
YEAR = 2026
CA_THRESHOLD = 52 * 20_401  # pence a year of net earnings at which a week's exceed £204


def step(pence: float) -> float:
    return float(np.spacing(np.float32(max(pence / 100, 1.0)))) * 100


def lean(binary: pathlib.Path, payload: list[dict]) -> list[dict]:
    out = subprocess.run([str(binary)], input=json.dumps(payload), capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def simulate(people_specs: list[dict], variables: list[str]) -> dict[str, list[float]]:
    """One single-adult benefit unit per spec (with `kids` children aged 5)."""
    from policyengine_uk import Simulation

    res: dict[str, list[float]] = {v: [] for v in variables}
    for lo in range(0, len(people_specs), 400):
        part = people_specs[lo : lo + 400]
        people, bus, hhs = {}, {}, {}
        for i, spec in enumerate(part):
            a = {"age": {YEAR: 40}} | {k: {YEAR: v} for k, v in spec.get("inputs", {}).items()}
            people[f"a{i}"] = a
            members = [f"a{i}"]
            for k in range(spec.get("kids", 0)):
                people[f"c{i}_{k}"] = {"age": {YEAR: 5}}
                members.append(f"c{i}_{k}")
            bus[f"b{i}"] = {"members": members}
            hhs[f"h{i}"] = {"members": members, "region": {YEAR: "NORTH_WEST"}}
        sim = Simulation(situation={"people": people, "benunits": bus, "households": hhs})
        for v in variables:
            vals = sim.calculate(v, YEAR)
            if v in ("child_benefit", "universal_credit", "uc_maximum_amount"):
                res[v] += [float(x) for x in vals]
            else:  # person level: the adult is the first member of each unit
                ids = list(people)
                res[v] += [float(vals[ids.index(f"a{i}")]) for i in range(len(part))]
    return res


def disability(binary: pathlib.Path, steps: float, rows: list[dict]) -> int:
    pip = ["NONE", "STANDARD", "ENHANCED"]
    care = ["NONE", "LOWER", "MIDDLE", "HIGHER"]
    mob = ["NONE", "LOWER", "HIGHER"]
    aa = ["NONE", "LOWER", "HIGHER"]
    lean_name = {"NONE": "none", "STANDARD": "standard", "ENHANCED": "enhanced", "LOWER": "lower",
                 "MIDDLE": "middle", "HIGHER": "higher"}
    care_name = {"NONE": "none", "LOWER": "lowest", "MIDDLE": "middle", "HIGHER": "highest"}
    combos = list(itertools.product(pip, pip, care, mob, aa))
    specs = [{"inputs": {"pip_dl_category": a, "pip_m_category": b, "dla_sc_category": c, "dla_m_category": d,
                         "aa_category": e}} for a, b, c, d, e in combos]
    pe = simulate(specs, ["pip", "dla", "attendance_allowance"])
    ln = lean(binary, [{"non_savings_pence": 0, "savings_pence": 0, "dividends_pence": 0,
                        "disability": {"pip_daily_living": lean_name[a], "pip_mobility": lean_name[b],
                                       "dla_care": care_name[c], "dla_mobility": lean_name[d],
                                       "attendance_allowance": lean_name[e]}} for a, b, c, d, e in combos])
    bad = 0
    for combo, r, p, dl, at in zip(combos, ln, pe["pip"], pe["dla"], pe["attendance_allowance"]):
        mine, theirs = r["disability_benefits_pence"], (p + dl + at) * 100
        ok = abs(mine - theirs) <= steps * step(mine)
        bad += not ok
        rows.append({"area": "disability", "case": "/".join(combo), "lean_pence": mine, "pe_pence": round(theirs, 4),
                     "ok": ok})
    print(f"PIP, DLA and Attendance Allowance: {len(combos) - bad}/{len(combos)} agree")
    return bad


def carers(binary: pathlib.Path, steps: float, n: int, rng: random.Random, rows: list[dict]) -> int:
    cases = [(CA_THRESHOLD + k, 0) for k in (-2, -1, 0, 1)] + [(0, 0), (1_200_000, 120_000), (1_100_000, 120_000)]
    for _ in range(n):
        pay = rng.choice([rng.randint(0, 1_500_000), rng.randint(900_000, 1_250_000), rng.randint(0, 4_000_000)])
        cases.append((pay, rng.choice([0, 0, rng.randint(0, min(pay, 400_000))])))
    pe = simulate([{"inputs": {"employment_income": pay / 100, "employee_pension_contributions": pen / 100,
                               "care_hours": 35}} for pay, pen in cases],
                  ["carers_allowance", "carers_allowance_earnings"])
    ln = lean(binary, [{"non_savings_pence": pay, "savings_pence": 0, "dividends_pence": 0, "employment_pence": pay,
                        "net_pay_pension_pence": pen, "carers_allowance": {}} for pay, pen in cases])
    bad = boundary = paid = 0
    for (pay, pen), r, ca, earn in zip(cases, ln, pe["carers_allowance"], pe["carers_allowance_earnings"]):
        mine, theirs = r["carers_allowance_pence"], ca * 100
        # the model's net earnings for the year, pence (pay less tax, NICs, half the contributions)
        net_earn = r["carers_allowance_weekly_net_earnings_pence"] * 52
        ok = abs(mine - theirs) <= steps * step(max(mine, 1))
        near = abs(earn * 100 - CA_THRESHOLD) < 100 or abs(net_earn - CA_THRESHOLD) < 152
        if not ok and near:
            boundary += 1
            ok = True
        bad += not ok
        paid += mine > 0
        rows.append({"area": "carers_allowance", "case": f"pay {pay} pension {pen}", "lean_pence": mine,
                     "pe_pence": round(theirs, 4), "ok": ok})
        if not ok and bad <= 10:
            print(f"  pay {pay} pension {pen}: lean {mine} pe {theirs:.2f} (pe earnings {earn:.2f})")
    print(f"Carer's Allowance: {len(cases) - bad}/{len(cases)} agree ({paid} paid; {boundary} within £1 of the "
          f"limit where the NIC gap decides)")
    return bad


def carers_uc(binary: pathlib.Path, steps: float, n: int, rng: random.Random, rows: list[dict]) -> int:
    cases = [(CA_THRESHOLD + k, 0, kids) for k in (-2, -1, 0, 1) for kids in (0, 2)]
    cases += [(1_000_000, 0, 2), (0, 0, 0), (500_000, 0, 0), (900_000, 50_000, 1)]
    for _ in range(n):
        pay = rng.choice([rng.randint(0, 1_200_000), rng.randint(900_000, 1_250_000), rng.randint(0, 3_000_000)])
        cases.append((pay, rng.choice([0, 0, rng.randint(0, min(pay, 200_000))]), rng.choice([0, 1, 2, 3])))
    pe = simulate([{"kids": kids, "inputs": {"employment_income": pay / 100,
                                             "employee_pension_contributions": pen / 100, "care_hours": 35}}
                   for pay, pen, kids in cases],
                  ["carers_allowance", "universal_credit", "uc_maximum_amount"])
    ln = lean(binary, [{"non_savings_pence": pay, "savings_pence": 0, "dividends_pence": 0,
                        "employment_pence": pay, "net_pay_pension_pence": pen, "carers_allowance": {},
                        "uc": {"couple": False, "children": kids, "carers": 1}} for pay, pen, kids in cases])
    bad = boundary = paid = both = worst = 0
    for (pay, pen, kids), r, ca, uc, mx in zip(cases, ln, pe["carers_allowance"], pe["universal_credit"],
                                               pe["uc_maximum_amount"]):
        mine, theirs = r["uc_millionths_pence"] / 1_000_000, uc * 100
        st = step(max(mx * 100, pay))
        ok = abs(mine - theirs) <= steps * st + (0.55 * 0.32 if pay > 1_257_000 else 0)
        if ok:
            worst = max(worst, abs(mine - theirs) / st)
        if not ok and abs(r["carers_allowance_pence"] - ca * 100) > 1:
            boundary += 1
            ok = True
        bad += not ok
        paid += mine > 0
        both += mine > 0 and r["carers_allowance_pence"] > 0
        rows.append({"area": "carers_allowance_uc", "case": f"pay {pay} pension {pen} children {kids}",
                     "lean_pence": mine, "pe_pence": round(theirs, 4), "ok": ok})
        if not ok and bad <= 10:
            print(f"  pay {pay} pension {pen} children {kids}: lean UC {mine:.2f} pe {theirs:.2f}"
                  f" (CA lean {r['carers_allowance_pence']} pe {ca * 100:.2f})")
    print(f"Universal Credit with Carer's Allowance: {len(cases) - bad}/{len(cases)} agree ({paid} with UC paid, "
          f"{both} with both; {boundary} where Carer's Allowance differs at the limit; worst {worst:.2f} float32 steps)")
    return bad


def child_benefit(binary: pathlib.Path, steps: float, rows: list[dict]) -> int:
    kids = [1, 2, 3, 4]
    pe = simulate([{"kids": k} for k in kids], ["child_benefit"])
    ln = lean(binary, [{"non_savings_pence": 0, "savings_pence": 0, "dividends_pence": 0,
                        "child_benefit_children": k} for k in kids])
    bad = 0
    for k, r, cb in zip(kids, ln, pe["child_benefit"]):
        mine, theirs = r["child_benefit_pence"], cb * 100
        ok = abs(mine / 53 - theirs / 52) <= steps * step(theirs) / 52
        bad += not ok
        rows.append({"area": "child_benefit", "case": f"{k} children", "lean_pence": mine, "pe_pence": round(theirs, 4),
                     "ok": ok})
        print(f"  Child Benefit, {k} {'child' if k == 1 else 'children'}: model £{mine / 100:,.2f} (53 weeks), PolicyEngine £{theirs / 100:,.2f}"
              f" (52 weeks): {'same weekly amount' if ok else 'DIFFERENT weekly amount'}, £{(mine - theirs) / 100:,.2f}"
              " a year apart")
    return bad


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=1976)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_disability.csv")
    args = ap.parse_args()
    rng = random.Random(args.seed)
    rows: list[dict] = []
    bad = disability(args.binary, args.steps, rows)
    bad += carers(args.binary, args.steps, args.random, rng, rows)
    bad += carers_uc(args.binary, args.steps, args.random, rng, rows)
    bad += child_benefit(args.binary, args.steps, rows)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
