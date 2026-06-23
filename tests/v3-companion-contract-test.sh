#!/usr/bin/env bash
# V3 W7 - Companion contract self-test.
#
# Contract-first gate for W7 mobile companion envelopes. It does not start the
# gated CompanionBridge, PairingFlow, PushDispatcher, companion app, or native
# mobile implementation. It locks short pairing tokens, device binding,
# redacted diff summaries, online-only approvals, biometric confirmation,
# LAN-first push, explicit cloud-push opt-in, and no mobile document editing.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

pairing_schema="docs/schemas/companion-pairing-token.schema.json"
summary_schema="docs/schemas/companion-diff-summary.schema.json"
approval_schema="docs/schemas/companion-approval-request.schema.json"
w7_spec="docs/product/v3/w7-companion-spec.md"
w5_spec="docs/product/v3/w5-eval-harness-spec.md"
master_plan="docs/product/v3-master-plan.md"
sweep="bin/v3-eval-sweep.sh"
workflow=".github/workflows/v3-contract-harnesses.yml"
valid_dir="docs/qa/fixtures/v3/companion/valid"
invalid_dir="docs/qa/fixtures/v3/companion/invalid"

[[ -f "$pairing_schema" ]] || fail "missing $pairing_schema"
[[ -f "$summary_schema" ]] || fail "missing $summary_schema"
[[ -f "$approval_schema" ]] || fail "missing $approval_schema"
[[ -f "$w7_spec" ]] || fail "missing $w7_spec"
[[ -f "$w5_spec" ]] || fail "missing $w5_spec"
[[ -f "$master_plan" ]] || fail "missing $master_plan"
[[ -f "$sweep" ]] || fail "missing $sweep"
[[ -f "$workflow" ]] || fail "missing $workflow"
[[ -d "$valid_dir" ]] || fail "missing $valid_dir"
[[ -d "$invalid_dir" ]] || fail "missing $invalid_dir"

python3 - "$pairing_schema" "$summary_schema" "$approval_schema" "$w7_spec" "$w5_spec" "$master_plan" "$sweep" "$workflow" "$valid_dir" "$invalid_dir" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

pairing_schema_path = Path(sys.argv[1])
summary_schema_path = Path(sys.argv[2])
approval_schema_path = Path(sys.argv[3])
w7_spec = Path(sys.argv[4])
w5_spec = Path(sys.argv[5])
master_plan = Path(sys.argv[6])
sweep_path = Path(sys.argv[7])
workflow_path = Path(sys.argv[8])
valid_dir = Path(sys.argv[9])
invalid_dir = Path(sys.argv[10])

PAIRING_REQUIRED = ["id", "schemaVersion", "createdAt", "expiresAt", "tenant", "workspace", "desktop", "device", "transport", "token", "security", "dataBoundary", "evidence"]
SUMMARY_REQUIRED = ["id", "schemaVersion", "createdAt", "taskId", "stepResultId", "tenant", "workspace", "surface", "diff", "summary", "redaction", "mobile", "evidence"]
APPROVAL_REQUIRED = ["id", "schemaVersion", "createdAt", "expiresAt", "taskId", "summaryId", "pairingId", "tenant", "workspace", "actor", "channel", "request", "transport", "approval", "dataBoundary", "audit", "evidence"]
EXPECTED_VALID_FILES = {
    "lan-pairing-token.json",
    "enterprise-pairing-token.json",
    "writer-paragraph-diff-summary.json",
    "calc-cell-diff-summary.json",
    "impress-slide-diff-summary.json",
    "lan-approval-request.json",
    "enterprise-approval-request.json",
}
EXPECTED_INVALID_FILES = {
    "pairing-token-ttl-too-long.json",
    "diff-summary-stores-document-content.json",
    "approval-allows-offline.json",
    "approval-public-egress-without-opt-in.json",
}
PAIRING_EVIDENCE = {"companion-pairing-token", "user-pin-confirmation", "device-binding", "audit-log-entry"}
SUMMARY_EVIDENCE = {"companion-diff-summary", "shadow-doc-diff", "apply-plan-runtime-validated", "evidence-record", "audit-log-entry"}
APPROVAL_EVIDENCE = {"companion-approval-request", "user-approval", "biometric-confirmation", "audit-log-entry", "evidence-record"}
ACTION_BY_SURFACE = {
    "writer": ("paragraph", "ParagraphAction"),
    "calc": ("cell", "CellAction"),
    "impress": ("slide", "SlideElementAction"),
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


def fixture_kind(value: dict[str, Any]) -> str:
    version = value.get("schemaVersion")
    if version == "v3-companion-pairing-token/0.1":
        return "pairing"
    if version == "v3-companion-diff-summary/0.1":
        return "summary"
    if version == "v3-companion-approval-request/0.1":
        return "approval"
    return "unknown"


def schema_for(value: dict[str, Any], schemas: dict[str, dict[str, Any]]) -> dict[str, Any] | None:
    kind = fixture_kind(value)
    return schemas.get(kind)


def semantic_errors(value: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    kind = fixture_kind(value)
    evidence = set(value.get("evidence", {}).get("required", []))
    boundary = value.get("dataBoundary", {})
    if kind in {"pairing", "approval"}:
        if boundary.get("storesDocumentContent") is not False:
            errors.append("companion payloads must not store document content")
        if boundary.get("storesDiffSummaryOnly") is not True:
            errors.append("companion payloads must store only diff summaries")
        if boundary.get("allowApprovalOffline") is not False:
            errors.append("companion approvals must not be allowed offline")

    if kind == "pairing":
        transport = value.get("transport", {})
        token = value.get("token", {})
        security = value.get("security", {})
        if token.get("ttlSeconds", 9999) > 600 or token.get("sessionTtlHours") != 24:
            errors.append("pairing token must be <=10 min and session token must be 24h")
        if token.get("storesSecret") is not False:
            errors.append("pairing token must store only a hash")
        if value.get("device", {}).get("bindingRequired") is not True:
            errors.append("device binding must be required")
        if security.get("pinConfirmationRequired") is not True or security.get("mTLSRequired") is not True:
            errors.append("pairing must require PIN confirmation and mTLS")
        if not PAIRING_EVIDENCE.issubset(evidence):
            errors.append("pairing evidence requirements drifted")
        if transport.get("mode") == "lan-grpc":
            if transport.get("port") != 17801 or transport.get("publicEgress") is not False or transport.get("mdnsRequired") is not True:
                errors.append("LAN pairing must use local port 17801, mDNS, and no public egress")
        if transport.get("publicEgress") is True and transport.get("cloudPushOptIn") is not True:
            errors.append("public pairing egress requires explicit cloudPushOptIn")

    elif kind == "summary":
        surface = value.get("surface")
        diff = value.get("diff", {})
        summary = value.get("summary", {})
        mobile = value.get("mobile", {})
        redaction = value.get("redaction", {})
        expected = ACTION_BY_SURFACE.get(surface)
        if expected is None or (diff.get("summaryKind"), diff.get("actionKind")) != expected:
            errors.append("diff summary surface/action kind drifted")
        if diff.get("storesDocumentContent") is not False or diff.get("mobileParsesApplyPlan") is not False:
            errors.append("mobile diff summary must not store content or parse ApplyPlan")
        if mobile.get("viewOnly") is not True or mobile.get("canEdit") is not False or mobile.get("offlineApproval") is not False:
            errors.append("mobile summary must be view-only and approval-offline disabled")
        if redaction.get("containsOriginalText") is not False or redaction.get("hashAlgorithm") != "sha256":
            errors.append("diff summary redaction must be hash-only/redacted")
        for changed in summary.get("changedObjects", []):
            if changed.get("kind") != diff.get("summaryKind"):
                errors.append("changed object kind must match summary kind")
        if not SUMMARY_EVIDENCE.issubset(evidence):
            errors.append("diff summary evidence requirements drifted")

    elif kind == "approval":
        transport = value.get("transport", {})
        request = value.get("request", {})
        approval = value.get("approval", {})
        audit = value.get("audit", {})
        if value.get("channel") != "companion" or value.get("actor", {}).get("role") != "user":
            errors.append("approval request must be from user over companion channel")
        if request.get("requiresOnline") is not True:
            errors.append("approval request must require online state")
        if not {"approve", "reject"}.intersection(set(request.get("availableActions", []))):
            errors.append("approval request must include approve or reject")
        if approval.get("biometricRequired") is not True or approval.get("secondConfirmRequired") is not True:
            errors.append("approval request must require biometric and second confirmation")
        if approval.get("mobileMayEdit") is not False or approval.get("decisionWritesAudit") is not True:
            errors.append("approval request must not allow mobile edits and must write audit")
        if audit.get("auditLogRequired") is not True or audit.get("actorRole") != "user" or audit.get("channel") != "companion":
            errors.append("approval audit requirements drifted")
        if transport.get("localGatewayPort") != 17801:
            errors.append("approval push must retain W8 local gateway port 17801")
        if transport.get("mode") == "lan-push" and (transport.get("publicEgress") is not False or transport.get("cloudPushOptIn") is not False):
            errors.append("LAN push must stay local-only")
        if transport.get("publicEgress") is True and transport.get("cloudPushOptIn") is not True:
            errors.append("public approval push requires explicit cloudPushOptIn")
        if not APPROVAL_EVIDENCE.issubset(evidence):
            errors.append("approval evidence requirements drifted")
    else:
        errors.append("unknown companion fixture schemaVersion")
    return errors


pairing_schema = load(pairing_schema_path)
summary_schema = load(summary_schema_path)
approval_schema = load(approval_schema_path)
schemas = {"pairing": pairing_schema, "summary": summary_schema, "approval": approval_schema}
if not all(isinstance(schema, dict) for schema in schemas.values()):
    die("schema top-level must be objects")

pass_count = 0

if pairing_schema.get("required") != PAIRING_REQUIRED:
    die(f"pairing schema.required drifted: {pairing_schema.get('required')!r}")
if summary_schema.get("required") != SUMMARY_REQUIRED:
    die(f"summary schema.required drifted: {summary_schema.get('required')!r}")
if approval_schema.get("required") != APPROVAL_REQUIRED:
    die(f"approval schema.required drifted: {approval_schema.get('required')!r}")
if any(schema.get("additionalProperties") is not False for schema in schemas.values()):
    die("all companion schemas must set top-level additionalProperties:false")
pass_count += 1

p_props = pairing_schema.get("properties", {})
s_props = summary_schema.get("properties", {})
a_props = approval_schema.get("properties", {})
if p_props.get("token", {}).get("properties", {}).get("ttlSeconds", {}).get("maximum") != 600:
    die("pairing token ttlSeconds maximum must stay 600")
if p_props.get("token", {}).get("properties", {}).get("sessionTtlHours", {}).get("const") != 24:
    die("pairing sessionTtlHours must stay 24")
if s_props.get("diff", {}).get("properties", {}).get("mobileParsesApplyPlan", {}).get("const") is not False:
    die("mobileParsesApplyPlan must be const false")
if s_props.get("mobile", {}).get("properties", {}).get("canEdit", {}).get("const") is not False:
    die("mobile canEdit must be const false")
if a_props.get("approval", {}).get("properties", {}).get("biometricRequired", {}).get("const") is not True:
    die("biometricRequired must be const true")
if a_props.get("dataBoundary", {}).get("properties", {}).get("allowApprovalOffline", {}).get("const") is not False:
    die("allowApprovalOffline must be const false")
pass_count += 1

valid_paths = sorted(valid_dir.glob("*.json"))
invalid_paths = sorted(invalid_dir.glob("*.json"))
if {path.name for path in valid_paths} != EXPECTED_VALID_FILES:
    die(f"valid fixture roster drifted: {[path.name for path in valid_paths]!r}")
if {path.name for path in invalid_paths} != EXPECTED_INVALID_FILES:
    die(f"invalid fixture roster drifted: {[path.name for path in invalid_paths]!r}")
pass_count += 1

kinds: set[str] = set()
surfaces: set[str] = set()
actions: set[str] = set()
pairing_modes: set[str] = set()
approval_modes: set[str] = set()
approval_states: set[str] = set()
for path in valid_paths:
    value = load(path)
    if not isinstance(value, dict):
        die(f"{path} must contain an object")
    schema = schema_for(value, schemas)
    if schema is None:
        die(f"{path} has unknown schemaVersion {value.get('schemaVersion')!r}")
    errors = validate(value, schema, [path.name])
    if errors:
        die(f"{path} violates schema:\n" + "\n".join(errors))
    semantic = semantic_errors(value)
    if semantic:
        die(f"{path} violates W7 companion semantics:\n" + "\n".join(semantic))
    kind = fixture_kind(value)
    kinds.add(kind)
    if kind == "summary":
        surfaces.add(value["surface"])
        actions.add(value["diff"]["actionKind"])
    if kind == "pairing":
        pairing_modes.add(value["transport"]["mode"])
    if kind == "approval":
        approval_modes.add(value["transport"]["mode"])
        approval_states.add(value["request"]["state"])
pass_count += 1

if kinds != {"pairing", "summary", "approval"}:
    die(f"valid fixtures must cover all companion schemas, saw {sorted(kinds)}")
if surfaces != {"writer", "calc", "impress"}:
    die(f"valid summaries must cover writer/calc/impress, saw {sorted(surfaces)}")
if actions != {"ParagraphAction", "CellAction", "SlideElementAction"}:
    die(f"valid summaries must cover V2 action kinds, saw {sorted(actions)}")
if pairing_modes != {"lan-grpc", "enterprise-https"}:
    die(f"pairing fixtures must cover LAN and enterprise modes, saw {sorted(pairing_modes)}")
if approval_modes != {"lan-push", "enterprise-push"}:
    die(f"approval fixtures must cover LAN and enterprise push, saw {sorted(approval_modes)}")
if approval_states != {"awaiting-review", "failure-recovery"}:
    die(f"approval fixtures must cover review and recovery states, saw {sorted(approval_states)}")
pass_count += 1

for path in invalid_paths:
    value = load(path)
    if not isinstance(value, dict):
        die(f"{path} must contain an object")
    schema = schema_for(value, schemas)
    if schema is None:
        die(f"{path} has unknown schemaVersion {value.get('schemaVersion')!r}")
    schema_errors = validate(value, schema, [path.name])
    semantic = semantic_errors(value)
    if not schema_errors and not semantic:
        die(f"{path} unexpectedly passed schema+semantic validation")
pass_count += 1

for path in valid_paths:
    raw = path.read_text(encoding="utf-8")
    forbidden = ["documentContent", "originalText", "rawText", "applyPlanEnvelope"]
    for needle in forbidden:
        if needle in raw:
            die(f"{path} contains forbidden raw-content marker {needle!r}")
pass_count += 1

w7_text = w7_spec.read_text(encoding="utf-8")
w5_text = w5_spec.read_text(encoding="utf-8")
master_text = master_plan.read_text(encoding="utf-8")
sweep_text = sweep_path.read_text(encoding="utf-8")
workflow_text = workflow_path.read_text(encoding="utf-8")
for path, text, needles in [
    (w7_spec, w7_text, ["companion-contract self-test", "Checks: 9", "storesDocumentContent", "biometricRequired", "cloudPushOptIn", "allowApprovalOffline"]),
    (w5_spec, w5_text, ["tests/v3-companion-contract-test.sh", "companion-contract self-test"]),
    (master_plan, master_text, ["companion-pairing-token.schema.json", "companion-diff-summary.schema.json", "companion-approval-request.schema.json", "tests/v3-companion-contract-test.sh"]),
    (sweep_path, sweep_text, ["tests/v3-companion-contract-test.sh", "W7 companion-contract self-test"]),
    (workflow_path, workflow_text, ["docs/schemas/companion-pairing-token.schema.json", "docs/schemas/companion-diff-summary.schema.json", "docs/schemas/companion-approval-request.schema.json", "bin/v3-eval-sweep.sh --self-test"]),
]:
    for needle in needles:
        if needle not in text:
            die(f"{path} missing {needle!r}")
pass_count += 1

if pass_count != 8:
    die(f"internal pass_count drifted before final increment: {pass_count}")
pass_count += 1

print("Status: passed")
print("Harness: W7 companion-contract self-test")
print(f"Pairing schema: {pairing_schema_path}")
print(f"Diff summary schema: {summary_schema_path}")
print(f"Approval schema: {approval_schema_path}")
print(f"Valid fixtures: {len(valid_paths)}")
print(f"Invalid fixtures: {len(invalid_paths)}")
print("Companion contract: short token, no document content, online biometric approval")
print("Runtime implementation: deferred until W7 gate")
print(f"Checks: {pass_count}")
PY
