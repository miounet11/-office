#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
proof="$repo_root/tmp/product-completion/live-accessibility-proof.md"
output="$repo_root/tmp/product-completion/live-accessibility-validation.md"
json_output=""
expected_app=""

usage() {
    cat <<'EOF'
Usage:
  workbench-a11y-live-validate.sh [options]

Options:
  --proof <file>    Live accessibility proof Markdown.
  --output <file>   Validation report path.
  --json-output <file>
                    Machine-readable validation JSON path.
  --expected-app <path>
                    Expected app bundle path recorded by the proof.
  -h, --help

Validates that the manual live accessibility proof has exactly 24 matrix
checks, all pass, no fail/skip/pending cells, and a passing verdict.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --proof)
            proof="$2"
            shift 2
            ;;
        --output)
            output="$2"
            shift 2
            ;;
        --json-output)
            json_output="$2"
            shift 2
            ;;
        --expected-app)
            expected_app="$2"
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

mkdir -p "$(dirname "$output")"

python3 - "$proof" "$output" "$json_output" "$expected_app" <<'PY'
from pathlib import Path
import json
import re
import sys

proof = Path(sys.argv[1])
output = Path(sys.argv[2])
json_output = Path(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else None
expected_app = Path(sys.argv[4]).resolve() if len(sys.argv) > 4 and sys.argv[4] else None
expected_soffice = expected_app / "Contents/MacOS/soffice" if expected_app else None

errors: list[str] = []
error_codes: list[str] = []

def add_error(code: str, message: str) -> None:
    error_codes.append(code)
    errors.append(message)

text = ""
proof_exists = proof.exists()
if not proof_exists:
    add_error("proof-missing", f"proof does not exist: {proof}")
else:
    text = proof.read_text(encoding="utf-8")

status = ""
claim = ""
summary = None
app_under_test = ""
app_executable = ""
normalized_app_under_test = ""
normalized_app_executable = ""
matrix_rows: list[tuple[str, list[str], str]] = []
in_matrix = False

for raw in text.splitlines():
    line = raw.strip()
    if line.startswith("- Status:"):
        status = line.split(":", 1)[1].strip()
    elif line.startswith("- Accessibility claim allowed:"):
        claim = line.split(":", 1)[1].strip()
    elif line.startswith("- Total pass:"):
        match = re.search(r"Total pass:\s*(\d+)\s*/\s*fail:\s*(\d+)\s*/\s*skip:\s*(\d+)", line)
        if match:
            summary = tuple(int(part) for part in match.groups())
    elif line.startswith("- App under test:"):
        app_under_test = line.split(":", 1)[1].strip().strip(chr(96))
    elif line.startswith("- App executable:"):
        app_executable = line.split(":", 1)[1].strip().strip(chr(96))
    elif line == "## Matrix":
        in_matrix = True
        continue
    elif line.startswith("## ") and line != "## Matrix":
        in_matrix = False

    if not in_matrix:
        continue
    if not line.startswith("|") or line.startswith("| ---") or line.startswith("| Surface "):
        continue
    cells = [cell.strip() for cell in line.strip("|").split("|")]
    if len(cells) != 6:
        add_error("matrix-row-shape", f"matrix row has {len(cells)} cells instead of 6: {line}")
        continue
    surface = cells[0]
    checks = cells[1:5]
    surface_status = cells[5]
    matrix_rows.append((surface, checks, surface_status))

if status != "passed":
    add_error("verdict-not-passed", f"verdict status is not passed: {status or 'missing'}")
if claim != "yes":
    add_error("claim-not-yes", f"accessibility claim allowed is not yes: {claim or 'missing'}")
if summary != (24, 0, 0):
    add_error("summary-not-24-0-0", f"summary is not 24/0/0: {summary if summary is not None else 'missing'}")
if len(matrix_rows) != 6:
    add_error("matrix-row-count", f"matrix row count is not 6: {len(matrix_rows)}")

if app_under_test:
    normalized_app_under_test = str(Path(app_under_test).resolve())
if app_executable:
    normalized_app_executable = str(Path(app_executable).resolve())

if expected_app is not None:
    if not app_under_test:
        add_error("app-under-test-missing", "app under test is missing")
    else:
        actual_app = Path(normalized_app_under_test)
        if actual_app != expected_app:
            add_error("app-under-test-mismatch", f"app under test does not match expected app: {actual_app} != {expected_app}")
    if not app_executable:
        add_error("app-executable-missing", "app executable is missing")
    else:
        actual_soffice = Path(normalized_app_executable)
        if actual_soffice != expected_soffice:
            add_error("app-executable-mismatch", f"app executable does not match expected soffice: {actual_soffice} != {expected_soffice}")

pass_cells = 0
bad_cells: list[str] = []
for surface, checks, surface_status in matrix_rows:
    for lane, value in zip(["Keyboard", "VoiceOver", "High contrast", "Resize"], checks):
        if value == "pass":
            pass_cells += 1
        else:
            bad_cells.append(f"{surface} / {lane}: {value}")
    if surface_status != "pass":
        bad_cells.append(f"{surface} / row status: {surface_status}")

if pass_cells != 24:
    add_error("matrix-pass-cell-count", f"matrix pass cell count is not 24: {pass_cells}")
if bad_cells:
    add_error("matrix-non-pass-cells", "non-pass matrix cells: " + "; ".join(bad_cells[:20]))

if not errors:
    failure_category = "none"
    next_action = ""
elif "proof-missing" in error_codes:
    failure_category = "proof-missing"
    next_action = "Generate tmp/product-completion/live-accessibility-checklist.md if needed, then run bin/workbench-a11y-live.sh --resume --app <selected-app> --output tmp/product-completion/live-accessibility-proof.md and rerun validation."
elif "app-under-test-mismatch" in error_codes or "app-executable-mismatch" in error_codes:
    failure_category = "app-mismatch"
    next_action = "Rerun the manual proof against the same app bundle selected by KDOFFICE_APP_BUNDLE, then rerun validation with --expected-app."
elif "matrix-non-pass-cells" in error_codes:
    failure_category = "matrix-non-pass"
    next_action = "Resolve failed, skipped, or pending live checks and rerun or resume the manual proof until all 24 checks pass."
elif any(code.startswith("matrix-") for code in error_codes) or "summary-not-24-0-0" in error_codes:
    failure_category = "proof-incomplete"
    next_action = "Complete or regenerate the live accessibility proof so it contains the six-row matrix and Total pass: 24 / fail: 0 / skip: 0."
else:
    failure_category = "proof-invalid"
    next_action = "Inspect the validation errors, correct the proof format or manual results, and rerun validation."

lines: list[str] = []
lines.append("# Live Accessibility Proof Validation")
lines.append("")
lines.append(f"Proof: {proof}")
lines.append("")
lines.append("## Verdict")
lines.append("")
lines.append(f"- Status: **{'passed' if not errors else 'failed'}**")
lines.append(f"- Matrix rows: {len(matrix_rows)}")
lines.append(f"- Matrix pass cells: {pass_cells}")
lines.append(f"- Summary: {summary if summary is not None else 'missing'}")
lines.append(f"- Accessibility claim allowed: {claim or 'missing'}")
lines.append(f"- App under test: {normalized_app_under_test or 'missing'}")
lines.append(f"- App executable: {normalized_app_executable or 'missing'}")
if expected_app is not None:
    lines.append(f"- Expected app: {expected_app}")
lines.append(f"- Failure category: {failure_category}")
lines.append(f"- Next action: {next_action or 'none'}")
lines.append("")
lines.append("## Errors")
lines.append("")
if errors:
    for error in errors:
        lines.append(f"- {error}")
else:
    lines.append("- none")

output.write_text("\n".join(lines) + "\n", encoding="utf-8")
payload = {
    "schema_version": 1,
    "proof": str(proof),
    "proof_exists": proof_exists,
    "status": "passed" if not errors else "failed",
    "failure_category": failure_category,
    "next_action": next_action,
    "matrix_rows": len(matrix_rows),
    "matrix_pass_cells": pass_cells,
    "summary": {
        "pass": summary[0],
        "fail": summary[1],
        "skip": summary[2],
    } if summary is not None else None,
    "accessibility_claim_allowed": claim or "",
    "verdict_status": status or "",
    "app_under_test": normalized_app_under_test,
    "app_executable": normalized_app_executable,
    "expected_app": str(expected_app) if expected_app else "",
    "expected_soffice": str(expected_soffice) if expected_soffice else "",
    "error_codes": error_codes,
    "errors": errors,
}
if json_output is not None:
    json_output.parent.mkdir(parents=True, exist_ok=True)
    json_output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Wrote live accessibility validation to {output}")
if errors:
    raise SystemExit(1)
PY
