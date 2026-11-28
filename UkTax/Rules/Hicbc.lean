import UkTax.Charges
import UkTax.Rules.S35

/-!
# The High Income Child Benefit Charge (ITEPA 2003 s681C) in the rules language

The charge is the appropriate percentage of the Child Benefit, where the
percentage is 1 % for every whole £200 by which adjusted net income exceeds
£60,000, up to 100 %; the Child Benefit, the percentage and the charge are each
rounded down to a whole number (s681C(3)). Proved equal to the model's `hicbc`
for **every** parameter set and every input (`hicbcRule_eval`).
-/

namespace UkTax.Rules

/-- The Child Benefit the charge is on (ITEPA 2003 s681B conditions A and B). -/
def childBenefitIn : Input where
  key := "child benefit"
  noun := "the child benefit in relation to which condition A or B is met"
  term := "Child Benefit for the year"
  defn := "For conditions A and B see section 681B."
  plain := "the Child Benefit paid for the tax year"
  gloss := "the Child Benefit paid for the tax year (6 April to 5 April) to you, or \
    to a partner you live with if you have the higher adjusted net income of the two. \
    Only the partner with the higher income pays the charge"

/-- s681C(2): the threshold test on adjusted net income. -/
def hicbcTest : Test where
  measure := adjustedNetIncome
  threshold := { name := "the threshold", get := (·.cbThreshold) }

/-- s681C(2)-(3): the appropriate percentage, 1 % for every whole £200 over
£60,000, up to 100 %. -/
def hicbcPct : Pct := .steps hicbcTest { get := (·.cbStep) } 100

/-- **ITEPA 2003 s681C**: the High Income Child Benefit Charge. -/
def hicbcRule : Amt :=
  .roundDownPound <| .percentOf hicbcPct <| .roundDownPound (.input childBenefitIn)

/-- The whole-steps block is the model's appropriate percentage. -/
theorem hicbcPct_eval (P : TaxParams) (env : Env) :
    hicbcPct.eval P env = 100 * hicbcPercent P (env adjustedNetIncome.key) := by
  simp only [hicbcPct, hicbcTest, Pct.eval, Test.holds, hicbcPercent]
  by_cases h : P.cbThreshold < env adjustedNetIncome.key
  · simp [h]
  · simp only [h, decide_false, Bool.false_eq_true, ↓reduceIte, Nat.zero_div]
    rw [show env adjustedNetIncome.key - P.cbThreshold = 0 by omega, Nat.zero_div]

/-- **The s681C rule is the model's charge**, for every parameter set, every
adjusted net income and every amount of Child Benefit. -/
theorem hicbcRule_eval (P : TaxParams) (env : Env) :
    hicbcRule.eval P env
      = ofPence (hicbc P (env adjustedNetIncome.key) (env childBenefitIn.key)) := by
  simp only [hicbcRule, Amt.eval]
  rw [hicbcPct_eval]
  simp only [hicbc, ofPence, perPenny]
  generalize hicbcPercent P (env adjustedNetIncome.key) = p
  generalize env childBenefitIn.key = cb
  have hq : (cb : Int) * 10000 / (100 * 10000) * (100 * 10000) = ((cb / 100 : Nat) : Int) * 1000000 := by
    omega
  rw [hq]
  generalize cb / 100 = q
  have h2 : ((q : Int) * 1000000 * ((100 * p : Nat) : Int)) / 10000 = ((p * q : Nat) : Int) * 10000 := by
    push_cast
    rw [show (q : Int) * 1000000 * (100 * (p : Int)) = ((p : Int) * q * 10000) * 10000 by
      simp only [Int.mul_assoc, Int.mul_comm, Int.mul_left_comm]; rfl]
    rw [Int.mul_ediv_cancel _ (by decide)]
  rw [h2]
  generalize p * q = k
  omega

end UkTax.Rules

/-- info: 'UkTax.Rules.hicbcRule_eval' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.Rules.hicbcRule_eval
