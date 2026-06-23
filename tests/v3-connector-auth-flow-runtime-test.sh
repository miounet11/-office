#!/usr/bin/env bash
# V3 W2/M4.3 - connector auth flow runtime guard smoke.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src_root="$repo_root/libreoffice-core"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -d "$src_root" ]] || fail "missing source root $src_root"

python3 - "$repo_root" "$src_root" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

repo = Path(sys.argv[1])
src = Path(sys.argv[2])

auth_hxx = src / "sfx2/source/sidebar/AIChatConnectorAuthFlowRuntime.hxx"
auth_cxx = src / "sfx2/source/sidebar/AIChatConnectorAuthFlowRuntime.cxx"
manifest_hxx = src / "sfx2/source/sidebar/AIChatConnectorManifestLoader.hxx"
manifest_cxx = src / "sfx2/source/sidebar/AIChatConnectorManifestLoader.cxx"
operation_hxx = src / "sfx2/source/sidebar/AIChatConnectorOperationRuntime.hxx"
operation_cxx = src / "sfx2/source/sidebar/AIChatConnectorOperationRuntime.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
auth_policy = repo / "docs/product/v3/w2-auth-flow-policy.md"
refresh_policy = repo / "docs/product/v3/w2-token-refresh-policy.md"
layer_spec = repo / "docs/product/v3/w2-connector-layer-spec.md"
contract_test = repo / "tests/v3-connector-manifest-contract-test.sh"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"
in_app = repo / "tests/v3-in-app-chat-test.sh"

for path in [
    auth_hxx,
    auth_cxx,
    manifest_hxx,
    manifest_cxx,
    operation_hxx,
    operation_cxx,
    library_mk,
    auth_policy,
    refresh_policy,
    layer_spec,
    contract_test,
    todo,
    in_app,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = auth_hxx.read_text()
cxx = auth_cxx.read_text()
manifest = manifest_hxx.read_text() + manifest_cxx.read_text()
operation = operation_hxx.read_text() + operation_cxx.read_text()
mk = library_mk.read_text()
auth_text = auth_policy.read_text()
refresh_text = refresh_policy.read_text()
spec_text = layer_spec.read_text()
contract = contract_test.read_text()
todo_text = todo.read_text()
in_app_text = in_app.read_text()
combined = hxx + cxx

def strip_leading_block_comments(text: str) -> str:
    body = text.lstrip()
    while body.startswith("/*") and "*/" in body:
        body = body.split("*/", 1)[1].lstrip()
    return body

cxx_body = strip_leading_block_comments(cxx)

fields = [
    "ConnectorId",
    "UserAction",
    "TenantPolicyRef",
    "UserApproved",
    "AuthType",
    "RequiredUserAction",
    "AuthSurface",
    "CallbackBinding",
    "TokenStoragePosture",
    "RefreshPosture",
    "EvidenceCategory",
]

checks = {
    "auth policy locked": "system-browser-loopback" in auth_text and "manual-secret-entry" in auth_text and "embeddedWebView=false" in auth_text,
    "refresh policy locked": "reauth-on-expiry" in refresh_text and "manual-rotate" in refresh_text and "backgroundRefresh=false" in refresh_text and "storesRefreshToken=false" in refresh_text,
    "spec auth decisions": "system-browser-loopback" in spec_text and "runtimeAuthImplementation=not-started" in spec_text,
    "contract guards": "embedded-webview-auth-flow.json" in contract and "runtime-auth-implementation-started.json" in contract and "refresh-token-stored.json" in contract,
    "runtime class": "class AIChatConnectorAuthFlowRuntime final" in hxx,
    "request result structs": "struct AIChatConnectorAuthFlowRequest" in hxx and "struct AIChatConnectorAuthFlowResult" in hxx,
    "all fields": all(field in hxx for field in fields),
    "compiled": "sfx2/source/sidebar/AIChatConnectorAuthFlowRuntime" in mk,
    "manifest auth reused": "AIChatConnectorManifestLoader::IsAuthFlowAllowed" in cxx and "AIChatConnectorManifestLoader::IsRefreshPolicyAllowed" in cxx,
    "no embedded webview": "!rManifest.EmbeddedWebView" in cxx and "embedded-webview=false" in cxx,
    "auth runtime not started": 'RuntimeAuthImplementation == u"not-started"_ustr' in cxx and "auth-runtime=not-started" in cxx,
    "refresh runtime not started": 'RuntimeRefreshImplementation == u"not-started"_ustr' in cxx and "refresh-runtime=not-started" in cxx,
    "no background refresh": "!rManifest.BackgroundRefresh" in cxx and "background-refresh=false" in cxx,
    "no refresh token storage": "!rManifest.StoresRefreshToken" in cxx and "stores-refresh-token=false" in cxx,
    "oauth action": 'AuthType == u"oauth2"_ustr' in cxx and "open-system-browser-loopback" in cxx and "system-browser" in cxx,
    "api key action": 'AuthType == u"api-key"_ustr' in cxx and "manual-secret-entry" in cxx and "native-secret-entry" in cxx,
    "none action": 'AuthType == u"none"_ustr' in cxx and "not-applicable" in cxx and 'return u"none"_ustr' in cxx,
    "approval required": "user-approval-required" in cxx and "UserApproved" in hxx,
    "expected user action": "unexpected-user-action" in cxx and "expected=" in cxx,
    "tenant policy required": "tenant-policy-required" in cxx and "RequiresTenantPolicy" in cxx,
    "credential redaction": "credential-redacted=true" in cxx and "secret-material-present=false" in cxx and "raw-secret=false" in cxx,
    "token redaction": "raw-token=false" in cxx and "stores-refresh-token=false" in cxx,
    "auth evidence": 'EvidenceCategory = u"auth"_ustr' in cxx and "evidence-category=auth" in cxx,
    "no browser started": "system-browser-started=false" in cxx,
    "no loopback listener": "loopback-listener-started=false" in cxx,
    "no network started": "network-started=false" in cxx,
    "operation remains read only": "connector-writeback=false" in operation and "data-write=false" in operation,
    "in app runs auth smoke": "v3-connector-auth-flow-runtime-test.sh" in in_app_text,
    "todo completed m4.3": "- [x] M4.3 Implement connector auth flow" in todo_text and "Follow-up task id: M4.4" in todo_text,
    "no raw secret fields": "RawSecret" not in combined and "SecretValue" not in combined and "AccessToken" not in combined and "RefreshTokenValue" not in combined,
    "no auth secret stores": "Keychain" not in combined and "DPAPI" not in combined and "libsecret" not in combined,
    "no shell execute": "XSystemShellExecute" not in combined and "SystemShellExecute" not in combined,
    "no webview runtime": "WebViewShell" not in combined and "WebViewController" not in combined and "VclWebView" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no document mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 connector auth flow runtime self-test passed. Checks: {len(checks)}")
PY
