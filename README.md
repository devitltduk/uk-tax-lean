# uk-tax-lean

UK income tax, employee National Insurance, the High Income Child Benefit
Charge, a minimal Universal Credit and the £100,000 childcare cliff for 2026-27,
for taxpayers in England, Wales and Northern Ireland (not Scottish taxpayers;
childcare rules are England's), formalised in Lean 4, with proofs about it and a harness that checks it against
[PolicyEngine UK](https://github.com/PolicyEngine/policyengine-uk).

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

All amounts are whole pence (`Nat`), and rates are basis points. Tax is computed
exactly, in 1/10,000 of a penny, and rounded down to the penny once at the end.

### 2026-27 figures and sources

Checked against legislation.gov.uk and GOV.UK on 2026-11-26. Each one is in
`UkTax/Params.lean` with its citation.

| Figure | 2026-27 | Source |
|---|---|---|
| Personal allowance | £12,570 | [ITA 2007 s35(1)](https://www.legislation.gov.uk/ukpga/2007/3/section/35); frozen by FA 2021 s5, FA 2026 s10 |
| Taper | above £100,000, half the excess, round up to £1 | ITA 2007 s35(2)-(3) |
| Basic rate limit | £37,700 | [ITA 2007 s10(5)](https://www.legislation.gov.uk/ukpga/2007/3/section/10) |
| Higher rate limit | £125,140 (2 × PA + £100,000) | ITA 2007 s10(5A) |
| Basic / higher / additional rate | 20 / 40 / 45 % | [Finance Act 2026 s2](https://www.legislation.gov.uk/ukpga/2026/11) |
| Savings rates | 20 / 40 / 45 % | Finance Act 2026 s3 |
| Starting rate for savings | 0 % up to £5,000 | [ITA 2007 s12](https://www.legislation.gov.uk/ukpga/2007/3/section/12); FA 2026 s9 |
| Personal savings allowance | £1,000 / £500 / £0 | [ITA 2007 s12B](https://www.legislation.gov.uk/ukpga/2007/3/section/12B) |
| Dividend allowance | £500 | [ITA 2007 s13A](https://www.legislation.gov.uk/ukpga/2007/3/section/13A) |
| Dividend ordinary / upper / additional | 10.75 / 35.75 / 39.35 % | [ITA 2007 s8](https://www.legislation.gov.uk/ukpga/2007/3/section/8) as amended by FA 2026 s4 |

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

A lone parent is eligible when they expect to earn at least £10,574.72 a year
(16 hours a week at the £12.71 National Living Wage, as £2,643.68 a quarter) and
their adjusted net income is not over £100,000. Tax-Free Childcare adds 20 % of
each child's childcare costs (£2 for every £8 paid in), up to £2,000 a child a
year. It can't be had with Universal Credit, so net income counts whichever is
larger. The working-parent funded hours are lost at the same £100,000; they are
in kind, so their yearly value is an input (`funded_hours_value_pence`) with no
default figure.

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

## Out of scope

Scottish rates (Welsh rates are in scope only because they equal the rUK rates
in 2026-27), National Insurance other than employee Class 1 primary contributions
(employer, self-employed, voluntary, other category letters), Universal Credit
beyond the minimal model (housing, childcare, disability and carer elements,
capital, unearned income, the benefit cap, the minimum income floor, under-25
rates, the first-child rate for children born before 6 April 2017, monthly
rounding, couples where both work), Tax-Free Childcare for couples and for
disabled children, legacy benefits, reliefs and deductions (pension
contributions, Gift Aid, losses, the trading and property allowances), Marriage
Allowance and Blind Person's Allowance, other tax reductions, property income's
own rates (from 2027-28), the default rates for non-residents, top-slicing relief,
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
  It rests on `taxExact_succ_le` (with both allowances fixed, a penny more pay
  adds at most 0.686p of income tax) and `net_succ_ge` (between steps net income
  rises at least 0.234p per penny, so the marginal rate there is at most 76.6 %).
- `netAll_drop_only_at_steps` (`UkTax/Benefits.lean`): the same with Universal
  Credit, Tax-Free Childcare (whichever is larger) and the funded hours added,
  with one more kind of step: adjusted net income going over £100,000.
  `earned_plus_uc_mono`: earned income plus UC never falls as earned income
  rises (the taper is 55 %).

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

`tests/golden.json` holds 28 cases with the expected figures worked out by hand
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
adjusted net income.

### Where earning more lowers net income

`python3 harness/cliffs.py` (about 2 minutes) writes [`docs/cliffs.md`](docs/cliffs.md) (every drop,
by household type, with its size and the pay range after it where net income stays
lower) and [`docs/emr.svg`](docs/emr.svg) with its table `docs/emr.csv` (effective
marginal rates on each £200 of pay). Net income there is the proved `netAll`, read from
`uktax` (`net_income_millionths_pence`), and the script evaluates it exactly at every
step penny that `netAll_drop_only_at_steps` allows, so the list is complete within
the model; nothing is sampled. CI checks that the docs match the model, and the
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
  loses Tax-Free Childcare, £1,999.99 with one child in £10,000 of childcare and
  £3,999.99 with two, and net income stays below its level at £100,000 for the
  next £5,263 / £10,526 of pay (the loss divided by the 38 % kept in the 60 % band).
  The funded hours go at the same penny and add their value to the drop.
- **Universal Credit** adds no drops: the 55 % taper on top of tax and NICs takes
  at most 89.5 % of a penny between steps, and moving between UC and Tax-Free
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
- The personal allowance is the same in both.
- The personal savings allowance is the same in both.
- Employee NICs are within the same float32 tolerance (at the employee's pay),
  plus 0.32p: PolicyEngine stores the weekly thresholds as £241.73 and £966.73
  (the annual figures ÷ 52) without the round-up to a whole pound in
  SI 2001/1004 reg 11(4), so over a year its thresholds are 4p below £12,570 and
  £50,270. The model is compared on its annual basis.
- The High Income Child Benefit Charge is equal (both whole pounds). Child
  Benefit is passed to PolicyEngine as an input so both charge the same amount,
  and the charge is taken off PolicyEngine's `income_tax`, which includes it.

Cases split non-savings income between pay and pension (passed to PolicyEngine as
`private_pension_income`) and carry 0 to 3 children's Child Benefit, with extra
edge cases at the NIC thresholds and at the HICBC steps.

It writes `harness/out/comparison.csv` and exits non-zero if any check fails.

It runs in CI as well (about 30 s for 3,000 cases). Latest local run:
7,198 cases (2,198 edge, 5,000 random). Every income tax is within 2 steps
(worst 1.13 steps, 1.76p), every NIC figure within tolerance (largest difference
0.39p), and every personal allowance, savings allowance and HICBC agrees. On NixOS, numpy needs
`libstdc++`: run with `LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH` (nix-ld) or from a
shell that provides it.

### Universal Credit against PolicyEngine

`uv run python compare_uc.py` compares the award for a single claimant with 0 to
4 children and a one-earner couple with 0 to 3 children, from £0 to £80,000 of
pay. Latest local run: 5,603 cases (2,729 with UC paid), all within 2 float32
steps plus 0.176p (55 % of the NIC threshold gap above); largest difference 0.43p.

By default PolicyEngine treats the couple as married and claiming the Marriage
Allowance (its `would_claim_marriage_allowance` take-up flag), which gives the
earner £1,260 of the partner's allowance: £252 less tax and £138.60 more UC a
year. That's a default, not an error. The model has no Marriage Allowance, so the
harness sets it to 0 for couples.

## CI

GitHub Actions (`.github/workflows/ci.yml`) builds with `--wfail`, checks the
proofs and the axiom guard, runs the golden cases, regenerates the cliff map
(failing if `docs/` no longer matches the model), then runs the PolicyEngine
comparisons (income tax, NICs and HICBC; Universal Credit) with 1,000 random cases
each.
