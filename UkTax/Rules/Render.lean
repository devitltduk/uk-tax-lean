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
  | roundDownPound
  | less (i : Input)
  | percentOf (p : Pct)

/-- An amount as its innermost block and the adjustments made to it, in order. -/
def Amt.chain : Amt → Amt × List Adj
  | .taper a per every t => let c := a.chain; (c.1, c.2 ++ [.taper per every t])
  | .notBelowNil a => let c := a.chain; (c.1, c.2 ++ [.notBelowNil])
  | .roundUpPound a => let c := a.chain; (c.1, c.2 ++ [.roundUpPound])
  | .roundDownPound a => let c := a.chain; (c.1, c.2 ++ [.roundDownPound])
  | .less a i => let c := a.chain; (c.1, c.2 ++ [.less i])
  | .percentOf p a => let c := a.chain; (c.1, c.2 ++ [.percentOf p])
  | a => (a, [])

/-- Add an input to a list unless it is there. -/
def addInput (is : List Input) (i : Input) : List Input :=
  if is.any (·.key == i.key) then is else is ++ [i]

/-- The inputs an amount reads, without repeats, in the order they appear. -/
def Amt.inputs : Amt → List Input
  | .fig _ => []
  | .input i => [i]
  | .taper a _ _ t => addInput a.inputs t.measure
  | .less a i => addInput a.inputs i
  | .percentOf (.steps t _ _) a => addInput a.inputs t.measure
  | .percentOf (.rate _) a => a.inputs
  | .notBelowNil a | .roundUpPound a | .roundDownPound a => a.inputs

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
  /-- Values of an input to work examples for, in pence: the input `exampleKey`
  (the rule's first input if none), with the others as in `exampleEnv`. -/
  examples : List Nat := []
  exampleKey : Option String := none
  exampleEnv : Env := fun _ => 0
  /-- A sentence before the examples saying what the other inputs are. -/
  exampleNote : String := ""
  /-- Plain text after the steps (context that is not part of the rule, such as
  a table of figures the rule's inputs take). -/
  extra : TaxParams → String := fun _ => ""

/-- A section of an Act that charges tax in bands. -/
structure BandsSection where
  number : String
  heading : String
  schedule : Schedule
  /-- Heading of the plain-English version, with the sections it covers. -/
  plainHeading : String
  /-- Taxable incomes to work examples for, in pence. -/
  examples : List Nat := []
  /-- What is charged: "Income tax". -/
  what : String := "Income tax"
  /-- Statute opening of the charge, before the dash. -/
  statuteOpen : String := "Income tax is charged on an individual's taxable income"
  /-- Paragraphs "(a) the main primary percentage of so much of ... as" (SSCBA
  1992 s8) rather than "(a) at the basic rate, on so much of it as" (ITA 2007 s10). -/
  ofStyle : Bool := false
  /-- A subsection after (1) stating the rates (SSCBA 1992 s8(2)). -/
  ratesSubsection : Bool := false
  /-- Plain text after the table. -/
  extra : TaxParams → String := fun _ => ""

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
  | .roundDownPound =>
    s!"If the amount under {subsections 1 (k - 1)} is not a whole number of pounds, \
      it is to be rounded down to the nearest whole number."
  | .less i => s!"{s.short.capitalize} under {subsections 1 (k - 1)} is reduced by {i.noun}."
  | .percentOf (.rate r) =>
    s!"{s.short.capitalize} is {r.name} of the amount under {subsections 1 (k - 1)}."
  | .percentOf (.steps t every cap) =>
    s!"{s.short.capitalize} is the appropriate percentage of the amount under \
      {subsections 1 (k - 1)}, that is {cap}%, or if less, 1% for every whole \
      {money (every.get P)} by which {t.measure.noun} exceeds {money (t.threshold.get P)}."

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
def bandParagraphs (P : TaxParams) (bands : List Band) (ofStyle : Bool := false)
    (noun : String := "") : List String := Id.run do
  let letters := "abcdefghijklmnopqrstuvwxyz".toList
  let mut out := []
  let mut prev : Option Figure := none
  let mut i := 0
  let shown := bands.filter (!·.silent)
  for b in bands do
    if b.silent then
      prev := b.upTo
      continue
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
    let last := i + 1 = shown.length
    let sep := if last then "." else if i + 2 = shown.length then "; and" else ";"
    let sep := if ofStyle then sep else sep.replace ";" ","
    let text := if ofStyle then
        s!"{b.rate.name} of so much of {if i = 0 then noun ++ (if noun.contains ',' then "," else "") else "those earnings"} as \
          {(part.replace "on so much of it as " "").replace "on all of it" "all of it"}"
      else s!"at {b.rate.name}, {part}"
    out := out ++ [s!"({letters.getD i 'z'}) {text}{sep}"]
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
    subsection 1 (s!"{s.statuteOpen}—\n\n" ++
      "\n\n".intercalate (bandParagraphs P sch.bands s.ofStyle sch.income.noun))
  let mut k := 2
  if s.ratesSubsection then
    let shown := sch.bands.filter (!·.silent)
    let letters := "abcdefghijklmnopqrstuvwxyz".toList
    let paras := shown.zipIdx.map fun (b, i) => s!"({letters.getD i 'z'}) {b.rate.name} is {percent (b.rate.get P)}"
    out := out ++ subsection k (s!"For the purposes of this section—\n\n" ++
      ";\n\n".intercalate paras ++ ".")
    k := k + 1
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
  | .roundDownPound =>
    "If that is not a whole number of pounds, round it down to the whole pound (drop the pence)."
  | .less i => s!"Take off {i.plain}."
  | .percentOf (.rate r) => s!"Take {percent (r.get P)} of that ({r.name})."
  | .percentOf (.steps t every cap) =>
    s!"Take a percentage of that: 1% for every whole {money (every.get P)} by which \
      {t.measure.plain} is more than {money (t.threshold.get P)}, up to {cap}%. \
      Only whole steps of {money (every.get P)} count, so the percentage is a whole number."

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
  let varied := match s.exampleKey with
    | some k => s.rule.inputs.find? fun (i : Input) => i.key == k
    | none => s.rule.inputs.head?
  let ex := match varied with
    | some i =>
      if s.examples.isEmpty then "" else
      s!"For example{s.exampleNote}:\n\n" ++ table [i.term.capitalize, s.plainName.capitalize]
        (s.examples.map fun v =>
          [money v, moneyOf (s.rule.eval P fun k => if k = i.key then v else s.exampleEnv k)]) ++ "\n"
    | none => ""
  s!"## {s.plainHeading}\n\n\
    To work out {s.plainName}:\n\n{numbered}\n" ++ glossary s.rule.inputs ++ s.extra P ++ ex

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
    s!"For example:\n\n" ++ table [sch.income.term.capitalize, s.what]
      (s.examples.map fun v =>
        [money v, moneyOf (sch.eval P fun k => if k = sch.income.key then v else 0)]) ++ "\n"
  return s!"## {s.plainHeading}\n\n\
    {s.what} on {sch.income.plain} is charged in bands. Each rate applies only to \
    the part of {sch.income.plain} that falls in its band:\n\n" ++
    table [s!"Part of {sch.income.plain}", "Rate"] rows ++ "\n" ++
    String.join (sch.bands.filterMap fun b => b.upTo.bind fun u =>
      if u.parts.isEmpty then none else some (u.plainParts P ++ "\n\n")) ++
    glossary [sch.income] ++ s.extra P ++ ex

end UkTax.Rules
