import UkTax.Benefits
import UkTax.Disability

/-!
# Carer's Allowance with Universal Credit, 2026-27

A carer who gets Carer's Allowance and claims Universal Credit:

* Carer's Allowance is unearned income for UC, deducted in full (SI 2013/376
  reg 66(1)(b)(iii)); paid weekly, it counts as 52/12 of the weekly rate a month
  (reg 73(2)(a)), so twelve months of it are the year's 52 weeks
  (`Claims.carersAllowanceYear`).
* The carer element is due whether or not Carer's Allowance is paid: reg 30(1)(a)
  gives regular and substantial caring responsibilities to anyone who satisfies
  the conditions for Carer's Allowance or would but for the earnings limit; a
  single claimant with the LCWRA element gets only that (reg 29(4)).
* Earned income for UC is pay less the income tax and primary Class 1 paid "in
  respect of the employment" (reg 55(5)(b)). The model takes the tax on the pay
  alone, the pay being the lowest slice of income and Carer's Allowance above it,
  as for the Carer's Allowance earnings rule (`caEarnings`) and as PolicyEngine
  does (`uc_income_tax_on_earnings`). In practice HMRC codes Carer's Allowance
  against the PAYE allowance, so the PAYE taken from the job can include tax on
  the allowance; the regulation does not say how to split the tax.
* Carer's Allowance is taxable (ITEPA 2003 s660, Table A), so income tax is on pay
  plus the allowance, as in `netCarer`.

Proved: `ucAward_withCa` (while UC is in payment, every penny of Carer's Allowance
takes a penny off UC) and `carer_uc_net` (so for a carer on UC, Carer's Allowance
changes net income only by the income tax and High Income Child Benefit Charge it
brings: the household is never better off for it, and the Carer's Allowance
earnings-limit cliff of `caYear_cliff` turns into a gain of that tax).
-/

namespace UkTax

/-- The claims with Carer's Allowance of `C` pence for the year as unearned
income. -/
def Claims.withCa (c : Claims) (C : Nat) : Claims := { c with carersAllowanceYear := C }

/-- Net income of a carer on Universal Credit with pay `g` (no savings or
dividends), 1/1 000 000 pence: pay, Child Benefit and Carer's Allowance, less
income tax on pay and the allowance, NICs and the HICBC, plus UC with the allowance
deducted as unearned income. -/
def netCarerUc (p : EarningsPeriod) (cb : Nat) (rg : Regime) (c : Claims) (ent : Bool) (ov g : Nat) : Int :=
  let C := caYear ent ov (caEarnings p rg g)
  100 * netCa p cb rg 0 0 C g + ucAward (c.withCa C) (earned p rg 0 0 g)

/-! ## Proved properties -/

/-- **While UC is in payment, Carer's Allowance comes off it penny for penny.** For
a claim with the carer element (so outside the benefit cap, reg 83(1)(j)), if UC is
paid with Carer's Allowance `C` for the year, it is the award without the
allowance less `C`. -/
theorem ucAward_withCa (c : Claims) (e : Int) (C : Nat) (hc : 0 < c.carers)
    (h : 0 < ucAward (c.withCa C) e) :
    ucAward (c.withCa C) e = ucAward (c.withCa 0) e - micro * (C : Int) := by
  have hcap : ∀ (A : Nat) (x : Int), (c.withCa A).capApplies x = false := by
    intro A x
    have : c.carers ≠ 0 := by omega
    simp [Claims.capApplies, Claims.withCa, this]
  -- the award with allowance `A`: the same expression less `micro * A` inside the max
  have key : ∀ A : Nat, ucAward (c.withCa A) e =
      if c.uc && decide (c.capital ≤ ucCapitalUpper) then
        max 0 (12 * (c.maxMicro - micro * (c.tariff + c.unearnedMonthly : Nat)) + 12 * c.childcareMicro e
          - (ucTaperPercent : Int)
            * max 0 (e + 10_000 * (c.partnerEarned : Int) - 10_000 * 12 * (c.workAllowance : Int))
          - micro * (A : Int))
      else 0 := by
    intro A
    unfold ucAward
    simp only [hcap, Bool.false_eq_true, ↓reduceIte]
    show (if c.uc && decide (c.capital ≤ ucCapitalUpper) then _ else 0) = _
    split
    · show max 0 (12 * (c.maxMicro - micro * (c.tariff + c.unearnedMonthly : Nat)) - micro * (A : Int)
          + 12 * c.childcareMicro e - (ucTaperPercent : Int)
            * max 0 (e + 10_000 * (c.partnerEarned : Int) - 10_000 * 12 * (c.workAllowance : Int))) = _
      congr 1
      omega
    · rfl
  rw [key C, key 0] at *
  split at h
  · rename_i hu
    simp only [hu, ↓reduceIte]
    generalize 12 * (c.maxMicro - micro * (c.tariff + c.unearnedMonthly : Nat)) + 12 * c.childcareMicro e
          - (ucTaperPercent : Int)
            * max 0 (e + 10_000 * (c.partnerEarned : Int) - 10_000 * 12 * (c.workAllowance : Int)) = Z at *
    unfold micro at *
    omega
  · omega

/-- **Carer's Allowance on UC is worth only what it costs in tax.** For a carer
with the carer element and pay `g`, while UC is in payment with the allowance `C`,
net income with it equals net income without it less the extra income tax and
HICBC on it. -/
theorem carer_uc_net (p : EarningsPeriod) (cb : Nat) (rg : Regime) (c : Claims) (C g : Nat)
    (hc : 0 < c.carers) (h : 0 < ucAward (c.withCa C) (earned p rg 0 0 g)) :
    100 * netCa p cb rg 0 0 C g + ucAward (c.withCa C) (earned p rg 0 0 g)
      = 100 * netCa p cb rg 0 0 0 g + ucAward (c.withCa 0) (earned p rg 0 0 g)
        - 100 * ((finalTaxExact rg ⟨g + C, 0, 0⟩ : Int) - finalTaxExact rg ⟨g, 0, 0⟩)
        - micro * ((hicbc (g + C - rg.relief) cb : Int) - hicbc (g - rg.relief) cb) := by
  rw [ucAward_withCa c _ C hc h]
  unfold netCa micro
  simp only [Nat.add_zero]
  push_cast
  omega

/-- The same at the Carer's Allowance earnings limit: where a penny more pay loses
the allowance and UC is in payment with it, net income before the penny is net
income at the same pay without the allowance, less the tax and HICBC the allowance
brought. -/
theorem carer_uc_cliff (p : EarningsPeriod) (cb : Nat) (rg : Regime) (c : Claims) (ent : Bool)
    (ov g : Nat) (hc : 0 < c.carers)
    (h : 0 < ucAward (c.withCa (caYear ent ov (caEarnings p rg g))) (earned p rg 0 0 g)) :
    netCarerUc p cb rg c ent ov g
      = 100 * netCa p cb rg 0 0 0 g + ucAward (c.withCa 0) (earned p rg 0 0 g)
        - 100 * ((finalTaxExact rg ⟨g + caYear ent ov (caEarnings p rg g), 0, 0⟩ : Int)
            - finalTaxExact rg ⟨g, 0, 0⟩)
        - micro * ((hicbc (g + caYear ent ov (caEarnings p rg g) - rg.relief) cb : Int)
            - hicbc (g - rg.relief) cb) :=
  carer_uc_net p cb rg c _ g hc h

end UkTax
