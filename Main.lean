import Lean.Data.Json
import UkTax

/-!
`uktax`: read incomes as JSON on stdin, print the 2026-27 liability as JSON.

Input: one object, or an array of objects, with whole-pence amounts:

    {"non_savings_pence": 5000000, "savings_pence": 0, "dividends_pence": 0}

Optional fields:

* `employment_pence`: the part of `non_savings_pence` that is employment
  earnings, on which employee Class 1 NICs are due (default 0);
* `nic_earnings_period`: `"annual"` (default), `"monthly"` or `"weekly"`;
* `child_benefit_pence`: Child Benefit paid for the year to the taxpayer or
  their partner, on which the taxpayer pays the High Income Child Benefit
  Charge (default 0);
* `uc`: `{"couple": false, "children": 2}` to claim Universal Credit (pay only:
  not allowed with savings or dividends). Optional fields of `uc`:
  `under_25` (single claimant, or both joint claimants, under 25),
  `first_child_pre_2017` (responsible for a child born before 6 April 2017),
  `disabled_children_lower`, `disabled_children_higher` (counts),
  `health` (`"none"`, `"new"` or `"protected"`: the LCWRA element), `carers`
  (0 to 2), `childcare_monthly_pence` and `childcare_children`, `rent_monthly_pence`
  with `lha_monthly_pence` (private renter) or `spare_rooms` (social renter) and
  `non_dependants`, `capital_pence`, `unearned_monthly_pence`,
  `partner_earned_pence` (the partner's earned income for the year, net of their
  tax and NICs), `cannot_provide_childcare` and
  `partner_cannot_provide_childcare` (reg 32(1)(b): limited capability for work,
  caring or absent, so the childcare work condition does not need that member in
  paid work), `london` and `cap_exempt` (for the benefit cap, which also counts
  `child_benefit_pence`);
* `childcare_costs_pence`: yearly childcare costs per child, for Tax-Free
  Childcare (default none);
* `partner`: `{"pay_pence": 3000000, "adjusted_net_income_pence": 3000000}`, a
  partner who must also pass the childcare tests (minimum earnings, £100,000);
  fixed. Not allowed with a UC couple, whose partner has no pay. A UC couple
  with no `partner` fails the tests;
* `country`: `"england"` (default), `"wales"`, `"northern_ireland"` or
  `"scotland"` (a Scottish taxpayer: Scottish rates on non-savings income); the
  funded hours are England's;
* `gift_aid_gross_pence`: Gift Aid donations, grossed up at the basic rate (the
  amount given ÷ 0.8), and `pension_relief_at_source_gross_pence`: pension
  contributions relieved at source, gross (default 0 each). Both raise the rate
  limits (ITA 2007 s414(2), FA 2004 s192(4), (4A)) and come off adjusted net
  income (ITA 2007 s58). Not allowed with `uc` (Universal Credit deducts pension
  contributions from earned income, which is not modelled yet);
* `net_pay_pension_pence`: pension contributions deducted from pay under a net
  pay arrangement (FA 2004 s193(2)), part of `employment_pence` (default 0).
  `non_savings_pence` and `employment_pence` are pay before them: income tax is
  on pay less them, NICs on the whole pay. Not allowed with the childcare tests
  (`childcare_costs_pence`, `funded_children`, `partner`);
* `blind`: gets the blind person's allowance (ITA 2007 s38; default false);
* `marriage_allowance`: `"transfer"` (has elected to give up £1,260 of personal
  allowance to a spouse or civil partner, s55C; the election stands only if this
  taxpayer passes the rate test of s55C(1)(c), (ca)) or `"receive"` (the spouse
  or civil partner has elected; a tax reduction of £252 if this taxpayer passes
  the rate test of s55B(2)(b), (ba)). Default none;
* `married_couples_allowance`: claims the married couple's allowance (s45 or
  s46: a party born before 6 April 1935; this taxpayer is the husband or the
  partner with the higher income). Not with `marriage_allowance`
  (s55B(2)(d)). Default false;
* `trading_receipts_pence` and `trading_expenses_pence`: one trade's receipts and
  allowable expenses; `property_receipts_pence` and `property_expenses_pence`:
  one UK property business's receipts and expenses, other than rent-a-room;
  `rent_a_room_receipts_pence` and `rent_a_room_expenses_pence`: receipts from
  letting furnished rooms in the taxpayer's only or main home, and
  `rent_a_room_shared`: someone else also has such receipts from that home (the
  limit is then halved). Default 0 / false. The profits, with the trading and
  property allowances and rent-a-room relief elected as gives the least
  (`UkTax/Profits.lean`), are added to `non_savings_pence` (which is then the
  other non-savings income, such as pay). No losses: a loss counts as nil. Not
  with the childcare tests; with `uc`, a trade only (no property or rent-a-room
  income): its receipts less expenses, less the tax and Class 4 on it, are
  self-employed earnings (reg 57, nil for a loss; `UkTax/UcSelfEmployed.lean`).
  `uc.minimum_income_floor`: `{"expected_hours": 35, "partner_expected_hours": 35,
  "whole_pounds": true}` applies the floor of reg 62 (the caller has found the
  claimant in gainful self-employment, subject to all work-related requirements
  and outside a start-up period); outputs `uc_earned_income_ten_thousandths_pence`
  (before the floor) and `uc_minimum_income_floor_ten_thousandths_pence` (the net
  individual threshold);
* National Insurance beyond employee Class 1 (`UkTax/Nics.lean`):
  `employer_zero_rated` (an employee under 21 or a relevant apprentice under 25:
  employer Class 1 at 0 % up to the upper secondary threshold; default false),
  `class_1a_benefits_pence` (cash equivalent of benefits in kind, for Class 1A),
  `class_2_voluntary_weeks` (weeks of voluntary Class 2, paid only with profits
  below the small profits threshold) and `class_3_weeks` (weeks of Class 3).
  Class 4 is on the trading profit, limited by the reg 100 annual maximum where
  employee Class 1 is also payable;
* `funded_children`: children for the funded hours, e.g.
  `[{"age": "under_2"}, {"age": "3_4", "price_pence_per_hour": 750}]`, ages
  `"under_2"` (9 months to 2), `"2"` and `"3_4"` (until school); the hours are
  valued at DfE's 2026-27 national average rate for the age unless a local price
  per hour is given. A 2-year-old also gets the targeted 15 hours when the family
  is on Universal Credit with low earnings (worked out here), or
  `targeted_other_benefit` is set, or the child has `"targeted_criteria": true`
  (output `funded_hours_targeted_millionths_pence`: what they add to
  `funded_hours_millionths_pence`).

* `child_benefit_children`: Child Benefit for a whole 2026-27 (53 weeks) for that
  many children, in place of `child_benefit_pence` (output `child_benefit_pence`);
* `disability`: `{"pip_daily_living": "standard" | "enhanced", "pip_mobility": ...,
  "dla_care": "lowest" | "middle" | "highest", "dla_mobility": "lower" | "higher",
  "attendance_allowance": "lower" | "higher"}` (outputs
  `disability_benefits_weekly_pence`, `disability_benefits_pence` for 52 weeks);
* `carers_allowance`: `{"overlapping_weekly_pence": 0}` for a carer meeting the
  caring conditions; pay only (outputs `carers_allowance_pence`,
  `carers_allowance_weekly_net_earnings_pence`, and
  `net_income_carer_ten_thousandths_pence`, the `netCarer` of
  `UkTax/Disability.lean`, with the allowance taxed as non-savings income).
  With `uc` (which must then have `carers` of at least 1, reg 30(1)(a), and no
  childcare tests) the allowance is deducted from UC as unearned income
  (`uc_millionths_pence`), and `net_income_carer_uc_millionths_pence` is the
  `netCarerUc` of `UkTax/CarerUc.lean` (`net_income_millionths_pence` is then
  null);
* `maternity_allowance`: `{"average_weekly_earnings_pence": n}` (output
  `maternity_allowance_weekly_tenths_pence`); `jsa_contrib`: `{"under_25": false,
  "earnings_weekly_pence": n, "pension_weekly_pence": n}` (output
  `jsa_contrib_weekly_pence`); `esa_contrib`: `{"assessment_under_25": false,
  "support_group": false, "pension_weekly_pence": n}` (output
  `esa_contrib_weekly_tenths_pence`); `ssmg`: `{"qualifying_benefit": true,
  "existing_children_under_16": 0, "babies": 1}` (output `ssmg_pence`).

* `pension_credit`: `{"couple": false, "savings_credit": false, "severe_disability": 0,
  "carers": 0, "children": 0, "first_child_pre_2017": false, "disabled_children_lower": 0,
  "disabled_children_higher": 0, "higher_earnings_disregard": false,
  "state_pension_pence": n, "other_pension_pence": n, "other_income_pence": n,
  "excluded_income_pence": n, "net_earnings_pence": n, "capital_pence": n,
  "income_tax_pence": n}`, yearly amounts (earnings after NICs; the income tax on
  all the income counted is deducted, reg 17(10)(a): for a single claimant the
  model's liability on it as non-savings income unless given, for a couple
  required) (`UkTax/Pension.lean`); outputs `pension_credit_tenths_pence` and
  `guarantee_credit_tenths_pence` for the year (52 weeks), the income
  (`pension_credit_income_tenths_pence`, also units of 1/520 penny a week) and the
  appropriate minimum guarantee (`minimum_guarantee_weekly_pence`);
* `housing_benefit` (with `pension_credit` describing the household's income):
  `{"rent_weekly_pence": n, "lha_weekly_pence": n (private renter), "non_dependants":
  [{"working": true, "gross_weekly_pence": n}], "non_dependant_exempt": false,
  "pensionable_age_before_april_2021": false, "lone_parent": false,
  "family_premium": false, "severe_disability": 0, "enhanced_disability_children": 0,
  "disabled_children": 0, "carers": 0}`, Housing Benefit for pensioners
  (`UkTax/HousingBenefit.lean`); output `housing_benefit_twentieths_pence` for the
  year (52 weeks), and the weekly maximum and applicable amount;
* `capital_gains_pence` and `badr_gains_pence`: the year's gains after losses, other
  and qualifying for Business Asset Disposal Relief (within the lifetime limit);
  output `cgt_exact_ten_thousandths_pence` (`UkTax/Cgt.lean`), banded against this
  taxpayer's income. For a Scottish taxpayer the UK basic rate band is used
  (TCGA 1992 s1J(6));
* `housing_benefit_working_age`: working-age Housing Benefit (`UkTax/HousingBenefitWa.lean`),
  pay only: the rent and non-dependant fields of `housing_benefit`, and `couple`,
  `lone_parent`, `under_25`, `children`, `family_premium`, `disability_premium`,
  `enhanced_disability_premium`, `severe_disability`, `enhanced_disability_children`,
  `disabled_children`, `carers`, `esa_component` (`"none"`, `"support"`, `"wra"`),
  `disregard` (`"single"`, `"couple"`, `"higher"`, `"lone_parent"`; by default from
  the household), `additional_disregard`, `passported` (on UC, Income Support,
  income-based JSA or income-related ESA), `other_weekly_pence` (other income
  counted in full), `capital_pence`, `accommodation` (`"specified"`, the default,
  `"temporary"` or `"general"`: specified or temporary accommodation keeps the award
  past 1 July 2026 and gives an earner the para 18 disregard from 5 October 2026)
  and `esa_saved` (an income-related ESA award saved by art 3A(2)); in general
  accommodation without that the award ends on 30 June 2026. The benefit cap:
  `cap_exempt` (a reg 75F benefit), `london`, `cap_other_weekly_pence` (the other
  welfare benefits a week). `under_25` is the single claimant or lone parent, or both members
  of a couple. Outputs `housing_benefit_wa_rate_before_millionths_pence` and
  `housing_benefit_wa_rate_from_october_millionths_pence` (each a rate for 52 weeks,
  to 4 October and from 5 October 2026), `housing_benefit_wa_payable_728_millionths_pence`
  (payable in 2026-27, × 728), the weekly applicable amount and maximum;
* `council_tax_reduction_working_age` (with `"country": "wales"`): Council Tax
  Reduction for a working-age applicant under the Welsh prescribed scheme
  (`UkTax/CtrWorkingAge.lean`): `council_tax_pence` (the year's bill after
  discounts) and the household fields of `housing_benefit_working_age` (no rent;
  `passported` for income support, income-based JSA or income-related ESA). With
  `uc` and a UC award above nil the UC rule applies (the UC maximum amount as the applicable amount, the UC
  income and award as income). Output `council_tax_reduction_wa_364m_pence`, the
  year's reduction in 1/364 000 000 pence, and the own-rules weekly applicable
  amount. With `"country": "scotland"`, the Scottish scheme (SSI 2021/249): its own
  applicable amount on UC too, the relevant UC payments and childcare charges;
  optional `band` ("A" to "H") for reg 14 (bands E to H) and `second_adult`
  (`{"council_tax_pence": n, "on_benefit": b, "students": b, "gross_weekly_pence": n}`,
  Sch 2). Then `council_tax_reduction_wa_364m_pence` is the reg 13 main reduction,
  and the outputs add `council_tax_reduction_wa_second_adult_364m_pence`,
  `council_tax_reduction_wa_bands_e_h_su_pence` and the entitlement
  `council_tax_reduction_wa_total_su_pence`, in 1/(364 000 000 × 891 261) pence;
* `council_tax_reduction_local` (with `"country": "england"`): a working-age
  applicant under one of the five English councils' schemes PolicyEngine models
  (`UkTax/CtrEnglandLocal.lean`): `authority` (`kingston_upon_thames`, `merton`,
  `newham`, `westminster`, `oxford`), `council_tax_pence`, the household fields of
  `housing_benefit_working_age` without premiums, `limited_children` (children
  given no amount by Kingston's two-child rule) and `child_benefit_children` (Oxford
  counts Child Benefit as income on UC). With `uc` and an award above nil
  the UC rules apply. Outputs `council_tax_reduction_local_lcu_pence`, the year's
  reduction in 1/36 400 000 000 pence; for the default-scheme councils the
  withdrawal and the weekly applicable amount, for Oxford the band's percentage and
  the year's income in 1/1 000 000 pence (52 weeks);
* `reliefs` (area 6, `UkTax/Reliefs.lean`): one individual's income from its
  sources, `{"pay_pence", "employment_expenses_pence", "trading_profit_pence",
  "capital_allowances_pence", "losses_brought_forward_pence",
  "property_profit_pence" (before finance costs), "finance_costs_pence",
  "savings_pence", "dividends_pence", "share_gifts_pence",
  "employer_pension_contributions_pence", "unused_annual_allowance_pence"}` (each
  default 0; the top-level income fields are ignored for it, the country and Gift
  Aid fields apply). Outputs `reliefs_tax_exact_ten_thousandths_pence` (income tax
  after the finance cost reduction, with the annual allowance charge), its parts,
  the tapered annual allowance and Class 4 on the trade;
* `land_tax`: `{"tax": "sdlt" | "lbtt" | "ltt", "kind": "residential" |
  "first_time_buyer" | "additional_dwelling" | "non_residential",
  "consideration_pence": n, "non_resident": false, "lease_rents_pence": [n, ...],
  "lease_residential": false}` (`UkTax/LandTax.lean`): the tax on the consideration
  (`land_tax_exact_ten_thousandths_pence`; LBTT with first-time buyer relief and the
  additional dwelling supplement, LTT with the higher rates, SDLT with the 2 %
  non-resident surcharge), and on a lease's rent, one entry a year, by its NPV at
  3.5 %: `land_tax_rent_scaled_ten_thousandths_pence` is the tax × 207ⁿ, with the
  NPV's numerator and the denominator 207ⁿ;
* `sdlt`: `{"kind": "residential" | "first_time_buyer" | "additional_dwelling" |
  "non_residential", "consideration_pence": n}`, Stamp Duty Land Tax in England or
  Northern Ireland (`UkTax/Sdlt.lean`; output `sdlt_exact_ten_thousandths_pence`);
* `council_tax`: `{"band": "A" .. "H" (or "I" in Wales), "band_d_pence": n,
  "single_person_discount": false}` (by `country`; output `council_tax_1440ths_pence`
  for the year, `UkTax/CouncilTax.lean`);
* `council_tax_reduction` (with `pension_credit`): `{"council_tax_pence": n}` (the
  year's bill) and the household fields of `housing_benefit` (non-dependants,
  premiums, `pensionable_age_before_april_2021`); the pensioner scheme of
  `country`; outputs `council_tax_reduction_7280ths_pence` for the year (365 days)
  and the withdrawal;
* `new_state_pension`: `{"qualifying_years": n}` for someone with no qualifying
  year before 6 April 2016 (output `new_state_pension_weekly_35ths_pence`).

Benefit outputs are in 1/1 000 000 of a penny: `uc_millionths_pence`,
`tfc_millionths_pence` (Tax-Free Childcare can't be had with Universal Credit;
`net_income_millionths_pence` counts the larger), `funded_hours_millionths_pence`,
and `net_income_millionths_pence` (null unless all non-savings income is pay),
the `netAll` of `UkTax/Benefits.lean`: gross
income less income tax, NICs and HICBC, plus Child Benefit, the better of UC and
Tax-Free Childcare, and the funded hours.

Output (an array for an array input). `liability_pence` is the liability after
the Step 6 tax reductions, rounded down to the penny;
`tax_exact_ten_thousandths_pence` is the same, exact and unrounded, in units of
1/10 000 of a penny; `step5_tax_exact_ten_thousandths_pence` is the tax before
the reductions; `marriage_allowance_reduction_ten_thousandths_pence` and
`mca_reduction_ten_thousandths_pence` are the reductions before the limit of
the tax there is; `marriage_allowance_transfer_valid` says whether a transferor's
election stands.

    {"liability_pence": 748600, "tax_exact_ten_thousandths_pence": 7486000000,
     "personal_allowance_pence": 1257000,
     "savings_allowance_pence": 100000, "allowance_against_savings_pence": 0,
     "allowance_against_dividends_pence": 0,
     "nic_exact_ten_thousandths_pence": 30160000, "nic_pence": 301600,
     "hicbc_pence": 0}

`nic_pence` is rounded down to the penny for display only; payroll rounds each
period's contribution, which is not modelled. `hicbc_pence` is exact (whole
pounds, by s681C(3)).
-/

open Lean UkTax

/-- One taxpayer: income, employment earnings, pay period and Child Benefit. -/
structure Case where
  income : Income
  regime : Regime
  employment : Nat
  period : EarningsPeriod
  childBenefit : Nat
  claims : Claims
  tradeProfit : Nat := 0
  propertyProfit : Nat := 0
  zeroRated : Bool := false
  class1A : Nat := 0
  class2Weeks : Nat := 0
  class3Weeks : Nat := 0
  disability : Disability := {}
  carer : Option Nat := none
  maAwe : Option Nat := none
  jsa : Option (Bool × Nat × Nat) := none
  esa : Option (Bool × Bool × Nat) := none
  ssmgIn : Option (Bool × Nat × Nat) := none
  pc : Option PcClaim := none
  nspYears : Option Nat := none
  hb : Option HbClaim := none
  ctr : Option (Nat × HbClaim) := none
  ct : Option Nat := none
  nation : Nation := .england
  cgt : Option (Nat × Nat) := none
  sdlt : Option (SdltKind × Nat) := none
  /-- UC profit of the trade, receipts less expenses (reg 57), pence. -/
  ucProfit : Int := 0
  /-- The minimum income floor: whole pounds, the claimant's and the partner's
  expected hours. -/
  mif : Option (Bool × Nat × Nat) := none
  hbWa : Option HbWaClaim := none
  /-- Working-age CTR: the bill, the household, the band (0 = A, ..., 7 = H; 8 if not
  given) and the second adult rebate (council tax due, rate in tenths of a percent). -/
  ctrWa : Option (Nat × HbWaClaim × Nat × Option (Nat × Nat)) := none
  /-- English local working-age CTR: the council, the bill, the household and the
  children with no amount under a two-child limit. -/
  ctrLocal : Option (LocalAuthority × Nat × HbWaClaim × Nat × Nat) := none
  /-- A land transaction: the tax (0 SDLT, 1 LBTT, 2 LTT), the kind, the
  consideration, non-resident, and the lease's yearly rents with whether the land
  is residential. -/
  land : Option (Nat × LandKind × Nat × Bool × List Nat × Bool) := none
  /-- One individual's income with the area 6 reliefs. -/
  reliefs : Option ReliefsIn := none
  /-- The borrower's student loan plans (P9a). -/
  studentLoan : Option Loans := none
  /-- The Winter Fuel Payment case (P9a). -/
  wfp : Option WfpCase := none
  /-- Scottish Child Payment: children under 16, and a qualifying benefit other
  than the Universal Credit worked out here (P9b). -/
  scp : Option (Nat × Bool) := none
  /-- The parent has a qualifying benefit for the targeted 2-year-old hours other
  than the Universal Credit worked out here (P9c). -/
  targetedOther : Bool := false
  /-- A company car: list price, capital contributions, CO2, electric range,
  diesel (s141), days unavailable, payments for private use, fuel provided (P9d). -/
  car : Option (Nat × Nat × Nat × Nat × Bool × Nat × Nat × Bool) := none
  /-- The TV licence: required, blind holder, over 75 with Pension Credit (P9d). -/
  tv : Option (Bool × Bool × Bool) := none
  /-- ISAs: age, subscriptions, Lifetime ISA payments (P9e). -/
  isa : Option (Nat × Nat × Nat) := none
  /-- The minimum wage: age, apprentice (P9e). -/
  mw : Option (Nat × Bool) := none
  /-- The Warm Home Discount: in England or Wales, qualifying benefit, bill holder (P9e). -/
  whdIn : Option (Bool × Bool × Bool) := none
  /-- A car for Vehicle Excise Duty (P9f). -/
  vedCar : Option VedCar := none
  /-- Student support (P9g): schedule, category, final year, care leaver,
  residual incomes (pence), dependent children, household income given (pence),
  dependants' income for the grants (pence). -/
  sfe : Option (SfeSchedule × SfeCat × Bool × Bool × List Nat × Nat × Option Nat × Option Nat) := none
  /-- Carer Support Payment: weekly overlapping benefits and additional cared for
  people (P9b). -/
  csp : Option (Nat × Nat) := none

def parseCase (j : Json) : Except String Case := do
  let field (k : String) : Except String Nat :=
    match j.getObjValAs? Nat k with
    | .ok v => .ok v
    | .error _ => .error s!"field \"{k}\" must be a non-negative whole number of pence"
  let optField (k : String) : Except String Nat :=
    match j.getObjVal? k with
    | .ok _ => field k
    | .error _ => .ok 0
  let income : Income :=
    ⟨← field "non_savings_pence", ← field "savings_pence", ← field "dividends_pence"⟩
  let employment ← optField "employment_pence"
  if employment > income.nonSavings then
    throw "employment_pence must not exceed non_savings_pence"
  let period ← match j.getObjValAs? String "nic_earnings_period" with
    | .ok "annual" => pure EarningsPeriod.annual
    | .ok "monthly" => pure .monthly
    | .ok "weekly" => pure .weekly
    | .ok p => throw s!"nic_earnings_period must be annual, monthly or weekly, not {p}"
    | .error _ => pure .annual
  let uc ← match j.getObjVal? "uc" with
    | .ok u => do
      let couple := (u.getObjValAs? Bool "couple").toOption.getD false
      let children ← match u.getObjValAs? Nat "children" with
        | .ok n => pure n
        | .error _ => throw "uc.children must be a non-negative whole number"
      if income.savings + income.dividends > 0 || employment ≠ income.nonSavings then
        throw "uc: only pay is modelled for Universal Credit (employment_pence must equal non_savings_pence, with no savings or dividends)"
      let b (k : String) : Bool := (u.getObjValAs? Bool k).toOption.getD false
      let n (k : String) : Except String Nat :=
        match u.getObjVal? k with
        | .ok _ => match u.getObjValAs? Nat k with
          | .ok v => .ok v
          | .error _ => .error s!"uc.{k} must be a non-negative whole number"
        | .error _ => .ok 0
      let health ← match u.getObjValAs? String "health" with
        | .ok "none" => pure Health.none
        | .ok "new" => pure .newClaim
        | .ok "protected" => pure .protectedRate
        | .ok h => throw s!"uc.health must be none, new or protected, not {h}"
        | .error _ => pure .none
      let lha ← match u.getObjVal? "lha_monthly_pence" with
        | .ok _ => some <$> n "lha_monthly_pence"
        | .error _ => pure none
      let ext : Claims := {
        under25 := b "under_25", firstChildPre2017 := b "first_child_pre_2017",
        disabledLower := ← n "disabled_children_lower", disabledHigher := ← n "disabled_children_higher",
        health, carers := ← n "carers",
        ucChildcareMonthly := ← n "childcare_monthly_pence", ucChildcareChildren := ← n "childcare_children",
        housing := { rent := ← n "rent_monthly_pence", lha, spareRooms := ← n "spare_rooms",
                     nonDeps := ← n "non_dependants" },
        capital := ← n "capital_pence", unearnedMonthly := ← n "unearned_monthly_pence",
        partnerEarned := ← n "partner_earned_pence", london := b "london", capExempt := b "cap_exempt",
        cannotCare := b "cannot_provide_childcare", partnerCannotCare := b "partner_cannot_provide_childcare" }
      pure (some (couple, children, ext))
    | .error _ => pure none
  let costs ← match j.getObjValAs? (Array Nat) "childcare_costs_pence" with
    | .ok xs => pure xs.toList
    | .error _ =>
      if (j.getObjVal? "childcare_costs_pence").toOption.isSome then
        throw "childcare_costs_pence must be an array of whole numbers of pence"
      else pure []
  let ucCouple := (uc.map (·.1)).getD false
  let ext : Claims := (uc.map (·.2.2)).getD {}
  let partner ← match j.getObjVal? "partner" with
    | .ok pj => do
      if ucCouple then
        throw "partner: a UC couple where both work is not modelled (the UC couple's partner has no pay)"
      let f (k : String) : Except String Nat :=
        match pj.getObjValAs? Nat k with
        | .ok v => .ok v
        | .error _ => .error s!"partner.{k} must be a non-negative whole number of pence"
      pure (some (← f "pay_pence", ← f "adjusted_net_income_pence"))
    | .error _ => pure none
  let (england, scottish) ← match j.getObjValAs? String "country" with
    | .ok "england" => pure (true, false)
    | .ok "wales" | .ok "northern_ireland" => pure (false, false)
    | .ok "scotland" => pure (false, true)
    | .ok c => throw s!"country must be england, wales, northern_ireland or scotland, not {c}"
    | .error _ => pure (true, false)
  let netPay ← optField "net_pay_pension_pence"
  if netPay > employment then
    throw "net_pay_pension_pence must not exceed employment_pence"
  if netPay > 0 && (!costs.isEmpty || (j.getObjVal? "funded_children").toOption.isSome
      || partner.isSome) then
    throw "net_pay_pension_pence: the childcare tests with net pay contributions are not modelled"
  let blind := (j.getObjValAs? Bool "blind").toOption.getD false
  let (maTransfer, maReceive) ← match j.getObjValAs? String "marriage_allowance" with
    | .ok "transfer" => pure (true, false)
    | .ok "receive" => pure (false, true)
    | .ok m => throw s!"marriage_allowance must be transfer or receive, not {m}"
    | .error _ => pure (false, false)
  let mca := (j.getObjValAs? Bool "married_couples_allowance").toOption.getD false
  if mca && (maTransfer || maReceive) then
    throw "married_couples_allowance: no Marriage Allowance with it (ITA 2007 s55B(2)(d))"
  let relief := (← optField "gift_aid_gross_pence") + (← optField "pension_relief_at_source_gross_pence")
  if uc.isSome && relief > 0 then
    throw "uc: Gift Aid and pension contributions are not modelled with Universal Credit yet"
  let kids ← match j.getObjValAs? (Array Json) "funded_children" with
    | .ok xs => xs.toList.mapM fun k => do
      let band ← match k.getObjValAs? String "age" with
        | .ok "under_2" => pure AgeBand.under2
        | .ok "2" => pure .two
        | .ok "3_4" => pure .threeFour
        | _ => throw "funded_children: age must be \"under_2\", \"2\" or \"3_4\""
      let price ← match k.getObjVal? "price_pence_per_hour" with
        | .ok _ => match k.getObjValAs? Nat "price_pence_per_hour" with
          | .ok v => pure (some v)
          | .error _ => throw "funded_children: price_pence_per_hour must be a whole number of pence"
        | .error _ => pure none
      let targetedOwn := (k.getObjValAs? Bool "targeted_criteria").toOption.getD false
      if targetedOwn && band != .two then
        throw "funded_children: targeted_criteria is for 2-year-olds (SI 2014/2147 reg 3)"
      pure ({ band, price, targetedOwn } : FundedChild)
    | .error _ =>
      if (j.getObjVal? "funded_children").toOption.isSome then
        throw "funded_children must be an array"
      else pure []
  if (j.getObjVal? "funded_hours_value_pence").toOption.isSome then
    throw "funded_hours_value_pence is replaced by funded_children"
  let cb ← match j.getObjVal? "child_benefit_children" with
    | .ok _ => do
      if (j.getObjVal? "child_benefit_pence").toOption.isSome then
        throw "give child_benefit_children or child_benefit_pence, not both"
      pure (childBenefitFor (← field "child_benefit_children") childBenefitWeeks)
    | .error _ => optField "child_benefit_pence"
  let claims : Claims := {
    ext with
    uc := uc.isSome, couple := ucCouple || partner.isSome, ucChildren := (uc.map (·.2.1)).getD 0,
    childcareCosts := costs, partner, england, fundedChildren := kids,
    capOtherBenefits := cb }
  let tr ← optField "trading_receipts_pence"
  let te ← optField "trading_expenses_pence"
  let pr ← optField "property_receipts_pence"
  let pe ← optField "property_expenses_pence"
  let rr ← optField "rent_a_room_receipts_pence"
  let re ← optField "rent_a_room_expenses_pence"
  let shared := (j.getObjValAs? Bool "rent_a_room_shared").toOption.getD false
  let profits := tradeProfit tr te + propertyProfit shared pr pe rr re
  if tr + te + pr + pe + rr + re > 0 && (!costs.isEmpty || partner.isSome
      || (j.getObjVal? "funded_children").toOption.isSome) then
    throw "trading, property and rent-a-room income are not modelled with the childcare tests yet"
  if pr + pe + rr + re > 0 && uc.isSome then
    throw "property and rent-a-room income are not modelled with Universal Credit yet"
  let mif ← match (j.getObjVal? "uc").toOption.bind (fun u => (u.getObjVal? "minimum_income_floor").toOption) with
    | some m => do
      let h (k : String) : Except String Nat :=
        match m.getObjVal? k with
        | .ok _ => match m.getObjValAs? Nat k with
          | .ok v => .ok v
          | .error _ => .error s!"uc.minimum_income_floor.{k} must be a whole number of hours"
        | .error _ => .ok 35
      pure (some ((m.getObjValAs? Bool "whole_pounds").toOption.getD true, ← h "expected_hours",
        ← h "partner_expected_hours"))
    | none => pure none
  let income : Income :=
    { income with nonSavings := income.nonSavings - netPay + profits }
  let rg : Regime := { scottish, relief, netPay, blind, maTransfer, maReceive, mca }
  let obj (k : String) : Option Json := (j.getObjVal? k).toOption
  let sub (o : Json) (k : String) : Except String Nat :=
    match o.getObjVal? k with
    | .ok _ => match o.getObjValAs? Nat k with
      | .ok v => .ok v
      | .error _ => .error s!"{k} must be a non-negative whole number"
    | .error _ => .ok 0
  let subB (o : Json) (k : String) : Bool := (o.getObjValAs? Bool k).toOption.getD false
  let disability ← match obj "disability" with
    | some o => do
      let pipR (k : String) : Except String PipRate := match o.getObjValAs? String k with
        | .ok "standard" => pure .standard | .ok "enhanced" => pure .enhanced
        | .ok "none" => pure .none | .error _ => pure .none
        | .ok v => throw s!"disability.{k} must be none, standard or enhanced, not {v}"
      let care ← match o.getObjValAs? String "dla_care" with
        | .ok "lowest" => pure DlaCare.lowest | .ok "middle" => pure .middle
        | .ok "highest" => pure .highest | .ok "none" => pure .none | .error _ => pure .none
        | .ok v => throw s!"disability.dla_care must be none, lowest, middle or highest, not {v}"
      let mob ← match o.getObjValAs? String "dla_mobility" with
        | .ok "lower" => pure DlaMobility.lower | .ok "higher" => pure .higher
        | .ok "none" => pure .none | .error _ => pure .none
        | .ok v => throw s!"disability.dla_mobility must be none, lower or higher, not {v}"
      let aa ← match o.getObjValAs? String "attendance_allowance" with
        | .ok "lower" => pure AaRate.lower | .ok "higher" => pure .higher
        | .ok "none" => pure .none | .error _ => pure .none
        | .ok v => throw s!"disability.attendance_allowance must be none, lower or higher, not {v}"
      pure ({ pipDaily := ← pipR "pip_daily_living", pipMobility := ← pipR "pip_mobility",
              dlaCare := care, dlaMobility := mob, aa } : Disability)
    | none => pure {}
  let carer ← match obj "carers_allowance" with
    | some o => do
      if income.savings + income.dividends > 0 || employment - netPay ≠ income.nonSavings then
        throw "carers_allowance: only pay is modelled (employment_pence must equal non_savings_pence, with no savings or dividends)"
      if relief > 0 || tr + te + pr + pe + rr + re > 0 then
        throw "carers_allowance: not modelled with Gift Aid, relief at source, or trading and property income"
      if uc.isSome && ext.carers = 0 then
        throw "carers_allowance with uc: a carer meeting the Carer's Allowance conditions has the carer element (SI 2013/376 reg 30(1)(a)); set uc.carers to at least 1"
      if uc.isSome && (!costs.isEmpty || (j.getObjVal? "funded_children").toOption.isSome || partner.isSome) then
        throw "carers_allowance with uc: the childcare tests (childcare_costs_pence, funded_children, partner) are not modelled with it"
      pure (some (← sub o "overlapping_weekly_pence"))
    | none => pure none
  let maAwe ← match obj "maternity_allowance" with
    | some o => pure (some (← sub o "average_weekly_earnings_pence"))
    | none => pure none
  let jsa ← match obj "jsa_contrib" with
    | some o => pure (some (subB o "under_25", ← sub o "earnings_weekly_pence", ← sub o "pension_weekly_pence"))
    | none => pure none
  let esa ← match obj "esa_contrib" with
    | some o => pure (some (subB o "assessment_under_25", subB o "support_group", ← sub o "pension_weekly_pence"))
    | none => pure none
  let ssmgIn ← match obj "ssmg" with
    | some o => do
      let babies ← if (o.getObjVal? "babies").toOption.isSome then sub o "babies" else pure 1
      let existing ← sub o "existing_children_under_16"
      if existing > 0 && babies > 1 then
        throw "ssmg: a multiple birth with existing children under 16 (reg 5A(5)-(7)) is not modelled"
      pure (some (subB o "qualifying_benefit", existing, babies))
    | none => pure none
  let pc ← match obj "pension_credit" with
    | some o => do
      let pcl : PcClaim := {
        couple := subB o "couple", savingsCredit := subB o "savings_credit",
        severeDisability := ← sub o "severe_disability", carers := ← sub o "carers",
        children := ← sub o "children", firstChildPre2017 := subB o "first_child_pre_2017",
        disabledChildrenLower := ← sub o "disabled_children_lower",
        disabledChildrenHigher := ← sub o "disabled_children_higher",
        higherDisregard := subB o "higher_earnings_disregard",
        statePension := ← sub o "state_pension_pence", otherPension := ← sub o "other_pension_pence",
        otherIncome := ← sub o "other_income_pence", excludedIncome := ← sub o "excluded_income_pence",
        earnings := ← sub o "net_earnings_pence", capital := ← sub o "capital_pence" }
      -- reg 17(10)(a): the income tax on the income counted. For a single claimant
      -- the model's own liability on it, all non-savings income, unless given; a
      -- couple's is per person, so it must be given.
      let given := (o.getObjVal? "income_tax_pence").toOption.isSome
      if pcl.couple && !given && pcl.statePension + pcl.otherPension + pcl.otherIncome
          + pcl.excludedIncome + pcl.earnings > 0 then
        throw "pension_credit: a couple's income_tax_pence must be given (each partner's tax on their income)"
      let tax ← if given then sub o "income_tax_pence" else
        pure (finalLiability ({ scottish } : Regime)
          ⟨pcl.statePension + pcl.otherPension + pcl.otherIncome + pcl.excludedIncome + pcl.earnings, 0, 0⟩)
      let pcl := { pcl with incomeTax := tax }
      if pcl.severeDisability > 2 || pcl.carers > 2 then
        throw "pension_credit: severe_disability and carers must be 0, 1 or 2"
      pure (some pcl)
    | none => pure none
  let parseHb (o : Json) : Except String HbClaim := do
    let lha ← match o.getObjVal? "lha_weekly_pence" with
      | .ok _ => some <$> sub o "lha_weekly_pence"
      | .error _ => pure none
    let nds ← match o.getObjValAs? (Array Json) "non_dependants" with
      | .ok xs => xs.toList.mapM fun n => do
          let g ← sub n "gross_weekly_pence"
          pure ({ working := subB n "working", grossWeekly := g } : NonDep)
      | .error _ => pure []
    let rent ← sub o "rent_weekly_pence"
    let sd ← sub o "severe_disability"
    let edc ← sub o "enhanced_disability_children"
    let dc ← sub o "disabled_children"
    let cr ← sub o "carers"
    pure {
      rent := rent, lha := lha, nonDeps := nds, nonDepExempt := subB o "non_dependant_exempt",
      oldRates := subB o "pensionable_age_before_april_2021", lone := subB o "lone_parent",
      familyPremium := subB o "family_premium", severeDisability := sd,
      enhancedDisabilityChildren := edc, disabledChildren := dc, carers := cr }
  let hb ← match obj "housing_benefit" with
    | some o => do
      if pc.isNone then
        throw "housing_benefit: give the household's income as pension_credit (HB(SPC), for pensioners)"
      pure (some (← parseHb o))
    | none => pure none
  let parseHbWa (k : String) (o : Json) : Except String HbWaClaim := do
    if income.savings + income.dividends > 0 || employment - netPay ≠ income.nonSavings then
      throw s!"{k}: only pay is modelled (employment_pence must equal non_savings_pence, with no savings or dividends)"
    if pc.isSome then
      throw s!"{k}: not with pension_credit (pensioners have housing_benefit)"
    let h ← parseHb o
    let couple := subB o "couple"
    let lone := subB o "lone_parent"
    let children ← sub o "children"
    if couple && lone then throw s!"{k}: couple and lone_parent together"
    let esa ← match o.getObjValAs? String "esa_component" with
      | .ok "none" | .error _ => pure EsaComponent.none
      | .ok "support" => pure .support
      | .ok "wra" => pure .wra
      | .ok v => throw s!"{k}.esa_component must be none, support or wra, not {v}"
    let dis ← match o.getObjValAs? String "disregard" with
      | .ok "single" => pure HbWaDisregard.single
      | .ok "couple" => pure .couple
      | .ok "higher" => pure .higher
      | .ok "lone_parent" => pure .loneParent
      | .ok v => throw s!"{k}.disregard must be single, couple, higher or lone_parent, not {v}"
      | .error _ => pure (if lone then .loneParent else if couple then .couple else .single)
    let acc ← match o.getObjValAs? String "accommodation" with
      | .ok "specified" | .error _ => pure HbWaAccommodation.specified
      | .ok "temporary" => pure .temporary
      | .ok "general" => pure .general
      | .ok v => throw s!"{k}.accommodation must be specified, temporary or general, not {v}"
    let capOther ← sub o "cap_other_weekly_pence"
    let other ← sub o "other_weekly_pence"
    let cap ← sub o "capital_pence"
    pure ({
      housing := h, couple, lone, under25 := subB o "under_25", children,
      familyPremium := h.familyPremium, disability := subB o "disability_premium",
      enhancedDisability := subB o "enhanced_disability_premium",
      severeDisability := h.severeDisability, enhancedDisabilityChildren := h.enhancedDisabilityChildren,
      disabledChildren := h.disabledChildren, carers := h.carers, esa, disregard := dis,
      additionalDisregard := subB o "additional_disregard", passported := subB o "passported",
      otherWeekly := other, capital := cap,
      accommodation := acc, esaSaved := subB o "esa_saved", capExempt := subB o "cap_exempt",
      london := subB o "london", capOtherWeekly := capOther } : HbWaClaim)
  let hbWa ← match obj "housing_benefit_working_age" with
    | some o => some <$> parseHbWa "housing_benefit_working_age" o
    | none => pure none
  let ctrWa ← match obj "council_tax_reduction_working_age" with
    | some o => do
      let wales := (j.getObjValAs? String "country").toOption.any (· == "wales")
      if !wales && !scottish then
        throw "council_tax_reduction_working_age: the national schemes of Wales and Scotland (country wales or scotland)"
      let band ← match o.getObjValAs? String "band" with
        | .ok b => match ["A", "B", "C", "D", "E", "F", "G", "H"].idxOf? b with
          | some i => pure i
          | none => throw "council_tax_reduction_working_age.band must be A to H"
        | .error _ => pure 8
      let sar ← match o.getObjVal? "second_adult" with
        | .ok so => do
          if !scottish then throw "council_tax_reduction_working_age.second_adult: Scotland only"
          pure (some (← sub so "council_tax_pence",
            scotSarRate (subB so "on_benefit") (subB so "students") (← sub so "gross_weekly_pence")))
        | .error _ => pure none
      pure (some (← sub o "council_tax_pence", ← parseHbWa "council_tax_reduction_working_age" o, band, sar))
    | none => pure none
  let ctrLocal ← match obj "council_tax_reduction_local" with
    | some o => do
      if !england then throw "council_tax_reduction_local: the English councils' schemes (country england)"
      let la ← match o.getObjValAs? String "authority" with
        | .ok "kingston_upon_thames" => pure LocalAuthority.kingston
        | .ok "merton" => pure .merton
        | .ok "newham" => pure .newham
        | .ok "westminster" => pure .westminster
        | .ok "oxford" => pure .oxford
        | _ => throw "council_tax_reduction_local.authority must be kingston_upon_thames, merton, newham, westminster or oxford"
      let h ← parseHbWa "council_tax_reduction_local" o
      if h.familyPremium || h.disability || h.enhancedDisability || h.severeDisability > 0
          || h.enhancedDisabilityChildren > 0 || h.disabledChildren > 0 || h.carers > 0 || h.esa != .none then
        throw "council_tax_reduction_local: premiums and components are not modelled for the local schemes"
      pure (some (la, ← sub o "council_tax_pence", h, ← sub o "limited_children",
        childBenefitFor (← sub o "child_benefit_children") 1))
    | none => pure none
  let land ← match obj "land_tax" with
    | some o => do
      let tax ← match o.getObjValAs? String "tax" with
        | .ok "sdlt" => pure 0
        | .ok "lbtt" => pure 1
        | .ok "ltt" => pure 2
        | _ => throw "land_tax.tax must be sdlt, lbtt or ltt"
      let kind ← match o.getObjValAs? String "kind" with
        | .ok "residential" | .error _ => pure LandKind.residential
        | .ok "first_time_buyer" => pure .firstTime
        | .ok "additional_dwelling" => pure .additional
        | .ok "non_residential" => pure .nonResidential
        | .ok v => throw s!"land_tax.kind must be residential, first_time_buyer, additional_dwelling or non_residential, not {v}"
      let nr := (o.getObjValAs? Bool "non_resident").toOption.getD false
      if nr && tax ≠ 0 then throw "land_tax.non_resident: the 2 % surcharge is SDLT's (FA 2003 s75ZA)"
      let rents ← match o.getObjValAs? (List Nat) "lease_rents_pence" with
        | .ok rs => pure rs
        | .error _ => do
          if (o.getObjVal? "lease_rents_pence").toOption.isSome then
            throw "land_tax.lease_rents_pence must be a list of whole pence, one a year"
          pure []
      pure (some (tax, kind, ← sub o "consideration_pence", nr, rents,
        (o.getObjValAs? Bool "lease_residential").toOption.getD false))
    | none => pure none
  let reliefs ← match obj "reliefs" with
    | some o => do
      let r : ReliefsIn := {
        pay := ← sub o "pay_pence", employmentExpenses := ← sub o "employment_expenses_pence",
        trade := ← sub o "trading_profit_pence", capitalAllowances := ← sub o "capital_allowances_pence",
        lossesBroughtForward := ← sub o "losses_brought_forward_pence",
        property := ← sub o "property_profit_pence", financeCosts := ← sub o "finance_costs_pence",
        savings := ← sub o "savings_pence", dividends := ← sub o "dividends_pence",
        shareGifts := ← sub o "share_gifts_pence", pensionInput := ← sub o "employer_pension_contributions_pence",
        unusedAllowance := ← sub o "unused_annual_allowance_pence" }
      if r.capitalAllowances > r.trade then
        throw "reliefs: capital allowances above the trading profit would make a loss, which is not modelled"
      if maTransfer || maReceive || mca then
        throw "reliefs: not with the marriage allowance or the married couple's allowance"
      pure (some r)
    | none => pure none
  let studentLoan ← match obj "student_loan" with
    | some o => do
      let plans ← match o.getObjValAs? (List String) "plans" with
        | .ok ps => pure ps
        | .error _ => throw "student_loan.plans must be a list of plan_1, plan_2, plan_4, plan_5 and postgraduate"
      for q in plans do
        if !["plan_1", "plan_2", "plan_4", "plan_5", "postgraduate"].contains q then
          throw s!"student_loan.plans: unknown plan {q}"
      let has (q : String) : Bool := plans.contains q
      let lo : Loans := { plan1 := has "plan_1", plan2 := has "plan_2", plan4 := has "plan_4",
                          plan5 := has "plan_5", postgraduate := has "postgraduate" }
      pure (some lo)
    | none => pure none
  let wfp ← match obj "winter_fuel_payment" with
    | some o => do
      let w : WfpCase := { over80 := subB o "over_80", relevantBenefit := subB o "relevant_benefit",
                           partnerOver80 := subB o "partner_over_80",
                           withEntitledUnder80 := subB o "with_entitled_under_80",
                           withEntitled80 := subB o "with_entitled_80", residentialCare := subB o "residential_care",
                           partnerPaidBenefit := subB o "partner_paid_benefit" }
      pure (some w)
    | none => pure none
  let scp ← match obj "scottish_child_payment" with
    | some o => do
      if !scottish then throw "scottish_child_payment: Scotland only (country \"scotland\")"
      pure (some (← sub o "children_under_16", subB o "other_qualifying_benefit"))
    | none => pure none
  let csp ← match obj "carer_support_payment" with
    | some o => do
      if !scottish then throw "carer_support_payment: Scotland only (country \"scotland\")"
      if income.savings + income.dividends > 0 || employment - netPay ≠ income.nonSavings then
        throw "carer_support_payment: only pay is modelled (employment_pence must equal non_savings_pence, with no savings or dividends)"
      if relief > 0 || tr + te + pr + pe + rr + re > 0 then
        throw "carer_support_payment: not modelled with Gift Aid, relief at source, or trading and property income"
      pure (some (← sub o "overlapping_weekly_pence", ← sub o "additional_cared_for"))
    | none => pure none
  let car ← match obj "company_car" with
    | some o => do
      let u ← sub o "days_unavailable"
      if u > taxYearDays then throw "company_car.days_unavailable: at most 365 in 2026-27"
      pure (some (← sub o "list_price_pence", ← sub o "capital_contributions_pence", ← sub o "co2_g_km",
        ← sub o "electric_range_miles", subB o "diesel_non_euro_6d", u, ← sub o "private_use_payments_pence",
        subB o "fuel_provided"))
    | none => pure none
  let tv ← match obj "tv_licence" with
    | some o => pure (some ((o.getObjValAs? Bool "required").toOption.getD true, subB o "blind",
        subB o "over_75_with_pension_credit"))
    | none => pure none
  let isa ← match obj "isa" with
    | some o => pure (some (← sub o "age", ← sub o "subscriptions_pence", ← sub o "lifetime_isa_payments_pence"))
    | none => pure none
  let mw ← match obj "minimum_wage" with
    | some o => pure (some (← sub o "age", subB o "apprentice"))
    | none => pure none
  let whdIn ← match obj "warm_home_discount" with
    | some o => pure (some (england || (j.getObjValAs? String "country").toOption == some "wales",
        subB o "qualifying_benefit", (o.getObjValAs? Bool "bill_holder").toOption.getD true))
    | none => pure none
  let vedCar ← match obj "vehicle_excise_duty" with
    | some o => match o.getObjValAs? String "registered" with
      | .ok "from_april_2017" => pure (some (VedCar.modern (← sub o "co2_g_km") (subB o "diesel_non_rde2")
          (subB o "zero_emission") (subB o "registered_before_april_2025") (← sub o "list_price_pence")
          (← sub o "licence_year")))
      | .ok "march_2001_to_march_2017" => pure (some (VedCar.graduated (← sub o "co2_g_km")
          (subB o "registered_before_23_march_2006")))
      | .ok "before_march_2001" => pure (some (VedCar.old (subB o "engine_over_1549cc")))
      | _ => throw "vehicle_excise_duty.registered must be from_april_2017, march_2001_to_march_2017 or before_march_2001"
    | none => pure none
  let sfe ← match obj "student_support" with
    | some o => do
      let sched ← match (o.getObjValAs? String "schedule").toOption.getD "standard" with
        | "standard" => pure SfeSchedule.standard
        | "benefits" => pure SfeSchedule.benefits
        | "over_60" => pure SfeSchedule.over60
        | _ => throw "student_support.schedule must be standard, benefits or over_60"
      let cat ← match (o.getObjValAs? String "category").toOption.getD "D" with
        | "A" => pure SfeCat.a
        | "B" => pure SfeCat.b
        | "C" => pure SfeCat.c
        | "D" => pure SfeCat.d
        | _ => throw "student_support.category must be A, B, C or D"
      let person (p : Json) : Except String Nat := do
        pure (residualIncome (← sub p "taxable_income_pence") (← sub p "pension_contributions_pence")
          (← sub p "term_time_earnings_pence") (subB p "student_or_award_holder"))
      let people := match o.getObjValAs? (Array Json) "residual_incomes" with
        | .ok a => a.toList
        | .error _ => []
      let rs ← people.mapM person
      let opt (k : String) : Except String (Option Nat) :=
        match o.getObjVal? k with
        | .ok _ => do pure (some (← sub o k))
        | .error _ => pure none
      pure (some (sched, cat, subB o "final_year", subB o "care_leaver", rs, ← sub o "dependent_children",
        ← opt "household_income_pence", ← opt "dependants_income_pence"))
    | none => pure none
  let nation : Nation := if scottish then .scotland else if england then .england else .wales
  let ctr ← match obj "council_tax_reduction" with
    | some o => do
      if pc.isNone then
        throw "council_tax_reduction: give the household's income as pension_credit (the pensioner schemes)"
      if !england && !scottish && (j.getObjValAs? String "country").toOption != some "wales" then
        throw "council_tax_reduction: Northern Ireland has rates, not council tax"
      pure (some (← sub o "council_tax_pence", ← parseHb o))
    | none => pure none
  let cgtIn ← match (j.getObjVal? "capital_gains_pence").toOption, (j.getObjVal? "badr_gains_pence").toOption with
    | none, none => pure none
    | _, _ => do
      pure (some (← optField "badr_gains_pence", ← optField "capital_gains_pence"))
  let sdlt ← match obj "sdlt" with
    | some o => do
      if scottish || !england && (j.getObjValAs? String "country").toOption == some "wales" then
        throw "sdlt: Scotland has LBTT and Wales LTT, not modelled yet"
      let kind ← match o.getObjValAs? String "kind" with
        | .ok "residential" => pure SdltKind.residential
        | .ok "first_time_buyer" => pure .firstTime
        | .ok "additional_dwelling" => pure .additional
        | .ok "non_residential" => pure .nonResidential
        | _ => throw "sdlt.kind must be residential, first_time_buyer, additional_dwelling or non_residential"
      pure (some (kind, ← sub o "consideration_pence"))
    | none => pure none
  let ct ← match obj "council_tax" with
    | some o => do
      let band ← match o.getObjValAs? String "band" with
        | .ok b => match ["A", "B", "C", "D", "E", "F", "G", "H", "I"].idxOf? b with
          | some i => if i = 8 && nation != .wales then throw "council_tax: band I is only in Wales" else pure i
          | none => throw "council_tax: band must be A to I"
        | .error _ => throw "council_tax: band is required"
      pure (some (councilTax nation band (← sub o "band_d_pence") (subB o "single_person_discount")))
    | none => pure none
  let nspYears ← match obj "new_state_pension" with
    | some o => pure (some (← sub o "qualifying_years"))
    | none => pure none
  let c1 ← optField "class_1a_benefits_pence"
  let c2 ← optField "class_2_voluntary_weeks"
  let c3 ← optField "class_3_weeks"
  let res : Case := {
    income := income, regime := income.settle rg, employment := employment - netPay,
    period := period, childBenefit := cb, claims := claims,
    tradeProfit := tradeProfit tr te, propertyProfit := propertyProfit shared pr pe rr re,
    zeroRated := (j.getObjValAs? Bool "employer_zero_rated").toOption.getD false,
    class1A := c1, class2Weeks := c2,
    class3Weeks := c3, disability := disability, carer := carer,
    maAwe := maAwe, jsa := jsa, esa := esa, ssmgIn := ssmgIn, pc := pc, nspYears := nspYears, hb := hb,
    ctr := ctr, ct := ct, nation := nation, cgt := cgtIn, sdlt := sdlt,
    ucProfit := (tr : Int) - te, mif := mif, hbWa := hbWa, ctrWa := ctrWa, ctrLocal := ctrLocal, land := land, reliefs := reliefs,
    studentLoan := studentLoan, wfp := wfp, scp := scp, csp := csp,
    targetedOther := (j.getObjValAs? Bool "targeted_other_benefit").toOption.getD false,
    car := car, tv := tv, isa := isa, mw := mw, whdIn := whdIn, vedCar := vedCar, sfe := sfe }
  return res

def result (c : Case) : Json :=
  let i := c.income
  let rg := c.regime
  let a := i.bestAlloc rg
  let nic := nicExact c.period (c.employment + rg.netPay)
  let ani := i.ani rg
  -- Carer's Allowance is unearned income for UC (reg 66(1)(b)(iii))
  let claims := match c.carer with
    | some ov => if c.claims.uc then c.claims.withCa (caYear true ov (caEarnings c.period rg c.employment))
                 else c.claims
    | none => c.claims
  -- earned income for UC: pay, plus self-employed earnings (reg 57) with a trade
  let ucEarned := if c.ucProfit ≠ 0 || c.tradeProfit > 0 then
      earnedWithTrade c.period rg c.employment c.tradeProfit c.ucProfit
    else earned c.period rg i.savings i.dividends c.employment
  -- the minimum income floor (reg 62): a lower bound on the claimant's earned income
  let mifF : Option Int := c.mif.map fun (w, h, _) => mifNetYear rg.scottish w h
  let floor : Option Int := c.mif.map fun (w, h, ph) =>
    let F := mifNetYear rg.scottish w h
    if c.claims.couple then
      min F (F + mifNetYear rg.scottish w ph - 10_000 * (c.claims.partnerEarned : Int))
    else F
  [
    ("liability_pence", toJson (finalLiability rg i)),
    ("tax_exact_ten_thousandths_pence", toJson (finalTaxExact rg i)),
    ("step5_tax_exact_ten_thousandths_pence", toJson (taxExact rg i)),
    ("marriage_allowance_reduction_ten_thousandths_pence", toJson (i.maReduction rg)),
    ("mca_reduction_ten_thousandths_pence", toJson (i.mcaReduction rg)),
    ("marriage_allowance_transfer_valid", toJson rg.maTransfer),
    ("adjusted_net_income_pence", toJson ani),
    ("personal_allowance_pence", toJson (i.personalAllowance rg)),
    ("savings_allowance_pence", toJson (savingsAllowanceFor rg (i.total - i.allowanceUsed rg))),
    ("trading_profit_pence", toJson c.tradeProfit),
    ("property_profit_pence", toJson c.propertyProfit),
    ("step3_income_pence", toJson (i.total - i.allowanceUsed rg)),
    ("allowance_against_savings_pence", toJson a.toSavings),
    ("allowance_against_dividends_pence", toJson a.toDividends),
    ("nic_exact_ten_thousandths_pence", toJson nic),
    ("nic_pence", toJson (nic / 10_000)),
    ("employer_nic_exact_ten_thousandths_pence",
      toJson (employerNicExact c.period c.zeroRated (c.employment + rg.netPay))),
    ("class_1a_exact_ten_thousandths_pence", toJson (class1AExact c.class1A)),
    ("class_4_exact_ten_thousandths_pence",
      toJson (class4Exact c.period (c.employment + rg.netPay) c.tradeProfit)),
    ("class_2_treated_paid", toJson (class2TreatedPaid c.tradeProfit)),
    ("class_2_voluntary_pence", toJson (class2Voluntary c.tradeProfit c.class2Weeks)),
    ("class_3_pence", toJson (class3 c.class3Weeks)),
    ("hicbc_pence", toJson (hicbc ani c.childBenefit)),
    ("uc_millionths_pence",
      toJson (match floor with
        | some f => ucAwardFloor claims f ucEarned
        | none => ucAward claims ucEarned)),
    ("uc_earned_income_ten_thousandths_pence", toJson ucEarned),
    ("uc_minimum_income_floor_ten_thousandths_pence", toJson mifF),
    ("tfc_millionths_pence", toJson (tfcTopUp c.claims c.employment ani)),
    ("funded_hours_millionths_pence", toJson (fundedHours c.claims c.employment ani)),
    ("childcare_eligible", toJson (childcareEligible c.claims c.employment ani)),
    ("funded_hours_targeted_millionths_pence",
      let award : Int := match floor with
        | some f => ucAwardFloor claims f ucEarned
        | none => ucAward claims ucEarned
      let e := ucEarned + (if c.claims.couple then 10_000 * (c.claims.partnerEarned : Int) else 0)
      toJson (micro * (targetedExtra c.claims (targetedFamily (c.claims.uc && decide (0 < award)) e c.targetedOther)
        (childcareEligible c.claims c.employment ani) : Nat))),
    -- `netAll` takes all non-savings income as pay
    ("net_income_millionths_pence",
      if c.employment = i.nonSavings && (c.carer.isNone || !c.claims.uc) then
        toJson (netAll c.period c.childBenefit rg c.claims i.savings i.dividends c.employment)
      else Json.null),
    ("child_benefit_pence", toJson c.childBenefit),
    ("disability_benefits_weekly_pence", toJson c.disability.weekly),
    ("disability_benefits_pence", toJson c.disability.year)]
    ++ (match c.carer with
      | some ov => [
        ("carers_allowance_pence", toJson (caYear true ov (caEarnings c.period rg c.employment))),
        ("carers_allowance_weekly_net_earnings_pence",
          toJson (caWeeklyEarnings (caEarnings c.period rg c.employment))),
        ("net_income_carer_ten_thousandths_pence",
          toJson (netCarer c.period c.childBenefit rg true ov 0 0 c.employment))]
        ++ (if c.claims.uc then
          [("net_income_carer_uc_millionths_pence",
            toJson (netCarerUc c.period c.childBenefit rg c.claims true ov c.employment))]
          else [])
      | none => [])
    ++ (match c.maAwe with
      | some a => [("maternity_allowance_weekly_tenths_pence", toJson (maWeeklyTenths a))]
      | none => [])
    ++ (match c.jsa with
      | some (u, e, pn) => [("jsa_contrib_weekly_pence", toJson (jsaWeekly u e pn))]
      | none => [])
    ++ (match c.esa with
      | some (a, sp, pn) => [("esa_contrib_weekly_tenths_pence", toJson (esaWeeklyTenths a sp pn))]
      | none => [])
    ++ (match c.ssmgIn with
      | some (q, ex, b) => [("ssmg_pence", toJson (ssmg q ex b))]
      | none => [])
    ++ (match c.pc with
      | some pc => [
        ("pension_credit_tenths_pence", toJson (pensionCredit pc)),
        ("guarantee_credit_tenths_pence", toJson (guaranteeCredit pc.mg pc.income)),
        ("pension_credit_income_tenths_pence", toJson pc.income),
        ("minimum_guarantee_weekly_pence", toJson pc.mg)]
      | none => [])
    ++ (match c.hb, c.pc with
      | some h, some pc => [
        ("housing_benefit_twentieths_pence", toJson (housingBenefit h pc)),
        ("housing_benefit_maximum_weekly_pence", toJson h.maximum),
        ("housing_benefit_applicable_amount_weekly_pence", toJson (h.applicable pc))]
      | _, _ => [])
    ++ (match c.ctr, c.pc with
      | some (ctAmt, h), some pc => [
        ("council_tax_reduction_7280ths_pence", toJson (councilTaxReduction c.nation ctAmt h pc)),
        ("council_tax_reduction_withdrawal_7280ths_pence",
          toJson (match ctrIncome h pc with
            | some i => ctrWithdrawal (ctrNonDeps c.nation h) (ctrApplicable c.nation h pc) i
            | none => 7_280 * ctAmt))]
      | _, _ => [])
    ++ (match c.cgt with
      | some (b, o) => [("cgt_exact_ten_thousandths_pence", toJson (cgtExact (i.cgtBand rg) b o))]
      | none => [])
    ++ (match c.hbWa with
      | some h => [
        ("housing_benefit_wa_rate_before_millionths_pence",
          toJson (hbWaRateBefore h (hbWaEarnings c.period rg c.employment))),
        ("housing_benefit_wa_rate_from_october_millionths_pence",
          toJson (hbWaRateAfter h (hbWaEarnings c.period rg c.employment))),
        ("housing_benefit_wa_payable_728_millionths_pence",
          toJson (hbWaPayable h (hbWaEarnings c.period rg c.employment))),
        ("housing_benefit_wa_uncapped_before_millionths_pence",
          toJson (hbWaRateUncapped h h.disregard.weekly (hbWaEarnings c.period rg c.employment))),
        ("housing_benefit_wa_uncapped_from_october_millionths_pence",
          toJson (hbWaRateUncapped h (h.disregard.weekly
            + if h.specifiedOrTemporary && decide (0 < hbWaEarnings c.period rg c.employment)
              then h.specifiedDisregard else 0) (hbWaEarnings c.period rg c.employment))),
        ("housing_benefit_wa_cap_weekly_pence", toJson h.capWeekly),
        ("housing_benefit_wa_applicable_weekly_pence", toJson h.applicable),
        ("housing_benefit_wa_maximum_weekly_pence", toJson h.housing.maximum)]
      | none => [])
    ++ (match c.ctrWa with
      | some (ct, h, band, sar) =>
        let onUc := claims.uc && decide (0 < ucAward claims ucEarned)
        let scot := c.nation == .scotland
        let nd := ctrNonDeps (if scot then .scotland else .wales) h.housing
        let E := hbWaEarnings c.period rg c.employment
        let x : Int := if scot then
            (if onUc then scotUcExcess claims h.disregard.weekly h.scotApplicable ucEarned else scotOwnExcess h E)
          else (if onUc then walesUcExcess claims ucEarned else walesOwnExcess h E)
        let passported := h.passported && !onUc
        let xEff : Int := if passported then 0 else x
        let capOk := onUc || !(h.capital > hbCapitalLimit)
        let main : Int := if capOk then ctrWaYear ct nd xEff else 0
        [("council_tax_reduction_wa_364m_pence", toJson main),
         ("council_tax_reduction_wa_withdrawal_364m_pence",
           if capOk then toJson (ctrWaWithdrawal nd xEff) else Json.null),
         ("council_tax_reduction_wa_applicable_weekly_pence",
           toJson (if scot then h.scotApplicable else h.walesApplicable))]
        ++ (if scot then
              let sarV : Int := if passported then 0 else (sar.map fun (g, r) => scotSar g r).getD 0
              let bands := if passported then 0
                else scotBandsEH band ct nd h.scotApplicable h.scotBandsThreshold xEff
              [("council_tax_reduction_wa_second_adult_364m_pence", toJson sarV),
               ("council_tax_reduction_wa_bands_e_h_su_pence", toJson (if capOk then bands else 0)),
               ("council_tax_reduction_wa_total_su_pence", toJson (scotTotal capOk main sarV bands))]
            else [])
      | none => [])
    ++ (match c.ctrLocal with
      | some (la, ct, h, limited, cb) =>
        let s := la.scheme
        let onUc := claims.uc && decide (0 < ucAward claims ucEarned)
        let nd := s.nonDepTotal h.housing
        let E := hbWaEarnings c.period rg c.employment
        let passported := h.passported && !onUc
        let capOk := la == .oxford && onUc || !(h.capital > s.capitalLimit)
        if la == .oxford then
          let x : Int := if passported then 0 else if onUc then oxfordUcIncome claims cb ucEarned else oxfordOwnIncome h E
          [("council_tax_reduction_local_lcu_pence", toJson (if capOk then oxfordYear ct nd x else 0)),
           ("council_tax_reduction_local_uc_route", toJson onUc),
           ("council_tax_reduction_local_oxford_percent", toJson (oxfordPct x)),
           ("council_tax_reduction_local_income_millionths_pence", toJson x)]
        else
          let x : Int := if passported then 0 else if onUc then walesUcExcess claims ucEarned
            else localOwnExcess s h limited E
          [("council_tax_reduction_local_lcu_pence", toJson (if capOk then localYear s ct nd x else 0)),
           ("council_tax_reduction_local_uc_route", toJson onUc),
           ("council_tax_reduction_local_withdrawal_lcu_pence",
             if capOk then toJson (localWithdrawal s nd x) else Json.null),
           ("council_tax_reduction_local_applicable_weekly_pence", toJson (s.applicable h limited))]
      | none => [])
    ++ (match c.reliefs with
      | some r =>
        let t := finalTaxExact (r.regime rg) r.income
        [("reliefs_tax_exact_ten_thousandths_pence", toJson (r.tax rg)),
         ("reliefs_tax_before_reductions_ten_thousandths_pence", toJson t),
         ("reliefs_finance_reduction_ten_thousandths_pence", toJson (r.financeReduction rg t)),
         ("reliefs_annual_allowance_pence", toJson r.allowance),
         ("reliefs_chargeable_amount_pence", toJson r.chargeable),
         ("reliefs_aa_charge_ten_thousandths_pence", toJson (aaCharge (r.regime rg) r.income r.chargeable)),
         ("reliefs_net_income_pence", toJson r.netIncome),
         ("reliefs_class_4_exact_ten_thousandths_pence", toJson (class4Exact c.period r.pay r.tradeProfit))]
      | none => [])
    ++ (match c.studentLoan with
      | some l =>
        -- unearned income (reg 29(5)): property profits, savings and dividends
        let unearned := c.propertyProfit + i.savings + i.dividends
        let earned := i.nonSavings - c.propertyProfit
        [("student_loan_repayment_ten_thousandths_pence", toJson (slRepayment l earned unearned)),
         ("student_loan_income_pence", toJson (slIncome earned unearned))]
      | none => [])
    ++ (match c.wfp with
      | some w =>
        let total := i.nonSavings + i.savings + i.dividends
        -- Scotland pays the Pension Age Winter Heating Payment (SSI 2024/351);
        -- s681I(6)(a) charges either
        let pay := if rg.scottish then pawhpAmount w else wfpAmount w
        [(if rg.scottish then "pension_age_winter_heating_payment_pence" else "winter_fuel_payment_pence", toJson pay),
         ("winter_fuel_payment_charge_pence", toJson (wfpCharge total pay w.relevantBenefit))]
      | none => [])
    ++ (match c.car with
      | some (price, contrib, co2, range, diesel, u, pay, fuel) =>
        [("company_car_percent", toJson (carPct co2 range diesel)),
         ("company_car_benefit_36500ths_pence", toJson (carBenefit price contrib co2 range diesel u pay)),
         ("car_fuel_benefit_36500ths_pence", toJson (fuelBenefit co2 range diesel u fuel))]
      | none => [])
    ++ (match c.tv with
      | some (req, blind, aged) => [("tv_licence_pence", toJson (tvLicence req blind aged))]
      | none => [])
    ++ (match c.vedCar with
      | some v => [("vehicle_excise_duty_pounds", toJson (ved v))]
      | none => [])
    ++ (match c.sfe with
      | some (s, k, final, care, rs, ch, given, dep) =>
        let hi := given.getD (householdIncome rs ch)
        [("student_household_income_pence", toJson hi),
         ("maintenance_loan_pounds", toJson (maintenanceLoan s k final care hi))]
        ++ (match dep with
          | some x => [("adult_dependants_grant_half_pence", toJson (adgHalfPence x)),
                       ("parents_learning_allowance_half_pence", toJson (plaHalfPence x))]
          | none => [])
      | none => [])
    ++ (match c.isa with
      | some (age, subs, lp) =>
        [("isa_subscriptions_above_limit_pence", toJson (isaExcess subs)),
         ("lifetime_isa_bonus_quarter_pence", toJson (lisaBonusQuarters age lp))]
      | none => [])
    ++ (match c.mw with
      | some (age, ap) => [("minimum_wage_pence", toJson (minimumWage age ap))]
      | none => [])
    ++ (match c.whdIn with
      | some (ew, q, b) => [("warm_home_discount_pence", toJson (whd ew q b))]
      | none => [])
    ++ (match c.scp with
      | some (n, other) =>
        let onUc := c.claims.uc && (0 : Int) < (match floor with
          | some f => ucAwardFloor claims f ucEarned
          | none => ucAward claims ucEarned)
        [("scottish_child_payment_pence", toJson (scpYear n (other || onUc)))]
      | none => [])
    ++ (match c.csp with
      | some (ov, n) =>
        let e := caEarnings c.period rg c.employment
        [("carer_support_payment_pence", toJson (cspYear ov e)),
         ("scottish_carer_supplement_pence", toJson (cspExtras ov e 0)),
         ("carer_additional_person_payment_pence", toJson (cspExtras ov e n - cspExtras ov e 0))]
      | none => [])
    ++ (match c.land with
      | some (tax, kind, p, nr, rents, resi) =>
        let sk : SdltKind := match kind with
          | .residential => .residential | .firstTime => .firstTime
          | .additional => .additional | .nonResidential => .nonResidential
        let purchase := if tax = 1 then lbttExact kind p else if tax = 2 then lttExact kind p
          else if nr then sdltNonResident sk p else sdltExact sk p
        -- Residential leases are exempt from LBTT (Sch 1 para 3) and not charged on
        -- rent in LTT (Sch 6 para 27).
        let table : List (Nat × Nat) :=
          if tax = 1 then (if resi then [] else lbttRent)
          else if tax = 2 then (if resi then [] else lttRent)
          else if resi then (if nr then bandsAdd sdltNonResidentRate sdltRentResidential else sdltRentResidential)
          else sdltRentNonResidential
        [("land_tax_exact_ten_thousandths_pence", toJson purchase)]
        ++ (if rents.isEmpty then [] else
          [("land_tax_rent_scaled_ten_thousandths_pence", toJson (if table.isEmpty then 0 else rentTaxScaled table rents)),
           ("land_tax_rent_npv_numerator_pence", toJson (npvNum rents)),
           ("land_tax_rent_denominator", toJson (npvDen rents))])
      | none => [])
    ++ (match c.sdlt with
      | some (k, p) => [("sdlt_exact_ten_thousandths_pence", toJson (sdltExact k p))]
      | none => [])
    ++ (match c.ct with
      | some v => [("council_tax_1440ths_pence", toJson v)]
      | none => [])
    ++ (match c.nspYears with
      | some y => [("new_state_pension_weekly_35ths_pence", toJson (nspReduced35 y))]
      | none => [])
    |> Json.mkObj

def run (input : String) : Except String Json := do
  let j ← Json.parse input
  match j with
  | .arr xs => return Json.arr (← xs.mapM fun x => result <$> parseCase x)
  | _ => return result (← parseCase j)

def main : IO UInt32 := do
  let input ← (← IO.getStdin).readToEnd
  match run input with
  | .ok j => IO.println j.compress; return 0
  | .error e => IO.eprintln s!"uktax: {e}"; return 1
