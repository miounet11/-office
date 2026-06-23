#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
script_under_test="$repo_root/bin/workbench-a11y-live-validate.sh"

tmp_root="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp_root"
}
trap cleanup EXIT

valid_proof="$tmp_root/live-accessibility-proof-valid.md"
invalid_proof="$tmp_root/live-accessibility-proof-invalid.md"
report="$tmp_root/live-accessibility-validation.md"
json_report="$tmp_root/live-accessibility-validation.json"
expected_app="$tmp_root/test-install/可圈office.app"
mkdir -p "$expected_app/Contents/MacOS"
touch "$expected_app/Contents/MacOS/soffice"

cat > "$valid_proof" <<'EOF'
# Live Accessibility Proof

## Verdict

- Status: passed
- Accessibility claim allowed: yes
- App under test: APP_PLACEHOLDER
- App executable: APP_PLACEHOLDER/Contents/MacOS/soffice
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
sed -i.bak "s|APP_PLACEHOLDER|$expected_app|g" "$valid_proof"
rm -f "$valid_proof.bak"

"$script_under_test" --proof "$valid_proof" --output "$report" --json-output "$json_report" --expected-app "$expected_app" > "$tmp_root/valid-stdout.log"

for expected in \
    '- Status: **passed**' \
    '- Matrix rows: 6' \
    '- Matrix pass cells: 24' \
    '- none'
do
    if ! grep -F -q -- "$expected" "$report"; then
        printf 'Expected valid live proof report to include %s\n' "$expected" >&2
        exit 1
    fi
done

python3 - "$json_report" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

if payload["schema_version"] != 1:
    raise SystemExit("unexpected validation schema")
if payload["status"] != "passed":
    raise SystemExit(f"expected passed validation: {payload['status']!r}")
if payload["failure_category"] != "none" or payload["error_codes"]:
    raise SystemExit(f"expected no failure category or error codes: {payload!r}")
if payload["matrix_rows"] != 6 or payload["matrix_pass_cells"] != 24:
    raise SystemExit(f"unexpected matrix counts: {payload!r}")
if payload["summary"] != {"pass": 24, "fail": 0, "skip": 0}:
    raise SystemExit(f"unexpected summary: {payload['summary']!r}")
if not payload["expected_app"] or payload["app_under_test"] != payload["expected_app"]:
    raise SystemExit(f"expected app match in payload: {payload!r}")
if payload["errors"]:
    raise SystemExit(f"expected no errors: {payload['errors']!r}")
PY

wrong_app="$tmp_root/wrong.app"
mkdir -p "$wrong_app/Contents/MacOS"
if "$script_under_test" --proof "$valid_proof" --output "$report" --json-output "$json_report" --expected-app "$wrong_app" > "$tmp_root/wrong-app-stdout.log" 2> "$tmp_root/wrong-app-stderr.log"; then
    printf 'Expected proof with mismatched app bundle to fail validation\n' >&2
    exit 1
fi

if ! grep -F -q -- 'app under test does not match expected app' "$report" ||
    ! grep -F -q -- 'app executable does not match expected soffice' "$report"; then
    printf 'Expected app mismatch validation report to identify app and executable mismatch\n' >&2
    exit 1
fi

python3 - "$json_report" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

if payload["failure_category"] != "app-mismatch":
    raise SystemExit(f"expected app mismatch category: {payload!r}")
for code in ("app-under-test-mismatch", "app-executable-mismatch"):
    if code not in payload["error_codes"]:
        raise SystemExit(f"expected {code} in error codes: {payload['error_codes']!r}")
if "KDOFFICE_APP_BUNDLE" not in payload["next_action"]:
    raise SystemExit(f"expected app rerun action: {payload['next_action']!r}")
PY

cat > "$invalid_proof" <<'EOF'
# Live Accessibility Proof

## Verdict

- Status: passed
- Accessibility claim allowed: yes
- App under test: APP_PLACEHOLDER
- App executable: APP_PLACEHOLDER/Contents/MacOS/soffice
- Total pass: 24 / fail: 0 / skip: 0

## Matrix

| Surface | Keyboard | VoiceOver | High contrast | Resize | Status |
| --- | --- | --- | --- | --- | --- |
| Start Center | pass | pass | pass | pending live review | pending live review |
EOF
sed -i.bak "s|APP_PLACEHOLDER|$expected_app|g" "$invalid_proof"
rm -f "$invalid_proof.bak"

if "$script_under_test" --proof "$invalid_proof" --output "$report" --json-output "$json_report" > "$tmp_root/invalid-stdout.log" 2> "$tmp_root/invalid-stderr.log"; then
    printf 'Expected incomplete live proof matrix to fail validation\n' >&2
    exit 1
fi

for expected in \
    '- Status: **failed**' \
    'matrix row count is not 6' \
    'matrix pass cell count is not 24' \
    'pending live review'
do
    if ! grep -F -q -- "$expected" "$report"; then
        printf 'Expected invalid live proof report to include %s\n' "$expected" >&2
        exit 1
    fi
done

python3 - "$json_report" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

if payload["status"] != "failed":
    raise SystemExit(f"expected failed validation: {payload['status']!r}")
if payload["matrix_rows"] != 1:
    raise SystemExit(f"unexpected invalid matrix rows: {payload['matrix_rows']!r}")
if payload["failure_category"] != "matrix-non-pass":
    raise SystemExit(f"expected matrix non-pass category: {payload!r}")
if "matrix-non-pass-cells" not in payload["error_codes"]:
    raise SystemExit(f"expected non-pass error code: {payload['error_codes']!r}")
if not any("matrix row count is not 6" in error for error in payload["errors"]):
    raise SystemExit(f"expected row-count error: {payload['errors']!r}")
PY

missing_proof="$tmp_root/live-accessibility-proof-missing.md"
if "$script_under_test" --proof "$missing_proof" --output "$report" --json-output "$json_report" --expected-app "$expected_app" > "$tmp_root/missing-stdout.log" 2> "$tmp_root/missing-stderr.log"; then
    printf 'Expected missing live proof to fail validation\n' >&2
    exit 1
fi

python3 - "$json_report" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

if payload["proof_exists"] is not False:
    raise SystemExit(f"expected proof_exists false: {payload!r}")
if payload["failure_category"] != "proof-missing":
    raise SystemExit(f"expected proof missing category: {payload!r}")
if "proof-missing" not in payload["error_codes"]:
    raise SystemExit(f"expected proof-missing code: {payload['error_codes']!r}")
if "workbench-a11y-live.sh --resume" not in payload["next_action"]:
    raise SystemExit(f"expected resume command next action: {payload['next_action']!r}")
PY

printf 'workbench-a11y-live validation test passed\n'
