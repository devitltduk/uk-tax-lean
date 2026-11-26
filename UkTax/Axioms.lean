import UkTax.Optimal
import UkTax.Charges
import UkTax.Cliffs

/-!
Fails the build if the main theorems ever depend on `sorryAx` or any axiom
beyond Lean's standard three. Each guard states the exact set a theorem uses
today, so any change to it is seen.
-/

/-- info: 'UkTax.leastTax_mono' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.leastTax_mono

/-- info: 'UkTax.liability_mono_of_optimal' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.liability_mono_of_optimal

/-- info: 'UkTax.exists_isLeastTax' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.exists_isLeastTax

/-- info: 'UkTax.isLeastTax_taxExact' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.isLeastTax_taxExact

/-- info: 'UkTax.liability_mono' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.liability_mono

/-- info: 'UkTax.nicExact_mono' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.nicExact_mono

/-- info: 'UkTax.hicbc_mono_income' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.hicbc_mono_income

/-- info: 'UkTax.hicbc_le' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.hicbc_le

/-- info: 'UkTax.taxExact_succ_le' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.taxExact_succ_le

/-- info: 'UkTax.net_drop_only_at_steps' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.net_drop_only_at_steps
