"""Compare council tax and Council Tax Reduction for pensioners (P7) with PolicyEngine UK, 2026-27.

Council tax: every band in England, Wales (with band I) and Scotland, for random
band D amounts (PolicyEngine's `council_tax_band`, `council_tax_band_d_amount`),
one adult (the single person discount) or two. Must agree within --steps float32
steps (PolicyEngine stores the ratios to 9 decimal places).

Council Tax Reduction: pensioners in each nation, aged 70 (pensionable age after
1 April 2021) or 80, single or couples, with State Pension, private pensions,
savings or a non-dependant aged 30 in work (35 hours a week) in each band or with
no income (then on Universal Credit with no earned income, so no deduction:
England Sch 1 para 8(8)(c) and the Welsh and Scottish equivalents), and a
council tax bill (PolicyEngine's household `council_tax`). The schemes work by the
day: over the 365 days of 2026-27 the non-dependant deductions and the 20 % taper
are taken for 365/7 weeks. PolicyEngine takes 52 weeks (findings #27), so its
withdrawal is 364/365 of the law's. The check is like with like: PolicyEngine's
reduction must equal the bill less 364/365 of the model's withdrawal (within
float32 steps, the savings credit rounding of findings #22 and a penny a partner
for the tax); the gap to the law is reported.

    uv run python compare_council_tax.py [--binary ../.lake/build/bin/uktax] [--random 1000]
"""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import random
import sys

import numpy as np

from compare_pension import run, taxes

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_BINARY = HERE.parent / ".lake/build/bin/uktax"
YEAR = 2026
REGION = {"england": "NORTH_WEST", "wales": "WALES", "scotland": "SCOTLAND"}


def step(pence: float) -> float:
    return float(np.spacing(np.float32(max(pence / 100, 1.0)))) * 100


def council_tax(binary: pathlib.Path, rng: random.Random, n: int, steps: float, rows: list[dict]) -> int:
    from policyengine_uk import Simulation

    cases = []
    for nation in REGION:
        for band in "ABCDEFGHI" if nation == "wales" else "ABCDEFGH":
            for _ in range(max(1, n // 25)):
                cases.append((nation, band, rng.randint(100_000, 300_000), rng.random() < 0.5))
    people, hhs = {}, {}
    for i, (nation, band, d, single) in enumerate(cases):
        members = [f"a{i}"] + ([] if single else [f"b{i}"])
        for m in members:
            people[m] = {"age": {YEAR: 40}}
        hhs[f"h{i}"] = {"members": members, "region": {YEAR: REGION[nation]}, "council_tax_band": {YEAR: band},
                        "council_tax_band_d_amount": {YEAR: d / 100}}
    sim = Simulation(situation={"people": people, "households": hhs})
    pe = [float(x) for x in sim.calculate("simulated_council_tax_less_discounts", YEAR)]
    ln = run(binary, [{"non_savings_pence": 0, "savings_pence": 0, "dividends_pence": 0, "country": nation,
                       "council_tax": {"band": band, "band_d_pence": d, "single_person_discount": single}}
                      for nation, band, d, single in cases])
    bad = 0
    for c, r, p in zip(cases, ln, pe):
        mine, theirs = r["council_tax_1440ths_pence"] / 1440, p * 100
        ok = abs(mine - theirs) <= steps * step(mine)
        bad += not ok
        rows.append({"area": "council_tax", "case": json.dumps(c), "lean_pence": round(mine, 4),
                     "pe_pence": round(theirs, 4), "law_gap_pence": 0, "ok": ok})
        if not ok and bad <= 5:
            print(f"  council tax {c}: lean {mine:.2f} pe {theirs:.2f}")
    print(f"Council tax: {len(cases) - bad}/{len(cases)} agree")
    return bad


def ctr_case(rng: random.Random) -> dict:
    couple = rng.random() < 0.4
    person = lambda: {"sp": rng.choice([0, rng.randint(400_000, 1_300_000)]),  # noqa: E731
                      "pp": rng.choice([0, 0, rng.randint(0, 1_500_000)])}
    nondep = rng.choice([None, None, None, ("work", 52 * rng.randint(10_000, 80_000)), ("none", 0)])
    capital = rng.choice([0, 0, rng.randint(0, 2_000_000)])
    return {"nation": rng.choice(list(REGION)), "couple": couple, "age": rng.choice([70, 80]), "a": person(),
            "b": person() if couple else None, "capital": capital if nondep is None else 0, "nondep": nondep,
            "ct": rng.randint(80_000, 400_000)}


def ctr(binary: pathlib.Path, rng: random.Random, n: int, steps: float, rows: list[dict]) -> int:
    from policyengine_uk import Simulation

    cs = [ctr_case(rng) for _ in range(n)]
    base = {"couple": False, "age": 70, "b": None, "capital": 0, "nondep": None, "ct": 200_000}
    for nation in REGION:
        cs += [{**base, "nation": nation, "a": {"sp": sp, "pp": 0}} for sp in (900_000, 1_300_000, 1_400_000)]
        cs += [{**base, "nation": nation, "a": {"sp": 900_000, "pp": 0}, "nondep": ("work", 52 * w)}
               for w in (27_899, 27_900, 28_600, 60_500, 61_400)]
    tax = taxes(binary, cs)
    payload = []
    for c, t in zip(cs, tax):
        members = (c["a"], c["b"]) if c["couple"] else (c["a"],)
        o = {"council_tax_pence": c["ct"], "pensionable_age_before_april_2021": c["age"] >= 80}
        # A non-dependant with no income gets Universal Credit with no earned income, so
        # no deduction (England Sch 1 para 8(8)(c), and the Welsh and Scottish
        # equivalents): the exemptions are the caller's to apply.
        if c["nondep"] and c["nondep"][0] == "work":
            o["non_dependants"] = [{"working": True, "gross_weekly_pence": c["nondep"][1] // 52}]
        payload.append({"non_savings_pence": 0, "savings_pence": 0, "dividends_pence": 0, "country": c["nation"],
                        "pension_credit": {"couple": c["couple"], "savings_credit": c["age"] >= 80,
                                           "state_pension_pence": sum(p["sp"] for p in members),
                                           "other_pension_pence": sum(p["pp"] for p in members),
                                           "capital_pence": c["capital"], "income_tax_pence": t},
                        "council_tax_reduction": o})
    ln = run(binary, payload)
    pe: list[float] = []
    for lo in range(0, len(cs), 300):
        people, bus, hhs, units = {}, {}, {}, []
        for i, c in enumerate(cs[lo : lo + 300]):
            members = []
            for tag, p in (("a", c["a"]), ("b", c["b"])):
                if p is None:
                    continue
                people[f"{tag}{i}"] = {"age": {YEAR: c["age"]}, "state_pension": {YEAR: p["sp"] / 100},
                                       "private_pension_income": {YEAR: p["pp"] / 100},
                                       "marriage_allowance": {YEAR: 0}}
                members.append(f"{tag}{i}")
            bus[f"b{i}"] = {"members": members}
            units.append(f"b{i}")
            hh = list(members)
            if c["nondep"]:
                people[f"n{i}"] = {"age": {YEAR: 30}, "employment_income": {YEAR: c["nondep"][1] / 100},
                                   "weekly_hours": {YEAR: 35 if c["nondep"][0] == "work" else 0}}
                bus[f"bn{i}"] = {"members": [f"n{i}"]}
                hh.append(f"n{i}")
            hhs[f"h{i}"] = {"members": hh, "region": {YEAR: REGION[c["nation"]]}, "council_tax": {YEAR: c["ct"] / 100},
                            "savings": {YEAR: c["capital"] / 100}}
        sim = Simulation(situation={"people": people, "benunits": bus, "households": hhs})
        vals = dict(zip(bus, (float(x) for x in sim.calculate("council_tax_benefit", YEAR))))
        pe += [vals[u] for u in units]
    bad, paid, worst_gap = 0, 0, 0.0
    for c, r, p in zip(cs, ln, pe):
        mine = r["council_tax_reduction_7280ths_pence"] / 7280
        withdrawal = r["council_tax_reduction_withdrawal_7280ths_pence"] / 7280
        # over £16,000 of capital (and no guarantee credit) there is no reduction at all
        expected_pe = 0.0 if c["capital"] > 1_600_000 and mine == 0 else max(0.0, c["ct"] - withdrawal * 364 / 365)
        theirs = p * 100
        tol = (steps * step(max(c["ct"], theirs)) + (0.2 * 104 * 365 / 364 if c["age"] >= 80 else 0)
               + (2 if c["couple"] else 1))
        ok = abs(theirs - expected_pe) <= tol
        bad += not ok
        paid += mine > 0
        worst_gap = max(worst_gap, theirs - mine)
        rows.append({"area": "council_tax_reduction", "case": json.dumps(c), "lean_pence": round(mine, 4),
                     "pe_pence": round(theirs, 4), "law_gap_pence": round(theirs - mine, 4), "ok": ok})
        if not ok and bad <= 10:
            print(f"  CTR {c}: lean {mine:.2f} (PolicyEngine basis {expected_pe:.2f}) pe {theirs:.2f}")
    print(f"Council Tax Reduction (pensioners): {len(cs) - bad}/{len(cs)} agree on PolicyEngine's 52-week basis "
          f"({paid} paid); PolicyEngine pays up to {worst_gap / 100:.2f} a year more than the 365-day law")
    return bad


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=1992)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_council_tax.csv")
    args = ap.parse_args()
    rng = random.Random(args.seed)
    rows: list[dict] = []
    bad = council_tax(args.binary, rng, args.random, args.steps, rows)
    bad += ctr(args.binary, rng, args.random, args.steps, rows)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
