import UkTax.Calc
import UkTax.Rules.Core

/-!
# ITA 2007 s35, s10 and s6 in the rules language

The personal allowance and its taper (s35), and the bands it feeds (the limits of
s10, the main rates of s6), written in the blocks of `UkTax/Rules/Core.lean` with
the figures of a `TaxParams`, and proved equal to the model's own definitions for
**every** parameter set (no `TaxParams.Valid` needed) and every input:

* `personalAllowanceRule_eval`: the rule gives `personalAllowanceFor`;
* `mainRates_eval`: the bands give `bandTax` at the main rates (a taxpayer with no
  Gift Aid or relief-at-source pension contributions, which would raise the
  limits; `Regime.relief = 0`).

`docs/prose/s35.md` and `docs/prose/s35-statute.md` are printed from these two
values by `lake env lean --run Prose.lean`.
-/

namespace UkTax.Rules

/-- Adjusted net income (ITA 2007 s58). -/
def adjustedNetIncome : Input where
  key := "adjusted net income"
  noun := "the individual's adjusted net income"
  term := "adjusted net income"
  defn := "For the meaning of “adjusted net income” see section 58."
  plain := "your adjusted net income"
  gloss := "your total income for the year that income tax is charged on, before \
    any allowances, \
    less the gross amount of any Gift Aid donations and of any pension \
    contributions paid to a scheme that claims the tax relief for you"

/-- Step 3 income: what is left of income after allowances (ITA 2007 s23). -/
def taxableIncome : Input where
  key := "taxable income"
  noun := "an individual's taxable income"
  term := "taxable income"
  defn := "In this section “taxable income” means the income remaining after \
    allowances are deducted at Step 3 of the calculation in section 23."
  plain := "your taxable income"
  gloss := "your income for the year after your personal allowance has been taken \
    off. These bands are for earnings, pensions, rent and other income that is not \
    savings or dividends, for someone who is not a Scottish taxpayer"

/-- **ITA 2007 s35**: the personal allowance, reduced by £1 for every £2 by which
adjusted net income exceeds the income limit, not below nil, rounded up to a
whole pound. -/
def personalAllowanceRule : Amt :=
  .roundUpPound <| .notBelowNil <|
    .taper (.fig { get := (·.pa) }) 1 2
      { measure := adjustedNetIncome, threshold := { name := "the income limit", get := (·.paLimit) } }

/-- **ITA 2007 s10 and s6**: the main rates and their bands. -/
def mainRates : Schedule where
  income := taxableIncome
  bands := [
    { rate := { name := "the basic rate", get := (·.nsRates.basic) },
      upTo := some { name := "the basic rate limit", get := (·.brl) } },
    { rate := { name := "the higher rate", get := (·.nsRates.higher) },
      upTo := some { name := "the higher rate limit", get := (·.hrl) } },
    { rate := { name := "the additional rate", get := (·.nsRates.additional) },
      upTo := none }]

/-- **The s35 rule is the model's personal allowance**, for every parameter set
and every adjusted net income. -/
theorem personalAllowanceRule_eval (P : TaxParams) (env : Env) :
    personalAllowanceRule.eval P env
      = ofPence (personalAllowanceFor P (env adjustedNetIncome.key)) := by
  simp only [personalAllowanceRule, Amt.eval, Test.excess, Test.holds, ofPence,
    perPenny, personalAllowanceFor]
  by_cases h : P.paLimit < env adjustedNetIncome.key <;>
    simp only [h, decide_true, decide_false, ↓reduceIte, Bool.false_eq_true] <;>
    omega

/-- A band's share of tax: the rate times the whole pence in the band. -/
private theorem band_share (n r : Nat) :
    ofPence n * (r : Int) / perPenny = ((r * n : Nat) : Int) := by
  simp only [ofPence, perPenny]
  rw [Int.mul_right_comm, Int.mul_ediv_cancel _ (by decide)]
  push_cast; exact Int.mul_comm _ _

/-- **The s10 bands at the s6 rates are the model's band tax**, for every
parameter set and every taxable income (with no Gift Aid or relief-at-source
pension contributions raising the limits). -/
theorem mainRates_eval (rg : Regime) (h : rg.relief = 0) (env : Env) :
    mainRates.eval rg.params env
      = ((bandTax rg.params.nsRates rg (env taxableIncome.key) : Nat) : Int) := by
  have hb : rg.brl = rg.params.brl := by simp [Regime.brl, h]
  have hh : rg.hrl = rg.params.hrl := by simp [Regime.hrl, h]
  simp only [Schedule.eval, mainRates, Schedule.evalFrom, bandTax, hb, hh]
  generalize env taxableIncome.key = x
  have e1 : max 0 (min (ofPence x) (ofPence rg.params.brl) - 0)
      = ofPence (min x rg.params.brl) := by simp only [ofPence, perPenny]; omega
  have e2 : max 0 (min (ofPence x) (ofPence rg.params.hrl) - ofPence rg.params.brl)
      = ofPence (min x rg.params.hrl - rg.params.brl) := by
    simp only [ofPence, perPenny]; omega
  have e3 : max 0 (ofPence x - ofPence rg.params.hrl) = ofPence (x - rg.params.hrl) := by
    simp only [ofPence, perPenny]; omega
  rw [e1, e2, e3, band_share, band_share, band_share]
  push_cast; omega

end UkTax.Rules

/-! Fails the build if either equivalence ever depends on `sorryAx` or an axiom
beyond the two it uses today. -/

/-- info: 'UkTax.Rules.personalAllowanceRule_eval' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.Rules.personalAllowanceRule_eval

/-- info: 'UkTax.Rules.mainRates_eval' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.Rules.mainRates_eval
