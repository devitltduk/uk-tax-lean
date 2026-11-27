import UkTax.Params

/-!
# ISAs, the minimum wage and the Warm Home Discount (P9e)

* **ISAs** (SI 1998/1870 regs 4ZA, 10A, Schedule para 1): subscriptions above
  £20,000 a year are over the limit; the Lifetime ISA bonus is 25 % of the year's
  payments up to £4,000, for a holder aged 18 to 49 (the age-40 limit for the first
  payment is the caller's).
* **The minimum wage** (SI 2015/621 regs 4, 4A, 5): the hourly rate by age, and the
  apprentice rate.
* **Warm Home Discount** (England and Wales, SI 2026/389): £150 for a household on
  a qualifying benefit whose bill is in the recipient's (or partner's) name with a
  participating supplier.
-/

namespace UkTax

/-- Subscriptions over the overall limit, pence. -/
def isaExcess (subs : Nat) : Nat := subs - isaLimit

/-- The Lifetime ISA bonus, pence: 25 % of payments up to £4,000, aged 18 to 49.
Exact in quarter pence: the result is in 1/4 pence. -/
def lisaBonusQuarters (age payments : Nat) : Nat :=
  if 18 ≤ age && age < 50 then min payments lisaLimit else 0

/-- The minimum hourly rate, pence. -/
def minimumWage (age : Nat) (apprentice : Bool) : Nat :=
  if apprentice then nmwApprenticeRate
  else if 21 ≤ age then nlwRate else if 18 ≤ age then nmw18Rate else nmw16Rate

/-- The Warm Home Discount, pence. -/
def whd (englandOrWales qualifying billHolder : Bool) : Nat :=
  if englandOrWales && qualifying && billHolder then whdRebate else 0

/-! ## Proved properties -/

/-- The bonus is at most £1,000 a year (4 000 quarter pence a pound: 400 000
quarters). -/
theorem lisaBonus_le (a p : Nat) : lisaBonusQuarters a p ≤ lisaLimit := by
  unfold lisaBonusQuarters; split <;> omega

/-- **The 50th birthday.** A payment of £4,000 earns a £1,000 bonus at 49 and
none at 50. -/
theorem lisa_age_cliff : lisaBonusQuarters 49 400_000 = 400_000 ∧ lisaBonusQuarters 50 400_000 = 0 := by
  unfold lisaBonusQuarters lisaLimit; decide

/-- The rate never falls with age (outside apprenticeships). -/
theorem minimumWage_mono (a : Nat) : minimumWage a false ≤ minimumWage (a + 1) false := by
  unfold minimumWage nlwRate nmw18Rate nmw16Rate
  simp only [Bool.false_eq_true, ite_false]
  split <;> split <;> (try split) <;> (try split) <;> omega

end UkTax
