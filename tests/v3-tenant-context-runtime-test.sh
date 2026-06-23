#!/usr/bin/env bash
# V3 W4/M6.1 - tenant context runtime smoke.

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

runtime_hxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.hxx"
runtime_cxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
tenant_schema = repo / "docs/schemas/tenant-context.schema.json"
policy_schema = repo / "docs/schemas/policy-rule.schema.json"
w4_spec = repo / "docs/product/v3/w4-tenant-policy-audit-spec.md"
w8_spec = repo / "docs/product/v3/w8-local-cloud-spec.md"
policy_test = repo / "tests/v3-policy-tenant-test.sh"
no_egress_test = repo / "tests/v3-local-cloud-no-egress-test.sh"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [
    runtime_hxx,
    runtime_cxx,
    library_mk,
    tenant_schema,
    policy_schema,
    w4_spec,
    w8_spec,
    policy_test,
    no_egress_test,
    todo,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = runtime_hxx.read_text()
cxx = runtime_cxx.read_text()
combined = hxx + cxx
mk = library_mk.read_text()
tenant_schema_text = tenant_schema.read_text()
policy_schema_text = policy_schema.read_text()
w4_text = w4_spec.read_text()
w8_text = w8_spec.read_text()
policy_test_text = policy_test.read_text()
no_egress_text = no_egress_test.read_text()
todo_text = todo.read_text()


def strip_leading_block_comments(text: str) -> str:
    body = text.lstrip()
    while body.startswith("/*") and "*/" in body:
        body = body.split("*/", 1)[1].lstrip()
    return body


cxx_body = strip_leading_block_comments(cxx)

context_fields = [
    "ContextId",
    "SchemaVersion",
    "CreatedAt",
    "TenantId",
    "TenantNameHash",
    "TenantPlan",
    "WorkspaceId",
    "WorkspaceNameHash",
    "WorkspaceDataClasses",
    "Users",
    "DefaultServiceMode",
    "AllowedServiceModes",
    "PublicEgressDefault",
    "TenantIsolation",
    "LocalOnlyAdminPanel",
    "AuditAppendOnly",
    "AuditHashChainRequired",
    "AuditSink",
    "AuditSinkPort",
    "DocumentBinding",
    "DocumentHashReference",
]

scope_fields = [
    "TenantId",
    "WorkspaceId",
    "UserId",
    "UserRole",
    "DocumentBinding",
    "DocumentHashReference",
    "TargetType",
    "DataClass",
    "ServiceMode",
    "Surface",
    "EvidenceId",
    "HashReference",
]

checks = {
    "runtime class": "class AIChatTenantContextRuntime final" in hxx,
    "context struct": "struct AIChatTenantContext" in hxx and all(field in hxx for field in context_fields),
    "scope struct": "struct AIChatTenantActionScope" in hxx and all(field in hxx for field in scope_fields),
    "result struct": "struct AIChatTenantContextResult" in hxx and "PolicyContextRef" in hxx and "AuditChainRef" in hxx,
    "compiled": "sfx2/source/sidebar/AIChatTenantContextRuntime" in mk,
    "storage sidecar": "kqoffice-v3-ai-tenant-context" in cxx and "contexts.tsv" in cxx,
    "save api": "SaveContext" in hxx + cxx,
    "load api": "LoadContext" in hxx + cxx,
    "scope api": "ValidateActionScope" in hxx + cxx,
    "schema version": 'rContext.SchemaVersion != u"v3-tenant-context/0.1"_ustr' in cxx,
    "context id": "IsContextIdAllowed" in cxx and 'rContextId.startsWith(u"tctx-"_ustr)' in cxx,
    "tenant slug": "IsTenantIdAllowed" in cxx and "IsSlug(rTenantId, 3, 64)" in cxx,
    "workspace slug": "IsWorkspaceIdAllowed" in cxx and "IsSlug(rWorkspaceId, 3, 64)" in cxx,
    "user role": "IsUserRoleAllowed" in cxx and 'u"admin"_ustr' in cxx and 'u"service"_ustr' in cxx,
    "tenant plan": "IsTenantPlanAllowed" in cxx and 'u"enterprise"_ustr' in cxx,
    "data classes": "IsDataClassAllowed" in cxx and all(x in cxx for x in ['u"public"_ustr', 'u"internal"_ustr', 'u"confidential"_ustr', 'u"secret"_ustr']),
    "service modes": "IsServiceModeAllowed" in cxx and 'u"offline"_ustr' in cxx and 'u"private"_ustr' in cxx and 'u"cloud"_ustr' not in cxx_body,
    "egress guard": "PublicEgressDefault" in cxx and "rContext.PublicEgressDefault" in cxx and "publicEgressDefault=false" in cxx,
    "isolation guard": "TenantIsolation" in cxx and "tenantIsolation=true" in cxx,
    "admin local": "LocalOnlyAdminPanel" in cxx and "localOnlyAdminPanel=true" in cxx,
    "audit boundary": "AuditAppendOnly" in cxx and "AuditHashChainRequired" in cxx and "AuditSinkPort != 17803" in cxx,
    "audit sink local": "IsAuditSinkAllowed" in cxx and 'u"local-file"_ustr' in cxx and 'u"local-sink-server"_ustr' in cxx,
    "document binding guard": "IsDocumentBindingAllowed" in cxx and 'rDocumentBinding.startsWith(u"doc-"_ustr)' in cxx,
    "document hash guard": "IsDocumentHashReferenceAllowed" in cxx and 'rDocumentHashReference.startsWith(u"sha256:"_ustr)' in cxx,
    "target roster": "IsTargetTypeAllowed" in cxx and all(x in cxx for x in ['u"chat"_ustr', 'u"provider"_ustr', 'u"connector"_ustr', 'u"knowledge-index"_ustr', 'u"agent-step"_ustr', 'u"patch-apply"_ustr', 'u"audit"_ustr', 'u"companion"_ustr', 'u"local-cloud"_ustr', 'u"starter-pack"_ustr', 'u"edition-policy"_ustr', 'u"i18n-manual"_ustr', 'u"distribution-update"_ustr', 'u"error-recovery-ux"_ustr', 'u"perf-baseline"_ustr', 'u"crash-recovery"_ustr', 'u"release-ga-checklist"_ustr']),
    "surface roster": "IsSurfaceAllowed" in cxx and all(x in cxx for x in ['u"chat"_ustr', 'u"provider"_ustr', 'u"connector"_ustr', 'u"knowledge-index"_ustr', 'u"agent"_ustr', 'u"apply-plan"_ustr', 'u"diff-review"_ustr', 'u"audit"_ustr', 'u"companion"_ustr', 'u"local-cloud"_ustr', 'u"starter-pack"_ustr', 'u"edition-policy"_ustr', 'u"i18n-manual"_ustr', 'u"distribution-update"_ustr', 'u"error-recovery-ux"_ustr', 'u"perf-baseline"_ustr', 'u"crash-recovery"_ustr', 'u"release-ga-checklist"_ustr']),
    "evidence hash guards": "IsEvidenceIdAllowed" in cxx and "IsHashReferenceAllowed" in cxx,
    "shape guard": "IsContextShapeAllowed" in cxx and "ContainsDuplicateString" in cxx,
    "refs": "MakePolicyContextRef" in cxx and "policy-context:" in cxx and "MakeAuditChainRef" in cxx and "audit-chain:" in cxx,
    "tenant evidence": "MakeTenantEvidenceId" in cxx and 'u"ev-"_ustr' in cxx,
    "tenant hash": "MakeTenantHashReference" in cxx and "AIChatKnowledgeIndexStore::MakeMetadataHash" in cxx,
    "metadata write": "AppendUtf8Line" in cxx and "EscapeField" in cxx and "UnescapeField" in cxx,
    "metadata message": "metadata-only=true" in cxx and "raw-prompt=false" in cxx and "raw-document=false" in cxx,
    "policy not started": "policy-engine-runtime=not-started" in cxx,
    "audit not started": "audit-log-runtime=not-started" in cxx and "audit-sink-runtime=not-started" in cxx,
    "tenant mismatch denied": "tenant-or-workspace-mismatch" in cxx and "fail-closed-user-visible=true" in cxx,
    "document mismatch denied": "document-binding-mismatch" in cxx and "cross-document-restore=false" in cxx,
    "user denied": "user-not-active-or-role-mismatch" in cxx,
    "data class denied": "data-class-outside-workspace" in cxx,
    "service mode denied": "service-mode-outside-tenant-boundary" in cxx and "no-public-egress=true" in cxx,
    "missing evidence denied": "missing-evidence-or-hash" in cxx and "evidenceRecordRequired=true" in cxx,
    "allowed message": "tenant-scope-allowed" in cxx and "policy-preflight=true" in cxx and "post-evidence-required=true" in cxx,
    "schema locks public egress": '"publicEgressDefault"' in tenant_schema_text and '"const": false' in tenant_schema_text,
    "schema locks local admin": '"localOnlyAdminPanel"' in tenant_schema_text and '"const": true' in tenant_schema_text,
    "schema locks audit": '"appendOnly"' in tenant_schema_text and '"hashChainRequired"' in tenant_schema_text and '"sinkPort"' in tenant_schema_text,
    "schema locks modes": '"offline"' in tenant_schema_text and '"private"' in tenant_schema_text,
    "policy schema evidence": '"auditLogRequired"' in policy_schema_text and '"evidenceRecordRequired"' in policy_schema_text,
    "w4 spec": "三层（Tenant/Workspace/User）" in w4_text and "本地 append-only file" in w4_text,
    "w8 no egress": "loopback/private-LAN defaults" in w8_text or "loopback/private LAN" in no_egress_text,
    "policy tenant self test": "tenantIsolation" in policy_test_text and "publicEgressDefault" in policy_test_text and "Checks: 8" in w4_text,
    "local cloud no egress test": "allowPublicEgress=false" in no_egress_text and "optInCloudEgress=false" in no_egress_text,
    "todo m6.1 complete": "- [x] M6.1 Implement tenant context runtime." in todo_text
    and "Follow-up task id: M6.2." in todo_text,
    "todo advanced beyond m6.1": (
        "Active cursor: M6.2 Implement policy engine" in todo_text
        or "Active cursor: M6.3 Implement audit log runtime" in todo_text
        or "Active cursor: M6.4 Implement local cloud sync-message runtime" in todo_text
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
        "Completed runtime foundation: M1.1-M6.1." in todo_text
        or "Completed runtime foundation: M1.1-M6.2." in todo_text
        or "Completed runtime foundation: M1.1-M6.3." in todo_text
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
    "no raw tenant payload": "RawTenant" not in combined and "TenantPayload" not in combined and "RawPolicy" not in combined,
    "no raw user payload": "RawUser" not in combined and "UserPayload" not in combined,
    "no raw document": "DocumentText" not in combined and "RawDocumentContent" not in combined and "storesDocumentContent=true" not in combined,
    "no policy engine": "PolicyEngine" not in combined and "RuleParser" not in combined and "EvaluatePolicy" not in combined,
    "no audit sink runtime": "AuditSinkRuntime" not in combined and "Socket" not in combined and "listen(" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no webview": "WebView" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 tenant context runtime self-test passed. Checks: {len(checks)}")
PY
