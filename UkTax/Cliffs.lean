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
def rateAt (r : Rates) (rg : Regime) (y : Nat) : Nat :=
  if y < rg.brl then r.basic else if y < rg.hrl then r.higher else r.additional

/-- The Scottish rate on the penny of non-savings income just above position `y`. -/
def scotRateAt (rg : Regime) (y : Nat) : Nat :=
  if y < scotStarterLimit then scotStarterRate
  else if y < scotBasicLimit + rg.relief then scotBasicRate
  else if y < scotIntermediateLimit + rg.relief then scotIntermediateRate
  else if y < scotHigherLimit + rg.relief then scotHigherRate
  else if y < scotAdvancedLimit + rg.relief then scotAdvancedRate
  else scotTopRate

/-- The non-savings rate on the penny just above position `y`. -/
def nsRateAt (rg : Regime) (y : Nat) : Nat :=
  if rg.scottish then scotRateAt rg y else rateAt nonSavingsRates rg y

macro "rate_tac" : tactic => `(tactic| (
  unfold bandTax rateAt at *
  (try unfold nonSavingsRates at *)
  (try unfold savingsRates at *)
  (try unfold dividendRates at *)
  unfold Regime.brl Regime.hrl at *
  unfold basicRateLimit higherRateLimit personalAllowance at *
  dsimp only at *
  split <;> (try split) <;> omega))

theorem bandTax_succ_sav (rg : Regime) (y : Nat) :
    bandTax savingsRates rg (y + 1) = bandTax savingsRates rg y + rateAt savingsRates rg y := by
  rate_tac

theorem bandTax_succ_div (rg : Regime) (y : Nat) :
    bandTax dividendRates rg (y + 1) = bandTax dividendRates rg y + rateAt dividendRates rg y := by
  rate_tac

theorem nsTax_succ (rg : Regime) (y : Nat) : nsTax rg (y + 1) = nsTax rg y + nsRateAt rg y := by
  unfold nsTax nsRateAt
  split
  · unfold scotTax scotRateAt scotStarterRate scotBasicRate scotIntermediateRate scotHigherRate
      scotAdvancedRate scotTopRate scotStarterLimit scotBasicLimit scotIntermediateLimit
      scotHigherLimit scotAdvancedLimit
    repeat' split
    all_goals omega
  · rate_tac

/-- Which rate applies where, as a disjunction `omega` can use. -/
theorem rateAt_sav_cases (rg : Regime) (y : Nat) :
    (y < rg.brl ∧ rateAt savingsRates rg y = 2000) ∨
      (rg.brl ≤ y ∧ y < rg.hrl ∧ rateAt savingsRates rg y = 4000) ∨
      (rg.hrl ≤ y ∧ rateAt savingsRates rg y = 4500) := by
  unfold rateAt savingsRates
  dsimp only
  split <;> (try split) <;> omega

theorem rateAt_ns_cases (rg : Regime) (y : Nat) :
    (y < rg.brl ∧ rateAt nonSavingsRates rg y = 2000) ∨
      (rg.brl ≤ y ∧ y < rg.hrl ∧ rateAt nonSavingsRates rg y = 4000) ∨
      (rg.hrl ≤ y ∧ rateAt nonSavingsRates rg y = 4500) := by
  unfold rateAt nonSavingsRates
  dsimp only
  split <;> (try split) <;> omega

theorem rateAt_div_cases (rg : Regime) (y : Nat) :
    (y < rg.brl ∧ rateAt dividendRates rg y = 1075) ∨
      (rg.brl ≤ y ∧ y < rg.hrl ∧ rateAt dividendRates rg y = 3575) ∨
      (rg.hrl ≤ y ∧ rateAt dividendRates rg y = 3935) := by
  unfold rateAt dividendRates
  dsimp only
  split <;> (try split) <;> omega

/-- The Scottish rates, by where `y` is. Only what the marginal-rate bound needs:
below the basic rate limit the rate is at most 21 % until the Scottish higher rate
starts, then 42 %; at or above it, at most 48 %. -/
theorem scotRateAt_cases (rg : Regime) (y : Nat) :
    (y < scotIntermediateLimit + rg.relief ∧ scotRateAt rg y ≤ 2100) ∨
      (scotIntermediateLimit + rg.relief ≤ y ∧ y < scotHigherLimit + rg.relief ∧
        scotRateAt rg y = 4200) ∨
      (scotHigherLimit + rg.relief ≤ y ∧ scotRateAt rg y ≤ 4800) := by
  unfold scotRateAt scotStarterRate scotBasicRate scotIntermediateRate scotHigherRate
    scotAdvancedRate scotTopRate scotStarterLimit scotBasicLimit scotIntermediateLimit
    scotHigherLimit scotAdvancedLimit
  repeat' split
  all_goals omega

/-- The most income tax a penny more non-savings income can add, with both
allowances fixed, in 1/10 000 pence: 0.686p, or 0.706p for a Scottish taxpayer
(`G_succ_le`). -/
def Regime.maxStep (rg : Regime) : Nat := if rg.scottish then 7060 else 6860

/-! ## One penny more non-savings income, allowances fixed -/

set_option maxRecDepth 100000 in
/-- With the allowances fixed, moving a share's non-savings income, its top and
the total all up by one penny adds at most `rg.maxStep` of tax: 0.686p (6,860
ten-thousandths), or 0.706p for a Scottish taxpayer. -/
theorem G_succ_le {rg : Regime} {A T x w : Nat} (hxw : x ≤ w) (hwT : w ≤ T) :
    G rg A (T + 1) (x + 1) (w + 1) ≤ G rg A T x w + rg.maxStep := by
  have hLB : startingRateLimitSavings < rg.brl := by
    unfold startingRateLimitSavings Regime.brl basicRateLimit; omega
  have hBH : rg.brl < rg.hrl := by
    unfold Regime.brl Regime.hrl basicRateLimit higherRateLimit personalAllowance; omega
  have hS : scotIntermediateLimit + rg.relief < rg.brl ∧ rg.brl ≤ scotHigherLimit + rg.relief ∧
      startingRateLimitSavings ≤ scotIntermediateLimit + rg.relief := by
    unfold scotIntermediateLimit scotHigherLimit Regime.brl basicRateLimit
      startingRateLimitSavings; omega
  -- the bottom of the taxed savings moves up by 0 or 1; if 0, `x` is below £5,000
  -- or no savings are taxed
  have hlo : (loSav A (x + 1) (w + 1) = loSav A x w ∧
        (x < startingRateLimitSavings ∨ loSav A x w = w + 1)) ∨
      (loSav A (x + 1) (w + 1) = loSav A x w + 1 ∧ x ≤ loSav A x w) := by
    unfold loSav; omega
  have hlow : loSav A x w ≤ w := loSav_le A x w
  have hlodw : w ≤ loDiv T w ∧ loDiv T w ≤ T := by unfold loDiv; omega
  have m1 := bandTax_le savingsRates rg (loSav_le A x w)
  have m2 := bandTax_le dividendRates rg (loDiv_le hwT)
  have m3 := bandTax_le savingsRates rg (loSav_le A (x + 1) (w + 1))
  have m4 := bandTax_le dividendRates rg (loDiv_le (T := T + 1) (w := w + 1) (by omega))
  have e1 := nsTax_succ rg x
  have e2 := bandTax_succ_sav rg w
  have e3 : (bandTax savingsRates rg (loSav A (x + 1) (w + 1))
        = bandTax savingsRates rg (loSav A x w) ∧
        (x < startingRateLimitSavings ∨ loSav A x w = w + 1)) ∨
      (bandTax savingsRates rg (loSav A (x + 1) (w + 1))
        = bandTax savingsRates rg (loSav A x w) + rateAt savingsRates rg (loSav A x w) ∧
        x ≤ loSav A x w) := by
    rcases hlo with ⟨h, h'⟩ | ⟨h, h'⟩
    · exact Or.inl ⟨by rw [h], h'⟩
    · exact Or.inr ⟨by rw [h]; exact bandTax_succ_sav rg _, h'⟩
  have e4 := bandTax_succ_div rg T
  have e5 : bandTax dividendRates rg (loDiv (T + 1) (w + 1))
      = bandTax dividendRates rg (loDiv T w) + rateAt dividendRates rg (loDiv T w) := by
    have : loDiv (T + 1) (w + 1) = loDiv T w + 1 := by unfold loDiv; omega
    rw [this]; exact bandTax_succ_div rg _
  have k1 := Nat.sub_add_cancel m1
  have k2 := Nat.sub_add_cancel m2
  have k3 := Nat.sub_add_cancel m3
  have k4 := Nat.sub_add_cancel m4
  have r2 := rateAt_sav_cases rg w
  have r3 := rateAt_sav_cases rg (loSav A x w)
  have r4 := rateAt_div_cases rg T
  have r5 := rateAt_div_cases rg (loDiv T w)
  unfold G
  generalize loSav A (x + 1) (w + 1) = lo' at *
  generalize loSav A x w = lo at *
  generalize loDiv (T + 1) (w + 1) = ld' at *
  generalize loDiv T w = ld at *
  cases hsc : rg.scottish
  · have hns : nsRateAt rg x = rateAt nonSavingsRates rg x := by
      unfold nsRateAt; simp [hsc]
    have hmax : rg.maxStep = 6860 := by unfold Regime.maxStep; simp [hsc]
    have r1 := rateAt_ns_cases rg x
    generalize startingRateLimitSavings = L at *
    omega
  · have hns : nsRateAt rg x = scotRateAt rg x := by
      unfold nsRateAt; simp [hsc]
    have hmax : rg.maxStep = 7060 := by unfold Regime.maxStep; simp [hsc]
    have r1 := scotRateAt_cases rg x
    generalize startingRateLimitSavings = L at *
    omega

/-- The Step 3 allowances move only with the s35 personal allowance. -/
theorem personalAllowance_congr {rg : Regime} {n s d : Nat}
    (hPA : personalAllowanceFor (n + 1 + s + d - rg.relief)
      = personalAllowanceFor (n + s + d - rg.relief)) :
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
theorem taxExact_succ_le {rg : Regime} {n s d : Nat}
    (hPA : personalAllowanceFor (n + 1 + s + d - rg.relief)
      = personalAllowanceFor (n + s + d - rg.relief))
    (hPSA : Income.psa rg ⟨n + 1, s, d⟩ = Income.psa rg ⟨n, s, d⟩) :
    taxExact rg ⟨n + 1, s, d⟩ ≤ taxExact rg ⟨n, s, d⟩ + rg.maxStep := by
  have hopt := (isLeastTax_taxExact rg ⟨n + 1, s, d⟩).2
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
    exact Nat.le_trans h1 (G_succ_le hF.2.1 hF.2.2.2.2)
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
theorem finalTaxExact_succ_le {rg : Regime} {n s d : Nat}
    (hPA : personalAllowanceFor (n + 1 + s + d - rg.relief)
      = personalAllowanceFor (n + s + d - rg.relief))
    (hPSA : Income.psa rg ⟨n + 1, s, d⟩ = Income.psa rg ⟨n, s, d⟩)
    (hMA : Income.maReduction rg ⟨n + 1, s, d⟩ = Income.maReduction rg ⟨n, s, d⟩) :
    finalTaxExact rg ⟨n + 1, s, d⟩ ≤ finalTaxExact rg ⟨n, s, d⟩ + rg.maxStep + rg.mcaStep := by
  have h1 := taxExact_succ_le hPA hPSA
  have h2 := mcaReduction_succ rg n s d
  unfold finalTaxExact
  rw [hMA]
  omega

/-- Below the Marriage Allowance limit the rate test is passed: with no Step 3
income above it, nothing is charged above the basic rate (or the Scottish
intermediate rate). -/
theorem maOk_of_step3_le {rg : Regime} {i : Income} (h : i.step3 rg ≤ rg.maLimit) :
    i.maOk rg = true := by
  have ha := bestAlloc_feasible rg i
  have hU := allowanceUsed_le rg i
  have hL : rg.maLimit ≤ rg.brl := by
    unfold Regime.maLimit Regime.brl scotIntermediateLimit basicRateLimit; split <;> omega
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
of the limit, which is how `harness/cliffs.py` finds it. -/
theorem maOk_payOnly (rg : Regime) (g : Nat) :
    Income.maOk rg ⟨g, 0, 0⟩ = true ↔ Income.step3 rg ⟨g, 0, 0⟩ ≤ rg.maLimit := by
  refine ⟨fun h => ?_, maOk_of_step3_le⟩
  have ha := bestAlloc_feasible rg ⟨g, 0, 0⟩
  unfold Income.maOk maRateTest at h
  unfold Income.step3
  unfold Alloc.Feasible at ha
  generalize Income.bestAlloc rg ⟨g, 0, 0⟩ = a at *
  have ht : Income.total ⟨g, 0, 0⟩ = g + 0 + 0 := rfl
  simp only [Bool.and_eq_true, decide_eq_true_eq] at h
  dsimp only at *
  generalize Income.allowanceUsed rg ⟨g, 0, 0⟩ = u at *
  omega

/-- **The Marriage Allowance step.** If a penny more non-savings income changes the
Marriage Allowance reduction, Step 3 income after that penny is above the
Marriage Allowance limit (the basic rate limit, or the top of the Scottish
intermediate rate): below it the recipient keeps the £252. -/
theorem maStep_above_limit {rg : Regime} {n s d : Nat}
    (h : Income.maReduction rg ⟨n + 1, s, d⟩ ≠ Income.maReduction rg ⟨n, s, d⟩) :
    rg.maLimit < Income.step3 rg ⟨n + 1, s, d⟩ := by
  apply Nat.lt_of_not_le
  intro hle
  have hmono : Income.step3 rg ⟨n, s, d⟩ ≤ Income.step3 rg ⟨n + 1, s, d⟩ := by
    unfold Income.step3 Income.allowanceUsed Income.total
    have := personalAllowanceFor_anti (x := n + s + d - rg.relief) (x' := n + 1 + s + d - rg.relief)
      (by omega)
    unfold Income.personalAllowance Income.ani Income.total
    generalize personalAllowanceFor (n + s + d - rg.relief) = A at *
    generalize personalAllowanceFor (n + 1 + s + d - rg.relief) = A' at *
    generalize (if rg.maTransfer = true then maTransferable else 0) = m
    generalize (if rg.blind = true then blindPersonsAllowance else 0) = b
    dsimp only at *
    omega
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
    - (nicExact p (g + rg.netPay) : Int) - 10_000 * (hicbc (g + s + d - rg.relief) cb : Int)

theorem nicExact_succ_le (p : EarningsPeriod) (g : Nat) : nicExact p (g + 1) ≤ nicExact p g + 800 := by
  unfold nicExact nicMainRate nicAdditionalRate
  omega

/-- The least net income gained from a penny more pay between steps, in 1/10 000
pence: a penny less the most income tax (`Regime.maxStep`), the most the married
couple's allowance can taper (`Regime.mcaStep`) and NICs (0.08p) it can cost.
0.234p, or 0.214p for a Scottish taxpayer, 0.05p less with the married couple's
allowance. -/
def Regime.minGain (rg : Regime) : Nat := 9200 - rg.maxStep - rg.mcaStep

theorem Regime.minGain_eq (rg : Regime) : rg.minGain + rg.maxStep + rg.mcaStep = 9200 := by
  unfold Regime.minGain Regime.maxStep Regime.mcaStep; split <;> split <;> omega

/-- Between steps, net income never falls: if a penny more pay changes neither
allowance nor the charge, net income rises by at least `rg.minGain`. -/
theorem net_succ_ge {p : EarningsPeriod} {cb : Nat} {rg : Regime} {s d g : Nat}
    (hPA : personalAllowanceFor (g + 1 + s + d - rg.relief)
      = personalAllowanceFor (g + s + d - rg.relief))
    (hPSA : Income.psa rg ⟨g + 1, s, d⟩ = Income.psa rg ⟨g, s, d⟩)
    (hMA : Income.maReduction rg ⟨g + 1, s, d⟩ = Income.maReduction rg ⟨g, s, d⟩)
    (hC : hicbc (g + 1 + s + d - rg.relief) cb = hicbc (g + s + d - rg.relief) cb) :
    net p cb rg s d g + rg.minGain ≤ net p cb rg s d (g + 1) := by
  have h1 := finalTaxExact_succ_le hPA hPSA hMA
  have h2 := nicExact_succ_le p (g + rg.netPay)
  rw [show g + rg.netPay + 1 = g + 1 + rg.netPay by omega] at h2
  have h3 := rg.minGain_eq
  unfold net
  rw [hC]
  omega

/-! ## The steps -/

/-- Adjusted net income `t + 1` is a whole multiple of £2 above £100,000, up to
£125,140: one penny more from `t` and the personal allowance falls by £1. -/
def PaStep (t : Nat) : Prop :=
  10_000_000 < t + 1 ∧ (t + 1) % 200 = 0 ∧ t + 1 ≤ 12_514_000

/-- Adjusted net income `t + 1` is a whole multiple of £200 from £60,200 to
£80,000: one penny more from `t` and the charge goes up 1 %. -/
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

theorem psa_succ {rg : Regime} {n s d : Nat}
    (hPA : personalAllowanceFor (n + 1 + s + d - rg.relief)
      = personalAllowanceFor (n + s + d - rg.relief)) :
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
  unfold savingsAllowanceFor savingsAllowanceAdditional savingsAllowanceHigher
    savingsAllowanceBasic
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
    t + 1 - rg.relief = (t - rg.relief) + 1 ∨
      (t + 1 - rg.relief = 0 ∧ t - rg.relief = 0) := by
  omega

/-- **Where net income can fall.** If a penny more pay lowers net income, then at
that penny the personal allowance falls by £1, the charge goes up 1 % (with some
Child Benefit), or Step 3 income passes the basic or the higher rate limit (where
the personal savings allowance falls), or a Marriage Allowance recipient fails the
rate test (above the basic rate limit); the allowance and the charge step with
adjusted net income, and the limits are raised by Gift Aid and pension
contributions relieved at source. This holds for every pay, savings, dividends,
Child Benefit, pay period, reliefs, and for Scottish taxpayers. -/
theorem net_drop_only_at_steps (p : EarningsPeriod) (cb : Nat) (rg : Regime) (s d g : Nat)
    (h : net p cb rg s d (g + 1) < net p cb rg s d g) :
    PaStep (g + s + d - rg.relief) ∨ (0 < cb ∧ HicbcStep (g + s + d - rg.relief)) ∨
      Income.step3 rg ⟨g, s, d⟩ = rg.brl ∨ Income.step3 rg ⟨g, s, d⟩ = rg.hrl ∨
      MaStep rg s d g := by
  by_cases hMA : MaStep rg s d g
  · exact Or.inr (Or.inr (Or.inr (Or.inr hMA)))
  unfold MaStep at hMA
  have hMA : Income.maReduction rg ⟨g + 1, s, d⟩ = Income.maReduction rg ⟨g, s, d⟩ :=
    Classical.not_not.mp hMA
  have ht : g + 1 + s + d = (g + s + d) + 1 := by omega
  have hA : (personalAllowanceFor (g + 1 + s + d - rg.relief)
        = personalAllowanceFor (g + s + d - rg.relief) ∧
      hicbc (g + 1 + s + d - rg.relief) cb = hicbc (g + s + d - rg.relief) cb) ∨
      PaStep (g + s + d - rg.relief) ∨ (0 < cb ∧ HicbcStep (g + s + d - rg.relief)) := by
    rw [ht]
    rcases ani_succ rg (g + s + d) with ha | ⟨ha, hb⟩
    · rw [ha]
      rcases personalAllowanceFor_succ (g + s + d - rg.relief) with hPA | hPA
      · rcases hicbc_succ (g + s + d - rg.relief) cb with hc | hc
        · exact Or.inl ⟨hPA, hc⟩
        · by_cases hcb : cb = 0
          · left; subst hcb; unfold hicbc; simp [hPA]
          · exact Or.inr (Or.inr ⟨by omega, hc⟩)
      · exact Or.inr (Or.inl hPA)
    · left; rw [ha, hb]; exact ⟨rfl, rfl⟩
  rcases hA with ⟨hPA, hC⟩ | hA
  · rcases psa_succ hPA with hPSA | hT | hT
    · have := net_succ_ge (p := p) hPA hPSA hMA hC
      omega
    · exact Or.inr (Or.inr (Or.inl hT))
    · exact Or.inr (Or.inr (Or.inr (Or.inl hT)))
  · rcases hA with hA | hA
    · exact Or.inl hA
    · exact Or.inr (Or.inl hA)

end UkTax
