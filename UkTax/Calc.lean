import UkTax.Params

/-!
# The income tax calculation (ITA 2007 s23), 2026-27, rUK rates

Scope: an individual who is not a Scottish or Welsh taxpayer, whose net income is
made up of non-savings, savings and dividend income, with no reliefs (so total
income = net income = adjusted net income) and no tax reductions.

ITA 2007 s23 steps as modelled here:

* Steps 1-2: total income is the sum of the three kinds; there are no reliefs.
* Step 3: deduct the personal allowance (s35, tapered above £100,000) from the
  three kinds in the order most favourable here, which s25(2) fixes as
  non-savings first, then savings, then dividends.
* Step 4: charge tax on what is left. Savings and dividends form the highest part
  of income, dividends on top (s16). Within the bands:
  - non-savings income at 20 / 40 / 45 % (s10);
  - savings income in the lowest £5,000 of Step 3 income at the 0 % starting rate
    for savings (s12), then the personal savings allowance at 0 % (s12A, s12B),
    then 20 / 40 / 45 %;
  - dividends: the first £500 at the 0 % dividend nil rate (s13A), then
    10.75 / 35.75 / 39.35 % (s8, s13).
  Income charged at a nil rate still uses up the band it falls in.
* Steps 5-7: nothing to do (no reductions); the liability is the Step 4 total.

Tax is computed exactly in units of 1/10 000 of a penny and rounded down to the
penny once, at the end.
-/

namespace UkTax

/-- A taxpayer's income for the year, in pence. -/
structure Income where
  nonSavings : Nat
  savings : Nat
  dividends : Nat
  deriving Repr

/-- Tax, in 1/10 000 pence, on the lowest `x` pence of Step 3 income if all of it
were charged at rates `r`. -/
def bandTax (r : Rates) (x : Nat) : Nat :=
  r.basic * min x basicRateLimit
    + r.higher * (min x higherRateLimit - basicRateLimit)
    + r.additional * (x - higherRateLimit)

/-- Tax, in 1/10 000 pence, on the slice of Step 3 income between positions `lo`
and `hi` (counting from the bottom of the basic rate band) at rates `r`. -/
def sliceTax (r : Rates) (lo hi : Nat) : Nat :=
  bandTax r hi - bandTax r lo

/-- Personal allowance for a given adjusted net income (ITA 2007 s35): reduced by
half the excess over £100,000, then rounded up to a whole pound. -/
def personalAllowanceFor (adjustedNetIncome : Nat) : Nat :=
  -- twice the reduced allowance, in pence; exact even when the excess is odd
  let twice := 2 * personalAllowance - (adjustedNetIncome - paIncomeLimit)
  100 * ((twice + 199) / 200)

/-- Personal savings allowance (ITA 2007 s12B), given total Step 3 income. Income
charged at a nil rate still counts as higher-rate or additional-rate income
(s12B(8)), so this depends only on where Step 3 income ends. -/
def savingsAllowanceFor (step3Income : Nat) : Nat :=
  if step3Income > higherRateLimit then savingsAllowanceAdditional
  else if step3Income > basicRateLimit then savingsAllowanceHigher
  else savingsAllowanceBasic

/-- Savings income charged at the starting rate for savings (s12): the part of it
that falls in the lowest £5,000 of Step 3 income. -/
def startingRateSavings (n s : Nat) : Nat :=
  min s (startingRateLimitSavings - n)

/-- Savings income charged at the savings nil rate (s12A). -/
def savingsNilRate (n s d : Nat) : Nat :=
  min (s - startingRateSavings n s) (savingsAllowanceFor (n + s + d))

/-- Dividend income charged at the dividend nil rate (s13A). -/
def dividendNilRate (d : Nat) : Nat :=
  min d dividendAllowance

/-- Step 4: tax, in 1/10 000 pence, on Step 3 income made of `n` non-savings, `s`
savings and `d` dividend income (savings above non-savings, dividends on top). -/
def taxOnStep3 (n s d : Nat) : Nat :=
  bandTax nonSavingsRates n
    + sliceTax savingsRates (n + startingRateSavings n s + savingsNilRate n s d) (n + s)
    + sliceTax dividendRates (n + s + dividendNilRate d) (n + s + d)

/-- Step 3 income: what is left of each kind after deducting allowance `pa`,
non-savings first, then savings, then dividends. -/
def step3 (pa : Nat) (i : Income) : Nat × Nat × Nat :=
  (i.nonSavings - pa,
   i.savings - (pa - i.nonSavings),
   i.dividends - (pa - i.nonSavings - i.savings))

/-- Total income (= net income = adjusted net income: no reliefs are modelled). -/
def Income.total (i : Income) : Nat := i.nonSavings + i.savings + i.dividends

/-- The personal allowance this taxpayer gets. -/
def Income.personalAllowance (i : Income) : Nat := personalAllowanceFor i.total

/-- Exact liability in 1/10 000 pence. -/
def taxExact (i : Income) : Nat :=
  let (n, s, d) := step3 i.personalAllowance i
  taxOnStep3 n s d

/-- Income tax liability for 2026-27, in pence, rounded down to the penny. -/
def liability (i : Income) : Nat := taxExact i / 10_000

end UkTax
