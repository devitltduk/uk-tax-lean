"""Compare the reliefs and allowances of P2 with PolicyEngine UK for 2026-27.

Six parts, each run through the `uktax` binary and PolicyEngine UK 2.180.2:

1. **Net pay pension contributions** (FA 2004 s193(2)): one employee with
   `employee_pension_contributions`; income tax, employee NICs (on the whole pay,
   HMRC NIM02365) and adjusted net income must agree within float32 steps.
2. **Blind person's allowance** (ITA 2007 s38): PolicyEngine does not compute it
   (`blind_persons_allowance` has no formula), so it is given £3,250; income tax
   must agree, which checks it is added to the tapered allowance, untapered.
3. **Married couple's allowance** (ss 45-46): PolicyEngine takes the allowance as
   an input (`married_couples_allowance`) and deducts 10 % of it at Step 6, up to
   the tax there is. It is given the model's tapered allowance; income tax must
   agree, which checks the taper (half the excess over £39,200, not below £4,530)
   only through the model, and the 10 % and the limit of the tax in both.
4. **Marriage Allowance** (ss 55A-55C), for married couples. The law and
   PolicyEngine split the household's tax differently, so the comparison is of
   the couple's total income tax:

   - in law the transferor's personal allowance falls by £1,260 (s55B(6)) and the
     recipient gets 20 % of £1,260, £252, off at Step 6 if both pass the rate
     tests (s55B(2)(b), (ba); s55C(1)(c), (ca));
   - PolicyEngine leaves the transferor's allowance alone and gives the
     recipient 20 % of the transferor's *unused* allowance (allowance less net
     income), up to £1,257 and rounded up to £10
     (`marriage_allowance_if_income_conditions_met`), claimed by default.

   Where the transferor's taxable income would all be charged at the basic rate
   (rUK, non-savings income only) the two give the same couple's total, apart
   from the £10 round-up. They part where the transferor's income above the
   reduced allowance is charged at 0 % (savings at the starting rate or the
   savings nil rate, dividends at the dividend nil rate: the law gives up to
   £252, PolicyEngine nothing), or at the Scottish starter rate, 19 % (the law
   gives 1 % of the part of £1,260 that is not unused, up to £12.60, more).

   So each couple is checked twice: PolicyEngine against its own stated basis,
   computed from the model's figures (`pe_basis`, the tolerance float32), and the
   law (the model) against PolicyEngine, the difference reported by cause.

5. **Trading allowance** (ITTOIA 2005 ss 783AD-783AM): receipts and expenses
   (expenses at most receipts: losses are not compared), PolicyEngine given the
   profit and the gross receipts.
6. **Property allowance and rent-a-room relief** (ss 783BD-783BH, 784-800):
   other letting receipts and expenses, and rent-a-room receipts with no expenses
   (PolicyEngine has no rent-a-room expenses and always deducts the limit).

    uv run python compare_reliefs.py [--binary ../.lake/build/bin/uktax]

Exits non-zero if PolicyEngine departs from its stated basis anywhere, or from
the model in parts 1-3, by more than --steps float32 steps.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import pathlib
import random
import subprocess
import sys

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_BINARY = HERE.parent / ".lake/build/bin/uktax"
YEAR = 2026
PA = 1_257_000
MA = 126_000  # transferable amount, pence


def pounds(x: float) -> int:
    return round(x * 100)


def step(pence: float) -> float:
    """One float32 step at this many pence, in pence."""
    return float(np.spacing(np.float32(max(pence / 100, 1.0)))) * 100


def lean(binary: pathlib.Path, payload: list[dict]) -> list[dict]:
    out = subprocess.run(
        [str(binary)], input=json.dumps(payload), capture_output=True, text=True, check=True
    ).stdout
    return json.loads(out)


def person(n: int, s: int = 0, d: int = 0, **kw) -> dict:
    return {"non_savings_pence": n, "savings_pence": s, "dividends_pence": d, "employment_pence": n, **kw}


def simulate(people: list[dict], households: list[tuple[list[str], str, bool]], variables: list[str]):
    from policyengine_uk import Simulation

    ppl, bus, hhs = {}, {}, {}
    for k, (members, region, married) in enumerate(households):
        for m in members:
            p = dict(people[int(m)])
            p["age"] = {YEAR: 40}
            if married:
                p["marital_status"] = {YEAR: "MARRIED"}
            ppl[m] = p
        bus[f"b{k}"] = {"members": [f"p{m}" for m in members]}
        hhs[f"h{k}"] = {"members": [f"p{m}" for m in members], "region": {YEAR: region}}
    # people are keyed "p<index>"
    ppl = {f"p{m}": v for m, v in ppl.items()}
    sim = Simulation(situation={"people": ppl, "benunits": bus, "households": hhs})
    return {v: sim.calculate(v, YEAR) for v in variables}


def pe_people(cases: list[dict], extra) -> list[dict]:
    out = []
    for c in cases:
        p = {
            "employment_income": {YEAR: c["employment_pence"] / 100},
            "savings_interest_income": {YEAR: c["savings_pence"] / 100},
            "dividend_income": {YEAR: c["dividends_pence"] / 100},
        }
        p.update({k: {YEAR: v} for k, v in extra(c).items()})
        out.append(p)
    return out


def singles(binary, cases, extra, chunk=1000):
    """Each case one person; returns (lean, pe) rows."""
    res = lean(binary, cases)
    pe = {"income_tax": [], "ni_employee": [], "adjusted_net_income": []}
    for a in range(0, len(cases), chunk):
        part = cases[a : a + chunk]
        hh = [([str(i)], "SCOTLAND" if c.get("country") == "scotland" else "LONDON", False) for i, c in enumerate(part)]
        r = simulate(pe_people(part, extra), hh, list(pe))
        for k in pe:
            pe[k] += [float(x) for x in r[k]]
    return res, pe


def part_singles(binary, steps, rows) -> int:
    rng = random.Random(2026)
    bad = 0
    near = lambda x: [x - 1, x, x + 1]  # noqa: E731

    # 1. net pay
    cases = []
    for pay in [pounds(x) for x in (20_000, 50_270, 60_000, 100_000, 110_000, 125_140, 150_000)]:
        for c in (pounds(1_000), pounds(5_000), pounds(10_000), pounds(25_140)):
            for g in near(pay + c):
                if c <= g:
                    cases.append(person(g, net_pay_pension_pence=c))
    for _ in range(300):
        g = rng.randint(0, pounds(200_000))
        cases.append(person(g, rng.choice([0, 0, pounds(500)]), rng.choice([0, pounds(2_000)]),
                            net_pay_pension_pence=rng.randint(0, g // 4),
                            country=rng.choice(["england", "scotland"])))
    bad += check_singles(binary, "net pay", cases,
                         lambda c: {"employee_pension_contributions": c["net_pay_pension_pence"] / 100},
                         steps, rows, nic=True)
    # 2. blind person's allowance
    cases = [person(g, blind=True) for t in (12_570, 15_820, 50_270, 53_520, 100_000, 110_000, 125_140, 131_640)
             for g in near(pounds(t))]
    cases += [person(rng.randint(0, pounds(200_000)), rng.choice([0, pounds(3_000)]), rng.choice([0, pounds(5_000)]),
                     blind=True, country=rng.choice(["england", "scotland"])) for _ in range(200)]
    bad += check_singles(binary, "blind person's allowance", cases,
                         lambda c: {"blind_persons_allowance": 3250}, steps, rows)
    # 3. married couple's allowance (the model's allowance given to PolicyEngine)
    cases = [person(g, married_couples_allowance=True) for t in (12_570, 14_000, 23_000, 39_200, 45_000, 53_540, 60_000, 100_000)
             for g in near(pounds(t))]
    cases += [person(rng.randint(0, pounds(150_000)), rng.choice([0, pounds(3_000)]),
                     married_couples_allowance=True) for _ in range(200)]
    mca = {id(c): r["mca_reduction_ten_thousandths_pence"] / 1000 / 100 for c, r in zip(cases, lean(binary, cases))}
    bad += check_singles(binary, "married couple's allowance", cases,
                         lambda c: {"married_couples_allowance": mca[id(c)]}, steps, rows)
    # 4. trading allowance (receipts and expenses; expenses at most receipts, as
    # neither side's loss relief is compared)
    cases = []
    for r in (0, 50_000, 99_999, 100_000, 100_001, 150_000, 500_000, 2_000_000):
        for e in (0, 30_000, 99_999, 100_000, 100_001, 400_000):
            if e <= r:
                for g in (pounds(20_000), pounds(60_000)):
                    cases.append(person(g, trading_receipts_pence=r, trading_expenses_pence=e))
    for _ in range(200):
        r = rng.randint(0, pounds(60_000))
        cases.append(person(rng.randint(0, pounds(120_000)), trading_receipts_pence=r,
                            trading_expenses_pence=rng.choice([0, rng.randint(0, min(r, pounds(2_000))), rng.randint(0, r)]),
                            country=rng.choice(["england", "scotland"])))
    bad += check_singles(binary, "trading allowance", cases,
                         lambda c: {"self_employment_income": (c["trading_receipts_pence"] - c["trading_expenses_pence"]) / 100,
                                    "self_employment_gross_receipts": c["trading_receipts_pence"] / 100},
                         steps, rows)
    # 5. property allowance and rent-a-room relief (PolicyEngine has no rent-a-room
    # expenses: it always deducts the limit, the s797 method, which is the law's
    # least profit when the expenses are nil)
    cases = []
    for p in (0, 99_999, 100_000, 100_001, 250_000, 1_200_000):
        for ep in (0, 50_000, 150_000):
            for q in (0, 374_999, 375_000, 375_001, 750_000, 750_001, 1_000_000):
                if ep <= p:
                    cases.append(person(pounds(30_000), property_receipts_pence=p, property_expenses_pence=ep,
                                        rent_a_room_receipts_pence=q))
    for _ in range(200):
        p = rng.choice([0, rng.randint(0, pounds(3_000)), rng.randint(0, pounds(40_000))])
        cases.append(person(rng.randint(0, pounds(120_000)), property_receipts_pence=p,
                            property_expenses_pence=rng.choice([0, rng.randint(0, p)]),
                            rent_a_room_receipts_pence=rng.choice([0, rng.randint(0, pounds(15_000))]),
                            country=rng.choice(["england", "scotland"])))
    bad += check_singles(binary, "property allowance and rent-a-room", cases,
                         lambda c: {"property_income": (c["property_receipts_pence"] - c["property_expenses_pence"]) / 100,
                                    "property_rental_income": c["property_receipts_pence"] / 100,
                                    "property_allowable_expenses": c["property_expenses_pence"] / 100,
                                    "rent_a_room_receipts": c["rent_a_room_receipts_pence"] / 100},
                         steps, rows)
    return bad


def check_singles(binary, label, cases, extra, steps, rows, nic=False) -> int:
    res, pe = singles(binary, cases, extra)
    bad = 0
    worst = 0.0
    for i, (c, r) in enumerate(zip(cases, res)):
        total = c["non_savings_pence"] + c["savings_pence"] + c["dividends_pence"] \
            + r["trading_profit_pence"] + r["property_profit_pence"]
        st = step(total)
        d_tax = pe["income_tax"][i] * 100 - r["tax_exact_ten_thousandths_pence"] / 10_000
        ok = abs(d_tax) <= steps * st
        # s35(3) round-up met at a float32 step of adjusted net income: £1 of allowance
        ani = r["adjusted_net_income_pence"]
        if not ok and 10_000_000 < ani <= 12_514_200 and min(ani % 200, 200 - ani % 200) <= 2 * st:
            ok = abs(abs(d_tax) - 100 * (0.45 if c.get("country") == "scotland" else 0.40)) < 0.1 * 100 or abs(d_tax) <= 48
        if nic:
            d_nic = pe["ni_employee"][i] * 100 - r["nic_exact_ten_thousandths_pence"] / 10_000
            ok = ok and abs(d_nic) <= steps * step(c["employment_pence"]) + 0.32
            d_ani = pe["adjusted_net_income"][i] * 100 - ani
            ok = ok and abs(d_ani) <= steps * st
        worst = max(worst, abs(d_tax) / st)
        bad += not ok
        rows.append({"part": label, "input": json.dumps(c), "lean_tax_pence": r["tax_exact_ten_thousandths_pence"] / 10_000,
                     "pe_tax_pence": round(pe["income_tax"][i] * 100, 4), "diff_pence": round(d_tax, 4), "ok": ok})
        if not ok and bad <= 10:
            print(f"  {label}: {c} lean {r['tax_exact_ten_thousandths_pence'] / 10_000} pe {pe['income_tax'][i] * 100:.4f}"
                  + (f" nic lean {r['nic_exact_ten_thousandths_pence'] / 10_000} pe {pe['ni_employee'][i] * 100:.4f}"
                     f" ani lean {ani} pe {pe['adjusted_net_income'][i] * 100:.2f}" if nic else ""))
    print(f"{label}: {len(cases) - bad}/{len(cases)} agree (worst {worst:.2f} float32 steps)")
    return bad


def couple_cases() -> list[tuple[dict, dict, str]]:
    """(recipient, transferor, region)."""
    rng = random.Random(55)
    out = []
    near = lambda x: [x - 1, x, x + 1]  # noqa: E731
    for region in ("LONDON", "SCOTLAND"):
        lim = 4_366_200 if region == "SCOTLAND" else 5_027_000
        for r in [pounds(20_000), pounds(30_000), *near(lim), pounds(60_000)]:
            for t in [0, pounds(5_000), pounds(11_310), pounds(11_505), pounds(12_000), *near(PA), pounds(13_000),
                      pounds(15_277), pounds(20_000), pounds(48_000), *near(4_901_000)]:
                out.append((person(r), person(t), region))
            # transferor with income above the allowance charged at 0 %: savings at
            # the starting rate, within the savings allowance, dividends within
            # the dividend allowance
            for t, s, d in [(pounds(5_000), pounds(10_000), 0), (pounds(12_570), pounds(1_000), 0),
                            (0, pounds(13_000), 0), (0, 0, pounds(13_000)), (pounds(10_000), 0, pounds(3_000)),
                            (pounds(12_570), 0, pounds(500))]:
                out.append((person(r), person(t, s, d), region))
        # recipient's rate test with savings or dividends near the limit
        for n, s, d in [(5_017_000, 60_000, 0), (5_017_000, 60_001, 0), (4_977_000, 0, 100_000), (4_997_000, 0, 40_000),
                        (4_000_000, 1_000_000, 0), (4_400_000, 700_000, 0), (4_520_000, 507_000, 0)]:
            out.append((person(n, s, d), person(0), region))
    for _ in range(400):
        region = rng.choice(["LONDON", "SCOTLAND"])
        r = person(rng.randint(0, pounds(80_000)), rng.choice([0, 0, rng.randint(0, pounds(6_000))]),
                   rng.choice([0, 0, rng.randint(0, pounds(4_000))]))
        t = person(rng.randint(0, pounds(25_000)), rng.choice([0, 0, rng.randint(0, pounds(12_000))]),
                   rng.choice([0, 0, rng.randint(0, pounds(4_000))]))
        out.append((r, t, region))
    return out


def part_couples(binary, steps, rows) -> int:
    cases = couple_cases()
    scot = lambda reg: "scotland" if reg == "SCOTLAND" else "england"  # noqa: E731
    # Each spouse with no Marriage Allowance, transferring, and receiving.
    payload = []
    for a, b, reg in cases:
        for x in (a, b):
            c = scot(reg)
            payload += [{**x, "country": c}, {**x, "country": c, "marriage_allowance": "transfer"},
                        {**x, "country": c, "marriage_allowance": "receive"}]
    res = lean(binary, payload)
    ex = lambda x: x["tax_exact_ten_thousandths_pence"] / 10_000  # noqa: E731

    people, hh = [], []
    for k, (a, b, reg) in enumerate(cases):
        people += [a, b]
        hh.append(([str(2 * k), str(2 * k + 1)], reg, True))
    pe = {"income_tax": []}
    for lo in range(0, len(hh), 500):
        part = hh[lo : lo + 500]
        sub = [people[int(m)] for members, _, _ in part for m in members]
        remap = [([str(2 * j), str(2 * j + 1)], reg, mar) for j, (_, reg, mar) in enumerate(part)]
        r = simulate(pe_people(sub, lambda c: {}), remap, list(pe))
        pe["income_tax"] += [float(x) for x in r["income_tax"]]

    bad = 0
    causes: dict[str, list[float]] = {}
    for k, (a, b, reg) in enumerate(cases):
        a0, a_tr, a_rec, b0, b_tr, b_rec = res[6 * k : 6 * k + 6]
        # The law: no election, or either spouse elects if their election stands
        # (s55C(1)(c)); the couple takes the least total.
        options = {"none": ex(a0) + ex(b0)}
        if b_tr["marriage_allowance_transfer_valid"]:
            options["b to a"] = ex(a_rec) + ex(b_tr)
        if a_tr["marriage_allowance_transfer_valid"]:
            options["a to b"] = ex(b_rec) + ex(a_tr)
        best = min(options, key=options.get)
        law = options[best]
        pe_hh = (pe["income_tax"][2 * k] + pe["income_tax"][2 * k + 1]) * 100

        # PolicyEngine's stated basis, from the model's figures: each spouse who
        # passes the rate test gets 20 % of the other's unused allowance (up to
        # £1,257, rounded up to £10), up to their own tax; no allowance is reduced.
        def unused(x, x0):
            return max(0, x0["personal_allowance_pence"] - (x["non_savings_pence"] + x["savings_pence"] + x["dividends_pence"]))

        def ma(rec, rec0, other, other0):
            t = math.ceil(min(unused(other, other0), PA // 10) / 1000) * 1000
            passes = rec["marriage_allowance_reduction_ten_thousandths_pence"] > 0
            return min(0.2 * t, ex(rec0)) if passes else 0.0

        basis = ex(a0) + ex(b0) - ma(a_rec, a0, b, b0) - ma(b_rec, b0, a, a0)
        st = step(max(sum(x[f] for f in ("non_savings_pence", "savings_pence", "dividends_pence")) for x in (a, b)))
        ok = abs(pe_hh - basis) <= 2 * steps * st
        bad += not ok
        gap = round(pe_hh - law, 2)
        if abs(gap) <= 2 * steps * st:
            cause = "agree"
        elif abs(gap) <= 200 + 2 * steps * st:
            cause = ("within £2: PolicyEngine rounds the unused allowance up to £10 (s55B(5) rounds only 10 % "
                     "of the s35(1) allowance), up to £1.98 more relief; or a Scottish starter-rate gap under £2")
        else:
            cause = ("transferor's income above the reduced allowance charged below 20 % (starting rate or "
                     "savings nil rate, dividend nil or ordinary rate, Scottish starter rate): the law gives "
                     "more than PolicyEngine's 20 % of the unused allowance")
        causes.setdefault(cause, []).append(gap)
        rows.append({"part": "Marriage Allowance", "input": json.dumps({"a": a, "b": b, "region": reg}),
                     "lean_tax_pence": law, "lean_choice": best, "pe_tax_pence": round(pe_hh, 4), "diff_pence": gap,
                     "pe_basis_pence": round(basis, 4), "ok": ok})
        if not ok and bad <= 10:
            print(f"  MA: {reg} a={a} b={b}: PE {pe_hh:.2f} vs its basis {basis:.2f} (law {law:.2f}, {best})")
    print(f"Marriage Allowance: PolicyEngine matches its stated basis for {len(cases) - bad}/{len(cases)} couples")
    for cause, gaps in sorted(causes.items()):
        print(f"  {cause}: {len(gaps)} couples, PolicyEngine - law {min(gaps) / 100:+.2f} to {max(gaps) / 100:+.2f} pounds")
    return bad


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_reliefs.csv")
    args = ap.parse_args()
    rows: list[dict] = []
    bad = part_singles(args.binary, args.steps, rows) + part_couples(args.binary, args.steps, rows)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=sorted({k for r in rows for k in r}))
        w.writeheader()
        w.writerows(rows)
    print(f"all cases in {args.out}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
