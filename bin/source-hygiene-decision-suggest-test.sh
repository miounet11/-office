#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
script_under_test="$repo_root/bin/source-hygiene-decision-suggest.sh"
report_under_test="$repo_root/bin/source-hygiene-report.sh"

tmp_root="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp_root"
}
trap cleanup EXIT

fake_repo="$tmp_root/repo"
mkdir -p "$fake_repo/bin"
cp "$script_under_test" "$fake_repo/bin/source-hygiene-decision-suggest.sh"
cp "$report_under_test" "$fake_repo/bin/source-hygiene-report.sh"
chmod +x "$fake_repo/bin/source-hygiene-decision-suggest.sh" "$fake_repo/bin/source-hygiene-report.sh"

git -C "$fake_repo" init -q
git -C "$fake_repo" config user.email source-hygiene-suggest-test@example.invalid
git -C "$fake_repo" config user.name "Source Hygiene Suggest Test"
printf 'tracked\n' > "$fake_repo/2.md"
git -C "$fake_repo" add 2.md bin/source-hygiene-decision-suggest.sh bin/source-hygiene-report.sh
git -C "$fake_repo" commit -q -m 'seed suggest test repo'
printf 'changed\n' >> "$fake_repo/2.md"
printf 'odd\n' > "$fake_repo/:-"

manifest="$fake_repo/tmp/source-hygiene-decision-summary.json"
paths="$fake_repo/tmp/suggest-paths.txt"
suggestions="$fake_repo/tmp/source-hygiene-decision-suggestions.json"
suggestions_report="$fake_repo/tmp/source-hygiene-decision-suggestions.md"
suggestions_tsv="$fake_repo/tmp/source-hygiene-decision-suggestions.tsv"

"$fake_repo/bin/source-hygiene-report.sh" --decision-json "$manifest" > "$tmp_root/manifest-stdout.log"
printf '2.md\n' > "$paths"

"$fake_repo/bin/source-hygiene-decision-suggest.sh" --manifest "$manifest" --paths "$paths" --output "$suggestions" --report "$suggestions_report" --tsv "$suggestions_tsv" --owner "suggest-test" --timestamp "2026-06-15 00:00:00 +0800" --note "unit suggestion" > "$tmp_root/suggest-stdout.log"

python3 - "$suggestions" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

if payload["schema_version"] != 1:
    raise SystemExit("unexpected suggestion schema")
if payload["executes_changes"] is not False or payload["applies_to_manifest"] is not False:
    raise SystemExit(f"suggestions must be non-mutating: {payload!r}")
if payload["rejected"]:
    raise SystemExit(f"unexpected rejected suggestions: {payload['rejected']!r}")
suggestions = payload["suggestions"]
if len(suggestions) != 1:
    raise SystemExit(f"expected one suggestion: {suggestions!r}")
entry = suggestions[0]
if entry["path"] != "2.md" or entry["bucket"] != "source_review_stage":
    raise SystemExit(f"unexpected suggestion entry: {entry!r}")
if entry["decision"] != "stage approved release source/control changes":
    raise SystemExit(f"unexpected suggested decision: {entry!r}")
PY

for expected in \
    '# Source Hygiene Decision Suggestions' \
    '- Status: **review-required**' \
    '- Executes changes: no' \
    '- Applies to manifest: no' \
    '|  M | source_review_stage | 2.md | stage approved release source/control changes |'
do
    if ! grep -F -q -- "$expected" "$suggestions_report"; then
        printf 'Expected suggestion report to include %s\n' "$expected" >&2
        exit 1
    fi
done

python3 - "$suggestions_tsv" <<'PY'
import csv
import sys

with open(sys.argv[1], encoding="utf-8", newline="") as handle:
    rows = list(csv.DictReader(handle, dialect="excel-tab"))

if len(rows) != 1:
    raise SystemExit(f"expected one suggestion TSV row: {rows!r}")
row = rows[0]
if row["path"] != "2.md" or row["decision_owner"] != "suggest-test":
    raise SystemExit(f"unexpected suggestion TSV row: {row!r}")
PY

printf '2.md\n:-\nnot-present.txt\n' > "$paths"
if "$fake_repo/bin/source-hygiene-decision-suggest.sh" --manifest "$manifest" --paths "$paths" --output "$suggestions" > "$tmp_root/reject-stdout.log" 2> "$tmp_root/reject-stderr.log"; then
    printf 'Expected mixed allowlist with odd/missing paths to fail suggestions\n' >&2
    exit 1
fi

python3 - "$suggestions" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

rejected = {item["path"]: item["reason"] for item in payload["rejected"]}
if ":-" not in rejected or "odd_local_human_decision" not in rejected[":-"]:
    raise SystemExit(f"expected odd local rejection: {rejected!r}")
if "not-present.txt" not in rejected:
    raise SystemExit(f"expected missing path rejection: {rejected!r}")
if len(payload["suggestions"]) != 1:
    raise SystemExit(f"expected valid suggestions to remain visible: {payload['suggestions']!r}")
PY

printf 'source-hygiene decision suggestion test passed\n'
