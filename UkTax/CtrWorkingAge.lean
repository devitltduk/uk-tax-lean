import UkTax.CouncilTax
import UkTax.HousingBenefitWa
import UkTax.CarerUc

/-!
# Council Tax Reduction for working-age applicants: Wales and Scotland (P7b)

The Council Tax Reduction Schemes and Prescribed Requirements (Wales) Regulations
2013 (WSI 2013/3029), classes C and D (regs 24, 25), which every Welsh authority's
scheme must include.

* **Maximum reduction** (Sch 6 para 4): the day's council tax (the year's bill,
  after discounts, ÷ the 365 days of 2026-27) less the non-dependant deductions × 1/7
  (para 5, the pensioner scheme's amounts).
* **Reduction** (Sch 6 para 6): class C (income at most the applicable amount) the
  maximum; class D the maximum less amount B, 2 6/7 % of the week's income above the
  applicable amount (reg 25(f)), not below nil. Over the year: the bill less 365/7
  weeks of the deductions and of 20 % of the excess income.
* **Not on UC** (Sch 6 Part 4, Sch 7, Sch 8): the applicable amount is the personal
  allowance (£101.85 single 25 or over or lone parent, £80.60 single under 25,
  £159.85 couple), £87.88 for each child, the family premium £20.22 for any family
  with a child, and the premiums of Housing Benefit; income is net earnings (gross
  pay less tax, primary Class 1 and half the pension contributions, para 15(3))
  less the Sch 8 disregards (£5, £10, £20, £25 and the £17.10 step, as in
  `hbWaEarningsAfter`), other income in full, and tariff income (£1 for each £250
  or part above £6,000, para 33); no reduction above £16,000 of capital. An
  applicant on income support, income-based JSA or income-related ESA has the
  maximum (as an input, `passported`).
* **On UC** (Sch 6 paras 3, 9; an award above nil, else the own rules): the applicable amount is the UC maximum amount ×
  12/52, and income is the income DWP assessed for UC plus the UC award, × 12/52.

`ctrWalesUc_excess` proves what the UC rule comes to: while UC is in payment (and
the benefit cap does not bite), the week's excess income is 12/52 of the household's
earned income less 55 % of it above the work allowance. The maximum amount, the
unearned income and the childcare element all cancel, so the Welsh reduction of a
UC claimant depends on earnings alone.

Amounts are in units of 1/364 000 000 of a penny (`cu`): 2 6/7 % of a week over 365
days is 73/364 of a week's excess, and 1/364 000 000 = 1/(52 × 7 × 1 000 000).
-/

namespace UkTax

/-- 1/364 000 000 of a penny per penny. -/
def cu : Int := 364_000_000

/-- The Welsh working-age applicable amount, pence a week (Sch 7), for a claim
described as for Housing Benefit. -/
def HbWaClaim.walesApplicable (h : HbWaClaim) : Nat :=
  h.applicable + ctrWalesPersonal h - (if h.couple then hbWaCouple else if h.lone then hbWaLoneParent
      else if h.under25 then hbWaSingleU25 else hbWaSingle25)
    + (if h.children > 0 && !h.familyPremium then hbFamilyPremium else 0)
where
  ctrWalesPersonal (h : HbWaClaim) : Nat :=
    if h.couple then ctrWalesCouple else if h.lone then ctrWalesLoneParent
    else if h.under25 then ctrWalesSingleU25 else ctrWalesSingle25

/-- The year's reduction, `cu`, on council tax `ct` pence for the year, non-dependant
deductions `nd` pence a week, and the year's excess income `x` (1/1 000 000 pence,
52 weeks of the weekly excess): the bill less 365/7 weeks of the deductions and
73/364 of the week's excess for each week of it. -/
def ctrWaYear (ct nd : Nat) (x : Int) : Int :=
  max 0 (cu * ct - 365 * 52_000_000 * (nd : Int) - 73 * max 0 x)

/-- The year's withdrawal, `cu`: 365/7 weeks of the deductions and of 20 % of the
excess. -/
def ctrWaWithdrawal (nd : Nat) (x : Int) : Int := 365 * 52_000_000 * (nd : Int) + 73 * max 0 x

/-- Wales, not on UC: the year's excess income (1/1 000 000 pence, 52 weeks) on net
earnings `E` (1/10 000 pence a year). -/
def walesOwnExcess (h : HbWaClaim) (E : Int) : Int :=
  100 * (hbWaEarningsAfter h.additionalDisregard h.disregard.weekly E
    + 10_000 * 52 * ((h.otherWeekly + hbWaTariff h.capital : Nat) : Int)
    - 10_000 * 52 * (h.walesApplicable : Int))

/-- Wales, not on UC: the year's reduction, `cu`. -/
def ctrWalesOwn (ct : Nat) (h : HbWaClaim) (E : Int) : Int :=
  if h.passported then ctrWaYear ct (ctrNonDeps .wales h.housing) 0
  else if h.capital > hbCapitalLimit then 0
  else ctrWaYear ct (ctrNonDeps .wales h.housing) (walesOwnExcess h E)

/-- Wales, on UC: the year's excess income, 1/1 000 000 pence (52 weeks of 12/52 of
the monthly amounts is 12 months of them): the income assessed for UC (the claimant's
earned income `e`, 1/10 000 pence a year, the partner's, unearned and tariff income
and Carer's Allowance) plus the award, less 12 months of the maximum amount
(childcare element included). -/
def walesUcExcess (P : TaxParams) (c : Claims) (e : Int) : Int :=
  100 * (e + 10_000 * (c.partnerEarned : Int)) + 12 * (micro * ((c.tariff + c.unearnedMonthly : Nat) : Int))
    + micro * (c.carersAllowanceYear : Int) + ucAward P c e - 12 * (c.maxMicro + c.childcareMicro e)

/-- Wales, on UC: the year's reduction, `cu`. -/
def ctrWalesUc (P : TaxParams) (ct nd : Nat) (c : Claims) (e : Int) : Int :=
  ctrWaYear ct nd (walesUcExcess P c e)

/-! ## Proved properties -/

/-- **On UC, the Welsh reduction depends on earnings alone.** While UC is in payment
and the benefit cap does not apply, the year's excess income is the household's
earned income less the taper (55 %) of it above the work allowance: the maximum amount, unearned
income, Carer's Allowance and the childcare element cancel. -/
theorem ctrWalesUc_excess (P : TaxParams) (c : Claims) (e : Int) (hcap : c.capApplies (e + 10_000 * (c.partnerEarned : Int)) = false)
    (h : 0 < ucAward P c e) :
    walesUcExcess P c e = 100 * (e + 10_000 * (c.partnerEarned : Int))
      - (P.ucTaper : Int) * max 0 (e + 10_000 * (c.partnerEarned : Int) - 10_000 * 12 * (c.workAllowance : Int)) := by
  unfold walesUcExcess
  unfold ucAward at *
  simp only [hcap, Bool.false_eq_true, ↓reduceIte] at *
  split at h
  · rename_i hu
    simp only [hu, ↓reduceIte]
    generalize c.childcareMicro e = X at *
    generalize c.maxMicro = M at *
    generalize micro * ((c.tariff + c.unearnedMonthly : Nat) : Int) = T at *
    generalize (P.ucTaper : Int) * max 0 (e + 10_000 * (c.partnerEarned : Int)
      - 10_000 * 12 * (c.workAllowance : Int)) = TP at *
    omega
  · omega

/-- A reduction never exceeds the bill, and each unit of excess income costs at most
73/364 of it (20 % for 365/7 weeks). -/
theorem ctrWaYear_bounds (ct nd : Nat) (x δ : Int) (hδ : 0 ≤ δ) :
    ctrWaYear ct nd x ≤ cu * ct ∧ ctrWaYear ct nd (x + δ) ≤ ctrWaYear ct nd x ∧
      ctrWaYear ct nd x ≤ ctrWaYear ct nd (x + δ) + 73 * δ := by
  unfold ctrWaYear cu
  refine ⟨by omega, by omega, by omega⟩

/-! # Scotland (SSI 2021/249)

The Council Tax Reduction (Scotland) Regulations 2021, for applicants under
pensionable age (and pensioners with UC or a qualifying income-related benefit,
reg 3).

* **Reg 13** (the main reduction): as in Wales, the day's council tax (reg 79(1))
  less the non-dependant deductions × 1/7 (reg 90), less 2 6/7 % of the week's
  income above the applicable amount; the maximum for a qualifying income-related
  benefit claimant (reg 13(11)); or, if greater, the **second adult rebate**
  (reg 13(7), (10), Sch 2).
* **Reg 14** (dwellings in bands E to H): the part of the day's tax due to the 2017
  rise in the band proportions, A − A/C (reg 79(2)), less the deductions, less
  2 6/7 % of the week's income above £321 (single, no child) or £479; due instead
  of reg 13 where it is greater (regs 13(4), 14(1)(b)).
* **Not on UC** (regs 38, 50, 57, 63; Sch 1, Sch 3): the Housing Benefit personal
  allowances and premiums with £109.85 for each child and no family premium; net
  earnings less the Sch 3 disregards (with the £17.10 step), other income, and
  tariff income of £1 a week for each £250 or part above £6,000.
* **On UC** (regs 42, 43, 49, 57(1)(p), 63(1)(a), 78; an award above nil): Scotland
  keeps its own applicable amount. Income is 12/52 of the month's UC earned income
  (pay less tax and Class 1, reg 49(6)) less the Sch 3 disregards (no £17.10 step),
  plus 12/52 of the unearned income, of £4.35 a month for each £250 of capital
  above £6,000, and of the **relevant UC payments** (the child element with the
  disabled child additions and the childcare costs element, or the award if lower,
  where there is a child element), less the childcare costs element × 100/85 ×
  12/52, rounded to the penny (reg 78(3)), up to £290 a week for one child or £497
  for more (reg 42(4), read as capping every deduction under reg 42(2)(c)).

Amounts in the reg 14 comparison are in units of 1/(364 000 000 × 891 261) of a
penny (`su`): 891 261 = 43 × 9 × 47 × 49, the denominators of (C − 1)/C.
-/

/-- 1/891 261 of a `cu`. -/
def suPerCu : Int := 891_261

/-- The Scottish working-age applicable amount, pence a week (Sch 1): the Housing
Benefit amount with the child premium of £109.85 in place of £87.88 and no family
premium. -/
def HbWaClaim.scotApplicable (h : HbWaClaim) : Nat :=
  h.applicable + h.children * ctrChildScotland - h.children * hbChild
    - (if h.familyPremium && h.children > 0 then hbFamilyPremium else 0)

/-- Scotland, not on UC: the year's excess income (1/1 000 000 pence, 52 weeks). -/
def scotOwnExcess (h : HbWaClaim) (E : Int) : Int :=
  100 * (hbWaEarningsAfter h.additionalDisregard h.disregard.weekly E
    + 10_000 * 52 * ((h.otherWeekly + hbWaTariff h.capital : Nat) : Int)
    - 10_000 * 52 * (h.scotApplicable : Int))

/-- The relevant UC payments for the year, 1/1 000 000 pence (reg 57(1)(p), (2)(d)):
with a child element, the child element and disabled child additions and the
childcare costs element, or the award (after the benefit cap) if lower. -/
def scotUcPayments (P : TaxParams) (c : Claims) (e : Int) : Int :=
  if c.childElements > 0 then
    min (12 * (micro * ((c.childElements + c.disabledLower * ucDisabledChildLower
      + c.disabledHigher * ucDisabledChildHigher : Nat) : Int) + c.childcareMicro e)) (ucAward P c e)
  else 0

/-- The weekly relevant childcare charges of a UC claimant, pence (reg 78(3)): the
month's childcare costs element × 100/85 × 12/52, to the nearest penny, up to the
reg 42(4) maximum. -/
def scotUcChildcare (c : Claims) (e : Int) : Int :=
  min ((2 * 1200 * c.childcareMicro e + 85 * 52 * micro) / (2 * 85 * 52 * micro))
    (if c.ucChildcareChildren ≤ 1 then ctrScotUcChildcareMaxOne else ctrScotUcChildcareMaxTwo)

/-- Scotland, on UC: the year's excess income, 1/1 000 000 pence (52 weeks): UC
earned income `e` (1/10 000 pence a year) and the partner's less the weekly
disregard `S`, unearned income, Carer's Allowance, UC tariff income and the relevant
UC payments, less the childcare charges and the applicable amount `A` (pence a
week). -/
def scotUcExcess (P : TaxParams) (c : Claims) (S A : Nat) (e : Int) : Int :=
  100 * hbWaEarningsAfter false S (e + 10_000 * (c.partnerEarned : Int))
    + 12 * (micro * ((c.tariff + c.unearnedMonthly : Nat) : Int)) + micro * (c.carersAllowanceYear : Int)
    + scotUcPayments P c e - 52 * micro * scotUcChildcare c e - 52 * micro * (A : Int)

/-- The second adult rebate for the year, `cu` (Sch 2): `rate` tenths of a percent of
the year's council tax due `gct` pence. -/
def scotSar (gct rate : Nat) : Int := 364_000 * (rate : Int) * (gct : Int)

/-- The second adult rebate's rate, tenths of a percent (Sch 2 para 1): `onBenefit`
where every second adult is on a qualifying income-related benefit, State Pension
Credit or UC with no earned income; `students` where the dwelling would otherwise be
wholly occupied by students; otherwise by the second adults' gross weekly income
`g` pence. -/
def scotSarRate (onBenefit students : Bool) (g : Nat) : Nat :=
  if students then 1000 else if onBenefit then 250
  else if g < ctrScotSarLower then 150 else if g < ctrScotSarUpper then 75 else 0

/-- (C − 1)/C for band `b` (0 = A, ..., 7 = H), in units of 1/891 261 (reg 79(3)). -/
def scotBandShare (b : Nat) : Nat :=
  if b = 4 then 62_181 else if b = 5 then 99_029 else if b = 6 then 132_741
  else if b = 7 then 163_701 else 0

/-- Reg 14 for the year, `su`: in band `b` (E to H), the band-rise share of the bill
`ct` less 365/7 weeks of the deductions `nd` and of 20 % of the income above the
threshold `T`, the year's excess income over the applicable amount `A` being `x`. -/
def scotBandsEH (b ct nd A T : Nat) (x : Int) : Int :=
  if scotBandShare b = 0 then 0
  else max 0 (cu * ct * scotBandShare b
    - suPerCu * (365 * 52_000_000 * (nd : Int) + 73 * max 0 (x + 52_000_000 * ((A : Int) - T))))

/-- The reg 14 threshold, pence a week. -/
def HbWaClaim.scotBandsThreshold (h : HbWaClaim) : Nat :=
  if !h.couple && h.children = 0 then ctrScotBandsEHSingle else ctrScotBandsEHOther

/-- The Scottish reduction for the year, `su`: the greater of reg 13 (the main
reduction `main`, `cu`, or the second adult rebate `sar`) and reg 14; nil with
capital over £16,000 (`capOk` false). -/
def scotTotal (capOk : Bool) (main sar bands : Int) : Int :=
  if capOk then max (suPerCu * max main sar) bands else 0

/-! ### Proved properties (Scotland) -/

/-- **Reg 14 adds nothing for an applicant on the maximum.** Where income does not
exceed the applicable amount, reg 13 gives the whole day's tax less the deductions,
and reg 14's band-rise share less the same deductions never exceeds it. -/
theorem scotBandsEH_le_main (b ct nd A T : Nat) (x : Int) (hx : x ≤ 0) :
    scotBandsEH b ct nd A T x ≤ suPerCu * ctrWaYear ct nd x := by
  unfold scotBandsEH ctrWaYear scotBandShare suPerCu cu
  have h0 : max 0 x = 0 := by omega
  rw [h0]
  split
  · split <;> omega
  · split <;> (try split) <;> (try split) <;> (try split) <;> omega

/-- **Reg 14 is a floor for incomes up to the threshold.** In bands E to H, an
applicant whose income does not exceed £321 or £479 a week (and the applicable
amount `A`) keeps at least the band-rise share of the bill less the deductions,
however far income is above the applicable amount. -/
theorem scotBandsEH_floor (b ct nd A T : Nat) (x : Int) (hb : 4 ≤ b ∧ b ≤ 7)
    (hx : x + 52_000_000 * ((A : Int) - T) ≤ 0) :
    scotBandsEH b ct nd A T x
      = max 0 (cu * ct * scotBandShare b - suPerCu * (365 * 52_000_000 * (nd : Int))) := by
  have hs : scotBandShare b ≠ 0 := by unfold scotBandShare; split <;> (try split) <;> (try split) <;> (try split) <;> omega
  unfold scotBandsEH
  simp only [hs, ↓reduceIte]
  have h0 : max 0 (x + 52_000_000 * ((A : Int) - T)) = 0 := Int.max_eq_left hx
  rw [h0, Int.mul_zero, Int.add_zero]

/-- The entitlement is at least each of its parts and at most the bill. -/
theorem scotTotal_bounds (main sar bands : Int) (ct : Nat) (hm : main ≤ cu * ct) (hs : sar ≤ cu * ct)
    (hb : bands ≤ suPerCu * (cu * ct)) :
    suPerCu * main ≤ scotTotal true main sar bands ∧ bands ≤ scotTotal true main sar bands ∧
      scotTotal true main sar bands ≤ suPerCu * (cu * ct) := by
  unfold scotTotal suPerCu at *
  simp only [↓reduceIte]
  omega

/-- **The capital cliff.** One penny of capital above £16,000 ends the whole Scottish
reduction (reg 66): the main reduction, the second adult rebate and reg 14. -/
theorem scot_capital_cliff (main sar bands : Int) : scotTotal false main sar bands = 0 := by
  unfold scotTotal; rfl

end UkTax
