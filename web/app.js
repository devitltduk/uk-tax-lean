import { loadModel, BUILTIN_PARAMS, ModelError } from "./model.js";

const $ = (id) => document.getElementById(id);
const form = $("form");
const gbp = new Intl.NumberFormat("en-GB", { style: "currency", currency: "GBP" });
const gbp0 = new Intl.NumberFormat("en-GB", { style: "currency", currency: "GBP", maximumFractionDigits: 0 });
const pence = (pounds) => Math.max(0, Math.round(Number(pounds || 0) * 100));
const AGES = [["under_2", "under 2"], ["2", "2"], ["3_4", "3 or 4"], ["school", "5 or over"]];

let model;

// --- the figures editor ---------------------------------------------------------

// The main figures, as the model's `params` fields. "£" fields are pence shown as
// pounds, "%" fields basis points shown as per cent, "pc" whole per cent. `also`
// lists fields set to the same value (savings income is taxed at the main rates).
const FIELDS = [
  ["Income tax"],
  ["personal_allowance_pence", "Personal allowance", "£"],
  ["personal_allowance_income_limit_pence", "Allowance taper starts at (income)", "£"],
  ["basic_rate_limit_pence", "Basic rate limit (above the allowance)", "£"],
  ["higher_rate_limit_pence", "Higher rate limit", "£"],
  ["basic_rate_bp", "Basic rate", "%", ["savings_basic_rate_bp"]],
  ["higher_rate_bp", "Higher rate", "%", ["savings_higher_rate_bp"]],
  ["additional_rate_bp", "Additional rate", "%", ["savings_additional_rate_bp"]],
  ["Dividends"],
  ["dividend_allowance_pence", "Dividend allowance", "£"],
  ["dividend_ordinary_rate_bp", "Ordinary rate", "%"],
  ["dividend_upper_rate_bp", "Upper rate", "%"],
  ["dividend_additional_rate_bp", "Additional rate", "%"],
  ["National Insurance (employee)"],
  ["nic_main_rate_bp", "Main rate", "%"],
  ["nic_additional_rate_bp", "Additional rate", "%"],
  ["Child Benefit charge, childcare and Universal Credit"],
  ["hicbc_threshold_pence", "Child Benefit charge starts at", "£"],
  ["hicbc_step_pence", "Income for each 1% of the charge", "£"],
  ["childcare_income_limit_pence", "Childcare help income limit", "£"],
  ["uc_taper_percent", "Universal Credit taper", "pc"],
];
const shown = (unit, v) => (unit === "£" ? v / 100 : unit === "%" ? v / 100 : v);
const stored = (unit, x) => Math.max(0, Math.round(Number(x || 0) * (unit === "pc" ? 1 : 100)));

function buildEditor() {
  const box = $("paramFields");
  for (const [key, label, unit] of FIELDS) {
    if (!label) {
      const h = document.createElement("h3");
      h.textContent = key;
      box.append(h);
      continue;
    }
    const l = document.createElement("label");
    l.dataset.key = key;
    l.textContent = `${label} (${unit === "£" ? "£" : "%"})`;
    const input = document.createElement("input");
    Object.assign(input, { type: "number", min: "0", step: unit === "pc" ? "1" : "0.01", name: `p_${key}` });
    input.value = shown(unit, model.defaults[key]);
    l.append(input);
    box.append(l);
  }
  $("resetParams").addEventListener("click", () => {
    for (const [key, label, unit] of FIELDS) if (label) form[`p_${key}`].value = shown(unit, model.defaults[key]);
    update();
  });
}

// The figures that differ from the built-in ones, or null if none do.
function editedParams() {
  const out = {};
  for (const [key, label, unit, also = []] of FIELDS) {
    if (!label) continue;
    const v = stored(unit, form[`p_${key}`].value);
    form[`p_${key}`].parentElement.classList.toggle("changed", v !== model.defaults[key]);
    if (v === model.defaults[key]) continue;
    out[key] = v;
    for (const k of also) out[k] = v;
  }
  return Object.keys(out).length ? out : BUILTIN_PARAMS;
}

function showCheck(r, params) {
  const el = $("paramsStatus");
  el.replaceChildren();
  if (!params) {
    el.textContent = "The 2026-27 figures: the guarantees hold.";
    el.className = "check-status ok";
    return;
  }
  const chk = r.params_check;
  if (chk.ok) {
    el.textContent = "The guarantees hold for these figures.";
    el.className = "check-status ok";
    return;
  }
  el.className = "check-status error";
  el.append("The guarantees do not hold for these figures:");
  const ul = document.createElement("ul");
  for (const v of chk.violations) {
    const li = document.createElement("li");
    li.textContent = v.message;
    ul.append(li);
  }
  el.append(ul);
}

// --- form -> model input ------------------------------------------------------

function kidRows() {
  const n = Math.min(6, Math.max(0, Math.floor(Number(form.children.value) || 0)));
  const box = $("kids");
  while (box.children.length < n) {
    const i = box.children.length + 1;
    const row = document.createElement("div");
    row.className = "kid";
    row.innerHTML = `<span>Child ${i}</span>
      <label>Age <select data-k="age">${AGES.map(([v, l]) => `<option value="${v}">${l}</option>`).join("")}</select></label>
      <label>Childcare (£ a year) <input data-k="cost" type="number" min="0" step="0.01" value="0"></label>`;
    box.append(row);
  }
  while (box.children.length > n) box.lastElementChild.remove();
  return [...box.children].map((row) => ({
    age: row.querySelector('[data-k="age"]').value,
    cost: pence(row.querySelector('[data-k="cost"]').value),
  }));
}

function situation() {
  for (const el of form.querySelectorAll(".dep")) el.hidden = !form[el.dataset.dep].checked;
  const kids = kidRows();
  return {
    pay: pence(form.pay.value),
    params: editedParams(),
    input(pay) {
      const c = {
        non_savings_pence: pay,
        employment_pence: pay,
        savings_pence: pence(form.savings.value),
        dividends_pence: pence(form.dividends.value),
        country: form.country.value,
        nic_earnings_period: form.period.value,
        child_benefit_children: kids.length,
      };
      const pension = pence(form.pension.value);
      if (pension) c.pension_relief_at_source_gross_pence = pension;
      const costs = kids.filter((k) => k.cost > 0).map((k) => k.cost);
      if (costs.length) c.childcare_costs_pence = costs;
      const young = kids.filter((k) => k.age !== "school").map((k) => ({ age: k.age }));
      if (young.length) c.funded_children = young;
      if (form.partner.checked) {
        const p = pence(form.partnerPay.value);
        c.partner = { pay_pence: p, adjusted_net_income_pence: p };
      }
      if (form.uc.checked) {
        c.uc = { couple: form.ucCouple.checked, children: kids.length };
        const rent = pence(form.rent.value);
        if (rent) c.uc.rent_monthly_pence = rent;
      }
      if (form.ma.value) c.marriage_allowance = form.ma.value;
      return c;
    },
  };
}

// Take-home in pounds from the model's output (net_income_millionths_pence).
const takeHome = (r) => (r.net_income_millionths_pence == null ? null : r.net_income_millionths_pence / 1e8);

// --- result and breakdown ---------------------------------------------------------

function showResult(s) {
  const input = s.input(s.pay);
  const t0 = performance.now();
  const r = model.calculate(input, s.params);
  const ms = performance.now() - t0;
  showCheck(r, s.params);
  const net = takeHome(r);
  $("net").textContent = net == null ? "n/a" : gbp.format(net);
  $("netMonthly").textContent = net == null ? "" : `${gbp.format(net / 12)} a month`;

  const ucCounted = r.uc_millionths_pence >= r.tfc_millionths_pence;
  const rows = [
    ["Pay", input.employment_pence / 100],
    ["Savings interest", input.savings_pence / 100],
    ["Dividends", input.dividends_pence / 100],
    ["Income tax", -r.tax_exact_ten_thousandths_pence / 1e6],
    ["Employee National Insurance", -r.nic_exact_ten_thousandths_pence / 1e6],
    ["High Income Child Benefit Charge", -r.hicbc_pence / 100],
    ["Child Benefit", r.child_benefit_pence / 100],
    ["Universal Credit", r.uc_millionths_pence / 1e8, !ucCounted && r.uc_millionths_pence > 0],
    ["Tax-Free Childcare top-up", r.tfc_millionths_pence / 1e8, ucCounted && r.tfc_millionths_pence > 0],
    ["Funded childcare hours (value)", r.funded_hours_millionths_pence / 1e8],
  ];
  const body = $("breakdown").tBodies[0];
  body.replaceChildren();
  for (const [label, v, notCounted] of rows) {
    if (v === 0 && !["Pay", "Income tax", "Employee National Insurance"].includes(label)) continue;
    const tr = body.insertRow();
    tr.insertCell().textContent = label + (notCounted ? " (not counted: the larger of UC and Tax-Free Childcare is)" : "");
    const td = tr.insertCell();
    td.textContent = (v < 0 ? "− " : "") + gbp.format(Math.abs(v));
    if (notCounted) tr.className = "muted";
  }
  const tr = body.insertRow();
  tr.className = "total";
  tr.insertCell().textContent = "Take-home";
  tr.insertCell().textContent = net == null ? "n/a" : gbp.format(net);
  return { r, ms };
}

// --- chart -------------------------------------------------------------------------

const W = 720, H = 340, M = { l: 64, r: 32, t: 24, b: 40 };
const POINTS = 600;

function sweep(s) {
  const maxPay = Math.max(15_000_000, Math.ceil((s.pay * 1.3) / 1_000_000) * 1_000_000);
  const step = Math.round(maxPay / POINTS);
  const pays = Array.from({ length: POINTS + 1 }, (_, i) => i * step);
  const t0 = performance.now();
  const out = model.calculate(pays.map((g) => s.input(g)), s.params);
  const ms = performance.now() - t0;
  const nets = out.map(takeHome);
  // Where take-home falls, from the model's cliff map: every penny the cliff
  // theorem allows is evaluated (the personal allowance band at its two ends), and
  // `cliffMap_complete` proves nothing is missed when the guarantees hold.
  const t1 = performance.now();
  const cm = model.calculate({ ...s.input(0), cliff_map: { max_pay_pence: maxPay } }, s.params).cliff_map;
  const cliffs = [];
  const bands = [];
  if (cm) {
    const one = cm.drops.filter((d) => d.kind !== "hicbc");
    const after = one.length ? model.calculate(one.map((d) => s.input(d.pay_pence + 1)), s.params).map(takeHome) : [];
    one.forEach((d, i) => cliffs.push({ pay: (d.pay_pence + 1) / 100, net: after[i], drop: d.drop_millionths_pence / 1e8, kind: d.kind }));
    const hicbc = cm.drops.filter((d) => d.kind === "hicbc");
    if (hicbc.length) {
      const sizes = hicbc.map((d) => d.drop_millionths_pence / 1e8);
      bands.push({ kind: "hicbc", from: (hicbc[0].pay_pence + 1) / 100, to: (hicbc.at(-1).pay_pence + 1) / 100,
        count: hicbc.length, min: Math.min(...sizes), max: Math.max(...sizes) });
    }
    const b = cm.personal_allowance_band;
    if (b) {
      const sizes = [b.first_drop_millionths_pence, b.last_drop_millionths_pence].map((x) => x / 1e8);
      bands.push({ kind: "personal_allowance", from: (b.first_pay_pence + 1) / 100, to: (b.last_pay_pence + 1) / 100,
        count: b.count, min: Math.min(...sizes), max: Math.max(...sizes) });
    }
  }
  const cmMs = performance.now() - t1;
  return { pays: pays.map((g) => g / 100), nets, cliffs, bands, cm, ms, cmMs };
}

const KIND = {
  personal_allowance: "Personal allowance taper (£1 off the allowance per £2)",
  hicbc: "High Income Child Benefit Charge (1% more per step)",
  savings_allowance: "Personal savings allowance falls (or a rate limit)",
  marriage_allowance: "Marriage Allowance lost",
  childcare: "Tax-Free Childcare and funded hours lost",
};

function svg(tag, attrs, parent) {
  const el = document.createElementNS("http://www.w3.org/2000/svg", tag);
  for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v);
  if (parent) parent.append(el);
  return el;
}

function niceStep(max, n) {
  const raw = max / n, p = 10 ** Math.floor(Math.log10(raw));
  return [1, 2, 2.5, 5, 10].map((m) => m * p).find((x) => x >= raw);
}

function drawChart(sw, you) {
  const box = $("chart");
  box.replaceChildren();
  const pts = sw.pays.map((x, i) => [x, sw.nets[i]]).filter(([, y]) => y != null);
  if (!pts.length) { box.textContent = "Take-home is not defined for this situation."; return; }
  const xMax = sw.pays.at(-1);
  const yMax = Math.max(...pts.map(([, y]) => y), 1) * 1.05;
  const x = (v) => M.l + (v / xMax) * (W - M.l - M.r);
  const y = (v) => H - M.b - (v / yMax) * (H - M.t - M.b);
  const root = svg("svg", { viewBox: `0 0 ${W} ${H}`, role: "img",
    "aria-label": `Take-home against pay from £0 to ${gbp0.format(xMax)}, ${sw.cliffs.length} cliffs` }, box);

  const g = svg("g", { class: "grid" }, root);
  const ys = niceStep(yMax, 5);
  for (let v = 0; v <= yMax; v += ys) {
    svg("line", { x1: M.l, x2: W - M.r, y1: y(v), y2: y(v) }, g);
    svg("text", { x: M.l - 8, y: y(v) + 4, "text-anchor": "end" }, g).textContent = gbp0.format(v);
  }
  const xs = niceStep(xMax, 6);
  for (let v = 0; v <= xMax; v += xs) {
    svg("text", { x: x(v), y: H - M.b + 18, "text-anchor": "middle" }, g).textContent = gbp0.format(v);
  }
  svg("text", { x: (M.l + W - M.r) / 2, y: H - 4, "text-anchor": "middle" }, g).textContent = "Pay (a year)";

  // reference: take-home equal to pay (no tax, no benefits)
  const lim = Math.min(xMax, yMax);
  svg("line", { class: "ref", x1: x(0), y1: y(0), x2: x(lim), y2: y(lim) }, root);
  svg("text", { class: "ref-label", x: x(lim * 0.3) + 6, y: y(lim * 0.3) + 4 }, root).textContent = "take-home = pay";

  for (const b of sw.bands) {
    if (b.from > xMax) continue;
    const x0 = x(b.from), x1 = x(Math.min(b.to, xMax));
    svg("rect", { class: "band", x: x0, y: M.t, width: Math.max(2, x1 - x0), height: H - M.t - M.b }, root);
    svg("text", { class: "band-label", x: x0 + 3, y: M.t + 24 + (b.kind === "hicbc" ? 12 : 0) }, root).textContent =
      b.kind === "hicbc" ? "Child Benefit charge" : "allowance taper";
  }
  svg("path", { class: "line", d: pts.map(([a, b], i) => `${i ? "L" : "M"}${x(a).toFixed(1)},${y(b).toFixed(1)}`).join("") }, root);

  if (you != null && you <= xMax) {
    svg("line", { class: "you", x1: x(you), x2: x(you), y1: M.t, y2: H - M.b }, root);
    svg("text", { class: "you-label", x: x(you) + 4, y: M.t + 10 }, root).textContent = "you";
  }
  for (const c of sw.cliffs) {
    if (c.pay > xMax || c.net == null) continue;
    svg("circle", { class: "cliff", cx: x(c.pay), cy: y(c.net), r: 5 }, root);
  }
  const big = [...sw.cliffs].filter((c) => c.pay <= xMax && c.net != null).sort((a, b) => b.drop - a.drop)[0];
  if (big) {
    svg("text", { class: "cliff-label", x: x(big.pay) + 8, y: y(big.net) + 16 }, root).textContent =
      `cliff at ${gbp0.format(big.pay)}: −${gbp0.format(big.drop)}`;
  }

  // hover: crosshair snapped to the nearest sweep point, one tooltip
  const hair = svg("line", { class: "hair", y1: M.t, y2: H - M.b, visibility: "hidden" }, root);
  const dot = svg("circle", { class: "hover-dot", r: 4, visibility: "hidden" }, root);
  const tip = document.createElement("div");
  tip.className = "tip";
  tip.hidden = true;
  box.append(tip);
  const hit = svg("rect", { x: M.l, y: M.t, width: W - M.l - M.r, height: H - M.t - M.b, fill: "transparent", tabindex: 0 }, root);
  const show = (i) => {
    const [px, py] = pts[i];
    hair.setAttribute("x1", x(px)); hair.setAttribute("x2", x(px)); hair.setAttribute("visibility", "visible");
    dot.setAttribute("cx", x(px)); dot.setAttribute("cy", y(py)); dot.setAttribute("visibility", "visible");
    const prev = pts[Math.max(0, i - 1)], next = pts[Math.min(pts.length - 1, i + 1)];
    const mtr = next[0] === prev[0] ? null : 1 - (next[1] - prev[1]) / (next[0] - prev[0]);
    tip.replaceChildren();
    const strong = document.createElement("strong");
    strong.textContent = gbp.format(py);
    tip.append(strong, ` take-home at ${gbp0.format(px)} pay`);
    if (mtr != null) {
      const p = document.createElement("div");
      p.textContent = `keeps ${Math.round((1 - mtr) * 100)}p of each extra £1 here`;
      tip.append(p);
    }
    tip.hidden = false;
    const r = root.getBoundingClientRect();
    const left = (x(px) / W) * r.width;
    tip.style.left = `${Math.min(left + 12, r.width - 230)}px`;
    tip.style.top = `${(y(py) / H) * r.height - 50}px`;
  };
  const nearest = (clientX) => {
    const r = root.getBoundingClientRect();
    const v = (((clientX - r.left) / r.width) * W - M.l) / (W - M.l - M.r) * xMax;
    let best = 0;
    for (let i = 1; i < pts.length; i++) if (Math.abs(pts[i][0] - v) < Math.abs(pts[best][0] - v)) best = i;
    return best;
  };
  let cur = 0;
  hit.addEventListener("pointermove", (e) => show((cur = nearest(e.clientX))));
  hit.addEventListener("pointerleave", () => { tip.hidden = true; hair.setAttribute("visibility", "hidden"); dot.setAttribute("visibility", "hidden"); });
  hit.addEventListener("keydown", (e) => {
    if (e.key === "ArrowRight") show((cur = Math.min(pts.length - 1, cur + 1)));
    if (e.key === "ArrowLeft") show((cur = Math.max(0, cur - 1)));
  });

  const body = $("cliffs").tBodies[0];
  body.replaceChildren();
  const rows = [
    ...sw.cliffs.map((c) => ({ at: c.pay, cells: [gbp.format(c.pay - 0.01), KIND[c.kind], gbp.format(c.drop)] })),
    ...sw.bands.map((b) => ({ at: b.from, cells: [
      `${gbp.format(b.from - 0.01)} to ${gbp.format(b.to - 0.01)}, ${b.count.toLocaleString("en-GB")} steps`,
      KIND[b.kind],
      b.min.toFixed(2) === b.max.toFixed(2) ? `${gbp.format(b.min)} each` : `${gbp.format(b.min)} to ${gbp.format(b.max)} each`] })),
  ].sort((a, b) => a.at - b.at);
  for (const row of rows) {
    const tr = body.insertRow();
    for (const c of row.cells) tr.insertCell().textContent = c;
  }
  if (!rows.length) body.insertRow().insertCell().textContent = "No cliffs in this range.";
  const note = $("cliffNote");
  if (!sw.cm) note.textContent = "The cliff map is not available for this situation (income other than pay, or Carer's Allowance with Universal Credit).";
  else if (sw.cm.guaranteed) note.textContent = `Every cliff below ${gbp0.format(sw.cm.max_pay_pence / 100)} of pay is listed: proved for these figures (cliffMap_complete).`;
  else if (!sw.cm.in_scope) note.textContent = "The cliff list is not proved complete for this situation (Marriage Allowance transfer, or received with savings or dividends).";
  else note.textContent = "These figures break a condition the theorems need, so the cliff list is not proved complete.";
}

// --- wiring ------------------------------------------------------------------------

let pending;
function update() {
  clearTimeout(pending);
  pending = setTimeout(() => {
    const s = situation();
    $("error").hidden = true;
    $("result").hidden = false;
    try {
      const { ms } = showResult(s);
      const sw = sweep(s);
      drawChart(sw, s.pay / 100);
      $("timing").textContent =
        `Model loaded in ${model.loadMs.toFixed(0)} ms. This calculation: ${ms.toFixed(2)} ms. ` +
        `Chart: ${POINTS + 1} calculations in one call, ${sw.ms.toFixed(0)} ms ` +
        `(${((sw.ms / (POINTS + 1)) * 1000).toFixed(0)} µs each); cliff map ${sw.cmMs.toFixed(0)} ms.`;
    } catch (e) {
      if (!(e instanceof ModelError)) throw e;
      $("error").textContent = `The model can't calculate this: ${e.message}`;
      $("error").hidden = false;
      $("result").hidden = true;
      $("chart").replaceChildren();
    }
  }, 120);
}

async function runGolden() {
  const out = $("goldenResult");
  out.textContent = "Running…";
  let cases;
  try {
    const res = await fetch("../tests/golden.json");
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    cases = await res.json();
  } catch (e) {
    out.textContent = `Could not load ../tests/golden.json (${e.message}). Serve the repository root, not web/.`;
    return;
  }
  const t0 = performance.now();
  const results = model.calculate(cases.map((c) => c.input));
  const ms = performance.now() - t0;
  const META = new Set(["name", "source", "working", "input"]);
  const failed = cases.filter((c, i) =>
    Object.keys(c).some((k) => !META.has(k) && JSON.stringify(results[i][k]) !== JSON.stringify(c[k])));
  out.textContent = `${cases.length - failed.length}/${cases.length} golden cases match their hand-worked values ` +
    `(${ms.toFixed(0)} ms for all).` + (failed.length ? ` Failed: ${failed.map((c) => c.name).join("; ")}` : "");
  out.className = failed.length ? "error" : "ok";
}

try {
  model = await loadModel();
  $("status").textContent = `Model loaded in ${model.loadMs.toFixed(0)} ms (WebAssembly).`;
  buildEditor();
  form.addEventListener("input", update);
  $("golden").addEventListener("click", runGolden);
  window.uktax = model; // for checking from the console
  update();
} catch (e) {
  $("status").textContent = `The model failed to load: ${e.message}. Has wasm/build.sh been run?`;
  $("status").className = "status error";
}
