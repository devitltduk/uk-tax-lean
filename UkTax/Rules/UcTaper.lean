import UkTax.Benefits
import UkTax.Rules.Core

/-!
# The Universal Credit taper and work allowance (UC Regulations 2013 reg 22)

The amount of earned income deducted from the maximum amount for an assessment
period: 55 % of the amount by which earned income exceeds the work allowance
(reg 22(1)(b)). Proved equal to the model's taper term for **every** parameter
set and every input (`ucTaperRule_eval`), and the model's award is shown to be
the maximum amount less that deduction (`ucAward_eq_rule`).

The model works with a year of equal months, in 1/1 000 000 pence, on earned
income that need not be whole pence; the rule works per month in whole pence. The
theorems are about months of whole pence, which is what reg 22 deals in.
-/

namespace UkTax.Rules

/-- Earned income for an assessment period (UC Regulations 2013 reg 52, 55). -/
def earnedIncomeIn : Input where
  key := "earned income"
  noun := "the claimant's earned income in respect of the assessment period"
  term := "earned income"
  defn := "For the meaning of “earned income” see regulation 52."
  plain := "your earned income for the month"
  gloss := "your pay for the assessment period (a month) after income tax and \
    National Insurance are taken off, together with your partner's if you claim as a \
    couple"

/-- The work allowance for the award (reg 22(2) and the table in reg 22). -/
def workAllowanceIn : Input where
  key := "work allowance"
  noun := "the work allowance specified in the table"
  term := "work allowance"
  defn := "The work allowance is specified in regulation 22(2) and the table."
  plain := "your work allowance"
  gloss := "the amount you can earn each month before Universal Credit starts to \
    fall, if you are responsible for a child or have limited capability for work \
    (see the table below). Other claimants have none, so all of their earned income \
    counts"

/-- The taper rate (reg 22(1)(b)), a whole percentage in the parameter set. -/
def ucTaperRate : Rate where
  name := "the taper rate"
  get := (·.ucTaper * 100)

/-- **UC Regulations 2013 reg 22(1)(b)**: the earned income deducted. -/
def ucTaperRule : Amt :=
  .percentOf (.rate ucTaperRate) <| .notBelowNil <| .less (.input earnedIncomeIn) workAllowanceIn

/-- **The reg 22 rule is the model's taper**, for every parameter set: twelve
months of the rule, in the model's unit, are the term the model takes off a
year's award, when earned income is `m` pence a month and the work allowance `w`
pence a month. -/
theorem ucTaperRule_eval (P : TaxParams) (env : Env) :
    1200 * ucTaperRule.eval P env
      = (P.ucTaper : Int) * max 0 (10_000 * 12 * (env earnedIncomeIn.key : Int)
          - 10_000 * 12 * (env workAllowanceIn.key : Int)) := by
  simp only [ucTaperRule, ucTaperRate, Amt.eval, Pct.eval, ofPence, perPenny]
  generalize (env earnedIncomeIn.key : Int) = m
  generalize (env workAllowanceIn.key : Int) = w
  have h1 : max 0 (10_000 * 12 * m - 10_000 * 12 * w) = 120_000 * max 0 (m - w) := by omega
  have h2 : max 0 (m * 10000 - w * 10000) = max 0 (m - w) * 10000 := by omega
  rw [h1, h2]
  generalize max 0 (m - w) = x
  rw [show x * 10000 * ((P.ucTaper * 100 : Nat) : Int) = (P.ucTaper * x * 100) * 10000 by
      push_cast; simp only [Int.mul_assoc, Int.mul_comm, Int.mul_left_comm],
    Int.mul_ediv_cancel _ (by decide)]
  simp only [Int.mul_assoc, Int.mul_comm, Int.mul_left_comm]; rfl

/-- **The model's award is the maximum amount less the reg 22 deduction**: for a
claim with capital within the limit and the benefit cap not applying, and
earned income (with the partner's) of `m` pence a month, the model's yearly award
is twelve months of the amounts before the taper less twelve months of the rule,
not below nil. -/
theorem ucAward_eq_rule (P : TaxParams) (c : Claims) (e : Int) (env : Env)
    (hUc : c.uc = true) (hCap : c.capital ≤ ucCapitalUpper)
    (hNoCap : c.capApplies (e + 10_000 * (c.partnerEarned : Int)) = false)
    (hE : e + 10_000 * (c.partnerEarned : Int) = 10_000 * 12 * (env earnedIncomeIn.key : Int))
    (hW : env workAllowanceIn.key = c.workAllowance) :
    ucAward P c e = max 0 (12 * (c.maxMicro - micro * (c.tariff + c.unearnedMonthly : Nat))
      - micro * (c.carersAllowanceYear : Int) + 12 * c.childcareMicro e
      - 1200 * ucTaperRule.eval P env) := by
  rw [ucTaperRule_eval, hW, ← hE]
  simp [ucAward, hUc, hCap, hNoCap]

end UkTax.Rules

/-- info: 'UkTax.Rules.ucTaperRule_eval' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.Rules.ucTaperRule_eval

/-- info: 'UkTax.Rules.ucAward_eq_rule' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.Rules.ucAward_eq_rule
