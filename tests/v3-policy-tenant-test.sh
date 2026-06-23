#!/usr/bin/env bash
# V3 W4 - policy-rule + tenant-context contract self-test.
#
# Contract-first gate for W4 policy/tenant envelopes. It does not start the
# gated TenantContext, PolicyEngine, RuleParser, AuditLog, AuditSink, or
# admin-panel implementation. It locks tenant isolation, local-only policy
# defaults, effect/enforcement semantics, evidence requirements, and
# schema-collapse boundaries.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

tenant_schema="docs/schemas/tenant-context.schema.json"
policy_schema="docs/schemas/policy-rule.schema.json"
w4_spec="docs/product/v3/w4-tenant-policy-audit-spec.md"
w5_spec="docs/product/v3/w5-eval-harness-spec.md"
master_plan="docs/product/v3-master-plan.md"
sweep="bin/v3-eval-sweep.sh"
workflow=".github/workflows/v3-contract-harnesses.yml"
valid_dir="docs/qa/fixtures/v3/policy-tenant/valid"
invalid_dir="docs/qa/fixtures/v3/policy-tenant/invalid"

[[ -f "$tenant_schema" ]] || fail "missing $tenant_schema"
[[ -f "$policy_schema" ]] || fail "missing $policy_schema"
[[ -f "$w4_spec" ]] || fail "missing $w4_spec"
[[ -f "$w5_spec" ]] || fail "missing $w5_spec"
[[ -f "$master_plan" ]] || fail "missing $master_plan"
[[ -f "$sweep" ]] || fail "missing $sweep"
[[ -f "$workflow" ]] || fail "missing $workflow"
[[ -d "$valid_dir" ]] || fail "missing $valid_dir"
[[ -d "$invalid_dir" ]] || fail "missing $invalid_dir"

python3 - "$tenant_schema" "$policy_schema" "$w4_spec" "$w5_spec" "$master_plan" "$sweep" "$workflow" "$valid_dir" "$invalid_dir" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

tenant_schema_path = Path(sys.argv[1])
policy_schema_path = Path(sys.argv[2])
w4_spec = Path(sys.argv[3])
w5_spec = Path(sys.argv[4])
master_plan = Path(sys.argv[5])
sweep_path = Path(sys.argv[6])
workflow_path = Path(sys.argv[7])
valid_dir = Path(sys.argv[8])
invalid_dir = Path(sys.argv[9])

TENANT_REQUIRED = ["id", "schemaVersion", "createdAt", "tenant", "workspace", "users", "dataBoundary", "audit"]
POLICY_REQUIRED = ["id", "schemaVersion", "priority", "phase", "effect", "when", "enforcement", "evidence"]
EXPECTED_VALID_FILES = {
    "offline-deny-cloud-connector.json",
    "tenant-private-provider-allow.json",
    "secret-agent-step-require-approval.json",
    "chat-require-evidence-post.json",
}
EXPECTED_INVALID_FILES = {
    "tenant-allows-public-egress.json",
    "policy-effect-enforcement-drift.json",
    "collapsed-evidence-fields.json",
}
EXPECTED_EFFECTS = {"allow", "deny", "require-approval", "require-evidence"}
EXPECTED_PHASES = {"pre-flight", "post-evidence"}
FORBIDDEN_EVIDENCE_FIELDS = {
    "schema_version",
    "capability_id",
    "source",
    "elapsed_ms",
    "budget_status",
    "diagnostic_count",
    "validator_status",
    "compatibility_status",
    "failure_reason_zh",
    "stores_document_content",
}
BASE_EVIDENCE = {"policy-decision", "audit-log-entry", "evidence-record"}


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


def find_forbidden_fields(value: Any, path: list[str]) -> list[str]:
    errors: list[str] = []
    if isinstance(value, dict):
        for key, child in value.items():
            if key in FORBIDDEN_EVIDENCE_FIELDS:
                errors.append(f"{json_pointer(path + [key])} must not embed evidence-record fields")
            errors.extend(find_forbidden_fields(child, path + [key]))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            errors.extend(find_forbidden_fields(child, path + [str(index)]))
    return errors


def semantic_errors(pair: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    tenant = pair.get("tenantContext", {})
    policy = pair.get("policyRule", {})
    boundary = tenant.get("dataBoundary", {})
    audit = tenant.get("audit", {})
    workspace = tenant.get("workspace", {})
    when = policy.get("when", {})
    enforcement = policy.get("enforcement", {})
    evidence = policy.get("evidence", {})
    effect = policy.get("effect")

    errors.extend(find_forbidden_fields(pair, []))
    if boundary.get("publicEgressDefault") is not False:
        errors.append("tenant publicEgressDefault must be false")
    if boundary.get("tenantIsolation") is not True:
        errors.append("tenantIsolation must be true")
    if boundary.get("localOnlyAdminPanel") is not True:
        errors.append("admin panel must remain local-only")
    if "cloud" in set(boundary.get("allowedServiceModes", [])):
        errors.append("tenant allowedServiceModes must not include cloud")
    if audit.get("appendOnly") is not True or audit.get("hashChainRequired") is not True:
        errors.append("audit must be append-only with hash chain")
    if audit.get("sinkPort") != 17803:
        errors.append("audit sinkPort must stay 17803")
    tenant_id = tenant.get("tenant", {}).get("id")
    if tenant_id not in set(when.get("tenants", [])):
        errors.append("policy tenants must include tenantContext.tenant.id")
    allowed_modes = set(boundary.get("allowedServiceModes", []))
    if not set(when.get("serviceModes", [])).issubset(allowed_modes):
        errors.append("policy serviceModes must be subset of tenant allowedServiceModes")
    if not set(when.get("dataClasses", [])).issubset(set(workspace.get("dataClasses", []))):
        errors.append("policy dataClasses must be subset of workspace dataClasses")
    if enforcement.get("auditLogRequired") is not True:
        errors.append("policy enforcement must require audit log")
    if evidence.get("emitsAuditLog") is not True or evidence.get("evidenceRecordRequired") is not True:
        errors.append("policy evidence must emit audit log and require evidence-record")
    required_evidence = set(evidence.get("required", []))
    if not BASE_EVIDENCE.issubset(required_evidence):
        errors.append("policy evidence requirements drifted")

    if effect == "deny":
        if enforcement.get("blocksAction") is not True or enforcement.get("approvalRequired") is not False:
            errors.append("deny effect must block action and not request approval")
    elif effect == "allow":
        if enforcement.get("blocksAction") is not False or enforcement.get("approvalRequired") is not False:
            errors.append("allow effect must not block or require approval")
    elif effect == "require-approval":
        if enforcement.get("blocksAction") is not True or enforcement.get("approvalRequired") is not True:
            errors.append("require-approval effect must block until approval")
        if "user-approval" not in required_evidence:
            errors.append("require-approval must require user-approval evidence")
    elif effect == "require-evidence":
        if policy.get("phase") != "post-evidence":
            errors.append("require-evidence must be post-evidence")
        if enforcement.get("blocksAction") is not False or enforcement.get("approvalRequired") is not False:
            errors.append("require-evidence must not block or request approval")
    return errors


tenant_schema = load(tenant_schema_path)
policy_schema = load(policy_schema_path)
if not isinstance(tenant_schema, dict) or not isinstance(policy_schema, dict):
    die("schema top-level must be objects")

pass_count = 0

if tenant_schema.get("required") != TENANT_REQUIRED:
    die(f"tenant schema.required drifted: {tenant_schema.get('required')!r}")
if tenant_schema.get("additionalProperties") is not False:
    die("tenant schema must set top-level additionalProperties:false")
t_props = tenant_schema.get("properties", {})
if t_props.get("dataBoundary", {}).get("properties", {}).get("publicEgressDefault", {}).get("const") is not False:
    die("tenant publicEgressDefault must be const false")
if t_props.get("dataBoundary", {}).get("properties", {}).get("tenantIsolation", {}).get("const") is not True:
    die("tenantIsolation must be const true")
if t_props.get("audit", {}).get("properties", {}).get("sinkPort", {}).get("const") != 17803:
    die("audit sinkPort must be 17803")
pass_count += 1

if policy_schema.get("required") != POLICY_REQUIRED:
    die(f"policy schema.required drifted: {policy_schema.get('required')!r}")
if policy_schema.get("additionalProperties") is not False:
    die("policy schema must set top-level additionalProperties:false")
p_props = policy_schema.get("properties", {})
if set(p_props.get("effect", {}).get("enum", [])) != EXPECTED_EFFECTS:
    die("policy effect enum drifted")
if p_props.get("enforcement", {}).get("properties", {}).get("auditLogRequired", {}).get("const") is not True:
    die("policy auditLogRequired must be const true")
if p_props.get("evidence", {}).get("properties", {}).get("emitsAuditLog", {}).get("const") is not True:
    die("policy emitsAuditLog must be const true")
pass_count += 1

valid_paths = sorted(valid_dir.glob("*.json"))
invalid_paths = sorted(invalid_dir.glob("*.json"))
if {path.name for path in valid_paths} != EXPECTED_VALID_FILES:
    die(f"valid fixture roster drifted: {[path.name for path in valid_paths]!r}")
if {path.name for path in invalid_paths} != EXPECTED_INVALID_FILES:
    die(f"invalid fixture roster drifted: {[path.name for path in invalid_paths]!r}")
pass_count += 1

effects: set[str] = set()
phases: set[str] = set()
for path in valid_paths:
    pair = load(path)
    if not isinstance(pair, dict) or not isinstance(pair.get("tenantContext"), dict) or not isinstance(pair.get("policyRule"), dict):
        die(f"{path} must contain tenantContext and policyRule objects")
    errors = validate(pair["tenantContext"], tenant_schema, ["tenantContext"]) + validate(pair["policyRule"], policy_schema, ["policyRule"])
    if errors:
        die(f"{path} violates schema:\n" + "\n".join(errors))
    semantic = semantic_errors(pair)
    if semantic:
        die(f"{path} violates W4 policy/tenant semantics:\n" + "\n".join(semantic))
    effects.add(pair["policyRule"]["effect"])
    phases.add(pair["policyRule"]["phase"])
pass_count += 1

if effects != EXPECTED_EFFECTS:
    die(f"valid fixtures must cover effects {sorted(EXPECTED_EFFECTS)}, saw {sorted(effects)}")
if phases != EXPECTED_PHASES:
    die(f"valid fixtures must cover phases {sorted(EXPECTED_PHASES)}, saw {sorted(phases)}")
pass_count += 1

for path in invalid_paths:
    pair = load(path)
    if not isinstance(pair, dict) or not isinstance(pair.get("tenantContext"), dict) or not isinstance(pair.get("policyRule"), dict):
        die(f"{path} must contain tenantContext and policyRule objects")
    schema_errors = validate(pair["tenantContext"], tenant_schema, ["tenantContext"]) + validate(pair["policyRule"], policy_schema, ["policyRule"])
    semantic = semantic_errors(pair)
    if not schema_errors and not semantic:
        die(f"{path} unexpectedly passed schema+semantic validation")
pass_count += 1

w4_text = w4_spec.read_text(encoding="utf-8")
w5_text = w5_spec.read_text(encoding="utf-8")
master_text = master_plan.read_text(encoding="utf-8")
sweep_text = sweep_path.read_text(encoding="utf-8")
workflow_text = workflow_path.read_text(encoding="utf-8")
for path, text, needles in [
    (w4_spec, w4_text, ["policy-tenant self-test", "Checks: 8", "sinkPort=17803", "tenantIsolation", "policy-rule"]),
    (w5_spec, w5_text, ["tests/v3-policy-tenant-test.sh", "policy-tenant self-test"]),
    (master_plan, master_text, ["policy-rule.schema.json", "tenant-context.schema.json", "tests/v3-policy-tenant-test.sh"]),
    (sweep_path, sweep_text, ["tests/v3-policy-tenant-test.sh", "W4 policy-tenant self-test"]),
    (workflow_path, workflow_text, ["docs/schemas/policy-rule.schema.json", "docs/schemas/tenant-context.schema.json", "bin/v3-eval-sweep.sh --self-test"]),
]:
    for needle in needles:
        if needle not in text:
            die(f"{path} missing {needle!r}")
pass_count += 1

if pass_count != 7:
    die(f"internal pass_count drifted before final increment: {pass_count}")
pass_count += 1

print("Status: passed")
print("Harness: W4 policy-tenant self-test")
print(f"Tenant schema: {tenant_schema_path}")
print(f"Policy schema: {policy_schema_path}")
print(f"Valid fixtures: {len(valid_paths)}")
print(f"Invalid fixtures: {len(invalid_paths)}")
print("Policy contract: tenantIsolation, effect enforcement, audit evidence")
print("Runtime implementation: deferred until W4 gate")
print(f"Checks: {pass_count}")
PY
