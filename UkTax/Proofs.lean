import UkTax.Calc

/-!
# Proved properties

Main result: `leastTax_mono`. It holds for every parameter set meeting
`TaxParams.Valid` (rates in order, the basic rate limit at most the higher, the
savings allowance not rising), not only the 2026-27 figures. The least tax over all legal ways of deducting the
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

/-! ## Products with symbolic rates

The rates are figures of the parameter set, so tax is a product of two unknowns.
`omega` treats each product as an atom; these lemmas give it the facts it needs. -/

/-- Summation by parts for three bands: the tax at each band's rate equals the
lowest rate on everything plus each rise in rate on what is in the bands above. -/
theorem abel3 {b h a : Nat} (hbh : b ≤ h) (hha : h ≤ a) (X Y Z : Nat) :
    b * X + h * Y + a * Z = b * (X + Y + Z) + (h - b) * (Y + Z) + (a - h) * Z := by
  obtain ⟨p, rfl⟩ := Nat.exists_eq_add_of_le hbh
  obtain ⟨q, rfl⟩ := Nat.exists_eq_add_of_le hha
  simp only [Nat.add_sub_cancel_left, Nat.add_mul, Nat.mul_add]
  omega

/-- A product's growth over a slice is at most its growth over a no shorter slice. -/
theorem mul_slice_le (c : Nat) {u v u' v' : Nat} (h : v - u ≤ v' - u') :
    c * v - c * u ≤ c * v' - c * u' := by
  rw [← Nat.mul_sub, ← Nat.mul_sub]; exact Nat.mul_le_mul_left _ h

theorem mul_le_of_le (c : Nat) {u v : Nat} (h : u ≤ v) : c * u ≤ c * v :=
  Nat.mul_le_mul_left _ h

theorem bandTax_le (r : Rates) (rg : Regime) {a b : Nat} (h : a ≤ b) :
    bandTax r rg a ≤ bandTax r rg b := by
  unfold bandTax
  have h1 : min a rg.brl ≤ min b rg.brl := by omega
  have h2 : min a rg.hrl - rg.brl ≤ min b rg.hrl - rg.brl := by omega
  have h3 : a - rg.hrl ≤ b - rg.hrl := by omega
  exact Nat.add_le_add (Nat.add_le_add (Nat.mul_le_mul_left _ h1) (Nat.mul_le_mul_left _ h2))
    (Nat.mul_le_mul_left _ h3)

theorem scotTax_mono (rg : Regime) {x y : Nat} (h : x ≤ y) : scotTax rg x ≤ scotTax rg y := by
  unfold scotTax
  dsimp only
  have := mul_le_of_le rg.params.scStarterRate h
  have := mul_le_of_le (rg.params.scBasicRate - rg.params.scStarterRate)
    (show x - rg.params.scStarterLimit ≤ y - rg.params.scStarterLimit by omega)
  have := mul_le_of_le (rg.params.scIntermediateRate - rg.params.scBasicRate)
    (show x - (rg.params.scBasicLimit + rg.relief) ≤ y - (rg.params.scBasicLimit + rg.relief) by omega)
  have := mul_le_of_le (rg.params.scHigherRate - rg.params.scIntermediateRate)
    (show x - (rg.params.scIntermediateLimit + rg.relief)
      ≤ y - (rg.params.scIntermediateLimit + rg.relief) by omega)
  have := mul_le_of_le (rg.params.scAdvancedRate - rg.params.scHigherRate)
    (show x - (rg.params.scHigherLimit + rg.relief) ≤ y - (rg.params.scHigherLimit + rg.relief) by omega)
  have := mul_le_of_le (rg.params.scTopRate - rg.params.scAdvancedRate)
    (show x - (rg.params.scAdvancedLimit + rg.relief) ≤ y - (rg.params.scAdvancedLimit + rg.relief) by omega)
  omega

/-- Non-savings tax never falls as income rises, for any figures. -/
theorem nsTax_mono (rg : Regime) {x y : Nat} (h : x ≤ y) : nsTax rg x ≤ nsTax rg y := by
  unfold nsTax
  split
  · exact scotTax_mono rg h
  · exact bandTax_le _ rg h

/-- A schedule as its lowest rate on everything plus each rise in rate on what is
above that rate's limit. With the limits symbolic (raised by the relief) this form
keeps `omega`'s case splits small. Needs the rates in order and the basic rate
limit at most the higher. -/
theorem bandTax_eq {r : Rates} (hr : r.Ordered) {rg : Regime} (hBH : rg.params.brl ≤ rg.params.hrl)
    (x : Nat) :
    bandTax r rg x = r.basic * x + (r.higher - r.basic) * (x - rg.brl)
      + (r.additional - r.higher) * (x - rg.hrl) := by
  have hBH' : rg.brl ≤ rg.hrl := by unfold Regime.brl Regime.hrl; omega
  unfold bandTax
  rw [abel3 hr.1 hr.2]
  have e2 : min x rg.hrl - rg.brl + (x - rg.hrl) = x - rg.brl := by omega
  rw [Nat.add_assoc (min x rg.brl), e2, show min x rg.brl + (x - rg.brl) = x by omega]

/-- What lies above a limit `l` in a slice never shrinks when the slice ends no
lower and is no shorter. -/
theorem above_slice_mono (l : Nat) {a b a' b' : Nat} (hab : a ≤ b) (hb : b ≤ b')
    (hlen : b - a ≤ b' - a') : (b - l) - (a - l) ≤ (b' - l) - (a' - l) := by
  omega

/-- Rates rise from band to band, so moving a slice up the bands, or lengthening it,
never lowers the tax on it. -/
theorem sliceTax_mono {r : Rates} (hr : r.Ordered) {rg : Regime}
    (hBH : rg.params.brl ≤ rg.params.hrl) {a b a' b' : Nat} (hab : a ≤ b) (hb : b ≤ b')
    (hlen : b - a ≤ b' - a') :
    sliceTax r rg a b ≤ sliceTax r rg a' b' := by
  unfold sliceTax
  rcases Nat.lt_or_ge b' a' with hab' | hab'
  · have : a = b := by omega
    subst this; simp
  rw [bandTax_eq hr hBH, bandTax_eq hr hBH, bandTax_eq hr hBH, bandTax_eq hr hBH]
  have m1 := mul_slice_le r.basic hlen
  have m2 := mul_slice_le (r.higher - r.basic) (above_slice_mono rg.brl hab hb hlen)
  have m3 := mul_slice_le (r.additional - r.higher) (above_slice_mono rg.hrl hab hb hlen)
  have k1 := mul_le_of_le r.basic hab
  have k2 := mul_le_of_le (r.higher - r.basic) (show a - rg.brl ≤ b - rg.brl by omega)
  have k3 := mul_le_of_le (r.additional - r.higher) (show a - rg.hrl ≤ b - rg.hrl by omega)
  have k4 := mul_le_of_le r.basic hab'
  have k5 := mul_le_of_le (r.higher - r.basic) (show a' - rg.brl ≤ b' - rg.brl by omega)
  have k6 := mul_le_of_le (r.additional - r.higher) (show a' - rg.hrl ≤ b' - rg.hrl by omega)
  omega

/-- The personal savings allowance only shrinks as Step 3 income grows. -/
theorem savingsAllowanceFor_anti {rg : Regime} (hP : rg.params.Valid) {t t' : Nat} (h : t ≤ t') :
    savingsAllowanceFor rg t' ≤ savingsAllowanceFor rg t := by
  have := hP.psaHigherBasic
  have := hP.psaAdditionalHigher
  unfold savingsAllowanceFor
  repeat' split
  all_goals omega

/-- The personal allowance only shrinks as adjusted net income grows, for any
figures. -/
theorem personalAllowanceFor_anti (P : TaxParams) {x x' : Nat} (h : x ≤ x') :
    personalAllowanceFor P x' ≤ personalAllowanceFor P x := by
  unfold personalAllowanceFor
  dsimp only
  omega

/-- Step 4 tax is monotone in each kind of Step 3 income. -/
theorem taxOnStep3_mono {rg : Regime} (hP : rg.params.Valid) {n s d n' s' d' : Nat} (hn : n ≤ n')
    (hs : s ≤ s') (hd : d ≤ d') : taxOnStep3 rg n s d ≤ taxOnStep3 rg n' s' d' := by
  unfold taxOnStep3
  have hpsa := savingsAllowanceFor_anti hP (show n + s + d ≤ n' + s' + d' by omega)
  have h1 := nsTax_mono rg hn
  have h2 : sliceTax rg.params.savRates rg
        (n + startingRateSavings rg n s + savingsNilRate rg n s d) (n + s)
      ≤ sliceTax rg.params.savRates rg
          (n' + startingRateSavings rg n' s' + savingsNilRate rg n' s' d') (n' + s') := by
    apply sliceTax_mono hP.savOrdered hP.brlHrl
    · unfold savingsNilRate startingRateSavings; omega
    · omega
    · unfold savingsNilRate startingRateSavings; omega
  have h3 : sliceTax rg.params.divRates rg (n + s + dividendNilRate rg d) (n + s + d)
      ≤ sliceTax rg.params.divRates rg (n' + s' + dividendNilRate rg d') (n' + s' + d') := by
    apply sliceTax_mono hP.divOrdered hP.brlHrl
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

theorem taxWith_le {rg : Regime} (hP : rg.params.Valid) {i i' : Income} {a a' : Alloc}
    (hn : i.nonSavings - a.toNonSavings ≤ i'.nonSavings - a'.toNonSavings)
    (hs : i.savings - a.toSavings ≤ i'.savings - a'.toSavings)
    (hd : i.dividends - a.toDividends ≤ i'.dividends - a'.toDividends) :
    taxWith rg i a ≤ taxWith rg i' a' :=
  taxOnStep3_mono hP hn hs hd

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
theorem exists_dominated {rg : Regime} (hP : rg.params.Valid) {i i' : Income} (h : i.Le i') {a' : Alloc}
    (ha' : a'.Feasible rg i') : ∃ a, a.Feasible rg i ∧ taxWith rg i a ≤ taxWith rg i' a' := by
  obtain ⟨hN, hS, hD⟩ := h
  have hPA : i'.personalAllowance rg ≤ i.personalAllowance rg := by
    unfold Income.personalAllowance Income.ani Income.total
    have := personalAllowanceFor_anti rg.params (x := i.nonSavings + i.savings + i.dividends - rg.step2 - rg.relief)
      (x' := i'.nonSavings + i'.savings + i'.dividends - rg.step2 - rg.relief) (by omega)
    generalize personalAllowanceFor rg.params (i.nonSavings + i.savings + i.dividends - rg.step2 - rg.relief) = A at *
    generalize personalAllowanceFor rg.params (i'.nonSavings + i'.savings + i'.dividends - rg.step2 - rg.relief) = A' at *
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
    exact taxWith_le hP h1 h2 h3

/-- **Monotonicity.** The least tax (the s25(2) liability) never goes down when any
kind of income (non-savings, savings or dividends) goes up. -/
theorem leastTax_mono {rg : Regime} (hP : rg.params.Valid) {i i' : Income} (h : i.Le i') {v v' : Nat}
    (hv : IsLeastTax rg i v) (hv' : IsLeastTax rg i' v') : v ≤ v' := by
  obtain ⟨⟨a', ha', rfl⟩, _⟩ := hv'
  obtain ⟨a, ha, hle⟩ := exists_dominated hP h ha'
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
theorem liability_mono_of_optimal {rg : Regime} (hP : rg.params.Valid) (hopt : ∀ i, IsLeastTax rg i (taxExact rg i))
    {i i' : Income} (h : i.Le i') : liability rg i ≤ liability rg i' :=
  Nat.div_le_div_right (leastTax_mono hP h (hopt i) (hopt i'))

end UkTax
