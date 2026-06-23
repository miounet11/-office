#!/usr/bin/env bash
# V3 W4/M6.3 - audit log runtime smoke.

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

runtime_hxx = src / "sfx2/source/sidebar/AIChatAuditLogRuntime.hxx"
runtime_cxx = src / "sfx2/source/sidebar/AIChatAuditLogRuntime.cxx"
policy_hxx = src / "sfx2/source/sidebar/AIChatPolicyEngineRuntime.hxx"
policy_cxx = src / "sfx2/source/sidebar/AIChatPolicyEngineRuntime.cxx"
tenant_hxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.hxx"
tenant_cxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
audit_schema = repo / "docs/schemas/audit-log-entry.schema.json"
evidence_schema = repo / "docs/schemas/evidence-record.schema.json"
policy_schema = repo / "docs/schemas/policy-rule.schema.json"
tenant_schema = repo / "docs/schemas/tenant-context.schema.json"
w4_spec = repo / "docs/product/v3/w4-tenant-policy-audit-spec.md"
w8_spec = repo / "docs/product/v3/w8-local-cloud-spec.md"
audit_entry_test = repo / "tests/v3-audit-log-entry-test.sh"
policy_test = repo / "tests/v3-policy-engine-runtime-test.sh"
tenant_test = repo / "tests/v3-tenant-context-runtime-test.sh"
no_egress_test = repo / "tests/v3-local-cloud-no-egress-test.sh"
in_app_test = repo / "tests/v3-in-app-chat-test.sh"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [
    runtime_hxx,
    runtime_cxx,
    policy_hxx,
    policy_cxx,
    tenant_hxx,
    tenant_cxx,
    library_mk,
    audit_schema,
    evidence_schema,
    policy_schema,
    tenant_schema,
    w4_spec,
    w8_spec,
    audit_entry_test,
    policy_test,
    tenant_test,
    no_egress_test,
    in_app_test,
    todo,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = runtime_hxx.read_text()
cxx = runtime_cxx.read_text()
combined = hxx + cxx
policy = policy_hxx.read_text() + policy_cxx.read_text()
tenant = tenant_hxx.read_text() + tenant_cxx.read_text()
mk = library_mk.read_text()
audit_schema_text = audit_schema.read_text()
evidence_schema_text = evidence_schema.read_text()
policy_schema_text = policy_schema.read_text()
tenant_schema_text = tenant_schema.read_text()
w4_text = w4_spec.read_text()
w8_text = w8_spec.read_text()
audit_entry_text = audit_entry_test.read_text()
policy_test_text = policy_test.read_text()
tenant_test_text = tenant_test.read_text()
no_egress_text = no_egress_test.read_text()
in_app_text = in_app_test.read_text()
todo_text = todo.read_text()


def strip_leading_block_comments(text: str) -> str:
    body = text.lstrip()
    while body.startswith("/*") and "*/" in body:
        body = body.split("*/", 1)[1].lstrip()
    return body


cxx_body = strip_leading_block_comments(cxx)

entry_fields = [
    "AuditId",
    "SchemaVersion",
    "Timestamp",
    "TenantId",
    "WorkspaceId",
    "ActorId",
    "ActorRole",
    "ActionType",
    "TargetRef",
    "ServiceMode",
    "DataClass",
    "PublicEgress",
    "EvidenceId",
    "PolicyDecision",
    "ApprovalChain",
    "StoresDocumentContent",
    "PromptStorage",
    "HashAlgorithm",
    "PreviousHash",
    "EntryHash",
    "PolicyContextRef",
    "AuditChainRef",
    "HashReference",
]
approval_fields = ["ApproverId", "Decision", "Timestamp", "EvidenceId"]
result_fields = ["Success", "Entry", "Message"]
apis = [
    "AppendPolicyDecision",
    "ValidateHashChain",
    "LoadEntries",
    "IsAuditIdAllowed",
    "IsTimestampAllowed",
    "IsActionTypeAllowed",
    "IsPolicyDecisionAllowed",
    "IsApprovalDecisionAllowed",
    "IsPromptStorageAllowed",
    "IsChainHashAllowed",
    "IsEntryShapeAllowed",
    "NormalizeActionType",
    "NormalizePolicyDecision",
    "MakeAuditId",
    "MakeEntryHash",
]

checks = {
    "runtime class": "class AIChatAuditLogRuntime final" in hxx,
    "approval struct": "struct AIChatAuditApprovalEntry" in hxx and all(field in hxx for field in approval_fields),
    "entry struct": "struct AIChatAuditLogEntry" in hxx and all(field in hxx for field in entry_fields),
    "result struct": "struct AIChatAuditLogResult" in hxx and all(field in hxx for field in result_fields),
    "public api": all(api in hxx + cxx for api in apis),
    "compiled": "sfx2/source/sidebar/AIChatAuditLogRuntime" in mk,
    "uses policy runtime": '#include "AIChatPolicyEngineRuntime.hxx"' in hxx and "AIChatPolicyDecision" in hxx,
    "uses tenant runtime": "AIChatTenantContextRuntime" in cxx and "IsContextShapeAllowed" in cxx,
    "uses metadata hash": '#include "AIChatKnowledgeIndexStore.hxx"' in cxx and "AIChatKnowledgeIndexStore::MakeMetadataHash" in cxx,
    "storage sidecar": "kqoffice-v3-ai-audit-log" in cxx and "audit.tsv" in cxx,
    "append only write": "AppendUtf8Line" in cxx and "setPos(osl_Pos_Absolut, nSize)" in cxx,
    "size guard": "MAX_AUDIT_LOG_BYTES" in cxx and "2 * 1024 * 1024" in cxx,
    "tsv escape": "EscapeField" in cxx and "UnescapeField" in cxx and "ParseAuditLine" in cxx,
    "field count": "aFields.size() != 23" in cxx,
    "approval safe separators": "APPROVAL_FIELD_SEPARATOR = u'~'" in cxx and "APPROVAL_ENTRY_SEPARATOR = u','" in cxx,
    "approval decode": "DecodeApprovals" in cxx and "IsApprovalDecisionAllowed" in cxx,
    "schema version": 'v3-audit-log-entry/0.1' in cxx and 'rEntry.SchemaVersion != u"v3-audit-log-entry/0.1"_ustr' in cxx,
    "audit id": "IsAuditIdAllowed" in cxx and 'rAuditId.startsWith(u"aud-"_ustr)' in cxx and "MakeAuditId" in cxx,
    "timestamp shape": "IsTimestampAllowed" in cxx and "rTimestamp[10] == u'T'" in cxx and "rTimestamp[19] == u'Z'" in cxx,
    "evidence id guard": "IsEvidenceIdAllowed(rEntry.EvidenceId)" in cxx and "IsEvidenceIdAllowed(rDecision.EvidenceId)" in cxx,
    "hash reference guard": "IsHashReferenceAllowed(rEntry.HashReference)" in cxx and "IsHashReferenceAllowed(rDecision.HashReference)" in cxx,
    "sha256": 'rEntry.HashAlgorithm != u"sha256"_ustr' in cxx and 'u"sha256:"_ustr' in tenant + policy,
    "genesis": 'rHash == u"GENESIS"_ustr' in cxx and 'u"GENESIS"_ustr' in cxx,
    "entry hash": "MakeEntryHash" in cxx and "EntryHash = MakeEntryHash" in cxx,
    "chain validation": "ValidateHashChain" in cxx and "rEntry.PreviousHash != sPreviousHash" in cxx and "rEntry.EntryHash != MakeEntryHash(rEntry)" in cxx,
    "tamper fail closed": "tampered-or-invalid-entry" in cxx and "fail-closed-user-visible=true" in cxx,
    "bad raw line fails": "if (!ParseAuditLine(sLine, aEntry))" in cxx and "audit-log-chain-failed reason=tampered-or-invalid-entry" in cxx,
    "existing chain guard": "existing-chain-invalid" in cxx and "ValidateHashChain()" in cxx,
    "action roster": all(x in cxx for x in ['u"chat"_ustr', 'u"patch-apply"_ustr', 'u"connector-fetch"_ustr', 'u"kb-query"_ustr', 'u"agent-step"_ustr']),
    "action normalization": "NormalizeActionType" in cxx and 'rTargetType == u"connector"_ustr' in cxx and 'return u"connector-fetch"_ustr' in cxx and 'rTargetType == u"knowledge-index"_ustr' in cxx and 'return u"kb-query"_ustr' in cxx,
    "provider companion normalization": 'rTargetType == u"provider"_ustr' in cxx and 'rTargetType == u"companion"_ustr' in cxx and 'return u"chat"_ustr' in cxx,
    "policy decisions": all(x in cxx for x in ['u"allow"_ustr', 'u"deny"_ustr', 'u"require-approval"_ustr']),
    "require evidence normalization": "NormalizePolicyDecision" in cxx and 'rDecision == u"require-evidence"_ustr' in cxx and 'return u"allow"_ustr' in cxx,
    "approval required has chain": 'rEntry.PolicyDecision == u"require-approval"_ustr' in cxx and "rEntry.ApprovalChain.empty()" in cxx,
    "prompt storage": "IsPromptStorageAllowed" in cxx and 'u"none"_ustr' in cxx and 'u"hash-only"_ustr' in cxx,
    "connector prompt none": 'rScope.TargetType == u"connector"_ustr ? u"none"_ustr : u"hash-only"_ustr' in cxx,
    "no public egress": "PublicEgress = false" in cxx and "rEntry.PublicEgress" in cxx and "public-egress=false" in cxx,
    "no document content": "StoresDocumentContent = false" in cxx and "rEntry.StoresDocumentContent" in cxx and "storesDocumentContent=false" in cxx,
    "policy refs": "PolicyContextRef" in cxx and 'startsWith(u"policy-context:"_ustr)' in cxx,
    "audit refs": "AuditChainRef" in cxx and 'startsWith(u"audit-chain:"_ustr)' in cxx,
    "success message": "audit-log-entry-appended" in cxx and "append-only=true" in cxx and "hash-chain=true" in cxx and "evidence-linked=true" in cxx,
    "boundary messages": "schema-collapse=false" in cxx and "metadata-only=true" in cxx and "local-audit-sink-runtime=not-started" in cxx and "gdpr-delete-runtime=not-started" in cxx and "admin-ui-runtime=not-started" in cxx,
    "invalid append fail": "invalid-policy-decision-or-context" in cxx and "evidence-required=true" in cxx,
    "invalid entry fail": "invalid-audit-entry-shape" in cxx and "ev-shape-required=true" in cxx,
    "policy emits audit refs": "AuditChainRef" in policy and "PolicyContextRef" in policy and "auditLogRequired=true" in policy,
    "tenant emits refs": "MakePolicyContextRef" in tenant and "MakeAuditChainRef" in tenant and "audit-chain:" in tenant,
    "audit schema": '"v3-audit-log-entry/0.1"' in audit_schema_text and '"evidenceId"' in audit_schema_text and '"previousHash"' in audit_schema_text and '"entryHash"' in audit_schema_text,
    "audit schema metadata": '"storesDocumentContent"' in audit_schema_text and '"const": false' in audit_schema_text and '"hash-only"' in audit_schema_text,
    "evidence schema exists": "evidence-record.schema.json" in evidence_schema_text and '"id"' in evidence_schema_text and '"stores_document_content"' in evidence_schema_text and '"const": false' in evidence_schema_text,
    "policy schema audit requirements": '"auditLogRequired"' in policy_schema_text and '"evidenceRecordRequired"' in policy_schema_text,
    "tenant schema audit": '"appendOnly"' in tenant_schema_text and '"hashChainRequired"' in tenant_schema_text and '"sinkPort"' in tenant_schema_text,
    "w4 spec audit": "本地 append-only file" in w4_text and "audit-log-entry self-test" in w4_text and "不同表同链" in w4_text,
    "w8 no egress": "loopback" in w8_text and "private" in w8_text,
    "contract audit test": "Checks: 7" in audit_entry_text and "append-only" in audit_entry_text and "hash-chain" in audit_entry_text,
    "policy runtime dependency test": "AIChatPolicyEngineRuntime" in policy_test_text and "audit-log-runtime=not-started" in policy_test_text,
    "tenant runtime dependency test": "AIChatTenantContextRuntime" in tenant_test_text and "audit-log-runtime=not-started" in tenant_test_text,
    "no egress test": "allowPublicEgress=false" in no_egress_text and "optInCloudEgress=false" in no_egress_text,
    "in app includes m6 chain": "v3-policy-engine-runtime-test.sh" in in_app_text or "v3-agent-failure-recovery-runtime-test.sh" in in_app_text,
    "todo m6.3 complete": "- [x] M6.3 Implement audit log runtime." in todo_text
    and "Follow-up task id: M6.4." in todo_text,
    "todo advanced beyond m6.3": (
        "Active cursor: M6.4 Implement local cloud sync-message runtime" in todo_text
        or "Active cursor: M6.5 Implement companion approval protocol" in todo_text
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
        "Completed runtime foundation: M1.1-M6.3." in todo_text
        or "Completed runtime foundation: M1.1-M6.4." in todo_text
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
        ("Start M6.4" in todo_text and "loopback/private LAN" in todo_text)
        or ("Start M6.5" in todo_text and "companion approval" in todo_text)
        or ("Start M7.1" in todo_text and "onboarding" in todo_text)
        or ("Start M7.3" in todo_text and "editions/local-first policy" in todo_text)
        or ("Start M7.4" in todo_text and "manual-docs/i18n" in todo_text)
        or ("Start M7.5" in todo_text and "distribution/update/recovery" in todo_text)
        or ("Start M7.6" in todo_text and "perf/crash" in todo_text)
        or ("Start M7.7" in todo_text and "release GA checklist" in todo_text)
        or ("- [x] M7.7 Release GA checklist." in todo_text and "Follow-up task id: Hardening Backlog M0.3/M0.4." in todo_text)
    )
    and ("tests/v3-sync-message-test.sh" in todo_text or "tests/v3-edition-policy-runtime-test.sh" in todo_text),
    "no raw audit payload": "RawAudit" not in combined and "AuditPayload" not in combined and "AuditBody" not in combined,
    "no raw evidence": "RawEvidence" not in combined and "EvidencePayload" not in combined and "EvidenceBody" not in combined,
    "no raw policy payload": "RawPolicy" not in combined and "PolicyPayload" not in combined and "RulePayload" not in combined,
    "no raw prompt": "RawPrompt" not in combined and "PromptBody" not in combined and "PromptText" not in combined,
    "no raw document": "DocumentText" not in combined and "RawDocumentContent" not in combined and "storesDocumentContent=true" not in combined,
    "no connector payload": "ConnectorPayload" not in combined and "ConnectorBody" not in combined,
    "no retrieval payload": "RetrievalPayload" not in combined and "SnippetText" not in combined,
    "no audit sink runtime": "AuditSinkRuntime" not in combined and "ServerSocket" not in combined and "listen(" not in combined,
    "no gdpr delete runtime": "GdprDelete" not in combined and "EraseAudit" not in combined and "DeleteAudit" not in combined,
    "no admin ui runtime": "AdminPanel" not in combined and "AdminConsole" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no webview": "WebView" not in combined,
    "no sqlite runtime": "sqlite" not in combined.lower() and "lancedb" not in combined.lower(),
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 audit log runtime self-test passed. Checks: {len(checks)}")
PY
