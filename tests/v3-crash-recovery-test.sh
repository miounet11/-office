#!/usr/bin/env bash
# V3 H12 - crash-recovery target contract.
#
# This does not run live SIGKILL/restart recovery yet. It locks the W9
# autosave/recovery target, platform fixture roster, local-only storage
# requirement, and evidence fields that future runtime samples must satisfy.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

schema="docs/schemas/crash-recovery-targets.schema.json"
w5_spec="docs/product/v3/w5-eval-harness-spec.md"
w9_spec="docs/product/v3/w9-market-readiness-spec.md"
valid_dir="docs/qa/fixtures/v3/recovery/valid"
invalid_dir="docs/qa/fixtures/v3/recovery/invalid"

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

EXPECTED_REQUIRED = ["id", "wave", "category", "platform", "measurementMode", "scenario", "evidence"]
EXPECTED_PLATFORMS = ["macos-arm64", "linux-x86_64", "windows-x86_64"]
EXPECTED_VALID_FILES = {
    "macos-writer-unsaved-text.json",
    "linux-calc-unsaved-grid.json",
    "windows-impress-unsaved-slide.json",
}
EXPECTED_INVALID_FILES = {
    "slow-recovery-dialog.json",
    "allows-data-loss.json",
    "missing-diff-zero-evidence.json",
}
EXPECTED_EVIDENCE = {
    "autosave-snapshot",
    "sigkill-marker",
    "recovery-dialog-shown",
    "restore-applied",
    "diff-zero-proof",
}
EXPECTED_SURFACES = {
    "macos-arm64": ("writer", "text-insert"),
    "linux-x86_64": ("calc", "cell-edit"),
    "windows-x86_64": ("impress", "slide-text-edit"),
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
        if isinstance(min_length, int) and len(value) < min_length:
            errors.append(f"{json_pointer(path)} shorter than minLength {min_length}")

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
    scenario = fixture.get("scenario", {})
    trigger = scenario.get("crashTrigger", {})
    edit = scenario.get("unsavedEdit", {})
    autosave = scenario.get("autosave", {})
    recovery = scenario.get("recovery", {})
    evidence = fixture.get("evidence", {})

    if fixture.get("wave") != "w9":
        errors.append("wave must be w9")
    if fixture.get("category") != "crash-recovery":
        errors.append("category must be crash-recovery")
    if fixture.get("measurementMode") != "target-contract":
        errors.append("measurementMode must be target-contract until runtime samples land")

    expected_surface = EXPECTED_SURFACES.get(platform)
    if expected_surface is None:
        errors.append(f"unexpected platform {platform!r}")
    else:
        surface, edit_kind = expected_surface
        if scenario.get("documentSurface") != surface:
            errors.append(f"{platform} documentSurface drifted")
        if edit.get("editKind") != edit_kind:
            errors.append(f"{platform} editKind drifted")

    if trigger.get("mode") != "sigkill":
        errors.append("crashTrigger.mode must be sigkill")
    if trigger.get("processState") != "editing-unsaved":
        errors.append("crashTrigger.processState must be editing-unsaved")
    if edit.get("includesUnsavedState") is not True:
        errors.append("unsavedEdit.includesUnsavedState must be true")
    if not isinstance(edit.get("minCharacters"), int) or edit.get("minCharacters") < 1:
        errors.append("unsavedEdit.minCharacters must be positive")

    if autosave.get("intervalSeconds") != 30:
        errors.append("autosave.intervalSeconds must be exactly 30")
    if autosave.get("storage") != "local-file-only":
        errors.append("autosave.storage must be local-file-only")
    if autosave.get("publicEgress") is not False:
        errors.append("autosave.publicEgress must be false")

    if recovery.get("dialog") != "RecoveryDialog":
        errors.append("recovery.dialog must be RecoveryDialog")
    if recovery.get("maxDialogSeconds") != 30:
        errors.append("recovery.maxDialogSeconds must be exactly 30")
    if recovery.get("oneClickRestore") is not True:
        errors.append("recovery.oneClickRestore must be true")
    if recovery.get("diffExpected") != "zero":
        errors.append("recovery.diffExpected must be zero")
    if recovery.get("dataLossTolerance") != "none":
        errors.append("recovery.dataLossTolerance must be none")

    required = evidence.get("required", [])
    if set(required) != EXPECTED_EVIDENCE:
        errors.append(f"evidence.required drifted: {required!r}")
    if evidence.get("blocksGA") is not True:
        errors.append("evidence.blocksGA must be true")
    return errors


schema = load(schema_path)
if not isinstance(schema, dict):
    die("crash-recovery schema top-level is not an object")

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

scenario_schema = props.get("scenario", {})
if scenario_schema.get("required") != ["documentSurface", "crashTrigger", "unsavedEdit", "autosave", "recovery"]:
    die("scenario.required drifted")
if scenario_schema.get("additionalProperties") is not False:
    die("scenario must set additionalProperties:false")
pass_count += 1

spec_text = w5_spec.read_text(encoding="utf-8") + "\n" + w9_spec.read_text(encoding="utf-8")
for needle in [
    "H12 crash-recovery",
    "RecoveryDialog",
    "diff = 0",
    "30s",
    "H11 / H12",
]:
    if needle not in spec_text:
        die(f"V3 specs no longer mention H12 invariant {needle!r}")
pass_count += 1

valid_paths = sorted(valid_dir.glob("*.json"))
invalid_paths = sorted(invalid_dir.glob("*.json"))
if {path.name for path in valid_paths} != EXPECTED_VALID_FILES:
    die(f"valid fixture roster drifted: {[path.name for path in valid_paths]}")
if {path.name for path in invalid_paths} != EXPECTED_INVALID_FILES:
    die(f"invalid fixture roster drifted: {[path.name for path in invalid_paths]}")
pass_count += 1

seen_platforms: set[str] = set()
seen_surfaces: set[str] = set()
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
    seen_surfaces.add(fixture["scenario"]["documentSurface"])

if seen_platforms != set(EXPECTED_PLATFORMS):
    die(f"valid fixtures must cover all platforms, saw {sorted(seen_platforms)}")
if seen_surfaces != {"writer", "calc", "impress"}:
    die(f"valid fixtures must cover writer/calc/impress, saw {sorted(seen_surfaces)}")
pass_count += 1

for path in invalid_paths:
    fixture = load(path)
    if not isinstance(fixture, dict):
        die(f"{path} top-level must be object")
    errors = schema_errors(fixture, schema) + semantic_errors(fixture)
    if not errors:
        die(f"{path} unexpectedly passed crash-recovery checks")
pass_count += 1

for path in valid_paths:
    fixture = load(path)
    scenario = fixture["scenario"]
    if scenario["autosave"]["intervalSeconds"] != 30:
        die(f"{path} autosave interval drifted")
    if scenario["recovery"]["maxDialogSeconds"] != 30:
        die(f"{path} recovery dialog target drifted")
    if scenario["recovery"]["diffExpected"] != "zero":
        die(f"{path} diff target drifted")
pass_count += 1

for path in valid_paths:
    fixture = load(path)
    if set(fixture["evidence"]["required"]) != EXPECTED_EVIDENCE:
        die(f"{path} evidence roster drifted")
    if fixture["evidence"]["blocksGA"] is not True:
        die(f"{path} blocksGA drifted")
pass_count += 1

print("Status: passed")
print("Harness: H12 crash-recovery target contract")
print(f"Valid fixtures: {len(valid_paths)}")
print(f"Invalid fixtures: {len(invalid_paths)}")
print("Targets: autosave=30s recoveryDialog=30s diff=0")
print("Runtime SIGKILL samples: deferred until W9 implementation gate")
print(f"Checks: {pass_count}")
PY
