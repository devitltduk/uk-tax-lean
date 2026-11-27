"""Map where earning more lowers net income, for a few household types (2026-27).

Net income = gross income - income tax - employee NICs - High Income Child
Benefit Charge + Child Benefit + the better of Universal Credit and Tax-Free
Childcare + funded hours (valued at DfE's national average funding rates): the `netAll` of UkTax/Benefits.lean, exact, in
1/1 000 000 of a penny, read from the `uktax` binary. Pay varies; each
household's savings, dividends, Child Benefit and claims are fixed; NICs on the
annual basis.

Completeness comes from the Lean theorem `netAll_drop_only_at_steps`: one more
penny of pay can lower net income only at a step of the personal allowance
(total income reaching a multiple of £2 in (£100,000, £125,140]), of the HICBC
(a multiple of £200 in [£60,200, £80,000], with Child Benefit), of the personal
savings allowance (Step 3 income at £37,700 or £125,140), where a Marriage
Allowance recipient fails the rate test, or where adjusted net income goes over
£100,000 (Tax-Free Childcare and funded hours). For a recipient with pay only the
rate test is Step 3 income at most £37,700, or £31,092 for a Scottish taxpayer
(`maOk_payOnly`), so that step is one penny, found like the savings allowance's. This script
lists every such penny, so it checks every place a drop can happen and finds
the drops exactly; it samples nothing. Between steps net income never falls
(`netAll_between_steps`), which is what makes the recovery search below exact.

For each drop it reports the size, and the "trap": the pay range above the step
where net income is below what it was just before the step, i.e. where earning
less would leave the household better off.

    python3 harness/cliffs.py                    # writes docs/cliffs.md, docs/net.csv, docs/rates.csv
                                                 # and harness/out/chart-data.json for charts.py
    python3 harness/cliffs.py --check-only       # seed checks only

Stdlib only. Exits non-zero if a seed check fails.
"""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import subprocess
import sys
from dataclasses import dataclass

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
DEFAULT_BINARY = ROOT / ".lake/build/bin/uktax"
UNIT = 1_000_000  # net income is in 1/1 000 000 of a penny
MAX_PAY = 20_000_000  # £200,000: above £125,140 + savings + dividends there are no steps

BRL = 3_770_000
HRL = 12_514_000

# Child Benefit for a whole 2026-27, 53 weeks (Child Benefit weeks begin on a Monday,
# SSCBA 1992 s147(1), and 2026-27 has 53 Mondays): £27.05 eldest, £17.90 each other
# child (SI 2006/965 reg 2(1), SI 2026/232). As `childBenefitFor n childBenefitWeeks`.
CB = {0: 0, 1: 53 * 2705, 2: 53 * (2705 + 1790), 3: 53 * (2705 + 2 * 1790)}


@dataclass(frozen=True)
class Household:
    key: str
    label: str
    savings: int = 0
    dividends: int = 0
    children: int = 0
    uc: bool = False
    childcare_costs: tuple[int, ...] = ()
    funded_children: tuple[str, ...] = ()  # age bands: "under_2", "2", "3_4"
    partner_pay: int | None = None  # a working partner (pay = adjusted net income), fixed
    country: str = "england"
    marriage_allowance: str | None = None  # "receive": the spouse has elected to transfer
    # Pupils for free school lunches: (value of the lunches 6 April-16 August 2026,
    # 17 August 2026-5 April 2027, pence; in reception to year 2).
    meals: tuple[tuple[int, int, bool], ...] = ()

    @property
    def cb(self) -> int:
        return CB[self.children]


# Childcare costs for Tax-Free Childcare are an illustrative assumption: £10,000 a
# year per child, enough to reach the £2,000 top-up cap (20 % of £10,000).
CHILDCARE = 1_000_000

# Free school lunches valued at DfE's 2026-27 universal infant meal rate, £2.66 a
# meal ("UIFSM: conditions of grant 2026 to 2027"), an illustrative value (a meal
# has none in law): 65 school days from 6 April to 16 August 2026 and 125 from 17
# August 2026 to 5 April 2027, a typical English term calendar with 190 in the
# school year, DfE's assumption.
MEAL = 266
PUPIL = (65 * MEAL, 125 * MEAL, False)

BRL_SCOT_INTERMEDIATE = 3_109_200  # top of the Scottish intermediate rate, Step 3 income

HOUSEHOLDS = [
    Household("single", "Single, pay only"),
    Household("one_child", "Pay only, 1 child", children=1),
    Household("three_children", "Pay only, 3 children", children=3),
    Household("savings", "Pay + £2,000 savings interest", savings=200_000),
    Household(
        "mixed",
        "Pay + £2,000 interest + £10,000 dividends, 2 children",
        savings=200_000,
        dividends=1_000_000,
        children=2,
    ),
    Household("uc_single", "Single, Universal Credit", uc=True),
    Household(
        "uc_one_child",
        "Lone parent, 1 child aged 2: UC (no childcare element) or Tax-Free Childcare, funded hours",
        children=1,
        uc=True,
        childcare_costs=(CHILDCARE,),
        funded_children=("2",),
    ),
    Household(
        "uc_two_children",
        "Lone parent, 2 children aged 1 and 3: UC (no childcare element) or Tax-Free Childcare, funded hours",
        children=2,
        uc=True,
        childcare_costs=(CHILDCARE, CHILDCARE),
        funded_children=("under_2", "3_4"),
    ),
    Household(
        "uc_school_meals",
        "Lone parent, 2 children at school (years 3 to 11): UC, free school lunches",
        children=2,
        uc=True,
        meals=(PUPIL, PUPIL),
    ),
    Household(
        "couple_child_3",
        "Couple, partner earns £40,000, 1 child aged 3: Tax-Free Childcare, funded hours",
        children=1,
        childcare_costs=(CHILDCARE,),
        funded_children=("3_4",),
        partner_pay=4_000_000,
    ),
    Household(
        "ma_receive",
        "Married, spouse has no income and gives the Marriage Allowance",
        marriage_allowance="receive",
    ),
    Household(
        "ma_receive_scotland",
        "Married in Scotland, spouse has no income and gives the Marriage Allowance",
        marriage_allowance="receive",
        country="scotland",
    ),
]


class Model:
    """Exact net income from the uktax binary, with a cache."""

    def __init__(self, binary: pathlib.Path, h: Household):
        self.binary = binary
        self.h = h
        self.cache: dict[int, dict] = {}

    def fetch(self, pays: list[int]) -> None:
        todo = sorted({g for g in pays if g not in self.cache})
        if not todo:
            return
        payload = [self.payload(g) for g in todo]
        out = subprocess.run(
            [str(self.binary)], input=json.dumps(payload), capture_output=True, text=True, check=True
        ).stdout
        for g, r in zip(todo, json.loads(out)):
            self.cache[g] = r

    def payload(self, g: int) -> dict:
        base = {
            "savings_pence": self.h.savings,
            "dividends_pence": self.h.dividends,
            "child_benefit_pence": self.h.cb,
            "childcare_costs_pence": list(self.h.childcare_costs),
            "country": self.h.country,
        }
        if self.h.marriage_allowance:
            base["marriage_allowance"] = self.h.marriage_allowance
        if self.h.uc:
            base["uc"] = {"couple": False, "children": self.h.children}
        if self.h.funded_children:
            base["funded_children"] = [{"age": a} for a in self.h.funded_children]
        if self.h.meals:
            base["school_meals"] = {"pupils": [
                {"value_before_pence": b, "value_after_pence": a, "infant": i} for b, a, i in self.h.meals]}
        if self.h.partner_pay is not None:
            base["partner"] = {"pay_pence": self.h.partner_pay, "adjusted_net_income_pence": self.h.partner_pay}
        return {"non_savings_pence": g, "employment_pence": g, **base}

    def net(self, g: int) -> int:
        self.fetch([g])
        key = "net_income_with_meals_millionths_pence" if self.h.meals else "net_income_millionths_pence"
        return self.cache[g][key]

    def meal_pennies(self) -> list[int]:
        """The pennies where free lunches are lost, from the model's cliff map (complete
        by `cliffMapFsm_complete`)."""
        self.fetch([0])
        payload = {**self.payload(0), "cliff_map": {"max_pay_pence": MAX_PAY}}
        out = subprocess.run(
            [str(self.binary)], input=json.dumps(payload), capture_output=True, text=True, check=True
        ).stdout
        return [d["pay_pence"] for d in json.loads(out)["cliff_map"]["drops"] if d["kind"] == "school_meals"]

    def step3(self, g: int) -> int:
        self.fetch([g])
        return self.cache[g]["step3_income_pence"]


def first_at_least(m: Model, target: int, lo: int, hi: int) -> int | None:
    """Least pay g in [lo, hi] with Step 3 income >= target (Step 3 income never
    falls as pay rises)."""
    if m.step3(hi) < target:
        return None
    while lo < hi:
        mid = (lo + hi) // 2
        if m.step3(mid) >= target:
            hi = mid
        else:
            lo = mid + 1
    return lo


def step_pennies(m: Model) -> dict[int, str]:
    """Every pay g at which the theorem allows net(g + 1) < net(g), by kind."""
    h = m.h
    other = h.savings + h.dividends
    steps: dict[int, str] = {}

    def add(total_after: int, kind: str) -> None:
        g = total_after - 1 - other  # pay g, so total income g + other = total_after - 1
        if 0 <= g < MAX_PAY:
            steps.setdefault(g, kind)

    for k in range(1, 12_571):
        add(10_000_000 + 200 * k, "personal allowance")
    if h.cb:
        for k in range(100):
            add(6_020_000 + 20_000 * k, "HICBC")
    if h.childcare_costs or h.funded_children:
        add(10_000_001, "childcare (£100,000)")
    for limit in (BRL, HRL):
        g = first_at_least(m, limit, 0, MAX_PAY)
        if g is not None and m.step3(g) == limit:
            steps[g] = "savings allowance"
    if h.meals:
        for g in m.meal_pennies():
            steps[g] = "free school meals"
    if h.marriage_allowance == "receive":
        assert not other, "maOk_payOnly locates the Marriage Allowance step for pay only"
        limit = BRL_SCOT_INTERMEDIATE if h.country == "scotland" else BRL
        g = first_at_least(m, limit, 0, MAX_PAY)
        if g is not None and m.step3(g) == limit:
            steps[g] = "Marriage Allowance"
    return steps


@dataclass
class Drop:
    pay: int  # net(pay + 1) < net(pay)
    kind: str
    drop: int  # net(pay) - net(pay + 1), 1/10 000 p
    trap_end: int  # first pay after the step with net >= net(pay)


def find_drops(m: Model) -> list[Drop]:
    steps = step_pennies(m)
    pts = sorted(steps)
    m.fetch([p for g in pts for p in (g, g + 1)])
    drops = [
        Drop(g, steps[g], m.net(g) - m.net(g + 1), -1) for g in pts if m.net(g + 1) < m.net(g)
    ]
    # Recovery: net is non-decreasing on [step + 1, next step] (net_succ_ge), so
    # find the first such segment whose right end is back at the level before the
    # drop, then binary search inside it (all drops in parallel).
    bounds = pts + [MAX_PAY]
    m.fetch(bounds)
    lo: dict[int, int] = {}
    hi: dict[int, int] = {}
    for d in drops:
        target = m.net(d.pay)
        i = bounds.index(d.pay)
        while i + 1 < len(bounds) - 1 and m.net(bounds[i + 1]) < target:
            i += 1
        lo[d.pay], hi[d.pay] = bounds[i] + 1, bounds[i + 1]
    while True:
        mids = {g: (lo[g] + hi[g]) // 2 for g in lo if lo[g] < hi[g]}
        if not mids:
            break
        m.fetch(list(mids.values()))
        for d in drops:
            if d.pay in mids:
                mid = mids[d.pay]
                if m.net(mid) >= m.net(d.pay):
                    hi[d.pay] = mid
                else:
                    lo[d.pay] = mid + 1
    for d in drops:
        d.trap_end = lo[d.pay]
    return drops


def pounds(p: float) -> str:
    return f"£{p / 100:,.2f}"


WINDOW = 20_000  # £200: one HICBC step per window, so its 1 % steps do not alias
TOP = 15_000_000  # charts run from £0 to £150,000 of pay
GRID = 5_000  # net income is drawn from its exact value every £50 of pay
MIN_EARNINGS = 4 * 264_368  # childcare minimum earnings, £10,574.72 a year

# One-off cliffs, drawn as drops with their £ amount. The other kinds repeat in
# bands of small steps (the personal allowance every £2, the HICBC every £200)
# and are described once per band; their average effect is a rate.
ONE_OFF = ("childcare (£100,000)", "savings allowance", "Marriage Allowance", "free school meals")
BANDS = ("HICBC", "personal allowance")


@dataclass
class Gain:
    pay: int  # net(pay + 1) > net(pay) by a one-off amount
    gain: int  # millionths of a penny


def find_gains(m: Model) -> list[Gain]:
    """One-off rises: reaching the childcare minimum earnings gains Tax-Free
    Childcare and the working-parent hours."""
    h = m.h
    if not (h.childcare_costs or h.funded_children):
        return []
    g = MIN_EARNINGS - 1
    jump = m.net(g + 1) - m.net(g)
    return [Gain(g, jump)] if jump > 1_000 * UNIT else []  # more than £10: not a smooth rise


def net_series(m: Model, drops: list[Drop], gains: list[Gain]) -> list[tuple[int, int]]:
    """Exact net income every £50 of pay to £150,000, plus both sides of every
    one-off cliff, so the drop is vertical where it happens."""
    xs = set(range(0, TOP + 1, GRID))
    xs |= {p for d in drops if d.kind in ONE_OFF for p in (d.pay, d.pay + 1)}
    xs |= {p for g in gains for p in (g.pay, g.pay + 1)}
    xs = sorted(x for x in xs if x <= TOP)
    m.fetch(xs)
    return [(x, m.net(x)) for x in xs]


def rate_series(m: Model, drops: list[Drop], gains: list[Gain]) -> list[tuple[int, float]]:
    """Effective marginal rate over each £200 of pay to £150,000, without the
    one-off cliffs and gains: those are amounts, not rates, and are shown as
    markers. The small repeated steps stay in, as the band's average rate."""
    xs = list(range(0, TOP + 1, WINDOW))
    m.fetch(xs)
    out = []
    for x in xs[:-1]:
        d_net = m.net(x + WINDOW) - m.net(x)
        d_net += sum(d.drop for d in drops if d.kind in ONE_OFF and x <= d.pay < x + WINDOW)
        d_net -= sum(g.gain for g in gains if x <= g.pay < x + WINDOW)
        out.append((x, 1 - d_net / (UNIT * WINDOW)))
    return out


def chart_data(h: Household, drops: list[Drop], gains: list[Gain], net, rates) -> dict:
    """What harness/charts.py draws, in pounds."""
    bands = []
    for kind in BANDS:
        ds = [d for d in drops if d.kind == kind]
        if ds:
            bands.append({
                "kind": kind,
                "from": (ds[0].pay + 1) / 100,
                "to": (ds[-1].pay + 1) / 100,
                "count": len(ds),
                "drop_min": min(d.drop for d in ds) / UNIT / 100,
                "drop_max": max(d.drop for d in ds) / UNIT / 100,
            })
    return {
        "key": h.key,
        "label": h.label,
        "net": [[x / 100, n / UNIT / 100] for x, n in net],
        "rates": [[x / 100, r] for x, r in rates],
        "cliffs": [
            {
                "kind": d.kind,
                "at": (d.pay + 1) / 100,
                "before": m_before / UNIT / 100,
                "lost": d.drop / UNIT / 100,
                "recovered_at": d.trap_end / 100,
            }
            for d, m_before in ((d, dict(net).get(d.pay)) for d in drops if d.kind in ONE_OFF)
        ],
        "gains": [{"at": (g.pay + 1) / 100, "gained": g.gain / UNIT / 100} for g in gains],
        "bands": bands,
    }


# Seed checks: figures worked out by hand, not by the model.
def seed_checks(binary: pathlib.Path) -> list[str]:
    fails = []
    single = Model(binary, HOUSEHOLDS[0])
    drops = find_drops(single)
    # Each £1 fall in the personal allowance puts £1 more in the 40% band: 40p,
    # plus 0.4p tax and 0.02p NICs on the penny itself, less the penny: 39.42p.
    if len(drops) != 12_570:
        fails.append(f"single: expected 12,570 drops (one per £1 of allowance), got {len(drops)}")
    if {d.drop for d in drops} != {39_420_000}:
        fails.append(f"single: expected every drop to be 39.42p, got {sorted({d.drop for d in drops})[:5]}")
    if {d.kind for d in drops} != {"personal allowance"}:
        fails.append(f"single: unexpected kinds {sorted({d.kind for d in drops})}")
    # £100,000 -> £125,140: 60% income tax (40% + half the allowance at 40%) and 2%
    # NICs, so net income rises by 38% of £25,140 = £9,553.20.
    rise = single.net(12_514_000) - single.net(10_000_000)
    if rise != 955_320 * UNIT:  # pence
        fails.append(f"single: £100,000 to £125,140 net rise {rise / UNIT}p, expected 955,320p")
    one = Model(binary, HOUSEHOLDS[1])
    d1 = {d.pay: d for d in find_drops(one)}
    # £60,199.99 -> £60,200: HICBC 1% of £1,433 = £14 (whole pounds), less the
    # penny after 40% tax and 2% NICs: 1 - 0.4 - 0.02 - 1,400 = -1,399.42p.
    first = d1.get(6_019_999)
    if first is None or first.kind != "HICBC" or first.drop != 1_399_420_000:
        fails.append(f"one child: drop at £60,200 should be £13.9942, got {first}")
    if sum(1 for d in d1.values() if d.kind == "HICBC") != 100:
        fails.append("one child: expected 100 HICBC drops")
    # Lone parent, child aged 2, £10,000 of childcare, 1p over £100,000: loses
    # Tax-Free Childcare £2,000 and 30 h x 38 weeks x £8.90 = £10,146 of funded
    # hours, and keeps 0.58p of the penny (40 % tax, 2 % NICs): £12,145.9942.
    lone = Model(binary, next(h for h in HOUSEHOLDS if h.key == "uc_one_child"))
    cliff = {d.pay: d for d in find_drops(lone)}.get(10_000_000)
    if cliff is None or cliff.kind != "childcare (£100,000)" or cliff.drop != 1_214_599_420_000:
        fails.append(f"lone parent, child aged 2: £100,000 drop should be £12,145.9942, got {cliff}")
    # Marriage Allowance recipient, pay only, 1p over £50,270 (Step 3 income 1p over
    # £37,700): the higher rate is charged, so s55B(2)(b) fails and the £252
    # reduction goes; the penny keeps 1 - 0.4 (tax) - 0.02 (NICs above the upper
    # earnings limit) = 0.58p: £251.9942.
    ma = Model(binary, next(h for h in HOUSEHOLDS if h.key == "ma_receive"))
    cliff = {d.pay: d for d in find_drops(ma)}.get(5_027_000)
    if cliff is None or cliff.kind != "Marriage Allowance" or cliff.drop != 25_199_420_000:
        fails.append(f"Marriage Allowance: drop at £50,270.01 should be £251.9942, got {cliff}")
    # In Scotland, 1p over £43,662 (Step 3 income 1p over the top of the 21 %
    # intermediate rate, £31,092): the 42 % higher rate is charged and the £252
    # goes; the penny keeps 1 - 0.42 - 0.08 (NICs) = 0.5p: £251.995.
    ma = Model(binary, next(h for h in HOUSEHOLDS if h.key == "ma_receive_scotland"))
    cliff = {d.pay: d for d in find_drops(ma)}.get(4_366_200)
    if cliff is None or cliff.kind != "Marriage Allowance" or cliff.drop != 25_199_500_000:
        fails.append(f"Marriage Allowance, Scotland: drop at £43,662.01 should be £251.995, got {cliff}")
    # Lone parent on UC, two pupils with lunches worth £172.90 (65 x £2.66) to 16
    # August and £332.50 (125 x £2.66) from 17 August: 1p over £7,400.04 of pay
    # (twelve months of £616.67, SI 2018/148 reg 4(b)) the lunches to 16 August go,
    # £345.80; pay is under the £710 a month work allowance and the personal
    # allowance and primary threshold, so the penny is kept whole: £345.79. Where the
    # UC award reaches nil the lunches from 17 August go, £665, less at most 0.72p
    # of the penny kept (20 % tax, 8 % NICs).
    fsm = Model(binary, next(h for h in HOUSEHOLDS if h.key == "uc_school_meals"))
    ds = [d for d in find_drops(fsm) if d.kind == "free school meals"]
    if len(ds) != 2 or ds[0].pay != 740_004 or ds[0].drop != 34_579 * UNIT:
        fails.append(f"free school meals: drop at £7,400.05 should be £345.79, got {ds[:1]}")
    elif not 66_499_280_000 <= ds[1].drop <= 66_500 * UNIT:
        fails.append(f"free school meals: drop where UC ends should be £664.9928 to £665, got {ds[1]}")
    return fails


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--check-only", action="store_true")
    ap.add_argument("--docs", type=pathlib.Path, default=ROOT / "docs")
    args = ap.parse_args()

    fails = seed_checks(args.binary)
    for f in fails:
        print("FAIL", f)
    print(f"seed checks: {'all passed' if not fails else f'{len(fails)} failed'}")
    if fails or args.check_only:
        return 1 if fails else 0

    args.docs.mkdir(parents=True, exist_ok=True)
    md = [
        "# Where earning more lowers net income (2026-27)",
        "",
        "Generated by `harness/cliffs.py`; do not edit by hand. Net income is gross income less",
        "income tax, employee NICs (annual basis) and the High Income Child Benefit Charge, plus",
        "Child Benefit (53 weeks at £27.05 / £17.90), plus, where claimed, the better of Universal",
        "Credit and Tax-Free Childcare (childcare costs £10,000 a year per child, an illustrative",
        "assumption), plus the funded hours (England) for the children's ages, valued at DfE's",
        "2026-27 national average local authority funding rates (£12.04 an hour under 2, £8.90 at",
        "2, £6.61 at 3 and 4) for 38 weeks. Pay varies; everything else is fixed. Over £100,000",
        "the working-parent hours go (30 a week under 3; the 15 on top of the universal 15 at 3",
        "and 4); the universal 15 hours stay. Reaching the minimum earnings gains Tax-Free",
        "Childcare and the working-parent hours, so it is a rise, not a drop.",
        "",
        "Free school lunches (England, Education Act 1996 s512ZB) are valued at DfE's £2.66 a meal,",
        "an illustrative value: 65 school days from 6 April to 16 August 2026, when Universal Credit",
        "qualifies only with earned income of at most £7,400.04 a year (SI 2018/148), and 125 from",
        "17 August 2026, when any award of Universal Credit does (s512ZB(4D)). Their cliffs are",
        "listed by `netAllFsm_drop_only_at_steps`, found exactly by `cliffMapFsm_complete`.",
        "",
        "The model's UC has no childcare costs element (85 % of costs up to £1,071.09 a month for",
        "one child, £1,836.16 for two or more: SI 2013/376 regs 34 and 36). With it UC would stay",
        "the better choice to much higher pay, so where the lone-parent households switch from UC",
        "to Tax-Free Childcare is illustrative, not realistic. The £100,000 cliff does not depend",
        "on it.",
        "",
        "Every penny where net income can fall is listed by the Lean theorem",
        "`netAll_drop_only_at_steps`, so these tables are complete within the model for each",
        "household, at every pay. A *drop* is the fall in net income from one more penny of pay. The",
        "*trap* is the pay range above the step where net income stays below its level just before",
        "the step.",
        "",
    ]
    charts, rows = [], []
    for h in HOUSEHOLDS:
        m = Model(args.binary, h)
        drops = find_drops(m)
        gains = find_gains(m)
        net = net_series(m, drops, gains)
        rates = rate_series(m, drops, gains)
        charts.append(chart_data(h, drops, gains, net, rates))
        for d in drops:
            rows.append(
                {
                    "household": h.key,
                    "kind": d.kind,
                    "pay_pence": d.pay + 1,
                    "total_income_pence": d.pay + 1 + h.savings + h.dividends,
                    "drop_millionths_pence": d.drop,
                    "trap_end_pay_pence": d.trap_end,
                    "trap_width_pence": d.trap_end - (d.pay + 1),
                }
            )
        md += [f"## {h.label}", ""]
        if not drops:
            md += ["No drops.", ""]
            continue
        md += ["| kind | where (pay reaching) | drops | each drop (one-off) | trap after each step |", "|---|---|---|---|---|"]
        for kind in ("free school meals", "savings allowance", "HICBC", "childcare (£100,000)", "personal allowance"):
            ds = [d for d in drops if d.kind == kind]
            if not ds:
                continue
            where = (
                pounds(ds[0].pay + 1)
                if len(ds) == 1
                else f"{pounds(ds[0].pay + 1)} to {pounds(ds[-1].pay + 1)}"
            )
            lo, hi = min(d.drop for d in ds), max(d.drop for d in ds)
            each = pounds(lo / UNIT) if lo == hi else f"{pounds(lo / UNIT)} to {pounds(hi / UNIT)}"
            widths = [d.trap_end - (d.pay + 1) for d in ds]
            wl, wh = min(widths), max(widths)
            trap = pounds(wl) if wl == wh else f"{pounds(wl)} to {pounds(wh)}"
            md.append(f"| {kind} | {where} | {len(ds):,} | {each} | {trap} |")
        md.append("")
        for d in (d for d in drops if d.kind in ONE_OFF):
            md.append(
                f"- {d.kind}: one more penny over {pounds(d.pay)} costs {pounds(d.drop / UNIT)}, once; "
                f"net income is back to its level at {pounds(d.trap_end)} of pay."
            )
        for g in gains:
            md.append(
                f"- Reaching the minimum earnings ({pounds(g.pay + 1)}) *gains* {pounds(g.gain / UNIT)}, once "
                "(the working-parent hours start, and Tax-Free Childcare where it beats Universal Credit)."
            )
        md.append("")
    md += [
        "## Charts",
        "",
        "A cliff is a one-off loss: one more penny of pay costs a fixed sum, once, and net income",
        "then climbs back at the usual rate. It is not a rate, so the charts show it as a drop in",
        "£, with the pay at which net income is back to where it was.",
        "",
        "![Net income against gross pay, by household, with each cliff labelled](net.svg)",
        "",
        "Net income against gross pay from £0 to £150,000, exact from the model every £50 and on",
        "both sides of each cliff (table view: `net.csv`, every £1,000). The bands of small",
        "repeated steps (the personal allowance taper, every £2; the HICBC, every £200) are",
        "described once each rather than drawn.",
        "",
        "![Effective marginal rate between the cliffs, by household](rates.svg)",
        "",
        "The marginal rate on each £200 of pay with the one-off cliffs and gains taken out (they",
        "are the markers, with their £ amount); the small repeated steps stay in, as the band's",
        "average rate: 62 % from £100,000 to £125,140 with NICs. Table view: `rates.csv`.",
        "Without benefits the rate on a penny between steps is at most 76.6 % (`net_succ_ge`);",
        "with benefits it is at most 89.47 % (`netAll_succ_ge`: 1 - 0.45 x 0.234).",
        "",
        "![Lone parent with a 2-year-old: net income from £80,000 to £140,000 of pay](cliff-100k.png)",
        "",
    ]
    (args.docs / "cliffs.md").write_text("\n".join(md))
    with (args.docs / "net.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["pay_pounds"] + [c["key"] for c in charts])
        grids = [{x: n for x, n in c["net"]} for c in charts]
        for x in range(0, TOP // 100 + 1, 1_000):
            w.writerow([x] + [f"{g[float(x)]:.2f}" for g in grids])
    with (args.docs / "rates.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["pay_from_pounds", "pay_to_pounds"] + [c["key"] for c in charts])
        for i, (x, _) in enumerate(charts[0]["rates"]):
            w.writerow([int(x), int(x) + WINDOW // 100] + [f"{c['rates'][i][1]:.4f}" for c in charts])
    out = HERE / "out"
    out.mkdir(exist_ok=True)
    (out / "chart-data.json").write_text(json.dumps(charts))
    with (out / "cliffs.csv").open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    print(f"{len(rows):,} drops; wrote {args.docs / 'cliffs.md'}, net.csv, rates.csv, {out / 'cliffs.csv'} "
          f"and {out / 'chart-data.json'} (draw with charts.py)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
