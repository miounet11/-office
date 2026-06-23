#!/usr/bin/env bash
# V2 W3 — apply-plan-runtime JSON parse gate (E2E envelope, no SwDoc).
# Runs CppunitTest_sw_apply_engine only (test35 writer-runtime 3-patch excerpt).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

export PKG_CONFIG="${PKG_CONFIG:-/tmp/kqoffice-pkgconf-utf8}"
V2_SMOKE_PARALLELISM="${V2_SMOKE_PARALLELISM:-2}"
V2_SMOKE_RETRY_SERIAL="${V2_SMOKE_RETRY_SERIAL:-1}"

smoke_make() {
  local target="$1"
  local parallelism="$V2_SMOKE_PARALLELISM"
  local log="tmp/v2-smoke-${target}.make.log"

  mkdir -p tmp
  echo "--- make $target (PARALLELISM=$parallelism) ---"
  set +e
  make PARALLELISM="$parallelism" "$target" 2>&1 | tee "$log"
  local status="${PIPESTATUS[0]}"
  set -e

  if [[ "$status" -ne 0 && "$V2_SMOKE_RETRY_SERIAL" == "1" && "$parallelism" != "1" ]] \
      && grep -Eq 'Killed: 9|Error 137' "$log"; then
    echo "WARN: $target hit a resource kill; retrying with PARALLELISM=1"
    set +e
    make PARALLELISM=1 "$target" 2>&1 | tee -a "$log"
    status="${PIPESTATUS[0]}"
    set -e
  fi

  return "$status"
}

echo "=== V2 W3 runtime parse smoke (CppunitTest_sw_apply_engine) ==="
smoke_make CppunitTest_sw_apply_engine

log="workdir/CppunitTest/sw_apply_engine.test.log"
if [[ -f "$log" ]]; then
  tail -1 "$log"
else
  echo "WARN: missing $log"
  exit 1
fi

echo ""
echo "=== W3 runtime parse smoke complete ==="
