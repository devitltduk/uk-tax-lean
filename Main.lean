import Lean.Data.Json
import UkTax

/-!
`uktax`: read incomes as JSON on stdin, print the 2026-27 liability as JSON.

Input: one object, or an array of objects, with whole-pence amounts:

    {"non_savings_pence": 5000000, "savings_pence": 0, "dividends_pence": 0}

Output (an array for an array input):

    {"liability_pence": 748600, "personal_allowance_pence": 1257000,
     "savings_allowance_pence": 100000, "allowance_against_savings_pence": 0,
     "allowance_against_dividends_pence": 0}
-/

open Lean UkTax

def parseIncome (j : Json) : Except String Income := do
  let field (k : String) : Except String Nat :=
    match j.getObjValAs? Nat k with
    | .ok v => .ok v
    | .error _ => .error s!"field \"{k}\" must be a non-negative whole number of pence"
  return ⟨← field "non_savings_pence", ← field "savings_pence", ← field "dividends_pence"⟩

def result (i : Income) : Json :=
  let a := i.bestAlloc
  Json.mkObj [
    ("liability_pence", toJson (liability i)),
    ("personal_allowance_pence", toJson i.personalAllowance),
    ("savings_allowance_pence", toJson (savingsAllowanceFor (i.total - i.allowanceUsed))),
    ("allowance_against_savings_pence", toJson a.toSavings),
    ("allowance_against_dividends_pence", toJson a.toDividends)]

def run (input : String) : Except String Json := do
  let j ← Json.parse input
  match j with
  | .arr xs => return Json.arr (← xs.mapM fun x => result <$> parseIncome x)
  | _ => return result (← parseIncome j)

def main : IO UInt32 := do
  let input ← (← IO.getStdin).readToEnd
  match run input with
  | .ok j => IO.println j.compress; return 0
  | .error e => IO.eprintln s!"uktax: {e}"; return 1
