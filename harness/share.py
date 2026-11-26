"""The 1200 x 1500 image for sharing the £100,000 cliff, in three designs.

charts.py draws the chosen one (DESIGN) to docs/cliff-100k.png; the others are
drawn on request for comparison:

    cd harness && uv run --frozen --only-group charts python charts.py --variants out/linkedin

Every figure on the image comes from the model (chart-data.json); only the
assumptions in the source line are fixed text. The font is Inter (SIL Open
Font License, harness/fonts/OFL.txt), loaded from its file, so the output does
not depend on the fonts installed on the machine.
"""

from __future__ import annotations

import math
import pathlib
from dataclasses import dataclass

import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
from matplotlib.patches import Rectangle
from matplotlib.ticker import FuncFormatter

FONTS = pathlib.Path(__file__).resolve().parent / "fonts"
W, H, DPI = 1200, 1500, 100  # 4:5, the tallest shape LinkedIn shows uncropped in the feed

# The publishing identity is not chosen yet: a neutral placeholder, to be replaced.
HANDLE = "‹ link or handle ›"

ASSUMPTIONS = ("2026-27 UK rules, exact model. Assumes £10,000 a year of paid childcare;"
               " free hours valued at the DfE's £8.90 an hour.")
TAKE_HOME = ("Take-home: pay after income tax and National Insurance, plus Child Benefit,"
             " Tax-Free Childcare and free hours.")

MINUS = "−"


def font(weight: str) -> FontProperties:
    return FontProperties(fname=FONTS / f"Inter-{weight}.ttf")


def money(x: float) -> str:
    return f"£{round(x):,}"


def k(x: float, _=None) -> str:
    return f"£{x / 1000:,.0f}k"


@dataclass(frozen=True)
class Cliff:
    """The £100,000 cliff, every number read from the model's output."""

    pay: float  # £100,000: the last pay before the drop
    before: float  # take-home at £100,000
    after: float  # take-home one penny later
    lost: float
    recovered: float  # pay at which take-home is back to `before`
    curve: list[tuple[float, float]]  # (pay, take-home), £80,000 to £140,000

    @property
    def raise_needed(self) -> float:
        return self.recovered - self.pay

    def at(self, x: float) -> float:
        """Take-home at pay x, interpolated between the model's points (not across the drop)."""
        for (x0, y0), (x1, y1) in zip(self.curve, self.curve[1:]):
            if x0 <= x <= x1 and x1 - x0 > 0.02:
                return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
        raise ValueError(x)


def cliff_of(h: dict) -> Cliff:
    (c,) = [c for c in h["cliffs"] if c["kind"].startswith("childcare")]
    net = dict(map(tuple, h["net"]))
    pay = math.floor(c["at"])
    assert net[pay] == c["before"], (net[pay], c["before"])
    return Cliff(pay=pay, before=c["before"], after=net[c["at"]], lost=c["lost"], recovered=c["recovered_at"],
                 curve=[(x, y) for x, y in h["net"] if 80_000 <= x <= 140_000])


# ---------------------------------------------------------------- drawing kit


class Canvas:
    """A figure addressed in pixels from the top-left corner."""

    def __init__(self, bg: str):
        self.fig = plt.figure(figsize=(W / DPI, H / DPI), dpi=DPI, facecolor=bg)
        self.r = self.fig.canvas.get_renderer()

    def text(self, x: float, y: float, s: str, size: float, color: str, weight: str = "Regular", **kw):
        return self.fig.text(x / W, 1 - y / H, s, fontproperties=font(weight), fontsize=size, color=color,
                             va=kw.pop("va", "top"), **kw)

    def runs(self, x: float, y: float, parts: list[tuple[str, str]], size: float, weight: str) -> float:
        """One line of differently coloured runs; returns the x after the last run."""
        for s, color in parts:
            t = self.text(x, y, s, size, color, weight)
            x += t.get_window_extent(self.r).width
        return x

    def axes(self, left: float, top: float, width: float, height: float):
        ax = self.fig.add_axes((left / W, 1 - (top + height) / H, width / W, height / H))
        ax.set_facecolor("none")
        for s in ax.spines.values():
            s.set_visible(False)
        ax.tick_params(length=0)
        return ax

    def rule(self, x0: float, x1: float, y: float, color: str, lw: float = 1.0):
        self.fig.add_artist(plt.Line2D([x0 / W, x1 / W], [1 - y / H] * 2, color=color, linewidth=lw))

    def save(self, path: pathlib.Path) -> None:
        self.fig.savefig(path, dpi=DPI, facecolor=self.fig.get_facecolor(), metadata={"Software": None})
        plt.close(self.fig)


def tick_labels(ax, color: str, size: float) -> None:
    for t in ax.get_xticklabels() + ax.get_yticklabels():
        t.set_fontproperties(font("Regular"))
        t.set_fontsize(size)
        t.set_color(color)


def loss_area(ax, c: Cliff, color: str, alpha: float) -> None:
    """Shade where take-home is below what it was at £100,000: from the drop to the recovery."""
    xs = [c.pay] + [x for x, _ in c.curve if c.pay < x < c.recovered] + [c.recovered]
    ys = [c.after] + [y for x, y in c.curve if c.pay < x < c.recovered] + [c.before]
    ax.fill_between(xs, ys, [c.before] * len(xs), color=color, alpha=alpha, linewidth=0, zorder=1)


def bracket(ax, x: float, y0: float, y1: float, color: str, lw: float, arm: float) -> None:
    """A square bracket ] spanning y0..y1 at x, arms pointing right by `arm` (data units)."""
    ax.plot([x - arm, x, x, x - arm], [y0, y0, y1, y1], color=color, linewidth=lw, solid_capstyle="butt",
            solid_joinstyle="miter", zorder=4, clip_on=False)


def footer(cv: Canvas, ink: str, faint: str, y: float = 1370) -> None:
    cv.text(80, y, TAKE_HOME, 13.5, ink)
    cv.text(80, y + 26, ASSUMPTIONS, 13.5, ink)
    cv.text(80, y + 70, HANDLE, 15, faint, "SemiBold")


# ---------------------------------------------------------------- A: shaded loss, light


def draw_shaded(c: Cliff, path: pathlib.Path) -> None:
    BG, INK, SUB, MUTED, GRID, RED = "#fbfaf7", "#16181d", "#4d5159", "#8a8f98", "#e6e4df", "#d23a2c"
    cv = Canvas(BG)
    cv.text(80, 84, "SINGLE PARENT · CHILD AGED 2 · ENGLAND · 2026-27", 15.5, SUB, "SemiBold")
    cv.text(80, 124, "Earn 1p over £100,000,", 58, INK, "ExtraBold")
    cv.runs(80, 210, [("lose ", INK), (money(c.lost) + ".", RED)], 58, "ExtraBold")
    cv.text(80, 316, f"Take-home drops from {money(c.before)} to {money(c.after)}.\n"
                     f"It takes a {money(c.raise_needed)} pay rise to get it back.", 25, SUB, linespacing=1.45)

    ax = cv.axes(150, 490, 990, 760)
    loss_area(ax, c, RED, 0.13)
    xs, ys = zip(*c.curve)
    ax.plot(xs, ys, color=INK, linewidth=4.5, solid_joinstyle="miter", solid_capstyle="round", zorder=3)
    ax.plot([c.pay, c.recovered], [c.before] * 2, color=RED, linewidth=1.6, zorder=2)
    bracket(ax, c.pay - 900, c.after, c.before, RED, 3.5, -700)
    ax.text(c.pay - 2400, c.after + 800, f"{MINUS}{money(c.lost)}", fontproperties=font("ExtraBold"),
            fontsize=40, color=RED, ha="right", va="center")
    ax.text(c.pay - 2400, c.after - 1300, "for 1p more pay", fontproperties=font("Medium"),
            fontsize=19, color=RED, ha="right", va="center")
    for x, y in ((c.pay, c.before), (c.recovered, c.before)):
        ax.plot([x], [y], "o", color=INK, markersize=13, markeredgecolor=BG, markeredgewidth=3, zorder=5)
    ax.plot([c.pay], [c.after], "o", color=RED, markersize=13, markeredgecolor=BG, markeredgewidth=3, zorder=5)
    ax.annotate(f"{money(c.before)}\nat {money(c.pay)}", (c.pay, c.before), xytext=(-14, 16),
                textcoords="offset points", ha="right", va="bottom", fontproperties=font("SemiBold"), fontsize=19,
                color=INK, linespacing=1.3)
    ax.annotate(f"{money(c.after)} at {money(c.pay)}.01", (c.pay, c.after), xytext=(14, -12),
                textcoords="offset points", ha="left", va="top", fontproperties=font("SemiBold"), fontsize=19,
                color=RED)
    ax.annotate(f"Back to {money(c.before)}\nonly at {money(c.recovered)}", (c.recovered, c.before), xytext=(-8, 16),
                textcoords="offset points", ha="right", va="bottom", fontproperties=font("SemiBold"), fontsize=19,
                color=INK, linespacing=1.3)
    mid = (c.pay + c.recovered) / 2
    ax.text(mid, c.before - 1100, f"WORSE OFF THAN AT {money(c.pay)}", fontproperties=font("Bold"), fontsize=14,
            color=RED, ha="center", va="top")

    ax.set_xlim(80_000, 140_000)
    lo, hi = c.after - 5_000, c.before + 6_500
    ax.set_ylim(lo, hi)
    ax.set_yticks(range(math.ceil(lo / 5_000) * 5_000, int(hi), 5_000))
    ax.set_xticks(range(80_000, 140_001, 10_000))
    ax.grid(axis="y", color=GRID, linewidth=1.2)
    ax.set_axisbelow(True)
    ax.axhline(lo, color="#c9c6bf", linewidth=1.2, zorder=0)
    ax.xaxis.set_major_formatter(FuncFormatter(k))
    ax.yaxis.set_major_formatter(FuncFormatter(k))
    tick_labels(ax, MUTED, 17)
    ax.tick_params(axis="x", pad=10)
    cv.text(80, 462, "Take-home a year", 17, MUTED, "SemiBold")
    cv.text(1140, 1290, "Pay before tax, a year", 17, MUTED, "SemiBold", ha="right")
    footer(cv, MUTED, MUTED)
    cv.save(path)


# ---------------------------------------------------------------- B: hero number, dark


def draw_dark(c: Cliff, path: pathlib.Path) -> None:
    BG, INK, SUB, MUTED, GRID, RED = "#101318", "#f3f4f6", "#b4b9c2", "#7d838d", "#262b33", "#ff5d4f"
    cv = Canvas(BG)
    cv.text(80, 76, "Earn one penny over £100,000:", 30, INK, "SemiBold")
    cv.text(70, 132, f"{MINUS}{money(c.lost)}", 150, RED, "ExtraBold")
    cv.text(80, 372, "A single parent with a 2-year-old in England, 2026-27,\n"
                     "loses Tax-Free Childcare and 30 free hours a week.", 22, SUB, linespacing=1.45)

    ax = cv.axes(80, 500, 1040, 570)
    loss_area(ax, c, RED, 0.22)
    xs, ys = zip(*c.curve)
    ax.plot(xs, ys, color=INK, linewidth=4.5, solid_joinstyle="miter", solid_capstyle="round", zorder=3)
    ax.plot([c.pay, c.recovered], [c.before] * 2, color=RED, linewidth=1.6, zorder=2)
    for x, y, col in ((c.pay, c.before, INK), (c.recovered, c.before, INK), (c.pay, c.after, RED)):
        ax.plot([x], [y], "o", color=col, markersize=14, markeredgecolor=BG, markeredgewidth=3, zorder=5)
    bracket(ax, c.pay - 900, c.after, c.before, RED, 3.5, -700)
    ax.text(c.pay - 2300, c.after + 2500, f"{MINUS}{money(c.lost)}", fontproperties=font("Bold"),
            fontsize=24, color=RED, ha="right", va="center")
    ax.text((c.pay + c.recovered) / 2, c.before - 1100, "WORSE OFF", fontproperties=font("Bold"), fontsize=15,
            color=RED, ha="center", va="top")
    ax.set_xlim(80_000, 140_000)
    lo = c.after - 3_000
    ax.set_ylim(lo, c.before + 6_000)
    ax.set_yticks([])
    ax.set_xticks([80_000, c.pay, c.recovered, 140_000])
    ax.xaxis.set_major_formatter(FuncFormatter(lambda x, _: money(x) if x in (c.pay, c.recovered) else k(x)))
    ax.axhline(lo, color=GRID, linewidth=1.5, zorder=0)
    for x in (c.pay, c.recovered):
        ax.plot([x, x], [lo, c.before], color=GRID, linewidth=1.5, zorder=0)
    tick_labels(ax, MUTED, 17)
    ax.tick_params(axis="x", pad=10)
    cv.text(1120, 1120, "pay before tax", 16, MUTED, ha="right")

    # three numbers, the story in order
    cols = [(f"Pay {money(c.pay)}", money(c.before), INK), (f"Pay {money(c.pay)}.01", money(c.after), RED),
            (f"Pay {money(c.recovered)}", money(c.before), INK)]
    cv.rule(80, 1120, 1170, GRID, 1.5)
    for i, (label, value, col) in enumerate(cols):
        x = 80 + i * 360
        cv.text(x, 1192, label, 17, MUTED, "Medium")
        cv.text(x, 1220, value, 36, col, "Bold")
    cv.text(80, 1290, f"Take-home a year. Getting back to {money(c.before)} takes a {money(c.raise_needed)} raise.",
            17, SUB)
    footer(cv, MUTED, "#5c626c", y=1362)
    cv.save(path)


# ---------------------------------------------------------------- C: three bars, light


def draw_bars(c: Cliff, path: pathlib.Path) -> None:
    BG, INK, SUB, MUTED, RED, BAR = "#ffffff", "#16181d", "#4d5159", "#8a8f98", "#d23a2c", "#c9ccd2"
    cv = Canvas(BG)
    cv.text(80, 90, "Earn one penny over £100,000,", 47, INK, "ExtraBold")
    cv.runs(80, 162, [("lose ", INK), (money(c.lost) + ".", RED)], 47, "ExtraBold")
    cv.text(80, 262, "Take-home a year, single parent with a 2-year-old, England, 2026-27", 21, SUB)

    ax = cv.axes(80, 360, 1040, 800)
    bars = [(f"{money(c.pay)}", c.before, BAR), (f"{money(c.pay)}.01", c.after, RED),
            (f"{money(c.recovered)}", c.before, BAR)]
    xs = [0, 1, 2.45]
    width = 0.62
    for x, (label, v, col) in zip(xs, bars):
        ax.add_patch(Rectangle((x - width / 2, 0), width, v, color=col, linewidth=0))
        ax.text(x, v + 1500, money(v), fontproperties=font("Bold"), fontsize=30, color=INK, ha="center",
                va="bottom")
        ax.text(x, -3500, f"pay {label}", fontproperties=font("SemiBold"), fontsize=19, color=SUB, ha="center",
                va="top")
    # the drop, carried across from bar 1 to bar 2
    ax.plot([xs[0] + width / 2, xs[2] - width / 2], [c.before] * 2, color=RED, linewidth=1.5, zorder=0)
    bracket(ax, xs[1] + width / 2 + 0.06, c.after, c.before, RED, 3.5, -0.04)
    ax.text(xs[1] + width / 2 + 0.12, c.after + c.lost / 2, f"{MINUS}{money(c.lost)}",
            fontproperties=font("ExtraBold"), fontsize=30, color=RED, ha="left", va="center")
    # the pay rise it takes to get back: from bar 2 to bar 3, under the pay labels
    y = -11_500
    ax.annotate("", (xs[2], y), (xs[1], y), annotation_clip=False,
                arrowprops={"arrowstyle": "-|>,head_width=0.3,head_length=0.6", "color": RED, "linewidth": 2,
                            "shrinkA": 0, "shrinkB": 0})
    ax.text((xs[1] + xs[2]) / 2, y - 1600, f"a {money(c.raise_needed)} raise just to stand still",
            fontproperties=font("Bold"), fontsize=19, color=RED, ha="center", va="top")
    ax.set_xlim(-0.42, 2.87)
    ax.set_ylim(0, c.before * 1.12)
    ax.set_xticks([])
    ax.set_yticks([])
    ax.axhline(0, color=INK, linewidth=1.5)
    footer(cv, MUTED, MUTED, y=1370)
    cv.save(path)


DESIGNS = {"shaded": draw_shaded, "dark": draw_dark, "bars": draw_bars}
DESIGN = "shaded"  # the one in docs/cliff-100k.png
