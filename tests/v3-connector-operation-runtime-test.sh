#!/usr/bin/env bash
# V3 W2/M4.2 - connector read-only operation runtime smoke.

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

runtime_hxx = src / "sfx2/source/sidebar/AIChatConnectorOperationRuntime.hxx"
runtime_cxx = src / "sfx2/source/sidebar/AIChatConnectorOperationRuntime.cxx"
manifest_hxx = src / "sfx2/source/sidebar/AIChatConnectorManifestLoader.hxx"
manifest_cxx = src / "sfx2/source/sidebar/AIChatConnectorManifestLoader.cxx"
registry_hxx = src / "sfx2/source/sidebar/AIChatContentRegistry.hxx"
registry_cxx = src / "sfx2/source/sidebar/AIChatContentRegistry.cxx"
provenance_hxx = src / "sfx2/source/sidebar/AIChatSourceProvenance.hxx"
provenance_cxx = src / "sfx2/source/sidebar/AIChatSourceProvenance.cxx"
preview_cxx = src / "sfx2/source/sidebar/AIChatPreviewMatrix.cxx"
opener_cxx = src / "sfx2/source/sidebar/AIChatContentOpener.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
ops_policy = repo / "docs/product/v3/w2-connector-operations-policy.md"
layer_spec = repo / "docs/product/v3/w2-connector-layer-spec.md"
registry_policy = repo / "docs/product/v3/w1-workspace-content-registry-policy.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"
in_app = repo / "tests/v3-in-app-chat-test.sh"

for path in [
    runtime_hxx,
    runtime_cxx,
    manifest_hxx,
    manifest_cxx,
    registry_hxx,
    registry_cxx,
    provenance_hxx,
    provenance_cxx,
    preview_cxx,
    opener_cxx,
    library_mk,
    ops_policy,
    layer_spec,
    registry_policy,
    todo,
    in_app,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = runtime_hxx.read_text()
cxx = runtime_cxx.read_text()
manifest = manifest_hxx.read_text() + manifest_cxx.read_text()
registry = registry_hxx.read_text() + registry_cxx.read_text()
provenance = provenance_hxx.read_text() + provenance_cxx.read_text()
preview = preview_cxx.read_text()
opener = opener_cxx.read_text()
mk = library_mk.read_text()
ops_text = ops_policy.read_text()
spec_text = layer_spec.read_text()
registry_policy_text = registry_policy.read_text()
todo_text = todo.read_text()
in_app_text = in_app.read_text()
combined = hxx + cxx

def strip_leading_block_comments(text: str) -> str:
    body = text.lstrip()
    while body.startswith("/*") and "*/" in body:
        body = body.split("*/", 1)[1].lstrip()
    return body

cxx_body = strip_leading_block_comments(cxx)

required_fields = [
    "ConnectorId",
    "Action",
    "QueryRef",
    "ScopeRef",
    "TenantPolicyRef",
    "CallerSurface",
    "UserApproved",
    "OperationId",
    "EvidenceId",
    "CitationId",
    "HashReference",
    "RegistryEntry",
]

write_guards = [
    'rAction == u"write"_ustr',
    'rAction == u"create"_ustr',
    'rAction == u"update"_ustr',
    'rAction == u"delete"_ustr',
    'rAction == u"patch"_ustr',
    'rAction == u"writeback"_ustr',
    'rAction.indexOf(u":write"_ustr) >= 0',
    'rAction.startsWith(u"write:"_ustr)',
]

checks = {
    "policy read only": "read-only" in ops_text and "writeback" in ops_text and "runtimeWriteImplementation" in ops_text,
    "spec connector result": "Connector 调用产生标准 evidence" in spec_text and "data-fetch" in spec_text,
    "runtime class": "class AIChatConnectorOperationRuntime final" in hxx,
    "request result structs": "struct AIChatConnectorOperationRequest" in hxx and "struct AIChatConnectorOperationResult" in hxx,
    "all fields": all(field in hxx for field in required_fields),
    "compiled": "sfx2/source/sidebar/AIChatConnectorOperationRuntime" in mk,
    "manifest validation reused": "AIChatConnectorManifestLoader::IsReadOnlyOperationsEnvelope" in cxx and "AIChatConnectorManifest" in hxx,
    "read action only": 'rRequest.Action == u"read"_ustr' in cxx and 'Contains(rManifest.AllowedActions, u"read"_ustr)' in cxx,
    "write guards": all(guard in cxx for guard in write_guards),
    "write denied message": "write-action-forbidden" in cxx and "connector-writeback=false" in cxx and "data-write=false" in cxx,
    "read envelope guards": "!rManifest.Writeback" in cxx and "!rManifest.WriteScopesAllowed" in cxx and 'RuntimeWriteImplementation == u"not-started"_ustr' in cxx,
    "evidence data fetch": "rManifest.EvidenceEmit" in cxx and 'rManifest.EvidenceCategory == u"data-fetch"_ustr' in cxx,
    "approval required": "user-approval-required" in cxx and "UserApproved" in hxx,
    "tenant policy required": "tenant-policy-required" in cxx and "RequiresTenantPolicy" in cxx,
    "query ref required": "missing-query-reference" in cxx,
    "operation id deterministic": "MakeOperationId" in hxx + cxx and "HashMetadata" in cxx and "comphelper::Hash::calculateHash" in cxx,
    "evidence id": "evidence:connector-fetch:" in cxx,
    "hash reference": "MakeConnectorHashReference" in hxx + cxx and "sha256:" in cxx,
    "registry result": "AIChatContentRegistry aRegistry" in cxx and "aRegistry.RegisterObject(aResult.RegistryEntry)" in cxx,
    "connector result type": 'RegistryEntry.Type = u"connector-result"_ustr' in cxx,
    "source surface": 'u"connector-runtime"_ustr' in cxx and "CallerSurface" in hxx,
    "open preview": 'OpenTarget = u"sidebar-preview"_ustr' in cxx and 'PreviewMode = u"metadata-summary"_ustr' in cxx,
    "provenance result": "AIChatSourceProvenance aProvenance" in cxx and "aProvenance.RegisterSource(aSource)" in cxx,
    "citation result": "AIChatSourceProvenance::MakeCitationId(aResult.OperationId)" in cxx,
    "span metadata": "span:connector-metadata:" in cxx,
    "success metadata only": "connector-operation-complete" in cxx and "metadata-only=true" in cxx and "raw-payload=false" in cxx,
    "no network started": "network-started=false" in cxx,
    "no writeback started": "connector-writeback=false" in cxx,
    "no data write": "data-write=false" in cxx,
    "no main mutation": "main-document-mutation=false" in cxx,
    "w1 registry supports connector": "connector-result" in registry_policy_text and "connector-result" in preview and "read-only=true" in opener,
    "in app runs operation smoke": "v3-connector-operation-runtime-test.sh" in in_app_text,
    "todo completed m4.2": "- [x] M4.2 Implement read-only connector operations" in todo_text and "Follow-up task id: M4.3" in todo_text,
    "no raw payload fields": "RawContent" not in combined and "Payload" not in combined and "ResponseBody" not in combined and "ResultBody" not in combined,
    "no connector manager": "ConnectorManager" not in combined and "ConnectorRegistry" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no auth runtime": "Keychain" not in combined and "DPAPI" not in combined and "libsecret" not in combined and "XSystemShellExecute" not in combined,
    "no webview runtime": "WebViewShell" not in combined and "WebViewController" not in combined and "VclWebView" not in combined,
    "no document mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 connector operation runtime self-test passed. Checks: {len(checks)}")
PY
