"""Draw the cliff charts from harness/out/chart-data.json (written by cliffs.py).

    python3 harness/cliffs.py
    cd harness && uv run --frozen --only-group charts python charts.py

Writes, under docs/:

* net.svg: net income against gross pay, £0 to £150,000, one panel per
  household. One-off cliffs are drawn as the drops they are and labelled with
  the amount lost and the pay at which net income is back where it was; each
  band of small repeated steps (the allowance taper, the HICBC) gets one label.
* rates.svg: the marginal rate on each £200 of pay with the one-off cliffs and
  gains taken out; they are markers with their £ amount, not rates.
* cliff-100k.png: one panel, 1200 x 1200, for sharing: the lone parent with a
  2-year-old, £80,000 to £140,000 of pay.

Output is byte-for-byte reproducible (CI checks it): fonts come only from
matplotlib's own bundled DejaVu Sans, and the files carry no dates.
"""

from __future__ import annotations

import json
import math
import pathlib

import matplotlib

matplotlib.use("Agg")
import matplotlib.font_manager as fm  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.ticker import FuncFormatter  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
DOCS = HERE.parent / "docs"
DATA = HERE / "out/chart-data.json"

# Only matplotlib's bundled fonts, so the output does not depend on the machine.
fm.fontManager.ttflist = [f for f in fm.fontManager.ttflist if f.fname.startswith(matplotlib.get_data_path())]

INK, SUB, GRID, BAND, BLUE = "#191919", "#666666", "#e7e7e7", "#f1f1f1", "#257de0"
plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 9,
    "svg.hashsalt": "uk-tax-lean",
    "svg.fonttype": "path",
    "axes.edgecolor": "#c2c2c2",
    "axes.labelcolor": SUB,
    "xtick.color": SUB,
    "ytick.color": SUB,
    "axes.spines.top": False,
    "axes.spines.right": False,
})
MINUS = "−"

BAND_TEXT = {
    "personal allowance": lambda b: f"Allowance taper\n{b['count']:,} steps of {b['drop_min'] * 100:.0f}p",
    "HICBC": lambda b: f"Child Benefit charge\n{b['count']} steps of £{round(b['drop_min'])}–£{round(b['drop_max'])}",
}


def k(x: float, _=None) -> str:
    return f"£{x / 1000:,.0f}k"


def money(x: float) -> str:
    return f"£{round(x):,}"


def cliff_text(c: dict) -> str:
    return f"{MINUS}{money(c['lost'])} at {money(math.floor(c['at']))},\nrecovered at {money(c['recovered_at'])}"


def axes_style(ax, ylabel: str) -> None:
    ax.grid(axis="y", color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)
    ax.tick_params(length=0)
    ax.xaxis.set_major_formatter(FuncFormatter(k))
    ax.set_xlim(0, 150_000)
    ax.set_ylabel(ylabel)


def header(fig, height: float, title: str, subtitle: str) -> None:
    """Title and subtitle in the top 0.75 inch of a figure `height` inches tall."""
    fig.text(0.07, 1 - 0.22 / height, title, fontsize=13, color=INK, fontweight="bold", va="top")
    fig.text(0.07, 1 - 0.50 / height, subtitle, fontsize=9, color=SUB, va="top")


def draw_net(hs: list[dict], path: pathlib.Path) -> None:
    height = 3.0 * len(hs)
    fig, axes = plt.subplots(len(hs), 1, figsize=(9.6, height))
    header(fig, height, "Net income against gross pay, 2026-27",
           "Each cliff is a one-off loss: the amount lost, and the pay at which net income is back where it was")
    for ax, h in zip(axes, hs):
        xs, ys = zip(*h["net"])
        top = max(ys) * 1.12
        for b in h["bands"]:
            ax.axvspan(b["from"], b["to"], color=BAND, linewidth=0, zorder=0)
            ax.text(b["from"] + 600, top * 0.04, BAND_TEXT[b["kind"]](b), fontsize=7.5, color=SUB, va="bottom")
        ax.plot(xs, ys, color=BLUE, linewidth=1.5, solid_joinstyle="miter")
        for i, c in enumerate(h["cliffs"]):
            ax.plot([c["at"], c["recovered_at"]], [c["before"]] * 2, color=INK, linewidth=0.9, linestyle=(0, (3, 2)))
            ax.plot([c["recovered_at"]], [c["before"]], "o", color=INK, markersize=3.5)
            if c["before"] > 0.6 * top:  # near the top: label below, right of the drop
                xy, off, ha, va = (c["at"], c["before"] - c["lost"]), (10, -14), "left", "top"
            else:  # label above, left of the drop
                xy, off, ha, va = (c["at"], c["before"]), (-8, 12 + 22 * i), "right", "bottom"
            ax.annotate(cliff_text(c), xy, xytext=off, textcoords="offset points", ha=ha, va=va, fontsize=8,
                        color=INK, arrowprops={"arrowstyle": "-", "color": SUB, "linewidth": 0.6})
        for g in h["gains"]:
            y = dict(map(tuple, h["net"]))[g["at"]]
            ax.annotate(f"+{money(g['gained'])} at {money(g['at'])}\n(childcare help starts)", (g["at"], y),
                        xytext=(6, 18), textcoords="offset points", ha="left", va="bottom", fontsize=8, color=INK,
                        arrowprops={"arrowstyle": "-", "color": SUB, "linewidth": 0.6})
        axes_style(ax, "net income")
        ax.yaxis.set_major_formatter(FuncFormatter(k))
        ax.set_ylim(0, top)
        ax.set_title(h["label"], loc="left", fontsize=9.5, color=INK, fontweight="bold")
    fig.tight_layout(rect=(0, 0, 1, 1 - 0.75 / height), h_pad=2.2)
    fig.savefig(path, metadata={"Date": None, "Creator": None})
    plt.close(fig)


def draw_rates(hs: list[dict], path: pathlib.Path) -> None:
    height = 2.4 * len(hs)
    fig, axes = plt.subplots(len(hs), 1, figsize=(9.6, height))
    header(fig, height, "Marginal rate between the cliffs, on each £200 of pay, 2026-27",
           "One-off cliffs and gains are not rates: they are taken out of the line and marked with their £ amount")
    for ax, h in zip(axes, hs):
        xs, rs = zip(*h["rates"])
        ax.step(xs, [r * 100 for r in rs], where="post", color=BLUE, linewidth=1.5)
        for c in h["cliffs"]:
            ax.plot([c["at"]], [104], "v", color=INK, markersize=6, clip_on=False)
            ax.text(c["at"], 110, f"{MINUS}{money(c['lost'])}", ha="center", fontsize=8, color=INK)
        for g in h["gains"]:
            ax.plot([g["at"]], [104], "^", color=INK, markersize=6, clip_on=False)
            ax.text(g["at"], 110, f"+{money(g['gained'])}", ha="center", fontsize=8, color=INK)
        axes_style(ax, "marginal rate")
        ax.set_ylim(0, 100)
        ax.set_yticks(range(0, 101, 20))
        ax.yaxis.set_major_formatter(FuncFormatter(lambda y, _: f"{y:.0f}%"))
        ax.set_title(h["label"], loc="left", fontsize=9.5, color=INK, fontweight="bold", pad=22)
    fig.tight_layout(rect=(0, 0, 1, 1 - 0.75 / height), h_pad=1.6)
    fig.savefig(path, metadata={"Date": None, "Creator": None})
    plt.close(fig)


def draw_share(h: dict, path: pathlib.Path) -> None:
    """One panel for a phone screen: the £100,000 cliff and its recovery."""
    (c,) = [c for c in h["cliffs"] if c["kind"].startswith("childcare")]
    pts = [(x, y) for x, y in h["net"] if 80_000 <= x <= 140_000]
    xs, ys = zip(*pts)
    after = min(y for x, y in pts if x > c["at"] - 1)
    fig = plt.figure(figsize=(12, 12), dpi=100)
    fig.text(0.06, 0.94, f"Earn one penny over £100,000,\nlose {money(c['lost'])}", fontsize=40, color=INK,
             fontweight="bold", va="top", linespacing=1.15)
    fig.text(0.06, 0.80, "A single parent with a 2-year-old in England, 2026-27", fontsize=21, color=SUB, va="top")
    ax = fig.add_axes((0.13, 0.17, 0.82, 0.57))
    ax.plot(xs, ys, color=BLUE, linewidth=4, solid_joinstyle="miter")
    ax.plot([c["at"], c["recovered_at"]], [c["before"]] * 2, color=INK, linewidth=2, linestyle=(0, (4, 3)))
    ax.plot([c["recovered_at"]], [c["before"]], "o", color=INK, markersize=11)
    ax.plot([c["at"]], [c["before"]], "o", color=INK, markersize=11)
    ax.annotate(f"At £100,000 of pay:\n{money(c['before'])} a year", (c["at"], c["before"]), xytext=(-16, 14),
                textcoords="offset points", ha="right", fontsize=22, color=INK)
    ax.annotate(f"1p more: {money(after)}\nTax-Free Childcare and\n30 free hours a week\nare gone",
                (c["at"], after), xytext=(24, -10), textcoords="offset points", ha="left", va="top", fontsize=22,
                color=INK)
    ax.annotate(f"Back to {money(c['before'])} only at\n{money(c['recovered_at'])} of pay: a\n"
                f"{money(c['recovered_at'] - math.floor(c['at']))} raise to stand still",
                (c["recovered_at"], c["before"]), xytext=(-14, 22), textcoords="offset points", ha="right",
                va="bottom", fontsize=22, color=INK, fontweight="bold")
    ax.grid(axis="y", color=GRID, linewidth=1.2)
    ax.set_axisbelow(True)
    ax.tick_params(length=0, labelsize=19)
    ax.xaxis.set_major_formatter(FuncFormatter(k))
    ax.yaxis.set_major_formatter(FuncFormatter(k))
    ax.set_xlim(80_000, 140_000)
    lo, hi = math.floor(min(ys) / 10_000) * 10_000, math.ceil(max(ys) / 10_000) * 10_000
    ax.set_ylim(lo - 5_000, hi)
    ax.set_yticks(range(lo, hi + 1, 5_000))  # no tick at the bottom corner
    ax.set_xlabel("Gross pay a year", fontsize=20, color=SUB, labelpad=12)
    ax.set_ylabel("Net income a year", fontsize=20, color=SUB, labelpad=12)
    fig.text(0.06, 0.035,
             "Net income: pay after income tax and National Insurance, plus Child Benefit, Tax-Free Childcare\n"
             "(£10,000 a year of paid childcare) and 30 free hours a week valued at the £8.90 an hour the\n"
             "government pays councils for a 2-year-old. Exact model of the 2026-27 rules.",
             fontsize=14, color=SUB, va="bottom", linespacing=1.4)
    fig.savefig(path, dpi=100, metadata={"Software": None})
    plt.close(fig)


def main() -> None:
    hs = json.loads(DATA.read_text())
    draw_net(hs, DOCS / "net.svg")
    draw_rates(hs, DOCS / "rates.svg")
    draw_share(next(h for h in hs if h["key"] == "uc_one_child"), DOCS / "cliff-100k.png")
    print(f"wrote {DOCS / 'net.svg'}, {DOCS / 'rates.svg'} and {DOCS / 'cliff-100k.png'}")


if __name__ == "__main__":
    main()
