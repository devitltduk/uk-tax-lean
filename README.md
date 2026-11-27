# uk-tax-lean

UK income tax (including Scottish rates, Gift Aid, pension contributions
relieved at source and under net pay, the Marriage Allowance, the married
couple's allowance, the blind person's allowance, and trading and property
income with the trading and property allowances and rent-a-room relief),
National Insurance (employee and employer Class 1, Class 1A, 2, 3 and 4), the High Income Child Benefit
Charge, Universal Credit, Child Benefit, PIP, DLA, Attendance Allowance, Carer's
Allowance, Maternity Allowance, new style JSA and ESA, the Sure Start Maternity Grant
and the £100,000 childcare cliff for 2026-27,
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

### Other National Insurance (`UkTax/Nics.lean`)

- **Employer (secondary) Class 1**: 15 % above the secondary threshold (£96 a
  week, £417 a month, £5,000 a year; SSCBA 1992 s9, SI 2001/1004 regs 10-11), or
  for an employee under 21 or a relevant apprentice under 25
  (`employer_zero_rated`) above the upper secondary threshold (£967, £4,189,
  £50,270; ss 9A, 9B), on the same earnings-period bases as employee
  contributions. The Employment Allowance is the employer's and is left out.
- **Class 1A**: 15 % of a given cash equivalent of benefits in kind (s10).
- **Class 4**: 6 % of trading profits between £12,570 and £50,270, 2 % above
  (s15), on the profits after the trading allowance; where employee Class 1 is
  also payable, limited by the annual maximum of SI 2001/1004 reg 100.
- **Class 2**: treated as paid with profits of at least the £7,105 small profits
  threshold (s11(5A)-(5B)); voluntary £3.65 a week below it
  (`class_2_voluntary_weeks`). **Class 3**: £18.40 a week (`class_3_weeks`).

### High Income Child Benefit Charge

ITEPA 2003 s681B-s681H. The input is the Child Benefit paid for the year to the
taxpayer or their partner (`child_benefit_pence`). The taxpayer is the one
liable: a single claimant, or the partner with the higher adjusted net income.
The charge is 1 % of the Child Benefit for each whole £200 of adjusted net income
over £60,000, up to 100 %. The Child Benefit, the percentage and the charge are
each rounded down to a whole number (s681C(3)). Adjusted net income is total
income, since no reliefs are modelled.

### Universal Credit

`UkTax/Benefits.lean`, amounts for assessment periods from 6 April 2026 (SI
2013/376 reg 36 as uprated by SI 2026/113 and SI 2026/148; Universal Credit Act
2025 s2):

- standard allowance, single or joint, under 25 or 25 and over;
- child element (£303.94, the first child £351.88 where the claimant is
  responsible for a child born before 6 April 2017), no two-child limit, and the
  disabled child additions (£164.79 / £514.71);
- the LCWRA element at the new-claim rate (£217.26) or the protected rate
  (£429.80), and the carer element (£209.34; not with the LCWRA element for the
  same claimant, reg 29(4));
- the childcare costs element, 85 % of costs up to £1,071.09 / £1,836.16, with
  the reg 32 work condition;
- the housing costs element: rent, capped at a given local housing allowance for
  a private renter, less 14 % / 25 % for under-occupancy in the social sector,
  less £96.55 for each non-dependant;
- the higher (£710) or lower (£427) work allowance, the 55 % taper on earned
  income (pay less income tax and NICs, reg 55(5)) of the claimant and partner;
- capital over £16,000 (no award) and tariff income (£4.35 for each £250 or part
  over £6,000); unearned income deducted in full;
- the benefit cap (£22,020 / £25,323 in London for a couple or a parent, £14,753
  / £16,967 for a single person), counting Child Benefit, lifted by earnings of
  £881 a month or by the LCWRA, carer or other reg 83 exemptions, and reduced by
  the childcare element (reg 81).

Pay is taken as equal each month, so the yearly award is twelve times the monthly
one; rounding each month (reg 6) and the grace period of the cap are not
modelled. Pay and one trade only: no savings, dividends or other income of the
claimant beyond the unearned income given.

**Self-employment and the minimum income floor** (`UkTax/UcSelfEmployed.lean`):

- self-employed earnings ([reg 57](https://www.legislation.gov.uk/uksi/2013/376/regulation/57)):
  receipts less expenses (no trading allowance), less the income tax and Class 4
  paid in respect of the trade (the tax on pay and profit less the tax on the pay
  alone; Class 2 is treated as paid), nil for a loss, which is never set against
  pay;
- the minimum income floor ([reg 62](https://www.legislation.gov.uk/uksi/2013/376/regulation/62)):
  for a claimant in gainful self-employment who would otherwise have all
  work-related requirements, outside a start-up period, earned income is at least
  the individual threshold: the expected hours (35 unless less, reg 88) at the
  National Living Wage (£12.71), × 52 / 12 a month (£1,927.68 for 35 hours,
  £1,927 with the fraction of a pound disregarded under reg 6(1A)(a), the
  default), less notional income tax and Class 4: £20,379.96 a year. Reg 62(4)(b)
  leaves that deduction to the Secretary of State; the model, like PolicyEngine,
  takes the tax and Class 4 on the threshold as the only income. For a couple
  (reg 62(3)) the floor is cut back so that it and the partner's earned income do
  not pass the couple threshold; `mifCouple_eq` proves that reg 62(3) comes to
  `max(earned income, min(threshold, couple threshold − partner's earned income))`.

### Non-means-tested benefits (`UkTax/Disability.lean`)

Weekly rates from 6 April 2026 (checked against legislation.gov.uk and GOV.UK on
2026-11-26; each is in `UkTax/Params.lean` with its citation):

| Benefit | 2026-27 a week | Source |
|---|---|---|
| Child Benefit | £27.05 eldest or only child, £17.90 each other | [SI 2006/965 reg 2(1)](https://www.legislation.gov.uk/uksi/2006/965/regulation/2) ([SI 2026/232 art 2](https://www.legislation.gov.uk/uksi/2026/232/made)) |
| PIP | daily living £76.70 / £114.60; mobility £30.30 / £80.00 | [SI 2013/377 reg 24](https://www.legislation.gov.uk/uksi/2013/377/regulation/24) (SI 2026/148 art 15) |
| DLA | care £30.30 / £76.70 / £114.60; mobility £30.30 / £80.00 | [SI 1991/2890 reg 4](https://www.legislation.gov.uk/uksi/1991/2890/regulation/4) (SI 2026/148 art 14) |
| Attendance Allowance | £76.70 / £114.60 | SSCBA 1992 Sch 4 Part III para 1 (SI 2026/148 Sch 1) |
| Carer's Allowance | £86.45; not payable after a week whose net earnings exceeded £204 | SSCBA 1992 Sch 4 para 4; [SI 1976/409 reg 8(1)](https://www.legislation.gov.uk/uksi/1976/409/regulation/8) ([SI 2026/218 reg 4](https://www.legislation.gov.uk/uksi/2026/218/made)); [SI 1996/2745 regs 5, 10](https://www.legislation.gov.uk/uksi/1996/2745/regulation/10) |
| Maternity Allowance | lower of 90 % of average weekly earnings and £194.32, from £30 of earnings | [SSCBA 1992 ss 35, 35A](https://www.legislation.gov.uk/ukpga/1992/4/section/35A); SI 1986/1960 reg 6 |
| New style JSA | £75.65 under 25, £95.55 from 25; less earnings over £5 and pensions over £50; nil under 10p | [SI 2013/378 regs 49-52](https://www.legislation.gov.uk/uksi/2013/378/regulation/49), Sch para 5 |
| New style ESA | £95.55 (£75.65 under 25 in the assessment phase), support component £50.35; less half of pensions over £85 | [SI 2013/379 regs 62, 67](https://www.legislation.gov.uk/uksi/2013/379/regulation/62) |
| Sure Start Maternity Grant | £500 a baby, with a qualifying benefit and no other child under 16 | [SI 2005/3061 regs 5, 5A](https://www.legislation.gov.uk/uksi/2005/3061/regulation/5) |

- **Child Benefit for a whole 2026-27 is 53 weeks**, not 52: a Child Benefit week
  begins on a Monday (SSCBA 1992 s147(1)), and 6 April 2026 and 5 April 2027 are
  both Mondays. The HICBC counts the same weeks (ITEPA 2003 s681H(3)). Input
  `child_benefit_children` gives 53 weeks for that many children (findings #19);
  `child_benefit_pence` still takes any amount.
- **PIP, DLA and Attendance Allowance** (`disability`): the rate of each
  component is an input, a year is 52 weeks (2026-27 has 52 of every weekday
  but Monday).
- **Carer's Allowance** (`carers_allowance`, pay only): £86.45 a week less any
  overlapping benefit, for a carer who meets the caring conditions, unless a
  week's net earnings exceed £204. Net earnings are pay less the income tax on
  the pay alone, primary Class 1 and half the net pay pension contributions,
  over 52 weeks, a fraction of a penny disregarded. The allowance is taxable
  (ITEPA 2003 s660), so `net_income_carer_ten_thousandths_pence` adds it to
  non-savings income for income tax (no NICs). With Universal Credit
  (`UkTax/CarerUc.lean`) it is unearned income deducted in full
  ([reg 66(1)(b)(iii)](https://www.legislation.gov.uk/uksi/2013/376/regulation/66),
  52 weeks a year by [reg 73(2)(a)](https://www.legislation.gov.uk/uksi/2013/376/regulation/73)),
  the carer element is due with or without it
  ([reg 30(1)(a)](https://www.legislation.gov.uk/uksi/2013/376/regulation/30)),
  and earned income is pay less the tax on the pay alone, the pay being the
  lowest slice (reg 55(5)(b) does not say how to split the tax; PolicyEngine does
  the same).
- **Maternity Allowance**, **new style JSA and ESA** and the **Sure Start
  Maternity Grant** as weekly amounts (or the grant) from the inputs above.

The Carer's Allowance limit is a cliff: with pay only, £10,608.51 a year keeps
the whole £4,495.40; £10,608.52 (£204.01 a week) loses it, and net income falls by
£3,988.61 (the allowance less the income tax on it). On Universal Credit the
cliff turns round: UC makes up the allowance penny for penny, so at the limit net
income rises by the tax the allowance carried (£506.79 for a lone parent of two
on £10,608.52, against £10,608.51).

### State Pension and Pension Credit (`UkTax/Pension.lean`)

| Figure | 2026-27 a week | Source |
|---|---|---|
| New State Pension | £241.30 with 35 qualifying years; 1/35 a year from 10 | [Pensions Act 2014 ss 2-3](https://www.legislation.gov.uk/ukpga/2014/19/section/3); [SI 2015/173 regs 1A, 13](https://www.legislation.gov.uk/uksi/2015/173/regulation/1A) |
| Basic State Pension | Category A £184.90; Category B (lower) and D £110.75; 25p at 80 | [SSCBA 1992 s44(4)](https://www.legislation.gov.uk/ukpga/1992/4/section/44), s79, Sch 4 |
| Standard minimum guarantee | £238.00 single, £363.25 couple | [SI 2002/1792 reg 6(1)](https://www.legislation.gov.uk/uksi/2002/1792/regulation/6) |
| Additional amounts | severe disability £86.05 (£172.10 double), carer £48.15, child £69.98 (first born before 6 April 2017 £81.07), disabled child £37.93 / £118.46 | reg 6(5), (8); Sch IIA |
| Savings credit | threshold £208.07 / £329.75; 60 % / 40 %; maximum £17.96 / £20.10; fractions of a penny to the claimant | [reg 7](https://www.legislation.gov.uk/uksi/2002/1792/regulation/7); [SPCA 2002 s3](https://www.legislation.gov.uk/ukpga/2002/16/section/3) |
| Deemed income from capital | £1 for each £500 or part above £10,000; no capital limit | [reg 15(6)](https://www.legislation.gov.uk/uksi/2002/1792/regulation/15) |
| Earnings disregard | £20 (lone parent, carer, disabled, listed jobs), else £10 couple, £5 single | [Sch VI](https://www.legislation.gov.uk/uksi/2002/1792/schedule/VI) |

- **State Pension**: an input. Anyone with a qualifying year before 6 April 2016
  gets the transitional rate, worked out from their own record (Pensions Act 2014
  s4), so no count of years gives it. `new_state_pension` gives the reduced rate
  for someone with no such year.
- **Pension Credit** (`pension_credit`): income is the State Pension, other
  pensions and income, earnings after NICs less the disregard, less the income tax
  on them (reg 17(10)(a)), plus deemed income from capital; guarantee credit is the
  appropriate minimum guarantee less income; savings credit (claimant or partner
  reached pensionable age before 6 April 2016) is amount A, rounded up, less amount
  B, rounded down. Yearly figures are 52 weeks.

### Housing Benefit for pensioners (`UkTax/HousingBenefit.lean`)

The Housing Benefit (Persons who have attained the qualifying age for state
pension credit) Regulations 2006 (SI 2006/214), figures from SI 2026/148:

| Figure | 2026-27 a week | Source |
|---|---|---|
| Personal allowance | single £256.00 (pensionable age before 1 April 2021) or £238.00; couple £383.35 or £363.25 | [Sch 3 para 1](https://www.legislation.gov.uk/uksi/2006/214/schedule/3/paragraph/1) |
| Child, family premium (protected) | £87.88 each; £20.22 | Sch 3 paras 2-3 |
| Premiums | severe disability £86.05 (£172.10), enhanced disability child £33.99, disabled child £84.46, carer £48.15 | Sch 3 para 12 |
| Taper, capital limit, tariff income | 65 %; £16,000; £1 per £500 or part above £10,000 | [regs 51](https://www.legislation.gov.uk/uksi/2006/214/regulation/51), [43](https://www.legislation.gov.uk/uksi/2006/214/regulation/43), [29(2)](https://www.legislation.gov.uk/uksi/2006/214/regulation/29) |
| Non-dependant deductions | £131.45, or by gross income £20.40 / £46.85 / £64.35 / £105.20 / £119.85 (bands at £192, £279, £365, £485, £605); £20.40 not in work | [reg 55](https://www.legislation.gov.uk/uksi/2006/214/regulation/55) |
| Earnings disregards | £25 lone parent, £20 carer / disabled / listed jobs, else £10 couple, £5 single | [Sch 4](https://www.legislation.gov.uk/uksi/2006/214/schedule/4) |

With the guarantee credit, Housing Benefit is the eligible rent less non-dependant
deductions (reg 26); with savings credit only, income is the Pension Credit
assessment plus the savings credit (reg 27); otherwise HB's own means test, with
income net of tax (reg 33(12)) and nothing over £16,000 of capital. Input
`housing_benefit` with the household's income in `pension_credit`. Not modelled:
the additional £17.10 earnings disregard, childcare charges, and the LHA itself (an
input).

### Working-age Housing Benefit and the legacy benefits (`UkTax/HousingBenefitWa.lean`)

What is left of the legacy benefits in 2026-27
([SI 2025/1148](https://www.legislation.gov.uk/uksi/2025/1148)):

- Income Support and income-based JSA were abolished for every award from 1 April
  2026 (arts 4, 5): nothing is payable;
- income-related ESA ends on 1 July 2026 except where an appointee acts for the
  claimant (art 3A); not computed (an input, as in PolicyEngine);
- working-age Housing Benefit ends on 1 July 2026 (art 7) except in specified or
  temporary accommodation and for awards saved with income-related ESA (art 7(4)).

Working-age Housing Benefit ([SI 2006/213](https://www.legislation.gov.uk/uksi/2006/213)),
input `housing_benefit_working_age`, from pay:

| Figure | 2026-27 | Source |
|---|---|---|
| Personal allowance | £95.55 single 25 or over or lone parent, £75.65 single under 25, £150.15 couple | Sch 3 para 1; [SI 2026/148 art 23(6), Sch 4](https://www.legislation.gov.uk/uksi/2026/148/article/23/made) |
| Each child | £87.88, every child (no two-child limit from 6 April 2026) | Sch 3 para 2; reg 22(1)(b) as amended by [SI 2026/316 reg 2(2)](https://www.legislation.gov.uk/uksi/2026/316/made) |
| Premiums | disability £44.85 / £64.00, enhanced disability £22.00 / £31.40 (child £33.99), severe disability £86.05, disabled child £84.46, carer £48.15, family premium (protected) £20.22; support component £50.35 | Sch 3, Order Sch 5 |
| Earnings disregards | £25 lone parent, £20 disability, carer or listed jobs, £10 couple, £5 single; £17.10 more where para 17(2) is met and earnings reach the total; from 5 October 2026 in specified or temporary accommodation £77.73 (£61.41 under 25), couples £119.70 (£61.53) | [Sch 4](https://www.legislation.gov.uk/uksi/2006/213/schedule/4) paras 3-10, 17, 18 ([SI 2026/753](https://www.legislation.gov.uk/uksi/2026/753/made) as substituted by [SI 2026/978](https://www.legislation.gov.uk/uksi/2026/978/made)) |
| Capital | £16,000 limit; £1 a week for each £250 or part above £6,000 | [regs 43, 52(1), (6)](https://www.legislation.gov.uk/uksi/2006/213/regulation/52) |
| Benefit cap | annual limit ÷ 52 to the penny (£283.71 single, £423.46 others outside London); Housing Benefit counts as nil in specified accommodation | [regs 75C, 75CA, 75D, 75H](https://www.legislation.gov.uk/uksi/2006/213/regulation/75C) |

Net earnings are pay less tax on the pay, primary Class 1 and half the pension
contributions (reg 36(3)). On UC, Income Support, income-based JSA or
income-related ESA all income and capital is disregarded (Sch 5 para 4, Sch 6
para 5): the maximum, the rent less non-dependant deductions (the pensioner
amounts). The award is the maximum less 65 % of income above the applicable
amount. 6 April 2026 is a Monday, so the 52-week year is 26 weeks to 4 October and
26 from 5 October; an award in general accommodation is payable for the 86 days to
30 June 2026. Not modelled: self-employment, childcare charges, other special
disregards, the cap's grace period.

### Council tax and Council Tax Reduction for pensioners (`UkTax/CouncilTax.lean`)

- **Council tax**: the band D amount (an input) in the band's proportion, 6 : 7 :
  8 : 9 : 11 : 13 : 15 : 18 ninths for bands A to H and 21 for band I in Wales
  ([LGFA 1992 s5](https://www.legislation.gov.uk/ukpga/1992/14/section/5)), 240 :
  280 : 320 : 360 : 473 : 585 : 705 : 882 360ths in Scotland
  ([s74](https://www.legislation.gov.uk/ukpga/1992/14/section/74)); 25 % off with
  one resident (s11, s79).
- **Council Tax Reduction for pensioners**, in each nation's prescribed scheme
  (England [SI 2012/2885](https://www.legislation.gov.uk/uksi/2012/2885/schedule/1),
  Wales WSI 2013/3029, Scotland SSI 2012/319): for each day, the day's council tax
  less non-dependant deductions × 1/7 (England £15.95, £13.30, £10.60, £5.20 at
  £605, £485 and £279 of gross weekly income; Wales £20.05, £16.80, £13.35, £6.70;
  Scotland £16.55, £13.90, £10.95, £5.55 at £614, £497 and £286), less 2 6/7 % of
  the week's income above the applicable amount; summed over the 365 days of
  2026-27. Income and the guarantee credit and savings credit routes as Housing
  Benefit's. The applicable amount is Housing Benefit's in England (no family
  premium); Wales and Scotland pay £256.00 / £383.35 whatever the date
  pensionable age was reached, Wales with the £20.22 family premium, Scotland with
  £109.85 a child. Inputs `council_tax` and `council_tax_reduction` (the year's
  bill, with the household's income in `pension_credit`).


### Council Tax Reduction for working-age applicants in Wales (`UkTax/CtrWorkingAge.lean`)

The Welsh prescribed scheme, classes C and D
([WSI 2013/3029](https://www.legislation.gov.uk/wsi/2013/3029) regs 24, 25, Schs
6-8), input `council_tax_reduction_working_age` with `"country": "wales"`. The
maximum is the bill by the day less the non-dependant deductions × 1/7 (the
pensioner amounts); the reduction is the maximum less 2 6/7 % a day of the week's
income above the applicable amount, so over 365 days the bill less 365/7 weeks of
the deductions and 20 % of the excess.

| Figure | 2026-27 | Source |
|---|---|---|
| Personal allowance | £101.85 single 25 or over or lone parent, £80.60 single 18 to 24, £159.85 couple | Sch 7 para 1 |
| Child, family premium | £87.88 each; £20.22 for any family with a child | Sch 7 paras 3, 4 |
| Premiums, earnings disregards | as working-age Housing Benefit (£5, £10, £20, £25, the £17.10 step) | Sch 7 para 17, Sch 8 |
| Capital | £16,000; £1 a week per £250 or part above £6,000 | Sch 6 para 33 |
| On UC (an award above nil) | applicable amount the UC maximum amount × 12/52; income the UC income and award × 12/52 | Sch 6 paras 3, 9 |

Income is net earnings from pay (gross less tax, Class 1 and half the pension
contributions) less the disregards, other income and tariff income; income support,
income-based JSA or income-related ESA give the maximum (`passported`). Not
modelled: self-employment, childcare charges, the extended reduction.

### Council Tax Reduction for working-age applicants in Scotland (`UkTax/CtrWorkingAge.lean`)

[SSI 2021/249](https://www.legislation.gov.uk/ssi/2021/249), input
`council_tax_reduction_working_age` with `"country": "scotland"`. Reg 13 is the
Welsh shape (the bill by the day less the deductions × 1/7, less 2 6/7 % a day of
the week's excess income), or the second adult rebate if greater; reg 14 gives
dwellings in bands E to H the part of the bill due to the 2017 band rise, tapered
above £321 or £479 a week, where that is greater.

| Figure | 2026-27 | Source |
|---|---|---|
| Personal allowance | £95.55 single 25 or over or lone parent, £75.65 single under 25, £150.15 couple | Sch 1 para 1 |
| Child premium, family premium | £109.85 each; no family premium | Sch 1 para 2 |
| Premiums, components | as working-age Housing Benefit | Sch 1 Parts 3-6 |
| Earnings disregards | £5, £10, £20, £25; the £17.10 step without UC | Sch 3 |
| Capital | £16,000; £1 a week per £250 or part above £6,000 (with UC £4.35 a month) | regs 63, 66 |
| Non-dependants | £16.55, £13.90, £10.95, £5.55 by income (£286, £497, £614) | reg 90 |
| On UC (an award above nil) | own applicable amount; UC earned income less the disregards, unearned and tariff income, the relevant UC payments (child and childcare elements, or the award if lower), less childcare costs element × 100/85 × 12/52 to the penny, up to £290 or £497 a week | regs 42, 49, 57(1)(p), 78 |
| Bands E to H | share (C − 1)/C of the bill: 3/43, 1/9, 7/47, 9/49; threshold £321 single with no child, £479 otherwise | regs 14, 79(2), (3) |
| Second adult rebate | 25 % (second adults on benefits), 15 % (gross income under £282), 7.5 % (under £383), 100 % (students) | Sch 2 |

Outputs: `council_tax_reduction_wa_364m_pence` (the reg 13 main reduction),
`council_tax_reduction_wa_second_adult_364m_pence`,
`council_tax_reduction_wa_bands_e_h_su_pence` and the entitlement
`council_tax_reduction_wa_total_su_pence`, in 1/(364 000 000 × 891 261) pence so
that the band shares are exact. Not modelled: self-employment, childcare charges
without UC, the extended reduction, joint liability.
### Council Tax Reduction: English local working-age schemes (`UkTax/CtrEnglandLocal.lean`)

The five councils' schemes PolicyEngine models, input `council_tax_reduction_local`
with `"country": "england"`. Kingston upon Thames, Merton, Newham and Westminster
follow the default scheme (SI 2012/2886) by the day; Oxford bands income.

| Council | Maximum | Taper | Allowances (single 25+, under 25, couple), a child | Non-dependants | Capital |
|---|---|---|---|---|---|
| Kingston upon Thames | 100 % | 20 % | £90.50, £71.70, £142.25; £83.24, none for a third child born after 1 April 2017 | £5.64 to £17.31 | £16,000 |
| Merton | 100 % | 20 % | £95.55, £75.65, £150.15; £87.88 | £5.20 to £15.95 | £16,000 |
| Newham | 70 % | 25 % (3 4/7 % a day) | the Housing Benefit amounts | £7.54 to £22.61 (bands £183, £316, £394) | £6,000 |
| Westminster | 100 % | 20 % | £95.55, £75.65, £150.15; £87.88 | £5.20 to £15.95 | £16,000 |
| Oxford | 100 %, 75 %, 50 %, 25 %, nil by weekly income to £480, £530, £580, £660 | none | none | £5.20 to £15.95 | £16,000 |

Without UC the default-scheme councils count net earnings less the Housing Benefit
disregards (£5, £10, £25, the £17.10 step), other income and tariff income (£1 per
£250 or part above £6,000), and disregard Child Benefit; with UC the UC maximum
amount against the UC income and award, × 12/52. Oxford counts all earnings
without UC; with UC, DWP's earned income, the award and other unearned income
(Child Benefit included), less £48.15 of each carer element and £84.46 of each
disabled child element. Output `council_tax_reduction_local_lcu_pence`, the year's
reduction in 1/36 400 000 000 pence. Not modelled: premiums, self-employment,
childcare, the class F (second adult) reduction.

### LBTT, LTT, lease rent and non-resident SDLT (`UkTax/LandTax.lean`)

Input `land_tax` with `"tax": "lbtt"`, `"ltt"` or `"sdlt"`. Tax by slices, in
1/10 000 pence.

| Tax | 2026-27 | Source |
|---|---|---|
| LBTT residential | 0 % to £145,000, 2 % to £250,000, 5 % to £325,000, 10 % to £750,000, 12 % | SSI 2015/126 Table A |
| LBTT first-time buyer | no tax on the first £175,000 | LBTT(S)A 2013 Sch 4A |
| LBTT additional dwelling supplement | 8 % of the whole price, from £40,000 | Sch 2A |
| LBTT non-residential; rent (NPV) | 0/1/5 % at £150,000, £250,000; 0/1/2 % at £150,000, £2m; residential leases exempt | Tables B, C; Sch 1 para 3 |
| LTT residential | 0 % to £225,000, 6 % to £400,000, 7.5 % to £750,000, 10 % to £1.5m, 12 % | WSI 2018/128 Table 1 |
| LTT higher rates | 5 %, 8.5 %, 10 %, 12.5 %, 15 %, 17 % at £180,000, £250,000, £400,000, £750,000, £1.5m; from £40,000 | Table 2; LTTA 2017 Sch 5 para 3 |
| LTT non-residential; rent (NPV) | 0/1/5/6 % at £225,000, £250,000, £1m; 0/1/2 % at £225,000, £2m | Tables 3, 4 |
| SDLT rent (NPV) | residential 0/1 % at £125,000; non-residential 0/1/2 % at £150,000, £5m | FA 2003 Sch 5 para 2 |
| SDLT non-resident | 2 % added to each residential rate | s75ZA |

A lease's rent, one entry a year, is taxed by its NPV at 3.5 % a year,
`Σ rᵢ / 1.035ⁱ`, held exactly over 207ⁿ. Not modelled: premiums with rent
(linked), multiple dwellings, rent reviews and overlap relief.

### Reliefs and the annual allowance charge (`UkTax/Reliefs.lean`)

Input `reliefs`: one individual's income from its sources.

| Relief | Rule | Source |
|---|---|---|
| Employment expenses | off the earnings, not below nil; NICs still on the pay | ITEPA 2003 ss 327-336 |
| Capital allowances, losses brought forward | off the trade's profits, for income tax and Class 4 | CAA 2001 s247; ITA 2007 s83; SSCBA 1992 Sch 2 para 3 |
| Gifts of shares and land | at Step 2, allocated with the allowances for the greatest reduction, lowering adjusted net income | ITA 2007 ss 24, 25(2), 431 |
| Finance costs | not deducted; a reduction of 20 % of the lowest of the costs, the property profits and adjusted total income | ITTOIA 2005 ss 272A, 274A, 274AA |
| Annual allowance charge | £60,000, tapered by half the adjusted income above £260,000 (threshold income above £200,000; reduction rounded down to £1; not below £10,000); the excess over it and unused allowance brought forward taxed as the top slice at the non-savings rates (Scottish: the basic rate up to the basic rate limit) | FA 2004 ss 227, 228, 228ZA |

The Step 2 relief is `Regime.step2` in the income tax engine: it is allocated with
the personal allowance by the same search, and taken off adjusted net income.
Not modelled: sideways loss relief (s64) and the s24A cap, more than one property
business or finance costs brought forward, defined benefit input amounts, member
contributions and the relief cap.

### Student loans and the Winter Fuel Payment (`UkTax/StudentLoans.lean`)

Input `student_loan` (`plans`: any of `plan_1`, `plan_2`, `plan_4`, `plan_5`,
`postgraduate`), on the case's own income; input `winter_fuel_payment` (England
and Wales: `over_80`, `relevant_benefit`, `partner_over_80`,
`with_entitled_under_80`, `with_entitled_80`, `residential_care`,
`partner_paid_benefit`), charged on the case's total income.

| Programme | Rule | Source |
|---|---|---|
| Student loan repayments | 9 % of income above the lowest threshold held among plans 1 (£26,900), 2 (£29,385), 4 (£33,795) and 5 (£25,000), and 6 % above £21,000 for a Postgraduate loan, concurrently; income is total income with property, savings and dividend income left out unless together over £2,000 | SI 2009/470 reg 29, Sch 1A |
| Winter Fuel Payment | £200 under 80 (£100 living with another person entitled or in a care home, unless paid a relevant benefit); £300 at 80, or on a relevant benefit with a partner of 80 (£200 or £150 sharing, by the other person's age); none for the partner of someone paid a relevant benefit | SI 2025/969 regs 2-4 |
| Winter fuel payment charge | the whole payment where total income exceeds £35,000, unless entitled to a relevant benefit in the qualifying week | ITEPA 2003 s681I (FA 2026 Sch 10) |

Not modelled: the outstanding balance as a cap, PAYE's pay-period deductions, the
other reg 29(4) adjustments (losses, incapacity benefit, ESA, pension relief not
already in total income). Scotland's Pension Age Winter Heating Payment is in
`UkTax/Devolved.lean`.

### Scotland's devolved benefits (`UkTax/Devolved.lean`)

Inputs for a household in Scotland (`country` `"scotland"`):
`scottish_child_payment` (`children_under_16`, `other_qualifying_benefit`; with
`uc`, the model's own award decides), `carer_support_payment`
(`overlapping_weekly_pence`, `additional_cared_for`; pay only), and
`winter_fuel_payment`, which in Scotland gives the Pension Age Winter Heating
Payment.

| Programme | Rule | Source |
|---|---|---|
| Scottish Child Payment | £28.20 a week for each child under 16 while UC or another qualifying benefit is awarded | SSI 2020/351 regs 14, 18, 20 |
| Carer Support Payment | £86.45 a week less overlapping benefits; none after a week with net earnings over £204 (net as for Carer's Allowance) | SSI 2023/302 regs 14, 16, Sch 2 |
| Scottish Carer Supplement, Carer Additional Person Payment | £11.70 a week, and £10.40 for each additional person cared for, while Carer Support Payment is payable | SSI 2023/302 regs 14A, 14B, 16(1A), (1B) |
| Pension Age Winter Heating Payment | the Winter Fuel Payment's rule with £316.70, £211.15, £158.35 and £105.55; charged like it | SSI 2024/351 regs 2A, 9, 10; ITEPA 2003 s681I |

### Early learning for disadvantaged 2-year-olds (`UkTax/Targeted.lean`)

A 2-year-old in England gets 15 hours a week for 38 weeks when the family is on
Universal Credit with earned income of at most £1,283.34 a month (a couple's
combined; £15,400.08 over twelve equal months), or on another qualifying benefit
(`targeted_other_benefit`), or the child has an EHC plan, DLA or is or was looked
after (`"targeted_criteria": true` on the child) (SI 2014/2147 regs 1, 3, 4). With
the working-parent hours the child has 30 in all, the first 15 targeted (DfE
statutory guidance para A1.11), so `funded_hours_targeted_millionths_pence` is
what they add to `funded_hours_millionths_pence`.

### Company cars, car fuel and the TV licence (`UkTax/CompanyCar.lean`)

Input `company_car`: `list_price_pence`, `capital_contributions_pence`,
`co2_g_km` (rounded down), `electric_range_miles` (rounded up),
`diesel_non_euro_6d`, `days_unavailable`, `private_use_payments_pence`,
`fuel_provided`; outputs the appropriate percentage and both cash equivalents in
1/36 500 pence. Input `tv_licence`: `required` (default true), `blind`,
`over_75_with_pension_credit`.

| Programme | Rule | Source |
|---|---|---|
| Company car benefit | list price less capital contributions (up to £5,000) × the appropriate percentage (2026-27: 4 % at 0 g/km; 4 % to 16 % at 1-50 g/km by electric range; 17 % to 21 % to 74 g/km; then 21 % plus a point for each 5 g/km above 75, at most 37 %; diesel not meeting Euro 6d 4 points more, at most 37 %), less the share for days unavailable, less payments for private use | ITEPA 2003 ss 121, 132, 139, 141, 143, 144 |
| Car fuel benefit | the appropriate percentage of £29,200, less the share for days unavailable; nil for a car that cannot emit CO2 | ss 149-152 |
| TV licence | £180; half for a blind holder; nil for a holder of 75 or over with Pension Credit (the BBC's concession) | SI 2004/692 Sch 1, reg 5; Communications Act 2003 s365A |

### ISAs, the minimum wage and the Warm Home Discount (`UkTax/Misc.lean`)

Inputs `isa` (`age`, `subscriptions_pence`, `lifetime_isa_payments_pence`),
`minimum_wage` (`age`, `apprentice`) and `warm_home_discount`
(`qualifying_benefit`, `bill_holder`, default true; England and Wales only).
Subscriptions over £20,000 a year are over the limit; the Lifetime ISA bonus is
25 % of up to £4,000 of payments from 18 to 49 (SI 1998/1870 regs 4ZA, 10A,
Schedule para 1), in quarter pence; the minimum wage is £12.71 an hour from 21,
£10.85 from 18, £8.00 under 18 and for apprentices (SI 2015/621 as amended by SI
2026/357); the Warm Home Discount is £150 (SI 2026/389) for a household on Pension
Credit, income-related ESA, Housing Benefit or Universal Credit.

### Vehicle Excise Duty for cars (`UkTax/Ved.lean`)

Input `vehicle_excise_duty`: `registered` (`from_april_2017`,
`march_2001_to_march_2017` or `before_march_2001`) with `co2_g_km`,
`diesel_non_rde2`, `zero_emission`, `registered_before_april_2025`,
`list_price_pence`, `licence_year` (0 for the first licence),
`registered_before_23_march_2006` or `engine_over_1549cc`; output
`vehicle_excise_duty_pounds`, the twelve-month single payment (VERA 1994 Sch 1
Parts 1A, 1AA, 1AB, rates from 1 April 2026 as on GOV.UK).

### Capital Gains Tax (`UkTax/Cgt.lean`)

| Figure | 2026-27 | Source |
|---|---|---|
| Rates | 18 % within the unused basic rate band, 24 % above it (residential property the same) | [TCGA 1992 s1H(3)](https://www.legislation.gov.uk/ukpga/1992/12/section/1H) (FA 2025 s7) |
| Annual exempt amount | £3,000, set against gains in the most beneficial way | [s1K(2), (5)](https://www.legislation.gov.uk/ukpga/1992/12/section/1K) |
| Business Asset Disposal Relief | 18 %, taking the unused basic rate band first; £1m lifetime limit (the caller's) | [s169N(3)](https://www.legislation.gov.uk/ukpga/1992/12/section/169N), [s1I(4)-(6)](https://www.legislation.gov.uk/ukpga/1992/12/section/1I) |

Inputs `capital_gains_pence` and `badr_gains_pence` (gains after losses); the unused
basic rate band is the basic rate limit, raised by Gift Aid and relief-at-source
contributions, less Step 3 income. Carried interest is charged to income tax from 6
April 2026 (Finance Act 2026 s58) and is not modelled; nor is investors' relief. A
Scottish taxpayer's gains are banded on the UK basic rate band: s1I applies "as if
the individual is not a Scottish or Welsh taxpayer"
([s1J(6)](https://www.legislation.gov.uk/ukpga/1992/12/section/1J)), whatever the
Scottish rates on their income.

### Stamp Duty Land Tax (`UkTax/Sdlt.lean`)

England and Northern Ireland, by slices of the consideration
([FA 2003 s55(1B)](https://www.legislation.gov.uk/ukpga/2003/14/section/55)):
residential 0 / 2 / 5 / 10 / 12 % at £125,000, £250,000, £925,000 and £1.5m;
first-time buyers 0 % to £300,000 and 5 % to £500,000, not above £500,000
([Sch 6ZA](https://www.legislation.gov.uk/ukpga/2003/14/schedule/6ZA)); additional
dwellings 5 / 7 / 10 / 15 / 17 % from £40,000
([Sch 4ZA](https://www.legislation.gov.uk/ukpga/2003/14/schedule/4ZA), FA 2025 s51);
non-residential 0 / 2 / 5 % at £150,000 and £250,000. Input `sdlt`. The
non-resident surcharge, leases and other reliefs are not modelled.

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
rates), National Insurance category letters other than A, Class 4 loss relief, the
Employment Allowance, freeport and veterans' employer reliefs, Universal Credit's
monthly rounding, the benefit cap's grace period, unused losses and surplus
earnings (regs 57A, 54A), Tax-Free Childcare and the funded hours for
disabled children, the childcare tests' routes for a partner who is disabled or a
carer, the lower minimum earnings for parents under 21 or apprentices, the 15
hours for disadvantaged 2-year-olds in net income and the cliff map (modelled
separately, `UkTax/Targeted.lean`), a child changing
age band during the year (the model takes one band for the year), Wales's,
Scotland's and Northern Ireland's own childcare schemes, income-related ESA, reliefs and deductions not listed above (losses and loss
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
- `employerNicExact_succ`, `class4Exact_succ`, `class4Exact_le_pre`
  (`UkTax/Nics.lean`): employer contributions and Class 4 never fall as pay or
  profits rise, and rise by at most 15 % and 6 % of a penny per penny; the reg 100
  maximum never raises Class 4. `class4Exact_full_class1`: with employee Class 1
  on the whole band, Class 4 is exactly 2 % of profits above £12,570.
- `netAll_drop_only_at_steps` (`UkTax/Benefits.lean`): the same with Universal
  Credit, Tax-Free Childcare (whichever is larger) and the funded hours added,
  with one more kind of step: adjusted net income going over £100,000. The
  minimum earnings test adds no step: reaching it gains Tax-Free Childcare and the
  working-parent hours.
- `caYear_cliff`, `caYear_anti`, `caYear_change` (`UkTax/Disability.lean`): more
  net earnings never give more Carer's Allowance, it changes only where a week's
  net earnings pass £204, and there the whole allowance goes at once.
  `netCarer_drop_only_at_steps` extends the cliff theorem to a carer: with the
  allowance taxed as income, a penny more pay lowers net income only where net
  earnings cross the limit, or, with the allowance unchanged, at a step of
  `net_drop_only_at_steps` at total income including it.
- `mifCouple_eq`, `uc_flat_below_floor`, `earned_plus_uc_mono_floor`
  (`UkTax/UcSelfEmployed.lean`): the couple rule of the minimum income floor is a
  plain lower bound on earned income; below the floor UC does not move as profit
  rises (each penny is kept in full); with the floor, earned income plus UC never
  falls as earned income rises.
- `ucAward_withCa`, `carer_uc_net`, `carer_uc_cliff` (`UkTax/CarerUc.lean`): while
  UC is in payment, each penny of Carer's Allowance takes a penny off it, so for a
  carer on UC the allowance changes net income only by the income tax and HICBC
  it brings, never for the better; at the earnings limit losing it raises net
  income by that tax.
- `ma_threshold_cliff`, `ma_mono`: Maternity Allowance is nil 1p below £30 of
  average weekly earnings and £27 at £30, and never falls above it.
  `jsa_total_succ`: earnings plus new style JSA never fall by more than 9p as
  earnings rise (the 10p minimum of reg 52; otherwise the deduction is pound for
  pound). `esa_total_gain`: pension plus new style ESA keeps at least half of
  any rise in pension.
- `pc_total_succ`, `pc_total_gain`, `sc_step`, `deemed_step` (`UkTax/Pension.lean`):
  income plus Pension Credit never falls as income rises (with qualifying income
  rising by the same amount, as it does unless the rise is in income reg 9 leaves
  out of qualifying income), except by at most a penny a week where amount B's
  rounding steps; above the minimum guarantee it keeps at least 60 % of such a
  rise; and each £500 of capital above £10,000 is exactly
  £1 a week of deemed income.
- `hbWa_passport`, `hbWa_capital_cliff`, `hbWa_additional_step`, `hbWa_earnings_gain`,
  `hbWa_cap_bounds`, `hbWa_cap_specified`, `hbWa_abolition`
  (`UkTax/HousingBenefitWa.lean`): working-age Housing Benefit is the maximum on a
  passporting benefit and nil a penny over £16,000; the £17.10 additional disregard
  is a step at which more earnings lower the income counted (HB rises); otherwise
  more earnings never give more HB and income plus HB keeps 35 % of a rise; the cap
  never raises HB or takes it below 50p a week, and in specified accommodation
  takes nothing unless the other benefits alone exceed it; an award ending on 1
  July 2026 pays 86/364 of the year.
- `hb_total_gain`, `hb_passport`, `hb_capital_cliff`, `nonDep_mono`
  (`UkTax/HousingBenefit.lean`): on the 65 % taper (`hbTaper`, the same maximum
  and applicable amount), income plus Housing Benefit keeps at least 35 % of any
  rise, which does not cover a rise that moves the claim between routes
  (guarantee credit, savings credit, capital limit) in `housingBenefit`; with the
  guarantee credit it is the maximum whatever the income and capital; without it,
  a penny over £16,000 of capital loses all of it; and a
  non-dependant's deduction never falls as their income rises.
- `ctrWalesUc_excess`, `ctrWaYear_bounds` (`UkTax/CtrWorkingAge.lean`): for a UC
  claimant in Wales the excess income is the household's earned income less 55 %
  of it above the work allowance, whatever the maximum amount, unearned income,
  Carer's Allowance or childcare element (they cancel while UC is in payment), so
  the reduction depends on earnings alone; a reduction never exceeds the bill and
  each unit of excess costs at most 73/364 of it.
- `scotBandsEH_le_main`, `scotBandsEH_floor`, `scotTotal_bounds`,
  `scot_capital_cliff` (`UkTax/CtrWorkingAge.lean`): in Scotland the bands E to H
  reduction adds nothing while income is at most the applicable amount; up to £321
  or £479 a week it is the whole band-rise share less the deductions, however far
  income is above the applicable amount; the entitlement is at least each part and
  at most the bill; a penny of capital over £16,000 ends all of it.
- `newham_at_most_70`, `localYear_taper`, `oxford_cliff_480`, `oxfordPct_anti`,
  `oxford_mono` (`UkTax/CtrEnglandLocal.lean`): Newham never pays a working-age
  applicant more than 70 % of the bill; on a council's taper more income never
  raises the reduction and each unit costs at most the taper for 365/7 weeks;
  Oxford's reduction never rises with income, and a penny a week above £480.00
  (likewise £530, £580, £660) costs a quarter of the bill.
- `bandsTax_add`, `sdlt_nonResident`, `lbtt_ads_cliff`, `ltt_higher_cliff`,
  `lbtt_succ`, `ltt_succ` (`UkTax/LandTax.lean`): adding 2 % to every rate adds
  exactly 2 % of the whole price, so the SDLT non-resident surcharge is 2 % of the
  consideration for every residential kind; Scotland's supplement and Wales's higher
  rates start at £40,000 (nil, then £3,200 and £2,000); a penny more never lowers
  LBTT or LTT.
- `aaCharge_le`, `aaTax_slice`, `allowance_bounds`, `financeReduction_le`
  (`UkTax/Reliefs.lean`): the annual allowance charge is never more than 48 % of
  the excess (45 % outside Scotland) and more excess never lowers it; the tapered
  allowance stays between £10,000 and £60,000; the finance cost reduction is at
  most 20 % of the costs and never more than the tax. `net_drop_only_at_steps` now
  holds with Step 2 reliefs (gifts of shares) as well.
- `threshold_le`, `sl_unearned_cliff`, `sl_unearned_cliff_size`,
  `sl_succ_earned`, `wfpAmount_le`, `wfp_charge_cliff`, `wfp_charge_benefit`
  (`UkTax/StudentLoans.lean`): the threshold is the lowest of the plans held;
  £2,000 of unearned income adds nothing to student loan income and £2,000.01 adds
  all of it, £180.0009 more of repayments above the threshold; otherwise a penny
  more earned income adds 0 to 0.15p; the Winter Fuel Payment is at most £300; a
  penny of total income above £35,000 charges the whole payment, and a relevant
  benefit removes the charge at any income.
- `wfpAmount_eq`, `scp_cliff`, `csp_cliff`, `pawhpAmount_le`
  (`UkTax/Devolved.lean`): the Winter Fuel Payment and the Scottish payment are one
  rule with two sets of amounts; when a family's Universal Credit ends, £1,466.40 a
  year of Scottish Child Payment goes for each child; a penny a week of net earnings
  above £204 takes away Carer Support Payment, the supplement and the additional
  person payments together (£5,103.80 a year, and £540.80 for each additional
  person); the heating payment is at most £316.70.
- `targeted_cliff`, `targetedValue_two`, `targetedExtra_working`
  (`UkTax/Targeted.lean`): a penny of earned income a year past £15,400.08 takes
  away a 2-year-old's targeted hours, £5,073 at the DfE rate, for a family without
  the working-parent hours; with them the targeted hours add nothing.
- `carPct_bounds`, `carPct_mono`, `carPct_range`, `car_50g_step`
  (`UkTax/CompanyCar.lean`): the appropriate percentage stays between 4 % and
  37 %, never falls as CO2 rises or rises as the electric range grows, and jumps
  from 4 % to 17 % between 50 and 51 g/km for a long-range hybrid (£5,200 more
  benefit on a £40,000 car).
- `lisaBonus_le`, `lisa_age_cliff`, `minimumWage_mono` (`UkTax/Misc.lean`): the
  Lifetime ISA bonus is at most £1,000 a year and stops at 50 (£1,000 on £4,000 at
  49, nothing at 50); the minimum wage never falls with age outside
  apprenticeships.
- `ved_supplement_cliff`, `vedFirst_top`, `vedFirst_mono` (`UkTax/Ved.lean`): a
  penny over a £40,000 list price costs £440 a year in licence years 2 to 6; the
  first licence never costs less as CO2 rises (checked gram by gram to 260 g/km,
  constant above 255).
- `ctr_step`, `ctr_full`, `councilTax_discount` (`UkTax/CouncilTax.lean`): each
  extra unit of weekly income above the applicable amount costs exactly 20 % of it
  for 365/7 weeks of Council Tax Reduction, never more; with no excess and no
  non-dependants the reduction is the whole bill; the single person discount is
  exactly a quarter.
- `cgt_succ_other`, `cgt_succ_badr`, `cgt_band`, `cgt_exempt` (`UkTax/Cgt.lean`):
  more gains never lower Capital Gains Tax and each penny adds at most 24p; each
  penny less of unused band adds at most 6p; gains up to £3,000 are tax-free.
  `cgtBand_scottish`: a Scottish taxpayer's band is the UK one (s1J(6)).
- `sdlt_succ`, `ftb_cliff`, `higher_cliff` (`UkTax/Sdlt.lean`): a penny more
  consideration never lowers SDLT, for every kind of transaction including the
  higher rates' start; the theorem leaves out only the first-time buyer's penny
  from £500,000. Both cliffs are jumps up: first-time buyers' relief ends at
  £500,000 (£10,000 of tax, then £15,000.0005), and the higher rates start at
  £40,000 (nil, then £2,000).
- `fundedHours_over_limit`, `fundedHours_drop_at_limit`: over £100,000 the funded
  hours are worth exactly the universal hours, and for a parent eligible at
  £100,000 the penny over loses exactly the working-parent hours, never the
  universal 15.
  `earned_plus_uc_mono`, `earned_plus_uc_gain`: earned income plus UC never
  falls as earned income rises, and keeps at least 45 % of any rise, with every
  element, the childcare work condition (`childcareMicro_mono`) and the benefit
  cap (`capApplies_anti`: its earnings exception, once met, stays met). So the full
  UC adds no step to `netAll_drop_only_at_steps`: meeting the childcare work
  condition or the cap's earnings exception only raises net income. `netAll_succ_ge`: between steps, a penny more pay
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

`tests/golden.json` holds 164 cases with the expected figures worked out by hand
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
each limit, the halved limit, and a rent-a-room loss set against other letting). For the non-means-tested
benefits: 53 weeks of Child Benefit with the HICBC on it, each disability benefit,
Carer's Allowance 1p either side of the earnings limit (and net income across it),
with pension contributions and an overlapping benefit, Maternity Allowance at the
threshold and the cap, JSA's 10p minimum, ESA's pension deduction and the grant. For pensions: the guarantee credit,
savings credit at its rounded maximum and with amount A rounded up, income net of
tax, a couple's £10 earnings disregard, the capital step 1p over £12,000, the
severe disability amount, and the new State Pension's reduced rate and minimum.
For Housing Benefit: the passport, the 65 % taper with tax deducted, the pre-2021
allowance, a non-dependant band, the capital limit 1p over, savings credit only,
and the LHA cap. For council tax: a band in each nation (Wales's band I), the
single person discount, and the pensioner reduction's taper over 365 days, a
non-dependant band, Wales's £256 allowance and a Scottish non-dependant. For CGT:
gains within and across the band, BADR taking the band first, the exempt amount,
Gift Aid extending the band, and a Scottish higher-rate taxpayer with gains inside
the UK band. For Carer's Allowance with UC: the allowance deducted from UC, and
1p either side of the limit. For UC and self-employment: the floor (in whole
pounds and with the pence kept), a profit above it with tax and Class 4 deducted, a
loss beside pay, and a couple's floor cut back to the couple threshold. For SDLT: each kind, both cliffs and the top band.

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
  Child Benefit in whole pounds (£13.99 to £14.99 with one child, £32.99 to £33.99
  with three), each followed by a £24 to £59 pay range where net income is lower.
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

### Universal Credit in full against PolicyEngine

`uv run python compare_uc_full.py` builds households with every modelled element
(under-25 rates, the pre-2017 first child, LCWRA at either rate, carer, childcare,
private and social rent, capital, two earners, the benefit cap in and outside
London with PolicyEngine's own Child Benefit), plus edge cases at the capital
limits and the cap's earnings exception. Latest local run: 1,029 of 1,029 agree
within 2 float32 steps plus 0.95p (the partner's earned income passed in whole
pence, and the NIC gap). Social renters have no spare bedroom: PolicyEngine has no
under-occupancy deduction (findings #16).

### Universal Credit for the self-employed against PolicyEngine

`uv run python compare_uc_se.py` compares a claimant with a trade (profit or loss)
and perhaps pay, single or with an employed partner, 0 to 3 children, with edge
cases around the floor. Whether the floor applies and the expected hours are
DWP's determinations, read from PolicyEngine and passed to the model with the
threshold's pence kept, as PolicyEngine keeps them. Latest local run: 1,011 of
1,011 agree within 2 float32 steps plus 0.95p (1,010 with the floor, 797 below it,
341 couples, 29 with a loss beside pay; expected hours 30 or 35).

### National Insurance against PolicyEngine

`uv run python compare_nics.py` compares employer Class 1 (annual basis, aged 40
or 20), Class 1A, Class 4 (with the reg 100 maximum where there is also pay) and
Class 2 (nothing payable as of course). Latest local run: 580 of 580 agree within
2 float32 steps (worst 1.57), 117 of them with both employee Class 1 and Class 4.

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

### Non-means-tested benefits against PolicyEngine

`uv run python compare_disability.py` compares every combination of PIP, DLA and
Attendance Allowance rates, Carer's Allowance for a carer with pay and net pay
pension contributions (edge cases 1p either side of the limit and random pay),
the same carers on Universal Credit with 0 to 3 children, and Child Benefit for 1
to 4 children. Latest local run: 324 of 324 rate combinations, 1,007 of 1,007
carers (508 paid) and 1,012 of 1,012 carers on UC (880 with UC paid, 519 with both)
agree within 2 float32 steps (on UC plus 55 % of PolicyEngine's 0.32p NIC gap,
findings #1, above the primary threshold).
Child Benefit agrees on the weekly rate and differs by one week a year:
PolicyEngine pays 52 weeks, the law 53 in 2026-27 (findings #19, a draft issue).
Maternity Allowance, new style JSA and ESA and the Sure Start Maternity Grant are
reported amounts in PolicyEngine, so there is nothing to compare (findings #20).

### Pension Credit against PolicyEngine

`uv run python compare_pension.py` compares single pensioners and couples aged 70
or 80 (savings credit), with State Pension, private pensions and capital, edge
cases at the savings credit threshold and the capital steps. Latest local run:
1,010 of 1,010 agree (827 paid, 92 with savings credit) within 2 float32 steps,
the reg 7(4) rounding PolicyEngine leaves out (up to 2p a week; at most 61p a year
seen; findings #22) and a penny a partner for the income tax, which PolicyEngine
deducts unrounded.

### Housing Benefit for pensioners against PolicyEngine

`uv run python compare_housing.py` compares social renters aged 70 or 80, single
or couples, with pensions, savings and, in some households, a working
non-dependant in each band. Latest local run: 1,013 of 1,013 agree (893 paid),
within 2 float32 steps plus 65 % of the savings credit rounding of findings #22
(largest difference 39p a year). Households with a non-dependant have no savings,
since PolicyEngine shares household savings between benefit units (findings #26).

### Working-age Housing Benefit against PolicyEngine

`uv run python compare_housing_wa.py` compares working-age council tenants
(single, under 25, lone parents, couples, 0 to 3 children) with pay and savings, in
specified, temporary and general accommodation, some on Universal Credit, with the
benefit cap. Two documented PolicyEngine limitations are put on its basis: it
leaves out the £87.88 child amount (its open issue #2825) and does not count
Housing Benefit as nil for the cap in specified accommodation (its documentation
says the input does not implement that); it also caps the year at the unrounded
annual limit where the law caps each week at the limit ÷ 52 to the penny. Latest
local run: 1,017 of 1,017 agree within 2 float32 steps plus 0.4p (921 paid, 65 on
UC). In law the child amount adds up to £8,742 a year for the 357 families with
children, specified accommodation up to £847 where the cap would bite, and the
weekly cap gives 8p to £63.35 a year less where it binds (findings #34).

### Council Tax Reduction in Wales for working-age applicants against PolicyEngine

`uv run python compare_ctr_wa.py` compares working-age households in Wales (single,
under 25, lone parents, couples, 0 to 3 children) with pay and savings, half on
UC. On PolicyEngine's 52-week basis (findings #27: its withdrawal is 364/365 of the
law's), latest local run: 1,009 of 1,009 agree within 2 float32 steps plus 0.4p
(and 2 steps of the UC amounts on UC; 796 paid, 510 on UC).

With `--country scotland` it compares the same households in Scotland, with UC
childcare costs for lone parents, against the reg 13 main reduction (PolicyEngine
models neither reg 14 nor the second adult rebate). Latest local run: 1,021 of
1,021 agree within the same tolerance plus 5.3p where there are childcare costs
(reg 78(3) rounds the weekly charges to the penny; 846 paid, 515 on UC). The
bands E to H reduction PolicyEngine leaves out is worth £244.44 a year to a single
person in band F with a £2,200 bill and £321 a week, and £164.13 more than reg 13
to a couple in band H with £4,000 and £479 a week (findings #36).

### English local Council Tax Reduction schemes against PolicyEngine

`uv run python compare_ctr_local.py` compares the five councils like with like: UC
claimants everywhere (any family, pay, capital), and the own rules where
PolicyEngine's omissions do not apply (findings #37: no children, no earnings,
Merton below £6,000 of capital, not Kingston) and in Oxford with children and pay.
Latest local run: 860 of 860 agree on PolicyEngine's 52-week basis within 2 float32
steps plus 0.4p (552 claiming UC; 175 households left out as not like with like).
Under the schemes a lone parent with two children and £15,000 of pay gets the whole
£1,800 bill in Kingston, Merton and Westminster (£1,260 in Newham); PolicyEngine
gives nil.

### LBTT, LTT and lease rent against PolicyEngine

`uv run python compare_land.py` compares purchases in Scotland and Wales (random
prices and 1p either side of each limit) and non-residential leases of 1 to 25
years in all three nations, giving PolicyEngine each lease's NPV as its rent
input. Latest local run: 1,122 of 1,122 agree (526 leases). PolicyEngine charges
Scotland's supplement and Wales's higher rates below £40,000 (£2,400 and £1,500 on
a £30,000 additional dwelling, where the law charges nil); those 34 purchases are
counted, not compared (findings #38).

### Reliefs and the annual allowance charge against PolicyEngine

`uv run python compare_area6.py` compares individuals in England and Scotland with
pay, employment expenses, a trade with capital allowances and losses brought
forward, property profits with finance costs, savings, dividends, gifts of
shares, and employer pension contributions with carry-forward. Latest local run:
832 of 832 agree on income tax, the charge, the allowance and Class 4 (287 with a
charge). PolicyEngine deducts gifts of shares as an allowance rather than from net
income, so it does not lift the personal allowance or the pension taper: 168
households with gifts and net income above £100,000 are counted, not compared
(findings #39).

### Student loans and the Winter Fuel Payment against PolicyEngine

`uv run python compare_p9a.py` compares borrowers on each plan with pay, pension
income, savings and dividends, and households of pensioners in England and Wales
(couples, single people and others sharing the home, some with Pension Credit).
Latest local run: 730 of 730 repayments agree (617 repaying) and 2,068 of 2,068
people's payment and charge agree (662 charged). PolicyEngine counts unearned
income of £2,000 or less, which reg 29(4)(c) leaves out: 295 such borrowers are
counted, not compared, up to £180 a year apart (findings #40).

### Scotland's devolved benefits against PolicyEngine

`uv run python compare_p9b.py` compares families in Scotland on Universal Credit
(the Scottish Child Payment), carers with pay and pension contributions (Carer
Support Payment and the supplement), and pensioner households (the Pension Age
Winter Heating Payment and the charge). Latest local run: 1,000 of 1,000, 1,007 of
1,007 and 2,042 of 2,042 agree; 7 families at the end of UC and 1 carer at the
earnings limit are float32 precision. PolicyEngine has no Carer Additional Person
Payment (findings #41).

### Company cars and the TV licence against PolicyEngine

`uv run python compare_p9d.py` compares random company cars across every CO2 band
edge and electric range edge, petrol and diesel, with contributions, days
unavailable, payments and fuel, and the TV licence for blind and older holders.
Latest local run: 1,033 of 1,033 and 16 of 16 agree (findings #43).

### ISAs, the minimum wage and the Warm Home Discount against PolicyEngine

`uv run python compare_p9e.py` compares subscriptions and Lifetime ISA payments
around the limits at ages 16 to 60, the minimum wage at 15 to 30 with and without
an apprenticeship, and the Warm Home Discount in England, Wales and Scotland on
each qualifying benefit. Latest local run: 1,036 of 1,036 agree (findings #44).

### Vehicle Excise Duty against PolicyEngine

`uv run python compare_p9f.py` compares cars first registered from 1995 to March
2027 in every fuel type, at each CO2 band edge, around the list price thresholds
and either side of 1,549cc. Latest local run: 1,297 of 1,297 agree (findings #45).

### Council tax and Council Tax Reduction against PolicyEngine

`uv run python compare_council_tax.py` compares council tax for every band in the
three nations with one or two adults, and the pensioner reduction in each nation
(ages 70 and 80, pensions, savings, non-dependants in each band or with no
income). Latest local run: council tax 1,000 of 1,000; the reduction 1,024 of
1,024 on PolicyEngine's 52-week basis. PolicyEngine annualises the daily schemes
at 52 weeks instead of 365/7, so it withdraws 364/365 of the law's amount and
pays up to £9.75 a year more (findings #27, a draft issue).

### Capital Gains Tax against PolicyEngine

`uv run python compare_cgt.py` compares taxpayers, a third of them Scottish, with
pay, savings, dividends, Gift Aid, gains and BADR gains, with edge cases at the
exempt amount and the basic rate limit, and Scottish higher-rate taxpayers inside
the UK band. Latest local run: 1,014 of 1,014 (341 Scottish) agree within 2
float32 steps (worst 0.39).

### Stamp Duty Land Tax against PolicyEngine

`uv run python compare_sdlt.py` compares purchases of each kind at random prices
and 1p either side of every limit. Latest local run: 1,108 of 1,108 agree; at
£500,000.01 PolicyEngine's float32 price rounds to £500,000 and keeps the
first-time buyers' relief (findings #31).

### Funded hours against PolicyEngine

`uv run python compare_childcare.py` compares the funded hours' yearly value for a
lone parent or a couple (partner's pay fixed at 0 to £100,000.01, including 1p
either side of the minimum earnings) with children aged 1, 2, 3, 1 and 3, or 2
and 3, in England and in Wales, from £0 to £150,000 of pay. PolicyEngine values
the hours the same way (its `gov.dfe.childcare_funding_rate` holds the same Table 6
rates, 38 weeks), so it checks the eligibility and the hours. Latest local run:
3,094 cases with `--random 1000` (907 with working-parent hours); 3,088 agree
within 2 float32 steps a child (largest difference 0.12p), 503 of them with the
15 hours for disadvantaged 2-year-olds (£5,073 at £8.90), for lone parents and
one-earner couples on Universal Credit, which both sides work out. 6 couples where
both work differ only by those hours, which the model's Universal Credit cannot
give them (no couple where both work), and 1 sits in the 8p window of findings
#42.

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
comparisons (income tax, NICs and HICBC; Universal Credit; funded hours, UC in full, NICs,
non-means-tested benefits, Pension Credit, Housing Benefit, council tax, CGT and
SDLT, with 1,000 random cases each; reliefs and allowances).

## In the browser (WebAssembly prototype)

A prototype: `web/` is a static page that runs the model in the browser, with no
server, from a WebAssembly build of `uktax`. Enter pay, savings, dividends,
children and childcare, where you live and a few benefit inputs; it shows
take-home pay with its breakdown and a take-home-against-pay chart swept live
by the model, with each cliff found to the penny. It has a button to run the
golden cases in the page.

**Route: Lean → C → Emscripten** (`wasm/build.sh`). `lake build` leaves the
model's C in `.lake/build/ir`. Toolchains ship no C for the Lean core modules,
so the ones `Main` needs (`Init`, `Lean.Data.Json` and what they import, 727
modules) are compiled to C with the toolchain's own `lean -c` from the sources
it ships. The Lean runtime is built for wasm32 from the Lean source at the
toolchain's version, single-threaded (so no cross-origin isolation headers are
needed), with two small fixes in `wasm/lean-runtime-emscripten.patch`. A C shim
(`wasm/shim.c`) exports `uktax_run`: JSON in, JSON out, through the same `run`
function and `Json.compress` as the CLI, so `Main.lean` is compiled unchanged.
In JavaScript, `web/model.js` wraps it (`calculate`, `calculateText`).

Build (needs elan, git, cmake, make, python3; Emscripten 7.0.1 is used from
`PATH` or installed into `.wasm-build/`, where all downloads and build output
stay):

```sh
wasm/build.sh                     # writes web/dist/uktax.mjs and uktax.wasm
python3 -m http.server -d . -b 127.0.0.1 8000  # serve the repository root, locally only
# open http://localhost:8000/web/
```

Serve the repository root, not `web/`, so the page's golden-case check can read
`tests/golden.json`.

**Equivalence with the native binary**: `node wasm/equivalence.mjs --random
1000` runs the golden inputs, 1,000 random variations of them (every whole
number in an input rescaled, so some are rejected) and 1,000 random households
through both builds and requires identical JSON text, and the same error message
where the model rejects an input. It runs in CI (the `wasm` job). On 2026-11-27:
2,215 inputs, 0 mismatches. In Chrome, the golden inputs give output whose
SHA-256 equals the native binary's.

**Measured** (2026-11-27, `-O2`, a desktop machine, Chrome and Node 26):

| | |
|---|---|
| `uktax.wasm` | 1.96 MB, 338 KB gzipped |
| `uktax.mjs` (Emscripten's loader) | 61 KB, 17 KB gzipped |
| load (fetch, compile, initialise) | about 105–120 ms from localhost |
| one calculation | about 1 ms in Chrome (median of 200), 0.3 ms warm in Node; native 0.2 ms |
| the chart's sweep, 601 cases in one call | about 0.7 s in Chrome on first draw |
| build from nothing | about 4 minutes on 6 cores, then about 2 minutes after a model change |

`WASM_OPT=-Oz wasm/build.sh` gives 0.89 MB (252 KB gzipped) and runs about 1.6
times slower.

**Limits.** It is a prototype for trying the model, not a product. It uses the
built-in 2026-27 figures: every call in `web/model.js` takes a `params`
argument, and anything other than the built-in set is refused until the model
takes a parameter set as JSON. The page asks only for the inputs above; the rest
of the model (self-employment, disability and carer benefits, Pension Credit,
Housing Benefit, council tax, CGT, the land taxes and so on) is reachable through
`calculate` with the CLI's JSON but has no form. Upstream Lean does not test its
Emscripten build (the job is switched off in its CI), so a toolchain upgrade may
need the patch updated; the equivalence check is what tells us the build is
still right.
