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

failures = 0
for case, got in zip(cases, results):
    ok = got["liability_pence"] == case["liability_pence"]
    failures += not ok
    mark = "ok  " if ok else "FAIL"
    print(f"{mark} {case['name']}: expected {case['liability_pence']}, got {got['liability_pence']}")

print(f"{len(cases) - failures}/{len(cases)} golden cases passed")
sys.exit(1 if failures else 0)
