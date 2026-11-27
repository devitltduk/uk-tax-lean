import UkTax.HousingBenefit

/-!
# Council tax and Council Tax Reduction for pensioners, 2026-27 (P7)

## Council tax

A dwelling's council tax is the billing authority's band D amount (an input) in the
band's proportion: 6 : 7 : 8 : 9 : 11 : 13 : 15 : 18 ninths for bands A to H, and
21 for band I in Wales (LGFA 1992 s5(1), (1A)); in Scotland 240 : 280 : 320 : 360 :
473 : 585 : 705 : 882 360ths (s74(1)). With one resident (no resident disregarded),
25 % off (s11(1)(b), s79). Exact, in 1/1 440 pence (1 440 = 4 × 360).

## Council Tax Reduction for pensioners

The prescribed schemes for pensioners: England (SI 2012/2885 Sch 1), Wales (WSI
2013/3029 Sch 1) and Scotland (SSI 2012/319). Each works by the day: the reduction
for a day is that day's council tax, less the non-dependant deductions × 1/7, less
amount B, 2 6/7 % of the week's income above the applicable amount (England Sch 1
paras 3(f), 7, 8). Over the 365 days of 2026-27 (1 April 2026 to 31 March 2027)
that is the year's council tax less 365/7 weeks of the deductions and of 20 % of the
excess income. Exact, in 1/7 280 pence (7 280 = 7 × 1 040).

Income follows the Housing Benefit for pensioners rules of `UkTax/HousingBenefit.lean`
(the schemes copy them): with the guarantee credit no income counts; with savings
credit only, the Pension Credit income plus the savings credit; otherwise income net
of tax with tariff income, and nothing above £16,000 of capital. The applicable
amount is Housing Benefit's in England (with no family premium after 1 May 2016);
in Wales and Scotland the higher personal allowance whatever the date pensionable
age was reached, with Wales's family premium and Scotland's £109.85 child amount.
The council tax liability for the reduction is an input (the bill, after discounts).
-/

namespace UkTax

inductive Nation where
  | england
  | wales
  | scotland
  deriving DecidableEq, Repr

/-- Council tax for the year in 1/1 440 pence, for band `b` (0 = A, ..., 7 = H, 8 = I
in Wales), band D amount `d` pence, with the single person discount if `single`. -/
def councilTax (n : Nation) (b d : Nat) (single : Bool) : Nat :=
  -- 1/1 440 = 1/(4 × 360) = 1/(160 × 9)
  let base := 4 * ((if n = .scotland then ctScot360.getD b 0 else 40 * ctNinths.getD b 0) * d)
  if single then base * (100 - ctDiscountPercent) / 100 else base

/-- A non-dependant's deduction, pence a week. -/
def ctrNonDep (n : Nation) (nd : NonDep) : Nat :=
  let amounts := match n with
    | .england => ctrNonDepEngland
    | .wales => ctrNonDepWales
    | .scotland => ctrNonDepScotland
  let bands := if n = .scotland then ctrBandsScotland else ctrBandsGb
  let k := if !nd.working then 0 else (bands.filter (· ≤ nd.grossWeekly)).length
  amounts.getD (min k 3) 0

/-- Non-dependant deductions a week (none with the reg 55(6)-style exemption). -/
def ctrNonDeps (n : Nation) (h : HbClaim) : Nat :=
  if h.nonDepExempt then 0 else (h.nonDeps.map (ctrNonDep n)).sum

/-- The applicable amount, pence a week. -/
def ctrApplicable (n : Nation) (h : HbClaim) (pc : PcClaim) : Nat :=
  let premiums := h.severeDisability * hbSevereDisability
    + h.enhancedDisabilityChildren * hbEnhancedDisabilityChild + h.disabledChildren * hbDisabledChild
    + h.carers * hbCarer
  match n with
  | .england => HbClaim.applicable { h with familyPremium := false } pc
  | .wales => (if pc.couple then hbCoupleOld else hbSingleOld) + pc.children * hbChild
      + (if pc.children > 0 then hbFamilyPremium else 0) + premiums
  | .scotland => (if pc.couple then hbCoupleOld else hbSingleOld) + pc.children * ctrChildScotland
      + premiums

/-- The year's withdrawal in 1/7 280 pence: 365/7 weeks of the non-dependant
deductions `nd` (pence a week) and of 20 % of income `i` (`hu`, 1/1 040 penny a
week) above the applicable amount `aa` (pence a week). -/
def ctrWithdrawal (nd aa i : Nat) : Nat := 365 * hw * nd + 73 * (i - hw * aa)

/-- Council Tax Reduction for the year in 1/7 280 pence, on council tax `ct` pence. -/
def ctrTaper (ct nd aa i : Nat) : Nat := 7_280 * ct - ctrWithdrawal nd aa i

/-- Council Tax Reduction for the year, 1/7 280 pence, and the withdrawal. -/
def ctrIncome (h : HbClaim) (pc : PcClaim) : Option Nat :=
  let gc := guaranteeCredit pc.mg pc.income
  let sc := if pc.savingsCredit then savingsCredit pc.mg pc.smg pc.threshold pc.income
      (pc.income - 10 * pc.excludedIncome) else 0
  if 0 < gc then some 0
  else if pc.capital > hbCapitalLimit then none
  else if 0 < sc then some (2 * pc.income + hw * sc)
  else some (h.income pc)

def councilTaxReduction (n : Nation) (ct : Nat) (h : HbClaim) (pc : PcClaim) : Nat :=
  match ctrIncome h pc with
  | none => 0
  | some i => ctrTaper ct (ctrNonDeps n h) (ctrApplicable n h pc) i

/-! ## Proved properties -/

/-- Each extra unit of weekly income above the applicable amount costs exactly 73
units of the year's reduction (20 % of it for 365/7 weeks), and never more. -/
theorem ctr_step (ct nd aa i δ : Nat) :
    ctrTaper ct nd aa (i + δ) ≤ ctrTaper ct nd aa i ∧
      ctrTaper ct nd aa i ≤ ctrTaper ct nd aa (i + δ) + 73 * δ := by
  unfold ctrTaper ctrWithdrawal hw; omega

/-- With no income above the applicable amount and no non-dependants, the reduction
is the whole council tax. -/
theorem ctr_full (ct aa i : Nat) (h : i ≤ hw * aa) : ctrTaper ct 0 aa i = 7_280 * ct := by
  unfold ctrTaper ctrWithdrawal; omega

/-- The single person discount takes exactly a quarter off. -/
theorem councilTax_discount (n : Nation) (b d : Nat) :
    4 * councilTax n b d true = 3 * councilTax n b d false := by
  unfold councilTax ctDiscountPercent
  simp only [↓reduceIte, Bool.false_eq_true]
  generalize (if n = .scotland then ctScot360.getD b 0 else 40 * ctNinths.getD b 0) * d = z
  omega

end UkTax
