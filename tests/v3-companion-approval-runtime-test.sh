#!/usr/bin/env bash
# V3 W7/M6.5 - companion approval runtime smoke.

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

runtime_hxx = src / "sfx2/source/sidebar/AIChatCompanionApprovalRuntime.hxx"
runtime_cxx = src / "sfx2/source/sidebar/AIChatCompanionApprovalRuntime.cxx"
sync_hxx = src / "sfx2/source/sidebar/AIChatLocalCloudSyncRuntime.hxx"
sync_cxx = src / "sfx2/source/sidebar/AIChatLocalCloudSyncRuntime.cxx"
tenant_cxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.cxx"
audit_cxx = src / "sfx2/source/sidebar/AIChatAuditLogRuntime.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
pairing_schema = repo / "docs/schemas/companion-pairing-token.schema.json"
summary_schema = repo / "docs/schemas/companion-diff-summary.schema.json"
approval_schema = repo / "docs/schemas/companion-approval-request.schema.json"
sync_schema = repo / "docs/schemas/sync-message.schema.json"
w7_spec = repo / "docs/product/v3/w7-companion-spec.md"
w8_spec = repo / "docs/product/v3/w8-local-cloud-spec.md"
companion_contract = repo / "tests/v3-companion-contract-test.sh"
sync_runtime_test = repo / "tests/v3-local-cloud-sync-runtime-test.sh"
sync_contract = repo / "tests/v3-sync-message-test.sh"
audit_test = repo / "tests/v3-audit-log-runtime-test.sh"
policy_test = repo / "tests/v3-policy-engine-runtime-test.sh"
tenant_test = repo / "tests/v3-tenant-context-runtime-test.sh"
in_app = repo / "tests/v3-in-app-chat-test.sh"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [
    runtime_hxx,
    runtime_cxx,
    sync_hxx,
    sync_cxx,
    tenant_cxx,
    audit_cxx,
    library_mk,
    pairing_schema,
    summary_schema,
    approval_schema,
    sync_schema,
    w7_spec,
    w8_spec,
    companion_contract,
    sync_runtime_test,
    sync_contract,
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
sync = sync_hxx.read_text() + sync_cxx.read_text()
tenant = tenant_cxx.read_text()
audit = audit_cxx.read_text()
mk = library_mk.read_text()
pairing_schema_text = pairing_schema.read_text()
summary_schema_text = summary_schema.read_text()
approval_schema_text = approval_schema.read_text()
sync_schema_text = sync_schema.read_text()
w7_text = w7_spec.read_text()
w8_text = w8_spec.read_text()
companion_contract_text = companion_contract.read_text()
sync_runtime_text = sync_runtime_test.read_text()
sync_contract_text = sync_contract.read_text()
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

pairing_fields = [
    "PairingId", "SchemaVersion", "CreatedAt", "ExpiresAt", "TenantId", "WorkspaceId",
    "DesktopInstanceId", "DesktopApp", "LanEndpointHash", "ProposedDeviceId",
    "DevicePlatform", "BindingRequired", "TransportMode", "Port", "PublicEgress",
    "CloudPushOptIn", "MdnsRequired", "TtlSeconds", "SessionTtlHours", "TokenHash",
    "StoresSecret", "PinConfirmationRequired", "BiometricEnrollmentRequired",
    "MTLSRequired", "Revocable", "DataBoundary", "RequiredEvidence", "EvidenceIds",
    "AuditLogRef", "TenantContextRef", "SyncMessageRef",
]
summary_fields = [
    "SummaryId", "TaskId", "StepResultId", "Surface", "SummaryKind", "ApplyPlanRef",
    "ActionKind", "ActionCount", "PreviewHash", "HumanSummaryHash", "StoresDocumentContent",
    "MobileParsesApplyPlan", "RiskLevel", "RequiresApproval", "SnippetStorage",
    "ContainsOriginalText", "CacheMode", "ViewOnly", "CanEdit", "OfflineApproval",
    "ChangedObjectRefs",
]
request_fields = [
    "RequestId", "TaskId", "SummaryId", "PairingId", "ActorId", "ActorRole", "Channel",
    "RequestState", "AvailableActions", "RequiresOnline", "TransportMode",
    "LocalGatewayPort", "PublicEgress", "CloudPushOptIn", "BiometricRequired",
    "SecondConfirmRequired", "MobileMayEdit", "DecisionWritesAudit", "AuditLogRequired",
    "AuditEvidenceRequired", "ReviewItemRef",
]
decision_fields = [
    "DecisionId", "RequestId", "SummaryId", "PairingId", "CreatedAt", "ActorId",
    "Decision", "EvidenceId", "HashReference", "AuditLogRef", "SyncMessageRef",
    "AppliesDocumentChange", "MobileMayEdit", "BiometricConfirmed",
    "SecondConfirmCompleted",
]
apis = [
    "PublishPairingToken",
    "PublishDiffSummary",
    "PublishApprovalRequest",
    "RecordApprovalDecision",
    "IsCompanionIdAllowed",
    "IsTimestampAllowed",
    "IsDesktopAppAllowed",
    "IsDevicePlatformAllowed",
    "IsPairingTransportAllowed",
    "IsApprovalTransportAllowed",
    "IsSurfaceAllowed",
    "IsSummaryKindAllowed",
    "IsActionKindAllowedForSurface",
    "IsRiskLevelAllowed",
    "IsSnippetStorageAllowed",
    "IsRequestStateAllowed",
    "IsApprovalActionAllowed",
    "IsDecisionAllowed",
    "IsRequiredEvidenceAllowed",
    "IsDataBoundaryAllowed",
    "IsPairingTokenShapeAllowed",
    "IsDiffSummaryShapeAllowed",
    "IsApprovalRequestShapeAllowed",
    "IsApprovalDecisionShapeAllowed",
    "MakePairingId",
    "MakeSummaryId",
    "MakeRequestId",
    "MakeDecisionId",
]

checks = {
    "runtime class": "class AIChatCompanionApprovalRuntime final" in hxx,
    "data boundary": "struct AIChatCompanionDataBoundary" in hxx and "StoresDocumentContent" in hxx and "StoresDiffSummaryOnly" in hxx and "AllowApprovalOffline" in hxx,
    "pairing struct": "struct AIChatCompanionPairingToken" in hxx and all(field in hxx for field in pairing_fields),
    "summary struct": "struct AIChatCompanionDiffSummary" in hxx and all(field in hxx for field in summary_fields),
    "request struct": "struct AIChatCompanionApprovalRequest" in hxx and all(field in hxx for field in request_fields),
    "decision struct": "struct AIChatCompanionApprovalDecision" in hxx and all(field in hxx for field in decision_fields),
    "result struct": "struct AIChatCompanionApprovalResult" in hxx and "ObjectId" in hxx and "Message" in hxx,
    "public api": all(api in hxx + cxx for api in apis),
    "compiled": "sfx2/source/sidebar/AIChatCompanionApprovalRuntime" in mk,
    "uses sync": '#include "AIChatLocalCloudSyncRuntime.hxx"' in hxx and "sync-message:" in cxx,
    "uses tenant": "AIChatTenantContextRuntime" in cxx and "ValidateActionScope" in cxx,
    "uses audit refs": "audit-log-entry:" in cxx and "AuditLogRef" in hxx + cxx,
    "uses hash": "AIChatKnowledgeIndexStore::MakeMetadataHash" in cxx,
    "storage sidecar": "kqoffice-v3-ai-companion-approval" in cxx and "companion-approval.tsv" in cxx,
    "append only": "AppendUtf8Line" in cxx and "setPos(osl_Pos_Absolut, nSize)" in cxx,
    "store records": "pairing-token" in cxx and "diff-summary" in cxx and "approval-request" in cxx and "approval-decision" in cxx,
    "schema versions": "v3-companion-pairing-token/0.1" in cxx and "v3-companion-diff-summary/0.1" in cxx and "v3-companion-approval-request/0.1" in cxx,
    "id guards": 'u"cpt"_ustr' in cxx and 'u"cds"_ustr' in cxx and 'u"car"_ustr' in cxx and 'u"cad"_ustr' in cxx,
    "timestamp": "AIChatAuditLogRuntime::IsTimestampAllowed" in cxx,
    "desktop apps": all(x in cxx for x in ['u"writer"_ustr', 'u"calc"_ustr', 'u"impress"_ustr', 'u"start-center"_ustr']),
    "platforms": all(x in cxx for x in ['u"ios"_ustr', 'u"android"_ustr', 'u"pwa"_ustr']),
    "pairing transports": 'u"lan-grpc"_ustr' in cxx and 'u"enterprise-https"_ustr' in cxx,
    "approval transports": 'u"lan-push"_ustr' in cxx and 'u"enterprise-push"_ustr' in cxx,
    "push port": "W8_PUSH_GATEWAY_PORT = 17801" in cxx and "LocalGatewayPort != W8_PUSH_GATEWAY_PORT" in cxx,
    "cloud opt in": "PublicEgress && !rToken.CloudPushOptIn" in cxx and "PublicEgress && !rRequest.CloudPushOptIn" in cxx,
    "lan no egress": 'rToken.TransportMode == u"lan-grpc"_ustr' in cxx and 'rRequest.TransportMode == u"lan-push"_ustr' in cxx,
    "ttl": "TtlSeconds < 60" in cxx and "TtlSeconds > 600" in cxx and "SessionTtlHours != 24" in cxx,
    "security": "PinConfirmationRequired" in cxx and "BiometricEnrollmentRequired" in cxx and "MTLSRequired" in cxx and "Revocable" in cxx,
    "summary surfaces": "IsSurfaceAllowed" in cxx and "IsSummaryKindAllowed" in cxx and "IsActionKindAllowedForSurface" in cxx,
    "action kinds": "ParagraphAction" in cxx and "CellAction" in cxx and "SlideElementAction" in cxx,
    "diff redaction": "PreviewHash" in cxx and "HumanSummaryHash" in cxx and "MobileParsesApplyPlan" in cxx and "ContainsOriginalText" in cxx,
    "mobile readonly": "ViewOnly" in cxx and "CanEdit" in cxx and "OfflineApproval" in cxx,
    "approval request": "RequiresOnline" in cxx and "BiometricRequired" in cxx and "SecondConfirmRequired" in cxx and "DecisionWritesAudit" in cxx,
    "approval actions": "approve" in cxx and "reject" in cxx and "rollback" in cxx,
    "decision actions": "approved" in cxx and "rejected" in cxx and "rollback-requested" in cxx,
    "decision no apply": "AppliesDocumentChange" in cxx and "!rDecision.AppliesDocumentChange" in cxx,
    "evidence roster": all(x in cxx for x in ["companion-pairing-token", "user-pin-confirmation", "device-binding", "companion-diff-summary", "shadow-doc-diff", "apply-plan-runtime-validated", "companion-approval-request", "user-approval", "biometric-confirmation", "audit-log-entry", "evidence-record"]),
    "base refs": "HasBaseRefs" in cxx and "tenant-context:" in cxx and "sync-message:" in cxx,
    "review item": "ReviewItemRef" in cxx and 'startsWith(u"review:"_ustr)' in cxx,
    "fail closed": "companion-approval-denied reason=" in cxx and "fail-closed-user-visible=true" in cxx,
    "messages": "companion-pairing-token-published" in cxx and "companion-diff-summary-published" in cxx and "companion-approval-request-published" in cxx and "companion-approval-decision-recorded" in cxx,
    "no service messages": "companion-server-runtime=not-started" in cxx and "pairing-listener-runtime=not-started" in cxx and "push-gateway-runtime=not-started" in cxx and "apns-fcm-bridge=not-started" in cxx and "remote-transport-runtime=not-started" in cxx,
    "sync runtime": "AIChatLocalCloudSyncRuntime" in sync and "local-cloud-sync-message-appended" in sync,
    "tenant companion": 'rTargetType == u"companion"_ustr' in tenant and 'rSurface == u"companion"_ustr' in tenant,
    "audit runtime": "AIChatAuditLogRuntime" in audit and "audit-log-entry-appended" in audit,
    "pairing schema": '"v3-companion-pairing-token/0.1"' in pairing_schema_text and '"ttlSeconds"' in pairing_schema_text and '"maximum": 600' in pairing_schema_text,
    "summary schema": '"v3-companion-diff-summary/0.1"' in summary_schema_text and '"mobileParsesApplyPlan"' in summary_schema_text and '"canEdit"' in summary_schema_text,
    "approval schema": '"v3-companion-approval-request/0.1"' in approval_schema_text and '"biometricRequired"' in approval_schema_text and '"allowApprovalOffline"' in approval_schema_text,
    "sync schema": '"approval-decision-sync"' in sync_schema_text and '"companion-approval-request"' in sync_schema_text,
    "w7 spec": "companion-contract self-test" in w7_text and "Checks: 9" in w7_text and "不做编辑" in w7_text,
    "w8 spec": "17801" in w8_text and "push gateway" in w8_text.lower(),
    "companion contract": "Checks: 9" in companion_contract_text and "biometricRequired" in companion_contract_text and "allowApprovalOffline" in companion_contract_text,
    "sync runtime test": "v3-local-cloud-sync-runtime-test.sh" in todo_text and "AIChatLocalCloudSyncRuntime" in sync_runtime_text,
    "sync contract test": "Checks: 8" in sync_contract_text,
    "audit regression": "AIChatAuditLogRuntime" in audit_test_text,
    "policy regression": "companion" in policy_test_text,
    "tenant regression": "companion" in tenant_test_text,
    "in app umbrella": "v3-agent-failure-recovery-runtime-test.sh" in in_app_text,
    "todo m6.5 complete": "- [x] M6.5 Implement companion approval protocol." in todo_text
    and "Follow-up task id: M7.1." in todo_text,
    "todo advanced beyond m6.5": (
        "Active cursor: M7.1 Build first-run onboarding" in todo_text
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
        "Completed runtime foundation: M1.1-M6.5." in todo_text
        or "Completed runtime foundation: M1.1-M7.1." in todo_text
        or "Completed runtime foundation: M1.1-M7.2." in todo_text
        or "Completed runtime foundation: M1.1-M7.3." in todo_text
        or "Completed runtime foundation: M1.1-M7.4." in todo_text
        or "Completed runtime foundation: M1.1-M7.5." in todo_text
        or "Completed runtime foundation: M1.1-M7.6." in todo_text
        or "Completed runtime foundation: M1.1-M7.7." in todo_text
    ),
    "immediate next slice": (
        ("Start M7.1" in todo_text and "onboarding" in todo_text)
        or ("Start M7.2" in todo_text and "starter-pack" in todo_text)
        or ("Start M7.3" in todo_text and "editions/local-first policy" in todo_text)
        or ("Start M7.4" in todo_text and "manual-docs/i18n" in todo_text)
        or ("Start M7.5" in todo_text and "distribution/update/recovery" in todo_text)
        or ("Start M7.6" in todo_text and "perf/crash" in todo_text)
        or ("Start M7.7" in todo_text and "release GA checklist" in todo_text)
        or ("- [x] M7.7 Release GA checklist." in todo_text and "Follow-up task id: Hardening Backlog M0.3/M0.4." in todo_text)
    ),
    "no raw document": "DocumentText" not in combined and "RawDocumentContent" not in combined and "storesDocumentContent=true" not in combined,
    "no raw companion body": "RawDiff" not in combined and "RawApproval" not in combined and "ApprovalBody" not in combined and "PairingSecret" not in combined,
    "no mobile edit path": "mobileMayEdit=true" not in combined and "CanEdit = true" not in combined and "MobileEdit" not in combined,
    "no apply execution": "ApplyPlan(" not in combined and "ExecuteList" not in combined and "applyDiagnosticsPlan" not in combined,
    "no provider ai": "Provider" not in combined and "XProvider" not in combined and "AIChatPanel" not in combined,
    "no socket listener": "ServerSocket" not in combined and "listen(" not in combined and "accept(" not in combined and "WebSocket" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no push bridge runtime": "PushDispatcher" not in combined and "APNS" not in combined and "FCM" not in combined,
    "no standalone app": "CompanionAppRuntime" not in combined and "PwaRuntime" not in combined and "AndroidRuntime" not in combined,
    "no sqlite/vector/model": "sqlite" not in combined.lower() and "lancedb" not in combined.lower() and "VectorStore" not in combined and "ModelRuntime" not in combined,
    "no webview": "WebView" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 companion approval runtime self-test passed. Checks: {len(checks)}")
PY
