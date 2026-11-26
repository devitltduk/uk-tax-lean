"""The 1200 x 1500 image for docs/drafts/linkedin.png: pension relief at source.

A worker pays £1,600 into a personal pension (a relief-at-source scheme); the
provider claims £400 from HMRC, so £2,000 goes in. In law that £400 is the
worker's whatever they earn (FA 2004 s192(1)-(3)). PolicyEngine UK instead
deducts the £2,000 from taxable income, which is worth nothing to someone with
no tax to pay. The chart plots, against pay, the tax relief on that £2,000 in law
(from the uktax model: 20 % at source plus any fall in the liability from the
raised rate limits) and in PolicyEngine UK 2.180.2 (the fall in its income tax),
and shades the relief PolicyEngine leaves out.

    lake build && cd harness && uv run --frozen python linkedin.py

The style is the shared
cliff image's: Inter (harness/fonts, SIL Open Font License), 4:5.
"""

from __future__ import annotations

import json
import pathlib
import subprocess

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.font_manager import FontProperties  # noqa: E402
from matplotlib.ticker import FuncFormatter  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
FONTS = HERE / "fonts"
W, H, DPI = 1200, 1500, 100
HANDLE = "‹ link ›"
YEAR = 2026
GROSS = 2_000  # pounds, gross contribution
PAYS = list(range(0, 25_001, 100))


def font(weight: str) -> FontProperties:
    return FontProperties(fname=FONTS / f"Inter-{weight}.ttf")


def money(x: float) -> str:
    return f"£{round(x):,}"


def law_relief() -> list[float]:
    """Relief in law, from the model: 20 % at source plus the fall in liability."""
    payload = []
    for p in PAYS:
        base = {"non_savings_pence": p * 100, "savings_pence": 0, "dividends_pence": 0, "employment_pence": p * 100}
        payload += [base, {**base, "pension_relief_at_source_gross_pence": GROSS * 100}]
    out = json.loads(subprocess.run([str(ROOT / ".lake/build/bin/uktax")], input=json.dumps(payload),
                                    capture_output=True, text=True, check=True).stdout)
    return [0.2 * GROSS + (a["tax_exact_ten_thousandths_pence"] - b["tax_exact_ten_thousandths_pence"]) / 1e6
            for a, b in zip(out[::2], out[1::2])]


def pe_relief() -> list[float]:
    """Relief in PolicyEngine: the fall in its income tax."""
    from policyengine_uk import Simulation

    def tax(contrib: float) -> list[float]:
        people = {f"p{i}": {"age": {YEAR: 40}, "employment_income": {YEAR: p},
                            "personal_pension_contributions": {YEAR: contrib}} for i, p in enumerate(PAYS)}
        sim = Simulation(situation={
            "people": people,
            "benunits": {f"b{i}": {"members": [f"p{i}"]} for i in range(len(PAYS))},
            "households": {f"h{i}": {"members": [f"p{i}"], "region": {YEAR: "LONDON"}} for i in range(len(PAYS))},
        })
        return [float(x) for x in sim.calculate("income_tax", YEAR)]

    return [a - b for a, b in zip(tax(0), tax(GROSS))]


def main() -> None:
    law, pe = law_relief(), pe_relief()
    at = dict(zip(PAYS, zip(law, pe)))
    l12, p12 = at[12_000]
    # first pay (on the £100 grid) from which they agree: £12,570 + £2,000 rounded up
    full = next(p for p, (lv, pv) in zip(PAYS, zip(law, pe)) if p >= 12_570 and abs(lv - pv) < 0.01)
    full = 12_570 + GROSS if full - 100 < 12_570 + GROSS <= full else full
    print(json.dumps({"law_at_12000": round(l12, 2), "pe_at_12000": round(p12, 2),
                      "pe_at_13570": round(at[13_600][1], 2), "agree_from": full}))

    BG, INK, SUB, MUTED, GRID, RED = "#fbfaf7", "#16181d", "#4d5159", "#8a8f98", "#e6e4df", "#d23a2c"
    fig = plt.figure(figsize=(W / DPI, H / DPI), dpi=DPI, facecolor=BG)

    def text(x, y, s, size, color, weight="Regular", **kw):
        return fig.text(x / W, 1 - y / H, s, fontproperties=font(weight), fontsize=size, color=color,
                        va=kw.pop("va", "top"), **kw)

    text(80, 84, "PERSONAL PENSION · RELIEF AT SOURCE · 2026-27", 15.5, SUB, "SemiBold")
    text(80, 124, "Low earners get the", 58, INK, "ExtraBold")
    text(80, 210, "20% top-up too.", 58, RED, "ExtraBold")
    text(80, 316, f"Pay {money(GROSS * 0.8)} into a pension and the provider adds {money(GROSS * 0.2)},\n"
                  f"whatever you earn. PolicyEngine UK gives none below\n"
                  f"{money(12_570)} of pay, and the full {money(GROSS * 0.2)} only from {money(full)}.", 25, SUB, linespacing=1.45)

    ax = fig.add_axes((150 / W, 1 - (530 + 700) / H, 990 / W, 700 / H))
    ax.set_facecolor("none")
    for s in ax.spines.values():
        s.set_visible(False)
    ax.tick_params(length=0)
    ax.fill_between(PAYS, pe, law, where=[lv - pv > 0.005 for lv, pv in zip(law, pe)], color=RED, alpha=0.13,
                    linewidth=0, zorder=1)
    ax.plot(PAYS, law, color=INK, linewidth=4.5, zorder=3)
    ax.plot(PAYS, pe, color=RED, linewidth=3, linestyle=(0, (4, 2)), zorder=3)
    ax.text(1_000, l12 + 22, f"The law: {money(l12)} at any pay", fontproperties=font("SemiBold"), fontsize=19,
            color=INK, va="bottom")
    ax.text(5_500, 140, f"RELIEF MISSING\nup to {money(l12 - p12)}", fontproperties=font("Bold"), fontsize=15,
            color=RED, ha="center", va="center", linespacing=1.4)
    ax.annotate("PolicyEngine UK:\nnothing until pay\npasses £12,570", (12_570, 0), xytext=(15_200, 60),
                ha="left", va="bottom", fontproperties=font("SemiBold"), fontsize=19, color=RED, linespacing=1.3,
                arrowprops={"arrowstyle": "-", "color": RED, "linewidth": 1.4})
    ax.set_xlim(0, 25_000)
    ax.set_ylim(-20, 480)
    ax.set_yticks(range(0, 401, 100))
    ax.set_xticks(range(0, 25_001, 5_000))
    ax.grid(axis="y", color=GRID, linewidth=1.2)
    ax.set_axisbelow(True)
    ax.xaxis.set_major_formatter(FuncFormatter(lambda x, _: f"£{x / 1000:,.0f}k"))
    ax.yaxis.set_major_formatter(FuncFormatter(lambda x, _: f"£{x:,.0f}"))
    for t in ax.get_xticklabels() + ax.get_yticklabels():
        t.set_fontproperties(font("Regular"))
        t.set_fontsize(17)
        t.set_color(MUTED)
    ax.tick_params(axis="x", pad=10)
    text(80, 492, f"Tax relief on {money(GROSS)} going into the pension", 17, MUTED, "SemiBold")
    text(1140, 1290, "Pay before tax, a year", 17, MUTED, "SemiBold", ha="right")
    text(80, 1360, "2026-27, England. Law: Finance Act 2004 s192, from an exact model of the rules.", 13.5, MUTED)
    text(80, 1386, "Model: PolicyEngine UK 2.180.2, the fall in income tax from the contribution.", 13.5, MUTED)
    text(80, 1430, HANDLE, 15, MUTED, "SemiBold")
    out = ROOT / "docs/drafts/linkedin.png"
    fig.savefig(out, dpi=DPI, facecolor=BG, metadata={"Software": None})
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
