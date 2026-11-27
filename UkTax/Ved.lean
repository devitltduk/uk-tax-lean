import UkTax.Params

/-!
# Vehicle Excise Duty for cars (P9f)

The duty for the twelve-month licence in force for 2026-27, single payment, whole
pounds (VERA 1994 Sch 1 Parts 1A, 1AA, 1AB, rates from 1 April 2026):

* registered from 1 April 2017: the first licence by CO2 (a higher table for
  diesel cars not meeting RDE2), later licences £200, plus £440 in licence years 2
  to 6 for a list price over £40,000 (£50,000 for a zero emission car, and none for
  one registered before 1 April 2025);
* registered 1 March 2001 to 31 March 2017: bands A to M by CO2, band K at most for
  a car registered before 23 March 2006;
* earlier: by engine size.
-/

namespace UkTax

/-- The rate for `x` in a banded table: the first band whose upper limit `x` does
not exceed, else the last rate. -/
def bandRate : List Nat → List Nat → Nat → Nat
  | r :: rs, l :: ls, x => if x ≤ l then r else bandRate rs ls x
  | r :: _, [], _ => r
  | [], _, _ => 0

/-- What a car's duty turns on. -/
inductive VedCar where
  /-- Registered from 1 April 2017: CO2, diesel not meeting RDE2, zero emission,
  registered before 1 April 2025, list price (pence), licence year (0 = the first
  licence). -/
  | modern (co2 : Nat) (diesel zev zevPre2025 : Bool) (price year : Nat)
  /-- Registered 1 March 2001 to 31 March 2017: CO2, registered before 23 March 2006. -/
  | graduated (co2 : Nat) (pre2006 : Bool)
  /-- Registered before 1 March 2001: engine over 1,549cc. -/
  | old (large : Bool)

/-- The duty, pounds. -/
def ved : VedCar → Nat
  | .modern co2 diesel zev pre price year =>
    let co2 := if zev then 0 else co2
    if year = 0 then bandRate (if diesel then vedFirstYearDiesel else vedFirstYear) vedFirstYearLimits co2
    else
      let threshold := if zev then vedPriceThresholdZev else vedPriceThreshold
      vedStandard + (if year ≤ 5 && threshold < price && !(zev && pre) then vedSupplement else 0)
  | .graduated co2 pre2006 =>
    bandRate vedGraduated vedGraduatedLimits (if pre2006 then min co2 225 else co2)
  | .old large => if large then vedLargeEngine else vedSmallEngine

/-! ## Proved properties -/

/-- **The £40,000 list price.** A penny over it costs £440 a year for five years
(£2,200), whatever the CO2. -/
theorem ved_supplement_cliff (co2 y : Nat) (h1 : 1 ≤ y) (h5 : y ≤ 5) :
    ved (.modern co2 false false false vedPriceThreshold y) = 200 ∧
    ved (.modern co2 false false false (vedPriceThreshold + 1) y) = 640 := by
  unfold ved vedStandard vedSupplement vedPriceThreshold
  have : y ≠ 0 := by omega
  have h5' : decide (y ≤ 5) = true := by simp [h5]
  simp [this, h5']

/-- Above 255 g/km the first licence costs the top rate. -/
theorem vedFirst_top (x : Nat) (h : 255 < x) : bandRate vedFirstYear vedFirstYearLimits x = 5690 := by
  simp only [bandRate, vedFirstYear, vedFirstYearLimits]
  simp only [show ¬ x ≤ 0 by omega, show ¬ x ≤ 50 by omega, show ¬ x ≤ 75 by omega, show ¬ x ≤ 90 by omega, show ¬ x ≤ 100 by omega, show ¬ x ≤ 110 by omega, show ¬ x ≤ 130 by omega, show ¬ x ≤ 150 by omega, show ¬ x ≤ 170 by omega, show ¬ x ≤ 190 by omega, show ¬ x ≤ 225 by omega, show ¬ x ≤ 255 by omega, ite_false]

set_option maxRecDepth 20000 in
/-- The first licence of a petrol car never costs less as CO2 rises, checked
gram by gram up to 260 g/km and constant above. -/
theorem vedFirst_mono_lt : ∀ x, x < 260 →
    bandRate vedFirstYear vedFirstYearLimits x ≤ bandRate vedFirstYear vedFirstYearLimits (x + 1) := by
  decide

theorem vedFirst_mono (x : Nat) :
    bandRate vedFirstYear vedFirstYearLimits x ≤ bandRate vedFirstYear vedFirstYearLimits (x + 1) := by
  by_cases h : x < 260
  · exact vedFirst_mono_lt x h
  · rw [vedFirst_top x (by omega), vedFirst_top (x + 1) (by omega)]; exact Nat.le_refl _

end UkTax
