#!/usr/bin/env bash
# V3 H11 — perf-baseline target contract.
#
# This does not run live performance measurements yet. It locks the W9
# P0 targets, platform fixture roster, local-provider requirement, and
# evidence fields that future runtime measurements must satisfy.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

schema="docs/schemas/perf-baseline-targets.schema.json"
w5_spec="docs/product/v3/w5-eval-harness-spec.md"
w9_spec="docs/product/v3/w9-market-readiness-spec.md"
valid_dir="docs/qa/fixtures/v3/perf/valid"
invalid_dir="docs/qa/fixtures/v3/perf/invalid"

[[ -f "$schema" ]] || fail "missing $schema"
[[ -f "$w5_spec" ]] || fail "missing $w5_spec"
[[ -f "$w9_spec" ]] || fail "missing $w9_spec"
[[ -d "$valid_dir" ]] || fail "missing $valid_dir"
[[ -d "$invalid_dir" ]] || fail "missing $invalid_dir"

python3 - "$schema" "$w5_spec" "$w9_spec" "$valid_dir" "$invalid_dir" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

schema_path = Path(sys.argv[1])
w5_spec = Path(sys.argv[2])
w9_spec = Path(sys.argv[3])
valid_dir = Path(sys.argv[4])
invalid_dir = Path(sys.argv[5])

EXPECTED_REQUIRED = ["id", "wave", "category", "platform", "measurementMode", "workload", "evidence"]
EXPECTED_PLATFORMS = ["macos-arm64", "linux-x86_64", "windows-x86_64"]
EXPECTED_VALID_FILES = {
    "macos-arm64-target.json",
    "linux-x86_64-target.json",
    "windows-x86_64-target.json",
}
EXPECTED_INVALID_FILES = {
    "slow-cold-start.json",
    "cloud-first-token-provider.json",
    "weak-retrieval-corpus.json",
}
EXPECTED_EVIDENCE = {"perf-sample", "system-profile", "local-provider-proof", "knowledge-index-sample"}
EXPECTED_ROUTES = {
    "macos-arm64": "dmg",
    "linux-x86_64": "appimage",
    "windows-x86_64": "msi",
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

    if isinstance(value, int) and not isinstance(value, bool):
        minimum = schema.get("minimum")
        maximum = schema.get("maximum")
        if isinstance(minimum, int) and value < minimum:
            errors.append(f"{json_pointer(path)} below minimum {minimum}")
        if isinstance(maximum, int) and value > maximum:
            errors.append(f"{json_pointer(path)} above maximum {maximum}")

    if isinstance(value, list):
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


def schema_errors(fixture: dict[str, Any], schema: dict[str, Any]) -> list[str]:
    return validate(fixture, schema, [])


def semantic_errors(fixture: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    platform = fixture.get("platform")
    workload = fixture.get("workload", {})
    cold_start = workload.get("coldStart", {})
    first_token = workload.get("firstToken", {})
    retrieval = workload.get("retrieval", {})
    evidence = fixture.get("evidence", {})

    if fixture.get("wave") != "w9":
        errors.append("wave must be w9")
    if fixture.get("category") != "perf-baseline":
        errors.append("category must be perf-baseline")
    if fixture.get("measurementMode") != "target-contract":
        errors.append("measurementMode must be target-contract until runtime samples land")

    if cold_start.get("targetMs") != 2000:
        errors.append("coldStart.targetMs must be exactly 2000")
    if cold_start.get("measurement") != "main-window-interactive":
        errors.append("coldStart.measurement drifted")
    if EXPECTED_ROUTES.get(platform) != cold_start.get("packageRoute"):
        errors.append(f"{platform} packageRoute drifted")

    if first_token.get("targetMs") != 800:
        errors.append("firstToken.targetMs must be exactly 800")
    if first_token.get("trigger") != "cmd-shift-k-chat":
        errors.append("firstToken.trigger drifted")
    if first_token.get("provider") != "ollama-local":
        errors.append("firstToken.provider must stay local")
    if first_token.get("model") != "llama3.2:3b":
        errors.append("firstToken.model drifted")

    if retrieval.get("targetMs") != 200:
        errors.append("retrieval.targetMs must be exactly 200")
    if retrieval.get("corpusDocuments") != 10000:
        errors.append("retrieval.corpusDocuments must be exactly 10000")
    if retrieval.get("topK") != 5:
        errors.append("retrieval.topK must be 5")
    if retrieval.get("index") != "local-knowledge-index":
        errors.append("retrieval.index drifted")

    required = evidence.get("required", [])
    if set(required) != EXPECTED_EVIDENCE:
        errors.append(f"evidence.required drifted: {required!r}")
    if evidence.get("blocksGA") is not True:
        errors.append("evidence.blocksGA must be true")
    return errors


schema = load(schema_path)
if not isinstance(schema, dict):
    die("perf schema top-level is not an object")

pass_count = 0

if schema.get("required") != EXPECTED_REQUIRED:
    die(f"schema.required drifted: {schema.get('required')!r}")
if schema.get("additionalProperties") is not False:
    die("schema must set top-level additionalProperties:false")
pass_count += 1

props = schema.get("properties", {})
if props.get("platform", {}).get("enum") != EXPECTED_PLATFORMS:
    die("platform enum drifted")
if props.get("measurementMode", {}).get("enum") != ["target-contract", "runtime-sample"]:
    die("measurementMode enum drifted")
pass_count += 1

workload_schema = props.get("workload", {})
if workload_schema.get("required") != ["coldStart", "firstToken", "retrieval"]:
    die("workload.required drifted")
if workload_schema.get("additionalProperties") is not False:
    die("workload must set additionalProperties:false")
pass_count += 1

spec_text = w5_spec.read_text(encoding="utf-8") + "\n" + w9_spec.read_text(encoding="utf-8")
for needle in [
    "H11 perf-baseline",
    "首启<2s",
    "首token<800ms",
    "召回<200ms",
    "10k 文档库",
    "llama3.2:3b",
    "H11 / H12 三平台全绿",
]:
    if needle not in spec_text:
        die(f"V3 specs no longer mention H11 invariant {needle!r}")
pass_count += 1

valid_paths = sorted(valid_dir.glob("*.json"))
invalid_paths = sorted(invalid_dir.glob("*.json"))
if {path.name for path in valid_paths} != EXPECTED_VALID_FILES:
    die(f"valid fixture roster drifted: {[path.name for path in valid_paths]}")
if {path.name for path in invalid_paths} != EXPECTED_INVALID_FILES:
    die(f"invalid fixture roster drifted: {[path.name for path in invalid_paths]}")
pass_count += 1

seen_platforms: set[str] = set()
for path in valid_paths:
    fixture = load(path)
    if not isinstance(fixture, dict):
        die(f"{path} top-level must be object")
    schema_only = schema_errors(fixture, schema)
    if schema_only:
        die(f"{path} schema errors: {schema_only}")
    errors = semantic_errors(fixture)
    if errors:
        die(f"{path} semantic errors: {errors}")
    seen_platforms.add(fixture["platform"])

if seen_platforms != set(EXPECTED_PLATFORMS):
    die(f"valid fixtures must cover all platforms, saw {sorted(seen_platforms)}")
pass_count += 1

for path in invalid_paths:
    fixture = load(path)
    if not isinstance(fixture, dict):
        die(f"{path} top-level must be object")
    errors = semantic_errors(fixture)
    if not errors:
        die(f"{path} unexpectedly passed semantic perf checks")
pass_count += 1

for path in valid_paths:
    fixture = load(path)
    workload = fixture["workload"]
    if workload["coldStart"]["targetMs"] != 2000:
        die(f"{path} coldStart target drifted")
    if workload["firstToken"]["targetMs"] != 800:
        die(f"{path} firstToken target drifted")
    if workload["retrieval"]["targetMs"] != 200:
        die(f"{path} retrieval target drifted")
pass_count += 1

print("Status: passed")
print("Harness: H11 perf-baseline target contract")
print(f"Valid fixtures: {len(valid_paths)}")
print(f"Invalid fixtures: {len(invalid_paths)}")
print("Targets: coldStart=2000ms firstToken=800ms retrieval=200ms")
print("Runtime samples: deferred until W9 implementation gate")
print(f"Checks: {pass_count}")
PY
