"""Compare Universal Credit in full (P4) with PolicyEngine UK, 2026-27.

Households built so that both sides see the same facts:

- single (aged 30, or 24 for the under-25 rate) or couple (both 30), 0 to 4
  children aged 5, or the eldest aged 10 (born before 6 April 2017: the higher
  first child element);
- the LCWRA element (new-claim or protected rate) and the carer element;
- childcare costs (PolicyEngine's `childcare_expenses` on the children);
- a private renter with the local housing allowance given to PolicyEngine as
  `uc_LHA_cap`, or a social renter with no spare bedroom (PolicyEngine has no
  under-occupancy deduction, findings #16, so social renters here have none);
- capital (PolicyEngine's `uc_reported_capital`);
- a couple where both work (the partner's earned income, pay less their income
  tax and NICs, worked out by the model and passed to it);
- the benefit cap, inside and outside London, with PolicyEngine's own Child
  Benefit passed to the model as `child_benefit_pence`.

The Marriage Allowance is switched off for couples (PolicyEngine claims it by
default; the model's UC partner is described by earned income only). UC must
agree within --steps float32 steps of the larger of the yearly maximum amount and
pay, plus 0.4p for PolicyEngine's monthly NIC thresholds on two earners, plus
0.55p because the partner's earned income is passed to the model in whole pence
(up to 1p less, 55 % of it in UC).

    uv run python compare_uc_full.py [--binary ../.lake/build/bin/uktax] [--random 1000]
"""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import random
import subprocess
import sys

import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
DEFAULT_BINARY = HERE.parent / ".lake/build/bin/uktax"
YEAR = 2026
MICRO = 1_000_000


def step(pence: float) -> float:
    return float(np.spacing(np.float32(max(pence / 100, 1.0)))) * 100


def random_case(rng: random.Random) -> dict:
    couple = rng.random() < 0.4
    kids = rng.choice([0, 0, 1, 2, 3, 4])
    tenure = rng.choice(["none", "private", "social"])
    rent = rng.choice([0, rng.randint(30_000, 180_000)]) if tenure != "none" else 0
    return {
        "couple": couple,
        "kids": kids,
        "old_eldest": kids > 0 and rng.random() < 0.3,
        "under25": rng.random() < 0.15,
        "health": rng.choice(["none", "none", "none", "new", "protected"]),
        "carer": rng.random() < 0.15,
        "childcare": rng.choice([0, 0, rng.randint(10_000, 250_000)]) if kids else 0,
        "tenure": tenure if rent else "none",
        "rent": rent,
        "lha": rng.randint(40_000, 150_000) if tenure == "private" else None,
        "capital": rng.choice([0, 0, rng.randint(0, 1_700_000)]),
        "pay": rng.choice([0, rng.randint(0, 4_000_000), rng.randint(0, 1_500_000)]),
        "partner_pay": rng.choice([0, rng.randint(0, 3_000_000)]) if couple else 0,
        "london": rng.random() < 0.3,
    }


def edge_cases() -> list[dict]:
    base = {"couple": False, "kids": 0, "old_eldest": False, "under25": False, "health": "none", "carer": False,
            "childcare": 0, "tenure": "none", "rent": 0, "lha": None, "capital": 0, "pay": 0, "partner_pay": 0,
            "london": False}
    out = []
    for cap in (600_000, 600_001, 625_000, 625_001, 1_600_000, 1_600_001):
        out.append({**base, "capital": cap})
    # the benefit cap: a large family with high rent, around the earnings exception
    # (16 x £12.71 x 52 / 12 = £881.21, £881 after reg 6(1A); the model treats
    # earned income as pay less tax and NICs, here pay)
    for pay in (0, 1_057_199, 1_057_200, 1_057_201, 1_500_000):
        for london in (False, True):
            out.append({**base, "kids": 4, "tenure": "private", "rent": 160_000, "lha": 160_000, "pay": pay,
                        "london": london})
            out.append({**base, "kids": 4, "tenure": "private", "rent": 160_000, "lha": 160_000, "pay": pay,
                        "london": london, "childcare": 120_000})
    for h in ("new", "protected"):
        out.append({**base, "health": h, "kids": 1, "pay": 1_200_000})
    out.append({**base, "couple": True, "kids": 2, "old_eldest": True, "carer": True, "pay": 2_000_000,
                "partner_pay": 900_000, "tenure": "social", "rent": 70_000})
    return out


def partner_earned(binary: pathlib.Path, cs: list[dict]) -> list[int]:
    """The partner's earned income for UC (pay less income tax and NICs), whole pence."""
    payload = [{"non_savings_pence": c["partner_pay"], "savings_pence": 0, "dividends_pence": 0,
                "employment_pence": c["partner_pay"]} for c in cs]
    out = json.loads(subprocess.run([str(binary)], input=json.dumps(payload), capture_output=True, text=True,
                                    check=True).stdout)
    return [c["partner_pay"] - (r["tax_exact_ten_thousandths_pence"] + r["nic_exact_ten_thousandths_pence"]) // 10_000
            for c, r in zip(cs, out)]


def lean(binary: pathlib.Path, cs: list[dict], cb: list[float], pe_partner: list[int]) -> list[dict]:
    payload = []
    for c, b, pp in zip(cs, cb, pe_partner):
        uc = {"couple": c["couple"], "children": c["kids"], "under_25": c["under25"],
              "first_child_pre_2017": c["old_eldest"], "health": c["health"],
              # the LCWRA and carer elements are both on the claimant: reg 29(4)
              "carers": int(c["carer"] and c["health"] == "none"), "london": c["london"],
              "capital_pence": c["capital"],
              "cannot_provide_childcare": c["health"] != "none" or c["carer"],
              "partner_earned_pence": pp}
        if c["childcare"]:
            uc |= {"childcare_monthly_pence": c["childcare"], "childcare_children": min(c["kids"], 2)}
        if c["tenure"] != "none":
            uc["rent_monthly_pence"] = c["rent"]
            if c["tenure"] == "private":
                uc["lha_monthly_pence"] = c["lha"]
        payload.append({"non_savings_pence": c["pay"], "savings_pence": 0, "dividends_pence": 0,
                        "employment_pence": c["pay"], "child_benefit_pence": round(b * 100), "uc": uc})
    return json.loads(subprocess.run([str(binary)], input=json.dumps(payload), capture_output=True, text=True,
                                     check=True).stdout)


def policyengine(cs: list[dict]) -> dict[str, list[float]]:
    from policyengine_uk import Simulation

    res: dict[str, list[float]] = {"universal_credit": [], "uc_maximum_amount": [], "child_benefit": []}
    for lo in range(0, len(cs), 400):
        part = cs[lo : lo + 400]
        people, bus, hhs = {}, {}, {}
        for i, c in enumerate(part):
            age = 24 if c["under25"] else 30
            a = {"age": {YEAR: age}, "employment_income": {YEAR: c["pay"] / 100},
                 "uc_limited_capability_for_WRA": {YEAR: c["health"] != "none"},
                 "is_carer_for_benefits": {YEAR: c["carer"]}}
            members = [f"a{i}"]
            people[f"a{i}"] = a
            if c["couple"]:
                a["marriage_allowance"] = {YEAR: 0}
                people[f"p{i}"] = {"age": {YEAR: age}, "employment_income": {YEAR: c["partner_pay"] / 100},
                                   "marriage_allowance": {YEAR: 0}}
                members.append(f"p{i}")
            for k in range(c["kids"]):
                kid = {"age": {YEAR: 10 if (k == 0 and c["old_eldest"]) else 5}}
                if c["childcare"] and k < 2:
                    kid["childcare_expenses"] = {YEAR: c["childcare"] * 12 / 100 / min(c["kids"], 2)}
                people[f"c{i}_{k}"] = kid
                members.append(f"c{i}_{k}")
            bu = {"members": members, "uc_reported_capital": {YEAR: c["capital"] / 100},
                  "uc_receives_new_claimant_health_element": {YEAR: c["health"] == "new"}}
            if c["tenure"] == "private":
                bu["uc_LHA_cap"] = {YEAR: c["lha"] * 12 / 100}
            bus[f"b{i}"] = bu
            hh = {"members": members, "region": {YEAR: "LONDON" if c["london"] else "NORTH_WEST"}}
            if c["tenure"] != "none":
                hh |= {"rent": {YEAR: c["rent"] * 12 / 100},
                       "tenure_type": {YEAR: "RENT_PRIVATELY" if c["tenure"] == "private" else "RENT_FROM_COUNCIL"}}
            hhs[f"h{i}"] = hh
        sim = Simulation(situation={"people": people, "benunits": bus, "households": hhs})
        for v in res:
            res[v] += [float(x) for x in sim.calculate(v, YEAR)]
    return res


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", type=pathlib.Path, default=DEFAULT_BINARY)
    ap.add_argument("--random", type=int, default=600)
    ap.add_argument("--seed", type=int, default=2013)
    ap.add_argument("--steps", type=float, default=2.0)
    ap.add_argument("--out", type=pathlib.Path, default=HERE / "out/compare_uc_full.csv")
    args = ap.parse_args()
    rng = random.Random(args.seed)
    cs = edge_cases() + [random_case(rng) for _ in range(args.random)]
    pe = policyengine(cs)
    ln = lean(args.binary, cs, pe["child_benefit"], partner_earned(args.binary, cs))
    rows, bad, worst, paid = [], 0, 0.0, 0
    for c, r, u, m in zip(cs, ln, pe["universal_credit"], pe["uc_maximum_amount"]):
        mine = r["uc_millionths_pence"] / MICRO
        theirs = u * 100
        st = step(max(m * 100, c["pay"] + c["partner_pay"]))
        ok = abs(theirs - mine) <= args.steps * st + 0.4 + 0.55
        worst = max(worst, abs(theirs - mine) / st)
        paid += mine > 0
        bad += not ok
        rows.append({**c, "lean_uc_pence": mine, "pe_uc_pence": round(theirs, 4), "diff": round(theirs - mine, 4),
                     "ok": ok})
        if not ok and bad <= 12:
            print(f"  {c}: lean {mine:.2f} pe {theirs:.2f}")
    print(f"Universal Credit in full: {len(cs) - bad}/{len(cs)} agree ({paid} with UC paid; "
          f"worst {worst:.2f} float32 steps)")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
