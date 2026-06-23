#!/usr/bin/env bash
# V3 W8/M6.4 - local cloud sync-message runtime smoke.

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

runtime_hxx = src / "sfx2/source/sidebar/AIChatLocalCloudSyncRuntime.hxx"
runtime_cxx = src / "sfx2/source/sidebar/AIChatLocalCloudSyncRuntime.cxx"
tenant_cxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.cxx"
tenant_hxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.hxx"
policy_cxx = src / "sfx2/source/sidebar/AIChatPolicyEngineRuntime.cxx"
audit_hxx = src / "sfx2/source/sidebar/AIChatAuditLogRuntime.hxx"
audit_cxx = src / "sfx2/source/sidebar/AIChatAuditLogRuntime.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
sync_schema = repo / "docs/schemas/sync-message.schema.json"
localcloud_schema = repo / "docs/schemas/localcloud-config.schema.json"
policy_schema = repo / "docs/schemas/policy-rule.schema.json"
w8_spec = repo / "docs/product/v3/w8-local-cloud-spec.md"
w4_spec = repo / "docs/product/v3/w4-tenant-policy-audit-spec.md"
w7_spec = repo / "docs/product/v3/w7-companion-spec.md"
sync_contract = repo / "tests/v3-sync-message-test.sh"
no_egress_test = repo / "tests/v3-local-cloud-no-egress-test.sh"
audit_test = repo / "tests/v3-audit-log-runtime-test.sh"
policy_test = repo / "tests/v3-policy-engine-runtime-test.sh"
tenant_test = repo / "tests/v3-tenant-context-runtime-test.sh"
in_app = repo / "tests/v3-in-app-chat-test.sh"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [
    runtime_hxx,
    runtime_cxx,
    tenant_cxx,
    tenant_hxx,
    policy_cxx,
    audit_hxx,
    audit_cxx,
    library_mk,
    sync_schema,
    localcloud_schema,
    policy_schema,
    w8_spec,
    w4_spec,
    w7_spec,
    sync_contract,
    no_egress_test,
    audit_test,
    policy_test,
    tenant_test,
    in_app,
    todo,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = runtime_hxx.read_text()
cxx = runtime_cxx.read_text()
combined = hxx + cxx
tenant = tenant_hxx.read_text() + tenant_cxx.read_text()
policy = policy_cxx.read_text()
audit = audit_hxx.read_text() + audit_cxx.read_text()
mk = library_mk.read_text()
sync_schema_text = sync_schema.read_text()
localcloud_schema_text = localcloud_schema.read_text()
policy_schema_text = policy_schema.read_text()
w8_text = w8_spec.read_text()
w4_text = w4_spec.read_text()
w7_text = w7_spec.read_text()
sync_contract_text = sync_contract.read_text()
no_egress_text = no_egress_test.read_text()
audit_test_text = audit_test.read_text()
policy_test_text = policy_test.read_text()
tenant_test_text = tenant_test.read_text()
in_app_text = in_app.read_text()
todo_text = todo.read_text()


def strip_leading_block_comments(text: str) -> str:
    body = text.lstrip()
    while body.startswith("/*") and "*/" in body:
        body = body.split("*/", 1)[1].lstrip()
    return body


cxx_body = strip_leading_block_comments(cxx)

payload_fields = ["RefType", "RefId", "HashReference", "StoresDocumentContent", "ContainsRawPayload"]
transport_fields = ["Mode", "EndpointClass", "Port", "PublicEgress", "MTLSRequired"]
ordering_fields = ["Sequence", "IdempotencyKey", "AckRequired"]
boundary_fields = ["ServiceMode", "StoresDocumentContent", "HashOnly", "DefaultNoPublicEgress"]
message_fields = [
    "SyncMessageId",
    "SchemaVersion",
    "CreatedAt",
    "TenantId",
    "WorkspaceId",
    "Channel",
    "Direction",
    "Kind",
    "Payload",
    "Transport",
    "Ordering",
    "Boundary",
    "RequiredEvidence",
    "EvidenceIds",
    "AuditLogRef",
    "PolicyContextRef",
    "AuditChainRef",
    "TenantContextRef",
]
apis = [
    "AppendMessage",
    "AppendAcknowledgement",
    "LoadMessages",
    "IsSyncMessageIdAllowed",
    "IsTimestampAllowed",
    "IsChannelAllowed",
    "IsDirectionAllowed",
    "IsKindAllowed",
    "IsPayloadRefTypeAllowed",
    "IsPayloadRefIdAllowed",
    "IsPayloadShapeAllowed",
    "IsTransportModeAllowed",
    "IsEndpointClassAllowed",
    "IsTransportShapeAllowed",
    "IsOrderingShapeAllowed",
    "IsBoundaryShapeAllowed",
    "IsRequiredEvidenceAllowed",
    "IsMessageShapeAllowed",
    "MakeSyncMessageId",
    "MakeIdempotencyKey",
    "MakeAuditLogRef",
    "MakeTenantContextRef",
]

checks = {
    "runtime class": "class AIChatLocalCloudSyncRuntime final" in hxx,
    "payload struct": "struct AIChatLocalCloudSyncPayloadRef" in hxx and all(field in hxx for field in payload_fields),
    "transport struct": "struct AIChatLocalCloudSyncTransport" in hxx and all(field in hxx for field in transport_fields),
    "ordering struct": "struct AIChatLocalCloudSyncOrdering" in hxx and all(field in hxx for field in ordering_fields),
    "boundary struct": "struct AIChatLocalCloudSyncBoundary" in hxx and all(field in hxx for field in boundary_fields),
    "message struct": "struct AIChatLocalCloudSyncMessage" in hxx and all(field in hxx for field in message_fields),
    "result struct": "struct AIChatLocalCloudSyncResult" in hxx and "MessageRecord" in hxx and "Message" in hxx,
    "public api": all(api in hxx + cxx for api in apis),
    "compiled": "sfx2/source/sidebar/AIChatLocalCloudSyncRuntime" in mk,
    "uses tenant": '#include "AIChatAuditLogRuntime.hxx"' in hxx and "AIChatTenantContextRuntime" in cxx and "ValidateActionScope" in cxx,
    "uses audit": "AIChatAuditLogEntry" in hxx and "MakeAuditLogRef" in cxx and "audit-log-entry:" in cxx,
    "uses hash": "AIChatKnowledgeIndexStore::MakeMetadataHash" in cxx,
    "storage sidecar": "kqoffice-v3-ai-local-cloud-sync" in cxx and "sync-messages.tsv" in cxx,
    "append only": "AppendUtf8Line" in cxx and "setPos(osl_Pos_Absolut, nSize)" in cxx,
    "size guard": "MAX_LOCAL_CLOUD_SYNC_BYTES" in cxx and "2 * 1024 * 1024" in cxx,
    "tsv parser": "ParseSyncMessageLine" in cxx and "SerializeSyncMessageLine" in cxx and "aFields.size() != 31" in cxx,
    "schema version": 'v3-sync-message/0.1' in cxx and 'rMessage.SchemaVersion != u"v3-sync-message/0.1"_ustr' in cxx,
    "sync id": "IsSyncMessageIdAllowed" in cxx and 'rSyncMessageId.startsWith(u"sync-"_ustr)' in cxx,
    "timestamp": "IsTimestampAllowed" in cxx and "AIChatAuditLogRuntime::IsTimestampAllowed" in cxx,
    "channels": all(x in cxx for x in ['u"desktop-to-sync"_ustr', 'u"sync-to-companion"_ustr', 'u"companion-to-sync"_ustr', 'u"sync-to-desktop"_ustr']),
    "directions": all(x in cxx for x in ['u"upload"_ustr', 'u"download"_ustr', 'u"ack"_ustr']),
    "kinds": all(x in cxx for x in ['u"evidence-sync"_ustr', 'u"diff-summary-sync"_ustr', 'u"approval-decision-sync"_ustr', 'u"task-state-sync"_ustr']),
    "ref types": all(x in cxx for x in ['u"evidence-record"_ustr', 'u"companion-diff-summary"_ustr', 'u"companion-approval-request"_ustr', 'u"agent-task-state"_ustr']),
    "ref ids": all(x in cxx for x in ['sPrefix == u"ev"_ustr', 'sPrefix == u"cds"_ustr', 'sPrefix == u"car"_ustr', 'sPrefix == u"agt"_ustr']),
    "hash only payload": "IsPayloadShapeAllowed" in cxx and "!rPayload.StoresDocumentContent" in cxx and "!rPayload.ContainsRawPayload" in cxx,
    "transport modes": 'rMode == u"local-socket"_ustr' in cxx and 'rMode == u"lan-grpc"_ustr' in cxx,
    "endpoint classes": 'rEndpointClass == u"loopback"_ustr' in cxx and 'rEndpointClass == u"private-lan"_ustr' in cxx,
    "port": "W8_SYNC_PORT = 17802" in cxx and "rTransport.Port != W8_SYNC_PORT" in cxx,
    "no public egress": "rTransport.PublicEgress" in cxx and "publicEgress=false" in cxx and "defaultNoPublicEgress=true" in cxx,
    "mtls": "MTLSRequired" in hxx and "!rTransport.MTLSRequired" in cxx and "mTLSRequired=true" in cxx,
    "local mapping": 'rTransport.Mode == u"local-socket"_ustr' in cxx and 'rTransport.EndpointClass == u"loopback"_ustr' in cxx,
    "lan mapping": 'rTransport.Mode == u"lan-grpc"_ustr' in cxx and 'rTransport.EndpointClass == u"private-lan"_ustr' in cxx,
    "ordering": "IsOrderingShapeAllowed" in cxx and "Sequence >= 1" in cxx and "2147483647" in cxx and "IdempotencyKey" in cxx and "AckRequired" in cxx,
    "boundary": "IsBoundaryShapeAllowed" in cxx and "HashOnly" in cxx and "DefaultNoPublicEgress" in cxx,
    "required evidence roster": all(x in cxx for x in ['u"localcloud-sync-message"_ustr', 'u"evidence-record"_ustr', 'u"audit-log-entry"_ustr', 'u"companion-diff-summary"_ustr', 'u"companion-approval-request"_ustr', 'u"agent-task-state"_ustr']),
    "base evidence": 'ContainsString(rMessage.RequiredEvidence, u"localcloud-sync-message"_ustr)' in cxx and 'ContainsString(rMessage.RequiredEvidence, u"evidence-record"_ustr)' in cxx and 'ContainsString(rMessage.RequiredEvidence, u"audit-log-entry"_ustr)' in cxx,
    "kind evidence": "RequiredEvidenceForKind" in cxx and "companion-diff-summary" in cxx and "companion-approval-request" in cxx and "agent-task-state" in cxx,
    "evidence ids": "rMessage.EvidenceIds.empty()" in cxx and "IsEvidenceIdAllowed(rEvidenceId)" in cxx,
    "tenant refs": "MakeTenantContextRef" in cxx and "tenant-context:" in cxx and "PolicyContextRef" in cxx and "AuditChainRef" in cxx,
    "append api": "AppendMessage" in cxx and "local-cloud-sync-message-appended" in cxx,
    "ack api": "AppendAcknowledgement" in cxx and 'Direction = u"ack"_ustr' in cxx and "invalid-ack-evidence" in cxx,
    "scope target": 'rScope.TargetType != u"companion"_ustr' in cxx and 'rScope.TargetType != u"local-cloud"_ustr' in cxx and 'rScope.Surface != u"companion"_ustr' in cxx and 'rScope.Surface != u"local-cloud"_ustr' in cxx,
    "fail closed": "local-cloud-sync-denied" in cxx and "fail-closed-user-visible=true" in cxx,
    "no service runtime message": "socket-listener-runtime=not-started" in cxx and "cloud-service-runtime=not-started" in cxx and "background-daemon-runtime=not-started" in cxx and "remote-account-sync=not-started" in cxx and "companion-protocol-runtime=not-started" in cxx and "admin-ui-runtime=not-started" in cxx,
    "tenant surfaces": 'rSurface == u"companion"_ustr' in tenant and 'rSurface == u"local-cloud"_ustr' in tenant,
    "tenant target sync": 'rTargetType == u"companion"_ustr' in tenant and 'rTargetType == u"local-cloud"_ustr' in tenant,
    "policy targets": 'rTargetType == u"companion"_ustr' in policy and 'rTargetType == u"local-cloud"_ustr' in policy,
    "schema sync": '"v3-sync-message/0.1"' in sync_schema_text and '"publicEgress"' in sync_schema_text and '"const": false' in sync_schema_text and '"ackRequired"' in sync_schema_text and '"const": true' in sync_schema_text,
    "schema localcloud": '"syncServer"' in localcloud_schema_text and '"port"' in localcloud_schema_text and '"allowPublicEgress"' in localcloud_schema_text,
    "schema policy": '"companion"' in policy_schema_text and '"local-cloud"' in policy_schema_text,
    "w8 spec": "sync-message self-test" in w8_text and "Checks: 8" in w8_text and "17802" in w8_text and "loopback" in w8_text,
    "w4 audit link": "audit-log-entry" in w4_text and "append-only" in w4_text,
    "w7 companion link": "companion" in w7_text.lower() and ("approval" in w7_text.lower() or "审批" in w7_text),
    "sync contract": "Checks: 8" in sync_contract_text and "ackRequired" in sync_contract_text and "publicEgress" in sync_contract_text,
    "no egress contract": "H10 local-cloud no-egress contract" in no_egress_text and "allowPublicEgress" in no_egress_text and "optInCloudEgress" in no_egress_text and "public egress requires explicit opt-in" in no_egress_text,
    "audit runtime regression": "AIChatAuditLogRuntime" in audit_test_text and "audit-log-runtime" in audit_test_text,
    "policy runtime regression": "companion" in policy_test_text and "local-cloud" in policy_test_text,
    "tenant runtime regression": "local-cloud" in tenant_test_text and "companion" in tenant_test_text,
    "in app still umbrellas": "v3-agent-failure-recovery-runtime-test.sh" in in_app_text,
    "todo m6.4 complete": "- [x] M6.4 Implement local cloud sync-message runtime." in todo_text
    and "Follow-up task id: M6.5." in todo_text,
    "todo advanced beyond m6.4": (
        "Active cursor: M6.5 Implement companion approval protocol" in todo_text
        or "Active cursor: M7.1 Build first-run onboarding" in todo_text
        or "Active cursor: M7.2 Ship starter packs" in todo_text
        or "Active cursor: M7.3 Finalize editions and local-first policy" in todo_text
        or "Active cursor: M7.4 Finalize manual docs and i18n" in todo_text
        or "Active cursor: M7.5 Finalize distribution/update/recovery" in todo_text
        or "Active cursor: M7.6 Prove perf and crash recovery targets" in todo_text
        or "Active cursor: M7.7 Release GA checklist" in todo_text
        or "Active cursor: Hardening Backlog M0.3/M0.4" in todo_text
        or "Active cursor: Post-hardening stabilization and broader validation" in todo_text
    )
    and (
        "Completed runtime foundation: M1.1-M6.4." in todo_text
        or "Completed runtime foundation: M1.1-M6.5." in todo_text
        or "Completed runtime foundation: M1.1-M7.1." in todo_text
        or "Completed runtime foundation: M1.1-M7.2." in todo_text
        or "Completed runtime foundation: M1.1-M7.3." in todo_text
        or "Completed runtime foundation: M1.1-M7.4." in todo_text
        or "Completed runtime foundation: M1.1-M7.5." in todo_text
        or "Completed runtime foundation: M1.1-M7.6." in todo_text
        or "Completed runtime foundation: M1.1-M7.7." in todo_text
    ),
    "immediate next slice": (
        ("Start M6.5" in todo_text and "companion approval" in todo_text)
        or ("Start M7.1" in todo_text and "onboarding" in todo_text)
        or ("Start M7.3" in todo_text and "editions/local-first policy" in todo_text)
        or ("Start M7.4" in todo_text and "manual-docs/i18n" in todo_text)
        or ("Start M7.5" in todo_text and "distribution/update/recovery" in todo_text)
        or ("Start M7.6" in todo_text and "perf/crash" in todo_text)
        or ("Start M7.7" in todo_text and "release GA checklist" in todo_text)
        or ("- [x] M7.7 Release GA checklist." in todo_text and "Follow-up task id: Hardening Backlog M0.3/M0.4." in todo_text)
    ),
    "no raw sync payload": "PayloadBody" not in combined and "DocumentPayload" not in combined and "RawSyncBody" not in combined,
    "no raw document": "DocumentText" not in combined and "RawDocumentContent" not in combined and "storesDocumentContent=true" not in combined,
    "no prompt": "RawPrompt" not in combined and "PromptText" not in combined,
    "no connector writeback": "writeback" not in combined.lower() and "WriteScope" not in combined,
    "no background token refresh": "TokenRefresh" not in combined and "RefreshToken" not in combined and "background token" not in combined.lower(),
    "no socket listener": "ServerSocket" not in combined and "listen(" not in combined and "accept(" not in combined and "WebSocket" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no daemon/cloud service": "Supervisor" not in combined and "SyncServer" not in combined and "CloudService" not in combined and "Daemon" not in combined,
    "no companion protocol runtime": "PairingToken" not in combined and "MobileCompanion" not in combined,
    "no sqlite/vector/model": "sqlite" not in combined.lower() and "lancedb" not in combined.lower() and "VectorStore" not in combined and "ModelRuntime" not in combined,
    "no webview": "WebView" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 local cloud sync runtime self-test passed. Checks: {len(checks)}")
PY
