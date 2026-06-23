#!/usr/bin/env bash
# V3 W9 - i18n-locale contract self-test.
#
# Contract-first gate for W9 UI locale and AI output language policy. It does
# not touch i18npool, prompt runtime, chat command parsing, or product code.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

schema_path="docs/schemas/i18n-locale-policy.schema.json"
w9_spec="docs/product/v3/w9-market-readiness-spec.md"
w5_spec="docs/product/v3/w5-eval-harness-spec.md"
master_plan="docs/product/v3-master-plan.md"
sweep="bin/v3-eval-sweep.sh"
workflow=".github/workflows/v3-contract-harnesses.yml"
valid_dir="docs/qa/fixtures/v3/i18n-locale/valid"
invalid_dir="docs/qa/fixtures/v3/i18n-locale/invalid"

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

REQUIRED = ["id", "schemaVersion", "createdAt", "locale", "ui", "aiOutput", "manual", "evidence", "gates"]
EXPECTED_VALID_FILES = {"zh-cn.json", "en-us.json", "ja-jp.json", "zh-tw.json"}
EXPECTED_INVALID_FILES = {
    "silent-switch.json",
    "output-language-mismatch.json",
    "missing-language-evidence.json",
    "missing-zh-tw-launch.json",
}
EXPECTED_LOCALES = ["zh-CN", "en-US", "ja-JP", "zh-TW"]
EXPECTED_LANGUAGE = {
    "zh-CN": "Chinese",
    "en-US": "English",
    "ja-JP": "Japanese",
    "zh-TW": "Traditional Chinese",
}
BASE_EVIDENCE = {"i18n-locale-policy", "locale-selection", "language-override", "ai-output-language", "evidence-record"}


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
    locale = value.get("locale", {})
    ui = value.get("ui", {})
    ai = value.get("aiOutput", {})
    override = ai.get("inlineOverride", {})
    manual = value.get("manual", {})
    evidence = set(value.get("evidence", {}).get("required", []))

    os_locale = locale.get("osLocale")
    ui_locale = locale.get("uiLocale")
    if os_locale != ui_locale:
        errors.append("UI locale must follow OS locale")
    if locale.get("supportedLaunchLocales") != EXPECTED_LOCALES:
        errors.append("launch locale coverage must be zh-CN/en-US/ja-JP/zh-TW in order")
    if ui.get("followsSystemLocale") is not True or ui.get("usesExistingI18nPool") is not True:
        errors.append("UI must follow system locale through existing i18npool")
    if ui.get("silentSwitchAllowed") is not False:
        errors.append("silent locale switching must be forbidden")
    if ai.get("defaultLocale") != ui_locale or ai.get("matchesUiLocale") is not True:
        errors.append("AI output default locale must match UI locale")
    if EXPECTED_LANGUAGE.get(ui_locale) != ai.get("outputLanguage"):
        errors.append("AI output language label must match UI locale")
    if override.get("enabled") is not True or override.get("explicitOnly") is not True:
        errors.append("language override must be enabled and explicit-only")
    if override.get("persistsWithoutUserAction") is not False:
        errors.append("language override must not persist silently")
    if override.get("commandPattern") != "^/lang (zh-CN|en-US|ja-JP|zh-TW|zh|en|ja)$":
        errors.append("/lang command pattern drifted")
    if ai.get("evidenceRequired") is not True or not BASE_EVIDENCE.issubset(evidence):
        errors.append("locale/output evidence requirements drifted")
    if manual.get("requiredLocales") != ["zh-CN", "en-US"]:
        errors.append("manual required locale baseline must stay zh-CN/en-US")
    if value.get("gates", {}).get("runtimeImplementation") != "not-started":
        errors.append("i18n runtime implementation must remain gated")
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
if props.get("ui", {}).get("properties", {}).get("silentSwitchAllowed", {}).get("const") is not False:
    die("silentSwitchAllowed must stay false")
if props.get("aiOutput", {}).get("properties", {}).get("matchesUiLocale", {}).get("const") is not True:
    die("matchesUiLocale must stay true")
if props.get("locale", {}).get("properties", {}).get("supportedLaunchLocales", {}).get("minItems") != 4:
    die("supportedLaunchLocales must lock 4 launch locales")
pass_count += 1

valid_paths = sorted(valid_dir.glob("*.json"))
invalid_paths = sorted(invalid_dir.glob("*.json"))
if {path.name for path in valid_paths} != EXPECTED_VALID_FILES:
    die(f"valid fixture roster drifted: {[path.name for path in valid_paths]!r}")
if {path.name for path in invalid_paths} != EXPECTED_INVALID_FILES:
    die(f"invalid fixture roster drifted: {[path.name for path in invalid_paths]!r}")
pass_count += 1

seen_locales: set[str] = set()
seen_languages: set[str] = set()
for path in valid_paths:
    value = load(path)
    if not isinstance(value, dict):
        die(f"{path} must contain an object")
    errors = validate(value, schema, [path.name])
    if errors:
        die(f"{path} violates schema:\n" + "\n".join(errors))
    semantic = semantic_errors(value)
    if semantic:
        die(f"{path} violates W9 i18n-locale semantics:\n" + "\n".join(semantic))
    seen_locales.add(value["locale"]["uiLocale"])
    seen_languages.add(value["aiOutput"]["outputLanguage"])
pass_count += 1

if seen_locales != set(EXPECTED_LOCALES):
    die(f"valid fixtures must cover launch locales {EXPECTED_LOCALES}, saw {sorted(seen_locales)}")
if seen_languages != set(EXPECTED_LANGUAGE.values()):
    die(f"valid fixtures must cover output languages, saw {sorted(seen_languages)}")
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
    for needle in ["silentSwitchAllowed\": true", "persistsWithoutUserAction\": true", "evidenceRequired\": false"]:
        if needle in raw:
            die(f"{path} contains forbidden locale marker {needle!r}")
pass_count += 1

w9_text = w9_spec.read_text(encoding="utf-8")
w5_text = w5_spec.read_text(encoding="utf-8")
master_text = master_plan.read_text(encoding="utf-8")
sweep_text = sweep_path.read_text(encoding="utf-8")
workflow_text = workflow_path.read_text(encoding="utf-8")
for path, text, needles in [
    (w9_spec, w9_text, ["i18n-locale self-test", "Checks: 8", "i18n-locale-policy", "zh-CN / en-US / ja-JP / zh-TW", "/lang"]),
    (w5_spec, w5_text, ["tests/v3-i18n-locale-test.sh", "i18n-locale self-test"]),
    (master_plan, master_text, ["i18n-locale-policy.schema.json", "tests/v3-i18n-locale-test.sh"]),
    (sweep_path, sweep_text, ["tests/v3-i18n-locale-test.sh", "W9 i18n-locale self-test"]),
    (workflow_path, workflow_text, ["docs/schemas/i18n-locale-policy.schema.json", "bin/v3-eval-sweep.sh --self-test"]),
]:
    for needle in needles:
        if needle not in text:
            die(f"{path} missing {needle!r}")
pass_count += 1

if pass_count != 7:
    die(f"internal pass_count drifted before final increment: {pass_count}")
pass_count += 1

print("Status: passed")
print("Harness: W9 i18n-locale self-test")
print(f"Schema: {schema_path}")
print(f"Valid fixtures: {len(valid_paths)}")
print(f"Invalid fixtures: {len(invalid_paths)}")
print("Locale contract: UI follows OS, AI follows UI, explicit /lang override")
print("Runtime implementation: deferred until W9 gate")
print(f"Checks: {pass_count}")
PY
