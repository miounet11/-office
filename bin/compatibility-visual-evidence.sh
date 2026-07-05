#!/usr/bin/env bash
# P2-01: PDF-rendered visual evidence for curated compatibility samples.
#
# Exports the first DOCX/XLSX/PPTX artifact pair from an existing
# compatibility-roundtrip run (source input + step2 roundtrip) to PDF, then
# renders first-page PNG previews. This is rendered visual evidence, not pixel
# diff against Microsoft Office.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$repo_root/tmp/compatibility-runs/p0-continue-v2-compatibility-smoke"
report_path="$repo_root/tmp/compatibility-visual-evidence/report.md"
lanes="docx,xlsx,pptx"
app_bundle="${KDOFFICE_APP_BUNDLE:-$repo_root/test-install/可圈办公.app}"

usage() {
    cat <<'EOF'
Usage:
  compatibility-visual-evidence.sh [options]

Options:
  --run-dir <path>   Existing compatibility-roundtrip run directory.
  --lanes <csv>      Lanes to render. Default: docx,xlsx,pptx.
  --app <bundle>     App bundle with soffice. Default: test-install/可圈办公.app.
  --report <path>    Output report. Default: tmp/compatibility-visual-evidence/report.md.
  -h, --help

Requires an existing roundtrip run with per-sample input/step1/step2 artifacts.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --run-dir)
            run_dir="$2"
            shift 2
            ;;
        --lanes)
            lanes="$2"
            shift 2
            ;;
        --app)
            app_bundle="$2"
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
            exit 2
            ;;
    esac
done

soffice="$app_bundle/Contents/MacOS/soffice"
if [[ ! -x "$soffice" ]]; then
    printf 'Missing soffice executable: %s\n' "$soffice" >&2
    exit 1
fi
if [[ ! -d "$run_dir" || ! -f "$run_dir/samples.tsv" ]]; then
    printf 'Missing compatibility run directory or samples.tsv: %s\n' "$run_dir" >&2
    exit 1
fi

evidence_dir="$(dirname "$report_path")"
if [[ "$evidence_dir" == "$report_path" || -z "$evidence_dir" ]]; then
    evidence_dir="$repo_root/tmp/compatibility-visual-evidence"
    report_path="$evidence_dir/report.md"
fi
mkdir -p "$evidence_dir/render"

pdf_filter_for() {
    case "${1##*.}" in
        docx|odt) printf '%s' 'pdf:writer_pdf_Export' ;;
        xlsx|ods) printf '%s' 'pdf:calc_pdf_Export' ;;
        pptx|odp) printf '%s' 'pdf:impress_pdf_Export' ;;
        *)
            printf 'Unsupported artifact for PDF export: %s\n' "$1" >&2
            return 1
            ;;
    esac
}

pdf_page_count() {
    python3 - "$1" <<'PY'
import re
import sys

data = open(sys.argv[1], "rb").read()
counts = [int(match.group(1)) for match in re.finditer(rb"/Type\s*/Pages[^>]*?/Count\s+(\d+)", data)]
print(max(counts) if counts else 0)
PY
}

convert_to_pdf() {
    local input_file="$1"
    local out_dir="$2"
    local profile filter pdf

    mkdir -p "$out_dir"
    profile="$(mktemp -d -t kq-vis-pdf.XXXXXX)"
    filter="$(pdf_filter_for "$input_file")"

    if ! "$soffice" --headless --norestore --nofirststartwizard \
        "-env:UserInstallation=file://$profile" \
        --convert-to "$filter" \
        --outdir "$out_dir" \
        "$input_file" >"$out_dir/convert.log" 2>&1; then
        rm -rf "$profile"
        return 1
    fi
    rm -rf "$profile"

    pdf="$(find "$out_dir" -maxdepth 1 -type f -name '*.pdf' | head -1)"
    if [[ -z "$pdf" || ! -s "$pdf" ]]; then
        return 1
    fi
    printf '%s' "$pdf"
}

render_png() {
    local pdf_file="$1"
    local out_dir="$2"
    local png

    mkdir -p "$out_dir"
    qlmanage -t -s 1200 -o "$out_dir" "$pdf_file" >/dev/null 2>&1
    png="$out_dir/$(basename "$pdf_file").png"
    if [[ -s "$png" ]]; then
        printf '%s' "$png"
        return 0
    fi
    return 1
}

selection_file="$(mktemp -t kq-vis-select.XXXXXX)"
trap 'rm -f "$selection_file"' EXIT
python3 - "$repo_root" "$run_dir" "$lanes" >"$selection_file" <<'PY'
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

repo_root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2]).resolve()
requested = [item.strip().lower().lstrip(".") for item in sys.argv[3].split(",") if item.strip()]
intermediate_ext = dict(docx="odt", xlsx="ods", pptx="odp")

def sample_dir_name(lane: str, source_rel: str) -> str:
    stem = Path(source_rel).stem.replace(" ", "_")
    digest = hashlib.sha1(source_rel.encode("utf-8")).hexdigest()[:10]
    return f"{lane}-{stem}-{digest}"

def single_file(root: Path, suffix: str) -> Path | None:
    if not root.is_dir():
        return None
    matches = sorted(path for path in root.iterdir() if path.is_file() and path.suffix.lower() == f".{suffix}")
    return matches[0] if len(matches) == 1 else None

samples = []
for raw in (run_dir / "samples.tsv").read_text(encoding="utf-8").splitlines():
    if not raw.strip():
        continue
    cols = raw.split("\t")
    if len(cols) < 2:
        continue
    lane = cols[0].strip().lower().lstrip(".")
    source_rel = cols[1].strip()
    note = cols[2].strip() if len(cols) >= 3 else ""
    samples.append((lane, source_rel, note))

seen = set()
for lane, source_rel, note in samples:
    if lane not in requested or lane in seen:
        continue
    sample_dir = run_dir / sample_dir_name(lane, source_rel)
    _ = intermediate_ext[lane]
    input_file = single_file(sample_dir, lane)
    step2_file = single_file(sample_dir / "step2", lane)
    if input_file is None or step2_file is None:
        continue
    print("\t".join([lane, source_rel, note, str(input_file), str(step2_file)]))
    seen.add(lane)

missing = [lane for lane in requested if lane not in seen]
if missing:
    raise SystemExit(f"Missing roundtrip artifacts for lane(s): {', '.join(missing)}")
PY

failures=0
records=()

while IFS= read -r row; do
    [[ -z "$row" ]] && continue
    IFS=$'\t' read -r lane source_rel note input_file step2_file <<<"$row"
    lane_dir="$evidence_dir/render/$lane"
    mkdir -p "$lane_dir"

    source_pdf_dir="$lane_dir/source-pdf"
    roundtrip_pdf_dir="$lane_dir/roundtrip-pdf"
    source_png_dir="$lane_dir/source-png"
    roundtrip_png_dir="$lane_dir/roundtrip-png"

    source_pdf=""
    roundtrip_pdf=""
    source_png=""
    roundtrip_png=""
    source_pages="0"
    roundtrip_pages="0"
    status="pass"

    if ! source_pdf="$(convert_to_pdf "$input_file" "$source_pdf_dir")"; then
        status="fail"
        failures=$((failures + 1))
    else
        source_pages="$(pdf_page_count "$source_pdf")"
        source_png="$(render_png "$source_pdf" "$source_png_dir" || true)"
        [[ -n "$source_png" ]] || { status="fail"; failures=$((failures + 1)); }
    fi

    if ! roundtrip_pdf="$(convert_to_pdf "$step2_file" "$roundtrip_pdf_dir")"; then
        status="fail"
        failures=$((failures + 1))
    else
        roundtrip_pages="$(pdf_page_count "$roundtrip_pdf")"
        roundtrip_png="$(render_png "$roundtrip_pdf" "$roundtrip_png_dir" || true)"
        [[ -n "$roundtrip_png" ]] || { status="fail"; failures=$((failures + 1)); }
    fi

    records+=("$lane|$source_rel|$note|$status|$source_pages|$roundtrip_pages|${input_file#$repo_root/}|${step2_file#$repo_root/}|${source_pdf#$repo_root/}|${roundtrip_pdf#$repo_root/}|${source_png#$repo_root/}|${roundtrip_png#$repo_root/}")
done <"$selection_file"

{
    printf '# Compatibility Visual Evidence (P2-01)\n\n'
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf 'Run directory: `%s`\n' "${run_dir#$repo_root/}"
    printf 'App bundle: `%s`\n' "$app_bundle"
    printf 'Lanes: `%s`\n\n' "$lanes"
    printf '## Evidence Definition\n\n'
    printf 'This report records PDF export plus first-page PNG previews for one sample per Office lane. It proves rendered output exists after roundtrip; it does not perform pixel diff against Microsoft Office.\n\n'
    printf '## Summary\n\n'
    printf '| Lane | Source sample | Scenario | Status | Source pages | Roundtrip pages | Source PNG | Roundtrip PNG |\n'
    printf '| --- | --- | --- | --- | ---: | ---: | --- | --- |\n'
    for record in "${records[@]}"; do
        IFS='|' read -r lane source_rel note status source_pages roundtrip_pages input_rel step2_rel source_pdf roundtrip_pdf source_png roundtrip_png <<<"$record"
        printf '| `%s` | `%s` | %s | **%s** | %s | %s | `%s` | `%s` |\n' \
            "$lane" "$source_rel" "$note" "$status" "$source_pages" "$roundtrip_pages" "$source_png" "$roundtrip_png"
    done
    printf '\n## Artifact Paths\n\n'
    for record in "${records[@]}"; do
        IFS='|' read -r lane source_rel note status source_pages roundtrip_pages input_rel step2_rel source_pdf roundtrip_pdf source_png roundtrip_png <<<"$record"
        printf '### `%s`: `%s`\n\n' "$lane" "$source_rel"
        printf -- '- scenario: %s\n' "$note"
        printf -- '- source input: `%s`\n' "$input_rel"
        printf -- '- roundtrip artifact: `%s`\n' "$step2_rel"
        printf -- '- source PDF: `%s`\n' "$source_pdf"
        printf -- '- roundtrip PDF: `%s`\n' "$roundtrip_pdf"
        printf -- '- source PNG: `%s`\n' "$source_png"
        printf -- '- roundtrip PNG: `%s`\n' "$roundtrip_png"
        printf -- '- page delta: %s -> %s\n\n' "$source_pages" "$roundtrip_pages"
    done
    printf '## Limitations\n\n'
    printf -- '- PNG previews are Quick Look first-page thumbnails, not full multi-page renders.\n'
    printf -- '- Page-count equality is a coarse stability signal, not layout fidelity proof.\n'
    printf -- '- Chart geometry, font substitution, and animation behavior are out of scope.\n\n'
    if [[ "$failures" -eq 0 ]]; then
        printf '## Result\n\nStatus: **pass**\n\nAt least one DOCX, XLSX, and PPTX sample has rendered PDF and PNG visual evidence.\n'
    else
        printf '## Result\n\nStatus: **fail**\n\nOne or more lanes failed PDF export or PNG rendering. Inspect per-lane convert.log files under `%s/render/`.\n' "${evidence_dir#$repo_root/}"
    fi
} >"$report_path"

printf 'Wrote compatibility visual evidence report to %s\n' "$report_path"
[[ "$failures" -eq 0 ]]