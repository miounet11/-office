#!/usr/bin/env bash
# V3 W9 - manual-docs contract self-test.
#
# Contract-first gate for W9 embedded and mirrored manual docs. It does not
# create docs/manual content, help UI wiring, online mirror runtime, or product
# integration code.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

schema_path="docs/schemas/manual-docs-manifest.schema.json"
w9_spec="docs/product/v3/w9-market-readiness-spec.md"
w5_spec="docs/product/v3/w5-eval-harness-spec.md"
master_plan="docs/product/v3-master-plan.md"
sweep="bin/v3-eval-sweep.sh"
workflow=".github/workflows/v3-contract-harnesses.yml"
valid_dir="docs/qa/fixtures/v3/manual-docs/valid"
invalid_dir="docs/qa/fixtures/v3/manual-docs/invalid"

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

REQUIRED = ["id", "schemaVersion", "createdAt", "manual", "locales", "topics", "delivery", "evidence", "gates"]
EXPECTED_VALID_FILES = {"manual-docs-manifest.json"}
EXPECTED_INVALID_FILES = {
    "embedded-missing.json",
    "missing-en-us.json",
    "public-internet-required.json",
    "missing-troubleshooting-topic.json",
}
EXPECTED_TOPICS = ["index", "quickstart", "ai-features", "connectors", "tenant-admin", "companion", "localcloud", "troubleshooting"]
EXPECTED_REQUIRED_LOCALES = ["zh-CN", "en-US"]
EXPECTED_LAUNCH_LOCALES = ["zh-CN", "en-US", "ja-JP", "zh-TW"]
BASE_EVIDENCE = {"manual-docs-manifest", "embedded-help-open", "online-mirror-sync", "locale-coverage", "evidence-record"}


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
    manual = value.get("manual", {})
    locales = value.get("locales", {})
    topics = value.get("topics", [])
    delivery = value.get("delivery", {})
    evidence = set(value.get("evidence", {}).get("required", []))

    if manual != {
        "rootPath": "docs/manual/",
        "embedded": True,
        "onlineMirror": True,
        "helpKey": "?",
        "helpMenuEntry": True,
        "searchEnabled": True,
        "noExternalDependency": True,
    }:
        errors.append("manual delivery policy drifted")
    if locales.get("requiredLocales") != EXPECTED_REQUIRED_LOCALES:
        errors.append("manual required locale baseline must stay zh-CN/en-US")
    if locales.get("launchLocales") != EXPECTED_LAUNCH_LOCALES:
        errors.append("manual launch locale roster must stay zh-CN/en-US/ja-JP/zh-TW")
    if locales.get("fallbackLocale") != "en-US" or locales.get("fallbackForUntranslated") != ["ja-JP", "zh-TW"]:
        errors.append("manual locale fallback policy drifted")

    if [topic.get("id") for topic in topics] != EXPECTED_TOPICS:
        errors.append("manual topic roster/order drifted")
    seen_paths: set[str] = set()
    for topic in topics:
        topic_id = topic.get("id")
        if topic.get("required") is not True or topic.get("embedded") is not True or topic.get("onlineMirror") is not True:
            errors.append(f"{topic_id} must be required, embedded, and mirrored")
        if topic.get("locales") != EXPECTED_REQUIRED_LOCALES:
            errors.append(f"{topic_id} locale coverage drifted")
        if topic.get("titleToken") != f"manual.{topic_id}":
            errors.append(f"{topic_id} title token drifted")
        paths = topic.get("pathByLocale", {})
        if paths.get("zh-CN") != f"docs/manual/zh-CN/{topic_id}.md":
            errors.append(f"{topic_id} zh-CN path drifted")
        if paths.get("en-US") != f"docs/manual/en-US/{topic_id}.md":
            errors.append(f"{topic_id} en-US path drifted")
        for path in paths.values():
            if path in seen_paths:
                errors.append(f"duplicate manual path {path}")
            seen_paths.add(path)

    if delivery != {
        "embeddedBundle": True,
        "onlineMirrorSource": True,
        "offlineReadable": True,
        "requiresPublicInternet": False,
        "updateChannel": "w8-self-host-or-release-bundle",
    }:
        errors.append("manual delivery/offline policy drifted")
    if not BASE_EVIDENCE.issubset(evidence):
        errors.append("manual docs evidence requirements drifted")
    if value.get("gates", {}).get("runtimeImplementation") != "not-started":
        errors.append("manual docs runtime implementation must remain gated")
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
if props.get("topics", {}).get("minItems") != 8 or props.get("topics", {}).get("maxItems") != 8:
    die("schema must lock exactly 8 manual topics")
if props.get("manual", {}).get("properties", {}).get("embedded", {}).get("const") is not True:
    die("manual embedded docs must stay required")
if props.get("delivery", {}).get("properties", {}).get("requiresPublicInternet", {}).get("const") is not False:
    die("manual docs must not require public internet")
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
        die(f"{path} violates W9 manual-docs semantics:\n" + "\n".join(semantic))
pass_count += 1

value = load(valid_paths[0])
topic_ids = [topic["id"] for topic in value["topics"]]
if topic_ids != EXPECTED_TOPICS:
    die(f"valid fixture topic roster drifted: {topic_ids!r}")
locale_paths = [path for topic in value["topics"] for path in topic["pathByLocale"].values()]
if len(locale_paths) != 16 or len(set(locale_paths)) != 16:
    die("valid fixture must expose unique zh-CN/en-US paths for 8 topics")
if value["locales"]["requiredLocales"] != EXPECTED_REQUIRED_LOCALES or value["delivery"]["offlineReadable"] is not True:
    die("valid fixture locale/offline baseline drifted")
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
for needle in ["embedded\": false", "onlineMirror\": false", "requiresPublicInternet\": true", "runtimeImplementation\": \"started\""]:
    if needle in raw:
        die(f"{valid_paths[0]} contains forbidden manual-docs marker {needle!r}")
pass_count += 1

w9_text = w9_spec.read_text(encoding="utf-8")
w5_text = w5_spec.read_text(encoding="utf-8")
master_text = master_plan.read_text(encoding="utf-8")
sweep_text = sweep_path.read_text(encoding="utf-8")
workflow_text = workflow_path.read_text(encoding="utf-8")
for path, text, needles in [
    (w9_spec, w9_text, ["manual-docs self-test", "Checks: 8", "manual-docs-manifest", "embedded + online mirror", "zh-CN / en-US"]),
    (w5_spec, w5_text, ["tests/v3-manual-docs-test.sh", "manual-docs self-test"]),
    (master_plan, master_text, ["manual-docs-manifest.schema.json", "tests/v3-manual-docs-test.sh"]),
    (sweep_path, sweep_text, ["tests/v3-manual-docs-test.sh", "W9 manual-docs self-test"]),
    (workflow_path, workflow_text, ["docs/schemas/manual-docs-manifest.schema.json", "bin/v3-eval-sweep.sh --self-test"]),
]:
    for needle in needles:
        if needle not in text:
            die(f"{path} missing {needle!r}")
pass_count += 1

if pass_count != 7:
    die(f"internal pass_count drifted before final increment: {pass_count}")
pass_count += 1

print("Status: passed")
print("Harness: W9 manual-docs self-test")
print(f"Schema: {schema_path}")
print(f"Valid fixtures: {len(valid_paths)}")
print(f"Invalid fixtures: {len(invalid_paths)}")
print("Manual docs contract: embedded + online mirror, zh-CN/en-US baseline")
print("Runtime implementation: deferred until W9 gate")
print(f"Checks: {pass_count}")
PY
