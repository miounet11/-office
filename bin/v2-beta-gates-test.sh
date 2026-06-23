#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_under_test="$repo_root/bin/v2-beta-gates.sh"

tmp_root="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp_root"
}
trap cleanup EXIT

fake_repo="$tmp_root/repo"
mkdir -p "$fake_repo/bin" "$fake_repo/docs/accessibility" "$fake_repo/docs/compatibility" "$fake_repo/docs/product" "$fake_repo/tmp"
cp "$script_under_test" "$fake_repo/bin/v2-beta-gates.sh"
cp "$repo_root/bin/workbench-a11y-live-validate.sh" "$fake_repo/bin/workbench-a11y-live-validate.sh"
chmod +x "$fake_repo/bin/v2-beta-gates.sh"
chmod +x "$fake_repo/bin/workbench-a11y-live-validate.sh"

touch "$fake_repo/docs/compatibility/smoke-manifest.tsv"
touch "$fake_repo/docs/product/beta-blocker-remediation-protocol.md"
cat > "$fake_repo/docs/accessibility/workbench-accessibility-evidence-m2-06.md" <<'EOF'
# accessibility evidence
EOF

write_stub() {
    local path="$1"
    local body="$2"
    cat > "$path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
$body
EOF
    chmod +x "$path"
}

write_stub "$fake_repo/bin/compatibility-manifest-audit.sh" 'exit 0'
write_stub "$fake_repo/bin/validator-readiness.sh" 'printf "validator strict failed\n" >&2; exit 1'
write_stub "$fake_repo/bin/compatibility-roundtrip.sh" 'printf "roundtrip strict failed\n" >&2; exit 1'
write_stub "$fake_repo/bin/workbench-accessibility-check.sh" 'exit 0'
write_stub "$fake_repo/bin/gui-smoke-timing.sh" 'exit 0'
write_stub "$fake_repo/bin/compatibility-layout-evidence.sh" 'exit 0'
write_stub "$fake_repo/bin/source-hygiene-report.sh" 'printf "source hygiene failed\n" >&2; exit 1'
write_stub "$fake_repo/bin/plugin-manifest-validator.sh" 'exit 0'

run_name="unit-remediation-order"
if "$fake_repo/bin/v2-beta-gates.sh" "$run_name" > "$tmp_root/stdout.log" 2> "$tmp_root/stderr.log"; then
    printf 'Expected beta gates to fail when strict validator, roundtrip, source hygiene, and live accessibility blockers fail\n' >&2
    exit 1
fi

report="$fake_repo/tmp/v2-beta-gates/$run_name.md"
json_report="$fake_repo/tmp/v2-beta-gates/$run_name.json"

for expected in \
    'Status: **failed**' \
    'validator-readiness-strict' \
    'compatibility-roundtrip' \
    'source-hygiene-strict' \
    'workbench-live-accessibility' \
    'tmp/source-hygiene-decision-summary.json' \
    'tmp/source-hygiene-decisions.tsv' \
    'tmp/source-hygiene-decisions.current-slice-filled.tsv' \
    'tmp/source-hygiene-current-dev-paths.txt' \
    'tmp/source-hygiene-decision-suggestions.json' \
    'tmp/source-hygiene-decision-suggestions.md' \
    'tmp/source-hygiene-decision-suggestions.tsv' \
    'tmp/source-hygiene-decision-current-slice-accepted.json' \
    'tmp/source-hygiene-decision-current-slice-accepted.md' \
    'tmp/source-hygiene-decision-current-slice-accepted.tsv' \
    'tmp/source-hygiene-decision-current-slice-merged.json' \
    'tmp/source-hygiene-decision-current-slice-merged-progress.json' \
    'tmp/source-hygiene-decision-current-slice-merged-progress.md' \
    'tmp/source-hygiene-decision-current-slice-progress.json' \
    'tmp/source-hygiene-decision-current-slice-progress.md' \
    'tmp/source-hygiene-decision-progress.md' \
    'tmp/source-hygiene-decision-progress.json' \
    'tmp/source-hygiene-decision-validation.md' \
    'tmp/source-hygiene-decision-plan.md' \
    'tmp/source-hygiene-decision-plan.json' \
    'tmp/source-hygiene-apply-plan-dry-run.md' \
    'tmp/source-hygiene-apply-plan-dry-run.json' \
    'tmp/source-hygiene-decision-packets/index.md'
do
    if ! grep -F -q -- "$expected" "$report"; then
        printf 'Expected beta gate report to include %s\n' "$expected" >&2
        exit 1
    fi
done

if ! grep -F -q -- 'tmp/product-completion/live-accessibility-validation.json' "$report"; then
    printf 'Expected beta gate report to include live accessibility validation JSON evidence\n' >&2
    exit 1
fi
if ! grep -F -q -- 'tmp/product-completion/live-accessibility-checklist.md' "$report" ||
    ! grep -F -q -- 'checklist-only evidence are insufficient' "$report"; then
    printf 'Expected beta gate report to include live accessibility checklist guidance and proof stop rule\n' >&2
    exit 1
fi

if grep -F -q -- 'GUI survival diagnostics' "$report"; then
    printf 'Did not expect GUI remediation text when gui-smoke-timing-startcenter passed\n' >&2
    exit 1
fi

python3 - "$json_report" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

failed = [item["key"] for item in payload["failed_blockers"]]
expected = [
    "validator-readiness-strict",
    "compatibility-roundtrip",
    "source-hygiene-strict",
    "workbench-live-accessibility",
]
if failed != expected:
    raise SystemExit(f"unexpected failed blockers: {failed!r}")

source_hygiene = next(item for item in payload["failed_blockers"] if item["key"] == "source-hygiene-strict")
action = source_hygiene["action"]
for expected_path in (
    "tmp/source-hygiene-decision-summary.json",
    "tmp/source-hygiene-decisions.tsv",
    "tmp/source-hygiene-decisions.current-slice-filled.tsv",
    "tmp/source-hygiene-current-dev-paths.txt",
    "tmp/source-hygiene-decision-suggestions.json",
    "tmp/source-hygiene-decision-suggestions.md",
    "tmp/source-hygiene-decision-suggestions.tsv",
    "tmp/source-hygiene-decision-current-slice-accepted.json",
    "tmp/source-hygiene-decision-current-slice-accepted.md",
    "tmp/source-hygiene-decision-current-slice-accepted.tsv",
    "tmp/source-hygiene-decision-current-slice-merged.json",
    "tmp/source-hygiene-decision-current-slice-merged-progress.json",
    "tmp/source-hygiene-decision-current-slice-merged-progress.md",
    "tmp/source-hygiene-decision-current-slice-progress.json",
    "tmp/source-hygiene-decision-current-slice-progress.md",
    "tmp/source-hygiene-decision-progress.md",
    "tmp/source-hygiene-decision-progress.json",
    "tmp/source-hygiene-decision-validation.md",
    "tmp/source-hygiene-decision-plan.md",
    "tmp/source-hygiene-decision-plan.json",
    "tmp/source-hygiene-apply-plan-dry-run.md",
    "tmp/source-hygiene-apply-plan-dry-run.json",
    "tmp/source-hygiene-decision-packets/index.md",
):
    if expected_path not in action:
        raise SystemExit(f"missing source hygiene action path {expected_path!r}: {action!r}")
if "source-hygiene-decision-tsv.sh --merge" not in action:
    raise SystemExit(f"missing source hygiene TSV merge guidance: {action!r}")
if "source-hygiene-decision-suggestions.json" not in action:
    raise SystemExit(f"missing current-slice suggestion guidance: {action!r}")
PY

printf 'v2-beta-gates remediation-order tests passed\n'

pass_repo="$tmp_root/pass-repo"
mkdir -p "$pass_repo/bin" "$pass_repo/docs/accessibility" "$pass_repo/docs/compatibility" "$pass_repo/docs/product" "$pass_repo/tmp/product-completion"
cp "$script_under_test" "$pass_repo/bin/v2-beta-gates.sh"
cp "$repo_root/bin/workbench-a11y-live-validate.sh" "$pass_repo/bin/workbench-a11y-live-validate.sh"
chmod +x "$pass_repo/bin/v2-beta-gates.sh"
chmod +x "$pass_repo/bin/workbench-a11y-live-validate.sh"

touch "$pass_repo/docs/compatibility/smoke-manifest.tsv"
touch "$pass_repo/docs/product/beta-blocker-remediation-protocol.md"
touch "$pass_repo/docs/accessibility/workbench-accessibility-evidence-m2-06.md"

write_stub "$pass_repo/bin/compatibility-manifest-audit.sh" 'exit 0'
write_stub "$pass_repo/bin/validator-readiness.sh" 'exit 0'
write_stub "$pass_repo/bin/compatibility-roundtrip.sh" 'if [[ -z "${KDOFFICE_APP_BUNDLE:-}" ]]; then printf "missing KDOFFICE_APP_BUNDLE\n" >&2; exit 1; fi; if [[ "${KDOFFICE_SOFFICE_BIN:-}" != "$KDOFFICE_APP_BUNDLE/Contents/MacOS/soffice" ]]; then printf "missing KDOFFICE_SOFFICE_BIN: %s\n" "${KDOFFICE_SOFFICE_BIN:-}" >&2; exit 1; fi'
write_stub "$pass_repo/bin/workbench-accessibility-check.sh" 'exit 0'
write_stub "$pass_repo/bin/gui-smoke-timing.sh" 'if [[ -z "${KDOFFICE_APP_BUNDLE:-}" ]]; then printf "missing GUI KDOFFICE_APP_BUNDLE\n" >&2; exit 1; fi; saw_app=0; while [[ $# -gt 0 ]]; do case "$1" in --app) [[ "$2" == "$KDOFFICE_APP_BUNDLE" ]] && saw_app=1; shift 2 ;; *) shift ;; esac; done; [[ "$saw_app" == 1 ]]'
write_stub "$pass_repo/bin/compatibility-layout-evidence.sh" 'exit 0'
write_stub "$pass_repo/bin/source-hygiene-report.sh" 'exit 0'
write_stub "$pass_repo/bin/plugin-manifest-validator.sh" 'exit 0'
mkdir -p "$pass_repo/test-install/可圈office.app/Contents/MacOS"
touch "$pass_repo/test-install/可圈office.app/Contents/MacOS/soffice"

cat > "$pass_repo/tmp/product-completion/live-accessibility-proof.md" <<'EOF'
# Live Accessibility Proof

## Verdict

- Status: passed
- Accessibility claim allowed: yes
- App under test: PASS_APP_PLACEHOLDER
- App executable: PASS_APP_PLACEHOLDER/Contents/MacOS/soffice
- Total pass: 24 / fail: 0 / skip: 0

## Matrix

| Surface | Keyboard | VoiceOver | High contrast | Resize | Status |
| --- | --- | --- | --- | --- | --- |
| Start Center | pass | pass | pass | pass | pass |
| Writer blank document | pass | pass | pass | pass | pass |
| Calc filters | pass | pass | pass | pass | pass |
| Impress new presentation | pass | pass | pass | pass | pass |
| Draw blank drawing | pass | pass | pass | pass | pass |
| Template/workbench fallback state | pass | pass | pass | pass | pass |

## Failure / Skip Notes

- None.
EOF
sed -i.bak "s|PASS_APP_PLACEHOLDER|$pass_repo/test-install/可圈office.app|g" "$pass_repo/tmp/product-completion/live-accessibility-proof.md"
rm -f "$pass_repo/tmp/product-completion/live-accessibility-proof.md.bak"

pass_run_name="unit-live-accessibility-proof"
KDOFFICE_APP_BUNDLE="$pass_repo/test-install/可圈office.app" "$pass_repo/bin/v2-beta-gates.sh" "$pass_run_name" > "$tmp_root/pass-stdout.log" 2> "$tmp_root/pass-stderr.log"

pass_report="$pass_repo/tmp/v2-beta-gates/$pass_run_name.md"
pass_json_report="$pass_repo/tmp/v2-beta-gates/$pass_run_name.json"

if ! grep -F -q -- '## workbench-live-accessibility' "$pass_report" ||
    ! grep -F -q -- '- status: **passed**' "$pass_report"; then
    printf 'Expected valid live accessibility proof to pass the live accessibility beta gate\n' >&2
    exit 1
fi

if ! grep -F -q -- 'tmp/product-completion/live-accessibility-validation.json' "$pass_report"; then
    printf 'Expected passed beta gate report to include live accessibility validation JSON evidence\n' >&2
    exit 1
fi

if ! grep -F -q -- "KDOFFICE_SOFFICE_BIN=" "$pass_report" ||
    ! grep -F -q -- "test-install/可圈office.app/Contents/MacOS/soffice" "$pass_report" ||
    ! grep -F -q -- "--app" "$pass_report" ||
    ! grep -F -q -- "test-install/可圈office.app" "$pass_report"; then
    printf 'Expected beta gate report to show explicit test-install app/soffice routing\n' >&2
    exit 1
fi

python3 - "$pass_json_report" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

if payload["failed_blockers"]:
    raise SystemExit(f"expected no failed blockers: {payload['failed_blockers']!r}")
if payload["overall_status"] != "passed":
    raise SystemExit(f"expected passed overall status: {payload['overall_status']!r}")
live_step = next(step for step in payload["steps"] if step["key"] == "workbench-live-accessibility")
if "--json-output" not in live_step["command"]:
    raise SystemExit(f"expected live accessibility command to write JSON validation: {live_step['command']!r}")
PY

printf 'v2-beta-gates live-accessibility-proof tests passed\n'
