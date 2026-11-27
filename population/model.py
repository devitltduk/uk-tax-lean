"""A synthetic population of UK benefit units for 2026-27, built from open
statistics only, computed household by household with the proved `uktax`
engine and weighted to published totals.

What is proved and what is not: each household's income tax, NICs, HICBC,
Child Benefit, Universal Credit and Carer's Allowance come from `uktax`, the
Lean model whose guarantees are in the README. Everything in this file is
ordinary statistical code and is NOT proved: which households exist, their
incomes, the weights, and the totals. The households are invented; none is a
real household or a record from any survey.

The unit is the benefit unit (a single adult or a couple, with their
dependent children), the unit tax credits, Universal Credit and Child Benefit
are assessed on. "Household" in the outputs means a benefit unit.

Steps:

1. `generate`: draw benefit units from rules set by the published figures in
   `margins.json` (family types, ages, country, incomes by HMRC income band
   and source, tenure, rent, caring, disability). Seeded; the same seed gives
   the same units on any machine (only `random.Random.random` is used).
2. `run_engine`: one `uktax` call per adult, in two passes (partners first, so
   a Universal Credit claim can count the partner's net earnings).
3. `calibrate`: minimum-entropy weights, close to the design weights, that
   reproduce the published totals (`targets`): people by country and age,
   family types, children by age, taxpayers by income band and country,
   Universal Credit households, Child Benefit families, Carer's Allowance.
   Money totals (tax, NICs, benefit spending) are not targets: they are the
   check (`aggregates`).
"""

from __future__ import annotations

import json
import math
import pathlib
import random
import subprocess
from dataclasses import dataclass, field

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
DEFAULT_BINARY = ROOT / ".lake/build/bin/uktax"
MARGINS = HERE / "margins.json"

# 2026-27 figures used to build inputs (the engine has its own copies for the
# calculation itself; these only shape the synthetic households).
FULL_NEW_STATE_PENSION = 241.30 * 52  # £ a year, SI 2026/xx uprating (4.8 %)
SOCIAL_RENT_UPRATING = 1.048  # 2026-27 social rent cap, CPI (Sept 2025) + 1 %
CHILDCARE_LIMIT = 100_000  # £ adjusted net income (Params.childcareIncomeLimit)
CHILDCARE_MIN_EARNINGS = 4 * 2_643.68  # £ (Params.childcareMinimumEarnings)
HICBC_START, HICBC_END = 60_000, 80_000
CA_EARNINGS_LIMIT_WEEKLY = 204.00  # £ (Params.caEarningsLimit)
UC_TAKEUP = 0.87  # share of entitled benefit units that claim (assumption)
PENSION_AGE = 66

COUNTRIES = ("england", "wales", "scotland", "northern_ireland")


def load_margins(path=MARGINS) -> dict:
    return json.loads(pathlib.Path(path).read_text())


# ---------------------------------------------------------------- generation


@dataclass
class Adult:
    age: int
    pay: float = 0.0
    profit: float = 0.0
    state_pension: float = 0.0
    other_pension: float = 0.0
    property_income: float = 0.0
    interest: float = 0.0
    dividends: float = 0.0
    carer: bool = False
    lcwra: bool = False
    net_pay_pension: float = 0.0  # part of pay, deducted before income tax

    @property
    def gross(self) -> float:
        return (self.pay + self.profit + self.state_pension + self.other_pension
                + self.property_income + self.interest + self.dividends)

    @property
    def pay_or_trade_only(self) -> bool:
        return (self.state_pension + self.other_pension + self.property_income
                + self.interest + self.dividends) == 0


@dataclass
class Unit:
    kind: str  # single, couple, lone_parent, couple_children; plus _pensioner
    adults: list[Adult]
    children: list[int]  # ages
    country: str
    london: bool
    tenure: str  # owned, social, private
    rent_monthly: float = 0.0
    lha_monthly: float = 0.0
    cb_registered: bool = False
    cb_opt_out: bool = False
    uc_u: float = 1.0  # take-up draw: claims if below UC_TAKEUP
    design_weight: float = 1.0
    out: dict = field(default_factory=dict)

    @property
    def pensioner(self) -> bool:
        return self.adults[0].age >= PENSION_AGE

    @property
    def uc_structure_ok(self) -> bool:
        """Universal Credit is modelled for working-age units whose adults
        have only pay or a trade (what `uktax` allows with `uc`)."""
        return (not self.pensioner and all(a.age < PENSION_AGE for a in self.adults)
                and all(a.pay_or_trade_only for a in self.adults))


class Rng:
    """Draws from `random.Random(seed).random()` only, so a seed gives the same
    population on any machine and Python version."""

    def __init__(self, seed: int):
        self.r = random.Random(seed)

    def u(self) -> float:
        return self.r.random()

    def choice(self, items, probs):
        x = self.u() * sum(probs)
        for item, p in zip(items, probs):
            x -= p
            if x < 0:
                return item
        return items[-1]

    def lognormal(self, sigma: float) -> float:
        """exp(sigma Z - sigma^2/2), mean 1, Z standard normal (Box-Muller)."""
        z = math.sqrt(-2 * math.log(1 - self.u())) * math.cos(2 * math.pi * self.u())
        return math.exp(sigma * z - sigma * sigma / 2)


def _power_inverse(lo: float, hi: float, s: float, u: float) -> float:
    """Inverse CDF of the density proportional to x^-s on [lo, hi]."""
    if abs(s - 1) < 1e-9:
        return lo * (hi / lo) ** u
    a = 1 - s
    return (lo ** a + u * (hi ** a - lo ** a)) ** (1 / a)


def _power_mean(lo: float, hi: float, s: float) -> float:
    def integral(k):  # integral of x^(k-s) from lo to hi
        e = k + 1 - s
        if abs(e) < 1e-9:
            return math.log(hi / lo)
        return (hi ** e - lo ** e) / e
    return integral(1) / integral(0)


def band_sampler(lo: float, hi: float | None, mean: float):
    """A density on [lo, hi) (Pareto above lo if hi is None) with the given
    mean: x^-s, s found by bisection."""
    if hi is None:
        alpha = mean / (mean - lo)
        return lambda u: lo * (1 - u) ** (-1 / alpha)
    a, b = -30.0, 30.0  # mean falls as s rises
    for _ in range(200):
        m = (a + b) / 2
        if _power_mean(lo, hi, m) > mean:
            a = m
        else:
            b = m
    s = (a + b) / 2
    return lambda u: _power_inverse(lo, hi, s, u)


@dataclass
class Design:
    """Everything `generate` needs from the margins, precomputed."""

    bands: list[dict]  # HMRC income ranges with sampler, mean, p_work, p_pens
    sources: list[dict]  # HMRC 3.6/3.7 by finer range
    kinds: dict[str, float]  # benefit unit kind -> number of units (design)
    country_adults: dict[str, float]
    london_share_england: float
    child_ages: list[float]  # registered children by single year of age 0..19
    rent_private_uk: float
    rent_private_london: float
    rent_social_weekly: float


def make_design(m: dict) -> Design:
    hm, ons = m["hmrc"], m["ons"]
    ranges = hm["taxpayers_by_range_2026_27"]
    sources = hm["income_sources_by_range_2023_24"]
    bands = []
    for r in ranges:
        mean = r["total_income"] / r["taxpayers"]
        bands.append({"lo": r["lower"], "hi": r["upper"], "mean": mean,
                      "sample": band_sampler(r["lower"], r["upper"], mean),
                      "taxpayers": r["taxpayers"]})
    # Pensioners' total income: taxpayers with a State Pension by range (3.6),
    # summed into the 2.5 ranges.
    for b in bands:
        b["pens"] = sum(s["state_pension"]["n"] for s in sources
                        if s["lower"] >= b["lo"] and (b["hi"] is None or s["lower"] < b["hi"]))
        b["pens"] = max(b["pens"], 1.0)

    fam = ons["families_2025"]
    pop = ons["population_mid_2025"]
    dep_all, dep_lone = fam["dependent_children"]["all"], fam["dependent_children"]["lone_parent"]
    couple_kids = {k: dep_all[k] - dep_lone[k] for k in ("one", "two", "three_plus")}
    couples_no_kids = fam["all_couple_families"] - sum(couple_kids.values())
    adults = pop["uk"]["16_plus"]
    cb_children_16 = (hm["child_benefit_in_payment_aug_2025"]["uk"]["children_by_age"]["16_plus"]
                      + hm["child_benefit_opted_out_aug_2025"]["children_by_age"]["16_plus"])
    singles = adults - 2 * fam["all_couple_families"] - sum(dep_lone.values()) - cb_children_16
    old = pop["uk"]["66_plus"]
    single_pensioners = fam["living_alone_65_plus"] * old / (old + pop["uk"]["by_age"]["65"])
    pensioner_couples = (old - single_pensioners) / 2
    kinds = {
        "single": singles - single_pensioners,
        "single_pensioner": single_pensioners,
        "couple": couples_no_kids - pensioner_couples,
        "couple_pensioner": pensioner_couples,
    }
    for k, n in zip(("one", "two", "three_plus"), (1, 2, 3)):
        kinds[f"lone_parent_{n}"] = dep_lone[k]
        kinds[f"couple_children_{n}"] = couple_kids[k]

    ages = hm["child_benefit_children_by_age_aug_2025"]
    child_ages = [ages.get(str(a), ages.get(a, 0.0)) for a in range(20)]
    country_adults = {c: pop[c]["16_plus"] for c in COUNTRIES}
    t = m["text"]
    return Design(
        bands=bands, sources=sources, kinds=kinds, country_adults=country_adults,
        london_share_england=pop["london"]["16_plus"] / pop["england"]["16_plus"],
        child_ages=child_ages,
        rent_private_uk=t["private_rent_uk_monthly_oct_2026"],
        rent_private_london=t["private_rent_london_monthly_oct_2026"],
        rent_social_weekly=t["social_rent_weekly_england_2025_26"] * SOCIAL_RENT_UPRATING,
    )


def _source_row(design: Design, x: float) -> dict:
    row = design.sources[0]
    for s in design.sources:
        if x >= s["lower"]:
            row = s
    return row


# Proposal for a worker's income band: the share of all taxpayers, with the
# bands above £100,000 drawn more often so each has enough households; the
# design weight undoes it.
TOP_BAND_FLOOR = 0.012
WORKER_INVESTMENT_SHARE = 0.65  # assumption: share of property, interest and dividends to under-66s
BELOW_PA_SHARE = 0.16  # workers with income under the personal allowance


def _band_probs(design: Design, key: str) -> tuple[list[float], list[float]]:
    """Target p and proposal q over [below-PA] + HMRC bands."""
    counts = [b[key] for b in design.bands]
    total = sum(counts)
    p = [BELOW_PA_SHARE] + [(1 - BELOW_PA_SHARE) * c / total for c in counts]
    q = [max(x, TOP_BAND_FLOOR) if i >= 7 else x for i, x in enumerate(p)]
    s = sum(q)
    return p, [x / s for x in q]


def _draw_income(rng: Rng, design: Design, p, q, below_lo: float):
    i = rng.choice(list(range(len(q))), q)
    factor = p[i] / q[i]
    if i == 0:
        return below_lo + rng.u() * (12_570 - below_lo), factor
    return design.bands[i - 1]["sample"](rng.u()), factor


def _working_adult(rng: Rng, design: Design, age: int, p_work: float, pq) -> tuple[Adult, float]:
    a = Adult(age=age)
    if rng.u() >= p_work:
        a.lcwra = rng.u() < 0.30
        return a, 1.0
    a.lcwra = rng.u() < 0.02
    x, factor = _draw_income(rng, design, *pq, below_lo=500)
    row = _source_row(design, x)
    rest = x
    if x >= 12_570:
        total = sum(row[k]["amount"] for k in ("self_employment", "employment", "state_pension",
                                               "other_pensions", "property", "interest", "dividends", "other"))
        base_n = max(row["employment"]["n"] + row["self_employment"]["n"], 1.0)
        for k in ("property", "interest", "dividends"):
            p_has = min(row[k]["n"] / base_n, 0.95)
            if rng.u() < p_has:
                # About a third of this income in a range goes to people over
                # pension age (who are drawn separately), so workers get less.
                share = min(WORKER_INVESTMENT_SHARE * (row[k]["amount"] / total) / p_has, 0.9)
                amt = min(share * x * rng.lognormal(0.5), 0.9 * rest)
                setattr(a, "property_income" if k == "property" else k, round(amt, 2))
                rest -= amt
        # Private pensions before State Pension age: by assumption 45 % of
        # workers aged 55 to 65 draw one, together receiving about a third of
        # the range's pension income (no open table splits it by age).
        if age >= 55 and rng.u() < 0.45:
            share = min(1.75 * (row["other_pensions"]["amount"] / total) / 0.45, 0.9)
            amt = min(share * x * rng.lognormal(0.5), 0.9 * rest)
            a.other_pension = round(amt, 2)
            rest -= amt
    # Self-employed with the probability that matches the range's split of
    # earnings by amount (by count it would overstate profits: many have both).
    se, emp = row["self_employment"]["amount"], row["employment"]["amount"]
    if rng.u() < se / (se + emp):
        a.profit = round(rest, 2)
    else:
        a.pay = round(rest, 2)
        a.net_pay_pension = auto_enrolment_contribution(a.pay)
    return a, factor


def auto_enrolment_contribution(pay: float) -> float:
    """The employee's minimum contribution under automatic enrolment: 5 % of
    qualifying earnings (£6,240 to £50,270 for 2026-27) for a jobholder paid
    at least the £10,000 trigger (Pensions Act 2008 ss 3, 13, 20; the
    Occupational and Personal Pension Schemes (Automatic Enrolment)
    Regulations 2010 reg 28), as if every one were in a net pay scheme.
    Opting out, contributions above the minimum and relief at source are not
    modelled."""
    if pay < 10_000:
        return 0.0
    return round(0.05 * (min(pay, 50_270) - 6_240), 2)


def _pensioner_adult(rng: Rng, design: Design, age: int, pq) -> tuple[Adult, float]:
    a = Adult(age=age)
    a.state_pension = round(FULL_NEW_STATE_PENSION * (0.72 + 0.33 * math.sqrt(rng.u())), 2)
    p, q = pq
    i = rng.choice(list(range(len(q))), q)
    factor = p[i] / q[i]
    if i == 0:
        top = max(12_570 - a.state_pension, 0)
        a.other_pension = round(rng.u() * top, 2)
        return a, factor
    x = max(design.bands[i - 1]["sample"](rng.u()), a.state_pension + 1)
    row = _source_row(design, x)
    # The rest of a pensioner's income, split like the range's income from
    # these sources, with the shares of work and investment income that go to
    # people over pension age set by assumption (no open table splits them).
    weights = {"other_pension": row["other_pensions"]["amount"],
               "property_income": (1 - WORKER_INVESTMENT_SHARE) * row["property"]["amount"],
               "interest": (1 - WORKER_INVESTMENT_SHARE) * row["interest"]["amount"],
               "dividends": (1 - WORKER_INVESTMENT_SHARE) * row["dividends"]["amount"],
               "pay": 0.05 * row["employment"]["amount"], "profit": 0.05 * row["self_employment"]["amount"]}
    total = sum(weights.values())
    rest = x - a.state_pension
    for k, w in weights.items():
        setattr(a, k, round(rest * w / total, 2))
    return a, factor


def _age(rng: Rng, lo: int, hi: int, by_age: dict) -> int:
    ages = list(range(lo, hi + 1))
    return rng.choice(ages, [by_age.get(str(a), by_age.get(a, 0.0)) for a in ages])


P_WORK = {"single": 0.72, "couple": 0.85, "lone_parent": 0.68, "couple_children": 0.92}
P_WORK_PARTNER = {"couple": 0.78, "couple_children": 0.74}


def generate(n: int, seed: int, margins: dict | None = None) -> list[Unit]:
    m = margins or load_margins()
    design = make_design(m)
    rng = Rng(seed)
    by_age = m["ons"]["population_mid_2025"]["uk"]["by_age"]
    kinds = list(design.kinds)
    kind_counts = [design.kinds[k] for k in kinds]
    total_units = sum(kind_counts)
    work_pq = _band_probs(design, "taxpayers")
    pens_pq = list(_band_probs(design, "pens"))
    # About a quarter of people over pension age pay no income tax (HMRC 2.1).
    tp_old = m["hmrc"]["taxpayers_by_rate_2026_27"]["state_pension_age"]
    below = 1 - tp_old / m["ons"]["population_mid_2025"]["uk"]["66_plus"]
    for lst in pens_pq:
        lst[0] = below
        s = sum(lst[1:])
        lst[1:] = [x * (1 - below) / s for x in lst[1:]]
    countries = list(COUNTRIES)
    country_p = [design.country_adults[c] for c in countries]

    units = []
    for _ in range(n):
        kind = rng.choice(kinds, kind_counts)
        base = kind.rsplit("_", 1)[0] if kind[-1].isdigit() else kind
        n_children = int(kind[-1]) if kind[-1].isdigit() else 0
        if n_children == 3 and rng.u() < 0.3:
            n_children = 4
        factor = 1.0
        adults = []
        if base.endswith("pensioner"):
            head_age = _age(rng, PENSION_AGE, 90, by_age)
            a, f = _pensioner_adult(rng, design, head_age, pens_pq)
            adults.append(a)
            factor *= f
            if base == "couple_pensioner":
                a, f = _pensioner_adult(rng, design, max(PENSION_AGE, head_age + round(4 * (rng.u() - 0.5))), pens_pq)
                adults.append(a)
                factor *= f
        else:
            lo, hi = (16, 65) if base == "single" else (18, 60) if n_children else (20, 65)
            head_age = _age(rng, lo, hi, by_age)
            p = P_WORK[base] * (0.75 if head_age < 25 else 0.7 if head_age >= 60 else 1.0)
            a, f = _working_adult(rng, design, head_age, p, work_pq)
            adults.append(a)
            factor *= f
            if base in P_WORK_PARTNER:
                partner_age = min(65, max(18, head_age + round(6 * (rng.u() - 0.5))))
                a, f = _working_adult(rng, design, partner_age, P_WORK_PARTNER[base], work_pq)
                adults.append(a)
                factor *= f
        children = []
        for _c in range(n_children):
            lo_age = 0
            hi_age = min(19, max(0, head_age - 16))
            children.append(rng.choice(list(range(lo_age, hi_age + 1)), design.child_ages[lo_age:hi_age + 1]))
        country = rng.choice(countries, country_p)
        london = country == "england" and rng.u() < design.london_share_england
        income = sum(a.gross for a in adults)
        young = adults[0].age < 30
        if base.endswith("pensioner"):
            tenure_p = (0.75, 0.17, 0.08)
        elif income < 20_000:
            tenure_p = (0.25, 0.38, 0.37) if not young else (0.10, 0.30, 0.60)
        elif income < 50_000:
            tenure_p = (0.55, 0.15, 0.30) if not young else (0.30, 0.12, 0.58)
        else:
            tenure_p = (0.78, 0.04, 0.18) if not young else (0.50, 0.03, 0.47)
        tenure = rng.choice(["owned", "social", "private"], tenure_p)
        u = Unit(kind=kind, adults=adults, children=sorted(children, reverse=True),
                 country=country, london=london, tenure=tenure)
        size = 1 + 0.12 * len(children) + (0.1 if len(adults) == 2 else 0)
        if tenure == "private":
            area = design.rent_private_london if london else design.rent_private_uk * (0.85 if country != "england" else 0.95)
            u.rent_monthly = round(area * 0.8 * size * rng.lognormal(0.3), 2)
            u.lha_monthly = round(area * 0.75 * size, 2)
        elif tenure == "social":
            u.rent_monthly = round(design.rent_social_weekly * 52 / 12 * size * 0.9 * rng.lognormal(0.15), 2)
        if not u.pensioner:
            for a in adults:
                if a.age < PENSION_AGE and a.profit == 0 and a.pay < 20_000 and a.pay_or_trade_only and rng.u() < 0.07:
                    a.carer = True
                    break
        if children:
            u.cb_registered = rng.u() < 0.90
            top = max(a.gross for a in adults)
            p_out = 0.85 if top >= HICBC_END else 0.30 if top >= HICBC_START else 0.0
            u.cb_opt_out = u.cb_registered and rng.u() < p_out
        u.uc_u = rng.u()
        u.design_weight = factor * total_units / n
        units.append(u)
    return units


# -------------------------------------------------------------------- engine


def _pence(x: float) -> int:
    return int(round(x * 100))


def _base_input(a: Adult, country: str, params: dict | None) -> dict:
    d = {
        "non_savings_pence": _pence(a.pay + a.state_pension + a.other_pension + a.property_income),
        "employment_pence": _pence(a.pay),
        "savings_pence": _pence(a.interest),
        "dividends_pence": _pence(a.dividends),
        "country": country,
    }
    if a.net_pay_pension > 0:
        d["net_pay_pension_pence"] = _pence(a.net_pay_pension)
    if a.profit > 0:
        expenses = max(1_001.0, round(0.2 * a.profit, 2))
        d["trading_receipts_pence"] = _pence(a.profit + expenses)
        d["trading_expenses_pence"] = _pence(expenses)
    if a.carer and a.pay_or_trade_only and a.profit == 0:
        d["carers_allowance"] = {"overlapping_weekly_pence": 0}
    if params:
        d["params"] = params
    return d


def _cb_index(u: Unit) -> int | None:
    """Which adult carries Child Benefit (and the HICBC): the one with the
    higher adjusted net income (ITEPA 2003 s681B)."""
    if not u.children or not u.cb_registered or u.cb_opt_out:
        return None
    return max(range(len(u.adults)), key=lambda i: u.adults[i].gross)


def _uc_claim(u: Unit, partner_net: float, partner_ca: float) -> dict:
    head = u.adults[0]
    couple = len(u.adults) == 2
    claim = {
        "couple": couple,
        "children": len(u.children),
        "under_25": all(a.age < 25 for a in u.adults),
        "first_child_pre_2017": bool(u.children) and max(u.children) >= 10,
        "health": "protected" if any(a.lcwra for a in u.adults) else "none",
        "carers": sum(1 for a in u.adults if a.carer),
        "london": u.london,
        # Benefit cap exemptions modelled: the LCWRA and carer elements
        # (the engine applies the cap otherwise). Carer's Allowance and PIP
        # also exempt; PIP is not modelled.
        "cap_exempt": any(a.lcwra or a.carer for a in u.adults),
    }
    if couple:
        claim["partner_earned_pence"] = _pence(max(partner_net, 0))
    if partner_ca > 0:
        claim["unearned_monthly_pence"] = _pence(partner_ca / 12)
    if u.tenure == "private":
        claim["rent_monthly_pence"] = _pence(u.rent_monthly)
        claim["lha_monthly_pence"] = _pence(u.lha_monthly)
    elif u.tenure == "social":
        claim["rent_monthly_pence"] = _pence(u.rent_monthly)
        claim["spare_rooms"] = 0
    return claim


def _call(binary, inputs: list[dict]) -> list[dict]:
    if not inputs:
        return []
    r = subprocess.run([str(binary)], input=json.dumps(inputs), capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"uktax failed: {r.stderr.strip()[:500]}")
    return json.loads(r.stdout)


def _person_result(o: dict) -> dict:
    return {
        "tax": o["liability_pence"] / 100,
        "nic_employee": (o["nic_exact_ten_thousandths_pence"] + o["class_4_exact_ten_thousandths_pence"]) / 1e6,
        "nic_class4": o["class_4_exact_ten_thousandths_pence"] / 1e6,
        "nic_employer": o["employer_nic_exact_ten_thousandths_pence"] / 1e6,
        "hicbc": o["hicbc_pence"] / 100,
        "child_benefit": o.get("child_benefit_pence", 0) / 100,
        "carers_allowance": (o.get("carers_allowance_pence") or 0) / 100,
        "ca_weekly_earnings": (o.get("carers_allowance_weekly_net_earnings_pence") or 0) / 100,
        "ani": o["adjusted_net_income_pence"] / 100,
        "step3": o["step3_income_pence"] / 100,
        "uc": (o.get("uc_millionths_pence") or 0) / 1e8,
    }


def run_engine(units: list[Unit], binary=DEFAULT_BINARY, params: dict | None = None) -> list[dict]:
    """Each unit's engine results: per adult, and the unit's net income.
    Returns a list parallel to `units` (also stored in `unit.out` when
    `params` is None)."""
    # Pass 1: partners (second adults).
    p_inputs, p_index = [], []
    for i, u in enumerate(units):
        if len(u.adults) == 2:
            d = _base_input(u.adults[1], u.country, params)
            if _cb_index(u) == 1:
                d["child_benefit_children"] = len(u.children)
            p_inputs.append(d)
            p_index.append(i)
    partner = {i: _person_result(o) for i, o in zip(p_index, _call(binary, p_inputs))}

    # Pass 2: heads, with Universal Credit where the unit can claim it.
    h_inputs = []
    for i, u in enumerate(units):
        d = _base_input(u.adults[0], u.country, params)
        if _cb_index(u) == 0:
            d["child_benefit_children"] = len(u.children)
        if u.uc_structure_ok:
            pr = partner.get(i)
            partner_net = 0.0
            partner_ca = 0.0
            if pr:
                b = u.adults[1]
                partner_net = b.pay + b.profit - pr["tax"] - pr["nic_employee"]
                partner_ca = pr["carers_allowance"]
            d["uc"] = _uc_claim(u, partner_net, partner_ca)
            if "carers_allowance" in d and d["uc"]["carers"] < 1:
                d["uc"]["carers"] = 1
        h_inputs.append(d)
    heads = [_person_result(o) for o in _call(binary, h_inputs)]

    results = []
    for i, u in enumerate(units):
        people = [heads[i]] + ([partner[i]] if i in partner else [])
        uc_entitled = heads[i]["uc"]
        uc_paid = uc_entitled if u.uc_u < UC_TAKEUP else 0.0
        gross = sum(a.gross for a in u.adults)
        r = {
            "people": people,
            "gross": gross,
            "tax": sum(p["tax"] for p in people),
            "nic_employee": sum(p["nic_employee"] for p in people),
            "nic_employer": sum(p["nic_employer"] for p in people),
            "hicbc": sum(p["hicbc"] for p in people),
            "child_benefit": sum(p["child_benefit"] for p in people),
            "carers_allowance": sum(p["carers_allowance"] for p in people),
            "uc_entitled": uc_entitled,
            "uc": uc_paid,
        }
        r["net"] = (gross - r["tax"] - r["nic_employee"] - r["hicbc"] + r["child_benefit"]
                    + r["uc"] + r["carers_allowance"])
        results.append(r)
        if params is None:
            u.out = r
    return results


# --------------------------------------------------------------- calibration


def targets(m: dict) -> list[tuple[str, float, str]]:
    """The published totals the weights reproduce: (name, value, source id)."""
    hm, ons, dwp = m["hmrc"], m["ons"], m["dwp"]
    pop = ons["population_mid_2025"]
    fam = ons["families_2025"]
    t = []
    for c in COUNTRIES:
        adults = pop[c]["16_plus"]
        if c == "england":
            t.append(("adults (16+), England outside London", adults - pop["london"]["16_plus"], "ons_mye"))
            t.append(("adults (16+), London", pop["london"]["16_plus"], "ons_mye"))
        else:
            t.append((f"adults (16+), {c.replace('_', ' ').title()}", adults, "ons_mye"))
    t.append(("adults aged 66 and over", pop["uk"]["66_plus"], "ons_mye"))
    t.append(("couple families", fam["all_couple_families"], "ons_families"))
    dep_all, dep_lone = fam["dependent_children"]["all"], fam["dependent_children"]["lone_parent"]
    for k, label in (("one", "1"), ("two", "2"), ("three_plus", "3+")):
        t.append((f"couples with {label} dependent children", dep_all[k] - dep_lone[k], "ons_families"))
        t.append((f"lone parents with {label} dependent children", dep_lone[k], "ons_families"))
    paid, opted = hm["child_benefit_in_payment_aug_2025"]["uk"], hm["child_benefit_opted_out_aug_2025"]
    for band, label in (("0_4", "0-4"), ("5_10", "5-10"), ("11_15", "11-15"), ("16_plus", "16+")):
        t.append((f"children aged {label} in Child Benefit families",
                  paid["children_by_age"][band] + opted["children_by_age"][band], "hmrc_cb"))
    for k, label in (("one", "1 child"), ("two", "2 children"), ("three_plus", "3+ children")):
        t.append((f"Child Benefit paid, families with {label}", paid[k], "hmrc_cb"))
    t.append(("Child Benefit opted out, families", opted["families"], "hmrc_cb"))
    for r in hm["taxpayers_by_range_2026_27"]:
        hi = f"£{r['upper']:,}" if r["upper"] else "and over"
        t.append((f"taxpayers, total income £{r['lower']:,} to {hi}" if r["upper"] else
                  f"taxpayers, total income £{r['lower']:,} and over", r["taxpayers"], "hmrc_t2_5"))
    tc = hm["taxpayers_by_country_2026_27"]
    for c in ("wales", "scotland", "northern_ireland"):
        t.append((f"taxpayers, {c.replace('_', ' ').title()}", tc[c], "hmrc_t2_2"))
    t.append(("taxpayers over State Pension age", hm["taxpayers_by_rate_2026_27"]["state_pension_age"], "hmrc_t2_1"))
    t.append(("Universal Credit households (with a payment)", dwp["uc_households"], "dwp_bect"))
    t.append(("Universal Credit households with children",
              dwp["uc_households"] * m["text"]["uc_share_with_children_aug_2026"], "uc_share_with_children_aug_2026"))
    t.append(("Universal Credit households with the LCWRA element", dwp["uc_lcwra"], "dwp_bect"))
    t.append(("Universal Credit households with the housing element", dwp["uc_housing_element"], "dwp_bect"))
    t.append(("Carer's Allowance in payment", dwp["carers_allowance_in_payment"], "dwp_bect"))
    return t


def indicators(units: list[Unit], m: dict) -> np.ndarray:
    """Each unit's contribution to each target, in the order of `targets`."""
    hm = m["hmrc"]
    ranges = hm["taxpayers_by_range_2026_27"]
    rows = []
    for u in units:
        o = u.out
        n_ad = len(u.adults)
        row = []
        for c in COUNTRIES:
            if c == "england":
                row.append(n_ad if (u.country == c and not u.london) else 0)
                row.append(n_ad if u.london else 0)
            else:
                row.append(n_ad if u.country == c else 0)
        row.append(sum(1 for a in u.adults if a.age >= PENSION_AGE))
        row.append(1 if n_ad == 2 else 0)
        k = len(u.children)
        for kk in (1, 2, 3):
            hit = (k == kk) if kk < 3 else (k >= 3)
            row.append(1 if (n_ad == 2 and hit) else 0)
            row.append(1 if (n_ad == 1 and hit) else 0)
        reg = u.cb_registered
        for lo, hi in ((0, 4), (5, 10), (11, 15), (16, 19)):
            row.append(sum(1 for c in u.children if lo <= c <= hi) if reg else 0)
        paid = reg and not u.cb_opt_out
        for kk in (1, 2, 3):
            hit = (k == kk) if kk < 3 else (k >= 3)
            row.append(1 if (paid and hit) else 0)
        row.append(1 if u.cb_opt_out else 0)
        for r in ranges:
            row.append(sum(1 for a, p in zip(u.adults, o["people"])
                           if p["tax"] > 0 and a.gross >= r["lower"] - (12_570 if r["lower"] == 12_570 else 0)
                           and (r["upper"] is None or a.gross < r["upper"])))
        for c in ("wales", "scotland", "northern_ireland"):
            row.append(sum(1 for p in o["people"] if p["tax"] > 0) if u.country == c else 0)
        row.append(sum(1 for a, p in zip(u.adults, o["people"]) if p["tax"] > 0 and a.age >= PENSION_AGE))
        uc = o["uc"] > 0
        row.append(1 if uc else 0)
        row.append(1 if uc and k > 0 else 0)
        row.append(1 if uc and any(a.lcwra for a in u.adults) else 0)
        row.append(1 if uc and u.tenure in ("private", "social") else 0)
        row.append(sum(1 for p in o["people"] if p["carers_allowance"] > 0))
        rows.append(row)
    return np.array(rows, dtype=float)


def calibrate(A: np.ndarray, d: np.ndarray, target: np.ndarray, iters: int = 200,
              bound: float = 25.0) -> tuple[np.ndarray, dict]:
    """Minimum-entropy weights w = d exp(A' lambda) with A'w = target.

    Newton's method on the dual, with step halving; each margin is scaled by
    its target so they are solved to the same relative accuracy. Weights are
    kept within [d / bound, d * bound]. Returns the weights and a report."""
    scale = np.where(target > 0, target, 1.0)
    As = A / scale
    ts = target / scale
    lam = np.zeros(A.shape[1])
    lo, hi = np.log(1 / bound), np.log(bound)

    def weights(lmb):
        return d * np.exp(np.clip(As @ lmb, lo, hi))

    def loss(lmb):
        g = As.T @ weights(lmb) - ts
        return float(g @ g)

    cur = loss(lam)
    for it in range(iters):
        w = weights(lam)
        g = As.T @ w - ts
        if np.max(np.abs(g)) < 1e-7:
            break
        H = As.T @ (As * w[:, None]) + 1e-9 * np.eye(len(lam))
        step = np.linalg.lstsq(H, g, rcond=None)[0]
        t = 1.0
        while t > 1e-4:
            cand = lam - t * step
            new = loss(cand)
            if new < cur:
                lam, cur = cand, new
                break
            t /= 2
        else:
            break
    w = weights(lam)
    fitted = A.T @ w
    return w, {"iterations": it + 1, "fitted": fitted,
               "max_rel_error": float(np.max(np.abs(fitted - target) / scale))}


# ------------------------------------------------------------------- summary


@dataclass
class Population:
    units: list[Unit]
    weights: np.ndarray
    targets: list[tuple[str, float, str]]
    fitted: np.ndarray
    margins: dict
    seed: int


def build(n: int = 30_000, seed: int = 1, binary=DEFAULT_BINARY, margins: dict | None = None) -> Population:
    m = margins or load_margins()
    units = generate(n, seed, m)
    run_engine(units, binary)
    t = targets(m)
    A = indicators(units, m)
    d = np.array([u.design_weight for u in units])
    w, rep = calibrate(A, d, np.array([x[1] for x in t]))
    return Population(units=units, weights=w, targets=t, fitted=rep["fitted"], margins=m, seed=seed)


def aggregates(pop: Population) -> dict:
    w = pop.weights
    def tot(key):
        return float(sum(wi * u.out[key] for wi, u in zip(w, pop.units)))
    return {
        "income_tax": tot("tax"),
        "nic_employee_class1_and_4": tot("nic_employee"),
        "nic_class4": float(sum(wi * sum(p["nic_class4"] for p in u.out["people"]) for wi, u in zip(w, pop.units))),
        "nic_employer": tot("nic_employer"),
        "hicbc": tot("hicbc"),
        "child_benefit": tot("child_benefit"),
        "universal_credit": tot("uc"),
        "carers_allowance": tot("carers_allowance"),
        "units": float(w.sum()),
        "adults": float(sum(wi * len(u.adults) for wi, u in zip(w, pop.units))),
        "taxpayers": float(sum(wi * sum(1 for p in u.out["people"] if p["tax"] > 0) for wi, u in zip(w, pop.units))),
        "hicbc_payers": float(sum(wi for wi, u in zip(w, pop.units) if u.out["hicbc"] > 0)),
        "uc_housing": float(sum(wi for wi, u in zip(w, pop.units) if u.out["uc"] > 0 and u.tenure != "owned")),
    }


def cliff_exposure(pop: Population) -> dict:
    """Weighted counts of benefit units near each cliff of the 2026-27 system."""
    w = pop.weights
    out = {}

    def count(pred):
        return float(sum(wi for wi, u in zip(w, pop.units) if pred(u)))

    def childcare_family(u, max_age):
        if not any(c <= max_age for c in u.children):
            return False
        return all(a.pay + a.profit >= CHILDCARE_MIN_EARNINGS for a in u.adults)

    def any_ani(u, lo, hi):
        return any(lo <= p["ani"] < hi for p in u.out["people"])

    out["childcare_below_cliff"] = count(lambda u: childcare_family(u, 11) and any_ani(u, CHILDCARE_LIMIT - 5_000, CHILDCARE_LIMIT + 0.01)
                                         and all(p["ani"] <= CHILDCARE_LIMIT for p in u.out["people"]))
    out["childcare_above_cliff"] = count(lambda u: childcare_family(u, 11) and any_ani(u, CHILDCARE_LIMIT + 0.01, CHILDCARE_LIMIT + 5_000))
    out["funded_hours_below_cliff"] = count(lambda u: childcare_family(u, 4) and any_ani(u, CHILDCARE_LIMIT - 5_000, CHILDCARE_LIMIT + 0.01)
                                            and all(p["ani"] <= CHILDCARE_LIMIT for p in u.out["people"]))
    out["childcare_families_over_limit"] = count(lambda u: childcare_family(u, 11) and any(p["ani"] > CHILDCARE_LIMIT for p in u.out["people"]))
    out["hicbc_band"] = count(lambda u: u.out["child_benefit"] > 0 and any(HICBC_START < p["ani"] < HICBC_END for p in u.out["people"]))
    out["hicbc_paying"] = count(lambda u: u.out["hicbc"] > 0)
    out["hicbc_total"] = float(sum(wi * u.out["hicbc"] for wi, u in zip(w, pop.units)))
    limit = CA_EARNINGS_LIMIT_WEEKLY

    def carers(pred):
        return float(sum(wi * sum(1 for a, p in zip(u.adults, u.out["people"]) if a.carer and pred(p))
                         for wi, u in zip(w, pop.units)))
    out["carers_within_20_below_limit"] = carers(lambda p: p["carers_allowance"] > 0 and p["ca_weekly_earnings"] > limit - 20)
    out["carers_within_20_above_limit"] = carers(lambda p: p["carers_allowance"] == 0 and limit < p["ca_weekly_earnings"] <= limit + 20)
    out["carers_receiving"] = carers(lambda p: p["carers_allowance"] > 0)
    out["pa_taper_people"] = float(sum(wi * sum(1 for p in u.out["people"] if 100_000 < p["ani"] < 125_140)
                                       for wi, u in zip(w, pop.units)))
    out["pa_taper_within_5k_below"] = float(sum(wi * sum(1 for p in u.out["people"] if 95_000 <= p["ani"] <= 100_000)
                                                for wi, u in zip(w, pop.units)))
    out["uc_in_work"] = count(lambda u: u.out["uc"] > 0 and any(a.pay + a.profit > 0 for a in u.adults))
    return out


def reform(pop: Population, params: dict, binary=DEFAULT_BINARY) -> dict:
    """Run the same weighted population with other figures; the change in each
    unit's net income. Cost is to the Exchequer (positive: households gain)."""
    res = run_engine(pop.units, binary, params=params)
    w = pop.weights
    delta = np.array([r["net"] - u.out["net"] for r, u in zip(res, pop.units)])
    d_tax = np.array([r["tax"] - u.out["tax"] for r, u in zip(res, pop.units)])
    d_nic = np.array([r["nic_employee"] - u.out["nic_employee"] for r, u in zip(res, pop.units)])
    d_uc = np.array([r["uc"] - u.out["uc"] for r, u in zip(res, pop.units)])
    d_hicbc = np.array([r["hicbc"] - u.out["hicbc"] for r, u in zip(res, pop.units)])
    win = delta > 1
    lose = delta < -1
    return {
        "params": params,
        "cost": float(w @ delta),
        "income_tax_change": float(w @ d_tax),
        "nic_change": float(w @ d_nic),
        "uc_change": float(w @ d_uc),
        "hicbc_change": float(w @ d_hicbc),
        "winners": float(w[win].sum()),
        "losers": float(w[lose].sum()),
        "unchanged": float(w[~win & ~lose].sum()),
        "mean_gain_winners": float((w[win] @ delta[win]) / w[win].sum()) if win.any() else 0.0,
        "mean_loss_losers": float((w[lose] @ delta[lose]) / w[lose].sum()) if lose.any() else 0.0,
        "delta": delta,
    }
