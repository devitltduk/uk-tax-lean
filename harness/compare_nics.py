"""Compare National Insurance beyond employee Class 1 (P3) with PolicyEngine UK, 2026-27.

For one person with pay, trading receipts and expenses, and benefits in kind:

1. **Employer Class 1** (SSCBA 1992 ss 9, 9A; SI 2001/1004 reg 11(3A)), on the
   annual earnings-period basis, the one PolicyEngine uses for employers; an
   employee aged 40, or aged 20 (the under-21 upper secondary threshold).
2. **Class 1A** (s10) on benefits in kind.
3. **Class 4** (s15) on trading profits after the trading allowance, with the
   reg 100 annual maximum where employee Class 1 is also payable.
4. **Class 2** (s11): whether the profits reach the small profits threshold, so
   that Class 2 is treated as paid; PolicyEngine's `ni_class_2` must be nil, as
   no Class 2 is payable as of course from 2024-25.

Each figure must agree within `--steps` float32 steps at its size. Employee
Class 1 is on the annual basis here too, so PolicyEngine's monthly thresholds
(findings #1) move it by at most 0.32p; reg 100 reads main-rate Class 1, so the
tolerance for Class 4 adds 0.32p.

    uv run python compare_nics.py [--binary ../.lake/build/bin/uktax] [--random 1000]
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


def step(pence: float) -> float:
    return float(np.spacing(np.float32(max(pence / 100, 1.0)))) * 100


def pounds(x: float) -> int:
    return round(x * 100)


def cases(n_random: int) -> list[dict]:
    out = []
    near = lambda x: [x - 1, x, x + 1]  # noqa: E731
    # employer thresholds
    for g in [0, *near(500_000), pounds(30_000), *near(5_027_000), pounds(80_000), pounds(200_000)]:
        for young in (False, True):
            out.append({"pay": g, "young": young, "r": 0, "e": 0, "bik": 0})
    # Class 4 limits, with and without employee Class 1 (reg 100 cases)
    for prof in [0, *near(1_257_000), pounds(20_000), *near(5_027_000), pounds(90_000)]:
        for g in [0, pounds(15_000), pounds(30_000), pounds(40_000), 5_027_000, pounds(70_000)]:
            out.append({"pay": g, "young": False, "r": prof + 100_000, "e": 0, "bik": 0})
    # small profits threshold
    for prof in near(710_500):
        out.append({"pay": 0, "young": False, "r": prof + 100_000, "e": 0, "bik": 0})
    # Class 1A
    for bik in (pounds(1), pounds(4_321.17), pounds(12_000)):
        out.append({"pay": pounds(40_000), "young": False, "r": 0, "e": 0, "bik": bik})
    rng = random.Random(1992)
    for _ in range(n_random):
        r = rng.choice([0, rng.randint(0, pounds(120_000))])
        out.append({"pay": rng.choice([0, rng.randint(0, pounds(150_000))]), "young": rng.random() < 0.2,
                    "r": r, "e": rng.choice([0, rng.randint(0, r)]), "bik": rng.choice([0, 0, rng.randint(0, pounds(15_000))])})
    return out


def lean(binary: pathlib.Path, cs: list[dict]) -> list[dict]:
    payload = [{"non_savings_pence": c["pay"], "savings_pence": 0, "dividends_pence": 0, "employment_pence": c["pay"],
                "employer_zero_rated": c["young"], "trading_receipts_pence": c["r"], "trading_expenses_pence": c["e"],
                "class_1a_benefits_pence": c["bik"]} for c in cs]
    out = subprocess.run([str(binary)], input=json.dumps(payload), capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def policyengine(cs: list[dict]) -> dict[str, list[float]]:
    from policyengine_uk import Simulation

    vars_ = ["ni_class_1_employer", "ni_class_1a", "ni_class_4", "ni_class_2", "ni_class_1_employee"]
    res: dict[str, list[float]] = {v: [] for v in vars_}
    for lo in range(0, len(cs), 1000):
        part = cs[lo : lo + 1000]
        people = {
            f"p{i}": {
                "age": {YEAR: 20 if c["young"] else 40},
                "employment_income": {YEAR: c["pay"] / 100},
                "self_employment_income": {YEAR: (c["r"] - c["e"]) / 100},
                "self_employment_gross_receipts": {YEAR: c["r"] / 100},
                "benefits_in_kind": {YEAR: c["bik"] / 100},
            }
            for i, c in enumerate(part)
        }
        sim = Simulation(situation={
            "people": people,
            "benunits": {f"b{i}": {"members": [f"p{i}"]} for i in range(len(part))},
            "households": {f"h{i}": {"members": [f"p{i}"], "region": {YEAR: "LONDON"}} for i in range(len(part))},
        })
        for v in vars_:
            res[v] += [float(x) for x in sim.calculate(v, YEAR)]
    return res


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--random", type=int, default=500)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_nics.csv")
    args = ap.parse_args()
    cs = cases(args.random)
    ln = lean(args.binary, cs)
    pe = policyengine(cs)
    rows, bad, worst = [], 0, {}
    checks = [
        ("employer", "ni_class_1_employer", "employer_nic_exact_ten_thousandths_pence", lambda c: c["pay"], 0.0),
        ("class 1A", "ni_class_1a", "class_1a_exact_ten_thousandths_pence", lambda c: c["bik"], 0.0),
        ("class 4", "ni_class_4", "class_4_exact_ten_thousandths_pence", lambda c: c["r"], 0.32),
    ]
    for i, (c, r) in enumerate(zip(cs, ln)):
        row = {"input": json.dumps(c)}
        ok = True
        for label, pv, lk, size, extra in checks:
            mine = r[lk] / 10_000
            theirs = pe[pv][i] * 100
            d = theirs - mine
            tol = args.steps * step(max(size(c), mine)) + extra
            good = abs(d) <= tol
            worst[label] = max(worst.get(label, 0.0), abs(d) / step(max(size(c), mine)))
            row[f"{label} lean"] = mine
            row[f"{label} pe"] = round(theirs, 4)
            ok &= good
            if not good and bad < 10:
                print(f"  {label}: {c} lean {mine:.4f} pe {theirs:.4f}")
        # Class 2: nothing payable as of course either way
        ok &= pe["ni_class_2"][i] == 0
        row["class 2 treated as paid"] = r["class_2_treated_paid"]
        row["ok"] = ok
        bad += not ok
        rows.append(row)
    print(f"NICs (employer, Class 1A, Class 4, Class 2): {len(cs) - bad}/{len(cs)} agree; worst float32 steps "
          + ", ".join(f"{k} {v:.2f}" for k, v in worst.items()))
    reg100 = sum(1 for c, r in zip(cs, ln) if r["nic_exact_ten_thousandths_pence"] > 0 and c["r"] > 0
                 and r["class_4_exact_ten_thousandths_pence"] > 0)
    print(f"  {reg100} cases with both employee Class 1 and Class 4 (reg 100 tested)")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
