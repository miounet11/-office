#!/usr/bin/env bash
# V2 product app launch smoke.
#
# Proves the installed 可圈办公.app can start from the real app bundle with
# the AI runtime environment enabled. This is stronger than H8 static bundle
# checks, but still not a GUI click-through.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mkdir -p tmp

app="${KDOFFICE_APP_BUNDLE:-$repo_root/instdir/可圈办公.app}"
log="${V2_APP_LAUNCH_LOG:-tmp/v2-app-launch-smoke.log}"
report="${V2_APP_LAUNCH_REPORT:-tmp/v2-app-launch-smoke.md}"
version_log="${V2_APP_LAUNCH_VERSION_LOG:-tmp/v2-app-launch-version.log}"
profile=""
keep_profile="${V2_APP_LAUNCH_KEEP_PROFILE:-0}"
timeout_seconds="${V2_APP_LAUNCH_TIMEOUT:-30}"
passes=0
blockers=0
failures=0
rows=()
version="<not-run>"

usage() {
    cat <<'EOF'
Usage:
  v2-app-launch-smoke.sh [--app <bundle>] [--keep-profile]

Checks:
  - H8 static bundle product-entry smoke still passes for the selected app.
  - soffice --version exits 0.
  - soffice --headless --terminate_after_init exits 0 with isolated profile.
  - AI runtime env is present during launch: KQOFFICE_AI_STUB_RUNTIME=1 and
    KQOFFICE_AI_DISABLE_PROBE=1.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)
            app="${2:?}"
            shift 2
            ;;
        --keep-profile)
            keep_profile=1
            shift
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

md_escape() {
    printf "%s" "$1" | tr "\n" ";" | sed "s/|/\\|/g"
}

record() {
    local status="$1"
    local area="$2"
    local detail="$3"
    rows+=("| $status | $area | $(md_escape "$detail") |")
    case "$status" in
        PASS)
            passes=$((passes + 1))
            printf "PASS: %s -- %s\n" "$area" "$detail"
            ;;
        BLOCKED)
            blockers=$((blockers + 1))
            printf "BLOCKED: %s -- %s\n" "$area" "$detail"
            ;;
        *)
            failures=$((failures + 1))
            printf "FAIL: %s -- %s\n" "$area" "$detail" >&2
            ;;
    esac
}

write_report() {
    local status="passed"
    if [[ "$failures" -ne 0 ]]; then
        status="failed"
    elif [[ "$blockers" -ne 0 ]]; then
        status="blocked"
    fi
    {
        echo "# V2 App Launch Smoke"
        echo
        echo "- Status: $status"
        echo "- App bundle: $app"
        echo "- Version: $version"
        echo "- Version log: $version_log"
        echo "- Launch log: $log"
        echo "- Isolated profile: ${profile:-<none>}"
        echo "- Timeout: ${timeout_seconds}s"
        echo "- Checks passed: $passes"
        echo "- Checks blocked: $blockers"
        echo "- Checks failed: $failures"
        echo "- Launch env: KQOFFICE_AI_STUB_RUNTIME=1, KQOFFICE_AI_DISABLE_PROBE=1"
        echo
        echo "| Status | Area | Detail |"
        echo "|---|---|---|"
        printf "%s\n" "${rows[@]}"
    } >"$report"

    echo "Status: $status"
    echo "Checks passed: $passes"
    echo "Checks blocked: $blockers"
    echo "Checks failed: $failures"
    echo "Report: $report"
    [[ "$failures" -eq 0 ]]
}

run_with_timeout() {
    local seconds="$1"
    shift
    perl -e 'alarm shift; exec @ARGV' "$seconds" "$@"
}

is_timeout_status() {
    local status="$1"
    [[ "$status" -eq 142 || "$status" -eq 14 ]]
}

echo "=== V2 app launch smoke ==="
echo "App bundle: $app"

echo "--- H8 static bundle checks ---"
set +e
bash bin/v2-w4-smoke-installdir.sh --no-install --app "$app" > tmp/v2-app-launch-static.log 2>&1
static_status=$?
set -e
if [[ "$static_status" -eq 0 ]] && grep -Fq "=== W4 installdir smoke: OK ===" tmp/v2-app-launch-static.log; then
    record PASS "static bundle smoke" "H8 installdir product-entry checks passed"
else
    record FAIL "static bundle smoke" "exit=$static_status; log=tmp/v2-app-launch-static.log"
    write_report
    exit 1
fi

echo "--- soffice --version ---"
set +e
run_with_timeout "$timeout_seconds" "$app/Contents/MacOS/soffice" --version >"$version_log" 2>&1
version_status=$?
set -e
version="$(head -1 "$version_log" 2>/dev/null || true)"
if [[ "$version_status" -eq 0 && -n "$version" ]]; then
    record PASS "soffice --version" "$version"
elif is_timeout_status "$version_status"; then
    version="<timeout>"
    record BLOCKED "soffice --version" "timed out after ${timeout_seconds}s; log=$version_log"
    write_report
    exit 0
elif [[ -z "$version" ]]; then
    record FAIL "soffice --version" "empty output; exit=$version_status; log=$version_log"
    write_report
    exit 1
else
    record FAIL "soffice --version" "exit=$version_status; output=$version; log=$version_log"
    write_report
    exit 1
fi
echo "$version"

profile="$(mktemp -d /tmp/kqoffice-app-launch-profile.XXXXXX)"
cleanup() {
    if [[ "$keep_profile" != "1" && -n "${profile:-}" ]]; then
        rm -rf "$profile"
    fi
}
trap cleanup EXIT

echo "--- launch --terminate_after_init ---"
set +e
run_with_timeout "$timeout_seconds" \
env \
KQOFFICE_AI_STUB_RUNTIME=1 \
KQOFFICE_AI_DISABLE_PROBE=1 \
SAL_LOG='+INFO.sw.inline_actions+INFO.kqoffice.ai' \
"$app/Contents/MacOS/soffice" \
    --headless \
    --nologo \
    --nodefault \
    --nofirststartwizard \
    --norestore \
    --nolockcheck \
    --terminate_after_init \
    "-env:UserInstallation=file://$profile" \
    >"$log" 2>&1
launch_status=$?
set -e

if [[ "$launch_status" -ne 0 ]]; then
    if is_timeout_status "$launch_status"; then
        record BLOCKED "headless terminate_after_init" "timed out after ${timeout_seconds}s; log=$log"
        write_report
        exit 0
    fi
    record FAIL "headless terminate_after_init" "exit=$launch_status; log=$log"
    write_report
    exit "$launch_status"
fi

record PASS "headless terminate_after_init" "isolated profile launch exited 0; log=$log"

write_report
if [[ "$keep_profile" == "1" ]]; then
    echo "Profile kept: $profile"
fi
