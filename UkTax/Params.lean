/-!
# Parameters for the 2026-27 tax year (England, Wales and Northern Ireland)

Every rate and threshold used by the model, each with its source. Figures were
checked against legislation.gov.uk and GOV.UK on 2026-11-26.

Units:
* money is in **pence** (`Nat`);
* rates are in **basis points** (`Nat`, 1 bp = 0.01 %), so 10.75 % is `1075`.

Multiplying pence by basis points therefore gives tax in units of 1/10 000 of a
penny, which keeps every intermediate result an exact natural number.
-/

namespace UkTax

/-- The three main rates that apply in the basic, higher and additional bands. -/
structure Rates where
  basic : Nat
  higher : Nat
  additional : Nat
  deriving Repr

/-- Personal allowance, £12,570.
ITA 2007 s35(1) <https://www.legislation.gov.uk/ukpga/2007/3/section/35>; amount
frozen to 2030-31 by FA 2021 s5 and FA 2026 s10. GOV.UK:
<https://www.gov.uk/government/publications/rates-and-allowances-income-tax/income-tax-rates-and-allowances-current-and-past> -/
def personalAllowance : Nat := 1_257_000

/-- Income limit for the personal allowance, £100,000: above it the allowance is
reduced by half the excess of adjusted net income (ITA 2007 s35(2)) and the result
rounded up to a whole pound (s35(3)). -/
def paIncomeLimit : Nat := 10_000_000

/-- Basic rate limit, £37,700. ITA 2007 s10(5)
<https://www.legislation.gov.uk/ukpga/2007/3/section/10>; frozen by FA 2021 s5 and
FA 2026 s10. With the full personal allowance the higher rate starts at £50,270 of
total income (GOV.UK <https://www.gov.uk/income-tax-rates>). -/
def basicRateLimit : Nat := 3_770_000

/-- Higher rate limit, £125,140. ITA 2007 s10(5A) defines it as twice the personal
allowance plus £100,000, i.e. the income at which the personal allowance has
tapered to nil. Additional rate applies above it (GOV.UK
<https://www.gov.uk/income-tax-rates>). -/
def higherRateLimit : Nat := 2 * personalAllowance + 10_000_000

/-- Starting rate limit for savings, £5,000, charged at the 0 % starting rate for
savings. ITA 2007 s12(3) <https://www.legislation.gov.uk/ukpga/2007/3/section/12>
(sum confirmed for 2026-27 to 2030-31 by FA 2026 s9(1)); rate 0 % by ITA 2007 s7.
GOV.UK <https://www.gov.uk/apply-tax-free-interest-on-savings/how-much-is-tax-free> -/
def startingRateLimitSavings : Nat := 500_000

/-- Personal savings allowance when no income is higher-rate or additional-rate
income, £1,000. ITA 2007 s12B(4)
<https://www.legislation.gov.uk/ukpga/2007/3/section/12B> -/
def savingsAllowanceBasic : Nat := 100_000

/-- Personal savings allowance when some income is higher-rate income but none is
additional-rate income, £500. ITA 2007 s12B(3). -/
def savingsAllowanceHigher : Nat := 50_000

/-- Personal savings allowance when some income is additional-rate income, nil.
ITA 2007 s12B(2). -/
def savingsAllowanceAdditional : Nat := 0

/-- Dividend allowance (dividend nil rate band), £500. ITA 2007 s13A(2)
<https://www.legislation.gov.uk/ukpga/2007/3/section/13A>; GOV.UK
<https://www.gov.uk/tax-on-dividends> -/
def dividendAllowance : Nat := 50_000

/-- Basic, higher and additional rates on non-savings income for 2026-27: 20 %, 40 %
and 45 %. Finance Act 2026 s2 <https://www.legislation.gov.uk/ukpga/2026/11>
(ITA 2007 s6); GOV.UK <https://www.gov.uk/income-tax-rates> -/
def nonSavingsRates : Rates := ⟨2000, 4000, 4500⟩

/-- Basic, higher and additional savings rates for 2026-27: 20 %, 40 % and 45 %.
Finance Act 2026 s3 <https://www.legislation.gov.uk/ukpga/2026/11> (ITA 2007 s7A).
2027-28 is out of scope. As enacted, FA 2026 s5 sets 22 / 42 / 47 % from 6 April
2027; Budget 2026 (para 6.247) announced a further 2 points, so the pinned
PolicyEngine UK models 24 / 44 / 49 % from that date. Neither applies to 2026-27. -/
def savingsRates : Rates := ⟨2000, 4000, 4500⟩

/-- Dividend ordinary, upper and additional rates for 2026-27: 10.75 %, 35.75 % and
39.35 %. ITA 2007 s8(1)-(3) <https://www.legislation.gov.uk/ukpga/2007/3/section/8>,
ordinary and upper rates raised from 8.75 % and 33.75 % by Finance Act 2026 s4 for
2026-27 onwards. GOV.UK policy paper
<https://www.gov.uk/government/publications/changes-to-tax-rates-for-property-savings-and-dividend-income> -/
def dividendRates : Rates := ⟨1075, 3575, 3935⟩

/-! ## Employee (primary) Class 1 National Insurance contributions, 2026-27

Amounts in pence per earnings period. The thresholds for 2026-27 are on GOV.UK,
"Rates and thresholds for employers 2026 to 2027"
<https://www.gov.uk/guidance/rates-and-thresholds-for-employers-2026-to-2027>
(also <https://www.gov.uk/government/publications/rates-and-allowances-national-insurance-contributions/rates-and-allowances-national-insurance-contributions>),
set under the Social Security (Contributions) Regulations 2001 reg 10 as amended
for 2026-27 by SI 2026/231 <https://www.legislation.gov.uk/uksi/2026/231/regulation/5/made>.
-/

/-- Primary threshold: £242 a week, £1,048 a month, £12,570 a year. -/
def primaryThresholdWeekly : Nat := 24_200
def primaryThresholdMonthly : Nat := 104_800
def primaryThresholdAnnual : Nat := 1_257_000

/-- Upper earnings limit: £967 a week, £4,189 a month, £50,270 a year. -/
def upperEarningsLimitWeekly : Nat := 96_700
def upperEarningsLimitMonthly : Nat := 418_900
def upperEarningsLimitAnnual : Nat := 5_027_000

/-- Main primary percentage, 8 %, on earnings above the primary threshold up to the
upper earnings limit. Social Security Contributions and Benefits Act 1992 s8(2)(a)
<https://www.legislation.gov.uk/ukpga/1992/4/section/8>; GOV.UK category A. -/
def nicMainRate : Nat := 800

/-- Additional primary percentage, 2 %, on earnings above the upper earnings limit.
SSCBA 1992 s8(2)(b); GOV.UK category A. -/
def nicAdditionalRate : Nat := 200

/-! ## High Income Child Benefit Charge (ITEPA 2003 Part 10 Chapter 8)

ITEPA 2003 s681C <https://www.legislation.gov.uk/ukpga/2003/1/section/681C>: the
charge is the appropriate percentage of the Child Benefit, 1 % for each £200 of
adjusted net income over £60,000 (capped at 100 %); the Child Benefit total, the
percentage and the charge are each rounded down to a whole number (s681C(3)).
Figures as substituted by Finance (No. 2) Act 2024 s5 for 2024-25 onwards. GOV.UK:
<https://www.gov.uk/child-benefit-tax-charge>. -/

/-- L in s681C(2): £60,000. -/
def hicbcThreshold : Nat := 6_000_000

/-- X in s681C(2): £200 of income per percentage point. -/
def hicbcStep : Nat := 20_000

/-! ## Child Benefit weekly rates, 2026-27

Used only to build example households (the model takes the Child Benefit received
as an input). £27.05 for the eldest or only child, £17.90 for each other child.
GOV.UK <https://www.gov.uk/child-benefit-rates> and
<https://www.gov.uk/government/publications/rates-and-allowances-tax-credits-child-benefit-and-guardians-allowance/tax-credits-child-benefit-and-guardians-allowance>. -/
def childBenefitEldestWeekly : Nat := 2_705
def childBenefitOtherWeekly : Nat := 1_790

end UkTax
