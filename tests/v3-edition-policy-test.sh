#!/usr/bin/env bash
# V3 W9 - edition-policy contract self-test.
#
# Contract-first gate for W9 freemium and audit-lock policy. It does not start
# gated edition switching, billing, entitlement, or product integration code.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

schema_path="docs/schemas/edition-policy.schema.json"
w9_spec="docs/product/v3/w9-market-readiness-spec.md"
w5_spec="docs/product/v3/w5-eval-harness-spec.md"
master_plan="docs/product/v3-master-plan.md"
sweep="bin/v3-eval-sweep.sh"
workflow=".github/workflows/v3-contract-harnesses.yml"
valid_dir="docs/qa/fixtures/v3/edition-policy/valid"
invalid_dir="docs/qa/fixtures/v3/edition-policy/invalid"

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

REQUIRED = ["id", "schemaVersion", "createdAt", "businessModel", "editions", "guardrails", "evidence", "gates"]
EXPECTED_VALID_FILES = {"w9-edition-policy.json"}
EXPECTED_INVALID_FILES = {
    "free-edition-paywalled.json",
    "enterprise-audit-disabled.json",
    "function-locked-personal.json",
    "self-hosted-requires-public-cloud.json",
}
EXPECTED_EDITION_ORDER = ["personal-free", "personal-pro", "enterprise", "enterprise-self-hosted"]
EXPECTED_LIMITS = {
    "personal-free": (0, False, 5, 10000, 1, False),
    "personal-pro": (39, False, 20, 50000, 3, False),
    "enterprise": (199, True, 1000000, 1000000000, 1000000, True),
    "enterprise-self-hosted": (9999, True, 1000000, 1000000000, 1000000, True),
}
BASE_EVIDENCE = {"edition-policy", "pricing-snapshot", "audit-lock", "evidence-record", "v2-regression-green"}


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
    business = value.get("businessModel", {})
    editions = value.get("editions", [])
    guardrails = value.get("guardrails", {})
    evidence = set(value.get("evidence", {}).get("required", []))

    if business.get("mode") != "freemium" or business.get("personalFreeLocal") is not True:
        errors.append("business model must stay freemium with true local personal free")
    if business.get("enterpriseChargesByAudit") is not True or business.get("functionLockAllowed") is not False:
        errors.append("enterprise must charge by audit and function locks must stay forbidden")
    if [edition.get("id") for edition in editions] != EXPECTED_EDITION_ORDER:
        errors.append("edition roster/order drifted")
    if guardrails != {
        "limitsOnlyScaleAndAudit": True,
        "personalEditionFullLocalAI": True,
        "enterpriseAuditMandatory": True,
        "trialBypassAuditAllowed": False,
    }:
        errors.append("edition guardrails drifted")

    seen = set()
    for edition in editions:
        edition_id = edition.get("id")
        if edition_id in seen:
            errors.append(f"duplicate edition {edition_id}")
        seen.add(edition_id)
        if edition_id not in EXPECTED_LIMITS:
            errors.append(f"unknown edition {edition_id}")
            continue
        expected_amount, expected_audit, expected_connectors, expected_docs, expected_concurrency, expected_unlimited = EXPECTED_LIMITS[edition_id]
        price = edition.get("price", {})
        audit = edition.get("audit", {})
        limits = edition.get("limits", {})
        features = edition.get("featureAccess", {})
        deployment = edition.get("deployment", {})
        boundary = edition.get("dataBoundary", {})

        if price.get("amount") != expected_amount:
            errors.append(f"{edition_id} price amount drifted")
        if edition_id == "personal-free" and price.get("period") != "free":
            errors.append("personal-free period must be free")
        if edition_id in {"enterprise", "enterprise-self-hosted"} and price.get("seatBased") is not True:
            errors.append(f"{edition_id} must be seat based")
        if audit.get("enabled") is not expected_audit or audit.get("requiredForEdition") is not expected_audit:
            errors.append(f"{edition_id} audit lock drifted")
        if audit.get("bypassAllowed") is not False:
            errors.append(f"{edition_id} audit bypass must be forbidden")
        if limits.get("connectorMax") != expected_connectors or limits.get("knowledgeIndexDocumentMax") != expected_docs:
            errors.append(f"{edition_id} scale limits drifted")
        if limits.get("agentConcurrencyMax") != expected_concurrency or limits.get("unlimitedScale") is not expected_unlimited:
            errors.append(f"{edition_id} concurrency/unlimited drifted")
        if features != {
            "aiPatch": True,
            "localModel": True,
            "starterPack": True,
            "companionApproval": True,
            "featureLocked": False,
        }:
            errors.append(f"{edition_id} feature access drifted")
        if deployment.get("requiresPublicCloud") is not False:
            errors.append(f"{edition_id} must not require public cloud")
        if edition_id == "enterprise-self-hosted" and (deployment.get("mode") != "w8-self-hosted" or deployment.get("w8SelfHosted") is not True):
            errors.append("enterprise-self-hosted must use W8 self-hosted deployment")
        if boundary != {"localFirst": True, "storesDocumentContent": False, "publicEgressDefault": False}:
            errors.append(f"{edition_id} data boundary drifted")

    if not BASE_EVIDENCE.issubset(evidence):
        errors.append("edition-policy evidence requirements drifted")
    if value.get("gates", {}).get("runtimeImplementation") != "not-started":
        errors.append("edition runtime implementation must remain gated")
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
if props.get("editions", {}).get("minItems") != 4 or props.get("editions", {}).get("maxItems") != 4:
    die("schema must lock exactly 4 editions")
if props.get("businessModel", {}).get("properties", {}).get("mode", {}).get("const") != "freemium":
    die("business model must stay freemium")
if props.get("businessModel", {}).get("properties", {}).get("functionLockAllowed", {}).get("const") is not False:
    die("functionLockAllowed must stay false")
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
        die(f"{path} violates W9 edition-policy semantics:\n" + "\n".join(semantic))
pass_count += 1

value = load(valid_paths[0])
editions = {edition["id"]: edition for edition in value["editions"]}
if set(editions) != set(EXPECTED_EDITION_ORDER):
    die("valid fixture edition roster drifted")
if editions["personal-free"]["price"]["amount"] != 0 or editions["personal-free"]["featureAccess"]["featureLocked"] is not False:
    die("personal-free must remain free and full-feature local")
if editions["enterprise"]["audit"]["requiredForEdition"] is not True or editions["enterprise-self-hosted"]["deployment"]["w8SelfHosted"] is not True:
    die("enterprise audit/self-host semantics drifted")
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
for needle in ["functionLocked\": true", "requiresPublicCloud\": true", "trialBypassAuditAllowed\": true", "storesDocumentContent\": true"]:
    if needle in raw:
        die(f"{valid_paths[0]} contains forbidden edition marker {needle!r}")
pass_count += 1

w9_text = w9_spec.read_text(encoding="utf-8")
w5_text = w5_spec.read_text(encoding="utf-8")
master_text = master_plan.read_text(encoding="utf-8")
sweep_text = sweep_path.read_text(encoding="utf-8")
workflow_text = workflow_path.read_text(encoding="utf-8")
for path, text, needles in [
    (w9_spec, w9_text, ["edition-policy self-test", "Checks: 8", "edition-policy", "freemium", "audit lock"]),
    (w5_spec, w5_text, ["tests/v3-edition-policy-test.sh", "edition-policy self-test"]),
    (master_plan, master_text, ["edition-policy.schema.json", "tests/v3-edition-policy-test.sh"]),
    (sweep_path, sweep_text, ["tests/v3-edition-policy-test.sh", "W9 edition-policy self-test"]),
    (workflow_path, workflow_text, ["docs/schemas/edition-policy.schema.json", "bin/v3-eval-sweep.sh --self-test"]),
]:
    for needle in needles:
        if needle not in text:
            die(f"{path} missing {needle!r}")
pass_count += 1

if pass_count != 7:
    die(f"internal pass_count drifted before final increment: {pass_count}")
pass_count += 1

print("Status: passed")
print("Harness: W9 edition-policy self-test")
print(f"Schema: {schema_path}")
print(f"Valid fixtures: {len(valid_paths)}")
print(f"Invalid fixtures: {len(invalid_paths)}")
print("Edition contract: freemium, audit lock, scale-only limits, local-first")
print("Runtime implementation: deferred until W9 gate")
print(f"Checks: {pass_count}")
PY
