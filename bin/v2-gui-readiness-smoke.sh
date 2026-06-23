#!/usr/bin/env bash
# V2 GUI readiness smoke for installed 可圈office.app.
#
# Captures host-side prerequisites for a real visible GUI click-through and
# compares the visible /Applications bundle against the builddir app-bundle V2
# entry resources. This does not claim Cmd+Shift+K/select-to-act/DiffReview/
# Cowork clicks are done; it turns the current GUI automation blocker into
# repeatable evidence.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mkdir -p tmp

app="${KDOFFICE_APP_BUNDLE:-$repo_root/instdir/可圈office.app}"
installed_app="${KDOFFICE_INSTALLED_APP_BUNDLE:-/Applications/可圈office.app}"
report="${V2_GUI_READINESS_REPORT:-tmp/v2-gui-readiness-smoke.md}"
log="${V2_GUI_READINESS_LOG:-tmp/v2-gui-readiness-smoke.log}"
expected_bundle_id="${V2_GUI_READINESS_BUNDLE_ID:-com.kdoffice.app}"
expected_bundle_name="${V2_GUI_READINESS_BUNDLE_NAME:-可圈office}"
passes=0
failures=0
readiness="ready"
rows=()

usage() {
    cat <<'EOF'
Usage:
  v2-gui-readiness-smoke.sh [--app <bundle>] [--installed-app <bundle>] [--report <path>] [--log <path>]

Checks:
  - Builddir and installed app bundle identity.
  - osascript can execute and activate com.kdoffice.app.
  - System Events can discover the running soffice process.
  - Accessibility permission for menu/window inspection is classified.
  - LaunchServices visible-instance route is recorded.
  - Visible bundle V2 entry-resource parity is classified.

This is a readiness/preflight gate, not a completed visible GUI click-through.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)
            app="${2:?}"
            shift 2
            ;;
        --installed-app)
            installed_app="${2:?}"
            shift 2
            ;;
        --report)
            report="${2:?}"
            shift 2
            ;;
        --log)
            log="${2:?}"
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

md_escape() {
    printf '%s' "$1" | tr '\n' ';' | sed 's/|/\\|/g'
}

record() {
    local status="$1"
    local area="$2"
    local detail="$3"
    rows+=("| $status | $area | $(md_escape "$detail") |")
    case "$status" in
        PASS)
            passes=$((passes + 1))
            printf 'PASS: %s -- %s\n' "$area" "$detail"
            ;;
        FAIL)
            failures=$((failures + 1))
            readiness="failed"
            printf 'FAIL: %s -- %s\n' "$area" "$detail" >&2
            ;;
        BLOCKED)
            readiness="blocked"
            printf 'BLOCKED: %s -- %s\n' "$area" "$detail"
            ;;
        *)
            printf '%s: %s -- %s\n' "$status" "$area" "$detail"
            ;;
    esac
}

record_blocked() {
    local area="$1"
    local detail="$2"
    readiness="blocked"
    rows+=("| BLOCKED | $area | $(md_escape "$detail") |")
    printf 'BLOCKED: %s -- %s\n' "$area" "$detail"
}

plist_value() {
    local plist="$1"
    local key="$2"
    /usr/bin/plutil -extract "$key" raw "$plist" 2>/dev/null || true
}

contains_binary() {
    local file="$1"
    local needle="$2"
    [[ -f "$file" ]] && LC_ALL=C grep -aqF "$needle" "$file" 2>/dev/null
}

check_bundle() {
    local label="$1"
    local bundle="$2"
    local plist="$bundle/Contents/Info.plist"
    local soffice="$bundle/Contents/MacOS/soffice"
    if [[ -d "$bundle" ]]; then
        record PASS "$label bundle" "$bundle exists"
    else
        record FAIL "$label bundle" "$bundle missing"
        return
    fi
    [[ -f "$plist" ]] && record PASS "$label plist" "$plist exists" || record FAIL "$label plist" "$plist missing"
    [[ -x "$soffice" ]] && record PASS "$label soffice" "$soffice executable" || record FAIL "$label soffice" "$soffice missing or not executable"

    local bundle_id bundle_name executable
    bundle_id="$(plist_value "$plist" CFBundleIdentifier)"
    bundle_name="$(plist_value "$plist" CFBundleName)"
    executable="$(plist_value "$plist" CFBundleExecutable)"
    [[ "$bundle_id" == "$expected_bundle_id" ]] && record PASS "$label bundle id" "$bundle_id" || record FAIL "$label bundle id" "expected $expected_bundle_id, got ${bundle_id:-<empty>}"
    [[ "$bundle_name" == "$expected_bundle_name" ]] && record PASS "$label bundle name" "$bundle_name" || record FAIL "$label bundle name" "expected $expected_bundle_name, got ${bundle_name:-<empty>}"
    [[ "$executable" == "soffice" ]] && record PASS "$label executable" "$executable" || record FAIL "$label executable" "expected soffice, got ${executable:-<empty>}"
}

check_v2_entry_parity() {
    local label="$1"
    local bundle="$2"
    local registry="$bundle/Contents/Resources/registry/main.xcd"
    local config="$bundle/Contents/Resources/config/soffice.cfg"
    local missing=()

    contains_binary "$registry" ".uno:CommandPalette" || missing+=(".uno:CommandPalette registry")
    contains_binary "$registry" ".uno:CoworkTaskManager" || missing+=(".uno:CoworkTaskManager registry")
    contains_binary "$registry" "K_SHIFT_MOD1" || missing+=("Cmd+Shift+K registry")
    contains_binary "$registry" "T_SHIFT_MOD1" || missing+=("Cmd+Shift+T registry")
    contains_binary "$registry" "DiffReviewDeck" || missing+=("DiffReviewDeck registry")
    [[ -f "$config/cui/ui/commandpalette.ui" ]] || missing+=("commandpalette.ui")
    [[ -f "$config/cui/ui/cowork-dialog.ui" ]] || missing+=("cowork-dialog.ui")
    [[ -f "$config/modules/swriter/ui/select-to-act-popover.ui" ]] || missing+=("Writer select-to-act UI")
    [[ -f "$config/modules/scalc/ui/cell-range-popover.ui" ]] || missing+=("Calc select-to-act UI")
    [[ -f "$config/modules/simpress/ui/slide-element-popover.ui" ]] || missing+=("Impress select-to-act UI")
    [[ -f "$config/svx/ui/diff-review-panel.ui" ]] || missing+=("DiffReview panel UI")

    if [[ "${#missing[@]}" -eq 0 ]]; then
        record PASS "$label V2 entry parity" "CommandPalette/Cowork shortcuts, DiffReviewDeck, and V2 UI resources present"
    else
        record_blocked "$label V2 entry parity" "missing: ${missing[*]}"
    fi
}

echo "=== V2 GUI readiness smoke ===" | tee "$log"
echo "App bundle: $app" | tee -a "$log"
echo "Installed app bundle: $installed_app" | tee -a "$log"

check_bundle "builddir app" "$app"
if [[ -d "$installed_app" ]]; then
    check_bundle "installed app" "$installed_app"
else
    record NOTE "installed app bundle" "$installed_app not present"
fi
check_v2_entry_parity "builddir app" "$app"
if [[ -d "$installed_app" ]]; then
    check_v2_entry_parity "installed app" "$installed_app"
fi

if command -v osascript >/dev/null 2>&1; then
    record PASS "osascript" "$(command -v osascript)"
else
    record FAIL "osascript" "missing osascript"
fi

osascript_ok="$(osascript -e 'return "osascript-ok"' 2>&1 || true)"
[[ "$osascript_ok" == "osascript-ok" ]] && record PASS "osascript execution" "$osascript_ok" || record FAIL "osascript execution" "$osascript_ok"

activate_output="$(osascript <<APPLESCRIPT 2>&1 || true
try
  tell application id "$expected_bundle_id" to activate
  delay 1
  return "activated"
on error errMsg number errNum
  return "activate failed: " & errNum & " " & errMsg
end try
APPLESCRIPT
)"
[[ "$activate_output" == "activated" ]] && record PASS "bundle activation" "application id $expected_bundle_id activated" || record FAIL "bundle activation" "$activate_output"

process_lines="$(ps -axo pid,ppid,etime,command | grep -F '可圈office.app/Contents/MacOS/soffice' | grep -v grep || true)"
if [[ -n "$process_lines" ]]; then
    record PASS "visible process" "$(echo "$process_lines" | tr '\n' ';' | sed 's/;$//')"
else
    record FAIL "visible process" "no 可圈office soffice process found after activation"
fi
if echo "$process_lines" | grep -Fq "$app/Contents/MacOS/soffice"; then
    record NOTE "LaunchServices route" "active visible instance is builddir app"
elif echo "$process_lines" | grep -Fq "$installed_app/Contents/MacOS/soffice"; then
    record NOTE "LaunchServices route" "active visible instance is installed /Applications app"
elif [[ -n "$process_lines" ]]; then
    record NOTE "LaunchServices route" "active visible instance path differs from builddir and installed defaults"
else
    record NOTE "LaunchServices route" "no visible instance to classify"
fi

system_events_processes="$(osascript <<'APPLESCRIPT' 2>&1 || true
tell application "System Events"
  set matches to {}
  repeat with p in processes
    set n to name of p
    if n contains "office" or n contains "soffice" or n contains "可圈" then set end of matches to n
  end repeat
  return matches
end tell
APPLESCRIPT
)"
echo "$system_events_processes" | grep -Fq "soffice" && record PASS "System Events process discovery" "$system_events_processes" || record FAIL "System Events process discovery" "$system_events_processes"

ax_probe="$(osascript <<'APPLESCRIPT' 2>&1 || true
try
  tell application "System Events"
    tell process "soffice"
      set frontmost to true
      set windowCount to count of windows
      set menuBarCount to count of menu bars
      return "AX_OK windows=" & windowCount & " menuBars=" & menuBarCount
    end tell
  end tell
on error errMsg number errNum
  return "AX_DENIED_OR_FAILED " & errNum & " " & errMsg
end try
APPLESCRIPT
)"
if echo "$ax_probe" | grep -Fq "AX_OK"; then
    record PASS "Accessibility menu/window access" "$ax_probe"
else
    record BLOCKED "Accessibility menu/window access" "$ax_probe"
fi

status="passed"
[[ "$failures" -ne 0 ]] && status="failed"

{
    echo "# V2 GUI Readiness Smoke"
    echo
    echo "- Status: $status"
    echo "- Readiness: $readiness"
    echo "- App bundle: $app"
    echo "- Installed app bundle: $installed_app"
    echo "- Expected bundle id: $expected_bundle_id"
    echo "- Checks passed: $passes"
    echo "- Checks failed: $failures"
    echo "- Scope: macOS visible GUI click-through readiness preflight"
    echo
    echo "| Status | Area | Detail |"
    echo "|---|---|---|"
    printf '%s\n' "${rows[@]}"
} >"$report"

echo "Status: $status"
echo "Readiness: $readiness"
echo "Checks passed: $passes"
echo "Checks failed: $failures"
echo "Report: $report"
[[ "$failures" -eq 0 ]]
