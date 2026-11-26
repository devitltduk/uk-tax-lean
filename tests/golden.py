"""Run the golden cases in tests/golden.json through the uktax binary.

Expected values are worked by hand from GOV.UK examples and the legislation (the
working is recorded next to each case), not produced by the model.

Usage: python3 tests/golden.py [path/to/uktax]
"""

import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
binary = sys.argv[1] if len(sys.argv) > 1 else str(ROOT / ".lake/build/bin/uktax")
cases = json.loads((ROOT / "tests/golden.json").read_text())

proc = subprocess.run(
    [binary],
    input=json.dumps([c["input"] for c in cases]),
    capture_output=True,
    text=True,
    check=True,
)
results = json.loads(proc.stdout)
assert len(results) == len(cases), f"expected {len(cases)} results, got {len(results)}"

# Each case states the outputs it was worked for; every one it states is checked.
CHECKED = (
    "liability_pence",
    "nic_exact_ten_thousandths_pence",
    "hicbc_pence",
    "uc_millionths_pence",
    "tfc_millionths_pence",
    "funded_hours_millionths_pence",
    "childcare_eligible",
    "net_income_millionths_pence",
)

failures = 0
for case, got in zip(cases, results):
    keys = [k for k in CHECKED if k in case]
    assert keys, f"{case['name']}: no expected output"
    bad = [k for k in keys if got[k] != case[k]]
    failures += bool(bad)
    mark = "FAIL" if bad else "ok  "
    detail = ", ".join(f"{k} expected {case[k]}, got {got[k]}" for k in keys)
    print(f"{mark} {case['name']}: {detail}")

print(f"{len(cases) - failures}/{len(cases)} golden cases passed")
sys.exit(1 if failures else 0)
