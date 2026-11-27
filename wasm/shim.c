// JSON-in, JSON-out entry point for the WebAssembly build of uktax.
//
// It calls the same function the CLI does, `run : String → Except String Json`
// in Main.lean, and prints the result with `Json.compress` as the CLI does, so
// the output is byte for byte what `uktax` writes to stdout (less the newline).
// Main.lean is compiled unchanged; its `main` is renamed at compile time
// (-Dmain=uktax_cli_main) so it is not the module's entry point.

#include <lean/lean.h>
#include <emscripten/emscripten.h>
#include <stdlib.h>
#include <string.h>

lean_object *lp_uk_x2dtax_x2dlean_run(lean_object *);
lean_object *l_Lean_Json_compress(lean_object *);
lean_object *initialize_uk_x2dtax_x2dlean_Main(uint8_t builtin);
void lean_initialize_runtime_module(void);
void lean_io_mark_end_initialization(void);

// Main.c calls `lean_initialize()`, which in a native build initialises the
// whole Lean compiler (libleancpp) because Main imports `Lean.Data.Json`. The
// model needs only the runtime and the modules Main imports, which Main's own
// initialiser goes on to initialise, so the runtime alone is set up here.
void lean_initialize(void) { lean_initialize_runtime_module(); }

static int g_ready = 0;
static char *g_out = NULL;

static char *copy_lean_string(lean_object *s) {
  size_t n = lean_string_size(s) - 1;  // size includes the trailing NUL
  char *buf = malloc(n + 1);
  memcpy(buf, lean_string_cstr(s), n + 1);
  return buf;
}

// Returns 0 on success, or 1 if initialisation failed.
EMSCRIPTEN_KEEPALIVE int uktax_init(void) {
  if (g_ready) return 0;
  lean_set_panic_messages(false);
  lean_object *res = initialize_uk_x2dtax_x2dlean_Main(1 /* builtin */);
  lean_set_panic_messages(true);
  lean_io_mark_end_initialization();
  if (!lean_io_result_is_ok(res)) return 1;
  lean_dec_ref(res);
  g_ready = 1;
  return 0;
}

// Runs one input (a case object or an array of cases, as for the CLI).
// Returns the compressed JSON on success, or the error message prefixed with
// "error:" (the CLI prints "uktax: <message>" to stderr and exits 1). The
// returned string stays valid until the next call.
EMSCRIPTEN_KEEPALIVE const char *uktax_run(const char *input) {
  free(g_out);
  g_out = NULL;
  if (uktax_init() != 0) {
    g_out = strdup("error:initialisation failed");
    return g_out;
  }
  lean_object *r = lp_uk_x2dtax_x2dlean_run(lean_mk_string(input));
  // Except String Json: constructor 0 is `error`, 1 is `ok`.
  lean_object *v = lean_ctor_get(r, 0);
  lean_inc(v);
  if (lean_obj_tag(r) == 1) {
    lean_dec(r);
    lean_object *s = l_Lean_Json_compress(v);
    g_out = copy_lean_string(s);
    lean_dec(s);
  } else {
    lean_dec(r);
    char *msg = copy_lean_string(v);
    lean_dec(v);
    size_t n = strlen(msg);
    g_out = malloc(n + 7);
    memcpy(g_out, "error:", 6);
    memcpy(g_out + 6, msg, n + 1);
    free(msg);
  }
  return g_out;
}
