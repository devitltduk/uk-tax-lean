import UkTax.Rules.Core

/-!
# Printing rules as plain English and as statute text

Two renderings of each block of `UkTax/Rules/Core.lean`. Each block's wording is
fixed here, once; the figures in it are read from the parameter set by the same
functions `eval` uses, and the worked examples are computed by `eval` itself. So
the printed text can only say what the rule computes, as long as each block's
wording means what the block's `eval` does (checked by reading, once per block;
see `docs/prose/README.md`).
-/

namespace UkTax.Rules

/-! ## Figures -/

/-- `n` with a comma every three digits: 1234567 → "1,234,567". -/
def commas (n : Nat) : String :=
  if n < 1000 then toString n
  else commas (n / 1000) ++ "," ++ (toString (n % 1000 + 1000)).drop 1
termination_by n
decreasing_by omega

/-- A sum in pence: "£12,570", or "£12,570.50" when there are pence. -/
def money (p : Nat) : String :=
  "£" ++ commas (p / 100) ++
    (if p % 100 = 0 then "" else "." ++ (toString (p % 100 + 100)).drop 1)

/-- Money in the rules' unit, to the penny (rounded down; the examples are whole
pence). Nil or less prints as £0. -/
def moneyOf (u : Int) : String := money (u / perPenny).toNat

/-- A rate in basis points as a percentage: 2000 → "20%", 1075 → "10.75%". -/
def percent (bp : Nat) : String :=
  let frac := ((toString (bp % 100 + 100)).drop 1).toString
  let frac := if frac.endsWith "0" then (frac.dropEnd 1).toString else frac
  toString (bp / 100) ++ (if bp % 100 = 0 then "" else "." ++ frac) ++ "%"

/-- "£1 for every £2", or "one-half" when it is exactly that. -/
def fraction (per every : Nat) : Option String :=
  if per * 2 = every then some "one-half" else none

/-- "twice ", "three times ", or nothing. -/
def times : Nat → String
  | 1 => ""
  | 2 => "twice "
  | n => s!"{n} times "

/-- A figure worked out from others, in statute words: "equal to— (a) twice the
amount specified in ..., plus (b) ...; that is, £25,140 plus £100,000, £125,140". -/
def Figure.statuteParts (f : Figure) (P : TaxParams) : String :=
  let letters := "abcdefghijklmnopqrstuvwxyz".toList
  let paras := f.parts.zipIdx.map fun (p, i) => s!"({letters.getD i 'z'}) {times p.times}{p.statute}"
  let sums := f.parts.map fun p => money (p.times * p.get P)
  "equal to— " ++ ", plus ".intercalate paras ++ "; that is, " ++ " plus ".intercalate sums ++
    s!", {money (f.get P)}"

/-- A figure worked out from others, in plain words. -/
def Figure.plainParts (f : Figure) (P : TaxParams) : String :=
  let parts := f.parts.map fun p => s!"{times p.times}{p.plain} ({money (p.get P)})"
  s!"The {money (f.get P)} limit is not a figure of its own: it is " ++ " plus ".intercalate parts ++
    "." ++ (if f.plainNote.isEmpty then "" else " " ++ f.plainNote)

/-! ## An amount as a starting figure and its adjustments -/

/-- One adjustment of an amount: a block that wraps another. -/
inductive Adj where
  | taper (per every : Nat) (t : Test)
  | notBelowNil
  | roundUpPound

/-- An amount as its innermost block and the adjustments made to it, in order. -/
def Amt.chain : Amt → Amt × List Adj
  | .taper a per every t => let c := a.chain; (c.1, c.2 ++ [.taper per every t])
  | .notBelowNil a => let c := a.chain; (c.1, c.2 ++ [.notBelowNil])
  | .roundUpPound a => let c := a.chain; (c.1, c.2 ++ [.roundUpPound])
  | a => (a, [])

/-- The inputs an amount reads, without repeats, in the order they appear. -/
def Amt.inputs : Amt → List Input
  | .fig _ => []
  | .input i => [i]
  | .taper a _ _ t =>
    let is := a.inputs
    if is.any (·.key == t.measure.key) then is else is ++ [t.measure]
  | .notBelowNil a | .roundUpPound a => a.inputs

/-- A section of an Act that gives an amount: "An individual is entitled to a
personal allowance of ...". -/
structure AmountSection where
  number : String
  heading : String
  /-- "an individual" -/
  who : String
  /-- "a personal allowance" -/
  what : String
  /-- How later subsections refer back to it: "the allowance". -/
  short : String
  /-- Plain English: "your personal allowance". -/
  plainName : String
  /-- Heading of the plain-English version, with the sections it covers. -/
  plainHeading : String
  rule : Amt
  /-- Values of the rule's first input to work examples for, in pence. -/
  examples : List Nat := []

/-- A section of an Act that charges tax in bands. -/
structure BandsSection where
  number : String
  heading : String
  schedule : Schedule
  /-- Heading of the plain-English version, with the sections it covers. -/
  plainHeading : String
  /-- Taxable incomes to work examples for, in pence. -/
  examples : List Nat := []

/-! ## Statute layout -/

/-- "subsection (2)", "subsections (2) and (3)", "subsections (2) to (4)". -/
def subsections (a b : Nat) : String :=
  if b ≤ a then s!"subsection ({a})"
  else if b = a + 1 then s!"subsections ({a}) and ({b})"
  else s!"subsections ({a}) to ({b})"

/-- "(1) text" as a markdown paragraph. -/
def subsection (k : Nat) (text : String) : String := s!"({k}) {text}\n\n"

/-- A starting amount in statute words. -/
def Amt.statuteBase (P : TaxParams) : Amt → String
  | .fig f => money (f.get P)
  | .input i => s!"an amount equal to {i.noun}"
  | _ => "the amount given below"

/-- One adjustment as a subsection, the `k`th of the section. -/
def Adj.statute (s : AmountSection) (P : TaxParams) (k : Nat) (prev : Option Adj) :
    Adj → String
  | .taper per every t =>
    let thr := money (t.threshold.get P) ++
      (match t.threshold.name with | some n => s!" (“{n}”)" | none => "")
    let by_ := match fraction per every with
      | some f => s!"{f} of the excess"
      | none => s!"{money (per * 100)} for every {money (every * 100)} of the excess"
    s!"For {s.who} whose {t.measure.term} exceeds {thr}, {s.short} under \
      {subsections 1 (k - 1)} is reduced by {by_}."
  | .notBelowNil =>
    match prev with
    | some (.taper ..) => s!"Subsection ({k - 1}) does not reduce {s.short} below nil."
    | _ => s!"{s.short.capitalize} under {subsections 1 (k - 1)} is not less than nil."
  | .roundUpPound =>
    s!"If the amount of {s.short} that remains after the operation of \
      {subsections 2 (k - 1)} would otherwise not be a multiple of £1, it is to be \
      rounded up to the nearest amount which is a multiple of £1."

/-- An amount section in statute layout. -/
def AmountSection.statute (s : AmountSection) (P : TaxParams) : String := Id.run do
  let (base, adjs) := s.rule.chain
  let n := adjs.length + 1
  let subj := if adjs.isEmpty then "" else s!"Subject to {subsections 2 n}, "
  let first := s!"{subj}{s.who} is entitled to {s.what} of {base.statuteBase P}."
  let mut out := s!"**{s.number} {s.heading}**\n\n" ++ subsection 1 first.capitalize
  let mut prev : Option Adj := none
  let mut k := 2
  for a in adjs do
    out := out ++ subsection k (a.statute s P k prev)
    prev := some a
    k := k + 1
  for i in s.rule.inputs do
    out := out ++ subsection k i.defn
    k := k + 1
  return out

/-- The paragraphs (a), (b), ... of a charge in bands. -/
def bandParagraphs (P : TaxParams) (bands : List Band) : List String := Id.run do
  let letters := "abcdefghijklmnopqrstuvwxyz".toList
  let mut out := []
  let mut prev : Option Figure := none
  let mut i := 0
  for b in bands do
    let lower := match prev with
      | some l => s!"exceeds {l.name.getD (money (l.get P))}"
      | none => ""
    let upper := match b.upTo with
      | some u => s!"does not exceed {u.name.getD (money (u.get P))}"
      | none => ""
    let part := match lower, upper with
      | "", "" => "on all of it"
      | "", u => s!"on so much of it as {u}"
      | l, "" => s!"on so much of it as {l}"
      | l, u => s!"on so much of it as {l} but {u}"
    let last := i + 1 = bands.length
    let sep := if last then "." else if i + 2 = bands.length then ", and" else ","
    out := out ++ [s!"({letters.getD i 'z'}) at {b.rate.name}, {part}{sep}"]
    prev := b.upTo
    i := i + 1
  return out

/-- The rates of a schedule in statute layout (in the way of ITA 2007 s6). -/
def BandsSection.statuteRates (s : BandsSection) (number heading year : String)
    (P : TaxParams) : String := Id.run do
  let names := s.schedule.bands.map (·.rate.name)
  let rec join : List String → String
    | [] => ""
    | [a] => a
    | [a, b] => s!"{a} and {b}"
    | a :: rest => s!"{a}, {join rest}"
  let rates := join (s.schedule.bands.map fun b => s!"{b.rate.name} is {percent (b.rate.get P)}")
  s!"**{number} {heading}**\n\n" ++
    subsection 1 s!"The main rates at which income tax is charged are {join names}." ++
    subsection 2 s!"For the tax year {year} {rates}."

/-- A charge in bands in statute layout (in the way of ITA 2007 s10). -/
def BandsSection.statute (s : BandsSection) (P : TaxParams) : String := Id.run do
  let sch := s.schedule
  let mut out := s!"**{s.number} {s.heading}**\n\n" ++
    subsection 1 (s!"Income tax is charged on {sch.income.noun}—\n\n" ++
      "\n\n".intercalate (bandParagraphs P sch.bands))
  let mut k := 2
  for b in sch.bands do
    match b.upTo with
    | some l =>
      let is := if l.parts.isEmpty then money (l.get P) else l.statuteParts P
      out := out ++ subsection k s!"{(l.name.getD "the limit").capitalize} is {is}."
      k := k + 1
    | none => pure ()
  out := out ++ subsection k sch.income.defn
  return out

/-! ## Plain English -/

/-- A starting amount in plain words. -/
def Amt.plainBase (P : TaxParams) : Amt → String
  | .fig f => money (f.get P)
  | .input i => i.plain
  | _ => "the amount below"

/-- One adjustment as a numbered step. -/
def Adj.plain (P : TaxParams) : Adj → String
  | .taper per every t =>
    let thr := money (t.threshold.get P)
    let how := match fraction per every with
      | some "one-half" =>
        s!"half of the amount by which it is more than {thr} (£1 for every £2 over, \
          worked out exactly rather than in whole £2 steps)"
      | _ =>
        s!"{money (per * 100)} for every {money (every * 100)} by which it is more \
          than {thr} (worked out exactly, not in whole steps of {money (every * 100)})"
    s!"If {t.measure.plain} is more than {thr}, take off {how}."
  | .notBelowNil => "If that leaves less than £0, use £0."
  | .roundUpPound =>
    "If the result is not a whole number of pounds, round it up to the next whole pound."

/-- A markdown table. -/
def table (head : List String) (rows : List (List String)) : String :=
  let line (cs : List String) := "| " ++ " | ".intercalate cs ++ " |\n"
  line head ++ line (head.map fun _ => "---") ++ String.join (rows.map line)

/-- What the words mean, for the inputs read. -/
def glossary (is : List Input) : String :=
  String.join (is.map fun i => s!"**{i.term.capitalize}** means {i.gloss}.\n\n")

/-- An amount section in plain English, with worked examples. -/
def AmountSection.plain (s : AmountSection) (P : TaxParams) : String :=
  let (base, adjs) := s.rule.chain
  let steps := s!"Start with {base.plainBase P}." :: adjs.map (·.plain P)
  let numbered := (steps.zipIdx.map fun (t, i) => s!"{i + 1}. {t}\n").foldl (· ++ ·) ""
  let ex := match s.rule.inputs with
    | i :: _ =>
      if s.examples.isEmpty then "" else
      s!"For example:\n\n" ++ table [i.term.capitalize, s.plainName.capitalize]
        (s.examples.map fun v =>
          [money v, moneyOf (s.rule.eval P fun k => if k = i.key then v else 0)]) ++ "\n"
    | [] => ""
  s!"## {s.plainHeading}\n\n\
    To work out {s.plainName}:\n\n{numbered}\n" ++ glossary s.rule.inputs ++ ex

/-- A charge in bands in plain English, with worked examples. -/
def BandsSection.plain (s : BandsSection) (P : TaxParams) : String := Id.run do
  let sch := s.schedule
  let mut rows := []
  let mut prev : Option Nat := none
  for b in sch.bands do
    let part := match prev, b.upTo with
      | none, some u => s!"The first {money (u.get P)}"
      | some l, some u => s!"Over {money l}, up to {money (u.get P)}"
      | some l, none => s!"Over {money l}"
      | none, none => "All of it"
    rows := rows ++ [[part, s!"{percent (b.rate.get P)} ({b.rate.name.replace "the " ""})"]]
    prev := b.upTo.map (·.get P)
  let ex := if s.examples.isEmpty then "" else
    s!"For example:\n\n" ++ table [sch.income.term.capitalize, "Income tax"]
      (s.examples.map fun v =>
        [money v, moneyOf (sch.eval P fun k => if k = sch.income.key then v else 0)]) ++ "\n"
  return s!"## {s.plainHeading}\n\n\
    Income tax on {sch.income.plain} is charged in bands. Each rate applies only to \
    the part of {sch.income.plain} that falls in its band:\n\n" ++
    table [s!"Part of {sch.income.plain}", "Rate"] rows ++ "\n" ++
    String.join (sch.bands.filterMap fun b => b.upTo.bind fun u =>
      if u.parts.isEmpty then none else some (u.plainParts P ++ "\n\n")) ++
    glossary [sch.income] ++ ex

end UkTax.Rules
