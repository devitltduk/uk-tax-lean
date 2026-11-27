import UkTax.CouncilTax
import UkTax.HousingBenefitWa
import UkTax.CarerUc

/-!
# Council Tax Reduction for working-age applicants: Wales (P7b)

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
def walesUcExcess (c : Claims) (e : Int) : Int :=
  100 * (e + 10_000 * (c.partnerEarned : Int)) + 12 * (micro * ((c.tariff + c.unearnedMonthly : Nat) : Int))
    + micro * (c.carersAllowanceYear : Int) + ucAward c e - 12 * (c.maxMicro + c.childcareMicro e)

/-- Wales, on UC: the year's reduction, `cu`. -/
def ctrWalesUc (ct nd : Nat) (c : Claims) (e : Int) : Int := ctrWaYear ct nd (walesUcExcess c e)

/-! ## Proved properties -/

/-- **On UC, the Welsh reduction depends on earnings alone.** While UC is in payment
and the benefit cap does not apply, the year's excess income is the household's
earned income less 55 % of it above the work allowance: the maximum amount, unearned
income, Carer's Allowance and the childcare element cancel. -/
theorem ctrWalesUc_excess (c : Claims) (e : Int) (hcap : c.capApplies (e + 10_000 * (c.partnerEarned : Int)) = false)
    (h : 0 < ucAward c e) :
    walesUcExcess c e = 100 * (e + 10_000 * (c.partnerEarned : Int))
      - (ucTaperPercent : Int) * max 0 (e + 10_000 * (c.partnerEarned : Int) - 10_000 * 12 * (c.workAllowance : Int)) := by
  unfold walesUcExcess
  unfold ucAward at *
  simp only [hcap, Bool.false_eq_true, ↓reduceIte] at *
  split at h
  · rename_i hu
    simp only [hu, ↓reduceIte]
    generalize c.childcareMicro e = X at *
    generalize c.maxMicro = M at *
    generalize micro * ((c.tariff + c.unearnedMonthly : Nat) : Int) = T at *
    generalize (ucTaperPercent : Int) * max 0 (e + 10_000 * (c.partnerEarned : Int)
      - 10_000 * 12 * (c.workAllowance : Int)) = P at *
    omega
  · omega

/-- A reduction never exceeds the bill, and each unit of excess income costs at most
73/364 of it (20 % for 365/7 weeks). -/
theorem ctrWaYear_bounds (ct nd : Nat) (x δ : Int) (hδ : 0 ≤ δ) :
    ctrWaYear ct nd x ≤ cu * ct ∧ ctrWaYear ct nd (x + δ) ≤ ctrWaYear ct nd x ∧
      ctrWaYear ct nd x ≤ ctrWaYear ct nd (x + δ) + 73 * δ := by
  unfold ctrWaYear cu
  refine ⟨by omega, by omega, by omega⟩

end UkTax
