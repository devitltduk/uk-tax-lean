import UkTax.TaxParams

/-!
# Checking a parameter set

`checkParams P` is `.ok ()` exactly when `P` meets `TaxParams.Valid`, the
conditions the parametric theorems need (`checkParams_ok_iff`); otherwise it
names the first broken condition, with the figures, e.g. "the higher rate (35%)
is below the basic rate (40%)". `violations P` lists every broken condition, and
is empty exactly when `P.Valid` (`violations_eq_nil_iff`).
-/

namespace UkTax

/-- A broken condition: a stable key, and what is wrong in words. -/
structure Violation where
  condition : String
  message : String
  deriving Repr, DecidableEq

/-- Basis points as a percentage: 4000 is "40%", 1075 is "10.75%". -/
def fmtBp (bp : Nat) : String :=
  let w := bp / 100
  let f := bp % 100
  if f = 0 then s!"{w}%"
  else if f % 10 = 0 then s!"{w}.{f / 10}%"
  else s!"{w}.{if f < 10 then "0" else ""}{f}%"

/-- Groups of three digits. -/
def fmtThousands (n : Nat) : String :=
  if n < 1000 then toString n
  else
    let r := n % 1000
    fmtThousands (n / 1000) ++ "," ++ (if r < 10 then "00" else if r < 100 then "0" else "") ++ toString r
termination_by n
decreasing_by omega

/-- Pence as pounds: 3770000 is "£37,700", 50 is "£0.50". -/
def fmtPence (p : Nat) : String :=
  let r := p % 100
  "£" ++ fmtThousands (p / 100) ++ (if r = 0 then "" else s!".{if r < 10 then "0" else ""}{r}")

/-- 1/10 000 pence as pence, to four places: 6860 is "0.6860p". -/
def fmtTenThousandths (x : Nat) : String :=
  let r := x % 10000
  let pad := if r < 10 then "000" else if r < 100 then "00" else if r < 1000 then "0" else ""
  s!"{x / 10000}.{pad}{r}p"

/-- A check that a rate is not below the one before it. -/
def rateCheck (key upper lower : String) (hi lo : Nat) : Bool × Violation :=
  (decide (lo ≤ hi), ⟨key, s!"the {upper} ({fmtBp hi}) is below the {lower} ({fmtBp lo})"⟩)

/-- The marginal-rate condition. -/
def marginalCheck (P : TaxParams) (sc : Bool) : Bool × Violation :=
  (decide (P.maxStep sc + mcaStepMax + P.nicStep ≤ 10_000),
    ⟨if sc then "marginal_rate_scotland" else "marginal_rate",
      s!"the worst-case marginal rate between steps is above 100%{if sc then " for a Scottish taxpayer" else ""}: " ++
      s!"a penny more pay can cost {fmtTenThousandths (P.maxStep sc)} of income tax, " ++
      s!"{fmtTenThousandths P.nicStep} of National Insurance and " ++
      s!"{fmtTenThousandths mcaStepMax} of married couple's allowance"⟩)

/-- Every condition of `TaxParams.Valid`, in order, with its message. -/
def checks (P : TaxParams) : List (Bool × Violation) :=
  [ rateCheck "higher_rate" "higher rate" "basic rate" P.nsRates.higher P.nsRates.basic,
    rateCheck "additional_rate" "additional rate" "higher rate" P.nsRates.additional P.nsRates.higher,
    rateCheck "savings_higher_rate" "higher rate on savings" "basic rate on savings"
      P.savRates.higher P.savRates.basic,
    rateCheck "savings_additional_rate" "additional rate on savings" "higher rate on savings"
      P.savRates.additional P.savRates.higher,
    rateCheck "dividend_upper_rate" "dividend upper rate" "dividend ordinary rate"
      P.divRates.higher P.divRates.basic,
    rateCheck "dividend_additional_rate" "dividend additional rate" "dividend upper rate"
      P.divRates.additional P.divRates.higher,
    rateCheck "scottish_basic_rate" "Scottish basic rate" "Scottish starter rate"
      P.scBasicRate P.scStarterRate,
    rateCheck "scottish_intermediate_rate" "Scottish intermediate rate" "Scottish basic rate"
      P.scIntermediateRate P.scBasicRate,
    rateCheck "scottish_higher_rate" "Scottish higher rate" "Scottish intermediate rate"
      P.scHigherRate P.scIntermediateRate,
    rateCheck "scottish_advanced_rate" "Scottish advanced rate" "Scottish higher rate"
      P.scAdvancedRate P.scHigherRate,
    rateCheck "scottish_top_rate" "Scottish top rate" "Scottish advanced rate"
      P.scTopRate P.scAdvancedRate,
    (decide (P.brl ≤ P.hrl), ⟨"higher_rate_limit",
      s!"the higher rate limit ({fmtPence P.hrl}, twice the personal allowance plus the income " ++
      s!"limit) is below the basic rate limit ({fmtPence P.brl})"⟩),
    (decide (P.psaHigher ≤ P.psaBasic), ⟨"savings_allowance_higher",
      s!"the savings allowance for higher-rate taxpayers ({fmtPence P.psaHigher}) is above the one " ++
      s!"for basic-rate taxpayers ({fmtPence P.psaBasic})"⟩),
    (decide (P.psaAdditional ≤ P.psaHigher), ⟨"savings_allowance_additional",
      s!"the savings allowance for additional-rate taxpayers ({fmtPence P.psaAdditional}) is above " ++
      s!"the one for higher-rate taxpayers ({fmtPence P.psaHigher})"⟩),
    (decide (P.ucTaper ≤ 100), ⟨"uc_taper", s!"the Universal Credit taper ({P.ucTaper}%) is above 100%"⟩),
    marginalCheck P false,
    marginalCheck P true ]

/-- Every broken condition. -/
def violations (P : TaxParams) : List Violation :=
  (checks P).filterMap fun c => if c.1 then none else some c.2

/-- The first broken condition, if any. -/
def checkParams (P : TaxParams) : Except Violation Unit :=
  match violations P with
  | [] => .ok ()
  | v :: _ => .error v

theorem filterMap_eq_nil_iff_all (l : List (Bool × Violation)) :
    l.filterMap (fun c => if c.1 then none else some c.2) = [] ↔ ∀ c ∈ l, c.1 = true := by
  induction l with
  | nil => simp
  | cons c l ih =>
    obtain ⟨b, v⟩ := c
    cases b <;> simp [ih]

theorem checks_all_iff (P : TaxParams) : (∀ c ∈ checks P, c.1 = true) ↔ P.Valid := by
  simp only [checks, rateCheck, marginalCheck, List.mem_cons, List.mem_nil_iff, or_false,
    forall_eq_or_imp, forall_eq, decide_eq_true_eq]
  constructor
  · rintro ⟨h1, h2, h3, h4, h5, h6, h7, h8, h9, h10, h11, h12, h13, h14, h15, h16, h17⟩
    exact ⟨⟨h1, h2⟩, ⟨h3, h4⟩, ⟨h5, h6⟩, h7, h8, h9, h10, h11, h12, h13, h14, h15, h16, h17⟩
  · rintro ⟨⟨h1, h2⟩, ⟨h3, h4⟩, ⟨h5, h6⟩, h7, h8, h9, h10, h11, h12, h13, h14, h15, h16, h17⟩
    exact ⟨h1, h2, h3, h4, h5, h6, h7, h8, h9, h10, h11, h12, h13, h14, h15, h16, h17⟩

/-- **Every broken condition is listed**: none exactly when the theorems' conditions
hold. -/
theorem violations_eq_nil_iff (P : TaxParams) : violations P = [] ↔ P.Valid := by
  unfold violations
  rw [filterMap_eq_nil_iff_all]
  exact checks_all_iff P

/-- **The check is exact**: it passes exactly when the parametric theorems apply. -/
theorem checkParams_ok_iff (P : TaxParams) : checkParams P = .ok () ↔ P.Valid := by
  rw [← violations_eq_nil_iff]
  unfold checkParams
  split <;> simp_all

example : checkParams .y2026 = .ok () := (checkParams_ok_iff _).2 valid_y2026

/-- The message names the condition and the figures. -/
def firstMessage (P : TaxParams) : String :=
  match checkParams P with
  | .ok () => ""
  | .error v => v.condition ++ ": " ++ v.message

#guard firstMessage { nsRates := ⟨4000, 3500, 4500⟩ } ==
  "higher_rate: the higher rate (35%) is below the basic rate (40%)"
#guard firstMessage { brl := 13_000_000 } ==
  "higher_rate_limit: the higher rate limit (£125,140, twice the personal allowance plus the income " ++
  "limit) is below the basic rate limit (£130,000)"
-- Lowering the allowance lowers the higher rate limit with it (s10(5A)).
#guard firstMessage { pa := 1_000_000, brl := 12_100_000 } ==
  "higher_rate_limit: the higher rate limit (£120,000, twice the personal allowance plus the income " ++
  "limit) is below the basic rate limit (£121,000)"
#guard firstMessage { divRates := ⟨1075, 3575, 3500⟩ } ==
  "dividend_additional_rate: the dividend additional rate (35%) is below the dividend upper rate (35.75%)"
#guard firstMessage { ucTaper := 101 } == "uc_taper: the Universal Credit taper (101%) is above 100%"
#guard firstMessage { nsRates := ⟨2000, 9000, 9000⟩ } ==
  "marginal_rate: the worst-case marginal rate between steps is above 100%: a penny more pay can " ++
  "cost 0.9500p of income tax, 0.0800p of National Insurance and 0.0500p of married couple's allowance"
#guard firstMessage .y2026 == ""

end UkTax
