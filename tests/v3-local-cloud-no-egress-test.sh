#!/usr/bin/env bash
# V3 H10 — local-cloud no-egress contract.
#
# Contract-first gate for V3 W8. It does not launch the gated
# localcloud supervisor. Instead it locks the config schema and seed
# fixtures that future runtime/socket tests must consume: default and
# enterprise-LAN paths may only target loopback/private LAN endpoints,
# while public egress is legal only when cloud opt-in is explicit and
# evidence-backed.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

schema="docs/schemas/localcloud-config.schema.json"
w8_spec="docs/product/v3/w8-local-cloud-spec.md"
w2_spec="docs/product/v3/w2-connector-layer-spec.md"
w4_spec="docs/product/v3/w4-tenant-policy-audit-spec.md"
w7_spec="docs/product/v3/w7-companion-spec.md"
valid_dir="docs/qa/fixtures/v3/localcloud/valid"
invalid_dir="docs/qa/fixtures/v3/localcloud/invalid"

[[ -f "$schema" ]] || fail "missing $schema"
[[ -f "$w8_spec" ]] || fail "missing $w8_spec"
[[ -f "$w2_spec" ]] || fail "missing $w2_spec"
[[ -f "$w4_spec" ]] || fail "missing $w4_spec"
[[ -f "$w7_spec" ]] || fail "missing $w7_spec"
[[ -d "$valid_dir" ]] || fail "missing $valid_dir"
[[ -d "$invalid_dir" ]] || fail "missing $invalid_dir"

python3 - "$schema" "$w8_spec" "$w2_spec" "$w4_spec" "$w7_spec" "$valid_dir" "$invalid_dir" <<'PY'
from __future__ import annotations

import ipaddress
import json
import re
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

schema_path = Path(sys.argv[1])
spec_paths = [Path(value) for value in sys.argv[2:6]]
valid_dir = Path(sys.argv[6])
invalid_dir = Path(sys.argv[7])

EXPECTED_REQUIRED = [
    "id",
    "version",
    "mode",
    "endpoint",
    "services",
    "allowPublicEgress",
    "optInCloudEgress",
    "evidence",
]
EXPECTED_MODES = ["single-user-default", "enterprise-lan", "cloud-opt-in"]
EXPECTED_SERVICES = {
    "oauthProxy": {"port": 0, "protocols": {"http"}},
    "pushGateway": {"port": 17801, "protocols": {"ws"}},
    "syncServer": {"port": 17802, "protocols": {"http"}},
    "auditSink": {"port": 17803, "protocols": {"http"}},
    "selfUpdate": {"port": 17804, "protocols": {"https"}},
}
EXPECTED_EVIDENCE_CATEGORIES = ["localcloud-config", "egress-opt-in", "health-check"]
EXPECTED_VALID_FILES = {
    "default-loopback.json",
    "enterprise-lan.json",
    "cloud-opt-in.json",
}
EXPECTED_INVALID_FILES = {
    "default-public-endpoint.json",
    "public-egress-without-opt-in.json",
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


def schema_errors(config: dict[str, Any], schema: dict[str, Any]) -> list[str]:
    return validate(config, schema, [])


def host_from_url(url: str) -> str:
    parsed = urlparse(url)
    if not parsed.scheme or not parsed.hostname:
        die(f"invalid URL in fixture: {url!r}")
    return parsed.hostname


def classify_host(host: str) -> str:
    try:
        ip = ipaddress.ip_address(host)
    except ValueError:
        return "public-name"
    if ip.is_loopback:
        return "loopback"
    if ip.is_private:
        return "private-lan"
    return "public-ip"


def is_local_host(host: str, *, allow_lan: bool) -> bool:
    category = classify_host(host)
    if category == "loopback":
        return True
    if allow_lan and category == "private-lan":
        return True
    return False


def semantic_errors(config: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    mode = config.get("mode")
    endpoint = config.get("endpoint", {})
    services = config.get("services", {})
    allow_public = config.get("allowPublicEgress")
    opt_in = config.get("optInCloudEgress")
    allowlist = config.get("egressAllowlist", [])
    evidence = config.get("evidence", {})

    if mode not in EXPECTED_MODES:
        errors.append(f"unknown mode {mode!r}")
        return errors

    default_or_lan = mode in {"single-user-default", "enterprise-lan"}
    allow_lan = mode == "enterprise-lan"
    if default_or_lan:
        if allow_public is not False:
            errors.append(f"{mode} must set allowPublicEgress=false")
        if opt_in is not False:
            errors.append(f"{mode} must set optInCloudEgress=false")
        if allowlist:
            errors.append(f"{mode} must not declare egressAllowlist")
        if evidence.get("category") != "localcloud-config":
            errors.append(f"{mode} evidence.category must be localcloud-config")

    if mode == "cloud-opt-in":
        if allow_public is not True or opt_in is not True:
            errors.append("cloud-opt-in must set allowPublicEgress=true and optInCloudEgress=true")
        if not isinstance(allowlist, list) or not allowlist:
            errors.append("cloud-opt-in must declare a non-empty egressAllowlist")
        if evidence.get("category") != "egress-opt-in":
            errors.append("cloud-opt-in evidence.category must be egress-opt-in")

    if evidence.get("emit") is not True:
        errors.append("evidence.emit must be true")
    if evidence.get("auditSinkRequired") is not True:
        errors.append("evidence.auditSinkRequired must be true")

    endpoint_host = host_from_url(endpoint.get("baseUrl", ""))
    endpoint_bind = endpoint.get("bindAddress", "")
    endpoint_allow_lan = endpoint.get("allowPrivateLan") is True
    expected_endpoint_lan = allow_lan
    if endpoint_allow_lan != expected_endpoint_lan:
        errors.append(f"{mode} endpoint.allowPrivateLan drifted")
    if default_or_lan and not is_local_host(endpoint_host, allow_lan=allow_lan):
        errors.append(f"{mode} endpoint host {endpoint_host!r} is not loopback/private LAN")
    if default_or_lan and not is_local_host(endpoint_bind, allow_lan=allow_lan):
        errors.append(f"{mode} bindAddress {endpoint_bind!r} is not loopback/private LAN")

    if set(services) != set(EXPECTED_SERVICES):
        errors.append(f"service roster drifted: {sorted(services)}")
        return errors

    for name, expected in EXPECTED_SERVICES.items():
        service = services[name]
        port = service.get("port")
        protocol = service.get("protocol")
        public_egress = service.get("publicEgress")
        bind_address = service.get("bindAddress", "")

        if port != expected["port"]:
            errors.append(f"{name}.port must be {expected['port']}, got {port!r}")
        if protocol not in expected["protocols"]:
            errors.append(f"{name}.protocol {protocol!r} not in {sorted(expected['protocols'])}")
        if default_or_lan and public_egress is not False:
            errors.append(f"{mode} {name}.publicEgress must be false")
        if public_egress is True and not (allow_public is True and opt_in is True):
            errors.append(f"{name}.publicEgress requires explicit cloud opt-in")
        if default_or_lan and not is_local_host(bind_address, allow_lan=allow_lan):
            errors.append(f"{mode} {name}.bindAddress {bind_address!r} is not loopback/private LAN")

    for index, item in enumerate(allowlist if isinstance(allowlist, list) else []):
        if item.get("evidenceCategory") != "egress-opt-in":
            errors.append(f"egressAllowlist[{index}] must require egress-opt-in evidence")

    return errors


schema = load(schema_path)
if not isinstance(schema, dict):
    die("localcloud schema top-level is not an object")

pass_count = 0

if schema.get("required") != EXPECTED_REQUIRED:
    die(f"schema.required drifted: {schema.get('required')!r}")
if schema.get("additionalProperties") is not False:
    die("schema must set top-level additionalProperties:false")
pass_count += 1

props = schema.get("properties", {})
if not isinstance(props, dict):
    die("schema.properties missing")
if props.get("mode", {}).get("enum") != EXPECTED_MODES:
    die("mode enum drifted")
if props.get("evidence", {}).get("properties", {}).get("category", {}).get("enum") != EXPECTED_EVIDENCE_CATEGORIES:
    die("evidence.category enum drifted")
pass_count += 1

endpoint_schema = props.get("endpoint", {})
services_schema = props.get("services", {})
if endpoint_schema.get("additionalProperties") is not False:
    die("endpoint must set additionalProperties:false")
if services_schema.get("required") != list(EXPECTED_SERVICES):
    die("services.required roster/order drifted")
if services_schema.get("additionalProperties") is not False:
    die("services must set additionalProperties:false")
for name in EXPECTED_SERVICES:
    if services_schema.get("properties", {}).get(name, {}).get("additionalProperties") is not False:
        die(f"{name} must set additionalProperties:false")
pass_count += 1

combined_specs = "\n".join(path.read_text(encoding="utf-8") for path in spec_paths)
for needle in [
    "H10 = **local-cloud-no-egress test**",
    "127.0.0.1",
    "10/8",
    "172.16/12",
    "192.168/16",
    "TCP 17801",
    "TCP 17802",
    "TCP 17803",
    "17804",
    "APNs+FCM（opt-in）",
    "W8 本地 sink server",
]:
    if needle not in combined_specs:
        die(f"V3 specs no longer mention H10/W8 invariant {needle!r}")
pass_count += 1

valid_paths = sorted(valid_dir.glob("*.json"))
invalid_paths = sorted(invalid_dir.glob("*.json"))
if {path.name for path in valid_paths} != EXPECTED_VALID_FILES:
    die(f"valid fixture roster drifted: {[path.name for path in valid_paths]}")
if {path.name for path in invalid_paths} != EXPECTED_INVALID_FILES:
    die(f"invalid fixture roster drifted: {[path.name for path in invalid_paths]}")
pass_count += 1

seen_modes: set[str] = set()
for path in valid_paths:
    fixture = load(path)
    if not isinstance(fixture, dict):
        die(f"{path} top-level must be object")
    errors = schema_errors(fixture, schema)
    if errors:
        die(f"{path} schema errors: {errors}")
    errors = semantic_errors(fixture)
    if errors:
        die(f"{path} semantic errors: {errors}")
    seen_modes.add(fixture["mode"])

if seen_modes != set(EXPECTED_MODES):
    die(f"valid fixtures must cover all modes, saw {sorted(seen_modes)}")
pass_count += 1

for path in invalid_paths:
    fixture = load(path)
    if not isinstance(fixture, dict):
        die(f"{path} top-level must be object")
    schema_only = schema_errors(fixture, schema)
    if schema_only:
        die(f"{path} should be schema-valid and semantically invalid, got schema errors: {schema_only}")
    errors = semantic_errors(fixture)
    if not errors:
        die(f"{path} unexpectedly passed semantic no-egress checks")
pass_count += 1

default_fixture = load(valid_dir / "default-loopback.json")
if any(service["bindAddress"] != "127.0.0.1" for service in default_fixture["services"].values()):
    die("default-loopback services must all bind 127.0.0.1")
if default_fixture["endpoint"]["baseUrl"] != "http://127.0.0.1:17802":
    die("default-loopback endpoint drifted")
pass_count += 1

enterprise_fixture = load(valid_dir / "enterprise-lan.json")
if classify_host(host_from_url(enterprise_fixture["endpoint"]["baseUrl"])) != "private-lan":
    die("enterprise-lan endpoint must be private LAN")
if any(service["publicEgress"] is not False for service in enterprise_fixture["services"].values()):
    die("enterprise-lan services must all set publicEgress=false")
pass_count += 1

opt_in_fixture = load(valid_dir / "cloud-opt-in.json")
if opt_in_fixture.get("allowPublicEgress") is not True or opt_in_fixture.get("optInCloudEgress") is not True:
    die("cloud-opt-in must explicitly enable both public egress gates")
if not opt_in_fixture.get("egressAllowlist"):
    die("cloud-opt-in must carry an allowlist")
if any(service["publicEgress"] is not False for service in opt_in_fixture["services"].values()):
    die("cloud-opt-in localcloud services must still avoid direct public egress")
pass_count += 1

print("Status: passed")
print("Harness: H10 local-cloud no-egress contract")
print(f"Valid fixtures: {len(valid_paths)}")
print(f"Invalid fixtures: {len(invalid_paths)}")
print("Default egress: loopback/private-LAN only; public egress requires explicit opt-in")
print(f"Checks: {pass_count}")
PY
