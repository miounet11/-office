#!/usr/bin/env bash
# V3 W4 - audit-log-entry contract self-test.
#
# Contract-first gate for W4. It does not start the gated PolicyEngine,
# AuditLog writer, AuditSink, or TenantContext implementation. It locks
# the append-only audit entry envelope, evidence linkage, redaction rule,
# hash-chain fields, policy decisions, and schema-collapse boundary.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

schema="docs/schemas/audit-log-entry.schema.json"
evidence_schema="docs/schemas/evidence-record.schema.json"
w4_spec="docs/product/v3/w4-tenant-policy-audit-spec.md"
w5_spec="docs/product/v3/w5-eval-harness-spec.md"
master_plan="docs/product/v3-master-plan.md"
sweep="bin/v3-eval-sweep.sh"
workflow=".github/workflows/v3-contract-harnesses.yml"
valid_dir="docs/qa/fixtures/v3/audit-log-entry/valid"
invalid_dir="docs/qa/fixtures/v3/audit-log-entry/invalid"

[[ -f "$schema" ]] || fail "missing $schema"
[[ -f "$evidence_schema" ]] || fail "missing $evidence_schema"
[[ -f "$w4_spec" ]] || fail "missing $w4_spec"
[[ -f "$w5_spec" ]] || fail "missing $w5_spec"
[[ -f "$master_plan" ]] || fail "missing $master_plan"
[[ -f "$sweep" ]] || fail "missing $sweep"
[[ -f "$workflow" ]] || fail "missing $workflow"
[[ -d "$valid_dir" ]] || fail "missing $valid_dir"
[[ -d "$invalid_dir" ]] || fail "missing $invalid_dir"

python3 - "$schema" "$evidence_schema" "$w4_spec" "$w5_spec" "$master_plan" "$sweep" "$workflow" "$valid_dir" "$invalid_dir" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

schema_path = Path(sys.argv[1])
evidence_schema_path = Path(sys.argv[2])
w4_spec = Path(sys.argv[3])
w5_spec = Path(sys.argv[4])
master_plan = Path(sys.argv[5])
sweep_path = Path(sys.argv[6])
workflow_path = Path(sys.argv[7])
valid_dir = Path(sys.argv[8])
invalid_dir = Path(sys.argv[9])

EXPECTED_REQUIRED = [
    "id",
    "schemaVersion",
    "timestamp",
    "tenant",
    "workspace",
    "actor",
    "action",
    "evidenceId",
    "policyDecision",
    "approvalChain",
    "redaction",
    "chain",
]
EXPECTED_VALID_FILES = {
    "chat-private-allow.json",
    "patch-apply-require-approval.json",
    "connector-fetch-deny.json",
}
EXPECTED_INVALID_FILES = {
    "missing-evidence-id.json",
    "stores-document-content.json",
    "collapsed-evidence-record-fields.json",
}
EXPECTED_ACTIONS = {"chat", "patch-apply", "connector-fetch"}
EXPECTED_DECISIONS = {"allow", "require-approval", "deny"}
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

    if isinstance(value, list):
        min_items = schema.get("minItems")
        if isinstance(min_items, int) and len(value) < min_items:
            errors.append(f"{json_pointer(path)} has fewer than minItems {min_items}")
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


def semantic_errors(entry: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    action = entry.get("action", {})
    redaction = entry.get("redaction", {})
    chain = entry.get("chain", {})
    decision = entry.get("policyDecision")
    approval_chain = entry.get("approvalChain", [])

    if action.get("publicEgress") is not False:
        errors.append("audit entries must not record public egress as allowed")
    if redaction.get("storesDocumentContent") is not False:
        errors.append("audit entries must not store document content")
    if redaction.get("hashAlgorithm") != "sha256":
        errors.append("redaction hash algorithm drifted")
    if chain.get("algorithm") != "sha256":
        errors.append("chain algorithm drifted")
    if decision == "require-approval" and not approval_chain:
        errors.append("require-approval decision must include approvalChain")
    if decision != "require-approval" and approval_chain:
        errors.append("only require-approval entries may include approvalChain")
    for key in FORBIDDEN_EVIDENCE_FIELDS:
        if key in entry:
            errors.append(f"audit-log-entry must not embed evidence-record field {key!r}")
    return errors


schema = load(schema_path)
evidence_schema = load(evidence_schema_path)
if not isinstance(schema, dict):
    die("audit schema top-level is not an object")
if not isinstance(evidence_schema, dict):
    die("evidence schema top-level is not an object")

pass_count = 0

if schema.get("required") != EXPECTED_REQUIRED:
    die(f"schema.required drifted: {schema.get('required')!r}")
if schema.get("additionalProperties") is not False:
    die("schema must set top-level additionalProperties:false")
pass_count += 1

props = schema.get("properties", {})
if props.get("evidenceId", {}).get("pattern") != "^ev-[0-9a-f]{16}$":
    die("evidenceId pattern must match V2 evidence id shape")
if props.get("redaction", {}).get("properties", {}).get("storesDocumentContent", {}).get("const") is not False:
    die("storesDocumentContent must be const false")
if props.get("chain", {}).get("properties", {}).get("previousHash", {}).get("pattern") != "^(GENESIS|[0-9a-f]{64})$":
    die("previousHash pattern drifted")
if set(props).intersection(FORBIDDEN_EVIDENCE_FIELDS):
    die("audit schema top-level collapsed evidence-record fields")
pass_count += 1

valid_paths = sorted(valid_dir.glob("*.json"))
invalid_paths = sorted(invalid_dir.glob("*.json"))
if {path.name for path in valid_paths} != EXPECTED_VALID_FILES:
    die(f"valid fixture roster drifted: {[path.name for path in valid_paths]!r}")
if {path.name for path in invalid_paths} != EXPECTED_INVALID_FILES:
    die(f"invalid fixture roster drifted: {[path.name for path in invalid_paths]!r}")
pass_count += 1

actions: set[str] = set()
decisions: set[str] = set()
valid_entries: list[tuple[Path, dict[str, Any]]] = []
previous_hash = "GENESIS"
for path in valid_paths:
    entry = load(path)
    if not isinstance(entry, dict):
        die(f"{path} top-level must be object")
    schema_errors = validate(entry, schema, [])
    if schema_errors:
        die(f"{path} violates schema:\n" + "\n".join(schema_errors))
    errors = semantic_errors(entry)
    if errors:
        die(f"{path} violates W4 semantics:\n" + "\n".join(errors))
    actions.add(entry["action"]["type"])
    decisions.add(entry["policyDecision"])
    valid_entries.append((path, entry))

for path, entry in sorted(valid_entries, key=lambda item: (item[1]["timestamp"], item[1]["id"])):
    if entry["chain"]["previousHash"] != previous_hash:
        die(f"{path} hash-chain previousHash drifted")
    previous_hash = entry["chain"]["entryHash"]
pass_count += 1

if actions != EXPECTED_ACTIONS:
    die(f"valid fixtures must cover {sorted(EXPECTED_ACTIONS)}, saw {sorted(actions)}")
if decisions != EXPECTED_DECISIONS:
    die(f"valid fixtures must cover {sorted(EXPECTED_DECISIONS)}, saw {sorted(decisions)}")
pass_count += 1

for path in invalid_paths:
    entry = load(path)
    if not isinstance(entry, dict):
        die(f"{path} top-level must be object")
    schema_errors = validate(entry, schema, [])
    errors = semantic_errors(entry)
    if not schema_errors and not errors:
        die(f"{path} unexpectedly passed schema+semantic validation")
pass_count += 1

w4_text = w4_spec.read_text(encoding="utf-8")
w5_text = w5_spec.read_text(encoding="utf-8")
master_text = master_plan.read_text(encoding="utf-8")
sweep_text = sweep_path.read_text(encoding="utf-8")
workflow_text = workflow_path.read_text(encoding="utf-8")
for path, text, needles in [
    (w4_spec, w4_text, ["audit-log-entry self-test", "Checks: 7", "ev-[0-9a-f]{16}", "append-only", "storesDocumentContent"]),
    (w5_spec, w5_text, ["tests/v3-audit-log-entry-test.sh", "audit-log-entry self-test"]),
    (master_plan, master_text, ["audit-log-entry.schema.json", "tests/v3-audit-log-entry-test.sh", "audit-log-entry self-test"]),
    (sweep_path, sweep_text, ["tests/v3-audit-log-entry-test.sh", "W4 audit-log-entry self-test"]),
    (workflow_path, workflow_text, ["docs/schemas/audit-log-entry.schema.json", "bin/v3-eval-sweep.sh --self-test"]),
]:
    for needle in needles:
        if needle not in text:
            die(f"{path} missing {needle!r}")
pass_count += 1

print("Status: passed")
print("Harness: W4 audit-log-entry self-test")
print(f"Schema: {schema_path}")
print(f"Valid fixtures: {len(valid_paths)}")
print(f"Invalid fixtures: {len(invalid_paths)}")
print("Evidence link: ev-<16 hex>, no evidence-record field embedding")
print("Runtime implementation: deferred until W4 gate")
print(f"Checks: {pass_count}")
PY
