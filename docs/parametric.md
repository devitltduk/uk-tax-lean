# The guarantees for any figures

The model's rates and thresholds for income tax, employee NICs, the High Income
Child Benefit Charge, the Universal Credit taper and the childcare tests are a
parameter set, `TaxParams` (`UkTax/TaxParams.lean`), carried by every `Regime`
(`Regime.params`). Its default, `TaxParams.y2026`, is the 2026-27 set, so every
output, golden case and PolicyEngine comparison is unchanged.

The headline theorems are stated for **any parameter set meeting
`TaxParams.Valid`**, not for the 2026-27 numbers. Only figures can change, not
structure: the personal allowance still tapers £1 for every £2 above its limit and
is rounded up to a whole pound, the HICBC still rises 1 % per step to 100 %, there
are still three UK bands and six Scottish ones. Figures outside the set (benefit
amounts, the Marriage Allowance and married couple's allowance, Class 4, CGT,
property taxes, student support and the rest of `UkTax/Params.lean`) stay 2026-27.

## What is in the set

Personal allowance and its income limit; basic and higher rate limits; the
starting rate limit for savings; the three personal savings allowances; the
dividend allowance; basic, higher and additional rates for non-savings income,
savings and dividends; the five Scottish limits and six Scottish rates; the
primary threshold and upper earnings limit for each pay period, and the two
employee NIC rates; the HICBC threshold and step; the UC taper; the childcare
income limit and minimum earnings.

## The conditions (`TaxParams.Valid`)

Each is used by a proof; nothing else is assumed.

| Condition | Used by |
|---|---|
| UK non-savings, savings and dividend rates do not fall from band to band | monotonicity (`sliceTax_mono`), the marginal bound (`G_succ_le`) |
| the six Scottish rates do not fall from band to band | the marginal bound, the annual allowance charge bound |
| basic rate limit ≤ higher rate limit | everything that splits income into bands, including the optimal allowance placement |
| personal savings allowance: additional ≤ higher ≤ basic | monotonicity (`savingsAllowanceFor_anti`) |
| UC taper ≤ 100 % | `netAll_succ_ge`, `earned_plus_uc_mono` |
| `maxStep + 0.05p + NIC step ≤ 1p`, for a Scottish taxpayer and anyone else | the cliff theorems: between steps net income does not fall |

Not needed, so not assumed: the Scottish limits in order (the Scottish schedule is
written as each rate's rise above its own limit), the starting rate limit below the
basic rate limit, a positive HICBC step, the HICBC threshold below the childcare
limit, the NIC thresholds in order.

## The results as formulas in the figures

* **Marginal income tax between steps** (`taxExact_succ_le`, `G_succ_le`): a penny
  more pay adds at most `TaxParams.maxStep`, the larger of two cases:
  below the starting rate limit for savings, `nsCapLow + max_k (s_k + d_2 − d_k)`;
  otherwise `max_(a ≤ b) (nsCap a + s_b − s_a + d_2 − d_b)`, where `s`, `d` are the
  savings and dividend rates by band (0 basic, 1 higher, 2 additional) and `nsCap a`
  the highest non-savings rate in UK band `a` (for a Scottish taxpayer, the highest
  Scottish rate whose limit is below that band's top). 2026-27: 0.686p, 0.706p in
  Scotland (`TaxParams.maxStep_y2026`).
* **Net income between steps** (`net_succ_ge`): rises by at least
  `minGain = 1p − maxStep − mcaStep − max(NIC rates)`; 2026-27 0.234p (0.214p).
* **With benefits** (`netAll_succ_ge`): rises by at least `(100 − taper) % × minGain`;
  2026-27 0.1053p, a marginal rate of at most 89.47 % (90.37 % in Scotland).
* **The steps** (`net_drop_only_at_steps`, `netAll_drop_only_at_steps`): adjusted
  net income `t + 1` in `(limit, limit + 2 × allowance]` with
  `(2 × allowance + limit − (t + 1))` a multiple of 200 (`PaStep`); `t + 1` the HICBC
  threshold plus 1 to 100 whole steps (`HicbcStep`); Step 3 income at the basic or
  higher rate limit; the Marriage Allowance rate test; adjusted net income at the
  childcare limit. For 2026-27 these are the £2 and £200 staircases of before
  (`paStep_y2026`, `hicbcStep_y2026`).
* **The cliff map** (`UkTax/CliffMap.lean`, `cliffMap_complete`): for a household
  (pay varying, everything else fixed), every pay below a bound at which a penny
  more lowers net income is in `paPennies` (the personal allowance band, an
  arithmetic progression) or `oneOffPennies` (the HICBC steps, the childcare limit,
  the savings allowance and Marriage Allowance crossings, found by a proved binary
  search). Scope (`CliffScope`): no Marriage Allowance transfer, and a recipient only
  with pay alone, as for the harness households.

## Mathlib

Not needed. Symbolic rates make tax a product of two unknowns, which `omega`
cannot reason about, but every product here has a fixed factor on one side of an
inequality. Three small lemmas give `omega` what it needs, with products as atoms:
summation by parts over three bands (`abel3`), a product grows over a longer slice
(`mul_slice_le`), and core's `Nat.mul_le_mul_left` / `Int.mul_le_mul_of_nonneg_left`.
The marginal bound is a finite maximum, proved by enumerating band indices. The
proofs remain `omega` and core Lean only.

## Audit

Every theorem in the axiom guard (`UkTax/Axioms.lean`). "Before" is how each stood
on the fixed figures: **already** parametric in substance (no figure used),
**easy** (the figures entered only through `omega` on a few constants), **hard**
(the proof depended on specific numbers: the marginal bound found by `omega` over
the 2026-27 rates, the step positions as literals), or **new**.

### Now proved for any figures

| Theorem | File | Before | Now holds for | Note |
|---|---|---|---|---|
| `leastTax_mono` | Proofs.lean | easy | `Valid` | rates in order, BRL ≤ HRL, savings allowance not rising: products with symbolic rates via `abel3` |
| `liability_mono_of_optimal` | Proofs.lean | easy | `Valid` |  |
| `exists_isLeastTax` | Proofs.lean | already | any figures |  |
| `isLeastTax_taxExact` | Optimal.lean | easy | BRL ≤ HRL | only that ordering; any rates |
| `liability_mono` | Optimal.lean | easy | `Valid` |  |
| `nicExact_mono` | Charges.lean | easy | any figures |  |
| `hicbc_mono_income` | Charges.lean | already | any figures |  |
| `hicbc_le` | Charges.lean | already | any figures |  |
| `taxExact_succ_le` | Cliffs.lean | hard | `Valid` | bound is `TaxParams.maxStep`, a formula in the rates and limits (2026-27: 0.686p / 0.706p, `maxStep_y2026`) |
| `net_drop_only_at_steps` | Cliffs.lean | hard | `Valid` | steps `PaStep P`, `HicbcStep P` are formulas in the figures |
| `earned_plus_uc_mono` | Benefits.lean | easy | UC taper ≤ 100 % |  |
| `netAll_drop_only_at_steps` | Benefits.lean | hard | `Valid` |  |
| `netAll_succ_ge` | Benefits.lean | hard | `Valid` | gain `(100 − taper) % × minGain` |
| `fundedHours_over_limit` | Benefits.lean | already | any figures | limit is `P.ccLimit` |
| `fundedHours_drop_at_limit` | Benefits.lean | already | any figures |  |
| `maOk_payOnly` | Cliffs.lean | already | any figures |  |
| `maStep_above_limit` | Cliffs.lean | easy | any figures | restated: Step 3 income above the lower of the Marriage Allowance limit and the BRL (the same for 2026-27) |
| `finalTaxExact_succ_le` | Cliffs.lean | hard | `Valid` |  |
| `class4Exact_le_pre` | Nics.lean | already | any figures |  |
| `class4Exact_succ` | Nics.lean | already | any figures |  |
| `earned_plus_uc_gain` | Benefits.lean | easy | any figures | keeps `(100 − taper) %` of a rise |
| `childcareMicro_mono` | Benefits.lean | already | any figures | no figure of the set involved |
| `capApplies_anti` | Benefits.lean | already | any figures | no figure of the set involved |
| `netCa_drop_only_at_steps` | Disability.lean | hard | `Valid` |  |
| `netCarer_drop_only_at_steps` | Disability.lean | hard | `Valid` |  |
| `cgt_band` | Cgt.lean | already | any figures | band is the (parametric) BRL less Step 3 income; CGT rates 2026-27 |
| `ucAward_withCa` | CarerUc.lean | easy | any figures |  |
| `carer_uc_net` | CarerUc.lean | easy | any figures |  |
| `carer_uc_cliff` | CarerUc.lean | easy | any figures | restated: the cliff at pay `g + 1` over the earnings limit (before, `carer_uc_net` at one pay) |
| `cgtBand_scottish` | Cgt.lean | already | any figures |  |
| `mifCouple_eq` | UcSelfEmployed.lean | already | any figures | no figure of the set involved |
| `uc_flat_below_floor` | UcSelfEmployed.lean | already | any figures |  |
| `earned_plus_uc_mono_floor` | UcSelfEmployed.lean | easy | UC taper ≤ 100 % |  |
| `ctrWalesUc_excess` | CtrWorkingAge.lean | easy | any figures | the taper is `P.ucTaper`; other CTR figures 2026-27 |
| `aaCharge_le` | Reliefs.lean | easy | `Valid` | as `aaTax_slice` |
| `aaTax_slice` | Reliefs.lean | easy | `Valid` | bound is the top rate `Regime.topRate` (2026-27: 48 % / 45 %, `topRate_y2026`) |
| `valid_y2026` | TaxParams.lean | new | 2026-27 (a fact about the default set) | the 2026-27 figures meet `Valid` |
| `TaxParams.maxStep_y2026` | TaxParams.lean | new | 2026-27 (a fact about the default set) | `maxStep` is 0.686p / 0.706p for 2026-27 |
| `G_succ_le` | Cliffs.lean | new | `Valid` | the marginal bound, by bands |
| `Regime.minGain_y2026` | Cliffs.lean | new | 2026-27 (a fact about the default set) |  |
| `paStep_y2026` | Cliffs.lean | new | 2026-27 (a fact about the default set) | `PaStep` for 2026-27 is the old £2 staircase |
| `hicbcStep_y2026` | Cliffs.lean | new | 2026-27 (a fact about the default set) | `HicbcStep` for 2026-27 is the old £200 staircase |
| `net_succ_ge` | Cliffs.lean | hard | `Valid` |  |
| `Regime.maxStep_y2026` | Cliffs.lean | new | 2026-27 (a fact about the default set) |  |
| `cliffMap_complete` | CliffMap.lean | new | `Valid` | households in `CliffScope` |
| `firstAbove_eq` | CliffMap.lean | new | any figures | binary search correctness |
| `Regime.topRate_y2026` | Reliefs.lean | new | 2026-27 (a fact about the default set) |  |
| `aaCharge_le_y2026` | Reliefs.lean | new | 2026-27 (a fact about the default set) | `aaCharge_le` with `topRate_y2026`: 45 % outside Scotland, 48 % in it |
| `bandTax_eq` | Proofs.lean | new | rates in order, BRL ≤ HRL |  |
| `sliceTax_mono` | Proofs.lean | new | rates in order, BRL ≤ HRL |  |

`Valid` is `TaxParams.Valid`.

### Proved for 2026-27 only

These are about figures outside the parameter set (benefit amounts and their
limits, Class 4 and employer NICs, CGT, SDLT, LBTT and LTT, council tax and its
reductions, student loans and support, company cars, VED, the minimum wage and
ISAs), which the model holds at their 2026-27 values. As in the README, several
are checks at one point (`lbtt_ads_cliff`, `ltt_higher_cliff`, `ftb_cliff`,
`higher_cliff`, `oxford_cliffs`, `pla_cliff`, `adg_no_cliff`, `ml80c_cliff`,
`csp_cliff`, `caYear_cliff`, `ma_threshold_cliff`, `targeted_cliff`,
`targetedValue_two`, `car_50g_step`, `lisa_age_cliff`, `ved_supplement_cliff`,
`sl_unearned_cliff`, `wfp_charge_cliff`): they give the size of a jump at a named
edge, not that there is no other. `class4Exact_full_class1`
depends on a relation between specific figures (employee Class 1 at 8 % above
Class 4 at 6 % on the same band) and is stated for `TaxParams.y2026`.

| File | Theorems proved for 2026-27 only |
|---|---|
| Cgt.lean | `cgt_succ_other`, `cgt_succ_badr`, `cgt_exempt` |
| CompanyCar.lean | `rangePct_bounds`, `co2Pct_bounds`, `co2Pct_mono`, `rangePct_anti`, `carPct_bounds`, `carPct_mono`, `carPct_range`, `car_50g_step` |
| CouncilTax.lean | `ctr_step`, `ctr_full`, `councilTax_discount` |
| CtrEnglandLocal.lean | `newham_at_most_70`, `localYear_taper`, `oxford_cliffs`, `oxfordPct_anti`, `oxford_mono` |
| CtrWorkingAge.lean | `ctrWaYear_bounds`, `scotBandsEH_le_main`, `scotBandsEH_floor`, `scotTotal_bounds`, `scotTotal_le_bill`, `scot_capital_cliff` |
| Devolved.lean | `wfpAmount_eq`, `scp_cliff`, `csp_cliff`, `pawhpAmount_le` |
| Disability.lean | `caYear_anti`, `caYear_change`, `caYear_cliff`, `ma_threshold_cliff`, `ma_mono`, `jsa_total_succ`, `esa_total_gain` |
| HousingBenefit.lean | `hb_total_gain`, `hb_passport`, `hb_capital_cliff`, `nonDep_mono` |
| HousingBenefitWa.lean | `hbWa_passport`, `hbWa_capital_cliff`, `hbWa_additional_step`, `hbWa_earnings_gain`, `hbWa_cap_bounds`, `hbWa_cap_specified`, `hbWa_abolition` |
| LandTax.lean | `bandsTax_add`, `sdlt_nonResident`, `lbtt_ads_cliff`, `ltt_higher_cliff`, `lbtt_succ`, `ltt_succ` |
| Misc.lean | `lisaBonus_le`, `lisa_age_cliff`, `minimumWage_mono` |
| Nics.lean | `employerNicExact_succ`, `class4Exact_full_class1` |
| Pension.lean | `nsp_full`, `sc_core`, `sc_step`, `pc_total_succ`, `pc_total_gain`, `deemed_step` |
| Profits.lean | `reliefProfit_succ`, `propertyProfit_succ_other`, `propertyProfit_succ_room` |
| Reliefs.lean | `allowance_bounds`, `financeReduction_le` |
| Sdlt.lean | `bandsTax_succ`, `sdlt_succ`, `ftb_cliff`, `higher_cliff` |
| StudentLoans.lean | `threshold_le`, `sl_unearned_cliff`, `sl_unearned_cliff_size`, `sl_succ_earned`, `wfpAmount_le`, `wfp_charge_cliff`, `wfp_charge_benefit` |
| StudentSupport.lean | `ml80a_anti`, `ml80b_anti`, `ml80a_d_bounds`, `ml80c_cliff`, `pla_cliff`, `adg_no_cliff` |
| Targeted.lean | `targeted_cliff`, `targetedValue_two`, `targetedExtra_working` |
| Ved.lean | `ved_supplement_cliff`, `vedFirst_top`, `vedFirst_mono_lt`, `vedFirst_mono`, `vedFirstDiesel_top`, `vedFirstDiesel_mono_lt`, `vedFirstCar_mono` |
