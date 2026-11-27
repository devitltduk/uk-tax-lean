import UkTax.Proofs

/-!
# The corner search finds the least tax

Main result: `isLeastTax_taxExact`, `∀ i, IsLeastTax i (taxExact i)`. The allowance
share that `Income.bestAlloc` picks gives the least Step 4 tax over every legal
share, so the computed liability is the s25(2) liability. With `leastTax_mono`
this makes the computed `liability` monotone in every kind of income
(`liability_mono`), for every parameter set meeting `TaxParams.Valid`.

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

/-! ## `bandTax` and `nsTax` at three evenly spaced points -/

/-- `x` is one of the non-savings limits (`nsLimits`): a UK rate limit or a
Scottish one. -/
def NsLine (rg : Regime) (x : Nat) : Prop :=
  x = rg.brl ∨ x = rg.hrl ∨ x = rg.params.scStarterLimit ∨ x = rg.params.scBasicLimit + rg.relief ∨
    x = rg.params.scIntermediateLimit + rg.relief ∨ x = rg.params.scHigherLimit + rg.relief ∨
    x = rg.params.scAdvancedLimit + rg.relief

/-- `a ≤ b ≤ c` evenly spaced, with no UK rate limit strictly between `a` and `c`. -/
def Even3 (rg : Regime) (a b c : Nat) : Prop :=
  a ≤ b ∧ a + c = 2 * b ∧ (c ≤ rg.brl ∨ rg.brl ≤ a) ∧ (c ≤ rg.hrl ∨ rg.hrl ≤ a)

/-- The same, with no Scottish limit strictly between `a` and `c` either. -/
def Even3NS (rg : Regime) (a b c : Nat) : Prop :=
  Even3 rg a b c ∧ (c ≤ rg.params.scStarterLimit ∨ rg.params.scStarterLimit ≤ a) ∧
    (c ≤ rg.params.scBasicLimit + rg.relief ∨ rg.params.scBasicLimit + rg.relief ≤ a) ∧
    (c ≤ rg.params.scIntermediateLimit + rg.relief ∨ rg.params.scIntermediateLimit + rg.relief ≤ a) ∧
    (c ≤ rg.params.scHigherLimit + rg.relief ∨ rg.params.scHigherLimit + rg.relief ≤ a) ∧
    (c ≤ rg.params.scAdvancedLimit + rg.relief ∨ rg.params.scAdvancedLimit + rg.relief ≤ a)

/-- A product with a fixed rate is linear on three evenly spaced points. -/
theorem mul_even3 (r : Nat) {A B C : Nat} (h : A + C = 2 * B) : r * A + r * C = 2 * (r * B) := by
  rw [← Nat.mul_add, h, Nat.mul_left_comm]

theorem bandTax_even3 (r : Rates) {rg : Regime} (hBH : rg.params.brl ≤ rg.params.hrl) {a b c : Nat}
    (h : Even3 rg a b c) :
    bandTax r rg a + bandTax r rg c = 2 * bandTax r rg b := by
  unfold Even3 at h
  have hBH : rg.brl ≤ rg.hrl := by unfold Regime.brl Regime.hrl; omega
  have f1 := mul_even3 r.basic (show min a rg.brl + min c rg.brl = 2 * min b rg.brl by omega)
  have f2 := mul_even3 r.higher (show (min a rg.hrl - rg.brl) + (min c rg.hrl - rg.brl)
      = 2 * (min b rg.hrl - rg.brl) by omega)
  have f3 := mul_even3 r.additional (show (a - rg.hrl) + (c - rg.hrl) = 2 * (b - rg.hrl) by omega)
  unfold bandTax
  omega

/-- What lies above a limit is linear on three evenly spaced points not straddling it. -/
theorem sub_even3 {a b c l : Nat} (h1 : a ≤ b) (h2 : a + c = 2 * b) (h : c ≤ l ∨ l ≤ a) :
    (a - l) + (c - l) = 2 * (b - l) := by
  omega

theorem nsTax_even3 {rg : Regime} (hBH : rg.params.brl ≤ rg.params.hrl) {a b c : Nat}
    (h : Even3NS rg a b c) :
    nsTax rg a + nsTax rg c = 2 * nsTax rg b := by
  unfold nsTax
  split
  · obtain ⟨⟨h1, h2, _, _⟩, k1, k2, k3, k4, k5⟩ := h
    have t0 := mul_even3 rg.params.scStarterRate h2
    have t1 := mul_even3 (rg.params.scBasicRate - rg.params.scStarterRate) (sub_even3 h1 h2 k1)
    have t2 := mul_even3 (rg.params.scIntermediateRate - rg.params.scBasicRate) (sub_even3 h1 h2 k2)
    have t3 := mul_even3 (rg.params.scHigherRate - rg.params.scIntermediateRate) (sub_even3 h1 h2 k3)
    have t4 := mul_even3 (rg.params.scAdvancedRate - rg.params.scHigherRate) (sub_even3 h1 h2 k4)
    have t5 := mul_even3 (rg.params.scTopRate - rg.params.scAdvancedRate) (sub_even3 h1 h2 k5)
    unfold scotTax
    dsimp only
    omega
  · exact bandTax_even3 rg.params.nsRates hBH h.1

/-! ## Step 4 tax at a point `(x, w)` -/

/-- Bottom of the savings taxed at 20 / 40 / 45 %: above the non-savings income `x`,
the starting rate for savings and the savings allowance `A`, capped at `w`. -/
def loSav (rg : Regime) (A x w : Nat) : Nat := min w (max x rg.params.srls + A)

/-- Bottom of the dividends taxed at 10.75 / 35.75 / 39.35 %: above the dividend
allowance, capped at `T`. -/
def loDiv (rg : Regime) (T w : Nat) : Nat := w + min (T - w) rg.params.divAllowance

/-- Step 4 tax, in 1/10 000 pence, when `x` non-savings income and `w - x` savings
are left after the allowance, out of `T` in all, with savings allowance `A`. -/
def G (rg : Regime) (A T x w : Nat) : Nat :=
  nsTax rg x
    + (bandTax rg.params.savRates rg w - bandTax rg.params.savRates rg (loSav rg A x w))
    + (bandTax rg.params.divRates rg T - bandTax rg.params.divRates rg (loDiv rg T w))

theorem taxOnStep3_eq_G (rg : Regime) {x w T : Nat} (hxw : x ≤ w) (hwT : w ≤ T) :
    taxOnStep3 rg x (w - x) (T - w) = G rg (savingsAllowanceFor rg T) T x w := by
  have h1 : x + (w - x) = w := by omega
  have h2 : x + (w - x) + (T - w) = T := by omega
  have h3 : x + startingRateSavings rg x (w - x) + savingsNilRate rg x (w - x) (T - w)
      = loSav rg (savingsAllowanceFor rg T) x w := by
    unfold savingsNilRate startingRateSavings loSav
    rw [h2]
    omega
  have h4 : x + (w - x) + dividendNilRate rg (T - w) = loDiv rg T w := by
    unfold dividendNilRate loDiv
    omega
  unfold taxOnStep3 sliceTax G
  rw [h3, h4, h2, h1]

/-! ## Where `G` is linear -/

theorem even3_x {rg : Regime} {x : Nat} (h0 : 0 < x) (h1 : x ≠ rg.brl) (h2 : x ≠ rg.hrl) :
    Even3 rg (x - 1) x (x + 1) := by
  unfold Even3; omega

theorem even3ns_x {rg : Regime} {x : Nat} (h0 : 0 < x) (h : ¬ NsLine rg x) :
    Even3NS rg (x - 1) x (x + 1) := by
  unfold NsLine at h; unfold Even3NS Even3; omega

theorem even3_loSav_x {rg : Regime} {A x w : Nat} (h0 : 0 < x) (h1 : x ≠ rg.params.srls)
    (h2 : x + A ≠ rg.brl) (h3 : x + A ≠ rg.hrl) (h4 : x + A ≠ w) :
    Even3 rg (loSav rg A (x - 1) w) (loSav rg A x w) (loSav rg A (x + 1) w) := by
  unfold Even3 loSav; omega

theorem even3_loSav_w_const {rg : Regime} {A c w : Nat} (h0 : 0 < w) (h1 : w ≠ rg.brl)
    (h2 : w ≠ rg.hrl) (h3 : w ≠ rg.params.srls + A) (h4 : w ≠ c + A) :
    Even3 rg (loSav rg A c (w - 1)) (loSav rg A c w) (loSav rg A c (w + 1)) := by
  unfold Even3 loSav; omega

theorem even3_loSav_w_diag {rg : Regime} {A e w : Nat} (he : e + 1 ≤ w) (h1 : w ≠ rg.brl)
    (h2 : w ≠ rg.hrl) (h3 : w ≠ rg.params.srls + A)
    (h4 : w ≠ rg.params.srls + e) (h5 : w + A ≠ rg.brl + e)
    (h6 : w + A ≠ rg.hrl + e) :
    Even3 rg (loSav rg A (w - 1 - e) (w - 1)) (loSav rg A (w - e) w) (loSav rg A (w + 1 - e) (w + 1)) := by
  unfold Even3 loSav; omega

theorem even3_loDiv {rg : Regime} {T w : Nat} (h0 : 0 < w) (hwT : w + 1 ≤ T)
    (h1 : w + rg.params.divAllowance ≠ T) (h2 : w + rg.params.divAllowance ≠ rg.brl)
    (h3 : w + rg.params.divAllowance ≠ rg.hrl) :
    Even3 rg (loDiv rg T (w - 1)) (loDiv rg T w) (loDiv rg T (w + 1)) := by
  unfold Even3 loDiv; omega

theorem loSav_le (rg : Regime) (A x w : Nat) : loSav rg A x w ≤ w := by unfold loSav; omega

theorem loDiv_le {rg : Regime} {T w : Nat} (h : w ≤ T) : loDiv rg T w ≤ T := by unfold loDiv; omega

/-- Bends of `G` along `x` (with `w` fixed). -/
def BendX (rg : Regime) (A w x : Nat) : Prop :=
  x = rg.params.srls ∨ NsLine rg x ∨
    x + A = rg.brl ∨ x + A = rg.hrl ∨ x + A = w

/-- Bends of `G` along `w` with `x = c` fixed. -/
def BendWConst (rg : Regime) (A T c w : Nat) : Prop :=
  w = rg.brl ∨ w = rg.hrl ∨ w = rg.params.srls + A ∨ w = c + A ∨
    w + rg.params.divAllowance = T ∨ w + rg.params.divAllowance = rg.brl ∨
    w + rg.params.divAllowance = rg.hrl

/-- Bends of `G` along `w` with `w - x = e` fixed. -/
def BendWDiag (rg : Regime) (A T e w : Nat) : Prop :=
  NsLine rg (w - e) ∨ w = rg.brl ∨ w = rg.hrl ∨
    w = rg.params.srls + e ∨ w = rg.params.srls + A ∨
    w + A = rg.brl + e ∨ w + A = rg.hrl + e ∨
    w + rg.params.divAllowance = T ∨ w + rg.params.divAllowance = rg.brl ∨
    w + rg.params.divAllowance = rg.hrl

theorem G_affine_x {rg : Regime} (hBH : rg.params.brl ≤ rg.params.hrl) {A T x w : Nat} (h0 : 0 < x) (_hxw : x + 1 ≤ w) (hwT : w ≤ T)
    (hB : ¬ BendX rg A w x) :
    G rg A T (x - 1) w + G rg A T (x + 1) w = 2 * G rg A T x w := by
  unfold BendX at hB
  have e1 := nsTax_even3 hBH (even3ns_x h0 (fun h => hB (Or.inr (Or.inl h))))
  have e2 := bandTax_even3 rg.params.savRates hBH
    (even3_loSav_x (A := A) (w := w) h0 (by omega) (by omega) (by omega) (by omega))
  have := bandTax_le rg.params.savRates rg (loSav_le rg A (x - 1) w)
  have := bandTax_le rg.params.savRates rg (loSav_le rg A x w)
  have := bandTax_le rg.params.savRates rg (loSav_le rg A (x + 1) w)
  have := bandTax_le rg.params.divRates rg (loDiv_le (rg := rg) hwT)
  unfold G
  omega

theorem G_affine_w_const {rg : Regime} (hBH : rg.params.brl ≤ rg.params.hrl) {A T c w : Nat} (hc : c + 1 ≤ w) (hwT : w + 1 ≤ T)
    (hB : ¬ BendWConst rg A T c w) :
    G rg A T c (w - 1) + G rg A T c (w + 1) = 2 * G rg A T c w := by
  unfold BendWConst at hB
  have e1 := bandTax_even3 rg.params.savRates hBH (even3_x (x := w) (by omega) (by omega) (by omega))
  have e2 := bandTax_even3 rg.params.savRates hBH
    (even3_loSav_w_const (A := A) (c := c) (w := w) (by omega) (by omega) (by omega) (by omega)
      (by omega))
  have e3 := bandTax_even3 rg.params.divRates hBH
    (even3_loDiv (T := T) (w := w) (by omega) hwT (by omega) (by omega) (by omega))
  have := bandTax_le rg.params.savRates rg (loSav_le rg A c (w - 1))
  have := bandTax_le rg.params.savRates rg (loSav_le rg A c w)
  have := bandTax_le rg.params.savRates rg (loSav_le rg A c (w + 1))
  have := bandTax_le rg.params.divRates rg (loDiv_le (rg := rg) (T := T) (w := w - 1) (by omega))
  have := bandTax_le rg.params.divRates rg (loDiv_le (rg := rg) (T := T) (w := w) (by omega))
  have := bandTax_le rg.params.divRates rg (loDiv_le (rg := rg) (T := T) (w := w + 1) (by omega))
  unfold G
  omega

theorem G_affine_w_diag {rg : Regime} (hBH : rg.params.brl ≤ rg.params.hrl) {A T e w : Nat} (he : e + 1 ≤ w) (hwT : w + 1 ≤ T)
    (hB : ¬ BendWDiag rg A T e w) :
    G rg A T (w - 1 - e) (w - 1) + G rg A T (w + 1 - e) (w + 1) = 2 * G rg A T (w - e) w := by
  unfold BendWDiag at hB
  have h1 : Even3NS rg (w - 1 - e) (w - e) (w + 1 - e) := by
    have hn : ¬ NsLine rg (w - e) := fun h => hB (Or.inl h)
    unfold NsLine at hn; unfold Even3NS Even3; omega
  have e1 := nsTax_even3 hBH h1
  have e2 := bandTax_even3 rg.params.savRates hBH (even3_x (x := w) (by omega) (by omega) (by omega))
  have e3 := bandTax_even3 rg.params.savRates hBH
    (even3_loSav_w_diag (A := A) (e := e) (w := w) he (by omega) (by omega) (by omega)
      (by omega) (by omega) (by omega))
  have e4 := bandTax_even3 rg.params.divRates hBH
    (even3_loDiv (T := T) (w := w) (by omega) hwT (by omega) (by omega) (by omega))
  have := bandTax_le rg.params.savRates rg (loSav_le rg A (w - 1 - e) (w - 1))
  have := bandTax_le rg.params.savRates rg (loSav_le rg A (w - e) w)
  have := bandTax_le rg.params.savRates rg (loSav_le rg A (w + 1 - e) (w + 1))
  have := bandTax_le rg.params.divRates rg (loDiv_le (rg := rg) (T := T) (w := w - 1) (by omega))
  have := bandTax_le rg.params.divRates rg (loDiv_le (rg := rg) (T := T) (w := w) (by omega))
  have := bandTax_le rg.params.divRates rg (loDiv_le (rg := rg) (T := T) (w := w + 1) (by omega))
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
def XLine (rg : Regime) (N A x : Nat) : Prop :=
  x = 0 ∨ x = N ∨ x = rg.params.srls ∨ x + A = rg.brl ∨ x + A = rg.hrl ∨
    NsLine rg x

/-- A constant-`w` line of the search (`Income.wLines`). -/
def WLine (rg : Regime) (D T A w : Nat) : Prop :=
  w = T ∨ w + D = T ∨ w = rg.params.srls ∨ w = rg.params.srls + A ∨
    w = rg.brl ∨ w = rg.hrl ∨ w + rg.params.divAllowance = T ∨
    w + rg.params.divAllowance = rg.brl ∨ w + rg.params.divAllowance = rg.hrl

/-- A constant-`(w - x)` line of the search (`Income.diagLines`). -/
def DLine (S A e : Nat) : Prop := e = 0 ∨ e = S ∨ e = A

/-- A crossing of two lines, as `Income.candidates` lists them. -/
def Cand (rg : Regime) (N S D T A x w : Nat) : Prop :=
  (XLine rg N A x ∧ WLine rg D T A w) ∨ (XLine rg N A x ∧ ∃ e, DLine S A e ∧ w = x + e) ∨
    (WLine rg D T A w ∧ ∃ e, DLine S A e ∧ w = x + e)

theorem cand_const {rg : Regime} {N S D T A y w' : Nat} (hx : XLine rg N A y)
    (hwB : w' = max (T - D) y ∨ w' = min T (y + S) ∨ BendWConst rg A T y w') :
    Cand rg N S D T A y w' := by
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

theorem cand_diag {rg : Regime} {N S D T A e w' : Nat} (he : DLine S A e)
    (hw1 : max e (T - D) ≤ w') (hw2 : w' ≤ min T (N + e))
    (hwB : w' = max e (T - D) ∨ w' = min T (N + e) ∨ BendWDiag rg A T e w') :
    Cand rg N S D T A (w' - e) w' := by
  unfold BendWDiag at hwB
  by_cases hd : w' = e ∨ w' = N + e ∨ NsLine rg (w' - e) ∨
      w' = rg.params.srls + e ∨ w' + A = rg.brl + e ∨ w' + A = rg.hrl + e
  · refine Or.inr (Or.inl ⟨?_, e, he, by omega⟩)
    unfold XLine
    rcases hd with h | h | h | h | h | h
    · pick
    · pick
    · exact Or.inr (Or.inr (Or.inr (Or.inr (Or.inr h))))
    · pick
    · pick
    · pick
  · refine Or.inr (Or.inr ⟨?_, e, he, by omega⟩)
    unfold WLine
    rcases hwB with h | h | h | h | h | h | h | h | h | h | h | h
    · pick
    · pick
    · exact absurd (Or.inr (Or.inr (Or.inl h))) hd
    all_goals pick

-- `G` is opaque here: `omega` only needs its values as atoms.
attribute [local irreducible] G in
/-- Every legal share has a crossing of two lines with no more tax. -/
theorem exists_cand {rg : Regime} (hBH : rg.params.brl ≤ rg.params.hrl) {N S D T A x w : Nat} (h : Feas N S D T x w) :
    ∃ x' w', Feas N S D T x' w' ∧ Cand rg N S D T A x' w' ∧ G rg A T x' w' ≤ G rg A T x w := by
  obtain ⟨hxN, hxw, hwS, hTD, hwT⟩ := h
  -- Step 1: along `x`, with `w` fixed.
  obtain ⟨y, hy1, hy2, hyB, hyle⟩ :=
    exists_min_at_bend (fun x => G rg A T x w) (BendX rg A w) (lo := w - S) (hi := min N w)
      (fun x h1 h2 hB => G_affine_x hBH (by omega) (by omega) hwT hB) (z := x) (by omega) (by omega)
  -- `y` is on a constant-`x` line, or on a constant-`(w - x)` line.
  have hform : XLine rg N A y ∨ ∃ e, DLine S A e ∧ e ≤ S ∧ y + e = w := by
    unfold BendX at hyB
    by_cases hd : (S ≤ w ∧ y = w - S) ∨ y = w ∨ y + A = w
    · right
      rcases hd with ⟨_, hd⟩ | hd | hd
      · exact ⟨S, Or.inr (Or.inl rfl), Nat.le_refl _, by omega⟩
      · exact ⟨0, Or.inl rfl, Nat.zero_le _, by omega⟩
      · exact ⟨A, Or.inr (Or.inr rfl), by omega, hd⟩
    · left; unfold XLine
      rcases hyB with h | h | h | h | h | h | h
      · omega
      · omega
      · omega
      · exact Or.inr (Or.inr (Or.inr (Or.inr (Or.inr h))))
      · omega
      · omega
      · omega
  rcases hform with hx | ⟨e, he, heS, hye⟩
  · -- Step 2: along `w`, with `x = y` fixed.
    obtain ⟨w', hw1, hw2, hwB, hwle⟩ :=
      exists_min_at_bend (fun w => G rg A T y w) (BendWConst rg A T y)
        (lo := max (T - D) y) (hi := min T (y + S))
        (fun w h1 h2 hB => G_affine_w_const hBH (by omega) (by omega) hB) (z := w)
        (by omega) (by omega)
    refine ⟨y, w', ⟨by omega, by omega, by omega, by omega, by omega⟩, ?_,
      Nat.le_trans hwle hyle⟩
    exact cand_const hx hwB
  · -- Step 2: along `w`, with `w - x = e` fixed.
    obtain ⟨w', hw1, hw2, hwB, hwle⟩ :=
      exists_min_at_bend (fun w => G rg A T (w - e) w) (BendWDiag rg A T e)
        (lo := max e (T - D)) (hi := min T (N + e))
        (fun w h1 h2 hB => G_affine_w_diag hBH (by omega) (by omega) hB) (z := w)
        (by omega) (by omega)
    have hyw : w - e = y := by omega
    simp only [hyw] at hwle
    refine ⟨w' - e, w', ⟨by omega, by omega, by omega, by omega, by omega⟩, ?_,
      Nat.le_trans hwle hyle⟩
    exact cand_diag he hw1 hw2 hwB

/-! ## Back to `Income` -/

theorem allowanceUsed_le (rg : Regime) (i : Income) : i.allowanceUsed rg ≤ i.total := by
  unfold Income.allowanceUsed; omega

theorem feasibleAt_of {rg : Regime} {i : Income} {x w : Nat}
    (h : Feas i.nonSavings i.savings i.dividends (i.total - i.allowanceUsed rg) x w) :
    i.feasibleAt rg ((x : Int), (w : Int)) = true := by
  have := allowanceUsed_le rg i
  unfold Feas at h
  unfold Income.feasibleAt
  simp only [Bool.and_eq_true, decide_eq_true_eq]
  generalize i.total = t at *
  generalize i.allowanceUsed rg = u at *
  omega

theorem taxWith_allocAt {rg : Regime} {i : Income} {x w : Nat}
    (h : Feas i.nonSavings i.savings i.dividends (i.total - i.allowanceUsed rg) x w) :
    taxWith rg i (i.allocAt rg ((x : Int), (w : Int)))
      = G rg (savingsAllowanceFor rg (i.total - i.allowanceUsed rg))
          (i.total - i.allowanceUsed rg) x w := by
  have := allowanceUsed_le rg i
  unfold taxWith Income.allocAt
  dsimp only
  unfold Feas at h
  rw [← taxOnStep3_eq_G rg (by omega) h.2.2.2.2]
  generalize i.total = t at *
  generalize i.allowanceUsed rg = u at *
  have h1 : i.nonSavings - (↑i.nonSavings - (x : Int)).toNat = x := by omega
  have h2 : i.savings - (↑i.savings - ((w : Int) - ↑x)).toNat = w - x := by omega
  have h3 : i.dividends - (↑i.dividends - ((↑t - ↑u : Int) - ↑w)).toNat = (t - u) - w := by omega
  rw [h1, h2, h3]

theorem taxWith_eq_G {rg : Regime} {i : Income} {a : Alloc} (ha : a.Feasible rg i) :
    Feas i.nonSavings i.savings i.dividends (i.total - i.allowanceUsed rg)
        (i.nonSavings - a.toNonSavings) (i.nonSavings - a.toNonSavings + (i.savings - a.toSavings))
      ∧ taxWith rg i a = G rg (savingsAllowanceFor rg (i.total - i.allowanceUsed rg))
          (i.total - i.allowanceUsed rg) (i.nonSavings - a.toNonSavings)
          (i.nonSavings - a.toNonSavings + (i.savings - a.toSavings)) := by
  have htot : i.total = i.nonSavings + i.savings + i.dividends := rfl
  unfold Alloc.Feasible at ha
  have hU := allowanceUsed_le rg i
  have hF : Feas i.nonSavings i.savings i.dividends (i.total - i.allowanceUsed rg)
      (i.nonSavings - a.toNonSavings) (i.nonSavings - a.toNonSavings + (i.savings - a.toSavings)) := by
    unfold Feas
    generalize i.total = t at *
    generalize i.allowanceUsed rg = u at *
    omega
  refine ⟨hF, ?_⟩
  rw [← taxOnStep3_eq_G rg hF.2.1 hF.2.2.2.2]
  unfold taxWith
  generalize i.total = t at *
  generalize i.allowanceUsed rg = u at *
  congr 1 <;> omega

/-- Unfold a line list into a disjunction of equations. -/
macro "lines" : tactic => `(tactic| (
  simp only [Income.xLines, Income.wLines, Income.diagLines, nsLimits, List.map_cons,
    List.map_nil, List.cons_append, List.nil_append, List.mem_cons, List.mem_nil_iff,
    or_false]))

theorem mem_candidates {rg : Regime} {i : Income} {x w : Nat}
    (h : Cand rg i.nonSavings i.savings i.dividends (i.total - i.allowanceUsed rg)
      (savingsAllowanceFor rg (i.total - i.allowanceUsed rg)) x w) :
    ((x : Int), (w : Int)) ∈ i.candidates rg := by
  have := allowanceUsed_le rg i
  unfold Income.candidates
  rcases h with ⟨hx, hw⟩ | ⟨hx, e, he, hwe⟩ | ⟨hw, e, he, hwe⟩
  · refine List.mem_append_left _ (List.mem_append_left _
      (List.mem_flatMap.2 ⟨x, ?_, List.mem_map.2 ⟨w, ?_, rfl⟩⟩))
    · unfold XLine NsLine at hx; lines
      generalize savingsAllowanceFor rg (i.total - i.allowanceUsed rg) = A at *
      rcases hx with h | h | h | h | h | h | h | h | h | h | h | h <;> pick
    · unfold WLine at hw; lines
      generalize savingsAllowanceFor rg (i.total - i.allowanceUsed rg) = A at *
      generalize i.total = t at *
      generalize i.allowanceUsed rg = u at *
      rcases hw with h | h | h | h | h | h | h | h | h <;> pick
  · refine List.mem_append_left _ (List.mem_append_right _
      (List.mem_flatMap.2 ⟨x, ?_, List.mem_map.2 ⟨(e : Int), ?_, by rw [hwe]; simp⟩⟩))
    · unfold XLine NsLine at hx; lines
      generalize savingsAllowanceFor rg (i.total - i.allowanceUsed rg) = A at *
      rcases hx with h | h | h | h | h | h | h | h | h | h | h | h <;> pick
    · unfold DLine at he; lines
      generalize savingsAllowanceFor rg (i.total - i.allowanceUsed rg) = A at *
      omega
  · refine List.mem_append_right _
      (List.mem_flatMap.2 ⟨w, ?_, List.mem_map.2 ⟨(e : Int), ?_, ?_⟩⟩)
    · unfold WLine at hw; lines
      generalize savingsAllowanceFor rg (i.total - i.allowanceUsed rg) = A at *
      generalize i.total = t at *
      generalize i.allowanceUsed rg = u at *
      rcases hw with h | h | h | h | h | h | h | h | h <;> pick
    · unfold DLine at he; lines
      generalize savingsAllowanceFor rg (i.total - i.allowanceUsed rg) = A at *
      omega
    · rw [hwe]; simp

/-! ## The search -/

/-- One step of the search in `Income.bestAlloc`. -/
def searchStep (rg : Regime) (i : Income) (best : Alloc) (p : Int × Int) : Alloc :=
  if i.feasibleAt rg p then
    let a := i.allocAt rg p
    if taxWith rg i a < taxWith rg i best then a else best
  else best

theorem bestAlloc_eq (rg : Regime) (i : Income) :
    i.bestAlloc rg = (i.candidates rg).foldl (searchStep rg i) (i.inOrder rg) :=
  rfl

/-- The search's result has no more tax than where it started, or than any
feasible candidate it looked at. -/
theorem foldl_best (rg : Regime) (i : Income) (l : List (Int × Int)) (b : Alloc) :
    taxWith rg i (l.foldl (searchStep rg i) b) ≤ taxWith rg i b ∧
      ∀ p ∈ l, i.feasibleAt rg p = true →
        taxWith rg i (l.foldl (searchStep rg i) b) ≤ taxWith rg i (i.allocAt rg p) := by
  induction l generalizing b with
  | nil => exact ⟨Nat.le_refl _, fun _ h => nomatch h⟩
  | cons p ps ih =>
    obtain ⟨ih1, ih2⟩ := ih (searchStep rg i b p)
    have hstep : taxWith rg i (searchStep rg i b p) ≤ taxWith rg i b := by
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

/-- **The search finds the least tax.** `taxExact rg i` is the least Step 4 tax over
every legal way of deducting the allowance (ITA 2007 s25(2)). -/
theorem isLeastTax_taxExact {rg : Regime} (hBH : rg.params.brl ≤ rg.params.hrl) (i : Income) : IsLeastTax rg i (taxExact rg i) := by
  refine ⟨⟨_, bestAlloc_feasible rg i, rfl⟩, fun a ha => ?_⟩
  obtain ⟨hF, hG⟩ := taxWith_eq_G ha
  obtain ⟨x', w', hF', hc, hle⟩ :=
    exists_cand hBH (rg := rg) (A := savingsAllowanceFor rg (i.total - i.allowanceUsed rg)) hF
  have hbest :=
    (foldl_best rg i (i.candidates rg) (i.inOrder rg)).2 _ (mem_candidates hc) (feasibleAt_of hF')
  rw [taxWith_allocAt hF', ← bestAlloc_eq] at hbest
  unfold taxExact
  rw [hG]
  exact Nat.le_trans hbest hle

/-- **Monotonicity of the computed liability.** `liability` never goes down when
any kind of income (non-savings, savings or dividends) goes up. -/
theorem liability_mono {rg : Regime} (hP : rg.params.Valid) {i i' : Income} (h : i.Le i') :
    liability rg i ≤ liability rg i' :=
  liability_mono_of_optimal hP (isLeastTax_taxExact hP.brlHrl) h

end UkTax
