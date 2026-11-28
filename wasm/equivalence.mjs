// Check that the WebAssembly build gives exactly the native uktax's output.
//
// Runs every golden input (tests/golden.json), N random variations of them
// (each whole number in the input rescaled at random, so every input the golden
// cases exercise is varied, and some variations are rejected by the model), and
// N random households of the kind the web app builds, through both builds, and
// asserts the JSON text is identical. Some households carry a parameter set other
// than 2026-27 (a few fixed ones, including sets that break the theorems'
// conditions, and random edits of the figures), and some ask for the cliff map. A rejected input must give the same error
// message on both. The golden cases are also run as one array, as the CLI takes them.
//
// Usage: node wasm/equivalence.mjs [--random N] [--seed S] [--binary path/to/uktax]
// Needs web/dist/uktax.mjs (wasm/build.sh) and the native binary (lake build).

import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const args = process.argv.slice(2);
const opt = (name, dflt) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : dflt;
};
const N = Number(opt("--random", "500"));
const SEED = Number(opt("--seed", "1"));
const BINARY = opt("--binary", path.join(ROOT, ".lake/build/bin/uktax"));

const { default: createUkTax } = await import(path.join(ROOT, "web/dist/uktax.mjs"));
const mod = await createUkTax();
if (mod._uktax_init() !== 0) throw new Error("wasm initialisation failed");
const wasmRun = mod.cwrap("uktax_run", "string", ["string"]);

// Same shape as wasmRun: the compressed JSON, or "error:" and the message.
function nativeRun(input) {
  const p = spawnSync(BINARY, { input, encoding: "utf8", maxBuffer: 1 << 30 });
  if (p.error) throw p.error;
  if (p.status === 0) return p.stdout.replace(/\n$/, "");
  return "error:" + p.stderr.replace(/^uktax: /, "").replace(/\n$/, "");
}

// mulberry32
let s = SEED >>> 0;
function rand() {
  s = (s + 0x6d2b79f5) >>> 0;
  let t = s;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
const pick = (xs) => xs[Math.floor(rand() * xs.length)];
const int = (lo, hi) => lo + Math.floor(rand() * (hi - lo + 1));

function mutate(v) {
  if (Array.isArray(v)) return v.map(mutate);
  if (v && typeof v === "object") {
    return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, mutate(x)]));
  }
  if (Number.isInteger(v) && rand() < 0.6) {
    return rand() < 0.1 ? 0 : Math.round(v * rand() * 3 + (v === 0 ? int(0, 5_000_000) * (rand() < 0.2) : 0));
  }
  return v;
}

// Parameter sets other than 2026-27: fixed ones, and random edits.
const PARAM_SETS = [
  {},
  { personal_allowance_income_limit_pence: 11_000_000 },
  { basic_rate_bp: 4000, higher_rate_bp: 3500, savings_basic_rate_bp: 4000, savings_higher_rate_bp: 3500 },
  { personal_allowance_pence: 1_500_000, basic_rate_limit_pence: 4_000_000,
    uc_taper_percent: 50, hicbc_threshold_pence: 8_000_000, hicbc_step_pence: 40_000,
    childcare_income_limit_pence: 12_000_000 },
  { scottish_higher_rate_bp: 4500, scottish_top_rate_bp: 5000, dividend_upper_rate_bp: 3375,
    nic_main_rate_bp: 600, nic_primary_threshold_monthly_pence: 110_000 },
  { additional_rate_bp: 9000, uc_taper_percent: 120 },
];
const EDITABLE = [
  ["personal_allowance_pence", 0, 3_000_000], ["personal_allowance_income_limit_pence", 0, 20_000_000],
  ["basic_rate_limit_pence", 0, 8_000_000],
  ["basic_rate_bp", 0, 6000], ["higher_rate_bp", 0, 7000], ["dividend_allowance_pence", 0, 500_000],
  ["nic_main_rate_bp", 0, 2000], ["hicbc_threshold_pence", 0, 12_000_000], ["hicbc_step_pence", 0, 100_000],
  ["uc_taper_percent", 0, 100], ["childcare_income_limit_pence", 0, 20_000_000],
];
function params() {
  if (rand() < 0.5) return pick(PARAM_SETS);
  const p = {};
  for (let i = int(1, 4); i > 0; i--) {
    const [k, lo, hi] = pick(EDITABLE);
    p[k] = int(lo, hi);
  }
  return p;
}

function household() {
  const pay = pick([int(0, 15_000_000), int(9_000_000, 13_000_000), int(0, 5_000_000)]);
  const children = int(0, 4);
  const uc = rand() < 0.35;
  const c = {
    non_savings_pence: pay,
    employment_pence: pay,
    savings_pence: uc ? 0 : pick([0, 0, int(0, 2_000_000)]),
    dividends_pence: uc ? 0 : pick([0, 0, int(0, 5_000_000)]),
    country: pick(["england", "wales", "northern_ireland", "scotland"]),
    nic_earnings_period: pick(["annual", "monthly", "weekly"]),
    child_benefit_children: children,
  };
  const young = Array.from({ length: children }, () => pick(["under_2", "2", "3_4", "school"]));
  const costs = young.filter((a) => a !== "school" && rand() < 0.7).map(() => int(0, 1_500_000));
  if (costs.length) c.childcare_costs_pence = costs;
  const funded = young.filter((a) => a !== "school").map((age) => ({ age }));
  if (funded.length && rand() < 0.7) c.funded_children = funded;
  if (uc) {
    c.uc = { couple: rand() < 0.3, children };
    if (rand() < 0.5) c.uc.rent_monthly_pence = int(30_000, 150_000);
    if (rand() < 0.3) c.uc.childcare_monthly_pence = int(0, 200_000);
    if (rand() < 0.2) c.uc.health = pick(["none", "new", "protected"]);
  } else if (rand() < 0.2) {
    const p = int(0, 12_000_000);
    c.partner = { pay_pence: p, adjusted_net_income_pence: p };
  }
  if (!uc && !c.partner && rand() < 0.15) c.marriage_allowance = pick(["transfer", "receive"]);
  if (!uc && rand() < 0.15) c.pension_relief_at_source_gross_pence = int(0, 2_000_000);
  if (rand() < 0.4) c.params = params();
  if (rand() < 0.1) c.cliff_map = { max_pay_pence: pick([15_000_000, int(0, 20_000_000)]) };
  return c;
}

const golden = JSON.parse(readFileSync(path.join(ROOT, "tests/golden.json"), "utf8")).map((c) => c.input);
const cases = [
  ...golden.map((input) => ["golden", input]),
  ...Array.from({ length: N }, () => ["golden, varied", mutate(pick(golden))]),
  ...Array.from({ length: N }, () => ["household", household()]),
];

let failures = 0;
let errors = 0;
const fail = (label, input, w, n) => {
  failures++;
  if (failures <= 5) {
    console.error(`MISMATCH (${label}): ${input}\n  wasm:   ${w}\n  native: ${n}`);
  }
};
// The inputs the wasm build accepts are compared as one array (one native
// process, the CLI's batch mode); the text of the two outputs must match
// exactly. If it does not, or for inputs the wasm build rejects, each input is
// compared on its own, so a mismatch is reported against its input.
const inputs = cases.map(([, c]) => JSON.stringify(c));
const wasmOut = inputs.map((input) => wasmRun(input));
const accepted = inputs.filter((_, i) => !wasmOut[i].startsWith("error:"));
const acceptedBatch = `[${accepted.join(",")}]`;
const batchSame = wasmRun(acceptedBatch) === nativeRun(acceptedBatch);
inputs.forEach((input, i) => {
  if (batchSame && !wasmOut[i].startsWith("error:")) return;
  const n = nativeRun(input);
  if (n.startsWith("error:")) errors++;
  if (wasmOut[i] !== n) fail(cases[i][0], input, wasmOut[i], n);
});
if (!batchSame && failures === 0) fail("accepted inputs, as one array", "(all accepted inputs)", "differs", "");
const batch = JSON.stringify(golden);
const wb = wasmRun(batch);
const nb = nativeRun(batch);
if (wb !== nb) fail("golden, as one array", "(all golden inputs)", wb.slice(0, 200), nb.slice(0, 200));

console.log(
  `${cases.length} inputs (${golden.length} golden, ${N} golden varied, ${N} households; ` +
    `${errors} rejected by the model, with the same message on both), plus the golden inputs as one ` +
    `array and the ${accepted.length} accepted inputs as one array: ${failures} mismatches (seed ${SEED})`,
);
process.exit(failures ? 1 : 0);
