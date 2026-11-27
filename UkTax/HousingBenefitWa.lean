import UkTax.HousingBenefit
import UkTax.Disability

/-!
# Housing Benefit for working-age claimants, and the legacy benefits, 2026-27 (P5c)

## Which legacy benefits are left

* **Income Support and income-based JSA** were abolished for every remaining award
  from 1 April 2026 (Welfare Reform Act 2012 (Commencement No. 35) (Abolition of
  Benefits) Order 2025, SI 2025/1148 arts 4, 5): nothing is payable in 2026-27.
* **Income-related ESA** ends on 1 July 2026 (art 3A(1)), except for an award where
  someone is appointed to act for the claimant, or was likely to be needed in the
  six months before (art 3A(2)). Not computed here (an input, as in PolicyEngine).
* **Working-age Housing Benefit** ends on 1 July 2026 (art 7(1), (3)) except in
  specified or temporary accommodation, for pensioners, and for those keeping
  income-related ESA under art 3A(2) (art 7(4)). This file models it.

## Working-age Housing Benefit (SI 2006/213)

* **Maximum Housing Benefit** (reg 70): the eligible rent less non-dependant
  deductions (reg 74, the same amounts as for pensioners: `HbClaim.maximum`).
* **Passport** (Sch 5 para 4, Sch 6 para 5): a claimant on Universal Credit, Income
  Support, income-based JSA or income-related ESA has all income and capital
  disregarded, so gets the maximum. In 2026-27 that is mostly a UC claimant in
  specified or temporary accommodation, whose rent UC does not pay.
* **Otherwise** income (reg 27, weekly): net earnings from pay (reg 36(3): gross
  pay less income tax, primary Class 1 and half the pension contributions, as for
  Carer's Allowance, `caEarnings`, a week being 1/52 of the year), less the Sch 4
  disregard (£25 lone parent, £20 for disability, carer or listed employments,
  £10 couple, £5 single; and the £17.10 additional disregard of para 17 where its
  conditions are met), not below nil; other income in full (an input: contributory
  benefits, Carer's Allowance; Child Benefit is disregarded, Sch 5 para 65); and
  tariff income of £1 for each £250 or part above £6,000 (reg 52(1), (6)). No
  Housing Benefit with capital above £16,000 (reg 43).
* **Applicable amount** (reg 22, Sch 3): the personal allowance, £87.88 for each
  child (every child: the two-child limit of reg 22(1)(b) was removed from 6 April
  2026 by SI 2026/316 reg 2(2)), the protected family premium, the disability, enhanced disability, severe
  disability, disabled child and carer premiums and the ESA components, as inputs.
* **Award** (SSCBA 1992 s130(3); reg 71): the maximum less 65 % of income above
  the applicable amount, not below nil.

From 5 October 2026 an earner in specified or temporary accommodation has a
further disregard (Sch 4 para 18, SI 2026/753 as substituted by SI 2026/978):
£77.73 a week single or lone parent aged 25 or over, £61.41 under 25, £119.70 a
couple with one aged 25 or over, £61.53 both under 25. 2026-27 runs from Monday 6
April, so the year (52 weeks, as elsewhere) is 26 weeks at each rate
(`hbWaRateBefore`, `hbWaRateAfter`, each a rate for 52 weeks). An award not saved
by art 7(4) is payable only to 30 June 2026, 86 days: `hbWaPayable`.

The £17.10 of para 17 is added only where earnings reach the other disregards
plus £17.10 (para 17(1), (3)), so it is a step: `hbWa_additional_step`.

**The benefit cap** (Part 8A): Housing Benefit is reduced by the excess of the
welfare benefits (it and the others, an input) over the relevant amount, the annual
limit (£14,753 single, £22,020 others; £16,967 and £25,323 in Greater London, reg
75CA(2)) ÷ 52 to the penny (reg 75CA(1)), leaving at least 50p a week (regs 75D,
75). In specified accommodation (reg 75H) Housing Benefit counts as nil (reg
75C(2)(a)), so only other benefits can bring the cap into play; temporary
accommodation has no such rule. Exemptions by benefit (reg 75F) are an input; the
working tax credit exemption (reg 75E(2)) cannot arise in 2026-27, and the 39-week
grace period (reg 75E(3)) is not modelled.

Not modelled: self-employed earnings, childcare charges (reg 27-28), the permitted
work and other special disregards, students, and the other income rules of Sch 5.
-/

namespace UkTax

/-- Where the claimant lives. -/
inductive HbWaAccommodation where
  | general
  /-- Specified accommodation (UC Regs Sch 1 para 3A; for the cap, reg 75H). -/
  | specified
  /-- Temporary accommodation (UC Regs Sch 1 para 3B). -/
  | temporary
  deriving Repr, DecidableEq

/-- The Sch 4 earnings disregard that applies. -/
inductive HbWaDisregard where
  | single
  | couple
  /-- £20: a disability, severe disability or carer premium, or listed employments. -/
  | higher
  | loneParent
  deriving Repr, DecidableEq

def HbWaDisregard.weekly : HbWaDisregard → Nat
  | .single => pcDisregardSingle
  | .couple => pcDisregardCouple
  | .higher => pcDisregardHigher
  | .loneParent => hbDisregardLoneParent

/-- An ESA component in the applicable amount. -/
inductive EsaComponent where
  | none
  | support
  | wra
  deriving Repr, DecidableEq

/-- A working-age Housing Benefit claim. Weekly amounts in pence. -/
structure HbWaClaim where
  /-- Rent, local housing allowance and non-dependants (only those fields are used). -/
  housing : HbClaim := {}
  couple : Bool := false
  lone : Bool := false
  /-- A single claimant or lone parent under 25 (for a single claimant, not entitled
  to main phase ESA), or a couple both under 25. -/
  under25 : Bool := false
  children : Nat := 0
  familyPremium : Bool := false
  disability : Bool := false
  enhancedDisability : Bool := false
  severeDisability : Nat := 0
  enhancedDisabilityChildren : Nat := 0
  disabledChildren : Nat := 0
  carers : Nat := 0
  esa : EsaComponent := .none
  disregard : HbWaDisregard := .single
  /-- Meets a condition of Sch 4 para 17(2) for the £17.10 additional disregard. -/
  additionalDisregard : Bool := false
  /-- On Universal Credit, Income Support, income-based JSA or income-related ESA. -/
  passported : Bool := false
  /-- Other income counted in full, pence a week. -/
  otherWeekly : Nat := 0
  capital : Nat := 0
  /-- Specified or temporary accommodation keeps the award past 1 July 2026 (art
  7(4)(a)) and from 5 October 2026 gives an earner the Sch 4 para 18 disregard. -/
  accommodation : HbWaAccommodation := .specified
  /-- Benefit cap: exempt by a benefit in reg 75F (PIP, DLA, AA, the ESA support
  component, ...). -/
  capExempt : Bool := false
  london : Bool := false
  /-- Benefit cap: the other welfare benefits, pence a week (Child Benefit, ...). -/
  capOtherWeekly : Nat := 0
  /-- An income-related ESA award saved by art 3A(2), which saves this award too
  (art 7(4)(b)). -/
  esaSaved : Bool := false
  deriving Repr

/-- The applicable amount, pence a week (reg 22, Sch 3). -/
def HbWaClaim.applicable (h : HbWaClaim) : Nat :=
  (if h.couple then hbWaCouple else if h.lone then hbWaLoneParent
   else if h.under25 then hbWaSingleU25 else hbWaSingle25)
    + h.children * hbChild + (if h.familyPremium && h.children > 0 then hbFamilyPremium else 0)
    + (if h.disability then (if h.couple then hbWaDisabilityCouple else hbWaDisabilitySingle) else 0)
    + (if h.enhancedDisability then (if h.couple then hbWaEnhancedCouple else hbWaEnhancedSingle) else 0)
    + h.severeDisability * hbSevereDisability + h.enhancedDisabilityChildren * hbEnhancedDisabilityChild
    + h.disabledChildren * hbDisabledChild + h.carers * hbCarer
    + (match h.esa with
       | .none => 0
       | .support => hbWaSupportComponent
       | .wra => hbWaWraComponent)

/-- Specified or temporary accommodation. -/
def HbWaClaim.specifiedOrTemporary (h : HbWaClaim) : Bool := h.accommodation ≠ .general

/-- The benefit cap's relevant amount, pence a week (reg 75CA): the annual limit ÷
52, half a penny or more rounded up. -/
def HbWaClaim.capWeekly (h : HbWaClaim) : Nat :=
  let annual := if h.couple || h.lone || h.children > 0 then (if h.london then capLondonFamily else capFamily)
    else (if h.london then capLondonSingle else capSingle)
  (annual + 26) / 52

/-- The Sch 4 para 18 disregard, pence a week, for an earner in specified or
temporary accommodation from 5 October 2026. -/
def HbWaClaim.specifiedDisregard (h : HbWaClaim) : Nat :=
  if h.couple then (if h.under25 then hbWaSpecifiedCoupleU25 else hbWaSpecifiedCouple25)
  else (if h.under25 then hbWaSpecifiedSingleU25 else hbWaSpecifiedSingle25)

/-- Tariff income, pence a week (reg 52(1), (6)): £1 for each £250 or part above
£6,000. -/
def hbWaTariff (capital : Nat) : Nat :=
  100 * ((capital - hbWaCapitalLower + hbWaCapitalStep - 1) / hbWaCapitalStep)

/-- Earnings after the Sch 4 disregards for a year (52 weeks) at the rate of the
period, 1/10 000 pence, on net earnings `E` (1/10 000 pence a year): the disregard
`S` a week (paras 3-10A, and 18 from October) up to the earnings, and the £17.10 of
para 17 where its conditions are met and earnings reach `S` + £17.10 (para
17(1), (3)). -/
def hbWaEarningsAfter (add : Bool) (S : Nat) (E : Int) : Int :=
  if add && decide (10_000 * 52 * ((S + hbWaAdditionalDisregard : Nat) : Int) ≤ E) then
    E - 10_000 * 52 * ((S + hbWaAdditionalDisregard : Nat) : Int)
  else max 0 (E - 10_000 * 52 * (S : Int))

/-- Housing Benefit at the rate for 52 weeks, 1/1 000 000 pence, with weekly
earnings disregard `S` (pence), on a year's net earnings `E` (1/10 000 pence): the
maximum if passported; nil with capital over £16,000; otherwise the maximum less
65 % of income above the applicable amount. -/
def hbWaRateUncapped (h : HbWaClaim) (S : Nat) (E : Int) : Int :=
  if h.passported then 1_000_000 * 52 * (h.housing.maximum : Int)
  else if h.capital > hbCapitalLimit then 0
  else max 0 (1_000_000 * 52 * (h.housing.maximum : Int)
    - 65 * max 0 (hbWaEarningsAfter h.additionalDisregard S E
        + 10_000 * 52 * ((h.otherWeekly + hbWaTariff h.capital : Nat) : Int)
        - 10_000 * 52 * (h.applicable : Int)))

/-- The benefit cap (regs 75C, 75D), on a 52-week award `A` (1/1 000 000 pence):
the reduction is the excess of the welfare benefits (the award, or nil in specified
accommodation, plus the others) over the relevant amount, at most the award less
50p a week. -/
def hbWaCap (h : HbWaClaim) (A : Int) : Int :=
  if h.capExempt then A
  else
    let counted := if h.accommodation = .specified then 0 else A
    let excess := max 0 (counted + 1_000_000 * 52 * (h.capOtherWeekly : Int) - 1_000_000 * 52 * (h.capWeekly : Int))
    A - min excess (max 0 (A - 1_000_000 * 52 * 50))

/-- Housing Benefit at the rate for 52 weeks after the benefit cap. -/
def hbWaRate (h : HbWaClaim) (S : Nat) (E : Int) : Int := hbWaCap h (hbWaRateUncapped h S E)

/-- The rate to 4 October 2026 (the first 26 weeks from Monday 6 April). -/
def hbWaRateBefore (h : HbWaClaim) (E : Int) : Int := hbWaRate h h.disregard.weekly E

/-- The rate from 5 October 2026: with the para 18 disregard for an earner in
specified or temporary accommodation. -/
def hbWaRateAfter (h : HbWaClaim) (E : Int) : Int :=
  hbWaRate h (h.disregard.weekly + if h.specifiedOrTemporary && decide (0 < E) then h.specifiedDisregard else 0) E

/-- Housing Benefit payable in 2026-27, in units of 1/728 000 000 of a penny: 26
weeks at each rate where the award continues all year (art 7(4)), else the 86 days
from 6 April to 30 June 2026 at the first rate (86/364 of a 52-week rate). -/
def hbWaPayable (h : HbWaClaim) (E : Int) : Int :=
  if h.specifiedOrTemporary || h.esaSaved then 364 * (hbWaRateBefore h E + hbWaRateAfter h E)
  else 172 * hbWaRateBefore h E

/-- Net earnings for working-age Housing Benefit from pay `g` (reg 36(3)): the
Carer's Allowance definition, gross pay less tax on the pay, primary Class 1 and
half the net pay pension contributions. 1/10 000 pence a year. -/
def hbWaEarnings (p : EarningsPeriod) (rg : Regime) (g : Nat) : Int := caEarnings p rg g

/-! ## Proved properties -/

/-- **The passport.** On UC or a legacy income-related benefit, working-age Housing
Benefit is the maximum whatever the income and capital. -/
theorem hbWa_passport (h : HbWaClaim) (S : Nat) (E : Int) (hp : h.passported = true) :
    hbWaRateUncapped h S E = 1_000_000 * 52 * (h.housing.maximum : Int) := by
  unfold hbWaRateUncapped; simp [hp]

/-- **The capital limit is a cliff.** Not passported, a penny over £16,000 loses all
Housing Benefit. -/
theorem hbWa_capital_cliff (h : HbWaClaim) (S : Nat) (E : Int) (hp : h.passported = false)
    (hc : h.capital = hbCapitalLimit + 1) : hbWaRate h S E = 0 := by
  unfold hbWaRate hbWaRateUncapped hbWaCap
  simp only [hp, hc, hbCapitalLimit, Bool.false_eq_true, ↓reduceIte]
  split <;> simp <;> omega

/-- **The £17.10 additional disregard is a step.** Where its conditions are met, the
penny of earnings that reaches the disregards plus £17.10 lowers the income counted
by £17.10 a week less that penny: Housing Benefit rises there. -/
theorem hbWa_additional_step (S : Nat) (E : Int) (hE : E = 10_000 * 52 * ((S + hbWaAdditionalDisregard : Nat) : Int)) :
    hbWaEarningsAfter true S (E - 1) = 10_000 * 52 * (hbWaAdditionalDisregard : Int) - 1 ∧
      hbWaEarningsAfter true S E = 0 := by
  unfold hbWaEarningsAfter hbWaAdditionalDisregard at *
  subst hE
  constructor
  · simp only [Bool.true_and, decide_eq_true_eq]; split <;> omega
  · simp only [Bool.true_and, decide_eq_true_eq]; split <;> omega

/-- Away from that step, more net earnings never give more Housing Benefit, and each
penny of earnings takes at most 65p of it: income plus Housing Benefit keeps at
least 35 %. -/
theorem hbWa_earnings_gain (h : HbWaClaim) (S : Nat) {E E' : Int} (hE : E ≤ E')
    (hstep : h.additionalDisregard = false) :
    hbWaRateUncapped h S E' ≤ hbWaRateUncapped h S E ∧
      100 * E + hbWaRateUncapped h S E + 35 * (E' - E) ≤ 100 * E' + hbWaRateUncapped h S E' := by
  unfold hbWaRateUncapped hbWaEarningsAfter
  simp only [hstep, Bool.false_and, Bool.false_eq_true, ↓reduceIte]
  split
  · omega
  · split
    · omega
    · generalize (1_000_000 * 52 * (h.housing.maximum : Int)) = M
      generalize 10_000 * 52 * ((h.otherWeekly + hbWaTariff h.capital : Nat) : Int) = O
      generalize 10_000 * 52 * (h.applicable : Int) = A
      generalize 10_000 * 52 * (S : Int) = D
      constructor <;> omega

/-- **The cap never raises Housing Benefit**, and never takes it below the lesser of
the award and 50p a week. -/
theorem hbWa_cap_bounds (h : HbWaClaim) (A : Int) :
    hbWaCap h A ≤ A ∧ min A (1_000_000 * 52 * 50) ≤ hbWaCap h A := by
  unfold hbWaCap
  split
  · omega
  · dsimp only; split <;> omega

/-- **Specified accommodation is outside the cap for Housing Benefit itself** (reg
75C(2)(a)): unless the other welfare benefits alone exceed the relevant amount, the
cap takes nothing. -/
theorem hbWa_cap_specified (h : HbWaClaim) (A : Int) (hs : h.accommodation = .specified)
    (ho : h.capOtherWeekly ≤ h.capWeekly) : hbWaCap h A = A := by
  unfold hbWaCap
  simp only [hs, ↓reduceIte]
  split
  · rfl
  · have : (h.capOtherWeekly : Int) ≤ h.capWeekly := by exact_mod_cast ho
    omega

/-- **The 1 July 2026 abolition.** An award not saved by art 7(4) pays 86 / 364 of a
year at the April rate in 2026-27. -/
theorem hbWa_abolition (h : HbWaClaim) (E : Int) (hs : h.accommodation = .general)
    (he : h.esaSaved = false) : hbWaPayable h E = 172 * hbWaRateBefore h E := by
  unfold hbWaPayable HbWaClaim.specifiedOrTemporary; simp [hs, he]

end UkTax
