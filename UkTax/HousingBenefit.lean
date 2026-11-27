import UkTax.Pension

/-!
# Housing Benefit for pensioners, 2026-27 (P5b)

The Housing Benefit (Persons who have attained the qualifying age for state
pension credit) Regulations 2006 (SI 2006/214, "HB(SPC)"), for a claimant who, or
whose partner, has reached the qualifying age for State Pension Credit and is not
on Universal Credit or an income-related legacy benefit (reg 5). In 2026-27 new
working-age claims are only for supported or temporary accommodation (SI 2014/1230
reg 6A), which is not modelled.

* **Maximum Housing Benefit** (reg 50): the eligible rent a week, capped at the
  local housing allowance for a private renter (an input; regs 12D, 13D), less the
  non-dependant deductions of reg 55: £131.45 for each non-dependant in
  remunerative work, less on lower gross income, £20.40 otherwise; none if the
  claimant or partner is blind or gets Attendance Allowance, the DLA care component
  or the PIP daily living component (reg 55(6)). The exemptions of reg 55(7)-(9)
  are the caller's.
* **Guarantee credit** (reg 26): a claimant or partner in receipt of the guarantee
  credit has all income and capital disregarded, so gets the maximum.
* **Savings credit only** (reg 27): income is the Pension Credit assessment plus the
  savings credit (reg 27(1), (4)(a)); the £16,000 capital limit applies to the
  Pension Credit capital (reg 27(6)); HB's own tariff income does not (reg 27(5)).
  Childcare charges and HB's extra earnings disregards of reg 27(4)(b)-(d) are not
  modelled.
* **Otherwise**: income (reg 29) less income tax on it (reg 33(12)), earnings less
  the Sch 4 disregard, and tariff income of £1 a week per £500 or part above
  £10,000 (reg 29(2)); no Housing Benefit with capital above £16,000 (reg 43). The
  additional £17.10 earnings disregard (Sch 4 para 9) is not modelled.
* **Award** (SSCBA 1992 s130(3); reg 51): the maximum less 65 % of income above the
  applicable amount (reg 22, Sch 3: the personal allowance, child amounts and
  premiums), not below nil.

Amounts are in units of 1/1 040 of a penny a week (`hu`), twice the Pension Credit
unit, so that 65 % of income stays whole; a year (52 weeks) of an amount `x hu` a
week is `x / 20` pence.
-/

namespace UkTax

/-- Units of a week (1/1 040 penny a week) in a penny a week. -/
def hw : Nat := 1_040

/-- A non-dependant: in remunerative work with gross weekly income (pence), or not
in remunerative work. -/
structure NonDep where
  working : Bool := false
  grossWeekly : Nat := 0
  deriving Repr

/-- The deduction for one non-dependant, pence a week (reg 55(1), (2)). -/
def NonDep.deduction (n : NonDep) : Nat :=
  if !n.working then hbNonDepBase
  else if n.grossWeekly < 19_200 then hbNonDepBase
  else if n.grossWeekly < 27_900 then 4_685
  else if n.grossWeekly < 36_500 then 6_435
  else if n.grossWeekly < 48_500 then 10_520
  else if n.grossWeekly < 60_500 then 11_985
  else hbNonDepTop

/-- A Housing Benefit claim under HB(SPC). Weekly amounts in pence. -/
structure HbClaim where
  /-- Weekly eligible rent (core rent and eligible service charges). -/
  rent : Nat := 0
  /-- Private renter: the local housing allowance that caps the eligible rent. -/
  lha : Option Nat := none
  nonDeps : List NonDep := []
  /-- The claimant or partner is blind or gets AA, DLA care or PIP daily living
  (reg 55(6)): no non-dependant deductions. -/
  nonDepExempt : Bool := false
  /-- Reached pensionable age before 1 April 2021 (claimant, or either partner). -/
  oldRates : Bool := false
  lone : Bool := false
  /-- Protected family premium (entitled on 30 April 2016). -/
  familyPremium : Bool := false
  severeDisability : Nat := 0
  enhancedDisabilityChildren : Nat := 0
  disabledChildren : Nat := 0
  carers : Nat := 0
  deriving Repr

/-- The applicable amount, pence a week (reg 22, Sch 3). -/
def HbClaim.applicable (h : HbClaim) (pc : PcClaim) : Nat :=
  (if pc.couple then (if h.oldRates then hbCoupleOld else hbCoupleNew)
   else (if h.oldRates then hbSingleOld else hbSingleNew))
    + pc.children * hbChild + (if h.familyPremium && pc.children > 0 then hbFamilyPremium else 0)
    + h.severeDisability * hbSevereDisability + h.enhancedDisabilityChildren * hbEnhancedDisabilityChild
    + h.disabledChildren * hbDisabledChild + h.carers * hbCarer

/-- Eligible rent, pence a week. -/
def HbClaim.eligibleRent (h : HbClaim) : Nat :=
  match h.lha with
  | some l => min h.rent l
  | none => h.rent

/-- Non-dependant deductions, pence a week. -/
def HbClaim.nonDepDeductions (h : HbClaim) : Nat :=
  if h.nonDepExempt then 0 else (h.nonDeps.map NonDep.deduction).sum

/-- Maximum Housing Benefit, pence a week (reg 50). -/
def HbClaim.maximum (h : HbClaim) : Nat := h.eligibleRent - h.nonDepDeductions

/-- The earnings disregard, pence a week (Sch 4). -/
def HbClaim.disregard (h : HbClaim) (pc : PcClaim) : Nat :=
  if h.lone then hbDisregardLoneParent else if pc.higherDisregard then pcDisregardHigher
  else if pc.couple then pcDisregardCouple else pcDisregardSingle

/-- Tariff income from capital, pence a week (reg 29(2)): the same rule as Pension
Credit's deemed income. -/
def hbTariff (capital : Nat) : Nat := deemedIncome capital

/-- Income under HB's own rules, `hu` a week: as Pension Credit's income
(`PcClaim.income`, in `wk` units) but with the Sch 4 earnings disregard. -/
def HbClaim.income (h : HbClaim) (pc : PcClaim) : Nat :=
  2 * (10 * (pc.statePension + pc.otherPension + pc.otherIncome + pc.excludedIncome)
    + (10 * pc.earnings - wk * h.disregard pc) - 10 * pc.incomeTax + wk * hbTariff pc.capital)

/-- Housing Benefit a week in `hu`, on income `i` (`hu`): the maximum less 65 % of
income above the applicable amount. -/
def hbTaper (maxHb aa i : Nat) : Nat := hw * maxHb - 13 * (i - hw * aa) / 20

/-- Housing Benefit a week, `hu`. -/
def housingBenefit (h : HbClaim) (pc : PcClaim) : Nat :=
  let gc := guaranteeCredit pc.mg pc.income
  let sc := if pc.savingsCredit then savingsCredit pc.mg pc.smg pc.threshold pc.income
      (pc.income - 10 * pc.excludedIncome) else 0
  if 0 < gc then hw * h.maximum
  else if pc.capital > hbCapitalLimit then 0
  else if 0 < sc then hbTaper h.maximum (h.applicable pc) (2 * pc.income + hw * sc)
  else hbTaper h.maximum (h.applicable pc) (h.income pc)

/-! ## Proved properties -/

/-- On the taper (`hbTaper`, with the maximum and applicable amount fixed), income
plus Housing Benefit keeps at least 35 % of any rise in income: the taper takes
65 %, never more. This is about `hbTaper` only, not every route of
`housingBenefit`: a rise that ends the guarantee credit, or changes the savings
credit added to income, is not covered. -/
theorem hb_total_gain (m aa i δ : Nat) :
    i + hbTaper m aa i + 7 * δ / 20 ≤ (i + δ) + hbTaper m aa (i + δ) + 1 := by
  unfold hbTaper hw; omega

/-- With the guarantee credit, Housing Benefit is the maximum whatever the income
and capital (reg 26). -/
theorem hb_passport (h : HbClaim) (pc : PcClaim) (hg : 0 < guaranteeCredit pc.mg pc.income) :
    housingBenefit h pc = hw * h.maximum := by
  unfold housingBenefit; simp only [hg, ↓reduceIte]

/-- **The capital limit is a cliff.** Without the guarantee credit, a penny over
£16,000 of capital loses all Housing Benefit. At £16,000 itself the claim is
assessed as usual (`housingBenefit` tests `capital > hbCapitalLimit`); this theorem
proves only the loss a penny above it. -/
theorem hb_capital_cliff (h : HbClaim) (pc : PcClaim) (hg : guaranteeCredit pc.mg pc.income = 0)
    (hc : pc.capital = hbCapitalLimit + 1) : housingBenefit h pc = 0 := by
  unfold housingBenefit
  simp only [hg, Nat.lt_irrefl, ↓reduceIte, hc]
  simp [hbCapitalLimit]

/-- The non-dependant deduction never falls as the non-dependant's income rises. -/
theorem nonDep_mono (w : Bool) {a b : Nat} (hab : a ≤ b) :
    NonDep.deduction ⟨w, a⟩ ≤ NonDep.deduction ⟨w, b⟩ := by
  unfold NonDep.deduction hbNonDepBase hbNonDepTop
  cases w <;> simp only [Bool.not_false, Bool.not_true, Bool.false_eq_true, ↓reduceIte] <;>
    repeat' split
  all_goals omega

end UkTax
