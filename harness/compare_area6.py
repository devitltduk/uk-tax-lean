"""Compare the area 6 reliefs with PolicyEngine UK, 2026-27: employment expenses,
capital allowances and trade losses brought forward (income tax and Class 4),
property finance costs, gifts of shares and land to charity, and the pension
annual allowance charge with its taper.

Random individuals in England and Scotland. PolicyEngine's inputs:
`employment_income`, `employment_expenses`, `self_employment_income` (the profit
before allowances), `capital_allowances`, `loss_relief`, and the same losses in
`ni_class_4_losses_brought_forward` (PolicyEngine keeps Class 4 losses separately,
since a loss set sideways for income tax still reduces Class 4 profits),
`property_income` (profit before finance costs, at least £1,000 so the property
allowance is not the better deduction) with `property_finance_costs`,
`savings_interest_income`, `dividend_income`, `charitable_investment_gifts`,
`employer_pension_contributions`, `unused_pension_annual_allowance`. Compared:
income tax (with the annual allowance charge), the charge, the annual allowance
and Class 4, within --steps float32 steps of the largest amount plus 0.4p (and,
where the allowance is tapered, £1 of allowance and 48p of charge: the reduction is
rounded down to a whole pound, and PolicyEngine's float32 adjusted income can fall
on the other side of a pound).

    uv run python compare_area6.py [--binary ../.lake/build/bin/uktax] [--random 1000]
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


def step(pence: float) -> float:
    return float(np.spacing(np.float32(max(pence / 100, 1.0)))) * 100


def pick(rng: random.Random, hi: int) -> int:
    return rng.choice([0, 0, rng.randint(0, hi)])


def random_case(rng: random.Random) -> dict:
    trade = rng.choice([0, 0, rng.randint(200_000, 15_000_000)])
    ca = rng.randint(0, trade) if trade and rng.random() < 0.5 else 0
    prop = rng.choice([0, rng.randint(100_000, 8_000_000)])
    return {"scottish": rng.random() < 0.3, "pay": rng.choice([0, rng.randint(0, 10_000_000), rng.randint(0, 45_000_000)]),
            "expenses": pick(rng, 500_000), "trade": trade, "ca": ca, "losses": pick(rng, 3_000_000),
            "property": prop, "finance": pick(rng, 3_000_000) if prop else 0, "savings": pick(rng, 2_000_000),
            "dividends": pick(rng, 3_000_000), "gifts": pick(rng, 2_000_000),
            "employer": rng.choice([0, rng.randint(0, 8_000_000), rng.randint(0, 25_000_000)]), "unused": pick(rng, 5_000_000)}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=2004)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_area6.csv")
    args = ap.parse_args()
    rng = random.Random(args.seed)
    cs = [random_case(rng) for _ in range(args.random)]
    payload = [{"non_savings_pence": 0, "savings_pence": 0, "dividends_pence": 0,
                "country": "scotland" if c["scottish"] else "england",
                "reliefs": {"pay_pence": c["pay"], "employment_expenses_pence": c["expenses"],
                            "trading_profit_pence": c["trade"], "capital_allowances_pence": c["ca"],
                            "losses_brought_forward_pence": c["losses"], "property_profit_pence": c["property"],
                            "finance_costs_pence": c["finance"], "savings_pence": c["savings"],
                            "dividends_pence": c["dividends"], "share_gifts_pence": c["gifts"],
                            "employer_pension_contributions_pence": c["employer"],
                            "unused_annual_allowance_pence": c["unused"]}} for c in cs]
    ln = run(args.binary, payload)
    from policyengine_uk import Simulation

    people, hhs = {}, {}
    for i, c in enumerate(cs):
        people[f"p{i}"] = {"age": {YEAR: 40}, "marriage_allowance": {YEAR: 0},
                           "employment_income": {YEAR: c["pay"] / 100}, "employment_expenses": {YEAR: c["expenses"] / 100},
                           "self_employment_income": {YEAR: c["trade"] / 100}, "capital_allowances": {YEAR: c["ca"] / 100},
                           "loss_relief": {YEAR: c["losses"] / 100},
                           "ni_class_4_losses_brought_forward": {YEAR: c["losses"] / 100},
                           "property_income": {YEAR: c["property"] / 100},
                           "property_finance_costs": {YEAR: c["finance"] / 100},
                           "savings_interest_income": {YEAR: c["savings"] / 100},
                           "dividend_income": {YEAR: c["dividends"] / 100},
                           "charitable_investment_gifts": {YEAR: c["gifts"] / 100},
                           "employer_pension_contributions": {YEAR: c["employer"] / 100},
                           "unused_pension_annual_allowance": {YEAR: c["unused"] / 100}}
        hhs[f"h{i}"] = {"members": [f"p{i}"], "region": {YEAR: "SCOTLAND" if c["scottish"] else "NORTH_WEST"}}
    sim = Simulation(situation={"people": people, "households": hhs})
    pe = {v: [float(x) for x in sim.calculate(v, YEAR)] for v in
          ["income_tax", "personal_pension_contributions_tax", "pension_annual_allowance", "ni_class_4"]}
    def allowance(ani: int) -> int:
        """The personal allowance, pence, on adjusted net income (ITA 2007 s35)."""
        return max(1_257_000 - max(ani - 10_000_000, 0) // 2, 0)

    def annual(net: int, employer: int) -> int:
        """The annual allowance, pence: tapered where threshold income is over £200,000
        and adjusted income over £260,000 (FA 2004 s228ZA), at least £10,000."""
        if net <= 20_000_000 or net + employer <= 26_000_000:
            return 6_000_000
        return max(6_000_000 - (net + employer - 26_000_000) // 200 * 100, 1_000_000)

    rows, bad, skipped = [], 0, 0
    for i, (c, r) in enumerate(zip(cs, ln)):
        # PolicyEngine takes the gifts at Step 3, so its net income is the law's plus the
        # gifts (findings #39). Left out only where that changes the personal allowance
        # or the annual allowance; elsewhere the two readings give the same tax.
        net = r["reliefs_net_income_pence"]
        if c["gifts"] and (allowance(net) != allowance(net + c["gifts"])
                           or annual(net, c["employer"]) != annual(net + c["gifts"], c["employer"])):
            skipped += 1
            continue
        mine = {"income_tax": r["reliefs_tax_exact_ten_thousandths_pence"] / 10_000,
                "personal_pension_contributions_tax": r["reliefs_aa_charge_ten_thousandths_pence"] / 10_000,
                "pension_annual_allowance": r["reliefs_annual_allowance_pence"],
                "ni_class_4": r["reliefs_class_4_exact_ten_thousandths_pence"] / 10_000}
        big = max(c["pay"], c["trade"], c["property"], c["savings"] + c["dividends"], c["employer"])
        tol = args.steps * step(big) + 0.4
        diffs = {k: pe[k][i] * 100 - mine[k] for k in mine}
        # A tapered allowance: the reduction is rounded down to a whole pound
        # (s228ZA(2)); PolicyEngine's float32 adjusted income can put it on the next
        # pound, so £1 of allowance and 48p of charge.
        tapered = mine["pension_annual_allowance"] < 6_000_000
        tols = {k: tol + (100 if k == "pension_annual_allowance" else 48) * tapered for k in mine}
        ok = all(abs(diffs[k]) <= tols[k] for k in mine)
        bad += not ok
        rows.append({**c, **{f"lean_{k}": round(v, 4) for k, v in mine.items()},
                     **{f"pe_{k}": round(pe[k][i] * 100, 4) for k in mine}, "ok": ok})
        if not ok and bad <= 12:
            print(f"  {c}: " + ", ".join(f"{k} lean {mine[k] / 100:,.2f} pe {pe[k][i]:,.2f}" for k in mine if abs(diffs[k]) > tol))
    n = len(rows)
    print(f"Area 6 reliefs and the annual allowance charge: {n - bad}/{n} agree "
          f"({sum(r['scottish'] for r in rows)} Scottish, {sum(r['lean_personal_pension_contributions_tax'] > 0 for r in rows)} "
          f"with a charge, {sum(r['gifts'] > 0 for r in rows)} with gifts; {skipped} where the gifts change the "
          "personal or annual allowance left out, findings #39)")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
