#!/usr/bin/env bash
# V2 office-suite document-processing smoke.
#
# Proves the installed 可圈office.app can process real documents across the
# main Office/WPS-equivalent surfaces: Writer, Calc, and Impress. This is still
# not a visible GUI click-through.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mkdir -p tmp

app="${KDOFFICE_APP_BUNDLE:-$repo_root/instdir/可圈office.app}"
report="${V2_SUITE_DOCUMENT_REPORT:-tmp/v2-suite-document-smoke.md}"
static_log="${V2_SUITE_DOCUMENT_STATIC_LOG:-tmp/v2-suite-document-static.log}"
writer_log="${V2_SUITE_WRITER_LOG:-tmp/v2-suite-writer-document-smoke.log}"
calc_log="${V2_SUITE_CALC_LOG:-tmp/v2-suite-calc-document-smoke.log}"
impress_pdf_log="${V2_SUITE_IMPRESS_PDF_LOG:-tmp/v2-suite-impress-pdf-smoke.log}"
impress_pptx_log="${V2_SUITE_IMPRESS_PPTX_LOG:-tmp/v2-suite-impress-pptx-smoke.log}"
writer_artifact="${V2_SUITE_WRITER_ARTIFACT:-tmp/v2-suite-writer-output.odt}"
calc_artifact="${V2_SUITE_CALC_ARTIFACT:-tmp/v2-suite-calc-output.ods}"
impress_pdf_artifact="${V2_SUITE_IMPRESS_PDF_ARTIFACT:-tmp/v2-suite-impress-output.pdf}"
impress_odp_artifact="${V2_SUITE_IMPRESS_ODP_ARTIFACT:-tmp/v2-suite-impress-pptx-output.odp}"
keep_work="${V2_SUITE_DOCUMENT_KEEP_WORK:-0}"
profile=""
work=""

usage() {
    cat <<'EOF'
Usage:
  v2-suite-document-smoke.sh [--app <bundle>] [--keep-work]

Checks:
  - H8 static bundle product-entry smoke still passes for the selected app.
  - Writer converts UTF-8 text to ODT and preserves document text.
  - Calc converts CSV to ODS and preserves sheet values.
  - Impress exports an ODP fixture to PDF.
  - Impress imports a PPTX fixture and writes a valid ODP.
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

src_root="${KDOFFICE_SRC_ROOT:-/Users/lu/kdoffice-src}"
impress_pdf_input="$src_root/sd/qa/unit/data/slide_with_text.odp"
impress_pptx_input="$src_root/sd/qa/unit/data/tdf90403.pptx"
if [[ ! -f "$impress_pdf_input" || ! -f "$impress_pptx_input" ]]; then
    echo "FAIL: missing Impress fixture(s) under $src_root/sd/qa/unit/data" >&2
    exit 1
fi

cleanup() {
    if [[ "$keep_work" != "1" ]]; then
        [[ -n "${profile:-}" ]] && rm -rf "$profile"
        [[ -n "${work:-}" ]] && rm -rf "$work"
    fi
}
trap cleanup EXIT

profile="$(mktemp -d /tmp/kqoffice-suite-profile.XXXXXX)"
work="$(mktemp -d /tmp/kqoffice-suite-smoke.XXXXXX)"
mkdir -p "$work/writer-out" "$work/calc-out" "$work/impress-pdf-out" "$work/impress-pptx-out"

writer_input="$work/writer-input.txt"
writer_expected="可圈office Writer smoke"
printf '%s\nAI suite baseline\n' "$writer_expected" >"$writer_input"

calc_input="$work/calc-input.csv"
calc_expected="Alpha"
printf 'Name,Score\nAlpha,42\nBeta,73\n' >"$calc_input"

run_soffice_convert() {
    local log_path="$1"
    shift
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
        "$@" \
        >"$log_path" 2>&1
    local status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
        cat "$log_path"
        echo "FAIL: soffice conversion exited $status" >&2
        exit "$status"
    fi
}

echo "=== V2 suite document smoke ==="
echo "App bundle: $app"

echo "--- H8 static bundle checks ---"
bash bin/v2-w4-smoke-installdir.sh --no-install --app "$app" >"$static_log"
grep -Fq "=== W4 installdir smoke: OK ===" "$static_log"

echo "--- Writer txt -> odt ---"
run_soffice_convert "$writer_log" --convert-to odt --outdir "$work/writer-out" "$writer_input"
writer_output="$work/writer-out/writer-input.odt"
[[ -s "$writer_output" ]] || { cat "$writer_log"; echo "FAIL: missing Writer ODT" >&2; exit 1; }
unzip -p "$writer_output" content.xml | LC_ALL=C grep -aqF "$writer_expected" \
    || { echo "FAIL: Writer ODT missing expected text" >&2; exit 1; }
cp "$writer_output" "$writer_artifact"

echo "--- Calc csv -> ods ---"
run_soffice_convert "$calc_log" --convert-to ods --outdir "$work/calc-out" "$calc_input"
calc_output="$work/calc-out/calc-input.ods"
[[ -s "$calc_output" ]] || { cat "$calc_log"; echo "FAIL: missing Calc ODS" >&2; exit 1; }
unzip -p "$calc_output" content.xml | LC_ALL=C grep -aqF "$calc_expected" \
    || { echo "FAIL: Calc ODS missing expected value" >&2; exit 1; }
cp "$calc_output" "$calc_artifact"

echo "--- Impress odp -> pdf ---"
run_soffice_convert "$impress_pdf_log" --convert-to pdf --outdir "$work/impress-pdf-out" "$impress_pdf_input"
impress_pdf_output="$work/impress-pdf-out/slide_with_text.pdf"
[[ -s "$impress_pdf_output" ]] || { cat "$impress_pdf_log"; echo "FAIL: missing Impress PDF" >&2; exit 1; }
head -c 5 "$impress_pdf_output" | LC_ALL=C grep -aqF '%PDF' \
    || { echo "FAIL: Impress PDF missing PDF header" >&2; exit 1; }
cp "$impress_pdf_output" "$impress_pdf_artifact"

echo "--- Impress pptx -> odp ---"
run_soffice_convert "$impress_pptx_log" --convert-to odp --outdir "$work/impress-pptx-out" "$impress_pptx_input"
impress_odp_output="$work/impress-pptx-out/tdf90403.odp"
[[ -s "$impress_odp_output" ]] || { cat "$impress_pptx_log"; echo "FAIL: missing PPTX-import ODP" >&2; exit 1; }
unzip -t "$impress_odp_output" >/dev/null
cp "$impress_odp_output" "$impress_odp_artifact"

version="$("$app/Contents/MacOS/soffice" --version 2>&1 | head -1)"

{
    echo "# V2 Suite Document Smoke"
    echo
    echo "- Status: passed"
    echo "- App bundle: $app"
    echo "- Version: $version"
    echo "- Static bundle smoke: passed"
    echo "- Isolated profile: $profile"
    echo "- Writer artifact: $writer_artifact"
    echo "- Calc artifact: $calc_artifact"
    echo "- Impress PDF artifact: $impress_pdf_artifact"
    echo "- Impress PPTX import artifact: $impress_odp_artifact"
    echo "- Logs: $writer_log, $calc_log, $impress_pdf_log, $impress_pptx_log"
    echo "- Launch env: KQOFFICE_AI_STUB_RUNTIME=1, KQOFFICE_AI_DISABLE_PROBE=1"
} >"$report"

echo "Status: passed"
echo "Version: $version"
echo "Writer artifact: $writer_artifact"
echo "Calc artifact: $calc_artifact"
echo "Impress PDF artifact: $impress_pdf_artifact"
echo "Impress PPTX import artifact: $impress_odp_artifact"
echo "Report: $report"
if [[ "$keep_work" == "1" ]]; then
    echo "Work kept: $work"
    echo "Profile kept: $profile"
fi
