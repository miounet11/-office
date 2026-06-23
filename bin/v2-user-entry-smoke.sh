#!/usr/bin/env bash
# V2 user-entry smoke for installed 可圈office.app.
#
# This is a local product-surface smoke, not a visible GUI click-through. It
# verifies that the installed app bundle carries a coherent user-entry chain for
# the V2 AI surfaces: command registration, shortcuts, menus, sidebar deck, and
# shipped UI controls.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mkdir -p tmp

app="${KDOFFICE_APP_BUNDLE:-$repo_root/instdir/可圈office.app}"
src_root="${KDOFFICE_SRC_ROOT:-/Users/lu/kdoffice-src}"
report="${V2_USER_ENTRY_REPORT:-tmp/v2-user-entry-smoke.md}"

usage() {
    cat <<'EOF'
Usage:
  v2-user-entry-smoke.sh [--app <bundle>] [--src-root <path>] [--report <path>]

Checks:
  - Installed registry exposes .uno:CommandPalette and .uno:CoworkTaskManager.
  - Installed registry maps Cmd+Shift+K/T to those two commands.
  - Writer/Calc/Draw/Impress/Global menubars ship the Cowork menu entry.
  - DiffReviewDeck is registered in the installed sidebar registry.
  - Command Palette, Cowork, Writer/Calc/Impress Select-to-act, and DiffReview UI
    resources ship with their expected interactive controls.
  - SRCDIR still contains the matching SFX slot, app dispatcher, and source
    registry/menu anchors.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)
            app="${2:?}"
            shift 2
            ;;
        --src-root)
            src_root="${2:?}"
            shift 2
            ;;
        --report)
            report="${2:?}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ ! -x "$app/Contents/MacOS/soffice" ]]; then
    echo "FAIL: missing executable soffice in app bundle: $app" >&2
    exit 1
fi
if [[ ! -d "$src_root" ]]; then
    echo "FAIL: missing SRCDIR: $src_root" >&2
    exit 1
fi

resources_dir="$app/Contents/Resources"
registry_main="$resources_dir/registry/main.xcd"
config_dir="$resources_dir/config/soffice.cfg"
failures=0
passes=0
report_rows=()

record_result() {
    local status="$1"
    local area="$2"
    local detail="$3"
    report_rows+=("| $status | $area | $detail |")
    if [[ "$status" == "PASS" ]]; then
        passes=$((passes + 1))
        printf 'PASS: %s — %s\n' "$area" "$detail"
    else
        failures=$((failures + 1))
        printf 'FAIL: %s — %s\n' "$area" "$detail" >&2
    fi
}

require_file() {
    local area="$1"
    local path="$2"
    local label="$3"
    if [[ -f "$path" ]]; then
        record_result "PASS" "$area" "$label shipped (${path#$app/})"
    else
        record_result "FAIL" "$area" "$label missing (${path#$app/})"
    fi
}

require_contains() {
    local area="$1"
    local path="$2"
    local needle="$3"
    local label="$4"
    if [[ -f "$path" ]] && LC_ALL=C grep -aqF "$needle" "$path" 2>/dev/null; then
        record_result "PASS" "$area" "$label"
    else
        record_result "FAIL" "$area" "$label missing needle '$needle' in ${path#$repo_root/}"
    fi
}

require_registry_pair() {
    local area="$1"
    local key="$2"
    local command="$3"
    if [[ -f "$registry_main" ]] \
        && LC_ALL=C grep -aqF "$key" "$registry_main" \
        && LC_ALL=C grep -aqF "$command" "$registry_main"; then
        record_result "PASS" "$area" "$key maps to $command in installed registry"
    else
        record_result "FAIL" "$area" "$key / $command pair missing in installed registry"
    fi
}

echo "=== V2 user-entry smoke ==="
echo "App bundle: $app"
echo "SRCDIR: $src_root"

# Installed command + shortcut registry.
require_contains "installed registry" "$registry_main" ".uno:CommandPalette" \
    ".uno:CommandPalette registered"
require_contains "installed registry" "$registry_main" ".uno:CoworkTaskManager" \
    ".uno:CoworkTaskManager registered"
require_registry_pair "installed shortcuts" "K_SHIFT_MOD1" ".uno:CommandPalette"
require_registry_pair "installed shortcuts" "T_SHIFT_MOD1" ".uno:CoworkTaskManager"
require_contains "installed sidebar" "$registry_main" "DiffReviewDeck" \
    "DiffReviewDeck registered"

# Installed menu entry coverage for the user-facing document apps that currently
# ship the async cowork entry.
for module in swriter scalc sdraw simpress sglobal; do
    menubar="$config_dir/modules/$module/menubar/menubar.xml"
    require_contains "installed menu:$module" "$menubar" ".uno:CoworkTaskManager" \
        "$module menubar exposes .uno:CoworkTaskManager"
done

# Installed UI resources + expected interactive controls.
command_palette_ui="$config_dir/cui/ui/commandpalette.ui"
cowork_ui="$config_dir/cui/ui/cowork-dialog.ui"
writer_popover_ui="$config_dir/modules/swriter/ui/select-to-act-popover.ui"
calc_popover_ui="$config_dir/modules/scalc/ui/cell-range-popover.ui"
impress_popover_ui="$config_dir/modules/simpress/ui/slide-element-popover.ui"
diff_review_ui="$config_dir/svx/ui/diff-review-panel.ui"

require_file "installed ui" "$command_palette_ui" "Command Palette UI"
require_contains "command palette ui" "$command_palette_ui" 'id="search_input"' \
    "search entry present"
require_contains "command palette ui" "$command_palette_ui" 'id="results_view"' \
    "results view present"

require_file "installed ui" "$cowork_ui" "Cowork dialog UI"
require_contains "cowork ui" "$cowork_ui" 'id="btn_new_task"' \
    "new task button present"
require_contains "cowork ui" "$cowork_ui" 'id="task_list_view"' \
    "task list view present"

require_file "installed ui" "$writer_popover_ui" "Writer Select-to-act UI"
for id in btn_rewrite btn_expand btn_shorten btn_translate_en btn_format_clean btn_explain btn_custom; do
    require_contains "writer select-to-act ui" "$writer_popover_ui" "id=\"$id\"" \
        "$id present"
done

require_file "installed ui" "$calc_popover_ui" "Calc Select-to-act UI"
for id in btn_explain_data btn_suggest_chart btn_generate_formula btn_format_clean btn_format_change; do
    require_contains "calc select-to-act ui" "$calc_popover_ui" "id=\"$id\"" \
        "$id present"
done

require_file "installed ui" "$impress_popover_ui" "Impress Select-to-act UI"
for id in btn_rewrite_text btn_adjust_color btn_relayout btn_translate_text; do
    require_contains "impress select-to-act ui" "$impress_popover_ui" "id=\"$id\"" \
        "$id present"
done

require_file "installed ui" "$diff_review_ui" "DiffReview panel UI"
require_contains "diff review ui" "$diff_review_ui" 'id="DiffReviewPanel"' \
    "DiffReviewPanel root present"
require_contains "diff review ui" "$diff_review_ui" 'id="btn_accept"' \
    "accept button present"
require_contains "diff review ui" "$diff_review_ui" 'id="btn_reject"' \
    "reject button present"

# Source-side anchors that feed the installed resources above.
require_contains "source sfx slots" "$src_root/sfx2/sdi/sfx.sdi" \
    "SfxVoidItem CommandPalette SID_COMMAND_PALETTE" \
    "CommandPalette UNO slot defined"
require_contains "source sfx slots" "$src_root/sfx2/sdi/sfx.sdi" \
    "SfxVoidItem CoworkTaskManager SID_COWORK_TASK_MANAGER" \
    "CoworkTaskManager UNO slot defined"
require_contains "source dispatcher" "$src_root/sfx2/source/appl/appserv.cxx" \
    "case SID_COMMAND_PALETTE:" \
    "CommandPalette dispatcher branch present"
require_contains "source dispatcher" "$src_root/sfx2/source/appl/appserv.cxx" \
    "case SID_COWORK_TASK_MANAGER:" \
    "CoworkTaskManager dispatcher branch present"
require_contains "source generic commands" \
    "$src_root/officecfg/registry/data/org/openoffice/Office/UI/GenericCommands.xcu" \
    ".uno:CommandPalette" "CommandPalette source command registered"
require_contains "source generic commands" \
    "$src_root/officecfg/registry/data/org/openoffice/Office/UI/GenericCommands.xcu" \
    ".uno:CoworkTaskManager" "CoworkTaskManager source command registered"
require_contains "source accelerators" \
    "$src_root/officecfg/registry/data/org/openoffice/Office/Accelerators.xcu" \
    "K_SHIFT_MOD1" "CommandPalette source shortcut anchor present"
require_contains "source accelerators" \
    "$src_root/officecfg/registry/data/org/openoffice/Office/Accelerators.xcu" \
    "T_SHIFT_MOD1" "CoworkTaskManager source shortcut anchor present"

{
    echo "# V2 User Entry Smoke"
    echo
    if [[ "$failures" -eq 0 ]]; then
        echo "- Status: passed"
    else
        echo "- Status: failed"
    fi
    echo "- App bundle: $app"
    echo "- SRCDIR: $src_root"
    echo "- Checks passed: $passes"
    echo "- Checks failed: $failures"
    echo "- Scope: installed command/shortcut/menu/sidebar/UI entry chain plus source anchors"
    echo
    echo "| Status | Area | Detail |"
    echo "|---|---|---|"
    printf '%s\n' "${report_rows[@]}"
} >"$report"

if [[ "$failures" -eq 0 ]]; then
    echo "Status: passed"
    echo "Checks: $passes"
    echo "Report: $report"
    exit 0
fi

echo "Status: failed"
echo "Checks passed: $passes"
echo "Checks failed: $failures"
echo "Report: $report"
exit 1
