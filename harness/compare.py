"""Compare the Lean model (the `uktax` binary) with PolicyEngine UK for 2026-27.

Generates test cases (edge cases around every threshold, plus random incomes),
runs both, and reports for each case how far PolicyEngine's income tax and
employee NICs are from the model's exact (unrounded) figures, and whether the
personal allowance, personal savings allowance and High Income Child Benefit
Charge agree.

A case is (non-savings, savings, dividends, employment, Child Benefit) in pence.
Employment is the part of non-savings income that is pay; the rest goes to
PolicyEngine as private pension income. Child Benefit is set as an input on
PolicyEngine's benefit unit, so both charge HICBC on the same amount.

NICs: PolicyEngine works out NICs per month on a twelfth of the year's pay, with
monthly thresholds of 52/12 times weekly ones stored as the annual figures over
52 (£241.73 and £966.73; its comments note the reg 10 weekly amounts are £242
and £967). That gives monthly thresholds of £1,047.50 and £4,189.16, not the
£1,048 and £4,189 of SI 2001/1004 reg 11(3)(a) and (2A)(a). Over a year of
equal months it is the annual basis with thresholds of £12,569.96 and
£50,269.96, so the model is run on the annual basis and NICs may differ by up to
8% x 4p = 0.32p (NIC_THRESHOLD_GAP_PENCE) on top of the float32 tolerance.

Scottish taxpayers are run with PolicyEngine's household in Scotland; Gift Aid is
passed as the amount given (the gross ÷ 1.25, both applying ITA 2007 s414(2)).

Pension contributions relieved at source (FA 2004 s192) are a different matter.
In law the member pays them net of 20 %, the scheme recovers the 20 % from HMRC,
and the member's own liability changes only through the raised rate limits.
PolicyEngine instead deducts the gross contribution from taxable income
(`pension_contributions_relief`), so its `income_tax` is the liability less the
relief at source. The two agree, after adding 20 % of the gross contribution to
PolicyEngine's figure, when the taxpayer is not Scottish and has taxable
non-savings income of at least the gross contribution; those cases are checked.
Outside them they differ by design (see docs/findings.md), and those cases are
not generated here.

Income tax: PolicyEngine's `income_tax` includes the High Income Child Benefit
Charge, a Step 7 amount under ITA 2007 s30(1) (inserted by FA 2012 Sch 1
para 6(3)), so the charge is taken off before comparing with the model's income
tax.

    uv run python compare.py                  # edge cases + 500 random cases
    uv run python compare.py --random 5000 --seed 7
    uv run python compare.py --steps 1        # tighter tax tolerance

Exits non-zero if any allowance differs, or if any tax differs by more than
--steps float32 steps. One exception: PolicyEngine adds incomes in float32, so
where adjusted net income is within 2 float32 steps of a £2 step of the tapered
allowance (ITA 2007 s35(3) rounds it up to a whole pound), PolicyEngine can land
on the other side of the step; then the allowances differ by £1 and the tax by
the rate on £1. Such cases are counted and reported, not failed. Writes every case to out/comparison.csv.

Tolerance: PolicyEngine holds amounts in float32, so its tax is only as precise as
float32 at the size of the incomes it adds up. One float32 step at £20,000 is
0.2p, at £100,000 0.8p, from £131,072 1.6p. The tolerance is a number of steps at
the taxpayer's total income (default 2). Over 7,198 cases (--random 5000) the
largest income tax difference seen was 1.13 steps (1.76p). NICs allow the 0.32p
gap above as well, so their worst case (0.39p) is 3.35 steps.
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
# PolicyEngine's thresholds are 4p below the annual ones (see the module docstring).
NIC_THRESHOLD_GAP_PENCE = 0.08 * 4


def pounds(p: float) -> int:
    """Pounds to pence."""
    return round(p * 100)


# (non-savings, savings, dividends, employment, Child Benefit, Scottish,
# grossed-up Gift Aid, gross pension contributions relieved at source), pence.
Case = tuple[int, int, int, int, int, bool, int, int]

# Child Benefit for a whole 2026-27, 53 weeks (£27.05 eldest, £17.90 others; findings
# #19). Passed to both sides as an input, so both charge the HICBC on the same amount.
CB_ONE = 53 * 2705
CB_TWO = 53 * (2705 + 1790)
CB_THREE = 53 * (2705 + 2 * 1790)


def edge_cases() -> list[Case]:
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
    out = {(n, s, d, n, 0, False, 0, 0) for n, s, d in cases}

    # NICs: the annual primary threshold and upper earnings limit, and the
    # weekly-basis ones (52 x £242, 52 x £967), with all non-savings income as pay.
    for t in (12_584, 50_284, 12_570, 50_270):
        for v in near(t):
            out.add((v, 0, 0, v, 0, False, 0, 0))
    # Pay plus pension: NICs on the pay only.
    out.add((pounds(40_000), 0, 0, pounds(25_000), 0, False, 0, 0))
    out.add((pounds(80_000), 0, 0, pounds(10_000), 0, False, 0, 0))

    # HICBC around 60,000, each £200 step, and 80,000, by pay and by dividends.
    for t in (60_000, 60_200, 60_400, 70_000, 79_800, 80_000):
        for v in near(t):
            for cb in (CB_ONE, CB_TWO, CB_THREE, 100_001):
                out.add((v, 0, 0, v, cb, False, 0, 0))
                out.add((pounds(50_000), 0, v - pounds(50_000), pounds(50_000), cb, False, 0, 0))

    # Scottish taxpayers: each Scottish limit (gross, with the full allowance) and
    # the UK ones, 1p either side, with savings and dividends above them (which
    # take UK rates in UK bands, and the UK test for the savings allowance).
    scot_totals = [12_570, 16_537, 29_526, 43_662, 50_270, 75_000, 100_000, 125_140]
    for t in scot_totals:
        for v in near(t):
            for s_, d_ in ((0, 0), (pounds(2_000), 0), (0, pounds(3_000)),
                           (pounds(6_000), pounds(1_000))):
                out.add((v, s_, d_, v, 0, True, 0, 0))
    for v in near(60_000):
        out.add((v, 0, 0, v, CB_TWO, True, 0, 0))

    # Gift Aid (grossed up; multiples of 5p so the amount given is whole pence):
    # it raises the limits and restores the allowance, in rUK and Scotland.
    for gift in (pounds(1_000), pounds(5_000), pounds(10_000) + 5, pounds(30_000)):
        for t in (30_000, 50_270, 60_000, 100_000, 110_000, 125_140, 150_000):
            for v in near(t + gift / 100):
                for scot in (False, True):
                    out.add((v, 0, 0, v, 0, scot, gift, 0))
                    out.add((v, pounds(1_500), pounds(2_000), v, CB_ONE, scot, gift, 0))
    # Relief at source, where PolicyEngine's deduction and the law agree: rUK,
    # taxable pay at least the gross contribution.
    for ras in (pounds(2_000), pounds(10_000), pounds(40_000)):
        for t in (50_270, 60_000, 100_000, 125_140, 140_000):
            for v in near(t + ras / 100):
                if v - pounds(12_570) >= ras:
                    out.add((v, 0, 0, v, 0, False, 0, ras))
                    out.add((v, 0, 0, v, CB_THREE, False, 0, ras))
    return sorted(out)


def random_cases(n: int, seed: int) -> list[Case]:
    """Random incomes up to £300k; about half the amounts are whole pounds.
    Four in five have all non-savings income as pay; half have Child Benefit."""
    rng = random.Random(seed)

    def amount(p_zero: float, scale: float) -> int:
        if rng.random() < p_zero:
            return 0
        pounds_ = min(300_000.0, rng.expovariate(1 / scale))
        pence = round(pounds_ * 100)
        return pence - pence % 100 if rng.random() < 0.5 else pence

    out = []
    for _ in range(n):
        ns = amount(0.1, 60_000)
        emp = ns if rng.random() < 0.8 else rng.randint(0, ns)
        cb = rng.choice([0, 0, 0, CB_ONE, CB_TWO, CB_THREE, rng.randint(0, 500_000)])
        scot = rng.random() < 0.3
        gift = 0
        if rng.random() < 0.2:
            gift = 5 * rng.randint(0, 2_000_000)  # up to £100,000, multiple of 5p
        out.append((ns, amount(0.4, 5_000), amount(0.4, 10_000), emp, cb, scot, gift, 0))
    return out


def run_lean(binary: pathlib.Path, cases: list[Case]) -> list[dict]:
    payload = [
        {
            "non_savings_pence": n,
            "savings_pence": s,
            "dividends_pence": d,
            "employment_pence": e,
            "child_benefit_pence": cb,
            "nic_earnings_period": "annual",
            "country": "scotland" if scot else "england",
            "gift_aid_gross_pence": gift,
            "pension_relief_at_source_gross_pence": ras,
        }
        for n, s, d, e, cb, scot, gift, ras in cases
    ]
    proc = subprocess.run(
        [str(binary)], input=json.dumps(payload), capture_output=True, text=True, check=True
    )
    return json.loads(proc.stdout)


def run_policyengine(cases: list[Case], chunk: int = 1_000) -> list[dict]:
    from policyengine_uk import Simulation

    out: list[dict] = []
    for start in range(0, len(cases), chunk):
        part = cases[start : start + chunk]
        people, benunits, households = {}, {}, {}
        for i, (n, s, d, e, cb, scot, gift, ras) in enumerate(part):
            people[f"p{i}"] = {
                "age": {YEAR: 40},
                "employment_income": {YEAR: e / 100},
                "private_pension_income": {YEAR: (n - e) / 100},
                "savings_interest_income": {YEAR: s / 100},
                "dividend_income": {YEAR: d / 100},
                # the amount given; PolicyEngine grosses it up at the basic rate
                "gift_aid": {YEAR: gift * 0.8 / 100},
                "personal_pension_contributions": {YEAR: ras / 100},
            }
            benunits[f"b{i}"] = {"members": [f"p{i}"], "child_benefit": {YEAR: cb / 100}}
            # PolicyEngine applies Scottish rates by region.
            region = "SCOTLAND" if scot else "LONDON"
            households[f"h{i}"] = {"members": [f"p{i}"], "region": {YEAR: region}}
        sim = Simulation(
            situation={"people": people, "benunits": benunits, "households": households}
        )
        tax = sim.calculate("income_tax", YEAR)
        pa = sim.calculate("personal_allowance", YEAR)
        psa = sim.calculate("savings_allowance", YEAR)
        nic = sim.calculate("ni_employee", YEAR)
        hicbc = sim.calculate("CB_HITC", YEAR)
        for (_, _, _, _, _, _, _, ras), t, a, b, ni, hc in zip(part, tax, pa, psa, nic, hicbc):
            out.append(
                {
                    # float32 value as computed, in pence, not rounded; plus the
                    # relief at source PolicyEngine nets into income tax
                    "tax_pence": (float(t) - float(hc)) * 100 + 0.2 * ras,
                    # allowances are whole pounds in both models
                    "personal_allowance_pence": pounds(float(a)),
                    "savings_allowance_pence": pounds(float(b)),
                    "nic_pence": float(ni) * 100,
                    # whole pounds in both (ITEPA 2003 s681C(3))
                    "hicbc_pence": pounds(float(hc)),
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
    for kind, (n, s, d, e, cb, scot, gift, ras), l, p in zip(kinds, cases, lean, pe):
        exact = l["tax_exact_ten_thousandths_pence"] / 10_000
        diff = p["tax_pence"] - exact
        step = float32_step_pence((n + s + d) / 100)
        nic_exact = l["nic_exact_ten_thousandths_pence"] / 10_000
        nic_diff = p["nic_pence"] - nic_exact
        nic_step = float32_step_pence(e / 100)
        # PolicyEngine adds incomes up in float32, so adjusted net income can be a
        # float32 step or two away from the model's. Where that straddles a £2
        # step of the tapered allowance (s35(3) round-up), the allowances differ
        # by £1 and the tax by its rate on £1; count those separately.
        ani = l["adjusted_net_income_pence"]
        to_step = min(ani % 200, 200 - ani % 200)
        pa_float = (
            abs(l["personal_allowance_pence"] - p["personal_allowance_pence"]) == 100
            and 10_000_000 < ani <= 12_514_000 + 200
            and to_step <= 2 * step
        )
        rows.append(
            {
                "kind": kind,
                "non_savings_pence": n,
                "savings_pence": s,
                "dividends_pence": d,
                "employment_pence": e,
                "child_benefit_pence": cb,
                "scottish": scot,
                "gift_aid_gross_pence": gift,
                "relief_at_source_gross_pence": ras,
                "lean_exact_pence": exact,
                "policyengine_pence": p["tax_pence"],
                "diff_pence": round(diff, 4),
                "float32_step_pence": step,
                "diff_in_steps": round(abs(diff) / step, 3),
                "tax_ok": abs(diff) <= args.steps * step or pa_float,
                "pa_float32": pa_float,
                "lean_pa_pence": l["personal_allowance_pence"],
                "policyengine_pa_pence": p["personal_allowance_pence"],
                "pa_ok": l["personal_allowance_pence"] == p["personal_allowance_pence"] or pa_float,
                "lean_psa_pence": l["savings_allowance_pence"],
                "policyengine_psa_pence": p["savings_allowance_pence"],
                "psa_ok": l["savings_allowance_pence"] == p["savings_allowance_pence"],
                "lean_nic_exact_pence": nic_exact,
                "policyengine_nic_pence": p["nic_pence"],
                "nic_diff_pence": round(nic_diff, 4),
                "nic_diff_in_steps": round(abs(nic_diff) / nic_step, 3),
                "nic_ok": abs(nic_diff) <= args.steps * nic_step + NIC_THRESHOLD_GAP_PENCE,
                "lean_hicbc_pence": l["hicbc_pence"],
                "policyengine_hicbc_pence": p["hicbc_pence"],
                "hicbc_ok": l["hicbc_pence"] == p["hicbc_pence"],
            }
        )
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)

    tax_bad = [r for r in rows if not r["tax_ok"]]
    pa_bad = [r for r in rows if not r["pa_ok"]]
    psa_bad = [r for r in rows if not r["psa_ok"]]
    plain = [r for r in rows if not r["pa_float32"]]
    worst = max(plain, key=lambda r: r["diff_in_steps"])
    print(
        f"tax: {len(rows) - len(tax_bad)} within {args.steps:g} float32 steps (or at a taper "
        f"step as below), {len(tax_bad)} beyond; elsewhere max |diff| "
        f"{max(abs(r['diff_pence']) for r in plain):.4f}p, worst {worst['diff_in_steps']} steps"
    )
    n_float = sum(r["pa_float32"] for r in rows)
    print(
        f"personal allowance: {len(rows) - len(pa_bad) - n_float} equal, {n_float} differ by £1 "
        f"where adjusted net income is within 2 float32 steps of a £2 taper step, "
        f"{len(pa_bad)} differ otherwise"
    )
    print(f"savings allowance: {len(rows) - len(psa_bad)} equal, {len(psa_bad)} differ")
    nic_bad = [r for r in rows if not r["nic_ok"]]
    hicbc_bad = [r for r in rows if not r["hicbc_ok"]]
    worst_nic = max(rows, key=lambda r: r["nic_diff_in_steps"])
    print(
        f"employee NICs: {len(rows) - len(nic_bad)} within {args.steps:g} float32 steps "
        f"+ {NIC_THRESHOLD_GAP_PENCE:.2f}p, "
        f"{len(nic_bad)} beyond; max |diff| {max(abs(r['nic_diff_pence']) for r in rows):.4f}p, "
        f"worst {worst_nic['nic_diff_in_steps']} steps"
    )
    print(f"HICBC: {len(rows) - len(hicbc_bad)} equal, {len(hicbc_bad)} differ")
    print(f"all cases in {args.out}")
    checks = ("tax_ok", "pa_ok", "psa_ok", "nic_ok", "hicbc_ok")
    bad = [r for r in rows if not all(r[c] for c in checks)]
    for r in sorted(bad, key=lambda r: -abs(r["diff_pence"]))[:30]:
        print(
            f"  {r['kind']:6} scot={r['scottish']} gift={r['gift_aid_gross_pence']} "
            f"ras={r['relief_at_source_gross_pence']} "
            f"ns={r['non_savings_pence']} sav={r['savings_pence']} "
            f"div={r['dividends_pence']}: lean={r['lean_exact_pence']} "
            f"pe={r['policyengine_pence']:.4f} diff={r['diff_pence']}p "
            f"({r['diff_in_steps']} steps), PA {r['lean_pa_pence']} vs "
            f"{r['policyengine_pa_pence']}, PSA {r['lean_psa_pence']} vs "
            f"{r['policyengine_psa_pence']}, emp={r['employment_pence']} "
            f"NIC {r['lean_nic_exact_pence']} vs {r['policyengine_nic_pence']:.4f}, "
            f"cb={r['child_benefit_pence']} HICBC {r['lean_hicbc_pence']} vs "
            f"{r['policyengine_hicbc_pence']}"
        )
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
