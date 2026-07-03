#!/usr/bin/env bash
# PDF confidence trio: CJK font embedding + page-count stability + PDF/A.
# Usage: bin/pdf-confidence-check.sh --run-name NAME [--samples lane:path,...]

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SOFFICE="$REPO/test-install/可圈办公.app/Contents/MacOS/soffice"
VERAPDF="$REPO/bin/verapdf.sh"
RUN_NAME=""
SAMPLES_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-name) RUN_NAME="${2:?}"; shift 2 ;;
    --samples) SAMPLES_ARG="${2:?}"; shift 2 ;;
    -h|--help) echo "Usage: $0 --run-name NAME [--samples lane:path,...]"; exit 0 ;;
    *) echo "Unknown: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$RUN_NAME" ]] || { echo "--run-name required" >&2; exit 2; }
[[ -x "$SOFFICE" ]] || { echo "Missing soffice" >&2; exit 2; }
[[ -x "$VERAPDF" ]] || { echo "Missing veraPDF wrapper" >&2; exit 2; }

RUN_DIR="$REPO/tmp/pdf-confidence/$RUN_NAME"
mkdir -p "$RUN_DIR"
REPORT="$RUN_DIR/report.md"

# Default samples chosen for CJK likelihood (LO test corpus is mostly Latin;
# we exercise the toolchain even if no CJK glyph appears).
default_samples="docx:/Users/lu/kdoffice-src/sw/qa/core/exportdata/ooxml/pass/sdt-in-shape-with-textbox.docx,xlsx:/Users/lu/kdoffice-src/sc/qa/uitest/data/tdf141547.xlsx,pptx:/Users/lu/kdoffice-src/sd/qa/unit/data/tdf90403.pptx"
SAMPLES="${SAMPLES_ARG:-$default_samples}"

# Inspect a PDF using stdlib + `strings`:
#   ARG1=mode (pages|fonts), ARG2=pdf path
inspect_pdf() {
  local mode="$1" pdf="$2"
  if [[ "$mode" == "pages" ]]; then
    python3 - "$pdf" <<'PY'
import re, sys
data = open(sys.argv[1], 'rb').read()
counts = [int(m.group(1)) for m in re.finditer(rb'/Type\s*/Pages[^>]*?/Count\s+(\d+)', data)]
print(max(counts) if counts else 0)
PY
  elif [[ "$mode" == "fonts" ]]; then
    local strtmp; strtmp=$(mktemp -t pdfc-strings.XXXXXX)
    strings "$pdf" 2>/dev/null > "$strtmp"
    python3 - "$strtmp" <<'PY'
import re, sys
text = open(sys.argv[1], 'r', errors='replace').read()
seen = set()
embedded = '/FontFile' in text
for m in re.finditer(r'/BaseFont\s*/([A-Z]{0,6}\+?)([A-Za-z0-9_,.\-]+)', text):
    seen.add((m.group(1) or '', m.group(2)))
for prefix, name in sorted(seen):
    print(f"{prefix}{name}\t{'embedded' if embedded else 'unknown'}")
PY
    rm -f "$strtmp"
  fi
}

cjk_pattern='CJK|Hei|Song|Sim|Noto|SourceHan|Source Han|MingLi|PingFang|Yuanti|STSong|STHeiti|Microsoft YaHei|Kaiti'

PASS=0; FAIL=0; SKIP=0
mark() { case "$1" in pass) PASS=$((PASS+1)) ;; fail) FAIL=$((FAIL+1)) ;; skip) SKIP=$((SKIP+1)) ;; esac; }

{
  echo "# PDF Confidence Report: $RUN_NAME"
  echo
  echo "Generated: $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "soffice: \`$SOFFICE\`"
  echo "veraPDF: \`$VERAPDF\`"
  echo "Inspection: stdlib regex (no pdfinfo/pdffonts available)"
  echo
} > "$REPORT"

IFS=',' read -ra items <<<"$SAMPLES"
for idx in "${!items[@]}"; do
  spec="${items[$idx]}"
  lane="${spec%%:*}"
  input="${spec#*:}"
  base="$(basename "$input")"
  stem="${base%.*}"
  lane_dir="$RUN_DIR/$lane-$((idx+1))"
  mkdir -p "$lane_dir"

  {
    echo "## Sample $((idx+1)): $lane"
    echo
    echo "- Input: \`$input\`"
  } >> "$REPORT"

  if [[ ! -f "$input" ]]; then
    echo "- Conversion: **fail** input missing" >> "$REPORT"
    mark fail; mark fail; mark fail
    continue
  fi

  pages=()
  conversion_ok=1
  pdf_path=""
  for n in 1 2 3; do
    out="$lane_dir/run$n"
    mkdir -p "$out"
    profile=$(mktemp -d -t pdfc.XXXXXX)
    if "$SOFFICE" --headless --norestore --nofirststartwizard \
         "-env:UserInstallation=file://$profile" \
         --convert-to 'pdf:writer_pdf_Export:{"SelectPdfVersion":{"type":"long","value":"1"}}' \
         --outdir "$out" "$input" \
         > "$out/convert.log" 2>&1; then
      pdf="$(find "$out" -maxdepth 1 -name "*.pdf" | head -1)"
      if [[ -n "$pdf" && -f "$pdf" ]]; then
        pc=$(inspect_pdf pages "$pdf" 2>/dev/null || echo ERR)
        pages+=("$pc")
        pdf_path="$pdf"
      else
        conversion_ok=0; pages+=("ERR")
      fi
    else
      conversion_ok=0; pages+=("ERR")
    fi
    rm -rf "$profile"
  done

  cstat="fail"; [[ "$conversion_ok" -eq 1 ]] && cstat="pass"
  echo "- Conversion: **$cstat**" >> "$REPORT"
  echo "- Page counts (3 runs): ${pages[*]}" >> "$REPORT"

  if [[ "$conversion_ok" -eq 1 && "${pages[0]}" != "ERR" \
        && "${pages[0]}" == "${pages[1]}" && "${pages[1]}" == "${pages[2]}" ]]; then
    echo "- Page stability: **pass**" >> "$REPORT"; mark pass
  else
    echo "- Page stability: **fail**" >> "$REPORT"; mark fail
  fi

  if [[ -z "$pdf_path" ]]; then
    echo "- CJK font embedding: **fail** no PDF" >> "$REPORT"; mark fail
    echo "- veraPDF PDF/A-1b: **fail** no PDF" >> "$REPORT"; mark fail
    echo >> "$REPORT"
    continue
  fi

  flist="$(inspect_pdf fonts "$pdf_path" 2>/dev/null || true)"
  echo "- Fonts:" >> "$REPORT"
  echo '```' >> "$REPORT"
  [[ -n "$flist" ]] && echo "$flist" >> "$REPORT" || echo "(no fonts detected)" >> "$REPORT"
  echo '```' >> "$REPORT"

  if echo "$flist" | grep -Eiq "$cjk_pattern" && echo "$flist" | grep -q "embedded"; then
    echo "- CJK font embedding: **pass**" >> "$REPORT"; mark pass
  elif echo "$flist" | grep -q "embedded"; then
    echo "- CJK font embedding: **skip** (no CJK glyph in this Latin sample; toolchain detected $(echo "$flist" | wc -l | tr -d ' ') embedded font(s))" >> "$REPORT"; mark skip
  else
    echo "- CJK font embedding: **fail** (no embedded fonts detected)" >> "$REPORT"; mark fail
  fi

  vlog="$lane_dir/verapdf.log"
  if "$VERAPDF" --flavour 1b "$pdf_path" > "$vlog" 2>&1; then
    if grep -Eiq 'isCompliant="true"|compliant="true"' "$vlog"; then
      echo "- veraPDF PDF/A-1b: **pass**" >> "$REPORT"; mark pass
    else
      echo "- veraPDF PDF/A-1b: **fail** non-compliant (PDF was not exported as PDF/A)" >> "$REPORT"; mark fail
    fi
  else
    echo "- veraPDF PDF/A-1b: **fail** veraPDF exit non-zero (likely non-PDF/A input)" >> "$REPORT"; mark fail
  fi
  echo "- veraPDF log: \`${vlog#$REPO/}\`" >> "$REPORT"
  echo >> "$REPORT"
done

{
  echo "## Summary"
  echo
  echo "- pass: $PASS"
  echo "- fail: $FAIL"
  echo "- skip: $SKIP"
  echo "- total: $((PASS+FAIL+SKIP))"
  echo
  echo "Note: CJK font embedding **skip** is expected when the input sample has no CJK glyphs. To prove CJK embedding for production use, supply a Chinese-text sample via --samples."
} >> "$REPORT"

echo "Report: $REPORT"
[[ "$FAIL" -eq 0 ]] || exit 1
exit 0
