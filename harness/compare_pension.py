"""Compare Pension Credit (P6) with PolicyEngine UK, 2026-27.

Single pensioners and couples aged 70 (no savings credit: pensionable age after
6 April 2016) or 80 (savings credit), with State Pension and private pension
income per person (PolicyEngine's `state_pension`, `private_pension_income`) and
capital (`pension_credit_reported_capital`). Income for Pension Credit is net of
income tax (SI 2002/1792 reg 17(10)(a)); the model is given each partner's tax on
their own income, worked out by the model.

PolicyEngine works with yearly amounts and does not round amounts A and B of the
savings credit to the penny (reg 7(4): A up, B down, to the claimant's
advantage), so with savings credit the two may differ by up to 2p a week, £1.04 a
year (findings #22). PolicyEngine also deducts the unrounded income tax, the model
the liability rounded down to the penny, so up to 1p a year per partner. The
award must agree within --steps float32 steps plus those.

    uv run python compare_pension.py [--binary ../.lake/build/bin/uktax] [--random 1000]
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
ROUNDING = 104  # pence a year: reg 7(4), a penny a week on each of A and B


def step(pence: float) -> float:
    return float(np.spacing(np.float32(max(pence / 100, 1.0)))) * 100


def run(binary: pathlib.Path, payload: list[dict]) -> list[dict]:
    out = subprocess.run([str(binary)], input=json.dumps(payload), capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def random_case(rng: random.Random) -> dict:
    couple = rng.random() < 0.4
    person = lambda: {"sp": rng.choice([0, rng.randint(400_000, 1_300_000)]),  # noqa: E731
                      "pp": rng.choice([0, 0, rng.randint(0, 1_500_000)])}
    return {"couple": couple, "age": rng.choice([70, 80]), "a": person(), "b": person() if couple else None,
            "capital": rng.choice([0, 0, rng.randint(0, 5_000_000), rng.randint(900_000, 1_200_000)])}


def edge_cases() -> list[dict]:
    base = {"couple": False, "age": 80, "b": None, "capital": 0}
    out = []
    for sp in (1_092_000, 1_150_000, 1_237_600, 1_300_000, 1_400_000):  # around the thresholds
        out.append({**base, "a": {"sp": sp, "pp": 0}})
    for cap in (1_000_000, 1_000_001, 1_050_000, 1_050_001):
        out.append({**base, "age": 70, "a": {"sp": 1_000_000, "pp": 0}, "capital": cap})
    out.append({**base, "couple": True, "a": {"sp": 1_000_000, "pp": 500_000}, "b": {"sp": 700_000, "pp": 0}})
    return out


def taxes(binary: pathlib.Path, cs: list[dict]) -> list[int]:
    people = []
    for c in cs:
        for p in (c["a"], c["b"]) if c["couple"] else (c["a"],):
            people.append({"non_savings_pence": p["sp"] + p["pp"], "savings_pence": 0, "dividends_pence": 0,
                           "country": c.get("nation", "england")})
    tax = iter(r["liability_pence"] for r in run(binary, people))
    return [next(tax) + (next(tax) if c["couple"] else 0) for c in cs]


def lean(binary: pathlib.Path, cs: list[dict], tax: list[int]) -> list[dict]:
    payload = []
    for c, t in zip(cs, tax):
        members = (c["a"], c["b"]) if c["couple"] else (c["a"],)
        payload.append({"non_savings_pence": 0, "savings_pence": 0, "dividends_pence": 0, "pension_credit": {
            "couple": c["couple"], "savings_credit": c["age"] >= 80,
            "state_pension_pence": sum(p["sp"] for p in members), "other_pension_pence": sum(p["pp"] for p in members),
            "capital_pence": c["capital"], "income_tax_pence": t}})
    return run(binary, payload)


def policyengine(cs: list[dict]) -> dict[str, list[float]]:
    from policyengine_uk import Simulation

    res: dict[str, list[float]] = {"pension_credit": [], "savings_credit": []}
    for lo in range(0, len(cs), 400):
        part = cs[lo : lo + 400]
        people, bus, hhs = {}, {}, {}
        for i, c in enumerate(part):
            members = []
            for tag, p in (("a", c["a"]), ("b", c["b"])):
                if p is None:
                    continue
                people[f"{tag}{i}"] = {"age": {YEAR: c["age"]}, "state_pension": {YEAR: p["sp"] / 100},
                                       "private_pension_income": {YEAR: p["pp"] / 100},
                                       "marriage_allowance": {YEAR: 0}}
                members.append(f"{tag}{i}")
            bus[f"b{i}"] = {"members": members, "pension_credit_reported_capital": {YEAR: c["capital"] / 100}}
            hhs[f"h{i}"] = {"members": members, "region": {YEAR: "NORTH_WEST"}}
        sim = Simulation(situation={"people": people, "benunits": bus, "households": hhs})
        for v in res:
            res[v] += [float(x) for x in sim.calculate(v, YEAR)]
    return res


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=2002)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_pension.csv")
    args = ap.parse_args()
    rng = random.Random(args.seed)
    cs = edge_cases() + [random_case(rng) for _ in range(args.random)]
    pe = policyengine(cs)
    ln = lean(args.binary, cs, taxes(args.binary, cs))
    rows, bad, paid, with_sc, worst_round = [], 0, 0, 0, 0.0
    for c, r, pc, sc in zip(cs, ln, pe["pension_credit"], pe["savings_credit"]):
        mine = r["pension_credit_tenths_pence"] / 10
        theirs = pc * 100
        tol = (args.steps * step(max(mine, theirs)) + (ROUNDING if sc > 0 or c["age"] >= 80 else 0)
               + (2 if c["couple"] else 1))
        diff = theirs - mine
        ok = abs(diff) <= tol
        if c["age"] >= 80:
            worst_round = max(worst_round, abs(diff))
        bad += not ok
        paid += mine > 0
        with_sc += sc > 0
        rows.append({**{k: v for k, v in c.items() if k not in ("a", "b")}, "a": json.dumps(c["a"]),
                     "b": json.dumps(c["b"]), "lean_pence": mine, "pe_pence": round(theirs, 4), "diff": round(diff, 4),
                     "ok": ok})
        if not ok and bad <= 10:
            print(f"  {c}: lean {mine:.2f} pe {theirs:.2f}")
    print(f"Pension Credit: {len(cs) - bad}/{len(cs)} agree ({paid} paid, {with_sc} with savings credit; largest "
          f"difference with savings credit {worst_round:.2f}p a year, the reg 7(4) rounding)")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
