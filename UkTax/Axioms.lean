import UkTax.Optimal
import UkTax.Charges
import UkTax.Cliffs
import UkTax.Benefits
import UkTax.Profits
import UkTax.Nics
import UkTax.Disability
import UkTax.Pension
import UkTax.HousingBenefit

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

/-- info: 'UkTax.earned_plus_uc_mono' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.earned_plus_uc_mono

/-- info: 'UkTax.netAll_drop_only_at_steps' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.netAll_drop_only_at_steps

/-- info: 'UkTax.netAll_succ_ge' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.netAll_succ_ge

/-- info: 'UkTax.fundedHours_over_limit' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.fundedHours_over_limit

/-- info: 'UkTax.fundedHours_drop_at_limit' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.fundedHours_drop_at_limit

/-- info: 'UkTax.maOk_payOnly' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.maOk_payOnly

/-- info: 'UkTax.maStep_above_limit' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.maStep_above_limit

/-- info: 'UkTax.finalTaxExact_succ_le' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.finalTaxExact_succ_le

/-- info: 'UkTax.reliefProfit_succ' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.reliefProfit_succ

/-- info: 'UkTax.propertyProfit_succ_other' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.propertyProfit_succ_other

/-- info: 'UkTax.propertyProfit_succ_room' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.propertyProfit_succ_room

/-- info: 'UkTax.employerNicExact_succ' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.employerNicExact_succ

/-- info: 'UkTax.class4Exact_le_pre' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.class4Exact_le_pre

/-- info: 'UkTax.class4Exact_succ' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.class4Exact_succ

/-- info: 'UkTax.class4Exact_full_class1' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.class4Exact_full_class1

/-- info: 'UkTax.earned_plus_uc_gain' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.earned_plus_uc_gain

/-- info: 'UkTax.childcareMicro_mono' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.childcareMicro_mono

/-- info: 'UkTax.capApplies_anti' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.capApplies_anti

/-- info: 'UkTax.caYear_anti' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.caYear_anti

/-- info: 'UkTax.caYear_change' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.caYear_change

/-- info: 'UkTax.caYear_cliff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.caYear_cliff

/-- info: 'UkTax.netCa_drop_only_at_steps' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.netCa_drop_only_at_steps

/-- info: 'UkTax.netCarer_drop_only_at_steps' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.netCarer_drop_only_at_steps

/-- info: 'UkTax.ma_threshold_cliff' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.ma_threshold_cliff

/-- info: 'UkTax.ma_mono' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.ma_mono

/-- info: 'UkTax.jsa_total_succ' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.jsa_total_succ

/-- info: 'UkTax.esa_total_gain' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.esa_total_gain

/-- info: 'UkTax.nsp_full' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.nsp_full

/-- info: 'UkTax.sc_core' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.sc_core

/-- info: 'UkTax.sc_step' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.sc_step

/-- info: 'UkTax.pc_total_succ' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.pc_total_succ

/-- info: 'UkTax.pc_total_gain' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.pc_total_gain

/-- info: 'UkTax.deemed_step' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.deemed_step

/-- info: 'UkTax.hb_total_gain' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.hb_total_gain

/-- info: 'UkTax.hb_passport' depends on axioms: [propext] -/
#guard_msgs in
#print axioms UkTax.hb_passport

/-- info: 'UkTax.hb_capital_cliff' depends on axioms: [propext] -/
#guard_msgs in
#print axioms UkTax.hb_capital_cliff

/-- info: 'UkTax.nonDep_mono' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.nonDep_mono
