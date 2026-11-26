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
  with `uc` or the childcare tests;
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
  per hour is given.

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
      pure ({ band, price } : FundedChild)
    | .error _ =>
      if (j.getObjVal? "funded_children").toOption.isSome then
        throw "funded_children must be an array"
      else pure []
  if (j.getObjVal? "funded_hours_value_pence").toOption.isSome then
    throw "funded_hours_value_pence is replaced by funded_children"
  let cb ← optField "child_benefit_pence"
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
  if tr + te + pr + pe + rr + re > 0 && (uc.isSome || !costs.isEmpty || partner.isSome
      || (j.getObjVal? "funded_children").toOption.isSome) then
    throw "trading, property and rent-a-room income are not modelled with Universal Credit or the childcare tests yet"
  let income : Income :=
    { income with nonSavings := income.nonSavings - netPay + profits }
  let rg : Regime := { scottish, relief, netPay, blind, maTransfer, maReceive, mca }
  return ⟨income, income.settle rg, employment - netPay, period, ← optField "child_benefit_pence", claims,
    tradeProfit tr te, propertyProfit shared pr pe rr re,
    (j.getObjValAs? Bool "employer_zero_rated").toOption.getD false,
    ← optField "class_1a_benefits_pence", ← optField "class_2_voluntary_weeks",
    ← optField "class_3_weeks"⟩

def result (c : Case) : Json :=
  let i := c.income
  let rg := c.regime
  let a := i.bestAlloc rg
  let nic := nicExact c.period (c.employment + rg.netPay)
  let ani := i.ani rg
  Json.mkObj [
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
      toJson (ucAward c.claims (earned c.period rg i.savings i.dividends c.employment))),
    ("tfc_millionths_pence", toJson (tfcTopUp c.claims c.employment ani)),
    ("funded_hours_millionths_pence", toJson (fundedHours c.claims c.employment ani)),
    ("childcare_eligible", toJson (childcareEligible c.claims c.employment ani)),
    -- `netAll` takes all non-savings income as pay
    ("net_income_millionths_pence",
      if c.employment = i.nonSavings then
        toJson (netAll c.period c.childBenefit rg c.claims i.savings i.dividends c.employment)
      else Json.null)]

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
