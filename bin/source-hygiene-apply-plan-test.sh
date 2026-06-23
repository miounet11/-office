#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
script_under_test="$repo_root/bin/source-hygiene-apply-plan.sh"

tmp_root="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp_root"
}
trap cleanup EXIT

blocked_plan="$tmp_root/blocked-plan.json"
ready_plan="$tmp_root/ready-plan.json"
report="$tmp_root/apply-plan.md"
json_report="$tmp_root/apply-plan.json"

cat > "$blocked_plan" <<'JSON'
{
  "schema_version": 1,
  "status": "blocked",
  "dry_run_only": true,
  "executes_changes": false,
  "counts": {
    "missing_path_decisions": 1
  },
  "decision_groups": []
}
JSON

if "$script_under_test" --plan "$blocked_plan" --output "$report" > "$tmp_root/no-dry-run-stdout.log" 2> "$tmp_root/no-dry-run-stderr.log"; then
    printf 'Expected source hygiene apply-plan to require explicit --dry-run\n' >&2
    exit 1
fi
if ! grep -F -q -- 'requires explicit --dry-run' "$tmp_root/no-dry-run-stderr.log"; then
    printf 'Expected missing --dry-run error to be explicit\n' >&2
    exit 1
fi

if "$script_under_test" --plan "$blocked_plan" --output "$report" --json-output "$json_report" --dry-run > "$tmp_root/blocked-stdout.log" 2> "$tmp_root/blocked-stderr.log"; then
    printf 'Expected blocked source hygiene plan to fail dry-run execution preview\n' >&2
    exit 1
fi

for expected in \
    '# Source Hygiene Apply Plan Dry Run' \
    '- Status: **blocked**' \
    '- Executes changes: no' \
    'The plan is not ready for operator execution preview.'
do
    if ! grep -F -q -- "$expected" "$report"; then
        printf 'Expected blocked apply-plan report to include %s\n' "$expected" >&2
        exit 1
    fi
done

python3 - "$json_report" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

if payload["schema_version"] != 1:
    raise SystemExit("unexpected apply-plan preview schema")
if payload["status"] != "blocked":
    raise SystemExit(f"expected blocked preview: {payload['status']!r}")
if payload["dry_run_only"] is not True or payload["executes_changes"] is not False:
    raise SystemExit(f"expected non-executing dry-run payload: {payload!r}")
if payload["decision_groups"]:
    raise SystemExit(f"blocked preview should not expose executable groups: {payload['decision_groups']!r}")
PY

cat > "$ready_plan" <<'JSON'
{
  "schema_version": 1,
  "status": "ready",
  "dry_run_only": true,
  "executes_changes": false,
  "decision_groups": [
    {
      "decision": "stage approved release source/control changes",
      "count": 1,
      "entries": [
        {
          "status": " M",
          "bucket": "source_review_stage",
          "path": "bin/source-hygiene-report.sh"
        }
      ]
    }
  ]
}
JSON

"$script_under_test" --plan "$ready_plan" --output "$report" --json-output "$json_report" --dry-run > "$tmp_root/ready-stdout.log"

for expected in \
    '- Status: **ready**' \
    '- Dry-run only: yes' \
    '- Executes changes: no' \
    '### stage approved release source/control changes' \
    'Execution command: intentionally not generated' \
    'bin/source-hygiene-report.sh'
do
    if ! grep -F -q -- "$expected" "$report"; then
        printf 'Expected ready apply-plan report to include %s\n' "$expected" >&2
        exit 1
    fi
done

python3 - "$json_report" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

if payload["status"] != "ready":
    raise SystemExit(f"expected ready preview: {payload['status']!r}")
if payload["dry_run_only"] is not True or payload["executes_changes"] is not False:
    raise SystemExit(f"expected non-executing ready preview: {payload!r}")
groups = payload["decision_groups"]
if len(groups) != 1 or groups[0]["decision"] != "stage approved release source/control changes":
    raise SystemExit(f"unexpected decision groups: {groups!r}")
if groups[0]["entries"][0]["path"] != "bin/source-hygiene-report.sh":
    raise SystemExit(f"unexpected preview path: {groups!r}")
PY

printf 'source-hygiene apply-plan dry-run test passed\n'
