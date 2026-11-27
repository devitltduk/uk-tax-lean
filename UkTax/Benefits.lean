import UkTax.Cliffs

/-!
# Universal Credit, Tax-Free Childcare and the funded hours, 2026-27

## Universal Credit (minimal)

Standard allowance, child element (children born on or after 6 April 2017; no
two-child limit from April 2026), higher work allowance when responsible for a
child, and the 55 % taper on earned income. Earned income is pay less the income
tax and employee NICs on it (SI 2013/376 reg 55(5)). Not modelled: housing,
childcare, disability and carer elements, capital and unearned income, the
benefit cap, the first-child rate for children born before 6 April 2017, the
minimum income floor, under-25 rates, and rounding to the penny each month
(reg 6). Pay is taken as equal every month, so a year's award is twelve times
the monthly one:

    UC = max(0, 12 × maximum amount − 55 % × max(0, earned income − 12 × work allowance)).

Only pay with no savings or dividends is meaningful here (the binary refuses
the combination), since earned income for UC counts only the tax on pay.

## Tax-Free Childcare and funded hours

A parent is eligible when they, and their partner if they have one, each expect
to earn at least the minimum (16 hours a week at the National Living Wage) and
each have adjusted net income not over £100,000. The partner's pay and income are
fixed while the parent's pay varies. Tax-Free Childcare adds 20 % of each child's
childcare costs, up to £2,000 a child a year; it cannot be had together with
Universal Credit, so the household takes whichever of the two is worth more.

The funded hours (England only) are in kind, valued at DfE's 2026-27 national
average hourly funding rate for the child's age band, or at a price per hour given
for the child, over 38 weeks:

* a 3 or 4-year-old gets the universal 15 hours whatever the parents earn, and
  15 more working-parent hours when eligible;
* a child from 9 months to 2, or a 2-year-old, gets 30 working-parent hours when
  eligible, and none otherwise (the 15 hours for disadvantaged 2-year-olds,
  which depend on benefits, are not modelled).

So going over £100,000 loses only the working-parent hours; the universal hours
stay (`fundedHours_over_limit`, `fundedHours_drop_at_limit`). Reaching the minimum
earnings gains them, so it is a rise in net income, not a drop.

All amounts here are in 1/1 000 000 of a penny, so the 55 % taper and the 20 %
top-up stay exact.
-/

namespace UkTax

/-- A child's age band for the funded hours. -/
inductive AgeBand where
  /-- 9 months to 2: working-parent hours only. -/
  | under2
  /-- 2 years old: working-parent hours only. -/
  | two
  /-- 3 or 4, until the child starts school: universal hours, plus the
  working-parent extension. -/
  | threeFour
  deriving DecidableEq, Repr

/-- DfE 2026-27 national average hourly funding rate for the band, pence. -/
def AgeBand.rate : AgeBand → Nat
  | .under2 => eyRateUnder2
  | .two => eyRate2
  | .threeFour => eyRate34

/-- Universal hours a week, whatever the parents earn. -/
def AgeBand.universalHours : AgeBand → Nat
  | .threeFour => universalHoursWeekly
  | _ => 0

/-- Working-parent hours a week, on top of the universal hours. -/
def AgeBand.workingHours (b : AgeBand) : Nat := workingParentHoursWeekly - b.universalHours

/-- A child for the funded hours: age band and, optionally, a local price per
hour in pence to value the hours at instead of the DfE rate. -/
structure FundedChild where
  band : AgeBand
  price : Option Nat := none

/-- The price each funded hour is valued at, pence. -/
def FundedChild.hourly (ch : FundedChild) : Nat := ch.price.getD ch.band.rate

/-- Yearly value of the universal hours, pence. -/
def FundedChild.universalValue (ch : FundedChild) : Nat :=
  ch.hourly * ch.band.universalHours * fundedWeeks

/-- Yearly value of the working-parent hours (beyond the universal ones), pence. -/
def FundedChild.workingValue (ch : FundedChild) : Nat :=
  ch.hourly * ch.band.workingHours * fundedWeeks

/-- The LCWRA (health) element: none, the rate for a claimant who first has it
from 6 April 2026, or the protected rate (reg 27A, Sch 5A, reg 40A, terminal
illness). For joint claimants, the higher of the two (reg 27(4)(b)). -/
inductive Health where
  | none
  | newClaim
  | protectedRate
  deriving DecidableEq, Repr

/-- Housing costs for the UC housing costs element (rent only; Sch 4). -/
structure Housing where
  /-- Monthly rent (core rent and eligible service charges), pence. -/
  rent : Nat := 0
  /-- Private renter: the local housing allowance for the size of home the
  claimant is allowed (Sch 4 para 25; the rate is an input), monthly pence. -/
  lha : Option Nat := none
  /-- Social renter: bedrooms more than the size criteria allow (Sch 4 paras 8-12),
  for the under-occupancy deduction (para 36). -/
  spareRooms : Nat := 0
  /-- Non-dependants for whom a housing cost contribution is deducted (Sch 4
  paras 13-16; the exemptions are for the caller to apply). -/
  nonDeps : Nat := 0
  deriving Repr

/-- A household's benefit claims. -/
structure Claims where
  /-- Claims Universal Credit. -/
  uc : Bool := false
  /-- A couple (joint claim) rather than a single claimant. -/
  couple : Bool := false
  /-- Children for the UC child element. -/
  ucChildren : Nat := 0
  /-- Yearly childcare costs for each child, in pence, for Tax-Free Childcare. -/
  childcareCosts : List Nat := []
  /-- A partner whose own pay and adjusted net income (pence, fixed) must also pass
  the childcare tests. A UC couple (`couple`) has a partner with no pay. -/
  partner : Option (Nat × Nat) := none
  /-- Lives in England, where the funded hours are (Tax-Free Childcare is UK-wide). -/
  england : Bool := true
  /-- Children of the ages that get funded hours. -/
  fundedChildren : List FundedChild := []
  /-- UC: the single claimant, or both joint claimants, under 25 (reg 36). -/
  under25 : Bool := false
  /-- UC: responsible for a child born before 6 April 2017, so the first child
  element is at the higher rate. -/
  firstChildPre2017 : Bool := false
  /-- UC: children with the lower and the higher disabled child addition. -/
  disabledLower : Nat := 0
  disabledHigher : Nat := 0
  /-- UC: the LCWRA element. -/
  health : Health := .none
  /-- UC: claimants with regular and substantial caring responsibilities for a
  severely disabled person (0 to 2). A single claimant with the LCWRA element
  gets only the LCWRA element (reg 29(4)); for joint claimants, count only those
  who do not have it. -/
  carers : Nat := 0
  /-- UC childcare work condition (reg 32(1)(b)): the claimant, and the partner,
  is unable to provide childcare (limited capability for work, caring for a
  severely disabled person, or temporarily absent), so need not be in paid work. -/
  cannotCare : Bool := false
  partnerCannotCare : Bool := false
  /-- UC: monthly relevant childcare costs, pence, and the number of children they
  are for (the cap is for one child, or two or more). -/
  ucChildcareMonthly : Nat := 0
  ucChildcareChildren : Nat := 0
  /-- UC: rent and the housing costs element. -/
  housing : Housing := {}
  /-- UC: capital, pence (reg 18, reg 72). -/
  capital : Nat := 0
  /-- UC: monthly unearned income, pence (reg 66; deducted in full). -/
  unearnedMonthly : Nat := 0
  /-- UC: Carer's Allowance for the year, pence, unearned income deducted in full
  (reg 66(1)(b)(iii)). Weekly payments count as 52/12 of a week a month
  (reg 73(2)(a)), so twelve months of it are the 52 weeks' allowance exactly. -/
  carersAllowanceYear : Nat := 0
  /-- UC: the partner's earned income for the year, pence, net of their income tax
  and NICs (reg 55(5)); fixed while the claimant's pay varies. -/
  partnerEarned : Nat := 0
  /-- UC benefit cap: lives in Greater London. -/
  london : Bool := false
  /-- UC benefit cap: exempt by receipt of a benefit in reg 83 other than the
  LCWRA and carer elements (PIP, DLA, attendance allowance, industrial injuries,
  war pension, ...). -/
  capExempt : Bool := false
  /-- UC benefit cap: other welfare benefits for the year, pence (reg 79; Child
  Benefit is the main one). -/
  capOtherBenefits : Nat := 0

/-- 1/1 000 000 of a penny per penny. -/
def micro : Int := 1_000_000

/-- Earned income for Universal Credit, in 1/10 000 pence: pay less income tax
and employee NICs. -/
def earned (p : EarningsPeriod) (rg : Regime) (s d g : Nat) : Int :=
  10_000 * (g : Int) - (finalTaxExact rg ⟨g, s, d⟩ : Int) - (nicExact p (g + rg.netPay) : Int)

/-- Child element, monthly pence (reg 24(1), 36): the first child at the higher
rate where the claimant is responsible for a child born before 6 April 2017. No
two-child limit from 6 April 2026. -/
def Claims.childElements (c : Claims) : Nat :=
  if c.firstChildPre2017 && c.ucChildren > 0 then
    ucChildElementFirst + (c.ucChildren - 1) * ucChildElement
  else c.ucChildren * ucChildElement

/-- Standard allowance, monthly pence (reg 36). -/
def Claims.standardAllowance (c : Claims) : Nat :=
  match c.couple, c.under25 with
  | true, true => ucStandardJointU25
  | true, false => ucStandardJoint25
  | false, true => ucStandardSingleU25
  | false, false => ucStandardSingle25

/-- LCWRA element, monthly pence. -/
def Claims.healthElement (c : Claims) : Nat :=
  match c.health with
  | .none => 0
  | .newClaim => ucLcwraNew
  | .protectedRate => ucLcwraProtected

/-- Housing costs element, in 1/1 000 000 pence a month: rent, capped at the local
housing allowance for a private renter, or less 14 % / 25 % for under-occupation
in the social sector, less the housing cost contributions, not below nil. -/
def Claims.housingMicro (c : Claims) : Int :=
  let h := c.housing
  let rent : Int := match h.lha with
    | some l => micro * (min h.rent l : Nat)
    | none =>
      micro * h.rent
        - (if h.spareRooms = 0 then 0
           else if h.spareRooms = 1 then micro / 100 * ucUnderOccOne * h.rent
           else micro / 100 * ucUnderOccTwo * h.rent)
  max 0 (rent - micro * (h.nonDeps * ucNonDepDeduction : Nat))

/-- The award includes a housing costs element (for the lower work allowance). -/
def Claims.hasHousing (c : Claims) : Bool := c.housing.rent > 0

/-- The childcare work condition (reg 32): a single claimant in paid work (taken as
having earned income); for a couple, one in paid work and the other in paid work
or unable to provide childcare. -/
def Claims.childcareWork (c : Claims) (e : Int) : Bool :=
  c.ucChildcareChildren > 0 && (decide (0 < e) || decide (0 < c.partnerEarned) && c.couple)
    && (decide (0 < e) || c.cannotCare && c.couple)
    && (!c.couple || decide (0 < c.partnerEarned) || c.partnerCannotCare)

/-- 85 % of the monthly childcare costs, up to the cap, in 1/1 000 000 pence. -/
def Claims.childcareFull (c : Claims) : Nat :=
  min (10_000 * ucChildcarePercent * c.ucChildcareMonthly)
    (1_000_000 * (if c.ucChildcareChildren = 1 then ucChildcareMaxOne else ucChildcareMaxTwo))

/-- Childcare costs element, 1/1 000 000 pence a month, if the work condition is
met. -/
def Claims.childcareMicro (c : Claims) (e : Int) : Int :=
  if c.childcareWork e then (c.childcareFull : Int) else 0

/-- Carer elements (reg 29): a single claimant with the LCWRA element has only that
(reg 29(4)). -/
def Claims.carerCount (c : Claims) : Nat :=
  if !c.couple && c.health ≠ .none then 0 else c.carers

/-- Maximum amount except the childcare element, monthly, 1/1 000 000 pence. -/
def Claims.maxMicro (c : Claims) : Int :=
  micro * (c.standardAllowance + c.childElements + c.disabledLower * ucDisabledChildLower
      + c.disabledHigher * ucDisabledChildHigher + c.healthElement + c.carerCount * ucCarerElement : Nat)
    + c.housingMicro

/-- Work allowance, monthly pence (reg 22): for a claimant responsible for a child
or with limited capability for work, the lower amount if the award has a housing
costs element, the higher if not; otherwise none. -/
def Claims.workAllowance (c : Claims) : Nat :=
  if c.ucChildren > 0 || c.health ≠ .none then
    if c.hasHousing then ucWorkAllowanceLower else ucWorkAllowanceHigher
  else 0

/-- Tariff income from capital, monthly pence (reg 72): £4.35 for each £250 or part
above £6,000. -/
def Claims.tariff (c : Claims) : Nat :=
  ucTariffPerStep * ((c.capital - ucCapitalLower + ucTariffStep - 1) / ucTariffStep)

/-- The benefit cap's relevant amount for the year, pence (reg 80A). -/
def Claims.capAmount (c : Claims) : Nat :=
  if c.couple || c.ucChildren > 0 then (if c.london then capLondonFamily else capFamily)
  else (if c.london then capLondonSingle else capSingle)

/-- Whether the benefit cap can apply, given the household's earned income `e` for
the year (1/10 000 pence): no LCWRA or carer element, no other reg 83 exemption,
and earned income below 16 hours at the National Living Wage (reg 82(1)(a); the
grace period of reg 82(1)(b) is not modelled). -/
def Claims.capApplies (c : Claims) (e : Int) : Bool :=
  c.health = .none && c.carers = 0 && !c.capExempt
    && decide (e < 10_000 * 12 * (capEarningsMonthly : Int))

/-- Universal Credit for the year, in 1/1 000 000 pence, on the claimant's earned
income `e` (1/10 000 pence a year; the partner's is added):

    award = max(0, 12 × (maximum amount + childcare element − tariff income − unearned income)
                   − 55 % × max(0, earned income − 12 × work allowance)),

nil with capital over £16,000 (reg 18), then reduced by the benefit cap: by the
excess of the award and the other welfare benefits over the relevant amount, less
the childcare element (reg 81), so at most `relevant amount + childcare element −
other benefits`, not below nil. Months are taken as equal; rounding to the penny
each assessment period (reg 6) is not modelled. -/
def ucAward (c : Claims) (e : Int) : Int :=
  if c.uc && c.capital ≤ ucCapitalUpper then
    let eh := e + 10_000 * (c.partnerEarned : Int)
    let cc := 12 * c.childcareMicro e
    let award := max 0 (12 * (c.maxMicro - micro * (c.tariff + c.unearnedMonthly : Nat))
      - micro * (c.carersAllowanceYear : Int) + cc
      - (ucTaperPercent : Int) * max 0 (eh - 10_000 * 12 * (c.workAllowance : Int)))
    if c.capApplies eh then
      max 0 (min award (micro * (c.capAmount : Int) + cc - micro * (c.capOtherBenefits : Int)))
    else award
  else 0

/-- One parent's part of the childcare tests: minimum earnings and the £100,000
limit. -/
def parentTest (pay ani : Nat) : Bool :=
  childcareMinimumEarnings ≤ pay && ani ≤ childcareIncomeLimit

/-- The partner's part, fixed while the parent's pay varies: passes for a lone
parent, fails for a UC couple's partner (no pay) unless given. -/
def Claims.partnerOk (c : Claims) : Bool :=
  match c.partner with
  | some (pay, ani) => parentTest pay ani
  | none => !c.couple

/-- Eligible for Tax-Free Childcare and the working-parent funded hours. -/
def childcareEligible (c : Claims) (pay ani : Nat) : Bool :=
  parentTest pay ani && c.partnerOk

/-- Tax-Free Childcare top-up for the year, in 1/1 000 000 pence. -/
def tfcTopUp (c : Claims) (pay ani : Nat) : Int :=
  if childcareEligible c pay ani then
    ((c.childcareCosts.map fun cost => min (1_000_000 * tfcCapPerChild) (1_000_000 * cost / 5)).sum
      : Nat)
  else 0

/-- Yearly value of the universal hours, pence (England only). -/
def universalValue (c : Claims) : Nat :=
  if c.england then (c.fundedChildren.map FundedChild.universalValue).sum else 0

/-- Yearly value of the working-parent hours, pence, if eligible (England only). -/
def workingValue (c : Claims) : Nat :=
  if c.england then (c.fundedChildren.map FundedChild.workingValue).sum else 0

/-- Funded hours, as their yearly value, in 1/1 000 000 pence: the universal hours
always, the working-parent hours when eligible. -/
def fundedHours (c : Claims) (pay ani : Nat) : Int :=
  micro * universalValue c + if childcareEligible c pay ani then micro * workingValue c else 0

/-- Net income with benefits, in 1/1 000 000 pence: `net` (gross less income tax,
NICs and HICBC, plus Child Benefit), plus the better of Universal Credit and
Tax-Free Childcare, plus the funded hours. -/
def netAll (p : EarningsPeriod) (cb : Nat) (rg : Regime) (c : Claims) (s d g : Nat) : Int :=
  100 * net p cb rg s d g
    + max (ucAward c (earned p rg s d g)) (tfcTopUp c g (g + s + d - rg.step2 - rg.relief))
    + fundedHours c g (g + s + d - rg.step2 - rg.relief)

/-! ## Proved properties -/

/-- The childcare element is never negative and never falls as earned income
rises (the work condition, once met, stays met). -/
theorem childcareMicro_mono (c : Claims) {e e' : Int} (h : e ≤ e') :
    0 ≤ c.childcareMicro e ∧ c.childcareMicro e ≤ c.childcareMicro e' := by
  have hw : c.childcareWork e = true → c.childcareWork e' = true := by
    unfold Claims.childcareWork
    simp only [Bool.and_eq_true, Bool.or_eq_true, decide_eq_true_eq]
    intro h1
    refine ⟨⟨⟨h1.1.1.1, ?_⟩, ?_⟩, h1.2⟩
    · rcases h1.1.1.2 with h2 | h2
      · exact Or.inl (by omega)
      · exact Or.inr h2
    · rcases h1.1.2 with h2 | h2
      · exact Or.inl (by omega)
      · exact Or.inr h2
  unfold Claims.childcareMicro
  constructor
  · split <;> omega
  · by_cases h1 : c.childcareWork e = true
    · simp only [h1, hw h1, ↓reduceIte]; exact Int.le_refl _
    · simp only [Bool.not_eq_true] at h1
      simp only [h1, Bool.false_eq_true, ↓reduceIte]
      split <;> omega

/-- The benefit cap's earnings exception, once met, stays met. -/
theorem capApplies_anti (c : Claims) {e e' : Int} (h : e ≤ e') (h' : c.capApplies e' = true) :
    c.capApplies e = true := by
  unfold Claims.capApplies at *
  simp only [Bool.and_eq_true, decide_eq_true_eq] at *
  exact ⟨h'.1, by omega⟩

/-- With the taper at 55 %, earned income plus UC keeps at least 45 % of any rise in
earned income: the childcare element and the lifting of the benefit cap only add. -/
theorem earned_plus_uc_gain (c : Claims) {e e' : Int} (h : e ≤ e') :
    100 * e + ucAward c e + 45 * (e' - e) ≤ 100 * e' + ucAward c e' := by
  have hcc := childcareMicro_mono c h
  have hcap := capApplies_anti c (e := e + 10_000 * (c.partnerEarned : Int))
    (e' := e' + 10_000 * (c.partnerEarned : Int)) (by omega)
  unfold ucAward ucTaperPercent
  split
  · dsimp only
    generalize c.childcareMicro e = X at *
    generalize c.childcareMicro e' = X' at *
    generalize c.capApplies (e + 10_000 * (c.partnerEarned : Int)) = a at *
    generalize c.capApplies (e' + 10_000 * (c.partnerEarned : Int)) = a' at *
    generalize c.maxMicro = M
    generalize (c.workAllowance : Int) = W
    generalize micro * (c.capAmount : Int) = K
    generalize micro * (c.capOtherBenefits : Int) = O
    generalize micro * ((c.tariff + c.unearnedMonthly : Nat) : Int) = T
    generalize micro * (c.carersAllowanceYear : Int) = A
    generalize (c.partnerEarned : Int) = P
    cases a <;> cases a'
    · simp only [Bool.false_eq_true, ↓reduceIte]; omega
    · simp at hcap
    · simp only [Bool.false_eq_true, ↓reduceIte]; omega
    · simp only [↓reduceIte]; omega
  · omega

/-- Earned income and Universal Credit together never fall as earned income rises:
the taper takes 55 %, not more. -/
theorem earned_plus_uc_mono (c : Claims) {e e' : Int} (h : e ≤ e') :
    100 * e + ucAward c e ≤ 100 * e' + ucAward c e' := by
  have := earned_plus_uc_gain c h
  omega

/-- Eligibility is only lost where adjusted net income goes over £100,000. -/
theorem childcareEligible_succ {c : Claims} {pay ani : Nat}
    (h : childcareEligible c pay ani = true) :
    childcareEligible c (pay + 1) (ani + 1) = true ∨ ani = childcareIncomeLimit := by
  by_cases hx : ani = childcareIncomeLimit
  · exact Or.inr hx
  · left
    unfold childcareEligible parentTest at *
    simp only [Bool.and_eq_true, decide_eq_true_eq] at *
    exact ⟨⟨by omega, by omega⟩, h.2⟩

/-- **The universal hours are never lost.** Over £100,000 of adjusted net income
the funded hours are worth exactly the universal hours: only the working-parent
hours go. -/
theorem fundedHours_over_limit (c : Claims) {pay ani : Nat} (h : childcareIncomeLimit < ani) :
    fundedHours c pay ani = micro * universalValue c := by
  have : childcareEligible c pay ani = false := by
    unfold childcareEligible parentTest
    have : ¬ ani ≤ childcareIncomeLimit := by omega
    simp [this]
  unfold fundedHours; rw [this]; simp

/-- **The £100,000 drop in funded hours.** For a parent eligible at exactly £100,000
of adjusted net income, the penny that takes it over loses exactly the working-parent
hours. -/
theorem fundedHours_drop_at_limit (c : Claims) {pay : Nat}
    (h : childcareEligible c pay childcareIncomeLimit = true) :
    fundedHours c pay childcareIncomeLimit
      = fundedHours c (pay + 1) (childcareIncomeLimit + 1) + micro * workingValue c := by
  rw [fundedHours_over_limit c (pay := pay + 1) (ani := childcareIncomeLimit + 1) (by omega)]
  unfold fundedHours; rw [h]; simp only [↓reduceIte]

/-- **Marginal rate between steps, with benefits.** Away from the steps, a penny more
pay raises net income with benefits by at least 45 % of `rg.minGain`: earned income
rises by at least `rg.minGain` (`taxExact_succ_le`, `nicExact_succ_le`) and UC takes
at most 55 % of that. That is 0.1053p (105,300 millionths of a penny), so an
effective marginal rate of at most 1 − 0.45 × 0.234 = 89.47 %; for a Scottish
taxpayer 0.0963p, at most 1 − 0.45 × 0.214 = 90.37 %. -/
theorem netAll_succ_ge {p : EarningsPeriod} {cb : Nat} {rg : Regime} {c : Claims} {s d g : Nat}
    (hPA : personalAllowanceFor (g + 1 + s + d - rg.step2 - rg.relief)
      = personalAllowanceFor (g + s + d - rg.step2 - rg.relief))
    (hPSA : Income.psa rg ⟨g + 1, s, d⟩ = Income.psa rg ⟨g, s, d⟩)
    (hMA : Income.maReduction rg ⟨g + 1, s, d⟩ = Income.maReduction rg ⟨g, s, d⟩)
    (hC : hicbc (g + 1 + s + d - rg.step2 - rg.relief) cb = hicbc (g + s + d - rg.step2 - rg.relief) cb)
    (hLim : g + s + d - rg.step2 - rg.relief ≠ childcareIncomeLimit) :
    netAll p cb rg c s d g + 45 * (rg.minGain : Int) ≤ netAll p cb rg c s d (g + 1) := by
  have hani : g + 1 + s + d - rg.step2 - rg.relief = (g + s + d - rg.step2 - rg.relief) + 1 ∨
      (g + 1 + s + d - rg.step2 - rg.relief = 0 ∧ g + s + d - rg.step2 - rg.relief = 0) := by omega
  have htax := finalTaxExact_succ_le hPA hPSA hMA
  have hnic := nicExact_succ_le p (g + rg.netPay)
  rw [show g + rg.netPay + 1 = g + 1 + rg.netPay by omega] at hnic
  have hmg := rg.minGain_eq
  have hearn : earned p rg s d g + rg.minGain ≤ earned p rg s d (g + 1) := by
    unfold earned
    generalize finalTaxExact rg ⟨g, s, d⟩ = A at *
    generalize finalTaxExact rg ⟨g + 1, s, d⟩ = A' at *
    generalize nicExact p (g + rg.netPay) = B at *
    generalize nicExact p (g + 1 + rg.netPay) = B' at *
    omega
  have hle : earned p rg s d g ≤ earned p rg s d (g + 1) := by
    generalize earned p rg s d g = E at *
    generalize earned p rg s d (g + 1) = E' at *
    omega
  have huc := earned_plus_uc_gain c hle
  have hEl : childcareEligible c g (g + s + d - rg.step2 - rg.relief) = true →
      childcareEligible c (g + 1) (g + 1 + s + d - rg.step2 - rg.relief) = true := by
    intro h1
    rcases hani with ha | ⟨ha, hb⟩
    · rw [ha]
      rcases childcareEligible_succ (c := c) h1 with h2 | h2
      · exact h2
      · exact absurd h2 hLim
    · rw [ha]; rw [hb] at h1
      unfold childcareEligible parentTest at *
      simp only [Bool.and_eq_true, decide_eq_true_eq] at *
      exact ⟨⟨by omega, by omega⟩, h1.2⟩
  have htfc : tfcTopUp c g (g + s + d - rg.step2 - rg.relief)
      ≤ tfcTopUp c (g + 1) (g + 1 + s + d - rg.step2 - rg.relief) := by
    unfold tfcTopUp
    by_cases h1 : childcareEligible c g (g + s + d - rg.step2 - rg.relief) = true
    · rw [h1, hEl h1]; simp
    · rw [show childcareEligible c g (g + s + d - rg.step2 - rg.relief) = false by simpa using h1]
      simp only [Bool.false_eq_true, ↓reduceIte]
      split <;> omega
  have hfh : fundedHours c g (g + s + d - rg.step2 - rg.relief)
      ≤ fundedHours c (g + 1) (g + 1 + s + d - rg.step2 - rg.relief) := by
    unfold fundedHours micro
    by_cases h1 : childcareEligible c g (g + s + d - rg.step2 - rg.relief) = true
    · rw [h1, hEl h1]; simp
    · rw [show childcareEligible c g (g + s + d - rg.step2 - rg.relief) = false by simpa using h1]
      simp only [Bool.false_eq_true, ↓reduceIte]
      split <;> omega
  have hsplit : ∀ g' : Nat, 100 * net p cb rg s d g'
      = 100 * earned p rg s d g' + 1_000_000 * ((s + d + cb : Nat) : Int)
        - 1_000_000 * (hicbc (g' + s + d - rg.step2 - rg.relief) cb : Int) := by
    intro g'; unfold net earned
    generalize finalTaxExact _ _ = A; generalize nicExact p _ = B; generalize hicbc _ cb = C
    omega
  clear hPA hPSA hEl htax hnic
  unfold netAll
  rw [hsplit, hsplit, hC]
  have : max (ucAward c (earned p rg s d g)) (tfcTopUp c g (g + s + d - rg.step2 - rg.relief))
      + 100 * earned p rg s d g + 45 * (rg.minGain : Int)
      ≤ max (ucAward c (earned p rg s d (g + 1)))
          (tfcTopUp c (g + 1) (g + 1 + s + d - rg.step2 - rg.relief))
        + 100 * earned p rg s d (g + 1) := by
    omega
  generalize hicbc (g + s + d - rg.step2 - rg.relief) cb = C at *
  omega

/-- Between steps, and away from £100,000, net income with benefits does not fall. -/
theorem netAll_between_steps {p : EarningsPeriod} {cb : Nat} {rg : Regime} {c : Claims}
    {s d g : Nat}
    (hPA : personalAllowanceFor (g + 1 + s + d - rg.step2 - rg.relief)
      = personalAllowanceFor (g + s + d - rg.step2 - rg.relief))
    (hPSA : Income.psa rg ⟨g + 1, s, d⟩ = Income.psa rg ⟨g, s, d⟩)
    (hMA : Income.maReduction rg ⟨g + 1, s, d⟩ = Income.maReduction rg ⟨g, s, d⟩)
    (hC : hicbc (g + 1 + s + d - rg.step2 - rg.relief) cb = hicbc (g + s + d - rg.step2 - rg.relief) cb)
    (hLim : g + s + d - rg.step2 - rg.relief ≠ childcareIncomeLimit)
    (h : netAll p cb rg c s d (g + 1) < netAll p cb rg c s d g) : False := by
  have := netAll_succ_ge (p := p) (c := c) hPA hPSA hMA hC hLim
  omega

/-- **Where net income with benefits can fall.** For every pay, savings,
dividends, Child Benefit, pay period, reliefs, Scottish or not, and set of claims:
if a penny more pay lowers net income including Universal Credit, Tax-Free
Childcare and funded hours, that penny is one of the steps of
`net_drop_only_at_steps`, or the one where adjusted net income goes over
£100,000. -/
theorem netAll_drop_only_at_steps (p : EarningsPeriod) (cb : Nat) (rg : Regime) (c : Claims)
    (s d g : Nat) (h : netAll p cb rg c s d (g + 1) < netAll p cb rg c s d g) :
    PaStep (g + s + d - rg.step2 - rg.relief) ∨ (0 < cb ∧ HicbcStep (g + s + d - rg.step2 - rg.relief)) ∨
      Income.step3 rg ⟨g, s, d⟩ = rg.brl ∨ Income.step3 rg ⟨g, s, d⟩ = rg.hrl ∨
      MaStep rg s d g ∨ g + s + d - rg.step2 - rg.relief = childcareIncomeLimit := by
  by_cases hLim : g + s + d - rg.step2 - rg.relief = childcareIncomeLimit
  · exact Or.inr (Or.inr (Or.inr (Or.inr (Or.inr hLim))))
  by_cases hM : MaStep rg s d g
  · exact Or.inr (Or.inr (Or.inr (Or.inr (Or.inl hM))))
  have hMA : Income.maReduction rg ⟨g + 1, s, d⟩ = Income.maReduction rg ⟨g, s, d⟩ :=
    Classical.not_not.mp hM
  have ht : g + 1 + s + d = (g + s + d) + 1 := by omega
  have hA : (personalAllowanceFor (g + 1 + s + d - rg.step2 - rg.relief)
        = personalAllowanceFor (g + s + d - rg.step2 - rg.relief) ∧
      hicbc (g + 1 + s + d - rg.step2 - rg.relief) cb = hicbc (g + s + d - rg.step2 - rg.relief) cb) ∨
      PaStep (g + s + d - rg.step2 - rg.relief) ∨ (0 < cb ∧ HicbcStep (g + s + d - rg.step2 - rg.relief)) := by
    rw [ht]
    rcases ani_succ rg (g + s + d) with ha | ⟨ha, hb⟩
    · rw [ha]
      rcases personalAllowanceFor_succ (g + s + d - rg.step2 - rg.relief) with hPA | hPA
      · rcases hicbc_succ (g + s + d - rg.step2 - rg.relief) cb with hc | hc
        · exact Or.inl ⟨hPA, hc⟩
        · by_cases hcb : cb = 0
          · left; subst hcb; unfold hicbc; simp [hPA]
          · exact Or.inr (Or.inr ⟨by omega, hc⟩)
      · exact Or.inr (Or.inl hPA)
    · left; rw [ha, hb]; exact ⟨rfl, rfl⟩
  rcases hA with ⟨hPA, hC⟩ | hA
  · rcases psa_succ hPA with hPSA | hT | hT
    · exact (netAll_between_steps hPA hPSA hMA hC hLim h).elim
    · exact Or.inr (Or.inr (Or.inl hT))
    · exact Or.inr (Or.inr (Or.inr (Or.inl hT)))
  · rcases hA with hA | hA
    · exact Or.inl hA
    · exact Or.inr (Or.inl hA)

end UkTax
