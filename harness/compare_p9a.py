"""Compare student loan repayments, the Winter Fuel Payment and the winter fuel
payment charge with PolicyEngine UK, 2026-27 (P9a).

Student loans: one borrower on one plan (PolicyEngine's `student_loan_plan`
holds one), with pay, pension income, savings interest and dividends, at random
and 1p either side of each threshold; no balance (PolicyEngine caps repayments
at a balance it is given). Must agree within --steps float32 steps of the income.
PolicyEngine counts unearned income of £2,000 or less, which SI 2009/470 reg
29(4)(c) leaves out (findings #40): for those borrowers PolicyEngine must exceed the
model by exactly the known difference, the rate (9 %, 6 % for a Postgraduate loan)
on the part of the unearned income that takes the total over the threshold, within
the same tolerance. Two or more plans at once (reg 29(3A), (5A)) PolicyEngine cannot
hold; the golden cases check them.

Winter Fuel Payment: households in England and Wales of one or two pensioners
(a couple or two single people) with, sometimes, another pensioner living with
them, aged 66 to 95, some with Pension Credit paid to one member. Each person's
case for the model is worked out here from the regulations (who is entitled
under regs 2 and 4(2)(a), who they live with, a partner of 80 for reg 3(3)),
not from PolicyEngine. Pension Credit is given to PolicyEngine as an input
(`is_on_pension_credit`, with a reported award to name the payee), and every
member is a claimant or partner (`is_claimant_or_partner`: PolicyEngine otherwise
presumes a member 20 or more years younger to be the claimant's child). The payment
and the charge must agree to the penny; total incomes include £35,000 and
£35,000.01.

    uv run python compare_p9a.py [--binary ../.lake/build/bin/uktax] [--random 1000]
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
PLANS = {"plan_1": 2_690_000, "plan_2": 2_938_500, "plan_4": 3_379_500, "plan_5": 2_500_000, "postgraduate": 2_100_000}


def step(pence: float) -> float:
    return float(np.spacing(np.float32(max(pence / 100, 1.0)))) * 100


def sl_cases(rng: random.Random, n: int) -> list[dict]:
    out = []
    for plan, t in PLANS.items():
        for d in (-1, 0, 1):
            out.append({"plan": plan, "pay": t + d, "pension": 0, "savings": 0, "dividends": 0})
        for u in (200_000, 200_001):
            out.append({"plan": plan, "pay": t + 500_000, "pension": 0, "savings": u, "dividends": 0})
    for _ in range(n):
        unearned = lambda: rng.choice([0, 0, rng.randint(1, 200_000), rng.randint(200_001, 3_000_000)])  # noqa: E731
        out.append({"plan": rng.choice(list(PLANS)), "pay": rng.choice([rng.randint(0, 6_000_000), rng.randint(0, 20_000_000)]),
                    "pension": rng.choice([0, 0, rng.randint(0, 2_000_000)]), "savings": unearned(), "dividends": unearned()})
    return out


def wfp_households(rng: random.Random, n: int) -> list[dict]:
    out = []
    age = lambda: rng.choice([rng.randint(66, 79), rng.randint(80, 95), 79, 80])  # noqa: E731
    income = lambda: rng.choice([rng.randint(0, 3_000_000), rng.randint(2_000_000, 8_000_000), 3_500_000, 3_500_001])  # noqa: E731
    for _ in range(n):
        couple = rng.random() < 0.6
        units = [[{"age": age(), "income": income()} for _ in range(2 if couple else 1)]]
        if rng.random() < 0.35:  # another pensioner sharing the home: a single person, or a second couple
            units.append([{"age": age(), "income": income()} for _ in range(rng.choice([1, 1, 2]))])
        for u in units:
            # Pension Credit paid to the first member (the claimant), sometimes
            u_pc = rng.random() < 0.3
            for i, p in enumerate(u):
                p["pc"] = u_pc and i == 0
        out.append({"units": units, "country": rng.choice(["england", "wales"])})
    return out


def wfp_lean_cases(h: dict) -> list[dict]:
    """Each person's case under SI 2025/969 regs 2-4, from the household."""
    people = [(ui, p) for ui, u in enumerate(h["units"]) for p in u]
    # reg 4(2)(a): the partner of a person paid a relevant benefit (all here have
    # reached pensionable age) is not entitled
    for ui, p in people:
        u = h["units"][ui]
        p["excluded"] = any(q is not p and q["pc"] for q in u)
    cases = []
    for ui, p in people:
        others = [q for _, q in people if q is not p and not q["excluded"]]
        partner = [q for q in h["units"][ui] if q is not p]
        w = {"over_80": p["age"] >= 80, "relevant_benefit": p["pc"],
             "partner_over_80": any(q["age"] >= 80 for q in partner),
             "with_entitled_under_80": any(q["age"] < 80 for q in others),
             "with_entitled_80": any(q["age"] >= 80 for q in others),
             "partner_paid_benefit": p["excluded"]}
        cases.append({"non_savings_pence": p["income"], "savings_pence": 0, "dividends_pence": 0,
                      "country": h["country"], "winter_fuel_payment": w})
    return cases


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=2009)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_p9a.csv")
    args = ap.parse_args()
    rng = random.Random(args.seed)
    from policyengine_uk import Simulation

    # Student loans
    sl = sl_cases(rng, args.random)
    ln = run(args.binary, [{"non_savings_pence": c["pay"] + c["pension"], "employment_pence": c["pay"],
                            "savings_pence": c["savings"], "dividends_pence": c["dividends"],
                            "student_loan": {"plans": [c["plan"]]}} for c in sl])
    people, hhs = {}, {}
    for i, c in enumerate(sl):
        people[f"p{i}"] = {"age": {YEAR: 35}, "student_loan_plan": {YEAR: c["plan"].upper()},
                           "employment_income": {YEAR: c["pay"] / 100}, "private_pension_income": {YEAR: c["pension"] / 100},
                           "savings_interest_income": {YEAR: c["savings"] / 100}, "dividend_income": {YEAR: c["dividends"] / 100}}
        hhs[f"h{i}"] = {"members": [f"p{i}"], "region": {YEAR: "NORTH_WEST"}}
    pe = [float(x) for x in Simulation(situation={"people": people, "households": hhs}).calculate("student_loan_repayment", YEAR)]
    rows, bad, small, small_max = [], 0, 0, 0.0
    for c, r, v in zip(sl, ln, pe):
        mine = r["student_loan_repayment_ten_thousandths_pence"] / 10_000
        diff = v * 100 - mine
        earned, unearned = c["pay"] + c["pension"], c["savings"] + c["dividends"]
        known = 0.0
        if 0 < unearned <= 200_000:
            # PolicyEngine counts it (findings #40): the rate on what it adds above the threshold.
            t, pct = PLANS[c["plan"]], 6 if c["plan"] == "postgraduate" else 9
            known = pct * (max(earned + unearned - t, 0) - max(earned - t, 0)) / 100
            small += 1
            small_max = max(small_max, known)
        tol = args.steps * step(earned + unearned) * 0.15 + 0.01
        ok = abs(diff - known) <= tol
        bad += not ok
        rows.append({"kind": "student_loan", **c, "lean": round(mine, 4), "pe": round(v * 100, 4),
                     "known_difference": round(known, 4), "ok": ok})
        if not ok and bad <= 12:
            print(f"  {c}: lean {mine / 100:,.4f} pe {v:,.4f} (known difference {known / 100:,.4f})")
    n_sl = len(rows)
    print(f"Student loan repayments: {n_sl - bad}/{n_sl} agree ({sum(r['lean'] > 0 for r in rows)} repaying), "
          f"{small} with unearned income of £2,000 or less where PolicyEngine is higher by exactly the rate on it above "
          f"the threshold (findings #40; up to £{small_max / 100:,.2f})")

    # Winter Fuel Payment and the charge
    hs = wfp_households(rng, args.random)
    lcases = [x for h in hs for x in wfp_lean_cases(h)]
    lres = run(args.binary, lcases)
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
        hhs[f"h{hi}"] = {"members": members, "region": {YEAR: "WALES" if h["country"] == "wales" else "NORTH_WEST"}}
    sim = Simulation(situation={"people": people, "benunits": bus, "households": hhs})
    pw = [float(x) for x in sim.calculate("winter_fuel_payment", YEAR)]
    pc_ = [float(x) for x in sim.calculate("winter_fuel_payment_charge", YEAR)]
    wbad = 0
    wrows = []
    for c, r, a, b in zip(lcases, lres, pw, pc_):
        mine = (r["winter_fuel_payment_pence"], r["winter_fuel_payment_charge_pence"])
        theirs = (round(a * 100), round(b * 100))
        ok = mine == theirs
        wbad += not ok
        wrows.append({"kind": "wfp", "income": c["non_savings_pence"], **c["winter_fuel_payment"],
                      "lean": mine[0], "lean_charge": mine[1], "pe": theirs[0], "pe_charge": theirs[1], "ok": ok})
        if not ok and wbad <= 12:
            print(f"  {c}: lean {mine} pe {theirs}")
    nw = len(wrows)
    print(f"Winter Fuel Payment and charge: {nw - wbad}/{nw} people agree in {len(hs)} households "
          f"({sum(r['lean_charge'] > 0 for r in wrows)} charged, {sum(r['relevant_benefit'] for r in wrows)} on Pension Credit, "
          f"{sum(r['partner_paid_benefit'] for r in wrows)} not entitled as a claimant's partner)")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    allrows = rows + wrows
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=sorted({k for r in allrows for k in r}))
        w.writeheader()
        w.writerows(allrows)
    return 1 if bad or wbad else 0


if __name__ == "__main__":
    sys.exit(main())
