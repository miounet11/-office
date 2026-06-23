#!/usr/bin/env bash
# V3 W6/M5.3 - Agent ShadowDoc metadata bridge runtime smoke.

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

bridge_hxx = src / "sfx2/source/sidebar/AIChatAgentShadowDocBridge.hxx"
bridge_cxx = src / "sfx2/source/sidebar/AIChatAgentShadowDocBridge.cxx"
task_hxx = src / "sfx2/source/sidebar/AIChatAgentTaskStateStore.hxx"
task_cxx = src / "sfx2/source/sidebar/AIChatAgentTaskStateStore.cxx"
registry_cxx = src / "sfx2/source/sidebar/AIChatContentRegistry.cxx"
provenance_cxx = src / "sfx2/source/sidebar/AIChatSourceProvenance.cxx"
review_cxx = src / "sfx2/source/sidebar/AIChatContentReviewStore.cxx"
preview_cxx = src / "sfx2/source/sidebar/AIChatPreviewMatrix.cxx"
opener_cxx = src / "sfx2/source/sidebar/AIChatContentOpener.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
shadow_policy = repo / "docs/product/v3/w6-shadow-doc-policy.md"
agent_plan_schema = repo / "docs/schemas/agent-step-plan.schema.json"
agent_result_schema = repo / "docs/schemas/agent-step-result.schema.json"
apply_schema = repo / "docs/schemas/apply-plan-runtime.schema.json"
agent_plan_test = repo / "tests/v3-agent-step-plan-test.sh"
agent_result_test = repo / "tests/v3-agent-step-result-state-test.sh"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"
in_app = repo / "tests/v3-in-app-chat-test.sh"

for path in [
    bridge_hxx,
    bridge_cxx,
    task_hxx,
    task_cxx,
    registry_cxx,
    provenance_cxx,
    review_cxx,
    preview_cxx,
    opener_cxx,
    library_mk,
    shadow_policy,
    agent_plan_schema,
    agent_result_schema,
    apply_schema,
    agent_plan_test,
    agent_result_test,
    todo,
    in_app,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = bridge_hxx.read_text()
cxx = bridge_cxx.read_text()
task = task_hxx.read_text() + task_cxx.read_text()
registry = registry_cxx.read_text()
provenance = provenance_cxx.read_text()
review = review_cxx.read_text()
preview = preview_cxx.read_text()
opener = opener_cxx.read_text()
mk = library_mk.read_text()
shadow_text = shadow_policy.read_text()
plan_schema_text = agent_plan_schema.read_text()
result_schema_text = agent_result_schema.read_text()
apply_schema_text = apply_schema.read_text()
agent_plan_test_text = agent_plan_test.read_text()
agent_result_test_text = agent_result_test.read_text()
todo_text = todo.read_text()
in_app_text = in_app.read_text()
combined = hxx + cxx


def strip_leading_block_comments(text: str) -> str:
    body = text.lstrip()
    while body.startswith("/*") and "*/" in body:
        body = body.split("*/", 1)[1].lstrip()
    return body


cxx_body = strip_leading_block_comments(cxx)

request_fields = [
    "TaskId",
    "StepIndex",
    "OwnerSurface",
    "ShadowBranchId",
    "ApplyPlanRuntimeRef",
    "ApplyPlanSchemaVersion",
    "DocumentSnapshotHash",
    "ShadowSnapshotRef",
    "DiffHashReference",
    "EvidenceId",
    "AuditReplayRef",
    "ApplyPlanRuntimeValidated",
    "MainDocumentUnchanged",
    "UserApprovedMerge",
]

checks = {
    "shadow policy": "per-step-compatible-branch" in shadow_text and "v2-w3-swdocshell" in shadow_text and "Runtime shadow doc implementation" in shadow_text and "not-started" in shadow_text,
    "agent schemas": "shadow-doc" in plan_schema_text and "apply-plan-runtime" in result_schema_text and "shadow-doc-diff" in result_schema_text,
    "apply plan schema": "v2-w3-runtime-1" in apply_schema_text and "doc_snapshot_hash" in apply_schema_text and "preview_only" in apply_schema_text,
    "agent tests": "PATCH_EVIDENCE" in agent_plan_test_text and "shadow-doc-diff" in agent_result_test_text,
    "bridge class": "class AIChatAgentShadowDocBridge final" in hxx,
    "request struct": "struct AIChatAgentShadowDocRequest" in hxx,
    "result struct": "struct AIChatAgentShadowDocResult" in hxx,
    "request fields": all(field in hxx for field in request_fields),
    "compiled": "sfx2/source/sidebar/AIChatAgentShadowDocBridge" in mk,
    "prepare api": "PreparePatchStep" in hxx + cxx,
    "request guard": "IsShadowDocRequestAllowed" in hxx + cxx and "ApplyPlanRuntimeValidated" in cxx and "!rRequest.UserApprovedMerge" in cxx,
    "apply ref guard": "IsApplyPlanRuntimeRefAllowed" in hxx + cxx and "aprt-" in cxx,
    "snapshot guard": "IsDocumentSnapshotHashAllowed" in hxx + cxx and "sha256:" in cxx,
    "shadow snapshot guard": "IsShadowSnapshotRefAllowed" in hxx + cxx and "shadow-snapshot:" in cxx,
    "task state guard": "IsTaskStateShapeAllowed(rCurrentState)" in cxx and 'rCurrentState.State == u"running"_ustr' in cxx and 'rCurrentState.State == u"awaiting-review"_ustr' in cxx,
    "schema guard": 'rRequest.ApplyPlanSchemaVersion == u"v2-w3-runtime-1"_ustr' in cxx,
    "main doc unchanged guard": "rRequest.MainDocumentUnchanged" in cxx and "mainDocumentUnchanged=true" in cxx,
    "step result patch": 'aResult.StepResult.Kind = u"patch"_ustr' in cxx and 'aResult.StepResult.OutputKind = u"apply-plan-runtime"_ustr' in cxx and 'aResult.StepResult.OutputSchemaRef = u"apply-plan-runtime"_ustr' in cxx,
    "step result evidence": "shadow-doc-diff" in cxx and "apply-plan-runtime-validated" in cxx and "policy-decision" in cxx and "audit-log-entry" in cxx,
    "task state awaiting": 'aNext.State = u"awaiting-review"_ustr' in cxx and 'aNext.CoworkTaskState = u"awaiting-review"_ustr' in cxx,
    "checkpoint": "MakeCheckpointId" in cxx and "EvidenceCompleteCheckpoint = true" in cxx and "ShadowSnapshotRef" in cxx and "AuditReplayRef" in cxx,
    "state shape validation": "IsStepResultAllowed(aResult.StepResult)" in cxx and "IsTaskStateShapeAllowed(aResult.TaskState)" in cxx and "invalid-step-or-task-state" in cxx,
    "state persistence": "AIChatAgentTaskStateStore aTaskStateStore" in cxx and "aTaskStateStore.RecordStepResult(aResult.StepResult)" in cxx and "aTaskStateStore.RecordTaskState(aResult.TaskState)" in cxx,
    "state write fail closed": "step-result-write-failed" in cxx and "task-state-write-failed" in cxx,
    "registry task step": 'aResult.RegistryEntry.Type = u"task-step"_ustr' in cxx and 'aResult.RegistryEntry.SourceSurface = u"agent-shadow-doc"_ustr' in cxx and 'aResult.RegistryEntry.OpenTarget = u"diff-review"_ustr' in cxx and 'aResult.RegistryEntry.PreviewMode = u"diff-preview"_ustr' in cxx,
    "registry write": "AIChatContentRegistry aRegistry" in cxx and "aRegistry.RegisterObject" in cxx,
    "provenance": "AIChatSourceProvenanceEntry aSource" in cxx and "AIChatSourceProvenance aProvenance" in cxx and "span:shadow-doc-step:" in cxx,
    "w1 task step supported": "task-step" in review and 'rEntry.Type == u"task-step"_ustr' in preview and "diff-review" in opener,
    "success message": "agent-shadow-doc-prepared task-id=" in cxx and "task-state=awaiting-review" in cxx and "step-result-recorded=true" in cxx and "task-state-recorded=true" in cxx,
    "compat message": "shadow-doc-mode=per-step-compatible-branch" in cxx and "writer-compatibility=v2-w3-swdocshell" in cxx and "creates-new-docshell=false" in cxx,
    "apply validation message": "apply-plan-schema=v2-w3-runtime-1" in cxx and "applyPlanRuntimeValidated=true" in cxx,
    "token lock message": "ParagraphAction:7" in cxx and "CellAction:5" in cxx and "SlideElementAction:4" in cxx,
    "no merge message": "mergeRequiresApproval=true" in cxx and "userApprovedMerge=false" in cxx,
    "metadata message": "storesDocumentContent=false" in cxx and "raw-apply-plan=false" in cxx and "raw-diff=false" in cxx and "metadata-only=true" in cxx,
    "runtime not started": "runtimeShadowDocImplementation=not-started" in cxx,
    "task state foundation": "class AIChatAgentTaskStateStore final" in task and "RecordStepResult" in task and "RecordTaskState" in task,
    "in app runs shadow smoke": "v3-agent-shadow-doc-runtime-test.sh" in in_app_text,
    "todo records m5.3 complete": "- [x] M5.3 Integrate ShadowDoc" in todo_text and "Follow-up task id: M5.4" in todo_text,
    "no raw apply plan": "RawApplyPlan" not in combined and "ApplyPlanPayload" not in combined,
    "no raw diff": "RawDiff" not in combined and "DiffBody" not in combined,
    "no document content": "RawDocumentContent" not in combined and "DocumentText" not in combined and "storesDocumentContent=true" not in combined,
    "no main doc mutation api": "ScDoc" not in combined and "SdDrawDocument" not in combined and "GetDoc()" not in combined and "SetModified" not in combined,
    "no new docshell api": "new DocShell" not in combined and "new-w6-docshell" not in combined and "SwDocShell*" not in combined and "SwDocShell&" not in combined,
    "no apply execution": "ExecuteList" not in combined and "ApplyPlan(" not in combined and "applyDiagnosticsPlan" not in combined,
    "no llm/model runtime": "LLM" not in combined and "ModelDownloader" not in combined and "EmbeddingPipeline" not in combined,
    "no vector/sql runtime": "sqlite3" not in combined and "lancedb" not in combined.lower() and "VectorBackend" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no webview": "WebView" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 agent ShadowDoc bridge runtime self-test passed. Checks: {len(checks)}")
PY
