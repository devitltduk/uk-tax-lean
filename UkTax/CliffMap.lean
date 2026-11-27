import UkTax.Benefits

/-!
# The cliff map: every penny where net income can fall, for any figures

For a household (pay period, Child Benefit, regime with its parameter set, claims,
savings and dividends fixed; pay varying), `stepPennies` lists, as formulas in the
parameter set, every pay penny at which `netAll_drop_only_at_steps` allows a drop:

* the personal allowance band: the pay at which adjusted net income reaches each
  `PaStep` (`paPennies`, an arithmetic progression, every £2 of income);
* the HICBC steps (`hicbcPennies`, 100 of them, with Child Benefit);
* adjusted net income reaching the childcare limit;
* Step 3 income crossing the basic and the higher rate limit (the personal
  savings allowance), and, for a Marriage Allowance recipient with pay only, the
  Marriage Allowance limit. Step 3 income never falls as pay rises, so each
  crossing is one penny, found by a binary search (`firstAbove`).

`cliffMap_complete`: for every parameter set meeting `TaxParams.Valid`, every pay
`g` below `maxPay` at which a penny more pay lowers `netAll` is in the list. So
evaluating `netAll` at the listed pennies finds every drop exactly; nothing is
sampled. The households covered are those of `CliffScope`: a Marriage Allowance
recipient only with pay alone (as `maOk_payOnly` needs), and no transfer.
-/

namespace UkTax

/-- What steps at a penny. -/
inductive StepKind where
  | personalAllowance
  | hicbc
  | savingsAllowance
  | marriageAllowance
  | childcare
  deriving Repr, DecidableEq

/-- The pay at which adjusted net income is `t`, for savings `s` and dividends `d`. -/
def payForAni (rg : Regime) (s d t : Nat) : Nat := t + rg.step2 + rg.relief - (s + d)

/-- The least `x` in `[lo, hi)` with `L < f x`, or `hi` if there is none, for a
monotone `f`. -/
def firstAbove (f : Nat → Nat) (L lo hi : Nat) : Nat :=
  if lo < hi then
    if L < f ((lo + hi) / 2) then firstAbove f L lo ((lo + hi) / 2)
    else firstAbove f L ((lo + hi) / 2 + 1) hi
  else lo
termination_by hi - lo

theorem firstAbove_eq (f : Nat → Nat) (hf : ∀ a b, a ≤ b → f a ≤ f b) (L lo hi x : Nat)
    (h1 : lo ≤ x) (h2 : x ≤ hi) (h3 : ∀ y, lo ≤ y → y < x → f y ≤ L) (h4 : x < hi → L < f x) :
    firstAbove f L lo hi = x := by
  rw [firstAbove]
  split
  · split
    · rename_i hm
      have hx : x ≤ (lo + hi) / 2 := by
        apply Nat.le_of_not_lt; intro hlt
        have := h3 _ (by omega) hlt; omega
      exact firstAbove_eq f hf L lo _ x h1 hx h3 (fun h => h4 (by omega))
    · rename_i hm
      have hx : (lo + hi) / 2 + 1 ≤ x := by
        apply Nat.le_of_not_lt; intro hlt
        have := h4 (by omega)
        have := hf x ((lo + hi) / 2) (by omega)
        omega
      exact firstAbove_eq f hf L _ hi x hx h2 (fun y hy hy' => h3 y (by omega) hy') h4
  · omega
termination_by hi - lo

/-- Step 3 income at pay `g`. -/
def step3At (rg : Regime) (s d g : Nat) : Nat := Income.step3 rg ⟨g, s, d⟩

theorem step3At_mono (rg : Regime) (s d : Nat) : ∀ a b, a ≤ b → step3At rg s d a ≤ step3At rg s d b := by
  intro a b h
  obtain ⟨k, rfl⟩ := Nat.exists_eq_add_of_le h
  induction k with
  | zero => exact Nat.le_refl _
  | succ k ih => exact Nat.le_trans (ih (Nat.le_add_right a k)) (step3_succ_ge rg (a + k) s d)

/-- The penny at which Step 3 income first goes above `L`, below `maxPay`. -/
def crossing (rg : Regime) (s d L maxPay : Nat) : List Nat :=
  let x := firstAbove (step3At rg s d) L 0 maxPay
  if 0 < x then [x - 1] else []

theorem mem_crossing {rg : Regime} {s d L maxPay g : Nat} (hg : g < maxPay)
    (h1 : step3At rg s d g ≤ L) (h2 : L < step3At rg s d (g + 1)) : g ∈ crossing rg s d L maxPay := by
  have := firstAbove_eq (step3At rg s d) (step3At_mono rg s d) L 0 maxPay (g + 1) (by omega) (by omega)
    (fun y _ hy => Nat.le_trans (step3At_mono rg s d y g (by omega)) h1) (fun _ => h2)
  unfold crossing
  simp only [this]
  simp

/-- The personal allowance band: for each `PaStep`, the pay at which adjusted net
income reaches it. -/
def paPennies (rg : Regime) (s d : Nat) : List Nat :=
  (List.range ((2 * rg.params.pa + 199) / 200)).map fun k =>
    payForAni rg s d (2 * rg.params.pa + rg.params.paLimit - 1 - 200 * k)

/-- The HICBC steps. -/
def hicbcPennies (rg : Regime) (s d : Nat) : List Nat :=
  (List.range 100).map fun k =>
    payForAni rg s d (rg.params.cbThreshold + (k + 1) * rg.params.cbStep - 1)

/-- Every other penny at which net income can fall, with what steps there. -/
def oneOffPennies (cb : Nat) (rg : Regime) (s d maxPay : Nat) : List (Nat × StepKind) :=
  (if 0 < cb then (hicbcPennies rg s d).map (·, StepKind.hicbc) else [])
    ++ [(payForAni rg s d rg.params.ccLimit, StepKind.childcare)]
    ++ ((crossing rg s d rg.brl maxPay).map (·, StepKind.savingsAllowance))
    ++ ((crossing rg s d rg.hrl maxPay).map (·, StepKind.savingsAllowance))
    ++ (if rg.maReceive then (crossing rg s d rg.maLimit maxPay).map (·, StepKind.marriageAllowance)
        else [])

/-- The households the cliff map covers: no Marriage Allowance transfer (its rate
test would make the regime depend on the pay), and a recipient only with pay
alone. -/
def CliffScope (rg : Regime) (s d : Nat) : Prop :=
  rg.maTransfer = false ∧ (rg.maReceive = false ∨ (s = 0 ∧ d = 0))

/-- A penny more income changes the personal allowance or the charge only where
adjusted net income itself moves up a penny, at a step. -/
theorem allowances_succ' (rg : Regime) (cb t : Nat) :
    (personalAllowanceFor rg.params (t + 1 - rg.step2 - rg.relief)
        = personalAllowanceFor rg.params (t - rg.step2 - rg.relief) ∧
      hicbc rg.params (t + 1 - rg.step2 - rg.relief) cb
        = hicbc rg.params (t - rg.step2 - rg.relief) cb) ∨
      (t + 1 - rg.step2 - rg.relief = (t - rg.step2 - rg.relief) + 1 ∧
        (PaStep rg.params (t - rg.step2 - rg.relief) ∨
          (0 < cb ∧ HicbcStep rg.params (t - rg.step2 - rg.relief)))) := by
  rcases ani_succ rg t with ha | ⟨ha, hb⟩
  · rcases allowances_succ rg cb t with h | h
    · exact Or.inl h
    · exact Or.inr ⟨ha, h⟩
  · left; rw [ha, hb]; exact ⟨rfl, rfl⟩

/-- With the allowance fixed, the savings allowance changes only where Step 3 income
crosses the basic or the higher rate limit. -/
theorem psa_succ_cross {rg : Regime} {n s d : Nat}
    (hPA : personalAllowanceFor rg.params (n + 1 + s + d - rg.step2 - rg.relief)
      = personalAllowanceFor rg.params (n + s + d - rg.step2 - rg.relief)) :
    Income.psa rg ⟨n + 1, s, d⟩ = Income.psa rg ⟨n, s, d⟩ ∨
      (step3At rg s d n ≤ rg.brl ∧ rg.brl < step3At rg s d (n + 1)) ∨
      (step3At rg s d n ≤ rg.hrl ∧ rg.hrl < step3At rg s d (n + 1)) := by
  have hPA' : Income.personalAllowance rg ⟨n + 1, s, d⟩
      = Income.personalAllowance rg ⟨n, s, d⟩ := personalAllowance_congr hPA
  unfold Income.psa step3At Income.step3 Income.allowanceUsed
  rw [hPA']
  have htot : Income.total ⟨n + 1, s, d⟩ = n + 1 + s + d := rfl
  have htot0 : Income.total ⟨n, s, d⟩ = n + s + d := rfl
  rw [htot, htot0]
  generalize Income.personalAllowance rg ⟨n, s, d⟩ = P
  unfold savingsAllowanceFor
  generalize rg.brl = B at *
  generalize rg.hrl = H at *
  repeat' split
  all_goals omega

theorem payForAni_eq {rg : Regime} {s d g : Nat}
    (h : g + 1 + s + d - rg.step2 - rg.relief = (g + s + d - rg.step2 - rg.relief) + 1) :
    payForAni rg s d (g + s + d - rg.step2 - rg.relief) = g := by
  unfold payForAni; omega

theorem mem_paPennies {rg : Regime} {s d g : Nat}
    (h : g + 1 + s + d - rg.step2 - rg.relief = (g + s + d - rg.step2 - rg.relief) + 1)
    (hs : PaStep rg.params (g + s + d - rg.step2 - rg.relief)) : g ∈ paPennies rg s d := by
  unfold paPennies
  rw [List.mem_map]
  generalize ht : g + s + d - rg.step2 - rg.relief = t at *
  unfold PaStep at hs
  refine ⟨(2 * rg.params.pa + rg.params.paLimit - (t + 1)) / 200, ?_, ?_⟩
  · rw [List.mem_range]; omega
  · rw [show 2 * rg.params.pa + rg.params.paLimit - 1
        - 200 * ((2 * rg.params.pa + rg.params.paLimit - (t + 1)) / 200) = t by omega, ← ht]
    exact payForAni_eq (by omega)

theorem mem_hicbcPennies {rg : Regime} {s d g : Nat}
    (h : g + 1 + s + d - rg.step2 - rg.relief = (g + s + d - rg.step2 - rg.relief) + 1)
    (hs : HicbcStep rg.params (g + s + d - rg.step2 - rg.relief)) : g ∈ hicbcPennies rg s d := by
  unfold hicbcPennies
  rw [List.mem_map]
  generalize ht : g + s + d - rg.step2 - rg.relief = t at *
  obtain ⟨h1, h2, ⟨m, hm⟩⟩ := hs
  -- `t + 1` is the threshold plus `m` steps, `1 ≤ m ≤ 100` (any `m` if the step is nil)
  have hk : ∃ k, k < 100 ∧ rg.params.cbThreshold + (k + 1) * rg.params.cbStep = t + 1 := by
    rcases Nat.eq_zero_or_pos rg.params.cbStep with h0 | h0
    · exact ⟨0, by omega, by rw [h0]; omega⟩
    · have hm1 : 1 ≤ m := by
        rcases Nat.eq_zero_or_pos m with h | h
        · rw [h, Nat.mul_zero] at hm; omega
        · exact h
      have hm2 : m ≤ 100 := by
        have : rg.params.cbStep * m ≤ rg.params.cbStep * 100 := by
          rw [← hm]; rw [Nat.mul_comm rg.params.cbStep 100]; omega
        exact Nat.le_of_mul_le_mul_left this h0
      refine ⟨m - 1, by omega, ?_⟩
      rw [show m - 1 + 1 = m by omega, Nat.mul_comm m]
      omega
  obtain ⟨k, hk1, hk2⟩ := hk
  refine ⟨k, List.mem_range.2 hk1, ?_⟩
  rw [show rg.params.cbThreshold + (k + 1) * rg.params.cbStep - 1 = t by omega, ← ht]
  exact payForAni_eq (by omega)

/-- **The cliff map is complete.** For every parameter set meeting
`TaxParams.Valid`, every household in scope and every pay `g` below `maxPay`: if a
penny more pay lowers net income with benefits, `g` is in the personal allowance
band or among the other listed pennies. -/
theorem cliffMap_complete (p : EarningsPeriod) (cb : Nat) {rg : Regime} (hP : rg.params.Valid)
    (c : Claims) {s d : Nat} (hS : CliffScope rg s d) {maxPay g : Nat} (hg : g < maxPay)
    (h : netAll p cb rg c s d (g + 1) < netAll p cb rg c s d g) :
    g ∈ paPennies rg s d ∨ g ∈ (oneOffPennies cb rg s d maxPay).map Prod.fst := by
  have hone : ∀ k, (g, k) ∈ oneOffPennies cb rg s d maxPay →
      g ∈ paPennies rg s d ∨ g ∈ (oneOffPennies cb rg s d maxPay).map Prod.fst :=
    fun k hk => Or.inr (List.mem_map.2 ⟨(g, k), hk, rfl⟩)
  -- the childcare limit
  by_cases hLim : g + s + d - rg.step2 - rg.relief = rg.params.ccLimit ∧
      g + 1 + s + d - rg.step2 - rg.relief = (g + s + d - rg.step2 - rg.relief) + 1
  · apply hone .childcare
    unfold oneOffPennies
    refine List.mem_append_left _ (List.mem_append_left _ (List.mem_append_left _
      (List.mem_append_right _ ?_)))
    rw [← hLim.1, payForAni_eq hLim.2]
    exact List.mem_singleton.2 rfl
  have hLim' : g + s + d - rg.step2 - rg.relief = rg.params.ccLimit →
      g + 1 + s + d - rg.step2 - rg.relief ≠ (g + s + d - rg.step2 - rg.relief) + 1 :=
    fun h1 h2 => hLim ⟨h1, h2⟩
  have hA := allowances_succ' rg cb (g + s + d)
  rw [show g + s + d + 1 = g + 1 + s + d by omega] at hA
  rcases hA with ⟨hPA, hC⟩ | ⟨ha, hA | ⟨hcb, hA⟩⟩
  · -- the Marriage Allowance
    by_cases hMA : Income.maReduction rg ⟨g + 1, s, d⟩ = Income.maReduction rg ⟨g, s, d⟩
    · rcases psa_succ_cross hPA with hPSA | hX | hX
      · exact (netAll_between_steps hP ⟨hPA, hPSA, hMA, hC⟩ hLim' h).elim
      · apply hone .savingsAllowance
        unfold oneOffPennies
        exact List.mem_append_left _ (List.mem_append_left _ (List.mem_append_right _
          (List.mem_map.2 ⟨g, mem_crossing hg hX.1 hX.2, rfl⟩)))
      · apply hone .savingsAllowance
        unfold oneOffPennies
        exact List.mem_append_left _ (List.mem_append_right _
          (List.mem_map.2 ⟨g, mem_crossing hg hX.1 hX.2, rfl⟩))
    · -- only a recipient with pay alone
      have hrec : rg.maReceive = true := by
        cases hr : rg.maReceive
        · exfalso; apply hMA; unfold Income.maReduction; simp [hr]
        · rfl
      obtain ⟨rfl, rfl⟩ : s = 0 ∧ d = 0 := by
        rcases hS.2 with h' | h'
        · rw [hrec] at h'; exact absurd h' (by decide)
        · exact h'
      have hok : Income.maOk rg ⟨g + 1, 0, 0⟩ ≠ Income.maOk rg ⟨g, 0, 0⟩ := by
        intro he; apply hMA; unfold Income.maReduction; rw [he]
      have e1 := maOk_payOnly rg g
      have e2 := maOk_payOnly rg (g + 1)
      have hm := step3_succ_ge rg g 0 0
      have hX : step3At rg 0 0 g ≤ rg.maLimit ∧ rg.maLimit < step3At rg 0 0 (g + 1) := by
        unfold step3At
        cases h0 : Income.maOk rg ⟨g, 0, 0⟩ <;> cases h1 : Income.maOk rg ⟨g + 1, 0, 0⟩ <;>
          simp_all <;> omega
      apply hone .marriageAllowance
      unfold oneOffPennies
      refine List.mem_append_right _ ?_
      simp only [hrec, ↓reduceIte]
      exact List.mem_map.2 ⟨g, mem_crossing hg hX.1 hX.2, rfl⟩
  · exact Or.inl (mem_paPennies ha hA)
  · apply hone .hicbc
    unfold oneOffPennies
    refine List.mem_append_left _ (List.mem_append_left _ (List.mem_append_left _
      (List.mem_append_left _ ?_)))
    simp only [hcb, ↓reduceIte]
    exact List.mem_map.2 ⟨g, mem_hicbcPennies ha hA, rfl⟩

end UkTax
