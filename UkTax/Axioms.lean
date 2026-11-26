import UkTax.Proofs

/-!
Fails the build if the main theorems ever depend on `sorryAx` or any axiom
beyond Lean's standard ones.
-/

/-- info: 'UkTax.liability_mono' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.liability_mono
