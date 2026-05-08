#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
schema_dir="$repo_root/docs/schemas"
fixture_dir="$schema_dir/fixtures"
output_path="${1:-$repo_root/tmp/intelligent-contract-fixtures.md}"

usage() {
    cat <<'EOF'
Usage:
  intelligent-contract-fixtures.sh [output-file]

Validates intelligent-office diagnostic and plugin manifest fixture files
against the checked-in JSON schema contracts using only Python stdlib.

Fixture naming:
  docs/schemas/fixtures/<schema-name>.valid.json
  docs/schemas/fixtures/<schema-name>.invalid.json

The report is written to:
  tmp/intelligent-contract-fixtures.md
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

mkdir -p "$(dirname "$output_path")"

python3 - "$repo_root" "$schema_dir" "$fixture_dir" "$output_path" <<'PY'
from __future__ import annotations

from pathlib import Path
import json
import re
import subprocess
import sys

repo_root = Path(sys.argv[1])
schema_dir = Path(sys.argv[2])
fixture_dir = Path(sys.argv[3])
output_path = Path(sys.argv[4])


def type_matches(value: object, expected: str) -> bool:
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


def json_pointer(path: list[str]) -> str:
    if not path:
        return "$"
    return "$." + ".".join(path)


def validate(value: object, schema: dict[str, object], path: list[str]) -> list[str]:
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
        min_length = schema.get("minLength")
        if isinstance(min_length, int) and len(value) < min_length:
            errors.append(f"{json_pointer(path)} shorter than minLength {min_length}")
        pattern = schema.get("pattern")
        if isinstance(pattern, str) and re.search(pattern, value) is None:
            errors.append(f"{json_pointer(path)} does not match pattern {pattern!r}")

    if isinstance(value, list):
        min_items = schema.get("minItems")
        if isinstance(min_items, int) and len(value) < min_items:
            errors.append(f"{json_pointer(path)} has fewer than {min_items} items")
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
        required = schema.get("required")
        if isinstance(required, list):
            for key in required:
                if isinstance(key, str) and key not in value:
                    errors.append(f"{json_pointer(path + [key])} is required")

        properties = schema.get("properties")
        property_names = set(properties.keys()) if isinstance(properties, dict) else set()

        if schema.get("additionalProperties") is False:
            for key in sorted(value.keys()):
                if key not in property_names:
                    errors.append(f"{json_pointer(path + [key])} is not allowed")

        if isinstance(properties, dict):
            for key, child_schema in properties.items():
                if key in value and isinstance(child_schema, dict):
                    errors.extend(validate(value[key], child_schema, path + [key]))

    return errors


def load_json(path: Path) -> object:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def git_value(*args: str) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(repo_root), *args],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except subprocess.CalledProcessError:
        return "unknown"


if not fixture_dir.exists():
    raise SystemExit(f"Missing fixture directory: {fixture_dir}")

fixtures = sorted(fixture_dir.glob("*.json"))
if not fixtures:
    raise SystemExit(f"No fixture JSON files found in {fixture_dir}")

results: list[tuple[str, str, str, list[str]]] = []
failed = False

for fixture in fixtures:
    name = fixture.name
    if name.endswith(".valid.json"):
        schema_name = name.removesuffix(".valid.json")
        expectation = "valid"
    elif name.endswith(".invalid.json"):
        schema_name = name.removesuffix(".invalid.json")
        expectation = "invalid"
    else:
        results.append((name, "unknown", "failed", ["fixture must end with .valid.json or .invalid.json"]))
        failed = True
        continue

    schema_path = schema_dir / f"{schema_name}.schema.json"
    if not schema_path.exists():
        results.append((name, expectation, "failed", [f"missing schema {schema_path.name}"]))
        failed = True
        continue

    schema = load_json(schema_path)
    instance = load_json(fixture)
    errors = validate(instance, schema, [])
    is_valid = not errors
    passed = is_valid if expectation == "valid" else not is_valid
    status = "passed" if passed else "failed"
    if not passed:
        failed = True
    results.append((name, expectation, status, errors))

created_at = subprocess.check_output(["date", "+%Y-%m-%d %H:%M:%S %z"], text=True).strip()

lines: list[str] = []
lines.append("# Intelligent Contract Fixtures")
lines.append("")
lines.append(f"Generated at: {created_at}")
lines.append(f"Branch: {git_value('rev-parse', '--abbrev-ref', 'HEAD')}")
lines.append(f"HEAD: {git_value('rev-parse', '--short', 'HEAD')}")
lines.append(f"Fixture dir: `{fixture_dir.relative_to(repo_root)}`")
lines.append("")
lines.append("## Summary")
lines.append("")
schema_names = sorted({name.removesuffix(".valid.json").removesuffix(".invalid.json") for name, _, _, _ in results})
lines.append(f"- Fixtures checked: {len(results)}")
lines.append(f"- Schemas covered: {len(schema_names)}")
lines.append(f"- Status: **{'failed' if failed else 'passed'}**")
lines.append("")
lines.append("## Schemas Covered")
lines.append("")
for schema_name in schema_names:
    lines.append(f"- `{schema_name}`")
lines.append("")
lines.append("## Results")
lines.append("")
lines.append("| Fixture | Expected | Status |")
lines.append("| --- | --- | --- |")
for name, expectation, status, _ in results:
    lines.append(f"| `{name}` | {expectation} | {status} |")

details = [(name, errors) for name, _, status, errors in results if errors and status == "failed"]
if details:
    lines.append("")
    lines.append("## Failure Details")
    lines.append("")
    for name, errors in details:
        lines.append(f"### `{name}`")
        lines.append("")
        for error in errors:
            lines.append(f"- {error}")

output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Wrote intelligent contract fixture report to {output_path}")

if failed:
    raise SystemExit(1)
PY

