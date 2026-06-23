#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_under_test="$repo_root/bin/source-hygiene-report.sh"

tmp_root="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp_root"
}
trap cleanup EXIT

fake_repo="$tmp_root/repo"
mkdir -p "$fake_repo/bin" "$fake_repo/docs/product" "$fake_repo/workdir/generated" "$fake_repo/instdir/app" "$fake_repo/.superpowers/session" "$fake_repo/.git.bak-20260510-pre-c/logs"
cp "$script_under_test" "$fake_repo/bin/source-hygiene-report.sh"
chmod +x "$fake_repo/bin/source-hygiene-report.sh"

git -C "$fake_repo" init -q
git -C "$fake_repo" config user.email source-hygiene-test@example.invalid
git -C "$fake_repo" config user.name "Source Hygiene Test"
printf 'tracked\n' > "$fake_repo/2.md"
git -C "$fake_repo" add 2.md bin/source-hygiene-report.sh
git -C "$fake_repo" commit -q -m 'seed tracked files'
printf 'modified\n' >> "$fake_repo/2.md"

cat > "$fake_repo/docs/product/source-hygiene-release-packet.md" <<'DOC'
# Source Hygiene Release Packet
DOC
cat > "$fake_repo/bin/v2-beta-gates.sh" <<'BIN'
#!/usr/bin/env bash
exit 0
BIN
for index in $(seq -w 1 85); do
    printf 'operator evidence %s\n' "$index" > "$fake_repo/docs/product/operator-$index.md"
done
printf 'generated\n' > "$fake_repo/workdir/generated/output.txt"
printf 'bundle\n' > "$fake_repo/instdir/app/output.txt"
printf 'session\n' > "$fake_repo/.superpowers/session/server.pid"
printf 'local\n' > "$fake_repo/local-note.txt"
printf 'backup\n' > "$fake_repo/.git.bak-20260510-pre-c/HEAD"
printf 'odd\n' > "$fake_repo/:-"

report_path="$fake_repo/tmp/source-hygiene-report.md"
"$fake_repo/bin/source-hygiene-report.sh" "$report_path" > "$tmp_root/stdout.log"

if ! grep -q '| Source review/stage | 87 |' "$report_path"; then
    printf 'Expected source review/stage to include modified tracked and untracked operator-controlled source files\n' >&2
    exit 1
fi

for expected in \
    '` M` `2.md`' \
    '`??` `bin/v2-beta-gates.sh`' \
    '`??` `docs/product/source-hygiene-release-packet.md`'
do
    if ! awk '/^### Source review\/stage$/{in_section=1; next} /^### /{in_section=0} in_section{print}' "$report_path" | grep -q -- "$expected"; then
        printf 'Expected Source review/stage section to include %s\n' "$expected" >&2
        exit 1
    fi
    if awk '/^### Unresolved human-decision items$/{in_section=1; next} /^## / || /^### /{in_section=0} in_section{print}' "$report_path" | grep -q -- "$expected"; then
        printf 'Did not expect Unresolved human-decision items section to include %s\n' "$expected" >&2
        exit 1
    fi
done

if ! awk '/^### Unresolved human-decision items$/{in_section=1; next} /^## / || /^### /{in_section=0} in_section{print}' "$report_path" | grep -q -- '`??` `local-note.txt`'; then
    printf 'Expected unrelated untracked source file to remain an unresolved human-decision item\n' >&2
    exit 1
fi

if ! awk '/^### Generated\/local clean-or-ignore$/{in_section=1; next} /^### /{in_section=0} in_section{print}' "$report_path" | grep -q -- '`??` `.superpowers/session/server.pid`'; then
    printf 'Expected .superpowers session files to be classified as generated/local clean-or-ignore entries\n' >&2
    exit 1
fi

if ! awk '/^### Repo backup human-decision items$/{in_section=1; next} /^### /{in_section=0} in_section{print}' "$report_path" | grep -q -- '`??` `.git.bak-20260510-pre-c/HEAD`'; then
    printf 'Expected .git.bak-* files to be classified as repo backup human-decision items\n' >&2
    exit 1
fi

if ! awk '/^### Odd\/local human-decision items$/{in_section=1; next} /^### /{in_section=0} in_section{print}' "$report_path" | grep -q -- '`??` `:-`'; then
    printf 'Expected odd/local section to include `??` `:-`\n' >&2
    exit 1
fi

strict_report_path="$fake_repo/tmp/source-hygiene-report-strict.md"
if "$fake_repo/bin/source-hygiene-report.sh" --strict "$strict_report_path" > "$tmp_root/strict-stdout.log" 2> "$tmp_root/strict-stderr.log"; then
    printf 'Expected strict source hygiene to fail while any working-tree entry remains\n' >&2
    exit 1
fi

if ! grep -F -q -- '- Status: **fail**' "$strict_report_path"; then
    printf 'Expected strict report status to be fail\n' >&2
    exit 1
fi

git -C "$fake_repo" add .
git -C "$fake_repo" commit -q -m 'clear hygiene entries'
clean_report_path="$fake_repo/tmp/source-hygiene-report-clean.md"
"$fake_repo/bin/source-hygiene-report.sh" --strict "$clean_report_path" > "$tmp_root/clean-stdout.log"

if ! grep -F -q -- '- Status: **pass**' "$clean_report_path"; then
    printf 'Expected strict source hygiene to pass with a clean working tree\n' >&2
    exit 1
fi

printf 'summary\n' > "$fake_repo/local-summary-note.txt"
decision_summary_path="$fake_repo/tmp/source-hygiene-decision-summary.md"
"$fake_repo/bin/source-hygiene-report.sh" --decision-summary "$decision_summary_path" > "$tmp_root/decision-summary-stdout.log"

for expected in \
    '# Source Hygiene Decision Summary' \
    'Strict status: fail until every working-tree entry is intentionally resolved' \
    '## Operator Decisions' \
    '### Unresolved human-decision items' \
    '`??` `local-summary-note.txt`'
do
    if ! grep -F -q -- "$expected" "$decision_summary_path"; then
        printf 'Expected decision summary to include %s\n' "$expected" >&2
        exit 1
    fi
done

decision_json_path="$fake_repo/tmp/source-hygiene-decision-summary.json"
"$fake_repo/bin/source-hygiene-report.sh" --decision-json "$decision_json_path" > "$tmp_root/decision-json-stdout.log"

decision_packets_dir="$fake_repo/tmp/source-hygiene-decision-packets"
"$fake_repo/bin/source-hygiene-report.sh" --decision-packets "$decision_packets_dir" > "$tmp_root/decision-packets-stdout.log"

for expected in \
    '# Source Hygiene Decision Packets' \
    'Total entries requiring decisions: 1' \
    '01-source_review_stage.md' \
    '04-unresolved_human_decision.md' \
    '05-generated_local_clean_or_ignore.md'
do
    if ! grep -F -q -- "$expected" "$decision_packets_dir/index.md"; then
        printf 'Expected decision packet index to include %s\n' "$expected" >&2
        exit 1
    fi
done

if ! grep -F -q -- 'local-summary-note.txt' "$decision_packets_dir/04-unresolved_human_decision.md" ||
    ! grep -F -q -- 'stage as intentional source/control work' "$decision_packets_dir/04-unresolved_human_decision.md" ||
    ! grep -F -q -- 'Review one packet at a time.' "$decision_packets_dir/index.md"; then
    printf 'Expected per-bucket decision packets to include paths, allowed decisions, and workflow guidance\n' >&2
    exit 1
fi

python3 - "$decision_json_path" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

if payload["schema_version"] != 1:
    raise SystemExit("unexpected schema version")
if payload["strict_status"] != "fail":
    raise SystemExit(f"unexpected strict status: {payload['strict_status']!r}")
if not payload["operator_decision_required"]:
    raise SystemExit("expected operator decision requirement")

counts = payload["counts"]
if counts["unresolved_human_decision"] != 1:
    raise SystemExit(f"unexpected unresolved count: {counts['unresolved_human_decision']!r}")
if counts["repo_backup_human_decision"] != 0:
    raise SystemExit(f"repo backups should be committed in this phase: {counts['repo_backup_human_decision']!r}")

buckets = {bucket["key"]: bucket for bucket in payload["buckets"]}
required = {
    "source_review_stage",
    "repo_backup_human_decision",
    "odd_local_human_decision",
    "unresolved_human_decision",
    "generated_local_clean_or_ignore",
    "config_autoconf_artifacts",
    "install_test_release_artifacts",
}
if set(buckets) != required:
    raise SystemExit(f"unexpected buckets: {sorted(buckets)}")

unresolved_paths = {entry["path"] for entry in buckets["unresolved_human_decision"]["entries"]}
if "local-summary-note.txt" not in unresolved_paths:
    raise SystemExit(f"missing unresolved note path: {unresolved_paths!r}")
if not buckets["unresolved_human_decision"]["allowed_decisions"]:
    raise SystemExit("expected allowed decisions")
for bucket in buckets.values():
    for entry in bucket["entries"]:
        for field in ("decision", "decision_owner", "decision_timestamp", "decision_note"):
            if field not in entry:
                raise SystemExit(f"expected operator-fillable field {field!r} in {entry!r}")
        if entry["decision"] != "":
            raise SystemExit(f"expected decision template to start empty: {entry!r}")
instructions = payload.get("operator_decision_instructions", {})
if not instructions.get("path_level_required"):
    raise SystemExit("expected path-level operator decision instructions")
if "--validate-decisions" not in instructions.get("validation_command", ""):
    raise SystemExit("expected validation command in operator instructions")
if not any("do not delete" in rule for rule in payload["stop_rules"]):
    raise SystemExit("expected destructive-operation stop rule")
PY

decision_validation_path="$fake_repo/tmp/source-hygiene-decision-validation.md"
if "$fake_repo/bin/source-hygiene-report.sh" --validate-decisions "$decision_json_path" "$decision_validation_path" > "$tmp_root/empty-validation-stdout.log" 2> "$tmp_root/empty-validation-stderr.log"; then
    printf 'Expected empty operator decision template to fail validation\n' >&2
    exit 1
fi

for expected in \
    '- Status: **fail**' \
    '- Missing path decisions: 1' \
    'local-summary-note.txt'
do
    if ! grep -F -q -- "$expected" "$decision_validation_path"; then
        printf 'Expected empty decision validation report to include %s\n' "$expected" >&2
        exit 1
    fi
done

decision_progress_path="$fake_repo/tmp/source-hygiene-decision-progress.md"
decision_progress_json_path="$fake_repo/tmp/source-hygiene-decision-progress.json"
if "$fake_repo/bin/source-hygiene-report.sh" --decision-progress "$decision_json_path" --json-output "$decision_progress_json_path" "$decision_progress_path" > "$tmp_root/empty-progress-stdout.log" 2> "$tmp_root/empty-progress-stderr.log"; then
    printf 'Expected empty operator decision template to produce blocked decision progress\n' >&2
    exit 1
fi

for expected in \
    '# Source Hygiene Decision Progress' \
    '- Status: **blocked**' \
    '- Progress percent: 0.00' \
    '| Unresolved human-decision items | 1 | 0 | 1 | 0 | 0 |' \
    '- Executes changes: no'
do
    if ! grep -F -q -- "$expected" "$decision_progress_path"; then
        printf 'Expected blocked decision progress to include %s\n' "$expected" >&2
        exit 1
    fi
done

python3 - "$decision_progress_json_path" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

if payload["schema_version"] != 1:
    raise SystemExit("unexpected decision-progress schema version")
if payload["status"] != "blocked":
    raise SystemExit(f"expected blocked progress: {payload['status']!r}")
if payload["executes_changes"] is not False:
    raise SystemExit("expected progress report to be non-executing")
if payload["progress_percent"] != 0:
    raise SystemExit(f"unexpected empty progress percent: {payload['progress_percent']!r}")
counts = payload["counts"]
if counts["missing_path_decisions"] != 1 or counts["valid_path_decisions"] != 0:
    raise SystemExit(f"unexpected blocked progress counts: {counts!r}")
bucket = next(item for item in payload["bucket_progress"] if item["key"] == "unresolved_human_decision")
if bucket["current"] != 1 or bucket["missing"] != 1 or bucket["valid"] != 0:
    raise SystemExit(f"unexpected blocked bucket progress: {bucket!r}")
PY

decision_plan_path="$fake_repo/tmp/source-hygiene-decision-plan.md"
decision_plan_json_path="$fake_repo/tmp/source-hygiene-decision-plan.json"
if "$fake_repo/bin/source-hygiene-report.sh" --decision-plan "$decision_json_path" --json-output "$decision_plan_json_path" "$decision_plan_path" > "$tmp_root/empty-plan-stdout.log" 2> "$tmp_root/empty-plan-stderr.log"; then
    printf 'Expected empty operator decision template to produce a blocked decision plan\n' >&2
    exit 1
fi

for expected in \
    '# Source Hygiene Decision Plan' \
    '- Status: **blocked**' \
    '- Missing path decisions: 1' \
    '- Executes changes: no' \
    'Fill missing decisions in tmp/source-hygiene-decision-summary.json'
do
    if ! grep -F -q -- "$expected" "$decision_plan_path"; then
        printf 'Expected blocked decision plan to include %s\n' "$expected" >&2
        exit 1
    fi
done

python3 - "$decision_plan_json_path" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

if payload["schema_version"] != 1:
    raise SystemExit("unexpected decision-plan schema version")
if payload["status"] != "blocked":
    raise SystemExit(f"expected blocked plan: {payload['status']!r}")
if payload["executes_changes"] is not False or payload["dry_run_only"] is not True:
    raise SystemExit("expected blocked plan to be dry-run only and non-executing")
counts = payload["counts"]
if counts["missing_path_decisions"] != 1 or counts["valid_path_decisions"] != 0:
    raise SystemExit(f"unexpected blocked plan counts: {counts!r}")
if payload["decision_groups"]:
    raise SystemExit(f"blocked empty plan should not have decision groups: {payload['decision_groups']!r}")
PY

filled_decision_json_path="$fake_repo/tmp/source-hygiene-decision-filled.json"
python3 - "$decision_json_path" "$filled_decision_json_path" <<'PY'
import json
import sys

source, target = sys.argv[1:3]
with open(source, encoding="utf-8") as handle:
    payload = json.load(handle)

for bucket in payload["buckets"]:
    decision = bucket["allowed_decisions"][0]
    for entry in bucket["entries"]:
        entry["decision"] = decision
        entry["decision_owner"] = "source-hygiene-test"
        entry["decision_timestamp"] = "2026-06-15 00:00:00 +0800"
        entry["decision_note"] = "unit-test operator decision"

with open(target, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY

"$fake_repo/bin/source-hygiene-report.sh" --validate-decisions "$filled_decision_json_path" "$decision_validation_path" > "$tmp_root/filled-validation-stdout.log"

for expected in \
    '- Status: **pass**' \
    '- Valid path decisions: 1' \
    '- Missing path decisions: 0' \
    '- Invalid path decisions: 0'
do
    if ! grep -F -q -- "$expected" "$decision_validation_path"; then
        printf 'Expected filled decision validation report to include %s\n' "$expected" >&2
        exit 1
    fi
done

"$fake_repo/bin/source-hygiene-report.sh" --decision-progress "$filled_decision_json_path" --json-output "$decision_progress_json_path" "$decision_progress_path" > "$tmp_root/filled-progress-stdout.log"

for expected in \
    '- Status: **ready**' \
    '- Progress percent: 100.00' \
    '| Unresolved human-decision items | 1 | 1 | 0 | 0 | 0 |' \
    '| stage as intentional source/control work | 1 |'
do
    if ! grep -F -q -- "$expected" "$decision_progress_path"; then
        printf 'Expected ready decision progress to include %s\n' "$expected" >&2
        exit 1
    fi
done

python3 - "$decision_progress_json_path" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

if payload["status"] != "ready":
    raise SystemExit(f"expected ready progress: {payload['status']!r}")
if payload["progress_percent"] != 100:
    raise SystemExit(f"unexpected ready progress percent: {payload['progress_percent']!r}")
counts = payload["counts"]
if counts["valid_path_decisions"] != 1 or counts["missing_path_decisions"] != 0:
    raise SystemExit(f"unexpected ready progress counts: {counts!r}")
if payload["valid_decisions_by_choice"] != {"stage as intentional source/control work": 1}:
    raise SystemExit(f"unexpected decision choice summary: {payload['valid_decisions_by_choice']!r}")
PY

"$fake_repo/bin/source-hygiene-report.sh" --decision-plan "$filled_decision_json_path" --json-output "$decision_plan_json_path" "$decision_plan_path" > "$tmp_root/filled-plan-stdout.log"

for expected in \
    '- Status: **ready**' \
    '- Dry-run only: yes' \
    '- Valid path decisions: 1' \
    '### stage as intentional source/control work' \
    'local-summary-note.txt'
do
    if ! grep -F -q -- "$expected" "$decision_plan_path"; then
        printf 'Expected ready decision plan to include %s\n' "$expected" >&2
        exit 1
    fi
done

python3 - "$decision_plan_json_path" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

if payload["status"] != "ready":
    raise SystemExit(f"expected ready plan: {payload['status']!r}")
if payload["executes_changes"] is not False or payload["dry_run_only"] is not True:
    raise SystemExit("expected ready plan to remain dry-run only and non-executing")
counts = payload["counts"]
if counts["valid_path_decisions"] != 1 or counts["missing_path_decisions"] != 0:
    raise SystemExit(f"unexpected ready plan counts: {counts!r}")
groups = payload["decision_groups"]
if len(groups) != 1:
    raise SystemExit(f"expected one decision group: {groups!r}")
if groups[0]["decision"] != "stage as intentional source/control work":
    raise SystemExit(f"unexpected decision group: {groups!r}")
paths = [entry["path"] for entry in groups[0]["entries"]]
if paths != ["local-summary-note.txt"]:
    raise SystemExit(f"unexpected ready plan paths: {paths!r}")
PY

invalid_decision_json_path="$fake_repo/tmp/source-hygiene-decision-invalid.json"
python3 - "$filled_decision_json_path" "$invalid_decision_json_path" <<'PY'
import json
import sys

source, target = sys.argv[1:3]
with open(source, encoding="utf-8") as handle:
    payload = json.load(handle)

for bucket in payload["buckets"]:
    if bucket["entries"]:
        bucket["entries"][0]["decision"] = "not an allowed source hygiene decision"
        break
else:
    raise SystemExit("expected at least one decision entry")

with open(target, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY

if "$fake_repo/bin/source-hygiene-report.sh" --validate-decisions "$invalid_decision_json_path" "$decision_validation_path" > "$tmp_root/invalid-validation-stdout.log" 2> "$tmp_root/invalid-validation-stderr.log"; then
    printf 'Expected invalid operator decision to fail validation\n' >&2
    exit 1
fi

if ! grep -F -q -- '- Invalid path decisions: 1' "$decision_validation_path" ||
    ! grep -F -q -- 'not an allowed source hygiene decision' "$decision_validation_path"; then
    printf 'Expected invalid decision validation report to identify the illegal decision\n' >&2
    exit 1
fi

stale_decision_json_path="$fake_repo/tmp/source-hygiene-decision-stale.json"
python3 - "$filled_decision_json_path" "$stale_decision_json_path" <<'PY'
import json
import sys

source, target = sys.argv[1:3]
with open(source, encoding="utf-8") as handle:
    payload = json.load(handle)

payload.setdefault("operator_decisions", []).append({
    "path": "removed-local-note.txt",
    "decision": "stage as intentional source/control work",
    "decision_owner": "source-hygiene-test",
    "decision_timestamp": "2026-06-15 00:00:00 +0800",
    "decision_note": "stale-path test",
})

with open(target, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY

if "$fake_repo/bin/source-hygiene-report.sh" --validate-decisions "$stale_decision_json_path" "$decision_validation_path" > "$tmp_root/stale-validation-stdout.log" 2> "$tmp_root/stale-validation-stderr.log"; then
    printf 'Expected stale operator decision to fail validation\n' >&2
    exit 1
fi

if ! grep -F -q -- '- Stale path decisions: 1' "$decision_validation_path" ||
    ! grep -F -q -- 'removed-local-note.txt is not present in current git status' "$decision_validation_path"; then
    printf 'Expected stale decision validation report to identify the stale path\n' >&2
    exit 1
fi

printf 'source-hygiene operator-controlled untracked classification test passed\n'
