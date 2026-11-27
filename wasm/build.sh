#!/usr/bin/env bash
# Build the uktax model as WebAssembly: web/dist/uktax.mjs and web/dist/uktax.wasm.
#
# Route: Lean -> C -> Emscripten.
#   1. `lake build uktax` compiles the model natively and leaves its C in .lake/build/ir.
#   2. The Lean core modules Main imports (Init, Lean.Data.Json and what they
#      import) are compiled to C with the toolchain's own `lean -c`, from the
#      sources the toolchain ships. Toolchains ship no C for them.
#   3. The Lean runtime (C++) is built for wasm32 from the Lean source at the
#      toolchain's version, single-threaded, with wasm/lean-runtime-emscripten.patch.
#   4. Everything is compiled with emcc and linked with wasm/shim.c, which exports
#      uktax_run (JSON in, JSON out, as the CLI).
#
# Needs: elan (or lean/lake on PATH), git, cmake, make, python3. Emscripten is
# used from PATH if `emcc` is there, otherwise installed into .wasm-build/emsdk.
# Everything it downloads or builds stays in .wasm-build/ (git-ignored); a second
# run reuses it. Set JOBS to limit parallel compiles (default: nproc).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
B=${WASM_BUILD_DIR:-$ROOT/.wasm-build}
OUT=$ROOT/web/dist
JOBS=${JOBS:-$(nproc)}
EMSDK_VERSION=${EMSDK_VERSION:-7.0.1}
OPT=${WASM_OPT:--O2}
mkdir -p "$B" "$OUT"
cd "$ROOT"

step() { printf '\n== %s\n' "$*"; }

# --- Lean toolchain and native build -------------------------------------
step "lake build uktax"
lake build uktax
TC=$(lean --print-prefix)
LEAN_VERSION=$(lean --version | sed -E 's/^Lean \(version ([^,]+),.*/\1/')
echo "Lean $LEAN_VERSION at $TC"

# --- Emscripten -------------------------------------------------------------
if ! command -v emcc >/dev/null; then
  if [ ! -x "$B/emsdk/emsdk" ]; then
    step "install emsdk $EMSDK_VERSION into $B/emsdk"
    git clone --depth 1 https://github.com/emscripten-core/emsdk.git "$B/emsdk"
  fi
  if [ ! -f "$B/emsdk/.installed-$EMSDK_VERSION" ]; then
    "$B/emsdk/emsdk" install "$EMSDK_VERSION"
    "$B/emsdk/emsdk" activate "$EMSDK_VERSION"
    touch "$B/emsdk/.installed-$EMSDK_VERSION"
  fi
  # shellcheck disable=SC1091
  EMSDK_QUIET=1 source "$B/emsdk/emsdk_env.sh"
fi
echo "emcc: $(emcc --version | head -1)"

# --- Lean runtime for wasm32 -------------------------------------------------
RT=$B/runtime-$LEAN_VERSION
if [ ! -f "$RT/lib/lean/libleanrt.a" ]; then
  step "build the Lean runtime $LEAN_VERSION for wasm32"
  rm -rf "$B/lean4-$LEAN_VERSION" "$RT"
  git clone -q --depth 1 --branch "v$LEAN_VERSION" https://github.com/leanprover/lean4 "$B/lean4-$LEAN_VERSION"
  git -C "$B/lean4-$LEAN_VERSION" apply "$ROOT/wasm/lean-runtime-emscripten.patch"
  emcmake cmake -S "$B/lean4-$LEAN_VERSION/src" -B "$RT" \
    -DCMAKE_BUILD_TYPE=Release -DSTAGE=1 -DMULTI_THREAD=OFF -DUSE_GMP=OFF -DMMAP=OFF \
    -DUSE_MIMALLOC=OFF -DCCACHE=OFF -DUSE_GITHASH=OFF -DINSTALL_CADICAL=OFF -DINSTALL_LEANTAR=OFF \
    -DLEAN_EXTRA_CXX_FLAGS="-include mutex" > "$B/runtime-configure.log" 2>&1 \
    || { cat "$B/runtime-configure.log"; exit 1; }
  make -C "$RT" -j"$JOBS" leanrt > "$B/runtime-build.log" 2>&1 \
    || { tail -50 "$B/runtime-build.log"; exit 1; }
fi
INC=$RT/include  # lean.h configured for this runtime (no mimalloc)

# --- C for the Lean core modules ---------------------------------------------
STD=$B/stdlib-$LEAN_VERSION
if [ ! -f "$STD/.done" ]; then
  step "compile the Lean core modules Main imports to C"
  rm -rf "$STD" && mkdir -p "$STD/c"
  python3 wasm/stdlib_modules.py "$TC" > "$STD/modules.txt"
  echo "$(wc -l < "$STD/modules.txt") modules"
  export TC STD
  LEAN_PATH=$TC/lib/lean xargs -P "$JOBS" -I{} sh -c '
    f=$(echo "$1" | tr . /)
    mkdir -p "$STD/c/$(dirname "$f")"
    lean -R "$TC/src/lean" -c "$STD/c/$f.c" "$TC/src/lean/$f.lean" >/dev/null 2>"$STD/c/$f.err" \
      || { echo "lean -c failed for $1:"; cat "$STD/c/$f.err"; exit 255; }
  ' _ {} < "$STD/modules.txt"
  touch "$STD/.done"
fi

# --- Compile to wasm objects ------------------------------------------------------
step "compile C to wasm objects ($OPT)"
OBJ=$B/obj$OPT
mkdir -p "$OBJ/std" "$OBJ/model"
CFLAGS="$OPT -fwasm-exceptions -w -I$INC"
export OBJ CFLAGS
# Lean core: compiled once per toolchain and optimisation level.
(cd "$STD/c" && find . -name '*.c') | xargs -P "$JOBS" -I{} sh -c '
  o="$OBJ/std/$(echo "$1" | sed "s|^\./||; s|/|_|g").o"
  [ -f "$o" ] || emcc $CFLAGS -c "'"$STD"'/c/$1" -o "$o"
' _ {}
# The model: always recompiled. Main.c's `main` is renamed so it is not the entry point.
rm -f "$OBJ"/model/*.o
(cd .lake/build/ir && find . -name '*.c') | xargs -P "$JOBS" -I{} sh -c '
  o="$OBJ/model/$(echo "$1" | sed "s|^\./||; s|/|_|g").o"
  extra=""; [ "$1" = "./Main.c" ] && extra="-Dmain=uktax_cli_main"
  emcc $CFLAGS $extra -c ".lake/build/ir/$1" -o "$o"
' _ {}
emcc $CFLAGS -c wasm/shim.c -o "$OBJ/model/shim.o"

# --- Link ---------------------------------------------------------------------------
step "link web/dist/uktax.mjs and uktax.wasm"
rm -f "$OUT/uktax.mjs" "$OUT/uktax.wasm"
# The runtime's Emscripten stubs for temp files disagree in signature with
# Init's declarations; neither is reachable from uktax_run.
em++ $OPT -fwasm-exceptions "$OBJ"/std/*.o "$OBJ"/model/*.o \
  "$RT/lib/lean/libleanrt.a" "$RT/libuv/src/libuv/libuv.a" \
  -sMODULARIZE=1 -sEXPORT_ES6=1 -sEXPORT_NAME=createUkTax -sENVIRONMENT=web,node \
  -sALLOW_MEMORY_GROWTH=1 -sSTACK_SIZE=8388608 \
  -sEXPORTED_FUNCTIONS=_uktax_init,_uktax_run -sEXPORTED_RUNTIME_METHODS=cwrap \
  -o "$OUT/uktax.mjs" 2>&1 | grep -v 'signature mismatch\|defined as\|^$' || true
test -f "$OUT/uktax.wasm"

raw=$(wc -c < "$OUT/uktax.wasm")
gz=$(gzip -9 -c "$OUT/uktax.wasm" | wc -c)
js=$(wc -c < "$OUT/uktax.mjs")
jsgz=$(gzip -9 -c "$OUT/uktax.mjs" | wc -c)
echo "uktax.wasm: $raw bytes ($gz gzipped); uktax.mjs: $js bytes ($jsgz gzipped)"
