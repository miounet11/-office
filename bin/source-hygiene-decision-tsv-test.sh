#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
script_under_test="$repo_root/bin/source-hygiene-decision-tsv.sh"
validator_under_test="$repo_root/bin/source-hygiene-report.sh"

tmp_root="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp_root"
}
trap cleanup EXIT

fake_repo="$tmp_root/repo"
mkdir -p "$fake_repo/bin"
cp "$script_under_test" "$fake_repo/bin/source-hygiene-decision-tsv.sh"
cp "$validator_under_test" "$fake_repo/bin/source-hygiene-report.sh"
chmod +x "$fake_repo/bin/source-hygiene-decision-tsv.sh" "$fake_repo/bin/source-hygiene-report.sh"

git -C "$fake_repo" init -q
git -C "$fake_repo" config user.email source-hygiene-tsv-test@example.invalid
git -C "$fake_repo" config user.name "Source Hygiene TSV Test"
printf 'tracked\n' > "$fake_repo/2.md"
git -C "$fake_repo" add 2.md bin/source-hygiene-decision-tsv.sh bin/source-hygiene-report.sh
git -C "$fake_repo" commit -q -m 'seed tsv test repo'
printf 'changed\n' >> "$fake_repo/2.md"

manifest="$fake_repo/tmp/source-hygiene-decision-summary.json"
tsv="$fake_repo/tmp/source-hygiene-decisions.tsv"
merged="$fake_repo/tmp/source-hygiene-decision-merged.json"
validation="$fake_repo/tmp/source-hygiene-decision-validation.md"
patch_tsv="$fake_repo/tmp/source-hygiene-decisions-patch.tsv"
overlaid_tsv="$fake_repo/tmp/source-hygiene-decisions-overlaid.tsv"

"$fake_repo/bin/source-hygiene-report.sh" --decision-json "$manifest" > "$tmp_root/manifest-stdout.log"
"$fake_repo/bin/source-hygiene-decision-tsv.sh" --export "$manifest" --tsv "$tsv" > "$tmp_root/export-stdout.log"
cp "$tsv" "$tmp_root/original-export.tsv"

for expected in \
    $'bucket\ttitle\tstatus\tpath\tallowed_decisions\tdecision\tdecision_owner\tdecision_timestamp\tdecision_note' \
    $'source_review_stage\tSource review/stage\t M\t2.md'
do
    if ! grep -F -q -- "$expected" "$tsv"; then
        printf 'Expected exported TSV to include %s\n' "$expected" >&2
        exit 1
    fi
done

python3 - "$tsv" <<'PY'
import csv
import sys

path = sys.argv[1]
with open(path, encoding="utf-8", newline="") as handle:
    rows = list(csv.DictReader(handle, dialect="excel-tab"))

if len(rows) != 1:
    raise SystemExit(f"expected one exported row: {rows!r}")
row = rows[0]
row["decision"] = "stage approved release source/control changes"
row["decision_owner"] = "source-hygiene-tsv-test"
row["decision_timestamp"] = "2026-06-15 00:00:00 +0800"
row["decision_note"] = "tsv merge test"

with open(path, "w", encoding="utf-8", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(row.keys()), dialect="excel-tab", lineterminator="\n")
    writer.writeheader()
    writer.writerow(row)
PY

python3 - "$tsv" "$patch_tsv" <<'PY'
import csv
import sys

source, target = sys.argv[1:3]
with open(source, encoding="utf-8", newline="") as handle:
    rows = list(csv.DictReader(handle, dialect="excel-tab"))
row = rows[0]
patch = {
    "path": row["path"],
    "decision": "stage approved release source/control changes",
    "decision_owner": "source-hygiene-tsv-test",
    "decision_timestamp": "2026-06-15 00:00:00 +0800",
    "decision_note": "tsv overlay test",
}
with open(target, "w", encoding="utf-8", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(patch), dialect="excel-tab", lineterminator="\n")
    writer.writeheader()
    writer.writerow(patch)
PY

"$fake_repo/bin/source-hygiene-decision-tsv.sh" --overlay "$tmp_root/original-export.tsv" --patch "$patch_tsv" --output "$overlaid_tsv" > "$tmp_root/overlay-stdout.log"

python3 - "$tmp_root/original-export.tsv" "$overlaid_tsv" <<'PY'
import csv
import sys

original_path, overlaid_path = sys.argv[1:3]
with open(original_path, encoding="utf-8", newline="") as handle:
    original = list(csv.DictReader(handle, dialect="excel-tab"))
with open(overlaid_path, encoding="utf-8", newline="") as handle:
    overlaid = list(csv.DictReader(handle, dialect="excel-tab"))
if original[0]["decision"]:
    raise SystemExit(f"overlay modified original TSV copy: {original!r}")
if overlaid[0]["decision"] != "stage approved release source/control changes":
    raise SystemExit(f"overlay did not write decision: {overlaid!r}")
PY

"$fake_repo/bin/source-hygiene-decision-tsv.sh" --merge "$manifest" --tsv "$overlaid_tsv" --output "$merged" > "$tmp_root/overlay-merge-stdout.log"

"$fake_repo/bin/source-hygiene-report.sh" --validate-decisions "$merged" "$validation" > "$tmp_root/overlay-validation-stdout.log"
if ! grep -F -q -- '- Status: **pass**' "$validation"; then
    printf 'Expected overlaid TSV decision manifest to validate\n' >&2
    exit 1
fi

"$fake_repo/bin/source-hygiene-decision-tsv.sh" --merge "$manifest" --tsv "$tsv" --output "$merged" > "$tmp_root/merge-stdout.log"

python3 - "$merged" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

entry = payload["buckets"][0]["entries"][0]
if entry["decision"] != "stage approved release source/control changes":
    raise SystemExit(f"decision not merged: {entry!r}")
if entry["decision_owner"] != "source-hygiene-tsv-test":
    raise SystemExit(f"owner not merged: {entry!r}")
merge = payload["operator_decision_instructions"].get("last_tsv_merge", {})
if merge.get("executes_changes") is not False or merge.get("merged_decision_rows") != 1:
    raise SystemExit(f"unexpected merge metadata: {merge!r}")
PY

"$fake_repo/bin/source-hygiene-report.sh" --validate-decisions "$merged" "$validation" > "$tmp_root/validation-stdout.log"
if ! grep -F -q -- '- Status: **pass**' "$validation"; then
    printf 'Expected TSV-merged decision manifest to validate\n' >&2
    exit 1
fi

duplicate_tsv="$fake_repo/tmp/source-hygiene-decisions-duplicate.tsv"
cp "$tsv" "$duplicate_tsv"
tail -n 1 "$tsv" >> "$duplicate_tsv"
if "$fake_repo/bin/source-hygiene-decision-tsv.sh" --merge "$manifest" --tsv "$duplicate_tsv" --output "$merged" > "$tmp_root/duplicate-stdout.log" 2> "$tmp_root/duplicate-stderr.log"; then
    printf 'Expected duplicate TSV path rows to fail merge\n' >&2
    exit 1
fi
if ! grep -F -q -- 'TSV has duplicate path rows' "$tmp_root/duplicate-stderr.log"; then
    printf 'Expected duplicate TSV merge failure to identify duplicate path rows\n' >&2
    exit 1
fi

printf 'source-hygiene decision TSV test passed\n'
