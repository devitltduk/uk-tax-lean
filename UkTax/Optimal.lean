import UkTax.Proofs

/-!
# The corner search finds the least tax

Main result: `isLeastTax_taxExact`, `∀ i, IsLeastTax i (taxExact i)`. The allowance
share that `Income.bestAlloc` picks gives the least Step 4 tax over every legal
share, so the computed liability is the s25(2) liability. With `leastTax_mono`
this makes the computed `liability` monotone in every kind of income
(`liability_mono`), with no hypothesis.

## The argument

Fix an income. Its total Step 3 income `T` and personal savings allowance `A` do
not depend on how the allowance is shared, so a share is a point `(x, w)`:
`x` is the non-savings income left and `w` is `x` plus the savings left.
`G A T x w` is the Step 4 tax at that point (`taxOnStep3_eq_G`), written as a sum
of `bandTax` terms. The bottom of the taxed savings slice simplifies to
`min w (max x L + A)` (`L` = £5,000, the starting rate limit for savings).

`bandTax` is linear between the band limits, so at three evenly spaced points with
no band limit strictly between the outer two, its value at the middle point is the
average of the outer two (`bandTax_even3`). Each argument of `bandTax` in `G`
moves by 0 or 1 when `x` or `w` moves by 1, so away from a short list of lines
(the "bends") `G` has a zero second difference.

A function on an interval of naturals with a zero second difference everywhere
except at a set `B` is least at an end of the interval or in `B`
(`exists_min_at_bend`): at the leftmost least point `y`, if `y` were inside the
interval and not in `B`, then `f (y - 1) > f y` would force `f (y + 1) < f y`.

Applied first along `x` (with `w` fixed) this moves any share to one where `x`
is a constant line or `w - x` is (`G_affine_x`). Then along the remaining line,
varying `w`, it moves to a crossing with a second line (`G_affine_w_const`,
`G_affine_w_diag`). Every such crossing is in `Income.candidates`, and the search
takes the least tax over the feasible ones (`foldl_best`).
-/

namespace UkTax

/-! ## `bandTax` at three evenly spaced points -/

/-- `a ≤ b ≤ c` evenly spaced, with no band limit strictly between `a` and `c`. -/
def Even3 (a b c : Nat) : Prop :=
  a ≤ b ∧ a + c = 2 * b ∧ (c ≤ basicRateLimit ∨ basicRateLimit ≤ a) ∧
    (c ≤ higherRateLimit ∨ higherRateLimit ≤ a)

theorem bandTax_even3 (r : Rates) {a b c : Nat} (h : Even3 a b c) :
    bandTax r a + bandTax r c = 2 * bandTax r b := by
  unfold Even3 at h
  have e1 : min a basicRateLimit + min c basicRateLimit = 2 * min b basicRateLimit := by omega
  have e2 : (min a higherRateLimit - basicRateLimit) + (min c higherRateLimit - basicRateLimit)
      = 2 * (min b higherRateLimit - basicRateLimit) := by omega
  have e3 : (a - higherRateLimit) + (c - higherRateLimit) = 2 * (b - higherRateLimit) := by omega
  have f1 : r.basic * min a basicRateLimit + r.basic * min c basicRateLimit
      = 2 * (r.basic * min b basicRateLimit) := by rw [← Nat.mul_add, e1, Nat.mul_left_comm]
  have f2 : r.higher * (min a higherRateLimit - basicRateLimit)
      + r.higher * (min c higherRateLimit - basicRateLimit)
      = 2 * (r.higher * (min b higherRateLimit - basicRateLimit)) := by
    rw [← Nat.mul_add, e2, Nat.mul_left_comm]
  have f3 : r.additional * (a - higherRateLimit) + r.additional * (c - higherRateLimit)
      = 2 * (r.additional * (b - higherRateLimit)) := by rw [← Nat.mul_add, e3, Nat.mul_left_comm]
  unfold bandTax
  omega

theorem bandTax_le (r : Rates) {a b : Nat} (h : a ≤ b) : bandTax r a ≤ bandTax r b := by
  unfold bandTax
  have h1 : min a basicRateLimit ≤ min b basicRateLimit := by omega
  have h2 : min a higherRateLimit - basicRateLimit ≤ min b higherRateLimit - basicRateLimit := by
    omega
  have h3 : a - higherRateLimit ≤ b - higherRateLimit := by omega
  exact Nat.add_le_add (Nat.add_le_add (Nat.mul_le_mul_left _ h1) (Nat.mul_le_mul_left _ h2))
    (Nat.mul_le_mul_left _ h3)

/-! ## Step 4 tax at a point `(x, w)` -/

/-- Bottom of the savings taxed at 20 / 40 / 45 %: above the non-savings income `x`,
the starting rate for savings and the savings allowance `A`, capped at `w`. -/
def loSav (A x w : Nat) : Nat := min w (max x startingRateLimitSavings + A)

/-- Bottom of the dividends taxed at 10.75 / 35.75 / 39.35 %: above the dividend
allowance, capped at `T`. -/
def loDiv (T w : Nat) : Nat := w + min (T - w) dividendAllowance

/-- Step 4 tax, in 1/10 000 pence, when `x` non-savings income and `w - x` savings
are left after the allowance, out of `T` in all, with savings allowance `A`. -/
def G (A T x w : Nat) : Nat :=
  bandTax nonSavingsRates x
    + (bandTax savingsRates w - bandTax savingsRates (loSav A x w))
    + (bandTax dividendRates T - bandTax dividendRates (loDiv T w))

theorem taxOnStep3_eq_G {x w T : Nat} (hxw : x ≤ w) (hwT : w ≤ T) :
    taxOnStep3 x (w - x) (T - w) = G (savingsAllowanceFor T) T x w := by
  have h1 : x + (w - x) = w := by omega
  have h2 : x + (w - x) + (T - w) = T := by omega
  have h3 : x + startingRateSavings x (w - x) + savingsNilRate x (w - x) (T - w)
      = loSav (savingsAllowanceFor T) x w := by
    unfold savingsNilRate startingRateSavings loSav
    rw [h2]
    omega
  have h4 : x + (w - x) + dividendNilRate (T - w) = loDiv T w := by
    unfold dividendNilRate loDiv
    omega
  unfold taxOnStep3 sliceTax G
  rw [h3, h4, h2, h1]

/-! ## Where `G` is linear -/

theorem even3_x {x : Nat} (h0 : 0 < x) (h1 : x ≠ basicRateLimit) (h2 : x ≠ higherRateLimit) :
    Even3 (x - 1) x (x + 1) := by
  unfold Even3; omega

theorem even3_loSav_x {A x w : Nat} (h0 : 0 < x) (h1 : x ≠ startingRateLimitSavings)
    (h2 : x + A ≠ basicRateLimit) (h3 : x + A ≠ higherRateLimit) (h4 : x + A ≠ w) :
    Even3 (loSav A (x - 1) w) (loSav A x w) (loSav A (x + 1) w) := by
  unfold Even3 loSav; omega

theorem even3_loSav_w_const {A c w : Nat} (h0 : 0 < w) (h1 : w ≠ basicRateLimit)
    (h2 : w ≠ higherRateLimit) (h3 : w ≠ startingRateLimitSavings + A) (h4 : w ≠ c + A) :
    Even3 (loSav A c (w - 1)) (loSav A c w) (loSav A c (w + 1)) := by
  unfold Even3 loSav; omega

theorem even3_loSav_w_diag {A e w : Nat} (he : e + 1 ≤ w) (h1 : w ≠ basicRateLimit)
    (h2 : w ≠ higherRateLimit) (h3 : w ≠ startingRateLimitSavings + A)
    (h4 : w ≠ startingRateLimitSavings + e) (h5 : w + A ≠ basicRateLimit + e)
    (h6 : w + A ≠ higherRateLimit + e) :
    Even3 (loSav A (w - 1 - e) (w - 1)) (loSav A (w - e) w) (loSav A (w + 1 - e) (w + 1)) := by
  unfold Even3 loSav; omega

theorem even3_loDiv {T w : Nat} (h0 : 0 < w) (hwT : w + 1 ≤ T)
    (h1 : w + dividendAllowance ≠ T) (h2 : w + dividendAllowance ≠ basicRateLimit)
    (h3 : w + dividendAllowance ≠ higherRateLimit) :
    Even3 (loDiv T (w - 1)) (loDiv T w) (loDiv T (w + 1)) := by
  unfold Even3 loDiv; omega

theorem loSav_le (A x w : Nat) : loSav A x w ≤ w := by unfold loSav; omega

theorem loDiv_le {T w : Nat} (h : w ≤ T) : loDiv T w ≤ T := by unfold loDiv; omega

/-- Bends of `G` along `x` (with `w` fixed). -/
def BendX (A w x : Nat) : Prop :=
  x = startingRateLimitSavings ∨ x = basicRateLimit ∨ x = higherRateLimit ∨
    x + A = basicRateLimit ∨ x + A = higherRateLimit ∨ x + A = w

/-- Bends of `G` along `w` with `x = c` fixed. -/
def BendWConst (A T c w : Nat) : Prop :=
  w = basicRateLimit ∨ w = higherRateLimit ∨ w = startingRateLimitSavings + A ∨ w = c + A ∨
    w + dividendAllowance = T ∨ w + dividendAllowance = basicRateLimit ∨
    w + dividendAllowance = higherRateLimit

/-- Bends of `G` along `w` with `w - x = e` fixed. -/
def BendWDiag (A T e w : Nat) : Prop :=
  w = basicRateLimit + e ∨ w = higherRateLimit + e ∨ w = basicRateLimit ∨ w = higherRateLimit ∨
    w = startingRateLimitSavings + e ∨ w = startingRateLimitSavings + A ∨
    w + A = basicRateLimit + e ∨ w + A = higherRateLimit + e ∨
    w + dividendAllowance = T ∨ w + dividendAllowance = basicRateLimit ∨
    w + dividendAllowance = higherRateLimit

theorem G_affine_x {A T x w : Nat} (h0 : 0 < x) (hxw : x + 1 ≤ w) (hwT : w ≤ T)
    (hB : ¬ BendX A w x) :
    G A T (x - 1) w + G A T (x + 1) w = 2 * G A T x w := by
  unfold BendX at hB
  have e1 := bandTax_even3 nonSavingsRates (even3_x h0 (by omega) (by omega))
  have e2 := bandTax_even3 savingsRates
    (even3_loSav_x (A := A) (w := w) h0 (by omega) (by omega) (by omega) (by omega))
  have := bandTax_le savingsRates (loSav_le A (x - 1) w)
  have := bandTax_le savingsRates (loSav_le A x w)
  have := bandTax_le savingsRates (loSav_le A (x + 1) w)
  have := bandTax_le dividendRates (loDiv_le hwT)
  unfold G
  omega

theorem G_affine_w_const {A T c w : Nat} (hc : c + 1 ≤ w) (hwT : w + 1 ≤ T)
    (hB : ¬ BendWConst A T c w) :
    G A T c (w - 1) + G A T c (w + 1) = 2 * G A T c w := by
  unfold BendWConst at hB
  have e1 := bandTax_even3 savingsRates (even3_x (x := w) (by omega) (by omega) (by omega))
  have e2 := bandTax_even3 savingsRates
    (even3_loSav_w_const (A := A) (c := c) (w := w) (by omega) (by omega) (by omega) (by omega)
      (by omega))
  have e3 := bandTax_even3 dividendRates
    (even3_loDiv (T := T) (w := w) (by omega) hwT (by omega) (by omega) (by omega))
  have := bandTax_le savingsRates (loSav_le A c (w - 1))
  have := bandTax_le savingsRates (loSav_le A c w)
  have := bandTax_le savingsRates (loSav_le A c (w + 1))
  have := bandTax_le dividendRates (loDiv_le (T := T) (w := w - 1) (by omega))
  have := bandTax_le dividendRates (loDiv_le (T := T) (w := w) (by omega))
  have := bandTax_le dividendRates (loDiv_le (T := T) (w := w + 1) (by omega))
  unfold G
  omega

theorem G_affine_w_diag {A T e w : Nat} (he : e + 1 ≤ w) (hwT : w + 1 ≤ T)
    (hB : ¬ BendWDiag A T e w) :
    G A T (w - 1 - e) (w - 1) + G A T (w + 1 - e) (w + 1) = 2 * G A T (w - e) w := by
  unfold BendWDiag at hB
  have h1 : Even3 (w - 1 - e) (w - e) (w + 1 - e) := by unfold Even3; omega
  have e1 := bandTax_even3 nonSavingsRates h1
  have e2 := bandTax_even3 savingsRates (even3_x (x := w) (by omega) (by omega) (by omega))
  have e3 := bandTax_even3 savingsRates
    (even3_loSav_w_diag (A := A) (e := e) (w := w) he (by omega) (by omega) (by omega)
      (by omega) (by omega) (by omega))
  have e4 := bandTax_even3 dividendRates
    (even3_loDiv (T := T) (w := w) (by omega) hwT (by omega) (by omega) (by omega))
  have := bandTax_le savingsRates (loSav_le A (w - 1 - e) (w - 1))
  have := bandTax_le savingsRates (loSav_le A (w - e) w)
  have := bandTax_le savingsRates (loSav_le A (w + 1 - e) (w + 1))
  have := bandTax_le dividendRates (loDiv_le (T := T) (w := w - 1) (by omega))
  have := bandTax_le dividendRates (loDiv_le (T := T) (w := w) (by omega))
  have := bandTax_le dividendRates (loDiv_le (T := T) (w := w + 1) (by omega))
  unfold G
  omega

/-! ## Least at an end or a bend -/

/-- If `f` has a zero second difference at every point strictly inside `[lo, hi]`
that is not in `B`, then for any `z` in `[lo, hi]` some point that is `lo`, `hi`
or in `B` has `f` no larger. -/
theorem exists_min_at_bend (f : Nat → Nat) (B : Nat → Prop) {lo hi : Nat}
    (haff : ∀ x, lo < x → x < hi → ¬ B x → f (x - 1) + f (x + 1) = 2 * f x)
    {z : Nat} (hz1 : lo ≤ z) (hz2 : z ≤ hi) :
    ∃ y, lo ≤ y ∧ y ≤ hi ∧ (y = lo ∨ y = hi ∨ B y) ∧ f y ≤ f z := by
  obtain ⟨m, ⟨u, hu1, hu2, rfl⟩, hmin⟩ :=
    exists_least_nat (fun v => ∃ u, lo ≤ u ∧ u ≤ hi ∧ f u = v) ⟨_, z, hz1, hz2, rfl⟩
  obtain ⟨y, ⟨hy1, hy2, hy3⟩, hleast⟩ :=
    exists_least_nat (fun y => lo ≤ y ∧ y ≤ hi ∧ f y = f u) ⟨u, hu1, hu2, rfl⟩
  refine ⟨y, hy1, hy2, ?_, by rw [hy3]; exact hmin _ ⟨z, hz1, hz2, rfl⟩⟩
  by_cases h1 : y = lo
  · exact Or.inl h1
  by_cases h2 : y = hi
  · exact Or.inr (Or.inl h2)
  by_cases hB : B y
  · exact Or.inr (Or.inr hB)
  exfalso
  have hx := haff y (by omega) (by omega) hB
  have hprev : f u ≤ f (y - 1) := hmin _ ⟨y - 1, by omega, by omega, rfl⟩
  have hnext : f u ≤ f (y + 1) := hmin _ ⟨y + 1, by omega, by omega, rfl⟩
  have hne : f (y - 1) ≠ f u := fun h => by
    have := hleast (y - 1) ⟨by omega, by omega, h⟩
    omega
  omega

/-! ## Shares as points

From here on an income is described by plain numbers: `N`, `S`, `D` its
non-savings, savings and dividend income, `T` its Step 3 income in all and `A` its
savings allowance. -/

/-- Prove a disjunction by trying `omega` on each disjunct in turn. -/
syntax "pick" : tactic
macro_rules
  | `(tactic| pick) => `(tactic| first | (apply Or.inl; omega) | (apply Or.inr; pick) | omega)

/-- `(x, w)` is a legal share. -/
def Feas (N S D T x w : Nat) : Prop :=
  x ≤ N ∧ x ≤ w ∧ w ≤ x + S ∧ T ≤ w + D ∧ w ≤ T

/-- A constant-`x` line of the search (`Income.xLines`). -/
def XLine (N A x : Nat) : Prop :=
  x = 0 ∨ x = N ∨ x = startingRateLimitSavings ∨ x = basicRateLimit ∨ x = higherRateLimit ∨
    x + A = basicRateLimit ∨ x + A = higherRateLimit

/-- A constant-`w` line of the search (`Income.wLines`). -/
def WLine (D T A w : Nat) : Prop :=
  w = T ∨ w + D = T ∨ w = startingRateLimitSavings ∨ w = startingRateLimitSavings + A ∨
    w = basicRateLimit ∨ w = higherRateLimit ∨ w + dividendAllowance = T ∨
    w + dividendAllowance = basicRateLimit ∨ w + dividendAllowance = higherRateLimit

/-- A constant-`(w - x)` line of the search (`Income.diagLines`). -/
def DLine (S A e : Nat) : Prop := e = 0 ∨ e = S ∨ e = A

/-- A crossing of two lines, as `Income.candidates` lists them. -/
def Cand (N S D T A x w : Nat) : Prop :=
  (XLine N A x ∧ WLine D T A w) ∨ (XLine N A x ∧ ∃ e, DLine S A e ∧ w = x + e) ∨
    (WLine D T A w ∧ ∃ e, DLine S A e ∧ w = x + e)

theorem cand_const {N S D T A y w' : Nat} (hx : XLine N A y)
    (hwB : w' = max (T - D) y ∨ w' = min T (y + S) ∨ BendWConst A T y w') :
    Cand N S D T A y w' := by
  unfold BendWConst at hwB
  by_cases hd : w' = y ∨ w' = y + S ∨ w' = y + A
  · refine Or.inr (Or.inl ⟨hx, ?_⟩)
    rcases hd with hd | hd | hd
    · exact ⟨0, Or.inl rfl, by omega⟩
    · exact ⟨S, Or.inr (Or.inl rfl), hd⟩
    · exact ⟨A, Or.inr (Or.inr rfl), hd⟩
  · refine Or.inl ⟨hx, ?_⟩
    clear hx
    unfold WLine
    rcases hwB with h | h | h | h | h | h | h | h | h <;> pick

theorem cand_diag {N S D T A e w' : Nat} (he : DLine S A e) (hw1 : max e (T - D) ≤ w')
    (hw2 : w' ≤ min T (N + e))
    (hwB : w' = max e (T - D) ∨ w' = min T (N + e) ∨ BendWDiag A T e w') :
    Cand N S D T A (w' - e) w' := by
  unfold BendWDiag at hwB
  by_cases hd : w' = e ∨ w' = N + e ∨ w' = basicRateLimit + e ∨ w' = higherRateLimit + e ∨
      w' = startingRateLimitSavings + e ∨ w' + A = basicRateLimit + e ∨
      w' + A = higherRateLimit + e
  · refine Or.inr (Or.inl ⟨?_, e, he, by omega⟩)
    unfold XLine
    rcases hd with h | h | h | h | h | h | h <;> pick
  · refine Or.inr (Or.inr ⟨?_, e, he, by omega⟩)
    unfold WLine
    rcases hwB with h | h | h | h | h | h | h | h | h | h | h | h | h <;> pick

-- `G` is opaque here: `omega` only needs its values as atoms.
attribute [local irreducible] G in
/-- Every legal share has a crossing of two lines with no more tax. -/
theorem exists_cand {N S D T A x w : Nat} (h : Feas N S D T x w) :
    ∃ x' w', Feas N S D T x' w' ∧ Cand N S D T A x' w' ∧ G A T x' w' ≤ G A T x w := by
  obtain ⟨hxN, hxw, hwS, hTD, hwT⟩ := h
  -- Step 1: along `x`, with `w` fixed.
  obtain ⟨y, hy1, hy2, hyB, hyle⟩ :=
    exists_min_at_bend (fun x => G A T x w) (BendX A w) (lo := w - S) (hi := min N w)
      (fun x h1 h2 hB => G_affine_x (by omega) (by omega) hwT hB) (z := x) (by omega) (by omega)
  -- `y` is on a constant-`x` line, or on a constant-`(w - x)` line.
  have hform : XLine N A y ∨ ∃ e, DLine S A e ∧ e ≤ S ∧ y + e = w := by
    unfold BendX at hyB
    by_cases hd : (S ≤ w ∧ y = w - S) ∨ y = w ∨ y + A = w
    · right
      rcases hd with ⟨_, hd⟩ | hd | hd
      · exact ⟨S, Or.inr (Or.inl rfl), Nat.le_refl _, by omega⟩
      · exact ⟨0, Or.inl rfl, Nat.zero_le _, by omega⟩
      · exact ⟨A, Or.inr (Or.inr rfl), by omega, hd⟩
    · left; unfold XLine; omega
  rcases hform with hx | ⟨e, he, heS, hye⟩
  · -- Step 2: along `w`, with `x = y` fixed.
    obtain ⟨w', hw1, hw2, hwB, hwle⟩ :=
      exists_min_at_bend (fun w => G A T y w) (BendWConst A T y)
        (lo := max (T - D) y) (hi := min T (y + S))
        (fun w h1 h2 hB => G_affine_w_const (by omega) (by omega) hB) (z := w)
        (by omega) (by omega)
    refine ⟨y, w', ⟨by omega, by omega, by omega, by omega, by omega⟩, ?_,
      Nat.le_trans hwle hyle⟩
    exact cand_const hx hwB
  · -- Step 2: along `w`, with `w - x = e` fixed.
    obtain ⟨w', hw1, hw2, hwB, hwle⟩ :=
      exists_min_at_bend (fun w => G A T (w - e) w) (BendWDiag A T e)
        (lo := max e (T - D)) (hi := min T (N + e))
        (fun w h1 h2 hB => G_affine_w_diag (by omega) (by omega) hB) (z := w)
        (by omega) (by omega)
    have hyw : w - e = y := by omega
    simp only [hyw] at hwle
    refine ⟨w' - e, w', ⟨by omega, by omega, by omega, by omega, by omega⟩, ?_,
      Nat.le_trans hwle hyle⟩
    exact cand_diag he hw1 hw2 hwB

/-! ## Back to `Income` -/

theorem allowanceUsed_le (i : Income) : i.allowanceUsed ≤ i.total := by
  unfold Income.allowanceUsed; omega

theorem feasibleAt_of {i : Income} {x w : Nat}
    (h : Feas i.nonSavings i.savings i.dividends (i.total - i.allowanceUsed) x w) :
    i.feasibleAt ((x : Int), (w : Int)) = true := by
  have := allowanceUsed_le i
  unfold Feas at h
  unfold Income.feasibleAt
  simp only [Bool.and_eq_true, decide_eq_true_eq]
  generalize i.total = t at *
  generalize i.allowanceUsed = u at *
  omega

theorem taxWith_allocAt {i : Income} {x w : Nat}
    (h : Feas i.nonSavings i.savings i.dividends (i.total - i.allowanceUsed) x w) :
    taxWith i (i.allocAt ((x : Int), (w : Int)))
      = G (savingsAllowanceFor (i.total - i.allowanceUsed)) (i.total - i.allowanceUsed) x w := by
  have := allowanceUsed_le i
  unfold taxWith Income.allocAt
  dsimp only
  unfold Feas at h
  rw [← taxOnStep3_eq_G (by omega) h.2.2.2.2]
  generalize i.total = t at *
  generalize i.allowanceUsed = u at *
  have h1 : i.nonSavings - (↑i.nonSavings - (x : Int)).toNat = x := by omega
  have h2 : i.savings - (↑i.savings - ((w : Int) - ↑x)).toNat = w - x := by omega
  have h3 : i.dividends - (↑i.dividends - ((↑t - ↑u : Int) - ↑w)).toNat = (t - u) - w := by omega
  rw [h1, h2, h3]

theorem taxWith_eq_G {i : Income} {a : Alloc} (ha : a.Feasible i) :
    Feas i.nonSavings i.savings i.dividends (i.total - i.allowanceUsed)
        (i.nonSavings - a.toNonSavings) (i.nonSavings - a.toNonSavings + (i.savings - a.toSavings))
      ∧ taxWith i a = G (savingsAllowanceFor (i.total - i.allowanceUsed))
          (i.total - i.allowanceUsed) (i.nonSavings - a.toNonSavings)
          (i.nonSavings - a.toNonSavings + (i.savings - a.toSavings)) := by
  have htot : i.total = i.nonSavings + i.savings + i.dividends := rfl
  unfold Alloc.Feasible at ha
  have hU := allowanceUsed_le i
  have hF : Feas i.nonSavings i.savings i.dividends (i.total - i.allowanceUsed)
      (i.nonSavings - a.toNonSavings) (i.nonSavings - a.toNonSavings + (i.savings - a.toSavings)) := by
    unfold Feas
    generalize i.total = t at *
    generalize i.allowanceUsed = u at *
    omega
  refine ⟨hF, ?_⟩
  rw [← taxOnStep3_eq_G hF.2.1 hF.2.2.2.2]
  unfold taxWith
  generalize i.total = t at *
  generalize i.allowanceUsed = u at *
  congr 1 <;> omega

/-- Unfold a line list into a disjunction of equations. -/
macro "lines" : tactic => `(tactic| (
  simp only [Income.xLines, Income.wLines, Income.diagLines, List.mem_cons, List.mem_nil_iff,
    or_false]))

theorem mem_candidates {i : Income} {x w : Nat}
    (h : Cand i.nonSavings i.savings i.dividends (i.total - i.allowanceUsed)
      (savingsAllowanceFor (i.total - i.allowanceUsed)) x w) :
    ((x : Int), (w : Int)) ∈ i.candidates := by
  have := allowanceUsed_le i
  unfold Income.candidates
  rcases h with ⟨hx, hw⟩ | ⟨hx, e, he, hwe⟩ | ⟨hw, e, he, hwe⟩
  · refine List.mem_append_left _ (List.mem_append_left _
      (List.mem_flatMap.2 ⟨x, ?_, List.mem_map.2 ⟨w, ?_, rfl⟩⟩))
    · unfold XLine at hx; lines
      generalize savingsAllowanceFor (i.total - i.allowanceUsed) = A at *
      omega
    · unfold WLine at hw; lines
      generalize savingsAllowanceFor (i.total - i.allowanceUsed) = A at *
      generalize i.total = t at *
      generalize i.allowanceUsed = u at *
      omega
  · refine List.mem_append_left _ (List.mem_append_right _
      (List.mem_flatMap.2 ⟨x, ?_, List.mem_map.2 ⟨(e : Int), ?_, by rw [hwe]; simp⟩⟩))
    · unfold XLine at hx; lines
      generalize savingsAllowanceFor (i.total - i.allowanceUsed) = A at *
      omega
    · unfold DLine at he; lines
      generalize savingsAllowanceFor (i.total - i.allowanceUsed) = A at *
      omega
  · refine List.mem_append_right _
      (List.mem_flatMap.2 ⟨w, ?_, List.mem_map.2 ⟨(e : Int), ?_, ?_⟩⟩)
    · unfold WLine at hw; lines
      generalize savingsAllowanceFor (i.total - i.allowanceUsed) = A at *
      generalize i.total = t at *
      generalize i.allowanceUsed = u at *
      omega
    · unfold DLine at he; lines
      generalize savingsAllowanceFor (i.total - i.allowanceUsed) = A at *
      omega
    · rw [hwe]; simp

/-! ## The search -/

/-- One step of the search in `Income.bestAlloc`. -/
def searchStep (i : Income) (best : Alloc) (p : Int × Int) : Alloc :=
  if i.feasibleAt p then
    let a := i.allocAt p
    if taxWith i a < taxWith i best then a else best
  else best

theorem bestAlloc_eq (i : Income) : i.bestAlloc = i.candidates.foldl (searchStep i) i.inOrder :=
  rfl

/-- The search's result has no more tax than where it started, or than any
feasible candidate it looked at. -/
theorem foldl_best (i : Income) (l : List (Int × Int)) (b : Alloc) :
    taxWith i (l.foldl (searchStep i) b) ≤ taxWith i b ∧
      ∀ p ∈ l, i.feasibleAt p = true →
        taxWith i (l.foldl (searchStep i) b) ≤ taxWith i (i.allocAt p) := by
  induction l generalizing b with
  | nil => exact ⟨Nat.le_refl _, fun _ h => nomatch h⟩
  | cons p ps ih =>
    obtain ⟨ih1, ih2⟩ := ih (searchStep i b p)
    have hstep : taxWith i (searchStep i b p) ≤ taxWith i b := by
      unfold searchStep
      split
      · dsimp only; split
        · omega
        · exact Nat.le_refl _
      · exact Nat.le_refl _
    refine ⟨Nat.le_trans ih1 hstep, fun q hq hfq => ?_⟩
    rcases List.mem_cons.1 hq with rfl | hq
    · refine Nat.le_trans ih1 ?_
      unfold searchStep
      simp only [hfq, ite_true]
      split
      · exact Nat.le_refl _
      · omega
    · exact ih2 q hq hfq

/-- **The search finds the least tax.** `taxExact i` is the least Step 4 tax over
every legal way of deducting the allowance (ITA 2007 s25(2)). -/
theorem isLeastTax_taxExact (i : Income) : IsLeastTax i (taxExact i) := by
  refine ⟨⟨_, bestAlloc_feasible i, rfl⟩, fun a ha => ?_⟩
  obtain ⟨hF, hG⟩ := taxWith_eq_G ha
  obtain ⟨x', w', hF', hc, hle⟩ := exists_cand (A := savingsAllowanceFor (i.total - i.allowanceUsed)) hF
  have hbest := (foldl_best i i.candidates i.inOrder).2 _ (mem_candidates hc) (feasibleAt_of hF')
  rw [taxWith_allocAt hF', ← bestAlloc_eq] at hbest
  unfold taxExact
  rw [hG]
  exact Nat.le_trans hbest hle

/-- **Monotonicity of the computed liability.** `liability` never goes down when
any kind of income (non-savings, savings or dividends) goes up. -/
theorem liability_mono {i i' : Income} (h : i.Le i') : liability i ≤ liability i' :=
  liability_mono_of_optimal isLeastTax_taxExact h

end UkTax
