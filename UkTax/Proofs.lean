import UkTax.Calc

/-!
# Proved properties

Main result: `leastTax_mono`. The least tax over all legal ways of deducting the
personal allowance (the liability ITA 2007 s25(2) asks for) never goes down when
any kind of income (non-savings, savings or dividends) goes up. This is not obvious from the
rules: a higher income moves savings and dividends into higher bands, shrinks the
personal savings allowance in two cliff-edge steps (£1,000 → £500 → £0) and tapers
the personal allowance, and each of those has to push the tax the same way.

The proof works on Step 3 income. A smaller income can always deduct its
allowance so that no kind of its income is left more taxable than the larger
income's (`exists_dominated`), and each of the three parts of Step 4 (non-savings,
taxed savings slice, taxed dividend slice) is monotone, using one
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

/-! ## Least tax over all legal allowance shares -/

/-- `v` is the least Step 4 tax over every legal way of deducting the allowance:
the liability s25(2) asks for. -/
def IsLeastTax (i : Income) (v : Nat) : Prop :=
  (∃ a, a.Feasible i ∧ taxWith i a = v) ∧ ∀ a, a.Feasible i → v ≤ taxWith i a

/-- Componentwise order on incomes. -/
def Income.Le (i i' : Income) : Prop :=
  i.nonSavings ≤ i'.nonSavings ∧ i.savings ≤ i'.savings ∧ i.dividends ≤ i'.dividends

theorem taxWith_le {i i' : Income} {a a' : Alloc}
    (hn : i.nonSavings - a.toNonSavings ≤ i'.nonSavings - a'.toNonSavings)
    (hs : i.savings - a.toSavings ≤ i'.savings - a'.toSavings)
    (hd : i.dividends - a.toDividends ≤ i'.dividends - a'.toDividends) :
    taxWith i a ≤ taxWith i' a' :=
  taxOnStep3_mono hn hs hd

private theorem sub_sub_min_add_le (x y e : Nat) : x - (x - min x y + e) ≤ y := by omega

/-- Given the share `a'` for a larger income `i'`, a share for `i`: first bring each
kind of `i`'s income down to at most what `a'` leaves of `i'`, then deduct whatever
allowance is left, non-savings first. -/
def dominatedAlloc (i i' : Income) (a' : Alloc) : Alloc :=
  let bn := i.nonSavings - min i.nonSavings (i'.nonSavings - a'.toNonSavings)
  let bs := i.savings - min i.savings (i'.savings - a'.toSavings)
  let bd := i.dividends - min i.dividends (i'.dividends - a'.toDividends)
  let r := i.allowanceUsed - (bn + bs + bd)
  let en := min r (i.nonSavings - bn)
  let es := min (r - en) (i.savings - bs)
  let ed := min (r - en - es) (i.dividends - bd)
  ⟨bn + en, bs + es, bd + ed⟩

/-- For any legal share of the allowance for the larger income, the smaller income
has a legal share that leaves no more of each kind of income taxable, and so
(by `taxOnStep3_mono`) no more tax. -/
theorem exists_dominated {i i' : Income} (h : i.Le i') {a' : Alloc} (ha' : a'.Feasible i') :
    ∃ a, a.Feasible i ∧ taxWith i a ≤ taxWith i' a' := by
  obtain ⟨hN, hS, hD⟩ := h
  have hP : i'.personalAllowance ≤ i.personalAllowance := by
    unfold Income.personalAllowance Income.total
    exact personalAllowanceFor_anti (by omega)
  unfold Alloc.Feasible Income.allowanceUsed Income.total at ha'
  refine ⟨dominatedAlloc i i' a', ?_, ?_⟩
  · unfold dominatedAlloc Alloc.Feasible Income.allowanceUsed Income.total
    dsimp only
    generalize i.personalAllowance = P at *
    generalize i'.personalAllowance = P' at *
    omega
  · have h1 : i.nonSavings - (dominatedAlloc i i' a').toNonSavings
        ≤ i'.nonSavings - a'.toNonSavings := by
      unfold dominatedAlloc; dsimp only; exact sub_sub_min_add_le _ _ _
    have h2 : i.savings - (dominatedAlloc i i' a').toSavings ≤ i'.savings - a'.toSavings := by
      unfold dominatedAlloc; dsimp only; exact sub_sub_min_add_le _ _ _
    have h3 : i.dividends - (dominatedAlloc i i' a').toDividends
        ≤ i'.dividends - a'.toDividends := by
      unfold dominatedAlloc; dsimp only; exact sub_sub_min_add_le _ _ _
    exact taxWith_le h1 h2 h3

/-- **Monotonicity.** The least tax (the s25(2) liability) never goes down when any
kind of income (non-savings, savings or dividends) goes up. -/
theorem leastTax_mono {i i' : Income} (h : i.Le i') {v v' : Nat}
    (hv : IsLeastTax i v) (hv' : IsLeastTax i' v') : v ≤ v' := by
  obtain ⟨⟨a', ha', rfl⟩, _⟩ := hv'
  obtain ⟨a, ha, hle⟩ := exists_dominated h ha'
  exact Nat.le_trans (hv.2 a ha) hle

/-! ## The search -/

theorem inOrder_feasible (i : Income) : i.inOrder.Feasible i := by
  unfold Income.inOrder Alloc.Feasible Income.allowanceUsed Income.total
  dsimp only
  generalize i.personalAllowance = P
  omega

theorem allocAt_feasible {i : Income} {p : Int × Int} (hp : i.feasibleAt p = true) :
    (i.allocAt p).Feasible i := by
  unfold Income.feasibleAt at hp
  simp only [Bool.and_eq_true, decide_eq_true_eq] at hp
  unfold Income.allocAt Alloc.Feasible Income.allowanceUsed Income.total at *
  dsimp only at *
  generalize i.personalAllowance = P at *
  omega

/-- The search only ever picks a legal share, so `taxExact` is the tax on some
legal share: it is never less than the least tax. -/
theorem bestAlloc_feasible (i : Income) : i.bestAlloc.Feasible i := by
  unfold Income.bestAlloc
  suffices ∀ (l : List (Int × Int)) (b : Alloc), b.Feasible i →
      (l.foldl (fun best p =>
        if i.feasibleAt p then
          (if taxWith i (i.allocAt p) < taxWith i best then i.allocAt p else best)
        else best) b).Feasible i from this _ _ (inOrder_feasible i)
  intro l
  induction l with
  | nil => intro b hb; exact hb
  | cons p ps ih =>
    intro b hb
    apply ih
    by_cases hp : i.feasibleAt p = true
    · simp only [hp, ite_true]
      split
      · exact allocAt_feasible hp
      · exact hb
    · simp only [hp]
      exact hb

/-- **Monotonicity of the computed liability, given the search is optimal.** The
one step not yet proved in Lean is that the corner search finds the least tax;
with it, `liability` is monotone in every kind of income. -/
theorem liability_mono_of_optimal (hopt : ∀ i, IsLeastTax i (taxExact i))
    {i i' : Income} (h : i.Le i') : liability i ≤ liability i' :=
  Nat.div_le_div_right (leastTax_mono h (hopt i) (hopt i'))

/-- With only non-savings income there is one legal share, so the search is
trivially optimal. -/
theorem isLeastTax_nonSavings_only (n : Nat) :
    IsLeastTax ⟨n, 0, 0⟩ (taxExact ⟨n, 0, 0⟩) := by
  have hb := bestAlloc_feasible ⟨n, 0, 0⟩
  refine ⟨⟨_, hb, rfl⟩, fun a ha => ?_⟩
  have : a = (Income.bestAlloc ⟨n, 0, 0⟩) := by
    unfold Alloc.Feasible at ha hb
    obtain ⟨_, ha2, ha3, ha4⟩ := ha
    obtain ⟨_, hb2, hb3, hb4⟩ := hb
    cases a; cases h : Income.bestAlloc ⟨n, 0, 0⟩
    rw [h] at hb2 hb3 hb4
    simp only [] at *
    congr <;> omega
  rw [this]; exact Nat.le_refl _

/-- **Monotone in non-savings income**, for someone with only non-savings income:
proved outright for the computed liability. -/
theorem liability_mono_nonSavings_only {n n' : Nat} (h : n ≤ n') :
    liability ⟨n, 0, 0⟩ ≤ liability ⟨n', 0, 0⟩ :=
  Nat.div_le_div_right (leastTax_mono (i := ⟨n, 0, 0⟩) (i' := ⟨n', 0, 0⟩)
    ⟨h, Nat.le_refl _, Nat.le_refl _⟩
    (isLeastTax_nonSavings_only n) (isLeastTax_nonSavings_only n'))

end UkTax
