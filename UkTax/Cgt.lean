import UkTax.Cliffs

/-!
# Capital Gains Tax for individuals, 2026-27 (P8a)

TCGA 1992 ss 1H-1K, 169N. For an individual's gains for the year (after losses,
which are an input), with gains qualifying for Business Asset Disposal Relief
(`badr`, within the £1,000,000 lifetime limit, which the caller applies) and other
gains (`other`: residential property and the rest, all at the same rates in
2026-27):

* the annual exempt amount, £3,000 (s1K(2)), is set against the other gains first (s1K(5):
  in the way most beneficial; against BADR gains it saves 18 % and frees as much
  basic rate band, worth 6 % on other gains above it, so never more);
* BADR gains are charged at 18 % (s169N(3)) and take the unused basic rate band
  first (s1I(4)-(6));
* other gains are charged at 18 % within what is left of the unused basic rate band,
  allocated to them (s1I(7)-(8)), and 24 % above it (s1H(3), s1I(9)).

The unused basic rate band is the basic rate limit (raised by Gift Aid and
relief-at-source pension contributions: ITA 2007 s414(2), FA 2004 s192(4))
less the income charged to income tax (Step 3 income). Carried interest, charged to
income tax from 6 April 2026 (Finance Act 2026 s58, ITTOIA 2005 s23I), and
investors' relief are not modelled; nor are Scottish taxpayers, for whom the
basic rate band used was not checked.

Tax is in 1/10 000 of a penny (rates in basis points), as for income tax.
-/

namespace UkTax

/-- Capital Gains Tax, 1/10 000 pence, on BADR gains `badr` and other gains
`other` (pence), with unused basic rate band `band` (pence). -/
def cgtExact (band badr other : Nat) : Nat :=
  let o := other - cgtExemptAmount
  let b := badr - (cgtExemptAmount - other)
  let inBand := min o (band - b)
  cgtBadrRate * b + cgtBasicRate * inBand + cgtHigherRate * (o - inBand)

/-- The unused basic rate band for Capital Gains Tax: the basic rate limit (raised
by the reliefs) less Step 3 income. -/
def Income.cgtBand (rg : Regime) (i : Income) : Nat := rg.brl - i.step3 rg

/-! ## Proved properties -/

/-- More gains never lower Capital Gains Tax, and each penny of gains adds at most
24p in the pound. -/
theorem cgt_succ_other (band badr other : Nat) :
    cgtExact band badr other ≤ cgtExact band badr (other + 1) ∧
      cgtExact band badr (other + 1) ≤ cgtExact band badr other + cgtHigherRate := by
  unfold cgtExact cgtExemptAmount cgtBadrRate cgtBasicRate cgtHigherRate
  dsimp only
  simp only [Nat.min_def]
  split <;> split <;> omega

theorem cgt_succ_badr (band badr other : Nat) :
    cgtExact band badr other ≤ cgtExact band (badr + 1) other ∧
      cgtExact band (badr + 1) other ≤ cgtExact band badr other + cgtHigherRate := by
  unfold cgtExact cgtExemptAmount cgtBadrRate cgtBasicRate cgtHigherRate
  dsimp only
  simp only [Nat.min_def]
  split <;> split <;> omega

/-- A smaller unused basic rate band (more income) never lowers the tax, and each
penny less of band adds at most 6p. -/
theorem cgt_band (band badr other : Nat) :
    cgtExact (band + 1) badr other ≤ cgtExact band badr other ∧
      cgtExact band badr other ≤ cgtExact (band + 1) badr other + (cgtHigherRate - cgtBasicRate) := by
  unfold cgtExact cgtExemptAmount cgtBadrRate cgtBasicRate cgtHigherRate
  dsimp only
  simp only [Nat.min_def]
  split <;> split <;> omega

/-- Gains up to the annual exempt amount are tax-free. -/
theorem cgt_exempt (band badr other : Nat) (h : badr + other ≤ cgtExemptAmount) :
    cgtExact band badr other = 0 := by
  unfold cgtExact cgtExemptAmount cgtBadrRate cgtBasicRate cgtHigherRate at *
  dsimp only
  simp only [Nat.min_def]
  split <;> omega

end UkTax
