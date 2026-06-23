#!/usr/bin/env bash
# V3 H9 — eval-baseline seed contract.
#
# This is not an LLM quality benchmark yet. It locks the first V3 eval
# fixture shape, expected-patch references, token counts, scoring methods,
# reference baseline, LLM-judge reproducibility policy, and V2 regression
# requirement so later W1/W6 runtime work has a stable baseline to execute
# against.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

capability_dir="docs/qa/fixtures/v3/eval/capability"
regression_dir="docs/qa/fixtures/v3/eval/regression"
expected_dir="docs/qa/fixtures/v3/eval/expected-patches"
invalid_dir="docs/qa/fixtures/v3/eval/invalid"
spec="docs/product/v3/w5-eval-harness-spec.md"
judge_prompt_library="docs/product/v3/w5-judge-prompt-library.md"
capability_schema="docs/schemas/eval-capability-fixture.schema.json"
expected_patch_schema="docs/schemas/eval-expected-patch.schema.json"
regression_schema="docs/schemas/eval-regression-fixture.schema.json"

[[ -d "$capability_dir" ]] || fail "missing $capability_dir"
[[ -d "$regression_dir" ]] || fail "missing $regression_dir"
[[ -d "$expected_dir" ]] || fail "missing $expected_dir"
[[ -d "$invalid_dir" ]] || fail "missing $invalid_dir"
[[ -f "$spec" ]] || fail "missing $spec"
[[ -f "$judge_prompt_library" ]] || fail "missing $judge_prompt_library"
[[ -f "$capability_schema" ]] || fail "missing $capability_schema"
[[ -f "$expected_patch_schema" ]] || fail "missing $expected_patch_schema"
[[ -f "$regression_schema" ]] || fail "missing $regression_schema"

python3 - "$capability_dir" "$regression_dir" "$expected_dir" "$invalid_dir" "$spec" "$judge_prompt_library" "$capability_schema" "$expected_patch_schema" "$regression_schema" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

capability_dir = Path(sys.argv[1])
regression_dir = Path(sys.argv[2])
expected_dir = Path(sys.argv[3])
invalid_dir = Path(sys.argv[4])
spec_path = Path(sys.argv[5])
judge_prompt_library_path = Path(sys.argv[6])
capability_schema_path = Path(sys.argv[7])
expected_patch_schema_path = Path(sys.argv[8])
regression_schema_path = Path(sys.argv[9])

EXPECTED_CAPABILITIES = {
    "v3-eval-w1-rewrite-formal-writer-001": {
        "surface": "writer",
        "patchType": "ParagraphAction",
        "tokenCount": 7,
        "method": "fuzzy",
    },
    "v3-eval-w1-cell-format-date-calc-001": {
        "surface": "calc",
        "patchType": "CellAction",
        "tokenCount": 5,
        "method": "exact",
    },
    "v3-eval-w1-slide-summarize-impress-001": {
        "surface": "impress",
        "patchType": "SlideElementAction",
        "tokenCount": 4,
        "method": "fuzzy",
    },
}

TOKEN_LOCK = {
    "ParagraphAction": 7,
    "CellAction": 5,
    "SlideElementAction": 4,
}
SURFACES = {"writer", "calc", "impress"}
SCORING_METHODS = {"exact", "fuzzy", "llm-judge"}
REQUIRED_EVIDENCE = {"provider-call", "user-approval"}
REFERENCE_BASELINE = {
    "id": "v2-ga-acceptance",
    "source": "v2-ga",
    "versionPolicy": "frozen-at-v2-ga",
    "frozenAtLedger": "L211",
    "requiresV2RegressionGreen": True,
    "runtimeReferenceImplementation": "not-started",
}
LLM_JUDGE_POLICY = {
    "enabled": False,
    "promptLibrary": "docs/product/v3/w5-judge-prompt-library.md",
    "promptId": "judge-v3-capability-v1",
    "promptVersion": "v1",
    "deterministicParameters": {
        "temperature": 0,
        "topP": 1,
        "seedRequired": True,
    },
    "defaultReleaseGate": False,
    "requiresHumanReviewForPublish": True,
    "runtimeJudgeImplementation": "not-started",
}


def die(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def load(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        die(f"{path} top-level must be object")
    return value


def require_keys(label: str, obj: dict[str, Any], required: set[str]) -> None:
    missing = sorted(required - set(obj))
    if missing:
        die(f"{label} missing keys: {missing}")


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
    if expected == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    return True


def validate_schema(value: Any, schema: dict[str, Any], path: list[str]) -> list[str]:
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

    if isinstance(value, (int, float)) and not isinstance(value, bool):
        minimum = schema.get("minimum")
        maximum = schema.get("maximum")
        if isinstance(minimum, (int, float)) and value < minimum:
            errors.append(f"{json_pointer(path)} below minimum {minimum}")
        if isinstance(maximum, (int, float)) and value > maximum:
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
                errors.extend(validate_schema(item, item_schema, path + [str(index)]))

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
                    errors.extend(validate_schema(value[key], child_schema, path + [key]))
    return errors


def require_schema_shape(path: Path, schema: dict[str, Any], required: list[str]) -> None:
    if schema.get("type") != "object":
        die(f"{path} top-level type must be object")
    if schema.get("required") != required:
        die(f"{path} required list drifted: {schema.get('required')!r}")
    if schema.get("additionalProperties") is not False:
        die(f"{path} must reject unknown top-level properties")


def expect_schema_pass(path: Path, schema: dict[str, Any]) -> None:
    errors = validate_schema(load(path), schema, [])
    if errors:
        die(f"{path} violates schema:\n" + "\n".join(errors))


def expect_schema_fail(path: Path, schema: dict[str, Any]) -> None:
    errors = validate_schema(load(path), schema, [])
    if not errors:
        die(f"{path} unexpectedly passed its invalid schema guard")


pass_count = 0

capability_schema = load(capability_schema_path)
expected_patch_schema = load(expected_patch_schema_path)
regression_schema = load(regression_schema_path)
require_schema_shape(
    capability_schema_path,
    capability_schema,
    ["id", "wave", "category", "surface", "referenceBaseline", "llmJudgePolicy", "input", "expected", "scoring"],
)
require_schema_shape(
    expected_patch_schema_path,
    expected_patch_schema,
    ["patchType", "tokenCount", "requiredEvidence", "mustPreserveUndo"],
)
require_schema_shape(
    regression_schema_path,
    regression_schema,
    ["id", "wave", "category", "requires", "command", "expected"],
)

spec_text = spec_path.read_text(encoding="utf-8")
judge_prompt_library_text = judge_prompt_library_path.read_text(encoding="utf-8")
for needle in ["H9", "Capability eval", "capability/", "regression/", "exact", "fuzzy", "LLM-judge"]:
    if needle not in spec_text:
        die(f"W5 spec no longer mentions {needle!r}")
for needle in [
    "judge-v3-capability-v1",
    "temperature=0",
    "topP=1",
    "seedRequired=true",
    "Default release gate",
    "not-started",
]:
    if needle not in judge_prompt_library_text:
        die(f"judge prompt library no longer mentions {needle!r}")
pass_count += 1

capability_paths = sorted(capability_dir.glob("*.json"))
regression_paths = sorted(regression_dir.glob("*.json"))
expected_paths = sorted(expected_dir.glob("*.patch.json"))
if len(capability_paths) != 3:
    die(f"expected 3 capability fixtures, found {len(capability_paths)}")
if len(regression_paths) != 1:
    die(f"expected 1 regression fixture, found {len(regression_paths)}")
if len(expected_paths) != 3:
    die(f"expected 3 expected patch fixtures, found {len(expected_paths)}")
pass_count += 1

invalid_capability_paths = sorted((invalid_dir / "capability").glob("*.json"))
invalid_expected_paths = sorted((invalid_dir / "expected-patches").glob("*.patch.json"))
invalid_regression_paths = sorted((invalid_dir / "regression").glob("*.json"))
if len(invalid_capability_paths) != 4:
    die(f"expected 4 invalid capability fixtures, found {len(invalid_capability_paths)}")
if len(invalid_expected_paths) != 1:
    die(f"expected 1 invalid expected patch fixture, found {len(invalid_expected_paths)}")
if len(invalid_regression_paths) != 1:
    die(f"expected 1 invalid regression fixture, found {len(invalid_regression_paths)}")
for path in capability_paths:
    expect_schema_pass(path, capability_schema)
for path in expected_paths:
    expect_schema_pass(path, expected_patch_schema)
for path in regression_paths:
    expect_schema_pass(path, regression_schema)
for path in invalid_capability_paths:
    expect_schema_fail(path, capability_schema)
for path in invalid_expected_paths:
    expect_schema_fail(path, expected_patch_schema)
for path in invalid_regression_paths:
    expect_schema_fail(path, regression_schema)
pass_count += 1

expected_patch_relpaths = {str(path) for path in expected_paths}
seen_ids: set[str] = set()
seen_surfaces: set[str] = set()
seen_patch_types: set[str] = set()

for path in capability_paths:
    fixture = load(path)
    label = str(path)
    require_keys(
        label,
        fixture,
        {"id", "wave", "category", "surface", "referenceBaseline", "llmJudgePolicy", "input", "expected", "scoring"},
    )
    fid = fixture["id"]
    if fid in seen_ids:
        die(f"duplicate fixture id {fid}")
    seen_ids.add(fid)
    expected_meta = EXPECTED_CAPABILITIES.get(fid)
    if not expected_meta:
        die(f"unexpected capability fixture id {fid}")

    if fixture["wave"] != "w1":
        die(f"{fid} wave must be w1")
    if fixture["category"] != "capability":
        die(f"{fid} category must be capability")
    if fixture["surface"] not in SURFACES:
        die(f"{fid} invalid surface {fixture['surface']!r}")
    if fixture["surface"] != expected_meta["surface"]:
        die(f"{fid} surface drifted")
    seen_surfaces.add(fixture["surface"])

    reference = fixture["referenceBaseline"]
    if not isinstance(reference, dict):
        die(f"{fid} referenceBaseline must be object")
    if reference != REFERENCE_BASELINE:
        die(f"{fid} referenceBaseline drifted: {reference!r}")

    llm_judge_policy = fixture.get("llmJudgePolicy")
    if not isinstance(llm_judge_policy, dict):
        die(f"{fid} llmJudgePolicy must be object")
    if llm_judge_policy != LLM_JUDGE_POLICY:
        die(f"{fid} llmJudgePolicy drifted: {llm_judge_policy!r}")

    input_obj = fixture["input"]
    if not isinstance(input_obj, dict):
        die(f"{fid} input must be object")
    require_keys(f"{fid}.input", input_obj, {"documentSnapshot", "selection", "userPrompt", "context"})
    if not isinstance(input_obj["documentSnapshot"], str) or not input_obj["documentSnapshot"]:
        die(f"{fid} documentSnapshot must be non-empty string")
    if not isinstance(input_obj["selection"], dict):
        die(f"{fid} selection must be object")
    if not isinstance(input_obj["userPrompt"], str) or len(input_obj["userPrompt"]) < 4:
        die(f"{fid} userPrompt too short")
    if not isinstance(input_obj["context"], list):
        die(f"{fid} context must be array")

    expected = fixture["expected"]
    if not isinstance(expected, dict):
        die(f"{fid} expected must be object")
    require_keys(f"{fid}.expected", expected, {"patchRef", "patchType", "tokenCount", "diffSimilarity"})
    patch_ref = expected["patchRef"]
    if patch_ref not in expected_patch_relpaths:
        die(f"{fid} patchRef {patch_ref!r} does not point at a checked expected patch fixture")
    patch_type = expected["patchType"]
    if patch_type != expected_meta["patchType"]:
        die(f"{fid} patchType drifted")
    token_count = expected["tokenCount"]
    if TOKEN_LOCK.get(patch_type) != token_count:
        die(f"{fid} tokenCount {token_count!r} violates V2 token lock for {patch_type}")
    if token_count != expected_meta["tokenCount"]:
        die(f"{fid} tokenCount drifted")
    seen_patch_types.add(patch_type)
    diff_similarity = expected["diffSimilarity"]
    if not isinstance(diff_similarity, str) or not re.match(r"^>= 0\.[0-9]+$", diff_similarity):
        die(f"{fid} diffSimilarity must be a string like '>= 0.85'")

    scoring = fixture["scoring"]
    if not isinstance(scoring, dict):
        die(f"{fid} scoring must be object")
    require_keys(f"{fid}.scoring", scoring, {"method", "threshold"})
    if scoring["method"] not in SCORING_METHODS:
        die(f"{fid} unknown scoring method {scoring['method']!r}")
    if scoring["method"] != expected_meta["method"]:
        die(f"{fid} scoring method drifted")
    threshold = scoring["threshold"]
    if not isinstance(threshold, (int, float)) or isinstance(threshold, bool) or threshold <= 0 or threshold > 1:
        die(f"{fid} scoring threshold must be in (0, 1]")

pass_count += 1

if seen_surfaces != SURFACES:
    die(f"capability fixtures must cover writer/calc/impress, saw {sorted(seen_surfaces)}")
if seen_patch_types != set(TOKEN_LOCK):
    die(f"capability fixtures must cover all V2 token-lock patch types, saw {sorted(seen_patch_types)}")
pass_count += 1

if {load(path)["referenceBaseline"]["id"] for path in capability_paths} != {"v2-ga-acceptance"}:
    die("capability fixtures must use only the V2 GA acceptance reference baseline")
if any(load(path)["referenceBaseline"].get("runtimeReferenceImplementation") != "not-started" for path in capability_paths):
    die("capability fixtures must not claim runtime reference implementation")
if "W5 Q2" not in spec_text or "v2-ga-acceptance" not in spec_text:
    die("W5 spec must document the H9 reference baseline decision")
pass_count += 1

for path in capability_paths:
    policy = load(path)["llmJudgePolicy"]
    if policy["enabled"] is not False:
        die(f"{path} must keep LLM judge opt-in and disabled by default")
    if policy["defaultReleaseGate"] is not False:
        die(f"{path} must not make LLM judge a default release gate")
    if policy["runtimeJudgeImplementation"] != "not-started":
        die(f"{path} must not claim runtime LLM-judge implementation")
    params = policy["deterministicParameters"]
    if params != {"temperature": 0, "topP": 1, "seedRequired": True}:
        die(f"{path} LLM-judge deterministic parameters drifted")
if "W5 Q1" not in spec_text or "judge-v3-capability-v1" not in spec_text:
    die("W5 spec must document the LLM-judge reproducibility decision")
pass_count += 1

for path in expected_paths:
    patch = load(path)
    label = str(path)
    require_keys(label, patch, {"patchType", "tokenCount", "requiredEvidence", "mustPreserveUndo"})
    patch_type = patch["patchType"]
    if patch_type not in TOKEN_LOCK:
        die(f"{label} unexpected patchType {patch_type!r}")
    if patch["tokenCount"] != TOKEN_LOCK[patch_type]:
        die(f"{label} tokenCount violates V2 token lock")
    evidence = patch["requiredEvidence"]
    if not isinstance(evidence, list) or not REQUIRED_EVIDENCE.issubset(set(evidence)):
        die(f"{label} requiredEvidence must include {sorted(REQUIRED_EVIDENCE)}")
    if patch["mustPreserveUndo"] is not True:
        die(f"{label} mustPreserveUndo must be true")
pass_count += 1

regression = load(regression_paths[0])
require_keys(str(regression_paths[0]), regression, {"id", "wave", "category", "requires", "command", "expected"})
if regression["id"] != "v3-regression-v2-contract-sweep-001":
    die("regression fixture id drifted")
if regression["wave"] != "regression" or regression["category"] != "regression":
    die("regression fixture wave/category drifted")
requires = regression["requires"]
if not isinstance(requires, dict):
    die("regression.requires must be object")
if requires.get("v15StrictRoundtrip") != "27/27":
    die("regression must require V1.5 27/27")
if requires.get("v2Sweep") != "H1-H10":
    die("regression must require V2 H1-H10")
if requires.get("v2FixtureFloor") != 36:
    die("regression fixture floor drifted")
if regression["command"] != "bash bin/v2-harness-sweep.sh --with-fixtures":
    die("regression command drifted")
expected = regression["expected"]
if expected.get("status") != "passed" or expected.get("fixtureFailures") != 0:
    die("regression expected result drifted")
pass_count += 1

print("Status: passed")
print("Harness: H9 eval-baseline seed")
print(f"Capability fixtures: {len(capability_paths)}")
print(f"Regression fixtures: {len(regression_paths)}")
print(f"Expected patch fixtures: {len(expected_paths)}")
print("Schemas: capability/expected-patch/regression")
print("Reference baseline: v2-ga-acceptance")
print("LLM judge policy: opt-in deterministic prompt library")
print(
    "Invalid schema guards: "
    f"{len(invalid_capability_paths) + len(invalid_expected_paths) + len(invalid_regression_paths)}"
)
print("Token lock: ParagraphAction=7 CellAction=5 SlideElementAction=4")
print("Regression: V1.5 27/27 + V2 H1-H10 + fixtures floor 36/0")
print(f"Checks: {pass_count}")
PY
