import UkTax.Rules.Prose

/-!
Print ITA 2007 s35 (and the s6 rates and s10 bands it feeds), the HICBC
(ITEPA 2003 s681C), the UC taper (UC Regulations 2013 reg 22) and employee
Class 1 NICs (SSCBA 1992 s8) from the rules in `UkTax/Rules/` as plain English,
and s35, s10 and s8 as statute text, with the 2026-27 figures, into
`docs/prose/` (or the directory given as the one argument):

    lake build && lake env lean --run Prose.lean

Run with `lean --run`, not as a `lean_exe`: an exe would leave a second C `main`
in `.lake/build/ir`, which `wasm/build.sh` links into the web build.
-/

open UkTax UkTax.Rules

def main (args : List String) : IO Unit := do
  let dir := args.headD "docs/prose"
  IO.FS.createDirAll dir
  IO.FS.writeFile s!"{dir}/s35.md" (plainDoc TaxParams.y2026 "2026-27")
  IO.FS.writeFile s!"{dir}/s35-statute.md" (statuteDoc TaxParams.y2026 "2026-27")
  IO.FS.writeFile s!"{dir}/hicbc.md" (hicbcDoc TaxParams.y2026 "2026-27")
  IO.FS.writeFile s!"{dir}/uc-taper.md" (ucTaperDoc TaxParams.y2026 "2026-27")
  IO.FS.writeFile s!"{dir}/class1.md" (class1Doc TaxParams.y2026 "2026-27")
  IO.FS.writeFile s!"{dir}/class1-statute.md" (class1StatuteDoc TaxParams.y2026 "2026-27")
