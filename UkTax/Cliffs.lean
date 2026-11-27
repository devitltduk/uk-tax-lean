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
most `TaxParams.maxStep` of income tax (`taxExact_succ_le`; 0.686p for 2026-27,
the worst case being basic-rate pay inside the starting rate for savings band
with dividends crossing bands above it) and at most `TaxParams.nicStep` of NICs
(0.08p), so net income rises by at least `Regime.minGain` (0.234p).

Everything here holds for every parameter set meeting `TaxParams.Valid`, with the
steps as formulas in the figures (`PaStep`, `HicbcStep`); the 2026-27 figures
above are the default set.
-/

namespace UkTax

/-! ## The rate at a point of the bands -/

/-- The rate on the penny of Step 3 income just above position `y`. -/
def rateAt (r : Rates) (rg : Regime) (y : Nat) : Nat :=
  if y < rg.brl then r.basic else if y < rg.hrl then r.higher else r.additional

/-- The Scottish rate on the penny of non-savings income just above position `y`. -/
def scotRateAt (rg : Regime) (y : Nat) : Nat := rg.params.scotRate rg.relief y

/-- The non-savings rate on the penny just above position `y`. -/
def nsRateAt (rg : Regime) (y : Nat) : Nat :=
  if rg.scottish then scotRateAt rg y else rateAt rg.params.nsRates rg y

/-- The UK band of position `y`: 0 basic, 1 higher, 2 additional. -/
def bandOf (rg : Regime) (y : Nat) : Nat :=
  if y < rg.brl then 0 else if y < rg.hrl then 1 else 2

theorem rateAt_eq (r : Rates) (rg : Regime) (y : Nat) : rateAt r rg y = r.at (bandOf rg y) := by
  unfold rateAt bandOf
  split
  · rfl
  · split <;> rfl

theorem bandOf_le (rg : Regime) (y : Nat) : bandOf rg y ≤ 2 := by
  unfold bandOf; split <;> (try split) <;> omega

theorem bandOf_mono {rg : Regime} (hBH : rg.params.brl ≤ rg.params.hrl) {y y' : Nat} (h : y ≤ y') :
    bandOf rg y ≤ bandOf rg y' := by
  have : rg.brl ≤ rg.hrl := by unfold Regime.brl Regime.hrl; omega
  unfold bandOf; repeat' split
  all_goals omega

theorem bandTax_succ (r : Rates) {rg : Regime} (hBH : rg.params.brl ≤ rg.params.hrl) (y : Nat) :
    bandTax r rg (y + 1) = bandTax r rg y + rateAt r rg y := by
  have hBH' : rg.brl ≤ rg.hrl := by unfold Regime.brl Regime.hrl; omega
  unfold bandTax rateAt
  by_cases h1 : y < rg.brl
  · simp only [h1, ↓reduceIte]
    rw [show min (y + 1) rg.brl = min y rg.brl + 1 by omega,
      show min (y + 1) rg.hrl - rg.brl = min y rg.hrl - rg.brl by omega,
      show y + 1 - rg.hrl = y - rg.hrl by omega, Nat.mul_add, Nat.mul_one]
    omega
  · by_cases h2 : y < rg.hrl
    · simp only [h1, h2, ↓reduceIte]
      rw [show min (y + 1) rg.brl = min y rg.brl by omega,
        show min (y + 1) rg.hrl - rg.brl = (min y rg.hrl - rg.brl) + 1 by omega,
        show y + 1 - rg.hrl = y - rg.hrl by omega, Nat.mul_add r.higher, Nat.mul_one]
      omega
    · simp only [h1, h2, ↓reduceIte]
      rw [show min (y + 1) rg.brl = min y rg.brl by omega,
        show min (y + 1) rg.hrl - rg.brl = min y rg.hrl - rg.brl by omega,
        show y + 1 - rg.hrl = (y - rg.hrl) + 1 by omega, Nat.mul_add r.additional, Nat.mul_one]
      omega

/-- What lies above a limit grows by the coefficient once the limit is passed. -/
theorem mul_sub_succ (c y l : Nat) : c * (y + 1 - l) = c * (y - l) + (if l ≤ y then c else 0) := by
  split
  · rw [show y + 1 - l = (y - l) + 1 by omega, Nat.mul_add, Nat.mul_one]
  · rw [show y + 1 - l = y - l by omega, Nat.add_zero]

theorem scotTax_succ (rg : Regime) (y : Nat) : scotTax rg (y + 1) = scotTax rg y + scotRateAt rg y := by
  unfold scotTax scotRateAt TaxParams.scotRate
  dsimp only
  rw [mul_sub_succ _ y, mul_sub_succ _ y, mul_sub_succ _ y, mul_sub_succ _ y, mul_sub_succ _ y,
    Nat.mul_add, Nat.mul_one]
  omega

theorem nsTax_succ {rg : Regime} (hBH : rg.params.brl ≤ rg.params.hrl) (y : Nat) :
    nsTax rg (y + 1) = nsTax rg y + nsRateAt rg y := by
  unfold nsTax nsRateAt
  split
  · exact scotTax_succ rg y
  · exact bandTax_succ _ hBH y

theorem ite_le_self (p : Prop) [Decidable p] (c : Nat) : (if p then c else 0) ≤ c := by
  split <;> omega

/-- A Scottish rate rise applying at `x` below `lim + relief` applies below `lim`. -/
theorem ite_below {l r x lim c : Nat} (h : x < lim + r) :
    (if l + r ≤ x then c else 0) ≤ (if l + 1 ≤ lim then c else 0) := by
  split <;> split <;> omega

theorem scotRate_le_below (P : TaxParams) (hP : P.Valid) {relief x lim : Nat} (h : x < lim + relief) :
    P.scotRate relief x ≤ P.scotBelow lim := by
  unfold TaxParams.scotRate TaxParams.scotBelow
  have := hP.scStarterBasic
  have h0 : P.scStarterRate + (if P.scStarterLimit ≤ x then P.scBasicRate - P.scStarterRate else 0)
      ≤ P.scBasicRate := by split <;> omega
  have := ite_below (l := P.scBasicLimit) (c := P.scIntermediateRate - P.scBasicRate) h
  have := ite_below (l := P.scIntermediateLimit) (c := P.scHigherRate - P.scIntermediateRate) h
  have := ite_below (l := P.scHigherLimit) (c := P.scAdvancedRate - P.scHigherRate) h
  have := ite_below (l := P.scAdvancedLimit) (c := P.scTopRate - P.scAdvancedRate) h
  omega

theorem scotRate_le_top (P : TaxParams) (hP : P.Valid) (relief x : Nat) :
    P.scotRate relief x ≤ P.scTopRate := by
  unfold TaxParams.scotRate
  have := hP.scStarterBasic; have := hP.scBasicIntermediate; have := hP.scIntermediateHigher
  have := hP.scHigherAdvanced; have := hP.scAdvancedTop
  have := ite_le_self (P.scStarterLimit ≤ x) (P.scBasicRate - P.scStarterRate)
  have := ite_le_self (P.scBasicLimit + relief ≤ x) (P.scIntermediateRate - P.scBasicRate)
  have := ite_le_self (P.scIntermediateLimit + relief ≤ x) (P.scHigherRate - P.scIntermediateRate)
  have := ite_le_self (P.scHigherLimit + relief ≤ x) (P.scAdvancedRate - P.scHigherRate)
  have := ite_le_self (P.scAdvancedLimit + relief ≤ x) (P.scTopRate - P.scAdvancedRate)
  omega

theorem scotBelow_le_top (P : TaxParams) (hP : P.Valid) (lim : Nat) : P.scotBelow lim ≤ P.scTopRate := by
  unfold TaxParams.scotBelow
  have := hP.scBasicIntermediate; have := hP.scIntermediateHigher
  have := hP.scHigherAdvanced; have := hP.scAdvancedTop
  have := ite_le_self (P.scBasicLimit + 1 ≤ lim) (P.scIntermediateRate - P.scBasicRate)
  have := ite_le_self (P.scIntermediateLimit + 1 ≤ lim) (P.scHigherRate - P.scIntermediateRate)
  have := ite_le_self (P.scHigherLimit + 1 ≤ lim) (P.scAdvancedRate - P.scHigherRate)
  have := ite_le_self (P.scAdvancedLimit + 1 ≤ lim) (P.scTopRate - P.scAdvancedRate)
  omega

/-- The non-savings rate at `x` is at most the cap for its UK band. -/
theorem nsRateAt_le_cap {rg : Regime} (hP : rg.params.Valid) (x : Nat) :
    nsRateAt rg x ≤ rg.params.nsCap rg.scottish (bandOf rg x) := by
  unfold nsRateAt TaxParams.nsCap
  cases hs : rg.scottish
  · simp only [Bool.false_eq_true, ↓reduceIte]
    rw [rateAt_eq]; exact Nat.le_refl _
  · simp only [↓reduceIte]
    unfold scotRateAt bandOf
    by_cases h1 : x < rg.brl
    · simp only [h1, ↓reduceIte]
      exact scotRate_le_below _ hP (by unfold Regime.brl at h1; omega)
    · by_cases h2 : x < rg.hrl
      · simp only [h1, h2, ↓reduceIte]
        exact scotRate_le_below _ hP (by unfold Regime.hrl at h2; omega)
      · simp only [h1, h2, ↓reduceIte]
        exact scotRate_le_top _ hP _ _

/-- Below the starting rate limit for savings, the non-savings rate is at most
`nsCapLow`. -/
theorem nsRateAt_le_capLow {rg : Regime} (hP : rg.params.Valid) {x : Nat} (hx : x < rg.params.srls) :
    nsRateAt rg x ≤ rg.params.nsCapLow rg.scottish := by
  unfold nsRateAt TaxParams.nsCapLow
  cases rg.scottish
  · simp only [Bool.false_eq_true, ↓reduceIte]
    unfold rateAt TaxParams.ukRate Regime.brl Regime.hrl
    have := hP.nsOrdered.1; have := hP.nsOrdered.2
    repeat' split
    all_goals omega
  · simp only [↓reduceIte]
    unfold scotRateAt TaxParams.scotRate
    have := hP.scStarterBasic
    have k1 : (if rg.params.scStarterLimit ≤ x then rg.params.scBasicRate - rg.params.scStarterRate else 0)
        ≤ (if rg.params.scStarterLimit ≤ rg.params.srls - 1
            then rg.params.scBasicRate - rg.params.scStarterRate else 0) := by
      split <;> split <;> omega
    have k (l c : Nat) : (if l + rg.relief ≤ x then c else 0)
        ≤ (if l + 0 ≤ rg.params.srls - 1 then c else 0) := by split <;> split <;> omega
    have := k rg.params.scBasicLimit (rg.params.scIntermediateRate - rg.params.scBasicRate)
    have := k rg.params.scIntermediateLimit (rg.params.scHigherRate - rg.params.scIntermediateRate)
    have := k rg.params.scHigherLimit (rg.params.scAdvancedRate - rg.params.scHigherRate)
    have := k rg.params.scAdvancedLimit (rg.params.scTopRate - rg.params.scAdvancedRate)
    omega

/-- Enumerate a band index. -/
theorem band_cases {k : Nat} (h : k ≤ 2) : k = 0 ∨ k = 1 ∨ k = 2 := by omega

/-- The bound when the penny is below the starting rate limit for savings: a penny
of savings leaves the starting rate for band `kw` and a penny of dividends moves
from band `kld` to band `kT`. -/
theorem caseA_le {P : TaxParams} (hP : P.Valid) (sc : Bool) {kw kld kT : Nat} (h1 : kw ≤ kld)
    (h2 : kld ≤ kT) (h3 : kT ≤ 2) :
    P.nsCapLow sc + P.savRates.at kw + P.divRates.at kT ≤ P.maxStep sc + P.divRates.at kld := by
  have := hP.savOrdered.1; have := hP.savOrdered.2; have := hP.divOrdered.1; have := hP.divOrdered.2
  obtain ⟨m1, m2, m3, -⟩ := P.maxStep_ge sc
  generalize P.maxStep sc = M at *
  generalize P.nsCapLow sc = L at *
  rcases band_cases (Nat.le_trans h1 (Nat.le_trans h2 h3)) with rfl | rfl | rfl <;>
  rcases band_cases (Nat.le_trans h2 h3) with rfl | rfl | rfl <;>
  rcases band_cases h3 with rfl | rfl | rfl <;>
  simp only [Rates.at_zero, Rates.at_one, Rates.at_two] <;> omega

/-- The bound otherwise: non-savings in band `kx`, the taxed savings slice moving
from band `klo` to `kw` at its ends, the taxed dividends from `kld` to `kT`. -/
theorem caseB_le {P : TaxParams} (hP : P.Valid) (sc : Bool) {kx klo kw kld kT : Nat} (h0 : kx ≤ klo)
    (h1 : klo ≤ kw) (h2 : kw ≤ kld) (h3 : kld ≤ kT) (h4 : kT ≤ 2) :
    P.nsCap sc kx + P.savRates.at kw + P.divRates.at kT
      ≤ P.maxStep sc + P.savRates.at klo + P.divRates.at kld := by
  have := hP.savOrdered.1; have := hP.savOrdered.2; have := hP.divOrdered.1; have := hP.divOrdered.2
  obtain ⟨-, -, -, m4, m5, m6, m7, m8, m9⟩ := P.maxStep_ge sc
  generalize P.maxStep sc = M at *
  rcases band_cases (by omega : kx ≤ 2) with rfl | rfl | rfl <;>
  rcases band_cases (by omega : klo ≤ 2) with rfl | rfl | rfl <;>
  rcases band_cases (by omega : kw ≤ 2) with rfl | rfl | rfl <;>
  rcases band_cases (by omega : kld ≤ 2) with rfl | rfl | rfl <;>
  rcases band_cases h4 with rfl | rfl | rfl <;>
  (try omega) <;>
  (simp only [Rates.at_zero, Rates.at_one, Rates.at_two]; omega)

/-- The most income tax a penny more non-savings income can add, with both
allowances fixed, in 1/10 000 pence: `TaxParams.maxStep`, 0.686p for 2026-27, or
0.706p for a Scottish taxpayer (`Regime.maxStep_y2026`). -/
def Regime.maxStep (rg : Regime) : Nat := rg.params.maxStep rg.scottish

theorem Regime.maxStep_y2026 {rg : Regime} (h : rg.params = .y2026) :
    rg.maxStep = if rg.scottish then 7060 else 6860 := by
  unfold Regime.maxStep; rw [h, TaxParams.maxStep_y2026]

/-! ## One penny more non-savings income, allowances fixed -/

/-- With the allowances fixed, moving a share's non-savings income, its top and
the total all up by one penny adds at most `rg.maxStep` of tax. For any figures
meeting `TaxParams.Valid`. -/
theorem G_succ_le {rg : Regime} (hP : rg.params.Valid) {A T x w : Nat} (hxw : x ≤ w) (hwT : w ≤ T) :
    G rg A (T + 1) (x + 1) (w + 1) ≤ G rg A T x w + rg.maxStep := by
  have hBH := hP.brlHrl
  -- the bottom of the taxed savings moves up by 0 or 1; if 0, `x` is below the
  -- starting rate limit (or no savings are taxed)
  have hlo : (loSav rg A (x + 1) (w + 1) = loSav rg A x w ∧
        (x < rg.params.srls ∨ loSav rg A x w = w + 1)) ∨
      (loSav rg A (x + 1) (w + 1) = loSav rg A x w + 1 ∧ x ≤ loSav rg A x w) := by
    unfold loSav; omega
  have hlow : loSav rg A x w ≤ w := loSav_le rg A x w
  have hlodw : w ≤ loDiv rg T w ∧ loDiv rg T w ≤ T := by unfold loDiv; omega
  have m1 := bandTax_le rg.params.savRates rg (loSav_le rg A x w)
  have m2 := bandTax_le rg.params.divRates rg (loDiv_le (rg := rg) hwT)
  have m3 := bandTax_le rg.params.savRates rg (loSav_le rg A (x + 1) (w + 1))
  have m4 := bandTax_le rg.params.divRates rg (loDiv_le (rg := rg) (T := T + 1) (w := w + 1) (by omega))
  have e1 := nsTax_succ hBH x
  have e2 := bandTax_succ rg.params.savRates hBH w
  have e4 := bandTax_succ rg.params.divRates hBH T
  have e5 : bandTax rg.params.divRates rg (loDiv rg (T + 1) (w + 1))
      = bandTax rg.params.divRates rg (loDiv rg T w) + rateAt rg.params.divRates rg (loDiv rg T w) := by
    have : loDiv rg (T + 1) (w + 1) = loDiv rg T w + 1 := by unfold loDiv; omega
    rw [this]; exact bandTax_succ _ hBH _
  have k1 := Nat.sub_add_cancel m1
  have k2 := Nat.sub_add_cancel m2
  have k3 := Nat.sub_add_cancel m3
  have k4 := Nat.sub_add_cancel m4
  have bw := bandOf_mono hBH (show w ≤ loDiv rg T w from hlodw.1)
  have bT := bandOf_mono hBH (show loDiv rg T w ≤ T from hlodw.2)
  have bT2 := bandOf_le rg T
  rw [rateAt_eq] at e2 e4 e5
  rcases hlo with ⟨h, h'⟩ | ⟨h, h'⟩
  · have hx : x < rg.params.srls := by omega
    have hA := caseA_le hP rg.scottish bw bT bT2
    have hns := nsRateAt_le_capLow hP hx
    unfold G Regime.maxStep
    rw [h]
    generalize loSav rg A x w = lo at *
    generalize loDiv rg (T + 1) (w + 1) = ld' at *
    generalize loDiv rg T w = ld at *
    omega
  · have e3 : bandTax rg.params.savRates rg (loSav rg A (x + 1) (w + 1))
        = bandTax rg.params.savRates rg (loSav rg A x w)
          + rg.params.savRates.at (bandOf rg (loSav rg A x w)) := by
      rw [h, bandTax_succ _ hBH, rateAt_eq]
    have hB := caseB_le hP rg.scottish (bandOf_mono hBH h') (bandOf_mono hBH hlow) bw bT bT2
    have hns := nsRateAt_le_cap hP x
    unfold G Regime.maxStep
    generalize loSav rg A (x + 1) (w + 1) = lo' at *
    generalize loSav rg A x w = lo at *
    generalize loDiv rg (T + 1) (w + 1) = ld' at *
    generalize loDiv rg T w = ld at *
    omega

/-- The Step 3 allowances move only with the s35 personal allowance. -/
theorem personalAllowance_congr {rg : Regime} {n s d : Nat}
    (hPA : personalAllowanceFor rg.params (n + 1 + s + d - rg.step2 - rg.relief)
      = personalAllowanceFor rg.params (n + s + d - rg.step2 - rg.relief)) :
    Income.personalAllowance rg ⟨n + 1, s, d⟩ = Income.personalAllowance rg ⟨n, s, d⟩ := by
  unfold Income.personalAllowance Income.ani Income.total
  rw [hPA]

/-- No income, no tax. -/
theorem taxOnStep3_zero (rg : Regime) : taxOnStep3 rg 0 0 0 = 0 := by
  unfold taxOnStep3 sliceTax nsTax
  split <;> simp [scotTax, bandTax]

/-- The personal savings allowance a taxpayer gets. -/
def Income.psa (rg : Regime) (i : Income) : Nat :=
  savingsAllowanceFor rg (i.total - i.allowanceUsed rg)

/-- Step 3 income in all. -/
def Income.step3 (rg : Regime) (i : Income) : Nat := i.total - i.allowanceUsed rg

/-- **Marginal income tax rate between steps.** If a penny more non-savings income
changes neither the personal allowance nor the personal savings allowance, it adds
at most 0.686p of income tax (with s25(2) placement on both sides). -/
theorem taxExact_succ_le {rg : Regime} (hP : rg.params.Valid) {n s d : Nat}
    (hPA : personalAllowanceFor rg.params (n + 1 + s + d - rg.step2 - rg.relief)
      = personalAllowanceFor rg.params (n + s + d - rg.step2 - rg.relief))
    (hPSA : Income.psa rg ⟨n + 1, s, d⟩ = Income.psa rg ⟨n, s, d⟩) :
    taxExact rg ⟨n + 1, s, d⟩ ≤ taxExact rg ⟨n, s, d⟩ + rg.maxStep := by
  have hopt := (isLeastTax_taxExact hP.brlHrl ⟨n + 1, s, d⟩).2
  have htot : Income.total ⟨n + 1, s, d⟩ = n + 1 + s + d := rfl
  have htot0 : Income.total ⟨n, s, d⟩ = n + s + d := rfl
  have hPA' : Income.personalAllowance rg ⟨n + 1, s, d⟩ = Income.personalAllowance rg ⟨n, s, d⟩ :=
    personalAllowance_congr hPA
  by_cases hfull : Income.personalAllowance rg ⟨n, s, d⟩ ≤ n + s + d
  · -- the whole allowance is used on both sides: keep the same share
    have ha := bestAlloc_feasible rg ⟨n, s, d⟩
    unfold taxExact
    generalize Income.bestAlloc rg ⟨n, s, d⟩ = a at ha ⊢
    have hU : Income.allowanceUsed rg ⟨n, s, d⟩ = Income.personalAllowance rg ⟨n, s, d⟩ := by
      unfold Income.allowanceUsed; rw [htot0]
      generalize Income.personalAllowance rg ⟨n, s, d⟩ = P at *; omega
    have hU' : Income.allowanceUsed rg ⟨n + 1, s, d⟩ = Income.personalAllowance rg ⟨n, s, d⟩ := by
      unfold Income.allowanceUsed; rw [htot, hPA']
      generalize Income.personalAllowance rg ⟨n, s, d⟩ = P at *; omega
    have hfa : a.toNonSavings ≤ n ∧ a.toSavings ≤ s ∧ a.toDividends ≤ d ∧
        a.toNonSavings + a.toSavings + a.toDividends = Income.personalAllowance rg ⟨n, s, d⟩ := by
      have := ha; unfold Alloc.Feasible at this; rw [hU] at this; exact this
    have ha' : a.Feasible rg ⟨n + 1, s, d⟩ := by
      unfold Alloc.Feasible; rw [hU']
      exact ⟨by simp only; omega, hfa.2.1, hfa.2.2.1, hfa.2.2.2⟩
    obtain ⟨hF, hG⟩ := taxWith_eq_G ha
    obtain ⟨_, hG'⟩ := taxWith_eq_G ha'
    have h1 := hopt a ha'
    rw [hG'] at h1
    rw [hG]
    have hA : savingsAllowanceFor rg (Income.total ⟨n + 1, s, d⟩ - Income.allowanceUsed rg ⟨n + 1, s, d⟩)
        = savingsAllowanceFor rg (Income.total ⟨n, s, d⟩ - Income.allowanceUsed rg ⟨n, s, d⟩) := hPSA
    have hT : Income.total ⟨n + 1, s, d⟩ - Income.allowanceUsed rg ⟨n + 1, s, d⟩
        = Income.total ⟨n, s, d⟩ - Income.allowanceUsed rg ⟨n, s, d⟩ + 1 := by
      rw [htot, htot0, hU, hU']; omega
    rw [hA, hT] at h1
    simp only at h1 hF ⊢
    have hx : n + 1 - a.toNonSavings + (s - a.toSavings)
        = n - a.toNonSavings + (s - a.toSavings) + 1 := by omega
    have hx' : n + 1 - a.toNonSavings = n - a.toNonSavings + 1 := by omega
    rw [hx, hx'] at h1
    unfold Feas at hF
    exact Nat.le_trans h1 (G_succ_le hP hF.2.1 hF.2.2.2.2)
  · -- all income is covered by the allowance on both sides: no tax
    have h0 : taxWith rg ⟨n + 1, s, d⟩ (Income.inOrder rg ⟨n + 1, s, d⟩) = 0 := by
      have hU' : Income.allowanceUsed rg ⟨n + 1, s, d⟩ = n + 1 + s + d := by
        unfold Income.allowanceUsed; rw [htot, hPA']
        generalize Income.personalAllowance rg ⟨n, s, d⟩ = P at *; omega
      unfold taxWith Income.inOrder
      rw [hU']
      simp only
      have e1 : n + 1 - min (n + 1 + s + d) (n + 1) = 0 := by omega
      have e2 : s - min (n + 1 + s + d - (n + 1)) s = 0 := by omega
      have e3 : d - min (n + 1 + s + d - (n + 1) - s) d = 0 := by omega
      rw [e1, e2, e3]
      exact taxOnStep3_zero rg
    have := hopt _ (inOrder_feasible rg _)
    omega

/-! ## Step 6 between steps -/

/-- The most the married couple's allowance reduction can fall for a penny more
income, in 1/10 000 pence: 10 % of half a penny, 0.05p, while it tapers. -/
def Regime.mcaStep (rg : Regime) : Nat := if rg.mca then 500 else 0

theorem mcaReduction_succ (rg : Regime) (n s d : Nat) :
    Income.mcaReduction rg ⟨n, s, d⟩ ≤ Income.mcaReduction rg ⟨n + 1, s, d⟩ + rg.mcaStep := by
  unfold Income.mcaReduction Regime.mcaStep Income.ani Income.total mcaRate mcaMin mcaMax
    mcaIncomeLimit
  dsimp only
  split <;> omega

/-- With the allowances and the Marriage Allowance reduction unchanged, a penny
more non-savings income adds at most `rg.maxStep + rg.mcaStep` to the liability
after Step 6. -/
theorem finalTaxExact_succ_le {rg : Regime} (hP : rg.params.Valid) {n s d : Nat}
    (hPA : personalAllowanceFor rg.params (n + 1 + s + d - rg.step2 - rg.relief)
      = personalAllowanceFor rg.params (n + s + d - rg.step2 - rg.relief))
    (hPSA : Income.psa rg ⟨n + 1, s, d⟩ = Income.psa rg ⟨n, s, d⟩)
    (hMA : Income.maReduction rg ⟨n + 1, s, d⟩ = Income.maReduction rg ⟨n, s, d⟩) :
    finalTaxExact rg ⟨n + 1, s, d⟩ ≤ finalTaxExact rg ⟨n, s, d⟩ + rg.maxStep + rg.mcaStep := by
  have h1 := taxExact_succ_le hP hPA hPSA
  have h2 := mcaReduction_succ rg n s d
  unfold finalTaxExact
  rw [hMA]
  omega

/-- Below the Marriage Allowance limit (and the basic rate limit) the rate test is
passed: with no Step 3 income above it, nothing is charged above the basic rate (or
the Scottish intermediate rate). For 2026-27 the Marriage Allowance limit is the
lower of the two. -/
theorem maOk_of_step3_le {rg : Regime} {i : Income} (h : i.step3 rg ≤ min rg.maLimit rg.brl) :
    i.maOk rg = true := by
  have ha := bestAlloc_feasible rg i
  have hU := allowanceUsed_le rg i
  unfold Income.step3 at h
  unfold Alloc.Feasible at ha
  unfold Income.maOk maRateTest
  generalize i.bestAlloc rg = a at *
  have ht : i.total = i.nonSavings + i.savings + i.dividends := rfl
  simp only [Bool.and_eq_true, Bool.or_eq_true, decide_eq_true_eq, beq_iff_eq]
  generalize i.allowanceUsed rg = u at *
  generalize i.total = t at *
  refine ⟨⟨by omega, Or.inl (by omega)⟩, Or.inr (by omega)⟩

/-- With pay (or other non-savings income) only, the rate test is exactly Step 3
income at most the Marriage Allowance limit. Step 3 income never falls as income
rises, so for such a recipient the reduction is lost at one penny, the crossing
of the limit, which is how the cliff map finds it. -/
theorem maOk_payOnly (rg : Regime) (g : Nat) :
    Income.maOk rg ⟨g, 0, 0⟩ = true ↔ Income.step3 rg ⟨g, 0, 0⟩ ≤ rg.maLimit := by
  have ha := bestAlloc_feasible rg ⟨g, 0, 0⟩
  unfold Income.maOk maRateTest
  unfold Income.step3
  unfold Alloc.Feasible at ha
  generalize Income.bestAlloc rg ⟨g, 0, 0⟩ = a at *
  have ht : Income.total ⟨g, 0, 0⟩ = g + 0 + 0 := rfl
  simp only [Bool.and_eq_true, Bool.or_eq_true, decide_eq_true_eq, beq_iff_eq]
  dsimp only at *
  generalize Income.allowanceUsed rg ⟨g, 0, 0⟩ = u at *
  constructor
  · intro h; omega
  · intro h; exact ⟨⟨by omega, Or.inr (by omega)⟩, Or.inl (by omega)⟩

/-- Step 3 income never falls as non-savings income rises. -/
theorem step3_succ_ge (rg : Regime) (n s d : Nat) :
    Income.step3 rg ⟨n, s, d⟩ ≤ Income.step3 rg ⟨n + 1, s, d⟩ := by
  unfold Income.step3 Income.allowanceUsed Income.total
  have := personalAllowanceFor_anti rg.params (x := n + s + d - rg.step2 - rg.relief)
    (x' := n + 1 + s + d - rg.step2 - rg.relief) (by omega)
  unfold Income.personalAllowance Income.ani Income.total
  generalize personalAllowanceFor rg.params (n + s + d - rg.step2 - rg.relief) = A at *
  generalize personalAllowanceFor rg.params (n + 1 + s + d - rg.step2 - rg.relief) = A' at *
  generalize (if rg.maTransfer = true then maTransferable else 0) = m
  generalize (if rg.blind = true then blindPersonsAllowance else 0) = b
  dsimp only at *
  omega

/-- **The Marriage Allowance step.** If a penny more non-savings income changes the
Marriage Allowance reduction, Step 3 income after that penny is above the
Marriage Allowance limit (the basic rate limit, or the top of the Scottish
intermediate rate) or the basic rate limit: below both the recipient keeps the
£252. -/
theorem maStep_above_limit {rg : Regime} {n s d : Nat}
    (h : Income.maReduction rg ⟨n + 1, s, d⟩ ≠ Income.maReduction rg ⟨n, s, d⟩) :
    min rg.maLimit rg.brl < Income.step3 rg ⟨n + 1, s, d⟩ := by
  apply Nat.lt_of_not_le
  intro hle
  have hmono := step3_succ_ge rg n s d
  have h1 := maOk_of_step3_le (i := ⟨n + 1, s, d⟩) hle
  have h0 := maOk_of_step3_le (i := ⟨n, s, d⟩) (Nat.le_trans hmono hle)
  apply h
  unfold Income.maReduction
  rw [h1, h0]

/-! ## Net income -/

/-- Net income, in 1/10 000 pence, for pay `g` (all of it employment income, after
any net pay pension contributions) with savings interest `s`, dividends `d` and
Child Benefit `cb`, paid per period `p`: gross income less income tax (after the
Step 6 reductions), employee NICs (on pay before net pay contributions) and the
High Income Child Benefit Charge (on adjusted net income), plus Child Benefit.
Gift Aid and pension contributions, being fixed, are left out: they move net
income by a constant. -/
def net (p : EarningsPeriod) (cb : Nat) (rg : Regime) (s d g : Nat) : Int :=
  10_000 * ((g + s + d : Nat) : Int) + 10_000 * (cb : Int) - (finalTaxExact rg ⟨g, s, d⟩ : Int)
    - (nicExact rg.params p (g + rg.netPay) : Int)
    - 10_000 * (hicbc rg.params (g + s + d - rg.step2 - rg.relief) cb : Int)

/-- The least net income gained from a penny more pay between steps, in 1/10 000
pence: a penny less the most income tax (`Regime.maxStep`), the most the married
couple's allowance can taper (`Regime.mcaStep`) and NICs (`TaxParams.nicStep`) it can
cost. For 2026-27 0.234p, or 0.214p for a Scottish taxpayer, 0.05p less with the
married couple's allowance (`Regime.minGain_y2026`). -/
def Regime.minGain (rg : Regime) : Nat := 10_000 - rg.maxStep - rg.mcaStep - rg.params.nicStep

theorem Regime.minGain_eq {rg : Regime} (hP : rg.params.Valid) :
    rg.minGain + rg.maxStep + rg.mcaStep + rg.params.nicStep = 10_000 := by
  have := hP.marginalUk; have := hP.marginalScot
  unfold Regime.minGain Regime.maxStep Regime.mcaStep mcaStepMax at *
  cases rg.scottish <;> cases rg.mca <;> simp <;> omega

theorem Regime.minGain_y2026 {rg : Regime} (h : rg.params = .y2026) :
    rg.minGain = (if rg.scottish then 2140 else 2340) - (if rg.mca then 500 else 0) := by
  unfold Regime.minGain Regime.mcaStep
  rw [Regime.maxStep_y2026 h, h]
  cases rg.scottish <;> cases rg.mca <;> decide

/-- Between steps, net income never falls: if a penny more pay changes neither
allowance nor the charge, net income rises by at least `rg.minGain`. -/
theorem net_succ_ge {p : EarningsPeriod} {cb : Nat} {rg : Regime} (hP : rg.params.Valid) {s d g : Nat}
    (hPA : personalAllowanceFor rg.params (g + 1 + s + d - rg.step2 - rg.relief)
      = personalAllowanceFor rg.params (g + s + d - rg.step2 - rg.relief))
    (hPSA : Income.psa rg ⟨g + 1, s, d⟩ = Income.psa rg ⟨g, s, d⟩)
    (hMA : Income.maReduction rg ⟨g + 1, s, d⟩ = Income.maReduction rg ⟨g, s, d⟩)
    (hC : hicbc rg.params (g + 1 + s + d - rg.step2 - rg.relief) cb
      = hicbc rg.params (g + s + d - rg.step2 - rg.relief) cb) :
    net p cb rg s d g + rg.minGain ≤ net p cb rg s d (g + 1) := by
  have h1 := finalTaxExact_succ_le hP hPA hPSA hMA
  have h2 := nicExact_succ_le rg.params p (g + rg.netPay)
  rw [show g + rg.netPay + 1 = g + 1 + rg.netPay by omega] at h2
  have h3 := Regime.minGain_eq hP
  unfold net
  rw [hC]
  omega

/-! ## The steps -/

/-- Adjusted net income `t + 1` is above the income limit, at most the limit plus
twice the allowance, and leaves twice the reduced allowance a whole multiple of
£2: one penny more from `t` and the personal allowance (rounded up to a whole
pound) falls by £1. For 2026-27: a multiple of £2 in (£100,000, £125,140]
(`paStep_y2026`). -/
def PaStep (P : TaxParams) (t : Nat) : Prop :=
  P.paLimit < t + 1 ∧ t + 1 ≤ P.paLimit + 2 * P.pa ∧ (2 * P.pa + P.paLimit - (t + 1)) % 200 = 0

/-- Adjusted net income `t + 1` is the threshold plus a whole number, 1 to 100,
of steps: one penny more from `t` and the charge goes up 1 %. For 2026-27: a
multiple of £200 from £60,200 to £80,000 (`hicbcStep_y2026`). -/
def HicbcStep (P : TaxParams) (t : Nat) : Prop :=
  P.cbThreshold + P.cbStep ≤ t + 1 ∧ t + 1 ≤ P.cbThreshold + 100 * P.cbStep ∧
    P.cbStep ∣ t + 1 - P.cbThreshold

theorem paStep_y2026 (t : Nat) :
    PaStep .y2026 t ↔ 10_000_000 < t + 1 ∧ (t + 1) % 200 = 0 ∧ t + 1 ≤ 12_514_000 := by
  unfold PaStep TaxParams.y2026 personalAllowance paIncomeLimit
  dsimp only
  omega

theorem hicbcStep_y2026 (t : Nat) :
    HicbcStep .y2026 t ↔ 6_020_000 ≤ t + 1 ∧ t + 1 ≤ 8_000_000 ∧ (t + 1) % 20_000 = 0 := by
  unfold HicbcStep TaxParams.y2026 hicbcThreshold hicbcStep
  dsimp only
  omega

theorem personalAllowanceFor_succ (P : TaxParams) (t : Nat) :
    personalAllowanceFor P (t + 1) = personalAllowanceFor P t ∨ PaStep P t := by
  unfold personalAllowanceFor PaStep
  dsimp only
  omega

theorem hicbcPercent_succ (P : TaxParams) (t : Nat) :
    hicbcPercent P (t + 1) = hicbcPercent P t ∨ HicbcStep P t := by
  unfold hicbcPercent
  by_cases hlt : t + 1 ≤ P.cbThreshold
  · left; rw [show t + 1 - P.cbThreshold = t - P.cbThreshold by omega]
  have ha : t + 1 - P.cbThreshold = (t - P.cbThreshold) + 1 := by omega
  rw [ha, Nat.succ_div]
  by_cases hd : P.cbStep ∣ t - P.cbThreshold + 1
  · simp only [hd, ↓reduceIte]
    by_cases hm : 100 ≤ (t - P.cbThreshold) / P.cbStep
    · left; omega
    · right
      have hpos : P.cbStep ≤ t - P.cbThreshold + 1 := Nat.le_of_dvd (by omega) hd
      have heq := Nat.div_mul_cancel hd
      rw [Nat.succ_div] at heq; simp only [hd, ↓reduceIte] at heq
      have : ((t - P.cbThreshold) / P.cbStep + 1) * P.cbStep ≤ 100 * P.cbStep :=
        Nat.mul_le_mul_right _ (by omega)
      refine ⟨by omega, by omega, ?_⟩
      rw [ha]; exact hd
  · left; simp only [hd, ↓reduceIte, Nat.add_zero]

theorem hicbc_succ (P : TaxParams) (t cb : Nat) :
    hicbc P (t + 1) cb = hicbc P t cb ∨ HicbcStep P t := by
  unfold hicbc
  rcases hicbcPercent_succ P t with h | h
  · left; rw [h]
  · right; exact h

theorem psa_succ {rg : Regime} {n s d : Nat}
    (hPA : personalAllowanceFor rg.params (n + 1 + s + d - rg.step2 - rg.relief)
      = personalAllowanceFor rg.params (n + s + d - rg.step2 - rg.relief)) :
    Income.psa rg ⟨n + 1, s, d⟩ = Income.psa rg ⟨n, s, d⟩ ∨
      Income.step3 rg ⟨n, s, d⟩ = rg.brl ∨ Income.step3 rg ⟨n, s, d⟩ = rg.hrl := by
  have hPA' : Income.personalAllowance rg ⟨n + 1, s, d⟩
      = Income.personalAllowance rg ⟨n, s, d⟩ := personalAllowance_congr hPA
  unfold Income.psa Income.step3 Income.allowanceUsed
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

/-- A penny more pay changes the Marriage Allowance reduction: the recipient fails
the rate test (s55B(2)(b), (ba)), losing £252 at once. `maStep_above_limit` shows
this happens only with Step 3 income above the basic rate limit, or for a Scottish
taxpayer above the top of the intermediate rate. -/
def MaStep (rg : Regime) (s d g : Nat) : Prop :=
  Income.maReduction rg ⟨g + 1, s, d⟩ ≠ Income.maReduction rg ⟨g, s, d⟩

/-- One penny more income moves adjusted net income up one penny, or (while the
reliefs exceed income) leaves it at nil. Either way the allowance and the charge
change only at a step of adjusted net income. -/
theorem ani_succ (rg : Regime) (t : Nat) :
    t + 1 - rg.step2 - rg.relief = (t - rg.step2 - rg.relief) + 1 ∨
      (t + 1 - rg.step2 - rg.relief = 0 ∧ t - rg.step2 - rg.relief = 0) := by
  omega

/-- A penny more income changes the personal allowance only at a `PaStep` of
adjusted net income, and the charge only at a `HicbcStep` (with some Child
Benefit). -/
theorem allowances_succ (rg : Regime) (cb t : Nat) :
    (personalAllowanceFor rg.params (t + 1 - rg.step2 - rg.relief)
        = personalAllowanceFor rg.params (t - rg.step2 - rg.relief) ∧
      hicbc rg.params (t + 1 - rg.step2 - rg.relief) cb
        = hicbc rg.params (t - rg.step2 - rg.relief) cb) ∨
      PaStep rg.params (t - rg.step2 - rg.relief) ∨
      (0 < cb ∧ HicbcStep rg.params (t - rg.step2 - rg.relief)) := by
  rcases ani_succ rg t with ha | ⟨ha, hb⟩
  · rw [ha]
    rcases personalAllowanceFor_succ rg.params (t - rg.step2 - rg.relief) with hPA | hPA
    · rcases hicbc_succ rg.params (t - rg.step2 - rg.relief) cb with hc | hc
      · exact Or.inl ⟨hPA, hc⟩
      · by_cases hcb : cb = 0
        · left; subst hcb; unfold hicbc; simp [hPA]
        · exact Or.inr (Or.inr ⟨by omega, hc⟩)
    · exact Or.inr (Or.inl hPA)
  · left; rw [ha, hb]; exact ⟨rfl, rfl⟩

/-- **Where net income can fall.** If a penny more pay lowers net income, then at
that penny the personal allowance falls by £1, the charge goes up 1 % (with some
Child Benefit), or Step 3 income passes the basic or the higher rate limit (where
the personal savings allowance falls), or a Marriage Allowance recipient fails the
rate test (above the basic rate limit); the allowance and the charge step with
adjusted net income, and the limits are raised by Gift Aid and pension
contributions relieved at source. This holds for every pay, savings, dividends,
Child Benefit, pay period, reliefs, Scottish taxpayers, and every parameter set
meeting `TaxParams.Valid`. -/
theorem net_drop_only_at_steps (p : EarningsPeriod) (cb : Nat) {rg : Regime} (hP : rg.params.Valid)
    (s d g : Nat) (h : net p cb rg s d (g + 1) < net p cb rg s d g) :
    PaStep rg.params (g + s + d - rg.step2 - rg.relief) ∨
      (0 < cb ∧ HicbcStep rg.params (g + s + d - rg.step2 - rg.relief)) ∨
      Income.step3 rg ⟨g, s, d⟩ = rg.brl ∨ Income.step3 rg ⟨g, s, d⟩ = rg.hrl ∨
      MaStep rg s d g := by
  by_cases hMA : MaStep rg s d g
  · exact Or.inr (Or.inr (Or.inr (Or.inr hMA)))
  unfold MaStep at hMA
  have hMA : Income.maReduction rg ⟨g + 1, s, d⟩ = Income.maReduction rg ⟨g, s, d⟩ :=
    Classical.not_not.mp hMA
  have hA := allowances_succ rg cb (g + s + d)
  rw [show g + s + d + 1 = g + 1 + s + d by omega] at hA
  rcases hA with ⟨hPA, hC⟩ | hA
  · rcases psa_succ hPA with hPSA | hT | hT
    · have := net_succ_ge (p := p) hP hPA hPSA hMA hC
      omega
    · exact Or.inr (Or.inr (Or.inl hT))
    · exact Or.inr (Or.inr (Or.inr (Or.inl hT)))
  · rcases hA with hA | hA
    · exact Or.inl hA
    · exact Or.inr (Or.inl hA)

end UkTax
