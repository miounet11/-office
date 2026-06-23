#!/usr/bin/env bash
# V2 W4 — Provider stub runtime JSON + Writer apply doc E2E (cppunit only).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

export PKG_CONFIG="${PKG_CONFIG:-/tmp/kqoffice-pkgconf-utf8}"
V2_SMOKE_PARALLELISM="${V2_SMOKE_PARALLELISM:-2}"
V2_SMOKE_RETRY_SERIAL="${V2_SMOKE_RETRY_SERIAL:-1}"

smoke_make() {
  local target="$1"
  shift
  local parallelism="$V2_SMOKE_PARALLELISM"
  local log="tmp/v2-smoke-${target}.make.log"

  mkdir -p tmp
  echo "--- make $target (PARALLELISM=$parallelism) $* ---"
  set +e
  make PARALLELISM="$parallelism" "$target" "$@" 2>&1 | tee "$log"
  local status="${PIPESTATUS[0]}"
  set -e

  if [[ "$status" -ne 0 && "$V2_SMOKE_RETRY_SERIAL" == "1" && "$parallelism" != "1" ]] \
      && grep -Eq 'Killed: 9|Error 137' "$log"; then
    echo "WARN: $target hit a resource kill; retrying with PARALLELISM=1"
    set +e
    make PARALLELISM=1 "$target" "$@" 2>&1 | tee -a "$log"
    status="${PIPESTATUS[0]}"
    set -e
  fi

  return "$status"
}
echo "=== V2 W4 Provider runtime JSON smoke ==="

echo "--- make CppunitTest_kqoffice_provider (default contract) ---"
smoke_make CppunitTest_kqoffice_provider
tail -1 workdir/CppunitTest/kqoffice_provider.test.log

echo "--- stub-runtime envelope (both env vars) ---"
export KQOFFICE_AI_STUB_RUNTIME=1
export KQOFFICE_AI_DISABLE_PROBE=1
smoke_make CppunitTest_kqoffice_provider CPPUNIT_TEST_NAME=testStubRuntimeReturnsOkJsonEnvelope
tail -3 workdir/CppunitTest/kqoffice_provider.test.log
unset KQOFFICE_AI_STUB_RUNTIME KQOFFICE_AI_DISABLE_PROBE

echo "--- make CppunitTest_sw_uwriter (doc apply E2E) ---"
smoke_make CppunitTest_sw_uwriter
grep -E 'ApplyEngineDocTest|OK \(' workdir/CppunitTest/sw_uwriter.test.log | tail -4

echo ""
echo "=== Manual Writer checklist (KQOFFICE_AI_STUB_RUNTIME=1) ==="
echo "  export KQOFFICE_AI_STUB_RUNTIME=1"
echo "  Launch Writer → select paragraph → Rewrite"
echo "  Expect: paragraph text becomes prompt/stub (runtime JSON path, not plain-text fallback)"
echo ""
echo "=== W4 Provider runtime JSON smoke complete ==="
