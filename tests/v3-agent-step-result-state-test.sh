#!/usr/bin/env bash
# V3 W6 - agent-step-result/task-state contract self-test.
#
# Contract-first gate for W6 lifecycle envelopes. It does not start the
# gated AgentRuntime, Actor, Observer, ShadowDoc, StepStore, or V2-W5
# cowork integration. It locks per-step results, task state, failure
# isolation, cancellation, approval, and ApplyPlan runtime validation.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

result_schema="docs/schemas/agent-step-result.schema.json"
state_schema="docs/schemas/agent-task-state.schema.json"
w6_spec="docs/product/v3/w6-agent-multistep-spec.md"
w5_spec="docs/product/v3/w5-eval-harness-spec.md"
master_plan="docs/product/v3-master-plan.md"
sweep="bin/v3-eval-sweep.sh"
workflow=".github/workflows/v3-contract-harnesses.yml"
valid_dir="docs/qa/fixtures/v3/agent-step-result-state/valid"
invalid_dir="docs/qa/fixtures/v3/agent-step-result-state/invalid"

[[ -f "$result_schema" ]] || fail "missing $result_schema"
[[ -f "$state_schema" ]] || fail "missing $state_schema"
[[ -f "$w6_spec" ]] || fail "missing $w6_spec"
[[ -f "$w5_spec" ]] || fail "missing $w5_spec"
[[ -f "$master_plan" ]] || fail "missing $master_plan"
[[ -f "$sweep" ]] || fail "missing $sweep"
[[ -f "$workflow" ]] || fail "missing $workflow"
[[ -d "$valid_dir" ]] || fail "missing $valid_dir"
[[ -d "$invalid_dir" ]] || fail "missing $invalid_dir"

python3 - "$result_schema" "$state_schema" "$w6_spec" "$w5_spec" "$master_plan" "$sweep" "$workflow" "$valid_dir" "$invalid_dir" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

result_schema_path = Path(sys.argv[1])
state_schema_path = Path(sys.argv[2])
w6_spec = Path(sys.argv[3])
w5_spec = Path(sys.argv[4])
master_plan = Path(sys.argv[5])
sweep_path = Path(sys.argv[6])
workflow_path = Path(sys.argv[7])
valid_dir = Path(sys.argv[8])
invalid_dir = Path(sys.argv[9])

RESULT_REQUIRED = ["id", "schemaVersion", "taskId", "stepIndex", "kind", "status", "startedAt", "finishedAt", "output", "sandbox", "policy", "evidence"]
STATE_REQUIRED = ["taskId", "schemaVersion", "updatedAt", "ownerSurface", "state", "currentStepIndex", "maxSteps", "progress", "cowork", "approval", "recovery", "merge", "evidence"]
EXPECTED_VALID_FILES = {
    "writer-patch-completed-running.json",
    "calc-review-awaiting.json",
    "impress-step-failed-recovery.json",
    "writer-hard-cancelled.json",
}
EXPECTED_INVALID_FILES = {
    "patch-without-apply-runtime-validation.json",
    "failed-step-mutates-main-doc.json",
    "task-state-bypasses-cowork.json",
}
EXPECTED_STATUSES = {"completed", "failed", "cancelled"}
EXPECTED_TASK_STATES = {"running", "awaiting-review", "failed", "cancelled"}
BASE_EVIDENCE = {"policy-decision", "audit-log-entry", "evidence-record"}
ROOT_STATE_EVIDENCE = {"policy-decision", "evidence-record", "audit-log-entry"}
PATCH_EVIDENCE = {"shadow-doc-diff", "apply-plan-runtime-validated"}


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


def semantic_errors(pair: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    result = pair.get("stepResult", {})
    state = pair.get("taskState", {})
    output = result.get("output", {})
    sandbox = result.get("sandbox", {})
    evidence = set(result.get("evidence", {}).get("required", []))
    failure = result.get("failure", {})
    progress = state.get("progress", {})

    if result.get("taskId") != state.get("taskId"):
        errors.append("stepResult.taskId must match taskState.taskId")
    if result.get("stepIndex") != state.get("currentStepIndex"):
        errors.append("stepResult.stepIndex must match taskState.currentStepIndex")
    if state.get("currentStepIndex", 0) >= state.get("maxSteps", 0):
        errors.append("currentStepIndex must be inside maxSteps")
    if output.get("storesDocumentContent") is not False:
        errors.append("step result output must not store document content")
    if sandbox.get("mode") != "shadow-doc":
        errors.append("step results must run in shadow-doc")
    if sandbox.get("mainDocumentUnchanged") is not True:
        errors.append("main document must remain unchanged before merge")
    if sandbox.get("failureIsolation") != "discard-step-branch":
        errors.append("failureIsolation must discard step branch")
    if result.get("policy", {}).get("preflight") is not True or result.get("policy", {}).get("auditLog") is not True:
        errors.append("each step result must require policy preflight and audit log")
    if not BASE_EVIDENCE.issubset(evidence):
        errors.append("step evidence requirements drifted")
    if set(state.get("evidence", {}).get("requiredForEveryStep", [])) != ROOT_STATE_EVIDENCE:
        errors.append("task-state root evidence requirements drifted")
    if state.get("evidence", {}).get("auditLogRequired") is not True:
        errors.append("task state must require audit log")
    if state.get("cowork", {}).get("usesV2AsyncCowork") is not True or state.get("cowork", {}).get("taskKind") != "agent-multistep":
        errors.append("W6 tasks must use V2 async cowork as the scheduler")
    if state.get("cowork", {}).get("taskState") != state.get("state"):
        errors.append("cowork taskState must mirror task state")
    if state.get("approval", {}).get("wholeTaskApprovalRequired") is not True:
        errors.append("whole-task approval must be required before merge")
    if state.get("approval", {}).get("perStepApprovalSupported") is not True:
        errors.append("per-step approval must remain supported")
    if state.get("recovery", {}).get("softCancelSupported") is not True or state.get("recovery", {}).get("hardCancelSupported") is not True:
        errors.append("soft and hard cancel must both be supported")
    if state.get("recovery", {}).get("userDecisionRequired") is not True:
        errors.append("failure recovery must require user decision")
    if state.get("recovery", {}).get("mainDocumentUnchangedOnFailure") is not True:
        errors.append("mainDocumentUnchangedOnFailure must be true")
    if state.get("merge", {}).get("target") != "main-doc":
        errors.append("merge target must be main-doc")
    if state.get("merge", {}).get("requiresApproval") is not True or state.get("merge", {}).get("requiresApplyPlanRuntimeValidation") is not True:
        errors.append("merge must require approval and ApplyPlan runtime validation")

    status = result.get("status")
    kind = result.get("kind")
    if kind == "patch":
        if output.get("kind") != "apply-plan-runtime" or output.get("schemaRef") != "apply-plan-runtime":
            errors.append("patch result must output apply-plan-runtime")
        if output.get("applyPlanRuntimeValidated") is not True:
            errors.append("patch result must validate ApplyPlan runtime")
        if not PATCH_EVIDENCE.issubset(evidence):
            errors.append("patch result missing shadow-doc/apply-plan evidence")
    if kind == "review":
        if output.get("kind") != "approval-decision" or output.get("schemaRef") != "user-approval":
            errors.append("review result must output user approval")
        if "user-approval" not in evidence:
            errors.append("review result missing user-approval evidence")
    if status == "completed":
        if failure.get("code") != "none":
            errors.append("completed result failure.code must be none")
        if state.get("state") == "failed":
            errors.append("completed result must not leave task failed")
    if status == "failed":
        if failure.get("code") in {None, "none"}:
            errors.append("failed result must include a real failure code")
        if "failure-record" not in evidence:
            errors.append("failed result must require failure-record evidence")
        if state.get("state") != "failed":
            errors.append("failed step must put task state in failed")
        if progress.get("failedSteps", 0) < 1:
            errors.append("failed task must record failedSteps")
    if status == "cancelled":
        if failure.get("code") != "user-cancelled":
            errors.append("cancelled result must use user-cancelled code")
        if "cancel-request" not in evidence:
            errors.append("cancelled result must require cancel-request evidence")
        if state.get("state") != "cancelled":
            errors.append("cancelled step must put task state in cancelled")
        if progress.get("cancelledSteps", 0) < 1:
            errors.append("cancelled task must record cancelledSteps")
    return errors


result_schema = load(result_schema_path)
state_schema = load(state_schema_path)
if not isinstance(result_schema, dict) or not isinstance(state_schema, dict):
    die("schema top-level must be objects")

pass_count = 0

if result_schema.get("required") != RESULT_REQUIRED:
    die(f"result schema.required drifted: {result_schema.get('required')!r}")
if result_schema.get("additionalProperties") is not False:
    die("result schema must set top-level additionalProperties:false")
r_props = result_schema.get("properties", {})
if r_props.get("sandbox", {}).get("properties", {}).get("mainDocumentUnchanged", {}).get("const") is not True:
    die("mainDocumentUnchanged must be const true")
if r_props.get("output", {}).get("properties", {}).get("storesDocumentContent", {}).get("const") is not False:
    die("storesDocumentContent must be const false")
pass_count += 1

if state_schema.get("required") != STATE_REQUIRED:
    die(f"state schema.required drifted: {state_schema.get('required')!r}")
if state_schema.get("additionalProperties") is not False:
    die("state schema must set top-level additionalProperties:false")
s_props = state_schema.get("properties", {})
if s_props.get("maxSteps", {}).get("maximum") != 25:
    die("maxSteps maximum must stay 25")
if s_props.get("cowork", {}).get("properties", {}).get("usesV2AsyncCowork", {}).get("const") is not True:
    die("usesV2AsyncCowork must be const true")
if s_props.get("merge", {}).get("properties", {}).get("requiresApplyPlanRuntimeValidation", {}).get("const") is not True:
    die("merge requiresApplyPlanRuntimeValidation must be const true")
pass_count += 1

valid_paths = sorted(valid_dir.glob("*.json"))
invalid_paths = sorted(invalid_dir.glob("*.json"))
if {path.name for path in valid_paths} != EXPECTED_VALID_FILES:
    die(f"valid fixture roster drifted: {[path.name for path in valid_paths]!r}")
if {path.name for path in invalid_paths} != EXPECTED_INVALID_FILES:
    die(f"invalid fixture roster drifted: {[path.name for path in invalid_paths]!r}")
pass_count += 1

statuses: set[str] = set()
task_states: set[str] = set()
for path in valid_paths:
    pair = load(path)
    if not isinstance(pair, dict) or not isinstance(pair.get("stepResult"), dict) or not isinstance(pair.get("taskState"), dict):
        die(f"{path} must contain stepResult and taskState objects")
    errors = validate(pair["stepResult"], result_schema, ["stepResult"]) + validate(pair["taskState"], state_schema, ["taskState"])
    if errors:
        die(f"{path} violates schema:\n" + "\n".join(errors))
    semantic = semantic_errors(pair)
    if semantic:
        die(f"{path} violates W6 result/state semantics:\n" + "\n".join(semantic))
    statuses.add(pair["stepResult"]["status"])
    task_states.add(pair["taskState"]["state"])
pass_count += 1

if statuses != EXPECTED_STATUSES:
    die(f"valid fixtures must cover statuses {sorted(EXPECTED_STATUSES)}, saw {sorted(statuses)}")
if task_states != EXPECTED_TASK_STATES:
    die(f"valid fixtures must cover task states {sorted(EXPECTED_TASK_STATES)}, saw {sorted(task_states)}")
pass_count += 1

for path in invalid_paths:
    pair = load(path)
    if not isinstance(pair, dict) or not isinstance(pair.get("stepResult"), dict) or not isinstance(pair.get("taskState"), dict):
        die(f"{path} must contain stepResult and taskState objects")
    schema_errors = validate(pair["stepResult"], result_schema, ["stepResult"]) + validate(pair["taskState"], state_schema, ["taskState"])
    semantic = semantic_errors(pair)
    if not schema_errors and not semantic:
        die(f"{path} unexpectedly passed schema+semantic validation")
pass_count += 1

w6_text = w6_spec.read_text(encoding="utf-8")
w5_text = w5_spec.read_text(encoding="utf-8")
master_text = master_plan.read_text(encoding="utf-8")
sweep_text = sweep_path.read_text(encoding="utf-8")
workflow_text = workflow_path.read_text(encoding="utf-8")
for path, text, needles in [
    (w6_spec, w6_text, ["agent-step-result-state self-test", "Checks: 8", "usesV2AsyncCowork", "mainDocumentUnchanged", "requiresApplyPlanRuntimeValidation"]),
    (w5_spec, w5_text, ["tests/v3-agent-step-result-state-test.sh", "agent-step-result-state self-test"]),
    (master_plan, master_text, ["agent-step-result.schema.json", "agent-task-state.schema.json", "tests/v3-agent-step-result-state-test.sh"]),
    (sweep_path, sweep_text, ["tests/v3-agent-step-result-state-test.sh", "W6 agent-step-result-state self-test"]),
    (workflow_path, workflow_text, ["docs/schemas/agent-step-result.schema.json", "docs/schemas/agent-task-state.schema.json", "bin/v3-eval-sweep.sh --self-test"]),
]:
    for needle in needles:
        if needle not in text:
            die(f"{path} missing {needle!r}")
pass_count += 1

if pass_count != 7:
    die(f"internal pass_count drifted before final increment: {pass_count}")
pass_count += 1

print("Status: passed")
print("Harness: W6 agent-step-result-state self-test")
print(f"Result schema: {result_schema_path}")
print(f"State schema: {state_schema_path}")
print(f"Valid fixtures: {len(valid_paths)}")
print(f"Invalid fixtures: {len(invalid_paths)}")
print("Lifecycle contract: V2 cowork, shadow-doc isolation, approval before merge")
print("Runtime implementation: deferred until W6 gate")
print(f"Checks: {pass_count}")
PY
