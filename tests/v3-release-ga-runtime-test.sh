#!/usr/bin/env bash
# V3 M7.7 - release GA checklist metadata runtime self-test.
#
# Runtime guard for W9 release GA checklist metadata. It must not publish
# releases, sign artifacts, upload packages, open update channels, or make
# canShip true.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

python3 - <<'PY'
from __future__ import annotations

import json
from pathlib import Path

root = Path(".")
runtime_hxx = root / "libreoffice-core/sfx2/source/sidebar/AIChatReleaseGARuntime.hxx"
runtime_cxx = root / "libreoffice-core/sfx2/source/sidebar/AIChatReleaseGARuntime.cxx"
tenant_cxx = root / "libreoffice-core/sfx2/source/sidebar/AIChatTenantContextRuntime.cxx"
policy_cxx = root / "libreoffice-core/sfx2/source/sidebar/AIChatPolicyEngineRuntime.cxx"
audit_cxx = root / "libreoffice-core/sfx2/source/sidebar/AIChatAuditLogRuntime.cxx"
library_mk = root / "libreoffice-core/sfx2/Library_sfx.mk"
release_schema = root / "docs/schemas/release-ga-checklist.schema.json"
policy_schema = root / "docs/schemas/policy-rule.schema.json"
valid_fixture = root / "docs/qa/fixtures/v3/release-ga-checklist/valid/release-ga-checklist.json"
w9_spec = root / "docs/product/v3/w9-market-readiness-spec.md"
todo = root / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"
release_contract = root / "tests/v3-release-ga-checklist-test.sh"
distribution_runtime = root / "libreoffice-core/sfx2/source/sidebar/AIChatDistributionRecoveryRuntime.cxx"
perf_runtime = root / "libreoffice-core/sfx2/source/sidebar/AIChatPerfCrashRuntime.cxx"
tenant_test = root / "tests/v3-tenant-context-runtime-test.sh"
policy_test = root / "tests/v3-policy-engine-runtime-test.sh"
no_egress_test = root / "tests/v3-local-cloud-no-egress-test.sh"
in_app = root / "tests/v3-in-app-chat-test.sh"

for path in [
    runtime_hxx,
    runtime_cxx,
    tenant_cxx,
    policy_cxx,
    audit_cxx,
    library_mk,
    release_schema,
    policy_schema,
    valid_fixture,
    w9_spec,
    todo,
    release_contract,
    distribution_runtime,
    perf_runtime,
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
tenant = tenant_cxx.read_text()
policy = policy_cxx.read_text()
mk = library_mk.read_text()
release_schema_text = release_schema.read_text()
policy_schema_text = policy_schema.read_text()
w9_text = w9_spec.read_text()
todo_text = todo.read_text()
release_contract_text = release_contract.read_text()
distribution_text = distribution_runtime.read_text()
perf_text = perf_runtime.read_text()
tenant_test_text = tenant_test.read_text()
policy_test_text = policy_test.read_text()
no_egress_text = no_egress_test.read_text()
in_app_text = in_app.read_text()
fixture = json.loads(valid_fixture.read_text())


def strip_leading_block_comments(text: str) -> str:
    body = text.lstrip()
    while body.startswith("/*") and "*/" in body:
        body = body.split("*/", 1)[1].lstrip()
    return body


cxx_body = strip_leading_block_comments(cxx)

expected_gate_ids = [
    "v2-regression-green",
    "h8-connector-contract",
    "h9-eval-baseline",
    "h10-localcloud-no-egress",
    "h11-perf-baseline",
    "h12-crash-recovery",
    "w9-onboarding-flow",
    "w9-starter-pack",
    "w9-edition-policy",
    "w9-i18n-locale",
    "w9-manual-docs",
    "w9-distribution-update",
    "w9-error-recovery-ux",
    "source-archive-clean",
    "windows-toast-proof",
    "release-policy-decisions",
]
base_evidence = [
    "release-ga-checklist",
    "v2-regression-green",
    "v3-self-test-green",
    "v3-only-green",
    "human-approval",
    "evidence-record",
    "release-signoff",
]
gate_evidence = [
    "v2-harness-sweep",
    "tests/v3-connector-manifest-contract-test.sh",
    "tests/v3-eval-baseline-test.sh",
    "tests/v3-local-cloud-no-egress-test.sh",
    "tests/v3-perf-baseline-test.sh",
    "tests/v3-crash-recovery-test.sh",
    "tests/v3-onboarding-flow-test.sh",
    "tests/v3-starter-pack-test.sh",
    "tests/v3-edition-policy-test.sh",
    "tests/v3-i18n-locale-test.sh",
    "tests/v3-manual-docs-test.sh",
    "tests/v3-distribution-update-test.sh",
    "tests/v3-error-recovery-ux-test.sh",
    "source-archive-commits",
    "h10-boundary-clean",
    "windows-host-compile",
    "manual-toast-proof",
    "d5-branding",
    "d8-team-identifier",
    "b3-push-strategy",
]
structs = [
    "AIChatReleaseGAScope",
    "AIChatReleaseGAReadinessGate",
    "AIChatReleaseGAApprovals",
    "AIChatReleaseGAGateState",
    "AIChatReleaseGAChecklist",
    "AIChatReleaseGAGateEvidenceRecord",
    "AIChatReleaseGASignoffRecord",
    "AIChatReleaseGAResult",
]
apis = [
    "SaveReleaseGAChecklist",
    "RecordGateEvidence",
    "RecordReleaseSignoff",
    "IsChecklistIdAllowed",
    "IsReleaseScopeShapeAllowed",
    "IsReleaseGateRosterAllowed",
    "IsReleaseApprovalsShapeAllowed",
    "IsReleaseChecklistShapeAllowed",
    "IsGateEvidenceRecordShapeAllowed",
    "IsReleaseSignoffRecordShapeAllowed",
    "MakeReleaseGAChecklistId",
    "MakeReleaseGAChecklistHashReference",
    "MakeGateEvidenceRecordId",
    "MakeReleaseSignoffId",
]

checks = {
    "runtime class": "class AIChatReleaseGARuntime final" in hxx,
    "runtime structs": all(f"struct {name}" in hxx for name in structs),
    "result shape": "struct AIChatReleaseGAResult" in hxx and "Success" in hxx and "Message" in hxx,
    "public api": all(api in hxx + cxx for api in apis),
    "compiled": "sfx2/source/sidebar/AIChatReleaseGARuntime" in mk,
    "uses tenant": "AIChatTenantContextRuntime" in hxx + cxx and "ValidateActionScope" in cxx,
    "uses audit": "AIChatAuditLogRuntime" in cxx and "IsTimestampAllowed" in cxx,
    "uses metadata hash": "AIChatKnowledgeIndexStore::MakeMetadataHash" in cxx,
    "storage sidecar": "kqoffice-v3-ai-release-ga" in cxx and "release-ga.tsv" in cxx,
    "append only": "AppendUtf8Line" in cxx and "setPos(osl_Pos_Absolut, nSize)" in cxx,
    "store records": "release-ga-checklist" in cxx and "release-ga-gate-evidence" in cxx and "release-ga-signoff" in cxx,
    "checklist id": 'rChecklistId.startsWith(u"relga-"_ustr)' in cxx and "MakeReleaseGAChecklistId" in cxx,
    "record ids": 'rRecord.RecordId.startsWith(u"rge-"_ustr)' in cxx and 'rRecord.SignoffId.startsWith(u"rgs-"_ustr)' in cxx,
    "scope": "product=kqoffice-v3" in cxx and "releasePhase=ga-blocking-contract" in cxx and "defaultDataBoundary=local-first" in cxx,
    "platform roster": all(x in cxx for x in ['u"macos"_ustr', 'u"windows"_ustr', 'u"linux"_ustr', 'u"self-hosted"_ustr']) and fixture["gaScope"]["supportedPlatforms"] == ["macos", "windows", "linux", "self-hosted"],
    "gate roster": all(gate in cxx for gate in expected_gate_ids) and [gate["id"] for gate in fixture["readinessGates"]] == expected_gate_ids,
    "gate count": "gates=16" in cxx and 'OUString::number(static_cast<sal_Int32>(aChecklist.ReadinessGates.size()))' in cxx,
    "pending statuses": "source-archive-clean" in cxx and "pending-release-decision" in cxx and "windows-toast-proof" in cxx and "pending-runtime" in cxx and "release-policy-decisions" in cxx,
    "gate owners": all(x in cxx for x in ['u"qa-owner"_ustr', 'u"release-owner"_ustr', 'u"repo-owner"_ustr', 'u"runtime-owner"_ustr']),
    "gate evidence": all(ev in cxx for ev in gate_evidence),
    "base evidence": all(ev in cxx for ev in base_evidence),
    "approvals": "HumanApprovalRequired" in hxx and "humanApprovalRequired=true" in cxx and "AutomatedApprovalAllowed" in hxx and "automatedApprovalAllowed=false" in cxx and "signoffEvidenceRequired=true" in cxx,
    "approver order": 'rApprovals.Approvers[0] == u"repo-owner"_ustr' in cxx and 'rApprovals.Approvers[1] == u"release-owner"_ustr' in cxx and 'rApprovals.Approvers[2] == u"qa-owner"_ustr' in cxx,
    "can ship locked false": "CanShip = false" in hxx and "canShip=false" in cxx and '"canShip"' in release_schema_text and '"const": false' in release_schema_text,
    "blocking gate": "BlocksGA = true" in hxx and "blocksGA=true" in cxx and '"blocksGA"' in release_schema_text,
    "explicit authorization": "RequiresExplicitUserAuthorization" in hxx and "requiresExplicitUserAuthorization=true" in cxx,
    "runtime not started": 'RuntimeImplementation == u"not-started"_ustr' in cxx and "runtimeImplementation=not-started" in cxx and '"runtimeImplementation": "not-started"' in valid_fixture.read_text(),
    "no runtime side effects": all(x in hxx for x in ["ArtifactPublishingRuntimeActive", "CodeSigningRuntimeActive", "NotarizationSubmissionRuntimeActive", "UpdateChannelPublicationRuntimeActive", "ReleaseUploadRuntimeActive", "ExternalMetricUploadRuntimeActive", "PublicNetworkRuntimeActive"]) and all(x in cxx for x in ["artifact-publishing-runtime=not-started", "code-signing-runtime=not-started", "notarization-submission=not-started", "update-channel-publication=not-started", "release-upload=not-started", "telemetry-upload=not-started", "public-network=not-started"]),
    "checklist refs": all(x in cxx for x in ["tenant-context:", "policy-context:", "audit-chain:", "distribution-recovery:", "perf-crash:", "localcloud-no-egress:", "v2-regression:", "v3-self-test:", "v3-only:", "source-archive:", "windows-toast-proof:", "release-policy-decisions:", "release-evidence:"]),
    "gate evidence refs": all(x in cxx for x in ["evidence-record:", "test-evidence:", "manual-evidence:", "artifact-ref:", "signing-ref:", "update-channel:", "recovery-proof:", "policy-decision:"]),
    "signoff refs": all(x in cxx for x in ["human-approval:", "release-signoff:", "artifact-bundle:", "artifact-bundle-ref=", "human-approval-ref=", "release-signoff-ref="]),
    "gate record message": "release-ga-gate-evidence-recorded" in cxx and "gateStatus=green" in cxx and "gateGreen=true" in cxx and "publicEgressRequired=false" in cxx,
    "signoff message": "release-ga-signoff-recorded" in cxx and "humanApprovalRecorded=true" in cxx and "automatedApproval=false" in cxx and "releasePublished=false" in cxx,
    "fail closed": "release-ga-denied reason=" in cxx and "fail-closed-user-visible=true" in cxx,
    "metadata only messages": "metadata-only=true" in cxx and "raw-release-payload=false" in cxx and "raw-evidence-payload=false" in cxx and "raw-signoff-payload=false" in cxx,
    "tenant target": 'rTargetType == u"release-ga-checklist"_ustr' in tenant and 'rSurface == u"release-ga-checklist"_ustr' in tenant,
    "policy target": 'rTargetType == u"release-ga-checklist"_ustr' in policy and '"release-ga-checklist"' in policy_schema_text,
    "release schema": '"v3-release-ga-checklist/0.1"' in release_schema_text and '"ga-blocking-contract"' in release_schema_text and '"local-first"' in release_schema_text and '"release-signoff"' in release_schema_text,
    "release contract": "tests/v3-release-ga-checklist-test.sh" in release_contract_text and "Release contract: GA-blocking checklist, human approval, canShip=false" in release_contract_text,
    "w9 link": "release-ga-checklist self-test" in w9_text and "human approval" in w9_text and "canShip=false" in w9_text,
    "distribution link": "AIChatDistributionRecoveryRuntime" in distribution_text and "distribution-update-policy-saved" in distribution_text and "error-recovery-ux-policy-saved" in distribution_text,
    "perf crash link": "AIChatPerfCrashRuntime" in perf_text and "perf-baseline-target-saved" in perf_text and "crash-recovery-target-saved" in perf_text,
    "tenant regression": "AIChatTenantContextRuntime" in tenant_test_text and "release-ga-checklist" in tenant_test_text,
    "policy regression": "AIChatPolicyEngineRuntime" in policy_test_text and "release-ga-checklist" in policy_test_text,
    "no egress regression": "public egress requires explicit opt-in" in no_egress_text or "allowPublicEgress=false" in no_egress_text,
    "in app umbrella unchanged": "v3-agent-failure-recovery-runtime-test.sh" in in_app_text,
    "todo m7.7 pending or complete": "- [ ] M7.7 Release GA checklist." in todo_text or "- [x] M7.7 Release GA checklist." in todo_text,
    "todo m7.7 slice": (
        ("Start M7.7" in todo_text and "tests/v3-release-ga-runtime-test.sh" in todo_text)
        or (
            "- [x] M7.7 Release GA checklist." in todo_text
            and "tests/v3-release-ga-runtime-test.sh" in todo_text
            and "Completed runtime foundation: M1.1-M7.7." in todo_text
        )
    ),
    "no raw document": "DocumentText" not in combined and "RawDocumentContent" not in combined and "storesDocumentContent=true" not in combined,
    "no raw prompt": "RawPrompt" not in combined and "PromptText" not in combined,
    "no raw release payload true": "raw-release-payload=true" not in combined and "raw-evidence-payload=true" not in combined and "raw-signoff-payload=true" not in combined,
    "no public egress true": "publicEgress=true" not in combined and "PublicEgressRequired = true" not in combined,
    "no can ship true": "canShip=true" not in combined and "CanShip = true" not in combined,
    "no automated approval true": "automatedApprovalAllowed=true" not in combined and "AutomatedApprovalAllowed = true" not in combined and "AutomatedApproval = true" not in combined,
    "no publish true": "releasePublished=true" not in combined and "ReleasePublished = true" not in combined,
    "no release publisher": "ReleasePublisher" not in combined and "PublishRelease" not in combined and "UploadRelease" not in combined,
    "no signing executor": "CodeSigner" not in combined and "SignArtifact" not in combined and "SubmitNotarization" not in combined,
    "no update publisher": "UpdateChannelPublisher" not in combined and "PublishUpdateChannel" not in combined,
    "no telemetry": "TelemetryClient" not in combined and "TelemetryUpload" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no webview": "WebView" not in combined and "webview=true" not in combined,
    "no apply execution": "ApplyPlan(" not in combined and "ExecuteList" not in combined,
    "no main doc write": "mainDocumentChanged=true" not in combined and "main-document-write=true" not in combined,
    "no sqlite/vector": "sqlite" not in combined.lower() and "lancedb" not in combined.lower() and "VectorStore" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 release GA runtime self-test passed. Checks: {len(checks)}")
PY
