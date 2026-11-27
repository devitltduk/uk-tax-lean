import UkTax.Optimal
import UkTax.Charges
import UkTax.Cliffs
import UkTax.Benefits
import UkTax.Profits
import UkTax.Nics
import UkTax.Disability
import UkTax.Pension
import UkTax.HousingBenefit
import UkTax.CouncilTax
import UkTax.Cgt
import UkTax.Sdlt
import UkTax.CarerUc
import UkTax.UcSelfEmployed

import UkTax.HousingBenefitWa
import UkTax.CtrWorkingAge
import UkTax.CtrEnglandLocal
import UkTax.LandTax
import UkTax.Reliefs
import UkTax.StudentLoans
import UkTax.Devolved
import UkTax.Targeted
import UkTax.CompanyCar
import UkTax.Misc
import UkTax.Ved
import UkTax.StudentSupport
import UkTax.CliffMap
import UkTax.CheckParams

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

/-- info: 'UkTax.ctr_step' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.ctr_step

/-- info: 'UkTax.ctr_full' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.ctr_full

/-- info: 'UkTax.councilTax_discount' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.councilTax_discount

/-- info: 'UkTax.cgt_succ_other' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.cgt_succ_other

/-- info: 'UkTax.cgt_succ_badr' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.cgt_succ_badr

/-- info: 'UkTax.cgt_band' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.cgt_band

/-- info: 'UkTax.cgt_exempt' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.cgt_exempt

/-- info: 'UkTax.bandsTax_succ' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.bandsTax_succ

/-- info: 'UkTax.sdlt_succ' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.sdlt_succ

/-- info: 'UkTax.ftb_cliff' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.ftb_cliff

/-- info: 'UkTax.higher_cliff' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.higher_cliff

/-- info: 'UkTax.ucAward_withCa' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.ucAward_withCa

/-- info: 'UkTax.carer_uc_net' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.carer_uc_net

/-- info: 'UkTax.carer_uc_cliff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.carer_uc_cliff

/-- info: 'UkTax.cgtBand_scottish' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.cgtBand_scottish

/-- info: 'UkTax.mifCouple_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.mifCouple_eq

/-- info: 'UkTax.uc_flat_below_floor' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.uc_flat_below_floor

/-- info: 'UkTax.earned_plus_uc_mono_floor' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.earned_plus_uc_mono_floor

/-- info: 'UkTax.hbWa_passport' depends on axioms: [propext] -/
#guard_msgs in
#print axioms UkTax.hbWa_passport

/-- info: 'UkTax.hbWa_capital_cliff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.hbWa_capital_cliff

/-- info: 'UkTax.hbWa_additional_step' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.hbWa_additional_step

/-- info: 'UkTax.hbWa_earnings_gain' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.hbWa_earnings_gain

/-- info: 'UkTax.hbWa_cap_bounds' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.hbWa_cap_bounds

/-- info: 'UkTax.hbWa_cap_specified' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.hbWa_cap_specified

/-- info: 'UkTax.hbWa_abolition' depends on axioms: [propext] -/
#guard_msgs in
#print axioms UkTax.hbWa_abolition

/-- info: 'UkTax.ctrWalesUc_excess' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.ctrWalesUc_excess

/-- info: 'UkTax.ctrWaYear_bounds' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.ctrWaYear_bounds

/-- info: 'UkTax.scotBandsEH_le_main' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.scotBandsEH_le_main

/-- info: 'UkTax.scotBandsEH_floor' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.scotBandsEH_floor

/-- info: 'UkTax.scotTotal_bounds' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.scotTotal_bounds

/-- info: 'UkTax.scot_capital_cliff' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.scot_capital_cliff

/-- info: 'UkTax.newham_at_most_70' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.newham_at_most_70

/-- info: 'UkTax.localYear_taper' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.localYear_taper

/-- info: 'UkTax.oxford_cliff_480' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.oxford_cliff_480

/-- info: 'UkTax.oxfordPct_anti' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.oxfordPct_anti

/-- info: 'UkTax.oxford_mono' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.oxford_mono

/-- info: 'UkTax.bandsTax_add' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.bandsTax_add

/-- info: 'UkTax.sdlt_nonResident' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.sdlt_nonResident

/-- info: 'UkTax.lbtt_ads_cliff' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.lbtt_ads_cliff

/-- info: 'UkTax.ltt_higher_cliff' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.ltt_higher_cliff

/-- info: 'UkTax.lbtt_succ' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.lbtt_succ

/-- info: 'UkTax.ltt_succ' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.ltt_succ

/-- info: 'UkTax.aaCharge_le' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.aaCharge_le

/-- info: 'UkTax.aaTax_slice' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.aaTax_slice

/-- info: 'UkTax.allowance_bounds' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.allowance_bounds

/-- info: 'UkTax.financeReduction_le' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.financeReduction_le

/-- info: 'UkTax.threshold_le' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.threshold_le

/-- info: 'UkTax.sl_unearned_cliff' depends on axioms: [propext] -/
#guard_msgs in
#print axioms UkTax.sl_unearned_cliff

/-- info: 'UkTax.sl_unearned_cliff_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.sl_unearned_cliff_size

/-- info: 'UkTax.sl_succ_earned' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.sl_succ_earned

/-- info: 'UkTax.wfpAmount_le' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.wfpAmount_le

/-- info: 'UkTax.wfp_charge_cliff' depends on axioms: [propext] -/
#guard_msgs in
#print axioms UkTax.wfp_charge_cliff

/-- info: 'UkTax.wfp_charge_benefit' depends on axioms: [propext] -/
#guard_msgs in
#print axioms UkTax.wfp_charge_benefit

/-- info: 'UkTax.wfpAmount_eq' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.wfpAmount_eq

/-- info: 'UkTax.scp_cliff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.scp_cliff

/-- info: 'UkTax.csp_cliff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.csp_cliff

/-- info: 'UkTax.pawhpAmount_le' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.pawhpAmount_le

/-- info: 'UkTax.targeted_cliff' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.targeted_cliff

/-- info: 'UkTax.targetedValue_two' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.targetedValue_two

/-- info: 'UkTax.targetedExtra_working' depends on axioms: [propext] -/
#guard_msgs in
#print axioms UkTax.targetedExtra_working

/-- info: 'UkTax.rangePct_bounds' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.rangePct_bounds

/-- info: 'UkTax.co2Pct_bounds' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.co2Pct_bounds

/-- info: 'UkTax.co2Pct_mono' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.co2Pct_mono

/-- info: 'UkTax.rangePct_anti' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.rangePct_anti

/-- info: 'UkTax.carPct_bounds' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.carPct_bounds

/-- info: 'UkTax.carPct_mono' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.carPct_mono

/-- info: 'UkTax.carPct_range' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.carPct_range

/-- info: 'UkTax.car_50g_step' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.car_50g_step

/-- info: 'UkTax.lisaBonus_le' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.lisaBonus_le

/-- info: 'UkTax.lisa_age_cliff' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.lisa_age_cliff

/-- info: 'UkTax.minimumWage_mono' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.minimumWage_mono

/-- info: 'UkTax.ved_supplement_cliff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.ved_supplement_cliff

/-- info: 'UkTax.vedFirst_top' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.vedFirst_top

/-- info: 'UkTax.vedFirst_mono_lt' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.vedFirst_mono_lt

/-- info: 'UkTax.vedFirst_mono' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.vedFirst_mono

/-- info: 'UkTax.ml80a_anti' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.ml80a_anti

/-- info: 'UkTax.ml80b_anti' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.ml80b_anti

/-- info: 'UkTax.ml80a_d_bounds' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.ml80a_d_bounds

/-- info: 'UkTax.ml80c_cliff' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.ml80c_cliff

/-- info: 'UkTax.pla_cliff' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.pla_cliff

/-- info: 'UkTax.adg_no_cliff' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.adg_no_cliff

/-! Parametric guarantees: the figures as a parameter set (`UkTax/TaxParams.lean`) and the
cliff map (`UkTax/CliffMap.lean`). -/

/-- info: 'UkTax.valid_y2026' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.valid_y2026

/-- info: 'UkTax.TaxParams.maxStep_y2026' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.TaxParams.maxStep_y2026

/-- info: 'UkTax.G_succ_le' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.G_succ_le

/-- info: 'UkTax.Regime.minGain_y2026' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.Regime.minGain_y2026

/-- info: 'UkTax.paStep_y2026' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.paStep_y2026

/-- info: 'UkTax.hicbcStep_y2026' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.hicbcStep_y2026

/-- info: 'UkTax.net_succ_ge' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.net_succ_ge

/-- info: 'UkTax.Regime.maxStep_y2026' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.Regime.maxStep_y2026

/-- info: 'UkTax.cliffMap_complete' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.cliffMap_complete

/-- info: 'UkTax.firstAbove_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.firstAbove_eq

/-- info: 'UkTax.Regime.topRate_y2026' does not depend on any axioms -/
#guard_msgs in
#print axioms UkTax.Regime.topRate_y2026

/-- info: 'UkTax.bandTax_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.bandTax_eq

/-- info: 'UkTax.sliceTax_mono' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.sliceTax_mono

/-! The condition check (`UkTax/CheckParams.lean`) and what `uktax` reports of the cliff map. -/

/-- info: 'UkTax.checkParams_ok_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.checkParams_ok_iff

/-- info: 'UkTax.violations_eq_nil_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.violations_eq_nil_iff

/-- info: 'UkTax.drops_complete' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms UkTax.drops_complete
