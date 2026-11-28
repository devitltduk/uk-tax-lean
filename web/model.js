// The uktax model compiled to WebAssembly (wasm/build.sh), behind a small API.
//
// calculate(input, params) takes one case (an object, as the CLI's JSON input) or
// an array of cases and returns what the CLI prints, parsed. calculateText takes
// and returns JSON text, byte for byte the CLI's output.
//
// Parameter sets: `params` is null for the 2026-27 figures built into the model,
// or an object of figures (the CLI's `params` field: pence, basis points, the UC
// taper in per cent) replacing some of them. The model checks the set against the
// conditions its theorems need and returns the result as `params_check`, and the
// figures worked out from the set (the higher rate limit) as `params_derived`.

import createUkTax from "./dist/uktax.mjs";

export const BUILTIN_PARAMS = null;

export class ModelError extends Error {}

export async function loadModel() {
  const t0 = performance.now();
  const mod = await createUkTax();
  if (mod._uktax_init() !== 0) throw new Error("the model failed to initialise");
  const run = mod.cwrap("uktax_run", "string", ["string"]);
  const loadMs = performance.now() - t0;

  function calculateText(text) {
    const out = run(text);
    if (out.startsWith("error:")) throw new ModelError(out.slice(6));
    return out;
  }

  const withParams = (c, params) => (params ? { ...c, params } : c);

  function calculate(input, params = BUILTIN_PARAMS) {
    const cases = Array.isArray(input) ? input.map((c) => withParams(c, params)) : withParams(input, params);
    return JSON.parse(calculateText(JSON.stringify(cases)));
  }

  // The built-in figures, and those worked out from them (the higher rate limit),
  // read from the model itself.
  const builtin = calculate({ non_savings_pence: 0, savings_pence: 0, dividends_pence: 0 }, {});
  const defaults = builtin.params;
  const derived = builtin.params_derived;

  return { loadMs, calculateText, calculate, defaults, derived };
}
