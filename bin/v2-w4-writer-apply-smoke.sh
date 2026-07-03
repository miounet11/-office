#!/usr/bin/env bash
# V2 W4 — Writer apply engine + inline-actions smoke (Day-5).
# Runs cppunit sw_apply_engine + sw_inline_actions; prints manual Ollama checklist.
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

echo "=== V2 W4 Writer apply smoke (cppunit) ==="

for t in CppunitTest_sw_apply_engine CppunitTest_sw_inline_actions; do
  smoke_make "$t"
  log="workdir/CppunitTest/${t#CppunitTest_}.test.log"
  if [[ -f "$log" ]]; then
    tail -1 "$log"
  else
    echo "WARN: missing $log"
  fi
done

echo ""
echo "=== Manual UI checklist (Writer; requires app bundle) ==="
app=""
for candidate in \
  "$repo_root/instdir/可圈办公.app" \
  "$repo_root/test-install/可圈办公.app"; do
  if [[ -x "$candidate/Contents/MacOS/soffice" ]]; then
    app="$candidate"
    break
  fi
done

if [[ -z "$app" ]]; then
  echo "SKIP: no 可圈办公.app — run: make test-install"
else
  echo "App: $app"
  echo "  1. Writer: select paragraph text → popover appears"
  echo "  2. Writer: Rewrite → provider ok → paragraph text replaced (or DiffReview on error)"
  echo "  3. With Ollama running: SAL_INFO sw.inline_actions shows dispatch + apply"
  if [[ "${KQOFFICE_AI_DISABLE_PROBE:-}" == "1" ]]; then
    echo "  Note: KQOFFICE_AI_DISABLE_PROBE=1 — provider may return stub content; apply still runs on ok"
  fi
  echo "Launch: \"$app/Contents/MacOS/soffice\" --writer"
fi

echo ""
echo "=== W4 Writer apply smoke complete ==="
