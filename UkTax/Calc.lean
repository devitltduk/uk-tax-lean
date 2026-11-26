import UkTax.Params

/-!
# The income tax calculation (ITA 2007 s23), 2026-27, rUK rates

Scope: an individual in England, Wales or Northern Ireland (not a Scottish
taxpayer), whose net income is
made up of non-savings, savings and dividend income, with no reliefs (so total
income = net income = adjusted net income) and no tax reductions. Welsh
taxpayers are covered because for 2026-27 every Welsh rate is 10p in the pound
(Welsh rate resolution NDM9117, agreed by the Senedd on 27 January 2026,
<https://record.senedd.wales/Motion/9117>), which leaves them on the same
20 / 40 / 45 % as England and Northern Ireland.

ITA 2007 s23 steps as modelled here:

* Steps 1-2: total income is the sum of the three kinds; there are no reliefs.
* Step 3: deduct the personal allowance (s35, tapered above £100,000) from the
  three kinds of income in the way that gives the least tax (s25(2)).
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

/-- Total income (= net income = adjusted net income: no reliefs are modelled). -/
def Income.total (i : Income) : Nat := i.nonSavings + i.savings + i.dividends

/-- The personal allowance this taxpayer gets (ITA 2007 s35). -/
def Income.personalAllowance (i : Income) : Nat := personalAllowanceFor i.total

/-- How much of the personal allowance is set against each kind of income. -/
structure Alloc where
  toNonSavings : Nat
  toSavings : Nat
  toDividends : Nat
  deriving Repr

/-- The allowance actually deducted at Step 3: all of it, or all the income if
that is less. -/
def Income.allowanceUsed (i : Income) : Nat := min i.personalAllowance i.total

/-- A legal way to deduct the allowance at Step 3: no kind of income goes below
nil, and the whole allowance (up to total income) is used. -/
def Alloc.Feasible (i : Income) (a : Alloc) : Prop :=
  a.toNonSavings ≤ i.nonSavings ∧ a.toSavings ≤ i.savings ∧ a.toDividends ≤ i.dividends ∧
    a.toNonSavings + a.toSavings + a.toDividends = i.allowanceUsed

/-- Step 4 tax, in 1/10 000 pence, when the allowance is deducted as `a`. -/
def taxWith (i : Income) (a : Alloc) : Nat :=
  taxOnStep3 (i.nonSavings - a.toNonSavings) (i.savings - a.toSavings)
    (i.dividends - a.toDividends)

/-- Deduct the allowance from non-savings income first, then savings, then
dividends. Always feasible; the search starts from it. -/
def Income.inOrder (i : Income) : Alloc :=
  let u := i.allowanceUsed
  ⟨min u i.nonSavings, min (u - i.nonSavings) i.savings,
    min (u - i.nonSavings - i.savings) i.dividends⟩

/-! ## Step 3: the share of the allowance that gives the least tax (ITA 2007 s25(2))

s25(2) deducts allowances "in the way which will result in the greatest reduction
in the taxpayer's liability". No fixed order does that: setting the allowance
against dividends can free the starting rate for savings, and setting it against
savings can lift the savings allowance into the higher rate band.

Write `x` for non-savings income left after the allowance, `w` for `x` plus the
savings left, and `T` for all income left (fixed). Every share is a point
`(x, w)` with `0 ≤ x ≤ N`, `0 ≤ w - x ≤ S` and `T - D ≤ w ≤ T`. Step 4 tax is
continuous and linear between lines on which `x`, `w` or `w - x` is constant:

* non-savings tax bends at `x ∈ {BRL, HRL}`;
* the starting rate for savings (`L` = £5,000) bends at `x = L` and `w = L`;
* the savings allowance `A` (fixed by `T`) bends at `w = L + A` and `w - x = A`,
  and the bottom of the taxed savings (`x + A` above `L`) crosses a limit at
  `x ∈ {BRL - A, HRL - A}`; the top `w` at `w ∈ {BRL, HRL}`;
* the dividend allowance `DA` bends at `w = T - DA` and `w + DA ∈ {BRL, HRL}`;
* the edges of the region are `x ∈ {0, N}`, `w - x ∈ {0, S}`, `w ∈ {T - D, T}`.

A linear function is least at a corner, so the least tax is at a point where two
of these lines cross, all of which are integers. `candidates` lists every such
crossing; the search keeps the feasible ones and takes the least tax.
`Optimal.lean` proves that this finds the least tax (`isLeastTax_taxExact`).
-/

/-- The constant-`x` lines. -/
def Income.xLines (i : Income) : List Int :=
  let A : Int := savingsAllowanceFor (i.total - i.allowanceUsed)
  [0, i.nonSavings, startingRateLimitSavings, basicRateLimit, higherRateLimit,
    basicRateLimit - A, higherRateLimit - A]

/-- The constant-`w` lines. -/
def Income.wLines (i : Income) : List Int :=
  let T : Int := i.total - i.allowanceUsed
  let A : Int := savingsAllowanceFor (i.total - i.allowanceUsed)
  let L : Int := startingRateLimitSavings
  let DA : Int := dividendAllowance
  [T, T - i.dividends, L, L + A, basicRateLimit, higherRateLimit, T - DA,
    basicRateLimit - DA, higherRateLimit - DA]

/-- The constant-`(w - x)` lines. -/
def Income.diagLines (i : Income) : List Int :=
  [0, i.savings, savingsAllowanceFor (i.total - i.allowanceUsed)]

/-- Every crossing of two lines, as `(x, w)`. -/
def Income.candidates (i : Income) : List (Int × Int) :=
  (i.xLines.flatMap fun x => i.wLines.map fun w => (x, w))
    ++ (i.xLines.flatMap fun x => i.diagLines.map fun e => (x, x + e))
    ++ (i.wLines.flatMap fun w => i.diagLines.map fun e => (w - e, w))

/-- Whether `(x, w)` is a legal share. -/
def Income.feasibleAt (i : Income) (p : Int × Int) : Bool :=
  let T : Int := i.total - i.allowanceUsed
  0 ≤ p.1 && p.1 ≤ i.nonSavings && p.1 ≤ p.2 && p.2 - p.1 ≤ i.savings
    && T - i.dividends ≤ p.2 && p.2 ≤ T

/-- The allowance share that leaves `(x, w)`. -/
def Income.allocAt (i : Income) (p : Int × Int) : Alloc :=
  let T : Int := i.total - i.allowanceUsed
  ⟨(i.nonSavings - p.1).toNat, (i.savings - (p.2 - p.1)).toNat,
    (i.dividends - (T - p.2)).toNat⟩

/-- The share of the allowance giving the least tax. -/
def Income.bestAlloc (i : Income) : Alloc :=
  i.candidates.foldl
    (fun best p =>
      if i.feasibleAt p then
        let a := i.allocAt p
        if taxWith i a < taxWith i best then a else best
      else best)
    i.inOrder

/-- Exact liability in 1/10 000 pence. -/
def taxExact (i : Income) : Nat := taxWith i i.bestAlloc

/-- Income tax liability for 2026-27, in pence, rounded down to the penny. -/
def liability (i : Income) : Nat := taxExact i / 10_000

end UkTax
