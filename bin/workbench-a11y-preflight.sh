#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -n "${KDOFFICE_SRC_ROOT:-}" ]]; then
    src_root="$(cd -P "$KDOFFICE_SRC_ROOT" && pwd)"
elif [[ -d "$repo_root/libreoffice-core" ]]; then
    src_root="$(cd -P "$repo_root/libreoffice-core" && pwd)"
else
    src_root="$(cd -P "$repo_root" && pwd)"
fi

app_root="${KDOFFICE_APP_BUNDLE:-$repo_root/test-install/可圈office.app}"
output_path="$repo_root/tmp/product-completion/workbench-a11y-preflight.md"
run_name="workbench-a11y-preflight"

usage() {
    cat <<'EOF'
Usage:
  workbench-a11y-preflight.sh [options]

Options:
  --app <path>          App bundle path. Defaults to KDOFFICE_APP_BUNDLE or test-install/可圈office.app.
  --output <path>       Report path. Default: tmp/product-completion/workbench-a11y-preflight.md
  --run-name <name>     GUI timing run name. Default: workbench-a11y-preflight
  -h, --help

Collects non-manual Workbench accessibility support evidence: static UI
accessibility checks, scenario template availability, and packaged app GUI
survival. This intentionally does not satisfy the live accessibility beta gate;
manual Tab/Shift+Tab, Enter/Space, VoiceOver, high-contrast, resize, and
missing-template fallback proof is still required.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)
            app_root="${2:?missing --app}"
            shift 2
            ;;
        --output)
            output_path="${2:?missing --output}"
            shift 2
            ;;
        --run-name)
            run_name="${2:?missing --run-name}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

mkdir -p "$(dirname "$output_path")"
preflight_dir="$repo_root/tmp/product-completion/workbench-a11y-preflight"
mkdir -p "$preflight_dir"

static_report="$preflight_dir/workbench-accessibility-check.md"
template_report="$preflight_dir/workbench-template-check.md"
gui_report="$repo_root/tmp/gui-smoke-timing/$run_name/report.md"
status="passed"
static_status="fail"
template_status="fail"
gui_status="fail"

run_gate() {
    local result_var="$1"
    local name="$2"
    local log_path="$preflight_dir/$name.log"
    shift
    shift
    if "$@" > "$log_path" 2>&1; then
        printf -v "$result_var" 'pass'
    else
        status="blocked"
        printf -v "$result_var" 'fail'
    fi
}

run_gate static_status static "$repo_root/bin/workbench-accessibility-check.sh" "$static_report"
run_gate template_status template "$repo_root/bin/workbench-template-check.sh" "$template_report"
run_gate gui_status gui env KDOFFICE_APP_BUNDLE="$app_root" "$repo_root/bin/gui-smoke-timing.sh" --app "$app_root" --mode startcenter --wait 8 --timeout 45 --run-name "$run_name"

timestamp="$(date '+%Y-%m-%d %H:%M:%S %z')"
{
    printf '# Workbench Accessibility Preflight\n\n'
    printf 'Generated at: %s\n' "$timestamp"
    printf 'Repo root: %s\n' "$repo_root"
    printf 'Source root: %s\n' "$src_root"
    printf 'App under test: `%s`\n\n' "$app_root"

    printf '## Verdict\n\n'
    printf -- '- Status: %s\n' "$status"
    printf -- '- Manual live accessibility satisfied: no\n'
    printf -- '- Accessibility claim allowed: no\n'
    printf -- '- Beta gate effect: support evidence only; workbench-live-accessibility remains blocked until `tmp/product-completion/live-accessibility-proof.md` records 24/24 manual pass.\n\n'

    printf '## Evidence\n\n'
    printf '| Gate | Status | Report | Log | What this proves | What this does not prove |\n'
    printf '| --- | --- | --- | --- | --- | --- |\n'
    printf '| Static Start Center accessibility | %s | `%s` | `%s` | UI resources and static accessibility policy can be inspected. | Manual keyboard, VoiceOver, high-contrast, resize, and fallback behavior. |\n' "$static_status" "${static_report#$repo_root/}" "${preflight_dir#$repo_root/}/static.log"
    printf '| Scenario template availability | %s | `%s` | `%s` | Scenario templates are present for runtime/manual review setup. | User-facing accessibility of the scenarios. |\n' "$template_status" "${template_report#$repo_root/}" "${preflight_dir#$repo_root/}/template.log"
    printf '| Packaged app Start Center GUI survival | %s | `%s` | `%s` | Packaged app can survive Start Center launch timing smoke. | Manual traversal, activation, announcement quality, and contrast. |\n\n' "$gui_status" "${gui_report#$repo_root/}" "${preflight_dir#$repo_root/}/gui.log"

    printf '## Manual Checks Still Required\n\n'
    printf -- '- Tab and Shift+Tab traversal order and focus-trap absence.\n'
    printf -- '- Enter and Space activation for task, blank, open, recent/template, help, extensions, and actions routes.\n'
    printf -- '- VoiceOver Chinese name, role, state, group, intent, and order quality.\n'
    printf -- '- macOS high/increased-contrast focus rings, labels, button boundaries, warnings, and empty states.\n'
    printf -- '- Narrow/short resize reachability and critical clipping review.\n'
    printf -- '- Missing-template fallback warning visibility, announcement, and focus movement.\n'
} > "$output_path"

printf 'Wrote Workbench accessibility preflight report to %s\n' "$output_path"

if [[ "$status" != "passed" ]]; then
    exit 1
fi
