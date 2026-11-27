import UkTax.Params

/-!
# Stamp Duty Land Tax, 2026-27 (P8b)

Finance Act 2003, England and Northern Ireland (Wales has Land Transaction Tax and
Scotland Land and Buildings Transaction Tax, not modelled yet). Tax on the
chargeable consideration `p` (pence) by slices (s55(1B)): each band's rate on the
part of the consideration within it. Exact, in 1/10 000 pence; no rounding is
applied. Not modelled: the non-resident surcharge (Sch 9A), linked transactions,
leases, multiple dwellings and the other reliefs.

* a purchase of a dwelling: the residential rates, or first-time buyers' relief
  where the consideration is not more than £500,000 (Sch 6ZA);
* an additional dwelling (a higher rates transaction, Sch 4ZA): the higher rates
  from £40,000 of consideration;
* non-residential or mixed property: Table B.

Proved: `sdlt_succ` (a penny more consideration never lowers the tax), and the two
cliffs: first-time buyers' relief ends at £500,000 (`ftb_cliff`, £5,000 more tax
for a penny more), and the higher rates start at £40,000 (`higher_cliff`, £2,000).
-/

namespace UkTax

/-- Tax on `p` pence by bands `(upper limit, rate)` above `lo`; a limit of 0 is the
last band. 1/10 000 pence. -/
def bandsTax : List (Nat × Nat) → Nat → Nat → Nat
  | [], _, _ => 0
  | (u, r) :: rest, lo, p =>
    if u = 0 then r * (p - lo) else r * (min p u - lo) + bandsTax rest u p

/-- What kind of transaction. -/
inductive SdltKind where
  | residential
  | firstTime
  | additional
  | nonResidential
  deriving DecidableEq, Repr

/-- SDLT on consideration `p`, 1/10 000 pence. -/
def sdltExact (k : SdltKind) (p : Nat) : Nat :=
  match k with
  | .residential => bandsTax sdltResidential 0 p
  | .firstTime =>
    if p ≤ sdltFirstTimeLimit then bandsTax sdltFirstTime 0 p else bandsTax sdltResidential 0 p
  | .additional =>
    if p < sdltHigherMin then bandsTax sdltResidential 0 p else bandsTax sdltHigher 0 p
  | .nonResidential => bandsTax sdltNonResidential 0 p

/-! ## Proved properties -/

theorem bandsTax_succ (bs : List (Nat × Nat)) (lo p : Nat) :
    bandsTax bs lo p ≤ bandsTax bs lo (p + 1) := by
  induction bs generalizing lo with
  | nil => simp [bandsTax]
  | cons b rest ih =>
    obtain ⟨u, r⟩ := b
    simp only [bandsTax]
    split
    · exact Nat.mul_le_mul_left r (by omega)
    · have h1 : min p u - lo ≤ min (p + 1) u - lo := by omega
      have := Nat.mul_le_mul_left r h1
      have := ih u
      omega

/-- A penny more consideration never lowers SDLT, for every kind of transaction
except at the two cliffs below. -/
theorem sdlt_succ (k : SdltKind) (p : Nat) (h1 : k = .firstTime → p ≠ sdltFirstTimeLimit) :
    sdltExact k p ≤ sdltExact k (p + 1) := by
  cases k <;> simp only [sdltExact]
  · exact bandsTax_succ _ _ _
  · have := h1 rfl
    split <;> split
    · exact bandsTax_succ _ _ _
    · omega
    · omega
    · exact bandsTax_succ _ _ _
  · split <;> split
    · exact bandsTax_succ _ _ _
    · rename_i hb ha
      unfold sdltHigherMin at *
      have : p = 3_999_999 := by omega
      subst this; decide
    · omega
    · exact bandsTax_succ _ _ _
  · exact bandsTax_succ _ _ _

/-- **First-time buyers' relief ends at £500,000.** At £500,000 the tax is £10,000;
a penny more and the ordinary rates apply to the whole price: £15,000.0005. -/
theorem ftb_cliff :
    sdltExact .firstTime sdltFirstTimeLimit = 10_000_000_000 ∧
      sdltExact .firstTime (sdltFirstTimeLimit + 1) = 15_000_000_500 := by
  decide

/-- **The higher rates start at £40,000.** An additional dwelling for £39,999.99 pays
nothing; for £40,000, 5 %: £2,000. -/
theorem higher_cliff :
    sdltExact .additional (sdltHigherMin - 1) = 0 ∧
      sdltExact .additional sdltHigherMin = 2_000_000_000 := by
  decide

end UkTax
