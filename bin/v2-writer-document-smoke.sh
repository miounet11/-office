#!/usr/bin/env bash
# V2 Writer document-processing smoke.
#
# Proves the installed 可圈办公.app can do more than initialize: it opens a
# real Writer import path, converts text to ODT through the product bundle, and
# verifies the generated document content. This is still not a GUI click-through.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mkdir -p tmp

app="${KDOFFICE_APP_BUNDLE:-$repo_root/instdir/可圈办公.app}"
report="${V2_WRITER_DOCUMENT_REPORT:-tmp/v2-writer-document-smoke.md}"
log="${V2_WRITER_DOCUMENT_LOG:-tmp/v2-writer-document-smoke.log}"
static_log="${V2_WRITER_DOCUMENT_STATIC_LOG:-tmp/v2-writer-document-static.log}"
artifact="${V2_WRITER_DOCUMENT_ARTIFACT:-tmp/v2-writer-document-output.odt}"
keep_work="${V2_WRITER_DOCUMENT_KEEP_WORK:-0}"
profile=""
work=""

usage() {
    cat <<'EOF'
Usage:
  v2-writer-document-smoke.sh [--app <bundle>] [--keep-work]

Checks:
  - H8 static bundle product-entry smoke still passes for the selected app.
  - soffice --headless --convert-to odt can convert a UTF-8 text file as Writer.
  - The generated ODT is readable and contains the expected document text.
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
        --keep-work)
            keep_work=1
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

cleanup() {
    if [[ "$keep_work" != "1" ]]; then
        [[ -n "${profile:-}" ]] && rm -rf "$profile"
        [[ -n "${work:-}" ]] && rm -rf "$work"
    fi
}
trap cleanup EXIT

profile="$(mktemp -d /tmp/kqoffice-writer-profile.XXXXXX)"
work="$(mktemp -d /tmp/kqoffice-writer-smoke.XXXXXX)"
input="$work/writer-input.txt"
outdir="$work/out"
output="$outdir/writer-input.odt"
expected="可圈办公 Writer smoke"
mkdir -p "$outdir"
printf '%s\nAI select-to-act baseline\n' "$expected" >"$input"

echo "=== V2 Writer document smoke ==="
echo "App bundle: $app"

echo "--- H8 static bundle checks ---"
bash bin/v2-w4-smoke-installdir.sh --no-install --app "$app" >"$static_log"
grep -Fq "=== W4 installdir smoke: OK ===" "$static_log"

echo "--- writer conversion ---"
set +e
KQOFFICE_AI_STUB_RUNTIME=1 \
KQOFFICE_AI_DISABLE_PROBE=1 \
"$app/Contents/MacOS/soffice" \
    --headless \
    --nologo \
    --nodefault \
    --nofirststartwizard \
    --norestore \
    --nolockcheck \
    "-env:UserInstallation=file://$profile" \
    --convert-to odt \
    --outdir "$outdir" \
    "$input" \
    >"$log" 2>&1
convert_status=$?
set -e

if [[ "$convert_status" -ne 0 ]]; then
    cat "$log"
    echo "FAIL: Writer conversion smoke exited $convert_status" >&2
    exit "$convert_status"
fi

if [[ ! -s "$output" ]]; then
    cat "$log"
    echo "FAIL: expected non-empty ODT output: $output" >&2
    exit 1
fi

if ! unzip -p "$output" content.xml | LC_ALL=C grep -aqF "$expected"; then
    cat "$log"
    echo "FAIL: generated ODT content.xml does not contain expected text" >&2
    exit 1
fi

cp "$output" "$artifact"

version="$("$app/Contents/MacOS/soffice" --version 2>&1 | head -1)"

{
    echo "# V2 Writer Document Smoke"
    echo
    echo "- Status: passed"
    echo "- App bundle: $app"
    echo "- Version: $version"
    echo "- Input: $input"
    echo "- Output artifact: $artifact"
    echo "- Log: $log"
    echo "- Static bundle smoke: passed"
    echo "- Isolated profile: $profile"
    echo "- Content check: passed"
    echo "- Launch env: KQOFFICE_AI_STUB_RUNTIME=1, KQOFFICE_AI_DISABLE_PROBE=1"
} >"$report"

echo "Status: passed"
echo "Version: $version"
echo "Output artifact: $artifact"
echo "Log: $log"
echo "Report: $report"
if [[ "$keep_work" == "1" ]]; then
    echo "Work kept: $work"
    echo "Profile kept: $profile"
fi
