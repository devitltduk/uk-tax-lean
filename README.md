# uk-tax-lean

UK income tax (including Scottish rates, Gift Aid, pension contributions
relieved at source and under net pay, the Marriage Allowance, the married
couple's allowance, the blind person's allowance, and trading and property
income with the trading and property allowances and rent-a-room relief),
employee National Insurance, the High Income Child Benefit
Charge, a minimal Universal Credit and the £100,000 childcare cliff for 2026-27,
for taxpayers anywhere in the UK (childcare rules are England's), formalised in
Lean 4, with proofs about it and a harness that checks it against
[PolicyEngine UK](https://github.com/PolicyEngine/policyengine-uk).

A write-up of the results, with the cliff map and the differences from
PolicyEngine UK, is in [`docs/writeup.md`](docs/writeup.md).

What PolicyEngine UK models and how much of it is formalised here, programme by
programme, is in [`docs/coverage.md`](docs/coverage.md); every difference found
from PolicyEngine, with its classification, is in
[`docs/findings.md`](docs/findings.md).

## What is modelled

Wales is included because for 2026-27 every Welsh rate is 10p in the pound
([Welsh rate resolution NDM9117](https://record.senedd.wales/Motion/9117),
agreed by the Senedd on 27 January 2026). That leaves Welsh taxpayers on the same
20 / 40 / 45 % as England and Northern Ireland. GOV.UK's rates table carries only
one caveat: "Income tax bands are different if you live in Scotland".

One individual whose income is non-savings income (e.g. pay or pension), savings
interest and dividends, following the steps of ITA 2007 s23:

- **Personal allowance** £12,570, tapered by half the excess of adjusted net
  income over £100,000, the result rounded up to a whole pound (s35).
- **Allowance placement** in the way that gives the least tax (s25(2)). No fixed
  order does that: setting the allowance against dividends can keep the
  starting rate for savings, and setting it against savings can lift the savings
  allowance into the higher band. The model searches the corners of the
  piecewise-linear tax (see `UkTax/Calc.lean`).
- **Bands** (on income after allowances): basic up to £37,700, higher up to
  £125,140, additional above.
- **Non-savings and savings rates** 20 / 40 / 45 %.
- **Starting rate for savings** 0 % on savings within the lowest £5,000.
- **Personal savings allowance** £1,000 / £500 / £0 by the highest band reached.
- **Dividend allowance** £500 at 0 %, then the dividend rates **10.75 / 35.75 / 39.35 %**.
- Savings sit above non-savings income and dividends on top (s16). Income at a nil
  rate still uses up its band.
- **Scottish taxpayers** (`"country": "scotland"`): non-savings income at the
  Scottish rates 19 / 20 / 21 / 42 / 45 / 48 % (s11A); savings and dividends at
  the UK rates in the UK bands, and the savings allowance by the UK limits, "as if
  the individual were not a Scottish taxpayer" (s11D(6), s13(5), s12B(8)). The
  s25(2) search covers Scottish limits too.
- **Gift Aid and pension contributions relieved at source**, as gross amounts:
  both raise the basic and higher rate limits, and for a Scottish taxpayer the
  Scottish basic rate limit and those above it but not the starter limit (ITA 2007
  s414(2); FA 2004 s192(4), (4A)), and both come off adjusted net income (ITA 2007
  s58), which sets the personal allowance taper, the HICBC and the childcare
  income limit. The relief at source itself (20 % of the gross, kept by the member
  whatever their liability) is not part of the liability. s192(4) raises the
  limits "if ... income tax at the higher rate or the additional rate is
  chargeable", on a claim; the model raises them for every relief-at-source
  contribution, as HMRC's PTM056120 describes. Read literally, "the higher rate" is
  the non-savings rate, so savings or dividends alone above the limit would not
  raise it (findings #11).
- **Net pay pension contributions** come off pay for income tax (FA 2004
  s193(2)) but not for NICs ("There is no equivalent NICs relief", HMRC
  NIM02365).
- **Blind person's allowance** £3,250 (ITA 2007 s38), added to the tapered
  personal allowance, itself untapered.
- **Marriage Allowance** (ss 55A-55E): the transferor's personal allowance falls
  by £1,260 (s55B(6)) if, with it reduced, they pass the rate test (s55C(1)(c),
  (ca)); the recipient gets 20 % of £1,260, £252, off at Step 6 if they pass the
  same test (s55B(2)(b), (ba)): no income charged above the basic rate (for a
  Scottish taxpayer, above the intermediate rate), dividends tested as if the
  dividend nil rate were omitted. Not with the married couple's allowance
  (s55B(2)(d)).
- **Married couple's allowance** (ss 45-46): 10 % of £11,700, less half the excess
  of adjusted net income over £39,200, not below 10 % of £4,530, at Step 6.
- **Trading and property income** (`UkTax/Profits.lean`): one trade's receipts and
  expenses, with the £1,000 trading allowance (ITTOIA 2005 ss 783AD-783AM: full
  relief within it, or receipts less £1,000 instead of expenses above it); one
  property business with the £1,000 property allowance (ss 783BD-783BH); and
  rent-a-room receipts with the £7,500 limit, halved if shared (ss 784-800: full
  relief within it, or receipts less the limit above it). The model makes the
  elections that give the least profit; losses count as nil and are not relieved.

All amounts are whole pence (`Nat`), and rates are basis points. Tax is computed
exactly, in 1/10,000 of a penny, and rounded down to the penny once at the end.

### 2026-27 figures and sources

Checked against legislation.gov.uk and GOV.UK on 2026-11-26. Each one is in
`UkTax/Params.lean` with its citation.

| Figure | 2026-27 | Source |
|---|---|---|
| Personal allowance | £12,570 | [ITA 2007 s35(1)](https://www.legislation.gov.uk/ukpga/2007/3/section/35); frozen for 2026-27 by FA 2021 s5 as amended by [FA 2023 s5](https://www.legislation.gov.uk/ukpga/2023/1/section/5) |
| Taper | above £100,000, half the excess, round up to £1 | ITA 2007 s35(2)-(3) |
| Basic rate limit | £37,700 | [ITA 2007 s10(5)](https://www.legislation.gov.uk/ukpga/2007/3/section/10) |
| Higher rate limit | £125,140 (2 × PA + £100,000) | ITA 2007 s10(5A) |
| Basic / higher / additional rate | 20 / 40 / 45 % | [Finance Act 2026 s2](https://www.legislation.gov.uk/ukpga/2026/11) |
| Savings rates | 20 / 40 / 45 % | Finance Act 2026 s3 |
| Starting rate for savings | 0 % up to £5,000 | [ITA 2007 s12](https://www.legislation.gov.uk/ukpga/2007/3/section/12); FA 2026 s9 |
| Personal savings allowance | £1,000 / £500 / £0 | [ITA 2007 s12B](https://www.legislation.gov.uk/ukpga/2007/3/section/12B) |
| Dividend allowance | £500 | [ITA 2007 s13A](https://www.legislation.gov.uk/ukpga/2007/3/section/13A) |
| Dividend ordinary / upper / additional | 10.75 / 35.75 / 39.35 % | [ITA 2007 s8](https://www.legislation.gov.uk/ukpga/2007/3/section/8) as amended by FA 2026 s4 |
| Scottish rates and limits (on income above the allowance) | starter 19 % to £3,967; basic 20 % to £16,956; intermediate 21 % to £31,092; higher 42 % to £62,430; advanced 45 % to £125,140; top 48 % | [Scottish rate resolution 2026-27, S6M-20844](https://www.parliament.scot/chamber-and-committees/votes-and-motions/S6M-20844); ITA 2007 s11A; [GOV.UK](https://www.gov.uk/scottish-income-tax) |
| Scottish savings and dividends; savings allowance test | UK rates and limits, as if not a Scottish taxpayer | [ITA 2007 s11D(6)](https://www.legislation.gov.uk/ukpga/2007/3/section/11D), s13(5), s12B(8)(a)(iv), (b)(iv) |
| Gift Aid | grossed up at 20 %; raises the basic and higher rate limits and the Scottish limits from the basic rate up | [ITA 2007 s414(2)](https://www.legislation.gov.uk/ukpga/2007/3/section/414), s415 |
| Pension contributions relieved at source | 20 % at source; raise the same limits | [FA 2004 s192(1), (4), (4A)](https://www.legislation.gov.uk/ukpga/2004/12/section/192); [GOV.UK](https://www.gov.uk/tax-on-your-private-pension/pension-tax-relief) |
| Adjusted net income | net income less grossed-up Gift Aid and gross relief-at-source contributions | [ITA 2007 s58](https://www.legislation.gov.uk/ukpga/2007/3/section/58) |
| Blind person's allowance | £3,250 | [ITA 2007 s38(1)](https://www.legislation.gov.uk/ukpga/2007/3/section/38) as amended by [SI 2026/38](https://www.legislation.gov.uk/uksi/2026/38/made) |
| Marriage Allowance | £1,260 transferred (10 % of £12,570 rounded up to £10); £252 reduction | [ITA 2007 s55B(4)(b), (5), (6)](https://www.legislation.gov.uk/ukpga/2007/3/section/55B) |
| Married couple's allowance | £11,700 maximum, £4,530 minimum, income limit £39,200, 10 % | ITA 2007 ss 43, 45, 46 as amended by SI 2026/38 art 2 |
| Trading allowance / property allowance | £1,000 each | [ITTOIA 2005 s783AD](https://www.legislation.gov.uk/ukpga/2005/5/section/783AD), [s783BD](https://www.legislation.gov.uk/ukpga/2005/5/section/783BD) |
| Rent-a-room limit | £7,500, or £3,750 if shared | [ITTOIA 2005 s789](https://www.legislation.gov.uk/ukpga/2005/5/section/789); SI 2015/1539 |

GOV.UK summary pages: [Income Tax rates](https://www.gov.uk/income-tax-rates),
[tax on savings interest](https://www.gov.uk/apply-tax-free-interest-on-savings/how-much-is-tax-free),
[tax on dividends](https://www.gov.uk/tax-on-dividends).

### Employee National Insurance (Class 1 primary)

On employment earnings only, which the input gives as the part of non-savings
income that is pay (`employment_pence`); pensions, savings and dividends carry
none. Category letter A, aged 16 to State Pension age. 8 % between the primary
threshold and the upper earnings limit, 2 % above it (`UkTax/Charges.lean`).

NICs are due per earnings period, so the yearly total depends on how often the
employee is paid. The model assumes equal pay every period and ignores the
rounding of each period's contribution to the penny. Then a year of periods is
the annual formula with annual-equivalent thresholds (`nic_earnings_period`):

| basis | primary threshold | upper earnings limit |
|---|---|---|
| `annual` (default; directors) | £12,570 | £50,270 |
| `monthly` (12 × £1,048, 12 × £4,189) | £12,576 | £50,268 |
| `weekly` (52 × £242, 52 × £967) | £12,584 | £50,284 |

### High Income Child Benefit Charge

ITEPA 2003 s681B-s681H. The input is the Child Benefit paid for the year to the
taxpayer or their partner (`child_benefit_pence`). The taxpayer is the one
liable: a single claimant, or the partner with the higher adjusted net income.
The charge is 1 % of the Child Benefit for each whole £200 of adjusted net income
over £60,000, up to 100 %. The Child Benefit, the percentage and the charge are
each rounded down to a whole number (s681C(3)). Adjusted net income is total
income, since no reliefs are modelled.

### Universal Credit (minimal)

`UkTax/Benefits.lean`. Standard allowance (single or joint, 25 or over), child
element for children born on or after 6 April 2017 with no two-child limit (reg
24A was revoked from April 2026), the higher work allowance for a claimant
responsible for a child, and the 55 % taper on earned income, which is pay less
income tax and employee NICs (SI 2013/376 reg 55(5)). Pay is taken as equal each
month, so the yearly award is twelve times the monthly one. Pay only: no savings,
dividends or other income for UC households.

### Tax-Free Childcare and the funded hours (England)

A parent is eligible when they, and their partner if they have one, each expect
to earn at least £10,574.72 a year (16 hours a week at the £12.71 National Living
Wage, as £2,643.68 a quarter) and each have adjusted net income not over
£100,000. The partner's pay and income are an input (`partner`), fixed while the
parent's pay varies; a UC couple's partner has no pay, so fails. Tax-Free
Childcare adds 20 % of each child's childcare costs (£2 for every £8 paid in), up
to £2,000 a child a year. It can't be had with Universal Credit, so net income
counts whichever is larger.

The funded hours are England's (`country`, default England; Tax-Free Childcare is
UK-wide). Each child is given an age band (`funded_children`):

| age band | universal hours (any income) | working-parent hours (if eligible) | DfE rate | a year, at that rate |
|---|---|---|---|---|
| 9 months to 2 (`under_2`) | none | 30 a week | £12.04 | £13,725.60 |
| 2 (`2`) | none | 30 a week | £8.90 | £10,146.00 |
| 3 and 4, until school (`3_4`) | 15 a week | 15 more a week | £6.61 | £3,767.70 + £3,767.70 |

Hours are counted for 38 weeks (570 hours a year for 15 a week, 1,140 for 30).
Each hour is valued at the Department for Education's 2026-27 national average of
local authority hourly funding rates for the age band (technical note, Table 6),
or at a local nursery price per hour given for the child
(`price_pence_per_hour`). Over £100,000 only the working-parent hours go; a 3 or
4-year-old keeps the universal 15. Reaching the minimum earnings gains the
working-parent hours, so it is a rise in net income, not a drop.

Why the national average local authority rate. DfE pays each local authority an
hourly rate per entitlement and publishes their national average; it publishes no
national figure for what providers are paid. Authorities must pass at least 97 %
of the funding through to providers, for each entitlement, so the average
provider rate is between 97 % and 100 % of these figures, with local variation
(no local authority gets less than £6.20 an hour for 3 and 4-year-olds in
2026-27, technical note section 3; there is no floor for younger children). The
national average is the one published national figure per age band, it is what
the state spends on an hour, and it is the figure PolicyEngine UK uses, so the
comparison is like for like. A nursery's own price for an hour can be higher;
to value the hours at what they would cost the family, give the local price.

### 2026-27 figures for NICs and HICBC

Checked against legislation.gov.uk and GOV.UK on 2026-11-26; each is in
`UkTax/Params.lean` with its citation.

| Figure | 2026-27 | Source |
|---|---|---|
| Primary threshold | £242 / week, £1,048 / month, £12,570 / year | [SI 2001/1004 reg 10(c), reg 11(3)](https://www.legislation.gov.uk/uksi/2001/1004/regulation/11) for 2026-27 ([SI 2026/231 reg 5](https://www.legislation.gov.uk/uksi/2026/231/regulation/5/made)); [GOV.UK](https://www.gov.uk/guidance/rates-and-thresholds-for-employers-2026-to-2027) |
| Upper earnings limit | £967 / week, £4,189 / month, £50,270 / year | SI 2001/1004 reg 10(b), reg 11(2A); GOV.UK as above |
| Main / additional primary rate | 8 % / 2 % | [SSCBA 1992 s8](https://www.legislation.gov.uk/ukpga/1992/4/section/8) |
| HICBC threshold, step | £60,000, 1 % per £200 | [ITEPA 2003 s681C](https://www.legislation.gov.uk/ukpga/2003/1/section/681C) (F(No. 2)A 2024 s5); [GOV.UK](https://www.gov.uk/child-benefit-tax-charge) |
| Child Benefit (examples only) | £27.05 eldest, £17.90 others, per week | [GOV.UK rates by tax year](https://www.gov.uk/government/publications/rates-and-allowances-tax-credits-child-benefit-and-guardians-allowance/tax-credits-child-benefit-and-guardians-allowance) |
| UC standard allowance, 25 or over | £424.90 single, £666.97 joint, per month | [SI 2013/376 reg 36](https://www.legislation.gov.uk/uksi/2013/376/regulation/36) (SI 2026/113); [GOV.UK benefit rates 2026 to 2027](https://www.gov.uk/government/publications/benefit-and-pension-rates-2026-to-2027/proposed-benefit-and-pension-rates-2026-to-2027) |
| UC child element | £303.94 per child per month, no two-child limit | reg 36 (SI 2026/148 Sch 13); [Universal Credit (Removal of Two Child Limit) Act 2026 s1](https://www.legislation.gov.uk/ukpga/2026/13) |
| UC higher work allowance, taper | £710 a month, 55 % | [reg 22](https://www.legislation.gov.uk/uksi/2013/376/regulation/22) ([SI 2026/148 art 32](https://www.legislation.gov.uk/uksi/2026/148/article/32/made)) |
| Childcare income limit | adjusted net income over £100,000 | [SI 2015/448 reg 15](https://www.legislation.gov.uk/uksi/2015/448/regulation/15); [GOV.UK funded hours](https://www.gov.uk/free-childcare-if-working/check-youre-eligible) |
| Childcare minimum earnings | £2,643.68 a quarter (21 or over) | [GOV.UK](https://www.gov.uk/tax-free-childcare/check-if-youre-eligible); NLW £12.71 [GOV.UK](https://www.gov.uk/national-minimum-wage-rates) |
| Tax-Free Childcare top-up | £2 per £8 paid in, up to £2,000 a child a year | [GOV.UK](https://www.gov.uk/tax-free-childcare) |
| Working-parent hours: income limit, minimum earnings | each parent: adjusted net income not over £100,000; £2,643.68 a quarter (21 or over) | [SI 2022/1134 regs 14, 15, 18](https://www.legislation.gov.uk/uksi/2022/1134/regulation/14); [GOV.UK](https://www.gov.uk/free-childcare-if-working/check-youre-eligible) ("You (and your partner, if you have one) must each expect to earn...") |
| Funded hours | universal 570 a year at 3 and 4 (no income test); working parents 1,140 a year from 9 months, universal hours included; over no fewer than 38 weeks | [Childcare Act 2006 s7](https://www.legislation.gov.uk/ukpga/2006/21/section/7); [Childcare Act 2016 s1](https://www.legislation.gov.uk/ukpga/2016/5/section/1); SI 2022/1134 reg 44; [DfE statutory guidance, April 2026](https://www.gov.uk/government/publications/early-education-and-childcare--2/early-education-and-childcare-valid-from-1-april-2026), paras A1.6, A1.10, A1.11, A1.16 |
| DfE hourly funding rates (national average of local authority rates) | £12.04 under 2s, £8.90 2-year-olds, £6.61 3 and 4-year-olds | [2026 to 2027 early years national funding formulae: technical note](https://www.gov.uk/government/publications/early-years-funding-2026-to-2027/2026-to-2027-early-years-national-funding-formulae-technical-note), section 3.8, Table 6 (and 3.3) |
| Pass-through to providers | at least 97 %, each entitlement | [Early years entitlements: local authority funding operational guide 2026 to 2027](https://www.gov.uk/government/publications/early-years-funding-2026-to-2027/early-years-entitlements-local-authority-funding-operational-guide-2026-to-2027), section 4.1; statutory guidance para A4.6 |

## Out of scope

Welsh rates other than 2026-27's (in scope only because they equal the rUK
rates), National Insurance other than employee Class 1 primary contributions
(employer, self-employed, voluntary, other category letters), Universal Credit
beyond the minimal model (housing, childcare, disability and carer elements,
capital, unearned income, the benefit cap, the minimum income floor, under-25
rates, the first-child rate for children born before 6 April 2017, monthly
rounding, couples where both work), Tax-Free Childcare and the funded hours for
disabled children, the childcare tests' routes for a partner who is disabled or a
carer, the lower minimum earnings for parents under 21 or apprentices, the 15
hours for disadvantaged 2-year-olds (which depend on benefits), a child changing
age band during the year (the model takes one band for the year), Wales's,
Scotland's and Northern Ireland's own childcare schemes, legacy benefits, reliefs and deductions not listed above (losses and loss
relief, capital allowances, property finance costs, employment expenses; Gift
Aid, pension contributions and trading or property income with Universal Credit
or the childcare tests), other tax reductions, property income's own rates (from 2027-28), the default rates for non-residents, top-slicing relief,
foreign income, capital gains, and every tax year other than 2026-27.

That includes 2027-28 savings rates, where the sources currently differ. As
enacted, Finance Act 2026 s5 sets 22 / 42 / 47 % from 6 April 2027. Budget 2026
(para 6.247) announced a further 2 points, so the pinned PolicyEngine UK
(2.180.2) models 24 / 44 / 49 % from that date. Neither affects 2026-27.

## What is proved

In `UkTax/Proofs.lean` and `UkTax/Optimal.lean`, with no `sorry`.
`UkTax/Axioms.lean` fails the build if any of these theorems ever depends on more
than Lean's standard axioms (`propext`, `Classical.choice`, `Quot.sound`). Nothing
is assumed: every result below holds for every income.

Every result holds for every regime: rUK or Scottish, with any Gift Aid and
relief-at-source contributions.

- `isLeastTax_taxExact`: the search finds the least tax. For every income, the
  allowance share the model picks gives the least Step 4 tax over every legal
  way of deducting the allowance, which is what s25(2) asks for. So the computed
  liability *is* the s25(2) liability, not an upper bound on it.
- `liability_mono`: the computed `liability` never goes down when any kind of
  income (non-savings, savings or dividends) goes up. This has to hold through
  the taper, savings and dividends moving into higher bands, and the savings
  allowance dropping from £1,000 to £500 to £0 at a cliff edge.
- `leastTax_mono`: the same for the least tax itself, which is how
  `liability_mono` is proved.
- `exists_isLeastTax`: the least tax exists for every income.
- `bestAlloc_feasible`: the search only picks legal allowance placements.
- `nicExact_mono`: employee NICs never go down when pay goes up, on every
  earnings-period basis.
- `hicbc_mono_income`, `hicbc_le`: the charge never goes down when adjusted net
  income goes up, and never exceeds the Child Benefit it is on.
- `net_drop_only_at_steps` (`UkTax/Cliffs.lean`): for every pay, savings,
  dividends, Child Benefit and pay period, if one more penny of pay lowers net
  income (gross − income tax − NICs − HICBC + Child Benefit), that penny is a step
  of the personal allowance (total income reaching a multiple of £2 in
  (£100,000, £125,140]), of the HICBC (a multiple of £200 in [£60,200, £80,000])
  or of the personal savings allowance (Step 3 income at £37,700 or £125,140).
  The allowance and the charge step with adjusted net income, and the limits are
  raised by Gift Aid and relief-at-source contributions. Scottish rates add no
  step: they are rates, not cliffs. It rests on `taxExact_succ_le` (with both
  allowances fixed, a penny more pay adds at most 0.686p of income tax, 0.706p
  for a Scottish taxpayer, whose worst case is pay in the 42 % higher rate below
  the UK basic rate limit with dividends above it crossing both UK limits:
  42 + 25 + 3.6 %) and `net_succ_ge`
  (between steps net income rises at least 0.234p per penny, 0.214p in Scotland,
  so the marginal rate there is at most 76.6 %, or 78.6 %).
  With the Marriage Allowance there is one more step: a recipient whose Step 3
  income passes the basic rate limit (for a Scottish taxpayer, the top of the
  intermediate rate) fails the rate test and loses the £252 at once
  (`maStep_above_limit`; `maOk_payOnly` shows that with pay only the test is
  exactly that), and the married couple's allowance taper costs at most 0.05p
  more per penny.
- `reliefProfit_succ`, `propertyProfit_succ_other`, `propertyProfit_succ_room`
  (`UkTax/Profits.lean`): with the elections made, a penny more receipts adds at
  most a penny to the trading or property profits charged and never lowers them,
  so the £1,000 allowances and the rent-a-room limit are not cliffs.
- `netAll_drop_only_at_steps` (`UkTax/Benefits.lean`): the same with Universal
  Credit, Tax-Free Childcare (whichever is larger) and the funded hours added,
  with one more kind of step: adjusted net income going over £100,000. The
  minimum earnings test adds no step: reaching it gains Tax-Free Childcare and the
  working-parent hours.
- `fundedHours_over_limit`, `fundedHours_drop_at_limit`: over £100,000 the funded
  hours are worth exactly the universal hours, and for a parent eligible at
  £100,000 the penny over loses exactly the working-parent hours, never the
  universal 15.
  `earned_plus_uc_mono`: earned income plus UC never falls as earned income
  rises (the taper is 55 %). `netAll_succ_ge`: between steps, a penny more pay
  raises net income with benefits by at least 0.1053p (0.0963p in Scotland), so
  the marginal rate there is at most 1 − 0.45 × 0.234 = 89.47 % (90.37 %).

How the optimality proof works (details at the top of `UkTax/Optimal.lean`): with
the income fixed, a way of sharing the allowance is a point `(x, w)` (non-savings
income left, and that plus savings left), and Step 4 tax is a sum of band-tax
terms that are linear between a short list of lines. Away from those lines the
tax has a zero second difference, so along any line segment it is least at an
end or on another line. Moving first along `x` and then along `w` takes any legal
share to a crossing of two lines with no more tax, and the search tries every
such crossing. The proof uses only Lean's core `omega` tactic; Mathlib is not
needed.

## Running it

Lean is pinned in `lean-toolchain`, and there are no dependencies (no Mathlib).
If elan is not installed, install it into the checkout with
`ELAN_HOME=$PWD/.elan` (ignored by git) so toolchains stay inside it.

```sh
lake build --wfail            # model, proofs, axiom guard and the uktax binary
python3 tests/golden.py       # hand-checked golden cases against the binary
```

`uktax` reads JSON on stdin (one object or an array) and prints JSON.
`liability_pence` is rounded down to the penny, and
`tax_exact_ten_thousandths_pence` is the exact tax before rounding. Optional
inputs `employment_pence`, `nic_earnings_period` and `child_benefit_pence` give
`nic_exact_ten_thousandths_pence` (and `nic_pence`, rounded down for display) and
`hicbc_pence`; see `Main.lean`.

```sh
$ echo '{"non_savings_pence": 2957000, "savings_pence": 0, "dividends_pence": 300000}' \
    | .lake/build/bin/uktax
{"allowance_against_dividends_pence":0,"allowance_against_savings_pence":0,"hicbc_pence":0,"liability_pence":366875,"nic_exact_ten_thousandths_pence":0,"nic_pence":0,"personal_allowance_pence":1257000,"savings_allowance_pence":100000,"tax_exact_ten_thousandths_pence":3668750000}
```

### Golden cases

`tests/golden.json` holds 90 cases with the expected figures worked out by hand
and the working shown. Each case states which outputs it checks (income tax,
NICs, HICBC). Two are GOV.UK's own 2026-27 worked examples (tax on
dividends; the savings allowance). The others are aimed at edges: the taper and its
round-up, the additional rate, the savings allowance at exactly £37,700 and 1p
over and at exactly £125,140 and 1p over, dividends alone pushing income over the
basic rate limit and so cutting the savings allowance, dividends across bands, the allowance set against dividends or savings,
and both s25(2) choices. For NICs: 1p over the primary threshold, each
earnings-period basis, above the upper earnings limit, and pay plus pension. For
HICBC: 1p below and at the first 1 % step, 99 % and 100 %, two children with a
benefit that is not whole pounds, and income from dividends counting towards
adjusted net income. For the funded hours: each age band at £100,000 and 1p over
(a 3-year-old keeping the universal hours), 1p under the minimum earnings, a local
price, a couple where the partner is 1p over £100,000 or 1p under the minimum
earnings, a UC couple, Wales, and net income either side of the £100,000 cliff.
For the reliefs: net pay contributions, the blind person's allowance through the
taper, the Marriage Allowance for each spouse (each rate test, 1p over the
limit, savings and dividends, Scotland), the married couple's allowance taper
and floor, and the trading, property and rent-a-room reliefs (within and above
each limit, the halved limit, and a rent-a-room loss set against other letting).

### Where earning more lowers net income

```sh
python3 harness/cliffs.py                                           # about 3 minutes
(cd harness && uv run --frozen --only-group charts python charts.py)  # the charts
```

`cliffs.py` (stdlib only) writes [`docs/cliffs.md`](docs/cliffs.md) (every drop, by
household type, with its size and the pay range after it where net income stays
lower), the tables `docs/net.csv` and `docs/rates.csv`, and the data `charts.py`
(matplotlib, pinned in the harness's `charts` dependency group) draws:

- [`docs/net.svg`](docs/net.svg): net income against gross pay, £0 to £150,000, a
  panel per household, each one-off cliff labelled with the £ lost and the pay at
  which net income has recovered;
- [`docs/rates.svg`](docs/rates.svg): the marginal rate between the cliffs, with
  the cliffs as markers carrying their £ amount;
- [`docs/cliff-100k.png`](docs/cliff-100k.png): the lone parent with a 2-year-old,
  £80,000 to £140,000, 1200 × 1200, for sharing.

A cliff is a one-off loss of a fixed sum, not a rate: one penny more pay costs that
sum once, and net income then rises again at the ordinary rate. Shown as a
"marginal rate" its size would depend only on how wide a slice of pay it is spread
over (the £12,146 cliff is 6,073 % of £200 of pay, about 40 % of £30,000), so the charts
give it in £. Net income there is the proved `netAll`, read from
`uktax` (`net_income_millionths_pence`), and the script evaluates it exactly at every
step penny that `netAll_drop_only_at_steps` allows, so the list is complete within
the model; nothing is sampled. CI regenerates the tables and charts and checks
that `docs/` matches them byte for byte, and the
script's seed checks hold figures worked out by hand: every personal allowance
step costs 39.42p, £100,000 to £125,140 keeps exactly 38 % (the 60 % band plus
2 % NICs), and the first HICBC step with one child costs £13.9942.

What it finds, for 2026-27:

- **The 60 % band is a staircase of small cliffs.** Because s35(3) rounds the
  tapered allowance *up* to a whole pound, it falls £1 at every £2 of income from
  £100,002 to £125,140. Each of those 12,570 pennies costs 39.42p of net income, and
  for about 68p of pay after each step net income is below its level before it.
  Over any whole £2 the rate is the familiar 60 % (62 % with NICs).
- **HICBC**: 100 drops, at each £200 from £60,200 to £80,000, each 1 % of the
  Child Benefit in whole pounds (£13.99 to £14.99 with one child, £31.99 to £32.99
  with three), each followed by a £24 to £57 pay range where net income is lower.
- **Personal savings allowance**: with savings income, crossing the basic rate
  limit costs £100 (£500 of interest moving from 0 % to 20 %) and crossing
  £125,140 costs £200 (£500 at 40 %), with traps of about £140 to £380 of pay.
- **The £100,000 childcare cliff**: going 1p over £100,000 of adjusted net income
  loses Tax-Free Childcare and the working-parent funded hours (at DfE rates, £10,000
  of childcare a child on top):

  | household | lost at £100,000.01 | net income back to its £100,000 level at pay |
  |---|---|---|
  | lone parent, child aged 2 | £12,145.99 (TFC £2,000 + hours £10,146) | £130,032.08 |
  | lone parent, children aged 1 and 3 | £21,493.29 (TFC £4,000 + hours £13,725.60 + £3,767.70) | £147,668.50 |
  | couple (partner £40,000), child aged 3 | £5,767.69 (TFC £2,000 + hours £3,767.70) | £115,177.42 |

  Up to £125,140 each extra pound keeps 38p (the 60 % band and 2 % NICs), after it
  53p, so a loss over £9,553.20 takes until well past £125,140 to recover. Before
  the funded hours were priced the cliff was £1,999.99 and £3,999.99 with £5,263 and
  £10,526 of pay to recover.
- **Universal Credit** adds no drops: with the 55 % taper on top of tax and NICs,
  the rate between steps is at most 89.47 % (proved: `netAll_succ_ge`), and moving between UC and Tax-Free
  Childcare is smooth because the household takes the larger.
- No other drops, for any household of this form.

## Comparing with PolicyEngine UK

```sh
lake build
cd harness
uv run python compare.py                 # ~2,000 threshold edge cases + 500 random
uv run python compare.py --random 5000   # more random cases
```

The harness is a uv project that pins `policyengine-uk==2.180.2`. For every case
it checks:

- PolicyEngine's tax, unrounded, is within `--steps` float32 steps (default 2) of
  the model's exact tax. PolicyEngine works in float32, so it can be no more
  precise than float32 at the size of the taxpayer's total income: one step is
  0.2p at £20,000, 0.8p at £100,000 and 1.6p from £131,072.
- The personal allowance is the same in both, except where adjusted net income
  is within 2 float32 steps of a £2 step of the tapered allowance: PolicyEngine
  adds incomes in float32 and can land on the other side of the step, so the
  allowance differs by £1 and the tax by the rate on £1. Those cases are counted
  and reported, not failed (findings #9).
- The personal savings allowance is the same in both.
- Employee NICs are within the same float32 tolerance (at the employee's pay),
  plus 0.32p. PolicyEngine works out NICs monthly from weekly thresholds stored
  as the annual figures ÷ 52 (£241.73 and £966.73; its comments note the reg 10
  weekly amounts are £242 and £967), so its monthly thresholds are £1,047.50 and
  £4,189.16, not £1,048 and £4,189 (SI 2001/1004 reg 11(3)(a), (2A)(a)), and over
  a year they are 4p below £12,570 and £50,270. The model is compared on its
  annual basis.
- The High Income Child Benefit Charge is equal (both whole pounds). Child
  Benefit is passed to PolicyEngine as an input so both charge the same amount,
  and the charge is taken off PolicyEngine's `income_tax`, which includes it.

Cases split non-savings income between pay and pension (passed to PolicyEngine as
`private_pension_income`) and carry 0 to 3 children's Child Benefit, with extra
edge cases at the NIC thresholds and at the HICBC steps. They include Scottish
taxpayers (PolicyEngine's region `SCOTLAND`), 1p either side of each Scottish
limit with savings and dividends above, and Gift Aid (passed as the amount
given, the gross × 0.8, so both gross it up the same way). Pension contributions
relieved at source are checked only where PolicyEngine's design and the law
agree: PolicyEngine deducts the gross contribution from taxable income instead
of raising the limits, so its `income_tax` is the liability less the 20 % relief
at source. Adding that back, the two agree for a taxpayer outside Scotland with
no savings or dividends whose taxable pay is at least the gross contribution,
and only such cases are generated. Outside them PolicyEngine gives less relief
than the law, or with savings in the starting rate band more (findings #7, a
limitation PolicyEngine documents, with a draft issue to close it).

It writes `harness/out/comparison.csv` and exits non-zero if any check fails.

It runs in CI as well (about 30 s for 3,000 cases). Latest local run:
7,723 cases (2,723 edge, 5,000 random; 1,738 Scottish, 1,354 with Gift Aid, 90
with relief at source). Every income tax is within 2 steps (worst 0.96 steps,
1.71p) apart from 4 edge cases built 1p from a taper step, where PolicyEngine's
float32 sum lands on the other side and the allowance differs by £1; every NIC
figure is within 2 steps plus the 0.32p gap (largest difference 0.39p, 3.34
steps); and every other personal allowance, every savings allowance and every
HICBC agrees. On NixOS, numpy needs
`libstdc++`: run with `LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH` (nix-ld) or from a
shell that provides it.

### Universal Credit against PolicyEngine

`uv run python compare_uc.py` compares the award for a single claimant with 0 to
4 children and a one-earner couple with 0 to 3 children, from £0 to £80,000 of
pay. Latest local run: 5,603 cases (2,729 with UC paid), all within 2 float32
steps plus 0.176p (55 % of the NIC threshold gap above); largest difference 0.43p
(2.79 steps, so above 2 steps only because of that gap).

By default PolicyEngine treats the couple as married and claiming the Marriage
Allowance (its `would_claim_marriage_allowance` take-up flag), which gives the
earner £1,260 of the partner's allowance: £252 less tax and £138.60 more UC a
year. That's a default, not an error. The UC harness sets it to 0 for couples, since
its couples have one earner and a partner with no income; the Marriage Allowance
itself is compared in `compare_reliefs.py` below.

### Reliefs and allowances against PolicyEngine

`uv run python compare_reliefs.py` (about 30 s) compares, for one taxpayer, net
pay pension contributions (income tax, NICs on the whole pay, adjusted net
income), the blind person's allowance, the married couple's allowance (given to
PolicyEngine as the model's tapered amount, which it takes as an input), the
trading allowance (receipts and expenses) and the property allowance with
rent-a-room relief (no rent-a-room expenses, which PolicyEngine does not take).
Latest local run: 384, 224, 224, 264 and 291 cases, all within 2 float32 steps
(worst 0.72 steps).

For the Marriage Allowance it compares the couple's total tax, since the law and
PolicyEngine put it on different spouses. PolicyEngine gives the recipient 20 %
of the transferor's *unused* allowance (rounded up to £10) and never reduces the
transferor's allowance; the law moves a fixed £1,260. The harness checks
PolicyEngine against that stated basis (666 of 666 couples match) and reports
where it departs from the law: 554 agree; 17 differ by under £2 (the £10
round-up); 95 pay £6.90 to £252 more in PolicyEngine, where the transferor's
income above the reduced allowance is taxed below 20 % (findings #12, a known
PolicyEngine issue).

### Funded hours against PolicyEngine

`uv run python compare_childcare.py` compares the funded hours' yearly value for a
lone parent or a couple (partner's pay fixed at 0 to £100,000.01, including 1p
either side of the minimum earnings) with children aged 1, 2, 3, 1 and 3, or 2
and 3, in England and in Wales, from £0 to £150,000 of pay. PolicyEngine values
the hours the same way (its `gov.dfe.childcare_funding_rate` holds the same Table 6
rates, 38 weeks), so it checks the eligibility and the hours. Latest local run:
6,090 cases (1,413 with working-parent hours); 6,068 agree within 2 float32 steps
a child (largest difference 0.12p). The other 22 differ only by PolicyEngine's 15
hours for disadvantaged 2-year-olds (£5,073 at £8.90), which it gives a family
on Universal Credit with low earnings and which the model leaves out.

PolicyEngine works term by term: a child counts from the term after it reaches
the minimum age, at the rate for its age that term, and stops when it starts
school. The model takes one age band for the year. So the harness uses children
born so that they stay in one band in all three terms; for a child who changes
band during the year PolicyEngine gives a blend (a 2-year-old born in April 2024,
under 2 in the April term, gets £11,339.20 there, not £10,146).

## CI

GitHub Actions (`.github/workflows/ci.yml`) builds with `--wfail`, checks the
proofs and the axiom guard, runs the golden cases, regenerates the cliff map and its charts
(failing if `docs/` no longer matches the model), then runs the PolicyEngine
comparisons (income tax, NICs and HICBC; Universal Credit; funded hours, with
1,000 random cases each; reliefs and allowances).
