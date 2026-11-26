import UkTax.Optimal

/-!
Fails the build if the main theorems ever depend on `sorryAx` or any axiom
beyond Lean's standard three.
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
