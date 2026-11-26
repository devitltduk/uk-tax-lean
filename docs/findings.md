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
| 1 | Employee NICs | Monthly primary threshold £1,047.50 and upper earnings limit £4,189.16 (weekly figures stored as annual ÷ 52) where SI 2001/1004 reg 11(3)(a), (2A)(a) give £1,048 and £4,189 | likely PolicyEngine error (small); the parameter comments acknowledge the reg 10 weekly figures, so it may be a deliberate approximation | 48p to 60p a year for a monthly-paid employee; at most 0.32p a year on the annual basis | writeup §1; draft issue to come |
| 2 | Income tax | `income_tax` includes the HICBC (Step 7 of ITA 2007 s23, s30(1)) | modelling choice (correct in law); compare like with like | the charge | writeup §2 |
| 3 | Marriage Allowance | Claimed by default for couples (`would_claim_marriage_allowance`) | modelling choice (a default) | £252 less tax, £138.60 more UC a year | writeup §3 |
| 4 | All | float32 arithmetic | precision | 2 float32 steps (0.2p at £20,000, 1.6p from £131,072) | writeup §4 |
| 5 | Funded hours | 15 hours for disadvantaged 2-year-olds | scope (now planned, P9) | £5,073 a year | writeup §5 |
| 6 | Funded hours | Term-by-term age bands | modelling choice (PolicyEngine more precise) | e.g. £11,339.20 against £10,146 | writeup §5 |
