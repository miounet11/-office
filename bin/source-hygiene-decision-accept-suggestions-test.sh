#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
accept_under_test="$repo_root/bin/source-hygiene-decision-accept-suggestions.sh"
suggest_under_test="$repo_root/bin/source-hygiene-decision-suggest.sh"
report_under_test="$repo_root/bin/source-hygiene-report.sh"

tmp_root="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp_root"
}
trap cleanup EXIT

fake_repo="$tmp_root/repo"
mkdir -p "$fake_repo/bin"
cp "$accept_under_test" "$fake_repo/bin/source-hygiene-decision-accept-suggestions.sh"
cp "$suggest_under_test" "$fake_repo/bin/source-hygiene-decision-suggest.sh"
cp "$report_under_test" "$fake_repo/bin/source-hygiene-report.sh"
chmod +x "$fake_repo/bin/source-hygiene-decision-accept-suggestions.sh" "$fake_repo/bin/source-hygiene-decision-suggest.sh" "$fake_repo/bin/source-hygiene-report.sh"

git -C "$fake_repo" init -q
git -C "$fake_repo" config user.email source-hygiene-accept-test@example.invalid
git -C "$fake_repo" config user.name "Source Hygiene Accept Test"
printf 'tracked\n' > "$fake_repo/2.md"
git -C "$fake_repo" add 2.md bin/source-hygiene-decision-accept-suggestions.sh bin/source-hygiene-decision-suggest.sh bin/source-hygiene-report.sh
git -C "$fake_repo" commit -q -m 'seed accept test repo'
printf 'changed\n' >> "$fake_repo/2.md"

manifest="$fake_repo/tmp/source-hygiene-decision-summary.json"
paths="$fake_repo/tmp/source-hygiene-accept-paths.txt"
suggestions="$fake_repo/tmp/source-hygiene-decision-suggestions.json"
accepted="$fake_repo/tmp/source-hygiene-decision-accepted.json"
accepted_report="$fake_repo/tmp/source-hygiene-decision-accepted.md"
accepted_tsv_patch="$fake_repo/tmp/source-hygiene-decision-accepted.tsv"
progress="$fake_repo/tmp/source-hygiene-decision-progress.md"
progress_json="$fake_repo/tmp/source-hygiene-decision-progress.json"

"$fake_repo/bin/source-hygiene-report.sh" --decision-json "$manifest" > "$tmp_root/manifest-stdout.log"
printf '2.md\n' > "$paths"
"$fake_repo/bin/source-hygiene-decision-suggest.sh" --manifest "$manifest" --paths "$paths" --output "$suggestions" --owner accept-test --timestamp "2026-06-15 00:00:00 +0800" --note "accept preview test" > "$tmp_root/suggest-stdout.log"
"$fake_repo/bin/source-hygiene-decision-accept-suggestions.sh" --manifest "$manifest" --suggestions "$suggestions" --output "$accepted" --report "$accepted_report" --tsv-patch "$accepted_tsv_patch" > "$tmp_root/accept-stdout.log"

python3 - "$manifest" "$accepted" <<'PY'
import json
import sys

source, accepted = sys.argv[1:3]
with open(source, encoding="utf-8") as handle:
    original = json.load(handle)
with open(accepted, encoding="utf-8") as handle:
    filled = json.load(handle)

original_entry = original["buckets"][0]["entries"][0]
filled_entry = filled["buckets"][0]["entries"][0]
if original_entry["decision"] != "":
    raise SystemExit(f"input manifest was modified: {original_entry!r}")
if filled_entry["decision"] != "stage approved release source/control changes":
    raise SystemExit(f"accepted manifest did not receive suggestion: {filled_entry!r}")
preview = filled["operator_decision_instructions"].get("last_suggestion_accept_preview", {})
if preview.get("accepted_rows") != 1 or preview.get("executes_changes") is not False or preview.get("applies_to_input_manifest") is not False:
    raise SystemExit(f"unexpected accept preview metadata: {preview!r}")
PY

for expected in \
    '# Source Hygiene Accepted Suggestions Preview' \
    '- Status: **preview-written**' \
    '- Executes changes: no' \
    '- Applies to input manifest: no' \
    '- Accepted suggestions: 1' \
    '| 2.md |'
do
    if ! grep -F -q -- "$expected" "$accepted_report"; then
        printf 'Expected accepted suggestion report to include %s\n' "$expected" >&2
        exit 1
    fi
done

python3 - "$accepted_tsv_patch" <<'PY'
import csv
import sys

with open(sys.argv[1], encoding="utf-8", newline="") as handle:
    rows = list(csv.DictReader(handle, dialect="excel-tab"))

if len(rows) != 1:
    raise SystemExit(f"expected one accepted TSV patch row: {rows!r}")
row = rows[0]
if row["path"] != "2.md" or row["decision"] != "stage approved release source/control changes":
    raise SystemExit(f"unexpected accepted TSV patch row: {row!r}")
PY

"$fake_repo/bin/source-hygiene-report.sh" --decision-progress "$accepted" --json-output "$progress_json" "$progress" > "$tmp_root/progress-stdout.log"
python3 - "$progress_json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

if payload["status"] != "ready":
    raise SystemExit(f"expected accepted suggestion preview to be ready in one-path test: {payload!r}")
if payload["counts"]["valid_path_decisions"] != 1 or payload["counts"]["missing_path_decisions"] != 0:
    raise SystemExit(f"unexpected accepted progress counts: {payload['counts']!r}")
PY

bad_suggestions="$fake_repo/tmp/source-hygiene-decision-suggestions-rejected.json"
python3 - "$suggestions" "$bad_suggestions" <<'PY'
import json
import sys

source, target = sys.argv[1:3]
with open(source, encoding="utf-8") as handle:
    payload = json.load(handle)
payload["rejected"] = [{"path": ":-", "reason": "odd local"}]
with open(target, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY
if "$fake_repo/bin/source-hygiene-decision-accept-suggestions.sh" --manifest "$manifest" --suggestions "$bad_suggestions" --output "$accepted" > "$tmp_root/rejected-stdout.log" 2> "$tmp_root/rejected-stderr.log"; then
    printf 'Expected accept suggestions to reject packets with rejected paths\n' >&2
    exit 1
fi
if ! grep -F -q -- 'suggestions contain rejected paths' "$tmp_root/rejected-stderr.log"; then
    printf 'Expected rejected suggestion packet failure to be explicit\n' >&2
    exit 1
fi

printf 'source-hygiene accept suggestions test passed\n'
