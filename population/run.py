"""Print the synthetic population's summary for 2026-27, or the effect of other
figures (a parameter set) on it.

    uv run --project population population/run.py                      # baseline summary
    uv run --project population population/run.py --set personal_allowance_pence=1357000
    uv run --project population population/run.py --params reform.json --json
    uv run --project population population/run.py docs                 # rewrite docs/population.md

`--set` and `--params` take the fields of the engine's parameter set (see the
top of Main.lean, `paramFields`: money in pence, rates in basis points,
`uc_taper_percent` in per cent). Every figure printed is a synthetic estimate:
invented households weighted to published totals, not real households, and
only the per-household calculation is proved. See docs/population.md.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys
import time

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import model  # noqa: E402

DOCS = model.ROOT / "docs" / "population.md"
N_DEFAULT = 30_000
SEEDS = (1, 2, 3, 4, 5)

REFORMS = [
    ("pa_plus_1000", "Personal allowance £12,570 → £13,570 (basic rate limit unchanged)",
     {"personal_allowance_pence": 1_357_000}),
    ("basic_rate_21", "Basic rate 20 % → 21 % on non-savings income (UK rates; Scottish rates unchanged)",
     {"basic_rate_bp": 2_100}),
    ("taper_125k", "Personal allowance taper starts at £125,000 instead of £100,000",
     {"personal_allowance_income_limit_pence": 12_500_000}),
    ("uc_taper_50", "Universal Credit taper 55 % → 50 %",
     {"uc_taper_percent": 50}),
]


def bn(x: float) -> str:
    return f"£{x / 1e9:,.1f}bn"


def th(x: float) -> str:
    """A count in thousands, rounded to the nearest thousand."""
    return f"{x / 1e3:,.0f}k"


def summary(pop: model.Population) -> dict:
    return {"aggregates": model.aggregates(pop), "cliffs": model.cliff_exposure(pop)}


def print_summary(pop, s, out=sys.stdout):
    a, c = s["aggregates"], s["cliffs"]
    p = lambda *x: print(*x, file=out)  # noqa: E731
    p(f"Synthetic estimate, 2026-27 ({len(pop.units):,} synthetic benefit units, seed {pop.seed})")
    p(f"  benefit units {th(a['units'])}, adults {th(a['adults'])}, taxpayers {th(a['taxpayers'])}")
    p(f"  income tax {bn(a['income_tax'])}; employee NICs {bn(a['nic_employee_class1_and_4'])}; "
      f"employer NICs {bn(a['nic_employer'])}")
    p(f"  Universal Credit {bn(a['universal_credit'])}; Child Benefit {bn(a['child_benefit'])}; "
      f"HICBC {bn(a['hicbc'])}; Carer's Allowance {bn(a['carers_allowance'])}")
    p("  cliffs:")
    p(f"    working families with a child under 12, ANI £95,000-£100,000: {th(c['childcare_below_cliff'])}; "
      f"just over (£100,000-£105,000): {th(c['childcare_above_cliff'])}")
    p(f"    Child Benefit families in the HICBC band (£60,000-£80,000): {th(c['hicbc_band'])}")
    p(f"    carers within £20 a week below the Carer's Allowance limit: {th(c['carers_within_20_below_limit'])}")
    p(f"    people in the personal allowance taper (£100,000-£125,140): {th(c['pa_taper_people'])}")


def print_reform(r, out=sys.stdout):
    p = lambda *x: print(*x, file=out)  # noqa: E731
    p(f"Synthetic estimate of the change from 2026-27 figures: {json.dumps(r['params'])}")
    sb = lambda x: ("+" if x >= 0 else "-") + bn(abs(x))  # noqa: E731
    p(f"  cost to the Exchequer {bn(r['cost'])}: income tax {sb(r['income_tax_change'])}, "
      f"employee NICs {sb(r['nic_change'])}, HICBC {sb(r['hicbc_change'])}, "
      f"Universal Credit paid {sb(r['uc_change'])}")
    p(f"  benefit units better off {th(r['winners'])} (mean £{r['mean_gain_winners']:,.0f} a year), "
      f"worse off {th(r['losers'])} (mean £{-r['mean_loss_losers']:,.0f} a year), unchanged {th(r['unchanged'])}")


def parse_sets(items) -> dict:
    out = {}
    for item in items or []:
        k, _, v = item.partition("=")
        out[k] = int(v)
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description="Synthetic population summary (2026-27)")
    ap.add_argument("command", nargs="?", default="summary", choices=["summary", "docs"])
    ap.add_argument("--n", type=int, default=N_DEFAULT, help="synthetic benefit units (default 30000)")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--binary", default=str(model.DEFAULT_BINARY))
    ap.add_argument("--params", help="JSON file with a parameter set")
    ap.add_argument("--set", action="append", metavar="FIELD=VALUE", help="one parameter (repeatable)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    if args.command == "docs":
        write_docs(args.n, args.binary)
        return
    params = {}
    if args.params:
        params.update(json.loads(pathlib.Path(args.params).read_text()))
    params.update(parse_sets(args.set))
    pop = model.build(args.n, args.seed, args.binary)
    if params:
        r = model.reform(pop, params, args.binary)
        if args.json:
            print(json.dumps({k: v for k, v in r.items() if k != "delta"}, indent=1))
        else:
            print_reform(r)
    else:
        s = summary(pop)
        if args.json:
            print(json.dumps(s, indent=1))
        else:
            print_summary(pop, s)


# ----------------------------------------------------------------- the docs


def _spread(values):
    return min(values), max(values)


def _range(values, fmt):
    lo, hi = _spread(values)
    return fmt(lo) if fmt(lo) == fmt(hi) else f"{fmt(lo)} to {fmt(hi)}"


def write_docs(n: int, binary) -> None:
    t0 = time.time()
    runs = []
    for seed in SEEDS:
        pop = model.build(n, seed, binary)
        s = summary(pop)
        reforms = {key: model.reform(pop, params, binary) for key, _, params in REFORMS}
        extra = untargeted(pop)
        runs.append((pop, s, reforms, extra))
        print(f"seed {seed} done ({time.time() - t0:.0f}s)", file=sys.stderr)
    DOCS.write_text(render(runs, n))
    print(f"wrote {DOCS}", file=sys.stderr)


def untargeted(pop: model.Population) -> dict:
    """Figures the weights were not fitted to, to compare with published ones."""
    w = pop.weights
    out = {"higher": 0.0, "additional": 0.0, "basic": 0.0}
    for wi, u in zip(w, pop.units):
        for a, p in zip(u.adults, u.out["people"]):
            if p["tax"] <= 0:
                continue
            if p["step3"] > 125_140:
                out["additional"] += wi
            elif p["step3"] > 37_700:
                out["higher"] += wi
            else:
                out["basic"] += wi
    total = float(w.sum())
    for ten in ("owned", "social", "private"):
        out[f"tenure_{ten}"] = float(sum(wi for wi, u in zip(w, pop.units) if u.tenure == ten)) / total
    out["design_effect"] = float(len(w) * (w @ w) / w.sum() ** 2)
    ratio = w / np.array([u.design_weight for u in pop.units])
    out["ratio_p1"], out["ratio_p99"] = (float(x) for x in np.percentile(ratio, [1, 99]))
    return out


def render(runs, n: int) -> str:
    pop0, s0, r0, e0 = runs[0]
    m = pop0.margins
    hm, dwp = m["hmrc"], m["dwp"]
    agg = [r[1]["aggregates"] for r in runs]
    cl = [r[1]["cliffs"] for r in runs]
    L = []
    w = L.append
    w("# A synthetic population for 2026-27")
    w("")
    w("> **Every figure on this page is a synthetic estimate.** The households are invented, not")
    w("> real ones; they are weighted to published totals from open statistics. Only the")
    w("> calculation for each household (`uktax`, the proved Lean model) is proved; the")
    w("> population itself (which households exist, their incomes, their weights) is ordinary")
    w("> statistical code in `population/`, and is not. The figures are rough: see")
    w("> [How rough](#how-rough).")
    w("")
    w("Generated by `uv run --project population population/run.py docs` "
      f"({n:,} synthetic benefit units, seeds {', '.join(map(str, SEEDS))}). Where a figure is given as a")
    w("range, it is the lowest and highest over the five seeds; a single figure is the same in all five")
    w("at the rounding shown. Do not edit by hand.")
    w("")
    w("## What this is and isn't")
    w("")
    w("- **Synthetic, not real households.** No survey or administrative record is used: no Family")
    w("  Resources Survey, no Survey of Personal Incomes microdata, nothing from the UK Data Service.")
    w("  The households are drawn by rules (`population/model.py`) from published tables, and then")
    w("  weighted so that their totals match those tables.")
    w("- **Open data only.** Every source is published under the Open Government Licence v3.0 and")
    w("  downloaded without an account or key (list below). `population/fetch.py` downloads them and")
    w("  extracts the figures into `population/margins.json`, with each file's SHA-256.")
    w("- **Rough.** The published totals fix how many households of each kind there are and how")
    w("  many taxpayers in each income range, but not how incomes combine within a household. That")
    w("  comes from assumptions (below), and it matters most for the cliffs.")
    w("- **Proved per household, not as a population.** Each household's income tax, NICs, HICBC,")
    w("  Child Benefit, Universal Credit and Carer's Allowance come from `uktax`. The weights,")
    w("  totals and counts are statistics, with no proof.")
    w("- **The unit is the benefit unit**: a single adult or a couple, with their dependent")
    w("  children. A household of several adults (grown-up children, sharers) is several units here.")
    w(f"  There are about {th(agg[0]['units'])} units against {th(m['ons']['families_2025']['households'])} "
      "households (ONS, 2025).")
    w("")
    w("## Sources")
    w("")
    w("| Source | Publisher | Licence | Used for |")
    w("|---|---|---|---|")
    used = {
        "hmrc_t2_5": "taxpayers by income range (target); tax and income by range (check)",
        "hmrc_t2_2": "taxpayers by country (target)",
        "hmrc_t2_1": "taxpayers over State Pension age (target); by marginal rate (check)",
        "hmrc_t3_6": "income from work and pensions by range: how each person's income is split",
        "hmrc_t3_7": "income from property, interest and dividends by range: the same",
        "hmrc_cb": "Child Benefit families by size, opted out, children by age (targets)",
        "hmrc_receipts": "income tax and NICs receipts 2025-26 (check)",
        "hmrc_trr": "costs of illustrative changes (check of the reforms)",
        "dwp_bect": "Universal Credit, Carer's Allowance caseloads (targets); spending forecasts (check)",
        "ons_families": "families by type and number of children (targets), households (check)",
        "ons_mye": "adults by country and age (targets), ages (draws)",
        "census_tenure": "tenure (check)",
        "uc_share_with_children_aug_2026": "share of UC households with children (target)",
        "private_rent_uk_monthly_oct_2026": "private rents (draws)",
        "private_rent_london_monthly_oct_2026": "private rents in London (draws)",
        "social_rent_weekly_england_2025_26": "social rents (draws)",
    }
    for sid, src in m["sources"].items():
        w(f"| [{src['title']}]({src['url']}) | {src['publisher']} | [OGL v3.0]({src['licence_url']}) | {used.get(sid, '')} |")
    w("")
    w("Nothing needed an account or key: the DWP's Stat-Xplore was not used (its tables need")
    w("registration for the API); its published release text gives the one Universal Credit split")
    w("used. Retrieved 2026-11-27.")
    w("")
    w("## How the population is built")
    w("")
    w(f"1. **Draw** {n:,} benefit units: single adults, couples, lone parents and couples with 1, 2 or")
    w("   3+ children, people over 66 (pensioners), in the proportions of the ONS family counts.")
    w("   Country and London by population. Children's ages from Child Benefit's single-year counts.")
    w("2. **Incomes.** A working adult draws an income range from HMRC's 2026-27 projection (Table 2.5),")
    w("   or an income below the personal allowance; within the range, from a curve with the range's")
    w("   published mean income. The income is split into pay or self-employment, property, interest")
    w("   and dividends by that range's shares (HMRC Tables 3.6 and 3.7, 2023-24); workers aged 55 to 65")
    w("   may also draw a private pension. People over 66 get a")
    w("   State Pension near the full new rate and the rest from their own range draw. Employees paid")
    w("   £10,000 or more pay the automatic-enrolment minimum (5 % of qualifying earnings) by net pay.")
    w("   The ranges above £100,000 are drawn more often and weighted down, so each has enough units.")
    w("3. **Housing, caring, health.** Tenure by income and age; private rents around ONS's average")
    w("   (London's in London), with a Local Housing Allowance below it; social rents around the")
    w("   Regulator's average. Some low earners are carers; some adults not in work have limited")
    w("   capability for work. Families register for Child Benefit, and high earners opt out, by")
    w("   assumption; Universal Credit is claimed by 87 % of those entitled.")
    w("4. **Compute** every adult with `uktax` (`.lake/build/bin/uktax`): partners first, then the")
    w("   head, whose Universal Credit claim counts the partner's net earnings and any Carer's Allowance.")
    w("5. **Weight** the units by minimum-entropy calibration: weights as close as possible to the")
    w("   design weights such that the weighted totals equal the published targets (next section).")
    w("   Taxpayer counts, Universal Credit, Child Benefit and Carer's Allowance counts use the")
    w("   engine's results, so the weights are fitted after the calculation.")
    w("")
    w("Money totals (tax, NICs, benefit spending) are **not** targets. They are the check.")
    w("")
    w("## Calibration fit")
    w("")
    max_err = max(float(np.max(np.abs(p.fitted - np.array([t[1] for t in p.targets])) / np.array([t[1] for t in p.targets])))
                  for p, *_ in runs)
    w(f"All {len(pop0.targets)} targets are met to within {max_err:.1e} (relative) in every seed. The weights")
    w(f"stay within 1/25 and 25 times the design weights by construction; the 1st to 99th percentiles")
    w(f"of the ratio are {e0['ratio_p1']:.2f} to {e0['ratio_p99']:.2f} (seed 1), and the design effect of the")
    w(f"weights is {_range([r[3]['design_effect'] for r in runs], lambda x: f'{x:.2f}')}.")
    w("")
    w("| Target | Published | Synthetic (seed 1) | Source |")
    w("|---|--:|--:|---|")
    for (name, val, src), fit in zip(pop0.targets, pop0.fitted):
        w(f"| {name} | {val / 1e3:,.0f}k | {fit / 1e3:,.0f}k | {src} |")
    w("")
    w("Figures the weights were not fitted to:")
    w("")
    rate = hm["taxpayers_by_rate_2026_27"]
    ten = m["ons"]["tenure_census_2021_england_wales"]
    ex = [r[3] for r in runs]
    w("| Figure | Published | Synthetic estimate |")
    w("|---|--:|--:|")
    w(f"| basic rate taxpayers (incl. savers) | {th(rate['basic'] + rate['savers'])} | {_range([e['basic'] for e in ex], th)} |")
    w(f"| higher rate taxpayers | {th(rate['higher'])} | {_range([e['higher'] for e in ex], th)} |")
    w(f"| additional rate taxpayers | {th(rate['additional'])} | {_range([e['additional'] for e in ex], th)} |")
    for k, label in (("owned", "owner-occupied"), ("social", "social rented"), ("private", "private rented")):
        pub = ten["owned" if k == "owned" else "social_rented" if k == "social" else "private_rented"] / ten["all"]
        w(f"| {label} (share; Census 2021 households, England and Wales, against all units) | {pub:.0%} | "
          f"{_range([e['tenure_' + k] for e in ex], lambda x: f'{x:.0%}')} |")
    w("")
    w("The marginal rate here is from the engine's Step 3 income against the UK limits, so Scottish")
    w("taxpayers are classed by the UK bands; HMRC classes them by their own.")
    w("")
    w("## Totals against outturn and forecasts")
    w("")
    rec = hm["receipts_2025_26"]
    w("| | Synthetic estimate 2026-27 | Published | Gap (seed 1) |")
    w("|---|--:|--:|--:|")

    def gap(x, ref):
        return f"{100 * (x / ref - 1):+.0f} %"
    rows = [
        ("Income tax", "income_tax", hm["taxpayers_all_ranges_2026_27"]["liability"],
         "HMRC projected liabilities 2026-27 (Table 2.5)"),
        ("Employee NICs (Class 1 and Class 4)", "nic_employee_class1_and_4", rec["class1_employee"] + rec["sa_class2_4"],
         "HMRC receipts 2025-26: Class 1 employee + SA Class 2 and 4"),
        ("Employer Class 1 NICs", "nic_employer", rec["class1_employer"], "HMRC receipts 2025-26"),
        ("Universal Credit", "universal_credit", dwp["uc_spend"], "DWP forecast 2026-27"),
        ("Child Benefit", "child_benefit", dwp["child_benefit_spend"], "DWP/HMRC forecast 2026-27"),
        ("Carer's Allowance", "carers_allowance", dwp["carers_allowance_spend"], "DWP forecast 2026-27"),
    ]
    for label, key, ref, src in rows:
        w(f"| {label} | {_range([a[key] for a in agg], bn)} | {bn(ref)} ({src}) | {gap(agg[0][key], ref)} |")
    w(f"| HICBC | {_range([a['hicbc'] for a in agg], bn)} | no open table fetched | |")
    w("")
    w("What the gaps mean:")
    w("")
    w("- **Income tax** is a few per cent high. The income in each HMRC range matches HMRC's within")
    w("  a per cent or two (it is drawn to), so the excess is in the deductions: only the")
    w("  automatic-enrolment minimum pension contribution is modelled, not larger contributions, salary")
    w("  sacrifice, relief at source, Gift Aid, losses, the Marriage Allowance or the married")
    w("  couple's allowance. Receipts also differ from liabilities by timing.")
    w("- **NICs** are well above 2025-26 receipts. Pay is somewhat high (pay is the residual of each")
    w("  range's income after other sources), salary sacrifice is not modelled, and the employer")
    w("  figure ignores the Employment Allowance (up to £10,500 per employer) and the lag of receipts")
    w("  after the April 2025 rise. Employer NICs are on this population's pay only.")
    w("- **Universal Credit** is high. Every claimant with the health element is given the protected")
    w("  (higher) rate; rents and the 87 % take-up are assumptions; capital, the minimum income")
    w("  floor, the disabled child elements and childcare costs are not modelled; and UC households are")
    w("  only those whose adults have pay or a trade alone.")
    w("- **Child Benefit**: the engine pays 53 weeks in 2026-27 (53 Mondays); the forecast is a")
    w("  spending figure. Families are fitted to August 2025 counts.")
    w("")
    w("## Cliffs: how many households sit near each")
    w("")
    w("Counts of benefit units (people where stated), synthetic estimates:")
    w("")
    w("| Cliff | Synthetic estimate |")
    w("|---|--:|")
    w(f"| Working families with a child under 12 and a parent's adjusted net income £95,000 to £100,000 (just below the £100,000 childcare limit: Tax-Free Childcare and the working-parent funded hours) | {_range([c['childcare_below_cliff'] for c in cl], th)} |")
    w(f"| the same, £100,000 to £105,000 (just above it) | {_range([c['childcare_above_cliff'] for c in cl], th)} |")
    w(f"| the same with a child aged 0 to 4 (funded hours), just below | {_range([c['funded_hours_below_cliff'] for c in cl], th)} |")
    w(f"| working families with a child under 12 over the limit (all) | {_range([c['childcare_families_over_limit'] for c in cl], th)} |")
    w(f"| Child Benefit families with a parent's adjusted net income in the HICBC band (£60,000 to £80,000) | {_range([c['hicbc_band'] for c in cl], th)} |")
    w(f"| Child Benefit families paying the HICBC | {_range([c['hicbc_paying'] for c in cl], th)} |")
    w(f"| Carers on Carer's Allowance with net earnings within £20 a week below the £204 limit (people) | {_range([c['carers_within_20_below_limit'] for c in cl], th)} |")
    w(f"| Carers just over the limit, within £20 a week, who lose it (people) | {_range([c['carers_within_20_above_limit'] for c in cl], th)} |")
    w(f"| People in the personal allowance taper (£100,000 to £125,140, a 60 % marginal rate) | {_range([c['pa_taper_people'] for c in cl], th)} |")
    w(f"| People £0 to £5,000 below the taper (£95,000 to £100,000) | {_range([c['pa_taper_within_5k_below'] for c in cl], th)} |")
    w(f"| Universal Credit households in work (on the 55 % taper) | {_range([c['uc_in_work'] for c in cl], th)} |")
    w("")
    w("The childcare counts need both parents (or the lone parent) to earn at least the minimum")
    w("(£10,574.72 a year), and do not ask whether the family uses paid childcare: they count who is")
    w("exposed, not who loses. How much each loses is in [`cliffs.md`](cliffs.md) for typical")
    w("households. How high earners pair with each other in a couple is an assumption here (they are")
    w("drawn independently), and these counts move with it: treat them as an order of magnitude.")
    w("")
    w("## Changing the figures")
    w("")
    w("The same population, run again with other figures (the parameter set of PR #33 and #34, passed")
    w("to `uktax` as `params`). Cost is to the Exchequer: the rise in households' net income (income")
    w("less income tax, employee NICs and the HICBC, plus Child Benefit, Universal Credit and Carer's")
    w("Allowance). No behaviour changes.")
    w("")
    w("| Change | Cost (synthetic estimate; negative raises money) | Better off | Worse off | Mean gain of those better off |")
    w("|---|--:|--:|--:|--:|")
    for key, label, params in REFORMS:
        rs = [r[2][key] for r in runs]
        w(f"| {label} | {_range([r['cost'] for r in rs], bn)} | {_range([r['winners'] for r in rs], th)} | "
          f"{_range([r['losers'] for r in rs], th)} | {_range([r['mean_gain_winners'] for r in rs], lambda x: f'£{x:,.0f}')} |")
    w("")
    rr = hm["ready_reckoner"]
    w("Checks against HMRC's ready reckoner (June 2025; receipts, so the first year is lower than a")
    w("full year's liabilities):")
    w("")
    w(f"- personal allowance +£1,000: ten times HMRC's £100 figure is {bn(10 * rr['personal_allowance_100']['2026_27'])} "
      f"(2026-27) and {bn(10 * rr['personal_allowance_100']['2027_28'])} (2027-28), against "
      f"{_range([r[2]['pa_plus_1000']['cost'] for r in runs], bn)} here. A little comes back through")
    w("  Universal Credit, whose award falls by 55 % of the rise in a claimant's net earnings.")
    w(f"- basic rate +1p: HMRC {bn(rr['basic_rate_1p']['2026_27'])} (2026-27) and "
      f"{bn(rr['basic_rate_1p']['2027_28'])} (2027-28), against "
      f"{_range([-r[2]['basic_rate_21']['cost'] for r in runs], bn)} raised here. Here the savings rate")
    w("  is unchanged, and Universal Credit makes up part of what its claimants lose.")
    w("")
    w("By hand: a basic rate taxpayer with income over £13,570 gains £200 from a £1,000 higher")
    w("allowance, a higher rate taxpayer £400 (the higher rate threshold moves up with it), and")
    w(f"someone in the taper gains up to £400; with about {th(rate['all'])} taxpayers that is roughly")
    w("£8bn to £10bn. Starting the taper at £125,000 helps only adjusted net incomes between £100,000")
    w("and £150,140 (where the allowance now runs out); HMRC has "
      f"{th(next(r['taxpayers'] for r in hm['taxpayers_by_range_2026_27'] if r['lower'] == 100_000))} "
      "taxpayers between £100,000 and £150,000. The")
    w("most, at £125,000, is £12,500 more allowance at 40 %, £5,000; the average is about half that.")
    w("")
    w("To run another set:")
    w("")
    w("```sh")
    w("uv run --project population population/run.py --set personal_allowance_pence=1357000")
    w("uv run --project population population/run.py --params my-figures.json --json")
    w("```")
    w("")
    w("## How rough")
    w("")
    w("Three kinds of uncertainty, largest first:")
    w("")
    w("1. **Assumptions where no open table exists.** How incomes pair within couples (independent")
    w("   here), who opts out of Child Benefit, who claims Universal Credit, who is a carer or has")
    w("   limited capability for work, tenure and rents, and how investment income splits between")
    w("   working-age people and pensioners. The weights fix the totals, not these joint patterns.")
    w("   Counts of small groups near a cliff can be out by a factor of two; national money totals")
    w("   by a few per cent to a few tens of per cent (see the gaps above).")
    w("2. **The published figures themselves.** HMRC's 2026-27 income figures are projections from")
    w("   the 2023-24 Survey of Personal Incomes; ONS family counts are Labour Force Survey estimates")
    w("   with 95 % intervals of about ±1 % to ±10 %; the income splits by source are 2023-24's; the")
    w("   Child Benefit counts are August 2025's.")
    w("3. **Sampling of the synthetic units.** The ranges over five seeds above show it: small for")
    w("   totals, larger for the cliff counts.")
    w("")
    w("## Known weaknesses, and what would improve them most")
    w("")
    w("- **Couples' incomes are drawn independently.** This matters most for the £100,000 and HICBC")
    w("  cliffs. An open table of couples' joint incomes (for example ONS's published household")
    w("  income distributions by family type) would give a target for it.")
    w("- **Pension Credit, Housing Benefit, council tax and its reductions, disability benefits,")
    w("  Tax-Free Childcare and the funded hours are not in the totals**, though the engine computes")
    w("  them. Adding Pension Credit and PIP flags would cover most of the remaining spending.")
    w("- **Deductions**: only the automatic-enrolment minimum. HMRC's private pension statistics")
    w("  (open) would let contributions above the minimum and relief at source be fitted.")
    w("- **Universal Credit**: no capital, no minimum income floor, no disabled child elements, no")
    w("  childcare costs; every health element at the protected rate. DWP's published element counts")
    w("  could be added as targets one by one.")
    w("- **Regions**: only the four countries and London, which is all the engine needs except for")
    w("  rents.")
    w("")
    w("## Running it")
    w("")
    w("```sh")
    w("lake build uktax                                   # the engine")
    w("python3 population/fetch.py                        # optional: download the sources again")
    w("uv run --project population population/run.py      # baseline summary")
    w("uv run --project population python -m unittest discover -s population/tests")
    w("uv run --project population population/run.py docs # this page")
    w("```")
    w("")
    return "\n".join(L)


if __name__ == "__main__":
    main()
