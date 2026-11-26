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

A lone parent is eligible when they expect to earn at least the minimum
(16 hours a week at the National Living Wage) and their adjusted net income is
not over £100,000. Tax-Free Childcare adds 20 % of each child's childcare costs,
up to £2,000 a child a year; it cannot be had together with Universal Credit, so
the household takes whichever of the two is worth more. The funded hours for
working parents are in kind; their value is an input (no default figure).

All amounts here are in 1/1 000 000 of a penny, so the 55 % taper and the 20 %
top-up stay exact.
-/

namespace UkTax

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
  /-- Yearly value, in pence, of the working-parent funded hours. -/
  fundedHoursValue : Nat := 0

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

/-- Eligible for Tax-Free Childcare and the working-parent funded hours. -/
def childcareEligible (pay ani : Nat) : Bool :=
  childcareMinimumEarnings ≤ pay && ani ≤ childcareIncomeLimit

/-- Tax-Free Childcare top-up for the year, in 1/1 000 000 pence. -/
def tfcTopUp (c : Claims) (pay ani : Nat) : Int :=
  if childcareEligible pay ani then
    ((c.childcareCosts.map fun cost => min (1_000_000 * tfcCapPerChild) (1_000_000 * cost / 5)).sum
      : Nat)
  else 0

/-- Funded hours, as their yearly value, in 1/1 000 000 pence. -/
def fundedHours (c : Claims) (pay ani : Nat) : Int :=
  if childcareEligible pay ani then micro * c.fundedHoursValue else 0

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

/-- Eligibility is only lost where adjusted net income goes over £100,000. -/
theorem childcareEligible_succ {pay ani : Nat} (h : childcareEligible pay ani = true) :
    childcareEligible (pay + 1) (ani + 1) = true ∨ ani = childcareIncomeLimit := by
  unfold childcareEligible at *
  simp only [Bool.and_eq_true, decide_eq_true_eq] at *
  omega

/-- Between steps, and away from £100,000, net income with benefits does not fall. -/
theorem netAll_between_steps {p : EarningsPeriod} {cb : Nat} {c : Claims} {s d g : Nat}
    (hPA : personalAllowanceFor (g + 1 + s + d) = personalAllowanceFor (g + s + d))
    (hPSA : Income.psa ⟨g + 1, s, d⟩ = Income.psa ⟨g, s, d⟩)
    (hC : hicbc (g + 1 + s + d) cb = hicbc (g + s + d) cb)
    (hLim : g + s + d ≠ childcareIncomeLimit)
    (h : netAll p cb c s d (g + 1) < netAll p cb c s d g) : False := by
  have ht : g + 1 + s + d = (g + s + d) + 1 := by omega
  have htax := taxExact_succ_le hPA hPSA
  have hnic := nicExact_succ_le p g
  have hearn : earned p s d g ≤ earned p s d (g + 1) := by
    unfold earned; omega
  have huc := earned_plus_uc_mono c hearn
  have hEl : childcareEligible g (g + s + d) = true →
      childcareEligible (g + 1) (g + 1 + s + d) = true := by
    intro h1; rw [ht]
    rcases childcareEligible_succ h1 with h2 | h2
    · exact h2
    · exact absurd h2 hLim
  have htfc : tfcTopUp c g (g + s + d) ≤ tfcTopUp c (g + 1) (g + 1 + s + d) := by
    unfold tfcTopUp
    by_cases h1 : childcareEligible g (g + s + d) = true
    · rw [h1, hEl h1]; simp
    · rw [show childcareEligible g (g + s + d) = false by simpa using h1]
      simp only [Bool.false_eq_true, ↓reduceIte]
      split <;> omega
  have hfh : fundedHours c g (g + s + d) ≤ fundedHours c (g + 1) (g + 1 + s + d) := by
    unfold fundedHours micro
    by_cases h1 : childcareEligible g (g + s + d) = true
    · rw [h1, hEl h1]; simp
    · rw [show childcareEligible g (g + s + d) = false by simpa using h1]
      simp only [Bool.false_eq_true, ↓reduceIte]
      split <;> omega
  have hsplit : ∀ g' : Nat, 100 * net p cb s d g'
      = 100 * earned p s d g' + 1_000_000 * ((s + d + cb : Nat) : Int)
        - 1_000_000 * (hicbc (g' + s + d) cb : Int) := by
    intro g'; unfold net earned
    generalize taxExact _ = A; generalize nicExact p g' = B; generalize hicbc _ cb = C
    omega
  clear hPA hPSA hEl htax hnic
  unfold netAll at h
  rw [hsplit, hsplit, hC] at h
  have : max (ucAward c (earned p s d g)) (tfcTopUp c g (g + s + d)) + 100 * earned p s d g
      ≤ max (ucAward c (earned p s d (g + 1))) (tfcTopUp c (g + 1) (g + 1 + s + d))
        + 100 * earned p s d (g + 1) := by
    omega
  generalize hicbc (g + s + d) cb = C at *
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
