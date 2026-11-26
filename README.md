# uk-tax-lean

UK income tax for 2026-27 (England, Wales and Northern Ireland: rUK rates),
formalised in Lean 4, with proofs about it and a harness that checks it against
[PolicyEngine UK](https://github.com/PolicyEngine/policyengine-uk).

## What is modelled

One individual whose income is non-savings income (e.g. pay or pension), savings
interest and dividends, following the steps of ITA 2007 s23:

- **Personal allowance** £12,570, tapered by half the excess of adjusted net
  income over £100,000, the result rounded up to a whole pound (s35).
- **Allowance placement** in the way that gives the least tax (s25(2)). No fixed
  order does that: setting the allowance against dividends can keep the
  starting rate for savings, and setting it against savings can lift the savings
  allowance into the higher band. The model searches the corners of the
  piecewise-linear tax (see `UkTax/Calc.lean`).
- **Bands** (on income after allowances): basic up to £37,700, higher up to
  £125,140, additional above.
- **Non-savings and savings rates** 20 / 40 / 45 %.
- **Starting rate for savings** 0 % on savings within the lowest £5,000.
- **Personal savings allowance** £1,000 / £500 / £0 by the highest band reached.
- **Dividend allowance** £500 at 0 %, then the dividend rates **10.75 / 35.75 / 39.35 %**.
- Savings sit above non-savings income and dividends on top (s16). Income at a nil
  rate still uses up its band.

All amounts are whole pence (`Nat`), and rates are basis points. Tax is computed
exactly, in 1/10,000 of a penny, and rounded down to the penny once at the end.

### 2026-27 figures and sources

Checked against legislation.gov.uk and GOV.UK on 2026-11-26. Each one is in
`UkTax/Params.lean` with its citation.

| Figure | 2026-27 | Source |
|---|---|---|
| Personal allowance | £12,570 | [ITA 2007 s35(1)](https://www.legislation.gov.uk/ukpga/2007/3/section/35); frozen by FA 2021 s5, FA 2026 s10 |
| Taper | above £100,000, half the excess, round up to £1 | ITA 2007 s35(2)-(3) |
| Basic rate limit | £37,700 | [ITA 2007 s10(5)](https://www.legislation.gov.uk/ukpga/2007/3/section/10) |
| Higher rate limit | £125,140 (2 × PA + £100,000) | ITA 2007 s10(5A) |
| Basic / higher / additional rate | 20 / 40 / 45 % | [Finance Act 2026 s2](https://www.legislation.gov.uk/ukpga/2026/11) |
| Savings rates | 20 / 40 / 45 % (22 / 42 / 47 % only from 2027-28) | Finance Act 2026 s3, s5 |
| Starting rate for savings | 0 % up to £5,000 | [ITA 2007 s12](https://www.legislation.gov.uk/ukpga/2007/3/section/12); FA 2026 s9 |
| Personal savings allowance | £1,000 / £500 / £0 | [ITA 2007 s12B](https://www.legislation.gov.uk/ukpga/2007/3/section/12B) |
| Dividend allowance | £500 | [ITA 2007 s13A](https://www.legislation.gov.uk/ukpga/2007/3/section/13A) |
| Dividend ordinary / upper / additional | 10.75 / 35.75 / 39.35 % | [ITA 2007 s8](https://www.legislation.gov.uk/ukpga/2007/3/section/8) as amended by FA 2026 s4 |

GOV.UK summary pages: [Income Tax rates](https://www.gov.uk/income-tax-rates),
[tax on savings interest](https://www.gov.uk/apply-tax-free-interest-on-savings/how-much-is-tax-free),
[tax on dividends](https://www.gov.uk/tax-on-dividends).

## Out of scope

Scottish and Welsh rates, National Insurance, reliefs and deductions (pension
contributions, Gift Aid, losses, the trading and property allowances), Marriage
Allowance and Blind Person's Allowance, other tax reductions, property income's
own rates (from 2027-28), the default rates for non-residents, top-slicing relief,
foreign income, capital gains, and every tax year other than 2026-27.

## What is proved

In `UkTax/Proofs.lean`, with no `sorry`. `UkTax/Axioms.lean` fails the build if a
theorem ever depends on more than Lean's standard axioms.

- `leastTax_mono`: the least tax over all legal ways of deducting the allowance
  (the s25(2) liability) never goes down when any kind of income goes up. This
  has to hold through the taper, savings and dividends moving into higher
  bands, and the savings allowance dropping from £1,000 to £500 to £0 at a
  cliff edge.
- `liability_mono_nonSavings_only`: the computed `liability` is monotone in
  non-savings income for someone with no savings or dividends.
- `liability_mono_of_optimal`: the computed `liability` is monotone in every
  kind of income, given that the corner search finds the least tax.
- `bestAlloc_feasible`: the search only picks legal allowance placements, so the
  computed liability is never below the least tax.

**Not yet proved:** that the corner search always finds the least tax. The
argument is in `UkTax/Calc.lean`, and the golden cases and PolicyEngine
comparison check it in practice. PolicyEngine runs the same kind of search on its own.

## Running it

Lean is pinned in `lean-toolchain`, and there are no dependencies (no Mathlib).

```sh
lake build --wfail            # model, proofs, axiom guard and the uktax binary
python3 tests/golden.py       # hand-checked golden cases against the binary
```

`uktax` reads JSON on stdin (one object or an array) and prints JSON:

```sh
$ echo '{"non_savings_pence": 2957000, "savings_pence": 0, "dividends_pence": 300000}' \
    | .lake/build/bin/uktax
{"allowance_against_dividends_pence":0,"allowance_against_savings_pence":0,"liability_pence":366875,"personal_allowance_pence":1257000,"savings_allowance_pence":100000}
```

### Golden cases

`tests/golden.json` holds 14 cases with the expected liability worked out by
hand and the working shown. Two are GOV.UK's own 2026-27 worked examples (tax on
dividends; the savings allowance). The others are aimed at edges: the taper and its
round-up, the additional rate, the savings allowance at exactly £37,700 and 1p
over, dividends across bands, the allowance set against dividends or savings,
and both s25(2) choices.

### Comparing with PolicyEngine UK

```sh
lake build
cd harness
uv run python compare.py                 # ~2,000 threshold edge cases + 500 random
uv run python compare.py --random 5000   # more random cases
```

The harness is a uv project that pins `policyengine-uk==2.180.2`. It runs every
case through both models, writes `harness/out/comparison.csv` and exits non-zero
if any case differs by more than `--tolerance` pence (default 2). PolicyEngine
works in float32, and above £131,072 an amount is held only to the nearest 1.56p.

It runs in CI as well (about 30 s for 3,000 cases). On NixOS, numpy needs
`libstdc++`: run with `LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH` (nix-ld) or from a
shell that provides it.

## CI

GitHub Actions (`.github/workflows/ci.yml`) builds with `--wfail`, checks the
proofs and the axiom guard, runs the golden cases, then runs the PolicyEngine
comparison with 1,000 random cases.
