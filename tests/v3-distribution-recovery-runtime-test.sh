#!/usr/bin/env bash
# V3 W9/M7.5 - distribution/update/recovery metadata runtime smoke.

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

runtime_hxx = src / "sfx2/source/sidebar/AIChatDistributionRecoveryRuntime.hxx"
runtime_cxx = src / "sfx2/source/sidebar/AIChatDistributionRecoveryRuntime.cxx"
tenant_hxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.hxx"
tenant_cxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.cxx"
policy_cxx = src / "sfx2/source/sidebar/AIChatPolicyEngineRuntime.cxx"
audit_cxx = src / "sfx2/source/sidebar/AIChatAuditLogRuntime.cxx"
edition_cxx = src / "sfx2/source/sidebar/AIChatEditionPolicyRuntime.cxx"
i18n_cxx = src / "sfx2/source/sidebar/AIChatI18nManualRuntime.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
distribution_schema = repo / "docs/schemas/distribution-update.schema.json"
recovery_schema = repo / "docs/schemas/error-recovery-ux.schema.json"
policy_schema = repo / "docs/schemas/policy-rule.schema.json"
distribution_fixture = repo / "docs/qa/fixtures/v3/distribution-update/valid/distribution-update-policy.json"
recovery_fixture = repo / "docs/qa/fixtures/v3/error-recovery-ux/valid/error-recovery-ux.json"
w9_spec = repo / "docs/product/v3/w9-market-readiness-spec.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"
distribution_contract = repo / "tests/v3-distribution-update-test.sh"
recovery_contract = repo / "tests/v3-error-recovery-ux-test.sh"
edition_runtime = repo / "tests/v3-edition-policy-runtime-test.sh"
i18n_runtime = repo / "tests/v3-i18n-manual-runtime-test.sh"
tenant_test = repo / "tests/v3-tenant-context-runtime-test.sh"
policy_test = repo / "tests/v3-policy-engine-runtime-test.sh"
no_egress_test = repo / "tests/v3-local-cloud-no-egress-test.sh"
in_app = repo / "tests/v3-in-app-chat-test.sh"

for path in [
    runtime_hxx,
    runtime_cxx,
    tenant_hxx,
    tenant_cxx,
    policy_cxx,
    audit_cxx,
    edition_cxx,
    i18n_cxx,
    library_mk,
    distribution_schema,
    recovery_schema,
    policy_schema,
    distribution_fixture,
    recovery_fixture,
    w9_spec,
    todo,
    distribution_contract,
    recovery_contract,
    edition_runtime,
    i18n_runtime,
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
edition = edition_cxx.read_text()
i18n = i18n_cxx.read_text()
mk = library_mk.read_text()
distribution_schema_text = distribution_schema.read_text()
recovery_schema_text = recovery_schema.read_text()
policy_schema_text = policy_schema.read_text()
distribution_value = json.loads(distribution_fixture.read_text())
recovery_value = json.loads(recovery_fixture.read_text())
w9_text = w9_spec.read_text()
todo_text = todo.read_text()
distribution_contract_text = distribution_contract.read_text()
recovery_contract_text = recovery_contract.read_text()
edition_runtime_text = edition_runtime.read_text()
i18n_runtime_text = i18n_runtime.read_text()
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

distribution_structs = [
    "AIChatDistributionChannel",
    "AIChatDistributionPolicy",
    "AIChatUpdatePolicy",
    "AIChatDistributionOnboardingPolicy",
    "AIChatDistributionUpdateGateState",
    "AIChatDistributionUpdateManifest",
    "AIChatUpdateRollbackSmokeRecord",
]
recovery_structs = [
    "AIChatErrorRecoveryPolicy",
    "AIChatErrorRecoveryScenario",
    "AIChatErrorRecoveryGateState",
    "AIChatErrorRecoveryUxManifest",
    "AIChatRecoveryActionRecord",
]
apis = [
    "SaveDistributionUpdatePolicy",
    "RecordUpdateRollbackSmoke",
    "SaveErrorRecoveryUxPolicy",
    "RecordRecoveryAction",
    "IsDistributionManifestIdAllowed",
    "IsErrorRecoveryManifestIdAllowed",
    "IsTimestampAllowed",
    "IsPlatformArtifactAllowed",
    "IsDistributionChannelOrderAllowed",
    "IsDistributionRequiredEvidenceAllowed",
    "IsErrorRecoveryRequiredEvidenceAllowed",
    "IsRecoveryKindAllowed",
    "IsRecoverySurfaceAllowed",
    "IsNextStepAllowed",
    "IsSmokeKindAllowed",
    "IsDistributionPolicyShapeAllowed",
    "IsUpdatePolicyShapeAllowed",
    "IsDistributionManifestShapeAllowed",
    "IsUpdateRollbackSmokeRecordShapeAllowed",
    "IsErrorRecoveryPolicyShapeAllowed",
    "IsErrorRecoveryScenarioOrderAllowed",
    "IsErrorRecoveryUxManifestShapeAllowed",
    "IsRecoveryActionRecordShapeAllowed",
    "MakeDistributionManifestId",
    "MakeErrorRecoveryManifestId",
    "MakeDistributionHashReference",
    "MakeErrorRecoveryHashReference",
    "MakeSmokeRecordId",
    "MakeRecoveryActionId",
]
distribution_channels = [
    (channel["platform"], channel["artifact"])
    for channel in distribution_value["distribution"]["firstLaunchChannels"]
]
recovery_kinds = [scenario["kind"] for scenario in recovery_value["scenarios"]]
recovery_surfaces = {scenario["surface"] for scenario in recovery_value["scenarios"]}
all_recovery_steps = {step for scenario in recovery_value["scenarios"] for step in scenario["nextSteps"]}

checks = {
    "runtime class": "class AIChatDistributionRecoveryRuntime final" in hxx,
    "distribution structs": all(f"struct {name}" in hxx for name in distribution_structs),
    "recovery structs": all(f"struct {name}" in hxx for name in recovery_structs),
    "result struct": "struct AIChatDistributionRecoveryResult" in hxx and "Success" in hxx and "Message" in hxx,
    "public api": all(api in hxx + cxx for api in apis),
    "compiled": "sfx2/source/sidebar/AIChatDistributionRecoveryRuntime" in mk,
    "uses tenant": "AIChatTenantContextRuntime" in hxx + cxx and "ValidateActionScope" in cxx,
    "uses audit timestamp": "AIChatAuditLogRuntime::IsTimestampAllowed" in cxx,
    "uses metadata hash": "AIChatKnowledgeIndexStore::MakeMetadataHash" in cxx,
    "storage sidecar": "kqoffice-v3-ai-distribution-recovery" in cxx and "distribution-recovery.tsv" in cxx,
    "append only": "AppendUtf8Line" in cxx and "setPos(osl_Pos_Absolut, nSize)" in cxx,
    "store records": "distribution-update-policy" in cxx and "update-rollback-smoke" in cxx and "error-recovery-ux-policy" in cxx and "recovery-action" in cxx,
    "distribution schema version": "v3-distribution-update/0.1" in cxx and '"v3-distribution-update/0.1"' in distribution_schema_text,
    "recovery schema version": "v3-error-recovery-ux/0.1" in cxx and '"v3-error-recovery-ux/0.1"' in recovery_schema_text,
    "distribution id": 'rManifestId.startsWith(u"dist-"_ustr)' in cxx and "MakeDistributionManifestId" in cxx,
    "recovery id": 'rManifestId.startsWith(u"errux-"_ustr)' in cxx and "MakeErrorRecoveryManifestId" in cxx,
    "distribution channels": all(x in cxx for x in ["macos", "DMG", "windows", "MSI", "linux", "AppImage", "self-hosted", "docker"]) and "IsDistributionChannelOrderAllowed" in cxx,
    "fixture distribution channels": distribution_channels == [("macos", "DMG"), ("windows", "MSI"), ("linux", "AppImage"), ("self-hosted", "docker")],
    "signing checksum notarization": "ArtifactSigningRequired" in hxx and "ChecksumRequired" in hxx and "NotarizationRequired" in hxx and "artifactSigningRequired=true" in cxx and "checksumRequired=true" in cxx and "notarizationRequired=true" in cxx,
    "offline no public cloud": "OfflineInstallSupported" in hxx and "NoPublicCloudRequired" in hxx and "offlineInstallSupported=true" in cxx and "noPublicCloudRequired=true" in cxx,
    "first patch": "DownloadToFirstPatchMaxMinutes" in hxx and "DownloadToFirstPatchMinutes" in hxx and "downloadToFirstPatchMaxMinutes=5" in cxx and "downloadToFirstPatchMinutes=5" in cxx,
    "update prompt one click": "prompt-one-click" in cxx and "PromptRequired" in hxx and "OneClick" in hxx and "Deferrable" in hxx and "promptRequired=true" in cxx and "oneClick=true" in cxx and "deferrable=true" in cxx,
    "no force update": "ForceUpdateAllowed" in hxx and "!rPolicy.ForceUpdateAllowed" in cxx and "forceUpdateAllowed=false" in cxx,
    "self host update": "SelfHostServer" in hxx and "w8-update-server" in cxx,
    "lan no public internet": "LanSupported" in hxx and "PublicInternetRequired" in hxx and "lanSupported=true" in cxx and "publicInternetRequired=false" in cxx,
    "rollback": "RollbackRequired" in hxx and "RollbackProofRef" in hxx and "rollbackRequired=true" in cxx and "rollback-proof-ref=" in cxx,
    "distribution evidence": all(x in cxx for x in ["distribution-update-policy", "artifact-signature", "installer-smoke", "update-prompt", "rollback-proof", "evidence-record", "v2-regression-green", "policy-decision", "audit-log-entry", "edition-policy", "i18n-locale-policy", "manual-docs-manifest", "localcloud-no-egress"]),
    "distribution refs": all(x in cxx for x in ["tenant-context:", "policy-context:", "audit-chain:", "edition-policy:", "i18n-locale-policy:", "manual-docs:", "localcloud-no-egress:", "release-evidence:"]),
    "distribution gate": "metadata-runtime-active" in cxx and "InstallerPackagingRuntimeActive" in hxx and "UpdateServerRuntimeActive" in hxx and "NetworkDownloadRuntimeActive" in hxx and "UpdaterDaemonActive" in hxx,
    "distribution save message": "distribution-update-policy-saved" in cxx and "channels=macos/DMG,windows/MSI,linux/AppImage,self-hosted/docker" in cxx,
    "distribution smoke message": "distribution-update-smoke-recorded" in cxx and "raw-installer-payload=false" in cxx and "installer-execution=false" in cxx and "rollback-execution=false" in cxx,
    "recovery policy": "inline-guidance" in cxx and "NextStepRequired" in hxx and "EvidenceOpenable" in hxx and "DeadEndAllowed" in hxx and "MainDocumentUnchangedUntilApply" in hxx and "HumanReadableCauseRequired" in hxx,
    "recovery no dead end": "!rPolicy.DeadEndAllowed" in cxx and "deadEndAllowed=false" in cxx,
    "recovery scenario roster": recovery_kinds == ["provider-timeout", "connector-auth-expired", "policy-denied", "patch-apply-failed"] and all(x in cxx for x in recovery_kinds),
    "recovery surface coverage": recovery_surfaces == {"writer", "calc", "impress", "companion"} and all(x in cxx for x in ["writer", "calc", "impress", "companion"]),
    "next steps": all(x in cxx for x in ["retry", "choose-local-model", "reconnect-connector", "request-approval", "open-evidence", "rollback-preview", "open-help", "export-diagnostics"]) and {"retry", "reconnect-connector", "request-approval", "rollback-preview", "open-evidence", "export-diagnostics"}.issubset(all_recovery_steps),
    "open evidence diagnostics": "openableEvidence=true" in cxx and "diagnosticsExportable=true" in cxx and "ContainsString(rScenario.NextSteps, u\"open-evidence\"_ustr)" in cxx and "ContainsString(rScenario.NextSteps, u\"export-diagnostics\"_ustr)" in cxx,
    "main doc unchanged": "mainDocumentUnchangedUntilApply=true" in cxx and "mainDocumentUnchanged=true" in cxx and "documentMutationApplied=false" in cxx and "!rRecord.DocumentMutationApplied" in cxx,
    "retry rollback action": "RetryAvailable" in hxx and "RollbackAvailable" in hxx and "retryAvailable=true" in cxx and "rollbackAvailable=true" in cxx,
    "recovery evidence": all(x in cxx for x in ["error-recovery-ux", "inline-guidance", "next-step-action", "openable-evidence", "diagnostics-export", "evidence-record", "v2-regression-green", "policy-decision", "audit-log-entry", "edition-policy", "i18n-locale-policy", "manual-docs-manifest", "localcloud-no-egress"]),
    "recovery gate": "InlineGuidanceUiRuntimeActive" in hxx and "DiagnosticsExporterRuntimeActive" in hxx and "RemoteRecoveryServiceActive" in hxx and "CrashReportRuntimeActive" in hxx and "OsNotificationBridgeActive" in hxx,
    "recovery save message": "error-recovery-ux-policy-saved" in cxx and "scenarios=4" in cxx and "surfaces=writer,calc,companion,impress" in cxx,
    "recovery action message": "recovery-action-recorded" in cxx and "raw-error-payload=false" in cxx and "main-document-write=false" in cxx,
    "fail closed": "distribution-recovery-denied reason=" in cxx and "fail-closed-user-visible=true" in cxx,
    "no service messages": "installer-packaging-runtime=not-started" in cxx and "update-server-runtime=not-started" in cxx and "network-downloader-runtime=not-started" in cxx and "updater-daemon=not-started" in cxx and "remote-recovery-service=not-started" in cxx and "crash-reporter=not-started" in cxx and "os-notification-bridge=not-started" in cxx,
    "tenant distribution target": 'rTargetType == u"distribution-update"_ustr' in tenant and 'rSurface == u"distribution-update"_ustr' in tenant,
    "tenant recovery target": 'rTargetType == u"error-recovery-ux"_ustr' in tenant and 'rSurface == u"error-recovery-ux"_ustr' in tenant,
    "policy targets": 'rTargetType == u"distribution-update"_ustr' in policy and 'rTargetType == u"error-recovery-ux"_ustr' in policy and '"distribution-update"' in policy_schema_text and '"error-recovery-ux"' in policy_schema_text,
    "audit link": "AIChatAuditLogRuntime" in audit and "audit-log-entry-appended" in audit,
    "edition link": "edition-policy-saved" in edition and "edition-policy:" in cxx,
    "i18n link": "manual-docs-manifest-saved" in i18n and "i18n-locale-policy:" in cxx and "manual-docs:" in cxx,
    "distribution contract": "Checks: 8" in distribution_contract_text and "DMG/MSI/AppImage/docker" in distribution_contract_text and "prompt + one-click" in distribution_contract_text,
    "recovery contract": "Checks: 8" in recovery_contract_text and "inline guidance" in recovery_contract_text and "openable evidence" in recovery_contract_text,
    "w9 spec distribution": "distribution-update self-test" in w9_text and "DMG / MSI / AppImage / docker" in w9_text and "prompt + one-click" in w9_text,
    "w9 spec recovery": "error-recovery-ux self-test" in w9_text and "inline guidance" in w9_text and "openable evidence" in w9_text,
    "schema distribution": '"forceUpdateAllowed"' in distribution_schema_text and '"const": false' in distribution_schema_text and '"publicInternetRequired"' in distribution_schema_text,
    "schema recovery": '"deadEndAllowed"' in recovery_schema_text and '"const": false' in recovery_schema_text and '"mainDocumentUnchangedUntilApply"' in recovery_schema_text,
    "fixture update": distribution_value["update"]["forceUpdateAllowed"] is False and distribution_value["update"]["publicInternetRequired"] is False and distribution_value["update"]["selfHostServer"] == "w8-update-server",
    "fixture recovery": recovery_value["policy"]["deadEndAllowed"] is False and recovery_value["policy"]["mainDocumentUnchangedUntilApply"] is True,
    "regression edition": "AIChatEditionPolicyRuntime" in edition_runtime_text,
    "regression i18n": "AIChatI18nManualRuntime" in i18n_runtime_text,
    "tenant runtime regression": "distribution-update" in tenant_test_text and "error-recovery-ux" in tenant_test_text,
    "policy runtime regression": "distribution-update" in policy_test_text and "error-recovery-ux" in policy_test_text,
    "no egress regression": "public egress requires explicit opt-in" in no_egress_text,
    "in app umbrella": "v3-agent-failure-recovery-runtime-test.sh" in in_app_text,
    "todo m7.5 pending or complete": (
        "- [ ] M7.5 Finalize distribution/update/recovery." in todo_text
        or "- [x] M7.5 Finalize distribution/update/recovery." in todo_text
    ),
    "todo m7.5 recorded": (
        ("Start M7.5" in todo_text and "tests/v3-distribution-recovery-runtime-test.sh" in todo_text)
        or ("- [x] M7.5 Finalize distribution/update/recovery." in todo_text and "Follow-up task id: M7.6." in todo_text)
    ),
    "no raw document": "DocumentText" not in combined and "RawDocumentContent" not in combined and "storesDocumentContent=true" not in combined,
    "no raw prompt": "RawPrompt" not in combined and "PromptText" not in combined,
    "no raw update": "RawUpdatePayload" not in combined and "InstallerPayload" not in combined and "UpdatePayload" not in combined,
    "no forced update": "forceUpdateAllowed=true" not in combined and "Forced = true" not in combined,
    "no public internet true": "publicInternetRequired=true" not in combined and "publicEgress=true" not in combined and "requiresPublicInternet=true" not in combined,
    "no installer runtime": "InstallerRunner" not in combined and "PackageBuilder" not in combined and "RunInstaller" not in combined,
    "no update daemon": "UpdateDaemon" not in combined and "Sparkle" not in combined and "WinSparkle" not in combined,
    "no updater network": "HttpClient" not in combined and "DownloadClient" not in combined and "FetchUpdate" not in combined,
    "no recovery service": "RemoteRecoveryClient" not in combined and "CrashReporterClient" not in combined and "Telemetry" not in combined,
    "no os notification bridge": "NSUserNotification" not in combined and "ToastNotification" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no webview": "WebView" not in combined and "webview=true" not in combined,
    "no connector writeback": "WriteBack" not in combined and "writeScopes" not in combined,
    "no apply execution": "ApplyPlan(" not in combined and "ExecuteList" not in combined,
    "no sqlite/vector/model": "sqlite" not in combined.lower() and "lancedb" not in combined.lower() and "VectorStore" not in combined and "ModelRuntime" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 distribution/recovery runtime self-test passed. Checks: {len(checks)}")
PY
