import UkTax.Params

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
def EarningsPeriod.primaryThreshold : EarningsPeriod → Nat
  | .annual => primaryThresholdAnnual
  | .monthly => 12 * primaryThresholdMonthly
  | .weekly => 52 * primaryThresholdWeekly

/-- Upper earnings limit for the year: periods a year × the period's limit. -/
def EarningsPeriod.upperEarningsLimit : EarningsPeriod → Nat
  | .annual => upperEarningsLimitAnnual
  | .monthly => 12 * upperEarningsLimitMonthly
  | .weekly => 52 * upperEarningsLimitWeekly

/-- Employee Class 1 NICs for the year on earnings `e` pence, exact, in units of
1/10 000 of a penny. -/
def nicExact (p : EarningsPeriod) (e : Nat) : Nat :=
  nicMainRate * (min e p.upperEarningsLimit - p.primaryThreshold)
    + nicAdditionalRate * (e - p.upperEarningsLimit)

/-- The appropriate percentage (ITEPA 2003 s681C(2)-(3)), a whole number from 0
to 100, for adjusted net income `ani` pence. -/
def hicbcPercent (ani : Nat) : Nat :=
  min 100 ((ani - hicbcThreshold) / hicbcStep)

/-- High Income Child Benefit Charge, in pence (always whole pounds), on Child
Benefit `cb` pence, for adjusted net income `ani` pence. The Child Benefit and
the charge are each rounded down to whole pounds (s681C(3)(a)). -/
def hicbc (ani cb : Nat) : Nat :=
  100 * (hicbcPercent ani * (cb / 100) / 100)

/-- Child Benefit for `children` children for `weeks` weeks, in pence. -/
def childBenefitFor (children weeks : Nat) : Nat :=
  if children = 0 then 0
  else weeks * (childBenefitEldestWeekly + (children - 1) * childBenefitOtherWeekly)

/-! ## Proved properties -/

/-- NICs never go down when earnings go up, on every basis. -/
theorem nicExact_mono (p : EarningsPeriod) {e e' : Nat} (h : e ≤ e') :
    nicExact p e ≤ nicExact p e' := by
  unfold nicExact nicMainRate nicAdditionalRate
  omega

/-- The charge never goes down when adjusted net income goes up. -/
theorem hicbc_mono_income (cb : Nat) {a a' : Nat} (h : a ≤ a') : hicbc a cb ≤ hicbc a' cb := by
  unfold hicbc
  have : hicbcPercent a ≤ hicbcPercent a' := by
    unfold hicbcPercent
    have := Nat.div_le_div_right (c := hicbcStep) (Nat.sub_le_sub_right h hicbcThreshold)
    omega
  exact Nat.mul_le_mul_left _ (Nat.div_le_div_right (Nat.mul_le_mul_right _ this))

/-- The charge never exceeds the Child Benefit it is on: keeping the benefit is
never worse than giving it up (before any other effect). -/
theorem hicbc_le (ani cb : Nat) : hicbc ani cb ≤ cb := by
  unfold hicbc hicbcPercent
  have h1 : min 100 ((ani - hicbcThreshold) / hicbcStep) * (cb / 100) ≤ 100 * (cb / 100) :=
    Nat.mul_le_mul_right _ (Nat.min_le_left _ _)
  have h2 := Nat.div_le_div_right (c := 100) h1
  rw [Nat.mul_div_cancel_left _ (by decide)] at h2
  omega

/-- No charge at or below £60,000 plus £199.99: the first percentage point starts
at £60,200. -/
theorem hicbc_zero {ani : Nat} (h : ani < hicbcThreshold + hicbcStep) (cb : Nat) :
    hicbc ani cb = 0 := by
  unfold hicbc hicbcPercent hicbcThreshold hicbcStep at *
  have : (ani - 6_000_000) / 20_000 = 0 := by omega
  rw [this]; simp

end UkTax
