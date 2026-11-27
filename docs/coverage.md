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
| P2 | Reliefs and allowances | net pay pension contributions, Marriage Allowance, married couple's allowance, Blind Person's Allowance, trading and property allowances, rent-a-room relief, self-employment and property profits (**done**) |
| P3 | NICs completeness | Class 2, 3 and 4, employer Class 1, Class 1A (**done**) |
| P4 | Universal Credit in full (**done**; self-employment and the minimum income floor in P4b) | every element, housing costs, childcare costs element, capital and unearned income, minimum income floor, the benefit cap |
| P5 | Other means-tested and disability benefits | Child Benefit, PIP, DLA, Attendance Allowance, Carer's Allowance, contributory JSA and ESA, Maternity Allowance, Sure Start Maternity Grant (P5a, **done**); Housing Benefit for pensioners (P5b, **done**); working-age Housing Benefit and legacy benefits still in payment (P5c, **done**: IS and income-based JSA abolished, income-related ESA an input) |
| P6 | Pensions | State Pension (new and basic), Pension Credit (**done**; the State Pension as an input, findings #25) |
| P7 | Council tax | council tax, Council Tax Reduction (**done**: liability and the pensioner schemes; working-age schemes planned, P7b) |
| P8 | CGT, property taxes and the remaining income tax reliefs (CGT **done**, P8a; SDLT **done**, P8b; LBTT, LTT, leases and non-residents **done**, P8c; reliefs **done**, area 6) | Capital Gains Tax, SDLT, LBTT, LTT; losses, capital allowances, property finance costs, the pension annual allowance charge and relief cap, salary sacrifice, gifts of shares and land, employment expenses |
| P9 | The rest (P9a **done**: student loans, the Winter Fuel Payment and its charge) | consumption duties, student loans, TV licence, ISAs, devolved benefits, other childcare schemes, energy and winter payments, student support |

## Taxes on income

| Programme | PolicyEngine variables | Legal source | Status |
|---|---|---|---|
| Income tax, rUK rates: personal allowance and taper, bands, savings (starting rate, personal savings allowance), dividends, s25(2) allowance placement | `income_tax`, `personal_allowance`, `earned_income_tax`, `savings_income_tax`, `dividend_income_tax`, `savings_allowance`, `dividend_allowance` | ITA 2007 ss 6-16, 23, 25, 35; Finance Act 2026 ss 1-4, 9; FA 2021 s5 as amended by FA 2023 s5 (allowance and basic rate limit frozen) | **done** (England, Wales, NI; Welsh rates equal rUK for 2026-27) |
| Welsh rates of income tax | `income_tax` (country = Wales) | ITA 2007 s6B; Senedd rate resolution NDM9117 | **done** (10p in each band, so the rUK rates) |
| Scottish income tax: Scottish rates on non-savings income, savings and dividends at UK rates in UK bands, the UK test for the savings allowance | `income_tax` via `gov.hmrc.income_tax.rates.scotland`, `tax_band` | ITA 2007 ss 11A, 11D(6), 12B(8), 13(5); Scottish rate resolution 2026-27 (S6M-20844); Scotland Act 1998 s80C | **done** (P1) |
| High Income Child Benefit Charge | `child_benefit_hitc` (in `income_tax` at Step 7) | ITEPA 2003 ss 681B-681H; ITA 2007 s30 | **done** |
| Pension contributions relieved at source: raised rate limits (rUK and Scottish), adjusted net income | `personal_pension_contributions`, `pension_contributions_relief` | Finance Act 2004 ss 190-192; ITA 2007 s58 | **done** (P1, the member's liability; findings #7, #8) |
| Net pay pension contributions, the relief cap, the annual allowance charge | `employee_pension_contributions`, `net_pay_pension_relief`, `pension_annual_allowance`, `pension_annual_allowance_chargeable_amount` | Finance Act 2004 ss 190, 193, 227-228ZA | **done** (P2: net pay contributions, income tax and NICs; area 6: the annual allowance charge with the taper and carry-forward, Scottish rates with the s227(4AA) basic rate slice, employer contributions as the input amount; findings #39); the relief cap on member contributions not modelled |
| Salary sacrifice for pensions | `pension_contributions_via_salary_sacrifice_*`, `salary_sacrifice_pension_ni_*` | ITEPA 2003 s62 (a contract variation, no statutory rule for income tax); NICs cap: National Insurance Contributions (Employer Pensions Contributions) Act 2026 s1, inserting SSCBA 1992 s4(6A) | **done** as lower pay (enter the salary after sacrifice; EIM42755; the NICs cap has effect only from 2029-30, s1(3)) |
| Gift Aid: raised rate limits (rUK and Scottish), adjusted net income | `gift_aid`, `gift_aid_grossed_up` | ITA 2007 ss 414-415, 58 | **done** (P1) |
| Gifts of shares and land to charity | `charitable_investment_gifts` | ITA 2007 Part 8 Ch 3 | **done** (area 6: at Step 2, allocated for the greatest reduction, s25(2), lowering adjusted net income; findings #39) |
| Marriage Allowance | `marriage_allowance`, `marriage_allowance_tax_reduction` | ITA 2007 ss 55A-55E | **done** (P2; findings #12) |
| Married couple's allowance | `married_couples_allowance`, `married_couples_allowance_deduction` | ITA 2007 ss 42-55 | **done** (P2; PolicyEngine takes the allowance as an input) |
| Blind Person's Allowance | `blind_persons_allowance` | ITA 2007 s38 | **done** (P2) |
| Trading and property allowances | `trading_allowance_deduction`, `property_allowance_deduction`, `miscellaneous_income_trading_allowance_deduction` | ITTOIA 2005 ss 783A-783BQ | **done** (P2: one trade, one property business; miscellaneous income not modelled) |
| Self-employment and property income as non-savings income | `taxable_self_employment_income`, `taxable_property_income`, `property_finance_cost_relief` | ITTOIA 2005 Parts 2-3, s272A (finance costs restriction), ss 274A-274C (the tax reduction) | **done** for income tax (P2, profits from receipts and expenses); the finance cost reduction **done** (area 6: 20 % of the lowest of costs, profits and adjusted total income, one property business, no costs brought forward) |
| Trade loss relief, capital allowances, relief cap | `loss_relief`, `trade_loss_relief_against_general_income`, `capital_allowances`, `income_tax_relief_cap` | ITA 2007 ss 64, 83, 24A; CAA 2001 | capital allowances and losses brought forward (s83) **done** (area 6, as inputs, for income tax and Class 4); sideways relief (s64) and the s24A cap not modelled |
| Rent-a-room relief | `rent_a_room_relief`, `rent_a_room_income_tax` | ITTOIA 2005 ss 784-802 | **done** (P2, Part 3 receipts; findings #13) |
| Company car and car fuel benefits | `company_car_benefit`, `car_fuel_benefit`, `ni_class_1a` | ITEPA 2003 ss 114-153 | planned (P9: the cash equivalent; Class 1A on it is done in P3) |
| Employment expenses and deductions | `employment_deductions`, `employment_expenses` | ITEPA 2003 Part 5 | **done** (area 6, as an input: off the earnings for income tax, not for NICs) |
| Winter fuel payment charge | `winter_fuel_payment_charge` | Finance Act 2026 Sch 10 (inserting ITEPA 2003 Part 10 Ch 9, s681I) | **done** (P9a: the whole payment above £35,000 of total income, none on a relevant benefit) |
| ISA cash-interest charge (from 2027-28) | `isa_cash_interest_flat_rate_charge` | Budget 2026; from 6 April 2027 | out of scope: starts after 2026-27 |

## National Insurance

| Programme | PolicyEngine variables | Legal source | Status |
|---|---|---|---|
| Class 1 primary (employee), category A | `ni_class_1_employee`, `ni_class_1_employee_primary`, `ni_class_1_employee_additional` | SSCBA 1992 s8; SI 2001/1004 regs 10-11 | **done** |
| Class 1 secondary (employer), employment allowance | `ni_class_1_employer`, `ni_employer` | SSCBA 1992 s9; SI 2001/1004 reg 10; NICA 2014 s1 | **done** (P3: 15 %, the secondary and under-21 / apprentice thresholds on each earnings-period basis); the Employment Allowance is the employer's, not modelled per employee (PolicyEngine has none either) |
| Class 1A on car benefits | `ni_class_1a` | SSCBA 1992 s10 | **done** (P3: 15 % of a given cash equivalent; the car benefit itself planned in P9) |
| Class 2 | `ni_class_2` | SSCBA 1992 s11 (as amended from 2024-25) | **done** (P3: treated as paid at or above the £7,105 small profits threshold; voluntary £3.65 a week below it) |
| Class 3 | `ni_class_3` | SSCBA 1992 s13 | **done** (P3: £18.40 a week, for weeks given) |
| Class 4, including losses | `ni_class_4`, `ni_class_4_main`, `ni_class_4_maximum`, `ni_class_4_loss_relief` | SSCBA 1992 ss 15-18; SI 2001/1004 reg 100 | **done** (P3: 6 % / 2 %, the reg 100 annual maximum with employee Class 1); loss relief for losses brought forward (Sch 2 para 3) **done** (area 6) |

## Benefits

| Programme | PolicyEngine variables | Legal source | Status |
|---|---|---|---|
| Universal Credit: standard allowance (25 or over), child element, higher work allowance, taper | `universal_credit`, `uc_standard_allowance`, `uc_child_element`, `uc_work_allowance` | Welfare Reform Act 2012 Part 1; SI 2013/376 regs 22, 36; Universal Credit (Removal of Two Child Limit) Act 2026 | **done** |
| UC: under-25 rates, lower work allowance, first-child rate (before 6 April 2017), disabled child additions | `uc_standard_allowance`, `uc_individual_child_element`, `uc_individual_disabled_child_element`, `uc_individual_severely_disabled_child_element` | SI 2013/376 regs 22, 24, 36 | **done** (P4) |
| UC: LCWRA (health) element, carer element | `uc_LCWRA_element`, `uc_carer_element` | SI 2013/376 regs 27-30, 36; Universal Credit Act 2025 | **done** (P4: new-claim and protected rates as an input; reg 29(4)) |
| UC: housing costs element, non-dependant deductions, LHA cap | `uc_housing_costs_element`, `uc_non_dep_deductions`, `uc_LHA_cap` | SI 2013/376 reg 25, Schs 1-5; Rent Officers (Universal Credit Functions) Order 2013 (SI 2013/382) | **done** (P4: rent, the LHA rate as an input, social-sector under-occupancy, non-dependant contributions as a count; findings #16) |
| UC: childcare costs element | `uc_childcare_element`, `uc_maximum_childcare_element_amount` | SI 2013/376 regs 31-35 | **done** (P4, with the reg 32 work condition) |
| UC: capital and unearned income, tariff income | `uc_assessable_capital`, `uc_tariff_income`, `uc_unearned_income` | SI 2013/376 regs 18, 45-50 (capital), 65-74 (unearned income; tariff income reg 72) | **done** (P4: capital limit and tariff income; unearned income as a monthly input; Carer's Allowance computed and deducted) |
| UC: two earners, self-employment, minimum income floor | `uc_earned_income`, `uc_minimum_income_floor` | SI 2013/376 regs 52-64 | **done** (P4: two earners, the partner's earned income fixed; P4b: one trade's self-employed earnings, reg 57, and the minimum income floor, reg 62, single and couple, the threshold's notional deductions as PolicyEngine takes them; unused losses of reg 57A and surplus earnings of reg 54A not modelled, as months are equal; findings #33) |
| Benefit cap | `benefit_cap_reduction`, `uc_benefit_cap`, `housing_benefit_benefit_cap_reduction` | Welfare Reform Act 2012 s96; SI 2013/376 regs 78-83; SI 2006/213 Part 8A | **done** for UC (P4: amounts, the earnings exception, LCWRA, carer and other exemptions, the childcare reduction of reg 81; the grace period not modelled); Housing Benefit's cap with P5 |
| UC deductions (advances, debts) | `uc_deductions`, `uc_deduction_*` | SI 2013/380 Sch 6 | out of scope: driven by imputed debts and random draws, not the entitlement |
| Child Benefit | `child_benefit`, `child_benefit_respective_amount` | SSCBA 1992 ss 141-147; SI 2006/965 reg 2 (SI 2026/232) | **done** (P5a: 53 weeks in 2026-27, findings #19; the eligibility of each child is the caller's) |
| Housing Benefit | `housing_benefit` and 45 components | SSCBA 1992 s130; SI 2006/213; SI 2006/214 regs 22, 26, 27, 29, 33, 43, 50, 51, 55, Schs 3-4 | **done** for pensioners (P5b, HB(SPC): the guarantee credit passport, savings credit only, the general means test, non-dependants, the LHA as an input; findings #26); working-age HB (P5c, SI 2006/213: the passport, the means test with the Sch 4 disregards including the October 2026 para 18 disregard, tariff income, the benefit cap with reg 75C(2)(a), the 1 July 2026 end under SI 2025/1148 art 7; findings #34) |
| Income Support, income-based JSA, income-related ESA, tax credits | `income_support`, `jsa_income`, `esa_income`, `tax_credits` | SSCBA 1992 s124; Jobseekers Act 1995; Welfare Reform Act 2007; Tax Credits Act 2002 | **done** as far as anything is payable (P5c): Income Support and income-based JSA abolished from 1 April 2026 (SI 2025/1148 arts 4, 5; PolicyEngine pays neither); income-related ESA ends 1 July 2026 except appointee cases (art 3A), an input as in PolicyEngine (its means test not modelled); tax credits out of scope: ended 5 April 2025 |
| Contribution-based JSA and ESA | `jsa_contrib`, `esa_contrib` | Jobseekers Act 1995; Welfare Reform Act 2007; SI 2013/378 regs 49-52, SI 2013/379 regs 62, 67 | **done** (P5a, new style: weekly award from earnings and pensions; PolicyEngine takes reported amounts, findings #20) |
| Personal Independence Payment | `pip`, `pip_dl`, `pip_m` | Welfare Reform Act 2012 Part 4; SI 2013/377 reg 24 | **done** (P5a: the rate of each component is an input, the assessment being outside the calculation) |
| Disability Living Allowance | `dla`, `dla_sc`, `dla_m` | SSCBA 1992 ss 71-76; SI 1991/2890 reg 4 | **done** (P5a, rates as inputs; the s73(1A) mobility ages are the caller's) |
| Attendance Allowance | `attendance_allowance` | SSCBA 1992 ss 64-67 | **done** (P5a, rate as an input) |
| Severe Disablement Allowance | `sda` | SSCBA 1992 s68 (closed to new claims) | out of scope: closed to new claims since 2001; PolicyEngine pays its maximum (the basic rate with the highest age addition, `gov.dwp.sda.maximum`) to anyone reporting it |
| Carer's Allowance | `carers_allowance` | SSCBA 1992 s70; SI 1976/409 reg 8 (SI 2026/218); SI 1979/597 reg 12; SI 1996/2745 regs 5, 10 | **done** (P5a: the earnings limit on net earnings from pay, overlapping benefits as an input, the cliff in net income proved; with UC as unearned income, findings #32) |
| Maternity Allowance | `maternity_allowance` | SSCBA 1992 ss 35, 35A | **done** (P5a, weekly rate from average weekly earnings; PolicyEngine takes it as reported, findings #20) |
| Sure Start Maternity Grant | `ssmg` | SI 2005/3061 regs 5, 5A | **done** (P5a, without the multiple-birth and refugee exceptions; PolicyEngine pays it on reported receipt, findings #20) |
| Statutory Sick, Maternity and Paternity Pay | budget terms only (inputs) | SSCBA 1992 Parts XI, XII, XIIZA | out of scope: PolicyEngine takes them as inputs |
| Bereavement, industrial injuries, war pensions, Armed Forces Compensation | budget terms only (inputs) | various | out of scope: PolicyEngine takes them as inputs |
| State Pension (new and basic, additional, age addition) | `state_pension`, `new_state_pension`, `basic_state_pension`, `additional_state_pension` | Pensions Act 2014 ss 2-5; SI 2015/173 regs 1A, 13; SSCBA 1992 ss 44, 79 | **done** as far as the statute fixes it (P6): an input, as in PolicyEngine, since the transitional rate comes from each person's record; the reduced rate for someone with no pre-2016 year and the full rates are modelled (findings #25) |
| Pension Credit (guarantee and savings credit) | `pension_credit`, `guarantee_credit`, `savings_credit`, `minimum_guarantee` | State Pension Credit Act 2002 ss 2, 3, 15; SI 2002/1792 regs 6, 7, 9, 15, 17, Schs IIA, VI | **done** (P6: the additional amounts as inputs, income net of tax, the earnings disregards, deemed income from capital, savings credit with the reg 7(4) rounding; findings #22-#24) |
| Winter Fuel Payment | `winter_fuel_payment` | Social Fund Winter Fuel Payment Regulations 2025 (SI 2025/969); NISR 2025/142 (the same amounts) | **done** (P9a: regs 2-4, England and Wales; custody and long hospital stays left to the caller) |

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
| Adult and Child Disability Payment (Scotland) | modelled through `pip`, `dla` | SSI 2022/54; SSI 2021/174 | **done** as PIP and DLA (P5a; the same weekly rates) |

## Local taxes and support

| Programme | PolicyEngine variables | Legal source | Status |
|---|---|---|---|
| Council tax | `council_tax` (an input), `simulated_council_tax`, `council_tax_band_d_amount` | Local Government Finance Act 1992 ss 5, 11, 74, 79 | **done** (P7: liability from band and band D, the single person discount; other discounts, disregards, premiums and exemptions not modelled) |
| Council Tax Reduction: Scotland and Wales national schemes, England pension-age scheme | `council_tax_reduction` and 60 components | LGFA 1992 s13A, Schs 1A, 1B; SI 2012/2885 (England, pension age); SI 2013/3029 (Wales); SSI 2021/249 (Scotland, working age), SSI 2012/319 (Scotland, pension age) | **done** for pensioners in all three nations (P7, daily over 365 days; findings #27, #28); the Welsh working-age scheme **done** (P7b: classes C and D on its own rules and on UC; findings #35); the Scottish working-age scheme **done** (P7b: reg 13 on its own rules and on UC, reg 14 bands E to H and the second adult rebate, which PolicyEngine does not model; findings #36) |
| Council Tax Reduction: English working-age local schemes (Kingston, Merton, Newham, Oxford, Westminster) | `council_tax_reduction` via `gov.local_authorities.*` | each authority's 2026-27 scheme | **done** (P7b: the four default-scheme councils on their own rules and on UC, Oxford's income bands with and without UC; premiums, self-employment, childcare and the class F reduction not modelled; findings #37) |
| High Value Council Tax Surcharge | `high_value_council_tax_surcharge` | announced at Budget 2025, from April 2028 | out of scope: not in force in 2026-27 |
| Business rates | `business_rates` | LGFA 1988 | out of scope: receipts allocated to households by shareholding, an incidence assumption |

## Capital and property taxes

| Programme | PolicyEngine variables | Legal source | Status |
|---|---|---|---|
| Capital Gains Tax (including BADR, residential property, carried interest) | `capital_gains_tax`, `capital_gains_badr` | TCGA 1992 ss 1H-1K, 169N; Finance Act 2025 ss 7-8; Finance Act 2026 s58 | **done** (P8a: main and residential rates, the annual exempt amount, BADR, the band after income and reliefs; losses as an input; Scottish taxpayers on the UK band, s1J(6); carried interest and investors' relief not modelled; findings #29, #30, #32) |
| Stamp Duty Land Tax | `stamp_duty_land_tax`, `sdlt_on_residential_property_transactions`, `sdlt_on_*_rent` | Finance Act 2003 s55, Schs 4ZA, 6ZA (FA 2025 s51) | **done** for purchases (P8b: residential, first-time buyers, additional dwellings, non-residential; findings #31), lease rent by its NPV and the 2 % non-resident surcharge (P8c, Sch 5, s75ZA; findings #38); multiple dwellings and linked transactions not modelled |
| Land and Buildings Transaction Tax | `land_and_buildings_transaction_tax` | LBTT (Scotland) Act 2013; SSI 2015/126 | **done** (P8c: Table A, first-time buyer relief, the additional dwelling supplement from £40,000, Table B, lease rent by its NPV; findings #38) |
| Land Transaction Tax | `land_transaction_tax` | LTT and Anti-avoidance of Devolved Taxes (Wales) Act 2017; WSI 2018/128 | **done** (P8c: Tables 1 to 4, the higher rates from £40,000, lease rent by its NPV; findings #38) |
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
| Student loan repayments | `student_loan_repayment` | SI 2009/470 reg 29, Sch 1A | **done** (P9a: plans 1, 2, 4, 5 and Postgraduate, more than one at once, the £2,000 unearned income rule; the balance cap and PAYE periods not modelled; findings #40) |
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
