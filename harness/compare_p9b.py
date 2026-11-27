"""Compare Scotland's devolved benefits with PolicyEngine UK, 2026-27 (P9b).

* Scottish Child Payment: single parents and couples in Scotland with one to four
  children under 16, at random pay, on Universal Credit worked out by each side.
  The payment must agree to the penny. Where the two sides' UC awards sit either
  side of nil (within the float32 tolerance of compare_uc.py) the qualifying test
  can flip: those are counted as precision.
* Carer Support Payment and the Scottish Carer Supplement: carers in Scotland with
  pay and net pay pension contributions, around the £204 earnings limit and at
  random. Must agree within --steps float32 steps; a case whose weekly net earnings
  are within a penny of the limit on either side is counted as precision (as in
  compare_disability.py). PolicyEngine has no Carer Additional Person Payment
  (SSI 2023/302 reg 14B), so it is not compared (findings #41).
* Pension Age Winter Heating Payment and the charge: the households of
  compare_p9a.py, in Scotland. Must agree to the penny.

    uv run python compare_p9b.py [--binary ../.lake/build/bin/uktax] [--random 1000]
"""

from __future__ import annotations

import argparse
import csv
import pathlib
import random
import sys

import numpy as np

from compare_p9a import wfp_households, wfp_lean_cases
from compare_pension import run

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_BINARY = HERE.parent / ".lake/build/bin/uktax"
YEAR = 2026
MICRO = 1_000_000
CA_THRESHOLD = 52 * 20_401


def step(pence: float) -> float:
    return float(np.spacing(np.float32(max(pence / 100, 1.0)))) * 100


def scp(binary: pathlib.Path, rng: random.Random, n: int, steps: float, rows: list[dict]) -> int:
    from policyengine_uk import Simulation

    cs = [{"couple": rng.random() < 0.4, "kids": rng.randint(1, 4),
           "pay": rng.choice([0, rng.randint(0, 3_000_000), rng.randint(0, 8_000_000)])} for _ in range(n)]
    ln = run(binary, [{"non_savings_pence": c["pay"], "employment_pence": c["pay"], "savings_pence": 0,
                       "dividends_pence": 0, "country": "scotland",
                       "uc": {"couple": c["couple"], "children": c["kids"]},
                       "scottish_child_payment": {"children_under_16": c["kids"]}} for c in cs])
    people, bus, hhs = {}, {}, {}
    for i, c in enumerate(cs):
        members = [f"a{i}"]
        people[f"a{i}"] = {"age": {YEAR: 30}, "employment_income": {YEAR: c["pay"] / 100}}
        if c["couple"]:
            people[f"a{i}"]["marriage_allowance"] = {YEAR: 0}
            people[f"b{i}"] = {"age": {YEAR: 30}}
            members.append(f"b{i}")
        for k in range(c["kids"]):
            people[f"c{i}_{k}"] = {"age": {YEAR: rng.randint(0, 15)}, "would_claim_scp": {YEAR: True}}
            members.append(f"c{i}_{k}")
        bus[f"u{i}"] = {"members": members}
        hhs[f"h{i}"] = {"members": members, "region": {YEAR: "SCOTLAND"}}
    sim = Simulation(situation={"people": people, "benunits": bus, "households": hhs})
    pe_scp = sim.calculate("scottish_child_payment", YEAR, map_to="benunit")
    pe_uc = sim.calculate("universal_credit", YEAR)
    pe_max = sim.calculate("uc_maximum_amount", YEAR)
    bad = flips = 0
    for c, r, s, u, m in zip(cs, ln, pe_scp, pe_uc, pe_max):
        mine, theirs = r["scottish_child_payment_pence"], round(float(s) * 100, 2)
        ok = abs(mine - theirs) < 0.5
        lean_uc = r["uc_millionths_pence"] / MICRO
        if not ok and min(lean_uc, float(u) * 100) <= steps * step(max(float(m) * 100, c["pay"])):
            flips += 1
            ok = True
        bad += not ok
        rows.append({"area": "scp", "case": f"couple {c['couple']} kids {c['kids']} pay {c['pay']}",
                     "lean_pence": mine, "pe_pence": theirs, "ok": ok})
        if not ok and bad <= 10:
            print(f"  SCP {c}: lean {mine} pe {theirs} (UC lean {lean_uc:.2f} pe {float(u) * 100:.2f})")
    print(f"Scottish Child Payment: {n - bad}/{n} agree ({sum(r['lean_pence'] > 0 for r in rows if r['area'] == 'scp')} paid; "
          f"{flips} at the end of UC, precision)")
    return bad


def csp(binary: pathlib.Path, rng: random.Random, n: int, steps: float, rows: list[dict]) -> int:
    from policyengine_uk import Simulation

    cs = [(CA_THRESHOLD + k, 0) for k in (-2, -1, 0, 1)] + [(0, 0), (1_200_000, 120_000), (1_100_000, 120_000)]
    for _ in range(n):
        pay = rng.choice([rng.randint(0, 1_500_000), rng.randint(900_000, 1_250_000), rng.randint(0, 4_000_000)])
        cs.append((pay, rng.choice([0, 0, rng.randint(0, min(pay, 400_000))])))
    ln = run(binary, [{"non_savings_pence": pay, "savings_pence": 0, "dividends_pence": 0, "employment_pence": pay,
                       "net_pay_pension_pence": pen, "country": "scotland", "carer_support_payment": {},
                       "carers_allowance": {}} for pay, pen in cs])
    people, hhs = {}, {}
    for i, (pay, pen) in enumerate(cs):
        people[f"p{i}"] = {"age": {YEAR: 40}, "employment_income": {YEAR: pay / 100},
                           "employee_pension_contributions": {YEAR: pen / 100}, "care_hours": {YEAR: 35},
                           "would_claim_carers_allowance": {YEAR: True}}
        hhs[f"h{i}"] = {"members": [f"p{i}"], "region": {YEAR: "SCOTLAND"}}
    sim = Simulation(situation={"people": people, "households": hhs})
    pe = {v: [float(x) for x in sim.calculate(v, YEAR)]
          for v in ("carer_support_payment", "scottish_carer_supplement", "carers_allowance_earnings")}
    bad = boundary = 0
    for (pay, pen), r, a, b, earn in zip(cs, ln, pe["carer_support_payment"], pe["scottish_carer_supplement"],
                                         pe["carers_allowance_earnings"]):
        mine = (r["carer_support_payment_pence"], r["scottish_carer_supplement_pence"])
        theirs = (a * 100, b * 100)
        ok = all(abs(x - y) <= steps * step(max(x, 1)) for x, y in zip(mine, theirs))
        near = abs(earn * 100 - CA_THRESHOLD) < 100 or abs(r["carers_allowance_weekly_net_earnings_pence"] * 52 - CA_THRESHOLD) < 152
        if not ok and near:
            boundary += 1
            ok = True
        bad += not ok
        rows.append({"area": "csp", "case": f"pay {pay} pension {pen}", "lean_pence": mine[0] + mine[1],
                     "pe_pence": round(theirs[0] + theirs[1], 4), "ok": ok})
        if not ok and bad <= 10:
            print(f"  CSP pay {pay} pension {pen}: lean {mine} pe {theirs}")
    paid = sum(r["lean_pence"] > 0 for r in rows if r["area"] == "csp")
    print(f"Carer Support Payment and the supplement: {len(cs) - bad}/{len(cs)} agree ({paid} paid; "
          f"{boundary} at the earnings limit, precision)")
    return bad


def pawhp(binary: pathlib.Path, rng: random.Random, n: int, rows: list[dict]) -> int:
    from policyengine_uk import Simulation

    hs = wfp_households(rng, n)
    for h in hs:
        h["country"] = "scotland"
    lcases = [x for h in hs for x in wfp_lean_cases(h)]
    lres = run(binary, lcases)
    people, bus, hhs = {}, {}, {}
    k = 0
    for hi, h in enumerate(hs):
        members = []
        for ui, u in enumerate(h["units"]):
            bm = []
            for p in u:
                pid = f"p{k}"
                k += 1
                people[pid] = {"age": {YEAR: p["age"]}, "private_pension_income": {YEAR: p["income"] / 100},
                               "is_on_pension_credit": {YEAR: p["pc"]}, "is_claimant_or_partner": {YEAR: True},
                               "pension_credit_reported": {YEAR: 1_000.0 if p["pc"] else 0.0}}
                for v in ("is_on_universal_credit", "is_on_income_support", "is_on_income_based_jsa", "is_on_income_related_esa"):
                    people[pid][v] = {YEAR: False}
                bm.append(pid)
            bus[f"b{hi}_{ui}"] = {"members": bm}
            members += bm
        hhs[f"h{hi}"] = {"members": members, "region": {YEAR: "SCOTLAND"}}
    sim = Simulation(situation={"people": people, "benunits": bus, "households": hhs})
    pw = [float(x) for x in sim.calculate("pension_age_winter_heating_payment", YEAR)]
    pc_ = [float(x) for x in sim.calculate("winter_fuel_payment_charge", YEAR)]
    bad = 0
    for c, r, a, b in zip(lcases, lres, pw, pc_):
        mine = (r["pension_age_winter_heating_payment_pence"], r["winter_fuel_payment_charge_pence"])
        theirs = (round(a * 100), round(b * 100))
        ok = mine == theirs
        bad += not ok
        rows.append({"area": "pawhp", "case": str(c["winter_fuel_payment"]) + f" income {c['non_savings_pence']}",
                     "lean_pence": mine[0] + mine[1], "pe_pence": theirs[0] + theirs[1], "ok": ok})
        if not ok and bad <= 10:
            print(f"  PAWHP {c}: lean {mine} pe {theirs}")
    nw = len(lcases)
    charged = sum(1 for r in lres if r["winter_fuel_payment_charge_pence"] > 0)
    print(f"Pension Age Winter Heating Payment and charge: {nw - bad}/{nw} people agree in {len(hs)} households "
          f"({charged} charged)")
    return bad


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=2018)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_p9b.csv")
    args = ap.parse_args()
    rng = random.Random(args.seed)
    rows: list[dict] = []
    bad = scp(args.binary, rng, args.random, args.steps, rows)
    bad += csp(args.binary, rng, args.random, args.steps, rows)
    bad += pawhp(args.binary, rng, args.random, rows)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
