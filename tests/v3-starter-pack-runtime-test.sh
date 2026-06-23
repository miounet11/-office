#!/usr/bin/env bash
# V3 W9/M7.2 - starter-pack metadata runtime smoke.

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

runtime_hxx = src / "sfx2/source/sidebar/AIChatStarterPackRuntime.hxx"
runtime_cxx = src / "sfx2/source/sidebar/AIChatStarterPackRuntime.cxx"
tenant_cxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.cxx"
tenant_hxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.hxx"
policy_cxx = src / "sfx2/source/sidebar/AIChatPolicyEngineRuntime.cxx"
audit_cxx = src / "sfx2/source/sidebar/AIChatAuditLogRuntime.cxx"
onboarding_hxx = src / "sfx2/source/sidebar/AIChatOnboardingRuntime.hxx"
onboarding_cxx = src / "sfx2/source/sidebar/AIChatOnboardingRuntime.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
schema = repo / "docs/schemas/starter-pack-manifest.schema.json"
policy_schema = repo / "docs/schemas/policy-rule.schema.json"
valid_fixture = repo / "docs/qa/fixtures/v3/starter-pack/valid/full-30-template-pack.json"
w9_spec = repo / "docs/product/v3/w9-market-readiness-spec.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"
starter_contract = repo / "tests/v3-starter-pack-test.sh"
onboarding_test = repo / "tests/v3-onboarding-runtime-test.sh"
tenant_test = repo / "tests/v3-tenant-context-runtime-test.sh"
policy_test = repo / "tests/v3-policy-engine-runtime-test.sh"
no_egress_test = repo / "tests/v3-local-cloud-no-egress-test.sh"
in_app = repo / "tests/v3-in-app-chat-test.sh"

for path in [
    runtime_hxx,
    runtime_cxx,
    tenant_cxx,
    tenant_hxx,
    policy_cxx,
    audit_cxx,
    onboarding_hxx,
    onboarding_cxx,
    library_mk,
    schema,
    policy_schema,
    valid_fixture,
    w9_spec,
    todo,
    starter_contract,
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
tenant = tenant_hxx.read_text() + tenant_cxx.read_text()
policy = policy_cxx.read_text()
audit = audit_cxx.read_text()
onboarding = onboarding_hxx.read_text() + onboarding_cxx.read_text()
mk = library_mk.read_text()
schema_text = schema.read_text()
policy_schema_text = policy_schema.read_text()
fixture_text = valid_fixture.read_text()
fixture = json.loads(fixture_text)
w9_text = w9_spec.read_text()
todo_text = todo.read_text()
starter_contract_text = starter_contract.read_text()
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

sample_patch_fields = [
    "Required", "ActionKind", "MustSucceed", "RequiresUndo", "EvidenceRequired",
    "ApplyPlanRef", "DiffReviewRef", "ApprovalRef", "EvidenceId",
]
boundary_fields = ["StoresDocumentContent", "PublicEgress", "LocalFirst", "HashOnly"]
template_fields = [
    "TemplateId", "Surface", "Scenario", "Path", "TitleKey", "LocaleReady",
    "HashReference", "SamplePatch", "DataBoundary",
]
coverage_fields = [
    "TemplateCount", "BusinessScenarioCount", "WriterCount", "CalcCount",
    "ImpressCount", "PatchSmokeRequired",
]
installation_fields = [
    "Installable", "RequiresNetwork", "W8SelfHostedCompatible", "Distribution",
    "EmbeddedDefault", "TemplateRoot", "LocaleStrategy", "BundleLocationRef",
]
gate_fields = [
    "BlocksGA", "RequiresV2RegressionGreen", "RuntimeImplementation",
    "TemplateAssetsInstalled", "InstallerWiringComplete", "SampleOpenSmokeRequired",
]
manifest_fields = [
    "ManifestId", "SchemaVersion", "CreatedAt", "PackName", "Coverage",
    "Installation", "Templates", "RequiredEvidence", "EvidenceIds", "Gates",
    "TenantContextRef", "PolicyContextRef", "AuditChainRef", "OnboardingDemoRef",
    "ManifestHashReference",
]
smoke_fields = [
    "SmokeId", "ManifestId", "TemplateId", "Surface", "Scenario", "OpenTargetRef",
    "SampleOpenSucceeded", "PatchSmokeSucceeded", "UndoSucceeded", "EvidenceRequired",
    "EvidenceId", "AuditLogRef", "StoresDocumentContent", "PublicEgress",
]
apis = [
    "RegisterManifest",
    "RecordTemplateInstall",
    "RecordSampleOpenSmoke",
    "IsManifestIdAllowed",
    "IsTimestampAllowed",
    "IsPackNameAllowed",
    "IsDistributionAllowed",
    "IsTemplateRootAllowed",
    "IsLocaleStrategyAllowed",
    "IsSurfaceAllowed",
    "IsScenarioAllowed",
    "IsTemplateIdAllowed",
    "IsTemplatePathAllowed",
    "IsTitleKeyAllowed",
    "IsLocaleAllowed",
    "IsActionKindAllowedForSurface",
    "IsRequiredEvidenceAllowed",
    "IsOpenTargetRefAllowed",
    "IsSamplePatchShapeAllowed",
    "IsDataBoundaryAllowed",
    "IsTemplateShapeAllowed",
    "IsCoverageShapeAllowed",
    "IsInstallationShapeAllowed",
    "IsGateShapeAllowed",
    "IsManifestShapeAllowed",
    "IsSmokeShapeAllowed",
    "MakeManifestId",
    "MakeTemplateHashReference",
    "MakeManifestHashReference",
    "MakeSmokeId",
]

fixture_templates = fixture["templates"]
fixture_surfaces = {surface: sum(1 for t in fixture_templates if t["surface"] == surface) for surface in ["writer", "calc", "impress"]}
fixture_scenarios = {scenario: sum(1 for t in fixture_templates if t["scenario"] == scenario) for scenario in {t["scenario"] for t in fixture_templates}}
fixture_actions = {action: sum(1 for t in fixture_templates if t["samplePatch"]["actionKind"] == action) for action in {t["samplePatch"]["actionKind"] for t in fixture_templates}}

checks = {
    "runtime class": "class AIChatStarterPackRuntime final" in hxx,
    "sample patch struct": "struct AIChatStarterPackSamplePatch" in hxx and all(field in hxx for field in sample_patch_fields),
    "data boundary struct": "struct AIChatStarterPackDataBoundary" in hxx and all(field in hxx for field in boundary_fields),
    "template struct": "struct AIChatStarterPackTemplate" in hxx and all(field in hxx for field in template_fields),
    "coverage struct": "struct AIChatStarterPackCoverage" in hxx and all(field in hxx for field in coverage_fields),
    "installation struct": "struct AIChatStarterPackInstallation" in hxx and all(field in hxx for field in installation_fields),
    "gate struct": "struct AIChatStarterPackGateState" in hxx and all(field in hxx for field in gate_fields),
    "manifest struct": "struct AIChatStarterPackManifest" in hxx and all(field in hxx for field in manifest_fields),
    "smoke struct": "struct AIChatStarterPackSmoke" in hxx and all(field in hxx for field in smoke_fields),
    "result struct": "struct AIChatStarterPackResult" in hxx and "Success" in hxx and "Message" in hxx,
    "public api": all(api in hxx + cxx for api in apis),
    "compiled": "sfx2/source/sidebar/AIChatStarterPackRuntime" in mk,
    "uses onboarding": '#include "AIChatOnboardingRuntime.hxx"' in hxx and "onboarding-demo:" in cxx,
    "uses tenant": "AIChatTenantContextRuntime" in cxx and "ValidateActionScope" in cxx,
    "uses audit timestamp": "AIChatAuditLogRuntime::IsTimestampAllowed" in cxx,
    "uses metadata hash": "AIChatKnowledgeIndexStore::MakeMetadataHash" in cxx,
    "storage sidecar": "kqoffice-v3-ai-starter-pack" in cxx and "starter-pack.tsv" in cxx,
    "append only": "AppendUtf8Line" in cxx and "setPos(osl_Pos_Absolut, nSize)" in cxx,
    "store records": "starter-pack-manifest" in cxx and "template-install" in cxx and "sample-open-smoke" in cxx,
    "schema version": "v3-starter-pack-manifest/0.1" in cxx,
    "manifest id": 'rManifestId.startsWith(u"spm-"_ustr)' in cxx and "MakeManifestId" in cxx,
    "template counts": "STARTER_TEMPLATE_COUNT = 30" in cxx and "STARTER_SCENARIO_COUNT = 10" in cxx and "STARTER_PER_SURFACE_COUNT = 10" in cxx,
    "coverage validation": "IsCoverageShapeAllowed" in cxx and "CountSurface" in cxx and "CountScenario" in cxx and "HasUniqueTemplateIdsAndPaths" in cxx,
    "surfaces": all(x in cxx for x in ['u"writer"_ustr', 'u"calc"_ustr', 'u"impress"_ustr']),
    "scenarios": all(x in cxx for x in ["meeting-notes", "okr", "prd", "weekly-report", "contract-brief", "budget", "sales-dashboard", "project-gantt", "roadshow", "retrospective"]),
    "paths": "templates/v3-starter-pack/" in cxx and ".ott" in cxx and ".ots" in cxx and ".otp" in cxx,
    "title key": "starter-pack." in cxx and "IsTitleKeyAllowed" in cxx,
    "locales": all(x in cxx for x in ['u"zh-CN"_ustr', 'u"en-US"_ustr', 'u"ja-JP"_ustr', 'u"zh-TW"_ustr']) and "HasValidLocales" in cxx,
    "action kinds": "ParagraphAction" in cxx and "CellAction" in cxx and "SlideElementAction" in cxx and "IsActionKindAllowedForSurface" in cxx,
    "sample patch": "SamplePatch" in hxx and "samplePatchRequired=true" in cxx and "samplePatchMustSucceed=true" in cxx and "requiresUndo=true" in cxx and "evidenceRequired=true" in cxx,
    "review refs": "ApplyPlanRef" in hxx and "DiffReviewRef" in hxx and "ApprovalRef" in hxx and "diff-review:" in cxx and "approval:" in cxx,
    "data boundary": "IsDataBoundaryAllowed" in cxx and "!rBoundary.StoresDocumentContent" in cxx and "!rBoundary.PublicEgress" in cxx and "LocalFirst" in cxx and "HashOnly" in cxx,
    "installation": "IsInstallationShapeAllowed" in cxx and "Installable" in hxx and "RequiresNetwork" in hxx and "W8SelfHostedCompatible" in hxx and "EmbeddedDefault" in hxx,
    "distribution": 'u"embedded"_ustr' in cxx and 'u"self-hosted-lan"_ustr' in cxx,
    "bundle ref": "BundleLocationRef" in hxx and 'startsWith(u"local-bundle:"_ustr)' in cxx,
    "evidence roster": all(x in cxx for x in ["starter-pack-manifest", "template-install", "sample-patch-result", "sample-open-smoke", "evidence-record", "v2-regression-green", "policy-decision", "audit-log-entry"]),
    "gate": "metadata-runtime-active" in cxx and "TemplateAssetsInstalled" in hxx and "InstallerWiringComplete" in hxx and "SampleOpenSmokeRequired" in hxx,
    "refs": "tenant-context:" in cxx and "policy-context:" in cxx and "audit-chain:" in cxx and "ManifestHashReference" in hxx,
    "register message": "starter-pack-manifest-registered" in cxx and "templates=30" in cxx and "scenarios=10" in cxx and "writer=10 calc=10 impress=10" in cxx,
    "install message": "starter-pack-template-install-recorded" in cxx and "template-binary-storage=false" in cxx,
    "smoke message": "starter-pack-sample-open-smoke-recorded" in cxx and "sampleOpenSucceeded=true" in cxx and "patchSmokeSucceeded=true" in cxx and "undoSucceeded=true" in cxx,
    "no mutation message": "no-main-document-mutation-before-approval=true" in cxx,
    "fail closed": "starter-pack-denied reason=" in cxx and "fail-closed-user-visible=true" in cxx,
    "no service messages": "installer-wiring-runtime=not-started" in cxx and "sample-open-ui-runtime=not-started" in cxx and "template-gallery-ui=not-started" in cxx,
    "tenant target": 'rTargetType == u"starter-pack"_ustr' in tenant and 'rSurface == u"starter-pack"_ustr' in tenant,
    "policy target": 'rTargetType == u"starter-pack"_ustr' in policy and '"starter-pack"' in policy_schema_text,
    "audit link": "AIChatAuditLogRuntime" in audit and "audit-log-entry-appended" in audit,
    "onboarding link": "AIChatOnboardingRuntime" in onboarding and "starter-writer-brief" in onboarding and "starter-calc-budget" in onboarding and "starter-impress-review" in onboarding,
    "schema contract": '"v3-starter-pack-manifest/0.1"' in schema_text and '"templateCount"' in schema_text and '"const": 30' in schema_text and '"requiresNetwork"' in schema_text and '"const": false' in schema_text,
    "fixture counts": len(fixture_templates) == 30 and fixture["coverage"]["businessScenarioCount"] == 10 and fixture_surfaces == {"writer": 10, "calc": 10, "impress": 10},
    "fixture scenarios": set(fixture_scenarios.values()) == {3} and len(fixture_scenarios) == 10,
    "fixture actions": fixture_actions == {"ParagraphAction": 10, "CellAction": 10, "SlideElementAction": 10},
    "fixture no network": fixture["installation"]["requiresNetwork"] is False and fixture["pack"]["embeddedDefault"] is True,
    "contract test": "Checks: 8" in starter_contract_text and "30 templates" in starter_contract_text and "10 business scenarios" in starter_contract_text,
    "w9 spec": "starter-pack self-test" in w9_text and "30 templates" in w9_text and "10 business scenarios" in w9_text,
    "onboarding runtime regression": "AIChatOnboardingRuntime" in onboarding_test_text and "onboarding-demo" in cxx,
    "tenant runtime regression": "starter-pack" in tenant_test_text,
    "policy runtime regression": "starter-pack" in policy_test_text,
    "no egress regression": "public egress requires explicit opt-in" in no_egress_text,
    "in app umbrella": "v3-agent-failure-recovery-runtime-test.sh" in in_app_text,
    "todo m7.2 pending or complete": (
        "- [ ] M7.2 Ship starter packs." in todo_text
        or "- [x] M7.2 Ship starter packs." in todo_text
    ),
    "todo m7.2 recorded": (
        ("Start M7.2" in todo_text and "tests/v3-starter-pack-runtime-test.sh" in todo_text)
        or ("- [x] M7.2 Ship starter packs." in todo_text and "Follow-up task id: M7.3." in todo_text)
    ),
    "no raw document": "DocumentText" not in combined and "RawDocumentContent" not in combined and "storesDocumentContent=true" not in combined,
    "no raw template body": "RawTemplate" not in combined and "TemplateBody" not in combined and "TemplatePayload" not in combined,
    "no binary assets": "TemplateBinary" not in combined and "BinaryTemplate" not in combined and ".ott payload" not in combined.lower(),
    "no prompt": "RawPrompt" not in combined and "PromptText" not in combined,
    "no connector writeback": "ConnectorWriteback" not in combined and "writeback=true" not in combined.lower(),
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no cdn": "CDN" not in combined and "cdn-fetch=true" not in combined,
    "no downloader": "DownloadTemplate" not in combined and "ModelDownloader" not in combined and "model-download=true" not in combined,
    "no installer": "InstallerRuntime" not in combined and "PackageInstaller" not in combined,
    "no webview/gallery": "WebView" not in combined and "StandaloneGallery" not in combined and "MarketingGallery" not in combined,
    "no apply execution": "ApplyPlan(" not in combined and "ExecuteList" not in combined and "applyDiagnosticsPlan" not in combined,
    "no sqlite/vector/model": "sqlite" not in combined.lower() and "lancedb" not in combined.lower() and "VectorStore" not in combined and "ModelRuntime" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 starter-pack runtime self-test passed. Checks: {len(checks)}")
PY
