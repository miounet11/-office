#!/usr/bin/env bash
# V2 W4 — select-to-act + inline-action + diff-review smoke gate.
# Runs protocol/cppunit checks; static instdir bundle checks when a .app exists;
# optional manual UI checklist (no automatic headless launch).
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

echo "=== V2 W4 smoke (protocol + cppunit) ==="

bash bin/v2-harness-sweep.sh

if [[ -x bin/v2-w4-writer-apply-smoke.sh ]]; then
  bash bin/v2-w4-writer-apply-smoke.sh
fi

for t in CppunitTest_sw_inline_actions CppunitTest_sc_inline_actions CppunitTest_sd_inline_actions; do
  smoke_make "$t"
  log="workdir/CppunitTest/${t#CppunitTest_}.test.log"
  if [[ -f "$log" ]]; then
    tail -1 "$log"
  else
    echo "WARN: missing $log"
  fi
done

app=""
for candidate in \
  "$repo_root/instdir/可圈office.app" \
  "$repo_root/test-install/可圈office.app"; do
  if [[ -x "$candidate/Contents/MacOS/soffice" ]]; then
    app="$candidate"
    break
  fi
done

echo ""
echo "=== Installdir bundle checks (static; no SAL_INFO launch) ==="
installdir_args=()
if [[ -n "$app" ]]; then
  installdir_args=(--app "$app")
else
  echo "No bundle yet — installdir smoke may run make test-install"
fi
if ! bash bin/v2-w4-smoke-installdir.sh "${installdir_args[@]}"; then
  echo "WARN: installdir checks failed — fix bundle before manual W4 UI pass"
fi
if [[ -z "$app" ]]; then
  for candidate in \
    "$repo_root/instdir/可圈office.app" \
    "$repo_root/test-install/可圈office.app"; do
    if [[ -x "$candidate/Contents/MacOS/soffice" ]]; then
      app="$candidate"
      break
    fi
  done
fi

echo ""
echo "=== Manual UI checklist (requires app bundle) ==="
if [[ -z "$app" ]]; then
  echo "SKIP: no 可圈office.app — run: make test-install"
else
  echo "App: $app"
  echo "  1. Writer: select paragraph text → popover appears"
  echo "  2. Writer: Rewrite → SAL_INFO inline_action_request + DiffReview (if Ollama/evidence)"
  echo "  3. Calc: select cell range → popover; Explain data → provider dispatch"
  echo "  4. Impress: select text shape → popover; Rewrite text → provider dispatch"
  echo "  5. Cmd+Shift+K → command palette (W2)"
  echo "  6. After applyDiagnosticsPlan: DiffReview lists patches; Accept reverts one undo step"
  echo "Launch: \"$app/Contents/MacOS/soffice\" --writer"
fi

echo ""
echo "=== W4 smoke complete ==="
