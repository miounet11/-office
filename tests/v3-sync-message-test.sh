#!/usr/bin/env bash
# V3 W8 - sync-message contract self-test.
#
# Contract-first gate for W8 sync-server message envelopes. It does not start
# the gated LocalCloud supervisor, sync server, socket proof, or product
# integration. It locks local/LAN-only sync, hash-only refs, idempotent ack,
# evidence/audit links, and no document-content payloads.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

schema_path="docs/schemas/sync-message.schema.json"
w8_spec="docs/product/v3/w8-local-cloud-spec.md"
w5_spec="docs/product/v3/w5-eval-harness-spec.md"
master_plan="docs/product/v3-master-plan.md"
sweep="bin/v3-eval-sweep.sh"
workflow=".github/workflows/v3-contract-harnesses.yml"
valid_dir="docs/qa/fixtures/v3/sync-message/valid"
invalid_dir="docs/qa/fixtures/v3/sync-message/invalid"

[[ -f "$schema_path" ]] || fail "missing $schema_path"
[[ -f "$w8_spec" ]] || fail "missing $w8_spec"
[[ -f "$w5_spec" ]] || fail "missing $w5_spec"
[[ -f "$master_plan" ]] || fail "missing $master_plan"
[[ -f "$sweep" ]] || fail "missing $sweep"
[[ -f "$workflow" ]] || fail "missing $workflow"
[[ -d "$valid_dir" ]] || fail "missing $valid_dir"
[[ -d "$invalid_dir" ]] || fail "missing $invalid_dir"

python3 - "$schema_path" "$w8_spec" "$w5_spec" "$master_plan" "$sweep" "$workflow" "$valid_dir" "$invalid_dir" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

schema_path = Path(sys.argv[1])
w8_spec = Path(sys.argv[2])
w5_spec = Path(sys.argv[3])
master_plan = Path(sys.argv[4])
sweep_path = Path(sys.argv[5])
workflow_path = Path(sys.argv[6])
valid_dir = Path(sys.argv[7])
invalid_dir = Path(sys.argv[8])

REQUIRED = ["id", "schemaVersion", "createdAt", "tenant", "workspace", "channel", "direction", "kind", "payload", "transport", "ordering", "boundary", "evidence"]
EXPECTED_VALID_FILES = {
    "local-evidence-upload.json",
    "lan-diff-summary-download.json",
    "companion-approval-upload.json",
    "task-state-ack.json",
}
EXPECTED_INVALID_FILES = {
    "stores-document-content.json",
    "public-egress-sync.json",
    "missing-ack-required.json",
    "raw-payload-sync.json",
}
KIND_TO_REF = {
    "evidence-sync": "evidence-record",
    "diff-summary-sync": "companion-diff-summary",
    "approval-decision-sync": "companion-approval-request",
    "task-state-sync": "agent-task-state",
}
BASE_EVIDENCE = {"localcloud-sync-message", "evidence-record", "audit-log-entry"}
EXPECTED_CHANNELS = {"desktop-to-sync", "sync-to-companion", "companion-to-sync", "sync-to-desktop"}
EXPECTED_DIRECTIONS = {"upload", "download", "ack"}
EXPECTED_KINDS = set(KIND_TO_REF)


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
    payload = value.get("payload", {})
    transport = value.get("transport", {})
    ordering = value.get("ordering", {})
    boundary = value.get("boundary", {})
    evidence = set(value.get("evidence", {}).get("required", []))

    if payload.get("refType") != KIND_TO_REF.get(value.get("kind")):
        errors.append("payload.refType must match message kind")
    if payload.get("storesDocumentContent") is not False or payload.get("containsRawPayload") is not False:
        errors.append("sync payload must be hash-only and must not store raw document content")
    if transport.get("port") != 17802 or transport.get("publicEgress") is not False:
        errors.append("sync transport must use W8 sync port 17802 and no public egress")
    if transport.get("mode") == "local-socket" and transport.get("endpointClass") != "loopback":
        errors.append("local-socket sync must use loopback endpoint")
    if transport.get("mode") == "lan-grpc" and transport.get("endpointClass") != "private-lan":
        errors.append("lan-grpc sync must use private-lan endpoint")
    if transport.get("mTLSRequired") is not True:
        errors.append("sync transport must require mTLS")
    if ordering.get("ackRequired") is not True:
        errors.append("sync messages must require ack")
    if boundary.get("serviceMode") not in {"offline", "private"}:
        errors.append("sync serviceMode must stay offline/private")
    if boundary.get("storesDocumentContent") is not False or boundary.get("hashOnly") is not True:
        errors.append("sync boundary must be hash-only with no document content")
    if boundary.get("defaultNoPublicEgress") is not True:
        errors.append("sync boundary must keep default no-public-egress")
    if not BASE_EVIDENCE.issubset(evidence):
        errors.append("sync evidence requirements drifted")
    required_for_kind = {
        "diff-summary-sync": "companion-diff-summary",
        "approval-decision-sync": "companion-approval-request",
        "task-state-sync": "agent-task-state",
    }.get(value.get("kind"))
    if required_for_kind is not None and required_for_kind not in evidence:
        errors.append(f"{value.get('kind')} missing {required_for_kind} evidence marker")
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
if props.get("transport", {}).get("properties", {}).get("port", {}).get("const") != 17802:
    die("sync transport port must stay 17802")
if props.get("transport", {}).get("properties", {}).get("publicEgress", {}).get("const") is not False:
    die("sync publicEgress must be const false")
if props.get("payload", {}).get("properties", {}).get("containsRawPayload", {}).get("const") is not False:
    die("containsRawPayload must be const false")
if props.get("ordering", {}).get("properties", {}).get("ackRequired", {}).get("const") is not True:
    die("ackRequired must be const true")
pass_count += 1

valid_paths = sorted(valid_dir.glob("*.json"))
invalid_paths = sorted(invalid_dir.glob("*.json"))
if {path.name for path in valid_paths} != EXPECTED_VALID_FILES:
    die(f"valid fixture roster drifted: {[path.name for path in valid_paths]!r}")
if {path.name for path in invalid_paths} != EXPECTED_INVALID_FILES:
    die(f"invalid fixture roster drifted: {[path.name for path in invalid_paths]!r}")
pass_count += 1

channels: set[str] = set()
directions: set[str] = set()
kinds: set[str] = set()
transports: set[str] = set()
endpoint_classes: set[str] = set()
for path in valid_paths:
    value = load(path)
    if not isinstance(value, dict):
        die(f"{path} must contain an object")
    errors = validate(value, schema, [path.name])
    if errors:
        die(f"{path} violates schema:\n" + "\n".join(errors))
    semantic = semantic_errors(value)
    if semantic:
        die(f"{path} violates W8 sync-message semantics:\n" + "\n".join(semantic))
    channels.add(value["channel"])
    directions.add(value["direction"])
    kinds.add(value["kind"])
    transports.add(value["transport"]["mode"])
    endpoint_classes.add(value["transport"]["endpointClass"])
pass_count += 1

if channels != EXPECTED_CHANNELS:
    die(f"valid fixtures must cover channels {sorted(EXPECTED_CHANNELS)}, saw {sorted(channels)}")
if directions != EXPECTED_DIRECTIONS:
    die(f"valid fixtures must cover directions {sorted(EXPECTED_DIRECTIONS)}, saw {sorted(directions)}")
if kinds != EXPECTED_KINDS:
    die(f"valid fixtures must cover kinds {sorted(EXPECTED_KINDS)}, saw {sorted(kinds)}")
if transports != {"local-socket", "lan-grpc"} or endpoint_classes != {"loopback", "private-lan"}:
    die("valid fixtures must cover local and LAN transports")
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

for path in valid_paths:
    raw = path.read_text(encoding="utf-8")
    for needle in ["documentContent", "rawPayload", "originalText", "publicEndpoint"]:
        if needle in raw:
            die(f"{path} contains forbidden raw-content/egress marker {needle!r}")
pass_count += 1

w8_text = w8_spec.read_text(encoding="utf-8")
w5_text = w5_spec.read_text(encoding="utf-8")
master_text = master_plan.read_text(encoding="utf-8")
sweep_text = sweep_path.read_text(encoding="utf-8")
workflow_text = workflow_path.read_text(encoding="utf-8")
for path, text, needles in [
    (w8_spec, w8_text, ["sync-message self-test", "Checks: 8", "storesDocumentContent", "ackRequired", "publicEgress", "17802"]),
    (w5_spec, w5_text, ["tests/v3-sync-message-test.sh", "sync-message self-test"]),
    (master_plan, master_text, ["sync-message.schema.json", "tests/v3-sync-message-test.sh"]),
    (sweep_path, sweep_text, ["tests/v3-sync-message-test.sh", "W8 sync-message self-test"]),
    (workflow_path, workflow_text, ["docs/schemas/sync-message.schema.json", "bin/v3-eval-sweep.sh --self-test"]),
]:
    for needle in needles:
        if needle not in text:
            die(f"{path} missing {needle!r}")
pass_count += 1

if pass_count != 7:
    die(f"internal pass_count drifted before final increment: {pass_count}")
pass_count += 1

print("Status: passed")
print("Harness: W8 sync-message self-test")
print(f"Schema: {schema_path}")
print(f"Valid fixtures: {len(valid_paths)}")
print(f"Invalid fixtures: {len(invalid_paths)}")
print("Sync contract: local/LAN only, hash-only payloads, ack + evidence required")
print("Runtime implementation: deferred until W8 gate")
print(f"Checks: {pass_count}")
PY
