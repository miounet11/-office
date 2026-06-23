#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
plan_path="$repo_root/tmp/source-hygiene-decision-plan.json"
output_path="$repo_root/tmp/source-hygiene-apply-plan-dry-run.md"
json_output=""
dry_run=0

usage() {
    cat <<'EOF'
Usage:
  source-hygiene-apply-plan.sh [options]

Options:
  --plan <file>       Machine-readable decision plan JSON.
  --output <file>     Dry-run report path.
  --json-output <file>
                      Machine-readable dry-run preview JSON path.
  --dry-run           Required. Write an operator execution preview only.
  -h, --help

Reads a source hygiene decision plan and writes a non-destructive execution
preview. This script intentionally does not stage, delete, ignore, reset,
archive, or clean files.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --plan)
            plan_path="$2"
            shift 2
            ;;
        --output)
            output_path="$2"
            shift 2
            ;;
        --json-output)
            json_output="$2"
            shift 2
            ;;
        --dry-run)
            dry_run=1
            shift
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

if [[ "$dry_run" -ne 1 ]]; then
    printf 'source-hygiene-apply-plan requires explicit --dry-run; execution mode is not implemented\n' >&2
    exit 2
fi

mkdir -p "$(dirname "$output_path")"

python3 - "$repo_root" "$plan_path" "$output_path" "$json_output" <<'PY'
from pathlib import Path
import json
import sys

repo_root = Path(sys.argv[1])
plan_path = Path(sys.argv[2])
output_path = Path(sys.argv[3])
json_output = Path(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4] else None

errors: list[str] = []
try:
    with plan_path.open(encoding="utf-8") as handle:
        payload = json.load(handle)
except FileNotFoundError:
    payload = None
    errors.append(f"plan does not exist: {plan_path}")
except json.JSONDecodeError as exc:
    payload = None
    errors.append(f"plan is not valid JSON: {exc}")

if payload is not None and not isinstance(payload, dict):
    errors.append("plan root must be a JSON object")
    payload = None

if payload is not None and payload.get("schema_version") != 1:
    errors.append("plan schema_version must be 1")

status = payload.get("status", "unknown") if payload else "invalid"
dry_run_only = payload.get("dry_run_only") if payload else None
executes_changes = payload.get("executes_changes") if payload else None
decision_groups = payload.get("decision_groups", []) if payload else []
if payload is not None and not isinstance(decision_groups, list):
    errors.append("plan decision_groups must be a list")
    decision_groups = []

ready = not errors and status == "ready" and dry_run_only is True and executes_changes is False
normalized_groups: list[dict] = []
if isinstance(decision_groups, list):
    for group in decision_groups:
        if not isinstance(group, dict):
            continue
        entries = group.get("entries", [])
        if not isinstance(entries, list):
            entries = []
        normalized_entries = []
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            normalized_entries.append({
                "status": str(entry.get("status", "")),
                "bucket": str(entry.get("bucket", "")),
                "path": str(entry.get("path", "")),
            })
        normalized_groups.append({
            "decision": str(group.get("decision", "")),
            "count": len(normalized_entries),
            "entries": normalized_entries,
        })

lines: list[str] = []
lines.append("# Source Hygiene Apply Plan Dry Run")
lines.append("")
lines.append(f"Repo root: {repo_root}")
lines.append(f"Plan: {plan_path}")
lines.append("")
lines.append("## Verdict")
lines.append("")
lines.append(f"- Status: **{'ready' if ready else 'blocked'}**")
lines.append("- Dry-run only: yes")
lines.append("- Executes changes: no")
lines.append(f"- Plan status: {status}")
lines.append(f"- Plan dry_run_only: {dry_run_only}")
lines.append(f"- Plan executes_changes: {executes_changes}")
lines.append("")

if errors:
    lines.append("## Plan Errors")
    lines.append("")
    for error in errors:
        lines.append(f"- {error}")
    lines.append("")

if not ready:
    lines.append("## Blocked")
    lines.append("")
    lines.append("- The plan is not ready for operator execution preview.")
    lines.append("- Regenerate and validate source hygiene decisions before any worktree change.")
else:
    lines.append("## Decision Groups")
    lines.append("")
    for group in normalized_groups:
        decision = group["decision"]
        entries = group["entries"]
        lines.append(f"### {decision}")
        lines.append("")
        lines.append(f"- Count: {len(entries)}")
        lines.append("- Execution command: intentionally not generated; operator approval must choose the command family.")
        lines.append("")
        lines.append("| Status | Bucket | Path |")
        lines.append("| --- | --- | --- |")
        for entry in entries:
            status_text = entry["status"]
            bucket = entry["bucket"]
            path = entry["path"].replace("|", "\\|")
            lines.append(f"| {status_text} | {bucket} | {path} |")
        lines.append("")

output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
preview_payload = {
    "schema_version": 1,
    "repo_root": str(repo_root),
    "plan": str(plan_path),
    "status": "ready" if ready else "blocked",
    "dry_run_only": True,
    "executes_changes": False,
    "plan_status": status,
    "plan_dry_run_only": dry_run_only,
    "plan_executes_changes": executes_changes,
    "plan_errors": errors,
    "decision_groups": normalized_groups if ready else [],
}
if json_output is not None:
    json_output.parent.mkdir(parents=True, exist_ok=True)
    json_output.write_text(json.dumps(preview_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Wrote source hygiene apply-plan dry-run to {output_path}")
if not ready:
    raise SystemExit(1)
PY
