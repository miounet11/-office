#!/usr/bin/env bash
# V3 W9 - onboarding-flow contract self-test.
#
# Contract-first gate for the W9 five-step first-run experience. It does not
# start the gated onboarding controller, recovery code, template installer, or
# product integration. It locks the path from first launch to a successful
# sample patch within five minutes.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

schema_path="docs/schemas/onboarding-flow.schema.json"
w9_spec="docs/product/v3/w9-market-readiness-spec.md"
w5_spec="docs/product/v3/w5-eval-harness-spec.md"
master_plan="docs/product/v3-master-plan.md"
sweep="bin/v3-eval-sweep.sh"
workflow=".github/workflows/v3-contract-harnesses.yml"
valid_dir="docs/qa/fixtures/v3/onboarding-flow/valid"
invalid_dir="docs/qa/fixtures/v3/onboarding-flow/invalid"

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

REQUIRED = ["id", "schemaVersion", "createdAt", "locale", "edition", "durationBudget", "steps", "privacy", "localModel", "connector", "demoPatch", "evidence", "gates"]
EXPECTED_VALID_FILES = {
    "zh-cn-personal-free.json",
    "en-us-enterprise-self-hosted.json",
    "ja-jp-personal-pro.json",
}
EXPECTED_INVALID_FILES = {
    "six-step-flow.json",
    "over-five-minutes.json",
    "privacy-step-without-evidence.json",
    "demo-patch-not-required.json",
}
EXPECTED_STEP_KINDS = ["welcome", "local-model", "connector", "privacy", "demo-patch"]
BASE_EVIDENCE = {"onboarding-flow", "evidence-record", "local-model-choice", "privacy-confirmation", "demo-patch-result"}


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
    steps = value.get("steps", [])
    privacy = value.get("privacy", {})
    local_model = value.get("localModel", {})
    connector = value.get("connector", {})
    demo_patch = value.get("demoPatch", {})
    evidence = set(value.get("evidence", {}).get("required", []))

    if [step.get("order") for step in steps] != [1, 2, 3, 4, 5]:
        errors.append("onboarding steps must be ordered 1..5")
    if [step.get("kind") for step in steps] != EXPECTED_STEP_KINDS:
        errors.append("onboarding must keep the W9 five-step kind order")
    if sum(step.get("maxSeconds", 0) for step in steps) > 300:
        errors.append("onboarding maxSeconds total must fit within five minutes")
    for step in steps:
        if step.get("kind") in {"welcome", "local-model", "privacy", "demo-patch"} and step.get("required") is not True:
            errors.append(f"{step.get('kind')} step must be required")
        if step.get("evidenceRequired") is not True:
            errors.append(f"{step.get('kind')} step must require evidence")

    if value.get("durationBudget", {}).get("maxMinutes") != 5 or value.get("durationBudget", {}).get("fromDownloadToPatch") is not True:
        errors.append("duration budget must lock download-to-patch within five minutes")
    if privacy.get("noSilentUpload") is not True or privacy.get("localFirst") is not True or privacy.get("explicitCloudOptIn") is not True:
        errors.append("privacy confirmation must lock local-first/no-silent-upload/explicit opt-in")
    if privacy.get("storesDocumentContent") is not False:
        errors.append("onboarding privacy must not store document content")
    if local_model.get("canSkip") is not True or local_model.get("offlineCapable") is not True:
        errors.append("local model step must be skippable and offline-capable")
    if connector.get("required") is not False or connector.get("maxInitialConnectors", 99) > 1 or connector.get("requiresEvidence") is not True:
        errors.append("connector step must remain optional, at most one connector, with evidence")
    if demo_patch.get("mustSucceed") is not True or demo_patch.get("requiresUndo") is not True or demo_patch.get("resultEvidence") is not True:
        errors.append("demo patch must succeed, be undoable, and emit evidence")
    if not BASE_EVIDENCE.issubset(evidence):
        errors.append("onboarding evidence requirements drifted")
    if value.get("gates", {}).get("runtimeImplementation") != "not-started":
        errors.append("onboarding runtime implementation must remain gated")
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
if props.get("durationBudget", {}).get("properties", {}).get("maxMinutes", {}).get("const") != 5:
    die("maxMinutes must stay const 5")
if props.get("steps", {}).get("minItems") != 5 or props.get("steps", {}).get("maxItems") != 5:
    die("onboarding must stay exactly 5 steps")
if props.get("privacy", {}).get("properties", {}).get("noSilentUpload", {}).get("const") is not True:
    die("noSilentUpload must be const true")
if props.get("demoPatch", {}).get("properties", {}).get("mustSucceed", {}).get("const") is not True:
    die("demoPatch.mustSucceed must be const true")
pass_count += 1

valid_paths = sorted(valid_dir.glob("*.json"))
invalid_paths = sorted(invalid_dir.glob("*.json"))
if {path.name for path in valid_paths} != EXPECTED_VALID_FILES:
    die(f"valid fixture roster drifted: {[path.name for path in valid_paths]!r}")
if {path.name for path in invalid_paths} != EXPECTED_INVALID_FILES:
    die(f"invalid fixture roster drifted: {[path.name for path in invalid_paths]!r}")
pass_count += 1

locales: set[str] = set()
editions: set[str] = set()
surfaces: set[str] = set()
providers: set[str] = set()
for path in valid_paths:
    value = load(path)
    if not isinstance(value, dict):
        die(f"{path} must contain an object")
    errors = validate(value, schema, [path.name])
    if errors:
        die(f"{path} violates schema:\n" + "\n".join(errors))
    semantic = semantic_errors(value)
    if semantic:
        die(f"{path} violates W9 onboarding semantics:\n" + "\n".join(semantic))
    locales.add(value["locale"])
    editions.add(value["edition"])
    surfaces.update(value["demoPatch"]["surfaces"])
    providers.add(value["localModel"]["provider"])
pass_count += 1

if locales != {"zh-CN", "en-US", "ja-JP"}:
    die(f"valid fixtures must cover zh-CN/en-US/ja-JP, saw {sorted(locales)}")
if editions != {"personal-free", "personal-pro", "enterprise-self-hosted"}:
    die(f"valid fixtures must cover personal-free/personal-pro/enterprise-self-hosted, saw {sorted(editions)}")
if not {"writer", "calc", "impress"}.issubset(surfaces):
    die(f"valid fixtures must cover writer/calc/impress demo patches, saw {sorted(surfaces)}")
if providers != {"ollama-local", "enterprise-local"}:
    die(f"valid fixtures must cover local and enterprise-local model modes, saw {sorted(providers)}")
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
    for needle in ["paywall", "forceCloud", "publicUpload", "documentContent"]:
        if needle in raw:
            die(f"{path} contains forbidden onboarding marker {needle!r}")
pass_count += 1

w9_text = w9_spec.read_text(encoding="utf-8")
w5_text = w5_spec.read_text(encoding="utf-8")
master_text = master_plan.read_text(encoding="utf-8")
sweep_text = sweep_path.read_text(encoding="utf-8")
workflow_text = workflow_path.read_text(encoding="utf-8")
for path, text, needles in [
    (w9_spec, w9_text, ["onboarding-flow self-test", "Checks: 8", "maxMinutes", "noSilentUpload", "demo-patch", "5 steps"]),
    (w5_spec, w5_text, ["tests/v3-onboarding-flow-test.sh", "onboarding-flow self-test"]),
    (master_plan, master_text, ["onboarding-flow.schema.json", "tests/v3-onboarding-flow-test.sh"]),
    (sweep_path, sweep_text, ["tests/v3-onboarding-flow-test.sh", "W9 onboarding-flow self-test"]),
    (workflow_path, workflow_text, ["docs/schemas/onboarding-flow.schema.json", "bin/v3-eval-sweep.sh --self-test"]),
]:
    for needle in needles:
        if needle not in text:
            die(f"{path} missing {needle!r}")
pass_count += 1

if pass_count != 7:
    die(f"internal pass_count drifted before final increment: {pass_count}")
pass_count += 1

print("Status: passed")
print("Harness: W9 onboarding-flow self-test")
print(f"Schema: {schema_path}")
print(f"Valid fixtures: {len(valid_paths)}")
print(f"Invalid fixtures: {len(invalid_paths)}")
print("Onboarding contract: 5 steps, <=5 minutes, privacy + demo patch evidence")
print("Runtime implementation: deferred until W9 gate")
print(f"Checks: {pass_count}")
PY
