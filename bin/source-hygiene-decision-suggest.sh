#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
manifest_path="$repo_root/tmp/source-hygiene-decision-summary.json"
output_path="$repo_root/tmp/source-hygiene-decision-suggestions.json"
report_path=""
tsv_path=""
owner="${USER:-operator}"
timestamp="$(date '+%Y-%m-%d %H:%M:%S %z')"
note="reviewed development/support tooling change"
decision="stage approved release source/control changes"
paths_file=""

usage() {
    cat <<'EOF'
Usage:
  source-hygiene-decision-suggest.sh [options]

Options:
  --manifest <file>      Source hygiene decision JSON.
  --paths <file>         Newline-delimited allowlist of paths to suggest.
  --output <file>        Suggestion JSON output.
  --report <file>        Human-readable suggestion review report.
  --tsv <file>           TSV containing only suggested rows.
  --owner <name>         Decision owner recorded in suggestions.
  --timestamp <value>    Decision timestamp recorded in suggestions.
  --note <text>          Decision note recorded in suggestions.
  -h, --help

Writes a non-mutating suggestion packet for explicitly allowlisted source
hygiene entries. It does not edit the manifest or working tree.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manifest)
            manifest_path="${2:?missing --manifest file}"
            shift 2
            ;;
        --paths)
            paths_file="${2:?missing --paths file}"
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
        --tsv)
            tsv_path="${2:?missing --tsv file}"
            shift 2
            ;;
        --owner)
            owner="${2:?missing --owner value}"
            shift 2
            ;;
        --timestamp)
            timestamp="${2:?missing --timestamp value}"
            shift 2
            ;;
        --note)
            note="${2:?missing --note value}"
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

if [[ -z "$paths_file" ]]; then
    printf 'Missing --paths allowlist file\n' >&2
    exit 2
fi

python3 - "$manifest_path" "$paths_file" "$output_path" "$owner" "$timestamp" "$note" "$decision" "$report_path" "$tsv_path" <<'PY'
from pathlib import Path
import csv
import json
import sys

manifest_path = Path(sys.argv[1])
paths_file = Path(sys.argv[2])
output_path = Path(sys.argv[3])
owner, timestamp, note, decision = sys.argv[4:8]
report_path = Path(sys.argv[8]) if len(sys.argv) > 8 and sys.argv[8] else None
tsv_path = Path(sys.argv[9]) if len(sys.argv) > 9 and sys.argv[9] else None

with manifest_path.open(encoding="utf-8") as handle:
    payload = json.load(handle)
if not isinstance(payload, dict) or payload.get("schema_version") != 1:
    raise SystemExit("decision manifest must be schema_version 1 JSON object")

allowlist = []
for raw in paths_file.read_text(encoding="utf-8").splitlines():
    path = raw.strip()
    if not path or path.startswith("#"):
        continue
    allowlist.append(path)

entries_by_path = {}
for bucket in payload.get("buckets", []):
    if not isinstance(bucket, dict):
        continue
    key = str(bucket.get("key", ""))
    title = str(bucket.get("title", ""))
    allowed = bucket.get("allowed_decisions", [])
    entries = bucket.get("entries", [])
    if not isinstance(entries, list):
        continue
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        path = entry.get("path")
        if isinstance(path, str):
            entries_by_path[path] = {
                "bucket": key,
                "title": title,
                "status": str(entry.get("status", "")),
                "allowed_decisions": [str(item) for item in allowed if isinstance(item, str)],
            }

suggestions = []
rejected = []
for path in allowlist:
    current = entries_by_path.get(path)
    if current is None:
        rejected.append({"path": path, "reason": "path is not present in decision manifest"})
        continue
    if current["bucket"] != "source_review_stage":
        rejected.append({"path": path, "reason": f"path is in bucket {current['bucket']}, not source_review_stage"})
        continue
    if decision not in current["allowed_decisions"]:
        rejected.append({"path": path, "reason": "suggested decision is not allowed for this bucket"})
        continue
    suggestions.append({
        "path": path,
        "status": current["status"],
        "bucket": current["bucket"],
        "decision": decision,
        "decision_owner": owner,
        "decision_timestamp": timestamp,
        "decision_note": note,
    })

packet = {
    "schema_version": 1,
    "manifest": str(manifest_path),
    "paths_file": str(paths_file),
    "executes_changes": False,
    "applies_to_manifest": False,
    "suggested_decision": decision,
    "suggestions": suggestions,
    "rejected": rejected,
    "next_action": "review suggestions, then transcribe accepted rows via TSV merge or JSON manifest editing and run --validate-decisions",
}

output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text(json.dumps(packet, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

if report_path is not None:
    report_lines = []
    report_lines.append("# Source Hygiene Decision Suggestions")
    report_lines.append("")
    report_lines.append(f"Manifest: {manifest_path}")
    report_lines.append(f"Paths file: {paths_file}")
    report_lines.append("")
    report_lines.append("## Verdict")
    report_lines.append("")
    report_lines.append("- Status: **review-required**")
    report_lines.append("- Executes changes: no")
    report_lines.append("- Applies to manifest: no")
    report_lines.append(f"- Suggestions: {len(suggestions)}")
    report_lines.append(f"- Rejected: {len(rejected)}")
    report_lines.append("")
    report_lines.append("## Suggested Rows")
    report_lines.append("")
    if suggestions:
        report_lines.append("| Status | Bucket | Path | Suggested decision | Owner | Timestamp | Note |")
        report_lines.append("| --- | --- | --- | --- | --- | --- | --- |")
        for item in suggestions:
            safe_path = item["path"].replace("|", "\\|")
            safe_note = item["decision_note"].replace("|", "\\|")
            report_lines.append(
                f"| {item['status']} | {item['bucket']} | {safe_path} | {item['decision']} | "
                f"{item['decision_owner']} | {item['decision_timestamp']} | {safe_note} |"
            )
    else:
        report_lines.append("- none")
    report_lines.append("")
    report_lines.append("## Rejected Rows")
    report_lines.append("")
    if rejected:
        report_lines.append("| Path | Reason |")
        report_lines.append("| --- | --- |")
        for item in rejected:
            safe_path = item["path"].replace("|", "\\|")
            safe_reason = item["reason"].replace("|", "\\|")
            report_lines.append(f"| {safe_path} | {safe_reason} |")
    else:
        report_lines.append("- none")
    report_lines.append("")
    report_lines.append("## Next Action")
    report_lines.append("")
    report_lines.append("- Review the suggested rows. Accepted rows still need to be transcribed into the TSV or JSON manifest, validated, planned, and dry-run previewed before any worktree operation.")
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text("\n".join(report_lines) + "\n", encoding="utf-8")

if tsv_path is not None:
    tsv_path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "bucket",
        "status",
        "path",
        "decision",
        "decision_owner",
        "decision_timestamp",
        "decision_note",
    ]
    with tsv_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, dialect="excel-tab", lineterminator="\n")
        writer.writeheader()
        for item in suggestions:
            writer.writerow({
                "bucket": item["bucket"],
                "status": item["status"],
                "path": item["path"],
                "decision": item["decision"],
                "decision_owner": item["decision_owner"],
                "decision_timestamp": item["decision_timestamp"],
                "decision_note": item["decision_note"],
            })

print(f"Wrote source hygiene decision suggestions to {output_path}")
if report_path is not None:
    print(f"Wrote source hygiene decision suggestion report to {report_path}")
if tsv_path is not None:
    print(f"Wrote source hygiene decision suggestion TSV to {tsv_path}")
print(f"Suggestions: {len(suggestions)}")
print(f"Rejected: {len(rejected)}")
if rejected:
    raise SystemExit(1)
PY
