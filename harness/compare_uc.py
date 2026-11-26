"""Compare the model's Universal Credit with PolicyEngine UK, 2026-27.

Households: a single claimant aged 30 with 0 to 4 children (aged 5, so born
after 6 April 2017), and a couple aged 30 where one partner works, with 0 to 3
children. No housing costs, childcare, disability or capital. Pay only.

By default PolicyEngine treats a couple as married and claiming the Marriage
Allowance (`would_claim_marriage_allowance`), so the earner gets £1,260 of the
partner's allowance (£252 less tax, £138.60 more UC). The partner here has no
income and the model's UC input does not carry a Marriage Allowance election,
so for couples the harness sets PolicyEngine's `marriage_allowance` to 0 and
compares like with like. The full set of UC elements is compared in
compare_uc_full.py.

Check, for every case: UC within --steps float32 steps of the model's exact
award, at the size of the larger of the household's maximum yearly amount and
its pay (PolicyEngine works in float32), plus 55 % of the 0.32p NIC gap found by
compare.py (PolicyEngine's NIC thresholds are 4p low, so its earned income can
be 0.32p lower and its UC 0.176p higher).

    uv run python compare_uc.py
    uv run python compare_uc.py --random 2000

Exits non-zero if any check fails. Writes out/compare_uc.csv.
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
MICRO = 1_000_000  # model benefit outputs are in millionths of a penny
NIC_GAP_UC_PENCE = 0.55 * 0.08 * 4  # see the module docstring

# (couple, children)
TYPES = [(False, k) for k in range(5)] + [(True, k) for k in range(4)]


def cases(n_random: int, seed: int) -> list[tuple[bool, int, int]]:
    """(couple, children, pay in whole pence)."""
    pays = set(range(0, 6_000_001, 100_000))  # every £1,000 to £60,000
    # Around the work allowance (12 x £710 = £8,520 of earned income), the primary
    # threshold and where UC runs out for each type.
    pays |= {852_000 + d for d in (-1, 0, 1)} | {1_257_000 + d for d in (-1, 0, 1)}
    rng = random.Random(seed)
    out = [(c, k, p) for c, k in TYPES for p in sorted(pays)]
    out += [(*rng.choice(TYPES), rng.randint(0, 8_000_000)) for _ in range(n_random)]
    return out


def run_lean(binary: pathlib.Path, cs: list[tuple[bool, int, int]]) -> list[dict]:
    payload = [
        {
            "non_savings_pence": p,
            "employment_pence": p,
            "savings_pence": 0,
            "dividends_pence": 0,
            "uc": {"couple": c, "children": k},
        }
        for c, k, p in cs
    ]
    out = subprocess.run(
        [str(binary)], input=json.dumps(payload), capture_output=True, text=True, check=True
    ).stdout
    return json.loads(out)


def run_policyengine(cs: list[tuple[bool, int, int]], chunk: int = 500) -> list[dict]:
    from policyengine_uk import Simulation

    out: list[dict] = []
    for start in range(0, len(cs), chunk):
        part = cs[start : start + chunk]
        people, benunits, households = {}, {}, {}
        for i, (couple, kids, pay) in enumerate(part):
            members = [f"a{i}"]
            people[f"a{i}"] = {"age": {YEAR: 30}, "employment_income": {YEAR: pay / 100}}
            if couple:
                people[f"a{i}"]["marriage_allowance"] = {YEAR: 0}
                people[f"b{i}"] = {"age": {YEAR: 30}}
                members.append(f"b{i}")
            for k in range(kids):
                people[f"c{i}_{k}"] = {"age": {YEAR: 5}}
                members.append(f"c{i}_{k}")
            benunits[f"u{i}"] = {"members": members}
            households[f"h{i}"] = {"members": members, "region": {YEAR: "LONDON"}}
        sim = Simulation(situation={"people": people, "benunits": benunits, "households": households})
        uc = sim.calculate("universal_credit", YEAR)
        mx = sim.calculate("uc_maximum_amount", YEAR)
        for u, m in zip(uc, mx):
            out.append({"uc_pence": float(u) * 100, "max_pence": float(m) * 100})
    return out


def step_pence(pounds_: float) -> float:
    return float(np.spacing(np.float32(max(pounds_, 1.0)))) * 100


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=500)
    ap.add_argument("--seed", type=int, default=2026)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_uc.csv")
    args = ap.parse_args()

    cs = cases(args.random, args.seed)
    lean = run_lean(args.binary, cs)
    pe = run_policyengine(cs)
    rows = []
    for (couple, kids, pay), l, p in zip(cs, lean, pe):
        model = l["uc_millionths_pence"] / MICRO
        diff = p["uc_pence"] - model
        # PolicyEngine adds monthly float32 amounts up to the maximum award, so
        # its precision is that of float32 at the larger of the maximum and pay.
        step = step_pence(max(p["max_pence"], pay) / 100)
        rows.append(
            {
                "couple": couple,
                "children": kids,
                "pay_pence": pay,
                "model_uc_pence": model,
                "policyengine_uc_pence": p["uc_pence"],
                "diff_pence": round(diff, 4),
                "diff_in_steps": round(abs(diff) / step, 3),
                "ok": abs(diff) <= args.steps * step + NIC_GAP_UC_PENCE,
            }
        )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    bad = [r for r in rows if not r["ok"]]
    paid = sum(1 for r in rows if r["model_uc_pence"] > 0)
    worst = max(rows, key=lambda r: r["diff_in_steps"])
    print(
        f"{len(rows)} cases ({paid} with UC > 0): {len(rows) - len(bad)} within {args.steps:g} float32 "
        f"steps + {NIC_GAP_UC_PENCE:.3f}p, {len(bad)} beyond; max |diff| {max(abs(r['diff_pence']) for r in rows):.4f}p, "
        f"worst {worst['diff_in_steps']} steps"
    )
    for r in sorted(bad, key=lambda r: -abs(r["diff_pence"]))[:20]:
        print(f"  couple={r['couple']} children={r['children']} pay={r['pay_pence']}: model "
              f"{r['model_uc_pence']:.4f} PE {r['policyengine_uc_pence']:.4f} diff {r['diff_pence']}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
