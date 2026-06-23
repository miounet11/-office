#!/usr/bin/env bash
# V3 W9 - error-recovery UX contract self-test.
#
# Contract-first gate for W9 recoverable error UX. It does not implement
# recovery UI, diagnostics export, or product integration code.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

schema_path="docs/schemas/error-recovery-ux.schema.json"
w9_spec="docs/product/v3/w9-market-readiness-spec.md"
w5_spec="docs/product/v3/w5-eval-harness-spec.md"
master_plan="docs/product/v3-master-plan.md"
sweep="bin/v3-eval-sweep.sh"
workflow=".github/workflows/v3-contract-harnesses.yml"
valid_dir="docs/qa/fixtures/v3/error-recovery-ux/valid"
invalid_dir="docs/qa/fixtures/v3/error-recovery-ux/invalid"

[[ -f "$schema_path" ]] || fail "missing $schema_path"
[[ -f "$w9_spec" ]] || fail "missing $w9_spec"
[[ -f "$w5_spec" ]] || fail "missing $w5_spec"
[[ -f "$master_plan" ]] || fail "missing $master_plan"
[[ -f "$sweep" ]] || fail "missing $sweep"
[[ -f "$workflow" ]] || fail "missing $workflow"
[[ -d "$valid_dir" ]] || fail "missing $valid_dir"
[[ -d "$invalid_dir" ]] || fail "missing $invalid_dir"

python3 - "$schema_path" "$w9_spec" "$w5_spec" "$master_plan" "$sweep" "$workflow" "$valid_dir" "$invalid_dir" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

schema_path = Path(sys.argv[1])
w9_spec = Path(sys.argv[2])
w5_spec = Path(sys.argv[3])
master_plan = Path(sys.argv[4])
sweep_path = Path(sys.argv[5])
workflow_path = Path(sys.argv[6])
valid_dir = Path(sys.argv[7])
invalid_dir = Path(sys.argv[8])

REQUIRED = ["id", "schemaVersion", "createdAt", "policy", "scenarios", "evidence", "gates"]
EXPECTED_VALID_FILES = {"error-recovery-ux.json"}
EXPECTED_INVALID_FILES = {
    "missing-next-step.json",
    "evidence-not-openable.json",
    "toast-only-dead-end.json",
    "main-document-mutated.json",
}
EXPECTED_SCENARIOS = ["provider-timeout", "connector-auth-expired", "policy-denied", "patch-apply-failed"]
EXPECTED_SURFACES = {"writer", "calc", "impress", "companion"}
BASE_EVIDENCE = {"error-recovery-ux", "inline-guidance", "next-step-action", "openable-evidence", "diagnostics-export", "evidence-record"}


def die(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def load(path: Path) -> Any:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def json_pointer(path: list[str]) -> str:
    if not path:
        return "$"
    return "$" + "".join(f"/{part}" for part in path)


def type_matches(value: Any, expected: str) -> bool:
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    return True


def validate(value: Any, schema: dict[str, Any], path: list[str]) -> list[str]:
    errors: list[str] = []
    expected_type = schema.get("type")
    if isinstance(expected_type, str) and not type_matches(value, expected_type):
        return [f"{json_pointer(path)} expected {expected_type}"]

    if "const" in schema and value != schema["const"]:
        errors.append(f"{json_pointer(path)} expected const {schema['const']!r}")

    enum_values = schema.get("enum")
    if isinstance(enum_values, list) and value not in enum_values:
        errors.append(f"{json_pointer(path)} expected one of {enum_values!r}")

    if isinstance(value, str):
        pattern = schema.get("pattern")
        if isinstance(pattern, str) and re.search(pattern, value) is None:
            errors.append(f"{json_pointer(path)} does not match {pattern!r}")
        min_length = schema.get("minLength")
        max_length = schema.get("maxLength")
        if isinstance(min_length, int) and len(value) < min_length:
            errors.append(f"{json_pointer(path)} shorter than minLength {min_length}")
        if isinstance(max_length, int) and len(value) > max_length:
            errors.append(f"{json_pointer(path)} longer than maxLength {max_length}")

    if isinstance(value, int) and not isinstance(value, bool):
        minimum = schema.get("minimum")
        maximum = schema.get("maximum")
        if isinstance(minimum, int) and value < minimum:
            errors.append(f"{json_pointer(path)} below minimum {minimum}")
        if isinstance(maximum, int) and value > maximum:
            errors.append(f"{json_pointer(path)} above maximum {maximum}")

    if isinstance(value, list):
        min_items = schema.get("minItems")
        max_items = schema.get("maxItems")
        if isinstance(min_items, int) and len(value) < min_items:
            errors.append(f"{json_pointer(path)} has fewer than minItems {min_items}")
        if isinstance(max_items, int) and len(value) > max_items:
            errors.append(f"{json_pointer(path)} has more than maxItems {max_items}")
        if schema.get("uniqueItems") is True:
            seen: set[str] = set()
            for index, item in enumerate(value):
                key = json.dumps(item, sort_keys=True, ensure_ascii=False)
                if key in seen:
                    errors.append(f"{json_pointer(path + [str(index)])} duplicates an earlier item")
                seen.add(key)
        item_schema = schema.get("items")
        if isinstance(item_schema, dict):
            for index, item in enumerate(value):
                errors.extend(validate(item, item_schema, path + [str(index)]))

    if isinstance(value, dict):
        properties = schema.get("properties")
        property_names = set(properties.keys()) if isinstance(properties, dict) else set()
        required = schema.get("required")
        if isinstance(required, list):
            for key in required:
                if isinstance(key, str) and key not in value:
                    errors.append(f"{json_pointer(path + [key])} is required")
        if schema.get("additionalProperties") is False:
            for key in sorted(value):
                if key not in property_names:
                    errors.append(f"{json_pointer(path + [key])} is not allowed")
        if isinstance(properties, dict):
            for key, child_schema in properties.items():
                if key in value and isinstance(child_schema, dict):
                    errors.extend(validate(value[key], child_schema, path + [key]))
    return errors


def semantic_errors(value: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    policy = value.get("policy", {})
    scenarios = value.get("scenarios", [])
    evidence = set(value.get("evidence", {}).get("required", []))

    if policy != {
        "presentation": "inline-guidance",
        "nextStepRequired": True,
        "evidenceOpenable": True,
        "deadEndAllowed": False,
        "mainDocumentUnchangedUntilApply": True,
        "humanReadableCauseRequired": True,
    }:
        errors.append("error recovery policy drifted")

    if [scenario.get("kind") for scenario in scenarios] != EXPECTED_SCENARIOS:
        errors.append("error scenario roster/order drifted")
    if {scenario.get("surface") for scenario in scenarios} != EXPECTED_SURFACES:
        errors.append("error scenario surface coverage drifted")

    for scenario in scenarios:
        kind = scenario.get("kind")
        if scenario.get("causeToken") != f"error.{kind}":
            errors.append(f"{kind} cause token drifted")
        next_steps = set(scenario.get("nextSteps", []))
        if "open-evidence" not in next_steps or "export-diagnostics" not in next_steps:
            errors.append(f"{kind} must offer open-evidence and export-diagnostics")
        if len(next_steps) < 2:
            errors.append(f"{kind} must offer at least two next steps")
        scenario_evidence = scenario.get("evidence", {})
        if scenario_evidence.get("openable") is not True or scenario_evidence.get("diagnosticsExportable") is not True:
            errors.append(f"{kind} evidence must be openable and diagnostics-exportable")
        guarantee = scenario.get("recoveryGuarantee", {})
        if guarantee != {
            "mainDocumentUnchanged": True,
            "canRetry": True,
            "canRollback": True,
            "requiresUserChoice": True,
        }:
            errors.append(f"{kind} recovery guarantee drifted")

    if not BASE_EVIDENCE.issubset(evidence):
        errors.append("error recovery evidence requirements drifted")
    if value.get("gates", {}).get("runtimeImplementation") != "not-started":
        errors.append("error recovery runtime implementation must remain gated")
    return errors


schema = load(schema_path)
if not isinstance(schema, dict):
    die("schema top-level must be object")

pass_count = 0

if schema.get("required") != REQUIRED:
    die(f"schema.required drifted: {schema.get('required')!r}")
if schema.get("additionalProperties") is not False:
    die("schema must set top-level additionalProperties:false")
props = schema.get("properties", {})
if props.get("scenarios", {}).get("minItems") != 4 or props.get("scenarios", {}).get("maxItems") != 4:
    die("schema must lock exactly 4 error scenarios")
if props.get("policy", {}).get("properties", {}).get("presentation", {}).get("const") != "inline-guidance":
    die("presentation must stay inline-guidance")
if props.get("policy", {}).get("properties", {}).get("deadEndAllowed", {}).get("const") is not False:
    die("dead-end errors must stay forbidden")
pass_count += 1

valid_paths = sorted(valid_dir.glob("*.json"))
invalid_paths = sorted(invalid_dir.glob("*.json"))
if {path.name for path in valid_paths} != EXPECTED_VALID_FILES:
    die(f"valid fixture roster drifted: {[path.name for path in valid_paths]!r}")
if {path.name for path in invalid_paths} != EXPECTED_INVALID_FILES:
    die(f"invalid fixture roster drifted: {[path.name for path in invalid_paths]!r}")
pass_count += 1

for path in valid_paths:
    value = load(path)
    if not isinstance(value, dict):
        die(f"{path} must contain an object")
    errors = validate(value, schema, [path.name])
    if errors:
        die(f"{path} violates schema:\n" + "\n".join(errors))
    semantic = semantic_errors(value)
    if semantic:
        die(f"{path} violates W9 error-recovery-ux semantics:\n" + "\n".join(semantic))
pass_count += 1

value = load(valid_paths[0])
steps = {step for scenario in value["scenarios"] for step in scenario["nextSteps"]}
for expected_step in ["retry", "reconnect-connector", "request-approval", "rollback-preview", "open-evidence", "export-diagnostics"]:
    if expected_step not in steps:
        die(f"valid fixture missing recovery action {expected_step}")
if {scenario["surface"] for scenario in value["scenarios"]} != EXPECTED_SURFACES:
    die("valid fixture surface coverage drifted")
pass_count += 1

for path in invalid_paths:
    value = load(path)
    if not isinstance(value, dict):
        die(f"{path} must contain an object")
    schema_errors = validate(value, schema, [path.name])
    semantic = semantic_errors(value)
    if not schema_errors and not semantic:
        die(f"{path} unexpectedly passed schema+semantic validation")
pass_count += 1

raw = valid_paths[0].read_text(encoding="utf-8")
for needle in ["toast-only", "deadEndAllowed\": true", "openable\": false", "mainDocumentUnchanged\": false"]:
    if needle in raw:
        die(f"{valid_paths[0]} contains forbidden error-recovery marker {needle!r}")
pass_count += 1

w9_text = w9_spec.read_text(encoding="utf-8")
w5_text = w5_spec.read_text(encoding="utf-8")
master_text = master_plan.read_text(encoding="utf-8")
sweep_text = sweep_path.read_text(encoding="utf-8")
workflow_text = workflow_path.read_text(encoding="utf-8")
for path, text, needles in [
    (w9_spec, w9_text, ["error-recovery-ux self-test", "Checks: 8", "error-recovery-ux", "inline guidance", "openable evidence"]),
    (w5_spec, w5_text, ["tests/v3-error-recovery-ux-test.sh", "error-recovery-ux self-test"]),
    (master_plan, master_text, ["error-recovery-ux.schema.json", "tests/v3-error-recovery-ux-test.sh"]),
    (sweep_path, sweep_text, ["tests/v3-error-recovery-ux-test.sh", "W9 error-recovery-ux self-test"]),
    (workflow_path, workflow_text, ["docs/schemas/error-recovery-ux.schema.json", "bin/v3-eval-sweep.sh --self-test"]),
]:
    for needle in needles:
        if needle not in text:
            die(f"{path} missing {needle!r}")
pass_count += 1

if pass_count != 7:
    die(f"internal pass_count drifted before final increment: {pass_count}")
pass_count += 1

print("Status: passed")
print("Harness: W9 error-recovery-ux self-test")
print(f"Schema: {schema_path}")
print(f"Valid fixtures: {len(valid_paths)}")
print(f"Invalid fixtures: {len(invalid_paths)}")
print("Error UX contract: inline guidance, next steps, openable evidence")
print("Runtime implementation: deferred until W9 gate")
print(f"Checks: {pass_count}")
PY
