"""Compare the English local Council Tax Reduction schemes for working-age
applicants (P7b) with PolicyEngine UK, 2026-27: Kingston upon Thames, Merton,
Newham, Westminster and Oxford.

Like with like only. PolicyEngine's four default-scheme councils
(`legacy_council_tax_reduction`) leave out the amounts for children, the earnings
disregards and the Child Benefit disregard of the councils' schemes (findings
#37), so households assessed on the schemes' own rules are compared only where
none of those applies: no children, no earnings (single or couple, under 25 or
not, with capital). Kingston's own-rules households are left out too: its scheme
prints £90.50, £71.70 and £142.25, PolicyEngine pays the Housing Benefit amounts
(its open issue #2881). Households on Universal Credit (any family, pay, capital)
are compared in all five: the default-scheme councils take the UC maximum amount
and the UC income plus the award × 12/52; Oxford bands the UC income and award.
Oxford's own rules count all earnings and disregard Child Benefit, as
PolicyEngine does, so its households have children and pay.

The schemes work by the day over 365 days; PolicyEngine takes 52 weeks (findings
#27), so for the default-scheme councils PolicyEngine's reduction must equal
`maxPct` % of the bill less 364/365 of the model's withdrawal, not below nil.
Oxford's has no taper. Tolerance: --steps float32 steps of the larger of the bill
and pay, plus 0.4p for the NIC thresholds (findings #1), plus on UC 2 float32 steps
of the yearly UC amounts; an Oxford income within 1p a week of a band limit may
fall in either band (float rounding).

    uv run python compare_ctr_local.py [--binary ../.lake/build/bin/uktax] [--random 1000]
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
LCU = 36_400_000_000
COUNCILS = {"kingston_upon_thames": ("KINGSTON_UPON_THAMES", "LONDON", 100),
            "merton": ("MERTON", "LONDON", 100), "newham": ("NEWHAM", "LONDON", 70),
            "westminster": ("WESTMINSTER", "LONDON", 100), "oxford": ("OXFORD", "SOUTH_EAST", 100)}
BANDS = [48_000, 53_000, 58_000, 66_000]


def step(pence: float) -> float:
    return float(np.spacing(np.float32(max(pence / 100, 1.0)))) * 100


def random_case(rng: random.Random) -> dict:
    la = rng.choice(list(COUNCILS))
    uc = rng.random() < 0.6 or la == "kingston_upon_thames"
    kind = rng.choice(["single", "single", "lone", "couple"])
    if not uc and la != "oxford":
        kind = rng.choice(["single", "couple"])
    kids = 0
    if uc or la == "oxford":
        kids = rng.choice([1, 2, 3]) if kind == "lone" else (rng.choice([0, 0, 1, 2]) if kind == "couple" else 0)
    pay = rng.choice([0, rng.randint(0, 1_500_000), rng.randint(0, 4_500_000)]) if uc or la == "oxford" else 0
    return {"la": la, "kind": kind, "young": kind == "single" and rng.random() < 0.25, "kids": kids, "pay": pay,
            "capital": rng.choice([0, 0, rng.randint(0, 1_700_000)]), "ct": rng.randint(100_000, 300_000), "uc": uc}


def edge_cases() -> list[dict]:
    out = []
    for la in COUNCILS:
        base = {"la": la, "kind": "single", "young": False, "kids": 0, "pay": 0, "capital": 0, "ct": 180_000,
                "uc": la == "kingston_upon_thames"}
        out += [{**base, "capital": c} for c in (600_000, 600_001, 1_600_000, 1_600_001)]
        out += [{**base, "uc": True, "kind": "lone", "kids": 2, "pay": p} for p in (0, 1_000_000, 2_400_000)]
    return out


def policyengine(cs: list[dict]) -> list[float]:
    from policyengine_uk import Simulation

    res: list[float] = []
    for lo in range(0, len(cs), 400):
        part = cs[lo : lo + 400]
        people, bus, hhs = {}, {}, {}
        for i, c in enumerate(part):
            authority, region, _ = COUNCILS[c["la"]]
            people[f"a{i}"] = {"age": {YEAR: 22 if c["young"] else 30}, "employment_income": {YEAR: c["pay"] / 100},
                               "marriage_allowance": {YEAR: 0}}
            members = [f"a{i}"]
            if c["kind"] == "couple":
                people[f"p{i}"] = {"age": {YEAR: 30}, "marriage_allowance": {YEAR: 0}}
                members.append(f"p{i}")
            for k in range(c["kids"]):
                people[f"c{i}_{k}"] = {"age": {YEAR: 5}}
                members.append(f"c{i}_{k}")
            bus[f"b{i}"] = {"members": members, "claims_universal_credit": {YEAR: c["uc"]}}
            hhs[f"h{i}"] = {"members": members, "region": {YEAR: region}, "local_authority": {YEAR: authority},
                            "council_tax": {YEAR: c["ct"] / 100}, "savings": {YEAR: c["capital"] / 100}}
        sim = Simulation(situation={"people": people, "benunits": bus, "households": hhs})
        res += [float(x) for x in sim.calculate("council_tax_benefit", YEAR)]
    return res


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=2886)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_ctr_local.csv")
    args = ap.parse_args()
    rng = random.Random(args.seed)
    cs = edge_cases() + [random_case(rng) for _ in range(args.random)]
    pe = policyengine(cs)
    payload = []
    for c in cs:
        ctr = {"authority": c["la"], "council_tax_pence": c["ct"], "couple": c["kind"] == "couple",
               "lone_parent": c["kind"] == "lone", "under_25": c["young"], "children": c["kids"],
               "capital_pence": c["capital"], "child_benefit_children": c["kids"]}
        x = {"non_savings_pence": c["pay"], "savings_pence": 0, "dividends_pence": 0, "employment_pence": c["pay"],
             "country": "england", "council_tax_reduction_local": ctr}
        if c["uc"]:
            x["uc"] = {"couple": c["kind"] == "couple", "children": c["kids"], "under_25": c["young"],
                       "capital_pence": c["capital"]}
        payload.append(x)
    ln = run(args.binary, payload)
    rows, bad, paid, worst, skipped = [], 0, 0, 0.0, 0
    for c, r, p in zip(cs, ln, pe):
        # Not like with like (findings #37): a default-scheme council's own rules with
        # children or earnings (PolicyEngine has no child amounts, no earnings
        # disregards, and counts Child Benefit), Merton's with tariff income
        # (PolicyEngine counts none), and Kingston's own rules (#2881). A UC claim
        # with a nil award falls to the own rules.
        own = not r["council_tax_reduction_local_uc_route"]
        if c["la"] != "oxford" and own and (c["kids"] or c["pay"] or c["la"] == "kingston_upon_thames"
                                            or c["la"] == "merton" and c["capital"] > 600_000):
            skipped += 1
            continue
        mine = r["council_tax_reduction_local_lcu_pence"] / LCU
        theirs = p * 100
        st = step(max(c["ct"], c["pay"]))
        tol = args.steps * st + 0.4 + (args.steps * step(3_000_000) if c["uc"] else 0)
        if c["la"] == "oxford":
            expected = [mine]
            wk = r["council_tax_reduction_local_income_millionths_pence"] / 52_000_000
            for b in BANDS:
                if abs(wk - b) <= 1.0 and mine > 0:
                    pcts = [100, 75, 50, 25, 0]
                    i = BANDS.index(b)
                    expected = [c["ct"] * pcts[i] / 100, c["ct"] * pcts[i + 1] / 100]
        else:
            w = r["council_tax_reduction_local_withdrawal_lcu_pence"]
            pct = COUNCILS[c["la"]][2]
            expected = [0.0 if w is None else max(0.0, c["ct"] * pct / 100 - w / LCU * 364 / 365)]
        ok = any(abs(theirs - e) <= tol for e in expected)
        worst = max(worst, min(abs(theirs - e) for e in expected) / st)
        paid += mine > 0
        bad += not ok
        rows.append({**c, "lean_pence": round(mine, 4), "lean_pe_basis_pence": round(expected[0], 4),
                     "pe_pence": round(theirs, 4), "ok": ok})
        if not ok and bad <= 20:
            print(f"  {c}: lean {mine:.2f} (PE basis {expected[0]:.2f}) pe {theirs:.2f}")
    n = len(rows)
    print(f"Council Tax Reduction, English local schemes, working age: {n - bad}/{n} agree "
          f"({paid} paid, {sum(r['uc'] for r in rows)} claiming UC; {skipped} left out as not like with like; "
          f"worst {worst:.2f} float32 steps)")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        wr = csv.DictWriter(f, fieldnames=list(rows[0]))
        wr.writeheader()
        wr.writerows(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
