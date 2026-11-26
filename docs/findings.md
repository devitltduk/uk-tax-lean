# Findings: differences from PolicyEngine UK

A running list of every difference found between the Lean model and
PolicyEngine UK 2.180.2, with its classification. Coverage is in
[`coverage.md`](coverage.md); the detail of the first five is in
[`writeup.md`](writeup.md#differences-from-policyengine-uk).

**Classes**

- **PolicyEngine error**: PolicyEngine departs from the law, checked against the
  statute and against PolicyEngine's own parameter comments and stated modelling
  basis. Each has a draft issue in [`drafts/issues/`](drafts/issues/).
- **our error**: the model was wrong; fixed, with the fix noted.
- **modelling choice**: both are defensible readings or simplifications; stated so
  users comparing the two know.
- **precision**: float32 rounding in PolicyEngine, within the stated tolerance.
- **scope**: one side models something the other leaves out.

Before anything is called a PolicyEngine error: the statute is quoted, the
PolicyEngine parameter file and its comments are read, its stated basis is
considered, and the numbers are worked by hand and reproduced in both models.

| # | Area | Difference | Class | Size | Detail |
|---|---|---|---|---|---|
| 1 | Employee NICs | Monthly primary threshold £1,047.50 and upper earnings limit £4,189.16 (weekly figures stored as annual ÷ 52) where SI 2001/1004 reg 11(3)(a), (2A)(a) give £1,048 and £4,189 | likely PolicyEngine error (small); the parameter comments acknowledge the reg 10 weekly figures, so it may be a deliberate approximation | 48p to 60p a year for a monthly-paid employee; at most 0.32p a year on the annual basis | writeup §1; draft issue to come (P3) |
| 2 | Income tax | `income_tax` includes the HICBC (Step 7 of ITA 2007 s23, s30(1)) | modelling choice (correct in law); compare like with like | the charge | writeup §2 |
| 3 | Marriage Allowance | Claimed by default for couples (`would_claim_marriage_allowance`) | modelling choice (a default) | £252 less tax, £138.60 more UC a year | writeup §3 |
| 4 | All | float32 arithmetic | precision | 2 float32 steps (0.2p at £20,000, 1.6p from £131,072) | writeup §4 |
| 5 | Funded hours | 15 hours for disadvantaged 2-year-olds | scope (now planned, P9) | £5,073 a year | writeup §5 |
| 6 | Funded hours | Term-by-term age bands | modelling choice (PolicyEngine more precise) | e.g. £11,339.20 against £10,146 | writeup §5 |
| 7 | Pension relief at source | PolicyEngine gives relief-at-source contributions their relief as a deduction from taxable income (`pension_contributions_relief` in `allowances`) and subtracts the gross contribution from net income. FA 2004 s192 gives 20 % at source whatever the member's liability, and HMRC does not recover the 1 % from a Scottish starter-rate taxpayer (PTM044220). So a non-taxpayer gets no relief, a taxpayer whose taxable income is below the gross contribution gets relief only on the taxable part, and a Scottish starter-rate taxpayer gets 19 % | likely PolicyEngine error. PolicyEngine's own relief function allows relief at source above earnings up to the £3,600 basic amount, which only matters to people the deduction gives nothing to | £400 a year on £12,000 pay and £2,000 gross; £234 on £15,000 and £3,600; £10 per £1,000 at the Scottish starter rate; nil for basic and higher rate taxpayers with taxable income above the contribution | [`drafts/issues/01-relief-at-source-non-taxpayers.md`](drafts/issues/01-relief-at-source-non-taxpayers.md) |
| 8 | Pension relief at source | Because of the same design, PolicyEngine's `income_tax` for a relief-at-source contributor is the statutory liability less the relief at source (20 % of the gross contribution) | modelling choice, a consequence of #7; the harness adds 20 % of the gross back and compares only where the two agree (rUK, taxable pay at least the gross contribution) | 20 % of the gross contribution | `harness/compare.py` |
| 9 | Personal allowance | PolicyEngine adds incomes in float32 (1.6p a step above £131,072), so adjusted net income 1p from a £2 step of the tapered allowance can land on the other side of it: the allowance differs by £1 (s35(3) rounds up) | precision | £1 of allowance, 40p to 45p of tax; 4 of 7,723 cases, all built at 1p from a step | `harness/compare.py` (`pa_float32`) |
| 10 | Our citations | The 2026-27 freeze of the personal allowance and basic rate limit was cited to FA 2021 s5 and FA 2026 s10; FA 2026 s10 covers 2028-29 to 2030-31, and the 2026-27 freeze is FA 2021 s5 as amended by FA 2023 s5 | our error (citation); fixed in P1 | none on any figure | `UkTax/Params.lean`, README |
