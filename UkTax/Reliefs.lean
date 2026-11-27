import UkTax.Cliffs
import UkTax.Nics

/-!
# Reliefs and the annual allowance charge (area 6)

One individual's income tax, built from its sources, with the reliefs PolicyEngine
models:

* **Employment expenses** (ITEPA 2003 Part 5 Chapter 2): deducted from the
  earnings, not below nil (s328(3) the deductions may not exceed the earnings);
  NICs are still on the pay.
* **Capital allowances** (CAA 2001 s247: an expense of the trade) and **trade losses
  brought forward** (ITA 2007 s83: against the first available profits of the same
  trade, as far as possible), both also for Class 4 (SSCBA 1992 Sch 2 para 3).
  Allowances above the profit would make a loss; that is not modelled (rejected).
* **Gifts of shares and land to charity** (ITA 2007 s431): deducted at Step 2 (s24),
  allocated with the allowances in the way giving the greatest reduction (s25(2),
  `Regime.step2`), so lowering net income and adjusted net income.
* **Finance costs of a dwelling-related loan** (ITTOIA 2005 s272A: not deductible;
  ss 274A, 274AA): a tax reduction at 20 % of the lowest of the costs, the property
  profits and adjusted total income (net income less savings and dividends, less the
  allowances deducted at Step 3), only so far as there is tax to reduce (ITA 2007
  s29).
* **The annual allowance charge** (FA 2004 ss 227, 228, 228ZA): on the pension input
  amount above the annual allowance and any unused allowance brought forward, taxed
  as the highest part of income at the non-savings rates (Scottish for a Scottish
  taxpayer, but the Scottish basic rate, not the starter rate, up to the Scottish
  basic rate limit, s227(4AA)). Inputs: employer contributions only, so adjusted income is net income
  plus them and threshold income is net income (s228ZA(4), (5)).

Tax in 1/10 000 pence.
-/

namespace UkTax

structure ReliefsIn where
  pay : Nat := 0
  employmentExpenses : Nat := 0
  trade : Nat := 0
  capitalAllowances : Nat := 0
  lossesBroughtForward : Nat := 0
  property : Nat := 0
  financeCosts : Nat := 0
  savings : Nat := 0
  dividends : Nat := 0
  shareGifts : Nat := 0
  /-- Employer contributions, the pension input amount. -/
  pensionInput : Nat := 0
  unusedAllowance : Nat := 0
  deriving Repr

/-- Trading profits after capital allowances and losses brought forward. -/
def ReliefsIn.tradeProfit (r : ReliefsIn) : Nat :=
  let p := r.trade - r.capitalAllowances
  p - min r.lossesBroughtForward p

/-- Income by component before the Step 2 relief for gifts, which the regime
carries (`Regime.step2`) so that it is allocated with the allowances in the way
giving the greatest reduction (ITA 2007 s25(2)) and lowers net income. -/
def ReliefsIn.income (r : ReliefsIn) : Income :=
  ⟨r.pay - min r.employmentExpenses r.pay + r.tradeProfit + r.property, r.savings, r.dividends⟩

/-- The regime with the gifts as a Step 2 relief. -/
def ReliefsIn.regime (r : ReliefsIn) (rg : Regime) : Regime := { rg with step2 := r.shareGifts }

/-- Net income (Step 2). -/
def ReliefsIn.netIncome (r : ReliefsIn) : Nat := r.income.total - r.shareGifts

/-- Adjusted total income for the finance cost relief (s274AA(6)): net income less
savings and dividends, less the allowances deducted at Step 3; the gifts are taken
as deducted from non-savings income first. -/
def ReliefsIn.ati (r : ReliefsIn) (rg : Regime) : Nat :=
  r.income.nonSavings - r.shareGifts - (r.income.allowanceUsed (r.regime rg) - min r.shareGifts r.income.total)

/-- The finance cost reduction, 1/10 000 pence, at most the tax `t`. -/
def ReliefsIn.financeReduction (r : ReliefsIn) (rg : Regime) (t : Nat) : Nat :=
  min (financeCostRate * min r.financeCosts (min r.property (r.ati rg))) t

/-- The annual allowance after the taper, pence. -/
def ReliefsIn.allowance (r : ReliefsIn) : Nat :=
  let net := r.netIncome
  let adjusted := net + r.pensionInput
  if aaTaperAdjusted < adjusted && aaTaperAdjusted - annualAllowance < net then
    max aaMinimum (annualAllowance - (adjusted - aaTaperAdjusted) / 2 / 100 * 100)
  else annualAllowance

/-- The chargeable amount, pence. -/
def ReliefsIn.chargeable (r : ReliefsIn) : Nat := r.pensionInput - (r.allowance + r.unusedAllowance)

/-- Tax on the lowest `x` pence at the charge's rates (s227(4), (4AA)): the
non-savings rates, but for a Scottish taxpayer the Scottish basic rate up to the
Scottish basic rate limit, so the starter rate's band is charged at 20 %. -/
def aaTax (rg : Regime) (x : Nat) : Nat :=
  nsTax rg x + (if rg.scottish then (scotBasicRate - scotStarterRate) * min x scotStarterLimit else 0)

/-- The charge's rate on the penny above `y`. -/
def aaRateAt (rg : Regime) (y : Nat) : Nat :=
  if rg.scottish && decide (y < scotStarterLimit) then scotBasicRate else nsRateAt rg y

/-- The annual allowance charge, 1/10 000 pence: the tax on the chargeable amount as
the top slice above reduced net income. -/
def aaCharge (rg : Regime) (i : Income) (c : Nat) : Nat :=
  let rni := i.total - i.allowanceUsed rg
  aaTax rg (rni + c) - aaTax rg rni

/-- Income tax with the reliefs and the charge, 1/10 000 pence. -/
def ReliefsIn.tax (r : ReliefsIn) (rg : Regime) : Nat :=
  let t := finalTaxExact (r.regime rg) r.income
  t - r.financeReduction rg t + aaCharge (r.regime rg) r.income r.chargeable

/-! ## Proved properties -/

/-- The non-savings rate never exceeds 48 %. -/
theorem nsRateAt_le (rg : Regime) (y : Nat) : nsRateAt rg y ≤ 4_800 := by
  unfold nsRateAt
  split
  · have := scotRateAt_cases rg y; omega
  · have := rateAt_ns_cases rg y; omega

theorem aaTax_succ (rg : Regime) (y : Nat) : aaTax rg (y + 1) = aaTax rg y + aaRateAt rg y := by
  unfold aaTax aaRateAt
  rw [nsTax_succ]
  cases hs : rg.scottish
  · simp
  · simp only [↓reduceIte, Bool.true_and]
    by_cases hy : y < scotStarterLimit
    · have hr : nsRateAt rg y = scotStarterRate := by
        unfold nsRateAt scotRateAt; simp [hs, hy]
      have hm1 : min (y + 1) scotStarterLimit = y + 1 := by omega
      have hm0 : min y scotStarterLimit = y := by omega
      simp only [hy, decide_true, ↓reduceIte, hr, hm1, hm0]
      unfold scotBasicRate scotStarterRate
      omega
    · have hm : min (y + 1) scotStarterLimit = min y scotStarterLimit := by omega
      simp only [hy, decide_false, Bool.false_eq_true, ↓reduceIte, hm]
      omega

theorem aaRateAt_le (rg : Regime) (y : Nat) : aaRateAt rg y ≤ 4_800 := by
  unfold aaRateAt
  split
  · unfold scotBasicRate; omega
  · exact nsRateAt_le rg y

/-- The charge's tax over a slice of `c` pence is at most 48 % of it, and never
negative. -/
theorem aaTax_slice (rg : Regime) (x c : Nat) : aaTax rg x ≤ aaTax rg (x + c) ∧ aaTax rg (x + c) ≤ aaTax rg x + 4_800 * c := by
  induction c with
  | zero => simp
  | succ c ih =>
    have h := aaTax_succ rg (x + c)
    have := aaRateAt_le rg (x + c)
    rw [show x + (c + 1) = x + c + 1 by omega, h, Nat.mul_succ]
    omega

/-- **The annual allowance charge is at most 48 % of the excess** (45 % outside
Scotland). -/
theorem aaCharge_le (rg : Regime) (i : Income) (c : Nat) : aaCharge rg i c ≤ 4_800 * c := by
  unfold aaCharge
  have := aaTax_slice rg (i.total - i.allowanceUsed rg) c
  dsimp only
  omega

/-- **The taper never takes the allowance below £10,000 or above £60,000.** -/
theorem allowance_bounds (r : ReliefsIn) : aaMinimum ≤ r.allowance ∧ r.allowance ≤ annualAllowance := by
  unfold ReliefsIn.allowance aaMinimum annualAllowance
  dsimp only
  split <;> omega

/-- The finance cost reduction never exceeds 20 % of the costs, nor the tax. -/
theorem financeReduction_le (r : ReliefsIn) (rg : Regime) (t : Nat) :
    r.financeReduction rg t ≤ financeCostRate * r.financeCosts ∧ r.financeReduction rg t ≤ t := by
  unfold ReliefsIn.financeReduction
  have : financeCostRate * min r.financeCosts (min r.property (r.ati rg)) ≤ financeCostRate * r.financeCosts :=
    Nat.mul_le_mul_left _ (by omega)
  omega

end UkTax
