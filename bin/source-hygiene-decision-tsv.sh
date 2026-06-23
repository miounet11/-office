#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
mode=""
manifest_path=""
tsv_path=""
output_path=""
patch_path=""

usage() {
    cat <<'EOF'
Usage:
  source-hygiene-decision-tsv.sh --export <manifest.json> --tsv <decisions.tsv>
  source-hygiene-decision-tsv.sh --merge <manifest.json> --tsv <decisions.tsv> --output <filled.json>
  source-hygiene-decision-tsv.sh --overlay <base.tsv> --patch <patch.tsv> --output <filled.tsv>

Exports and merges operator source-hygiene decisions as TSV. This helper only
transcribes decision fields; it never stages, deletes, ignores, archives,
resets, cleans, or otherwise mutates the working tree.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --export)
            mode="export"
            manifest_path="${2:?missing --export manifest}"
            shift 2
            ;;
        --merge)
            mode="merge"
            manifest_path="${2:?missing --merge manifest}"
            shift 2
            ;;
        --overlay)
            mode="overlay"
            tsv_path="${2:?missing --overlay base TSV}"
            shift 2
            ;;
        --patch)
            patch_path="${2:?missing --patch TSV}"
            shift 2
            ;;
        --tsv)
            tsv_path="${2:?missing --tsv file}"
            shift 2
            ;;
        --output)
            output_path="${2:?missing --output file}"
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

if [[ -z "$mode" || -z "$tsv_path" ]]; then
    usage >&2
    exit 2
fi
if [[ "$mode" != "overlay" && -z "$manifest_path" ]]; then
    usage >&2
    exit 2
fi
if [[ "$mode" == "merge" && -z "$output_path" ]]; then
    printf 'Missing --output for --merge\n' >&2
    exit 2
fi
if [[ "$mode" == "overlay" && ( -z "$patch_path" || -z "$output_path" ) ]]; then
    printf 'Missing --patch or --output for --overlay\n' >&2
    exit 2
fi

python3 - "$repo_root" "$mode" "$manifest_path" "$tsv_path" "$output_path" "$patch_path" <<'PY'
from pathlib import Path
import csv
import json
import sys

repo_root = Path(sys.argv[1])
mode = sys.argv[2]
manifest_path = Path(sys.argv[3])
tsv_path = Path(sys.argv[4])
output_path = Path(sys.argv[5]) if len(sys.argv) > 5 and sys.argv[5] else None
patch_path = Path(sys.argv[6]) if len(sys.argv) > 6 and sys.argv[6] else None

fieldnames = [
    "bucket",
    "title",
    "status",
    "path",
    "allowed_decisions",
    "decision",
    "decision_owner",
    "decision_timestamp",
    "decision_note",
]

payload = None
if mode != "overlay":
    with manifest_path.open(encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict) or payload.get("schema_version") != 1:
        raise SystemExit("decision manifest must be schema_version 1 JSON object")

def iter_entries():
    for bucket in payload.get("buckets", []):
        if not isinstance(bucket, dict):
            continue
        bucket_key = str(bucket.get("key", ""))
        title = str(bucket.get("title", ""))
        allowed = bucket.get("allowed_decisions", [])
        allowed_text = " | ".join(str(item) for item in allowed if isinstance(item, str))
        entries = bucket.get("entries", [])
        if not isinstance(entries, list):
            continue
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            yield bucket_key, title, allowed_text, entry

def read_tsv(path: Path, required_fields: list[str]) -> list[dict]:
    with path.open(encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, dialect="excel-tab")
        missing = [field for field in required_fields if field not in (reader.fieldnames or [])]
        if missing:
            raise SystemExit(f"{path} is missing required columns: " + ", ".join(missing))
        return list(reader)

def rows_by_unique_path(rows: list[dict], label: str) -> dict[str, dict]:
    by_path: dict[str, list[dict]] = {}
    for row in rows:
        path = (row.get("path") or "").strip()
        if not path:
            continue
        by_path.setdefault(path, []).append(row)
    duplicate_paths = sorted(path for path, values in by_path.items() if len(values) > 1)
    if duplicate_paths:
        raise SystemExit(f"{label} has duplicate path rows: " + ", ".join(duplicate_paths[:20]))
    return {path: values[0] for path, values in by_path.items()}

if mode == "overlay":
    if output_path is None or patch_path is None:
        raise SystemExit("missing overlay output or patch path")
    base_rows = read_tsv(tsv_path, fieldnames)
    patch_required = ["path", "decision", "decision_owner", "decision_timestamp", "decision_note"]
    patch_rows = read_tsv(patch_path, patch_required)
    base_by_path = rows_by_unique_path(base_rows, "base TSV")
    patch_by_path = rows_by_unique_path(patch_rows, "patch TSV")
    missing_patch_paths = sorted(path for path in patch_by_path if path not in base_by_path)
    if missing_patch_paths:
        raise SystemExit("patch TSV paths are missing from base TSV: " + ", ".join(missing_patch_paths[:20]))
    overlay_count = 0
    for path, patch_row in patch_by_path.items():
        base_row = base_by_path[path]
        for field in ("decision", "decision_owner", "decision_timestamp", "decision_note"):
            base_row[field] = patch_row.get(field, "") or ""
        if base_row.get("decision"):
            overlay_count += 1
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, dialect="excel-tab", lineterminator="\n")
        writer.writeheader()
        writer.writerows(base_rows)
    print(f"Wrote source hygiene overlaid decision TSV to {output_path}")
    print(f"Overlay decision rows: {overlay_count}")
    raise SystemExit(0)

if mode == "export":
    tsv_path.parent.mkdir(parents=True, exist_ok=True)
    with tsv_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, dialect="excel-tab", lineterminator="\n")
        writer.writeheader()
        for bucket_key, title, allowed_text, entry in iter_entries():
            writer.writerow({
                "bucket": bucket_key,
                "title": title,
                "status": str(entry.get("status", "")),
                "path": str(entry.get("path", "")),
                "allowed_decisions": allowed_text,
                "decision": str(entry.get("decision", "")),
                "decision_owner": str(entry.get("decision_owner", "")),
                "decision_timestamp": str(entry.get("decision_timestamp", "")),
                "decision_note": str(entry.get("decision_note", "")),
            })
    print(f"Wrote source hygiene decision TSV to {tsv_path}")
    raise SystemExit(0)

if mode != "merge":
    raise SystemExit(f"unsupported mode: {mode}")

if output_path is None:
    raise SystemExit("missing output path")
rows = read_tsv(tsv_path, fieldnames)
rows_by_path = rows_by_unique_path(rows, "TSV")

merged = 0
for _bucket_key, _title, _allowed_text, entry in iter_entries():
    path = str(entry.get("path", ""))
    row = rows_by_path.get(path)
    if row is None:
        continue
    for field in ("decision", "decision_owner", "decision_timestamp", "decision_note"):
        entry[field] = row.get(field, "") or ""
    if entry.get("decision"):
        merged += 1

payload.setdefault("operator_decision_instructions", {})["last_tsv_merge"] = {
    "tsv": str(tsv_path),
    "merged_decision_rows": merged,
    "executes_changes": False,
}

output_path.parent.mkdir(parents=True, exist_ok=True)
with output_path.open("w", encoding="utf-8") as handle:
    json.dump(payload, handle, ensure_ascii=False, indent=2)
    handle.write("\n")

print(f"Wrote merged source hygiene decision JSON to {output_path}")
print(f"Merged decision rows: {merged}")
PY
