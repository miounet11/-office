#!/usr/bin/env bash
# V3 W2/M4.1 - connector manifest loader runtime smoke.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src_root="$repo_root/libreoffice-core"

fail() {
    printf 'FAIL: %s\\n' "$1" >&2
    exit 1
}

[[ -d "$src_root" ]] || fail "missing source root $src_root"

python3 - "$repo_root" "$src_root" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

repo = Path(sys.argv[1])
src = Path(sys.argv[2])

loader_hxx = src / "sfx2/source/sidebar/AIChatConnectorManifestLoader.hxx"
loader_cxx = src / "sfx2/source/sidebar/AIChatConnectorManifestLoader.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
schema = repo / "docs/schemas/connector-manifest.schema.json"
trust_policy = repo / "docs/product/v3/w2-manifest-trust-policy.md"
ops_policy = repo / "docs/product/v3/w2-connector-operations-policy.md"
auth_policy = repo / "docs/product/v3/w2-auth-flow-policy.md"
refresh_policy = repo / "docs/product/v3/w2-token-refresh-policy.md"
contract_test = repo / "tests/v3-connector-manifest-contract-test.sh"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [
    loader_hxx,
    loader_cxx,
    library_mk,
    schema,
    trust_policy,
    ops_policy,
    auth_policy,
    refresh_policy,
    contract_test,
    todo,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = loader_hxx.read_text()
cxx = loader_cxx.read_text()

def strip_leading_block_comments(text: str) -> str:
    body = text.lstrip()
    while body.startswith("/*") and "*/" in body:
        body = body.split("*/", 1)[1].lstrip()
    return body

cxx_body = strip_leading_block_comments(cxx)
mk = library_mk.read_text()
schema_text = schema.read_text()
trust_text = trust_policy.read_text()
ops_text = ops_policy.read_text()
auth_text = auth_policy.read_text()
refresh_text = refresh_policy.read_text()
contract = contract_test.read_text()
todo_text = todo.read_text()
combined = hxx + cxx

fields = [
    "Id",
    "Version",
    "DisplayName",
    "TrustSource",
    "Publisher",
    "ManifestSha256",
    "ReviewState",
    "InstallScope",
    "SignatureRequired",
    "AllowUnsigned",
    "OperationMode",
    "AllowedActions",
    "Writeback",
    "WriteScopesAllowed",
    "RuntimeWriteImplementation",
    "AuthType",
    "AuthScopes",
    "TokenStorage",
    "AuthFlowStrategy",
    "EmbeddedWebView",
    "AuthCallback",
    "RuntimeAuthImplementation",
    "RefreshStrategy",
    "BackgroundRefresh",
    "StoresRefreshToken",
    "RuntimeRefreshImplementation",
    "ServiceModes",
    "Scopes",
    "EvidenceEmit",
    "EvidenceCategory",
    "RequiresTenantPolicy",
    "CacheTTLSeconds",
]
invalid_reasons = [
    "trust-envelope",
    "read-only-operations",
    "auth-flow",
    "token-refresh",
    "offline-service-mode",
    "evidence",
    "tenant-policy-required",
]

checks = {
    "schema trust": "manifestSha256" in schema_text and "signatureRequired" in schema_text and "allowUnsigned" in schema_text,
    "schema read only": '"mode": {' in schema_text and '"const": "read-only"' in schema_text and '"writeback": {' in schema_text,
    "schema auth flow": "system-browser-loopback" in schema_text and "embeddedWebView" in schema_text,
    "schema refresh": "backgroundRefresh" in schema_text and "storesRefreshToken" in schema_text,
    "trust policy loader rejects unsigned": "manifest loader rejects unsigned manifests" in trust_text,
    "ops policy no writeback": "Connectors may not claim auth runtime implementation" not in ops_text and "writeback" in ops_text and "read-only" in ops_text,
    "auth policy system browser": "system-browser-loopback" in auth_text and "embeddedWebView=false" in auth_text,
    "refresh policy no background": "backgroundRefresh=false" in refresh_text and "storesRefreshToken=false" in refresh_text,
    "contract fixture roster": "EXPECTED_ROSTER" in contract and "local-fs" in contract and "notion" in contract and "invalid_paths" in contract,
    "loader class": "class AIChatConnectorManifestLoader final" in hxx,
    "manifest struct": "struct AIChatConnectorManifest" in hxx,
    "load result": "struct AIChatConnectorManifestLoadResult" in hxx,
    "all fields": all(field in hxx for field in fields),
    "compiled": "sfx2/source/sidebar/AIChatConnectorManifestLoader" in mk,
    "uses boost json": "boost::property_tree::read_json" in cxx,
    "bounded file read": "MAX_CONNECTOR_MANIFEST_BYTES" in cxx,
    "load from file": "LoadFromFile" in hxx + cxx and "connector-manifest-load-failed" in cxx,
    "load from string": "LoadFromString" in hxx + cxx,
    "validate api": "Validate" in hxx + cxx,
    "id validation": "IsValidConnectorId" in hxx + cxx and "^[a-z][a-z0-9-]{2,31}$" not in cxx,
    "publisher validation": "IsValidPublisher" in hxx + cxx,
    "sha validation": "IsValidManifestSha256" in hxx + cxx and "sha256:" in cxx and "IsLowerHex" in cxx,
    "trust envelope validation": "IsValidTrustEnvelope" in hxx + cxx,
    "builtin semantics": 'TrustSource == u"builtin"_ustr' in cxx and 'Publisher == u"kqoffice"_ustr' in cxx and 'ReviewState == u"repo-reviewed"_ustr' in cxx,
    "community semantics": 'TrustSource == u"community"_ustr' in cxx and "security-reviewed" in cxx and "tenant-approved" in cxx,
    "enterprise semantics": 'TrustSource == u"enterprise-admin"_ustr' in cxx and "tenant-approved" in cxx,
    "signature posture": "SignatureRequired" in cxx and "AllowUnsigned" in cxx and "allow-unsigned=false" in cxx,
    "read only envelope": "IsReadOnlyOperationsEnvelope" in hxx + cxx and 'OperationMode == u"read-only"_ustr' in cxx and 'AllowedActions.front() == u"read"_ustr' in cxx,
    "writeback guard": "!rManifest.Writeback" in cxx and "!rManifest.WriteScopesAllowed" in cxx and 'RuntimeWriteImplementation == u"not-started"_ustr' in cxx,
    "write scope guard": "HasWriteScope" in cxx and "HasWriteConnectorScope" in cxx,
    "auth flow validation": "IsAuthFlowAllowed" in hxx + cxx,
    "oauth loopback": 'AuthType == u"oauth2"_ustr' in cxx and "system-browser-loopback" in cxx and "loopback-127.0.0.1" in cxx,
    "api key manual": 'AuthType == u"api-key"_ustr' in cxx and "manual-secret-entry" in cxx and "manual-entry" in cxx,
    "auth none": 'AuthType == u"none"_ustr' in cxx and "not-applicable" in cxx,
    "no embedded webview": "EmbeddedWebView" in cxx and 'RuntimeAuthImplementation != u"not-started"_ustr' in cxx,
    "refresh validation": "IsRefreshPolicyAllowed" in hxx + cxx,
    "refresh strategies": "reauth-on-expiry" in cxx and "manual-rotate" in cxx and "not-applicable" in cxx,
    "no background refresh": "BackgroundRefresh" in cxx and "StoresRefreshToken" in cxx and 'RuntimeRefreshImplementation != u"not-started"_ustr' in cxx,
    "offline rejected": 'u"offline"_ustr' in cxx and "offline-service-mode" in cxx,
    "evidence data fetch": "EvidenceEmit" in cxx and 'EvidenceCategory != u"data-fetch"_ustr' in cxx,
    "tenant policy guard": "RequiresTenantPolicyForScopes" in hxx + cxx and "confidential" in cxx and "secret" in cxx,
    "invalid reasons": all(reason in cxx for reason in invalid_reasons),
    "success metadata only": "connector-manifest-loaded" in cxx and "metadata-only=true" in cxx and "raw-payload=false" in cxx,
    "no network started": "network-started=false" in cxx,
    "no writeback started": "connector-writeback=false" in cxx,
    "todo has m4.1": "M4.1 Implement connector manifest loader" in todo_text,
    "no raw body fields": "RawContent" not in combined and "Payload" not in combined and "ManifestBody" not in combined,
    "no connector runtime classes": "ConnectorManager" not in combined and "ConnectorRegistry" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no auth runtime": "Keychain" not in combined and "DPAPI" not in combined and "libsecret" not in combined and "XSystemShellExecute" not in combined,
    "no webview runtime": "WebViewShell" not in combined and "WebViewController" not in combined and "VclWebView" not in combined,
    "no document mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 connector manifest loader runtime self-test passed. Checks: {len(checks)}")
PY
