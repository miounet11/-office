#!/usr/bin/env bash
# V3 W5 - eval-report field self-test.
#
# Meta-gate for W5 reporting. This does not run model scoring or runtime
# samples; it locks the Markdown/JSON report fields that the active H8-H12
# contract sweep must publish once real wave reports are generated.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

schema="docs/schemas/eval-report.schema.json"
sample="docs/product/v3/eval-reports/v3-contract-self-test.json"
template="docs/product/v3/eval-reports/template.md"
sweep="bin/v3-eval-sweep.sh"
workflow=".github/workflows/v3-contract-harnesses.yml"
w5_spec="docs/product/v3/w5-eval-harness-spec.md"
master_plan="docs/product/v3-master-plan.md"

[[ -f "$schema" ]] || fail "missing $schema"
[[ -f "$sample" ]] || fail "missing $sample"
[[ -f "$template" ]] || fail "missing $template"
[[ -f "$sweep" ]] || fail "missing $sweep"
[[ -f "$workflow" ]] || fail "missing $workflow"
[[ -f "$w5_spec" ]] || fail "missing $w5_spec"
[[ -f "$master_plan" ]] || fail "missing $master_plan"

python3 - "$schema" "$sample" "$template" "$sweep" "$workflow" "$w5_spec" "$master_plan" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

schema_path = Path(sys.argv[1])
sample_path = Path(sys.argv[2])
template_path = Path(sys.argv[3])
sweep_path = Path(sys.argv[4])
workflow_path = Path(sys.argv[5])
w5_spec_path = Path(sys.argv[6])
master_plan_path = Path(sys.argv[7])
archive_policy_path = Path("docs/product/v3/w5-report-archive-policy.md")

EXPECTED_REQUIRED = ["id", "version", "generatedAt", "scope", "baseline", "harnesses", "summary", "artifacts", "archivePolicy", "gates"]
EXPECTED_HARNESS_CHECKS = {
    "H8": 16,
    "H9": 9,
    "H10": 10,
    "H11": 8,
    "H12": 9,
}
EXPECTED_HARNESS_COMMANDS = {
    "H8": "bash tests/v3-connector-manifest-contract-test.sh",
    "H9": "bash tests/v3-eval-baseline-test.sh",
    "H10": "bash tests/v3-local-cloud-no-egress-test.sh",
    "H11": "bash tests/v3-perf-baseline-test.sh",
    "H12": "bash tests/v3-crash-recovery-test.sh",
}
EXPECTED_ROOTS = [
    "docs/qa/fixtures/v3/connector/",
    "docs/qa/fixtures/v3/eval/",
    "docs/qa/fixtures/v3/localcloud/",
    "docs/qa/fixtures/v3/perf/",
    "docs/qa/fixtures/v3/recovery/",
]
EXPECTED_TOTAL = sum(EXPECTED_HARNESS_CHECKS.values())


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


def require_path(path_text: str) -> None:
    path = Path(path_text.rstrip("/"))
    if not path.exists():
        die(f"report artifact path does not exist: {path_text}")


schema = load(schema_path)
if not isinstance(schema, dict):
    die("eval-report schema top-level is not an object")

pass_count = 0

if schema.get("required") != EXPECTED_REQUIRED:
    die(f"schema.required drifted: {schema.get('required')!r}")
if schema.get("additionalProperties") is not False:
    die("schema must set top-level additionalProperties:false")
pass_count += 1

props = schema.get("properties", {})
if props.get("scope", {}).get("properties", {}).get("mode", {}).get("enum") != ["v3-contract-sweep", "nightly", "release-candidate"]:
    die("scope.mode enum drifted")
if props.get("baseline", {}).get("properties", {}).get("v15StrictRoundtrip", {}).get("const") != "27/27":
    die("V1.5 baseline const drifted")
if props.get("baseline", {}).get("properties", {}).get("v2Sweep", {}).get("const") != "H1-H10":
    die("V2 sweep baseline const drifted")
if props.get("artifacts", {}).get("properties", {}).get("schema", {}).get("const") != str(schema_path):
    die("artifact schema const drifted")
pass_count += 1

report = load(sample_path)
if not isinstance(report, dict):
    die("sample report top-level is not an object")
errors = validate(report, schema, [])
if errors:
    die("sample report violates schema:\n" + "\n".join(errors))
pass_count += 1

if report.get("id") != "v3-eval-report-contract-self-test":
    die("sample report id drifted")
if report.get("scope", {}).get("contractOnly") is not True:
    die("self-test sample must remain contract-only")
if report.get("scope", {}).get("runtimeImplementation") != "not-started":
    die("self-test sample must not claim runtime implementation")
baseline = report.get("baseline", {})
if baseline.get("v3Harnesses") != list(EXPECTED_HARNESS_CHECKS):
    die(f"v3Harnesses drifted: {baseline.get('v3Harnesses')!r}")
if baseline.get("v3TotalChecks") != EXPECTED_TOTAL:
    die("baseline v3TotalChecks drifted")
summary = report.get("summary", {})
if summary.get("status") != "passed" or summary.get("totalChecks") != EXPECTED_TOTAL:
    die("summary status/totalChecks drifted")
if summary.get("failedHarnesses") != 0 or summary.get("pendingHarnesses") != 0 or summary.get("regressions") is not False:
    die("summary failure/pending/regression fields drifted")
pass_count += 1

harnesses = report.get("harnesses", [])
if [row.get("id") for row in harnesses] != list(EXPECTED_HARNESS_CHECKS):
    die("harness roster/order drifted")
total = 0
for row in harnesses:
    hid = row["id"]
    if row.get("status") != "passed":
        die(f"{hid} status must be passed in self-test sample")
    if row.get("checks") != EXPECTED_HARNESS_CHECKS[hid]:
        die(f"{hid} checks drifted")
    if row.get("command") != EXPECTED_HARNESS_COMMANDS[hid]:
        die(f"{hid} command drifted")
    total += row["checks"]
    for artifact in row.get("artifacts", []):
        require_path(artifact)
if total != EXPECTED_TOTAL:
    die("harness check total no longer matches expected total")
pass_count += 1

artifacts = report.get("artifacts", {})
if artifacts.get("jsonReport") != str(sample_path):
    die("jsonReport path drifted")
if artifacts.get("markdownReport") != str(template_path):
    die("markdownReport path drifted")
if artifacts.get("sourceFixtureRoots") != EXPECTED_ROOTS:
    die("sourceFixtureRoots drifted")
for artifact in [artifacts.get("jsonReport"), artifacts.get("markdownReport"), artifacts.get("schema"), *artifacts.get("sourceFixtureRoots", [])]:
    if not isinstance(artifact, str):
        die("artifact list contains a non-string path")
    require_path(artifact)
pass_count += 1

archive_policy = report.get("archivePolicy", {})
if archive_policy.get("policyDoc") != str(archive_policy_path):
    die("archive policy doc path drifted")
if archive_policy.get("perReleaseDirectory") != "docs/product/v3/eval-reports/<release>/":
    die("per-release report directory drifted")
if archive_policy.get("gitTrackedReports") != ["json", "markdown"]:
    die("git-tracked report types drifted")
if archive_policy.get("heavyArtifactsInGit") is not False:
    die("heavy artifacts must not be committed by default")
if archive_policy.get("largeArtifactPolicy") != "release-artifact-or-lfs":
    die("large artifact policy drifted")
if archive_policy.get("requiresLfsDecisionForLargeArtifacts") is not True:
    die("large artifacts must require an explicit LFS/release-artifact decision")
if archive_policy.get("maxGitReportBytes") != 262144:
    die("max git report byte budget drifted")
if archive_policy.get("runtimeArchiveAutomation") != "not-started":
    die("archive automation must remain not-started")
require_path(archive_policy["policyDoc"])
archive_policy_text = archive_policy_path.read_text(encoding="utf-8")
for needle in [
    "release-artifact-or-lfs",
    "heavyArtifactsInGit",
    "maxGitReportBytes",
    "runtimeArchiveAutomation",
    "not-started",
]:
    if needle not in archive_policy_text:
        die(f"archive policy doc missing {needle!r}")
pass_count += 1

gates = report.get("gates", {})
if gates.get("blocksReleaseOnFailure") is not True:
    die("contract failures must block release")
if gates.get("requiresV2RegressionGreen") is not True:
    die("report must require V2 regression green")
if gates.get("allowsPublicEgress") is not False:
    die("report must not allow public egress")
if gates.get("requiresRuntimeSamplesBeforeGA") is not True:
    die("report must require runtime samples before GA")
if gates.get("publishable") is not False:
    die("contract-only self-test report must not be externally publishable")
pass_count += 1

template_text = template_path.read_text(encoding="utf-8")
for needle in [
    "## Scope",
    "## Baseline",
    "## Harness Results",
    "## Gate Decisions",
    "## Artifacts",
    "## Archive Policy",
    "## Reproduction",
    "## Runtime Notes",
    "docs/schemas/eval-report.schema.json",
    "docs/product/v3/w5-report-archive-policy.md",
    "release-artifact-or-lfs",
    "bash bin/v3-eval-sweep.sh --self-test",
    "Contract-only reports are not GA evidence",
]:
    if needle not in template_text:
        die(f"report template missing {needle!r}")
pass_count += 1

sweep_text = sweep_path.read_text(encoding="utf-8")
workflow_text = workflow_path.read_text(encoding="utf-8")
w5_text = w5_spec_path.read_text(encoding="utf-8")
master_text = master_plan_path.read_text(encoding="utf-8")
for path, text, needles in [
    (sweep_path, sweep_text, ["--self-test", "tests/v3-eval-report-self-test.sh", "W5 eval-report self-test"]),
    (workflow_path, workflow_text, ["docs/schemas/eval-report.schema.json", "bin/v3-eval-sweep.sh --self-test"]),
    (w5_spec_path, w5_text, ["eval-report.schema.json", "eval-reports/template.md", "v3-contract-self-test.json", "w5-report-archive-policy.md", "report-field self-test", "Checks: 10"]),
    (master_plan_path, master_text, ["eval-report.schema.json", "tests/v3-eval-report-self-test.sh", "w5-report-archive-policy.md", "report-field self-test"]),
]:
    for needle in needles:
        if needle not in text:
            die(f"{path} missing {needle!r}")
pass_count += 1

print("Status: passed")
print("Harness: W5 eval-report self-test")
print(f"Report schema: {schema_path}")
print(f"Sample report: {sample_path}")
print(f"Template: {template_path}")
print(f"V3 contract checks represented: {EXPECTED_TOTAL}")
print(f"Checks: {pass_count}")
PY
