#!/usr/bin/env bash
# V3 H8 — connector-manifest contract harness.
#
# Contract-first gate for V3 W2. It validates the V3-only connector
# manifest schema and the built-in connector fixture roster without
# enrolling these fixtures into the V2 fixture baseline. Once the source
# registration file lands, the same harness auto-checks Connectors.xcu.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

src_root="${KDOFFICE_SRC_ROOT:-/Users/lu/kdoffice-src}"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

schema="docs/schemas/connector-manifest.schema.json"
spec="docs/product/v3/w2-connector-layer-spec.md"
valid_dir="docs/qa/fixtures/v3/connector/valid"
invalid_dir="docs/qa/fixtures/v3/connector/invalid"
xcu_path="$src_root/officecfg/registry/data/org/openoffice/Office/Connectors.xcu"

[[ -f "$schema" ]] || fail "missing $schema"
[[ -f "$spec" ]] || fail "missing $spec"
[[ -d "$valid_dir" ]] || fail "missing $valid_dir"
[[ -d "$invalid_dir" ]] || fail "missing $invalid_dir"

python3 - "$schema" "$spec" "$valid_dir" "$invalid_dir" "$xcu_path" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

schema_path = Path(sys.argv[1])
spec_path = Path(sys.argv[2])
valid_dir = Path(sys.argv[3])
invalid_dir = Path(sys.argv[4])
xcu_path = Path(sys.argv[5])

EXPECTED_ROSTER = {
    "local-fs": {"auth": "none", "maxDataClass": "confidential"},
    "feishu-docs": {"auth": "oauth2", "maxDataClass": "internal"},
    "wechat-work-docs": {"auth": "oauth2", "maxDataClass": "internal"},
    "notion": {"auth": "oauth2", "maxDataClass": "internal"},
    "sharepoint": {"auth": "oauth2", "maxDataClass": "confidential"},
    "confluence": {"auth": "api-key", "maxDataClass": "confidential"},
    "slack": {"auth": "oauth2", "maxDataClass": "internal"},
}

EXPECTED_REQUIRED = [
    "id",
    "version",
    "displayName",
    "trust",
    "operations",
    "auth",
    "serviceModes",
    "scopes",
    "rateLimit",
    "evidence",
]
EXPECTED_TRUST_REQUIRED = [
    "source",
    "publisher",
    "manifestSha256",
    "reviewState",
    "installScope",
    "signatureRequired",
    "allowUnsigned",
]
EXPECTED_TRUST_SOURCES = ["builtin", "community", "enterprise-admin"]
EXPECTED_TRUST_REVIEW_STATES = ["repo-reviewed", "security-reviewed", "tenant-approved"]
EXPECTED_TRUST_INSTALL_SCOPES = ["builtin", "user", "tenant"]
EXPECTED_OPERATIONS_REQUIRED = [
    "mode",
    "allowedActions",
    "writeback",
    "writeScopesAllowed",
    "runtimeWriteImplementation",
]
EXPECTED_SERVICE_MODES = ["private", "cloud"]
EXPECTED_AUTH_TYPES = ["oauth2", "api-key", "none"]
EXPECTED_TOKEN_STORAGE = ["keychain", "memory", "none"]
EXPECTED_AUTH_REQUIRED = ["type", "tokenStorage", "flow", "refreshPolicy"]
EXPECTED_AUTH_FLOW_REQUIRED = [
    "strategy",
    "embeddedWebView",
    "callback",
    "runtimeAuthImplementation",
]
EXPECTED_AUTH_FLOW_STRATEGIES = ["system-browser-loopback", "manual-secret-entry", "not-applicable"]
EXPECTED_AUTH_FLOW_CALLBACKS = ["loopback-127.0.0.1", "manual-entry", "none"]
EXPECTED_REFRESH_POLICY_REQUIRED = [
    "strategy",
    "backgroundRefresh",
    "storesRefreshToken",
    "runtimeRefreshImplementation",
]
EXPECTED_REFRESH_STRATEGIES = ["reauth-on-expiry", "manual-rotate", "not-applicable"]
EXPECTED_DATA_CLASSES = ["public", "internal", "confidential", "secret"]
EXPECTED_EVIDENCE_CATEGORIES = ["data-fetch", "data-write", "auth", "metadata"]
DATA_CLASS_RANK = {value: index for index, value in enumerate(EXPECTED_DATA_CLASSES)}


def die(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def load_json(path: Path) -> Any:
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
        max_length = schema.get("maxLength")
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


def schema_errors(manifest: dict[str, Any], schema: dict[str, Any]) -> list[str]:
    return validate(manifest, schema, [])


def semantic_errors(manifest: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    auth = manifest.get("auth", {})
    auth_type = auth.get("type") if isinstance(auth, dict) else None
    auth_scopes = auth.get("scopes", []) if isinstance(auth, dict) else []
    token_storage = auth.get("tokenStorage") if isinstance(auth, dict) else None
    auth_flow = auth.get("flow", {}) if isinstance(auth, dict) else {}
    flow_strategy = auth_flow.get("strategy") if isinstance(auth_flow, dict) else None
    embedded_webview = auth_flow.get("embeddedWebView") if isinstance(auth_flow, dict) else None
    callback = auth_flow.get("callback") if isinstance(auth_flow, dict) else None
    runtime_auth = auth_flow.get("runtimeAuthImplementation") if isinstance(auth_flow, dict) else None
    refresh_policy = auth.get("refreshPolicy", {}) if isinstance(auth, dict) else {}
    refresh_strategy = refresh_policy.get("strategy") if isinstance(refresh_policy, dict) else None
    background_refresh = refresh_policy.get("backgroundRefresh") if isinstance(refresh_policy, dict) else None
    stores_refresh_token = refresh_policy.get("storesRefreshToken") if isinstance(refresh_policy, dict) else None
    runtime_refresh = (
        refresh_policy.get("runtimeRefreshImplementation") if isinstance(refresh_policy, dict) else None
    )
    service_modes = manifest.get("serviceModes", [])
    scopes = manifest.get("scopes", [])
    evidence = manifest.get("evidence", {})
    requires_policy = manifest.get("requiresTenantPolicy", False)
    operations = manifest.get("operations", {})
    allowed_actions = operations.get("allowedActions", []) if isinstance(operations, dict) else []
    writeback = operations.get("writeback") if isinstance(operations, dict) else None
    write_scopes_allowed = operations.get("writeScopesAllowed") if isinstance(operations, dict) else None
    runtime_write = operations.get("runtimeWriteImplementation") if isinstance(operations, dict) else None
    trust = manifest.get("trust", {})
    source = trust.get("source") if isinstance(trust, dict) else None
    publisher = trust.get("publisher") if isinstance(trust, dict) else None
    review_state = trust.get("reviewState") if isinstance(trust, dict) else None
    install_scope = trust.get("installScope") if isinstance(trust, dict) else None
    signature_required = trust.get("signatureRequired") if isinstance(trust, dict) else None
    allow_unsigned = trust.get("allowUnsigned") if isinstance(trust, dict) else None

    if signature_required is not True:
        errors.append("trust.signatureRequired must be true")
    if allow_unsigned is not False:
        errors.append("trust.allowUnsigned must be false")
    if install_scope == "tenant" and review_state != "tenant-approved":
        errors.append("tenant installScope requires tenant-approved reviewState")
    if install_scope == "builtin" and source != "builtin":
        errors.append("builtin installScope requires builtin source")
    if source == "builtin":
        if publisher != "kqoffice":
            errors.append("builtin manifests must use publisher kqoffice")
        if review_state != "repo-reviewed":
            errors.append("builtin manifests must be repo-reviewed")
        if install_scope != "builtin":
            errors.append("builtin manifests must use installScope builtin")
    elif source == "community":
        if install_scope == "user" and review_state != "security-reviewed":
            errors.append("community user installs require security-reviewed reviewState")
        elif install_scope == "tenant" and review_state != "tenant-approved":
            errors.append("community tenant installs require tenant-approved reviewState")
        elif install_scope not in {"user", "tenant"}:
            errors.append("community manifests must install at user or tenant scope")
    elif source == "enterprise-admin":
        if install_scope != "tenant":
            errors.append("enterprise-admin manifests must install at tenant scope")
        if review_state != "tenant-approved":
            errors.append("enterprise-admin manifests require tenant-approved reviewState")

    if operations.get("mode") != "read-only" if isinstance(operations, dict) else True:
        errors.append("operations.mode must be read-only")
    if allowed_actions != ["read"]:
        errors.append("operations.allowedActions must be read-only")
    if writeback is not False:
        errors.append("operations.writeback must be false")
    if write_scopes_allowed is not False:
        errors.append("operations.writeScopesAllowed must be false")
    if runtime_write != "not-started":
        errors.append("operations.runtimeWriteImplementation must be not-started")

    if auth_type == "none":
        if token_storage != "none":
            errors.append("auth none must use tokenStorage none")
        if auth_scopes:
            errors.append("auth none must not declare provider scopes")
        if flow_strategy != "not-applicable":
            errors.append("auth none must use flow.strategy not-applicable")
        if callback != "none":
            errors.append("auth none must use flow.callback none")
        if refresh_strategy != "not-applicable":
            errors.append("auth none must use refreshPolicy.strategy not-applicable")
    elif auth_type in {"oauth2", "api-key"}:
        if token_storage == "none":
            errors.append(f"auth {auth_type} must not use tokenStorage none")
        if not isinstance(auth_scopes, list) or not auth_scopes:
            errors.append(f"auth {auth_type} must declare non-empty auth.scopes")
        expected_flow_strategy = "system-browser-loopback" if auth_type == "oauth2" else "manual-secret-entry"
        expected_callback = "loopback-127.0.0.1" if auth_type == "oauth2" else "manual-entry"
        if flow_strategy != expected_flow_strategy:
            errors.append(f"auth {auth_type} must use flow.strategy {expected_flow_strategy}")
        if callback != expected_callback:
            errors.append(f"auth {auth_type} must use flow.callback {expected_callback}")
        expected_refresh_strategy = "reauth-on-expiry" if auth_type == "oauth2" else "manual-rotate"
        if refresh_strategy != expected_refresh_strategy:
            errors.append(f"auth {auth_type} must use refreshPolicy.strategy {expected_refresh_strategy}")
    if embedded_webview is not False:
        errors.append("auth.flow.embeddedWebView must be false")
    if runtime_auth != "not-started":
        errors.append("auth.flow.runtimeAuthImplementation must be not-started")
    if background_refresh is not False:
        errors.append("auth.refreshPolicy.backgroundRefresh must be false")
    if stores_refresh_token is not False:
        errors.append("auth.refreshPolicy.storesRefreshToken must be false")
    if runtime_refresh != "not-started":
        errors.append("auth.refreshPolicy.runtimeRefreshImplementation must be not-started")

    if "offline" in service_modes:
        errors.append("offline mode must disable connectors")
    if evidence.get("emit") is not True:
        errors.append("evidence.emit must be true")
    if evidence.get("category") not in EXPECTED_EVIDENCE_CATEGORIES:
        errors.append("evidence.category must be a locked category")
    if evidence.get("category") == "data-write":
        errors.append("evidence.category=data-write is forbidden for read-only connectors")

    if isinstance(auth_scopes, list):
        for scope in auth_scopes:
            if isinstance(scope, str) and ":write" in scope:
                errors.append("auth.scopes must not include write scopes")

    if isinstance(scopes, list):
        for index, scope in enumerate(scopes):
            if not isinstance(scope, dict):
                continue
            name = scope.get("name")
            if isinstance(name, str) and name.startswith("write:"):
                errors.append(f"scopes[{index}].name must not be a write scope")
            data_class = scope.get("dataClass")
            if data_class in {"confidential", "secret"} and "cloud" in service_modes and not requires_policy:
                errors.append(
                    f"scopes[{index}].dataClass={data_class} over cloud requires tenant policy"
                )
    return errors


schema = load_json(schema_path)
if not isinstance(schema, dict):
    die("connector manifest schema top-level is not an object")

pass_count = 0

if schema.get("required") != EXPECTED_REQUIRED:
    die(f"schema.required drifted: {schema.get('required')!r}")
pass_count += 1

if schema.get("additionalProperties") is not False:
    die("schema must set top-level additionalProperties:false")
pass_count += 1

properties = schema.get("properties", {})
if not isinstance(properties, dict):
    die("schema.properties missing")

trust = properties.get("trust", {})
trust_props = trust.get("properties", {})
if trust.get("required") != EXPECTED_TRUST_REQUIRED:
    die("trust.required drifted")
if trust.get("additionalProperties") is not False:
    die("trust must set additionalProperties:false")
if trust_props.get("source", {}).get("enum") != EXPECTED_TRUST_SOURCES:
    die("trust.source enum drifted")
if trust_props.get("publisher", {}).get("pattern") != "^[a-z][a-z0-9-]{2,63}$":
    die("trust.publisher pattern drifted")
if trust_props.get("manifestSha256", {}).get("pattern") != "^sha256:[a-f0-9]{64}$":
    die("trust.manifestSha256 pattern drifted")
if trust_props.get("reviewState", {}).get("enum") != EXPECTED_TRUST_REVIEW_STATES:
    die("trust.reviewState enum drifted")
if trust_props.get("installScope", {}).get("enum") != EXPECTED_TRUST_INSTALL_SCOPES:
    die("trust.installScope enum drifted")
if trust_props.get("signatureRequired", {}).get("type") != "boolean":
    die("trust.signatureRequired type drifted")
if trust_props.get("allowUnsigned", {}).get("const") is not False:
    die("trust.allowUnsigned must be const false")

operations = properties.get("operations", {})
operations_props = operations.get("properties", {})
if operations.get("required") != EXPECTED_OPERATIONS_REQUIRED:
    die("operations.required drifted")
if operations.get("additionalProperties") is not False:
    die("operations must set additionalProperties:false")
if operations_props.get("mode", {}).get("const") != "read-only":
    die("operations.mode must be const read-only")
if operations_props.get("allowedActions", {}).get("items", {}).get("const") != "read":
    die("operations.allowedActions must be read-only")
if operations_props.get("allowedActions", {}).get("minItems") != 1:
    die("operations.allowedActions minItems drifted")
if operations_props.get("allowedActions", {}).get("maxItems") != 1:
    die("operations.allowedActions maxItems drifted")
if operations_props.get("allowedActions", {}).get("uniqueItems") is not True:
    die("operations.allowedActions must set uniqueItems:true")
if operations_props.get("writeback", {}).get("const") is not False:
    die("operations.writeback must be const false")
if operations_props.get("writeScopesAllowed", {}).get("const") is not False:
    die("operations.writeScopesAllowed must be const false")
if operations_props.get("runtimeWriteImplementation", {}).get("const") != "not-started":
    die("operations.runtimeWriteImplementation must be const not-started")

auth_props = properties.get("auth", {}).get("properties", {})
if properties.get("auth", {}).get("required") != EXPECTED_AUTH_REQUIRED:
    die("auth.required drifted")
if auth_props.get("type", {}).get("enum") != EXPECTED_AUTH_TYPES:
    die("auth.type enum drifted")
if auth_props.get("tokenStorage", {}).get("enum") != EXPECTED_TOKEN_STORAGE:
    die("auth.tokenStorage enum drifted")
auth_flow = auth_props.get("flow", {})
auth_flow_props = auth_flow.get("properties", {})
if auth_flow.get("required") != EXPECTED_AUTH_FLOW_REQUIRED:
    die("auth.flow.required drifted")
if auth_flow.get("additionalProperties") is not False:
    die("auth.flow must set additionalProperties:false")
if auth_flow_props.get("strategy", {}).get("enum") != EXPECTED_AUTH_FLOW_STRATEGIES:
    die("auth.flow.strategy enum drifted")
if auth_flow_props.get("embeddedWebView", {}).get("const") is not False:
    die("auth.flow.embeddedWebView must be const false")
if auth_flow_props.get("callback", {}).get("enum") != EXPECTED_AUTH_FLOW_CALLBACKS:
    die("auth.flow.callback enum drifted")
if auth_flow_props.get("runtimeAuthImplementation", {}).get("const") != "not-started":
    die("auth.flow.runtimeAuthImplementation must be const not-started")
refresh_policy = auth_props.get("refreshPolicy", {})
refresh_props = refresh_policy.get("properties", {})
if refresh_policy.get("required") != EXPECTED_REFRESH_POLICY_REQUIRED:
    die("auth.refreshPolicy.required drifted")
if refresh_policy.get("additionalProperties") is not False:
    die("auth.refreshPolicy must set additionalProperties:false")
if refresh_props.get("strategy", {}).get("enum") != EXPECTED_REFRESH_STRATEGIES:
    die("auth.refreshPolicy.strategy enum drifted")
if refresh_props.get("backgroundRefresh", {}).get("const") is not False:
    die("auth.refreshPolicy.backgroundRefresh must be const false")
if refresh_props.get("storesRefreshToken", {}).get("const") is not False:
    die("auth.refreshPolicy.storesRefreshToken must be const false")
if refresh_props.get("runtimeRefreshImplementation", {}).get("const") != "not-started":
    die("auth.refreshPolicy.runtimeRefreshImplementation must be const not-started")
if properties.get("auth", {}).get("additionalProperties") is not False:
    die("auth must set additionalProperties:false")
pass_count += 1

service_enum = properties.get("serviceModes", {}).get("items", {}).get("enum")
if service_enum != EXPECTED_SERVICE_MODES:
    die(f"serviceModes enum must be {EXPECTED_SERVICE_MODES}; got {service_enum!r}")
pass_count += 1

scope_props = properties.get("scopes", {}).get("items", {}).get("properties", {})
data_enum = scope_props.get("dataClass", {}).get("enum")
if data_enum != EXPECTED_DATA_CLASSES:
    die("scopes[].dataClass enum drifted")
if properties.get("scopes", {}).get("items", {}).get("additionalProperties") is not False:
    die("scopes.items must set additionalProperties:false")
pass_count += 1

rate_limit = properties.get("rateLimit", {})
if rate_limit.get("required") != ["perMinute", "perDay"]:
    die("rateLimit.required drifted")
if rate_limit.get("additionalProperties") is not False:
    die("rateLimit must set additionalProperties:false")
pass_count += 1

evidence = properties.get("evidence", {})
evidence_props = evidence.get("properties", {})
if evidence.get("required") != ["emit", "category"]:
    die("evidence.required drifted")
if evidence_props.get("emit", {}).get("const") is not True:
    die("evidence.emit must be const true")
if evidence_props.get("category", {}).get("enum") != EXPECTED_EVIDENCE_CATEGORIES:
    die("evidence.category enum drifted")
if evidence.get("additionalProperties") is not False:
    die("evidence must set additionalProperties:false")
pass_count += 1

valid_paths = sorted(valid_dir.glob("*.json"))
invalid_paths = sorted(invalid_dir.glob("*.json"))
if len(valid_paths) != len(EXPECTED_ROSTER):
    die(f"expected {len(EXPECTED_ROSTER)} valid fixtures, found {len(valid_paths)}")
if len(invalid_paths) != 17:
    die(f"expected 17 invalid fixtures, found {len(invalid_paths)}")
pass_count += 1

spec_text = spec_path.read_text(encoding="utf-8")
spec_ids = set(re.findall(r"\| `([a-z][a-z0-9-]{2,31})` \|", spec_text))
if spec_ids != set(EXPECTED_ROSTER):
    die(f"W2 spec built-in connector roster drifted: {sorted(spec_ids)}")
pass_count += 1

valid_manifests: dict[str, dict[str, Any]] = {}
for path in valid_paths:
    manifest = load_json(path)
    if not isinstance(manifest, dict):
        die(f"{path} top-level is not an object")
    cid = manifest.get("id")
    if not isinstance(cid, str):
        die(f"{path} missing string id")
    if cid in valid_manifests:
        die(f"duplicate connector id {cid}")
    valid_manifests[cid] = manifest

if set(valid_manifests) != set(EXPECTED_ROSTER):
    die(f"valid fixture roster drifted: {sorted(valid_manifests)}")
pass_count += 1

for cid, manifest in valid_manifests.items():
    errors = schema_errors(manifest, schema)
    if errors:
        die(f"valid fixture {cid} failed schema: {errors}")
pass_count += 1

for cid, manifest in valid_manifests.items():
    errors = semantic_errors(manifest)
    if errors:
        die(f"valid fixture {cid} failed semantic contract: {errors}")
pass_count += 1

for cid, expected in EXPECTED_ROSTER.items():
    manifest = valid_manifests[cid]
    auth_type = manifest.get("auth", {}).get("type")
    if auth_type != expected["auth"]:
        die(f"{cid} auth type {auth_type!r} != expected {expected['auth']!r}")
    data_classes = [scope.get("dataClass") for scope in manifest.get("scopes", [])]
    max_data = max(data_classes, key=lambda value: DATA_CLASS_RANK.get(value, -1))
    if max_data != expected["maxDataClass"]:
        die(f"{cid} max dataClass {max_data!r} != expected {expected['maxDataClass']!r}")
    trust = manifest.get("trust", {})
    if trust.get("source") != "builtin":
        die(f"{cid} must use builtin trust source")
    if trust.get("publisher") != "kqoffice":
        die(f"{cid} must use kqoffice publisher")
    if trust.get("reviewState") != "repo-reviewed":
        die(f"{cid} must be repo-reviewed")
    if trust.get("installScope") != "builtin":
        die(f"{cid} must use builtin install scope")
    if trust.get("signatureRequired") is not True:
        die(f"{cid} must require manifest signature")
    if trust.get("allowUnsigned") is not False:
        die(f"{cid} must forbid unsigned manifests")
    operations = manifest.get("operations", {})
    if operations.get("mode") != "read-only":
        die(f"{cid} must use read-only operation mode")
    if operations.get("allowedActions") != ["read"]:
        die(f"{cid} must allow only read actions")
    if operations.get("writeback") is not False:
        die(f"{cid} must disable writeback")
    if operations.get("writeScopesAllowed") is not False:
        die(f"{cid} must forbid write scopes")
    if operations.get("runtimeWriteImplementation") != "not-started":
        die(f"{cid} must keep write runtime not-started")
pass_count += 1

invalid_expected = {
    "evidence-disabled.json": "evidence.emit",
    "offline-service-mode.json": "offline mode",
    "cloud-confidential-without-policy.json": "requires tenant policy",
    "missing-manifest-hash.json": "manifestSha256",
    "tenant-scope-without-approval.json": "tenant-approved",
    "unsigned-community-manifest.json": "allowUnsigned",
    "unreviewed-community-manifest.json": "security-reviewed",
    "data-write-evidence.json": "data-write",
    "runtime-write-implementation-started.json": "runtimeWriteImplementation",
    "embedded-webview-auth-flow.json": "embeddedWebView",
    "oauth-non-loopback-callback.json": "flow.callback",
    "runtime-auth-implementation-started.json": "runtimeAuthImplementation",
    "background-refresh-enabled.json": "backgroundRefresh",
    "refresh-token-stored.json": "storesRefreshToken",
    "runtime-refresh-implementation-started.json": "runtimeRefreshImplementation",
    "write-scope-declared.json": "write scope",
    "writeback-enabled.json": "writeback",
}
observed_invalid: dict[str, list[str]] = {}
for path in invalid_paths:
    manifest = load_json(path)
    if not isinstance(manifest, dict):
        observed_invalid[path.name] = ["top-level not object"]
        continue
    observed_invalid[path.name] = schema_errors(manifest, schema) + semantic_errors(manifest)

if set(observed_invalid) != set(invalid_expected):
    die(f"invalid fixture roster drifted: {sorted(observed_invalid)}")
pass_count += 1

for name, needle in invalid_expected.items():
    errors = observed_invalid[name]
    if not errors:
        die(f"invalid fixture {name} unexpectedly passed")
    joined = " | ".join(errors)
    if needle not in joined:
        die(f"invalid fixture {name} failed for wrong reason: {errors}")
pass_count += 1

registration_mode = "contract-only"
registered_ids: set[str] = set()
if xcu_path.exists():
    text = xcu_path.read_text(encoding="utf-8", errors="ignore")
    registered_ids = set(re.findall(r"<node[^>]+oor:name=\"([a-z][a-z0-9-]{2,31})\"", text))
    missing = sorted(set(EXPECTED_ROSTER) - registered_ids)
    extra = sorted(registered_ids - set(EXPECTED_ROSTER))
    if missing or extra:
        die(f"Connectors.xcu roster drifted; missing={missing} extra={extra}")
    registration_mode = "xcu-locked"
pass_count += 1

print("Status: passed")
print("Harness: H8 connector-manifest contract")
print(f"Mode: {registration_mode}")
print(f"Schema: {schema_path}")
print(f"Valid fixtures: {len(valid_paths)}")
print(f"Invalid fixtures: {len(invalid_paths)}")
print("Built-in connectors: " + ", ".join(sorted(EXPECTED_ROSTER)))
if registration_mode == "xcu-locked":
    print("Connectors.xcu: locked")
else:
    print(f"Connectors.xcu: not present at {xcu_path}; registration check deferred")
print(f"Checks: {pass_count}")
PY
