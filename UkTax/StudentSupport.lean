import UkTax.Params

/-!
# Student support in England (P9g)

The Education (Student Support) Regulations 2011 (SI 2011/1986) for the 2026-27
academic year, for a full-time 2016 cohort student with full entitlement:

* **Household income** (Sch 4 paras 3 to 7): the residual incomes of the student
  and, for a dependent student, the parents (and a parent's partner), or, for an
  independent student, the partner; less £1,130 for each dependent child. A
  residual income is taxable income (ITA 2007 s23 Step 1) less pension
  contributions relieved under FA 2004 s188, less, for the student, pay for work
  in the academic years of the course, and less £1,130 for a parent or parent's
  partner who is a student or holds a statutory award. Who counts (the
  independence tests in para 2) and which year's income (the prior financial
  year, para 1(1)(o)) are the caller's.
* **Loan for living costs** (regs 80A, 80B, 80C, 105): the maximum for the category
  less £1 for every complete step of household income over £25,000 (two stages for
  a student who would qualify for a special support grant), not below the minimum
  level; at 60 or over, £4,582 less £1 for every complete £4.16, nil below £50; an
  eligible care leaver gets the maximum.
* **Adult Dependants' Grant and Parents' Learning Allowance** (regs 44, 46, 47):
  the basic amount less half the dependants' income (the residual income of an
  adult dependant or partner and the net income of dependent children) over a
  threshold. The Part 8 contribution (Sch 4 para 9, household income over £39,796)
  and reg 47(1C), (3C) protection are not modelled.
-/

namespace UkTax

/-- The category of reg 90. -/
inductive SfeCat where
  | a | b | c | d
  deriving Repr, DecidableEq

/-- The figure for the category from a list in the order A, B, C, D. -/
def SfeCat.pick (k : SfeCat) (l : List Nat) : Nat :=
  l.getD (match k with | .a => 0 | .b => 1 | .c => 2 | .d => 3) 0

/-- Which schedule of loan applies (reg 71(1)(g), (h), (i)). -/
inductive SfeSchedule where
  /-- Reg 80A. -/
  | standard
  /-- Reg 80B: would qualify for a special support grant but for reg 61(A1). -/
  | benefits
  /-- Reg 80C: 60 or over on the relevant date. -/
  | over60
  deriving Repr, DecidableEq

/-- Complete steps of `step` tenths of a penny in `x` pence. -/
def completeSteps (x step : Nat) : Nat := x * 10 / step

/-- A person's residual income, pence (Sch 4 paras 4, 5(2), 6, 7(1)). -/
def residualIncome (taxable pension termEarnings : Nat) (award : Bool) : Nat :=
  taxable - termEarnings - pension - (if award then sfeChildDeduction else 0)

/-- Household income, pence (Sch 4 para 3): the residual incomes taken together,
less £1,130 for each dependent child. -/
def householdIncome (residuals : List Nat) (children : Nat) : Nat :=
  residuals.sum - sfeChildDeduction * children

/-- Reg 80A: the maximum less £1 per complete step over £25,000, not below the
minimum level (para (4)). -/
def ml80a (k : SfeCat) (final : Bool) (hi : Nat) : Nat :=
  max (k.pick (if final then ml80aMaxFinal else ml80aMax) - completeSteps (hi - sfeThreshold) (k.pick mlTaper))
      (k.pick (if final then mlMinFinal else mlMin))

/-- Reg 80B: the maximum less Y (£25,000 to £42,875) and Z (over £42,875), not
below the minimum level (para (6)). -/
def ml80b (k : SfeCat) (final : Bool) (hi : Nat) : Nat :=
  let y := completeSteps (if hi ≤ sfeHigherThreshold then hi - sfeThreshold else sfeHigherThreshold - sfeThreshold) (k.pick (if final then ml80bTaper1Final else ml80bTaper1))
  let z := completeSteps (hi - sfeHigherThreshold) (k.pick mlTaper)
  max (k.pick (if final then ml80bMaxFinal else ml80bMax) - (y + z)) (k.pick (if final then mlMinFinal else mlMin))

/-- Reg 80C: nil when less than £50 (para (3)). -/
def ml80c (hi : Nat) : Nat :=
  let v := ml80cMax - completeSteps (hi - sfeThreshold) ml80cTaper
  if v < ml80cMinimum then 0 else v

/-- The maximum loan for living costs, pounds. An eligible care leaver gets X
(regs 80A(5), 80B(7), 80C(4)). -/
def maintenanceLoan (s : SfeSchedule) (k : SfeCat) (final careLeaver : Bool) (hi : Nat) : Nat :=
  match s with
  | .standard => if careLeaver then k.pick (if final then ml80aMaxFinal else ml80aMax) else ml80a k final hi
  | .benefits => if careLeaver then k.pick (if final then ml80bMaxFinal else ml80bMax) else ml80b k final hi
  | .over60 => if careLeaver then ml80cMax else ml80c hi

/-- Adult Dependants' Grant, half pence (reg 47(1A), (1AA), (1B)); `x` is the
dependants' income, pence. -/
def adgHalfPence (x : Nat) : Nat :=
  if adgNilAbove < x then 0 else 2 * adgBasic - (x - adgThreshold)

/-- Parents' Learning Allowance, half pence (reg 47(3A), (3AA), (3B), (6)). -/
def plaHalfPence (x : Nat) : Nat :=
  if plaNilAbove < x then 0
  else
    let v := 2 * plaBasic - (x - plaThreshold)
    if 2 ≤ v && v < 2 * plaMinimum then 2 * plaMinimum else v

/-- What the Childcare Grant needs (regs 45, 47): two or more dependent children (the
higher cap and threshold), the weekly prescribed childcare charges (pence, the
same each week), the days in the academic year for which the student applies and
qualifies (at most 365), and whether reg 47(5) halves it (the partner is also a
student, or holds a statutory award, and is supported for the dependants). The
exclusions of reg 45(3), (3B), (4) (the UC childcare costs element, Tax-Free
Childcare, healthcare bursary support, charges paid to the partner) and the
nanny rule of reg 45(7A) are the caller's: an excluded student has no grant. -/
structure CgClaim where
  two : Bool := false
  weeklyCharges : Nat
  days : Nat := 365
  halved : Bool := false
  deriving Repr

/-- Reg 45(5): the basic amount for each week, in hundredths of a penny: 85 % of
the charges, at most the cap. -/
def cgWeekly100 (two : Bool) (w : Nat) : Nat :=
  min (cgPercent * w) (100 * (if two then cgMaxTwo else cgMaxOne))

/-- The Childcare Grant for the academic year, in 1/73,000 of a penny (1/100 of a
penny over the 365 days of the year, halved): above the threshold, reg 47(2A) or
(2B), `A` less the income over the threshold, not below nil; at or below it,
(2AA) or (2BA), `A`; either way for the days qualifying, `× E/F`; nil over the
(2C) limit; halved under (5). `A` is 52 weeks of the basic amount and `x` the
income of reg 47 (the partner's and adult dependants' residual income and the
children's net income, prior financial year), pence.

Read as printed, (2A) and (2B) scale only the reduction by `E/F`
(`A − [(B + C) − D] × [E/F]`), so for part of a year the grant would jump up a
penny above the threshold, from `A × E/F` to nearly `A`. SLC's guidance for
2026-27 scales the whole amount ("(£5,107.24 / 365) x 122 = £1,707.08", where
£5,107.24 is `A` less the excess), as (2AA) does, and so does this
(docs/findings.md #47). Over a whole year the two agree. -/
def childcareGrant73k (cg : CgClaim) (x : Nat) : Nat :=
  let a := 52 * cgWeekly100 cg.two cg.weeklyCharges
  let e := min cg.days cgYearDays
  let d := if cg.two then cgThresholdTwo else cgThresholdOne
  let v :=
    if (if cg.two then cgNilAboveTwo else cgNilAboveOne) < x then 0
    else if d < x then e * (a - 100 * (x - d))
    else e * a
  if cg.halved then v else 2 * v

/-! ## Proved properties -/

/-- **More income never raises the loan** (reg 80A), in every category, in any year. -/
theorem ml80a_anti (k : SfeCat) (f : Bool) (x : Nat) : ml80a k f (x + 1) ≤ ml80a k f x := by
  cases k <;> cases f <;>
    simp only [ml80a, completeSteps, SfeCat.pick, ml80aMax, ml80aMaxFinal, mlTaper, mlMin, mlMinFinal,
      sfeThreshold, List.getD, List.getElem?_cons_zero, List.getElem?_cons_succ, Option.getD_some,
      Bool.false_eq_true, ite_false, ite_true] <;> omega

/-- The same for reg 80B, across both stages. -/
theorem ml80b_anti (k : SfeCat) (f : Bool) (x : Nat) : ml80b k f (x + 1) ≤ ml80b k f x := by
  by_cases h1 : x + 1 ≤ 4_287_500
  · have h0 : x ≤ 4_287_500 := by omega
    cases k <;> cases f <;>
      simp only [ml80b, sfeHigherThreshold, h1, h0, ite_true, completeSteps, SfeCat.pick, ml80bMax, ml80bMaxFinal, ml80bTaper1,
        ml80bTaper1Final, mlTaper, mlMin, mlMinFinal, sfeThreshold, sfeHigherThreshold, List.getD,
        List.getElem?_cons_zero, List.getElem?_cons_succ, Option.getD_some, Bool.false_eq_true, ite_false] <;> omega
  · by_cases h0 : x ≤ 4_287_500
    · cases k <;> cases f <;>
        simp only [ml80b, sfeHigherThreshold, h1, h0, ite_true, completeSteps, SfeCat.pick, ml80bMax, ml80bMaxFinal, ml80bTaper1,
          ml80bTaper1Final, mlTaper, mlMin, mlMinFinal, sfeThreshold, sfeHigherThreshold, List.getD,
          List.getElem?_cons_zero, List.getElem?_cons_succ, Option.getD_some, Bool.false_eq_true, ite_false] <;> omega
    · cases k <;> cases f <;>
        simp only [ml80b, sfeHigherThreshold, h1, h0, ite_true, completeSteps, SfeCat.pick, ml80bMax, ml80bMaxFinal, ml80bTaper1,
          ml80bTaper1Final, mlTaper, mlMin, mlMinFinal, sfeThreshold, sfeHigherThreshold, List.getD,
          List.getElem?_cons_zero, List.getElem?_cons_succ, Option.getD_some, Bool.false_eq_true, ite_false] <;> omega

/-- **The floor.** Whatever the household income, a student living away from home
outside London on the standard schedule gets at least £5,048, and the full £10,830
at £25,000 or less. -/
theorem ml80a_d_bounds (x : Nat) :
    5_048 ≤ ml80a .d false x ∧ ml80a .d false x ≤ 10_830 ∧ (x ≤ 2_500_000 → ml80a .d false x = 10_830) := by
  simp only [ml80a, completeSteps, SfeCat.pick, ml80aMax, mlTaper, mlMin, sfeThreshold, List.getD,
    List.getElem?_cons_zero, List.getElem?_cons_succ, Option.getD_some, Bool.false_eq_true, ite_false]
  omega

/-- **The £50 cliff at 60.** A student aged 60 or over gets £50 at household income
of £43,857.27 and nothing a penny higher. -/
theorem ml80c_cliff : ml80c 4_385_727 = 50 ∧ ml80c 4_385_728 = 0 := by
  simp only [ml80c, completeSteps, ml80cMax, ml80cTaper, ml80cMinimum, sfeThreshold]; decide

/-- **The Parents' Learning Allowance cliff.** £50 at dependants' income of
£18,957.98 (the taper has reached £0.01), nothing a penny higher. -/
theorem pla_cliff : plaHalfPence 1_895_798 = 10_000 ∧ plaHalfPence 1_895_799 = 0 := by
  simp only [plaHalfPence, plaNilAbove, plaBasic, plaThreshold, plaMinimum]; decide

/-- The Adult Dependants' Grant has no cliff: it tapers to a penny before it stops
(at most a penny, in half pence, either side of £15,835.98). -/
theorem adg_no_cliff : adgHalfPence 1_583_598 = 2 ∧ adgHalfPence 1_583_599 = 0 := by
  simp only [adgHalfPence, adgNilAbove, adgBasic, adgThreshold]; decide


/-! ### The Childcare Grant -/

/-- **More income never raises the grant**, for any charges, days, one child or
more, halved or not: the reg 47 taper and the (2C) limit only take away. -/
theorem childcareGrant_anti (two halved : Bool) (w e x : Nat) :
    childcareGrant73k ⟨two, w, e, halved⟩ (x + 1) ≤ childcareGrant73k ⟨two, w, e, halved⟩ x := by
  cases two <;> cases halved <;>
    simp only [childcareGrant73k, cgWeekly100, cgPercent, cgMaxOne, cgMaxTwo, cgThresholdOne,
      cgThresholdTwo, cgNilAboveOne, cgNilAboveTwo, cgYearDays, Bool.false_eq_true, ite_false,
      ite_true] <;> (repeat' split) <;>
    first
      | omega
      | (apply Nat.mul_le_mul_left; omega)
      | (apply Nat.mul_le_mul_left; apply Nat.mul_le_mul_left; omega)

/-- **Bounds.** Over a whole year the grant is never more than 52 weeks of the
weekly basic amount, and at or below the threshold it is exactly that: for one
child at most £10,380.24 (52 × £199.62), for two or more £17,796.48 (52 ×
£342.24), each before any halving. -/
theorem childcareGrant_bounds (two : Bool) (w x : Nat) :
    childcareGrant73k ⟨two, w, 365, false⟩ x ≤ 730 * (52 * cgWeekly100 two w) ∧
      (x ≤ (if two then cgThresholdTwo else cgThresholdOne) →
        childcareGrant73k ⟨two, w, 365, false⟩ x = 730 * (52 * cgWeekly100 two w)) ∧
      52 * cgWeekly100 two w ≤ (if two then 177_964_800 else 103_802_400) := by
  cases two <;>
    simp only [childcareGrant73k, cgWeekly100, cgPercent, cgMaxOne, cgMaxTwo, cgThresholdOne,
    cgThresholdTwo, cgNilAboveOne, cgNilAboveTwo, cgYearDays, Nat.min_self, Bool.false_eq_true, ite_false,
    ite_true] <;> (repeat' split) <;> omega

/-- **No cliff.** At the full cap (charges of at least £234.85 a week for one
child) the taper has brought the grant for a whole year down to 1p at £20,107.23,
the (2C) limit, and it is nil a penny higher; for two or more children (charges of
at least £402.64 a week) the same at £28,914.47. With lower charges the taper
reaches nil before the limit. 1p is 73,000 units. -/
theorem childcareGrant_no_cliff :
    childcareGrant73k ⟨false, 23_485, 365, false⟩ 2_010_723 = 73_000 ∧
      childcareGrant73k ⟨false, 23_485, 365, false⟩ 2_010_724 = 0 ∧
      childcareGrant73k ⟨true, 40_264, 365, false⟩ 2_891_447 = 73_000 ∧
      childcareGrant73k ⟨true, 40_264, 365, false⟩ 2_891_448 = 0 := by
  simp only [childcareGrant73k, cgWeekly100, cgPercent, cgMaxOne, cgMaxTwo, cgThresholdOne,
    cgThresholdTwo, cgNilAboveOne, cgNilAboveTwo, cgYearDays, Nat.min_self, Bool.false_eq_true, ite_false,
    ite_true]
  decide

/-- **SLC's worked examples** (SFE Grants for Dependants AY 2026/27, the Miriam
example): dependants' income £15,000 at the full caps gives £13,914.48 a year for
two children and £5,107.24 for one; for 243 and 122 days, £9,263.61 and
£1,707.08 to the penny (here exactly £9,263.6127... and £1,707.0774...). -/
theorem childcareGrant_slc :
    childcareGrant73k ⟨true, 40_264, 365, false⟩ 1_500_000 = 73_000 * 1_391_448 ∧
      childcareGrant73k ⟨false, 23_485, 365, false⟩ 1_500_000 = 73_000 * 510_724 ∧
      childcareGrant73k ⟨true, 40_264, 243, false⟩ 1_500_000 = 67_624_372_800 ∧
      childcareGrant73k ⟨false, 23_485, 122, false⟩ 1_500_000 = 12_461_665_600 := by
  simp only [childcareGrant73k, cgWeekly100, cgPercent, cgMaxOne, cgMaxTwo, cgThresholdOne,
    cgThresholdTwo, cgNilAboveOne, cgNilAboveTwo, cgYearDays, Nat.min_self, Bool.false_eq_true, ite_false,
    ite_true]
  decide

end UkTax
