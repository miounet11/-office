#!/usr/bin/env bash
# V3 W6 - agent-step-plan contract self-test.
#
# Contract-first gate for W6. It now also runs the focused M5.1
# planner-validation runtime smoke, but it does not start gated AgentRuntime,
# Actor, Observer, prompt execution, scheduler, or ShadowDoc implementation.
# It locks the Plan-Act-Observe plan envelope, step roster semantics, V2
# token-lock preservation, shadow-doc isolation, and per-step policy/audit
# evidence.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

bash tests/v3-agent-planner-runtime-test.sh >/dev/null

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

schema="docs/schemas/agent-step-plan.schema.json"
w6_spec="docs/product/v3/w6-agent-multistep-spec.md"
w6_dependency_policy="docs/product/v3/w6-dependency-policy.md"
w6_plan_validation_policy="docs/product/v3/w6-plan-validation-policy.md"
w6_approval_policy="docs/product/v3/w6-approval-policy.md"
w6_resume_policy="docs/product/v3/w6-resume-policy.md"
w6_shadow_doc_policy="docs/product/v3/w6-shadow-doc-policy.md"
w6_prompt_library="docs/product/v3/w6-prompt-library.md"
w5_spec="docs/product/v3/w5-eval-harness-spec.md"
master_plan="docs/product/v3-master-plan.md"
sweep="bin/v3-eval-sweep.sh"
workflow=".github/workflows/v3-contract-harnesses.yml"
valid_dir="docs/qa/fixtures/v3/agent-step-plan/valid"
invalid_dir="docs/qa/fixtures/v3/agent-step-plan/invalid"

[[ -f "$schema" ]] || fail "missing $schema"
[[ -f "$w6_spec" ]] || fail "missing $w6_spec"
[[ -f "$w6_dependency_policy" ]] || fail "missing $w6_dependency_policy"
[[ -f "$w6_plan_validation_policy" ]] || fail "missing $w6_plan_validation_policy"
[[ -f "$w6_approval_policy" ]] || fail "missing $w6_approval_policy"
[[ -f "$w6_resume_policy" ]] || fail "missing $w6_resume_policy"
[[ -f "$w6_shadow_doc_policy" ]] || fail "missing $w6_shadow_doc_policy"
[[ -f "$w6_prompt_library" ]] || fail "missing $w6_prompt_library"
[[ -f "$w5_spec" ]] || fail "missing $w5_spec"
[[ -f "$master_plan" ]] || fail "missing $master_plan"
[[ -f "$sweep" ]] || fail "missing $sweep"
[[ -f "$workflow" ]] || fail "missing $workflow"
[[ -d "$valid_dir" ]] || fail "missing $valid_dir"
[[ -d "$invalid_dir" ]] || fail "missing $invalid_dir"

python3 - "$schema" "$w6_spec" "$w6_dependency_policy" "$w6_plan_validation_policy" "$w6_approval_policy" "$w6_resume_policy" "$w6_shadow_doc_policy" "$w6_prompt_library" "$w5_spec" "$master_plan" "$sweep" "$workflow" "$valid_dir" "$invalid_dir" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

schema_path = Path(sys.argv[1])
w6_spec = Path(sys.argv[2])
w6_dependency_policy = Path(sys.argv[3])
w6_plan_validation_policy = Path(sys.argv[4])
w6_approval_policy = Path(sys.argv[5])
w6_resume_policy = Path(sys.argv[6])
w6_shadow_doc_policy = Path(sys.argv[7])
w6_prompt_library = Path(sys.argv[8])
w5_spec = Path(sys.argv[9])
master_plan = Path(sys.argv[10])
sweep_path = Path(sys.argv[11])
workflow_path = Path(sys.argv[12])
valid_dir = Path(sys.argv[13])
invalid_dir = Path(sys.argv[14])

EXPECTED_REQUIRED = [
    "taskId",
    "schemaVersion",
    "goal",
    "createdAt",
    "ownerSurface",
    "maxSteps",
    "approvalMode",
    "approvalPolicy",
    "resumePolicy",
    "dataBoundary",
    "sandbox",
    "shadowDocPolicy",
    "dependencyPolicy",
    "plannerValidation",
    "promptPolicy",
    "tokenLock",
    "steps",
    "evidence",
]
EXPECTED_VALID_FILES = {
    "writer-quarterly-risk-report.json",
    "calc-clean-sales-data.json",
    "impress-outline-to-slides.json",
}
EXPECTED_INVALID_FILES = {
    "overflow-maxsteps.json",
    "patch-bypasses-apply-plan-runtime.json",
    "missing-shadow-doc-isolation.json",
    "forward-dependency-dag.json",
    "invalid-plan-silent-retry.json",
    "implicit-per-step-approval.json",
    "stale-checkpoint-auto-resume.json",
    "shadow-doc-new-docshell-runtime.json",
    "prompt-policy-public-egress-runtime.json",
}
TOKEN_LOCK = {
    "ParagraphAction": 7,
    "CellAction": 5,
    "SlideElementAction": 4,
}
EXPECTED_SURFACES = {"writer", "calc", "impress"}
PATCH_EVIDENCE = {"provider-call", "shadow-doc-diff", "apply-plan-runtime-validated"}
ROOT_EVIDENCE = {"policy-decision", "evidence-record"}
DEPENDENCY_POLICY = {
    "policyDoc": "docs/product/v3/w6-dependency-policy.md",
    "graphType": "forward-only-dag",
    "executionOrder": "topological-index",
    "allowsFanIn": True,
    "allowsFanOut": True,
    "allowsCycles": False,
    "allowsFutureDependencies": False,
    "allowsParallelRuntime": False,
    "runtimeSchedulerImplementation": "not-started",
}
PLANNER_VALIDATION_POLICY = {
    "policyDoc": "docs/product/v3/w6-plan-validation-policy.md",
    "validationPhase": "before-execution",
    "onInvalidPlan": "fail-closed-user-visible",
    "blocksExecution": True,
    "autoRetryAllowed": False,
    "autoSimplificationAllowed": False,
    "userRetryAllowed": True,
    "invalidPlanEvidence": "required",
    "runtimePlannerImplementation": "not-started",
}
APPROVAL_POLICY_BASE = {
    "policyDoc": "docs/product/v3/w6-approval-policy.md",
    "defaultMode": "whole-task",
    "perStepRequiresExplicitUserChoice": True,
    "implicitPerStepPromptsAllowed": False,
    "reviewStepRequired": True,
    "approvalEvidence": "user-approval",
    "runtimeApprovalUiImplementation": "not-started",
}
RESUME_POLICY = {
    "policyDoc": "docs/product/v3/w6-resume-policy.md",
    "crossSessionResumeAllowed": True,
    "resumePoint": "evidence-complete-checkpoint",
    "requiresUserConfirmation": True,
    "requiresDocumentHashMatch": True,
    "requiresShadowSnapshot": True,
    "requiresAuditReplay": True,
    "autoResumeAllowed": False,
    "staleCheckpointBehavior": "fail-closed-user-visible",
    "checkpointEvidence": "required",
    "runtimeResumeImplementation": "not-started",
}
SHADOW_DOC_POLICY = {
    "policyDoc": "docs/product/v3/w6-shadow-doc-policy.md",
    "shadowDocMode": "per-step-compatible-branch",
    "writerCompatibilityTarget": "v2-w3-swdocshell",
    "requiresExistingSwDocShellCompatibility": True,
    "createsNewDocShellType": False,
    "mergePath": "v2-apply-plan-runtime",
    "mainDocMutationBeforeApprovalAllowed": False,
    "mergeRequiresApproval": True,
    "runtimeShadowDocImplementation": "not-started",
}
PROMPT_POLICY = {
    "policyDoc": "docs/product/v3/w6-prompt-library.md",
    "promptSetId": "w6-plan-act-observe-v1",
    "promptSetVersion": "v1",
    "plannerPromptId": "planner-v1",
    "actorPromptId": "actor-v1",
    "observerPromptId": "observer-v1",
    "deterministicParameters": {
        "temperature": 0,
        "topP": 1,
        "seedRequired": True,
    },
    "publicEgressAllowed": False,
    "runtimePromptExecution": "not-started",
}


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


def semantic_errors(plan: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    steps = plan.get("steps", [])
    max_steps = plan.get("maxSteps")
    data_boundary = plan.get("dataBoundary", {})
    sandbox = plan.get("sandbox", {})
    dependency_policy = plan.get("dependencyPolicy", {})
    planner_validation = plan.get("plannerValidation", {})
    approval_policy = plan.get("approvalPolicy", {})
    resume_policy = plan.get("resumePolicy", {})
    shadow_doc_policy = plan.get("shadowDocPolicy", {})
    prompt_policy = plan.get("promptPolicy", {})
    token_lock = plan.get("tokenLock", {})
    root_evidence = plan.get("evidence", {})

    if max_steps != len(steps):
        errors.append("maxSteps must equal the fixture step count")
    if len(steps) > 25:
        errors.append("steps exceed hard limit 25")
    if data_boundary.get("allowPublicEgress") is not False:
        errors.append("agent plans must not allow public egress by default")
    if data_boundary.get("requiresPolicyPreflight") is not True:
        errors.append("agent plans must require policy preflight")
    if sandbox.get("mode") != "shadow-doc":
        errors.append("sandbox.mode must be shadow-doc")
    if sandbox.get("mergeTarget") != "main-doc":
        errors.append("sandbox.mergeTarget must be main-doc")
    if sandbox.get("failureIsolation") != "discard-step-branch":
        errors.append("failureIsolation must discard the failed step branch")
    if dependency_policy != DEPENDENCY_POLICY:
        errors.append("dependencyPolicy drifted from forward-only DAG contract")
    if planner_validation != PLANNER_VALIDATION_POLICY:
        errors.append("plannerValidation drifted from fail-closed invalid-plan contract")
    if approval_policy.get("policyDoc") != APPROVAL_POLICY_BASE["policyDoc"]:
        errors.append("approvalPolicy policy doc drifted")
    if approval_policy.get("defaultMode") != "whole-task":
        errors.append("approvalPolicy default must be whole-task")
    if approval_policy.get("perStepRequiresExplicitUserChoice") is not True:
        errors.append("per-step approval must require explicit user choice")
    if approval_policy.get("implicitPerStepPromptsAllowed") is not False:
        errors.append("implicit per-step prompts must be forbidden")
    if approval_policy.get("reviewStepRequired") is not True:
        errors.append("approval policy must require a review step")
    if approval_policy.get("approvalEvidence") != "user-approval":
        errors.append("approval policy must use user-approval evidence")
    if approval_policy.get("runtimeApprovalUiImplementation") != "not-started":
        errors.append("approval UI runtime must remain not-started")
    approval_mode = plan.get("approvalMode")
    selected_source = approval_policy.get("selectedModeSource")
    prompt_strategy = approval_policy.get("promptStrategy")
    if approval_mode == "whole-task":
        if selected_source != "default-whole-task":
            errors.append("whole-task approval must use the default-whole-task source")
        if prompt_strategy != "final-review-only":
            errors.append("whole-task approval must use final-review-only prompts")
    elif approval_mode == "per-step":
        if selected_source != "explicit-user-choice":
            errors.append("per-step approval must come from explicit user choice")
        if prompt_strategy != "explicit-per-step-review":
            errors.append("per-step approval must use explicit-per-step-review prompts")
    else:
        errors.append("approvalMode must be whole-task or per-step")
    if resume_policy != RESUME_POLICY:
        errors.append("resumePolicy drifted from evidence-complete checkpoint contract")
    if shadow_doc_policy != SHADOW_DOC_POLICY:
        errors.append("shadowDocPolicy drifted from SwDocShell-compatible shadow-doc contract")
    if prompt_policy != PROMPT_POLICY:
        errors.append("promptPolicy drifted from deterministic Plan-Act-Observe prompt contract")
    if token_lock.get("patchStepMustUseApplyPlanRuntime") is not True:
        errors.append("patch steps must use ApplyPlan runtime")
    if token_lock.get("tokenCounts") != TOKEN_LOCK:
        errors.append("tokenCounts drifted from V2 token lock")
    if set(root_evidence.get("requiredForEveryStep", [])) != ROOT_EVIDENCE:
        errors.append("root evidence requirements drifted")
    if root_evidence.get("auditLogRequired") is not True:
        errors.append("auditLogRequired must be true")
    if root_evidence.get("blocksMergeOnMissingEvidence") is not True:
        errors.append("missing evidence must block merge")

    seen_indices: set[int] = set()
    patch_steps = 0
    review_steps = 0
    fan_in_seen = False
    fan_out_sources: dict[int, int] = {}
    for offset, step in enumerate(steps):
        index = step.get("index")
        if index != offset:
            errors.append(f"step index must be sequential: expected {offset}, saw {index!r}")
        if index in seen_indices:
            errors.append(f"duplicate step index {index}")
        seen_indices.add(index)
        deps = step.get("dependencies", [])
        for dep in deps:
            if not isinstance(dep, int) or dep < 0 or dep >= offset:
                errors.append(f"step {index} dependency {dep!r} must point to an earlier step")
            else:
                fan_out_sources[dep] = fan_out_sources.get(dep, 0) + 1
        if len(deps) > 1:
            fan_in_seen = True
        evidence = set(step.get("evidence", []))
        if "policy-decision" not in evidence:
            errors.append(f"step {index} missing policy-decision evidence")
        policy = step.get("policy", {})
        if policy.get("preflight") is not True or policy.get("auditLog") is not True:
            errors.append(f"step {index} must require policy preflight and audit log")
        expected = step.get("expectedOutput", {})
        kind = step.get("kind")
        if kind == "patch":
            patch_steps += 1
            if expected.get("kind") != "apply-plan-runtime" or expected.get("schemaRef") != "apply-plan-runtime":
                errors.append(f"patch step {index} must output apply-plan-runtime")
            missing = PATCH_EVIDENCE - evidence
            if missing:
                errors.append(f"patch step {index} missing evidence {sorted(missing)}")
        if kind == "review":
            review_steps += 1
            if expected.get("kind") != "approval-decision" or expected.get("schemaRef") != "user-approval":
                errors.append(f"review step {index} must output user approval")
            if "user-approval" not in evidence:
                errors.append(f"review step {index} missing user-approval evidence")
    if patch_steps == 0:
        errors.append("valid agent plans must contain at least one patch step")
    if review_steps == 0:
        errors.append("valid agent plans must contain at least one review step")
    if steps and not fan_in_seen and plan.get("ownerSurface") == "writer":
        errors.append("writer fixture must retain fan-in coverage")
    if steps and not any(count > 1 for count in fan_out_sources.values()) and plan.get("ownerSurface") == "writer":
        errors.append("writer fixture must retain fan-out coverage")
    return errors


schema = load(schema_path)
if not isinstance(schema, dict):
    die("agent-step-plan schema top-level is not an object")

pass_count = 0

if schema.get("required") != EXPECTED_REQUIRED:
    die(f"schema.required drifted: {schema.get('required')!r}")
if schema.get("additionalProperties") is not False:
    die("schema must set top-level additionalProperties:false")
props = schema.get("properties", {})
if props.get("steps", {}).get("maxItems") != 25:
    die("steps.maxItems must be 25")
if props.get("maxSteps", {}).get("maximum") != 25:
    die("maxSteps.maximum must be 25")
pass_count += 1

if props.get("sandbox", {}).get("properties", {}).get("mode", {}).get("const") != "shadow-doc":
    die("sandbox.mode const drifted")
dependency_props = props.get("dependencyPolicy", {}).get("properties", {})
for key, expected in DEPENDENCY_POLICY.items():
    if dependency_props.get(key, {}).get("const") != expected:
        die(f"dependencyPolicy.{key} const drifted")
planner_props = props.get("plannerValidation", {}).get("properties", {})
for key, expected in PLANNER_VALIDATION_POLICY.items():
    if planner_props.get(key, {}).get("const") != expected:
        die(f"plannerValidation.{key} const drifted")
approval_props = props.get("approvalPolicy", {}).get("properties", {})
for key, expected in APPROVAL_POLICY_BASE.items():
    if approval_props.get(key, {}).get("const") != expected:
        die(f"approvalPolicy.{key} const drifted")
if approval_props.get("selectedModeSource", {}).get("enum") != ["default-whole-task", "explicit-user-choice"]:
    die("approvalPolicy.selectedModeSource enum drifted")
if approval_props.get("promptStrategy", {}).get("enum") != ["final-review-only", "explicit-per-step-review"]:
    die("approvalPolicy.promptStrategy enum drifted")
resume_props = props.get("resumePolicy", {}).get("properties", {})
for key, expected in RESUME_POLICY.items():
    if resume_props.get(key, {}).get("const") != expected:
        die(f"resumePolicy.{key} const drifted")
shadow_doc_props = props.get("shadowDocPolicy", {}).get("properties", {})
for key, expected in SHADOW_DOC_POLICY.items():
    if shadow_doc_props.get(key, {}).get("const") != expected:
        die(f"shadowDocPolicy.{key} const drifted")
prompt_props = props.get("promptPolicy", {}).get("properties", {})
for key, expected in PROMPT_POLICY.items():
    if key == "deterministicParameters":
        param_props = prompt_props.get(key, {}).get("properties", {})
        for param_key, param_expected in expected.items():
            if param_props.get(param_key, {}).get("const") != param_expected:
                die(f"promptPolicy.deterministicParameters.{param_key} const drifted")
    elif prompt_props.get(key, {}).get("const") != expected:
        die(f"promptPolicy.{key} const drifted")
if props.get("dataBoundary", {}).get("properties", {}).get("allowPublicEgress", {}).get("const") is not False:
    die("allowPublicEgress const drifted")
token_props = props.get("tokenLock", {}).get("properties", {}).get("tokenCounts", {}).get("properties", {})
for key, expected in TOKEN_LOCK.items():
    if token_props.get(key, {}).get("const") != expected:
        die(f"{key} token lock drifted")
pass_count += 1

dependency_text = w6_dependency_policy.read_text(encoding="utf-8")
for needle in [
    "forward-only-dag",
    "topological-index",
    "Allows cycles",
    "Allows future dependencies",
    "Allows parallel runtime",
    "not-started",
]:
    if needle not in dependency_text:
        die(f"{w6_dependency_policy} missing {needle!r}")
pass_count += 1

planner_validation_text = w6_plan_validation_policy.read_text(encoding="utf-8")
for needle in [
    "before-execution",
    "fail-closed-user-visible",
    "Auto retry allowed",
    "Auto simplification allowed",
    "Invalid plan evidence",
    "not-started",
]:
    if needle not in planner_validation_text:
        die(f"{w6_plan_validation_policy} missing {needle!r}")
pass_count += 1

approval_text = w6_approval_policy.read_text(encoding="utf-8")
for needle in [
    "whole-task",
    "explicit-user-choice",
    "Implicit per-step prompts allowed",
    "final-review-only",
    "explicit-per-step-review",
    "not-started",
]:
    if needle not in approval_text:
        die(f"{w6_approval_policy} missing {needle!r}")
pass_count += 1

resume_text = w6_resume_policy.read_text(encoding="utf-8")
for needle in [
    "evidence-complete-checkpoint",
    "Requires document hash match",
    "Requires shadow snapshot",
    "Auto resume allowed",
    "fail-closed-user-visible",
    "not-started",
]:
    if needle not in resume_text:
        die(f"{w6_resume_policy} missing {needle!r}")
pass_count += 1

shadow_doc_text = w6_shadow_doc_policy.read_text(encoding="utf-8")
for needle in [
    "per-step-compatible-branch",
    "v2-w3-swdocshell",
    "SwDocShell",
    "Creates new DocShell type",
    "Main document mutation before approval",
    "not-started",
]:
    if needle not in shadow_doc_text:
        die(f"{w6_shadow_doc_policy} missing {needle!r}")
pass_count += 1

prompt_text = w6_prompt_library.read_text(encoding="utf-8")
for needle in [
    "w6-plan-act-observe-v1",
    "planner-v1",
    "actor-v1",
    "observer-v1",
    "Temperature",
    "Public egress allowed",
    "not-started",
]:
    if needle not in prompt_text:
        die(f"{w6_prompt_library} missing {needle!r}")
pass_count += 1

valid_paths = sorted(valid_dir.glob("*.json"))
invalid_paths = sorted(invalid_dir.glob("*.json"))
if {path.name for path in valid_paths} != EXPECTED_VALID_FILES:
    die(f"valid fixture roster drifted: {[path.name for path in valid_paths]!r}")
if {path.name for path in invalid_paths} != EXPECTED_INVALID_FILES:
    die(f"invalid fixture roster drifted: {[path.name for path in invalid_paths]!r}")
pass_count += 1

seen_surfaces: set[str] = set()
for path in valid_paths:
    plan = load(path)
    if not isinstance(plan, dict):
        die(f"{path} top-level must be object")
    schema_errors = validate(plan, schema, [])
    if schema_errors:
        die(f"{path} violates schema:\n" + "\n".join(schema_errors))
    errors = semantic_errors(plan)
    if errors:
        die(f"{path} violates W6 semantics:\n" + "\n".join(errors))
    seen_surfaces.add(plan["ownerSurface"])
pass_count += 1

if seen_surfaces != EXPECTED_SURFACES:
    die(f"valid fixtures must cover writer/calc/impress, saw {sorted(seen_surfaces)}")
pass_count += 1

for path in invalid_paths:
    plan = load(path)
    if not isinstance(plan, dict):
        die(f"{path} top-level must be object")
    schema_errors = validate(plan, schema, [])
    errors = semantic_errors(plan)
    if not schema_errors and not errors:
        die(f"{path} unexpectedly passed schema+semantic validation")
pass_count += 1

texts = {
    w6_spec: w6_spec.read_text(encoding="utf-8"),
    w6_dependency_policy: dependency_text,
    w6_plan_validation_policy: planner_validation_text,
    w6_approval_policy: approval_text,
    w6_resume_policy: resume_text,
    w6_shadow_doc_policy: shadow_doc_text,
    w6_prompt_library: prompt_text,
    w5_spec: w5_spec.read_text(encoding="utf-8"),
    master_plan: master_plan.read_text(encoding="utf-8"),
    sweep_path: sweep_path.read_text(encoding="utf-8"),
    workflow_path: workflow_path.read_text(encoding="utf-8"),
}
expected_needles = {
    w6_spec: ["agent-step-plan.schema.json", "w6-dependency-policy.md", "w6-plan-validation-policy.md", "w6-approval-policy.md", "w6-resume-policy.md", "w6-shadow-doc-policy.md", "w6-prompt-library.md", "agent-step-plan self-test", "Checks: 13", "fail-closed", "forward-only DAG", "whole-task approval", "evidence-complete checkpoint", "SwDocShell-compatible ShadowDoc", "deterministic prompt policy", "ParagraphAction=7"],
    w6_dependency_policy: ["forward-only-dag", "topological-index", "runtime scheduler not started"],
    w6_plan_validation_policy: ["before-execution", "fail-closed-user-visible", "planner runtime not started"],
    w6_approval_policy: ["whole-task", "explicit-user-choice", "approval UI runtime not started"],
    w6_resume_policy: ["evidence-complete-checkpoint", "fail-closed-user-visible", "resume runtime not started"],
    w6_shadow_doc_policy: ["per-step-compatible-branch", "v2-w3-swdocshell", "shadow doc runtime not started"],
    w6_prompt_library: ["w6-plan-act-observe-v1", "planner-v1", "prompt runtime not started"],
    w5_spec: ["tests/v3-agent-step-plan-test.sh", "agent-step-plan self-test", "Checks: 13"],
    master_plan: ["agent-step-plan.schema.json", "w6-dependency-policy.md", "w6-plan-validation-policy.md", "w6-approval-policy.md", "w6-resume-policy.md", "w6-shadow-doc-policy.md", "w6-prompt-library.md", "tests/v3-agent-step-plan-test.sh", "agent-step-plan self-test", "13 checks"],
    sweep_path: ["tests/v3-agent-step-plan-test.sh", "W6 agent-step-plan self-test"],
    workflow_path: ["docs/schemas/agent-step-plan.schema.json", "bin/v3-eval-sweep.sh --self-test"],
}
for path, needles in expected_needles.items():
    text = texts[path]
    for needle in needles:
        if needle not in text:
            die(f"{path} missing {needle!r}")
pass_count += 1

print("Status: passed")
print("Harness: W6 agent-step-plan self-test")
print(f"Schema: {schema_path}")
print(f"Valid fixtures: {len(valid_paths)}")
print(f"Invalid fixtures: {len(invalid_paths)}")
print("Token lock: ParagraphAction=7 CellAction=5 SlideElementAction=4")
print("Dependency policy: forward-only-dag topological-index no runtime parallelism")
print("Planner validation: fail-closed-user-visible no silent retry")
print("Approval policy: whole-task default explicit per-step opt-in")
print("Resume policy: evidence-complete checkpoint no auto resume")
print("ShadowDoc policy: SwDocShell-compatible no new DocShell runtime")
print("Prompt policy: deterministic Plan-Act-Observe no public egress")
print("Runtime implementation: deferred until W6 gate")
print(f"Checks: {pass_count}")
PY
