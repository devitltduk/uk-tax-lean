import UkTax.Sdlt

/-!
# Land transaction taxes: LBTT, LTT, leases and non-residents (P8c)

* **Land and Buildings Transaction Tax** (Scotland, LBTT(S)A 2013): Table A by
  slices; first-time buyer relief takes the first £175,000 out of tax (Sch 4A); the
  additional dwelling supplement adds 8 % of the whole consideration where it is
  £40,000 or more (Sch 2A); Table B for non-residential property.
* **Land Transaction Tax** (Wales, LTTA 2017): Table 1; the higher rates (Table 2)
  for an additional dwelling bought for £40,000 or more (Sch 5 para 3); Table 3.
* **Rent under a lease**, in all three taxes: the tax on the net present value of
  the rent, `v = Σ rᵢ / 1.035ⁱ` (FA 2003 Sch 5 para 3; LBTT(S)A Sch 19 para 3; LTTA
  Sch 6 para 31), by the rent table's slices. With 1.035 = 207/200 the NPV of `n`
  years is `num / 207ⁿ`, `num = Σ rᵢ × 200ⁱ × 207ⁿ⁻ⁱ`, and the tax is exact as
  `bandsTax` on `num` with the limits × 207ⁿ, over 207ⁿ.
* **SDLT for non-residents** (FA 2003 s75ZA): 2 % added to each residential rate.
  `bandsTax_add` proves this is exactly 2 % of the whole consideration.

Tax in 1/10 000 pence, as in `Sdlt.lean`.
-/

namespace UkTax

/-- Bands that run upwards from `lo` and end with an unbounded band. -/
def bandsAsc : List (Nat × Nat) → Nat → Bool
  | [], _ => false
  | (u, _) :: rest, lo => u == 0 || (decide (lo ≤ u) && bandsAsc rest u)

/-- Each rate raised by `d`. -/
def bandsAdd (d : Nat) (bs : List (Nat × Nat)) : List (Nat × Nat) := bs.map fun (u, r) => (u, r + d)

/-- **Adding `d` to every rate adds `d` on the whole amount above `lo`.** -/
theorem bandsTax_add (d : Nat) (bs : List (Nat × Nat)) (lo p : Nat) (h : bandsAsc bs lo = true) :
    bandsTax (bandsAdd d bs) lo p = bandsTax bs lo p + d * (p - lo) := by
  induction bs generalizing lo with
  | nil => simp [bandsAsc] at h
  | cons b rest ih =>
    obtain ⟨u, r⟩ := b
    simp only [bandsAdd, List.map] at *
    simp only [bandsTax]
    by_cases hu : u = 0
    · simp only [hu, ↓reduceIte, Nat.add_mul]
    · simp only [hu, ↓reduceIte]
      have h2 : lo ≤ u ∧ bandsAsc rest u = true := by
        simp only [bandsAsc] at h; revert h; simp [hu]
      rw [ih u h2.2, Nat.add_mul]
      have : (min p u - lo) + (p - u) = p - lo := by omega
      rw [← this, Nat.mul_add]
      omega

/-! ## Purchases -/

inductive LandKind where
  | residential | firstTime | additional | nonResidential
  deriving DecidableEq, Repr

/-- LBTT on consideration `p` pence, 1/10 000 pence. -/
def lbttExact (k : LandKind) (p : Nat) : Nat :=
  match k with
  | .residential => bandsTax lbttResidential 0 p
  | .firstTime => bandsTax lbttFirstTime 0 p
  | .additional => bandsTax lbttResidential 0 p + (if lbttAdsMin ≤ p then lbttAdsRate * p else 0)
  | .nonResidential => bandsTax lbttNonResidential 0 p

/-- LTT on consideration `p` pence, 1/10 000 pence (Wales has no first-time buyer
relief: the main rates). -/
def lttExact (k : LandKind) (p : Nat) : Nat :=
  match k with
  | .residential | .firstTime => bandsTax lttResidential 0 p
  | .additional => if lttHigherMin ≤ p then bandsTax lttHigher 0 p else bandsTax lttResidential 0 p
  | .nonResidential => bandsTax lttNonResidential 0 p

/-- SDLT for a non-resident buyer: each residential table with 2 % added. -/
def sdltNonResident (k : SdltKind) (p : Nat) : Nat :=
  match k with
  | .residential => bandsTax (bandsAdd sdltNonResidentRate sdltResidential) 0 p
  | .firstTime =>
    if p ≤ sdltFirstTimeLimit then bandsTax (bandsAdd sdltNonResidentRate sdltFirstTime) 0 p
    else bandsTax (bandsAdd sdltNonResidentRate sdltResidential) 0 p
  | .additional =>
    if p < sdltHigherMin then bandsTax (bandsAdd sdltNonResidentRate sdltResidential) 0 p
    else bandsTax (bandsAdd sdltNonResidentRate sdltHigher) 0 p
  | .nonResidential => bandsTax sdltNonResidential 0 p

/-! ## Rent -/

/-- The NPV numerator of yearly rents `rs` (pence, year 1 first) over `207ⁿ`. -/
def npvNum (rs : List Nat) : Nat :=
  (rs.zipIdx.map fun (r, i) => r * 200 ^ (i + 1) * 207 ^ (rs.length - (i + 1))).sum

/-- The NPV's denominator, `207ⁿ`. -/
def npvDen (rs : List Nat) : Nat := 207 ^ rs.length

/-- Tax on the rent, × `207ⁿ`, 1/10 000 pence: `bandsTax` on the numerator with the
limits scaled. -/
def rentTaxScaled (bs : List (Nat × Nat)) (rs : List Nat) : Nat :=
  bandsTax (bs.map fun (u, r) => (u * npvDen rs, r)) 0 (npvNum rs)

/-! ## Proved properties -/

/-- **The non-resident surcharge is 2 % of the whole price.** For every residential
kind (and only the first-time buyer's limit and the £40,000 start decide which
table), SDLT for a non-resident is the resident's tax plus 2 % of the consideration. -/
theorem sdlt_nonResident (k : SdltKind) (p : Nat) (hk : k ≠ .nonResidential) :
    sdltNonResident k p = sdltExact k p + sdltNonResidentRate * p := by
  have r : bandsAsc sdltResidential 0 = true := by decide
  have f : bandsAsc sdltFirstTime 0 = true := by decide
  have hh : bandsAsc sdltHigher 0 = true := by decide
  cases k <;> simp only [sdltNonResident, sdltExact]
  · rw [bandsTax_add _ _ _ _ r]; simp
  · split
    · rw [bandsTax_add _ _ _ _ f]; simp
    · rw [bandsTax_add _ _ _ _ r]; simp
  · split
    · rw [bandsTax_add _ _ _ _ r]; simp
    · rw [bandsTax_add _ _ _ _ hh]; simp
  · exact absurd rfl hk

/-- **The additional dwelling supplement starts at £40,000.** £39,999.99 pays no LBTT;
£40,000 pays £3,200 (8 % of the whole price). -/
theorem lbtt_ads_cliff :
    lbttExact .additional (lbttAdsMin - 1) = 0 ∧ lbttExact .additional lbttAdsMin = 3_200_000_000 := by
  decide

/-- **Wales's higher rates start at £40,000.** £39,999.99 pays no LTT; £40,000 pays
£2,000. -/
theorem ltt_higher_cliff :
    lttExact .additional (lttHigherMin - 1) = 0 ∧ lttExact .additional lttHigherMin = 2_000_000_000 := by
  decide

set_option linter.deprecated false in
/-- A penny more never lowers LBTT or LTT (the £40,000 steps are jumps up). -/
theorem lbtt_succ (k : LandKind) (p : Nat) : lbttExact k p ≤ lbttExact k (p + 1) := by
  cases k
  · exact bandsTax_succ _ _ _
  · exact bandsTax_succ _ _ _
  · show bandsTax lbttResidential 0 p + (if lbttAdsMin ≤ p then lbttAdsRate * p else 0)
      ≤ bandsTax lbttResidential 0 (p + 1) + (if lbttAdsMin ≤ p + 1 then lbttAdsRate * (p + 1) else 0)
    have h1 := bandsTax_succ lbttResidential 0 p
    have h8 : lbttAdsRate * p ≤ lbttAdsRate * (p + 1) := Nat.mul_le_mul_left _ (by omega)
    by_cases h : lbttAdsMin ≤ p
    · rw [if_pos h, if_pos (Nat.le_succ_of_le h)]; omega
    · rw [if_neg h]; omega
  · exact bandsTax_succ _ _ _

theorem ltt_succ (k : LandKind) (p : Nat) : lttExact k p ≤ lttExact k (p + 1) := by
  cases k <;> simp only [lttExact]
  · exact bandsTax_succ _ _ _
  · exact bandsTax_succ _ _ _
  · split <;> split
    · exact bandsTax_succ _ _ _
    · omega
    · rename_i hb ha
      unfold lttHigherMin at *
      have : p = 3_999_999 := by omega
      subst this; decide
    · exact bandsTax_succ _ _ _
  · exact bandsTax_succ _ _ _

end UkTax
