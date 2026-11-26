import UkTax.Optimal
import UkTax.Charges

/-!
# Where net income can fall

Net income here is gross income, less income tax, employee NICs and the High
Income Child Benefit Charge, plus the Child Benefit received. Take a household
whose pay varies, with its savings interest, dividends, Child Benefit and pay
period fixed. Every penny of pay is either employment income on which NICs are
due, and all of it is non-savings income.

Main result (`net_drop_only_at_steps`): if one more penny of pay lowers net
income, then that penny is one of:

* a step of the personal allowance: total income reaches a whole multiple of £2
  above £100,000, up to £125,140, where the allowance (rounded up to a whole
  pound, ITA 2007 s35(3)) falls by £1;
* a step of the High Income Child Benefit Charge: total income reaches a
  whole multiple of £200 from £60,200 to £80,000, where the charge goes up 1 %;
* a step of the personal savings allowance: Step 3 income goes past £37,700 or
  £125,140, where the allowance falls from £1,000 to £500 or from £500 to nil.

Nowhere else. The proof is a bound on the marginal rate between steps: with the
personal allowance and the savings allowance fixed, a penny more pay adds at
most 0.686p of income tax (`taxExact_succ_le`; the worst case is basic-rate pay
inside the starting rate for savings band with dividends crossing bands above
it) and at most 0.08p of NICs, so net income rises by at least 0.234p.
-/

namespace UkTax

/-! ## The rate at a point of the bands -/

/-- The rate on the penny of Step 3 income just above position `y`. -/
def rateAt (r : Rates) (y : Nat) : Nat :=
  if y < basicRateLimit then r.basic else if y < higherRateLimit then r.higher else r.additional

macro "rate_tac" : tactic => `(tactic| (
  unfold bandTax rateAt at *
  (try unfold nonSavingsRates at *)
  (try unfold savingsRates at *)
  (try unfold dividendRates at *)
  unfold basicRateLimit higherRateLimit personalAllowance at *
  dsimp only at *
  split <;> (try split) <;> omega))

theorem bandTax_succ_ns (y : Nat) :
    bandTax nonSavingsRates (y + 1) = bandTax nonSavingsRates y + rateAt nonSavingsRates y := by
  rate_tac

theorem bandTax_succ_sav (y : Nat) :
    bandTax savingsRates (y + 1) = bandTax savingsRates y + rateAt savingsRates y := by
  rate_tac

theorem bandTax_succ_div (y : Nat) :
    bandTax dividendRates (y + 1) = bandTax dividendRates y + rateAt dividendRates y := by
  rate_tac

/-- Which rate applies where, as a disjunction `omega` can use. -/
theorem rateAt_sav_cases (y : Nat) :
    (y < 3_770_000 ∧ rateAt savingsRates y = 2000) ∨
      (3_770_000 ≤ y ∧ y < 12_514_000 ∧ rateAt savingsRates y = 4000) ∨
      (12_514_000 ≤ y ∧ rateAt savingsRates y = 4500) := by
  unfold rateAt savingsRates basicRateLimit higherRateLimit personalAllowance
  dsimp only
  split <;> (try split) <;> omega

theorem rateAt_ns_cases (y : Nat) :
    (y < 3_770_000 ∧ rateAt nonSavingsRates y = 2000) ∨
      (3_770_000 ≤ y ∧ y < 12_514_000 ∧ rateAt nonSavingsRates y = 4000) ∨
      (12_514_000 ≤ y ∧ rateAt nonSavingsRates y = 4500) := by
  unfold rateAt nonSavingsRates basicRateLimit higherRateLimit personalAllowance
  dsimp only
  split <;> (try split) <;> omega

theorem rateAt_div_cases (y : Nat) :
    (y < 3_770_000 ∧ rateAt dividendRates y = 1075) ∨
      (3_770_000 ≤ y ∧ y < 12_514_000 ∧ rateAt dividendRates y = 3575) ∨
      (12_514_000 ≤ y ∧ rateAt dividendRates y = 3935) := by
  unfold rateAt dividendRates basicRateLimit higherRateLimit personalAllowance
  dsimp only
  split <;> (try split) <;> omega

/-! ## One penny more non-savings income, allowances fixed -/

/-- With the allowances fixed, moving a share's non-savings income, its top and
the total all up by one penny adds at most 0.686p (6,860 ten-thousandths) of
tax. -/
theorem G_succ_le {A T x w : Nat} (hxw : x ≤ w) (hwT : w ≤ T) :
    G A (T + 1) (x + 1) (w + 1) ≤ G A T x w + 6860 := by
  have hLB : startingRateLimitSavings < 3_770_000 := by unfold startingRateLimitSavings; decide
  -- the bottom of the taxed savings moves up by 0 or 1; if 0, `x` is below £5,000
  -- or no savings are taxed
  have hlo : (loSav A (x + 1) (w + 1) = loSav A x w ∧
        (x < startingRateLimitSavings ∨ loSav A x w = w + 1)) ∨
      (loSav A (x + 1) (w + 1) = loSav A x w + 1 ∧ x ≤ loSav A x w) := by
    unfold loSav; omega
  have hlow : loSav A x w ≤ w := loSav_le A x w
  have hlodw : w ≤ loDiv T w ∧ loDiv T w ≤ T := by unfold loDiv; omega
  have m1 := bandTax_le savingsRates (loSav_le A x w)
  have m2 := bandTax_le dividendRates (loDiv_le hwT)
  have m3 := bandTax_le savingsRates (loSav_le A (x + 1) (w + 1))
  have m4 := bandTax_le dividendRates (loDiv_le (T := T + 1) (w := w + 1) (by omega))
  have e1 := bandTax_succ_ns x
  have e2 := bandTax_succ_sav w
  have e3 : (bandTax savingsRates (loSav A (x + 1) (w + 1)) = bandTax savingsRates (loSav A x w) ∧
        (x < startingRateLimitSavings ∨ loSav A x w = w + 1)) ∨
      (bandTax savingsRates (loSav A (x + 1) (w + 1))
        = bandTax savingsRates (loSav A x w) + rateAt savingsRates (loSav A x w) ∧
        x ≤ loSav A x w) := by
    rcases hlo with ⟨h, h'⟩ | ⟨h, h'⟩
    · exact Or.inl ⟨by rw [h], h'⟩
    · exact Or.inr ⟨by rw [h]; exact bandTax_succ_sav _, h'⟩
  have e4 := bandTax_succ_div T
  have e5 : bandTax dividendRates (loDiv (T + 1) (w + 1))
      = bandTax dividendRates (loDiv T w) + rateAt dividendRates (loDiv T w) := by
    have : loDiv (T + 1) (w + 1) = loDiv T w + 1 := by unfold loDiv; omega
    rw [this]; exact bandTax_succ_div _
  have k1 := Nat.sub_add_cancel m1
  have k2 := Nat.sub_add_cancel m2
  have k3 := Nat.sub_add_cancel m3
  have k4 := Nat.sub_add_cancel m4
  have r1 := rateAt_ns_cases x
  have r2 := rateAt_sav_cases w
  have r3 := rateAt_sav_cases (loSav A x w)
  have r4 := rateAt_div_cases T
  have r5 := rateAt_div_cases (loDiv T w)
  unfold G
  generalize loSav A (x + 1) (w + 1) = lo' at *
  generalize loSav A x w = lo at *
  generalize loDiv (T + 1) (w + 1) = ld' at *
  generalize loDiv T w = ld at *
  generalize startingRateLimitSavings = L at *
  omega

/-- The personal savings allowance a taxpayer gets. -/
def Income.psa (i : Income) : Nat := savingsAllowanceFor (i.total - i.allowanceUsed)

/-- Step 3 income in all. -/
def Income.step3 (i : Income) : Nat := i.total - i.allowanceUsed

/-- **Marginal income tax rate between steps.** If a penny more non-savings income
changes neither the personal allowance nor the personal savings allowance, it adds
at most 0.686p of income tax (with s25(2) placement on both sides). -/
theorem taxExact_succ_le {n s d : Nat}
    (hPA : personalAllowanceFor (n + 1 + s + d) = personalAllowanceFor (n + s + d))
    (hPSA : Income.psa ⟨n + 1, s, d⟩ = Income.psa ⟨n, s, d⟩) :
    taxExact ⟨n + 1, s, d⟩ ≤ taxExact ⟨n, s, d⟩ + 6860 := by
  have hopt := (isLeastTax_taxExact ⟨n + 1, s, d⟩).2
  have htot : Income.total ⟨n + 1, s, d⟩ = n + 1 + s + d := rfl
  have htot0 : Income.total ⟨n, s, d⟩ = n + s + d := rfl
  have hPA' : Income.personalAllowance ⟨n + 1, s, d⟩ = Income.personalAllowance ⟨n, s, d⟩ := hPA
  by_cases hfull : Income.personalAllowance ⟨n, s, d⟩ ≤ n + s + d
  · -- the whole allowance is used on both sides: keep the same share
    have ha := bestAlloc_feasible ⟨n, s, d⟩
    unfold taxExact
    generalize Income.bestAlloc ⟨n, s, d⟩ = a at ha ⊢
    have hU : Income.allowanceUsed ⟨n, s, d⟩ = Income.personalAllowance ⟨n, s, d⟩ := by
      unfold Income.allowanceUsed; rw [htot0]
      generalize Income.personalAllowance ⟨n, s, d⟩ = P at *; omega
    have hU' : Income.allowanceUsed ⟨n + 1, s, d⟩ = Income.personalAllowance ⟨n, s, d⟩ := by
      unfold Income.allowanceUsed; rw [htot, hPA']
      generalize Income.personalAllowance ⟨n, s, d⟩ = P at *; omega
    have hfa : a.toNonSavings ≤ n ∧ a.toSavings ≤ s ∧ a.toDividends ≤ d ∧
        a.toNonSavings + a.toSavings + a.toDividends = Income.personalAllowance ⟨n, s, d⟩ := by
      have := ha; unfold Alloc.Feasible at this; rw [hU] at this; exact this
    have ha' : a.Feasible ⟨n + 1, s, d⟩ := by
      unfold Alloc.Feasible; rw [hU']
      exact ⟨by simp only; omega, hfa.2.1, hfa.2.2.1, hfa.2.2.2⟩
    obtain ⟨hF, hG⟩ := taxWith_eq_G ha
    obtain ⟨_, hG'⟩ := taxWith_eq_G ha'
    have h1 := hopt a ha'
    rw [hG'] at h1
    rw [hG]
    have hA : savingsAllowanceFor (Income.total ⟨n + 1, s, d⟩ - Income.allowanceUsed ⟨n + 1, s, d⟩)
        = savingsAllowanceFor (Income.total ⟨n, s, d⟩ - Income.allowanceUsed ⟨n, s, d⟩) := hPSA
    have hT : Income.total ⟨n + 1, s, d⟩ - Income.allowanceUsed ⟨n + 1, s, d⟩
        = Income.total ⟨n, s, d⟩ - Income.allowanceUsed ⟨n, s, d⟩ + 1 := by
      rw [htot, htot0, hU, hU']; omega
    rw [hA, hT] at h1
    simp only at h1 hF ⊢
    have hx : n + 1 - a.toNonSavings + (s - a.toSavings)
        = n - a.toNonSavings + (s - a.toSavings) + 1 := by omega
    have hx' : n + 1 - a.toNonSavings = n - a.toNonSavings + 1 := by omega
    rw [hx, hx'] at h1
    unfold Feas at hF
    exact Nat.le_trans h1 (G_succ_le hF.2.1 hF.2.2.2.2)
  · -- all income is covered by the allowance on both sides: no tax
    have h0 : taxWith ⟨n + 1, s, d⟩ (Income.inOrder ⟨n + 1, s, d⟩) = 0 := by
      have hU' : Income.allowanceUsed ⟨n + 1, s, d⟩ = n + 1 + s + d := by
        unfold Income.allowanceUsed; rw [htot, hPA']
        generalize Income.personalAllowance ⟨n, s, d⟩ = P at *; omega
      unfold taxWith Income.inOrder
      rw [hU']
      simp only
      have e1 : n + 1 - min (n + 1 + s + d) (n + 1) = 0 := by omega
      have e2 : s - min (n + 1 + s + d - (n + 1)) s = 0 := by omega
      have e3 : d - min (n + 1 + s + d - (n + 1) - s) d = 0 := by omega
      rw [e1, e2, e3]
      decide
    have := hopt _ (inOrder_feasible _)
    omega

/-! ## Net income -/

/-- Net income, in 1/10 000 pence, for pay `g` (all of it employment income) with
savings interest `s`, dividends `d` and Child Benefit `cb`, paid per period `p`:
gross income less income tax, employee NICs and the High Income Child Benefit
Charge, plus Child Benefit. -/
def net (p : EarningsPeriod) (cb s d g : Nat) : Int :=
  10_000 * ((g + s + d : Nat) : Int) + 10_000 * (cb : Int) - (taxExact ⟨g, s, d⟩ : Int)
    - (nicExact p g : Int) - 10_000 * (hicbc (g + s + d) cb : Int)

theorem nicExact_succ_le (p : EarningsPeriod) (g : Nat) : nicExact p (g + 1) ≤ nicExact p g + 800 := by
  unfold nicExact nicMainRate nicAdditionalRate
  omega

/-- Between steps, net income never falls: if a penny more pay changes neither
allowance nor the charge, net income rises by at least 0.234p. -/
theorem net_succ_ge {p : EarningsPeriod} {cb s d g : Nat}
    (hPA : personalAllowanceFor (g + 1 + s + d) = personalAllowanceFor (g + s + d))
    (hPSA : Income.psa ⟨g + 1, s, d⟩ = Income.psa ⟨g, s, d⟩)
    (hC : hicbc (g + 1 + s + d) cb = hicbc (g + s + d) cb) :
    net p cb s d g + 2340 ≤ net p cb s d (g + 1) := by
  have h1 := taxExact_succ_le hPA hPSA
  have h2 := nicExact_succ_le p g
  unfold net
  rw [hC]
  omega

/-! ## The steps -/

/-- Total income `t + 1` is a whole multiple of £2 above £100,000, up to £125,140:
one penny more from `t` and the personal allowance falls by £1. -/
def PaStep (t : Nat) : Prop :=
  10_000_000 < t + 1 ∧ (t + 1) % 200 = 0 ∧ t + 1 ≤ 12_514_000

/-- Total income `t + 1` is a whole multiple of £200 from £60,200 to £80,000: one
penny more from `t` and the charge goes up 1 %. -/
def HicbcStep (t : Nat) : Prop :=
  6_020_000 ≤ t + 1 ∧ t + 1 ≤ 8_000_000 ∧ (t + 1) % 20_000 = 0

theorem personalAllowanceFor_succ (t : Nat) :
    personalAllowanceFor (t + 1) = personalAllowanceFor t ∨ PaStep t := by
  unfold personalAllowanceFor PaStep personalAllowance paIncomeLimit
  dsimp only
  omega

theorem hicbc_succ (t cb : Nat) : hicbc (t + 1) cb = hicbc t cb ∨ HicbcStep t := by
  unfold hicbc
  by_cases h : hicbcPercent (t + 1) = hicbcPercent t
  · left; rw [h]
  · right
    unfold hicbcPercent hicbcThreshold hicbcStep at h
    unfold HicbcStep
    omega

theorem psa_succ {n s d : Nat}
    (hPA : personalAllowanceFor (n + 1 + s + d) = personalAllowanceFor (n + s + d)) :
    Income.psa ⟨n + 1, s, d⟩ = Income.psa ⟨n, s, d⟩ ∨
      Income.step3 ⟨n, s, d⟩ = basicRateLimit ∨ Income.step3 ⟨n, s, d⟩ = higherRateLimit := by
  have hPA' : Income.personalAllowance ⟨n + 1, s, d⟩ = Income.personalAllowance ⟨n, s, d⟩ := hPA
  unfold Income.psa Income.step3 Income.allowanceUsed
  rw [hPA']
  have htot : Income.total ⟨n + 1, s, d⟩ = n + 1 + s + d := rfl
  have htot0 : Income.total ⟨n, s, d⟩ = n + s + d := rfl
  rw [htot, htot0]
  generalize Income.personalAllowance ⟨n, s, d⟩ = P
  unfold savingsAllowanceFor savingsAllowanceAdditional savingsAllowanceHigher
    savingsAllowanceBasic
  generalize basicRateLimit = B at *
  generalize higherRateLimit = H at *
  repeat' split
  all_goals omega

/-- **Where net income can fall.** If a penny more pay lowers net income, then at
that penny the personal allowance falls by £1, the charge goes up 1 % (with some
Child Benefit), or Step 3 income passes £37,700 or £125,140 (where the personal
savings allowance falls). This holds for every pay, savings, dividends, Child
Benefit and pay period. -/
theorem net_drop_only_at_steps (p : EarningsPeriod) (cb s d g : Nat)
    (h : net p cb s d (g + 1) < net p cb s d g) :
    PaStep (g + s + d) ∨ (0 < cb ∧ HicbcStep (g + s + d)) ∨
      Income.step3 ⟨g, s, d⟩ = basicRateLimit ∨ Income.step3 ⟨g, s, d⟩ = higherRateLimit := by
  have ht : g + 1 + s + d = (g + s + d) + 1 := by omega
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
      · have := net_succ_ge (p := p) hPA hPSA hC
        omega
      · exact Or.inr (Or.inl hC)
    · exact Or.inr (Or.inr (Or.inl hT))
    · exact Or.inr (Or.inr (Or.inr hT))
  · exact Or.inl hPA

end UkTax
