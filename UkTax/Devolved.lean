import UkTax.StudentLoans
import UkTax.Disability

/-!
# Scottish devolved benefits (P9b)

* **Scottish Child Payment** (SSI 2020/351 regs 14, 18, 20): £28.20 a week for
  each child under 16 of a family awarded a qualifying benefit (income-based JSA,
  income-related ESA, Income Support, Pension Credit or Universal Credit), for the
  52 benefit weeks of the year.
* **Carer Support Payment** (SSI 2023/302): the Carer's Allowance rules in
  Scotland, £86.45 a week (reg 16(1)), less overlapping benefits (reg 16(2)), not
  in a week after one with net earnings above £204 (reg 14, Sch 2 para 9, the
  same net earnings as Carer's Allowance). With it, for each week it is payable,
  the **Scottish Carer Supplement**, £11.70 (regs 14A, 16(1A)), and the **Carer
  Additional Person Payment**, £10.40 for each other disabled person cared for
  20 hours a week (regs 14B, 16(1B)).
* **Pension Age Winter Heating Payment** (SSI 2024/351 regs 2A, 9, 10): the Winter
  Fuel Payment's structure with Scotland's amounts; charged by ITEPA 2003 s681I
  like the Winter Fuel Payment.
-/

namespace UkTax

/-- The year's Scottish Child Payment, pence, for `n` children under 16 when the
individual responsible has been awarded a qualifying benefit. -/
def scpYear (n : Nat) (qualifying : Bool) : Nat :=
  if qualifying then benefitWeeks * scpWeekly * n else 0

/-- The year's Carer Support Payment, pence: as Carer's Allowance (`caYear`, the
same rate, overlapping benefit rule and earnings test). -/
def cspYear (overlap : Nat) (e : Int) : Nat := caYear true overlap e

/-- The Scottish Carer Supplement and the Carer Additional Person Payment for `n`
additional cared for people, pence a year: for each week Carer Support Payment
is payable. -/
def cspExtras (overlap : Nat) (e : Int) (n : Nat) : Nat :=
  if cspYear overlap e > 0 then benefitWeeks * (cspSupplement + cspAdditional * n) else 0

/-- The five amounts of a winter heating payment. -/
structure HeatingAmounts where
  lower : Nat
  lowerShared : Nat
  higher : Nat
  higherSharedWithUnder80 : Nat
  higherSharedWith80 : Nat

def wfpAmounts : HeatingAmounts :=
  ⟨wfpLower, wfpLowerShared, wfpHigher, wfpHigherSharedWithUnder80, wfpHigherSharedWith80⟩

def pawhpAmounts : HeatingAmounts :=
  ⟨pawhpLower, pawhpLowerShared, pawhpHigher, pawhpHigherSharedWithUnder80, pawhpHigherSharedWith80⟩

/-- A winter heating payment with amounts `a` (SI 2025/969 reg 3; SSI 2024/351
reg 10). In Scotland reg 10(6)(b) and (c) have no order between them; living with
entitled people both under and over 80 is read as (c), as reg 3(5) is subject to
reg 3(6) in England and Wales. -/
def heatingAmount (a : HeatingAmounts) (w : WfpCase) : Nat :=
  if !w.entitled then 0
  else if w.relevantBenefit then
    if w.over80 || w.partnerOver80 then a.higher else a.lower
  else if w.over80 then
    if w.withEntitled80 || w.residentialCare then a.higherSharedWith80
    else if w.withEntitledUnder80 then a.higherSharedWithUnder80 else a.higher
  else
    if w.withEntitledUnder80 || w.withEntitled80 || w.residentialCare then a.lowerShared
    else a.lower

/-- The Pension Age Winter Heating Payment, pence. Reg 2A treats the partner of
someone entitled to a relevant benefit as entitled too; reg 9(c), (d) exclude
someone in residential care on a relevant benefit and the member of a couple whose
partner was paid, as `WfpCase.entitled` does. -/
def pawhpAmount (w : WfpCase) : Nat := heatingAmount pawhpAmounts w

/-! ## Proved properties -/

/-- The England and Wales payment is the same rule with its own amounts. -/
theorem wfpAmount_eq (w : WfpCase) : wfpAmount w = heatingAmount wfpAmounts w := by
  unfold wfpAmount heatingAmount wfpAmounts
  rfl

/-- **The Scottish Child Payment cliff.** It goes with the qualifying benefit:
when a family's last penny of Universal Credit is tapered away, £1,466.40 a year
goes for each child. -/
theorem scp_cliff (n : Nat) : scpYear n true = scpYear n false + 146_640 * n := by
  unfold scpYear benefitWeeks scpWeekly
  simp only [ite_true, Bool.false_eq_true, ite_false]
  omega

/-- The Carer Support Payment cliff: at a week's net earnings of £204 the payment
and the supplement are paid, £4,495.40 and £608.40 a year (as `caYear`); a penny
more and both go. -/
theorem csp_cliff (n : Nat) :
    cspYear 0 (caThreshold - 1) + cspExtras 0 (caThreshold - 1) n
      = 449_540 + 60_840 + 54_080 * n ∧
    cspYear 0 caThreshold + cspExtras 0 caThreshold n = 0 := by
  unfold cspExtras cspYear caYear caEarningsOk caWeeklyEarnings caThreshold
  unfold benefitWeeks caEarningsLimit caRate cspSupplement cspAdditional
  constructor <;> simp <;> omega

/-- The Pension Age Winter Heating Payment is never more than £316.70. -/
theorem pawhpAmount_le (w : WfpCase) : pawhpAmount w ≤ pawhpHigher := by
  unfold pawhpAmount heatingAmount pawhpAmounts
  unfold pawhpHigher pawhpLower pawhpHigherSharedWith80 pawhpHigherSharedWithUnder80 pawhpLowerShared
  dsimp only
  split <;> (try split) <;> (try split) <;> (try split) <;> (try split) <;> omega

end UkTax
