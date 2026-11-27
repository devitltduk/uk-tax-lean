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
  (try unfold Regime.brl at *)
  (try unfold Regime.hrl at *)
  (try unfold nonSavingsRates at *)
  (try unfold savingsRates at *)
  (try unfold dividendRates at *)
  (try unfold basicRateLimit at *)
  (try unfold higherRateLimit at *)
  (try unfold personalAllowance at *)
  (try unfold Regime.brl at *)
  (try unfold Regime.hrl at *)
  (try dsimp only at *)
  omega))

theorem nsTax_mono (rg : Regime) {x y : Nat} (h : x ≤ y) : nsTax rg x ≤ nsTax rg y := by
  unfold nsTax
  split
  · unfold scotTax scotStarterRate scotBasicRate scotIntermediateRate scotHigherRate
      scotAdvancedRate scotTopRate
    omega
  · tax_omega

/-! Each schedule as its lowest rate on everything plus each rise in rate on what
is above that rate's limit. With the limits symbolic (raised by the relief) this
form keeps `omega`'s case splits small. -/

theorem bandTax_ns_eq (rg : Regime) (x : Nat) :
    bandTax nonSavingsRates rg x = 2000 * x + 2000 * (x - rg.brl) + 500 * (x - rg.hrl) := by
  tax_omega

theorem bandTax_sav_eq (rg : Regime) (x : Nat) :
    bandTax savingsRates rg x = 2000 * x + 2000 * (x - rg.brl) + 500 * (x - rg.hrl) := by
  tax_omega

theorem bandTax_div_eq (rg : Regime) (x : Nat) :
    bandTax dividendRates rg x = 1075 * x + 2500 * (x - rg.brl) + 360 * (x - rg.hrl) := by
  tax_omega

/-- What lies above a limit `l` in a slice never shrinks when the slice ends no
lower and is no shorter. -/
theorem above_slice_mono (l : Nat) {a b a' b' : Nat} (hab : a ≤ b) (hb : b ≤ b')
    (hlen : b - a ≤ b' - a') : (b - l) - (a - l) ≤ (b' - l) - (a' - l) := by
  omega

/-- Rates rise from band to band, so moving a slice up the bands, or lengthening it,
never lowers the tax on it. -/
theorem sliceTax_mono_savings (rg : Regime) {a b a' b' : Nat} (hab : a ≤ b) (hb : b ≤ b')
    (hlen : b - a ≤ b' - a') :
    sliceTax savingsRates rg a b ≤ sliceTax savingsRates rg a' b' := by
  unfold sliceTax
  rcases Nat.lt_or_ge b' a' with hab' | hab'
  · have : a = b := by omega
    subst this; simp
  rw [bandTax_sav_eq, bandTax_sav_eq, bandTax_sav_eq, bandTax_sav_eq]
  have h1 := above_slice_mono rg.brl hab hb hlen
  have h2 := above_slice_mono rg.hrl hab hb hlen
  have h3 : a - rg.brl ≤ b - rg.brl := by omega
  have h4 : a - rg.hrl ≤ b - rg.hrl := by omega
  have h5 : a' - rg.brl ≤ b' - rg.brl := by omega
  have h6 : a' - rg.hrl ≤ b' - rg.hrl := by omega
  generalize a - rg.brl = A1 at *; generalize b - rg.brl = B1 at *
  generalize a' - rg.brl = A1' at *; generalize b' - rg.brl = B1' at *
  generalize a - rg.hrl = A2 at *; generalize b - rg.hrl = B2 at *
  generalize a' - rg.hrl = A2' at *; generalize b' - rg.hrl = B2' at *
  omega

theorem sliceTax_mono_dividends (rg : Regime) {a b a' b' : Nat} (hab : a ≤ b) (hb : b ≤ b')
    (hlen : b - a ≤ b' - a') :
    sliceTax dividendRates rg a b ≤ sliceTax dividendRates rg a' b' := by
  unfold sliceTax
  rcases Nat.lt_or_ge b' a' with hab' | hab'
  · have : a = b := by omega
    subst this; simp
  rw [bandTax_div_eq, bandTax_div_eq, bandTax_div_eq, bandTax_div_eq]
  have h1 := above_slice_mono rg.brl hab hb hlen
  have h2 := above_slice_mono rg.hrl hab hb hlen
  have h3 : a - rg.brl ≤ b - rg.brl := by omega
  have h4 : a - rg.hrl ≤ b - rg.hrl := by omega
  have h5 : a' - rg.brl ≤ b' - rg.brl := by omega
  have h6 : a' - rg.hrl ≤ b' - rg.hrl := by omega
  generalize a - rg.brl = A1 at *; generalize b - rg.brl = B1 at *
  generalize a' - rg.brl = A1' at *; generalize b' - rg.brl = B1' at *
  generalize a - rg.hrl = A2 at *; generalize b - rg.hrl = B2 at *
  generalize a' - rg.hrl = A2' at *; generalize b' - rg.hrl = B2' at *
  omega

/-- The personal savings allowance only shrinks as Step 3 income grows. -/
theorem savingsAllowanceFor_anti (rg : Regime) {t t' : Nat} (h : t ≤ t') :
    savingsAllowanceFor rg t' ≤ savingsAllowanceFor rg t := by
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
theorem taxOnStep3_mono (rg : Regime) {n s d n' s' d' : Nat} (hn : n ≤ n') (hs : s ≤ s')
    (hd : d ≤ d') : taxOnStep3 rg n s d ≤ taxOnStep3 rg n' s' d' := by
  unfold taxOnStep3
  have hpsa := savingsAllowanceFor_anti rg (show n + s + d ≤ n' + s' + d' by omega)
  have h1 := nsTax_mono rg hn
  have h2 : sliceTax savingsRates rg (n + startingRateSavings n s + savingsNilRate rg n s d) (n + s)
      ≤ sliceTax savingsRates rg (n' + startingRateSavings n' s' + savingsNilRate rg n' s' d')
          (n' + s') := by
    apply sliceTax_mono_savings
    · unfold savingsNilRate startingRateSavings; omega
    · omega
    · unfold savingsNilRate startingRateSavings; omega
  have h3 : sliceTax dividendRates rg (n + s + dividendNilRate d) (n + s + d)
      ≤ sliceTax dividendRates rg (n' + s' + dividendNilRate d') (n' + s' + d') := by
    apply sliceTax_mono_dividends
    · unfold dividendNilRate; omega
    · omega
    · unfold dividendNilRate; omega
  omega

/-! ## Least tax over all legal allowance shares -/

/-- `v` is the least Step 4 tax over every legal way of deducting the allowance:
the liability s25(2) asks for. -/
def IsLeastTax (rg : Regime) (i : Income) (v : Nat) : Prop :=
  (∃ a, a.Feasible rg i ∧ taxWith rg i a = v) ∧ ∀ a, a.Feasible rg i → v ≤ taxWith rg i a

/-- Componentwise order on incomes. -/
def Income.Le (i i' : Income) : Prop :=
  i.nonSavings ≤ i'.nonSavings ∧ i.savings ≤ i'.savings ∧ i.dividends ≤ i'.dividends

theorem taxWith_le (rg : Regime) {i i' : Income} {a a' : Alloc}
    (hn : i.nonSavings - a.toNonSavings ≤ i'.nonSavings - a'.toNonSavings)
    (hs : i.savings - a.toSavings ≤ i'.savings - a'.toSavings)
    (hd : i.dividends - a.toDividends ≤ i'.dividends - a'.toDividends) :
    taxWith rg i a ≤ taxWith rg i' a' :=
  taxOnStep3_mono rg hn hs hd

private theorem sub_sub_min_add_le (x y e : Nat) : x - (x - min x y + e) ≤ y := by omega

/-- Given the share `a'` for a larger income `i'`, a share for `i`: first bring each
kind of `i`'s income down to at most what `a'` leaves of `i'`, then deduct whatever
allowance is left, non-savings first. -/
def dominatedAlloc (rg : Regime) (i i' : Income) (a' : Alloc) : Alloc :=
  let bn := i.nonSavings - min i.nonSavings (i'.nonSavings - a'.toNonSavings)
  let bs := i.savings - min i.savings (i'.savings - a'.toSavings)
  let bd := i.dividends - min i.dividends (i'.dividends - a'.toDividends)
  let r := i.allowanceUsed rg - (bn + bs + bd)
  let en := min r (i.nonSavings - bn)
  let es := min (r - en) (i.savings - bs)
  let ed := min (r - en - es) (i.dividends - bd)
  ⟨bn + en, bs + es, bd + ed⟩

/-- For any legal share of the allowance for the larger income, the smaller income
has a legal share that leaves no more of each kind of income taxable, and so
(by `taxOnStep3_mono`) no more tax. -/
theorem exists_dominated (rg : Regime) {i i' : Income} (h : i.Le i') {a' : Alloc}
    (ha' : a'.Feasible rg i') : ∃ a, a.Feasible rg i ∧ taxWith rg i a ≤ taxWith rg i' a' := by
  obtain ⟨hN, hS, hD⟩ := h
  have hP : i'.personalAllowance rg ≤ i.personalAllowance rg := by
    unfold Income.personalAllowance Income.ani Income.total
    have := personalAllowanceFor_anti (x := i.nonSavings + i.savings + i.dividends - rg.step2 - rg.relief)
      (x' := i'.nonSavings + i'.savings + i'.dividends - rg.step2 - rg.relief) (by omega)
    generalize personalAllowanceFor (i.nonSavings + i.savings + i.dividends - rg.step2 - rg.relief) = A at *
    generalize personalAllowanceFor (i'.nonSavings + i'.savings + i'.dividends - rg.step2 - rg.relief) = A' at *
    generalize (if rg.maTransfer = true then maTransferable else 0) = m
    generalize (if rg.blind = true then blindPersonsAllowance else 0) = b
    omega
  unfold Alloc.Feasible Income.allowanceUsed Income.total at ha'
  refine ⟨dominatedAlloc rg i i' a', ?_, ?_⟩
  · unfold dominatedAlloc Alloc.Feasible Income.allowanceUsed Income.total
    dsimp only
    generalize i.personalAllowance rg = P at *
    generalize i'.personalAllowance rg = P' at *
    omega
  · have h1 : i.nonSavings - (dominatedAlloc rg i i' a').toNonSavings
        ≤ i'.nonSavings - a'.toNonSavings := by
      unfold dominatedAlloc; dsimp only; exact sub_sub_min_add_le _ _ _
    have h2 : i.savings - (dominatedAlloc rg i i' a').toSavings ≤ i'.savings - a'.toSavings := by
      unfold dominatedAlloc; dsimp only; exact sub_sub_min_add_le _ _ _
    have h3 : i.dividends - (dominatedAlloc rg i i' a').toDividends
        ≤ i'.dividends - a'.toDividends := by
      unfold dominatedAlloc; dsimp only; exact sub_sub_min_add_le _ _ _
    exact taxWith_le rg h1 h2 h3

/-- **Monotonicity.** The least tax (the s25(2) liability) never goes down when any
kind of income (non-savings, savings or dividends) goes up. -/
theorem leastTax_mono (rg : Regime) {i i' : Income} (h : i.Le i') {v v' : Nat}
    (hv : IsLeastTax rg i v) (hv' : IsLeastTax rg i' v') : v ≤ v' := by
  obtain ⟨⟨a', ha', rfl⟩, _⟩ := hv'
  obtain ⟨a, ha, hle⟩ := exists_dominated rg h ha'
  exact Nat.le_trans (hv.2 a ha) hle

/-! ## The search -/

theorem inOrder_feasible (rg : Regime) (i : Income) : (i.inOrder rg).Feasible rg i := by
  unfold Income.inOrder Alloc.Feasible Income.allowanceUsed Income.total
  dsimp only
  generalize i.personalAllowance rg = P
  omega

/-- Every non-empty set of natural numbers has a least element. -/
theorem exists_least_nat (P : Nat → Prop) (h : ∃ n, P n) :
    ∃ m, P m ∧ ∀ k, P k → m ≤ k := by
  obtain ⟨n, hn⟩ := h
  induction n using Nat.strongRecOn with
  | _ n ih =>
    by_cases hlt : ∃ k, k < n ∧ P k
    · obtain ⟨k, hk, hPk⟩ := hlt
      exact ih k hk hPk
    · refine ⟨n, hn, fun k hk => ?_⟩
      exact Nat.not_lt.mp fun hkn => hlt ⟨k, hkn, hk⟩

/-- The least tax exists for every income, so `leastTax_mono` is never vacuous. -/
theorem exists_isLeastTax (rg : Regime) (i : Income) : ∃ v, IsLeastTax rg i v := by
  obtain ⟨v, ⟨a, ha, hv⟩, hmin⟩ :=
    exists_least_nat (fun v => ∃ a, a.Feasible rg i ∧ taxWith rg i a = v)
      ⟨_, i.inOrder rg, inOrder_feasible rg i, rfl⟩
  exact ⟨v, ⟨a, ha, hv⟩, fun b hb => hmin _ ⟨b, hb, rfl⟩⟩

theorem allocAt_feasible {rg : Regime} {i : Income} {p : Int × Int}
    (hp : i.feasibleAt rg p = true) : (i.allocAt rg p).Feasible rg i := by
  unfold Income.feasibleAt at hp
  simp only [Bool.and_eq_true, decide_eq_true_eq] at hp
  unfold Income.allocAt Alloc.Feasible Income.allowanceUsed Income.total at *
  dsimp only at *
  generalize i.personalAllowance rg = P at *
  omega

/-- The search only ever picks a legal share, so `taxExact` is the tax on some
legal share: it is never less than the least tax. -/
theorem bestAlloc_feasible (rg : Regime) (i : Income) : (i.bestAlloc rg).Feasible rg i := by
  unfold Income.bestAlloc
  suffices ∀ (l : List (Int × Int)) (b : Alloc), b.Feasible rg i →
      (l.foldl (fun best p =>
        if i.feasibleAt rg p then
          (if taxWith rg i (i.allocAt rg p) < taxWith rg i best then i.allocAt rg p else best)
        else best) b).Feasible rg i from this _ _ (inOrder_feasible rg i)
  intro l
  induction l with
  | nil => intro b hb; exact hb
  | cons p ps ih =>
    intro b hb
    apply ih
    by_cases hp : i.feasibleAt rg p = true
    · simp only [hp, ite_true]
      split
      · exact allocAt_feasible hp
      · exact hb
    · simp only [hp]
      exact hb

/-- If the corner search finds the least tax, `liability` is monotone in every
kind of income. `Optimal.lean` proves the hypothesis (`isLeastTax_taxExact`), so
`liability_mono` there states this with no hypothesis. -/
theorem liability_mono_of_optimal (rg : Regime) (hopt : ∀ i, IsLeastTax rg i (taxExact rg i))
    {i i' : Income} (h : i.Le i') : liability rg i ≤ liability rg i' :=
  Nat.div_le_div_right (leastTax_mono rg h (hopt i) (hopt i'))

end UkTax
