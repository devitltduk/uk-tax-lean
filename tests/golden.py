"""Run the golden cases in tests/golden.json through the uktax binary.

Expected values are worked by hand from GOV.UK examples and the legislation (the
working is recorded next to each case), not produced by the model.

Usage: python3 tests/golden.py [path/to/uktax]
"""

import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
binary = sys.argv[1] if len(sys.argv) > 1 else str(ROOT / ".lake/build/bin/uktax")
cases = json.loads((ROOT / "tests/golden.json").read_text())

proc = subprocess.run(
    [binary],
    input=json.dumps([c["input"] for c in cases]),
    capture_output=True,
    text=True,
    check=True,
)
results = json.loads(proc.stdout)
assert len(results) == len(cases), f"expected {len(cases)} results, got {len(results)}"

# Each case states the outputs it was worked for; every one it states is checked.
CHECKED = (
    "liability_pence",
    "student_loan_repayment_ten_thousandths_pence",
    "student_loan_income_pence",
    "winter_fuel_payment_pence",
    "winter_fuel_payment_charge_pence",
    "pension_age_winter_heating_payment_pence",
    "scottish_child_payment_pence",
    "carer_support_payment_pence",
    "scottish_carer_supplement_pence",
    "carer_additional_person_payment_pence",
    "company_car_percent",
    "company_car_benefit_36500ths_pence",
    "car_fuel_benefit_36500ths_pence",
    "tv_licence_pence",
    "isa_subscriptions_above_limit_pence",
    "lifetime_isa_bonus_quarter_pence",
    "minimum_wage_pence",
    "warm_home_discount_pence",
    "tax_exact_ten_thousandths_pence",
    "adjusted_net_income_pence",
    "personal_allowance_pence",
    "trading_profit_pence",
    "property_profit_pence",
    "nic_exact_ten_thousandths_pence",
    "employer_nic_exact_ten_thousandths_pence",
    "class_1a_exact_ten_thousandths_pence",
    "class_4_exact_ten_thousandths_pence",
    "class_2_voluntary_pence",
    "class_2_treated_paid",
    "class_3_pence",
    "hicbc_pence",
    "uc_millionths_pence",
    "tfc_millionths_pence",
    "funded_hours_millionths_pence",
    "funded_hours_targeted_millionths_pence",
    "childcare_eligible",
    "net_income_millionths_pence",
    "child_benefit_pence",
    "disability_benefits_pence",
    "carers_allowance_pence",
    "net_income_carer_ten_thousandths_pence",
    "maternity_allowance_weekly_tenths_pence",
    "jsa_contrib_weekly_pence",
    "esa_contrib_weekly_tenths_pence",
    "ssmg_pence",
    "pension_credit_tenths_pence",
    "guarantee_credit_tenths_pence",
    "new_state_pension_weekly_35ths_pence",
    "housing_benefit_twentieths_pence",
    "council_tax_1440ths_pence",
    "council_tax_reduction_7280ths_pence",
    "cgt_exact_ten_thousandths_pence",
    "sdlt_exact_ten_thousandths_pence",
    "net_income_carer_uc_millionths_pence",
    "uc_earned_income_ten_thousandths_pence",
    "uc_minimum_income_floor_ten_thousandths_pence",
    "housing_benefit_wa_rate_before_millionths_pence",
    "housing_benefit_wa_rate_from_october_millionths_pence",
    "housing_benefit_wa_payable_728_millionths_pence",
    "council_tax_reduction_wa_364m_pence",
    "council_tax_reduction_wa_applicable_weekly_pence",
    "council_tax_reduction_wa_second_adult_364m_pence",
    "council_tax_reduction_wa_bands_e_h_su_pence",
    "council_tax_reduction_wa_total_su_pence",
    "council_tax_reduction_local_lcu_pence",
    "council_tax_reduction_local_applicable_weekly_pence",
    "land_tax_exact_ten_thousandths_pence",
    "land_tax_rent_scaled_ten_thousandths_pence",
    "land_tax_rent_denominator",
    "reliefs_tax_exact_ten_thousandths_pence",
    "reliefs_finance_reduction_ten_thousandths_pence",
    "reliefs_aa_charge_ten_thousandths_pence",
    "reliefs_annual_allowance_pence",
    "reliefs_net_income_pence",
    "reliefs_class_4_exact_ten_thousandths_pence",
)

failures = 0
for case, got in zip(cases, results):
    keys = [k for k in CHECKED if k in case]
    assert keys, f"{case['name']}: no expected output"
    bad = [k for k in keys if got[k] != case[k]]
    failures += bool(bad)
    mark = "FAIL" if bad else "ok  "
    detail = ", ".join(f"{k} expected {case[k]}, got {got[k]}" for k in keys)
    print(f"{mark} {case['name']}: {detail}")

print(f"{len(cases) - failures}/{len(cases)} golden cases passed")
sys.exit(1 if failures else 0)
