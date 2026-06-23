#!/usr/bin/env bash
set -euo pipefail

manifest_path=""
suggestions_path=""
output_path=""
report_path=""
tsv_patch_path=""

usage() {
    cat <<'EOF'
Usage:
  source-hygiene-decision-accept-suggestions.sh --manifest <manifest.json> --suggestions <suggestions.json> --output <filled.json> [--report <report.md>] [--tsv-patch <patch.tsv>]

Creates a new decision manifest with reviewed suggestion rows transcribed.
This is a non-mutating preview: it does not edit the input manifest, stage,
delete, ignore, archive, reset, clean, or otherwise touch the working tree.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest)
            manifest_path="${2:?missing --manifest file}"
            shift 2
            ;;
        --suggestions)
            suggestions_path="${2:?missing --suggestions file}"
            shift 2
            ;;
        --output)
            output_path="${2:?missing --output file}"
            shift 2
            ;;
        --report)
            report_path="${2:?missing --report file}"
            shift 2
            ;;
        --tsv-patch)
            tsv_patch_path="${2:?missing --tsv-patch file}"
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

if [[ -z "$manifest_path" || -z "$suggestions_path" || -z "$output_path" ]]; then
    usage >&2
    exit 2
fi

python3 - "$manifest_path" "$suggestions_path" "$output_path" "$report_path" "$tsv_patch_path" <<'PY'
from pathlib import Path
import copy
import csv
import json
import sys

manifest_path = Path(sys.argv[1])
suggestions_path = Path(sys.argv[2])
output_path = Path(sys.argv[3])
report_path = Path(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4] else None
tsv_patch_path = Path(sys.argv[5]) if len(sys.argv) > 5 and sys.argv[5] else None

with manifest_path.open(encoding="utf-8") as handle:
    manifest = json.load(handle)
with suggestions_path.open(encoding="utf-8") as handle:
    suggestions_payload = json.load(handle)

if not isinstance(manifest, dict) or manifest.get("schema_version") != 1:
    raise SystemExit("decision manifest must be schema_version 1 JSON object")
if not isinstance(suggestions_payload, dict) or suggestions_payload.get("schema_version") != 1:
    raise SystemExit("suggestions must be schema_version 1 JSON object")
if suggestions_payload.get("rejected"):
    raise SystemExit("suggestions contain rejected paths; review or regenerate before accepting")
if suggestions_payload.get("executes_changes") is not False or suggestions_payload.get("applies_to_manifest") is not False:
    raise SystemExit("suggestion packet must be non-mutating")

suggestions = suggestions_payload.get("suggestions", [])
if not isinstance(suggestions, list):
    raise SystemExit("suggestions field must be a list")

suggestions_by_path = {}
for item in suggestions:
    if not isinstance(item, dict):
        raise SystemExit("suggestion item must be an object")
    path = item.get("path")
    if not isinstance(path, str) or not path:
        raise SystemExit("suggestion item is missing path")
    if path in suggestions_by_path:
        raise SystemExit(f"duplicate suggestion path: {path}")
    suggestions_by_path[path] = item

filled = copy.deepcopy(manifest)
accepted = []
accepted_rows = []
missing = []
bucket_mismatches = []

for bucket in filled.get("buckets", []):
    if not isinstance(bucket, dict):
        continue
    bucket_key = str(bucket.get("key", ""))
    entries = bucket.get("entries", [])
    if not isinstance(entries, list):
        continue
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        path = entry.get("path")
        if not isinstance(path, str):
            continue
        suggestion = suggestions_by_path.get(path)
        if suggestion is None:
            continue
        if suggestion.get("bucket") != bucket_key:
            bucket_mismatches.append(f"{path}: suggestion bucket {suggestion.get('bucket')} != manifest bucket {bucket_key}")
            continue
        for field in ("decision", "decision_owner", "decision_timestamp", "decision_note"):
            entry[field] = str(suggestion.get(field, ""))
        accepted.append(path)
        accepted_rows.append({
            "bucket": bucket_key,
            "status": str(entry.get("status", "")),
            "path": path,
            "decision": str(suggestion.get("decision", "")),
            "decision_owner": str(suggestion.get("decision_owner", "")),
            "decision_timestamp": str(suggestion.get("decision_timestamp", "")),
            "decision_note": str(suggestion.get("decision_note", "")),
        })

accepted_set = set(accepted)
for path in suggestions_by_path:
    if path not in accepted_set:
        missing.append(path)

if bucket_mismatches or missing:
    for message in bucket_mismatches:
        print(message, file=sys.stderr)
    for path in missing:
        print(f"suggestion path not found in manifest: {path}", file=sys.stderr)
    raise SystemExit(1)

filled.setdefault("operator_decision_instructions", {})["last_suggestion_accept_preview"] = {
    "suggestions": str(suggestions_path),
    "accepted_rows": len(accepted),
    "executes_changes": False,
    "applies_to_input_manifest": False,
}

output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text(json.dumps(filled, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

if report_path is not None:
    lines = []
    lines.append("# Source Hygiene Accepted Suggestions Preview")
    lines.append("")
    lines.append(f"Manifest: {manifest_path}")
    lines.append(f"Suggestions: {suggestions_path}")
    lines.append(f"Output: {output_path}")
    lines.append("")
    lines.append("## Verdict")
    lines.append("")
    lines.append("- Status: **preview-written**")
    lines.append("- Executes changes: no")
    lines.append("- Applies to input manifest: no")
    lines.append(f"- Accepted suggestions: {len(accepted)}")
    lines.append("")
    lines.append("## Accepted Paths")
    lines.append("")
    if accepted:
        lines.append("| Path |")
        lines.append("| --- |")
        for path in accepted:
            lines.append(f"| {path.replace('|', '\\|')} |")
    else:
        lines.append("- none")
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

if tsv_patch_path is not None:
    tsv_patch_path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "bucket",
        "status",
        "path",
        "decision",
        "decision_owner",
        "decision_timestamp",
        "decision_note",
    ]
    with tsv_patch_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, dialect="excel-tab", lineterminator="\n")
        writer.writeheader()
        for row in accepted_rows:
            writer.writerow(row)

print(f"Wrote accepted source hygiene suggestion preview to {output_path}")
if report_path is not None:
    print(f"Wrote accepted source hygiene suggestion report to {report_path}")
if tsv_patch_path is not None:
    print(f"Wrote accepted source hygiene suggestion TSV patch to {tsv_patch_path}")
print(f"Accepted suggestions: {len(accepted)}")
PY
