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

/-- 1/1 000 000 of a penny per penny. -/
def micro : Int := 1_000_000

/-- Earned income for Universal Credit, in 1/10 000 pence: pay less income tax
and employee NICs. -/
def earned (p : EarningsPeriod) (s d g : Nat) : Int :=
  10_000 * (g : Int) - (taxExact ⟨g, s, d⟩ : Int) - (nicExact p g : Int)

/-- Universal Credit for the year, in 1/1 000 000 pence, on earned income `e`
(in 1/10 000 pence). -/
def ucAward (c : Claims) (e : Int) : Int :=
  if c.uc then
    let maxMonthly : Int :=
      (if c.couple then ucStandardJoint25 else ucStandardSingle25) + c.ucChildren * ucChildElement
    let wa : Int := if c.ucChildren > 0 then ucWorkAllowanceHigher else 0
    max 0 (micro * 12 * maxMonthly - (ucTaperPercent : Int) * max 0 (e - 10_000 * 12 * wa))
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
def netAll (p : EarningsPeriod) (cb : Nat) (c : Claims) (s d g : Nat) : Int :=
  100 * net p cb s d g + max (ucAward c (earned p s d g)) (tfcTopUp c g (g + s + d))
    + fundedHours c g (g + s + d)

/-! ## Proved properties -/

/-- Earned income and Universal Credit together never fall as earned income rises:
the taper takes 55 %, not more. -/
theorem earned_plus_uc_mono (c : Claims) {e e' : Int} (h : e ≤ e') :
    100 * e + ucAward c e ≤ 100 * e' + ucAward c e' := by
  unfold ucAward ucTaperPercent
  split
  · dsimp only
    generalize (if c.ucChildren > 0 then (ucWorkAllowanceHigher : Int) else 0) = wa
    generalize micro * 12 * _ = m
    omega
  · omega

/-- With the taper at 55 %, earned income plus UC keeps at least 45 % of any rise in
earned income. -/
theorem earned_plus_uc_gain (c : Claims) {e e' : Int} (h : e ≤ e') :
    100 * e + ucAward c e + 45 * (e' - e) ≤ 100 * e' + ucAward c e' := by
  unfold ucAward ucTaperPercent
  split
  · dsimp only
    generalize (if c.ucChildren > 0 then (ucWorkAllowanceHigher : Int) else 0) = wa
    generalize micro * 12 * _ = m
    omega
  · omega

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
pay raises net income with benefits by at least 0.1053p (105,300 millionths of a
penny): earned income rises by at least 0.234p (`taxExact_succ_le`,
`nicExact_succ_le`) and UC takes at most 55 % of that. So the effective marginal
rate there is at most 1 − 0.45 × 0.234 = 89.47 %. -/
theorem netAll_succ_ge {p : EarningsPeriod} {cb : Nat} {c : Claims} {s d g : Nat}
    (hPA : personalAllowanceFor (g + 1 + s + d) = personalAllowanceFor (g + s + d))
    (hPSA : Income.psa ⟨g + 1, s, d⟩ = Income.psa ⟨g, s, d⟩)
    (hC : hicbc (g + 1 + s + d) cb = hicbc (g + s + d) cb)
    (hLim : g + s + d ≠ childcareIncomeLimit) :
    netAll p cb c s d g + 105_300 ≤ netAll p cb c s d (g + 1) := by
  have ht : g + 1 + s + d = (g + s + d) + 1 := by omega
  have htax := taxExact_succ_le hPA hPSA
  have hnic := nicExact_succ_le p g
  have hearn : earned p s d g + 2340 ≤ earned p s d (g + 1) := by
    unfold earned
    generalize taxExact ⟨g, s, d⟩ = A at *
    generalize taxExact ⟨g + 1, s, d⟩ = A' at *
    generalize nicExact p g = B at *
    generalize nicExact p (g + 1) = B' at *
    omega
  have hle : earned p s d g ≤ earned p s d (g + 1) := by
    generalize earned p s d g = E at *
    generalize earned p s d (g + 1) = E' at *
    omega
  have huc := earned_plus_uc_gain c hle
  have hEl : childcareEligible c g (g + s + d) = true →
      childcareEligible c (g + 1) (g + 1 + s + d) = true := by
    intro h1; rw [ht]
    rcases childcareEligible_succ (c := c) h1 with h2 | h2
    · exact h2
    · exact absurd h2 hLim
  have htfc : tfcTopUp c g (g + s + d) ≤ tfcTopUp c (g + 1) (g + 1 + s + d) := by
    unfold tfcTopUp
    by_cases h1 : childcareEligible c g (g + s + d) = true
    · rw [h1, hEl h1]; simp
    · rw [show childcareEligible c g (g + s + d) = false by simpa using h1]
      simp only [Bool.false_eq_true, ↓reduceIte]
      split <;> omega
  have hfh : fundedHours c g (g + s + d) ≤ fundedHours c (g + 1) (g + 1 + s + d) := by
    unfold fundedHours micro
    by_cases h1 : childcareEligible c g (g + s + d) = true
    · rw [h1, hEl h1]; simp
    · rw [show childcareEligible c g (g + s + d) = false by simpa using h1]
      simp only [Bool.false_eq_true, ↓reduceIte]
      split <;> omega
  have hsplit : ∀ g' : Nat, 100 * net p cb s d g'
      = 100 * earned p s d g' + 1_000_000 * ((s + d + cb : Nat) : Int)
        - 1_000_000 * (hicbc (g' + s + d) cb : Int) := by
    intro g'; unfold net earned
    generalize taxExact _ = A; generalize nicExact p g' = B; generalize hicbc _ cb = C
    omega
  clear hPA hPSA hEl htax hnic
  unfold netAll
  rw [hsplit, hsplit, hC]
  have : max (ucAward c (earned p s d g)) (tfcTopUp c g (g + s + d)) + 100 * earned p s d g
      + 105_300
      ≤ max (ucAward c (earned p s d (g + 1))) (tfcTopUp c (g + 1) (g + 1 + s + d))
        + 100 * earned p s d (g + 1) := by
    omega
  generalize hicbc (g + s + d) cb = C at *
  omega

/-- Between steps, and away from £100,000, net income with benefits does not fall. -/
theorem netAll_between_steps {p : EarningsPeriod} {cb : Nat} {c : Claims} {s d g : Nat}
    (hPA : personalAllowanceFor (g + 1 + s + d) = personalAllowanceFor (g + s + d))
    (hPSA : Income.psa ⟨g + 1, s, d⟩ = Income.psa ⟨g, s, d⟩)
    (hC : hicbc (g + 1 + s + d) cb = hicbc (g + s + d) cb)
    (hLim : g + s + d ≠ childcareIncomeLimit)
    (h : netAll p cb c s d (g + 1) < netAll p cb c s d g) : False := by
  have := netAll_succ_ge (p := p) (c := c) hPA hPSA hC hLim
  omega

/-- **Where net income with benefits can fall.** For every pay, savings,
dividends, Child Benefit, pay period and set of claims: if a penny more pay lowers
net income including Universal Credit, Tax-Free Childcare and funded hours, that
penny is one of the steps of `net_drop_only_at_steps`, or the one where adjusted
net income goes over £100,000. -/
theorem netAll_drop_only_at_steps (p : EarningsPeriod) (cb : Nat) (c : Claims) (s d g : Nat)
    (h : netAll p cb c s d (g + 1) < netAll p cb c s d g) :
    PaStep (g + s + d) ∨ (0 < cb ∧ HicbcStep (g + s + d)) ∨
      Income.step3 ⟨g, s, d⟩ = basicRateLimit ∨ Income.step3 ⟨g, s, d⟩ = higherRateLimit ∨
      g + s + d = childcareIncomeLimit := by
  have ht : g + 1 + s + d = (g + s + d) + 1 := by omega
  by_cases hLim : g + s + d = childcareIncomeLimit
  · exact Or.inr (Or.inr (Or.inr (Or.inr hLim)))
  rcases personalAllowanceFor_succ (g + s + d) with hPA | hPA
  · rw [← ht] at hPA
    rcases psa_succ hPA with hPSA | hT | hT
    · have hC : hicbc (g + 1 + s + d) cb = hicbc (g + s + d) cb ∨
          (0 < cb ∧ HicbcStep (g + s + d)) := by
        rw [ht]
        rcases hicbc_succ (g + s + d) cb with hc | hc
        · exact Or.inl hc
        · by_cases hcb : cb = 0
          · left; subst hcb; unfold hicbc; simp
          · exact Or.inr ⟨by omega, hc⟩
      rcases hC with hC | hC
      · exfalso
        exact netAll_between_steps hPA hPSA hC hLim h
      · exact Or.inr (Or.inl hC)
    · exact Or.inr (Or.inr (Or.inl hT))
    · exact Or.inr (Or.inr (Or.inr (Or.inl hT)))
  · exact Or.inl hPA

end UkTax
