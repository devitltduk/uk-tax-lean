import UkTax.TaxParams

/-!
# A small rules language for tax law

Building blocks shaped like the way tax legislation is drafted: a figure, an
input, a threshold test, a taper ("reduced by £1 for every £2 by which ... exceeds
..."), "not less than nil", rounding up to a whole pound, and a schedule of rate
bands. Each block has a meaning here (`Amt.eval`, `Schedule.eval`) and two
renderings in `UkTax/Rules/Render.lean`: plain English and a statute-style layout.

The printed text is produced from the same values that `eval` runs, and the
figures it quotes are read from a `TaxParams` by the same functions, so a theorem
about `eval` is a theorem about what the text says (up to the wording of each
block, which is fixed per block and listed in `docs/prose/README.md`).

Int is held as an integer number of 1/10 000 pence, so that halving a whole
number of pence (the taper) is exact, and a rate in basis points times an amount
in pence is the model's own unit of tax (`bandTax`).
-/

namespace UkTax.Rules

/-- Units of money (whole 1/10 000ths of a penny, held as an `Int`) in a penny. -/
def perPenny : Int := 10_000

/-- An amount in whole pence as money. -/
def ofPence (n : Nat) : Int := n * perPenny

/-- A sum of money fixed by the legislation for the year, read from the parameter
set: "the income limit", £100,000. -/
structure Figure where
  /-- What the legislation calls it, if it names it ("the basic rate limit"). -/
  name : Option String := none
  /-- The figure, in pence. -/
  get : TaxParams → Nat

/-- A rate of tax, in basis points, read from the parameter set. -/
structure Rate where
  /-- "the basic rate" -/
  name : String
  get : TaxParams → Nat

/-- A fact about the taxpayer that the rules take as given, in pence. -/
structure Input where
  /-- Key in the environment. -/
  key : String
  /-- Statute wording: "the individual's adjusted net income". -/
  noun : String
  /-- The defined term alone: "adjusted net income". -/
  term : String
  /-- Statute definition, a whole sentence: "For the meaning of “adjusted net
  income” see section 58." -/
  defn : String
  /-- Plain wording: "your adjusted net income". -/
  plain : String
  /-- Plain explanation. Explanatory only: not part of what is proved. -/
  gloss : String

/-- Values of the inputs, in pence. -/
abbrev Env := String → Nat

/-- **Threshold test**: does an input exceed a figure? -/
structure Test where
  measure : Input
  threshold : Figure

/-- The test holds: the input is more than the figure. -/
def Test.holds (t : Test) (P : TaxParams) (env : Env) : Bool :=
  t.threshold.get P < env t.measure.key

/-- "The excess": by how much the input exceeds the figure, nil if the test fails. -/
def Test.excess (t : Test) (P : TaxParams) (env : Env) : Int :=
  if t.holds P env then ofPence (env t.measure.key) - ofPence (t.threshold.get P) else 0

/-- An amount, built from blocks. Every block but the first two wraps exactly one
amount, so each amount reads as a starting figure and a list of adjustments, the
way a section of an Act states an amount in subsection (1) and adjusts it in
the subsections after. -/
inductive Amt where
  /-- A figure from the parameter set. -/
  | fig (f : Figure)
  /-- An input. -/
  | input (i : Input)
  /-- **Taper**: reduced by `per` pounds for every `every` pounds of the excess in
  the threshold test. -/
  | taper (a : Amt) (per every : Nat) (t : Test)
  /-- **Not less than nil.** -/
  | notBelowNil (a : Amt)
  /-- **Rounded up** to a multiple of £1. -/
  | roundUpPound (a : Amt)

/-- What an amount comes to. -/
def Amt.eval (P : TaxParams) (env : Env) : Amt → Int
  | .fig f => ofPence (f.get P)
  | .input i => ofPence (env i.key)
  | .taper a per every t => a.eval P env - t.excess P env * per / every
  | .notBelowNil a => max 0 (a.eval P env)
  | .roundUpPound a => (a.eval P env + (100 * perPenny - 1)) / (100 * perPenny) * (100 * perPenny)

/-- One band of a rate schedule: a rate, charged up to a limit (or without limit,
for the top band). -/
structure Band where
  rate : Rate
  upTo : Option Figure

/-- **Rate bands**: a list of bands from the lowest; each band starts where the
one below ends, the first at nil. -/
structure Schedule where
  /-- What the bands are charged on. -/
  income : Input
  bands : List Band

/-- Tax on income `x`, the part above `lo` charged band by band. -/
def Schedule.evalFrom (P : TaxParams) (x : Int) : Int → List Band → Int
  | _, [] => 0
  | lo, b :: bs =>
    match b.upTo with
    | some l =>
      max 0 (min x (ofPence (l.get P)) - lo) * b.rate.get P / perPenny
        + evalFrom P x (ofPence (l.get P)) bs
    | none => max 0 (x - lo) * b.rate.get P / perPenny

/-- Tax, in `Int`, on the schedule's input. -/
def Schedule.eval (s : Schedule) (P : TaxParams) (env : Env) : Int :=
  Schedule.evalFrom P (ofPence (env s.income.key)) 0 s.bands

end UkTax.Rules
