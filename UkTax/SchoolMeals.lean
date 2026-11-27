import UkTax.CliffMap

/-!
# Free school lunches, England, 2026-27 (P9h)

A pupil is eligible for free school lunches (Education Act 1996 s512ZB(1), (2);
the request of (2)(b) is taken as made) if within s512ZB(4), (4A) or (4D):

* (4)(a)(ai), (b)(ai): the parent, or the pupil, is in receipt of Universal
  Credit and has earned income (UC Regs 2013 Part 6 Ch 2; a couple's combined) of
  no more than £616.67 in the assessment period before the request, or £1,233.34
  over the last two, or £1,850 over the last three (SI 2018/148 regs 2 to 4). With
  equal months the three tests give the same answer: earned income of at most
  £7,400.04 a year;
* (4)(a)(iii): the parent is in receipt of asylum support (Immigration and Asylum
  Act 1999 Part 6);
* (4)(aa)(i): the parent is in receipt of the guarantee credit of State Pension
  Credit (SI 2005/885, made under the former (4)(a)(iv) and kept in force under
  (aa) by the Child Poverty Act 2010 s26(2));
* (4A): a pupil in reception, year 1 or year 2 at a maintained school or pupil
  referral unit (universal infant free school meals);
* (4D), from 17 August 2026 (Children's Wellbeing and Schools Act 2026 s32; SI
  2026/803 reg 4): a pupil at a maintained school or pupil referral unit who, or
  whose parent, is in receipt of Universal Credit, whatever the earnings. Pupils
  at a maintained nursery school are treated the same from that day (SI 2026/706
  art 3).

Income support, income-based JSA, income-related ESA and the tax credits stopped
being routes on 31 March 2022 (Welfare Reform Act 2012 Sch 14 Part 1; SI 2018/145
art 2), and the transitional protection of SI 2018/145 art 3 ended on 17 August
2026 (SI 2026/813). Section 512ZB is about maintained schools and pupil referral
units; academies apply the same criteria through their funding agreements, not
legislation, and are taken to here.

So 2026-27 has two parts: 6 April to 16 August 2026, when the Universal Credit
route needs the earnings test, and 17 August 2026 to 5 April 2027, when it does
not. A meal has no statutory money value, so each pupil's lunches are an input
for each part, in pence (nil unless given; DfE funds universal infant meals at
£2.66 a meal for 2026-27, 190 meals a year, "Universal infant free school meals
(UIFSM): conditions of grant 2026 to 2027", which is a funding rate, not the
value to the family). The household's net income with them is `netAllFsm`.
"In receipt of Universal Credit" is an award above nil, as for the targeted
2-year-old hours.
-/

namespace UkTax

/-- A pupil for free school lunches. -/
structure Pupil where
  /-- In reception, year 1 or year 2 at a maintained school or pupil referral unit
  (s512ZB(4A)). -/
  infant : Bool := false
  /-- Eligible on a route other than the household's Universal Credit worked out
  here, all year: in receipt of a qualifying benefit in their own right. -/
  own : Bool := false
  /-- The money value of the pupil's lunches from 6 April to 16 August 2026, pence. -/
  before : Nat := 0
  /-- The money value of the pupil's lunches from 17 August 2026 to 5 April 2027, pence. -/
  after : Nat := 0
  deriving Repr

/-- The household's free school lunches: its pupils, and whether the parent is in
receipt of asylum support or the guarantee credit (s512ZB(4)(a)(iii), (aa)(i)). -/
structure Meals where
  pupils : List Pupil := []
  other : Bool := false
  deriving Repr

/-- The earnings test of SI 2018/148 reg 4 on a year's earned income `e`, 1/10 000
pence (a couple's combined), over twelve equal assessment periods. -/
def fsmEarningsOk (e : Int) : Bool := decide (e ≤ 10_000 * ((12 * fsmUcMonthlyLimit : Nat) : Int))

/-- Whether the pupil is eligible before 17 August 2026 (`u`: in receipt of UC with
the earnings test met) and from that day (`u'`: in receipt of UC). -/
def Pupil.eligibleBefore (m : Meals) (ch : Pupil) (u : Bool) : Bool := ch.own || m.other || ch.infant || u
def Pupil.eligibleAfter (m : Meals) (ch : Pupil) (u' : Bool) : Bool := ch.own || m.other || ch.infant || u'

/-- The value of a pupil's free lunches for the year, pence: `u` in receipt of UC,
`b` in receipt of it with the earnings test met. -/
def Pupil.value (m : Meals) (ch : Pupil) (u b : Bool) : Nat :=
  (if ch.eligibleBefore m b then ch.before else 0) + (if ch.eligibleAfter m u then ch.after else 0)

/-- The value of the household's free lunches for the year, pence. -/
def Meals.value (m : Meals) (u b : Bool) : Nat := (m.pupils.map fun ch => ch.value m u b).sum

/-- The value given the UC award (above nil or not) and earned income `e`
(1/10 000 pence, a couple's combined). -/
def Meals.valueFor (m : Meals) (onUc : Bool) (e : Int) : Nat := m.value onUc (onUc && fsmEarningsOk e)

/-- In receipt of Universal Credit at pay `g`: an award above nil. -/
def onUcAt (p : EarningsPeriod) (rg : Regime) (c : Claims) (s d g : Nat) : Bool :=
  decide (0 < ucAward rg.params c (earned p rg s d g))

/-- Earned income for the test at pay `g`, 1/10 000 pence: the claimant's, and a
joint claimant's partner's. -/
def fsmEarned (p : EarningsPeriod) (rg : Regime) (c : Claims) (s d g : Nat) : Int :=
  earned p rg s d g + (if c.couple then 10_000 * (c.partnerEarned : Int) else 0)

/-- The household's free lunches at pay `g`, pence. -/
def fsmAt (p : EarningsPeriod) (rg : Regime) (c : Claims) (m : Meals) (s d g : Nat) : Nat :=
  m.valueFor (onUcAt p rg c s d g) (fsmEarned p rg c s d g)

/-- Net income with benefits and free school lunches, 1/1 000 000 pence. -/
def netAllFsm (p : EarningsPeriod) (cb : Nat) (rg : Regime) (c : Claims) (m : Meals) (s d g : Nat) : Int :=
  netAll p cb rg c s d g + micro * (fsmAt p rg c m s d g : Int)

/-! ## Proved properties -/

theorem sum_map_le {α : Type} (l : List α) (f g : α → Nat) (h : ∀ x ∈ l, f x ≤ g x) :
    (l.map f).sum ≤ (l.map g).sum := by
  induction l with
  | nil => simp
  | cons a l ih =>
    simp only [List.map_cons, List.sum_cons]
    have := h a (List.mem_cons_self ..)
    have := ih (fun x hx => h x (List.mem_cons_of_mem _ hx))
    omega

/-- More routes never lose a pupil a lunch. -/
theorem Meals.value_mono (m : Meals) {u b u' b' : Bool} (hu : u = true → u' = true)
    (hb : b = true → b' = true) : m.value u b ≤ m.value u' b' := by
  unfold Meals.value
  apply sum_map_le
  intro ch _
  unfold Pupil.value Pupil.eligibleBefore Pupil.eligibleAfter
  generalize (ch.own || m.other || ch.infant) = z
  cases z <;> cases u <;> cases b <;> cases u' <;> cases b' <;> simp_all <;> omega

/-- **Where free lunches can be lost.** If a penny more pay lowers their value, the
Universal Credit award has just gone to nil, or (still on UC) earned income has
just gone over £7,400.04. -/
theorem fsm_loss_where {p : EarningsPeriod} {rg : Regime} {c : Claims} {m : Meals} {s d g : Nat}
    (h : fsmAt p rg c m s d (g + 1) < fsmAt p rg c m s d g) :
    (onUcAt p rg c s d g = true ∧ onUcAt p rg c s d (g + 1) = false) ∨
      (onUcAt p rg c s d g = true ∧ onUcAt p rg c s d (g + 1) = true ∧
        fsmEarningsOk (fsmEarned p rg c s d g) = true ∧
        fsmEarningsOk (fsmEarned p rg c s d (g + 1)) = false) := by
  unfold fsmAt Meals.valueFor at h
  generalize onUcAt p rg c s d g = u at *
  generalize onUcAt p rg c s d (g + 1) = u' at *
  generalize fsmEarningsOk (fsmEarned p rg c s d g) = k at *
  generalize fsmEarningsOk (fsmEarned p rg c s d (g + 1)) = k' at *
  cases u <;> cases u' <;> cases k <;> cases k' <;> simp at h ⊢
  all_goals first
    | (have := Meals.value_mono m (u := false) (b := false) (u' := false) (b' := false) (by simp) (by simp); omega)
    | (have := Meals.value_mono m (u := false) (b := false) (u' := true) (b' := false) (by simp) (by simp); omega)
    | (have := Meals.value_mono m (u := false) (b := false) (u' := true) (b' := true) (by simp) (by simp); omega)
    | (have := Meals.value_mono m (u := true) (b := false) (u' := true) (b' := false) (by simp) (by simp); omega)
    | (have := Meals.value_mono m (u := true) (b := false) (u' := true) (b' := true) (by simp) (by simp); omega)
    | (have := Meals.value_mono m (u := true) (b := true) (u' := true) (b' := true) (by simp) (by simp); omega)

/-- **Where net income with free lunches can fall.** A penny more pay lowers it only
at one of the steps of `netAll_drop_only_at_steps`, or where free lunches are lost
(`fsm_loss_where`: the UC award reaches nil, or earned income passes £7,400.04).
For every parameter set meeting `TaxParams.Valid`. -/
theorem netAllFsm_drop_only_at_steps (p : EarningsPeriod) (cb : Nat) {rg : Regime}
    (hP : rg.params.Valid) (c : Claims) (m : Meals) (s d g : Nat)
    (h : netAllFsm p cb rg c m s d (g + 1) < netAllFsm p cb rg c m s d g) :
    (PaStep rg.params (g + s + d - rg.step2 - rg.relief) ∨
      (0 < cb ∧ HicbcStep rg.params (g + s + d - rg.step2 - rg.relief)) ∨
      Income.step3 rg ⟨g, s, d⟩ = rg.brl ∨ Income.step3 rg ⟨g, s, d⟩ = rg.hrl ∨
      MaStep rg s d g ∨ g + s + d - rg.step2 - rg.relief = rg.params.ccLimit) ∨
    fsmAt p rg c m s d (g + 1) < fsmAt p rg c m s d g := by
  unfold netAllFsm micro at h
  by_cases hf : fsmAt p rg c m s d (g + 1) < fsmAt p rg c m s d g
  · exact Or.inr hf
  · left
    apply netAll_drop_only_at_steps p cb hP c s d g
    omega

/-- **The £7,400.04 line.** £7,400.04 of earned income a year (twelve months of
£616.67) passes the test, a penny more fails it. -/
theorem fsm_threshold :
    fsmEarningsOk (10_000 * 740_004) = true ∧ fsmEarningsOk (10_000 * 740_004 + 1) = false := by
  unfold fsmEarningsOk fsmUcMonthlyLimit; decide

/-- **The cliff at £7,400.04, for an example family.** Two pupils in years 3 to 11
with lunches valued at DfE's £2.66, 65 school days before 17 August and 125 after
(£172.90 and £332.50 each): on Universal Credit at £7,400.04 of earned income they
are worth £1,010.80 for 2026-27; a penny more and £665.00, so the cliff is £345.80
(two pupils' lunches from 6 April to 16 August). An infant keeps them (s512ZB(4A)).
When the UC award reaches nil the £665.00 goes too. -/
theorem fsm_cliff_example :
    let ch : Pupil := { before := 17_290, after := 33_250 }
    let m : Meals := { pupils := [ch, ch] }
    m.valueFor true (10_000 * 740_004) = 101_080 ∧
      m.valueFor true (10_000 * 740_004 + 1) = 66_500 ∧
      m.valueFor false 0 = 0 ∧
      ({ pupils := [{ ch with infant := true }] } : Meals).valueFor false 0 = 50_540 := by
  decide

/-! ## The cliff map with free lunches

Earned income is not monotone in pay (it falls where the personal allowance
tapers, and where the savings or Marriage Allowance steps raise tax), so where it
crosses £7,400.04, or where the UC award reaches nil, cannot be found by a binary
search on earned income itself. `fsmH` is a counter that never falls as pay
rises and goes up at every penny where free lunches are lost: three times
(three times the tax steps passed, plus the UC regions entered) plus the
lunches lost. Between tax steps earned income rises (`netAll_succ_ge`'s
argument), so within a UC region the award does not rise and the earnings test,
once failed, stays failed. Every penny where `fsmH` goes up is found by
`jumps`, a bisection that drops every interval on which `fsmH` is constant. -/

def ind (b : Bool) : Nat := if b then 1 else 0

/-- Tax steps passed by pay `g`: the personal allowance lost (pence), and Step 3
income past the basic and higher rate limits and the Marriage Allowance limit. -/
def fsmT (rg : Regime) (s d g : Nat) : Nat :=
  (personalAllowanceFor rg.params 0 - personalAllowanceFor rg.params (g + s + d - rg.step2 - rg.relief))
    + ind (decide (rg.brl < step3At rg s d g)) + ind (decide (rg.hrl < step3At rg s d g))
    + ind (decide (rg.maLimit < step3At rg s d g))

/-- The UC regions entered: earned income above nil (the childcare work condition)
and out of the benefit cap. -/
def fsmR (p : EarningsPeriod) (rg : Regime) (c : Claims) (s d g : Nat) : Nat :=
  ind (decide (0 < earned p rg s d g))
    + ind (!c.capApplies (earned p rg s d g + 10_000 * (c.partnerEarned : Int)))

/-- What is lost: being on UC, and the earnings test. -/
def fsmL (p : EarningsPeriod) (rg : Regime) (c : Claims) (s d g : Nat) : Nat :=
  ind (!onUcAt p rg c s d g) + ind (!(onUcAt p rg c s d g && fsmEarningsOk (fsmEarned p rg c s d g)))

def fsmH (p : EarningsPeriod) (rg : Regime) (c : Claims) (s d g : Nat) : Nat :=
  3 * (3 * fsmT rg s d g + fsmR p rg c s d g) + fsmL p rg c s d g

/-- Within one UC region (the same side of nil earned income and of the benefit
cap's earnings exception), more earned income never raises the award. -/
theorem ucAward_region_anti (P : TaxParams) (c : Claims) {e e' : Int} (h : e ≤ e')
    (h0 : decide (0 < e) = decide (0 < e'))
    (hc : c.capApplies (e + 10_000 * (c.partnerEarned : Int))
      = c.capApplies (e' + 10_000 * (c.partnerEarned : Int))) :
    ucAward P c e' ≤ ucAward P c e := by
  have hcc : c.childcareMicro e = c.childcareMicro e' := by
    unfold Claims.childcareMicro Claims.childcareWork; rw [h0]
  have hτ : (0 : Int) ≤ (P.ucTaper : Int) := Int.natCast_nonneg _
  have hX : max 0 (e + 10_000 * (c.partnerEarned : Int) - 10_000 * 12 * (c.workAllowance : Int))
      ≤ max 0 (e' + 10_000 * (c.partnerEarned : Int) - 10_000 * 12 * (c.workAllowance : Int)) := by
    omega
  have m1 := Int.mul_le_mul_of_nonneg_left hX hτ
  unfold ucAward
  split
  · dsimp only
    rw [hcc, hc]
    generalize (P.ucTaper : Int) * max 0 (e + 10_000 * (c.partnerEarned : Int)
      - 10_000 * 12 * (c.workAllowance : Int)) = TX at *
    generalize (P.ucTaper : Int) * max 0 (e' + 10_000 * (c.partnerEarned : Int)
      - 10_000 * 12 * (c.workAllowance : Int)) = TX' at *
    split <;> omega
  · omega

theorem ind_le_one (b : Bool) : ind b ≤ 1 := by unfold ind; split <;> omega

theorem ind_mono {a b : Bool} (h : a = true → b = true) : ind a ≤ ind b := by
  unfold ind; cases a <;> cases b <;> simp_all

/-- Tax steps passed never fall as pay rises; where none is passed, the personal
allowance, the savings allowance and the Marriage Allowance reduction are
unchanged. -/
theorem fsmT_succ {rg : Regime} {s d : Nat} (hS : CliffScope rg s d) (g : Nat) :
    fsmT rg s d g ≤ fsmT rg s d (g + 1) ∧
      (fsmT rg s d (g + 1) = fsmT rg s d g →
        personalAllowanceFor rg.params (g + 1 + s + d - rg.step2 - rg.relief)
            = personalAllowanceFor rg.params (g + s + d - rg.step2 - rg.relief) ∧
          Income.psa rg ⟨g + 1, s, d⟩ = Income.psa rg ⟨g, s, d⟩ ∧
          Income.maReduction rg ⟨g + 1, s, d⟩ = Income.maReduction rg ⟨g, s, d⟩) := by
  have hA0 := personalAllowanceFor_anti rg.params (x := 0) (x' := g + s + d - rg.step2 - rg.relief) (by omega)
  have hA1 := personalAllowanceFor_anti rg.params (x := g + s + d - rg.step2 - rg.relief)
    (x' := g + 1 + s + d - rg.step2 - rg.relief) (by omega)
  have hs := step3At_mono rg s d g (g + 1) (by omega)
  have i1 := ind_mono (a := decide (rg.brl < step3At rg s d g)) (b := decide (rg.brl < step3At rg s d (g + 1)))
    (by simp only [decide_eq_true_eq]; omega)
  have i2 := ind_mono (a := decide (rg.hrl < step3At rg s d g)) (b := decide (rg.hrl < step3At rg s d (g + 1)))
    (by simp only [decide_eq_true_eq]; omega)
  have i3 := ind_mono (a := decide (rg.maLimit < step3At rg s d g)) (b := decide (rg.maLimit < step3At rg s d (g + 1)))
    (by simp only [decide_eq_true_eq]; omega)
  unfold fsmT
  refine ⟨by omega, fun hT => ?_⟩
  have hPA : personalAllowanceFor rg.params (g + 1 + s + d - rg.step2 - rg.relief)
      = personalAllowanceFor rg.params (g + s + d - rg.step2 - rg.relief) := by omega
  have e1 : ind (decide (rg.brl < step3At rg s d (g + 1))) = ind (decide (rg.brl < step3At rg s d g)) := by omega
  have e2 : ind (decide (rg.hrl < step3At rg s d (g + 1))) = ind (decide (rg.hrl < step3At rg s d g)) := by omega
  have e3 : ind (decide (rg.maLimit < step3At rg s d (g + 1)))
      = ind (decide (rg.maLimit < step3At rg s d g)) := by omega
  refine ⟨hPA, ?_, ?_⟩
  · rcases psa_succ_cross hPA with h | h | h
    · exact h
    · unfold ind at e1; simp only [decide_eq_true_eq] at e1
      split at e1 <;> split at e1 <;> omega
    · unfold ind at e2; simp only [decide_eq_true_eq] at e2
      split at e2 <;> split at e2 <;> omega
  · rcases hS with ⟨_, hR | ⟨rfl, rfl⟩⟩
    · unfold Income.maReduction; simp [hR]
    · have k1 := maOk_payOnly rg g
      have k2 := maOk_payOnly rg (g + 1)
      have : Income.maOk rg ⟨g + 1, 0, 0⟩ = Income.maOk rg ⟨g, 0, 0⟩ := by
        unfold step3At at e3
        unfold ind at e3; simp only [decide_eq_true_eq] at e3
        cases h1 : Income.maOk rg ⟨g + 1, 0, 0⟩ <;> cases h2 : Income.maOk rg ⟨g, 0, 0⟩ <;> simp_all <;>
          split at e3 <;> split at e3 <;> omega
      unfold Income.maReduction; rw [this]

/-- **The counter never falls, and goes up wherever free lunches are lost.** -/
theorem fsmH_succ {p : EarningsPeriod} {rg : Regime} (hP : rg.params.Valid) {c : Claims} (m : Meals)
    {s d : Nat} (hS : CliffScope rg s d) (g : Nat) :
    fsmH p rg c s d g ≤ fsmH p rg c s d (g + 1) ∧
      (fsmAt p rg c m s d (g + 1) < fsmAt p rg c m s d g → fsmH p rg c s d g < fsmH p rg c s d (g + 1)) := by
  obtain ⟨hT, hTe⟩ := fsmT_succ hS g
  have hR0 : fsmR p rg c s d g ≤ 2 := by
    unfold fsmR; have := ind_le_one (decide (0 < earned p rg s d g))
    have := ind_le_one (!c.capApplies (earned p rg s d g + 10_000 * (c.partnerEarned : Int))); omega
  have hL0 : fsmL p rg c s d g ≤ 2 := by
    unfold fsmL; have := ind_le_one (!onUcAt p rg c s d g)
    have := ind_le_one (!(onUcAt p rg c s d g && fsmEarningsOk (fsmEarned p rg c s d g))); omega
  unfold fsmH
  by_cases hTs : fsmT rg s d (g + 1) = fsmT rg s d g
  · obtain ⟨hPA, hPSA, hMA⟩ := hTe hTs
    -- no tax step: earned income rises
    have htax := finalTaxExact_succ_le hP hPA hPSA hMA
    have hnic := nicExact_succ_le rg.params p (g + rg.netPay)
    rw [show g + rg.netPay + 1 = g + 1 + rg.netPay by omega] at hnic
    have hmg := Regime.minGain_eq hP
    have hearn : earned p rg s d g ≤ earned p rg s d (g + 1) := by
      unfold earned
      generalize finalTaxExact rg ⟨g, s, d⟩ = A at *
      generalize finalTaxExact rg ⟨g + 1, s, d⟩ = A' at *
      generalize nicExact rg.params p (g + rg.netPay) = B at *
      generalize nicExact rg.params p (g + 1 + rg.netPay) = B' at *
      omega
    have r1 := ind_mono (a := decide (0 < earned p rg s d g)) (b := decide (0 < earned p rg s d (g + 1)))
      (by simp only [decide_eq_true_eq]; omega)
    have r2 := ind_mono (a := !c.capApplies (earned p rg s d g + 10_000 * (c.partnerEarned : Int)))
      (b := !c.capApplies (earned p rg s d (g + 1) + 10_000 * (c.partnerEarned : Int))) (by
        intro h1
        simp only [Bool.not_eq_true'] at *
        cases h2 : c.capApplies (earned p rg s d (g + 1) + 10_000 * (c.partnerEarned : Int))
        · rfl
        · rw [capApplies_anti c (by omega) h2] at h1; exact h1)
    have hR : fsmR p rg c s d g ≤ fsmR p rg c s d (g + 1) := by unfold fsmR; omega
    by_cases hRs : fsmR p rg c s d (g + 1) = fsmR p rg c s d g
    · -- the same UC region: the award does not rise, the test once failed stays failed
      have hz : decide (0 < earned p rg s d g) = decide (0 < earned p rg s d (g + 1)) := by
        unfold fsmR at hRs
        unfold ind at r1 r2 hRs
        revert r1 r2 hRs
        cases decide (0 < earned p rg s d g) <;> cases decide (0 < earned p rg s d (g + 1)) <;>
          cases c.capApplies (earned p rg s d g + 10_000 * (c.partnerEarned : Int)) <;>
          cases c.capApplies (earned p rg s d (g + 1) + 10_000 * (c.partnerEarned : Int)) <;> simp
      have hc : c.capApplies (earned p rg s d g + 10_000 * (c.partnerEarned : Int))
          = c.capApplies (earned p rg s d (g + 1) + 10_000 * (c.partnerEarned : Int)) := by
        unfold fsmR at hRs
        unfold ind at r1 r2 hRs
        revert r1 r2 hRs
        cases decide (0 < earned p rg s d g) <;> cases decide (0 < earned p rg s d (g + 1)) <;>
          cases c.capApplies (earned p rg s d g + 10_000 * (c.partnerEarned : Int)) <;>
          cases c.capApplies (earned p rg s d (g + 1) + 10_000 * (c.partnerEarned : Int)) <;> simp
      have haw := ucAward_region_anti rg.params c hearn hz hc
      have hu : onUcAt p rg c s d (g + 1) = true → onUcAt p rg c s d g = true := by
        unfold onUcAt; simp only [decide_eq_true_eq]; omega
      have hk : fsmEarningsOk (fsmEarned p rg c s d (g + 1)) = true →
          fsmEarningsOk (fsmEarned p rg c s d g) = true := by
        unfold fsmEarningsOk fsmEarned; simp only [decide_eq_true_eq]; split <;> omega
      unfold fsmL fsmAt Meals.valueFor
      generalize onUcAt p rg c s d g = u at *
      generalize onUcAt p rg c s d (g + 1) = u' at *
      generalize fsmEarningsOk (fsmEarned p rg c s d g) = k at *
      generalize fsmEarningsOk (fsmEarned p rg c s d (g + 1)) = k' at *
      rw [hTs, hRs]
      cases u <;> cases u' <;> cases k <;> cases k' <;> simp_all [ind]
    · have : fsmR p rg c s d g + 1 ≤ fsmR p rg c s d (g + 1) := by omega
      constructor <;> intros <;> omega
  · have : fsmT rg s d g + 1 ≤ fsmT rg s d (g + 1) := by omega
    constructor <;> intros <;> omega

theorem fsmH_mono {p : EarningsPeriod} {rg : Regime} (hP : rg.params.Valid) (c : Claims)
    {s d : Nat} (hS : CliffScope rg s d) : ∀ a b, a ≤ b → fsmH p rg c s d a ≤ fsmH p rg c s d b := by
  intro a b h
  obtain ⟨k, rfl⟩ := Nat.exists_eq_add_of_le h
  induction k with
  | zero => exact Nat.le_refl _
  | succ k ih => exact Nat.le_trans (ih (Nat.le_add_right a k)) ((fsmH_succ hP {} hS (a + k)).1)

/-- Every `x` in `[lo, hi)` at which a monotone `f` goes up: bisection, dropping any
interval whose ends `same` says are equal under `f`. -/
def jumps (same : Nat → Nat → Bool) (lo hi : Nat) : List Nat :=
  if lo < hi then
    if same lo hi then []
    else if lo + 1 = hi then [lo]
    else jumps same lo ((lo + hi) / 2) ++ jumps same ((lo + hi) / 2) hi
  else []
termination_by hi - lo

theorem mem_jumps (f : Nat → Nat) (hf : ∀ a b, a ≤ b → f a ≤ f b) (same : Nat → Nat → Bool)
    (hs : ∀ a b, same a b = true → f a = f b) (lo hi x : Nat)
    (h1 : lo ≤ x) (h2 : x + 1 ≤ hi) (h3 : f x < f (x + 1)) : x ∈ jumps same lo hi := by
  rw [jumps]
  have hlo := hf lo x h1
  have hhi := hf (x + 1) hi h2
  have hlt : lo < hi := by omega
  have hne : same lo hi = false := by
    cases h : same lo hi
    · rfl
    · have := hs lo hi h; omega
  simp only [hlt, hne, ↓reduceIte, Bool.false_eq_true]
  split
  · have : x = lo := by omega
    rw [this]; exact List.mem_singleton.2 rfl
  · by_cases hm : x + 1 ≤ (lo + hi) / 2
    · exact List.mem_append_left _ (mem_jumps f hf same hs lo _ x h1 hm h3)
    · exact List.mem_append_right _ (mem_jumps f hf same hs _ hi x (by omega) h2 h3)
termination_by hi - lo

/-- `fsmH` with earned income worked out once (it is the costly part). -/
def fsmHc (p : EarningsPeriod) (rg : Regime) (c : Claims) (s d g : Nat) : Nat :=
  let e := earned p rg s d g
  let u := decide (0 < ucAward rg.params c e)
  3 * (3 * fsmT rg s d g + (ind (decide (0 < e)) + ind (!c.capApplies (e + 10_000 * (c.partnerEarned : Int)))))
    + (ind (!u) + ind (!(u && fsmEarningsOk (e + (if c.couple then 10_000 * (c.partnerEarned : Int) else 0)))))

theorem fsmHc_eq (p : EarningsPeriod) (rg : Regime) (c : Claims) (s d g : Nat) :
    fsmHc p rg c s d g = fsmH p rg c s d g := rfl

/-- `fsmAt` with earned income worked out once. -/
def fsmAtc (p : EarningsPeriod) (rg : Regime) (c : Claims) (m : Meals) (s d g : Nat) : Nat :=
  let e := earned p rg s d g
  m.valueFor (decide (0 < ucAward rg.params c e)) (e + (if c.couple then 10_000 * (c.partnerEarned : Int) else 0))

theorem fsmAtc_eq (p : EarningsPeriod) (rg : Regime) (c : Claims) (m : Meals) (s d g : Nat) :
    fsmAtc p rg c m s d g = fsmAt p rg c m s d g := rfl

/-- Equal counters at two pays. The tax steps are compared first: they are cheap,
and where they differ so do the counters, so the earned income (the costly part)
is only worked out inside a run with no tax step. -/
def fsmSame (p : EarningsPeriod) (rg : Regime) (c : Claims) (s d a b : Nat) : Bool :=
  decide (fsmT rg s d a = fsmT rg s d b) && decide (fsmHc p rg c s d a = fsmHc p rg c s d b)

/-- The pennies below `maxPay` where free lunches are lost (none if they are worth
nothing): the counter's jumps at which their value falls. -/
def fsmPennies (p : EarningsPeriod) (rg : Regime) (c : Claims) (m : Meals) (s d maxPay : Nat) : List Nat :=
  if m.value true true = 0 then []
  else (jumps (fsmSame p rg c s d) 0 maxPay).filter
    fun g => decide (fsmAtc p rg c m s d (g + 1) < fsmAtc p rg c m s d g)

theorem fsmAt_le (p : EarningsPeriod) (rg : Regime) (c : Claims) (m : Meals) (s d g : Nat) :
    fsmAt p rg c m s d g ≤ m.value true true := by
  unfold fsmAt Meals.valueFor
  exact Meals.value_mono m (by simp) (by simp)

/-- **The cliff map with free lunches is complete.** For every parameter set meeting
`TaxParams.Valid`, every household in scope and every pay `g` below `maxPay`: if a
penny more pay lowers net income with free school lunches, `g` is in the personal
allowance band, among the other listed pennies, or among the pennies where free
lunches can be lost. -/
theorem cliffMapFsm_complete (p : EarningsPeriod) (cb : Nat) {rg : Regime} (hP : rg.params.Valid)
    (c : Claims) (m : Meals) {s d : Nat} (hS : CliffScope rg s d) {maxPay g : Nat} (hg : g < maxPay)
    (h : netAllFsm p cb rg c m s d (g + 1) < netAllFsm p cb rg c m s d g) :
    g ∈ paPennies rg s d ∨ g ∈ (oneOffPennies cb rg s d maxPay).map Prod.fst ∨
      g ∈ fsmPennies p rg c m s d maxPay := by
  unfold netAllFsm micro at h
  by_cases hf : fsmAt p rg c m s d (g + 1) < fsmAt p rg c m s d g
  · right; right
    have hpos := fsmAt_le p rg c m s d g
    unfold fsmPennies
    have h0 : m.value true true ≠ 0 := by omega
    simp only [h0, ↓reduceIte]
    refine List.mem_filter.2 ⟨mem_jumps _ (fsmH_mono hP c hS) _ (fun a b h => ?_) 0 maxPay g (by omega) hg
      ((fsmH_succ hP m hS g).2 hf), by simp [fsmAtc_eq, hf]⟩
    unfold fsmSame at h
    simp only [Bool.and_eq_true, decide_eq_true_eq] at h
    rw [← fsmHc_eq, ← fsmHc_eq]; exact h.2
  · have := cliffMap_complete p cb hP c hS hg (by omega)
    rcases this with h1 | h1
    · exact Or.inl h1
    · exact Or.inr (Or.inl h1)

/-! ## Evaluating the map with free lunches -/

def dropAtFsm (p : EarningsPeriod) (cb : Nat) (rg : Regime) (c : Claims) (m : Meals) (s d g : Nat) : Int :=
  netAllFsm p cb rg c m s d g - netAllFsm p cb rg c m s d (g + 1)

/-- The drops at the one-off pennies and the free-lunch pennies below `maxPay`, by
pay. -/
def oneOffDropsFsm (p : EarningsPeriod) (cb : Nat) (rg : Regime) (c : Claims) (m : Meals) (s d maxPay : Nat) :
    List Drop :=
  let found := ((oneOffPennies cb rg s d maxPay) ++ (fsmPennies p rg c m s d maxPay).map (·, StepKind.schoolMeals)).filterMap
    fun (g, k) =>
      if g < maxPay then
        let x := dropAtFsm p cb rg c m s d g
        if 0 < x then some ⟨g, k, x⟩ else none
      else none
  found.foldr insertDrop []

def bandSummaryFsm (p : EarningsPeriod) (cb : Nat) (rg : Regime) (c : Claims) (m : Meals) (s d maxPay : Nat) :
    Option BandSummary :=
  let l := bandPennies rg s d maxPay
  match l.head?, l.getLast? with
  | some hi, some lo => some ⟨lo, hi, l.length, dropAtFsm p cb rg c m s d lo, dropAtFsm p cb rg c m s d hi⟩
  | _, _ => none

def bandDropsFsm (p : EarningsPeriod) (cb : Nat) (rg : Regime) (c : Claims) (m : Meals) (s d maxPay : Nat) :
    List Drop :=
  ((bandPennies rg s d maxPay).filterMap fun g =>
    let x := dropAtFsm p cb rg c m s d g
    if 0 < x then some ⟨g, .personalAllowance, x⟩ else none).reverse

/-- **What `uktax` reports with free lunches is complete.** -/
theorem dropsFsm_complete (p : EarningsPeriod) (cb : Nat) {rg : Regime} (hP : rg.params.Valid)
    (c : Claims) (m : Meals) {s d : Nat} (hS : CliffScope rg s d) {maxPay g : Nat} (hg : g < maxPay)
    (h : netAllFsm p cb rg c m s d (g + 1) < netAllFsm p cb rg c m s d g) :
    g ∈ bandPennies rg s d maxPay ∨ ∃ x ∈ oneOffDropsFsm p cb rg c m s d maxPay, x.pay = g := by
  have hd : 0 < dropAtFsm p cb rg c m s d g := by unfold dropAtFsm; omega
  have key : ∀ k, (g, k) ∈ (oneOffPennies cb rg s d maxPay)
      ++ (fsmPennies p rg c m s d maxPay).map (·, StepKind.schoolMeals) →
      ∃ x ∈ oneOffDropsFsm p cb rg c m s d maxPay, x.pay = g := by
    intro k hk
    have hm : (⟨g, k, dropAtFsm p cb rg c m s d g⟩ : Drop) ∈
        ((oneOffPennies cb rg s d maxPay) ++ (fsmPennies p rg c m s d maxPay).map (·, StepKind.schoolMeals)).filterMap
        fun (g, k) => if g < maxPay then
          (let x := dropAtFsm p cb rg c m s d g; if 0 < x then some (⟨g, k, x⟩ : Drop) else none)
          else none := by
      rw [List.mem_filterMap]
      exact ⟨(g, k), hk, by simp [hg, hd]⟩
    exact mem_foldr_insertDrop _ _ hm
  rcases cliffMapFsm_complete p cb hP c m hS hg h with hp | ho | hf
  · left
    exact mem_dedupAdj _ _ (List.mem_filter.2 ⟨hp, by simp [hg]⟩)
  · right
    obtain ⟨⟨g', k⟩, hk, rfl⟩ := List.mem_map.1 ho
    exact key k (List.mem_append_left _ hk)
  · right
    exact key .schoolMeals (List.mem_append_right _ (List.mem_map.2 ⟨g, hf, rfl⟩))

end UkTax
