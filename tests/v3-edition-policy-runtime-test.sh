#!/usr/bin/env bash
# V3 W9/M7.3 - edition/local-first policy runtime smoke.

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

import json
import sys
from pathlib import Path

repo = Path(sys.argv[1])
src = Path(sys.argv[2])

runtime_hxx = src / "sfx2/source/sidebar/AIChatEditionPolicyRuntime.hxx"
runtime_cxx = src / "sfx2/source/sidebar/AIChatEditionPolicyRuntime.cxx"
starter_hxx = src / "sfx2/source/sidebar/AIChatStarterPackRuntime.hxx"
starter_cxx = src / "sfx2/source/sidebar/AIChatStarterPackRuntime.cxx"
onboarding_cxx = src / "sfx2/source/sidebar/AIChatOnboardingRuntime.cxx"
tenant_hxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.hxx"
tenant_cxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.cxx"
policy_cxx = src / "sfx2/source/sidebar/AIChatPolicyEngineRuntime.cxx"
audit_cxx = src / "sfx2/source/sidebar/AIChatAuditLogRuntime.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
schema = repo / "docs/schemas/edition-policy.schema.json"
policy_schema = repo / "docs/schemas/policy-rule.schema.json"
valid_fixture = repo / "docs/qa/fixtures/v3/edition-policy/valid/w9-edition-policy.json"
w9_spec = repo / "docs/product/v3/w9-market-readiness-spec.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"
edition_contract = repo / "tests/v3-edition-policy-test.sh"
starter_runtime_test = repo / "tests/v3-starter-pack-runtime-test.sh"
onboarding_test = repo / "tests/v3-onboarding-runtime-test.sh"
tenant_test = repo / "tests/v3-tenant-context-runtime-test.sh"
policy_test = repo / "tests/v3-policy-engine-runtime-test.sh"
no_egress_test = repo / "tests/v3-local-cloud-no-egress-test.sh"
in_app = repo / "tests/v3-in-app-chat-test.sh"

for path in [
    runtime_hxx,
    runtime_cxx,
    starter_hxx,
    starter_cxx,
    onboarding_cxx,
    tenant_hxx,
    tenant_cxx,
    policy_cxx,
    audit_cxx,
    library_mk,
    schema,
    policy_schema,
    valid_fixture,
    w9_spec,
    todo,
    edition_contract,
    starter_runtime_test,
    onboarding_test,
    tenant_test,
    policy_test,
    no_egress_test,
    in_app,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = runtime_hxx.read_text()
cxx = runtime_cxx.read_text()
combined = hxx + cxx
starter = starter_hxx.read_text() + starter_cxx.read_text()
onboarding = onboarding_cxx.read_text()
tenant = tenant_hxx.read_text() + tenant_cxx.read_text()
policy = policy_cxx.read_text()
audit = audit_cxx.read_text()
mk = library_mk.read_text()
schema_text = schema.read_text()
policy_schema_text = policy_schema.read_text()
fixture_text = valid_fixture.read_text()
fixture = json.loads(fixture_text)
w9_text = w9_spec.read_text()
todo_text = todo.read_text()
edition_contract_text = edition_contract.read_text()
starter_runtime_text = starter_runtime_test.read_text()
onboarding_test_text = onboarding_test.read_text()
tenant_test_text = tenant_test.read_text()
policy_test_text = policy_test.read_text()
no_egress_text = no_egress_test.read_text()
in_app_text = in_app.read_text()


def strip_leading_block_comments(text: str) -> str:
    body = text.lstrip()
    while body.startswith("/*") and "*/" in body:
        body = body.split("*/", 1)[1].lstrip()
    return body


cxx_body = strip_leading_block_comments(cxx)

price_fields = ["Currency", "Amount", "Period", "SeatBased"]
audit_fields = ["Enabled", "RequiredForEdition", "BypassAllowed", "AuditLockRef"]
limit_fields = ["ConnectorMax", "KnowledgeIndexDocumentMax", "AgentConcurrencyMax", "UnlimitedScale"]
feature_fields = ["AIPatch", "LocalModel", "StarterPack", "CompanionApproval", "FeatureLocked"]
deployment_fields = ["Mode", "W8SelfHosted", "RequiresPublicCloud"]
boundary_fields = ["LocalFirst", "StoresDocumentContent", "PublicEgressDefault", "ExplicitPublicEgressOptIn"]
edition_fields = ["EditionId", "Price", "Audit", "Limits", "FeatureAccess", "Deployment", "DataBoundary"]
business_fields = ["Mode", "PersonalFreeLocal", "EnterpriseChargesByAudit", "FunctionLockAllowed"]
guardrail_fields = ["LimitsOnlyScaleAndAudit", "PersonalEditionFullLocalAI", "EnterpriseAuditMandatory", "TrialBypassAuditAllowed"]
gate_fields = ["BlocksGA", "RequiresV2RegressionGreen", "RuntimeImplementation", "BillingRuntimeActive", "LicenseServerActive", "AccountCloudLoginActive", "EntitlementFetchActive"]
policy_fields = ["PolicyId", "SchemaVersion", "CreatedAt", "BusinessModel", "Editions", "Guardrails", "RequiredEvidence", "EvidenceIds", "Gates", "TenantContextRef", "PolicyContextRef", "AuditChainRef", "OnboardingRef", "StarterPackRef", "NoEgressRef", "HashReference"]
selection_fields = ["SelectionId", "PolicyId", "EditionId", "UserId", "TenantId", "WorkspaceId", "ServiceMode", "LocalAIDefault", "PublicEgress", "EnterpriseGateSatisfied", "AuditRequired", "AuditEnabled", "EvidenceId", "AuditLogRef", "PolicyDecisionRef"]
apis = [
    "SavePolicy",
    "RecordEditionSelection",
    "IsPolicyIdAllowed",
    "IsTimestampAllowed",
    "IsEditionIdAllowed",
    "IsCurrencyAllowed",
    "IsPeriodAllowed",
    "IsDeploymentModeAllowed",
    "IsServiceModeAllowedForEdition",
    "IsRequiredEvidenceAllowed",
    "IsPriceShapeAllowed",
    "IsAuditShapeAllowed",
    "IsLimitsShapeAllowed",
    "IsFeatureAccessShapeAllowed",
    "IsDeploymentShapeAllowed",
    "IsDataBoundaryShapeAllowed",
    "IsEditionShapeAllowed",
    "IsBusinessModelShapeAllowed",
    "IsGuardrailShapeAllowed",
    "IsGateShapeAllowed",
    "IsPolicyShapeAllowed",
    "IsSelectionShapeAllowed",
    "MakePolicyId",
    "MakePolicyHashReference",
    "MakeSelectionId",
]

editions = {edition["id"]: edition for edition in fixture["editions"]}

checks = {
    "runtime class": "class AIChatEditionPolicyRuntime final" in hxx,
    "price struct": "struct AIChatEditionPrice" in hxx and all(field in hxx for field in price_fields),
    "audit struct": "struct AIChatEditionAudit" in hxx and all(field in hxx for field in audit_fields),
    "limits struct": "struct AIChatEditionLimits" in hxx and all(field in hxx for field in limit_fields),
    "feature struct": "struct AIChatEditionFeatureAccess" in hxx and all(field in hxx for field in feature_fields),
    "deployment struct": "struct AIChatEditionDeployment" in hxx and all(field in hxx for field in deployment_fields),
    "boundary struct": "struct AIChatEditionDataBoundary" in hxx and all(field in hxx for field in boundary_fields),
    "edition struct": "struct AIChatEditionDefinition" in hxx and all(field in hxx for field in edition_fields),
    "business struct": "struct AIChatEditionBusinessModel" in hxx and all(field in hxx for field in business_fields),
    "guardrails struct": "struct AIChatEditionGuardrails" in hxx and all(field in hxx for field in guardrail_fields),
    "gate struct": "struct AIChatEditionGateState" in hxx and all(field in hxx for field in gate_fields),
    "policy struct": "struct AIChatEditionPolicy" in hxx and all(field in hxx for field in policy_fields),
    "selection struct": "struct AIChatEditionSelection" in hxx and all(field in hxx for field in selection_fields),
    "result struct": "struct AIChatEditionPolicyResult" in hxx and "Success" in hxx and "Message" in hxx,
    "public api": all(api in hxx + cxx for api in apis),
    "compiled": "sfx2/source/sidebar/AIChatEditionPolicyRuntime" in mk,
    "uses starter": '#include "AIChatStarterPackRuntime.hxx"' in hxx and "starter-pack:" in cxx,
    "uses tenant": "AIChatTenantContextRuntime" in cxx and "ValidateActionScope" in cxx,
    "uses audit timestamp": "AIChatAuditLogRuntime::IsTimestampAllowed" in cxx,
    "uses metadata hash": "AIChatKnowledgeIndexStore::MakeMetadataHash" in cxx,
    "storage sidecar": "kqoffice-v3-ai-edition-policy" in cxx and "edition-policy.tsv" in cxx,
    "append only": "AppendUtf8Line" in cxx and "setPos(osl_Pos_Absolut, nSize)" in cxx,
    "store records": "edition-policy" in cxx and "edition-selection" in cxx,
    "schema version": "v3-edition-policy/0.1" in cxx,
    "policy id": 'rPolicyId.startsWith(u"edp-"_ustr)' in cxx and "MakePolicyId" in cxx,
    "selection id": 'rSelection.SelectionId.startsWith(u"eds-"_ustr)' in cxx and "MakeSelectionId" in cxx,
    "edition roster": all(x in cxx for x in ["personal-free", "personal-pro", "enterprise", "enterprise-self-hosted"]) and "EditionOrderMatchesContract" in cxx,
    "business model": "freemium" in cxx and "PersonalFreeLocal" in hxx and "EnterpriseChargesByAudit" in hxx and "FunctionLockAllowed" in hxx,
    "price locks": "Amount == 0" in cxx and "Amount == 39" in cxx and "Amount == 199" in cxx and "Amount == 9999" in cxx,
    "currency": 'rCurrency == u"CNY"_ustr' in cxx,
    "periods": "free" in cxx and "monthly" in cxx and "one-time-plus-monthly" in cxx,
    "audit lock": "AuditLockRef" in hxx and "enterpriseAuditMandatory=true" in cxx and "auditBypassAllowed=false" in cxx,
    "enterprise audit": "rAudit.Enabled == bEnterprise" in cxx and "rAudit.RequiredForEdition == bEnterprise" in cxx and "!rAudit.BypassAllowed" in cxx,
    "limits": "ConnectorMax == 5" in cxx and "ConnectorMax == 20" in cxx and "ConnectorMax == 1000000" in cxx and "KnowledgeIndexDocumentMax == 1000000000" in cxx,
    "scale only": "LimitsOnlyScaleAndAudit" in hxx and "limitsOnlyScaleAndAudit=true" in cxx,
    "features full": "AIPatch" in hxx and "LocalModel" in hxx and "StarterPack" in hxx and "CompanionApproval" in hxx and "FeatureLocked" in hxx and "featureLocked=false" in cxx,
    "deployment": "desktop-local" in cxx and "enterprise-managed" in cxx and "w8-self-hosted" in cxx,
    "self hosted": "enterprise-self-hosted" in cxx and "W8SelfHosted" in hxx and "w8-self-hosted" in cxx,
    "boundary": "LocalFirst" in hxx and "StoresDocumentContent" in hxx and "PublicEgressDefault" in hxx and "ExplicitPublicEgressOptIn" in hxx,
    "no public egress": "publicEgressDefault=false" in cxx and "hidden-cloud-default=false" in cxx and "!rBoundary.PublicEgressDefault" in cxx,
    "no cloud opt in default": "!rBoundary.ExplicitPublicEgressOptIn" in cxx and "!rSelection.PublicEgress" in cxx,
    "service modes": "IsServiceModeAllowedForEdition" in cxx and "offline" in cxx and "private" in cxx,
    "evidence roster": all(x in cxx for x in ["edition-policy", "pricing-snapshot", "audit-lock", "evidence-record", "v2-regression-green", "policy-decision", "audit-log-entry", "tenant-context", "starter-pack-manifest", "onboarding-flow", "localcloud-no-egress"]),
    "refs": "tenant-context:" in cxx and "policy-context:" in cxx and "audit-chain:" in cxx and "onboarding-flow:" in cxx and "starter-pack:" in cxx and "localcloud-no-egress:" in cxx,
    "gate": "metadata-runtime-active" in cxx and "BillingRuntimeActive" in hxx and "LicenseServerActive" in hxx and "AccountCloudLoginActive" in hxx and "EntitlementFetchActive" in hxx,
    "save message": "edition-policy-saved" in cxx and "editions=4" in cxx and "personal-free-local=true" in cxx and "functionLockAllowed=false" in cxx,
    "selection message": "edition-selection-recorded" in cxx and "localAIDefault=true" in cxx and "enterpriseGateSatisfied=" in cxx,
    "fail closed": "edition-policy-denied reason=" in cxx and "fail-closed-user-visible=true" in cxx,
    "no service messages": "billing-runtime=not-started" in cxx and "license-server-runtime=not-started" in cxx and "account-cloud-login=not-started" in cxx and "entitlement-fetch=not-started" in cxx and "remote-admin-ui=not-started" in cxx,
    "tenant target": 'rTargetType == u"edition-policy"_ustr' in tenant and 'rSurface == u"edition-policy"_ustr' in tenant,
    "policy target": 'rTargetType == u"edition-policy"_ustr' in policy and '"edition-policy"' in policy_schema_text,
    "audit link": "AIChatAuditLogRuntime" in audit and "audit-log-entry-appended" in audit,
    "starter link": "AIChatStarterPackRuntime" in starter and "starter-pack-manifest-registered" in starter,
    "onboarding link": "AIChatOnboardingRuntime" in onboarding_test_text and "onboarding-flow" in cxx,
    "no egress link": "local-cloud no-egress" in no_egress_text and "localcloud-no-egress" in cxx,
    "schema contract": '"v3-edition-policy/0.1"' in schema_text and '"freemium"' in schema_text and '"functionLockAllowed"' in schema_text and '"const": false' in schema_text,
    "fixture editions": set(editions) == {"personal-free", "personal-pro", "enterprise", "enterprise-self-hosted"},
    "fixture personal free": editions["personal-free"]["price"]["amount"] == 0 and editions["personal-free"]["featureAccess"]["featureLocked"] is False,
    "fixture enterprise audit": editions["enterprise"]["audit"]["requiredForEdition"] is True and editions["enterprise-self-hosted"]["audit"]["requiredForEdition"] is True,
    "fixture local first": all(edition["dataBoundary"] == {"localFirst": True, "storesDocumentContent": False, "publicEgressDefault": False} for edition in editions.values()),
    "fixture no public cloud": all(edition["deployment"]["requiresPublicCloud"] is False for edition in editions.values()),
    "contract test": "Checks: 8" in edition_contract_text and "freemium" in edition_contract_text and "audit lock" in edition_contract_text,
    "w9 spec": "Edition" in w9_text and "audit lock" in w9_text and "freemium" in w9_text,
    "starter runtime regression": "AIChatStarterPackRuntime" in starter_runtime_text,
    "tenant runtime regression": "edition-policy" in tenant_test_text,
    "policy runtime regression": "edition-policy" in policy_test_text,
    "in app umbrella": "v3-agent-failure-recovery-runtime-test.sh" in in_app_text,
    "todo m7.3 pending or complete": (
        "- [ ] M7.3 Finalize editions and local-first policy." in todo_text
        or "- [x] M7.3 Finalize editions and local-first policy." in todo_text
    ),
    "todo m7.3 recorded": (
        ("Start M7.3" in todo_text and "tests/v3-edition-policy-runtime-test.sh" in todo_text)
        or ("- [x] M7.3 Finalize editions and local-first policy." in todo_text and "Follow-up task id: M7.4." in todo_text)
    ),
    "no raw document": "DocumentText" not in combined and "RawDocumentContent" not in combined and "storesDocumentContent=true" not in combined,
    "no raw prompt": "RawPrompt" not in combined and "PromptText" not in combined,
    "no function lock true": "featureLocked=true" not in combined and "FunctionLocked" not in combined,
    "no billing engine": "BillingEngine" not in combined and "PaymentProvider" not in combined and "Invoice" not in combined,
    "no license server": "LicenseServerRuntime" not in combined and "LicenseKey" not in combined,
    "no entitlement fetch": "EntitlementClient" not in combined and "FetchEntitlement" not in combined,
    "no account cloud": "CloudAccount" not in combined and "AccountLogin" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no installer activation": "InstallerActivation" not in combined and "ActivationServer" not in combined,
    "no remote admin ui": "RemoteAdmin" not in combined and "AdminWeb" not in combined,
    "no webview": "WebView" not in combined,
    "no apply execution": "ApplyPlan(" not in combined and "ExecuteList" not in combined and "applyDiagnosticsPlan" not in combined,
    "no sqlite/vector/model runtime": "sqlite" not in combined.lower() and "lancedb" not in combined.lower() and "VectorStore" not in combined and "ModelRuntime" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 edition policy runtime self-test passed. Checks: {len(checks)}")
PY
