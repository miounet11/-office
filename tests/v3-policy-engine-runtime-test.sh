#!/usr/bin/env bash
# V3 W4/M6.2 - policy engine runtime smoke.

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

engine_hxx = src / "sfx2/source/sidebar/AIChatPolicyEngineRuntime.hxx"
engine_cxx = src / "sfx2/source/sidebar/AIChatPolicyEngineRuntime.cxx"
tenant_hxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.hxx"
tenant_cxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
policy_schema = repo / "docs/schemas/policy-rule.schema.json"
tenant_schema = repo / "docs/schemas/tenant-context.schema.json"
w4_spec = repo / "docs/product/v3/w4-tenant-policy-audit-spec.md"
w2_ops = repo / "docs/product/v3/w2-connector-operations-policy.md"
w6_plan = repo / "docs/product/v3/w6-plan-validation-policy.md"
policy_test = repo / "tests/v3-policy-tenant-test.sh"
tenant_test = repo / "tests/v3-tenant-context-runtime-test.sh"
connector_test = repo / "tests/v3-connector-operation-runtime-test.sh"
agent_test = repo / "tests/v3-agent-planner-runtime-test.sh"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [
    engine_hxx,
    engine_cxx,
    tenant_hxx,
    tenant_cxx,
    library_mk,
    policy_schema,
    tenant_schema,
    w4_spec,
    w2_ops,
    w6_plan,
    policy_test,
    tenant_test,
    connector_test,
    agent_test,
    todo,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = engine_hxx.read_text()
cxx = engine_cxx.read_text()
tenant = tenant_hxx.read_text() + tenant_cxx.read_text()
combined = hxx + cxx
mk = library_mk.read_text()
policy_schema_text = policy_schema.read_text()
tenant_schema_text = tenant_schema.read_text()
w4_text = w4_spec.read_text()
w2_ops_text = w2_ops.read_text()
w6_plan_text = w6_plan.read_text()
policy_test_text = policy_test.read_text()
tenant_test_text = tenant_test.read_text()
connector_test_text = connector_test.read_text()
agent_test_text = agent_test.read_text()
todo_text = todo.read_text()


def strip_leading_block_comments(text: str) -> str:
    body = text.lstrip()
    while body.startswith("/*") and "*/" in body:
        body = body.split("*/", 1)[1].lstrip()
    return body


cxx_body = strip_leading_block_comments(cxx)

rule_fields = [
    "RuleId",
    "SchemaVersion",
    "Priority",
    "Phase",
    "Effect",
    "Tenants",
    "ServiceModes",
    "ActorRoles",
    "TargetTypes",
    "DataClasses",
    "BlocksAction",
    "ApprovalRequired",
    "AuditLogRequired",
    "ReasonCode",
    "RequiredEvidence",
    "EmitsAuditLog",
    "EvidenceRecordRequired",
]

decision_fields = [
    "Success",
    "RuleId",
    "Effect",
    "Phase",
    "Decision",
    "BlocksAction",
    "ApprovalRequired",
    "AuditLogRequired",
    "ReasonCode",
    "PolicyContextRef",
    "AuditChainRef",
    "EvidenceId",
    "HashReference",
    "Message",
]

checks = {
    "engine class": "class AIChatPolicyEngineRuntime final" in hxx,
    "rule struct": "struct AIChatPolicyRule" in hxx and all(field in hxx for field in rule_fields),
    "decision struct": "struct AIChatPolicyDecision" in hxx and all(field in hxx for field in decision_fields),
    "compiled": "sfx2/source/sidebar/AIChatPolicyEngineRuntime" in mk,
    "evaluate api": "EvaluateRule" in hxx + cxx,
    "uses tenant scope": "AIChatTenantContextRuntime" in hxx + cxx and "ValidateActionScope" in cxx,
    "rule id": "IsRuleIdAllowed" in cxx and 'rRuleId.startsWith(u"pol-"_ustr)' in cxx,
    "phase": "IsPhaseAllowed" in cxx and 'u"pre-flight"_ustr' in cxx and 'u"post-evidence"_ustr' in cxx,
    "effects": "IsEffectAllowed" in cxx and all(x in cxx for x in ['u"allow"_ustr', 'u"deny"_ustr', 'u"require-approval"_ustr', 'u"require-evidence"_ustr']),
    "target types": "IsPolicyTargetTypeAllowed" in cxx and all(x in cxx for x in ['u"chat"_ustr', 'u"provider"_ustr', 'u"connector"_ustr', 'u"kb-query"_ustr', 'u"agent-step"_ustr', 'u"patch-apply"_ustr', 'u"companion"_ustr', 'u"local-cloud"_ustr', 'u"starter-pack"_ustr', 'u"edition-policy"_ustr', 'u"i18n-manual"_ustr', 'u"distribution-update"_ustr', 'u"error-recovery-ux"_ustr', 'u"perf-baseline"_ustr', 'u"crash-recovery"_ustr', 'u"release-ga-checklist"_ustr']),
    "target normalization": "NormalizeTargetType" in cxx and 'rTargetType == u"knowledge-index"_ustr' in cxx and 'return u"kb-query"_ustr' in cxx,
    "reason code": "IsReasonCodeAllowed" in cxx,
    "evidence requirements": "IsEvidenceRequirementAllowed" in cxx and all(x in cxx for x in ['u"policy-decision"_ustr', 'u"audit-log-entry"_ustr', 'u"evidence-record"_ustr', 'u"user-approval"_ustr']),
    "shape guard": "IsRuleShapeAllowed" in cxx and "ContainsDuplicateString" in cxx,
    "base evidence required": "policy-decision" in cxx and "audit-log-entry" in cxx and "evidence-record" in cxx,
    "deny semantics": 'rRule.Effect == u"deny"_ustr' in cxx and "rRule.BlocksAction && !rRule.ApprovalRequired" in cxx,
    "allow semantics": 'rRule.Effect == u"allow"_ustr' in cxx and "!rRule.BlocksAction && !rRule.ApprovalRequired" in cxx,
    "approval semantics": 'rRule.Effect == u"require-approval"_ustr' in cxx and "rRule.BlocksAction && rRule.ApprovalRequired" in cxx and 'u"user-approval"_ustr' in cxx,
    "evidence semantics": 'rRule.Effect == u"require-evidence"_ustr' in cxx and 'rRule.Phase == u"post-evidence"_ustr' in cxx,
    "rule match": "RuleMatchesScope" in cxx and "IsAnyRoleOrMatches" in cxx,
    "decision evidence": "MakePolicyDecisionEvidenceId" in cxx and 'u"ev-"_ustr' in cxx,
    "decision hash": "MakePolicyDecisionHashReference" in cxx and 'u"sha256:"_ustr' in cxx,
    "metadata hash": "AIChatKnowledgeIndexStore::MakeMetadataHash" in cxx,
    "tenant invalid denied": "policy-decision-denied reason=tenant-scope-invalid" in cxx and "fail-closed-user-visible=true" in cxx,
    "invalid rule denied": "policy-decision-denied reason=invalid-policy-rule" in cxx and "raw-policy=false" in cxx,
    "not applicable": "policy-decision-not-applicable" in cxx and "rule-scope-mismatch" in cxx,
    "evidence invalid denied": "decision-evidence-invalid" in cxx,
    "success message": "policy-decision-evaluated" in cxx and "policy-decision=true" in cxx,
    "audit refs": "PolicyContextRef" in cxx and "AuditChainRef" in cxx and "auditLogRequired=true" in cxx,
    "no public egress": "no-public-egress=true" in cxx and "publicEgressDefault=false" in cxx,
    "runtime gated": "yaml-parser-runtime=not-started" in cxx and "audit-log-runtime=not-started" in cxx,
    "tenant supports patch apply": 'rTargetType == u"patch-apply"_ustr' in tenant and 'rSurface == u"apply-plan"_ustr' in tenant,
    "schema effects": '"allow"' in policy_schema_text and '"deny"' in policy_schema_text and '"require-approval"' in policy_schema_text and '"require-evidence"' in policy_schema_text,
    "schema targets": '"kb-query"' in policy_schema_text and '"patch-apply"' in policy_schema_text and '"companion"' in policy_schema_text and '"local-cloud"' in policy_schema_text and '"starter-pack"' in policy_schema_text and '"edition-policy"' in policy_schema_text and '"i18n-manual"' in policy_schema_text and '"distribution-update"' in policy_schema_text and '"error-recovery-ux"' in policy_schema_text and '"perf-baseline"' in policy_schema_text and '"crash-recovery"' in policy_schema_text and '"release-ga-checklist"' in policy_schema_text,
    "schema evidence": '"policy-decision"' in policy_schema_text and '"audit-log-entry"' in policy_schema_text and '"evidence-record"' in policy_schema_text,
    "tenant schema no egress": '"publicEgressDefault"' in tenant_schema_text and '"const": false' in tenant_schema_text,
    "w4 policy engine plan": "Policy 引擎" in w4_text and "pre-flight" in w4_text and "post-evidence" in w4_text,
    "connector policy": "writeScopesAllowed" in w2_ops_text and "tenant policy" in w2_ops_text,
    "agent policy": "Auto retry allowed" in w6_plan_text and "policy-decision" in policy_test_text,
    "policy self test": "effect enforcement" in policy_test_text and "Checks: 8" in w4_text,
    "tenant runtime self test": "AIChatTenantContextRuntime" in tenant_test_text and "MakePolicyContextRef" in tenant_test_text and "policy-context:" in tenant_test_text,
    "connector regression": "tenant-policy-required" in connector_test_text or "TenantPolicyRef" in connector_test_text,
    "agent regression": "RequiresPolicyPreflight" in agent_test_text or "policy preflight" in agent_test_text,
    "todo m6.2 complete": "- [x] M6.2 Implement policy engine." in todo_text
    and "Follow-up task id: M6.3." in todo_text,
    "todo advanced beyond m6.2": (
        "Active cursor: M6.3 Implement audit log runtime" in todo_text
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
        "Completed runtime foundation: M1.1-M6.2." in todo_text
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
    "no raw policy payload": "RawPolicy" not in combined and "PolicyPayload" not in combined and "RulePayload" not in combined,
    "no raw prompt": "RawPrompt" not in combined and "PromptBody" not in combined,
    "no raw document": "DocumentText" not in combined and "RawDocumentContent" not in combined and "storesDocumentContent=true" not in combined,
    "no yaml parser": "YAML" not in combined and "RuleParser" not in combined,
    "no audit writer": "AuditLogWriter" not in combined and "AppendAudit" not in combined and "AuditSinkRuntime" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no webview": "WebView" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 policy engine runtime self-test passed. Checks: {len(checks)}")
PY
