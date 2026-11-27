import UkTax.TaxParams

/-!
# Employee Class 1 NICs and the High Income Child Benefit Charge, 2026-27

## Employee (primary) Class 1 National Insurance

On employment earnings only (not pensions, savings or dividends), for an
employee over 16 and under State Pension age, category letter A, with no
salary sacrifice, contracted-out or reduced-rate cases. Contributions are worked
out per earnings period (SSCBA 1992 s6, s8; Social Security (Contributions)
Regulations 2001). The model assumes the year's earnings are paid in equal
amounts every period and ignores rounding to the penny each period. Then for
`k` periods a year, with period thresholds `PT` and `UEL`,

    k × (8 % × (min(E/k, UEL) − PT)⁺ + 2 % × (E/k − UEL)⁺)
      = 8 % × (min(E, k·UEL) − k·PT)⁺ + 2 % × (E − k·UEL)⁺,

so each period basis is the annual formula with annual-equivalent thresholds:

| basis   | k  | k·PT    | k·UEL   |
|---------|----|---------|---------|
| annual  | 1  | £12,570 | £50,270 |
| monthly | 12 | £12,576 | £50,268 |
| weekly  | 52 | £12,584 | £50,284 |

The annual basis is the one directors use (an annual earnings period); most
employees are paid monthly or weekly.

## High Income Child Benefit Charge

ITEPA 2003 s681B-s681H. The input is the Child Benefit paid in the year to the
taxpayer or their partner (s681B conditions A and B), and the taxpayer is the
one liable: a single claimant, or the partner with the higher adjusted net
income (s681B(3)). Adjusted net income is total income here (no reliefs).
-/

namespace UkTax

/-- How often the employee is paid (the earnings period). -/
inductive EarningsPeriod
  | annual
  | monthly
  | weekly
  deriving Repr, DecidableEq

/-- Primary threshold for the year: periods a year × the period's threshold. -/
def EarningsPeriod.primaryThreshold (P : TaxParams) : EarningsPeriod → Nat
  | .annual => P.ptAnnual
  | .monthly => 12 * P.ptMonthly
  | .weekly => 52 * P.ptWeekly

/-- Upper earnings limit for the year: periods a year × the period's limit. -/
def EarningsPeriod.upperEarningsLimit (P : TaxParams) : EarningsPeriod → Nat
  | .annual => P.uelAnnual
  | .monthly => 12 * P.uelMonthly
  | .weekly => 52 * P.uelWeekly

/-- Employee Class 1 NICs for the year on earnings `e` pence, exact, in units of
1/10 000 of a penny. -/
def nicExact (P : TaxParams) (p : EarningsPeriod) (e : Nat) : Nat :=
  P.nicMain * (min e (p.upperEarningsLimit P) - p.primaryThreshold P)
    + P.nicAdditional * (e - p.upperEarningsLimit P)

/-- The appropriate percentage (ITEPA 2003 s681C(2)-(3)), a whole number from 0
to 100, for adjusted net income `ani` pence. -/
def hicbcPercent (P : TaxParams) (ani : Nat) : Nat :=
  min 100 ((ani - P.cbThreshold) / P.cbStep)

/-- High Income Child Benefit Charge, in pence (always whole pounds), on Child
Benefit `cb` pence, for adjusted net income `ani` pence. The Child Benefit and
the charge are each rounded down to whole pounds (s681C(3)(a)). -/
def hicbc (P : TaxParams) (ani cb : Nat) : Nat :=
  100 * (hicbcPercent P ani * (cb / 100) / 100)

/-- Child Benefit for `children` children for `weeks` weeks, in pence. -/
def childBenefitFor (children weeks : Nat) : Nat :=
  if children = 0 then 0
  else weeks * (childBenefitEldestWeekly + (children - 1) * childBenefitOtherWeekly)

/-! ## Proved properties -/

/-- NICs never go down when earnings go up, on every basis. -/
theorem nicExact_mono (P : TaxParams) (p : EarningsPeriod) {e e' : Nat} (h : e ≤ e') :
    nicExact P p e ≤ nicExact P p e' := by
  unfold nicExact
  exact Nat.add_le_add (Nat.mul_le_mul_left _ (by omega)) (Nat.mul_le_mul_left _ (by omega))

/-- `c * v ≤ c * u + c` when `v` is at most one more than `u`. -/
theorem mul_le_succ (c : Nat) {u v : Nat} (h : v ≤ u + 1) : c * v ≤ c * u + c := by
  have := Nat.mul_le_mul_left c h
  rw [Nat.mul_add, Nat.mul_one] at this
  exact this

/-- A penny more pay adds at most the larger NIC rate, `P.nicStep`. -/
theorem nicExact_succ_le (P : TaxParams) (p : EarningsPeriod) (g : Nat) :
    nicExact P p (g + 1) ≤ nicExact P p g + P.nicStep := by
  unfold nicExact TaxParams.nicStep
  by_cases h : g < p.upperEarningsLimit P
  · have h1 := mul_le_succ P.nicMain
      (show min (g + 1) (p.upperEarningsLimit P) - p.primaryThreshold P
        ≤ (min g (p.upperEarningsLimit P) - p.primaryThreshold P) + 1 by omega)
    rw [show g + 1 - p.upperEarningsLimit P = g - p.upperEarningsLimit P by omega]
    omega
  · have h1 := mul_le_succ P.nicAdditional
      (show g + 1 - p.upperEarningsLimit P ≤ (g - p.upperEarningsLimit P) + 1 by omega)
    rw [show min (g + 1) (p.upperEarningsLimit P) = min g (p.upperEarningsLimit P) by omega]
    omega

/-- The charge never goes down when adjusted net income goes up. -/
theorem hicbc_mono_income (P : TaxParams) (cb : Nat) {a a' : Nat} (h : a ≤ a') :
    hicbc P a cb ≤ hicbc P a' cb := by
  unfold hicbc
  have : hicbcPercent P a ≤ hicbcPercent P a' := by
    unfold hicbcPercent
    have := Nat.div_le_div_right (c := P.cbStep) (Nat.sub_le_sub_right h P.cbThreshold)
    omega
  exact Nat.mul_le_mul_left _ (Nat.div_le_div_right (Nat.mul_le_mul_right _ this))

/-- The charge never exceeds the Child Benefit it is on: keeping the benefit is
never worse than giving it up (before any other effect). -/
theorem hicbc_le (P : TaxParams) (ani cb : Nat) : hicbc P ani cb ≤ cb := by
  unfold hicbc hicbcPercent
  have h1 : min 100 ((ani - P.cbThreshold) / P.cbStep) * (cb / 100) ≤ 100 * (cb / 100) :=
    Nat.mul_le_mul_right _ (Nat.min_le_left _ _)
  have h2 := Nat.div_le_div_right (c := 100) h1
  rw [Nat.mul_div_cancel_left _ (by decide)] at h2
  omega

/-- No charge at or below £60,000 plus £199.99: the first percentage point starts
at £60,200. -/
theorem hicbc_zero (P : TaxParams) {ani : Nat} (h : ani < P.cbThreshold + P.cbStep) (cb : Nat) :
    hicbc P ani cb = 0 := by
  unfold hicbc hicbcPercent
  have : (ani - P.cbThreshold) / P.cbStep = 0 := by
    rcases Nat.eq_zero_or_pos P.cbStep with h0 | h0
    · simp [h0]
    · exact Nat.div_eq_of_lt (by omega)
  rw [this]; simp

end UkTax
