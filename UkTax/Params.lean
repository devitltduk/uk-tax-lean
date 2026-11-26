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
The rise to 22 / 42 / 47 % (FA 2026 s5) starts in 2027-28, not 2026-27. -/
def savingsRates : Rates := ⟨2000, 4000, 4500⟩

/-- Dividend ordinary, upper and additional rates for 2026-27: 10.75 %, 35.75 % and
39.35 %. ITA 2007 s8(1)-(3) <https://www.legislation.gov.uk/ukpga/2007/3/section/8>,
ordinary and upper rates raised from 8.75 % and 33.75 % by Finance Act 2026 s4 for
2026-27 onwards. GOV.UK policy paper
<https://www.gov.uk/government/publications/changes-to-tax-rates-for-property-savings-and-dividend-income> -/
def dividendRates : Rates := ⟨1075, 3575, 3935⟩

end UkTax
