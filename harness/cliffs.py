"""Map where earning more lowers net income, for a few household types (2026-27).

Net income = gross income - income tax - employee NICs - High Income Child
Benefit Charge + Child Benefit + the better of Universal Credit and Tax-Free
Childcare + funded hours: the `netAll` of UkTax/Benefits.lean, exact, in
1/1 000 000 of a penny, read from the `uktax` binary. Pay varies; each
household's savings, dividends, Child Benefit and claims are fixed; NICs on the
annual basis.

Completeness comes from the Lean theorem `netAll_drop_only_at_steps`: one more
penny of pay can lower net income only at a step of the personal allowance
(total income reaching a multiple of £2 in (£100,000, £125,140]), of the HICBC
(a multiple of £200 in [£60,200, £80,000], with Child Benefit), of the personal
savings allowance (Step 3 income at £37,700 or £125,140), or where adjusted net
income goes over £100,000 (Tax-Free Childcare and funded hours). This script
lists every such penny, so it checks every place a drop can happen and finds
the drops exactly; it samples nothing. Between steps net income never falls
(`netAll_between_steps`), which is what makes the recovery search below exact.

For each drop it reports the size, and the "trap": the pay range above the step
where net income is below what it was just before the step, i.e. where earning
less would leave the household better off.

    python3 harness/cliffs.py                    # writes docs/cliffs.md, docs/emr.svg
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

# Child Benefit for 52 weeks, GOV.UK 2026-27: £27.05 eldest, £17.90 each other child.
CB = {0: 0, 1: 52 * 2705, 2: 52 * (2705 + 1790), 3: 52 * (2705 + 2 * 1790)}


@dataclass(frozen=True)
class Household:
    key: str
    label: str
    savings: int = 0
    dividends: int = 0
    children: int = 0
    uc: bool = False
    childcare_costs: tuple[int, ...] = ()

    @property
    def cb(self) -> int:
        return CB[self.children]


# Childcare costs for Tax-Free Childcare are an illustrative assumption: £10,000 a
# year per child, enough to reach the £2,000 top-up cap (20 % of £10,000).
CHILDCARE = 1_000_000

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
        "Lone parent, 1 child: UC (no childcare element) or Tax-Free Childcare",
        children=1,
        uc=True,
        childcare_costs=(CHILDCARE,),
    ),
    Household(
        "uc_three_children",
        "Lone parent, 3 children (2 in childcare): UC (no childcare element) or Tax-Free Childcare",
        children=3,
        uc=True,
        childcare_costs=(CHILDCARE, CHILDCARE),
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
        base = {
            "savings_pence": self.h.savings,
            "dividends_pence": self.h.dividends,
            "child_benefit_pence": self.h.cb,
            "childcare_costs_pence": list(self.h.childcare_costs),
        }
        if self.h.uc:
            base["uc"] = {"couple": False, "children": self.h.children}
        payload = [{"non_savings_pence": g, "employment_pence": g, **base} for g in todo]
        out = subprocess.run(
            [str(self.binary)], input=json.dumps(payload), capture_output=True, text=True, check=True
        ).stdout
        for g, r in zip(todo, json.loads(out)):
            self.cache[g] = r

    def net(self, g: int) -> int:
        self.fetch([g])
        return self.cache[g]["net_income_millionths_pence"]

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
    if h.childcare_costs:
        add(10_000_001, "childcare (£100,000)")
    for limit in (BRL, HRL):
        g = first_at_least(m, limit, 0, MAX_PAY)
        if g is not None and m.step3(g) == limit:
            steps[g] = "savings allowance"
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


def emr_series(m: Model, window: int = WINDOW, top: int = 15_000_000) -> list[tuple[int, float]]:
    """Effective marginal rate over each £200 of pay up to £150,000."""
    xs = list(range(0, top + 1, window))
    m.fetch(xs)
    return [(x, 1 - (m.net(x + window) - m.net(x)) / (UNIT * window)) for x in xs[:-1]]


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
    # £60,199.99 -> £60,200: HICBC 1% of £1,406 = £14 (whole pounds), less the
    # penny after 40% tax and 2% NICs: 1 - 0.4 - 0.02 - 1,400 = -1,399.42p.
    first = d1.get(6_019_999)
    if first is None or first.kind != "HICBC" or first.drop != 1_399_420_000:
        fails.append(f"one child: drop at £60,200 should be £13.9942, got {first}")
    if sum(1 for d in d1.values() if d.kind == "HICBC") != 100:
        fails.append("one child: expected 100 HICBC drops")
    return fails


def write_svg(series: dict[str, list[tuple[int, float]]], labels: dict[str, str], path: pathlib.Path) -> None:
    """Small multiples, one panel per household: effective marginal rate on £100
    of extra pay, 0 to £150,000."""
    W, PH, GAP, L, R, T = 760, 140, 58, 56, 16, 48
    n = len(series)
    H = T + n * (PH + GAP)
    # Fixed 0-120 % scale; any window above it is marked with an arrow and its value.
    xmax, ymin, ymax = 15_000_000, 0.0, 1.2
    ink, sub, grid, base, blue = "#1f1f1f", "#666666", "#e7e7e7", "#c2c2c2", "#257de0"
    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" '
        'font-family="system-ui, -apple-system, Segoe UI, sans-serif" font-size="11">',
        f'<rect width="{W}" height="{H}" fill="#ffffff"/>',
        f'<text x="{L}" y="18" font-size="14" fill="{ink}" font-weight="600">Effective marginal rate on '
        "£200 more pay, 2026-27</text>",
        f'<text x="{L}" y="34" fill="{sub}">Income tax + NICs + HICBC, less Child Benefit, UC and Tax-Free Childcare; '
        "above 100% the extra £200 leaves the household worse off</text>",
    ]
    for k, (key, pts) in enumerate(series.items()):
        top = T + k * (PH + GAP) + 18
        sx = lambda x: L + (W - L - R) * x / xmax  # noqa: E731
        sy = lambda y: top + PH * (1 - (min(max(y, ymin), ymax) - ymin) / (ymax - ymin))  # noqa: E731
        out.append(f'<text x="{L}" y="{top - 6}" fill="{ink}" font-weight="600">{labels[key]}</text>')
        for y in [i / 5 for i in range(int(ymax * 5) + 1)]:
            c = base if y == 0 else grid
            dash = ' stroke-dasharray="3 3"' if y == 1.0 else ""
            out.append(f'<line x1="{L}" x2="{W - R}" y1="{sy(y):.1f}" y2="{sy(y):.1f}" stroke="{c}"{dash}/>')
            out.append(f'<text x="{L - 6}" y="{sy(y) + 4:.1f}" text-anchor="end" fill="{sub}">{int(y * 100)}%</text>')
        for x in range(0, xmax + 1, 2_500_000):
            out.append(f'<text x="{sx(x):.1f}" y="{top + PH + 14}" text-anchor="middle" fill="{sub}">'
                       f"£{x // 100_000}k</text>")
        d = " ".join(f"{'M' if i == 0 else 'L'}{sx(x):.1f},{sy(y):.1f}" for i, (x, y) in enumerate(pts))
        out.append(f'<path d="{d}" fill="none" stroke="{blue}" stroke-width="1.5" stroke-linejoin="round"/>')
        for x, y in pts:
            if y > ymax:
                cx, cy = sx(x), sy(ymax)
                out.append(f'<path d="M{cx - 4:.1f},{cy + 2:.1f} L{cx:.1f},{cy - 5:.1f} L{cx + 4:.1f},{cy + 2:.1f} Z" '
                           f'fill="{blue}"/>')
                left = cx > 0.7 * W  # keep the label inside the chart
                tx, anchor = (cx - 7, "end") if left else (cx + 7, "start")
                out.append(f'<text x="{tx:.1f}" y="{cy + 14:.1f}" text-anchor="{anchor}" fill="{ink}">'
                           f"{y * 100:,.0f}% (£{x / 100:,.0f} to £{(x + WINDOW) / 100:,.0f})</text>")
    out.append("</svg>")
    path.write_text("\n".join(out) + "\n")


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
        "Child Benefit (52 weeks at £27.05 / £17.90), plus, where claimed, the better of Universal",
        "Credit and Tax-Free Childcare (childcare costs £10,000 a year per child, an illustrative",
        "assumption). Pay varies; everything else is fixed. The funded hours for working parents",
        "are lost at the same £100,000 as Tax-Free Childcare, but they are in kind and no value is",
        "assumed here, so their cliff is not in these tables: it adds their value to the",
        "£100,000 drop, and lengthens the trap by about that value divided by 0.38.",
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
    series, labels, rows = {}, {}, []
    for h in HOUSEHOLDS:
        m = Model(args.binary, h)
        drops = find_drops(m)
        labels[h.key] = h.label
        series[h.key] = emr_series(m)
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
        md += ["| kind | where (pay reaching) | drops | each drop | trap after each step |", "|---|---|---|---|---|"]
        for kind in ("savings allowance", "HICBC", "childcare (£100,000)", "personal allowance"):
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
    md += [
        "## Effective marginal rate",
        "",
        "![Effective marginal rate on £200 more pay, by household](emr.svg)",
        "",
        "The rate on each £200 of pay from £0 to £150,000 is in `emr.csv` (the chart's table view);",
        "£200 windows hold one HICBC step each, so the HICBC band shows as a level rate.",
        "Without benefits the rate on a penny between steps is at most 76.6 % (`net_succ_ge`);",
        "with benefits it is at most 89.47 % (`netAll_succ_ge`: 1 - 0.45 x 0.234). A rate above 100 % occurs only",
        "on the step pennies above.",
        "",
    ]
    (args.docs / "cliffs.md").write_text("\n".join(md))
    write_svg(series, labels, args.docs / "emr.svg")
    with (args.docs / "emr.csv").open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["pay_from_pence", "pay_to_pence"] + [h.key for h in HOUSEHOLDS])
        for i, (x, _) in enumerate(series[HOUSEHOLDS[0].key]):
            w.writerow([x, x + WINDOW] + [f"{series[h.key][i][1]:.4f}" for h in HOUSEHOLDS])
    out = HERE / "out"
    out.mkdir(exist_ok=True)
    with (out / "cliffs.csv").open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    print(f"{len(rows):,} drops; wrote {args.docs / 'cliffs.md'}, emr.svg, emr.csv and {out / 'cliffs.csv'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
