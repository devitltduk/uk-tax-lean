import UkTax.Benefits

/-!
# Early learning for disadvantaged 2-year-olds, England (P9c)

A 2-year-old gets 15 hours a week for 38 weeks (SI 2014/2147 regs 3, 4) when the
parent is entitled to Universal Credit with earned income of no more than
£1,283.34 in the assessment period (a couple's combined), or to the guarantee
credit, income-based JSA, income-related ESA, Income Support or asylum support,
or the child has an EHC plan, Disability Living Allowance, or is or was looked
after (reg 1(2), "eligible child"). The months here are equal, so the test is
twelve times the monthly limit (the two- and three-month averages of reg 1(5),
(6) give the same answer).

A child eligible for both the targeted and the working-parent hours gets 30 in
all, the first 15 under the targeted entitlement (DfE statutory guidance, April
2026, para A1.11), so the targeted hours add to `fundedHours` only where the
working-parent hours are not had. They are valued like the other funded hours.
-/

namespace UkTax

/-- The family route: entitled to Universal Credit (an award above nil) with the
year's earned income `e` (1/10 000 pence, the couple's combined) at most twelve
times the monthly limit, or another qualifying benefit. -/
def targetedFamily (onUc : Bool) (e : Int) (other : Bool) : Bool :=
  other || (onUc && decide (e ≤ 10_000 * (12 * targetedUcMonthlyLimit : Nat)))

/-- The yearly value of a child's targeted hours, pence. -/
def FundedChild.targetedValue (ch : FundedChild) : Nat :=
  if ch.band = .two then ch.hourly * targetedHoursWeekly * fundedWeeks else 0

/-- What the targeted hours add, pence a year: for each 2-year-old eligible
through the family or in their own right, unless the working-parent hours are
had (`working`). England only. -/
def targetedExtra (c : Claims) (family working : Bool) : Nat :=
  if c.england && !working then
    (c.fundedChildren.map fun ch => if family || ch.targetedOwn then ch.targetedValue else 0).sum
  else 0

/-! ## Proved properties -/

/-- **The £15,400.08 cliff.** A penny a year of earned income past twelve times
£1,283.34 takes the family route away: at the DfE rate for a 2-year-old, £5,073
a year (15 hours × £8.90 × 38 weeks) for each 2-year-old. -/
theorem targeted_cliff :
    targetedFamily true (10_000 * 1_540_008) false = true ∧
    targetedFamily true (10_000 * 1_540_008 + 1) false = false := by
  unfold targetedFamily targetedUcMonthlyLimit
  decide

theorem targetedValue_two :
    ({ band := .two } : FundedChild).targetedValue = 507_300 := by
  unfold FundedChild.targetedValue FundedChild.hourly AgeBand.rate eyRate2 targetedHoursWeekly fundedWeeks
  decide

/-- With the working-parent hours the targeted hours add nothing: the 2-year-old
already has 30. -/
theorem targetedExtra_working (c : Claims) (f : Bool) : targetedExtra c f true = 0 := by
  unfold targetedExtra
  simp

end UkTax
