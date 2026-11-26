"""Compare the Lean model (the `uktax` binary) with PolicyEngine UK for 2026-27.

Generates test cases (edge cases around every threshold, plus random incomes),
runs both, and reports for each case how far PolicyEngine's tax is from the
model's exact (unrounded) tax, and whether the personal allowance and personal
savings allowance agree.

    uv run python compare.py                  # edge cases + 500 random cases
    uv run python compare.py --random 5000 --seed 7
    uv run python compare.py --steps 1        # tighter tax tolerance

Exits non-zero if any allowance differs, or if any tax differs by more than
--steps float32 steps. Writes every case to out/comparison.csv.

Tolerance: PolicyEngine holds amounts in float32, so its tax is only as precise as
float32 at the size of the incomes it adds up. One float32 step at £20,000 is
0.2p, at £100,000 0.8p, from £131,072 1.6p. The tolerance is a number of steps at
the taxpayer's total income (default 2). Over 7,046 cases the largest difference
seen was 1.02 steps (1.59p).
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
import time

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_BINARY = HERE.parent / ".lake/build/bin/uktax"
YEAR = 2026  # PolicyEngine labels the 2026-27 tax year as 2026
DEFAULT_STEPS = 2.0


def pounds(p: float) -> int:
    """Pounds to pence."""
    return round(p * 100)


def edge_cases() -> list[tuple[int, int, int]]:
    """(non-savings, savings, dividends) in pence, around every threshold.

    Thresholds on total income: personal allowance 12,570; end of starting rate
    for savings 17,570; higher rate 50,270; taper start 100,000; additional rate
    125,140. On savings: starting rate 5,000, savings allowance 1,000 / 500. On
    dividends: dividend allowance 500. Each is probed 1p below, at and 1p above,
    and odd excesses over 100,000 probe the round-up of the tapered allowance.
    """
    total_thresholds = [12_570, 17_570, 50_270, 100_000, 125_140]
    near = lambda x: [pounds(x) - 1, pounds(x), pounds(x) + 1]  # noqa: E731

    non_savings = sorted(
        {0}
        | {v for t in total_thresholds for v in near(t)}
        | {pounds(30_000), pounds(60_000), pounds(110_000), pounds(200_000)}
        | {pounds(100_000) + k for k in (2, 99, 100, 101, 199, 200, 201, 300)}
    )
    savings = sorted({0, *near(500), *near(1_000), *near(5_000), pounds(6_000), pounds(20_000)})
    dividends = sorted({0, *near(500), pounds(2_000), pounds(40_000)})
    cases = set(itertools.product(non_savings, savings, dividends))

    # Put the end of total taxable income exactly at the basic rate and higher
    # rate limits using each kind of income, where the savings allowance changes.
    for limit in (50_270, 125_140):
        for delta in (-1, 0, 1):
            top = pounds(limit) + delta
            cases.add((top - pounds(1_000), pounds(1_000), 0))
            cases.add((top - pounds(800), 0, pounds(800)))
            cases.add((top - pounds(1_500), pounds(1_000), pounds(500)))
            cases.add((0, top, 0))
            cases.add((0, 0, top))
    return sorted(cases)


def random_cases(n: int, seed: int) -> list[tuple[int, int, int]]:
    """Random incomes up to £300k; about half the amounts are whole pounds."""
    rng = random.Random(seed)

    def amount(p_zero: float, scale: float) -> int:
        if rng.random() < p_zero:
            return 0
        pounds_ = min(300_000.0, rng.expovariate(1 / scale))
        pence = round(pounds_ * 100)
        return pence - pence % 100 if rng.random() < 0.5 else pence

    return [(amount(0.1, 60_000), amount(0.4, 5_000), amount(0.4, 10_000)) for _ in range(n)]


def run_lean(binary: pathlib.Path, cases: list[tuple[int, int, int]]) -> list[dict]:
    payload = [
        {"non_savings_pence": n, "savings_pence": s, "dividends_pence": d} for n, s, d in cases
    ]
    proc = subprocess.run(
        [str(binary)], input=json.dumps(payload), capture_output=True, text=True, check=True
    )
    return json.loads(proc.stdout)


def run_policyengine(cases: list[tuple[int, int, int]], chunk: int = 1_000) -> list[dict]:
    from policyengine_uk import Simulation

    out: list[dict] = []
    for start in range(0, len(cases), chunk):
        part = cases[start : start + chunk]
        people, benunits, households = {}, {}, {}
        for i, (n, s, d) in enumerate(part):
            people[f"p{i}"] = {
                "age": {YEAR: 40},
                "employment_income": {YEAR: n / 100},
                "savings_interest_income": {YEAR: s / 100},
                "dividend_income": {YEAR: d / 100},
            }
            benunits[f"b{i}"] = {"members": [f"p{i}"]}
            # Any English region: PolicyEngine applies Scottish rates by region.
            households[f"h{i}"] = {"members": [f"p{i}"], "region": {YEAR: "LONDON"}}
        sim = Simulation(
            situation={"people": people, "benunits": benunits, "households": households}
        )
        tax = sim.calculate("income_tax", YEAR)
        pa = sim.calculate("personal_allowance", YEAR)
        psa = sim.calculate("savings_allowance", YEAR)
        for t, a, b in zip(tax, pa, psa):
            out.append(
                {
                    # float32 value as computed, in pence, not rounded
                    "tax_pence": float(t) * 100,
                    # allowances are whole pounds in both models
                    "personal_allowance_pence": pounds(float(a)),
                    "savings_allowance_pence": pounds(float(b)),
                }
            )
    return out


def float32_step_pence(pounds_: float) -> float:
    """Gap between adjacent float32 values near `pounds_`, in pence."""
    return float(np.spacing(np.float32(max(pounds_, 1.0)))) * 100


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=500, help="number of random cases")
    ap.add_argument("--seed", type=int, default=2026)
    ap.add_argument(
        "--steps",
        type=float,
        default=DEFAULT_STEPS,
        help="allowed difference, in float32 steps at the taxpayer's total income",
    )
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/comparison.csv")
    args = ap.parse_args()

    if not args.binary.exists():
        sys.exit(f"{args.binary} not found: run `lake build` first")

    edges = edge_cases()
    cases = edges + random_cases(args.random, args.seed)
    kinds = ["edge"] * len(edges) + ["random"] * (len(cases) - len(edges))
    print(f"{len(cases)} cases ({len(edges)} edge, {len(cases) - len(edges)} random)")

    t0 = time.time()
    lean = run_lean(args.binary, cases)
    t1 = time.time()
    pe = run_policyengine(cases)
    t2 = time.time()
    print(f"Lean: {t1 - t0:.1f}s, PolicyEngine: {t2 - t1:.1f}s")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    for kind, (n, s, d), l, p in zip(kinds, cases, lean, pe):
        exact = l["tax_exact_ten_thousandths_pence"] / 10_000
        diff = p["tax_pence"] - exact
        step = float32_step_pence((n + s + d) / 100)
        rows.append(
            {
                "kind": kind,
                "non_savings_pence": n,
                "savings_pence": s,
                "dividends_pence": d,
                "lean_exact_pence": exact,
                "policyengine_pence": p["tax_pence"],
                "diff_pence": round(diff, 4),
                "float32_step_pence": step,
                "diff_in_steps": round(abs(diff) / step, 3),
                "tax_ok": abs(diff) <= args.steps * step,
                "lean_pa_pence": l["personal_allowance_pence"],
                "policyengine_pa_pence": p["personal_allowance_pence"],
                "pa_ok": l["personal_allowance_pence"] == p["personal_allowance_pence"],
                "lean_psa_pence": l["savings_allowance_pence"],
                "policyengine_psa_pence": p["savings_allowance_pence"],
                "psa_ok": l["savings_allowance_pence"] == p["savings_allowance_pence"],
            }
        )
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)

    tax_bad = [r for r in rows if not r["tax_ok"]]
    pa_bad = [r for r in rows if not r["pa_ok"]]
    psa_bad = [r for r in rows if not r["psa_ok"]]
    worst = max(rows, key=lambda r: r["diff_in_steps"])
    print(
        f"tax: {len(rows) - len(tax_bad)} within {args.steps:g} float32 steps, "
        f"{len(tax_bad)} beyond; max |diff| {max(abs(r['diff_pence']) for r in rows):.4f}p, "
        f"worst {worst['diff_in_steps']} steps"
    )
    print(f"personal allowance: {len(rows) - len(pa_bad)} equal, {len(pa_bad)} differ")
    print(f"savings allowance: {len(rows) - len(psa_bad)} equal, {len(psa_bad)} differ")
    print(f"all cases in {args.out}")
    bad = [r for r in rows if not (r["tax_ok"] and r["pa_ok"] and r["psa_ok"])]
    for r in sorted(bad, key=lambda r: -abs(r["diff_pence"]))[:30]:
        print(
            f"  {r['kind']:6} ns={r['non_savings_pence']} sav={r['savings_pence']} "
            f"div={r['dividends_pence']}: lean={r['lean_exact_pence']} "
            f"pe={r['policyengine_pence']:.4f} diff={r['diff_pence']}p "
            f"({r['diff_in_steps']} steps), PA {r['lean_pa_pence']} vs "
            f"{r['policyengine_pa_pence']}, PSA {r['lean_psa_pence']} vs "
            f"{r['policyengine_psa_pence']}"
        )
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
