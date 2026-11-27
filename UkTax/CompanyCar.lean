import UkTax.Params

/-!
# Company cars, car fuel and the TV licence (P9d)

* **Company car benefit** (ITEPA 2003 ss 120, 121, 132, 139, 141, 143, 144): the
  list price less capital contributions (up to £5,000), times the appropriate
  percentage, less the share for days unavailable (U/Y × A), less payments for
  private use, not below nil.
* **Car fuel benefit** (ss 149-152): the appropriate percentage of £29,200, less
  the same share for days unavailable; nil when the employee makes good all private
  fuel (s151) and for a car that cannot emit CO2 (s149(4)).
* **TV licence** (SI 2004/692 Sch 1, reg 5; Communications Act 2003 s365A): £180,
  half for a blind licence holder, nil under the BBC's concession for a licence
  holder of 75 or over who, or whose partner, receives Pension Credit.

Cash equivalents are exact in 1/36 500 pence (a hundredth of a percentage point,
per day of the 365-day year).
-/

namespace UkTax

/-- The s139 table for 1-50 g/km by electric range `r` (miles, rounded up). -/
def rangePct (r : Nat) : Nat :=
  if 130 ≤ r then 4 else if 70 ≤ r then 7 else if 40 ≤ r then 10 else if 30 ≤ r then 14 else 16

/-- From 51 g/km: the table's 17 % to 21 % in steps of 5 g/km up to 74 (17 % plus
a point for each full 5 g/km above 50: 51-54 17 %, ..., 70-74 21 %), then s139(3)
and (4), 21 % plus a point for each full 5 g/km above 75, at most 37 %. -/
def co2Pct (c : Nat) : Nat :=
  if c ≤ 74 then 17 + (c - 50) / 5 else min (21 + (c - 75) / 5) carMaxPct

/-- The appropriate percentage, whole percentage points, for a car with CO2
emissions figure `co2` (g/km, rounded down) and electric range `range` (miles,
rounded up), `diesel` when s141 applies. -/
def carPct (co2 range : Nat) (diesel : Bool) : Nat :=
  let base := if co2 = 0 then 4 else if co2 ≤ 50 then rangePct range else co2Pct co2
  -- s141(3): a car that cannot emit CO2 is not propelled by diesel
  if diesel && co2 ≠ 0 then min (base + carDieselSupplement) carMaxPct else base

/-- The company car's cash equivalent, 1/36 500 pence: list price `price`,
capital contributions `contrib`, days unavailable `u`, payments `pay` (pence). -/
def carBenefit (price contrib co2 range : Nat) (diesel : Bool) (u pay : Nat) : Nat :=
  (price - min contrib carContributionCap) * carPct co2 range diesel * (taxYearDays - u)
    - 100 * taxYearDays * pay

/-- The car fuel benefit, 1/36 500 pence. -/
def fuelBenefit (co2 range : Nat) (diesel : Bool) (u : Nat) (provided : Bool) : Nat :=
  if provided && co2 ≠ 0 then carFuelMultiplier * carPct co2 range diesel * (taxYearDays - u) else 0

/-- The TV licence fee, pence. -/
def tvLicence (required blind over75WithPc : Bool) : Nat :=
  if !required || over75WithPc then 0 else if blind then tvLicenceFee / 2 else tvLicenceFee

/-! ## Proved properties -/

theorem rangePct_bounds (r : Nat) : 4 ≤ rangePct r ∧ rangePct r ≤ 16 := by
  unfold rangePct; split <;> (try split) <;> (try split) <;> (try split) <;> omega

theorem co2Pct_bounds (c : Nat) (h : 51 ≤ c) : 17 ≤ co2Pct c ∧ co2Pct c ≤ carMaxPct := by
  unfold co2Pct carMaxPct; split <;> omega

theorem co2Pct_mono (c : Nat) (h : 51 ≤ c) : co2Pct c ≤ co2Pct (c + 1) := by
  unfold co2Pct carMaxPct; split <;> split <;> omega

theorem rangePct_anti (r : Nat) : rangePct (r + 1) ≤ rangePct r := by
  unfold rangePct
  repeat' split
  all_goals omega

/-- The base percentage (before the diesel supplement). -/
theorem carPct_false (c r : Nat) :
    carPct c r false = if c = 0 then 4 else if c ≤ 50 then rangePct r else co2Pct c := by
  unfold carPct; simp

theorem carPct_true (c r : Nat) (h : c ≠ 0) :
    carPct c r true = min ((if c = 0 then 4 else if c ≤ 50 then rangePct r else co2Pct c)
      + carDieselSupplement) carMaxPct := by
  unfold carPct; simp [h]

theorem carPct_zero (r : Nat) (d : Bool) : carPct 0 r d = 4 := by
  unfold carPct; cases d <;> simp

/-- The appropriate percentage is between 4 % and 37 %. -/
theorem carPct_bounds (co2 range : Nat) (d : Bool) :
    4 ≤ carPct co2 range d ∧ carPct co2 range d ≤ carMaxPct := by
  have hr := rangePct_bounds range
  have hc := co2Pct_bounds co2
  cases d
  · rw [carPct_false]; unfold carMaxPct at *
    split
    · omega
    · split
      · omega
      · have := hc (by omega); omega
  · by_cases h0 : co2 = 0
    · subst h0; rw [carPct_zero]; unfold carMaxPct; omega
    rw [carPct_true _ _ h0]; unfold carMaxPct carDieselSupplement at *
    split
    · omega
    · split
      · omega
      · have := hc (by omega); omega

/-- More CO2 never lowers the percentage (for the same range and fuel). -/
theorem carPct_mono (c range : Nat) (d : Bool) :
    carPct c range d ≤ carPct (c + 1) range d := by
  have hr := rangePct_bounds range
  have hb := co2Pct_bounds (c + 1)
  have hm := co2Pct_mono c
  cases d
  · rw [carPct_false, carPct_false]; unfold carMaxPct at *
    by_cases h0 : c = 0
    · subst h0; simp; omega
    · by_cases h50 : c + 1 ≤ 50
      · simp [h0, h50, show c ≤ 50 by omega]
      · by_cases h : c ≤ 50
        · have := hb (by omega); simp [h0, h, h50]; omega
        · have := hm (by omega); simp [h0, h, h50]; omega
  · by_cases h0 : c = 0
    · subst h0; rw [carPct_zero, carPct_true _ _ (by omega)]; unfold carMaxPct carDieselSupplement at *; simp; omega
    rw [carPct_true _ _ h0, carPct_true _ _ (by omega)]; unfold carMaxPct carDieselSupplement at *
    · by_cases h50 : c + 1 ≤ 50
      · simp [h0, h50, show c ≤ 50 by omega]
      · by_cases h : c ≤ 50
        · have := hb (by omega); simp [h0, h, h50]; omega
        · have := hm (by omega); simp [h0, h, h50]; omega

/-- A longer electric range never raises it. -/
theorem carPct_range (c r : Nat) (d : Bool) :
    carPct c (r + 1) d ≤ carPct c r d := by
  have := rangePct_anti r
  cases d
  · rw [carPct_false, carPct_false]; split <;> (try split) <;> omega
  · by_cases h0 : c = 0
    · subst h0; rw [carPct_zero, carPct_zero]; exact Nat.le_refl 4
    rw [carPct_true _ _ h0, carPct_true _ _ h0]; split <;> (try split) <;> omega

/-- **The 50 g/km step.** A hybrid with 130 miles of electric range at 50 g/km is
taxed at 4 %; one more gram, at 17 %: on a £40,000 car, £5,200 more of benefit
(£2,080 more tax for a higher-rate taxpayer). -/
theorem car_50g_step : carPct 50 130 false = 4 ∧ carPct 51 130 false = 17 := by
  unfold carPct rangePct co2Pct carMaxPct
  decide

end UkTax
