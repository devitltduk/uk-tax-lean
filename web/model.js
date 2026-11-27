// The uktax model compiled to WebAssembly (wasm/build.sh), behind a small API.
//
// calculate(input) takes one case (an object, as the CLI's JSON input) or an
// array of cases and returns what the CLI prints, parsed. calculateText takes
// and returns JSON text, byte for byte the CLI's output.
//
// Parameter sets: this build has the 2026-27 rates and thresholds compiled in.
// Every call takes a `params` argument so the app is already wired for a model
// that accepts a parameter set (rates and thresholds as JSON); until then any
// set other than BUILTIN_PARAMS is refused rather than silently ignored.

import createUkTax from "./dist/uktax.mjs";

export const BUILTIN_PARAMS = Object.freeze({ id: "builtin-2026-27", label: "2026-27 (built into the model)" });

export class ModelError extends Error {}

export async function loadModel() {
  const t0 = performance.now();
  const mod = await createUkTax();
  if (mod._uktax_init() !== 0) throw new Error("the model failed to initialise");
  const run = mod.cwrap("uktax_run", "string", ["string"]);
  const loadMs = performance.now() - t0;

  function checkParams(params) {
    if (params !== BUILTIN_PARAMS && params?.id !== BUILTIN_PARAMS.id) {
      throw new ModelError(
        "this build of the model has the 2026-27 figures built in and cannot take a parameter set yet",
      );
    }
  }

  function calculateText(text, params = BUILTIN_PARAMS) {
    checkParams(params);
    const out = run(text);
    if (out.startsWith("error:")) throw new ModelError(out.slice(6));
    return out;
  }

  return {
    loadMs,
    calculateText,
    calculate: (input, params = BUILTIN_PARAMS) => JSON.parse(calculateText(JSON.stringify(input), params)),
  };
}
