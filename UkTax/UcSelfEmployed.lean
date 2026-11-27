import UkTax.Benefits
import UkTax.Nics
import UkTax.Profits
import UkTax.Misc

/-!
# Universal Credit for the self-employed and the minimum income floor (P4b)

## Self-employed earnings (SI 2013/376 reg 57)

For one trade, a year of equal assessment periods: the actual receipts less the
allowable expenses (step 1; reg 57(2) has no trading allowance), less the income
tax and National Insurance paid in respect of the trade (step 3); nil if that is
nil or less (so a loss never reduces employed earnings). Unused losses carried
between assessment periods (reg 57A, step 5) do not arise with equal months.

The tax in respect of the trade is taken as the tax on pay and profit less the tax
on the pay alone (the profit above the pay), as the tax on pay is taken for
employed earnings (`earned`); the regulation does not say how to split a person's
tax. National Insurance in respect of the trade is Class 4; Class 2 is treated as
paid above the small profits threshold, so nothing is paid (SSCBA 1992 s11).

## The minimum income floor (reg 62)

A claimant in gainful self-employment (reg 64) who would otherwise be subject to
all work-related requirements, outside a start-up period (regs 62(5), 63), whose
earned income is below their individual threshold is treated as having that
threshold (reg 62(2)). The individual threshold (reg 90(2)(b)) is what "a person
of the same age as the claimant would be paid at the hourly rate applicable under
regulation 4 or regulation 4A(1)(a) to (c)" of the National Minimum Wage
Regulations 2015 for the expected hours (35 unless lower under reg 88(2)), × 52 / 12
a month: £12.71 at 21 or over, £10.85 at 18 to 20, £8.00 under 18 (SI 2026/357 reg
2; `minimumWage` outside apprenticeships). Not modelled: the apprentice rate of reg
90(4), the 16 hours of reg 90(2)(a), and reg 90(3)(b) (a partner who is not a joint
claimant). Reg 6(1A)(a)
disregards a fraction of a pound in an amount calculated for reg 90; DWP's
published floors keep the pence, so both are offered (`wholePounds`).

The threshold is "converted to [a] net amount" by "deducting such amount for
income tax and national insurance contributions as the Secretary of State
considers appropriate" (reg 62(4)(b)); DWP's Advice for Decision Making (H4078)
repeats the words and gives no method. The model deducts the income tax and Class 4
a person with that threshold as their only income, from self-employment, would pay
(the personal allowance, the person's own rest-of-UK or Scottish rates), as
PolicyEngine does: a modelling choice, not law.

For a member of a couple (reg 62(3)) the floor applies while the claimant's earned
income is below their threshold and the couple's below the couple threshold (the
sum of the joint claimants' thresholds, reg 90(3)(a)), and is the threshold less
any excess of it and the partner's earned income over the couple threshold.
`mifCouple_eq` proves that this is `max e (min F (Tc - P))`: the floor is a plain
lower bound on earned income.

Proved: `mifCouple_eq`; `uc_flat_below_floor` (below the floor more earnings leave
UC unchanged, so each penny of profit is kept in full) and
`earned_plus_uc_mono_floor` (with the floor, earned income plus UC never falls as
earned income rises).
-/

namespace UkTax

/-- The individual threshold for a year (12 months), pence, for a claimant aged
`age` with `hours` expected hours a week: `hours` × the minimum wage for that age ×
52 / 12 a month, in whole pounds a month if `wholePounds` (reg 6(1A)(a)), else exact
(a year is then `hours` × the rate × 52). -/
def mifGrossYear (wholePounds : Bool) (age hours : Nat) : Nat :=
  let r := minimumWage age false
  if wholePounds then 12 * (hours * r * 52 / 1_200 * 100)
  else hours * r * 52

/-- The net individual threshold for the year, 1/10 000 pence: the gross threshold
less the income tax (personal allowance, the person's own rates, no other relief)
and Class 4 on it as the person's only income. -/
def mifNetYear (P : TaxParams) (scottish wholePounds : Bool) (age hours : Nat) : Int :=
  let g := mifGrossYear wholePounds age hours
  10_000 * (g : Int) - (taxExact { scottish, params := P } ⟨g, 0, 0⟩ : Int)
    - (class4Exact P .annual 0 g : Int)

/-- Self-employed earnings for the year (reg 57), 1/10 000 pence: UC profit `u`
(receipts less expenses, pence, may be negative) less the income tax on the
taxable profit `π` above pay `g` and Class 4 on it; nil if not positive. -/
def seEarned (p : EarningsPeriod) (rg : Regime) (g π : Nat) (u : Int) : Int :=
  max 0 (10_000 * u - ((finalTaxExact rg ⟨g + π, 0, 0⟩ : Int) - finalTaxExact rg ⟨g, 0, 0⟩)
    - (class4Exact rg.params p (g + rg.netPay) π : Int))

/-- The claimant's earned income (1/10 000 pence a year): employed earnings
(`earned`, pay less tax on the pay alone, Class 1 and net pay pension
contributions) plus self-employed earnings. -/
def earnedWithTrade (p : EarningsPeriod) (rg : Regime) (g π : Nat) (u : Int) : Int :=
  earned p rg 0 0 g + seEarned p rg g π u

/-- Reg 62(3) as it reads, for a claimant with earned income `e`, individual
threshold `F`, partner's earned income `P` and couple threshold `Tc` (a single
claimant is a couple with `P = 0` and `Tc = F`, which is reg 62(2)). -/
def mifCouple (F P Tc e : Int) : Int :=
  if e < F ∧ e + P < Tc then F - max 0 (F + P - Tc) else e

/-- **Reg 62(3) is a lower bound.** The floor gives `max e (min F (Tc − P))`. -/
theorem mifCouple_eq (F P Tc e : Int) : mifCouple F P Tc e = max e (min F (Tc - P)) := by
  unfold mifCouple
  split <;> omega

/-- UC with the floor `f`: the award on `max e f`. -/
def ucAwardFloor (P : TaxParams) (c : Claims) (f e : Int) : Int := ucAward P c (max e f)

/-! ## Proved properties -/

/-- **Below the floor UC does not move.** Any two earned incomes at or below the
floor give the same UC: a penny more profit there is kept in full. -/
theorem uc_flat_below_floor (P : TaxParams) (c : Claims) {f e e' : Int} (h : e ≤ f) (h' : e' ≤ f) :
    ucAwardFloor P c f e = ucAwardFloor P c f e' := by
  unfold ucAwardFloor
  rw [show max e f = f by omega, show max e' f = f by omega]

/-- **The floor keeps the taper honest.** With the floor, earned income plus UC
never falls as earned income rises (above it, the taper, at most 100 %; below it,
UC is fixed). -/
theorem earned_plus_uc_mono_floor (P : TaxParams) (hT : P.ucTaper ≤ 100) (c : Claims) (f : Int)
    {e e' : Int} (h : e ≤ e') :
    100 * e + ucAwardFloor P c f e ≤ 100 * e' + ucAwardFloor P c f e' := by
  unfold ucAwardFloor
  have hx : max e f ≤ max e' f := by omega
  have := earned_plus_uc_gain P c hx
  have : (0 : Int) ≤ (100 - (P.ucTaper : Int)) * (max e' f - max e f) :=
    Int.mul_nonneg (by omega) (by omega)
  have : max e' f - max e f ≤ e' - e := by omega
  omega

end UkTax
