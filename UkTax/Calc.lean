import UkTax.Params

/-!
# The income tax calculation (ITA 2007 s23), 2026-27

Scope: an individual resident in the UK, in England, Wales, Northern Ireland or
Scotland, whose net income is made up of non-savings, savings and dividend
income, with no reliefs at Step 2 and no tax reductions. Welsh taxpayers are
covered because for 2026-27 every Welsh rate is 10p in the pound (Welsh rate
resolution NDM9117, agreed by the Senedd on 27 January 2026,
<https://record.senedd.wales/Motion/9117>), which leaves them on the same
20 / 40 / 45 % as England and Northern Ireland. Scottish taxpayers pay the
Scottish rates on non-savings income (s11A) and the UK rates on savings and
dividends (s11D(6), s13(5)). Gift Aid and pension contributions relieved at
source raise the rate limits and reduce adjusted net income (`Regime.relief`).

ITA 2007 s23 steps as modelled here:

* Steps 1-2: total income is the sum of the three kinds; there are no reliefs.
* Step 3: deduct the personal allowance (s35, tapered above £100,000 of adjusted
  net income) from the three kinds of income in the way that gives the least tax
  (s25(2)).
* Step 4: charge tax on what is left. Savings and dividends form the highest part
  of income, dividends on top (s16). Within the bands:
  - non-savings income at 20 / 40 / 45 % (s10), or at the Scottish rates
    19 / 20 / 21 / 42 / 45 / 48 % for a Scottish taxpayer (s11A);
  - savings income in the lowest £5,000 of Step 3 income at the 0 % starting rate
    for savings (s12), then the personal savings allowance at 0 % (s12A, s12B),
    then 20 / 40 / 45 %;
  - dividends: the first £500 at the 0 % dividend nil rate (s13A), then
    10.75 / 35.75 / 39.35 % (s8, s13).
  Income charged at a nil rate still uses up the band it falls in.
* Step 6: the Marriage Allowance and married couple's allowance reductions, each
  only so far as there is tax (s29).
* Steps 5 and 7: nothing to do here (the HICBC is computed separately).

Tax is computed exactly in units of 1/10 000 of a penny and rounded down to the
penny once, at the end.
-/

namespace UkTax

/-- What about the taxpayer, other than the three kinds of income, the
calculation depends on. Fixed for the year, so held apart from `Income`. -/
structure Regime where
  /-- A Scottish taxpayer: non-savings income at the Scottish rates. -/
  scottish : Bool := false
  /-- Grossed-up Gift Aid donations plus gross pension contributions relieved at
  source, in pence. They raise the basic and higher rate limits (and the Scottish
  limits from the basic rate's up; ITA 2007 s414(2), FA 2004 s192(4), (4A)) and
  are deducted from net income to give adjusted net income (ITA 2007 s58). For
  relief at source, s192(4) raises the limits "if ... income tax at the higher rate
  or the additional rate is chargeable" and "on the making of a claim"; the model
  raises them for every such contribution, as HMRC's PTM056120 describes, and
  assumes the claim is made. Read literally, "the higher rate" is the non-savings
  rate, which would leave the limits alone where only savings or dividends are
  above them (docs/findings.md #11). -/
  relief : Nat := 0
  /-- Pension contributions under a net pay arrangement, deducted from pay for
  income tax (FA 2004 s193(2)) but not for NICs ("There is no equivalent NICs
  relief", HMRC NIM02365). Pay in the model is pay after them; NICs are charged
  on pay plus them. -/
  netPay : Nat := 0
  /-- Gets the blind person's allowance (ITA 2007 s38). -/
  blind : Bool := false
  /-- Has given up the Marriage Allowance to a spouse or civil partner: their own
  personal allowance is reduced by the transferable amount (s55B(6)). -/
  maTransfer : Bool := false
  /-- Has received the Marriage Allowance from a spouse or civil partner who is
  eligible to give it (s55B(2)(a), s55C): a tax reduction if this taxpayer passes
  the rate test of s55B(2)(b), (ba). -/
  maReceive : Bool := false
  /-- Is the spouse entitled to the married couple's allowance (a party born
  before 6 April 1935; s45, s46). -/
  mca : Bool := false
  deriving Repr, DecidableEq

/-- The basic rate limit, raised by the relief. -/
def Regime.brl (rg : Regime) : Nat := basicRateLimit + rg.relief

/-- The higher rate limit, raised by the relief. -/
def Regime.hrl (rg : Regime) : Nat := higherRateLimit + rg.relief

/-- A taxpayer's income for the year, in pence. -/
structure Income where
  nonSavings : Nat
  savings : Nat
  dividends : Nat
  deriving Repr

/-- Tax, in 1/10 000 pence, on the lowest `x` pence of Step 3 income if all of it
were charged at rates `r`. -/
def bandTax (r : Rates) (rg : Regime) (x : Nat) : Nat :=
  r.basic * min x rg.brl
    + r.higher * (min x rg.hrl - rg.brl)
    + r.additional * (x - rg.hrl)

/-- Tax, in 1/10 000 pence, on the lowest `x` pence of a Scottish taxpayer's
Step 3 income if all of it were non-savings income: each rate's increase over
the one below, charged on what is above that rate's lower limit. The starter
limit is not raised by the relief; the others are. -/
def scotTax (rg : Regime) (x : Nat) : Nat :=
  scotStarterRate * x
    + (scotBasicRate - scotStarterRate) * (x - scotStarterLimit)
    + (scotIntermediateRate - scotBasicRate) * (x - (scotBasicLimit + rg.relief))
    + (scotHigherRate - scotIntermediateRate) * (x - (scotIntermediateLimit + rg.relief))
    + (scotAdvancedRate - scotHigherRate) * (x - (scotHigherLimit + rg.relief))
    + (scotTopRate - scotAdvancedRate) * (x - (scotAdvancedLimit + rg.relief))

/-- Tax, in 1/10 000 pence, on the lowest `x` pence of Step 3 income at the
non-savings rates: the Scottish rates for a Scottish taxpayer (ITA 2007 s11A),
otherwise the main rates (s10). -/
def nsTax (rg : Regime) (x : Nat) : Nat :=
  if rg.scottish then scotTax rg x else bandTax nonSavingsRates rg x

/-- Where a non-savings rate can change, as positions in Step 3 income: the basic
and higher rate limits and the Scottish limits, whichever applies. The search
tries all of them; a line where the rate does not in fact change only adds
candidates. -/
def nsLimits (rg : Regime) : List Nat :=
  [rg.brl, rg.hrl, scotStarterLimit, scotBasicLimit + rg.relief,
    scotIntermediateLimit + rg.relief, scotHigherLimit + rg.relief,
    scotAdvancedLimit + rg.relief]

/-- Tax, in 1/10 000 pence, on the slice of Step 3 income between positions `lo`
and `hi` (counting from the bottom of the basic rate band) at rates `r`. -/
def sliceTax (r : Rates) (rg : Regime) (lo hi : Nat) : Nat :=
  bandTax r rg hi - bandTax r rg lo

/-- Personal allowance for a given adjusted net income (ITA 2007 s35): reduced by
half the excess over £100,000, then rounded up to a whole pound. -/
def personalAllowanceFor (adjustedNetIncome : Nat) : Nat :=
  -- twice the reduced allowance, in pence; exact even when the excess is odd
  let twice := 2 * personalAllowance - (adjustedNetIncome - paIncomeLimit)
  100 * ((twice + 199) / 200)

/-- Personal savings allowance (ITA 2007 s12B), given total Step 3 income. Income
charged at a nil rate still counts as higher-rate or additional-rate income
(s12B(8)), so this depends only on where Step 3 income ends. -/
def savingsAllowanceFor (rg : Regime) (step3Income : Nat) : Nat :=
  if step3Income > rg.hrl then savingsAllowanceAdditional
  else if step3Income > rg.brl then savingsAllowanceHigher
  else savingsAllowanceBasic

/-- Savings income charged at the starting rate for savings (s12): the part of it
that falls in the lowest £5,000 of Step 3 income. -/
def startingRateSavings (n s : Nat) : Nat :=
  min s (startingRateLimitSavings - n)

/-- Savings income charged at the savings nil rate (s12A). -/
def savingsNilRate (rg : Regime) (n s d : Nat) : Nat :=
  min (s - startingRateSavings n s) (savingsAllowanceFor rg (n + s + d))

/-- Dividend income charged at the dividend nil rate (s13A). -/
def dividendNilRate (d : Nat) : Nat :=
  min d dividendAllowance

/-- Step 4: tax, in 1/10 000 pence, on Step 3 income made of `n` non-savings, `s`
savings and `d` dividend income (savings above non-savings, dividends on top). -/
def taxOnStep3 (rg : Regime) (n s d : Nat) : Nat :=
  nsTax rg n
    + sliceTax savingsRates rg (n + startingRateSavings n s + savingsNilRate rg n s d) (n + s)
    + sliceTax dividendRates rg (n + s + dividendNilRate d) (n + s + d)

/-- Total income (= net income: no reliefs at Step 2 are modelled). -/
def Income.total (i : Income) : Nat := i.nonSavings + i.savings + i.dividends

/-- Adjusted net income (ITA 2007 s58): net income less the grossed-up Gift Aid
and the gross pension contributions relieved at source. -/
def Income.ani (rg : Regime) (i : Income) : Nat := i.total - rg.relief

/-- The allowances this taxpayer deducts at Step 3: the personal allowance (ITA
2007 s35, tapered), less the Marriage Allowance given up (s55B(6)), plus the blind
person's allowance (s38, not tapered). -/
def Income.personalAllowance (rg : Regime) (i : Income) : Nat :=
  (personalAllowanceFor (i.ani rg) - (if rg.maTransfer then maTransferable else 0))
    + (if rg.blind then blindPersonsAllowance else 0)

/-- How much of the personal allowance is set against each kind of income. -/
structure Alloc where
  toNonSavings : Nat
  toSavings : Nat
  toDividends : Nat
  deriving Repr

/-- The allowance actually deducted at Step 3: all of it, or all the income if
that is less. -/
def Income.allowanceUsed (rg : Regime) (i : Income) : Nat :=
  min (i.personalAllowance rg) i.total

/-- A legal way to deduct the allowance at Step 3: no kind of income goes below
nil, and the whole allowance (up to total income) is used. -/
def Alloc.Feasible (rg : Regime) (i : Income) (a : Alloc) : Prop :=
  a.toNonSavings ≤ i.nonSavings ∧ a.toSavings ≤ i.savings ∧ a.toDividends ≤ i.dividends ∧
    a.toNonSavings + a.toSavings + a.toDividends = i.allowanceUsed rg

/-- Step 4 tax, in 1/10 000 pence, when the allowance is deducted as `a`. -/
def taxWith (rg : Regime) (i : Income) (a : Alloc) : Nat :=
  taxOnStep3 rg (i.nonSavings - a.toNonSavings) (i.savings - a.toSavings)
    (i.dividends - a.toDividends)

/-- Deduct the allowance from non-savings income first, then savings, then
dividends. Always feasible; the search starts from it. -/
def Income.inOrder (rg : Regime) (i : Income) : Alloc :=
  let u := i.allowanceUsed rg
  ⟨min u i.nonSavings, min (u - i.nonSavings) i.savings,
    min (u - i.nonSavings - i.savings) i.dividends⟩

/-! ## Step 3: the share of the allowance that gives the least tax (ITA 2007 s25(2))

s25(2) deducts allowances "in the way which will result in the greatest reduction
in the taxpayer's liability". No fixed order does that: setting the allowance
against dividends can free the starting rate for savings, and setting it against
savings can lift the savings allowance into the higher rate band.

Write `x` for non-savings income left after the allowance, `w` for `x` plus the
savings left, and `T` for all income left (fixed). Every share is a point
`(x, w)` with `0 ≤ x ≤ N`, `0 ≤ w - x ≤ S` and `T - D ≤ w ≤ T`. Step 4 tax is
continuous and linear between lines on which `x`, `w` or `w - x` is constant:

* non-savings tax bends at `x ∈ nsLimits` (the basic and higher rate limits, and
  the Scottish limits);
* the starting rate for savings (`L` = £5,000) bends at `x = L` and `w = L`;
* the savings allowance `A` (fixed by `T`) bends at `w = L + A` and `w - x = A`,
  and the bottom of the taxed savings (`x + A` above `L`) crosses a limit at
  `x ∈ {BRL - A, HRL - A}`; the top `w` at `w ∈ {BRL, HRL}`;
* the dividend allowance `DA` bends at `w = T - DA` and `w + DA ∈ {BRL, HRL}`;
* the edges of the region are `x ∈ {0, N}`, `w - x ∈ {0, S}`, `w ∈ {T - D, T}`.

A linear function is least at a corner, so the least tax is at a point where two
of these lines cross, all of which are integers. `candidates` lists every such
crossing; the search keeps the feasible ones and takes the least tax.
`Optimal.lean` proves that this finds the least tax (`isLeastTax_taxExact`).
-/

/-- The constant-`x` lines. -/
def Income.xLines (rg : Regime) (i : Income) : List Int :=
  let A : Int := savingsAllowanceFor rg (i.total - i.allowanceUsed rg)
  let B : Int := rg.brl
  let H : Int := rg.hrl
  ([0, i.nonSavings, startingRateLimitSavings, B - A, H - A] : List Int)
    ++ (nsLimits rg).map (fun l : Nat => (l : Int))

/-- The constant-`w` lines. -/
def Income.wLines (rg : Regime) (i : Income) : List Int :=
  let T : Int := i.total - i.allowanceUsed rg
  let A : Int := savingsAllowanceFor rg (i.total - i.allowanceUsed rg)
  let L : Int := startingRateLimitSavings
  let DA : Int := dividendAllowance
  let B : Int := rg.brl
  let H : Int := rg.hrl
  [T, T - i.dividends, L, L + A, B, H, T - DA, B - DA, H - DA]

/-- The constant-`(w - x)` lines. -/
def Income.diagLines (rg : Regime) (i : Income) : List Int :=
  [0, i.savings, savingsAllowanceFor rg (i.total - i.allowanceUsed rg)]

/-- Every crossing of two lines, as `(x, w)`. -/
def Income.candidates (rg : Regime) (i : Income) : List (Int × Int) :=
  ((i.xLines rg).flatMap fun x => (i.wLines rg).map fun w => (x, w))
    ++ ((i.xLines rg).flatMap fun x => (i.diagLines rg).map fun e => (x, x + e))
    ++ ((i.wLines rg).flatMap fun w => (i.diagLines rg).map fun e => (w - e, w))

/-- Whether `(x, w)` is a legal share. -/
def Income.feasibleAt (rg : Regime) (i : Income) (p : Int × Int) : Bool :=
  let T : Int := i.total - i.allowanceUsed rg
  0 ≤ p.1 && p.1 ≤ i.nonSavings && p.1 ≤ p.2 && p.2 - p.1 ≤ i.savings
    && T - i.dividends ≤ p.2 && p.2 ≤ T

/-- The allowance share that leaves `(x, w)`. -/
def Income.allocAt (rg : Regime) (i : Income) (p : Int × Int) : Alloc :=
  let T : Int := i.total - i.allowanceUsed rg
  ⟨(i.nonSavings - p.1).toNat, (i.savings - (p.2 - p.1)).toNat,
    (i.dividends - (T - p.2)).toNat⟩

/-- The share of the allowance giving the least tax. -/
def Income.bestAlloc (rg : Regime) (i : Income) : Alloc :=
  (i.candidates rg).foldl
    (fun best p =>
      if i.feasibleAt rg p then
        let a := i.allocAt rg p
        if taxWith rg i a < taxWith rg i best then a else best
      else best)
    (i.inOrder rg)

/-- Exact liability in 1/10 000 pence. -/
def taxExact (rg : Regime) (i : Income) : Nat := taxWith rg i (i.bestAlloc rg)

/-- The Step 5 tax (no Step 5 amounts are modelled), in pence, rounded down to
the penny: the liability before the Step 6 tax reductions. -/
def liability (rg : Regime) (i : Income) : Nat := taxExact rg i / 10_000

/-! ## Step 6: tax reductions -/

/-- The highest non-savings income, as a position in Step 3 income, at which a
Marriage Allowance recipient is still liable only at the rates s55B(2)(b) allows:
the basic rate limit, or for a Scottish taxpayer the top of the intermediate rate. -/
def Regime.maLimit (rg : Regime) : Nat :=
  if rg.scottish then scotIntermediateLimit + rg.relief else rg.brl

/-- s55B(2)(b), (ba) for Step 3 income of `n` non-savings, `s` savings and `d`
dividends: no non-savings income above `maLimit`; no savings charged at a rate
above the savings basic rate (savings at the starting rate or the savings nil rate
are allowed wherever they sit); and, if there are dividends, none would be above
the basic rate limit with the dividend nil rate omitted. -/
def maRateTest (rg : Regime) (n s d : Nat) : Bool :=
  n ≤ rg.maLimit
    && (n + s ≤ rg.brl || n + s ≤ n + startingRateSavings n s + savingsNilRate rg n s d)
    && (d == 0 || n + s + d ≤ rg.brl)

/-- Whether a Marriage Allowance recipient passes the rate test, with the
allowance deducted as s25(2) asks. -/
def Income.maOk (rg : Regime) (i : Income) : Bool :=
  let a := i.bestAlloc rg
  maRateTest rg (i.nonSavings - a.toNonSavings) (i.savings - a.toSavings)
    (i.dividends - a.toDividends)

/-- The transferor's election stands only if, with their personal allowance
reduced by the transferable amount, they would be liable at no rate other than
those s55B(2)(b) allows, the dividends tested as if s13A were omitted (s55C(1)(c),
(ca): the same list and the same test as for the recipient). If it fails, no
election can be made and the allowance is not reduced. `Regime.maTransfer` is the
wish to elect; this is the regime that applies. Only the transferor's own side is
settled here: the partner's reduction is an input (`maReceive`). -/
def Income.settle (rg : Regime) (i : Income) : Regime :=
  if rg.maTransfer && !i.maOk rg then { rg with maTransfer := false } else rg

/-- The Marriage Allowance reduction, in 1/10 000 pence: 20 % of £1,260, £252
(s55B(1)), if received and the rate test is passed. -/
def Income.maReduction (rg : Regime) (i : Income) : Nat :=
  if rg.maReceive && i.maOk rg then maRate * maTransferable else 0

/-- The married couple's allowance reduction, in 1/10 000 pence: 10 % of the
maximum less half the excess of adjusted net income over £39,200, not below 10 %
of the minimum (s45, s46). -/
def Income.mcaReduction (rg : Regime) (i : Income) : Nat :=
  if rg.mca then
    max (mcaRate * mcaMin) (mcaRate * mcaMax - (mcaRate / 2) * (i.ani rg - mcaIncomeLimit))
  else 0

/-- The liability after the Step 6 reductions, in 1/10 000 pence: each only so far
as there is tax (s29(2)); with both deducted from one total, their order does not
change it. -/
def finalTaxExact (rg : Regime) (i : Income) : Nat :=
  taxExact rg i - (i.maReduction rg + i.mcaReduction rg)

/-- Income tax liability for 2026-27, in pence, rounded down to the penny. -/
def finalLiability (rg : Regime) (i : Income) : Nat := finalTaxExact rg i / 10_000

end UkTax
