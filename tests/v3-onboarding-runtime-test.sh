#!/usr/bin/env bash
# V3 W9/M7.1 - onboarding runtime smoke.

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

runtime_hxx = src / "sfx2/source/sidebar/AIChatOnboardingRuntime.hxx"
runtime_cxx = src / "sfx2/source/sidebar/AIChatOnboardingRuntime.cxx"
tenant_hxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.hxx"
tenant_cxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.cxx"
audit_cxx = src / "sfx2/source/sidebar/AIChatAuditLogRuntime.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
schema = repo / "docs/schemas/onboarding-flow.schema.json"
w9_spec = repo / "docs/product/v3/w9-market-readiness-spec.md"
model_policy = repo / "docs/product/v3/w3-model-acquisition-policy.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"
flow_test = repo / "tests/v3-onboarding-flow-test.sh"
no_egress_test = repo / "tests/v3-local-cloud-no-egress-test.sh"
companion_test = repo / "tests/v3-companion-approval-runtime-test.sh"
in_app = repo / "tests/v3-in-app-chat-test.sh"

for path in [
    runtime_hxx, runtime_cxx, tenant_hxx, tenant_cxx, audit_cxx, library_mk, schema,
    w9_spec, model_policy, todo, flow_test, no_egress_test, companion_test, in_app,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = runtime_hxx.read_text()
cxx = runtime_cxx.read_text()
combined = hxx + cxx
tenant = tenant_hxx.read_text() + tenant_cxx.read_text()
audit = audit_cxx.read_text()
mk = library_mk.read_text()
schema_text = schema.read_text()
w9_text = w9_spec.read_text()
model_policy_text = model_policy.read_text()
todo_text = todo.read_text()
flow_test_text = flow_test.read_text()
no_egress_text = no_egress_test.read_text()
companion_test_text = companion_test.read_text()
in_app_text = in_app.read_text()


def strip_leading_block_comments(text: str) -> str:
    body = text.lstrip()
    while body.startswith("/*") and "*/" in body:
        body = body.split("*/", 1)[1].lstrip()
    return body


cxx_body = strip_leading_block_comments(cxx)

step_fields = ["Order", "Kind", "TitleKey", "Required", "MaxSeconds", "EvidenceRequired", "State", "EvidenceId"]
privacy_fields = ["NoSilentUpload", "LocalFirst", "ExplicitCloudOptIn", "StoresDocumentContent", "Acknowledged", "EvidenceId"]
local_model_fields = ["Mode", "Provider", "CanSkip", "DefaultModel", "OfflineCapable", "UserSkipped", "ExplicitDownloadApproved", "EvidenceId"]
connector_fields = ["Required", "MaxInitialConnectors", "OptionalKinds", "RequiresEvidence", "SelectedKind", "UserOptIn", "EvidenceId"]
demo_fields = ["SampleDocument", "Surfaces", "MustSucceed", "RequiresUndo", "ResultEvidence", "ApplyPlanRef", "DiffReviewRef", "ApprovalRef", "ExplicitApprovalRequired", "PatchApplied", "EvidenceId"]
gate_fields = ["BlocksGA", "RequiresV2RegressionGreen", "RuntimeImplementation", "RecoverySupported", "CanSkipAndResume"]
flow_fields = ["FlowId", "SchemaVersion", "CreatedAt", "Locale", "Edition", "MaxMinutes", "ExpectedMinutes", "FromDownloadToPatch", "Steps", "Privacy", "LocalModel", "Connector", "DemoPatch", "RequiredEvidence", "EvidenceIds", "Gates", "TenantContextRef", "PolicyContextRef", "AuditChainRef", "ResumeStateRef"]
apis = [
    "SaveFlow", "MarkStepComplete", "RecordSkipOrResume", "IsFlowIdAllowed",
    "IsTimestampAllowed", "IsLocaleAllowed", "IsEditionAllowed", "IsStepKindAllowed",
    "IsStepStateAllowed", "IsLocalModelModeAllowed", "IsLocalModelProviderAllowed",
    "IsDefaultModelAllowed", "IsConnectorKindAllowed", "IsSampleDocumentAllowed",
    "IsDemoSurfaceAllowed", "IsRequiredEvidenceAllowed", "IsStepShapeAllowed",
    "IsPrivacyShapeAllowed", "IsLocalModelShapeAllowed", "IsConnectorShapeAllowed",
    "IsDemoPatchShapeAllowed", "IsGateShapeAllowed", "IsFlowShapeAllowed",
    "MakeFlowId", "MakeResumeStateRef",
]

checks = {
    "runtime class": "class AIChatOnboardingRuntime final" in hxx,
    "step struct": "struct AIChatOnboardingStep" in hxx and all(field in hxx for field in step_fields),
    "privacy struct": "struct AIChatOnboardingPrivacy" in hxx and all(field in hxx for field in privacy_fields),
    "local model struct": "struct AIChatOnboardingLocalModel" in hxx and all(field in hxx for field in local_model_fields),
    "connector struct": "struct AIChatOnboardingConnector" in hxx and all(field in hxx for field in connector_fields),
    "demo struct": "struct AIChatOnboardingDemoPatch" in hxx and all(field in hxx for field in demo_fields),
    "gate struct": "struct AIChatOnboardingGateState" in hxx and all(field in hxx for field in gate_fields),
    "flow struct": "struct AIChatOnboardingFlow" in hxx and all(field in hxx for field in flow_fields),
    "result struct": "struct AIChatOnboardingResult" in hxx and "Success" in hxx and "Message" in hxx,
    "public api": all(api in hxx + cxx for api in apis),
    "compiled": "sfx2/source/sidebar/AIChatOnboardingRuntime" in mk,
    "storage sidecar": "kqoffice-v3-ai-onboarding" in cxx and "onboarding.tsv" in cxx,
    "append only": "AppendUtf8Line" in cxx and "setPos(osl_Pos_Absolut, nSize)" in cxx,
    "uses tenant": "AIChatTenantContextRuntime" in cxx and "ValidateActionScope" in cxx,
    "uses audit timestamp": "AIChatAuditLogRuntime::IsTimestampAllowed" in cxx,
    "uses metadata hash": "AIChatKnowledgeIndexStore::MakeMetadataHash" in cxx,
    "schema version": "v3-onboarding-flow/0.1" in cxx,
    "flow id": 'rFlowId.startsWith(u"onb-"_ustr)' in cxx and "MakeFlowId" in cxx,
    "locales": all(x in cxx for x in ['u"zh-CN"_ustr', 'u"en-US"_ustr', 'u"ja-JP"_ustr', 'u"zh-TW"_ustr']),
    "editions": all(x in cxx for x in ['u"personal-free"_ustr', 'u"personal-pro"_ustr', 'u"enterprise"_ustr', 'u"enterprise-self-hosted"_ustr']),
    "five steps": "StepOrderMatchesContract" in cxx and "rSteps.size() != 5" in cxx and all(x in cxx for x in ['u"welcome"', 'u"local-model"', 'u"connector"', 'u"privacy"', 'u"demo-patch"']),
    "duration": "MaxMinutes != 5" in cxx and "ExpectedMinutes < 1" in cxx and "TotalStepSeconds(rFlow.Steps) > 300" in cxx,
    "step evidence": "EvidenceRequired" in cxx and "IsStepShapeAllowed" in cxx,
    "privacy": "NoSilentUpload" in cxx and "LocalFirst" in cxx and "ExplicitCloudOptIn" in cxx and "Acknowledged" in cxx and "!rPrivacy.StoresDocumentContent" in cxx,
    "local model": "select-or-skip" in cxx and "preconfigured" in cxx and "ollama-local" in cxx and "enterprise-local" in cxx and "none" in cxx,
    "model no hidden download": "!rLocalModel.ExplicitDownloadApproved" in cxx and "hidden-model-download=false" in cxx,
    "default models": "llama3.2:3b" in cxx and "qwen3:0.6b" in cxx and "enterprise-local" in cxx,
    "connector optional": "rConnector.Required" in cxx and "MaxInitialConnectors > 1" in cxx and "connector-required=false" in cxx,
    "connector kinds": all(x in cxx for x in ["local-fs", "feishu-docs", "wechat-work-docs", "notion", "sharepoint", "confluence"]),
    "connector opt in": "SelectedKind" in cxx and "UserOptIn" in cxx and "connector-writeback=false" in cxx,
    "demo patch": "starter-writer-brief" in cxx and "starter-calc-budget" in cxx and "starter-impress-review" in cxx,
    "demo surfaces": "writer" in cxx and "calc" in cxx and "impress" in cxx,
    "demo approval": "ApplyPlanRef" in cxx and "DiffReviewRef" in cxx and "ApprovalRef" in cxx and "ExplicitApprovalRequired" in cxx and "PatchApplied" in cxx,
    "demo no apply before approval": "demoPatchApplyBeforeApproval=false" in cxx and "demo-patch-approval-missing" in cxx,
    "evidence roster": all(x in cxx for x in ["onboarding-flow", "evidence-record", "local-model-choice", "privacy-confirmation", "demo-patch-result", "connector-choice"]),
    "gate": "BlocksGA" in cxx and "RequiresV2RegressionGreen" in cxx and "metadata-runtime-active" in cxx and "RecoverySupported" in cxx and "CanSkipAndResume" in cxx,
    "refs": "tenant-context:" in cxx and "policy-context:" in cxx and "audit-chain:" in cxx and "onboarding-resume:" in cxx,
    "save message": "onboarding-flow-saved" in cxx and "five-steps=true" in cxx and "maxMinutes=5" in cxx,
    "step complete": "MarkStepComplete" in cxx and "onboarding-step-completed" in cxx and "privacy-not-acknowledged" in cxx,
    "skip resume": "RecordSkipOrResume" in cxx and "onboarding-skip-resume-recorded" in cxx and "canSkipAndResume=true" in cxx,
    "no service messages": "onboarding-controller-runtime=not-started" in cxx and "model-downloader-runtime=not-started" in cxx and "cloud-account-login=not-started" in cxx and "installer-updater=not-started" in cxx,
    "schema": '"v3-onboarding-flow/0.1"' in schema_text and '"maxMinutes"' in schema_text and '"const": 5' in schema_text and '"noSilentUpload"' in schema_text and '"mustSucceed"' in schema_text,
    "w9 spec": "onboarding-flow self-test" in w9_text and "Checks: 8" in w9_text and "5 steps" in w9_text,
    "model policy": "silent" in model_policy_text.lower() and "download" in model_policy_text.lower(),
    "flow contract": "Checks: 8" in flow_test_text and "noSilentUpload" in flow_test_text and "demo-patch" in flow_test_text,
    "no egress contract": "local-cloud no-egress" in no_egress_text and "public egress requires explicit opt-in" in no_egress_text,
    "companion regression": "AIChatCompanionApprovalRuntime" in companion_test_text,
    "in app umbrella": "v3-agent-failure-recovery-runtime-test.sh" in in_app_text,
    "todo m7.1 complete": "- [x] M7.1 Build first-run onboarding." in todo_text and "Follow-up task id: M7.2." in todo_text,
    "todo advanced beyond m7.1": (
        "Active cursor: M7.2 Ship starter packs" in todo_text
        or "Active cursor: M7.3 Finalize editions and local-first policy" in todo_text
        or "Active cursor: M7.4 Finalize manual docs and i18n" in todo_text
        or "Active cursor: M7.5 Finalize distribution/update/recovery" in todo_text
        or "Active cursor: M7.6 Prove perf and crash recovery targets" in todo_text
        or "Active cursor: M7.7 Release GA checklist" in todo_text
        or "Active cursor: Hardening Backlog M0.3/M0.4" in todo_text
        or "Active cursor: Post-hardening stabilization and broader validation" in todo_text
    )
    and (
        "Completed runtime foundation: M1.1-M7.1." in todo_text
        or "Completed runtime foundation: M1.1-M7.2." in todo_text
        or "Completed runtime foundation: M1.1-M7.3." in todo_text
        or "Completed runtime foundation: M1.1-M7.4." in todo_text
        or "Completed runtime foundation: M1.1-M7.5." in todo_text
        or "Completed runtime foundation: M1.1-M7.6." in todo_text
        or "Completed runtime foundation: M1.1-M7.7." in todo_text
    ),
    "immediate next slice": (
        ("Start M7.2" in todo_text and "starter pack" in todo_text)
        or ("Start M7.3" in todo_text and "editions/local-first policy" in todo_text)
        or ("Start M7.4" in todo_text and "manual-docs/i18n" in todo_text)
        or ("Start M7.5" in todo_text and "distribution/update/recovery" in todo_text)
        or ("Start M7.6" in todo_text and "perf/crash" in todo_text)
        or ("Start M7.7" in todo_text and "release GA checklist" in todo_text)
        or ("- [x] M7.7 Release GA checklist." in todo_text and "Follow-up task id: Hardening Backlog M0.3/M0.4." in todo_text)
    ),
    "no raw document": "DocumentText" not in combined and "RawDocumentContent" not in combined and "storesDocumentContent=true" not in combined,
    "no prompt": "RawPrompt" not in combined and "PromptText" not in combined,
    "no connector writeback": "ConnectorWriteback" not in combined and "writeback=true" not in combined.lower(),
    "no cloud history": "CloudHistory" not in combined and "cloud-history=true" not in combined,
    "no model downloader": "ModelDownloader" not in combined and "DownloadModel" not in combined,
    "no webview/landing": "WebView" not in combined and "LandingPage" not in combined and "Marketing" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no apply execution": "ApplyPlan(" not in combined and "ExecuteList" not in combined and "applyDiagnosticsPlan" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 onboarding runtime self-test passed. Checks: {len(checks)}")
PY
