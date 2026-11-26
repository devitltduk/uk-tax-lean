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
  not allowed with savings or dividends);
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

Output (an array for an array input). `liability_pence` is the liability rounded
down to the penny; `tax_exact_ten_thousandths_pence` is the exact, unrounded tax
in units of 1/10 000 of a penny.

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
      pure (some (couple, children))
    | .error _ => pure none
  let costs ← match j.getObjValAs? (Array Nat) "childcare_costs_pence" with
    | .ok xs => pure xs.toList
    | .error _ =>
      if (j.getObjVal? "childcare_costs_pence").toOption.isSome then
        throw "childcare_costs_pence must be an array of whole numbers of pence"
      else pure []
  let ucCouple := (uc.map (·.1)).getD false
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
  let claims : Claims := {
    uc := uc.isSome, couple := ucCouple || partner.isSome, ucChildren := (uc.map (·.2)).getD 0,
    childcareCosts := costs, partner, england, fundedChildren := kids }
  return ⟨income, { scottish, relief }, employment, period, ← optField "child_benefit_pence", claims⟩

def result (c : Case) : Json :=
  let i := c.income
  let rg := c.regime
  let a := i.bestAlloc rg
  let nic := nicExact c.period c.employment
  let ani := i.ani rg
  Json.mkObj [
    ("liability_pence", toJson (liability rg i)),
    ("tax_exact_ten_thousandths_pence", toJson (taxExact rg i)),
    ("adjusted_net_income_pence", toJson ani),
    ("personal_allowance_pence", toJson (i.personalAllowance rg)),
    ("savings_allowance_pence", toJson (savingsAllowanceFor rg (i.total - i.allowanceUsed rg))),
    ("step3_income_pence", toJson (i.total - i.allowanceUsed rg)),
    ("allowance_against_savings_pence", toJson a.toSavings),
    ("allowance_against_dividends_pence", toJson a.toDividends),
    ("nic_exact_ten_thousandths_pence", toJson nic),
    ("nic_pence", toJson (nic / 10_000)),
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
