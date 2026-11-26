import UkTax.Params

/-!
# Trading and property profits: the trading and property allowances and rent-a-room relief

Profits of a trade (ITTOIA 2005 Part 2) and of a UK property business (Part 3)
are non-savings income (ITA 2007 s18). This file turns receipts and expenses into
the profits charged, with the reliefs of ITTOIA 2005 Part 6A (the £1,000 trading
and property allowances) and Part 7 Chapter 1 (rent-a-room relief). Each relief
is "full" (receipts within the limit are left out, with their expenses) or, above
the limit, an election to deduct the limit instead of the actual expenses; the
taxpayer may also elect out of full relief or not elect for partial relief.

The model makes the elections that give the least profit. Income tax never
falls as non-savings income rises (`liability_mono`), so that is the least tax;
the same holds for Class 4 NICs. Losses are not modelled: a trade or property
business with expenses above receipts has nil profit here, and no loss relief is
given against other income (ITA 2007 ss 64, 118, 120 are out of scope), so where
a loss would be worth more than the allowance the model gives none of it.

Not modelled: miscellaneous income sharing the trading allowance (s783AB), the
exclusions for receipts from an employer, a firm or a close company
(ss 783AN-783AQ), more than one trade or property business, the cash basis
tests of s783AE(2)-(3), rent-a-room receipts of a trade (s796) or chargeable as
miscellaneous income (s798), and balancing charges.
-/

namespace UkTax

/-- Trading allowance, £1,000: ITTOIA 2005 s783AD(1)
<https://www.legislation.gov.uk/ukpga/2005/5/section/783AD> ("an individual's
trading allowance for a tax year is £1,000"). Unchanged for 2026-27; Budget 2026
announced £3,000 from 6 April 2027, not yet enacted and outside 2026-27. -/
def tradingAllowance : Nat := 100_000

/-- Property allowance, £1,000: ITTOIA 2005 s783BD(1)
<https://www.legislation.gov.uk/ukpga/2005/5/section/783BD>. -/
def propertyAllowance : Nat := 100_000

/-- Rent-a-room basic amount, £7,500: ITTOIA 2005 s789(4)
<https://www.legislation.gov.uk/ukpga/2005/5/section/789>, as amended by the Income
Tax (Limit for Rent-a-Room Relief) Order 2015 (SI 2015/1539) art 2 from 2016-17.
The individual's limit is half of it, £3,750, if someone else also has receipts
from letting in the same residence (s789(3), s790). -/
def rentARoomBasic : Nat := 750_000

/-- The individual's rent-a-room limit (s789(2), (3)). -/
def rentARoomLimit (shared : Bool) : Nat :=
  if shared then rentARoomBasic / 2 else rentARoomBasic

/-- Profits of a trade with receipts `r` and allowable expenses `e`, with the
trading allowance `a`:

* receipts within the allowance: full relief, profits nil (s783AE(1), s783AF);
* above it, the better of actual expenses and partial relief, receipts less the
  allowance with no expenses (s783AH, s783AI, on election under s783AM);
* a loss counts as nil (losses are not modelled).

All three are `r - max e a` in natural numbers: within the allowance it is nil. -/
def reliefProfit (a r e : Nat) : Nat := r - max e a

/-- Profits of the trade charged to income tax: receipts less the larger of the
expenses and the £1,000 trading allowance. -/
def tradeProfit (r e : Nat) : Nat := reliefProfit tradingAllowance r e

/-- Profits of a UK property business in pence, as an integer before any loss is
floored at nil. Receipts `p` from letting other than rent-a-room, with expenses
`ep`; rent-a-room receipts `q` from furnished accommodation in the taxpayer's only
or main home, with expenses `eq`.

* The rent-a-room receipts are not relievable receipts for the property
  allowance (s783BB(2)): the two reliefs apply to separate receipts.
* Other receipts: ordinary profits `p - ep`, or the property allowance (full
  relief at or below £1,000, s783BF; partial relief above it, s783BH: receipts
  less £1,000, no expenses).
* Rent-a-room receipts: ordinary profits `q - eq`, or rent-a-room relief (full
  relief at or below the limit, receipts and expenses left out, s791, s793; above
  it, by election, receipts less the limit with no expenses, s795, s797).
* Each choice is the taxpayer's, and each part is in one business's profits, so a
  loss on one part reduces the other: the least profit is the sum of the least
  of each part, floored at nil. -/
def propertyProfitInt (shared : Bool) (p ep q eq : Nat) : Int :=
  min ((p : Int) - ep) ((p - min p propertyAllowance : Nat) : Int)
    + min ((q : Int) - eq) ((q - min q (rentARoomLimit shared) : Nat) : Int)

/-- Profits of the property business charged to income tax (no loss relief). -/
def propertyProfit (shared : Bool) (p ep q eq : Nat) : Nat :=
  (propertyProfitInt shared p ep q eq).toNat

/-! ## No cliff at the allowances

A pound more receipts never adds more than a pound to the profits charged, and
never lowers them: with the elections made, the £1,000 allowances and the
rent-a-room limit leave no step in profits (unlike a rule that charged all the
receipts once they passed the limit). -/

theorem reliefProfit_succ (a r e : Nat) :
    reliefProfit a r e ≤ reliefProfit a (r + 1) e ∧
      reliefProfit a (r + 1) e ≤ reliefProfit a r e + 1 := by
  unfold reliefProfit; omega

/-- Within the allowance nothing is charged; above it, never more than receipts
less the allowance. -/
theorem reliefProfit_le (a r e : Nat) : reliefProfit a r e ≤ r - a := by
  unfold reliefProfit; omega

theorem propertyProfit_succ_other (shared : Bool) (p ep q eq : Nat) :
    propertyProfit shared p ep q eq ≤ propertyProfit shared (p + 1) ep q eq ∧
      propertyProfit shared (p + 1) ep q eq ≤ propertyProfit shared p ep q eq + 1 := by
  unfold propertyProfit propertyProfitInt
  generalize propertyAllowance = A
  generalize rentARoomLimit shared = L
  omega

theorem propertyProfit_succ_room (shared : Bool) (p ep q eq : Nat) :
    propertyProfit shared p ep q eq ≤ propertyProfit shared p ep (q + 1) eq ∧
      propertyProfit shared p ep (q + 1) eq ≤ propertyProfit shared p ep q eq + 1 := by
  unfold propertyProfit propertyProfitInt
  generalize propertyAllowance = A
  generalize rentARoomLimit shared = L
  omega

end UkTax
