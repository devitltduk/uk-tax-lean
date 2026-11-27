import UkTax.CtrWorkingAge

/-!
# Council Tax Reduction: the English local working-age schemes (P7b)

The five schemes PolicyEngine models (`Params.lean` cites each council's 2026-27
text).

* **Kingston upon Thames, Merton, Newham, Westminster** follow the default scheme
  (SI 2012/2886) by the day: the maximum is `maxPct` % of the day's council tax less
  the non-dependant deductions × 1/7 (para 29); a person whose income exceeds the
  applicable amount loses `taper`/7 % a day of the week's excess (para 17: 2 6/7 %,
  Newham 3 4/7 %). Without UC the applicable amount is the council's personal
  allowance and an amount for each child (Sch 3; Kingston none for a third or later
  child born after 1 April 2017); income is net earnings less the Housing Benefit
  disregards (Sch 7), other income, and tariff income of £1 a week per £250 or part
  above £6,000; Child Benefit is disregarded (Sch 8). With UC (paras 28, 37) the
  applicable amount and income are the UC maximum amount and the UC income plus the
  award, × 12/52, as in Wales (`walesUcExcess`).
* **Oxford** bands income: 100 %, 75 %, 50 %, 25 % or nil of the day's tax by weekly
  income, less the non-dependant deductions. Without UC income is net earnings (no
  disregards, Appendix 4), other income and tariff income; with UC, DWP's net earned
  income, the award and other unearned income, less £48.15 of each carer element and
  £84.46 of each disabled child element (Appendix 3).

Amounts are in units of 1/36 400 000 000 of a penny (`lcu`): `taper` % of a week's
excess over 365 days is 365 × taper/(7 × 100) weeks, and 36 400 000 000 =
52 × 7 × 100 × 1 000 000.

Not modelled: premiums and components (the councils print their own amounts),
self-employment, childcare charges, the alternative maximum (second adult)
reduction of class F, joint liability.
-/

namespace UkTax

/-- 1/36 400 000 000 of a penny per penny. -/
def lcu : Int := 36_400_000_000

inductive LocalAuthority where
  | kingston | merton | newham | westminster | oxford
  deriving Repr, DecidableEq

/-- A default-scheme council's parameters. -/
structure LocalScheme where
  /-- Percent of the day's tax that is the maximum (para 29). -/
  maxPct : Nat
  /-- Percent of the week's excess income withdrawn (amount B × 7). -/
  taper : Nat
  capitalLimit : Nat
  /-- Personal allowances, pence a week: single 25 or over, single under 25, lone
  parent, couple. -/
  personal : List Nat
  child : Nat
  /-- Non-dependant deductions, pence a week (lowest first), and the income bands. -/
  nonDeps : List Nat
  nonDepBands : List Nat

/-- The scheme of each council (`Params.lean`). -/
def LocalAuthority.scheme : LocalAuthority → LocalScheme
  | .kingston => ⟨100, 20, hbCapitalLimit, kingstonPersonal, kingstonChild, kingstonNonDeps, localNonDepBands⟩
  | .merton => ⟨100, 20, hbCapitalLimit, [hbWaSingle25, hbWaSingleU25, hbWaLoneParent, hbWaCouple], hbChild,
      mertonNonDeps, localNonDepBands⟩
  | .newham => ⟨70, 25, newhamCapitalLimit, [hbWaSingle25, hbWaSingleU25, hbWaLoneParent, hbWaCouple], hbChild,
      newhamNonDeps, newhamNonDepBands⟩
  | .westminster => ⟨100, 20, hbCapitalLimit, [hbWaSingle25, hbWaSingleU25, hbWaLoneParent, hbWaCouple], hbChild,
      mertonNonDeps, localNonDepBands⟩
  | .oxford => ⟨100, 0, hbCapitalLimit, [], 0, mertonNonDeps, localNonDepBands⟩

/-- One non-dependant's deduction, pence a week: the lowest unless in remunerative
work, then by normal gross weekly income. -/
def LocalScheme.nonDep (s : LocalScheme) (nd : NonDep) : Nat :=
  let k := if !nd.working then 0 else (s.nonDepBands.filter (· ≤ nd.grossWeekly)).length
  s.nonDeps.getD (min k 3) 0

/-- The week's deductions (none where the applicant is exempt). -/
def LocalScheme.nonDepTotal (s : LocalScheme) (h : HbClaim) : Nat :=
  if h.nonDepExempt then 0 else (h.nonDeps.map s.nonDep).sum

/-- The applicable amount without UC, pence a week: the personal allowance and an
amount for each child, less `limited` children with none (Kingston's limit). -/
def LocalScheme.applicable (s : LocalScheme) (h : HbWaClaim) (limited : Nat) : Nat :=
  s.personal.getD (if h.couple then 3 else if h.lone then 2 else if h.under25 then 1 else 0) 0
    + (h.children - limited) * s.child

/-- Without UC: the year's excess income (1/1 000 000 pence, 52 weeks) on net
earnings `E` (1/10 000 pence a year). -/
def localOwnExcess (s : LocalScheme) (h : HbWaClaim) (limited : Nat) (E : Int) : Int :=
  100 * (hbWaEarningsAfter h.additionalDisregard h.disregard.weekly E
    + 10_000 * 52 * ((h.otherWeekly + hbWaTariff h.capital : Nat) : Int)
    - 10_000 * 52 * (s.applicable h limited : Int))

/-- The year's withdrawal, `lcu`: 365/7 weeks of the deductions `nd` and of `taper`
% of the excess `x`. -/
def localWithdrawal (s : LocalScheme) (nd : Nat) (x : Int) : Int :=
  365 * 5_200_000_000 * (nd : Int) + 365 * (s.taper : Int) * max 0 x

/-- The year's reduction, `lcu`, on a bill of `ct` pence. -/
def localYear (s : LocalScheme) (ct nd : Nat) (x : Int) : Int :=
  max 0 (364_000_000 * (s.maxPct : Int) * ct - localWithdrawal s nd x)

/-! ## Oxford -/

/-- Oxford's percentage for a year's income `x` (1/1 000 000 pence, 52 weeks): the
band whose upper limit the week's income does not exceed (the bands run to £480.00,
£530.00, £580.00, £660.00; a week's income between two printed limits, such as
£480.004, belongs to the higher band). -/
def oxfordPct (x : Int) : Nat :=
  if x ≤ 52_000_000 * (48_000 : Int) then 100 else if x ≤ 52_000_000 * (53_000 : Int) then 75
  else if x ≤ 52_000_000 * (58_000 : Int) then 50 else if x ≤ 52_000_000 * (66_000 : Int) then 25 else 0

/-- Oxford without UC: the year's income, 1/1 000 000 pence: net earnings `E`
(1/10 000 pence a year) in full, other income and tariff income. -/
def oxfordOwnIncome (h : HbWaClaim) (E : Int) : Int :=
  100 * (E + 10_000 * 52 * ((h.otherWeekly + hbWaTariff h.capital : Nat) : Int))

/-- Oxford with UC (Appendix 3): the earned income, the award, and "all other
unearned income" (UC unearned income, Carer's Allowance, and Child Benefit of `cb`
pence a week, which Appendix 3 does not ignore: the Child Benefit disregard of
Appendix 5 is only for applicants without UC), less £48.15 a week of each carer
element and £84.46 of each disabled child element. -/
def oxfordUcIncome (P : TaxParams) (c : Claims) (cb : Nat) (e : Int) : Int :=
  100 * (e + 10_000 * (c.partnerEarned : Int)) + 12 * (micro * (c.unearnedMonthly : Int))
    + 52 * micro * (cb : Int)
    + micro * (c.carersAllowanceYear : Int) + ucAward P c e
    - 52 * micro * ((c.carerCount * oxfordCarerDisregard
        + (c.disabledLower + c.disabledHigher) * oxfordDisabledChildDisregard : Nat) : Int)

/-- Oxford: the year's reduction, `lcu`: the band's percentage of the bill less 365/7
weeks of the deductions. -/
def oxfordYear (ct nd : Nat) (x : Int) : Int :=
  max 0 (364_000_000 * (oxfordPct x : Int) * ct - 365 * 5_200_000_000 * (nd : Int))

/-! ## Proved properties -/

/-- **Newham pays at most 70 % of the bill** to a working-age applicant, whatever the
income. -/
theorem newham_at_most_70 (ct nd : Nat) (x : Int) :
    localYear LocalAuthority.newham.scheme ct nd x ≤ 364_000_000 * 70 * (ct : Int) := by
  unfold localYear localWithdrawal LocalAuthority.scheme
  dsimp only
  omega

/-- On the taper, each unit of excess income costs at most `taper` % of it for 365/7
weeks, and more income never raises the reduction. -/
theorem localYear_taper (s : LocalScheme) (ct nd : Nat) (x δ : Int) (hδ : 0 ≤ δ) :
    localYear s ct nd (x + δ) ≤ localYear s ct nd x ∧
      localYear s ct nd x ≤ localYear s ct nd (x + δ) + 365 * (s.taper : Int) * δ := by
  unfold localYear localWithdrawal
  have h1 : max 0 x ≤ max 0 (x + δ) := by omega
  have h2 : max 0 (x + δ) ≤ max 0 x + δ := by omega
  have h3 : 365 * (s.taper : Int) * max 0 x ≤ 365 * (s.taper : Int) * max 0 (x + δ) :=
    Int.mul_le_mul_of_nonneg_left h1 (by omega)
  have h4 : 365 * (s.taper : Int) * max 0 (x + δ) ≤ 365 * (s.taper : Int) * max 0 x + 365 * (s.taper : Int) * δ := by
    rw [← Int.mul_add]; exact Int.mul_le_mul_of_nonneg_left h2 (by omega)
  constructor <;> omega

/-- **Oxford's cliffs.** With no non-dependants, a penny of weekly income above
£480.00 costs a quarter of the bill: the reduction falls from the whole bill to
three quarters of it. The same quarter is lost at £530.00, £580.00 and £660.00. -/
theorem oxford_cliff_480 (ct : Nat) :
    oxfordYear ct 0 (52_000_000 * 48_000) = 364_000_000 * 100 * (ct : Int) ∧
      oxfordYear ct 0 (52_000_000 * 48_001) = 364_000_000 * 75 * (ct : Int) := by
  unfold oxfordYear oxfordPct
  constructor <;> simp <;> omega

/-- Oxford's percentage never rises with income. -/
theorem oxfordPct_anti (x y : Int) (hxy : x ≤ y) : oxfordPct y ≤ oxfordPct x := by
  unfold oxfordPct
  repeat' split
  all_goals omega

/-- Oxford's income test has no taper: more income never raises the reduction. -/
theorem oxford_mono (ct nd : Nat) (x y : Int) (hxy : x ≤ y) : oxfordYear ct nd y ≤ oxfordYear ct nd x := by
  unfold oxfordYear
  have hp := oxfordPct_anti x y hxy
  have h2 : 364_000_000 * (oxfordPct y : Int) * ct ≤ 364_000_000 * (oxfordPct x : Int) * ct :=
    Int.mul_le_mul_of_nonneg_right (by omega) (by omega)
  omega

end UkTax
