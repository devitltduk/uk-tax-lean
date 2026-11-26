import UkTax.Charges
import UkTax.Profits

/-!
# National Insurance contributions other than employee Class 1, 2026-27

Employer (secondary) Class 1, Class 1A, Class 2, Class 3 and Class 4, with the
Class 4 annual maximum for someone who also pays employee Class 1. Amounts are in
pence, rates in basis points, results exact in 1/10 000 of a penny, like the rest
of the model. Sources were read on legislation.gov.uk (revised text in force on
6 April 2026) on 2026-11-26.

The 2026-27 instrument is the Social Security (Contributions) (Rates, Limits and
Thresholds Amendments, National Insurance Funds Payments and Extension of
Veteran's Relief) Regulations 2026 (SI 2026/231)
<https://www.legislation.gov.uk/uksi/2026/231/made>: it sets the Class 2 rate and
small profits threshold, the Class 3 rate and the lower earnings limit, and moves
SI 2001/1004 reg 10 to 2026-27. The other figures are carried forward from the
amendments that last set them, named below.
-/

namespace UkTax

/-! ## Class 1 secondary (employer) -/

/-- The secondary percentage, 15 %: SSCBA 1992 s9(2) ("the secondary percentage
is 15%") <https://www.legislation.gov.uk/ukpga/1992/4/section/9>, as amended by the
National Insurance Contributions (Secondary Class 1 Contributions) Act 2025 s1. -/
def secondaryRate : Nat := 1500

/-- Secondary threshold: £96 a week (SI 2001/1004 reg 10(d)), £417 a month and
£5,000 a year (reg 11(3A)(a), (b))
<https://www.legislation.gov.uk/uksi/2001/1004/regulation/11>, as substituted by the
2025 Act s2. -/
def secondaryThresholdWeekly : Nat := 9_600
def secondaryThresholdMonthly : Nat := 41_700
def secondaryThresholdAnnual : Nat := 500_000

/-- Upper secondary threshold for the under 21 group (s9A) and for relevant
apprentices under 25 (s9B): £967 a week, £4,189 a month, £50,270 a year (reg
10(e), (f), 11(3B), (3C)). Below it the secondary percentage is 0 %. -/
def upperSecondaryWeekly : Nat := 96_700
def upperSecondaryMonthly : Nat := 418_900
def upperSecondaryAnnual : Nat := 5_027_000

/-- The secondary threshold for the year on each earnings-period basis. -/
def EarningsPeriod.secondaryThreshold : EarningsPeriod → Nat
  | .annual => secondaryThresholdAnnual
  | .monthly => 12 * secondaryThresholdMonthly
  | .weekly => 52 * secondaryThresholdWeekly

/-- The upper secondary threshold for the year on each basis. -/
def EarningsPeriod.upperSecondaryThreshold : EarningsPeriod → Nat
  | .annual => upperSecondaryAnnual
  | .monthly => 12 * upperSecondaryMonthly
  | .weekly => 52 * upperSecondaryWeekly

/-- Employer Class 1 contributions for the year on earnings `e`, exact (1/10 000
pence): 15 % above the secondary threshold, or for an employee under 21 or a
relevant apprentice under 25 (`zeroRated`) 15 % above the upper secondary
threshold, 0 % below it (s9(1), s9A, s9B). Earnings are spread evenly over the
periods, as for employee contributions. The Employment Allowance (£10,500 a year
per employer, NICA 2014 s1) is the employer's and is not set against one
employee's contributions here. -/
def employerNicExact (p : EarningsPeriod) (zeroRated : Bool) (e : Nat) : Nat :=
  secondaryRate * (e - if zeroRated then p.upperSecondaryThreshold else p.secondaryThreshold)

/-- Class 1A percentage: equal to the secondary percentage, 15 % (SSCBA 1992
s10(5) <https://www.legislation.gov.uk/ukpga/1992/4/section/10>), on the cash
equivalent of taxable benefits in kind (s10(1)), such as a company car. The cash
equivalent is an input. -/
def class1AExact (benefits : Nat) : Nat := secondaryRate * benefits

/-! ## Class 2 and Class 3 -/

/-- Small profits threshold, £7,105: SSCBA 1992 s11(4)(b)
<https://www.legislation.gov.uk/ukpga/1992/4/section/11>, set by SI 2026/231 reg 3(a).
From 6 April 2024 no Class 2 is payable as of course (s11(2) omitted by the
National Insurance Contributions (Reduction in Rates) Act 2023 s3): an earner with
relevant profits (the Class 4 profits, s11(3)) of at least the threshold is
treated as having paid Class 2 for each week (s11(5A), (5B)). -/
def smallProfitsThreshold : Nat := 710_500

/-- Voluntary Class 2, £3.65 a week, for an earner with profits below the small
profits threshold who chooses to pay (s11(6); SI 2026/231 reg 3(b)). -/
def class2Weekly : Nat := 365

/-- Class 3, £18.40 a week (SSCBA 1992 s13(1)
<https://www.legislation.gov.uk/ukpga/1992/4/section/13>; SI 2026/231 reg 4). -/
def class3Weekly : Nat := 1_840

/-- Class 2 treated as paid: profits at or above the small profits threshold. -/
def class2TreatedPaid (profits : Nat) : Bool := smallProfitsThreshold ≤ profits

/-- Voluntary Class 2 for `weeks` weeks, in pence: only below the threshold (an
earner treated as paid has nothing to pay). -/
def class2Voluntary (profits weeks : Nat) : Nat :=
  if class2TreatedPaid profits then 0 else weeks * class2Weekly

/-- Class 3 for `weeks` weeks, in pence. -/
def class3 (weeks : Nat) : Nat := weeks * class3Weekly

/-! ## Class 4 -/

/-- Lower and upper profits limits, £12,570 and £50,270, and the main and
additional Class 4 percentages, 6 % and 2 %: SSCBA 1992 s15(3), (3ZA)
<https://www.legislation.gov.uk/ukpga/1992/4/section/15>. The profits are those of
trades chargeable to income tax under ITTOIA 2005 Part 2 Chapter 2 (s15(1)), so
after the trading allowance; loss relief (Sch 2 para 3) is not modelled. -/
def lowerProfitsLimit : Nat := 1_257_000
def upperProfitsLimit : Nat := 5_027_000
def class4MainRate : Nat := 600
def class4AdditionalRate : Nat := 200

/-- Class 4 before the annual maximum, exact. -/
def class4Pre (prof : Nat) : Nat :=
  class4MainRate * (min prof upperProfitsLimit - lowerProfitsLimit)
    + class4AdditionalRate * (prof - upperProfitsLimit)

/-- The main-rate part of Class 4 (needed by the annual maximum). -/
def class4Main (prof : Nat) : Nat :=
  class4MainRate * (min prof upperProfitsLimit - lowerProfitsLimit)

/-- Employee Class 1 paid at the main primary percentage, exact. -/
def nicMainExact (p : EarningsPeriod) (e : Nat) : Nat :=
  nicMainRate * (min e p.upperEarningsLimit - p.primaryThreshold)

/-- The Class 4 annual maximum of SI 2001/1004 reg 100(3)
<https://www.legislation.gov.uk/uksi/2001/1004/regulation/100>, times 3 (so that
Step Eight, 2 % of Step Seven, where Step Seven is a profit found by multiplying
by 100/6, stays a whole number of units), for main-rate employee contributions
`c1` (exact) and Class 4 profits `prof`:

* Step Two: 6 % of the upper less the lower profits limit;
* Step Four: less `c1` (Case 3: nil if negative);
* Case 1: Step Four exceeds `c1` plus main-rate Class 4: the maximum is Step Four;
* otherwise: Step Four, plus 2 % of what is left of the main band after Step Four
  is turned back into profits at 100/6 (Steps Five to Eight), plus 2 % of the
  profits above the upper limit (Step Nine). -/
def class4Max3 (c1 prof : Nat) : Nat :=
  let step2 := class4MainRate * (upperProfitsLimit - lowerProfitsLimit)
  let step4 := step2 - c1
  if c1 < step2 ∧ c1 + class4Main prof < step4 then 3 * step4
  else
    -- 3 × Step Eight = 2 % × 3 × Step Seven = (6 % × Step Six − Step Four)⁺
    3 * step4 + (class4MainRate * (min prof upperProfitsLimit - lowerProfitsLimit) - step4)
      + 3 * class4AdditionalRate * (prof - upperProfitsLimit)

/-- Class 4 for the year, exact: before the maximum, limited by reg 100 where
employee Class 1 is also payable (reg 100(1)(a)). Where the maximum applies it is
rounded down to 1/10 000 of a penny, the only rounding in the model below that. -/
def class4Exact (p : EarningsPeriod) (e prof : Nat) : Nat :=
  if 0 < nicExact p e then min (class4Pre prof) (class4Max3 (nicMainExact p e) prof / 3)
  else class4Pre prof

/-! ## Properties -/

/-- Employer contributions never fall as pay rises, and rise by at most 15 % of
it. -/
theorem employerNicExact_succ (p : EarningsPeriod) (z : Bool) (e : Nat) :
    employerNicExact p z e ≤ employerNicExact p z (e + 1) ∧
      employerNicExact p z (e + 1) ≤ employerNicExact p z e + secondaryRate := by
  unfold employerNicExact
  generalize (if z = true then p.upperSecondaryThreshold else p.secondaryThreshold) = T
  unfold secondaryRate
  omega

/-- The annual maximum never raises Class 4. -/
theorem class4Exact_le_pre (p : EarningsPeriod) (e prof : Nat) :
    class4Exact p e prof ≤ class4Pre prof := by
  unfold class4Exact; split <;> omega

/-- Class 4 never falls as profits rise, with or without the annual maximum, and a
penny more profit adds at most 6 % of a penny. -/
theorem class4Exact_succ (p : EarningsPeriod) (e prof : Nat) :
    class4Exact p e prof ≤ class4Exact p e (prof + 1) ∧
      class4Exact p e (prof + 1) ≤ class4Exact p e prof + class4MainRate := by
  have hLU : lowerProfitsLimit ≤ upperProfitsLimit := by decide
  unfold class4Exact class4Max3 class4Pre class4Main
  generalize nicMainExact p e = c
  generalize nicExact p e = n
  generalize upperProfitsLimit = U at *
  generalize lowerProfitsLimit = L at *
  unfold class4MainRate class4AdditionalRate
  dsimp only
  repeat' split
  all_goals omega

/-- With employee contributions at the main rate on a full band (pay at the upper
earnings limit on the annual basis), Class 4 is 2 % of all profits above the
lower limit: the employee has already paid 8 % on the whole band, more than the
6 % Class 4 would charge on it, so reg 100 leaves only the additional rate. -/
theorem class4Exact_full_class1 (prof : Nat) :
    class4Exact .annual upperEarningsLimitAnnual prof
      = class4AdditionalRate * (prof - lowerProfitsLimit) := by
  have h1 : nicMainExact .annual upperEarningsLimitAnnual
      = nicMainRate * (upperProfitsLimit - lowerProfitsLimit) := by decide
  have h2 : 0 < nicExact .annual upperEarningsLimitAnnual := by decide
  have hLU : lowerProfitsLimit ≤ upperProfitsLimit := by decide
  unfold class4Exact class4Max3 class4Pre class4Main
  rw [h1]
  simp only [h2, ↓reduceIte]
  generalize upperProfitsLimit = U at *
  generalize lowerProfitsLimit = L at *
  unfold class4MainRate class4AdditionalRate nicMainRate
  try dsimp only
  repeat' split
  all_goals omega

end UkTax
