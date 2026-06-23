#!/usr/bin/env bash
# V3 W9/M7.6 - perf/crash metadata runtime smoke.

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

runtime_hxx = src / "sfx2/source/sidebar/AIChatPerfCrashRuntime.hxx"
runtime_cxx = src / "sfx2/source/sidebar/AIChatPerfCrashRuntime.cxx"
distribution_cxx = src / "sfx2/source/sidebar/AIChatDistributionRecoveryRuntime.cxx"
tenant_hxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.hxx"
tenant_cxx = src / "sfx2/source/sidebar/AIChatTenantContextRuntime.cxx"
policy_cxx = src / "sfx2/source/sidebar/AIChatPolicyEngineRuntime.cxx"
audit_cxx = src / "sfx2/source/sidebar/AIChatAuditLogRuntime.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
perf_schema = repo / "docs/schemas/perf-baseline-targets.schema.json"
crash_schema = repo / "docs/schemas/crash-recovery-targets.schema.json"
policy_schema = repo / "docs/schemas/policy-rule.schema.json"
perf_fixtures = repo / "docs/qa/fixtures/v3/perf/valid"
crash_fixtures = repo / "docs/qa/fixtures/v3/recovery/valid"
w9_spec = repo / "docs/product/v3/w9-market-readiness-spec.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"
perf_contract = repo / "tests/v3-perf-baseline-test.sh"
crash_contract = repo / "tests/v3-crash-recovery-test.sh"
distribution_runtime = repo / "tests/v3-distribution-recovery-runtime-test.sh"
tenant_test = repo / "tests/v3-tenant-context-runtime-test.sh"
policy_test = repo / "tests/v3-policy-engine-runtime-test.sh"
no_egress_test = repo / "tests/v3-local-cloud-no-egress-test.sh"
in_app = repo / "tests/v3-in-app-chat-test.sh"

for path in [
    runtime_hxx,
    runtime_cxx,
    distribution_cxx,
    tenant_hxx,
    tenant_cxx,
    policy_cxx,
    audit_cxx,
    library_mk,
    perf_schema,
    crash_schema,
    policy_schema,
    perf_fixtures,
    crash_fixtures,
    w9_spec,
    todo,
    perf_contract,
    crash_contract,
    distribution_runtime,
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
distribution = distribution_cxx.read_text()
tenant = tenant_hxx.read_text() + tenant_cxx.read_text()
policy = policy_cxx.read_text()
audit = audit_cxx.read_text()
mk = library_mk.read_text()
perf_schema_text = perf_schema.read_text()
crash_schema_text = crash_schema.read_text()
policy_schema_text = policy_schema.read_text()
w9_text = w9_spec.read_text()
todo_text = todo.read_text()
perf_contract_text = perf_contract.read_text()
crash_contract_text = crash_contract.read_text()
distribution_runtime_text = distribution_runtime.read_text()
tenant_test_text = tenant_test.read_text()
policy_test_text = policy_test.read_text()
no_egress_text = no_egress_test.read_text()
in_app_text = in_app.read_text()
perf_values = [json.loads(path.read_text()) for path in sorted(perf_fixtures.glob("*.json"))]
crash_values = [json.loads(path.read_text()) for path in sorted(crash_fixtures.glob("*.json"))]


def strip_leading_block_comments(text: str) -> str:
    body = text.lstrip()
    while body.startswith("/*") and "*/" in body:
        body = body.split("*/", 1)[1].lstrip()
    return body


cxx_body = strip_leading_block_comments(cxx)

perf_structs = [
    "AIChatPerfColdStartTarget",
    "AIChatPerfFirstTokenTarget",
    "AIChatPerfRetrievalTarget",
    "AIChatPerfGateState",
    "AIChatPerfBaselineTarget",
    "AIChatPerfSampleRecord",
]
crash_structs = [
    "AIChatCrashTriggerTarget",
    "AIChatUnsavedEditTarget",
    "AIChatAutosaveTarget",
    "AIChatRecoveryDialogTarget",
    "AIChatCrashRecoveryScenarioTarget",
    "AIChatCrashGateState",
    "AIChatCrashRecoveryTarget",
    "AIChatCrashRecoverySampleRecord",
]
apis = [
    "SavePerfBaselineTarget",
    "RecordPerfSample",
    "SaveCrashRecoveryTarget",
    "RecordCrashRecoverySample",
    "IsPerfTargetIdAllowed",
    "IsCrashTargetIdAllowed",
    "IsPlatformAllowed",
    "IsPackageRouteAllowedForPlatform",
    "IsPerfRequiredEvidenceAllowed",
    "IsCrashRequiredEvidenceAllowed",
    "IsDocumentSurfaceAllowedForPlatform",
    "IsEditKindAllowedForSurface",
    "IsPerfTargetShapeAllowed",
    "IsPerfSampleRecordShapeAllowed",
    "IsCrashRecoveryTargetShapeAllowed",
    "IsCrashRecoverySampleRecordShapeAllowed",
    "MakePerfTargetId",
    "MakeCrashTargetId",
    "MakePerfTargetHashReference",
    "MakeCrashTargetHashReference",
    "MakePerfSampleId",
    "MakeCrashSampleId",
]
perf_platforms = {value["platform"] for value in perf_values}
perf_routes = {value["platform"]: value["workload"]["coldStart"]["packageRoute"] for value in perf_values}
crash_platforms = {value["platform"] for value in crash_values}
crash_surfaces = {value["scenario"]["documentSurface"] for value in crash_values}
crash_edits = {value["scenario"]["documentSurface"]: value["scenario"]["unsavedEdit"]["editKind"] for value in crash_values}

checks = {
    "runtime class": "class AIChatPerfCrashRuntime final" in hxx,
    "perf structs": all(f"struct {name}" in hxx for name in perf_structs),
    "crash structs": all(f"struct {name}" in hxx for name in crash_structs),
    "result struct": "struct AIChatPerfCrashResult" in hxx and "Success" in hxx and "Message" in hxx,
    "public api": all(api in hxx + cxx for api in apis),
    "compiled": "sfx2/source/sidebar/AIChatPerfCrashRuntime" in mk,
    "uses tenant": "AIChatTenantContextRuntime" in hxx + cxx and "ValidateActionScope" in cxx,
    "uses audit": "AIChatAuditLogRuntime" in cxx and "AIChatAuditLogRuntime" in audit,
    "uses metadata hash": "AIChatKnowledgeIndexStore::MakeMetadataHash" in cxx,
    "storage sidecar": "kqoffice-v3-ai-perf-crash" in cxx and "perf-crash.tsv" in cxx,
    "append only": "AppendUtf8Line" in cxx and "setPos(osl_Pos_Absolut, nSize)" in cxx,
    "store records": "perf-baseline-target" in cxx and "perf-sample" in cxx and "crash-recovery-target" in cxx and "crash-recovery-sample" in cxx,
    "perf schema": '"perf-baseline"' in perf_schema_text and '"main-window-interactive"' in perf_schema_text and '"ollama-local"' in perf_schema_text and '"local-knowledge-index"' in perf_schema_text,
    "crash schema": '"crash-recovery"' in crash_schema_text and '"sigkill"' in crash_schema_text and '"RecoveryDialog"' in crash_schema_text and '"local-file-only"' in crash_schema_text,
    "perf target ids": 'rTargetId.startsWith(u"v3-perf-baseline-"_ustr)' in cxx and "MakePerfTargetId" in cxx,
    "crash target ids": 'rTargetId.startsWith(u"v3-crash-recovery-"_ustr)' in cxx and "MakeCrashTargetId" in cxx,
    "platform roster": all(x in cxx for x in ["macos-arm64", "linux-x86_64", "windows-x86_64"]) and perf_platforms == {"macos-arm64", "linux-x86_64", "windows-x86_64"} and crash_platforms == {"macos-arm64", "linux-x86_64", "windows-x86_64"},
    "package routes": "dmg" in cxx and "appimage" in cxx and "msi" in cxx and perf_routes == {"macos-arm64": "dmg", "linux-x86_64": "appimage", "windows-x86_64": "msi"},
    "perf targets": "coldStartTargetMs=2000" in cxx and "firstTokenTargetMs=800" in cxx and "retrievalTargetMs=200" in cxx and all(value["workload"]["coldStart"]["targetMs"] == 2000 and value["workload"]["firstToken"]["targetMs"] == 800 and value["workload"]["retrieval"]["targetMs"] == 200 for value in perf_values),
    "local provider": "provider=ollama-local" in cxx and "model=llama3.2:3b" in cxx and all(value["workload"]["firstToken"]["provider"] == "ollama-local" and value["workload"]["firstToken"]["model"] == "llama3.2:3b" for value in perf_values),
    "retrieval": "corpusDocuments=10000" in cxx and "topK=5" in cxx and "local-knowledge-index" in cxx and all(value["workload"]["retrieval"]["corpusDocuments"] == 10000 and value["workload"]["retrieval"]["topK"] == 5 for value in perf_values),
    "perf evidence": all(x in cxx for x in ["perf-sample", "system-profile", "local-provider-proof", "knowledge-index-sample", "policy-decision", "audit-log-entry", "distribution-update-policy", "error-recovery-ux", "localcloud-no-egress"]),
    "perf refs": "system-profile-ref=" in cxx and "local-provider-proof-ref=" in cxx and "knowledge-index-sample-ref=" in cxx,
    "perf gate": "RuntimeSamplerActive" in hxx and "ModelDownloadActive" in hxx and "ExternalMetricUploadActive" in hxx and "BackgroundProbeActive" in hxx and "runtime-sampler=not-started" in cxx and "model-download=not-started" in cxx and "telemetry-upload=not-started" in cxx,
    "perf sample message": "perf-sample-recorded" in cxx and "targetsMet=true" in cxx and "raw-perf-payload=false" in cxx and "runtime-benchmark=false" in cxx,
    "crash surfaces": crash_surfaces == {"writer", "calc", "impress"} and all(x in cxx for x in ["writer", "calc", "impress"]),
    "crash edit kinds": crash_edits == {"writer": "text-insert", "calc": "cell-edit", "impress": "slide-text-edit"} and all(x in cxx for x in ["text-insert", "cell-edit", "slide-text-edit"]),
    "crash trigger": "crashTrigger=sigkill" in cxx and "processState=editing-unsaved" in cxx and "IncludesUnsavedState" in hxx,
    "autosave": "autosaveIntervalSeconds=30" in cxx and "storage=local-file-only" in cxx and all(value["scenario"]["autosave"]["intervalSeconds"] == 30 and value["scenario"]["autosave"]["publicEgress"] is False for value in crash_values),
    "recovery dialog": "dialog=RecoveryDialog" in cxx and "recoveryDialogSeconds=30" in cxx and "oneClickRestore=true" in cxx and "diffExpected=zero" in cxx and "dataLossTolerance=none" in cxx,
    "crash evidence": all(x in cxx for x in ["autosave-snapshot", "sigkill-marker", "recovery-dialog-shown", "restore-applied", "diff-zero-proof", "policy-decision", "audit-log-entry", "distribution-update-policy", "error-recovery-ux", "localcloud-no-egress"]),
    "crash refs": "autosave-snapshot-ref=" in cxx and "sigkill-marker-ref=" in cxx and "recovery-dialog-ref=" in cxx and "restore-applied-ref=" in cxx and "diff-zero-proof-ref=" in cxx,
    "crash gate": "SigkillRunnerActive" in hxx and "AutosaveEngineRuntimeActive" in hxx and "RecoveryDialogRuntimeActive" in hxx and "CloudRecoveryRuntimeActive" in hxx and "MainDocumentWriteRuntimeActive" in hxx,
    "crash sample message": "crash-recovery-sample-recorded" in cxx and "mainDocumentChanged=false" in cxx and "raw-recovery-payload=false" in cxx and "sigkill-execution=false" in cxx,
    "shared refs": all(x in cxx for x in ["tenant-context:", "policy-context:", "audit-chain:", "distribution-recovery:", "localcloud-no-egress:", "release-evidence:"]),
    "fail closed": "perf-crash-denied reason=" in cxx and "fail-closed-user-visible=true" in cxx,
    "tenant targets": 'rTargetType == u"perf-baseline"_ustr' in tenant and 'rTargetType == u"crash-recovery"_ustr' in tenant and 'rSurface == u"perf-baseline"_ustr' in tenant and 'rSurface == u"crash-recovery"_ustr' in tenant,
    "policy targets": 'rTargetType == u"perf-baseline"_ustr' in policy and 'rTargetType == u"crash-recovery"_ustr' in policy and '"perf-baseline"' in policy_schema_text and '"crash-recovery"' in policy_schema_text,
    "distribution link": "AIChatDistributionRecoveryRuntime" in distribution_runtime_text and "distribution-update-policy-saved" in distribution,
    "contract perf": "Targets: coldStart=2000ms firstToken=800ms retrieval=200ms" in perf_contract_text and "coldStart.targetMs must be exactly 2000" in perf_contract_text and "llama3.2:3b" in perf_contract_text,
    "contract crash": "Targets: autosave=30s recoveryDialog=30s diff=0" in crash_contract_text and "autosave.intervalSeconds must be exactly 30" in crash_contract_text and "RecoveryDialog" in crash_contract_text,
    "w9 perf": "H11 perf-baseline" in w9_text and "首 token 800ms" in w9_text and "10k 文档" in w9_text,
    "w9 crash": "H12 crash-recovery" in w9_text and "RecoveryDialog" in w9_text and "diff=0" in w9_text,
    "tenant regression": "AIChatTenantContextRuntime" in tenant_test_text and "perf-baseline" in tenant and "crash-recovery" in tenant,
    "policy regression": "AIChatPolicyEngineRuntime" in policy_test_text and "perf-baseline" in policy and "crash-recovery" in policy,
    "no egress regression": "public egress requires explicit opt-in" in no_egress_text,
    "in app umbrella": "v3-agent-failure-recovery-runtime-test.sh" in in_app_text,
    "todo m7.6 pending or complete": (
        "- [ ] M7.6 Prove perf and crash recovery targets." in todo_text
        or "- [x] M7.6 Prove perf and crash recovery targets." in todo_text
    ),
    "todo m7.6 recorded": (
        ("Start M7.6" in todo_text and "tests/v3-perf-crash-runtime-test.sh" in todo_text)
        or ("- [x] M7.6 Prove perf and crash recovery targets." in todo_text and "Follow-up task id: M7.7." in todo_text)
    ),
    "no raw document": "DocumentText" not in combined and "RawDocumentContent" not in combined and "storesDocumentContent=true" not in combined,
    "no raw prompt": "RawPrompt" not in combined and "PromptText" not in combined,
    "no raw sample": "RawPerfPayload" not in combined and "RawRecoveryPayload" not in combined and "SamplePayload" not in combined,
    "no public egress true": "publicEgress=true" not in combined and "PublicEgress = true" not in combined,
    "no model downloader": "ModelDownloader" not in combined and "DownloadModel" not in combined and "hiddenModelDownload=true" not in combined,
    "no benchmark daemon": "BenchmarkDaemon" not in combined and "RunBenchmark" not in combined,
    "no crash injector": "CrashInjector" not in combined and "kill(" not in combined and "SIGKILL" not in combined,
    "no telemetry": "TelemetryClient" not in combined and "TelemetryUpload" not in combined,
    "no cloud recovery": "CloudRecoveryClient" not in combined and "cloudRecovery=true" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no webview": "WebView" not in combined and "webview=true" not in combined,
    "no apply execution": "ApplyPlan(" not in combined and "ExecuteList" not in combined,
    "no main doc write": "mainDocumentChanged=true" not in combined and "main-document-write=true" not in combined,
    "no sqlite/vector": "sqlite" not in combined.lower() and "lancedb" not in combined.lower() and "VectorStore" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 perf/crash runtime self-test passed. Checks: {len(checks)}")
PY
