import UkTax.Params

/-!
# Student loan repayments and the Winter Fuel Payment charge (P9a)

* **Student loans, the year's repayment** (SI 2009/470 reg 29, the Self
  Assessment calculation, which also settles the year for a PAYE borrower who
  files a return): 9 % of income above the repayment threshold for plans 1, 2, 4
  and 5 (with more than one, the lowest threshold, reg 29(5A)) and 6 % above
  £21,000 for a Postgraduate (plan 3) loan, concurrently (reg 29(3A)). The income
  is total income (ITA 2007 s23 Step 1) with unearned income left out unless it
  exceeds £2,000 (reg 29(4)(c)); unearned income is anything not charged under
  ITEPA 2003 or ITTOIA 2005 Part 2 (reg 29(5)): property income, savings
  interest and dividends. Exact, in 1/10 000 pence; the outstanding balance is
  not a cap here (the caller gives a borrower who still owes).
* **Winter Fuel Payment** (England and Wales, SI 2025/969 regs 2-4; Northern
  Ireland's NISR 2025/142 has the same amounts): the amount from P's age, a
  relevant benefit paid to P, and who P lives with.
* **The winter fuel payment charge** (ITEPA 2003 s681I, FA 2026 Sch 10): the
  whole payment, where P's total income exceeds £35,000 and P is not entitled to
  a relevant benefit in the qualifying week.
-/

namespace UkTax

/-- A borrower's plans. -/
structure Loans where
  plan1 : Bool := false
  plan2 : Bool := false
  plan4 : Bool := false
  plan5 : Bool := false
  postgraduate : Bool := false
  deriving Repr

/-- The repayment threshold for plans 1, 2, 4 and 5: the lowest among those held
(reg 29(5A)); `none` with none of them. Plan 5's is the lowest, then 1, 2, 4. -/
def Loans.threshold (l : Loans) : Option Nat :=
  if l.plan5 then some slPlan5 else if l.plan1 then some slPlan1
  else if l.plan2 then some slPlan2 else if l.plan4 then some slPlan4 else none

/-- The income for repayments, pence: earned income, and unearned income only if
it exceeds £2,000 (reg 29(4)(c)). -/
def slIncome (earned unearned : Nat) : Nat :=
  earned + (if slUnearnedLimit < unearned then unearned else 0)

/-- The plan 1, 2, 4 or 5 repayment, 1/10 000 pence (reg 29(3)(a)). -/
def slMain (l : Loans) (i : Nat) : Nat :=
  match l.threshold with
  | some t => slRate * (i - t)
  | none => 0

/-- The Postgraduate loan repayment, 1/10 000 pence (reg 29(3)(b)). -/
def slPg (l : Loans) (i : Nat) : Nat :=
  if l.postgraduate then slPostgraduateRate * (i - slPostgraduate) else 0

/-- The year's repayments, 1/10 000 pence: both, concurrently (reg 29(3A)). -/
def slRepayment (l : Loans) (earned unearned : Nat) : Nat :=
  slMain l (slIncome earned unearned) + slPg l (slIncome earned unearned)

/-- What the Winter Fuel Payment turns on for one person P who has reached
pensionable age and lives in England or Wales in the qualifying week. -/
structure WfpCase where
  /-- P has reached 80 in or before the qualifying week. -/
  over80 : Bool := false
  /-- A relevant benefit (Pension Credit, Universal Credit, income-related ESA,
  and the abolished IS and income-based JSA) is paid, or falls to be paid, to P
  for the qualifying week. -/
  relevantBenefit : Bool := false
  /-- P's partner, living with P, has reached 80 (reg 3(3)). -/
  partnerOver80 : Bool := false
  /-- P lives with another person entitled to a payment who is under 80. -/
  withEntitledUnder80 : Bool := false
  /-- P lives with another person entitled to a payment who has reached 80. -/
  withEntitled80 : Bool := false
  /-- P is in residential care (a care home or independent hospital). -/
  residentialCare : Bool := false
  /-- P's partner, living with P, has reached pensionable age and is paid a
  relevant benefit for the qualifying week (reg 4(2)(a)). -/
  partnerPaidBenefit : Bool := false
  deriving Repr

/-- Whether P is entitled (reg 2 with the exclusions of reg 4(2)(a) and 4(3);
custody, long hospital stays and late claims are left to the caller). -/
def WfpCase.entitled (w : WfpCase) : Bool :=
  !w.partnerPaidBenefit && !(w.residentialCare && w.relevantBenefit)

/-- The Winter Fuel Payment, pence (SI 2025/969 reg 3). -/
def wfpAmount (w : WfpCase) : Nat :=
  if !w.entitled then 0
  else if w.relevantBenefit then
    -- reg 3(1), (3), (4): the full amount, £300 when P or P's partner is 80
    if w.over80 || w.partnerOver80 then wfpHigher else wfpLower
  else if w.over80 then
    -- reg 3(4), (5), (6); (5) is subject to (6)
    if w.withEntitled80 || w.residentialCare then wfpHigherSharedWith80
    else if w.withEntitledUnder80 then wfpHigherSharedWithUnder80 else wfpHigher
  else
    -- reg 3(1), (2)
    if w.withEntitledUnder80 || w.withEntitled80 || w.residentialCare then wfpLowerShared
    else wfpLower

/-- The winter fuel payment charge, pence (ITEPA 2003 s681I): the payment `w`
where total income `t` exceeds £35,000 and P is not entitled to a relevant
benefit in the qualifying week. -/
def wfpCharge (t w : Nat) (relevantBenefit : Bool) : Nat :=
  if !relevantBenefit && wfpChargeThreshold < t then w else 0

/-! ## Proved properties -/

/-- The threshold is the lowest of the plans held: never above any one of them. -/
theorem threshold_le (l : Loans) :
    (l.plan1 → ∃ t, l.threshold = some t ∧ t ≤ slPlan1) ∧
    (l.plan2 → ∃ t, l.threshold = some t ∧ t ≤ slPlan2) ∧
    (l.plan4 → ∃ t, l.threshold = some t ∧ t ≤ slPlan4) ∧
    (l.plan5 → l.threshold = some slPlan5) := by
  unfold Loans.threshold slPlan1 slPlan2 slPlan4 slPlan5
  cases l.plan1 <;> cases l.plan2 <;> cases l.plan4 <;> cases l.plan5 <;> simp

/-- **The unearned income cliff.** £2,000 of savings interest, property or
dividend income adds nothing to the income for repayments; £2,000.01 adds all of
it. -/
theorem sl_unearned_cliff (e : Nat) :
    slIncome e slUnearnedLimit = e ∧ slIncome e (slUnearnedLimit + 1) = e + (slUnearnedLimit + 1) := by
  unfold slIncome
  exact ⟨by simp, by simp⟩

/-- The size of that cliff: a plan 1, 2, 4 or 5 borrower with earned income at or
above the threshold repays 9 % of £2,000.01, £180.0009, more for the last penny
of unearned income. -/
theorem sl_unearned_cliff_size (l : Loans) (e t : Nat) (ht : l.threshold = some t) (he : t ≤ e)
    (hpg : l.postgraduate = false) :
    slRepayment l e (slUnearnedLimit + 1) = slRepayment l e slUnearnedLimit + 180_000_900 := by
  unfold slRepayment slMain slPg slIncome
  rw [ht, hpg]
  unfold slRate slUnearnedLimit
  have h1 : ¬ (200_000 < 200_000) := by omega
  have h2 : 200_000 < 200_000 + 1 := by omega
  simp only [h1, h2, ite_true, ite_false, Bool.false_eq_true]
  omega

/-- Away from that cliff, a penny more earned income adds at most 0.15p of repayments
(9 % and 6 % of a penny), never less than nothing. -/
theorem sl_succ_earned (l : Loans) (e u : Nat) :
    slRepayment l e u ≤ slRepayment l (e + 1) u ∧ slRepayment l (e + 1) u ≤ slRepayment l e u + 1_500 := by
  unfold slRepayment slMain slPg slIncome slRate slPostgraduateRate
  split <;> split <;> (try split) <;> omega

/-- The payment is never more than £300. -/
theorem wfpAmount_le (w : WfpCase) : wfpAmount w ≤ wfpHigher := by
  unfold wfpAmount wfpHigher wfpLower wfpHigherSharedWith80 wfpHigherSharedWithUnder80 wfpLowerShared
  split <;> (try split) <;> (try split) <;> (try split) <;> (try split) <;> omega

/-- **The Winter Fuel Payment charge cliff.** At £35,000 of total income the
payment is kept; a penny more and all of it is charged. -/
theorem wfp_charge_cliff (w : Nat) :
    wfpCharge wfpChargeThreshold w false = 0 ∧ wfpCharge (wfpChargeThreshold + 1) w false = w := by
  unfold wfpCharge
  simp

/-- A relevant benefit in the qualifying week takes away the charge at any income. -/
theorem wfp_charge_benefit (t w : Nat) : wfpCharge t w true = 0 := by
  unfold wfpCharge
  simp

end UkTax
