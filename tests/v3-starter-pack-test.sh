#!/usr/bin/env bash
# V3 W9 - starter-pack contract self-test.
#
# Contract-first gate for the W9 30-template starter pack. It does not create
# the gated template assets, installer wiring, or product integration. It locks
# the manifest shape that the runtime starter pack must satisfy before V3 GA.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

schema_path="docs/schemas/starter-pack-manifest.schema.json"
w9_spec="docs/product/v3/w9-market-readiness-spec.md"
w5_spec="docs/product/v3/w5-eval-harness-spec.md"
master_plan="docs/product/v3-master-plan.md"
sweep="bin/v3-eval-sweep.sh"
workflow=".github/workflows/v3-contract-harnesses.yml"
valid_dir="docs/qa/fixtures/v3/starter-pack/valid"
invalid_dir="docs/qa/fixtures/v3/starter-pack/invalid"

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
from collections import Counter
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

REQUIRED = ["id", "schemaVersion", "createdAt", "pack", "coverage", "templates", "installation", "evidence", "gates"]
EXPECTED_VALID_FILES = {"full-30-template-pack.json"}
EXPECTED_INVALID_FILES = {
    "missing-template.json",
    "wrong-surface-count.json",
    "sample-patch-not-required.json",
    "network-required.json",
}
EXPECTED_SCENARIOS = {
    "meeting-notes",
    "okr",
    "prd",
    "weekly-report",
    "contract-brief",
    "budget",
    "sales-dashboard",
    "project-gantt",
    "roadshow",
    "retrospective",
}
EXPECTED_SURFACES = {"writer", "calc", "impress"}
EXPECTED_ACTION = {
    "writer": "ParagraphAction",
    "calc": "CellAction",
    "impress": "SlideElementAction",
}
EXPECTED_EXT = {
    "writer": ".ott",
    "calc": ".ots",
    "impress": ".otp",
}
BASE_EVIDENCE = {"starter-pack-manifest", "template-install", "sample-patch-result", "evidence-record", "v2-regression-green"}


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
    coverage = value.get("coverage", {})
    templates = value.get("templates", [])
    installation = value.get("installation", {})
    evidence = set(value.get("evidence", {}).get("required", []))

    if coverage.get("templateCount") != 30 or len(templates) != 30:
        errors.append("starter pack must contain exactly 30 templates")
    if coverage.get("businessScenarioCount") != 10:
        errors.append("starter pack must cover 10 business scenarios")
    if coverage.get("patchSmokeRequired") is not True:
        errors.append("starter pack must require patch smoke coverage")

    surface_counts = Counter(template.get("surface") for template in templates)
    if surface_counts != {"writer": 10, "calc": 10, "impress": 10}:
        errors.append(f"surface counts must be writer/calc/impress=10 each, saw {dict(surface_counts)}")
    if coverage.get("perSurfaceCount") != {"writer": 10, "calc": 10, "impress": 10}:
        errors.append("coverage.perSurfaceCount must lock writer/calc/impress to 10 each")

    scenario_counts = Counter(template.get("scenario") for template in templates)
    if set(scenario_counts) != EXPECTED_SCENARIOS or any(count != 3 for count in scenario_counts.values()):
        errors.append(f"each of 10 scenarios must appear once per surface, saw {dict(scenario_counts)}")

    ids = [template.get("id") for template in templates]
    paths = [template.get("path") for template in templates]
    if len(ids) != len(set(ids)):
        errors.append("template ids must be unique")
    if len(paths) != len(set(paths)):
        errors.append("template paths must be unique")

    for template in templates:
        surface = template.get("surface")
        path = template.get("path", "")
        sample_patch = template.get("samplePatch", {})
        boundary = template.get("dataBoundary", {})
        if surface not in EXPECTED_SURFACES:
            errors.append(f"unknown surface {surface!r}")
            continue
        if not path.startswith(f"templates/v3-starter-pack/{surface}/") or not path.endswith(EXPECTED_EXT[surface]):
            errors.append(f"{template.get('id')} path/surface extension drifted")
        if sample_patch.get("actionKind") != EXPECTED_ACTION[surface]:
            errors.append(f"{template.get('id')} samplePatch actionKind must match surface")
        if sample_patch.get("required") is not True or sample_patch.get("mustSucceed") is not True:
            errors.append(f"{template.get('id')} sample patch must be required and successful")
        if sample_patch.get("requiresUndo") is not True or sample_patch.get("evidenceRequired") is not True:
            errors.append(f"{template.get('id')} sample patch must require undo and evidence")
        if boundary.get("storesDocumentContent") is not False or boundary.get("publicEgress") is not False or boundary.get("localFirst") is not True:
            errors.append(f"{template.get('id')} data boundary must be local-only and hash/metadata-only")

    if installation.get("installable") is not True or installation.get("requiresNetwork") is not False:
        errors.append("starter pack must be installable without network")
    if installation.get("w8SelfHostedCompatible") is not True:
        errors.append("starter pack must be W8 self-host compatible")
    if not BASE_EVIDENCE.issubset(evidence):
        errors.append("starter pack evidence requirements drifted")
    if value.get("gates", {}).get("runtimeImplementation") != "not-started":
        errors.append("starter pack runtime implementation must remain gated")
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
if props.get("templates", {}).get("minItems") != 30 or props.get("templates", {}).get("maxItems") != 30:
    die("schema must lock exactly 30 templates")
if props.get("coverage", {}).get("properties", {}).get("businessScenarioCount", {}).get("const") != 10:
    die("businessScenarioCount must stay 10")
if props.get("installation", {}).get("properties", {}).get("requiresNetwork", {}).get("const") is not False:
    die("starter pack must not require network")
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
        die(f"{path} violates W9 starter-pack semantics:\n" + "\n".join(semantic))
pass_count += 1

value = load(valid_paths[0])
templates = value["templates"]
surface_counts = Counter(template["surface"] for template in templates)
scenario_counts = Counter(template["scenario"] for template in templates)
action_counts = Counter(template["samplePatch"]["actionKind"] for template in templates)
if surface_counts != {"writer": 10, "calc": 10, "impress": 10}:
    die(f"valid fixture surface counts drifted: {dict(surface_counts)}")
if set(scenario_counts) != EXPECTED_SCENARIOS or any(count != 3 for count in scenario_counts.values()):
    die(f"valid fixture scenario coverage drifted: {dict(scenario_counts)}")
if action_counts != {"ParagraphAction": 10, "CellAction": 10, "SlideElementAction": 10}:
    die(f"valid fixture action coverage drifted: {dict(action_counts)}")
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
for needle in ["documentContent", "publicEndpoint", "requiresCloud", "paywall"]:
    if needle in raw:
        die(f"{valid_paths[0]} contains forbidden starter-pack marker {needle!r}")
pass_count += 1

w9_text = w9_spec.read_text(encoding="utf-8")
w5_text = w5_spec.read_text(encoding="utf-8")
master_text = master_plan.read_text(encoding="utf-8")
sweep_text = sweep_path.read_text(encoding="utf-8")
workflow_text = workflow_path.read_text(encoding="utf-8")
for path, text, needles in [
    (w9_spec, w9_text, ["starter-pack self-test", "Checks: 8", "starter-pack-manifest", "30 templates", "10 business scenarios"]),
    (w5_spec, w5_text, ["tests/v3-starter-pack-test.sh", "starter-pack self-test"]),
    (master_plan, master_text, ["starter-pack-manifest.schema.json", "tests/v3-starter-pack-test.sh"]),
    (sweep_path, sweep_text, ["tests/v3-starter-pack-test.sh", "W9 starter-pack self-test"]),
    (workflow_path, workflow_text, ["docs/schemas/starter-pack-manifest.schema.json", "bin/v3-eval-sweep.sh --self-test"]),
]:
    for needle in needles:
        if needle not in text:
            die(f"{path} missing {needle!r}")
pass_count += 1

if pass_count != 7:
    die(f"internal pass_count drifted before final increment: {pass_count}")
pass_count += 1

print("Status: passed")
print("Harness: W9 starter-pack self-test")
print(f"Schema: {schema_path}")
print(f"Valid fixtures: {len(valid_paths)}")
print(f"Invalid fixtures: {len(invalid_paths)}")
print("Starter pack contract: 30 templates, 10 scenarios, 3 surfaces, patch evidence")
print("Runtime implementation: deferred until W9 gate")
print(f"Checks: {pass_count}")
PY
