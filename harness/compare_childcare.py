"""Compare the model's funded childcare hours with PolicyEngine UK, 2026-27.

The model values the funded hours (England) at DfE's 2026-27 national average
local authority hourly funding rates by age band (£12.04 under 2, £8.90 at 2,
£6.61 at 3 and 4) for 38 weeks: the universal 15 hours a week for a 3 or
4-year-old whatever the parents earn, and the working-parent hours (30 a week
under 3, 15 more at 3 and 4) when the parent, and any partner, each expect at
least the minimum earnings and have adjusted net income not over £100,000.

PolicyEngine values them the same way (`gov.dfe.childcare_funding_rate`, the
same Table 6 rates; `weeks_per_year` 38), term by term: a child counts in a
term only once old enough at its start, at the rate for its age then. The
model takes one age band for the whole year, so each child here is born so
that it stays in one band in all three terms of 2026-27 (1 April, 1 September,
1 January) and does not start school in the year:

* under 2: born 1 March 2025 (9 months on 1 December 2025, 2 on 1 March 2027);
* 2: born 15 January 2024 (2 on 15 January 2026, 3 on 15 January 2027);
* 3: born 15 January 2023 (3 on 15 January 2026; starts school in September 2027).

Compared: the model's `funded_hours_millionths_pence` against PolicyEngine's
`extended_childcare_entitlement` (benefit unit) plus each child's
`universal_childcare_entitlement` and `targeted_childcare_entitlement`, within
--steps float32 steps a child of the value.

The 15 hours for disadvantaged 2-year-olds (`targeted_childcare_entitlement`,
SI 2014/2147: a family on Universal Credit with earned income of at most
£1,283.34 a month) are compared for lone parents, for whom the model works out
Universal Credit too, and for couples whose partner has no pay (partner 0): the model's total is `funded_hours_millionths_pence` plus
`funded_hours_targeted_millionths_pence`. A child eligible for both gets 15 + 15
hours, 30 in all (statutory guidance para A1.11). The model's Universal Credit
has no couple where both work, so for couples the targeted hours are not
compared: those cases pass when PolicyEngine's total less its targeted hours
matches the model, and are counted separately. Households: a lone parent, or a couple whose partner's pay is fixed;
pay only; England (London), and Wales for the England-only check.

    uv run python compare_childcare.py
    uv run python compare_childcare.py --random 2000

Exits non-zero if any check fails. Writes out/compare_childcare.csv.
"""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import random
import subprocess
import sys

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_BINARY = HERE.parent / ".lake/build/bin/uktax"
YEAR = 2026
MICRO = 1_000_000

BORN = {"under_2": 20250301, "2": 20240115, "3_4": 20230115}
AGE = {"under_2": 1, "2": 2, "3_4": 3}  # age on 6 October 2026
KIDS = [("under_2",), ("2",), ("3_4",), ("under_2", "3_4"), ("2", "3_4")]
MIN_EARN = 1_057_472  # 4 x £2,643.68
LIMIT = 10_000_000
# Partner's pay (= adjusted net income), or None for a lone parent.
PARTNERS = [None, 3_000_000, MIN_EARN - 1, MIN_EARN, LIMIT, LIMIT + 1]
COUNTRIES = ["england", "wales"]


def cases(n_random: int, seed: int) -> list[tuple]:
    """(country, kids, partner pay, pay in whole pence)."""
    pays = set(range(0, 15_000_001, 500_000))
    pays |= {MIN_EARN + d for d in (-1, 0, 1)} | {LIMIT + d for d in (-1, 0, 1)}
    out = [("england", k, pp, p) for k in KIDS for pp in PARTNERS for p in sorted(pays)]
    out += [("wales", k, None, p) for k in KIDS for p in (3_000_000, LIMIT)]
    rng = random.Random(seed)
    out += [
        (rng.choice(COUNTRIES), rng.choice(KIDS), rng.choice(PARTNERS), rng.randint(0, 15_000_000))
        for _ in range(n_random)
    ]
    # lone parents of a 2-year-old on Universal Credit, through the targeted hours'
    # earnings limit (net earnings £15,400.08 a year is pay of about £17,600)
    out += [("england", rng.choice([("2",), ("2", "3_4")]), None, rng.randint(0, 2_500_000))
            for _ in range(n_random // 2)]
    # couples whose partner has no pay (partner 0): on Universal Credit, no
    # working-parent hours; through the limit, pay £16,500.66 / £16,500.67
    out += [("england", rng.choice([("2",), ("2", "3_4")]), 0, rng.randint(0, 3_000_000))
            for _ in range(n_random // 2)]
    out += [("england", ("2",), 0, p) for p in (1_650_066, 1_650_067, 1_650_000, 1_650_100)]
    return out


def run_lean(binary: pathlib.Path, cs: list[tuple]) -> list[dict]:
    payload = []
    for country, kids, partner, pay in cs:
        d = {
            "non_savings_pence": pay,
            "employment_pence": pay,
            "savings_pence": 0,
            "dividends_pence": 0,
            "country": country,
            "funded_children": [{"age": k} for k in kids],
        }
        if partner == 0:
            d["uc"] = {"couple": True, "children": len(kids)}
        elif partner is not None:
            d["partner"] = {"pay_pence": partner, "adjusted_net_income_pence": partner}
        else:
            d["uc"] = {"children": len(kids)}
        payload.append(d)
    out = subprocess.run(
        [str(binary)], input=json.dumps(payload), capture_output=True, text=True, check=True
    ).stdout
    return json.loads(out)


def run_policyengine(cs: list[tuple], chunk: int = 500) -> list[tuple[float, float]]:
    """(total funded hours value, targeted part), in pounds."""
    from policyengine_uk import Simulation

    out: list[tuple[float, float]] = []
    for start in range(0, len(cs), chunk):
        part = cs[start : start + chunk]
        people, benunits, households, kids_of = {}, {}, {}, []
        for i, (country, kids, partner, pay) in enumerate(part):
            members = [f"a{i}"]
            people[f"a{i}"] = {"age": {YEAR: 30}, "employment_income": {YEAR: pay / 100}}
            if partner == 0:  # as compare_uc.py: no Marriage Allowance (findings #3)
                people[f"a{i}"]["marriage_allowance"] = {YEAR: 0}
            if partner is not None:
                people[f"b{i}"] = {"age": {YEAR: 30}, "employment_income": {YEAR: partner / 100}}
                members.append(f"b{i}")
            ks = []
            for j, k in enumerate(kids):
                people[f"c{i}_{j}"] = {"age": {YEAR: AGE[k]}, "date_of_birth": {YEAR: BORN[k]}}
                members.append(f"c{i}_{j}")
                ks.append(f"c{i}_{j}")
            kids_of.append(ks)
            region = "LONDON" if country == "england" else "WALES"
            benunits[f"u{i}"] = {"members": members}
            households[f"h{i}"] = {"members": members, "region": {YEAR: region}}
        sim = Simulation(situation={"people": people, "benunits": benunits, "households": households})
        ext = sim.calculate("extended_childcare_entitlement", YEAR)
        ids = list(people)
        uni = dict(zip(ids, sim.calculate("universal_childcare_entitlement", YEAR)))
        tgt = dict(zip(ids, sim.calculate("targeted_childcare_entitlement", YEAR)))
        for e, ks in zip(ext, kids_of):
            t = sum(float(tgt[k]) for k in ks)
            out.append((float(e) + sum(float(uni[k]) for k in ks) + t, t))
    return out


def step_pence(pounds_: float) -> float:
    return float(np.spacing(np.float32(max(pounds_, 1.0)))) * 100


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=500)
    ap.add_argument("--seed", type=int, default=2026)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_childcare.csv")
    args = ap.parse_args()

    cs = cases(args.random, args.seed)
    lean = run_lean(args.binary, cs)
    pe = run_policyengine(cs)
    rows = []
    for (country, kids, partner, pay), l, (p, t) in zip(cs, lean, pe):
        model = (l["funded_hours_millionths_pence"] + l["funded_hours_targeted_millionths_pence"]) / MICRO
        pe_pence, targeted = p * 100, t * 100
        diff = pe_pence - model
        # PolicyEngine adds float32 values per term and per programme: allow
        # --steps float32 steps per child at the size of the total.
        step = step_pence(max(model, pe_pence) / 100)
        tol = args.steps * len(kids) * step
        rows.append(
            {
                "country": country,
                "children": "+".join(kids),
                "partner_pay_pence": "" if partner is None else partner,
                "pay_pence": pay,
                "model_pence": model,
                "policyengine_pence": round(pe_pence, 4),
                "diff_pence": round(diff, 4),
                "diff_in_steps": round(abs(diff) / step, 3),
                "policyengine_targeted_pence": round(targeted, 4),
                "model_targeted_pence": l["funded_hours_targeted_millionths_pence"] / MICRO,
                "targeted_only": bool(partner) and abs(diff) > tol and abs(diff - targeted) <= tol,
                # findings #42: the law's limit is 12 x £1,283.34 = £15,400.08 a
                # year of earned income, PolicyEngine's £15,400
                "limit_window": 10_000 * 1_540_000 < l["uc_earned_income_ten_thousandths_pence"] <= 10_000 * 1_540_008,
                "ok": abs(diff) <= tol or (bool(partner) and abs(diff - targeted) <= tol),
            }
        )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    window = [r for r in rows if r["limit_window"] and not r["ok"]]
    for r in window:
        r["ok"] = True
    bad = [r for r in rows if not r["ok"]]
    working = sum(1 for r, l in zip(rows, lean) if l["childcare_eligible"] and r["country"] == "england")
    same = [r for r in rows if not r["targeted_only"] and not r["limit_window"]]
    worst = max(same, key=lambda r: r["diff_in_steps"])
    print(
        f"{len(rows)} cases ({working} with working-parent hours): "
        f"{sum(r['ok'] for r in same)} of {len(same)} within {args.steps:g} float32 steps a child "
        f"(max |diff| {max(abs(r['diff_pence']) for r in same):.4f}p, worst {worst['diff_in_steps']} steps); "
        f"{sum(r['model_targeted_pence'] > 0 for r in rows)} lone parents and one-earner couples with the targeted 2-year-old hours; "
        f"{len(window)} with earned income in (£15,400, £15,400.08] (findings #42); "
        f"{sum(r['targeted_only'] for r in rows)} couples where both work differ only by them (not compared); {len(bad)} fail"
    )
    for r in sorted(bad, key=lambda r: -abs(r["diff_pence"]))[:20]:
        print(f"  {r['country']} children={r['children']} partner={r['partner_pay_pence']} pay={r['pay_pence']}: "
              f"model {r['model_pence']:.4f} PE {r['policyengine_pence']:.4f} diff {r['diff_pence']}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
