import UkTax.Cliffs

/-!
# Non-means-tested benefits, 2026-27 (P5a)

* **Child Benefit** (`childBenefitFor`, `UkTax/Charges.lean`) for a whole year of
  2026-27 is 53 weeks (`childBenefitWeeks`): a Child Benefit week begins on a
  Monday (SSCBA 1992 s147(1)) and 2026-27 has 53 Mondays. The High Income Child
  Benefit Charge counts the same weeks (ITEPA 2003 s681H(3)).
* **PIP, DLA and Attendance Allowance**: the weekly rate of each component, for
  52 weeks (`benefitWeeks`). Who qualifies for which rate is an assessment, so the
  rate is an input; DLA mobility needs the age conditions of SSCBA 1992 s73(1A)
  (3 for the higher rate, 5 for the lower), which the caller applies.
* **Carer's Allowance** (SSCBA 1992 s70): £86.45 a week for someone caring for at
  least 35 hours a week for a person getting a qualifying disability benefit,
  aged 16 or over and not in full-time education (the caller says whether those
  hold), unless their net earnings in the week before exceeded £204 (SI 1976/409
  reg 8(1)), less any overlapping benefit such as the State Pension (SI 1979/597
  reg 12). Net earnings are gross pay less income tax, primary Class 1 and half
  the pension contributions (SI 1996/2745 reg 10(4)). Pay is taken as equal each
  week, so a week's net earnings are the year's ÷ 52, a fraction of a penny
  disregarded (reg 5, to the claimant's advantage); the tax is the liability on
  the pay alone (what PAYE takes on a standard code). Care charges (reg 10(3),
  Sch 3) are not deducted.
* **Maternity Allowance** (s35A): the lower of 90 % of average weekly earnings and
  £194.32, if average weekly earnings reach the £30 threshold (s35(1)(c)).
* **New style JSA** (SI 2013/378 regs 49-52): the age-related amount less weekly
  earnings above £5 and pension payments above £50; nothing if under 10p.
* **New style ESA** (SI 2013/379 regs 62, 67): £95.55 (£75.65 under 25 in the
  assessment phase), plus £50.35 in the support group, less half of pension
  payments above £85 a week.
* **Sure Start Maternity Grant** (SI 2005/3061 regs 5, 5A): £500 a baby for a
  claimant getting a qualifying benefit, if no other member of the family is
  under 16 (the multiple-birth and refugee exceptions of reg 5A are not modelled).

`netCarer` is net income for a carer: Carer's Allowance is taxable (ITEPA 2003
s660, Table A) and so is added to non-savings income for income tax, but carries
no NICs. `netCarer_drop_only_at_steps` extends the cliff theorem: earning a penny
more lowers it only at one of the steps of `net_drop_only_at_steps` (with the
allowance added to income) or where weekly net earnings pass £204, where the whole
allowance is lost at once (`caYear_cliff`).
-/

namespace UkTax

/-- A rate of a PIP component. -/
inductive PipRate where
  | none
  | standard
  | enhanced
  deriving DecidableEq, Repr

/-- A rate of the DLA care component. -/
inductive DlaCare where
  | none
  | lowest
  | middle
  | highest
  deriving DecidableEq, Repr

/-- A rate of the DLA mobility component. -/
inductive DlaMobility where
  | none
  | lower
  | higher
  deriving DecidableEq, Repr

/-- A rate of Attendance Allowance. -/
inductive AaRate where
  | none
  | lower
  | higher
  deriving DecidableEq, Repr

/-- The disability benefits one person gets. -/
structure Disability where
  pipDaily : PipRate := .none
  pipMobility : PipRate := .none
  dlaCare : DlaCare := .none
  dlaMobility : DlaMobility := .none
  aa : AaRate := .none
  deriving Repr

def PipRate.daily : PipRate → Nat
  | .none => 0
  | .standard => pipDailyStandard
  | .enhanced => pipDailyEnhanced

def PipRate.mobility : PipRate → Nat
  | .none => 0
  | .standard => pipMobilityStandard
  | .enhanced => pipMobilityEnhanced

def DlaCare.weekly : DlaCare → Nat
  | .none => 0
  | .lowest => dlaCareLowest
  | .middle => dlaCareMiddle
  | .highest => dlaCareHighest

def DlaMobility.weekly : DlaMobility → Nat
  | .none => 0
  | .lower => dlaMobilityLower
  | .higher => dlaMobilityHigher

def AaRate.weekly : AaRate → Nat
  | .none => 0
  | .lower => aaLower
  | .higher => aaHigher

/-- The person's disability benefits a week, pence. -/
def Disability.weekly (x : Disability) : Nat :=
  x.pipDaily.daily + x.pipMobility.mobility + x.dlaCare.weekly + x.dlaMobility.weekly + x.aa.weekly

/-- The same for a year of 52 weeks, pence. -/
def Disability.year (x : Disability) : Nat := benefitWeeks * x.weekly

/-! ## Carer's Allowance -/

/-- A year of net earnings `e` (1/10 000 pence) as a week's, in whole pence, the
fraction of a penny disregarded (SI 1996/2745 reg 5). -/
def caWeeklyEarnings (e : Int) : Int := e / (10_000 * benefitWeeks)

/-- Net earnings do not exceed the limit (SI 1976/409 reg 8(1)). -/
def caEarningsOk (e : Int) : Bool := decide (caWeeklyEarnings e ≤ caEarningsLimit)

/-- Carer's Allowance for the year, pence, for a carer who meets every condition
but the earnings one (`entitled`), with weekly overlapping benefits `overlap`
pence, on a year's net earnings `e` (1/10 000 pence). -/
def caYear (entitled : Bool) (overlap : Nat) (e : Int) : Nat :=
  if entitled && caEarningsOk e then benefitWeeks * (caRate - overlap) else 0

/-- Net earnings for the earnings limit, 1/10 000 pence a year, for pay `g` after
net pay pension contributions `rg.netPay`: gross pay less the income tax on the
pay alone, primary Class 1 and half the pension contributions (SI 1996/2745
reg 10(4)). -/
def caEarnings (p : EarningsPeriod) (rg : Regime) (g : Nat) : Int :=
  10_000 * ((g + rg.netPay : Nat) : Int) - (finalTaxExact rg ⟨g, 0, 0⟩ : Int)
    - (nicExact p (g + rg.netPay) : Int) - 5_000 * (rg.netPay : Int)

/-- The year's net earnings at which a week's exceed £204: 52 × £204.01. -/
def caThreshold : Int := 10_000 * benefitWeeks * (caEarningsLimit + 1)

theorem caEarningsOk_iff (e : Int) : caEarningsOk e = true ↔ e < caThreshold := by
  unfold caEarningsOk caWeeklyEarnings caThreshold benefitWeeks caEarningsLimit
  simp only [decide_eq_true_eq]
  omega

/-- More net earnings never give more Carer's Allowance. -/
theorem caYear_anti (ent : Bool) (ov : Nat) {e e' : Int} (h : e ≤ e') :
    caYear ent ov e' ≤ caYear ent ov e := by
  unfold caYear
  have h1 := caEarningsOk_iff e
  have h2 := caEarningsOk_iff e'
  cases ent <;> simp only [Bool.false_and, Bool.true_and, Bool.false_eq_true, ↓reduceIte,
    Nat.le_refl]
  by_cases ha : caEarningsOk e' = true
  · have : caEarningsOk e = true := h1.mpr (by have := h2.mp ha; omega)
    simp [ha, this]
  · simp only [Bool.not_eq_true] at ha; simp [ha]

/-- Carer's Allowance changes only where net earnings cross the limit. -/
theorem caYear_change (ent : Bool) (ov : Nat) {e e' : Int} (h : caYear ent ov e' ≠ caYear ent ov e) :
    (e < caThreshold ∧ caThreshold ≤ e') ∨ (e' < caThreshold ∧ caThreshold ≤ e) := by
  have h1 := caEarningsOk_iff e
  have h2 := caEarningsOk_iff e'
  unfold caYear at h
  by_cases ha : e < caThreshold <;> by_cases hb : e' < caThreshold
  · rw [h1.mpr ha, h2.mpr hb] at h; exact absurd rfl h
  · exact Or.inl ⟨ha, by omega⟩
  · exact Or.inr ⟨hb, by omega⟩
  · have : caEarningsOk e = false := by
      cases hc : caEarningsOk e
      · rfl
      · exact absurd (h1.mp hc) ha
    have : caEarningsOk e' = false := by
      cases hc : caEarningsOk e'
      · rfl
      · exact absurd (h2.mp hc) hb
    simp_all

/-- **The Carer's Allowance cliff.** A penny of net earnings a year below 52 ×
£204.01 the carer gets the whole allowance; at it, nothing: £4,495.40 a year with
no overlapping benefit. -/
theorem caYear_cliff (ov : Nat) :
    caYear true ov (caThreshold - 1) = benefitWeeks * (caRate - ov) ∧
      caYear true ov caThreshold = 0 := by
  have h1 := caEarningsOk_iff (caThreshold - 1)
  have h2 := caEarningsOk_iff caThreshold
  unfold caYear
  constructor
  · simp [h1.mpr (by omega)]
  · have : caEarningsOk caThreshold = false := by
      cases hc : caEarningsOk caThreshold
      · rfl
      · exact absurd (h2.mp hc) (by omega)
    simp [this]

example : benefitWeeks * caRate = 449_540 := rfl

/-! ## Net income for a carer -/

/-- Net income, 1/10 000 pence, with taxable income `C` pence added to non-savings
income (no NICs on it): as `net`, with income tax on `g + C`. -/
def netCa (p : EarningsPeriod) (cb : Nat) (rg : Regime) (s d C g : Nat) : Int :=
  10_000 * ((g + C + s + d : Nat) : Int) + 10_000 * (cb : Int) - (finalTaxExact rg ⟨g + C, s, d⟩ : Int)
    - (nicExact p (g + rg.netPay) : Int) - 10_000 * (hicbc (g + C + s + d - rg.relief) cb : Int)

/-- Net income of a carer with pay `g`: `netCa` with the year's Carer's Allowance. -/
def netCarer (p : EarningsPeriod) (cb : Nat) (rg : Regime) (ent : Bool) (ov s d g : Nat) : Int :=
  netCa p cb rg s d (caYear ent ov (caEarnings p rg g)) g

theorem netCa_succ_ge {p : EarningsPeriod} {cb : Nat} {rg : Regime} {s d C g : Nat}
    (hPA : personalAllowanceFor (g + C + 1 + s + d - rg.relief)
      = personalAllowanceFor (g + C + s + d - rg.relief))
    (hPSA : Income.psa rg ⟨g + C + 1, s, d⟩ = Income.psa rg ⟨g + C, s, d⟩)
    (hMA : Income.maReduction rg ⟨g + C + 1, s, d⟩ = Income.maReduction rg ⟨g + C, s, d⟩)
    (hC : hicbc (g + C + 1 + s + d - rg.relief) cb = hicbc (g + C + s + d - rg.relief) cb) :
    netCa p cb rg s d C g + rg.minGain ≤ netCa p cb rg s d C (g + 1) := by
  have h1 := finalTaxExact_succ_le hPA hPSA hMA
  have h2 := nicExact_succ_le p (g + rg.netPay)
  rw [show g + rg.netPay + 1 = g + 1 + rg.netPay by omega] at h2
  have h3 := rg.minGain_eq
  have e : g + 1 + C = g + C + 1 := by omega
  unfold netCa
  rw [e, hC]
  omega

/-- With the carer's taxable income fixed, net income falls only at the steps of
`net_drop_only_at_steps`, taken at total income `g + C`. -/
theorem netCa_drop_only_at_steps (p : EarningsPeriod) (cb : Nat) (rg : Regime) (s d C g : Nat)
    (h : netCa p cb rg s d C (g + 1) < netCa p cb rg s d C g) :
    PaStep (g + C + s + d - rg.relief) ∨ (0 < cb ∧ HicbcStep (g + C + s + d - rg.relief)) ∨
      Income.step3 rg ⟨g + C, s, d⟩ = rg.brl ∨ Income.step3 rg ⟨g + C, s, d⟩ = rg.hrl ∨
      MaStep rg s d (g + C) := by
  by_cases hMA : MaStep rg s d (g + C)
  · exact Or.inr (Or.inr (Or.inr (Or.inr hMA)))
  unfold MaStep at hMA
  have hMA : Income.maReduction rg ⟨g + C + 1, s, d⟩ = Income.maReduction rg ⟨g + C, s, d⟩ :=
    Classical.not_not.mp hMA
  have ht : g + C + 1 + s + d = (g + C + s + d) + 1 := by omega
  have hA : (personalAllowanceFor (g + C + 1 + s + d - rg.relief)
        = personalAllowanceFor (g + C + s + d - rg.relief) ∧
      hicbc (g + C + 1 + s + d - rg.relief) cb = hicbc (g + C + s + d - rg.relief) cb) ∨
      PaStep (g + C + s + d - rg.relief) ∨ (0 < cb ∧ HicbcStep (g + C + s + d - rg.relief)) := by
    rw [ht]
    rcases ani_succ rg (g + C + s + d) with ha | ⟨ha, hb⟩
    · rw [ha]
      rcases personalAllowanceFor_succ (g + C + s + d - rg.relief) with hPA | hPA
      · rcases hicbc_succ (g + C + s + d - rg.relief) cb with hc | hc
        · exact Or.inl ⟨hPA, hc⟩
        · by_cases hcb : cb = 0
          · left; subst hcb; unfold hicbc; simp [hPA]
          · exact Or.inr (Or.inr ⟨by omega, hc⟩)
      · exact Or.inr (Or.inl hPA)
    · left; rw [ha, hb]; exact ⟨rfl, rfl⟩
  rcases hA with ⟨hPA, hC⟩ | hA
  · rcases psa_succ hPA with hPSA | hT | hT
    · have := netCa_succ_ge (p := p) hPA hPSA hMA hC
      omega
    · exact Or.inr (Or.inr (Or.inl hT))
    · exact Or.inr (Or.inr (Or.inr (Or.inl hT)))
  · rcases hA with hA | hA
    · exact Or.inl hA
    · exact Or.inr (Or.inl hA)

/-- **Where a carer's net income can fall.** For every pay, savings, dividends,
Child Benefit, pay period, reliefs, overlapping benefit, Scottish or not: if a
penny more pay lowers net income with Carer's Allowance, then either net earnings
cross the £204 a week limit at that penny (the allowance is lost or, where the
penny lowers net earnings, regained), or the allowance is unchanged at `C` and the
penny is a step of `net_drop_only_at_steps` at total income `g + C`. -/
theorem netCarer_drop_only_at_steps (p : EarningsPeriod) (cb : Nat) (rg : Regime) (ent : Bool)
    (ov s d g : Nat) (h : netCarer p cb rg ent ov s d (g + 1) < netCarer p cb rg ent ov s d g) :
    ((caEarnings p rg g < caThreshold ∧ caThreshold ≤ caEarnings p rg (g + 1)) ∨
      (caEarnings p rg (g + 1) < caThreshold ∧ caThreshold ≤ caEarnings p rg g)) ∨
    ∃ C, C = caYear ent ov (caEarnings p rg g) ∧
      (PaStep (g + C + s + d - rg.relief) ∨ (0 < cb ∧ HicbcStep (g + C + s + d - rg.relief)) ∨
        Income.step3 rg ⟨g + C, s, d⟩ = rg.brl ∨ Income.step3 rg ⟨g + C, s, d⟩ = rg.hrl ∨
        MaStep rg s d (g + C)) := by
  by_cases hc : caYear ent ov (caEarnings p rg (g + 1)) = caYear ent ov (caEarnings p rg g)
  · right
    refine ⟨_, rfl, ?_⟩
    unfold netCarer at h
    rw [hc] at h
    exact netCa_drop_only_at_steps p cb rg s d _ g h
  · left
    exact caYear_change ent ov hc

/-! ## Maternity Allowance, new style JSA and ESA, Sure Start Maternity Grant -/

/-- Maternity Allowance a week, in 1/10 pence, for average weekly earnings `awe`
pence: the lower of 90 % of them and £194.32, if they reach £30. -/
def maWeeklyTenths (awe : Nat) : Nat :=
  if awe < maThreshold then 0 else min (10 * maRateStandard) (9 * awe)

/-- **The Maternity Allowance threshold is a cliff**: 1p a week below £30 of
average weekly earnings gets nothing, £30 gets £27 a week. -/
theorem ma_threshold_cliff : maWeeklyTenths (maThreshold - 1) = 0 ∧ maWeeklyTenths maThreshold = 27_000 := by
  decide

/-- Above the threshold more earnings never give less Maternity Allowance. -/
theorem ma_mono {a a' : Nat} (h : a ≤ a') : maWeeklyTenths a ≤ maWeeklyTenths a' := by
  unfold maWeeklyTenths maThreshold maRateStandard
  split <;> split <;> omega

/-- New style JSA a week, pence (SI 2013/378): the age-related amount less weekly
earnings above £5 (reg 50, Schedule para 5) and pension payments above £50
(reg 51(1)); not payable if less than 10p (reg 52). -/
def jsaWeekly (under25 : Bool) (earn pension : Nat) : Nat :=
  let a := (if under25 then jsaUnder25 else jsa25) - (earn - jsaEarningsDisregard)
    - (pension - jsaPensionThreshold)
  if a < 10 then 0 else a

/-- Earnings plus new style JSA never fall as earnings rise, except by at most 9p
where the award falls below the 10p minimum (reg 52). -/
theorem jsa_total_succ (u : Bool) (earn pension : Nat) :
    earn + jsaWeekly u earn pension ≤ earn + 1 + jsaWeekly u (earn + 1) pension + 9 := by
  unfold jsaWeekly jsaUnder25 jsa25 jsaEarningsDisregard jsaPensionThreshold
  dsimp only
  split <;> split <;> split <;> omega

/-- New style ESA a week, in 1/10 pence (SI 2013/379): £95.55, or £75.65 under 25
in the assessment phase, plus the £50.35 support component, less half of pension
payments above £85 (reg 67(1)). -/
def esaWeeklyTenths (assessmentUnder25 support : Bool) (pension : Nat) : Nat :=
  10 * ((if assessmentUnder25 then esaAssessmentUnder25 else esaRate) + (if support then esaSupport else 0))
    - 5 * (pension - esaPensionThreshold)

/-- Pension plus new style ESA keeps at least half of any rise in pension
payments. -/
theorem esa_total_gain (a s : Bool) (pension : Nat) :
    10 * pension + esaWeeklyTenths a s pension + 5 ≤ 10 * (pension + 1) + esaWeeklyTenths a s (pension + 1) := by
  unfold esaWeeklyTenths esaAssessmentUnder25 esaRate esaSupport esaPensionThreshold
  split <;> split <;> omega

/-- Sure Start Maternity Grant, pence: £500 for each baby expected, for a claimant
getting a qualifying benefit (reg 5(2)) with no other member of the family under
16 (reg 5A(4)). -/
def ssmg (qualifying : Bool) (existingUnder16 babies : Nat) : Nat :=
  if qualifying && existingUnder16 = 0 then ssmgAmount * babies else 0

end UkTax
