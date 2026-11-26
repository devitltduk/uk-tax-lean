# UK tax and benefit cliffs for 2026-27, formalised in Lean

**Draft, not for publication.** Nothing here has been shared outside this
repository. Suggested outreach is listed at the end for the owner to decide.

## Summary

This repository models a UK taxpayer's 2026-27 income tax (England, Wales and
Northern Ireland), employee National Insurance, the High Income Child Benefit
Charge (HICBC), a minimal Universal Credit (UC), Tax-Free Childcare and the
£100,000 limit on the working-parent funded hours, in Lean 4. It proves facts about
the model, checks it against hand-worked cases, and compares it with
[PolicyEngine UK](https://github.com/PolicyEngine/policyengine-uk) 2.180.2.

The main results:

1. **The model computes the s25(2) liability exactly.** ITA 2007 s25(2) says
   allowances are deducted "in the way which will result in the greatest
   reduction in the taxpayer's liability". The model searches the allowance
   placements, and it is *proved* that the search finds the least tax for every
   income (`isLeastTax_taxExact`). As a consequence the computed liability is
   proved monotone in every kind of income (`liability_mono`).
2. **The complete list of places where earning more lowers net income is a
   theorem.** For a household whose pay varies (with any fixed savings,
   dividends, Child Benefit, pay period and benefit claims), one more penny of
   pay can lower net income only at four kinds of penny
   (`netAll_drop_only_at_steps`). The cliff map evaluates every such penny
   exactly, so it is complete within the model.
3. **The "60 % band" between £100,000 and £125,140 is a staircase of 12,570
   small cliffs**, not a smooth 60 % rate, because the tapered personal allowance
   is rounded *up* to a whole pound (ITA 2007 s35(3)).
4. **PolicyEngine UK agrees** on income tax, NICs, HICBC and UC to within its
   float32 precision on about 12,800 cases. The one difference that looks like
   a PolicyEngine error is small: it leaves out a round-up in the NIC thresholds
   for weekly and monthly pay (up to £1.12 a year).

## What is modelled

All figures for 2026-27, each cited in `UkTax/Params.lean` and the README, checked
against legislation.gov.uk and GOV.UK on 2026-11-26.

| Part | What | Main sources |
|---|---|---|
| Income tax | Non-savings, savings and dividend income; personal allowance £12,570 tapered above £100,000 and rounded up to £1; bands £37,700 / £125,140; 20 / 40 / 45 %; starting rate for savings (£5,000 at 0 %); personal savings allowance £1,000 / £500 / nil; dividend allowance £500; dividend rates 10.75 / 35.75 / 39.35 %; s25(2) allowance placement | ITA 2007 ss 6-16, 25, 35; Finance Act 2026 ss 2-4, 9-10 |
| Employee NICs | Class 1 primary, category A: 8 % from the primary threshold (£12,570 a year, £1,048 a month, £242 a week) to the upper earnings limit (£50,270 / £4,189 / £967), 2 % above; annual, monthly or weekly earnings period, equal pay each period | SSCBA 1992 s8; SI 2001/1004 regs 10-11 as amended by SI 2026/231 |
| HICBC | 1 % of Child Benefit per whole £200 of adjusted net income over £60,000, capped at 100 %; benefit, percentage and charge each rounded down | ITEPA 2003 s681C |
| Universal Credit | Standard allowance (£424.90 single, £666.97 joint, 25 or over), child element £303.94 with no two-child limit, higher work allowance £710, 55 % taper on pay less tax and NICs | SI 2013/376 regs 22, 36, 55; SI 2026/148; Universal Credit (Removal of Two Child Limit) Act 2026 |
| Childcare | Tax-Free Childcare (20 % of costs up to £2,000 a child), lost over £100,000 adjusted net income, minimum earnings £2,643.68 a quarter; funded hours lost at the same limit (value is an input) | SI 2015/448 reg 15; GOV.UK |

Out of scope (see the README for the full list): Scottish rates, reliefs (pension
contributions, Gift Aid), Marriage Allowance, self-employment, UC housing,
childcare, disability and carer elements, capital and the benefit cap, couples
where both work, per-period rounding of NICs and UC, and every other tax year.

## What is proved, tested and solver-checked

Nothing is solver-checked. Every guarantee below is a Lean proof using only
Lean's core `omega` decision procedure and the standard axioms (`propext`,
`Classical.choice`, `Quot.sound`); `UkTax/Axioms.lean` fails the build if any of
them changes or a `sorry` appears. Mathlib is not used. The roadmap allowed a Z3
certificate as a fallback; it was not needed.

### Proved (Lean)

| Theorem | Statement |
|---|---|
| `isLeastTax_taxExact` | For every income, the allowance placement the model picks gives the least Step 4 tax over every legal placement (s25(2)). |
| `liability_mono` | The computed liability never goes down when any kind of income goes up. |
| `nicExact_mono`, `hicbc_mono_income`, `hicbc_le` | NICs and the HICBC are monotone; the charge never exceeds the benefit. |
| `taxExact_succ_le` | With both allowances fixed, one more penny of pay adds at most 0.686p of income tax. |
| `net_succ_ge` | Between steps, one more penny of pay raises net income (after tax, NICs, HICBC) by at least 0.234p: the marginal rate there is at most 76.6 %. |
| `earned_plus_uc_mono` | Earned income plus UC never falls as earned income rises. |
| `netAll_drop_only_at_steps` | If one more penny of pay lowers net income (with UC, Tax-Free Childcare and funded hours), it is a step of the personal allowance, the HICBC, the personal savings allowance, or adjusted net income going over £100,000. |

How the optimality proof works: with the income fixed, an allowance placement is
a point `(x, w)` (non-savings income left, and that plus savings left). Step 4 tax
there is a sum of band-tax terms whose arguments move by 0 or 1 per penny, so
away from a short list of lines its second difference is zero. A one-dimensional
lemma (a function with zero second difference off a set `B` is least at an end of
its interval or in `B`), applied along `x` and then along `w`, takes any legal
placement to a crossing of two lines with no more tax. Every such crossing is a
candidate the search tries.

What the proofs do *not* cover: that the model matches the law. That is the job
of the citations, the golden cases and the PolicyEngine comparison.

### Tested

- **37 golden cases** (`tests/golden.json`), each worked by hand with the working
  written down, two of them GOV.UK's own 2026-27 examples, aimed at boundaries
  (thresholds, 1p either side, rounding, s25(2) choices, the two-child limit, the
  UC/TFC choice, the £100,000 and minimum-earnings edges). Three of the HICBC
  cases were checked by breaking the code and seeing them fail.
- **Cliff-map seed checks** (`harness/cliffs.py`), against figures worked by hand:
  every personal allowance step costs exactly 39.42p, £100,000 to £125,140 keeps
  exactly £9,553.20, the first HICBC step with one child costs £13.9942.

### Compared with PolicyEngine UK 2.180.2

| Comparison | Cases | Result |
|---|---|---|
| Income tax (unrounded) | 7,198 | all within 2 float32 steps; worst 1.13 steps (1.76p) |
| Personal allowance, savings allowance | 7,198 | all equal |
| Employee NICs | 7,198 | all within 2 float32 steps + 0.32p (the threshold gap below); largest 0.39p |
| HICBC | 7,198 | all equal |
| Universal Credit | 5,603 (2,729 paid) | all within 2 float32 steps + 0.176p; largest 0.43p |

CI runs smaller versions of both comparisons (1,000 random cases each) on every
pull request.

## The cliff map

Full tables: [`cliffs.md`](cliffs.md). Chart: [`emr.svg`](emr.svg) (table view
[`emr.csv`](emr.csv)). Net income here is gross income less income tax,
employee NICs and the HICBC, plus Child Benefit, the better of UC and Tax-Free
Childcare, and the funded hours. A *drop* is the fall in net income from one more
penny of pay; the *trap* is the pay range after it where net income stays below
its level just before the step.

| Step | Where | Drop | Trap | Households |
|---|---|---|---|---|
| Personal allowance (s35(3) round-up) | every £2 of total income, £100,002 to £125,140 (12,570 steps) | 39.42p each | about £0.68 each | everyone |
| HICBC | every £200, £60,200 to £80,000 (100 steps) | 1 % of the Child Benefit in whole pounds: £13.99-£14.99 (1 child), £31.99-£32.99 (3 children) | £24-£57 | with Child Benefit |
| Personal savings allowance | Step 3 income past £37,700; past £125,140 | £99.99-£100.00; £199.99 | £139-£378 | with savings interest |
| Tax-Free Childcare (and funded hours) | adjusted net income past £100,000 | £1,999.99 (one child in £10,000 of childcare), £3,999.99 (two), plus the value of any funded hours | £5,263; £10,526 | parents using childcare |

No other drops exist for any household of this form (pay varying; savings,
dividends, Child Benefit and claims fixed). UC adds none: with the taper, the
marginal rate between steps is at most 89.5 %, and moving between UC and
Tax-Free Childcare is smooth because the household takes the larger.

### The 60 % band is a staircase

The usual account is that the personal allowance taper gives an effective 60 %
rate between £100,000 and £125,140. That is right on average. But ITA 2007 s35(3)
says the reduced allowance "is to be rounded up to the nearest amount which is a
multiple of £1", so the allowance falls in £1 steps every £2 of income. At each
step (£100,002.00, £100,004.00, ...), the penny of income that crosses it brings
£1 of income into the 40 % band. Tax rises by 40.4p and NICs by 0.02p, so net
income falls by 39.42p. Between steps the rate is 42 % (40 % tax, 2 % NICs), and
over any whole £2 it is 62 % (60 % tax, 2 % NICs).

In money this barely matters: the worst a taxpayer can lose by being 1p over a
step is 39p. But it means "earning more always increases net income in the 60 %
band" is false at penny resolution, 12,570 times, and that a net-income function
is not monotone there. PolicyEngine models the same round-up (its personal
allowance agrees with the model's on every case), so its net income has the same
staircase.

### The £100,000 childcare cliff

Going 1p over £100,000 of adjusted net income loses Tax-Free Childcare (up to
£2,000 a child) and the working-parent funded hours. With one child in £10,000 of
childcare, net income drops £1,999.99 and does not recover until pay is £5,263
higher. Each extra pound keeps 38p in this band (60 % income tax and 2 % NICs),
and £1,999.99 / 0.38 ≈ £5,263. The funded hours are in kind and no value is
assumed; their value adds to the drop, and lengthens the trap by that value
divided by 0.38.

## Differences from PolicyEngine UK

### 1. NIC thresholds for weekly and monthly pay: likely a PolicyEngine error (small)

**What PolicyEngine does.** `parameters/gov/hmrc/national_insurance/class_1/employee_scale.yaml`
stores the 2026-27 primary threshold as **£241.73 a week** and the upper earnings
limit as **£966.73**. Its comment explains these as the annual figures divided by
52, "as SI 2001/1004 reg 11(3)(c) does for periods of whole weeks". The employee
NIC formulas (`ni_class_1_employee_primary.py`, `..._additional.py`) then work
monthly with `threshold * WEEKS_IN_YEAR / MONTHS_IN_YEAR`, i.e. £1,047.50 a month.

**What the law says.** SI 2001/1004 reg 10 sets the weekly primary threshold at
£242 and the upper earnings limit at £967 for 2026-27. Reg 11(3)(a) sets the
monthly primary threshold at £1,048 and reg 11(2A)(a) the monthly upper limit at
£4,189. Reg 11(3)(c) (a multiple of a week) does divide £12,570 by 52, but reg
11(4) then says the result, "if not whole pounds, shall be rounded up to the next
whole pound", which gives £242. GOV.UK's
[rates and thresholds for employers 2026 to 2027](https://www.gov.uk/guidance/rates-and-thresholds-for-employers-2026-to-2027)
lists £242 / £1,048 / £12,570 and £967 / £4,189 / £50,270.

**Effect.** PolicyEngine's thresholds come to £12,569.96 and £50,269.96 a year.
For an employee on £30,000:

| Basis | Correct NICs | PolicyEngine | Difference |
|---|---|---|---|
| Annual earnings period (directors) | £1,394.40 | £1,394.40 | 0.32p |
| Monthly pay (12 × £1,048) | £1,393.92 | £1,394.40 (£116.20 a month, not £116.16) | +£0.48 a year |
| Weekly pay (52 × £242) | £1,393.28 | £1,394.40 | +£1.12 a year |

The comparison harness confirms the annual-basis gap on every case (within
0.32p plus float32), and it shows up in UC as 55 % of that (0.176p).

**Assessment.** This looks like an error: the comment cites reg 11(3)(c) but not
reg 11(4), and the monthly calculation uses neither the monthly figures in reg
11(3)(a) and (2A)(a) nor the weekly ones in reg 10. The amounts are tiny (at most
£1.12 a year per employee). It might be deliberate: storing
annual ÷ 52 makes yearly totals match the annual thresholds. If so, the comment
should say that it approximates rather than follows reg 11.

### 2. `income_tax` includes the HICBC: by design

PolicyEngine's `income_tax` adds `CB_HITC`. Its code cites Finance Act 2026 Sch 10
para 4(3) as adding the charge to ITA 2007 s30(1) (not checked here). If so, that
is correct as law. Anyone comparing "income tax" figures needs to
know it, and the harness subtracts the charge.

### 3. Marriage Allowance claimed by default for couples: a default

For a one-earner couple PolicyEngine's defaults treat the couple as married and
claiming Marriage Allowance (`would_claim_marriage_allowance`), which transfers
£1,260 of allowance: £252 less tax and £138.60 more UC a year. This is a modelling
default, not an error, but a user who builds a couple without setting it gets a
claim they may not have made. The model has no Marriage Allowance, so the harness
turns it off.

### 4. Float32 precision: a limitation

PolicyEngine computes in float32, so a figure is only as precise as float32 at its
size: 0.2p at £20,000, 0.8p at £100,000, 1.6p from £131,072. Every comparison
allows 2 float32 steps; the worst seen was 1.13 steps for income tax and 2.79
steps for UC (where monthly amounts are added up). This matters for
penny-level questions; the 39.42p staircase above is still well resolved (0.8p
steps at £100,000).

### No differences found

Personal allowance (including the s35(3) round-up), personal savings allowance,
the s25(2) allowance placement for savings and dividends, HICBC (including all
three s681C(3) roundings) and the UC award agree exactly or within float32 on
every case.

## Suggested outreach (for the owner to decide)

None of this has been done. Each is a suggestion only.

1. **PolicyEngine UK issue on the NIC thresholds** (difference 1), quoting reg 10,
   reg 11(3)(a), 11(4) and GOV.UK, with the £30,000 example. Small fix,
   clearly sourced.
2. **PolicyEngine UK note on the Marriage Allowance default** (difference 3):
   possibly a documentation point rather than an issue.
3. **Share the "60 % band is a staircase" observation** with tax-policy people
   who discuss the £100k trap (for example the Low Incomes Tax Reform Group, the
   Institute for Fiscal Studies or the Chartered Institute of Taxation's
   technical team) as a curiosity: it changes nothing material, but it is a
   precise, checkable statement.
4. **Lean community** (Zulip): the optimality proof (s25(2) search is optimal)
   and the cliff theorem as an example of formal verification of tax law with
   core `omega` only.
5. **Make the repository public** once the owner is happy with the write-up and
   the scope statements.

## What is left

- Couples where both work (joint UC earnings, two HICBC incomes, TFC needing both
  parents in work), and Marriage Allowance.
- Pension contributions and Gift Aid, which reduce adjusted net income and are the
  usual way out of the £100,000 cliffs.
- UC housing, childcare, disability and carer elements, capital, the benefit cap
  and the first-child rate for children born before 6 April 2017.
- Per-period rounding of NICs and UC, and weeks-in-year effects (53 Child Benefit
  Mondays in 2026-27).
- Scottish income tax, self-employment (Class 4 NICs), and 2027-28 (where the
  enacted and announced savings rates differ).
- A money value for the funded hours, if a citable one can be agreed.
