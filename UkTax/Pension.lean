import UkTax.Params

/-!
# State Pension and Pension Credit, 2026-27 (P6)

## State Pension

Anyone with a qualifying year before 6 April 2016 gets the new State Pension at
the *transitional* rate (Pensions Act 2014 s4(1), (3)), worked out from their own
contribution record (s5, Sch 1: the starting amount and any protected payment),
and the basic State Pension of anyone who reached pensionable age before then
likewise depends on their record. So the State Pension is an input here, as in
PolicyEngine. The model gives the rates the statute fixes: the full new State
Pension £241.30 with 35 qualifying years, and for someone with no year before
6 April 2016 the reduced rate, 1/35 of it for each qualifying year from 10
(s2, s3(2); SI 2015/173 reg 13(1)), exact (as a numerator over 35: no rounding
rule was found); the basic State Pension's Category A £184.90 and Category B or D
£110.75, and the 25p age addition at 80.

## Pension Credit (State Pension Credit Act 2002; SI 2002/1792)

All weekly amounts are in units of 1/520 of a penny a week (`u`), which is also
1/10 of a penny a year (52 weeks): a year's income `a` pence is `10 a` units a
week (reg 17(1)(b)(iii): a yearly payment ÷ 52), and 60 % and 40 % of a number of
units stay whole.

* **Income** (s15, reg 15): the State Pension, other pensions, other income
  counted in full, earnings less NICs and the Sch VI disregard (£20, £10 or £5,
  never more than the earnings), less the income tax payable on that income (reg
  17(10)(a)), and deemed income from capital, £1 a week for each
  £500 or part above £10,000 (reg 15(6)). Benefits reg 15(1) leaves out (PIP, DLA,
  AA, Child Benefit, Housing Benefit, ...) are simply not given.
* **Guarantee credit** (s2): the appropriate minimum guarantee (the standard
  minimum guarantee plus the severe disability, carer and child amounts) less
  income, if positive.
* **Savings credit** (s3, reg 7), only where the claimant or partner reached
  pensionable age before 6 April 2016: amount A, 60 % of qualifying income (income
  less the items of reg 9, e.g. maternity allowance, contributory ESA and JSA)
  above the threshold, up to the maximum, rounded up to a penny; less amount B,
  40 % of income above the appropriate minimum guarantee, rounded down; not below
  nil.

Proved: income plus Pension Credit never falls as income rises with qualifying
income rising by the same amount (both theorems assume this, so they do not cover
a rise in income reg 9 leaves out of qualifying income), except by at most a
penny a week where amount B's rounding steps (`pc_total_succ`); between those
pennies it keeps at least 60 % of any such rise once the guarantee credit is used
up (`pc_total_gain`); each £500 of capital above £10,000 costs exactly £1 a week of
guarantee credit while it is payable (`deemed_step`).
-/

namespace UkTax

/-! ## State Pension -/

/-- New State Pension a week, in 1/35 pence, for someone with `years` qualifying
years, none before 6 April 2016 (s2, s3(2)). -/
def nspReduced35 (years : Nat) : Nat :=
  if years < nspMinYears then 0 else min years nspFullYears * nspFull

theorem nsp_full (y : Nat) (h : nspFullYears ≤ y) : nspReduced35 y = 35 * nspFull := by
  unfold nspReduced35 nspMinYears nspFullYears at *
  rw [ite_eq_right_iff.mpr (fun h' => absurd h' (by omega)), Nat.min_eq_right h]

/-! ## Pension Credit -/

/-- A Pension Credit claim. Yearly amounts in pence; `earnings` is earnings for the
year less NICs (reg 17(10)(b)); the income tax on all the income counted is
`incomeTax`, disregarded under reg 17(10)(a). -/
structure PcClaim where
  couple : Bool := false
  /-- The claimant or partner reached pensionable age before 6 April 2016. -/
  savingsCredit : Bool := false
  /-- Severe disability amount: 0, 1 (£86.05) or 2 (£172.10). -/
  severeDisability : Nat := 0
  /-- Members entitled to Carer's Allowance or carer support payment (reg 6(8)). -/
  carers : Nat := 0
  children : Nat := 0
  firstChildPre2017 : Bool := false
  disabledChildrenLower : Nat := 0
  disabledChildrenHigher : Nat := 0
  /-- Qualifies for the £20 earnings disregard (Sch VI paras 1-4). -/
  higherDisregard : Bool := false
  statePension : Nat := 0
  otherPension : Nat := 0
  /-- Other income counted in full and qualifying for savings credit. -/
  otherIncome : Nat := 0
  /-- Income counted in full but not qualifying income (reg 9). -/
  excludedIncome : Nat := 0
  earnings : Nat := 0
  capital : Nat := 0
  /-- Income tax payable for the year on the income counted (reg 17(10)(a)). -/
  incomeTax : Nat := 0
  deriving Repr

/-- Units of a week (1/520 penny a week) in a penny a week. -/
def wk : Nat := 520

def PcClaim.smg (c : PcClaim) : Nat := if c.couple then pcSmgCouple else pcSmgSingle

def PcClaim.threshold (c : PcClaim) : Nat :=
  if c.couple then pcScThresholdCouple else pcScThresholdSingle

/-- The child amounts, pence a week (Sch IIA). -/
def PcClaim.childAmounts (c : PcClaim) : Nat :=
  (if c.firstChildPre2017 && c.children > 0 then pcChildFirstPre2017 + (c.children - 1) * pcChild
   else c.children * pcChild)
    + c.disabledChildrenLower * pcDisabledChildLower + c.disabledChildrenHigher * pcDisabledChildHigher

/-- The appropriate minimum guarantee, pence a week (s2(3)). -/
def PcClaim.mg (c : PcClaim) : Nat :=
  c.smg + c.severeDisability * pcSevereDisability + c.carers * pcCarer + c.childAmounts

/-- Deemed income from capital, pence a week (reg 15(6)). -/
def deemedIncome (capital : Nat) : Nat := 100 * ((capital - pcCapitalLower + pcCapitalStep - 1) / pcCapitalStep)

/-- The earnings disregard, pence a week (Sch VI). -/
def PcClaim.disregard (c : PcClaim) : Nat :=
  if c.higherDisregard then pcDisregardHigher else if c.couple then pcDisregardCouple else pcDisregardSingle

/-- Income, units a week. -/
def PcClaim.income (c : PcClaim) : Nat :=
  10 * (c.statePension + c.otherPension + c.otherIncome + c.excludedIncome)
    + (10 * c.earnings - wk * c.disregard) - 10 * c.incomeTax + wk * deemedIncome c.capital

/-- Guarantee credit, units a week (= tenths of a penny a year). -/
def guaranteeCredit (mg i : Nat) : Nat := wk * mg - i

/-- Savings credit, pence a week, for minimum guarantee `mg`, standard minimum
guarantee `smg` and threshold `t` (pence a week), income `i` and qualifying
income `q` (units a week): amount A rounded up, amount B rounded down. -/
def savingsCredit (mg smg t i q : Nat) : Nat :=
  let a := min (3 * (wk * (smg - t)) / 5) (3 * (q - wk * t) / 5)
  let b := 2 * (i - wk * mg) / 5
  (a + wk - 1) / wk - b / wk

/-- Pension Credit for the year, tenths of a penny (= units a week). -/
def pensionCredit (c : PcClaim) : Nat :=
  let i := c.income
  guaranteeCredit c.mg i
    + if c.savingsCredit then
        wk * savingsCredit c.mg c.smg c.threshold i (i - 10 * c.excludedIncome)
      else 0

/-! ## Proved properties -/

/-- The savings credit term: amount A never falls when qualifying income rises, and
amount B, rounded down to a penny, rises by at most 40 % of the rise in income above
the minimum guarantee and a penny. -/
theorem sc_core {X0 X1 b0 b1 : Nat} (hX : X0 ≤ X1) (hb : b0 ≤ b1) :
    wk * (X0 - b0 / wk) ≤ wk * (X1 - b1 / wk) + (b1 - b0) + wk := by
  unfold wk; omega

theorem sc_step (mg smg t i q δ : Nat) :
    wk * savingsCredit mg smg t i q
      ≤ wk * savingsCredit mg smg t (i + δ) (q + δ) + (2 * (i + δ - wk * mg) / 5 - 2 * (i - wk * mg) / 5) + wk := by
  have ha : min (3 * (wk * (smg - t)) / 5) (3 * (q - wk * t) / 5)
      ≤ min (3 * (wk * (smg - t)) / 5) (3 * (q + δ - wk * t) / 5) := by
    have : 3 * (q - wk * t) / 5 ≤ 3 * (q + δ - wk * t) / 5 := Nat.div_le_div_right (by omega)
    simp only [Nat.min_def]; split <;> split <;> omega
  have hA := Nat.div_le_div_right (c := wk) (Nat.add_le_add_right ha (wk - 1))
  have hb : 2 * (i - wk * mg) / 5 ≤ 2 * (i + δ - wk * mg) / 5 := Nat.div_le_div_right (by omega)
  exact sc_core hA hb

/-- **No cliff in Pension Credit.** For any minimum guarantee, threshold and
standard minimum guarantee, if income and qualifying income both rise by `δ`
units, income plus Pension Credit falls by at most a penny a week (`wk` units):
the guarantee credit takes back at most what income adds, amount A never falls,
and amount B, rounded down to a penny, can step by a penny. -/
theorem pc_total_succ (mg smg t i q δ : Nat) (sc : Bool) :
    i + guaranteeCredit mg i + (if sc then wk * savingsCredit mg smg t i q else 0)
      ≤ (i + δ) + guaranteeCredit mg (i + δ)
        + (if sc then wk * savingsCredit mg smg t (i + δ) (q + δ) else 0) + wk := by
  have h := sc_step mg smg t i q δ
  unfold guaranteeCredit
  cases sc
  · simp only [Bool.false_eq_true, ↓reduceIte]; omega
  · simp only [↓reduceIte]
    generalize wk * savingsCredit mg smg t i q = S0 at *
    generalize wk * savingsCredit mg smg t (i + δ) (q + δ) = S1 at *
    unfold wk at *
    omega

/-- Above the minimum guarantee, income plus Pension Credit keeps at least 60 % of
any rise in (qualifying) income, less the penny of amount B's rounding. -/
theorem pc_total_gain (mg smg t i q δ : Nat) (sc : Bool) (hi : wk * mg ≤ i) :
    i + guaranteeCredit mg i + (if sc then wk * savingsCredit mg smg t i q else 0) + 3 * δ / 5
      ≤ (i + δ) + guaranteeCredit mg (i + δ)
        + (if sc then wk * savingsCredit mg smg t (i + δ) (q + δ) else 0) + wk := by
  have h := sc_step mg smg t i q δ
  unfold guaranteeCredit
  cases sc
  · simp only [Bool.false_eq_true, ↓reduceIte]; omega
  · simp only [↓reduceIte]
    generalize wk * savingsCredit mg smg t i q = S0 at *
    generalize wk * savingsCredit mg smg t (i + δ) (q + δ) = S1 at *
    unfold wk at *
    omega

/-- The single maximum savings credit: 60 % of £238.00 − £208.07 is £17.958,
which reg 7(4) rounds up to £17.96 a week (amount A at the maximum). -/
example : savingsCredit pcSmgSingle pcSmgSingle pcScThresholdSingle 0 (wk * 100_000) = 1_796 := by
  decide

/-- **Each £500 of capital is £1 a week.** One more penny of capital beyond a
whole £500 above £10,000 adds exactly £1 a week of deemed income. -/
theorem deemed_step (k : Nat) :
    deemedIncome (pcCapitalLower + k * pcCapitalStep + 1)
      = deemedIncome (pcCapitalLower + k * pcCapitalStep) + 100 := by
  unfold deemedIncome pcCapitalLower pcCapitalStep
  omega

end UkTax
