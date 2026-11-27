"""Print the Lean core modules the uktax CLI needs compiled into the wasm build.

Main.lean imports Lean.Data.Json, and every module imports Init. This follows
the `import` lines of the toolchain's own sources (shipped in
`<prefix>/src/lean`) from those two roots. Reading import lines with a regex can
only over-approximate (an import in a comment adds a module that is compiled and
then dropped by the linker); a module it missed would fail the link.

Usage: python3 wasm/stdlib_modules.py <lean --print-prefix>
"""

import pathlib
import re
import sys

src = pathlib.Path(sys.argv[1]) / "src" / "lean"
IMPORT = re.compile(r"^\s*(?:public\s+)?(?:meta\s+)?import\s+(?:all\s+)?([\w.]+)")

seen: set[str] = set()
todo = ["Init", "Lean.Data.Json"]
while todo:
    mod = todo.pop()
    if mod in seen:
        continue
    path = src / (mod.replace(".", "/") + ".lean")
    if not path.exists():
        continue
    seen.add(mod)
    for line in path.read_text().splitlines():
        m = IMPORT.match(line)
        if m:
            todo.append(m.group(1))

print("\n".join(sorted(seen)))
