/-!
# Parameters for the 2026-27 tax year (England, Wales and Northern Ireland)

Every rate and threshold used by the model, each with its source. Figures were
checked against legislation.gov.uk and GOV.UK on 2026-11-26.

Units:
* money is in **pence** (`Nat`);
* rates are in **basis points** (`Nat`, 1 bp = 0.01 %), so 10.75 % is `1075`.

Multiplying pence by basis points therefore gives tax in units of 1/10 000 of a
penny, which keeps every intermediate result an exact natural number.
-/

namespace UkTax

/-- The three main rates that apply in the basic, higher and additional bands. -/
structure Rates where
  basic : Nat
  higher : Nat
  additional : Nat
  deriving Repr, DecidableEq

/-- Personal allowance, £12,570.
ITA 2007 s35(1) <https://www.legislation.gov.uk/ukpga/2007/3/section/35>; amount
frozen for 2026-27 by FA 2021 s5(2) as amended by FA 2023 s5
<https://www.legislation.gov.uk/ukpga/2023/1/section/5> (and to 2030-31 by FA 2026
s10). GOV.UK:
<https://www.gov.uk/government/publications/rates-and-allowances-income-tax/income-tax-rates-and-allowances-current-and-past> -/
def personalAllowance : Nat := 1_257_000

/-- Income limit for the personal allowance, £100,000: above it the allowance is
reduced by half the excess of adjusted net income (ITA 2007 s35(2)) and the result
rounded up to a whole pound (s35(3)). -/
def paIncomeLimit : Nat := 10_000_000

/-- Basic rate limit, £37,700. ITA 2007 s10(5)
<https://www.legislation.gov.uk/ukpga/2007/3/section/10>; frozen for 2026-27 by FA 2021
s5(1) as amended by FA 2023 s5. With the full personal allowance the higher rate starts at £50,270 of
total income (GOV.UK <https://www.gov.uk/income-tax-rates>). -/
def basicRateLimit : Nat := 3_770_000

/- The higher rate limit is not a figure here: ITA 2007 s10(5A) defines it from the
personal allowance and the income limit, and `TaxParams.hrl` works it out
(£125,140 for 2026-27; GOV.UK <https://www.gov.uk/income-tax-rates>). -/

/-- Starting rate limit for savings, £5,000, charged at the 0 % starting rate for
savings. ITA 2007 s12(3) <https://www.legislation.gov.uk/ukpga/2007/3/section/12>
(sum confirmed for 2026-27 to 2030-31 by FA 2026 s9(1)); rate 0 % by ITA 2007 s7.
GOV.UK <https://www.gov.uk/apply-tax-free-interest-on-savings/how-much-is-tax-free> -/
def startingRateLimitSavings : Nat := 500_000

/-- Personal savings allowance when no income is higher-rate or additional-rate
income, £1,000. ITA 2007 s12B(4)
<https://www.legislation.gov.uk/ukpga/2007/3/section/12B> -/
def savingsAllowanceBasic : Nat := 100_000

/-- Personal savings allowance when some income is higher-rate income but none is
additional-rate income, £500. ITA 2007 s12B(3). -/
def savingsAllowanceHigher : Nat := 50_000

/-- Personal savings allowance when some income is additional-rate income, nil.
ITA 2007 s12B(2). -/
def savingsAllowanceAdditional : Nat := 0

/-- Dividend allowance (dividend nil rate band), £500. ITA 2007 s13A(2)
<https://www.legislation.gov.uk/ukpga/2007/3/section/13A>; GOV.UK
<https://www.gov.uk/tax-on-dividends> -/
def dividendAllowance : Nat := 50_000

/-- Basic, higher and additional rates on non-savings income for 2026-27: 20 %, 40 %
and 45 %. Finance Act 2026 s2 <https://www.legislation.gov.uk/ukpga/2026/11>
(ITA 2007 s6); GOV.UK <https://www.gov.uk/income-tax-rates> -/
def nonSavingsRates : Rates := ⟨2000, 4000, 4500⟩

/-- Basic, higher and additional savings rates for 2026-27: 20 %, 40 % and 45 %.
Finance Act 2026 s3 <https://www.legislation.gov.uk/ukpga/2026/11> (ITA 2007 s7A).
2027-28 is out of scope. As enacted, FA 2026 s5 sets 22 / 42 / 47 % from 6 April
2027; Budget 2026 (para 6.247) announced a further 2 points, so the pinned
PolicyEngine UK models 24 / 44 / 49 % from that date. Neither applies to 2026-27. -/
def savingsRates : Rates := ⟨2000, 4000, 4500⟩

/-- Dividend ordinary, upper and additional rates for 2026-27: 10.75 %, 35.75 % and
39.35 %. ITA 2007 s8(1)-(3) <https://www.legislation.gov.uk/ukpga/2007/3/section/8>,
ordinary and upper rates raised from 8.75 % and 33.75 % by Finance Act 2026 s4 for
2026-27 onwards. GOV.UK policy paper
<https://www.gov.uk/government/publications/changes-to-tax-rates-for-property-savings-and-dividend-income> -/
def dividendRates : Rates := ⟨1075, 3575, 3935⟩

/-! ## Scottish rates of income tax, 2026-27

A Scottish taxpayer's non-savings income is charged at the Scottish rates
(ITA 2007 s11A(1A) <https://www.legislation.gov.uk/ukpga/2007/3/section/11A>),
set for 2026-27 by the Scottish rate resolution, motion S6M-20844, agreed by the
Scottish Parliament on 19 February 2026
<https://www.parliament.scot/chamber-and-committees/votes-and-motions/S6M-20844>
(power: Scotland Act 1998 s80C). The resolution charges each rate on income
"charged above the personal allowance": "(a) a starter rate of 19%, charged on
income up to a limit of £3,967, (b) the Scottish basic rate is 20%, charged on
income above £3,967 and up to a limit of £16,956, (c) an intermediate rate of
21% ... up to a limit of £31,092, (d) a higher rate of 42% ... up to a limit of
£62,430, (e) an advanced rate of 45% ... up to a limit of £125,140, and (f) a top
rate of 48%, charged on income above £125,140". GOV.UK
<https://www.gov.uk/scottish-income-tax> gives the same bands as gross income with
the standard allowance (£12,571 to £16,537 starter, ... £75,001 to £125,140
advanced). Savings and dividends of a Scottish taxpayer are charged at the UK
rates in the UK bands, "as if the individual were not a Scottish taxpayer"
(s11D(6), s13(5)), and so is the personal savings allowance's test of
higher-rate and additional-rate income (s12B(8)(a)(iv), (b)(iv)). -/

/-- Starter rate limit, £3,967 of income above the personal allowance. Not raised
by Gift Aid or pension contributions (ITA 2007 s414(2)(b) and FA 2004 s192(4A)
raise only the Scottish basic rate's limit and those above it). -/
def scotStarterLimit : Nat := 396_700

/-- Upper limit of the Scottish basic rate, £16,956. -/
def scotBasicLimit : Nat := 1_695_600

/-- Upper limit of the intermediate rate, £31,092. -/
def scotIntermediateLimit : Nat := 3_109_200

/-- Upper limit of the Scottish higher rate, £62,430. -/
def scotHigherLimit : Nat := 6_243_000

/-- Upper limit of the advanced rate, £125,140; the top rate is charged above it. -/
def scotAdvancedLimit : Nat := 12_514_000

/-- Starter, basic, intermediate, higher, advanced and top rates: 19, 20, 21, 42,
45 and 48 %, in basis points. -/
def scotStarterRate : Nat := 1900
def scotBasicRate : Nat := 2000
def scotIntermediateRate : Nat := 2100
def scotHigherRate : Nat := 4200
def scotAdvancedRate : Nat := 4500
def scotTopRate : Nat := 4800

/-! ## Gift Aid and pension contributions relieved at source

A Gift Aid donation is treated as made after deduction of income tax at the
basic rate, and the basic rate limit and the higher rate limit, and for a
Scottish taxpayer "the upper limit for the Scottish basic rate and the limits for
any Scottish rates above the Scottish basic rate", are "increased by an amount
equal to the grossed up amount of the gift" (ITA 2007 s414(2)
<https://www.legislation.gov.uk/ukpga/2007/3/section/414>), grossed up at the
basic rate (s415). Pension contributions relieved at source raise the same
limits by the gross contribution (Finance Act 2004 s192(4), and s192(4A) for the
Scottish limits <https://www.legislation.gov.uk/ukpga/2004/12/section/192>). Both
are deducted from net income to give adjusted net income (ITA 2007 s58, steps 2
and 3 <https://www.legislation.gov.uk/ukpga/2007/3/section/58>). The model takes
the gross amounts as inputs. For 2026-27 the Scottish basic rate equals the basic
rate (20 %), so the s414A and FA 2004 ss192A-192B adjustments are nil. -/

/-! ## Blind person's allowance, Marriage Allowance and married couple's allowance -/

/-- Blind person's allowance, £3,250 for 2026-27: ITA 2007 s38(1)
<https://www.legislation.gov.uk/ukpga/2007/3/section/38> ("a blind person's allowance
of £3,250"), substituted for £3,130 by The Income Tax (Indexation) Order 2026
(SI 2026/38) <https://www.legislation.gov.uk/uksi/2026/38/made>. GOV.UK
<https://www.gov.uk/blind-persons-allowance/what-youll-get>. It is not tapered:
s35(2) reduces only the personal allowance. -/
def blindPersonsAllowance : Nat := 325_000

/-- Marriage Allowance transferable amount, £1,260: 10 % of the s35(1) personal
allowance (£1,257), rounded up to a multiple of £10. ITA 2007 s55B(4)(b), (5)
<https://www.legislation.gov.uk/ukpga/2007/3/section/55B>. The recipient gets a tax
reduction of the basic rate (or Scottish basic rate), 20 %, of it at Step 6
(s55B(1), (3), s55A(2)), so up to £252; the transferor's own personal allowance
is reduced by it (s55B(6)). GOV.UK <https://www.gov.uk/marriage-allowance>. -/
def maTransferable : Nat := 126_000

/-- The Marriage Allowance reduction rate, the basic rate (and Scottish basic rate),
20 %, in basis points (s55B(3)). -/
def maRate : Nat := 2000

/-- Married couple's allowance, for a marriage where either party was born before
6 April 1935 (ITA 2007 s42(1), s45, s46): the maximum amount £11,700 (s45(3)(a),
s46(3)(a)), reduced by half the excess of adjusted net income over £39,200
(s45(4), s46(4)) but not below the minimum amount £4,530 (s43, s46(5)), all as
substituted for 2026-27 by SI 2026/38 art 2. The tax reduction is 10 % of it
(s45(1), s46(1)), at Step 6 (s42(4)), only so far as there is tax (s29(2)).
<https://www.legislation.gov.uk/ukpga/2007/3/section/46> -/
def mcaMax : Nat := 1_170_000
def mcaMin : Nat := 453_000
def mcaIncomeLimit : Nat := 3_920_000
def mcaRate : Nat := 1000

/-! ## Employee (primary) Class 1 National Insurance contributions, 2026-27

Amounts in pence per earnings period. The thresholds for 2026-27 are on GOV.UK,
"Rates and thresholds for employers 2026 to 2027"
<https://www.gov.uk/guidance/rates-and-thresholds-for-employers-2026-to-2027>
(also <https://www.gov.uk/government/publications/rates-and-allowances-national-insurance-contributions/rates-and-allowances-national-insurance-contributions>),
set under the Social Security (Contributions) Regulations 2001 reg 10 as amended
for 2026-27 by SI 2026/231 <https://www.legislation.gov.uk/uksi/2026/231/regulation/5/made>.
-/

/-- Primary threshold: £242 a week, £1,048 a month, £12,570 a year. -/
def primaryThresholdWeekly : Nat := 24_200
def primaryThresholdMonthly : Nat := 104_800
def primaryThresholdAnnual : Nat := 1_257_000

/-- Upper earnings limit: £967 a week, £4,189 a month, £50,270 a year. -/
def upperEarningsLimitWeekly : Nat := 96_700
def upperEarningsLimitMonthly : Nat := 418_900
def upperEarningsLimitAnnual : Nat := 5_027_000

/-- Main primary percentage, 8 %, on earnings above the primary threshold up to the
upper earnings limit. Social Security Contributions and Benefits Act 1992 s8(2)(a)
<https://www.legislation.gov.uk/ukpga/1992/4/section/8>; GOV.UK category A. -/
def nicMainRate : Nat := 800

/-- Additional primary percentage, 2 %, on earnings above the upper earnings limit.
SSCBA 1992 s8(2)(b); GOV.UK category A. -/
def nicAdditionalRate : Nat := 200

/-! ## High Income Child Benefit Charge (ITEPA 2003 Part 10 Chapter 8)

ITEPA 2003 s681C <https://www.legislation.gov.uk/ukpga/2003/1/section/681C>: the
charge is the appropriate percentage of the Child Benefit, 1 % for each £200 of
adjusted net income over £60,000 (capped at 100 %); the Child Benefit total, the
percentage and the charge are each rounded down to a whole number (s681C(3)).
Figures as substituted by Finance (No. 2) Act 2024 s5 for 2024-25 onwards. GOV.UK:
<https://www.gov.uk/child-benefit-tax-charge>. -/

/-- L in s681C(2): £60,000. -/
def hicbcThreshold : Nat := 6_000_000

/-- X in s681C(2): £200 of income per percentage point. -/
def hicbcStep : Nat := 20_000

/-! ## Child Benefit weekly rates, 2026-27

£27.05 for the eldest or only child ("the enhanced rate"), £17.90 for each other
child: Child Benefit (Rates) Regulations 2006 (SI 2006/965) reg 2(1), as amended
by the Child Benefit and Guardian's Allowance Up-rating Order 2026 (SI 2026/232)
art 2, from 6 April 2026
<https://www.legislation.gov.uk/uksi/2026/232/made>. Checked 2026-11-26. -/
def childBenefitEldestWeekly : Nat := 2_705
def childBenefitOtherWeekly : Nat := 1_790

/-! ## Universal Credit, 2026-27 (monthly amounts, pence)

Universal Credit Regulations 2013 (SI 2013/376) reg 36 table, amounts for 2026-27
set by the Social Security Benefits Up-rating Order 2026 (SI 2026/148) art 32 and
Sch 13, and (standard allowance) SI 2026/113. GOV.UK "Benefit and pension rates
2026 to 2027"
<https://www.gov.uk/government/publications/benefit-and-pension-rates-2026-to-2027/proposed-benefit-and-pension-rates-2026-to-2027>
and <https://www.gov.uk/universal-credit/what-youll-get>. -/

/-- Standard allowance, single claimant aged 25 or over: £424.90 a month. -/
def ucStandardSingle25 : Nat := 42_490

/-- Standard allowance, joint claimants where either is aged 25 or over: £666.97. -/
def ucStandardJoint25 : Nat := 66_697

/-- Child element for each child born on or after 6 April 2017: £303.94 a month.
No two-child limit: reg 24A was revoked for assessment periods from 6 April 2026 by
the Universal Credit (Removal of Two Child Limit) Act 2026 s1
<https://www.legislation.gov.uk/ukpga/2026/13>. -/
def ucChildElement : Nat := 30_394

/-- Higher work allowance (no housing costs element), for a claimant responsible
for a child: £710 a month. Reg 22(2); SI 2026/148 art 32(1)(a)
<https://www.legislation.gov.uk/uksi/2026/148/article/32/made>. -/
def ucWorkAllowanceHigher : Nat := 71_000

/-- Taper: the award goes down by 55 % of earned income above the work allowance.
Reg 22(1)(b) <https://www.legislation.gov.uk/uksi/2013/376/regulation/22>. -/
def ucTaperPercent : Nat := 55

/-! ## Tax-Free Childcare and the working-parent funded hours (England) -/

/-- The £100,000 limit: a parent, or their partner, who expects adjusted net
income to exceed it is not eligible. Tax-Free Childcare: Childcare Payments
(Eligibility) Regulations 2015 (SI 2015/448) reg 15(1)
<https://www.legislation.gov.uk/uksi/2015/448/regulation/15>. Funded hours for
working parents: The Childcare (Free of Charge for Working Parents) (England)
Regulations 2022 (SI 2022/1134) regs 14(3)(c)(i) and 15(3)(b)(i)
<https://www.legislation.gov.uk/uksi/2022/1134/regulation/14>; GOV.UK
<https://www.gov.uk/free-childcare-if-working/check-youre-eligible> ("You will not be
eligible if either ... you or your partner's expected adjusted net income ... is
over £100,000"). The universal 15 hours for 3 and 4-year-olds have no income
limit (Childcare Act 2006 s7). -/
def childcareIncomeLimit : Nat := 10_000_000

/-- Minimum expected earnings, as a year: £2,643.68 over three months for a parent
aged 21 or over (16 hours a week at the National Living Wage, £12.71 from April
2026, for 13 weeks), times four. The same figure for both schemes, and for each
parent of a couple: SI 2015/448 reg 9 and SI 2022/1134 reg 18(3) ("minimum weekly
income" of 16 hours at the minimum wage)
<https://www.legislation.gov.uk/uksi/2022/1134/regulation/18>. GOV.UK
<https://www.gov.uk/tax-free-childcare/check-if-youre-eligible>,
<https://www.gov.uk/free-childcare-if-working/check-youre-eligible> ("Over 21 years |
£2,643.68"), <https://www.gov.uk/national-minimum-wage-rates>. Parents under 21 or
apprentices have lower figures (£2,256.80, £1,664), not modelled. -/
def childcareMinimumEarnings : Nat := 4 * 264_368

/-- Tax-Free Childcare top-up cap per child, £500 a quarter, £2,000 a year (child
not disabled). GOV.UK <https://www.gov.uk/tax-free-childcare>. The top-up is £2 for
every £8 the parent pays in, i.e. 20 % of the childcare paid for. -/
def tfcCapPerChild : Nat := 200_000

/-! ## Funded early education and childcare hours (England), 2026-27

Hours. The universal entitlement for 3 and 4-year-olds is 570 hours a year
(Childcare Act 2006 s7; The Local Authority (Duty to Secure Early Years Provision
Free of Charge) Regulations 2014 (SI 2014/2147) reg 4), and the working-parent
entitlement is 1,140 hours a year from 9 months old (SI 2022/1134 reg 44(2)(b);
Childcare Act 2016 s1), the universal hours counting towards it (Childcare Act 2016
s1(6)(a), SI 2022/1134 reg 44(3)). Both are secured "over no fewer than 38 weeks of
the year": DfE statutory guidance "Early education and childcare", valid from 1
April 2026, paras A1.6, A1.10 and A1.16
<https://www.gov.uk/government/publications/early-education-and-childcare--2/early-education-and-childcare-valid-from-1-april-2026>.
GOV.UK: "30 hours per week of free childcare for 38 weeks of the year"
<https://www.gov.uk/free-childcare-if-working/check-youre-eligible>. So the model
counts 15 or 30 hours a week for 38 weeks: 570 or 1,140 hours a year.

Value. The hours are in kind. Each is valued at the Department for Education's
2026-27 national average of local authority hourly funding rates, for the child's
age band: "2026 to 2027 early years national funding formulae: technical note",
section 3.8, Table 6, and section 3.3 (published 15 December 2025, updated 13
January 2026)
<https://www.gov.uk/government/publications/early-years-funding-2026-to-2027/2026-to-2027-early-years-national-funding-formulae-technical-note>.
These are the rates DfE pays local authorities. Authorities must pass at least
97 % of it through to providers, for each entitlement separately ("For 2026 to
2027, we are increasing the minimum pass-through rate to 97%": "Early years
entitlements: local authority funding operational guide 2026 to 2027", section
4.1
<https://www.gov.uk/government/publications/early-years-funding-2026-to-2027/early-years-entitlements-local-authority-funding-operational-guide-2026-to-2027>;
statutory guidance para A4.6), so the average provider gets between 97 % and
100 % of these rates, and the rate a provider gets varies by authority and by
supplement. DfE publishes no national average
of provider rates, so the national average local authority rate is the one
published national figure per hour for each age band. A local nursery price can
be given instead (per child). -/

/-- Weeks a year over which the funded hours are counted: 38. -/
def fundedWeeks : Nat := 38

/-- Universal hours a week for a 3 or 4-year-old: 15 (570 a year over 38 weeks). -/
def universalHoursWeekly : Nat := 15

/-- Working-parent hours a week from 9 months old to school age, universal hours
included: 30 (1,140 a year over 38 weeks). -/
def workingParentHoursWeekly : Nat := 30

/-- Under 2s (9 months to 2), working parent entitlement: £12.04 an hour (Table 6). -/
def eyRateUnder2 : Nat := 1_204

/-- 2-year-olds, combined average of the working parent and disadvantaged
entitlements: £8.90 an hour (Table 6). -/
def eyRate2 : Nat := 890

/-- 3 and 4-year-olds, combined average for the universal and additional hours:
£6.61 an hour (Table 6). -/
def eyRate34 : Nat := 661

/-! ## Universal Credit in full, 2026-27 (monthly amounts, pence)

For assessment periods beginning on or after 6 April 2026 (SI 2026/148 art 1(3),
SI 2026/113 reg 1(4)). Amounts from the reg 36 table as amended by SI 2026/113
reg 3(3) (standard allowance, LCWRA protected rate) and the Social Security
Benefits Up-rating Order 2026 (SI 2026/148) art 32 and Sch 13
<https://www.legislation.gov.uk/uksi/2026/148/article/32/made>; the LCWRA element
for new claimants by the Universal Credit Act 2025 s2(1)(a)
<https://www.legislation.gov.uk/ukpga/2025/22/section/2>. Checked 2026-11-26. -/

/-- Standard allowance, single claimant under 25: £338.58. -/
def ucStandardSingleU25 : Nat := 33_858

/-- Standard allowance, joint claimants both under 25: £528.34. -/
def ucStandardJointU25 : Nat := 52_834

/-- Child element for the first child, where the claimant is responsible for a
child born before 6 April 2017 (Welfare Reform and Work Act 2016 s14(5)(b); SI
2014/1230 reg 43): £351.88. -/
def ucChildElementFirst : Nat := 35_188

/-- Disabled child addition (reg 24(2)), lower rate £164.79, higher rate (a child
getting the DLA care component at the highest rate, the enhanced PIP daily living
component, or blind) £514.71. -/
def ucDisabledChildLower : Nat := 16_479
def ucDisabledChildHigher : Nat := 51_471

/-- LCWRA (health) element (regs 27-28): £217.26 for a claimant who first has it
from 6 April 2026 (Universal Credit Act 2025 s2(1)(a), frozen to 2029-30 by s3);
£429.80 for the protected groups (claimants who had it before 6 April 2026,
reg 27A and Sch 5A; the severe conditions criteria, reg 40A; the terminally ill). -/
def ucLcwraNew : Nat := 21_726
def ucLcwraProtected : Nat := 42_980

/-- Carer element (regs 29-30): £209.34 for each claimant with regular and
substantial caring responsibilities for a severely disabled person. -/
def ucCarerElement : Nat := 20_934

/-- Childcare costs element (regs 31-35): 85 % of the relevant childcare costs
(reg 34(1)), up to £1,071.09 for one child or £1,836.16 for two or more (reg 36,
Sch 13). -/
def ucChildcarePercent : Nat := 85
def ucChildcareMaxOne : Nat := 107_109
def ucChildcareMaxTwo : Nat := 183_616

/-- Lower work allowance, for a claimant whose award includes the housing costs
element: £427 a month (reg 22(2); SI 2026/148 art 32(1)(b)). -/
def ucWorkAllowanceLower : Nat := 42_700

/-- Housing cost contribution for each non-dependant, £96.55 a month (Sch 4 para
14(1); SI 2026/148 art 32(3)). -/
def ucNonDepDeduction : Nat := 9_655

/-- Social-sector under-occupancy (Sch 4 para 36): 14 % of the rent for one
bedroom more than allowed, 25 % for two or more. -/
def ucUnderOccOne : Nat := 14
def ucUnderOccTwo : Nat := 25

/-- Capital (reg 18(1)): no award above £16,000. Tariff income (reg 72(1)): £4.35 a
month for each £250, or part of £250, above £6,000. Unchanged since 2013. -/
def ucCapitalUpper : Nat := 1_600_000
def ucCapitalLower : Nat := 600_000
def ucTariffStep : Nat := 25_000
def ucTariffPerStep : Nat := 435

/-- Benefit cap, annual relevant amounts (reg 80A; WRA 2012 s96): £25,323 in
Greater London and £22,020 elsewhere for a couple or a claimant responsible for a
child, £16,967 and £14,753 for a single claimant without one (as set by SI
2023/335, unchanged for 2026-27). -/
def capLondonFamily : Nat := 2_532_300
def capLondonSingle : Nat := 1_696_700
def capFamily : Nat := 2_202_000
def capSingle : Nat := 1_475_300

/-- Benefit cap earnings exception (reg 82(1)(a)): earned income of at least 16
hours a week at the National Living Wage (£12.71, SI 2026/357), × 52 / 12:
£881.21, which reg 6(1A)(za) rounds down to £881 a month. -/
def capEarningsMonthly : Nat := 88_100

/-! ## Non-means-tested benefits, 2026-27 (weekly amounts, pence)

Social Security Benefits Up-rating Order 2026 (SI 2026/148)
<https://www.legislation.gov.uk/uksi/2026/148/made>, in force from 6 April 2026
(art 1(3)); GOV.UK "Benefit and pension rates 2026 to 2027"
<https://www.gov.uk/government/publications/benefit-and-pension-rates-2026-to-2027/proposed-benefit-and-pension-rates-2026-to-2027>.
Checked 2026-11-26. -/

/-- Child Benefit weeks in 2026-27: 53. A Child Benefit week begins on a Monday
(SSCBA 1992 s147(1)), and so does a week for the High Income Child Benefit Charge,
which is "in a tax year if (and only if) the Monday with which it begins is in the
tax year" (ITEPA 2003 s681H(3)). 6 April 2026 and 5 April 2027 are both Mondays
(SI 2026/232's explanatory note: 6 April 2026 is "the first Monday in the tax year
2026-27"), so 53 weeks begin in 2026-27. -/
def childBenefitWeeks : Nat := 53

/-- Weeks in a year of the other weekly benefits: 52. The tax year 2026-27 has 53
Mondays and 52 of every other day of the week, so 52 weeks of a benefit whose
week starts on any day but Monday begin in it; the model, like PolicyEngine,
takes 52. -/
def benefitWeeks : Nat := 52

/-- PIP daily living component, standard £76.70 and enhanced £114.60; mobility
component, standard £30.30 and enhanced £80.00 (SI 2013/377 reg 24; SI 2026/148
art 15). -/
def pipDailyStandard : Nat := 7_670
def pipDailyEnhanced : Nat := 11_460
def pipMobilityStandard : Nat := 3_030
def pipMobilityEnhanced : Nat := 8_000

/-- DLA care component, highest £114.60, middle £76.70, lowest £30.30; mobility
component, higher £80.00, lower £30.30 (SI 1991/2890 reg 4; SI 2026/148 art 14). -/
def dlaCareHighest : Nat := 11_460
def dlaCareMiddle : Nat := 7_670
def dlaCareLowest : Nat := 3_030
def dlaMobilityHigher : Nat := 8_000
def dlaMobilityLower : Nat := 3_030

/-- Attendance Allowance, higher £114.60 and lower £76.70 (SSCBA 1992 Sch 4 Part III
para 1, s65(3); SI 2026/148 art 3, Sch 1). -/
def aaHigher : Nat := 11_460
def aaLower : Nat := 7_670

/-- Carer's Allowance £86.45 (SSCBA 1992 Sch 4 Part III para 4; SI 2026/148 art 3,
Sch 1). Earnings limit: not entitled in a week after one whose earnings "exceeded
£204" (SI 1976/409 reg 8(1), as amended by the Social Security Benefits Up-rating
Regulations 2026, SI 2026/218 reg 4
<https://www.legislation.gov.uk/uksi/2026/218/made>); earnings are net earnings,
gross pay less income tax, primary Class 1 contributions and half of pension
contributions (SI 1996/2745 reg 10(4)), a fraction of a penny disregarded where
that favours the claimant (reg 5). -/
def caRate : Nat := 8_645
def caEarningsLimit : Nat := 20_400

/-- Maternity Allowance: the lower of 90 % of average weekly earnings and £194.32
(SSCBA 1992 s35A(1); SI 1986/1960 reg 6; SI 2026/148 art 9), for average weekly
earnings of at least the £30 maternity allowance threshold (s35(1)(c), (6A)). -/
def maRateStandard : Nat := 19_432
def maThreshold : Nat := 3_000

/-- New style JSA (SI 2013/378 reg 49(1); SI 2026/148 art 28): £75.65 under 25,
£95.55 from 25. Earnings above £5 a week (reg 50, Schedule para 5) and pension
payments above £50 a week (reg 51(1)) are deducted. -/
def jsaUnder25 : Nat := 7_565
def jsa25 : Nat := 9_555
def jsaEarningsDisregard : Nat := 500
def jsaPensionThreshold : Nat := 5_000

/-- New style ESA (SI 2013/379 reg 62; SI 2026/148 art 31): £95.55, or £75.65 for a
claimant under 25 in the assessment phase; the support component £50.35. Pension
payments above £85 a week reduce it by half the excess (reg 67(1)). -/
def esaRate : Nat := 9_555
def esaAssessmentUnder25 : Nat := 7_565
def esaSupport : Nat := 5_035
def esaPensionThreshold : Nat := 8_500

/-- Sure Start Maternity Grant: £500 (SI 2005/3061 reg 5(1)). -/
def ssmgAmount : Nat := 50_000

/-! ## State Pension and Pension Credit, 2026-27 (weekly amounts, pence)

SI 2026/148 arts 4, 6, 29, Sch 1; GOV.UK "Benefit and pension rates 2026 to
2027". Checked 2026-11-26 against legislation.gov.uk. -/

/-- New State Pension full rate, £241.30 (SI 2015/173 reg 1A; Pensions Act 2014
s3(1)); 35 qualifying years for it (s2(1)(b)), at least 10 for the reduced rate of
1/35 a year (s3(2); SI 2015/173 reg 13(1)). -/
def nspFull : Nat := 24_130
def nspFullYears : Nat := 35
def nspMinYears : Nat := 10

/-- Basic State Pension, Category A £184.90 (SSCBA 1992 s44(4)); Category B
(lower rate, on a spouse's or civil partner's contributions) and Category D
£110.75 (Sch 4 Part I para 5, Part III para 7); the age addition at 80, 25p
(s79; Sch 4 Part III para 8, not uprated). -/
def bspCategoryA : Nat := 18_490
def bspCategoryB : Nat := 11_075
def spAgeAddition : Nat := 25

/-- Pension Credit standard minimum guarantee, £363.25 for a claimant with a
partner, £238.00 without (SI 2002/1792 reg 6(1)). -/
def pcSmgCouple : Nat := 36_325
def pcSmgSingle : Nat := 23_800

/-- Additional amounts (reg 6(5), (8); Sch IIA): severe disability £86.05 (£172.10
where both members of a couple qualify and no one gets a carer benefit for
either); carer £48.15 each; each child £69.98, the first child born before
6 April 2017 £81.07; disabled child £37.93, or £118.46 at the higher rate. -/
def pcSevereDisability : Nat := 8_605
def pcCarer : Nat := 4_815
def pcChild : Nat := 6_998
def pcChildFirstPre2017 : Nat := 8_107
def pcDisabledChildLower : Nat := 3_793
def pcDisabledChildHigher : Nat := 11_846

/-- Savings credit (SPCA 2002 s3; reg 7): threshold £208.07 single, £329.75 a
couple (reg 7(2)); amount A 60 % of qualifying income above the threshold, up to
the maximum, 60 % of the standard minimum guarantee less the threshold (reg
7(1)(a), (b); s3(7)); amount B 40 % of income above the appropriate minimum
guarantee (reg 7(1)(c)); a fraction of a penny in A or B goes to the claimant's
advantage (reg 7(4)). Only where the claimant or partner reached pensionable age
before 6 April 2016 (s3(1)). -/
def pcScThresholdSingle : Nat := 20_807
def pcScThresholdCouple : Nat := 32_975

/-- Deemed income from capital (reg 15(6)): £1 a week for each £500, or part of
£500, above £10,000. No capital limit. -/
def pcCapitalLower : Nat := 1_000_000
def pcCapitalStep : Nat := 50_000

/-- Earnings disregards (Sch VI): £20 for a lone parent, listed employments, a
carer or a disabled claimant or partner (paras 1-4); otherwise £5 for a claimant
without a partner and £10 with one (para 5). -/
def pcDisregardHigher : Nat := 2_000
def pcDisregardSingle : Nat := 500
def pcDisregardCouple : Nat := 1_000

/-! ## Housing Benefit for pensioners, 2026-27 (weekly amounts, pence)

The Housing Benefit (Persons who have attained the qualifying age for state
pension credit) Regulations 2006 (SI 2006/214), as uprated by SI 2026/148 art 24
and Schs 6-7. Checked against legislation.gov.uk on 2026-11-26. -/

/-- Personal allowances (Sch 3 para 1): single claimant or lone parent £256.00 if
they reached pensionable age before 1 April 2021, £238.00 on or after; couple
£383.35 if either did, £363.25 if both reached it on or after. -/
def hbSingleOld : Nat := 25_600
def hbSingleNew : Nat := 23_800
def hbCoupleOld : Nat := 38_335
def hbCoupleNew : Nat := 36_325

/-- Each child or young person £87.88 (Sch 3 para 2); the family premium £20.22,
kept only by those entitled on 30 April 2016 (para 3; SI 2015/1857 reg 4). -/
def hbChild : Nat := 8_788
def hbFamilyPremium : Nat := 2_022

/-- Premiums (Sch 3 para 12): severe disability £86.05 (£172.10 for a couple both
qualifying with no carer benefit for either); enhanced disability £33.99 and
disabled child £84.46 for each child; carer £48.15 each. -/
def hbSevereDisability : Nat := 8_605
def hbEnhancedDisabilityChild : Nat := 3_399
def hbDisabledChild : Nat := 8_446
def hbCarer : Nat := 4_815

/-- Taper (reg 51): 65 % of income above the applicable amount. Capital limit
(reg 43): £16,000. Tariff income (reg 29(2)): £1 a week for each £500 or part
above £10,000. -/
def hbTaperPercent : Nat := 65
def hbCapitalLimit : Nat := 1_600_000

/-- Non-dependant deductions (reg 55(1), (2)): £131.45 for one aged 18 or over in
remunerative work, less on lower gross weekly income: under £192.00, £20.40;
under £279.00, £46.85; under £365.00, £64.35; under £485.00, £105.20; under
£605.00, £119.85; £20.40 for one not in remunerative work. -/
def hbNonDepTop : Nat := 13_145
def hbNonDepBase : Nat := 2_040

/-- Earnings disregards (Sch 4): £25 lone parent, £20 for a carer, a disabled
claimant or partner or listed employments (paras 2-5, at most £25 for a lone
parent and £20 otherwise, para 1), else £10 for a couple and £5 single (para 7). -/
def hbDisregardLoneParent : Nat := 2_500

/-! ## Housing Benefit for working-age claimants, 2026-27 (weekly amounts, pence)

The Housing Benefit Regulations 2006 (SI 2006/213), as uprated by SI 2026/148 art
23 and Schs 4-5 <https://www.legislation.gov.uk/uksi/2026/148/article/23/made>.
The child allowance, family premium, severe disability, enhanced disability (child),
disabled child and carer premiums and the non-dependant deductions are the same
amounts as for pensioners (above). Checked against legislation.gov.uk on
2026-11-27. -/

/-- Personal allowances (Sch 3 para 1, SI 2026/148 Sch 4): single claimant aged 25
or over, or entitled to main phase ESA, £95.55; under 25, £75.65; lone parent aged
18 or over £95.55; couple with a member aged 18 or over £150.15. -/
def hbWaSingle25 : Nat := 9_555
def hbWaSingleU25 : Nat := 7_565
def hbWaLoneParent : Nat := 9_555
def hbWaCouple : Nat := 15_015

/-- Disability premium (Sch 3 para 20(5)): £44.85 single, £64.00 couple. Enhanced
disability premium for an adult (para 20(9)(b), (c)): £22.00 single, £31.40 couple. -/
def hbWaDisabilitySingle : Nat := 4_485
def hbWaDisabilityCouple : Nat := 6_400
def hbWaEnhancedSingle : Nat := 2_200
def hbWaEnhancedCouple : Nat := 3_140

/-- Components (Sch 3 Part 6, art 23(9)): the support component £50.35 (para 26);
the work-related activity component £37.95 (para 25, only for awards protected by
SI 2017/204 Sch 2 paras 2-7). -/
def hbWaSupportComponent : Nat := 5_035
def hbWaWraComponent : Nat := 3_795

/-- The additional earnings disregard (Sch 4 para 17): £17.10, unchanged
(art 23(10)). -/
def hbWaAdditionalDisregard : Nat := 1_710

/-- The disregard for earners in specified or temporary accommodation, from 5 October
2026 (Sch 4 para 18, inserted by SI 2026/753 reg 2 as substituted by SI 2026/978
reg 2): a single claimant or lone parent £61.41 under 25, £77.73 at 25 or over; a
couple £61.53 where both are under 25 (one 18 or over), £119.70 where one is 25 or
over. -/
def hbWaSpecifiedSingleU25 : Nat := 6_141
def hbWaSpecifiedSingle25 : Nat := 7_773
def hbWaSpecifiedCoupleU25 : Nat := 6_153
def hbWaSpecifiedCouple25 : Nat := 11_970

/-- Tariff income (reg 52(1), (6)): £1 a week for each £250, or part, of capital
above £6,000. -/
def hbWaCapitalLower : Nat := 600_000
def hbWaCapitalStep : Nat := 25_000

/-! ## Council tax and Council Tax Reduction, 2026-27

Checked against legislation.gov.uk on 2026-11-27. -/

/-- Band proportions (LGFA 1992 s5(1)): 6 : 7 : 8 : 9 : 11 : 13 : 15 : 18 for bands
A to H, in ninths of band D; Wales adds band I at 21 (s5(1A)); Scotland 240 : 280 :
320 : 360 : 473 : 585 : 705 : 882 in 360ths (s74(1), SSI 2016/368 art 2). -/
def ctNinths : List Nat := [6, 7, 8, 9, 11, 13, 15, 18, 21]
def ctScot360 : List Nat := [240, 280, 320, 360, 473, 585, 705, 882]

/-- Single person discount (LGFA 1992 s11(1)(b), (3); s79 in Scotland): 25 %. -/
def ctDiscountPercent : Nat := 25

/-- Council Tax Reduction for pensioners: England (SI 2012/2885 Sch 1, as amended by
SI 2026/27), Wales (SI 2013/3029 Sch 1, as amended by WSI 2026/13), Scotland (SSI
2012/319, as amended by SSI 2026/56). For each day: 100 % of the day's council tax
less the non-dependant deductions × 1/7 (England Sch 1 paras 7-8), less amount B,
2 6/7 % of the week's income above the applicable amount (para 3(f)), i.e. 20 % a
week. Capital limit £16,000 (SI 2012/2885 reg 11; WSI 2013/3029 reg 30; SSI
2012/319 reg 40). Non-dependant deductions a
week (in remunerative work, by gross weekly income; £x × 1/7 a day): England £15.95,
under £605 £13.30, under £485 £10.60, under £279 or not working £5.20; Wales £20.05,
£16.80, £13.35, £6.70 at the same bands; Scotland £16.55, under £614 £13.90, under
£497 £10.95, under £286 or not working £5.55. -/
def ctrNonDepEngland : List Nat := [520, 1_060, 1_330, 1_595]
def ctrNonDepWales : List Nat := [670, 1_335, 1_680, 2_005]
def ctrNonDepScotland : List Nat := [555, 1_095, 1_390, 1_655]
def ctrBandsGb : List Nat := [27_900, 48_500, 60_500]
def ctrBandsScotland : List Nat := [28_600, 49_700, 61_400]

/-- Applicable amounts that differ from Housing Benefit's: Wales and Scotland have
no lower rate for pensionable age reached from 1 April 2021 (single £256.00, couple
£383.35: WSI 2013/3029 Sch 2 para 1; SSI 2012/319 Sch 1 para 2); Scotland's child
amount is £109.85 (SSI 2012/319 Sch 1 para 3); Wales keeps the family premium,
£20.22 (WSI 2013/3029 Sch 2 para 3), which England sets at nil for weeks from
1 May 2016 (SI 2012/2885 Sch 2 para 3(b)). Premiums as Housing Benefit's in all
three (Sch 2 Part 4; SSI 2012/319 Sch 1 para 13). -/
def ctrChildScotland : Nat := 10_985

/-- Council Tax Reduction for working-age applicants in Wales (WSI 2013/3029 Sch 7,
as amended for 2026-27; consolidated text on legislation.gov.uk checked
2026-11-27): personal allowances (para 1) £101.85 single aged 25 or over (or
entitled to main phase ESA) or lone parent, £80.60 single 18 to 24, £159.85
couple; each child or young person £87.88 (para 3); the family premium £20.22 for
any family with a child (para 4(1)(b), not limited to protected cases as in
Housing Benefit). Premiums (para 17), the earnings disregards (Sch 8 paras 4-11,
17) and the non-dependant deductions (Sch 6 para 5) are those of Housing Benefit
and of the pensioner scheme. Tariff income (Sch 6 para 33): £1 for each £250 or
part above £6,000. -/
def ctrWalesSingle25 : Nat := 10_185
def ctrWalesSingleU25 : Nat := 8_060
def ctrWalesLoneParent : Nat := 10_185
def ctrWalesCouple : Nat := 15_985

/-- Council Tax Reduction for working-age applicants in Scotland (SSI 2021/249 as
amended for 2026-27; consolidated text on legislation.gov.uk checked 2026-11-27).
The personal allowances (Sch 1 para 1), premiums (Sch 1 Part 5), components (paras
23, 24) and the non-dependant deductions (reg 90) are those of Housing Benefit and
the pensioner scheme; the child premium is £109.85 for each child or young person
(para 2, `ctrChildScotland`); there is no family premium. Tariff income (reg 63):
£1 a week for each £250 or part above £6,000, or with Universal Credit £4.35 a
month (the UC amount, `ucTariffPerStep`). Capital limit £16,000 (reg 66).

Reg 42(4): the most a UC claimant may deduct for relevant childcare charges, £290.00
a week for one child, £497.00 for more than one. -/
def ctrScotUcChildcareMaxOne : Nat := 29_000
def ctrScotUcChildcareMaxTwo : Nat := 49_700

/-- Reg 14 (bands E to H): the weekly income below which the maximum is due, £321
for a single applicant not responsible for a child or young person, £479 otherwise
(reg 14(5), (6)). Reg 79(2), (3): the maximum is the day's council tax less that tax
divided by C, 1.075 for band E, 1.125 F, 1.175 G, 1.225 H (the 2017 rise in the band
proportions, LGFA 1992 s74(1) as amended by SSI 2016/368), so the share (C − 1)/C:
3/43, 1/9, 7/47 and 9/49. -/
def ctrScotBandsEHSingle : Nat := 32_100
def ctrScotBandsEHOther : Nat := 47_900

/-- Second adult rebate (Sch 2 para 1): 25 % of the council tax due where every
second adult is on a qualifying income-related benefit, State Pension Credit, or UC
with no earned income; 15 % where their gross income is below £282.00 a week, 7.5 %
below £383.00; 100 % where the dwelling would otherwise be wholly occupied by
students. Rates in tenths of a percent. -/
def ctrScotSarLower : Nat := 28_200
def ctrScotSarUpper : Nat := 38_300

/-! ## English local Council Tax Reduction schemes for working-age applicants, 2026-27

The five English working-age schemes PolicyEngine models, each the council's own
scheme under LGFA 1992 s13A(2) and Sch 1A, read from the council's 2026-27 scheme
text (checked 2026-11-27):

* Kingston upon Thames, Council Tax Reduction Scheme 2026-27
  <https://www.kingston.gov.uk/sites/default/files/2026-07/Council%20Tax%20Reduction%20Scheme%202026-27.pdf>:
  para 29(1) 100 % of A/B; para 17 amount B 2 6/7 % (20 % a week); Sch 3 para 1
  £90.50 single 25 or over or lone parent, £71.70 single 18 to 24, £142.25 couple;
  para 3 £83.24 a child or young person, para 26(1)(b)(i) none for a third or later
  child born after 1 April 2017; para 30A non-dependants £17.31 (£5.64 not in
  remunerative work or under £279.00 a week, £11.50 under £485.00, £14.43 under
  £605.00); £16,000 capital, £1 a week per £250 or part above £6,000.
* Merton, Local Council Tax Support Scheme Rules 2026
  <https://www.merton.gov.uk/sites/default/files/2026-03/Council%20Tax%20Reduction%20Scheme%20L%20B%20Merton%202026-27.pdf>:
  100 %, 2 6/7 %; Sch 3 £95.55, £75.65, £95.55, £150.15, £87.88 a child; para 30
  £15.95 (£5.20, £10.60, £13.30 at £279, £485, £605); £16,000.
* Newham, Council Tax Reduction Scheme 2026
  <https://www.newham.gov.uk/downloads/file/10753/council-tax-reduction-scheme-2026>:
  para 29(1) 70 % of A/B for a person who is not a pensioner; para 17 amount B 3 4/7
  % (25 % a week); Sch 3 the Housing Benefit amounts; para 30B £22.61 (£7.54, £14.96,
  £18.84 at £183, £316, £394); para 22A no reduction above £6,000 of capital.
* Westminster, Council Tax Support scheme for 2026/27
  <https://www.westminster.gov.uk/sites/default/files/media/documents/council-tax-support-scheme-for-2026-27.pdf>
  (the council's summary; the default scheme is its basis): 100 %, 20 %; £95.55,
  £75.65, £95.55, £150.15, £87.88 a child; £15.95 (£5.20, £10.60, £13.30 at £279,
  £485, £605); £16,000.
* Oxford, Council Tax Reduction Scheme 2026 to 2027
  <https://www.oxford.gov.uk/council-tax-reduction/council-tax-reduction-scheme-2026-27>:
  income bands (para 9, Appendix 3): 100 % up to £480.00 a week, 75 % to £530.00,
  50 % to £580.00, 25 % to £660.00, nil above; para 43 non-dependants as Merton;
  £16,000; Appendix 3 ignores £48.15 of each UC carer element and £84.46 of each
  disabled child element; Appendix 4 counts all earnings of a working-age applicant.

All four default-scheme councils keep the Housing Benefit earnings disregards (Sch
7: £5, £10, £20, £25 and the £17.10 step) and disregard Child Benefit (Kingston,
Merton Sch 8 para 66, Newham para 65); the family premium is nil for claims after
1 May 2016. -/
def kingstonPersonal : List Nat := [9_050, 7_170, 9_050, 14_225]
def kingstonChild : Nat := 8_324
def kingstonNonDeps : List Nat := [564, 1_150, 1_443, 1_731]
def mertonNonDeps : List Nat := [520, 1_060, 1_330, 1_595]
def newhamNonDeps : List Nat := [754, 1_496, 1_884, 2_261]
def newhamNonDepBands : List Nat := [18_300, 31_600, 39_400]
def localNonDepBands : List Nat := [27_900, 48_500, 60_500]
def newhamCapitalLimit : Nat := 600_000
def oxfordBands : List Nat := [48_000, 53_000, 58_000, 66_000]
def oxfordCarerDisregard : Nat := 4_815
def oxfordDisabledChildDisregard : Nat := 8_446

/-! ## Capital Gains Tax, 2026-27

TCGA 1992 as amended by Finance Act 2025 ss 7-8 and Finance Act 2023 s8. -/

/-- Main rates (s1H(2)-(3), FA 2025 s7, from 30 October 2024): 18 % within the
unused basic rate band, 24 % above it; residential property gains the same. -/
def cgtBasicRate : Nat := 1_800
def cgtHigherRate : Nat := 2_400

/-- Business Asset Disposal Relief rate for disposals from 6 April 2026: 18 %
(s169N(3), FA 2025 s8). -/
def cgtBadrRate : Nat := 1_800

/-- Annual exempt amount: £3,000 (s1K(2), FA 2023 s8). -/
def cgtExemptAmount : Nat := 300_000

/-! ## Reliefs and the annual allowance charge, 2026-27 (area 6)

Checked on legislation.gov.uk 2026-11-27. -/

/-- The annual allowance (FA 2004 s228(1)): £60,000. The taper (s228ZA): for an
individual whose adjusted income exceeds £260,000 and threshold income exceeds
£260,000 less the allowance (£200,000), the allowance is reduced by half the excess
of adjusted income over £260,000, the reduction rounded down to a whole pound
(s228ZA(2)), not below £10,000. -/
def annualAllowance : Nat := 6_000_000
def aaTaperAdjusted : Nat := 26_000_000
def aaMinimum : Nat := 1_000_000

/-- The tax reduction for finance costs of a dwelling-related loan (ITTOIA 2005
ss 274A, 274AA(5)): the property basic rate, for 2026-27 the basic rate, 20 %
(the separate property rates start in 2027-28, FA 2026 Sch 1). -/
def financeCostRate : Nat := 2_000

/-! ## Student loan repayments and the Winter Fuel Payment, 2026-27 (P9a)

Checked 2026-11-27. -/

/-- Repayment thresholds for 2026-27 (SI 2009/470 reg 3 and Sch 1A): plan 1
£26,900 and plan 2 £29,385 (paras 1, 2: the previous year's threshold times the
repayment threshold variable of reg 8B, rounded up to £5; the amounts published on
GOV.UK, "Repaying your student loan: what you pay"); plan 4 £33,795 (para 4: the
Education (Student Loans) (Scotland) Regulations 2000 reg 2; GOV.UK, as above);
plan 5 £25,000 (para 5(1)(a), the year to 5 April 2027); plan 3 (Postgraduate)
£21,000 (para 3). Rates (reg 29(3)): 9 % for plans 1, 2, 4 and 5, 6 % for plan 3,
concurrently (reg 29(3A)); with more than one of plans 1, 2, 4 and 5, the lowest
threshold (reg 29(5A)). Unearned income counts only if it exceeds £2,000 (reg
29(4)(c)). Plan 5 repayments are due from 6 April 2026 (reg 15(2BA), (2BB)). -/
def slPlan1 : Nat := 2_690_000
def slPlan2 : Nat := 2_938_500
def slPlan4 : Nat := 3_379_500
def slPlan5 : Nat := 2_500_000
def slPostgraduate : Nat := 2_100_000
def slRate : Nat := 900
def slPostgraduateRate : Nat := 600
def slUnearnedLimit : Nat := 200_000

/-- Winter Fuel Payment, pence (SI 2025/969 reg 3, unchanged since made): under
80, £200 (reg 3(1)), or £100 for someone not paid a relevant benefit who lives with
another person entitled or is in residential care (reg 3(2)); £300 at 80 or over
(reg 3(4)), or for someone paid a relevant benefit whose partner is 80 (reg 3(3));
at 80 or over without a relevant benefit, £200 living with an entitled person
under 80 (reg 3(5)) and £150 living with one 80 or over or in residential care
(reg 3(6)). -/
def wfpLower : Nat := 20_000
def wfpLowerShared : Nat := 10_000
def wfpHigher : Nat := 30_000
def wfpHigherSharedWithUnder80 : Nat := 20_000
def wfpHigherSharedWith80 : Nat := 15_000

/-- The winter fuel payment charge (ITEPA 2003 s681I(1)(b), inserted by FA 2026
Sch 10): total income for the tax year exceeding £35,000. -/
def wfpChargeThreshold : Nat := 3_500_000

/-! ## Scottish devolved benefits, 2026-27 (P9b)

Checked 2026-11-27 against the regulations as amended by the Social Security
(Up-rating) (Miscellaneous Amendments) (Scotland) Regulations 2026 (SSI 2026/170)
<https://www.legislation.gov.uk/ssi/2026/170/made>. -/

/-- Scottish Child Payment, £28.20 a week per child (SSI 2020/351 reg 20(1); SSI
2026/170 reg 8). -/
def scpWeekly : Nat := 2_820

/-- Scottish Carer Supplement £11.70 and Carer Additional Person Payment £10.40 a
week (SSI 2023/302 reg 16(1A), (1B); SSI 2026/170 reg 12(3)). Carer Support
Payment itself is £86.45 (reg 16(1)) with a £204 earnings limit (reg 14(1)), the
Carer's Allowance figures `caRate` and `caEarningsLimit`. -/
def cspSupplement : Nat := 1_170
def cspAdditional : Nat := 1_040

/-- Pension Age Winter Heating Payment, pence (SSI 2024/351 reg 10(4)-(6); SSI
2026/170 reg 15(3)): £316.70 and £211.15 on a relevant benefit; under 80 without
one £211.15, or £105.55 sharing or in residential care; 80 or over without one
£316.70, £211.15 living with an entitled person under 80, £158.35 with one 80 or
over or in residential care. -/
def pawhpLower : Nat := 21_115
def pawhpLowerShared : Nat := 10_555
def pawhpHigher : Nat := 31_670
def pawhpHigherSharedWithUnder80 : Nat := 21_115
def pawhpHigherSharedWith80 : Nat := 15_835

/-! ## Early learning for 2-year-olds, England (P9c) -/

/-- The targeted 15 hours for a 2-year-old (SI 2014/2147 regs 3, 4; 570 hours a
year over 38 weeks). A parent on Universal Credit qualifies with earned income
(UC Regs Part 6 Ch 2) of no more than £1,283.34 in the assessment period before
the request, a couple's combined (reg 1(3)(c), (4)); over twelve equal months,
£15,400.08 a year. Checked 2026-11-27 against
<https://www.legislation.gov.uk/uksi/2014/2147/regulation/1>. -/
def targetedHoursWeekly : Nat := 15
def targetedUcMonthlyLimit : Nat := 128_334

/-! ## Company cars, car fuel and the TV licence, 2026-27 (P9d)

Checked 2026-11-27. -/

/-- The appropriate percentage (ITEPA 2003 s139, the table for 2026-27 substituted
by FA 2023 s11(5), (6); s139(3)(a) 21 % by s11(3), (4)): 0 g/km 4 %; 1-50 g/km by
electric range, 130 miles or more 4 %, 70-129 7 %, 40-69 10 %, 30-39 14 %, under
30 16 %; 51-54 17 %, 55-59 18 %, 60-64 19 %, 65-69 20 %, 70-74 21 %; from 75 g/km
21 % plus a point for each full 5 g/km above 75, at most 37 % (s139(3), (4)). A
diesel car not meeting Euro 6d adds 4 points, at most 37 % (s141(2), Step 3:
legislation.gov.uk still prints 35 %, but FA 2025 s5(6) substitutes "38%" for
"37%" there from 2028-29, so 37 % is the figure in force). -/
def carMaxPct : Nat := 37
def carDieselSupplement : Nat := 4

/-- Capital contributions count up to £5,000 (s132(3)); the car fuel benefit
charge multiplier is £29,200 (s150(1)). 2026-27 has 365 days (s143(3) Y). -/
def carContributionCap : Nat := 500_000
def carFuelMultiplier : Nat := 2_920_000
def taxYearDays : Nat := 365

/-- The TV licence fee, £180.00 (Communications (Television Licensing) Regulations
2004, SI 2004/692, Sch 1 Part 1 para 2); half for a blind licence holder (reg 5). -/
def tvLicenceFee : Nat := 18_000

/-! ## ISAs, the minimum wage and the Warm Home Discount, 2026-27 (P9e)

Checked 2026-11-27. -/

/-- ISA subscription limit £20,000 and Lifetime ISA payment limit £4,000 a year
(SI 1998/1870 reg 4ZA(1), (1A)); the government bonus is 25 % of qualifying
additions (Schedule para 1, "government bonus"), for a holder of 18 to 49 (reg
10A(2)(a), (b)). -/
def isaLimit : Nat := 2_000_000
def lisaLimit : Nat := 400_000

/-- Hourly rates, pence (National Minimum Wage Regulations 2015, SI 2015/621, regs
4, 4A(1), as amended by SI 2026/357 reg 2): 21 or over £12.71 (the National Living
Wage), 18 to 20 £10.85, under 18 £8.00, apprentices (reg 5(1)(a), (b)) £8.00. -/
def nlwRate : Nat := 1_271
def nmw18Rate : Nat := 1_085
def nmw16Rate : Nat := 800
def nmwApprenticeRate : Nat := 800

/-- The Warm Home Discount rebate, £150 (Warm Home Discount (England and Wales)
Regulations 2026, SI 2026/389 reg 2, "prescribed rebate"); the qualifying benefits
are set by the 2026-27 eligibility statement (reg 10): Pension Credit,
income-related ESA, Housing Benefit, Universal Credit. -/
def whdRebate : Nat := 15_000

/-! ## Vehicle Excise Duty for cars, 2026-27 (P9f)

Vehicle Excise and Registration Act 1994 Sch 1 Parts 1A (pre-2001 light vehicles),
1AA (cars registered 1 March 2001 to 31 March 2017, graduated by CO2) and 1AB (cars
registered from 1 April 2017), with the rates for licences taken out from 1 April
2026 as published on GOV.UK, "Vehicle tax rate tables" (checked 2026-11-27): a
twelve-month licence, single payment, pounds. -/

/-- First licence of a car registered from 1 April 2017, by CO2 band upper limits
0, 50, 75, 90, 100, 110, 130, 150, 170, 190, 225, 255 g/km, then above 255
(Sch 1 Part 1AB para 1J): petrol, RDE2 diesel, alternative fuel and zero emission;
and other diesel cars. -/
def vedFirstYear : List Nat := [10, 115, 135, 280, 365, 405, 455, 560, 1410, 2270, 3420, 4850, 5690]
def vedFirstYearDiesel : List Nat := [10, 135, 280, 365, 405, 455, 560, 1410, 2270, 3420, 4850, 5690, 5690]
def vedFirstYearLimits : List Nat := [0, 50, 75, 90, 100, 110, 130, 150, 170, 190, 225, 255]

/-- Later licences: £200, and £440 more in the second to sixth licence years where
the list price exceeded £40,000 (£50,000 for a zero emission car; none for a zero
emission car registered before 1 April 2025) (Sch 1 Part 1AB paras 1K, 1L). -/
def vedStandard : Nat := 200
def vedSupplement : Nat := 440
def vedPriceThreshold : Nat := 4_000_000
def vedPriceThresholdZev : Nat := 5_000_000

/-- Bands A to M for cars registered 1 March 2001 to 31 March 2017, by upper
limits 100, 110, 120, 130, 140, 150, 165, 175, 185, 200, 225, 255 g/km, then above
(Sch 1 Part 1AA): £20, 20, 35, 170, 200, 225, 275, 325, 360, 410, 445, 760, 790;
a car registered before 23 March 2006 pays no more than band K. -/
def vedGraduated : List Nat := [20, 20, 35, 170, 200, 225, 275, 325, 360, 410, 445, 760, 790]
def vedGraduatedLimits : List Nat := [100, 110, 120, 130, 140, 150, 165, 175, 185, 200, 225, 255]

/-- Cars registered before 1 March 2001: £230 with an engine of 1,549cc or less,
£375 above (Sch 1 Part 1A). -/
def vedSmallEngine : Nat := 230
def vedLargeEngine : Nat := 375

/-! ## Student support in England, 2026-27 academic year (P9g)

The Education (Student Support) Regulations 2011 (SI 2011/1986), with the sums
substituted for academic years from 1 August 2026 by SI 2026/130 Sch (checked on
legislation.gov.uk, 2026-11-27). Loans for living costs of a 2016 cohort student
(began on or after 1 August 2016) with full entitlement: regs 80A (standard),
80B (would qualify for a special support grant but for reg 61(A1): the
"entitled to benefits" schedule) and 80C (aged 60 or over). Categories (reg 90):
A living with parents, B London, C overseas, D elsewhere. Each list is
A, B, C, D. Loans in pounds; incomes in pence; tapers in tenths of a penny per
pound of loan ("£1 for every complete £6.54": 6540). -/

/-- Household income above which the loans taper: £25,000 (regs 80A(2), 80B(2), 80C(2)). -/
def sfeThreshold : Nat := 2_500_000
/-- The second stage of reg 80B: £42,875. -/
def sfeHigherThreshold : Nat := 4_287_500

/-- Reg 80A(2) X, academic years other than a final year: £9,118, £14,135, £12,403, £10,830. -/
def ml80aMax : List Nat := [9_118, 14_135, 12_403, 10_830]
/-- Reg 80A(3) X, a final year: £8,579, £13,096, £11,103, £10,242. -/
def ml80aMaxFinal : List Nat := [8_579, 13_096, 11_103, 10_242]
/-- Reg 80A(2), (3) Y and reg 80B Z: £1 for every complete £6.54, £6.36, £6.41, £6.47. -/
def mlTaper : List Nat := [6_540, 6_360, 6_410, 6_470]
/-- Reg 80B(2) X: £10,757, £15,415, £13,806, £12,345. -/
def ml80bMax : List Nat := [10_757, 15_415, 13_806, 12_345]
/-- Reg 80B(4) X, a final year: £10,255, £14,447, £12,597, £11,800. -/
def ml80bMaxFinal : List Nat := [10_255, 14_447, 12_597, 11_800]
/-- Reg 80B(2) Y, £25,000 to £42,875: £1 for every complete £4.088, £4.37, £4.265, £4.179. -/
def ml80bTaper1 : List Nat := [4_088, 4_370, 4_265, 4_179]
/-- Reg 80B(4) Y, a final year: £4.054, £4.295, £4.174, £4.137. -/
def ml80bTaper1Final : List Nat := [4_054, 4_295, 4_174, 4_137]
/-- The minimum level (reg 105(6A), (6C)): £4,013, £7,039, £5,996, £5,048. -/
def mlMin : List Nat := [4_013, 7_039, 5_996, 5_048]
/-- The minimum level in a final year (reg 105(6B), (6D)): £3,687, £6,413, £5,210, £4,693. -/
def mlMinFinal : List Nat := [3_687, 6_413, 5_210, 4_693]
/-- Reg 80C(2), (3): £4,582 less £1 for every complete £4.16 over £25,000; nil if
less than £50. -/
def ml80cMax : Nat := 4_582
def ml80cTaper : Nat := 4_160
def ml80cMinimum : Nat := 50

/-- Sch 4 para 3(3): £1,130 off household income for each dependent child (other
than the student); para 5(2)(c), 7(1)(c): £1,130 off the residual income of a
parent (or parent's partner) who is a student or holds a statutory award. -/
def sfeChildDeduction : Nat := 113_000

/-- Adult Dependants' Grant (regs 44(3)(a), 47(1A)-(1B)): £3,545, less half the
excess of the dependants' income over £8,746; nil over £15,835.98. -/
def adgBasic : Nat := 354_500
def adgThreshold : Nat := 874_600
def adgNilAbove : Nat := 1_583_598
/-- Parents' Learning Allowance (regs 46(2), 47(3A)-(3B), (6)): £2,024, less half
the excess over £14,910; at least £50 once £0.01 or more; nil over £18,957.98. -/
def plaBasic : Nat := 202_400
def plaThreshold : Nat := 1_491_000
def plaNilAbove : Nat := 1_895_798
def plaMinimum : Nat := 5_000

/-- Childcare Grant (reg 45(5)): 85 % of the prescribed childcare charges for each
week, at most £199.62 a week for one dependent child and £342.24 for two or more.
Reg 47(2A)-(2C): the annual amount (`A`, 52 weeks of it) less the excess of the
residual income of the partner and adult dependants and the net income of the
children over £9,727 (one child) or £11,118 (two or more), the excess times the
days qualifying over the days of the academic year; nil over £20,107.23 or
£28,914.47. The sums were last substituted by SI 2025/162 Sch 2; SI 2026/130
changes none of regs 44 to 47 (its Schedule lists no sum there), so they carry
into 2026-27 (checked on legislation.gov.uk, 2026-11-27). The 2026-27 academic
year has no 29 February, so F is 365. -/
def cgPercent : Nat := 85
def cgMaxOne : Nat := 19_962
def cgMaxTwo : Nat := 34_224
def cgThresholdOne : Nat := 972_700
def cgThresholdTwo : Nat := 1_111_800
def cgNilAboveOne : Nat := 2_010_723
def cgNilAboveTwo : Nat := 2_891_447
def cgYearDays : Nat := 365

/-! ## Free school lunches in England, 2026-27 (P9h)

Education Act 1996 s512ZB as in force in 2026-27 (checked on legislation.gov.uk,
2026-11-27). The Universal Credit route of s512ZB(4)(a)(ai), (b)(ai) carries an
earnings test (the Free School Lunches and Milk, and School and Early Years
Finance (Amendments Relating to Universal Credit) (England) Regulations 2018, SI
2018/148, regs 2 to 4): earned income (UC Regs 2013 Part 6 Ch 2; a couple's
combined) of no more than £616.67 in the assessment period before the request,
or £1,233.34 over two, or £1,850 over three. From 17 August 2026 s512ZB(4D)
(Children's Wellbeing and Schools Act 2026 s32, commenced by SI 2026/803 reg 4)
makes a pupil whose parent, or who, is in receipt of Universal Credit eligible
whatever the earnings. -/

/-- The SI 2018/148 reg 4(b)(i) limit for one assessment period: £616.67. With
equal months the two- and three-period tests (£1,233.34, £1,850) give the same
answer, so the test is twelve times it a year: £7,400.04. -/
def fsmUcMonthlyLimit : Nat := 61_667

/-! ## Stamp Duty Land Tax (England and Northern Ireland), 2026-27

Finance Act 2003, for land transactions with an effective date in 2026-27. Bands
as (upper limit in pence, rate in basis points); the last band has no limit. -/

/-- Residential rates (s55(1B) Table A): 0 % to £125,000, 2 % to £250,000, 5 % to
£925,000, 10 % to £1,500,000, 12 % above. -/
def sdltResidential : List (Nat × Nat) :=
  [(12_500_000, 0), (25_000_000, 200), (92_500_000, 500), (150_000_000, 1_000), (0, 1_200)]

/-- First-time buyers' relief (Sch 6ZA para 4): 0 % to £300,000, 5 % to £500,000;
only where the consideration is not more than £500,000 (para 1(3)) and not for a
higher rates transaction (para 1(7)). -/
def sdltFirstTime : List (Nat × Nat) := [(30_000_000, 0), (0, 500)]
def sdltFirstTimeLimit : Nat := 50_000_000

/-- Higher rates for additional dwellings (Sch 4ZA para 1(2), FA 2025 s51, from
1 April 2025): 5 % to £125,000, 7 % to £250,000, 10 % to £925,000, 15 % to
£1,500,000, 17 % above; not where the consideration is under £40,000 (para 3(2)). -/
def sdltHigher : List (Nat × Nat) :=
  [(12_500_000, 500), (25_000_000, 700), (92_500_000, 1_000), (150_000_000, 1_500), (0, 1_700)]
def sdltHigherMin : Nat := 4_000_000

/-- Non-residential or mixed (s55(1B) Table B): 0 % to £150,000, 2 % to £250,000,
5 % above. -/
def sdltNonResidential : List (Nat × Nat) := [(15_000_000, 0), (25_000_000, 200), (0, 500)]

/-- Rent under a lease (Sch 5 para 2(3)), on the net present value of the rent
(para 3, discounted at 3.5 % a year, para 8): residential (Table A) 0 % to £125,000,
1 % above; non-residential or mixed (Table B) 0 % to £150,000, 1 % to £5 million,
2 % above. -/
def sdltRentResidential : List (Nat × Nat) := [(12_500_000, 0), (0, 100)]
def sdltRentNonResidential : List (Nat × Nat) := [(15_000_000, 0), (500_000_000, 100), (0, 200)]

/-- Non-resident transactions (s75ZA, Sch 9A, from 1 April 2021): 2 % added to each
rate of s55(1B) Table A, Sch 4ZA Table A, Sch 6ZA Table A and Sch 5 Table A. -/
def sdltNonResidentRate : Nat := 200

/-! ## Land and Buildings Transaction Tax (Scotland), 2026-27

LBTT(S)A 2013; the Tax Rates and Tax Bands Order (SSI 2015/126 Schedule, as amended
by SSI 2018/372, 2019 and 2020 Orders; consolidated text checked 2026-11-27, no
amending instrument in 2025 or 2026). -/

/-- Table A, residential: 0 % to £145,000, 2 % to £250,000, 5 % to £325,000, 10 % to
£750,000, 12 % above. -/
def lbttResidential : List (Nat × Nat) :=
  [(14_500_000, 0), (25_000_000, 200), (32_500_000, 500), (75_000_000, 1_000), (0, 1_200)]

/-- First-time buyer relief (Sch 4A para 3): no tax on the first £175,000. -/
def lbttFirstTime : List (Nat × Nat) :=
  [(17_500_000, 0), (25_000_000, 200), (32_500_000, 500), (75_000_000, 1_000), (0, 1_200)]

/-- Additional dwelling supplement (Sch 2A paras 2(1)(b), 4(2)): 8 % of the relevant
consideration where it is £40,000 or more. -/
def lbttAdsRate : Nat := 800
def lbttAdsMin : Nat := 4_000_000

/-- Table B, non-residential: 0 % to £150,000, 1 % to £250,000, 5 % above. Table C,
rent (on the NPV, Sch 19 paras 3, 7: 3.5 %): 0 % to £150,000, 1 % to £2 million, 2 %
above. Residential leases are exempt (Sch 1 para 3). -/
def lbttNonResidential : List (Nat × Nat) := [(15_000_000, 0), (25_000_000, 100), (0, 500)]
def lbttRent : List (Nat × Nat) := [(15_000_000, 0), (200_000_000, 100), (0, 200)]

/-! ## Land Transaction Tax (Wales), 2026-27

LTTA 2017; the Tax Bands and Tax Rates Regulations (WSI 2018/128 Schedule, as
amended to 2024; consolidated text checked 2026-11-27). -/

/-- Table 1, residential: 0 % to £225,000, 6 % to £400,000, 7.5 % to £750,000, 10 %
to £1,500,000, 12 % above. -/
def lttResidential : List (Nat × Nat) :=
  [(22_500_000, 0), (40_000_000, 600), (75_000_000, 750), (150_000_000, 1_000), (0, 1_200)]

/-- Table 2, higher rates (where Sch 5 applies: an individual buying a dwelling for
£40,000 or more who owns another, para 3(2)(c)): 5 % to £180,000, 8.5 % to
£250,000, 10 % to £400,000, 12.5 % to £750,000, 15 % to £1,500,000, 17 % above. -/
def lttHigher : List (Nat × Nat) :=
  [(18_000_000, 500), (25_000_000, 850), (40_000_000, 1_000), (75_000_000, 1_250), (150_000_000, 1_500), (0, 1_700)]
def lttHigherMin : Nat := 4_000_000

/-- Table 3, non-residential: 0 % to £225,000, 1 % to £250,000, 5 % to £1,000,000, 6 %
above. Table 4, rent (on the NPV, Sch 6 paras 31, 32: 3.5 %): 0 % to £225,000, 1 %
to £2 million, 2 % above; residential leases are not charged on rent (Sch 6 para
27). -/
def lttNonResidential : List (Nat × Nat) := [(22_500_000, 0), (25_000_000, 100), (100_000_000, 500), (0, 600)]
def lttRent : List (Nat × Nat) := [(22_500_000, 0), (200_000_000, 100), (0, 200)]

end UkTax
