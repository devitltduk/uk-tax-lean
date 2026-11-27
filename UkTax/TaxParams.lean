import UkTax.Params

/-!
# A parameter set: the figures the guarantees are proved for

`TaxParams` holds the rates and thresholds of income tax, employee NICs, the High
Income Child Benefit Charge, the Universal Credit taper and the childcare tests:
the figures that `netAll` (net income with benefits) depends on and that the
headline theorems are about. Each field defaults to its 2026-27 value in
`UkTax/Params.lean`, so `TaxParams.y2026 = {}` is the 2026-27 set, and a
`Regime` carries one (`Regime.params`, default 2026-27).

Only figures can change, not structure: the personal allowance still tapers by
£1 for every £2 and is rounded up to a whole pound, the HICBC still rises 1 % per
step to 100 %, there are still three UK bands and six Scottish ones, and so on.
Every other figure in the model (benefit amounts, the Marriage Allowance and the
married couple's allowance, and all of `UkTax/Params.lean` not listed here) stays
the 2026-27 one.

`TaxParams.Valid` is the list of conditions the parametric theorems need, and
nothing more; each is used by some proof. They are:

* each schedule's rates do not fall from band to band (UK non-savings, savings,
  dividends, and the six Scottish rates);
* the basic rate limit is at most the higher rate limit;
* the personal savings allowance does not rise from band to band;
* the UC taper is at most 100 %;
* the worst-case marginal rate between steps is at most 100 %: the most a penny
  of pay can add to income tax (`TaxParams.maxStep`, a formula in the rates and
  limits), plus 0.05p for the married couple's allowance taper, plus the larger
  NIC rate, is at most a penny, for a Scottish taxpayer and for anyone else.
-/

namespace UkTax

/-- The figures a user can change. Money in pence, rates in basis points (except
the UC taper, a whole percentage). Defaults: 2026-27. -/
structure TaxParams where
  /-- Personal allowance (ITA 2007 s35(1)). -/
  pa : Nat := personalAllowance
  /-- Income limit for the personal allowance (s35(2)). -/
  paLimit : Nat := paIncomeLimit
  /-- Basic rate limit (s10(5)). -/
  brl : Nat := basicRateLimit
  /-- Higher rate limit (s10(5A)). -/
  hrl : Nat := higherRateLimit
  /-- Starting rate limit for savings (s12(3)). -/
  srls : Nat := startingRateLimitSavings
  /-- Personal savings allowance: no higher-rate income, higher-rate income, and
  additional-rate income (s12B). -/
  psaBasic : Nat := savingsAllowanceBasic
  psaHigher : Nat := savingsAllowanceHigher
  psaAdditional : Nat := savingsAllowanceAdditional
  /-- Dividend allowance (s13A). -/
  divAllowance : Nat := dividendAllowance
  /-- Basic, higher and additional rates on non-savings income, savings and
  dividends. -/
  nsRates : Rates := nonSavingsRates
  savRates : Rates := savingsRates
  divRates : Rates := dividendRates
  /-- Scottish limits (of Step 3 income) and rates. -/
  scStarterLimit : Nat := scotStarterLimit
  scBasicLimit : Nat := scotBasicLimit
  scIntermediateLimit : Nat := scotIntermediateLimit
  scHigherLimit : Nat := scotHigherLimit
  scAdvancedLimit : Nat := scotAdvancedLimit
  scStarterRate : Nat := scotStarterRate
  scBasicRate : Nat := scotBasicRate
  scIntermediateRate : Nat := scotIntermediateRate
  scHigherRate : Nat := scotHigherRate
  scAdvancedRate : Nat := scotAdvancedRate
  scTopRate : Nat := scotTopRate
  /-- Employee Class 1: primary threshold and upper earnings limit per period,
  and the main and additional rates. -/
  ptAnnual : Nat := primaryThresholdAnnual
  ptMonthly : Nat := primaryThresholdMonthly
  ptWeekly : Nat := primaryThresholdWeekly
  uelAnnual : Nat := upperEarningsLimitAnnual
  uelMonthly : Nat := upperEarningsLimitMonthly
  uelWeekly : Nat := upperEarningsLimitWeekly
  nicMain : Nat := nicMainRate
  nicAdditional : Nat := nicAdditionalRate
  /-- HICBC: the threshold, and the income per 1 % of the charge. -/
  cbThreshold : Nat := hicbcThreshold
  cbStep : Nat := hicbcStep
  /-- UC taper, whole per cent. -/
  ucTaper : Nat := ucTaperPercent
  /-- Childcare tests: the adjusted net income limit and the minimum earnings. -/
  ccLimit : Nat := childcareIncomeLimit
  ccMinEarnings : Nat := childcareMinimumEarnings
  deriving Repr, DecidableEq

/-- The 2026-27 figures. -/
abbrev TaxParams.y2026 : TaxParams := {}


/-- A rate in a schedule by band: 0 basic, 1 higher, 2 additional. -/
def Rates.at (r : Rates) : Nat → Nat
  | 0 => r.basic
  | 1 => r.higher
  | _ => r.additional

@[simp] theorem Rates.at_zero (r : Rates) : r.at 0 = r.basic := rfl
@[simp] theorem Rates.at_one (r : Rates) : r.at 1 = r.higher := rfl
@[simp] theorem Rates.at_two (r : Rates) : r.at 2 = r.additional := rfl

/-- The rates do not fall from band to band. -/
def Rates.Ordered (r : Rates) : Prop := r.basic ≤ r.higher ∧ r.higher ≤ r.additional

instance (r : Rates) : Decidable r.Ordered := inferInstanceAs (Decidable (_ ∧ _))

/-- The Scottish rate on a penny of non-savings income at position `y`, given how
far the limits above the starter limit are raised (`relief`). Each rate's rise
over the one below applies above its limit. -/
def TaxParams.scotRate (P : TaxParams) (relief y : Nat) : Nat :=
  P.scStarterRate
    + (if P.scStarterLimit ≤ y then P.scBasicRate - P.scStarterRate else 0)
    + (if P.scBasicLimit + relief ≤ y then P.scIntermediateRate - P.scBasicRate else 0)
    + (if P.scIntermediateLimit + relief ≤ y then P.scHigherRate - P.scIntermediateRate else 0)
    + (if P.scHigherLimit + relief ≤ y then P.scAdvancedRate - P.scHigherRate else 0)
    + (if P.scAdvancedLimit + relief ≤ y then P.scTopRate - P.scAdvancedRate else 0)

/-- The UK rate of schedule `r` at position `y`, limits raised by `relief`. -/
def TaxParams.ukRate (P : TaxParams) (r : Rates) (relief y : Nat) : Nat :=
  if y < P.brl + relief then r.basic else if y < P.hrl + relief then r.higher else r.additional

/-- The highest Scottish rate on non-savings income below the limit `lim` of the
UK band (for any relief): the Scottish basic rate (the starter rate is no higher)
plus the rise of each Scottish rate whose limit is below `lim`. -/
def TaxParams.scotBelow (P : TaxParams) (lim : Nat) : Nat :=
  P.scBasicRate
    + (if P.scBasicLimit + 1 ≤ lim then P.scIntermediateRate - P.scBasicRate else 0)
    + (if P.scIntermediateLimit + 1 ≤ lim then P.scHigherRate - P.scIntermediateRate else 0)
    + (if P.scHigherLimit + 1 ≤ lim then P.scAdvancedRate - P.scHigherRate else 0)
    + (if P.scAdvancedLimit + 1 ≤ lim then P.scTopRate - P.scAdvancedRate else 0)

/-- The most a penny of non-savings income in UK band `k` can be charged, for a
Scottish taxpayer (`sc`) or not. -/
def TaxParams.nsCap (P : TaxParams) (sc : Bool) (k : Nat) : Nat :=
  if sc then (match k with
    | 0 => P.scotBelow P.brl
    | 1 => P.scotBelow P.hrl
    | _ => P.scTopRate)
  else P.nsRates.at k

/-- The most a penny of non-savings income below the starting rate limit for
savings can be charged (the limits raised by no relief: relief only lowers it). -/
def TaxParams.nsCapLow (P : TaxParams) (sc : Bool) : Nat :=
  if sc then P.scotRate 0 (P.srls - 1) else P.ukRate P.nsRates 0 (P.srls - 1)

/-- **The marginal income tax bound, as a formula in the figures.** The most a
penny more non-savings income can add to income tax with both allowances fixed,
in 1/10 000 pence (`G_succ_le`). Two cases:

* the penny is below the starting rate limit for savings, which pushes a penny of
  savings out of the 0 % starting rate into the band of the top of the savings,
  and a penny of dividends from the bottom of the taxed dividends to the top:
  `nsCapLow + max_k (s_k + d_2 - d_k)`;
* otherwise the taxed savings slice moves up a penny (from band `a` to band `b`,
  `a ≤ b`) and so does the taxed dividend slice:
  `max_{a ≤ b} (nsCap a + s_b - s_a + d_2 - d_b)`.

`s`, `d` are the savings and dividend rates by band. For 2026-27 this is 0.686p,
or 0.706p for a Scottish taxpayer (`maxStep_y2026`). -/
def TaxParams.maxStep (P : TaxParams) (sc : Bool) : Nat :=
  let s := P.savRates.at
  let d := P.divRates.at
  let c := P.nsCap sc
  max (P.nsCapLow sc + max (s 0 + d 2 - d 0) (max (s 1 + d 2 - d 1) (s 2)))
    (max (max (c 0 + d 2 - d 0) (c 0 + (s 1 - s 0) + d 2 - d 1))
      (max (max (c 0 + (s 2 - s 0)) (c 1 + d 2 - d 1))
        (max (c 1 + (s 2 - s 1)) (c 2))))

/-- The most a penny more pay can add to employee NICs, 1/10 000 pence. -/
def TaxParams.nicStep (P : TaxParams) : Nat := max P.nicMain P.nicAdditional

/-- The most the married couple's allowance reduction can fall for a penny more
income, in 1/10 000 pence (10 % of half a penny); a 2026-27 figure. -/
def mcaStepMax : Nat := 500

/-- **The conditions the parametric theorems need.** -/
structure TaxParams.Valid (P : TaxParams) : Prop where
  nsOrdered : P.nsRates.Ordered
  savOrdered : P.savRates.Ordered
  divOrdered : P.divRates.Ordered
  scStarterBasic : P.scStarterRate ≤ P.scBasicRate
  scBasicIntermediate : P.scBasicRate ≤ P.scIntermediateRate
  scIntermediateHigher : P.scIntermediateRate ≤ P.scHigherRate
  scHigherAdvanced : P.scHigherRate ≤ P.scAdvancedRate
  scAdvancedTop : P.scAdvancedRate ≤ P.scTopRate
  brlHrl : P.brl ≤ P.hrl
  psaHigherBasic : P.psaHigher ≤ P.psaBasic
  psaAdditionalHigher : P.psaAdditional ≤ P.psaHigher
  ucTaperLe : P.ucTaper ≤ 100
  marginalUk : P.maxStep false + mcaStepMax + P.nicStep ≤ 10_000
  marginalScot : P.maxStep true + mcaStepMax + P.nicStep ≤ 10_000

/-- Find a term inside nested `max`es (and under `L + _`). -/
syntax "max_le" : tactic
macro_rules
  | `(tactic| max_le) => `(tactic| first
    | exact Nat.le_refl _
    | (apply Nat.add_le_add_left; max_le)
    | (refine Nat.le_trans ?_ (Nat.le_max_left _ _); max_le)
    | (refine Nat.le_trans ?_ (Nat.le_max_right _ _); max_le))

/-- Each case of the bound is at most it. -/
theorem TaxParams.maxStep_ge (P : TaxParams) (sc : Bool) :
    P.nsCapLow sc + (P.savRates.basic + P.divRates.additional - P.divRates.basic) ≤ P.maxStep sc ∧
    P.nsCapLow sc + (P.savRates.higher + P.divRates.additional - P.divRates.higher) ≤ P.maxStep sc ∧
    P.nsCapLow sc + P.savRates.additional ≤ P.maxStep sc ∧
    P.nsCap sc 0 + P.divRates.additional - P.divRates.basic ≤ P.maxStep sc ∧
    P.nsCap sc 0 + (P.savRates.higher - P.savRates.basic) + P.divRates.additional
      - P.divRates.higher ≤ P.maxStep sc ∧
    P.nsCap sc 0 + (P.savRates.additional - P.savRates.basic) ≤ P.maxStep sc ∧
    P.nsCap sc 1 + P.divRates.additional - P.divRates.higher ≤ P.maxStep sc ∧
    P.nsCap sc 1 + (P.savRates.additional - P.savRates.higher) ≤ P.maxStep sc ∧
    P.nsCap sc 2 ≤ P.maxStep sc := by
  unfold TaxParams.maxStep
  simp only [Rates.at_zero, Rates.at_one, Rates.at_two]
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩ <;> max_le

/-- The 2026-27 bound: 0.686p, 0.706p for a Scottish taxpayer. -/
theorem TaxParams.maxStep_y2026 (sc : Bool) :
    TaxParams.y2026.maxStep sc = if sc then 7060 else 6860 := by
  cases sc <;> decide

/-- The 2026-27 figures meet every condition. -/
theorem valid_y2026 : TaxParams.y2026.Valid := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩ <;> decide

end UkTax
