#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src_root="${KDOFFICE_SRC_ROOT:-/Volumes/MobileDrive/devpc/kdoffice-src}"

checks=0
pass() { checks=$((checks + 1)); }
fail() { echo "$1" >&2; exit 1; }

test -f "$src_root/cui/UITest_cui_cowork.mk" || fail "missing UITest_cui_cowork.mk"
pass

grep -q 'UITest_cui_cowork' "$src_root/cui/Module_cui.mk" || fail "Module_cui.mk missing UITest_cui_cowork"
pass

test -f "$src_root/cui/qa/uitest/cowork/test_cowork_dialog.py" || fail "missing test_cowork_dialog.py"
pass

grep -q 'test_a_cowork_dialog_controls_smoke' "$src_root/cui/qa/uitest/cowork/test_cowork_dialog.py" || fail "missing controls smoke"
pass

grep -q 'test_c_cowork_accept_task_enabled_after_review' "$src_root/cui/qa/uitest/cowork/test_cowork_dialog.py" || fail "missing accept smoke"
pass

test -x "$repo_root/bin/refresh-test-install-from-instdir.sh" || fail "missing refresh-test-install-from-instdir.sh"
pass

echo "Checks: $checks"