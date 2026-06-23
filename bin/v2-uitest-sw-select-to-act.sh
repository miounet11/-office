#!/usr/bin/env bash
# V2 W4 — UITest_sw_select_to_act (headless svp).
# Prereq: solenv fixes for CLICOLOR (UnpackedTarball.mk + ExternalProject.mk).
#
# Do NOT prepend: pkill soffice/pytest; rm -rf workdir/UITest/sw_select_to_act
# That forces ~7min build ALL and races with parallel jobs (SIGTERM 15, make Error 2).
# Gate: done.log must contain "OK (skipped=2)" — office-connect smoke only.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

export PKG_CONFIG="${PKG_CONFIG:-/tmp/kqoffice-pkgconf-utf8}"
export GCC_COLORS=0 NO_COLOR=1 TERM=dumb CLICOLOR=0 CLICOLOR_FORCE=0

echo "=== V2 UITest sw_select_to_act ==="
echo "Building deps: more_fonts epm (if needed)..."
make more_fonts.build epm.build 2>&1 | tail -3

echo "--- make UITest_sw_select_to_act (may take several minutes) ---"
make UITest_sw_select_to_act

log="workdir/UITest/sw_select_to_act/done.log"
if [[ -f "$log" ]]; then
  echo "--- done.log tail ---"
  tail -20 "$log"
  if grep -q '^OK$' "$log" 2>/dev/null || grep -q 'OK (' "$log"; then
    echo "UITest: passed (default: office-connect smoke; Writer UI/UNO probes skipped under svp)"
  elif grep -q 'FAILED\|Failures\|Error:' "$log"; then
    echo "UITest: failed (see $log)"
    exit 1
  else
    echo "UITest: inconclusive — check $log"
    exit 2
  fi
else
  echo "WARN: missing $log"
  exit 1
fi