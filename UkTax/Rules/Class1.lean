import UkTax.Charges
import UkTax.Rules.Core

/-!
# Employee Class 1 National Insurance (SSCBA 1992 s8) in the rules language

Primary Class 1 contributions as a schedule of bands: nothing up to the primary
threshold, the main primary percentage up to the upper earnings limit, the
additional primary percentage above it. `class1 pt uel` is that schedule for any
pair of thresholds; it is proved equal to the model's `nicExact`

* for a year on each earnings basis, with the annual-equivalent thresholds the
  model uses (`class1For_eval`), and
* for a week, with the weekly thresholds of the Social Security (Contributions)
  Regulations 2001 reg 10: 52 equal weeks of the rule are the model's year on the
  weekly basis (`class1Weekly_eval`),

for **every** parameter set and all earnings.
-/

namespace UkTax.Rules

/-- Earnings from the employment (SSCBA 1992 s3, s8). -/
def earningsIn : Input where
  key := "earnings"
  noun := "the earner's earnings paid in the tax week, in respect of the employment in question"
  term := "earnings"
  defn := "For the meaning of “earnings” see section 3."
  plain := "your pay for the week"
  gloss := "what your employer pays you from the job for the week, before \
    income tax and before any pension contributions taken from your pay. Pensions, \
    savings interest and dividends are not earnings and carry no National Insurance. \
    This is for an employee aged 16 to State Pension age on category letter A"

/-- No contribution below the primary threshold. -/
def nilRate : Rate where
  name := "no contribution"
  get := fun _ => 0

/-- The main primary percentage (s8(2)(a)). -/
def mainPrimary : Rate where
  name := "the main primary percentage"
  get := (·.nicMain)

/-- The additional primary percentage (s8(2)(b)). -/
def additionalPrimary : Rate where
  name := "the additional primary percentage"
  get := (·.nicAdditional)

/-- **SSCBA 1992 s8(1)**: primary Class 1 contributions on earnings, given the
primary threshold and the upper earnings limit. -/
def class1 (pt uel : Figure) : Schedule where
  income := earningsIn
  bands := [
    { rate := nilRate, upTo := some pt, silent := true },
    { rate := mainPrimary, upTo := some uel },
    { rate := additionalPrimary, upTo := none }]

/-- The weekly thresholds (Social Security (Contributions) Regulations 2001 reg 10). -/
def class1Weekly : Schedule :=
  class1 { name := "the primary threshold", get := (·.ptWeekly) }
    { name := "the upper earnings limit", get := (·.uelWeekly) }

/-- A year on an earnings basis, with the annual-equivalent thresholds. -/
def class1For (p : EarningsPeriod) : Schedule :=
  class1 { name := "the primary threshold", get := p.primaryThreshold }
    { name := "the upper earnings limit", get := p.upperEarningsLimit }

/-- The schedule for any thresholds, as a formula. -/
theorem class1_eval (pt uel : Figure) (P : TaxParams) (env : Env) :
    (class1 pt uel).eval P env
      = ((P.nicMain * (min (env earningsIn.key) (uel.get P) - pt.get P)
          + P.nicAdditional * (env earningsIn.key - uel.get P) : Nat) : Int) := by
  simp only [Schedule.eval, class1, Schedule.evalFrom, nilRate, mainPrimary, additionalPrimary]
  generalize env earningsIn.key = x
  have e2 : max 0 (min (ofPence x) (ofPence (uel.get P)) - ofPence (pt.get P))
      = ofPence (min x (uel.get P) - pt.get P) := by
    simp only [ofPence, perPenny]; omega
  have e3 : max 0 (ofPence x - ofPence (uel.get P)) = ofPence (x - uel.get P) := by
    simp only [ofPence, perPenny]; omega
  rw [e2, e3]
  have band (n r : Nat) : ofPence n * (r : Int) / perPenny = ((r * n : Nat) : Int) := by
    simp only [ofPence, perPenny]
    rw [Int.mul_right_comm, Int.mul_ediv_cancel _ (by decide)]
    push_cast; exact Int.mul_comm _ _
  rw [band, band]
  simp only [Int.natCast_zero, Int.mul_zero, Int.zero_ediv, Int.zero_add]
  push_cast; rfl

/-- **The s8 rule is the model's NICs for a year**, on every earnings basis, for
every parameter set and all earnings. -/
theorem class1For_eval (p : EarningsPeriod) (P : TaxParams) (env : Env) :
    (class1For p).eval P env = (nicExact P p (env earningsIn.key) : Int) := by
  rw [class1For, class1_eval]; rfl

/-- **Fifty-two weeks of the s8 rule with the weekly thresholds are the model's
NICs for the year on the weekly basis**, for equal weekly pay `w`. -/
theorem class1Weekly_eval (P : TaxParams) (env : Env) :
    52 * class1Weekly.eval P env = (nicExact P .weekly (52 * env earningsIn.key) : Int) := by
  rw [class1Weekly, class1_eval]
  simp only [nicExact, EarningsPeriod.primaryThreshold, EarningsPeriod.upperEarningsLimit]
  generalize env earningsIn.key = w
  rw [show min (52 * w) (52 * P.uelWeekly) - 52 * P.ptWeekly
      = 52 * (min w P.uelWeekly - P.ptWeekly) by omega,
    show 52 * w - 52 * P.uelWeekly = 52 * (w - P.uelWeekly) by omega]
  push_cast
  generalize ((min w P.uelWeekly - P.ptWeekly : Nat) : Int) = X
  generalize ((w - P.uelWeekly : Nat) : Int) = Y
  rw [Int.mul_comm 52, Int.add_mul, Int.mul_assoc, Int.mul_assoc, Int.mul_comm X, Int.mul_comm Y]

end UkTax.Rules

/-- info: 'UkTax.Rules.class1For_eval' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.Rules.class1For_eval

/-- info: 'UkTax.Rules.class1Weekly_eval' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.Rules.class1Weekly_eval
