import UkTax.Calc

/-!
# Proved properties

Main result: `liability_mono`. Income tax liability never goes down when any kind
of income (non-savings, savings or dividends) goes up. This is not obvious from the
rules: a higher income moves savings and dividends into higher bands, shrinks the
personal savings allowance in two cliff-edge steps (£1,000 → £500 → £0) and tapers
the personal allowance, and each of those has to push the tax the same way.

The proof works on Step 3 income. Each of the three parts of Step 4 (non-savings,
taxed savings slice, taxed dividend slice) is shown to be monotone, using one
fact about the band schedule: since rates rise from band to band, a slice of
income that ends no lower and is no shorter is taxed no less (`sliceTax_mono`).
-/

namespace UkTax

/-- Unfold the 2026-27 figures and close a goal in linear arithmetic. -/
macro "tax_omega" : tactic => `(tactic| (
  (try unfold bandTax at *)
  (try unfold nonSavingsRates at *)
  (try unfold savingsRates at *)
  (try unfold dividendRates at *)
  (try unfold basicRateLimit at *)
  (try unfold higherRateLimit at *)
  (try unfold personalAllowance at *)
  (try dsimp only at *)
  omega))

theorem bandTax_mono_nonSavings {x y : Nat} (h : x ≤ y) :
    bandTax nonSavingsRates x ≤ bandTax nonSavingsRates y := by
  tax_omega

/-- Rates rise from band to band, so moving a slice up the bands, or lengthening it,
never lowers the tax on it. -/
theorem sliceTax_mono_savings {a b a' b' : Nat} (hab : a ≤ b) (hb : b ≤ b')
    (hlen : b - a ≤ b' - a') :
    sliceTax savingsRates a b ≤ sliceTax savingsRates a' b' := by
  unfold sliceTax; tax_omega

theorem sliceTax_mono_dividends {a b a' b' : Nat} (hab : a ≤ b) (hb : b ≤ b')
    (hlen : b - a ≤ b' - a') :
    sliceTax dividendRates a b ≤ sliceTax dividendRates a' b' := by
  unfold sliceTax; tax_omega

/-- The personal savings allowance only shrinks as Step 3 income grows. -/
theorem savingsAllowanceFor_anti {t t' : Nat} (h : t ≤ t') :
    savingsAllowanceFor t' ≤ savingsAllowanceFor t := by
  unfold savingsAllowanceFor savingsAllowanceAdditional savingsAllowanceHigher
    savingsAllowanceBasic
  repeat' split
  all_goals omega

/-- The personal allowance only shrinks as adjusted net income grows. -/
theorem personalAllowanceFor_anti {x x' : Nat} (h : x ≤ x') :
    personalAllowanceFor x' ≤ personalAllowanceFor x := by
  unfold personalAllowanceFor personalAllowance paIncomeLimit
  dsimp only
  omega

/-- Step 4 tax is monotone in each kind of Step 3 income. -/
theorem taxOnStep3_mono {n s d n' s' d' : Nat} (hn : n ≤ n') (hs : s ≤ s') (hd : d ≤ d') :
    taxOnStep3 n s d ≤ taxOnStep3 n' s' d' := by
  unfold taxOnStep3
  have hpsa := savingsAllowanceFor_anti (show n + s + d ≤ n' + s' + d' by omega)
  have h1 := bandTax_mono_nonSavings hn
  have h2 : sliceTax savingsRates (n + startingRateSavings n s + savingsNilRate n s d) (n + s)
      ≤ sliceTax savingsRates (n' + startingRateSavings n' s' + savingsNilRate n' s' d')
          (n' + s') := by
    apply sliceTax_mono_savings
    · unfold savingsNilRate startingRateSavings; omega
    · omega
    · unfold savingsNilRate startingRateSavings; omega
  have h3 : sliceTax dividendRates (n + s + dividendNilRate d) (n + s + d)
      ≤ sliceTax dividendRates (n' + s' + dividendNilRate d') (n' + s' + d') := by
    apply sliceTax_mono_dividends
    · unfold dividendNilRate; omega
    · omega
    · unfold dividendNilRate; omega
  omega

/-- Exact tax is monotone in each kind of income. -/
theorem taxExact_mono {i i' : Income} (hn : i.nonSavings ≤ i'.nonSavings)
    (hs : i.savings ≤ i'.savings) (hd : i.dividends ≤ i'.dividends) :
    taxExact i ≤ taxExact i' := by
  have hpa : i'.personalAllowance ≤ i.personalAllowance := by
    unfold Income.personalAllowance Income.total
    exact personalAllowanceFor_anti (by omega)
  unfold taxExact step3
  apply taxOnStep3_mono <;> omega

/-- **Monotonicity.** Raising any kind of income (non-savings, savings or dividends)
never lowers the 2026-27 income tax liability. -/
theorem liability_mono {i i' : Income} (hn : i.nonSavings ≤ i'.nonSavings)
    (hs : i.savings ≤ i'.savings) (hd : i.dividends ≤ i'.dividends) :
    liability i ≤ liability i' :=
  Nat.div_le_div_right (taxExact_mono hn hs hd)

/-- In particular, liability is monotone in non-savings income. -/
theorem liability_mono_nonSavings (n n' s d : Nat) (h : n ≤ n') :
    liability ⟨n, s, d⟩ ≤ liability ⟨n', s, d⟩ :=
  liability_mono h (Nat.le_refl _) (Nat.le_refl _)

end UkTax
