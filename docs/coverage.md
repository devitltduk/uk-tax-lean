# Coverage of PolicyEngine UK

What [PolicyEngine UK](https://github.com/PolicyEngine/policyengine-uk) **2.180.2**
(pinned in `harness/pyproject.toml`) models, and how much of it this repository
formalises in Lean for the 2026-27 tax year.

The aim is the statutory calculation for one household: given who is in it, what
they earn and own and what they pay, what each tax and benefit comes to under the
law. Microsimulation, survey data and its imputations, take-up modelling,
behavioural responses, forecasts and hypothetical reforms are out of scope.

PolicyEngine's own list of programmes is `policyengine_uk/programs.yaml`; this
inventory follows it and adds what the list leaves out (components it counts
under a bigger programme, and variables with no entry). The variable tree has
1,517 variables, 1,001 with formulas.

**Status**

- **done**: modelled in Lean with every figure cited, properties proved where
  they mean something, golden cases, and a harness comparison with PolicyEngine;
- **planned (Pn)**: to be built, in the order of the PR plan below;
- **out of scope**: with the reason.

Legal sources are the main ones; the Lean files cite each figure to the section,
regulation or GOV.UK page it comes from, checked when that part is built.

## PR plan

| | Area | Programmes |
|---|---|---|
| P1 | Scottish income tax, Gift Aid, relief at source | Scottish rates on non-savings income, savings and dividends on UK rates, s25(2) placement for Scottish taxpayers; Gift Aid and relief-at-source pension contributions raising the rate limits and reducing adjusted net income |
| P2 | Reliefs and allowances | net pay pension contributions, Marriage Allowance, Blind Person's Allowance, trading and property allowances, self-employment profits |
| P3 | NICs completeness | Class 2, 3 and 4, employer Class 1, Class 1A |
| P4 | Universal Credit in full | every element, housing costs, childcare costs element, capital and unearned income, minimum income floor, the benefit cap |
| P5 | Other means-tested and disability benefits | Housing Benefit, legacy benefits still in payment, Child Benefit, PIP, DLA, Attendance Allowance, Carer's Allowance, contributory JSA and ESA, Maternity Allowance, Sure Start Maternity Grant |
| P6 | Pensions | State Pension (new and basic), Pension Credit |
| P7 | Council tax | council tax, Council Tax Reduction |
| P8 | CGT and property taxes | Capital Gains Tax, SDLT, LBTT, LTT |
| P9 | The rest | consumption duties, student loans, TV licence, ISAs, devolved benefits, other childcare schemes, energy and winter payments, student support |

## Taxes on income

| Programme | PolicyEngine variables | Legal source | Status |
|---|---|---|---|
| Income tax, rUK rates: personal allowance and taper, bands, savings (starting rate, personal savings allowance), dividends, s25(2) allowance placement | `income_tax`, `personal_allowance`, `earned_income_tax`, `savings_income_tax`, `dividend_income_tax`, `savings_allowance`, `dividend_allowance` | ITA 2007 ss 6-16, 23, 25, 35; Finance Act 2026 ss 1-4, 9; FA 2021 s5 as amended by FA 2023 s5 (allowance and basic rate limit frozen) | **done** (England, Wales, NI; Welsh rates equal rUK for 2026-27) |
| Welsh rates of income tax | `income_tax` (country = Wales) | ITA 2007 s6B; Senedd rate resolution NDM9117 | **done** (10p in each band, so the rUK rates) |
| Scottish income tax: Scottish rates on non-savings income, savings and dividends at UK rates in UK bands, the UK test for the savings allowance | `income_tax` via `gov.hmrc.income_tax.rates.scotland`, `tax_band` | ITA 2007 ss 11A, 11D(6), 12B(8), 13(5); Scottish rate resolution 2026-27 (S6M-20844); Scotland Act 1998 s80C | **done** (P1) |
| High Income Child Benefit Charge | `child_benefit_hitc` (in `income_tax` at Step 7) | ITEPA 2003 ss 681B-681H; ITA 2007 s30 | **done** |
| Pension contributions relieved at source: raised rate limits (rUK and Scottish), adjusted net income | `personal_pension_contributions`, `pension_contributions_relief` | Finance Act 2004 ss 190-192; ITA 2007 s58 | **done** (P1, the member's liability; findings #7, #8) |
| Net pay pension contributions, the relief cap, the annual allowance charge | `employee_pension_contributions`, `net_pay_pension_relief`, `pension_annual_allowance`, `pension_annual_allowance_chargeable_amount` | Finance Act 2004 ss 190, 193, 227-228ZA | planned (P2) |
| Salary sacrifice for pensions | `pension_contributions_via_salary_sacrifice_*`, `salary_sacrifice_pension_ni_*` | ITEPA 2003 s62 (a contract variation, no statutory rule for income tax); NICs cap: National Insurance Contributions (Employer Pensions Contributions) Act 2026 s1, inserting SSCBA 1992 s4(6A) | planned (P2, as lower pay) |
| Gift Aid: raised rate limits (rUK and Scottish), adjusted net income | `gift_aid`, `gift_aid_grossed_up` | ITA 2007 ss 414-415, 58 | **done** (P1) |
| Gifts of shares and land to charity | `charitable_investment_gifts` | ITA 2007 Part 8 Ch 3 | planned (P2) |
| Marriage Allowance | `marriage_allowance`, `marriage_allowance_tax_reduction` | ITA 2007 ss 55A-55E | planned (P2) |
| Married couple's allowance | `married_couples_allowance`, `married_couples_allowance_deduction` | ITA 2007 ss 42-55 | planned (P2) |
| Blind Person's Allowance | `blind_persons_allowance` | ITA 2007 s38 | planned (P2) |
| Trading and property allowances | `trading_allowance_deduction`, `property_allowance_deduction`, `miscellaneous_income_trading_allowance_deduction` | ITTOIA 2005 ss 783A-783BQ | planned (P2) |
| Self-employment and property income as non-savings income | `taxable_self_employment_income`, `taxable_property_income`, `property_finance_cost_relief` | ITTOIA 2005 Parts 2-3, s272A (finance costs restriction), ss 274A-274C (the tax reduction) | planned (P2) |
| Trade loss relief, capital allowances, relief cap | `loss_relief`, `trade_loss_relief_against_general_income`, `capital_allowances`, `income_tax_relief_cap` | ITA 2007 ss 64, 24A; CAA 2001 | planned (P2: losses as an input) |
| Rent-a-room relief | `rent_a_room_relief`, `rent_a_room_income_tax` | ITTOIA 2005 ss 784-802 | planned (P2) |
| Company car and car fuel benefits | `company_car_benefit`, `car_fuel_benefit`, `ni_class_1a` | ITEPA 2003 ss 114-153 | planned (P3) |
| Employment expenses and deductions | `employment_deductions`, `employment_expenses` | ITEPA 2003 Part 5 | planned (P2, as an input) |
| Winter fuel payment charge | `winter_fuel_payment_charge` | Finance Act 2026 s57 and Sch 10 (inserting ITEPA 2003 Part 10 Ch 9) | planned (P9) |
| ISA cash-interest charge (from 2027-28) | `isa_cash_interest_flat_rate_charge` | Budget 2026; from 6 April 2027 | out of scope: starts after 2026-27 |

## National Insurance

| Programme | PolicyEngine variables | Legal source | Status |
|---|---|---|---|
| Class 1 primary (employee), category A | `ni_class_1_employee`, `ni_class_1_employee_primary`, `ni_class_1_employee_additional` | SSCBA 1992 s8; SI 2001/1004 regs 10-11 | **done** |
| Class 1 secondary (employer), employment allowance | `ni_class_1_employer`, `ni_employer` | SSCBA 1992 s9; SI 2001/1004 reg 10; NICA 2014 s1 | planned (P3) |
| Class 1A on car benefits | `ni_class_1a` | SSCBA 1992 s10 | planned (P3) |
| Class 2 | `ni_class_2` | SSCBA 1992 s11 (as amended from 2024-25) | planned (P3) |
| Class 3 | `ni_class_3` | SSCBA 1992 s13 | planned (P3) |
| Class 4, including losses | `ni_class_4`, `ni_class_4_main`, `ni_class_4_maximum`, `ni_class_4_loss_relief` | SSCBA 1992 ss 15-18; SI 2001/1004 reg 100 | planned (P3) |

## Benefits

| Programme | PolicyEngine variables | Legal source | Status |
|---|---|---|---|
| Universal Credit: standard allowance (25 or over), child element, higher work allowance, taper | `universal_credit`, `uc_standard_allowance`, `uc_child_element`, `uc_work_allowance` | Welfare Reform Act 2012 Part 1; SI 2013/376 regs 22, 36; Universal Credit (Removal of Two Child Limit) Act 2026 | **done** (minimal: one earner, pay only) |
| UC: under-25 rates, lower work allowance, first-child rate (before 6 April 2017), disabled child additions | `uc_standard_allowance`, `uc_individual_child_element`, `uc_individual_disabled_child_element`, `uc_individual_severely_disabled_child_element` | SI 2013/376 regs 22, 24, 36 | planned (P4) |
| UC: LCWRA (health) element, carer element | `uc_LCWRA_element`, `uc_carer_element` | SI 2013/376 regs 27-30, 36; Universal Credit Act 2025 | planned (P4) |
| UC: housing costs element, non-dependant deductions, LHA cap | `uc_housing_costs_element`, `uc_non_dep_deductions`, `uc_LHA_cap` | SI 2013/376 reg 25, Schs 1-5; Rent Officers (Universal Credit Functions) Order 2013 (SI 2013/382) | planned (P4, LHA rate as an input) |
| UC: childcare costs element | `uc_childcare_element`, `uc_maximum_childcare_element_amount` | SI 2013/376 regs 31-35 | planned (P4) |
| UC: capital and unearned income, tariff income | `uc_assessable_capital`, `uc_tariff_income`, `uc_unearned_income` | SI 2013/376 regs 18, 45-50 (capital), 65-74 (unearned income; tariff income reg 72) | planned (P4) |
| UC: two earners, self-employment, minimum income floor | `uc_earned_income`, `uc_minimum_income_floor` | SI 2013/376 regs 52-64 | planned (P4) |
| Benefit cap | `benefit_cap_reduction`, `uc_benefit_cap`, `housing_benefit_benefit_cap_reduction` | Welfare Reform Act 2012 s96; SI 2013/376 regs 78-83; SI 2006/213 Part 8A | planned (P4) |
| UC deductions (advances, debts) | `uc_deductions`, `uc_deduction_*` | SI 2013/380 Sch 6 | out of scope: driven by imputed debts and random draws, not the entitlement |
| Child Benefit | `child_benefit`, `child_benefit_respective_amount` | SSCBA 1992 ss 141-147; SI 2006/965 | planned (P5; now an input) |
| Housing Benefit | `housing_benefit` and 45 components | SSCBA 1992 s130; SI 2006/213; SI 2006/214 | planned (P5) |
| Income Support, income-based JSA, income-related ESA, tax credits | `income_support`, `jsa_income`, `esa_income`, `tax_credits` | SSCBA 1992 s124; Jobseekers Act 1995; Welfare Reform Act 2007; Tax Credits Act 2002 | planned (P5: those PolicyEngine still pays in 2026-27); tax credits out of scope: ended 5 April 2025 |
| Contribution-based JSA and ESA | `jsa_contrib`, `esa_contrib` | Jobseekers Act 1995; Welfare Reform Act 2007; SI 2013/378, SI 2013/379 | planned (P5) |
| Personal Independence Payment | `pip`, `pip_dl`, `pip_m` | Welfare Reform Act 2012 Part 4; SI 2013/377 | planned (P5) |
| Disability Living Allowance | `dla`, `dla_sc`, `dla_m` | SSCBA 1992 ss 71-76 | planned (P5) |
| Attendance Allowance | `attendance_allowance` | SSCBA 1992 ss 64-67 | planned (P5) |
| Severe Disablement Allowance | `sda` | SSCBA 1992 s68 (closed to new claims) | planned (P5) |
| Carer's Allowance | `carers_allowance` | SSCBA 1992 s70; SI 1976/409; SI 1979/597 | planned (P5) |
| Maternity Allowance | `maternity_allowance` | SSCBA 1992 ss 35, 35A | planned (P5) |
| Sure Start Maternity Grant | `ssmg` | SI 2005/3061 | planned (P5) |
| Statutory Sick, Maternity and Paternity Pay | budget terms only (inputs) | SSCBA 1992 Parts XI, XII, XIIZA | out of scope: PolicyEngine takes them as inputs |
| Bereavement, industrial injuries, war pensions, Armed Forces Compensation | budget terms only (inputs) | various | out of scope: PolicyEngine takes them as inputs |
| State Pension (new and basic, additional, age addition) | `state_pension`, `new_state_pension`, `basic_state_pension`, `additional_state_pension` | Pensions Act 2014 Part 1; SSCBA 1992 ss 44-45, 78-79 | planned (P6) |
| Pension Credit (guarantee and savings credit) | `pension_credit`, `guarantee_credit`, `savings_credit`, `minimum_guarantee` | State Pension Credit Act 2002; SI 2002/1792 | planned (P6) |
| Winter Fuel Payment | `winter_fuel_payment` | Social Fund Winter Fuel Payment Regulations 2025 (SI 2025/969) | planned (P9) |

## Childcare

| Programme | PolicyEngine variables | Legal source | Status |
|---|---|---|---|
| Tax-Free Childcare | `tax_free_childcare` | Childcare Payments Act 2014; SI 2015/448 | **done** (non-disabled children) |
| Funded hours, England: universal 15 at 3-4, working-parent hours from 9 months | `universal_childcare_entitlement`, `extended_childcare_entitlement` | Childcare Act 2006 s7; SI 2014/2147 reg 4; Childcare Act 2016 s1; SI 2022/1134 | **done** (one age band a year) |
| Funded hours for disadvantaged 2-year-olds | `targeted_childcare_entitlement` | Childcare Act 2006 s7; SI 2014/2147 regs 3-4 | planned (P9) |
| Wales childcare offer | `wales_childcare_offer` | Childcare Funding (Wales) Act 2019 | planned (P9) |
| Scotland funded early learning and childcare | `funded_early_learning_childcare` | Children and Young People (Scotland) Act 2014 Part 6 | planned (P9) |
| DfE student support (maintenance loans, Childcare Grant, Parents' Learning Allowance, Adult Dependants' Grant, Travel Grant, DSA, 16-19 bursary, Care to Learn) | `maintenance_loan`, `childcare_grant`, `parents_learning_allowance`, `adult_dependants_grant`, `travel_grant`, `disabled_students_allowance`, `bursary_fund_16_to_19`, `care_to_learn` | SI 2011/1986 (Education (Student Support) Regulations 2011); DfE guidance | planned (P9) |

## Devolved benefits

| Programme | PolicyEngine variables | Legal source | Status |
|---|---|---|---|
| Scottish Child Payment | `scottish_child_payment` | SSI 2020/351 | planned (P9) |
| Carer Support Payment, Scottish Carer's Allowance Supplement | `carer_support_payment`, `scottish_carer_supplement` | Social Security (Scotland) Act 2018 s81 (supplement); SSI 2023/302 | planned (P9) |
| Pension Age Winter Heating Payment | `pension_age_winter_heating_payment` | Social Security (Scotland) Act 2018 s30; SSI 2024/351 | planned (P9) |
| Scottish two-child limit payment | `two_child_limit_payment` | Scottish Government scheme | planned (P9): check whether anything is payable in 2026-27, since the UC two-child limit it makes up for was removed from 6 April 2026 (Universal Credit (Removal of Two Child Limit) Act 2026) |
| Adult and Child Disability Payment (Scotland) | modelled through `pip`, `dla` | SSI 2022/54; SSI 2021/174 | planned (P5, as PIP and DLA) |

## Local taxes and support

| Programme | PolicyEngine variables | Legal source | Status |
|---|---|---|---|
| Council tax | `council_tax` (an input), `simulated_council_tax`, `council_tax_band_d_amount` | Local Government Finance Act 1992 | planned (P7: liability from band, Band D and discounts) |
| Council Tax Reduction: Scotland and Wales national schemes, England pension-age scheme | `council_tax_reduction` and 60 components | LGFA 1992 s13A, Schs 1A, 1B; SI 2012/2885 (England, pension age); SI 2013/3029 (Wales); SSI 2021/249 (Scotland, working age), SSI 2012/319 (Scotland, pension age) | planned (P7) |
| Council Tax Reduction: English working-age local schemes (Kingston, Merton, Newham, Oxford, Westminster) | `council_tax_reduction` via `gov.local_authorities.*` | each authority's scheme | planned (P7, the five PolicyEngine has) |
| High Value Council Tax Surcharge | `high_value_council_tax_surcharge` | announced at Budget 2025, from April 2028 | out of scope: not in force in 2026-27 |
| Business rates | `business_rates` | LGFA 1988 | out of scope: receipts allocated to households by shareholding, an incidence assumption |

## Capital and property taxes

| Programme | PolicyEngine variables | Legal source | Status |
|---|---|---|---|
| Capital Gains Tax (including BADR, residential property, carried interest) | `capital_gains_tax`, `capital_gains_badr` | TCGA 1992 ss 1H-1K, 169H-169S | planned (P8) |
| Stamp Duty Land Tax | `stamp_duty_land_tax`, `sdlt_on_residential_property_transactions`, `sdlt_on_*_rent` | Finance Act 2003 Part 4, s55, Sch 5 | planned (P8) |
| Land and Buildings Transaction Tax | `land_and_buildings_transaction_tax` | LBTT (Scotland) Act 2013 | planned (P8) |
| Land Transaction Tax | `land_transaction_tax` | LTT and Anti-avoidance of Devolved Taxes (Wales) Act 2017 | planned (P8) |
| Corporate SDLT, land value, wealth | `corporate_sdlt`, `corporate_land_value`, `net_wealth` | — | out of scope: incidence and imputation |

## Consumption and other taxes

| Programme | PolicyEngine variables | Legal source | Status |
|---|---|---|---|
| VAT (standard and reduced rate on household spending, domestic energy, private school fees) | `vat`, `full_rate_vat_consumption`, `reduced_rate_vat_consumption`, `private_school_vat`, `domestic_energy_vat` | VATA 1994 ss 2, 29A, Schs 7A-8 | planned (P9: rate × spending) |
| Fuel duty | `fuel_duty` | Hydrocarbon Oil Duties Act 1979 s6 | planned (P9) |
| Alcohol duty | `alcohol_duty` | Finance (No. 2) Act 2023 Part 2 | planned (P9) |
| Tobacco duty | `tobacco_duty` | Tobacco Products Duty Act 1979 | planned (P9) |
| Vehicle Excise Duty | `vehicle_excise_duty` | Vehicle Excise and Registration Act 1994 Sch 1 | planned (P9) |
| Gambling duties | `gambling_duty` | Betting and Gaming Duties Act 1981; Finance Act 1997; Finance Act 2014 | out of scope: duty bases attributed to households by proxy |
| TV licence | `tv_licence` | Communications Act 2003 s363; SI 2004/692 | planned (P9) |
| Student loan repayments | `student_loan_repayment` | SI 2009/470 | planned (P9) |
| ISA subscription limits, Lifetime ISA bonus and charge | `isa_subscriptions_above_limit`, `lifetime_isa_bonus` | SI 1998/1870 | planned (P9) |
| National Minimum Wage | `minimum_wage` | National Minimum Wage Act 1998; SI 2015/621 | planned (P9; already used for the childcare test) |

## Energy and one-off support

| Programme | PolicyEngine variables | Legal source | Status |
|---|---|---|---|
| Household Energy Payment (England, from January 2027) | `household_energy_payment` | Budget 2026 (administrative scheme) | planned (P9) |
| Warm Home Discount | `warm_home_discount` | SI 2022/772 (England and Wales; PolicyEngine does not model the Scottish scheme, SI 2022/1073) | planned (P9) |
| Cost of Living Payments, Energy Bills Rebate, Energy Price Guarantee | `cost_of_living_support_payment`, `energy_bills_rebate`, `price_cap_subsidy` | — | out of scope: ended before 2026-27 |

## Out of scope as a class

| What | PolicyEngine variables | Why |
|---|---|---|
| Hypothetical reforms (UBI, carbon tax, land value tax, wealth tax, disability basic income, employer NIC incidence) | `contrib/*` | not law |
| Population data, weights, poverty and inequality measures, deciles | `household_weight`, `in_poverty_*`, `household_income_decile`, `hbai_*` | microsimulation outputs |
| Take-up and random draws | `would_claim_*`, `*_random_draw`, `*_takeup` | behaviour, not entitlement (the model computes the entitlement) |
| Behavioural responses | `labour_supply_response`, `capital_gains_behavioural_response` | behaviour |
| Public services in kind (NHS, education, transport) | `nhs_spending`, `dfe_education_spending`, `rail_subsidy_spending` | spending allocation, not a household calculation |
| Years other than 2026-27 | all | the model is for one year |
