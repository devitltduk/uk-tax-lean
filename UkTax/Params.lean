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
  deriving Repr

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

/-- Higher rate limit, £125,140. ITA 2007 s10(5A) defines it as twice the personal
allowance plus £100,000, i.e. the income at which the personal allowance has
tapered to nil. Additional rate applies above it (GOV.UK
<https://www.gov.uk/income-tax-rates>). -/
def higherRateLimit : Nat := 2 * personalAllowance + 10_000_000

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

end UkTax
