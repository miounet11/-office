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
manifest_path=""
output_path=""

usage() {
    cat <<'EOF'
Usage:
  compatibility-manifest-audit.sh --manifest <path> [--report <path>]

Audits a compatibility manifest without running conversions. The manifest
format is:
  format<TAB>source-relative-path<TAB>scenario/risk note

The audit checks lane validity, missing files, duplicate samples, extension
matches, /fail/ paths, scenario-note coverage, and high-level risk labels.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest)
            manifest_path="$2"
            shift 2
            ;;
        --report)
            output_path="$2"
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

if [[ -z "$manifest_path" ]]; then
    printf 'Missing --manifest\n' >&2
    usage >&2
    exit 1
fi

if [[ ! -f "$manifest_path" ]]; then
    printf 'Missing manifest: %s\n' "$manifest_path" >&2
    exit 1
fi

manifest_path="$(cd "$(dirname "$manifest_path")" && pwd)/$(basename "$manifest_path")"

if [[ -z "$output_path" ]]; then
    stem="$(basename "$manifest_path" .tsv)"
    output_path="$repo_root/tmp/compatibility-manifest-audit-$stem.md"
fi

mkdir -p "$(dirname "$output_path")"

python3 - "$repo_root" "$src_root" "$manifest_path" "$output_path" <<'PY'
from collections import Counter
from pathlib import Path
import subprocess
import sys

repo_root = Path(sys.argv[1])
src_root = Path(sys.argv[2])
manifest_path = Path(sys.argv[3])
output_path = Path(sys.argv[4])

allowed_formats = {"docx", "xlsx", "pptx", "odt", "ods", "odp", "doc", "xls", "ppt", "pdf"}
risk_keywords = {
    "writer": ("writer", "docx", "文档", "report", "notice", "minutes", "resume", "contract", "table", "tracked", "comments"),
    "calc": ("calc", "xlsx", "sheet", "budget", "schedule", "sales", "formula", "chart", "filter", "date"),
    "impress": ("impress", "pptx", "slide", "deck", "media", "shape", "font", "text", "theme", "courseware"),
}


def now() -> str:
    return subprocess.check_output(["date", "+%Y-%m-%d %H:%M:%S %z"], text=True).strip()


entries: list[dict[str, object]] = []
errors: list[str] = []
warnings: list[str] = []
seen: set[tuple[str, str]] = set()

for line_number, raw_line in enumerate(manifest_path.read_text(encoding="utf-8").splitlines(), start=1):
    line = raw_line.strip()
    if not line or line.startswith("#"):
        continue

    columns = raw_line.split("\t")
    if len(columns) < 2:
        errors.append(f"{line_number}: expected format<TAB>source-relative-path")
        continue

    lane = columns[0].strip().lower().lstrip(".")
    rel = columns[1].strip()
    note = columns[2].strip() if len(columns) >= 3 else ""
    entry_errors: list[str] = []
    entry_warnings: list[str] = []

    if lane not in allowed_formats:
        entry_errors.append(f"unsupported lane {lane!r}")

    rel_path = Path(rel)
    if not rel:
        entry_errors.append("empty source-relative-path")
    elif rel_path.is_absolute() or ".." in rel_path.parts:
        entry_errors.append("path must stay inside source root")
    else:
        source_path = src_root / rel_path
        if not source_path.is_file():
            entry_errors.append("sample missing")
        elif source_path.suffix.lower() != f".{lane}":
            entry_errors.append(f"lane does not match extension {source_path.suffix!r}")

    if "fail" in rel_path.parts:
        entry_warnings.append("path contains /fail/")

    if not note:
        entry_warnings.append("missing scenario/risk note")

    key = (lane, rel)
    if key in seen:
        entry_errors.append("duplicate lane/path")
    seen.add(key)

    errors.extend(f"{line_number}: {item}" for item in entry_errors)
    warnings.extend(f"{line_number}: {item}" for item in entry_warnings)
    entries.append({
        "line": line_number,
        "lane": lane,
        "rel": rel,
        "note": note,
        "errors": entry_errors,
        "warnings": entry_warnings,
    })

lane_counts = Counter(str(entry["lane"]) for entry in entries)
root_counts = Counter(str(entry["rel"]).split("/", 1)[0] for entry in entries if entry["rel"])
note_count = sum(1 for entry in entries if entry["note"])
risk_counts = Counter()
for entry in entries:
    note = str(entry["note"]).lower()
    for risk, keywords in risk_keywords.items():
        if any(keyword in note for keyword in keywords):
            risk_counts[risk] += 1

lines: list[str] = []
lines.append("# Compatibility Manifest Audit")
lines.append("")
lines.append(f"Generated at: {now()}")
lines.append(f"Manifest: `{manifest_path}`")
lines.append(f"Source root: `{src_root}`")
lines.append("")
lines.append("## Summary")
lines.append("")
lines.append(f"- Entries: {len(entries)}")
lines.append(f"- Scenario notes: {note_count}/{len(entries)}")
lines.append(f"- Errors: {len(errors)}")
lines.append(f"- Warnings: {len(warnings)}")
lines.append(f"- Status: **{'fail' if errors else 'pass'}**")
lines.append("")
lines.append("## Lane Counts")
lines.append("")
if lane_counts:
    lines.append("| Lane | Count |")
    lines.append("| --- | ---: |")
    for lane, count in sorted(lane_counts.items()):
        lines.append(f"| `{lane}` | {count} |")
else:
    lines.append("- none")
lines.append("")
lines.append("## Root Counts")
lines.append("")
if root_counts:
    lines.append("| Root | Count |")
    lines.append("| --- | ---: |")
    for root, count in root_counts.most_common():
        lines.append(f"| `{root}` | {count} |")
else:
    lines.append("- none")
lines.append("")
lines.append("## Risk Label Coverage")
lines.append("")
lines.append("| Risk group | Matched notes |")
lines.append("| --- | ---: |")
for risk in ("writer", "calc", "impress"):
    lines.append(f"| `{risk}` | {risk_counts[risk]} |")
lines.append("")
lines.append("## Errors")
lines.append("")
if errors:
    for item in errors:
        lines.append(f"- {item}")
else:
    lines.append("- none")
lines.append("")
lines.append("## Warnings")
lines.append("")
if warnings:
    for item in warnings:
        lines.append(f"- {item}")
else:
    lines.append("- none")
lines.append("")
lines.append("## Entries")
lines.append("")
lines.append("| Line | Lane | Path | Note |")
lines.append("| ---: | --- | --- | --- |")
for entry in entries:
    lines.append(f"| {entry['line']} | `{entry['lane']}` | `{entry['rel']}` | {entry['note'] or '-'} |")

output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Wrote compatibility manifest audit to {output_path}")

if errors:
    raise SystemExit(1)
PY
