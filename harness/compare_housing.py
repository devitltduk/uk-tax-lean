"""Compare Housing Benefit for pensioners (P5b) with PolicyEngine UK, 2026-27.

Social renters (no local housing allowance) aged 70 (pensionable age after
1 April 2021: the lower personal allowances, no savings credit) or 80 (the
higher allowances, savings credit), single or couples, with State Pension and
private pension per person, savings (PolicyEngine's household `savings`, which
both its Pension Credit and its Housing Benefit count as capital) and, in some
households, a working non-dependant aged 30 (35 hours a week, so in
remunerative work) with pay in each band of reg 55(2). Households with a
non-dependant have no savings: PolicyEngine shares household savings between the
benefit units in it by their adults, so the non-dependant would take part of the
pensioner's capital (a data-allocation choice; the model takes the claimant's).

The model is given each partner's income tax on their own income (reg 33(12)
disregards it), and the non-dependant's gross weekly pay.

With savings credit the Housing Benefit income includes it (reg 27(4)(a)), so
the savings credit rounding PolicyEngine leaves out (findings #22, up to £1.04 a
year) moves Housing Benefit by up to 65 % of that. Tolerance: --steps float32
steps, plus that, plus a penny a partner for the tax (PolicyEngine deducts it
unrounded).

    uv run python compare_housing.py [--binary ../.lake/build/bin/uktax] [--random 1000]
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


def step(pence: float) -> float:
    return float(np.spacing(np.float32(max(pence / 100, 1.0)))) * 100


def random_case(rng: random.Random) -> dict:
    couple = rng.random() < 0.4
    person = lambda: {"sp": rng.choice([0, rng.randint(400_000, 1_300_000)]),  # noqa: E731
                      "pp": rng.choice([0, 0, rng.randint(0, 1_500_000)])}
    nondep = rng.choice([None, None, None, 52 * rng.randint(10_000, 80_000)])
    capital = rng.choice([0, 0, rng.randint(0, 2_000_000), rng.randint(1_500_000, 1_700_000)])
    return {"couple": couple, "age": rng.choice([70, 80]), "a": person(), "b": person() if couple else None,
            "capital": capital if nondep is None else 0,
            "rent": rng.randint(5_000, 25_000),  # pence a week
            "nondep": nondep}


def edge_cases() -> list[dict]:
    base = {"couple": False, "age": 70, "b": None, "capital": 0, "rent": 10_000, "nondep": None}
    out = [{**base, "a": {"sp": sp, "pp": 0}} for sp in (900_000, 1_237_600, 1_237_700, 1_300_000, 2_000_000)]
    out += [{**base, "a": {"sp": 1_300_000, "pp": 0}, "capital": c} for c in (1_600_000, 1_600_001, 1_200_001)]
    out += [{**base, "a": {"sp": 900_000, "pp": 0}, "nondep": 52 * w} for w in (19_199, 19_200, 27_900, 60_500)]
    out.append({**base, "age": 80, "a": {"sp": 1_150_000, "pp": 150_000}})
    return out


def lean(binary: pathlib.Path, cs: list[dict], tax: list[int]) -> list[dict]:
    payload = []
    for c, t in zip(cs, tax):
        members = (c["a"], c["b"]) if c["couple"] else (c["a"],)
        hb = {"rent_weekly_pence": c["rent"], "pensionable_age_before_april_2021": c["age"] >= 80}
        if c["nondep"] is not None:
            hb["non_dependants"] = [{"working": True, "gross_weekly_pence": c["nondep"] // 52}]
        payload.append({"non_savings_pence": 0, "savings_pence": 0, "dividends_pence": 0, "pension_credit": {
            "couple": c["couple"], "savings_credit": c["age"] >= 80,
            "state_pension_pence": sum(p["sp"] for p in members), "other_pension_pence": sum(p["pp"] for p in members),
            "capital_pence": c["capital"], "income_tax_pence": t}, "housing_benefit": hb})
    return run(binary, payload)


def policyengine(cs: list[dict]) -> list[float]:
    from policyengine_uk import Simulation

    out: list[float] = []
    for lo in range(0, len(cs), 300):
        part = cs[lo : lo + 300]
        people, bus, hhs, claimant_units = {}, {}, {}, []
        for i, c in enumerate(part):
            members = []
            for tag, p in (("a", c["a"]), ("b", c["b"])):
                if p is None:
                    continue
                people[f"{tag}{i}"] = {"age": {YEAR: c["age"]}, "state_pension": {YEAR: p["sp"] / 100},
                                       "private_pension_income": {YEAR: p["pp"] / 100},
                                       "marriage_allowance": {YEAR: 0}}
                members.append(f"{tag}{i}")
            bus[f"b{i}"] = {"members": members}
            claimant_units.append(f"b{i}")
            hh = list(members)
            if c["nondep"] is not None:
                people[f"n{i}"] = {"age": {YEAR: 30}, "employment_income": {YEAR: c["nondep"] / 100},
                                   "weekly_hours": {YEAR: 35}}
                bus[f"bn{i}"] = {"members": [f"n{i}"]}
                hh.append(f"n{i}")
            hhs[f"h{i}"] = {"members": hh, "region": {YEAR: "NORTH_WEST"}, "rent": {YEAR: c["rent"] * 52 / 100},
                            "tenure_type": {YEAR: "RENT_FROM_COUNCIL"}, "savings": {YEAR: c["capital"] / 100}}
        sim = Simulation(situation={"people": people, "benunits": bus, "households": hhs})
        hb = dict(zip(bus, (float(x) for x in sim.calculate("housing_benefit", YEAR))))
        out += [hb[b] for b in claimant_units]
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=2006)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_housing.csv")
    args = ap.parse_args()
    rng = random.Random(args.seed)
    cs = edge_cases() + [random_case(rng) for _ in range(args.random)]
    pe = policyengine(cs)
    ln = lean(args.binary, cs, taxes(args.binary, cs))
    rows, bad, paid, worst = [], 0, 0, 0.0
    for c, r, hb in zip(cs, ln, pe):
        mine = r["housing_benefit_twentieths_pence"] / 20
        theirs = hb * 100
        tol = args.steps * step(max(mine, theirs)) + (0.65 * 104 if c["age"] >= 80 else 0) + (2 if c["couple"] else 1)
        diff = theirs - mine
        ok = abs(diff) <= tol
        worst = max(worst, abs(diff))
        bad += not ok
        paid += mine > 0
        rows.append({**{k: v for k, v in c.items() if k not in ("a", "b")}, "a": json.dumps(c["a"]),
                     "b": json.dumps(c["b"]), "lean_pence": round(mine, 4), "pe_pence": round(theirs, 4),
                     "diff": round(diff, 4), "ok": ok})
        if not ok and bad <= 10:
            print(f"  {c}: lean {mine:.2f} pe {theirs:.2f}")
    print(f"Housing Benefit (pension age): {len(cs) - bad}/{len(cs)} agree ({paid} paid; largest difference "
          f"{worst:.2f}p a year)")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
