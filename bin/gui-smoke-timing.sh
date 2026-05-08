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
app_candidates=(
    "$repo_root/instdir/可圈office.app"
    "$repo_root/test-install/可圈office.app"
)
if [[ "$src_root" != "$repo_root" ]]; then
    app_candidates+=(
        "$src_root/test-install/可圈office.app"
        "$src_root/instdir/可圈office.app"
    )
fi
if [[ -n "${KDOFFICE_APP_BUNDLE:-}" ]]; then
    app_root="$KDOFFICE_APP_BUNDLE"
else
    app_root="${app_candidates[0]}"
    for candidate in "${app_candidates[@]}"; do
        if [[ -x "$candidate/Contents/MacOS/soffice" ]]; then
            app_root="$candidate"
            break
        fi
    done
fi
run_name="$(date '+%Y%m%d-%H%M%S')"
report_path=""
wait_seconds="12"
max_elapsed_seconds=""
timeout_seconds=""
mode="startcenter"

usage() {
    cat <<'EOF'
Usage:
  gui-smoke-timing.sh [options]

Options:
  --app <path>          App bundle path. Defaults to instdir/可圈office.app.
  --mode <startcenter|writer|calc|impress>
  --wait <seconds>     Seconds the process must remain alive. Default: 12.
  --max-elapsed <sec>  Optional wall-clock budget for the full smoke run.
                      Reports budget status separately from process survival.
  --timeout <seconds>  Optional hard watchdog for the smoke run.
                      Reports timeout status separately from budget status.
  --run-name <name>
  --report <path>
  -h, --help

Launches the packaged app with a fresh temporary profile, records a
repeatable GUI smoke/timing report, then terminates the process.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)
            app_root="$2"
            shift 2
            ;;
        --mode)
            mode="$2"
            shift 2
            ;;
        --wait)
            wait_seconds="$2"
            shift 2
            ;;
        --max-elapsed)
            max_elapsed_seconds="$2"
            shift 2
            ;;
        --timeout)
            timeout_seconds="$2"
            shift 2
            ;;
        --run-name)
            run_name="$2"
            shift 2
            ;;
        --report)
            report_path="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

case "$mode" in
    startcenter) mode_arg="" ;;
    writer) mode_arg="--writer" ;;
    calc) mode_arg="--calc" ;;
    impress) mode_arg="--impress" ;;
    *)
        printf 'Unsupported mode: %s\n' "$mode" >&2
        exit 1
        ;;
esac

if ! [[ "$wait_seconds" =~ ^[0-9]+$ ]] || [[ "$wait_seconds" -lt 1 ]]; then
    printf 'Wait must be a positive integer\n' >&2
    exit 1
fi

if [[ -n "$max_elapsed_seconds" ]]; then
    python3 - "$max_elapsed_seconds" <<'PY'
import sys
try:
    value = float(sys.argv[1])
except ValueError:
    raise SystemExit("Timing budget must be a positive number")
if value <= 0:
    raise SystemExit("Timing budget must be a positive number")
PY
fi

if [[ -n "$timeout_seconds" ]]; then
    if ! [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || [[ "$timeout_seconds" -lt 1 ]]; then
        printf 'Timeout must be a positive integer\n' >&2
        exit 1
    fi
fi

soffice_bin="$app_root/Contents/MacOS/soffice"
if [[ ! -x "$soffice_bin" ]]; then
    printf 'Missing app executable: %s\n' "$soffice_bin" >&2
    exit 1
fi

run_dir="$repo_root/tmp/gui-smoke-timing/$run_name"
mkdir -p "$run_dir"
if [[ -z "$report_path" ]]; then
    report_path="$run_dir/report.md"
fi

profile_dir="$(mktemp -d "${TMPDIR:-/tmp}/kqoffice-gui-smoke.XXXXXX")"
log_path="$run_dir/soffice.log"
codesign_log="$run_dir/codesign-verify.log"
bundle_metadata_log="$run_dir/bundle-metadata.log"
crash_report_path="not-found"

latest_soffice_crash_report() {
    local diagnostics_dir="$HOME/Library/Logs/DiagnosticReports"
    if [[ -d "$diagnostics_dir" ]]; then
        ls -t "$diagnostics_dir"/soffice*.ips 2>/dev/null | head -1 || true
    fi
}

wait_for_new_soffice_crash_report() {
    local previous="$1"
    local newest=""
    for _ in 1 2 3 4 5; do
        newest="$(latest_soffice_crash_report)"
        if [[ -n "$newest" && "$newest" != "$previous" ]]; then
            printf '%s\n' "$newest"
            return 0
        fi
        sleep 1
    done
    if [[ -n "$newest" ]]; then
        printf '%s\n' "$newest"
    fi
}

preexisting_crash_report="$(latest_soffice_crash_report)"

{
    printf 'Bundle: %s\n' "$app_root"
    printf 'Executable exists: %s\n' "$(if [[ -x "$soffice_bin" ]]; then printf yes; else printf no; fi)"
    printf 'Code signature resources: %s\n' "$(if [[ -f "$app_root/Contents/_CodeSignature/CodeResources" ]]; then printf present; else printf missing; fi)"
    if command -v plutil >/dev/null 2>&1; then
        printf 'CFBundleExecutable: '
        plutil -extract CFBundleExecutable raw "$app_root/Contents/Info.plist" 2>/dev/null || printf 'unreadable'
        printf '\nCFBundleIdentifier: '
        plutil -extract CFBundleIdentifier raw "$app_root/Contents/Info.plist" 2>/dev/null || printf 'unreadable'
        printf '\nNSPrincipalClass: '
        plutil -extract NSPrincipalClass raw "$app_root/Contents/Info.plist" 2>/dev/null || printf 'unreadable'
        printf '\nLSRequiresCarbon: '
        plutil -extract LSRequiresCarbon raw "$app_root/Contents/Info.plist" 2>/dev/null || printf 'unreadable'
        printf '\n'
    fi
} > "$bundle_metadata_log" 2>&1

codesign_status="not-run"
if command -v codesign >/dev/null 2>&1; then
    if codesign --verify --deep --strict --verbose=2 "$app_root" > "$codesign_log" 2>&1; then
        codesign_status="pass"
    else
        codesign_status="fail"
    fi
else
    printf 'codesign not found\n' > "$codesign_log"
fi

start_epoch="$(python3 - <<'PY'
import time
print(f"{time.monotonic():.6f}")
PY
)"

launch_cmd=("$soffice_bin" "-env:UserInstallation=file://$profile_dir" "--norestore")
if [[ -n "$mode_arg" ]]; then
    launch_cmd+=("$mode_arg")
fi

"${launch_cmd[@]}" > "$log_path" 2>&1 &
pid="$!"

alive="no"
timeout_status="not-set"
timeout_triggered="no"
wait_completed="no"
process_exit_status="not-collected"
exit_classification="still-running"
SECONDS=0

classify_exit() {
    local status="$1"
    if [[ "$status" =~ ^[0-9]+$ ]]; then
        if [[ "$status" -ge 128 ]]; then
            local signal=$((status - 128))
            case "$signal" in
                6) printf 'signal %s (SIGABRT / likely abort)\n' "$signal" ;;
                9) printf 'signal %s (SIGKILL)\n' "$signal" ;;
                11) printf 'signal %s (SIGSEGV / likely crash)\n' "$signal" ;;
                15) printf 'signal %s (SIGTERM)\n' "$signal" ;;
                *) printf 'signal %s\n' "$signal" ;;
            esac
        elif [[ "$status" -eq 0 ]]; then
            printf 'clean exit before wait window\n'
        else
            printf 'non-zero exit before wait window\n'
        fi
    else
        printf 'unknown\n'
    fi
}

while true; do
    if ! kill -0 "$pid" 2>/dev/null; then
        if wait "$pid"; then
            process_exit_status="0"
        else
            process_exit_status="$?"
        fi
        exit_classification="$(classify_exit "$process_exit_status")"
        break
    fi
    if [[ "$SECONDS" -ge "$wait_seconds" ]]; then
        alive="yes"
        wait_completed="yes"
        break
    fi
    if [[ -n "$timeout_seconds" && "$SECONDS" -ge "$timeout_seconds" ]]; then
        timeout_triggered="yes"
        timeout_status="fail"
        break
    fi
    sleep 1
done

if [[ -n "$timeout_seconds" && "$timeout_triggered" == "no" ]]; then
    timeout_status="pass"
fi

end_epoch="$(python3 - <<'PY'
import time
print(f"{time.monotonic():.6f}")
PY
)"
elapsed="$(python3 - "$start_epoch" "$end_epoch" <<'PY'
import sys
start = float(sys.argv[1])
end = float(sys.argv[2])
print(f"{end - start:.3f}")
PY
)"

budget_status="not-set"
if [[ -n "$max_elapsed_seconds" ]]; then
    if python3 - "$elapsed" "$max_elapsed_seconds" <<'PY'
import sys
elapsed = float(sys.argv[1])
budget = float(sys.argv[2])
raise SystemExit(0 if elapsed <= budget else 1)
PY
    then
        budget_status="pass"
    else
        budget_status="fail"
    fi
fi

if [[ "$alive" == "yes" ]]; then
    kill "$pid" 2>/dev/null || true
    sleep 2
    kill -9 "$pid" 2>/dev/null || true
    if wait "$pid" 2>/dev/null; then
        process_exit_status="0"
    else
        process_exit_status="$?"
    fi
    exit_classification="terminated after successful wait window"
elif [[ "$timeout_triggered" == "yes" ]]; then
    kill "$pid" 2>/dev/null || true
    sleep 2
    kill -9 "$pid" 2>/dev/null || true
    if wait "$pid" 2>/dev/null; then
        process_exit_status="0"
    else
        process_exit_status="$?"
    fi
    exit_classification="terminated after timeout watchdog"
fi

if [[ "$alive" != "yes" ]]; then
    newest_crash_report="$(wait_for_new_soffice_crash_report "$preexisting_crash_report")"
    if [[ -n "$newest_crash_report" && "$newest_crash_report" != "$preexisting_crash_report" ]]; then
        crash_report_path="$newest_crash_report"
    elif [[ -n "$newest_crash_report" ]]; then
        crash_report_path="$newest_crash_report"
    fi
fi

survival_status="fail"
if [[ "$alive" == "yes" && "$wait_completed" == "yes" ]]; then
    survival_status="pass"
fi

overall_status="pass"
if [[ "$survival_status" != "pass" || "$timeout_status" == "fail" || "$budget_status" == "fail" ]]; then
    overall_status="fail"
fi

{
    printf '# GUI Smoke Timing\n\n'
    printf 'Run name: %s\n' "$run_name"
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf 'App: `%s`\n' "$app_root"
    printf 'Executable: `%s`\n' "$soffice_bin"
    printf 'Mode: `%s`\n' "$mode"
    printf 'Fresh profile: `%s`\n' "$profile_dir"
    printf 'Process ID: `%s`\n' "$pid"
    printf 'Process exit status: `%s`\n' "$process_exit_status"
    printf 'Likely exit classification: `%s`\n' "$exit_classification"
    printf 'Wait seconds: %s\n' "$wait_seconds"
    printf 'Elapsed seconds: %s\n' "$elapsed"
    printf 'Alive after wait: **%s**\n' "$alive"
    printf 'Survival status: **%s**\n' "$survival_status"
    if [[ -n "$timeout_seconds" ]]; then
        printf 'Timeout seconds: %s\n' "$timeout_seconds"
    else
        printf 'Timeout seconds: not set\n'
    fi
    printf 'Timeout status: **%s**\n' "$timeout_status"
    if [[ -n "$max_elapsed_seconds" ]]; then
        printf 'Timing budget seconds: %s\n' "$max_elapsed_seconds"
    else
        printf 'Timing budget seconds: not set\n'
    fi
    printf 'Timing budget status: **%s**\n' "$budget_status"
    printf 'Log: `%s`\n\n' "${log_path#$repo_root/}"
    printf 'Codesign verify status: **%s**\n' "$codesign_status"
    printf 'Bundle metadata log: `%s`\n' "${bundle_metadata_log#$repo_root/}"
    printf 'Codesign log: `%s`\n' "${codesign_log#$repo_root/}"
    printf 'Newest crash report: `%s`\n\n' "$crash_report_path"
    printf '## Timing Scope\n\n'
    printf 'This script measures total wall-clock smoke duration through the configured wait window. It proves process survival and coarse timing only; it does not prove UI-ready paint, first input latency, or visual usability.\n\n'
    printf '## Bundle Metadata\n\n'
    printf '```\n'
    tail -80 "$bundle_metadata_log" 2>/dev/null || true
    printf '```\n\n'
    printf '## Codesign Verify\n\n'
    printf '```\n'
    tail -80 "$codesign_log" 2>/dev/null || true
    printf '```\n\n'
    if [[ "$crash_report_path" != "not-found" && -f "$crash_report_path" ]]; then
        printf '## Crash Report Header\n\n'
        printf '```\n'
        sed -n '1,80p' "$crash_report_path" 2>/dev/null || true
        printf '```\n\n'
    fi
    printf '## SOffice Log Tail\n\n'
    printf '```\n'
    tail -80 "$log_path" 2>/dev/null || true
    printf '```\n\n'
    printf '## Result\n\n'
    printf 'Status: **%s**\n' "$overall_status"
    if [[ "$timeout_status" == "fail" ]]; then
        printf '\n'
        printf 'The smoke run hit the hard timeout before completing the configured wait window.\n'
    elif [[ "$survival_status" != "pass" ]]; then
        printf '\n'
        printf 'The process exited before the wait window completed.\n'
    elif [[ "$budget_status" == "fail" ]]; then
        printf '\n'
        printf 'The process survived, but elapsed time exceeded the configured timing budget.\n'
    else
        printf '\n'
        printf 'The process survived the wait window and did not trigger configured timeout or timing-budget failures.\n'
    fi
} > "$report_path"

printf 'Wrote GUI smoke timing report to %s\n' "$report_path"

if [[ "$timeout_status" == "fail" ]]; then
    tail -40 "$log_path" >&2 || true
    exit 1
fi

if [[ "$survival_status" != "pass" ]]; then
    tail -40 "$log_path" >&2 || true
    exit 1
fi

if [[ "$budget_status" == "fail" ]]; then
    exit 1
fi
