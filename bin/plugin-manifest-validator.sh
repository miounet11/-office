#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
schema_path="$repo_root/docs/schemas/kqoffice-plugin.schema.json"
output_path="$repo_root/tmp/plugin-manifest-validator.md"
policy="local-offline"
self_test="0"
manifest_paths=()

usage() {
    cat <<'EOF'
Usage:
  plugin-manifest-validator.sh [options] <manifest.json>...
  plugin-manifest-validator.sh --self-test [--report <path>]

Options:
  --policy <name>     Validation policy: local-offline or schema-only.
                      Default: local-offline.
  --report <path>    Markdown report path.
                      Default: tmp/plugin-manifest-validator.md.
  --self-test        Validate built-in positive and negative cases.

Validates KQOffice plugin manifests locally, offline, and without provider
runtime code. The local-offline policy rejects private/cloud provider manifests
until signing, consent, service-mode enforcement, allowlist/update/quarantine
policy, auditability, and failure-isolation gates exist, requires Chinese-facing
failure messages, and keeps plugin commands scoped to KQOffice-owned UNO commands.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --policy)
            if [[ $# -lt 2 ]]; then
                printf 'Missing value for --policy\n' >&2
                exit 2
            fi
            policy="$2"
            shift 2
            ;;
        --report)
            if [[ $# -lt 2 ]]; then
                printf 'Missing value for --report\n' >&2
                exit 2
            fi
            output_path="$2"
            shift 2
            ;;
        --self-test)
            self_test="1"
            shift
            ;;
        --)
            shift
            while [[ $# -gt 0 ]]; do
                manifest_paths+=("$1")
                shift
            done
            ;;
        -*)
            printf 'Unknown option: %s\n' "$1" >&2
            exit 2
            ;;
        *)
            manifest_paths+=("$1")
            shift
            ;;
    esac
done

if [[ "$policy" != "local-offline" && "$policy" != "schema-only" ]]; then
    printf 'Unsupported policy: %s\n' "$policy" >&2
    exit 2
fi

if [[ "$self_test" != "1" && ${#manifest_paths[@]} -eq 0 ]]; then
    usage >&2
    exit 2
fi

mkdir -p "$(dirname "$output_path")"

python_args=("$repo_root" "$schema_path" "$output_path" "$policy" "$self_test")
if [[ ${#manifest_paths[@]} -gt 0 ]]; then
    python_args+=("${manifest_paths[@]}")
fi

python3 - "${python_args[@]}" <<'PY'
from __future__ import annotations

from pathlib import Path
import copy
import json
import re
import subprocess
import sys

repo_root = Path(sys.argv[1])
schema_path = Path(sys.argv[2])
output_path = Path(sys.argv[3])
policy = sys.argv[4]
self_test = sys.argv[5] == "1"
manifest_args = sys.argv[6:]


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


def validate_schema(value: object, schema: dict[str, object], path: list[str]) -> list[str]:
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
                errors.extend(validate_schema(item, item_schema, path + [str(index)]))

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
                    errors.extend(validate_schema(value[key], child_schema, path + [key]))

    return errors


def load_json(path: Path) -> object:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def has_cjk(value: str) -> bool:
    return re.search(r"[\u4e00-\u9fff]", value) is not None


def duplicate_values(items: object, key: str) -> list[tuple[int, object]]:
    if not isinstance(items, list):
        return []
    seen: dict[object, int] = {}
    duplicates: list[tuple[int, object]] = []
    for index, item in enumerate(items):
        if not isinstance(item, dict) or key not in item:
            continue
        value = item[key]
        if value in seen:
            duplicates.append((index, value))
        else:
            seen[value] = index
    return duplicates


def validate_semantics(instance: object) -> list[str]:
    if policy == "schema-only":
        return []
    if not isinstance(instance, dict):
        return []

    errors: list[str] = []

    for path, value in [
        ("$.name_zh", instance.get("name_zh")),
        ("$.privacy.context_scope_zh", (instance.get("privacy") or {}).get("context_scope_zh") if isinstance(instance.get("privacy"), dict) else None),
    ]:
        if isinstance(value, str) and value.strip() and not has_cjk(value):
            errors.append(f"{path} must be Chinese-facing text")

    failure_behavior = instance.get("failure_behavior")
    if isinstance(failure_behavior, dict):
        message = failure_behavior.get("message_zh")
        if not isinstance(message, str) or not message.strip():
            errors.append("$.failure_behavior.message_zh is required by the local/offline policy")
        else:
            if not has_cjk(message):
                errors.append("$.failure_behavior.message_zh must be Chinese-facing text")
            if re.search(r"(失败|错误|异常|不可用)", message) is None:
                errors.append("$.failure_behavior.message_zh must explain the failure/error state")
            if re.search(r"(不修改|不会修改|不更改|不会更改|不写入|不会写入|不改变|不会改变)", message) is None:
                errors.append("$.failure_behavior.message_zh must state that the document will not be modified")

    network = instance.get("network")
    if network in ("private", "cloud"):
        errors.append(
            "$.network private/cloud service mode is blocked until signing, explicit consent, "
            "service-mode enforcement, allowlist/update/quarantine policy, auditability, "
            "and failure isolation are in place; 当前版本仅允许离线或本地模式，避免未授权传输文档内容"
        )
    elif network not in ("offline", "local"):
        errors.append("$.network must be offline or local under the current service-policy enforcement gate")

    privacy = instance.get("privacy")
    if isinstance(privacy, dict) and privacy.get("stores_document_content") is not False:
        errors.append("$.privacy.stores_document_content must be explicitly false for local/offline manifests")

    entrypoints = instance.get("entrypoints")
    if isinstance(entrypoints, list):
        for index, entrypoint in enumerate(entrypoints):
            if not isinstance(entrypoint, dict):
                continue
            label = entrypoint.get("label_zh")
            if isinstance(label, str) and label.strip() and not has_cjk(label):
                errors.append(f"$.entrypoints.{index}.label_zh must be Chinese-facing text")
            command = entrypoint.get("command")
            if isinstance(command, str) and not command.startswith(".uno:KqOffice"):
                errors.append(f"$.entrypoints.{index}.command must use a KQOffice-scoped UNO command")

        for index, value in duplicate_values(entrypoints, "id"):
            errors.append(f"$.entrypoints.{index}.id duplicates earlier entrypoint id {value!r}")
        for index, value in duplicate_values(entrypoints, "command"):
            errors.append(f"$.entrypoints.{index}.command duplicates earlier entrypoint command {value!r}")

    return errors


def git_value(*args: str) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(repo_root), *args],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except subprocess.CalledProcessError:
        return "unknown"


schema = load_json(schema_path)
if not isinstance(schema, dict):
    raise SystemExit(f"Schema root must be object: {schema_path}")

cases: list[tuple[str, str, object]] = []

if self_test:
    valid_fixture = repo_root / "docs/schemas/fixtures/kqoffice-plugin.valid.json"
    invalid_fixture = repo_root / "docs/schemas/fixtures/kqoffice-plugin.invalid.json"
    valid_instance = load_json(valid_fixture)
    invalid_instance = load_json(invalid_fixture)

    cases.append((str(valid_fixture.relative_to(repo_root)), "valid", valid_instance))
    cases.append((str(invalid_fixture.relative_to(repo_root)), "invalid", invalid_instance))

    missing_message = copy.deepcopy(valid_instance)
    if isinstance(missing_message, dict) and isinstance(missing_message.get("failure_behavior"), dict):
        missing_message["failure_behavior"]["message_zh"] = ""
    cases.append(("<self-test:missing-failure-message>", "invalid", missing_message))

    private_manifest = copy.deepcopy(valid_instance)
    if isinstance(private_manifest, dict):
        private_manifest["network"] = "private"
    cases.append(("<self-test:private-before-service-policy-gates>", "invalid", private_manifest))

    provider_manifest = copy.deepcopy(valid_instance)
    if isinstance(provider_manifest, dict):
        provider_manifest["network"] = "cloud"
    cases.append(("<self-test:cloud-provider-before-service-policy-gates>", "invalid", provider_manifest))

    unsafe_command = copy.deepcopy(valid_instance)
    if (
        isinstance(unsafe_command, dict)
        and isinstance(unsafe_command.get("entrypoints"), list)
        and unsafe_command["entrypoints"]
        and isinstance(unsafe_command["entrypoints"][0], dict)
    ):
        unsafe_command["entrypoints"][0]["command"] = ".uno:SaveAs"
    cases.append(("<self-test:unsafe-command-scope>", "invalid", unsafe_command))

for raw_path in manifest_args:
    path = Path(raw_path)
    if not path.is_absolute():
        path = (Path.cwd() / path).resolve()
    if not path.exists():
        cases.append((raw_path, "valid", {"__missing_file__": str(path)}))
        continue
    try:
        instance = load_json(path)
    except json.JSONDecodeError as exc:
        cases.append((raw_path, "valid", {"__json_error__": str(exc)}))
        continue
    try:
        label = path.relative_to(repo_root).as_posix()
    except ValueError:
        label = str(path)
    cases.append((label, "valid", instance))

results: list[tuple[str, str, str, list[str]]] = []
failed = False

for label, expectation, instance in cases:
    errors: list[str] = []
    if isinstance(instance, dict) and "__missing_file__" in instance:
        errors.append(f"manifest file does not exist: {instance['__missing_file__']}")
    elif isinstance(instance, dict) and "__json_error__" in instance:
        errors.append(f"invalid JSON: {instance['__json_error__']}")
    else:
        errors.extend(validate_schema(instance, schema, []))
        errors.extend(validate_semantics(instance))

    is_valid = not errors
    passed = is_valid if expectation == "valid" else not is_valid
    status = "passed" if passed else "failed"
    if not passed:
        failed = True
    validation_outcome = "valid" if is_valid else "invalid"
    results.append((label, expectation, status, [f"outcome: {validation_outcome}", *errors]))

created_at = subprocess.check_output(["date", "+%Y-%m-%d %H:%M:%S %z"], text=True).strip()

lines: list[str] = []
lines.append("# Plugin Manifest Validator")
lines.append("")
lines.append(f"Generated at: {created_at}")
lines.append(f"Branch: {git_value('rev-parse', '--abbrev-ref', 'HEAD')}")
lines.append(f"HEAD: {git_value('rev-parse', '--short', 'HEAD')}")
lines.append(f"Policy: `{policy}`")
lines.append(f"Schema: `{schema_path.relative_to(repo_root)}`")
lines.append("")
lines.append("## Summary")
lines.append("")
lines.append(f"- Cases checked: {len(results)}")
lines.append(f"- Status: **{'failed' if failed else 'passed'}**")
lines.append("")
lines.append("## Results")
lines.append("")
lines.append("| Manifest | Expected | Status |")
lines.append("| --- | --- | --- |")
for label, expectation, status, _ in results:
    lines.append(f"| `{label}` | {expectation} | {status} |")

details = [(label, errors) for label, _, _, errors in results if len(errors) > 1]
if details:
    lines.append("")
    lines.append("## Validation Details")
    lines.append("")
    for label, errors in details:
        lines.append(f"### `{label}`")
        lines.append("")
        for error in errors[1:]:
            lines.append(f"- {error}")

lines.append("")
lines.append("## Service-Policy Enforcement")
lines.append("")
lines.append("- Manifests must stay `offline` or `local` until private/cloud signing, explicit consent, service-mode enforcement, allowlist/update/quarantine policy, auditability, and failure-isolation gates exist.")
lines.append("- Private/cloud rejection details are product-facing and must clearly explain that document-content transmission is blocked until those gates exist.")
lines.append("- Failure behavior must include Chinese text explaining failure and no document mutation.")
lines.append("- Privacy must explicitly avoid storing document content.")
lines.append("- Entrypoint commands must use KQOffice-scoped `.uno:KqOffice...` commands.")

output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Wrote plugin manifest validator report to {output_path}")

if failed:
    raise SystemExit(1)
PY
