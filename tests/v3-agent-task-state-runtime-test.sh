#!/usr/bin/env bash
# V3 W6/M5.2 - Agent task state metadata store runtime smoke.

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

store_hxx = src / "sfx2/source/sidebar/AIChatAgentTaskStateStore.hxx"
store_cxx = src / "sfx2/source/sidebar/AIChatAgentTaskStateStore.cxx"
planner_hxx = src / "sfx2/source/sidebar/AIChatAgentPlannerRuntime.hxx"
planner_cxx = src / "sfx2/source/sidebar/AIChatAgentPlannerRuntime.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
result_schema = repo / "docs/schemas/agent-step-result.schema.json"
state_schema = repo / "docs/schemas/agent-task-state.schema.json"
agent_result_test = repo / "tests/v3-agent-step-result-state-test.sh"
agent_plan_test = repo / "tests/v3-agent-step-plan-test.sh"
resume_policy = repo / "docs/product/v3/w6-resume-policy.md"
approval_policy = repo / "docs/product/v3/w6-approval-policy.md"
shadow_doc_policy = repo / "docs/product/v3/w6-shadow-doc-policy.md"
w6_spec = repo / "docs/product/v3/w6-agent-multistep-spec.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"
in_app = repo / "tests/v3-in-app-chat-test.sh"

for path in [
    store_hxx,
    store_cxx,
    planner_hxx,
    planner_cxx,
    library_mk,
    result_schema,
    state_schema,
    agent_result_test,
    agent_plan_test,
    resume_policy,
    approval_policy,
    shadow_doc_policy,
    w6_spec,
    todo,
    in_app,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = store_hxx.read_text()
cxx = store_cxx.read_text()
planner = planner_hxx.read_text() + planner_cxx.read_text()
mk = library_mk.read_text()
result_schema_text = result_schema.read_text()
state_schema_text = state_schema.read_text()
agent_result_test_text = agent_result_test.read_text()
agent_plan_test_text = agent_plan_test.read_text()
resume_text = resume_policy.read_text()
approval_text = approval_policy.read_text()
shadow_text = shadow_doc_policy.read_text()
w6_text = w6_spec.read_text()
todo_text = todo.read_text()
in_app_text = in_app.read_text()
combined = hxx + cxx


def strip_leading_block_comments(text: str) -> str:
    body = text.lstrip()
    while body.startswith("/*") and "*/" in body:
        body = body.split("*/", 1)[1].lstrip()
    return body


cxx_body = strip_leading_block_comments(cxx)

step_fields = [
    "ResultId",
    "SchemaVersion",
    "TaskId",
    "StepIndex",
    "Kind",
    "Status",
    "StartedAt",
    "FinishedAt",
    "OutputKind",
    "OutputSchemaRef",
    "OutputRefId",
    "StoresDocumentContent",
    "ApplyPlanRuntimeValidated",
    "SandboxMode",
    "ShadowBranchId",
    "MainDocumentUnchanged",
    "FailureIsolation",
    "PolicyPreflight",
    "PolicyAuditLog",
    "PolicyDecision",
    "RequiredEvidence",
    "EvidenceIds",
    "FailureCode",
    "FailureRecoverable",
    "RetryAllowed",
]

state_fields = [
    "TaskId",
    "SchemaVersion",
    "UpdatedAt",
    "OwnerSurface",
    "State",
    "CurrentStepIndex",
    "MaxSteps",
    "CompletedSteps",
    "FailedSteps",
    "CancelledSteps",
    "UsesV2AsyncCowork",
    "TaskKind",
    "CoworkTaskState",
    "ApprovalMode",
    "WholeTaskApprovalRequired",
    "PerStepApprovalSupported",
    "SoftCancelSupported",
    "HardCancelSupported",
    "UserDecisionRequired",
    "MainDocumentUnchangedOnFailure",
    "MergeTarget",
    "MergeRequiresApproval",
    "RequiresApplyPlanRuntimeValidation",
    "AuditLogRequired",
    "RequiredForEveryStep",
    "TaskEvidenceIds",
    "CheckpointId",
    "EvidenceCompleteCheckpoint",
    "DocumentHashReference",
    "ShadowSnapshotRef",
    "AuditReplayRef",
    "ResumeRequiresUserConfirmation",
]

checks = {
    "schemas active": "v3-agent-step-result/0.1" in result_schema_text and "v3-agent-task-state/0.1" in state_schema_text and "usesV2AsyncCowork" in state_schema_text,
    "contract tests active": "agent-step-result-state self-test" in agent_result_test_text and "Checks: 8" in w6_text and "forward-only-dag" in agent_plan_test_text,
    "policies active": "evidence-complete-checkpoint" in resume_text and "fail-closed-user-visible" in resume_text and "whole-task" in approval_text and "explicit-user-choice" in approval_text and "v2-w3-swdocshell" in shadow_text,
    "store class": "class AIChatAgentTaskStateStore final" in hxx,
    "step result struct": "struct AIChatAgentStepResultEntry" in hxx,
    "task state struct": "struct AIChatAgentTaskStateEntry" in hxx,
    "result struct": "struct AIChatAgentTaskStateResult" in hxx,
    "all step fields": all(field in hxx for field in step_fields),
    "all state fields": all(field in hxx for field in state_fields),
    "compiled": "sfx2/source/sidebar/AIChatAgentTaskStateStore" in mk,
    "local profile storage": "SvtPathOptions" in cxx and "GetUserConfigPath()" in cxx and "kqoffice-v3-ai-agent-task-state" in cxx,
    "storage files": "task-states.tsv" in cxx and "step-results.tsv" in cxx,
    "bounded read": "MAX_AGENT_TASK_STATE_BYTES" in cxx,
    "append only": "AppendUtf8Line" in cxx and "setPos(osl_Pos_Absolut, nSize)" in cxx,
    "escaped fields": "EscapeField" in cxx and "UnescapeField" in cxx,
    "apis": "RecordStepResult" in hxx + cxx and "SaveTaskState" in hxx + cxx and "RecordTaskState" in hxx + cxx and "LoadTaskStates" in hxx + cxx and "LoadStepResults" in hxx + cxx and "GetLatestTaskState" in hxx + cxx,
    "transition cancel resume apis": "TransitionTaskState" in hxx + cxx and "RequestCancel" in hxx + cxx and "ValidateResumeCheckpoint" in hxx + cxx,
    "id validators": "IsTaskIdAllowed" in hxx + cxx and "IsStepResultIdAllowed" in hxx + cxx and "IsShadowBranchIdAllowed" in hxx + cxx and "IsEvidenceIdAllowed" in hxx + cxx,
    "step result status guard": "IsStepResultStatusAllowed" in hxx + cxx and "completed" in cxx and "failed" in cxx and "cancelled" in cxx,
    "task state guard": "IsTaskStateAllowed" in hxx + cxx and "pending" in cxx and "running" in cxx and "awaiting-review" in cxx and "applied" in cxx and "failed" in cxx and "cancelled" in cxx,
    "transition guard": "IsAllowedTransition" in hxx + cxx and "terminal-state-locked=true" in cxx,
    "step result schema guard": "v3-agent-step-result/0.1" in cxx and "IsStepResultAllowed" in hxx + cxx,
    "task state schema guard": "v3-agent-task-state/0.1" in cxx and "IsTaskStateShapeAllowed" in hxx + cxx,
    "cowork guard": "UsesV2AsyncCowork" in hxx + cxx and "usesV2AsyncCowork=true" in cxx and "agent-multistep" in cxx and "CoworkTaskState == rEntry.State" in cxx,
    "approval guard": "WholeTaskApprovalRequired" in hxx + cxx and "wholeTaskApprovalRequired=true" in cxx and "PerStepApprovalSupported" in hxx + cxx,
    "cancel guard": "softCancelSupported=true" in cxx and "hardCancelSupported=true" in cxx and "cancel-request-evidence=true" in cxx and "userDecisionRequired=true" in cxx,
    "merge guard": "MergeTarget" in hxx + cxx and "merge-target=main-doc" in cxx and "requiresApproval=true" in cxx and "requiresApplyPlanRuntimeValidation=true" in cxx,
    "evidence guard": "IsBaseEvidenceComplete" in hxx + cxx and "policy-decision" in cxx and "evidence-record" in cxx and "audit-log-entry" in cxx,
    "checkpoint guard": "EvidenceCompleteCheckpoint" in hxx + cxx and "evidence-complete-checkpoint" in cxx and "checkpoint-id=" in cxx,
    "resume guard": "autoResumeAllowed=false" in cxx and "fail-closed-user-visible" in cxx and "requiresUserConfirmation=true" in cxx and "requiresDocumentHashMatch=true" in cxx and "requiresShadowSnapshot=true" in cxx and "requiresAuditReplay=true" in cxx,
    "shadow doc metadata": "shadow-doc" in cxx and "shadow-" in cxx and "discard-step-branch" in cxx and "ShadowSnapshotRef" in hxx,
    "main doc unchanged": "MainDocumentUnchanged" in hxx + cxx and "mainDocumentUnchanged=true" in cxx and "mainDocumentUnchangedOnFailure=true" in cxx and "main-document-mutation=false" in cxx,
    "apply plan validation": "ApplyPlanRuntimeValidated" in hxx + cxx and "ApplyPlanRuntimeValidated)" in cxx and "RequiresApplyPlanRuntimeValidation" in hxx + cxx,
    "hash metadata": "MakeTaskHashReference" in hxx + cxx and "sha256:" in cxx and "metadata-only" in cxx,
    "planner foundation present": "class AIChatAgentPlannerRuntime final" in planner and "agent-plan-validated" in planner,
    "in app runs task state smoke": "v3-agent-task-state-runtime-test.sh" in in_app_text,
    "todo records m5.2 complete": "- [x] M5.2 Implement task state store" in todo_text and "Follow-up task id: M5.3" in todo_text,
    "no raw output": "RawOutput" not in combined and "raw-output=false" in cxx,
    "no raw step result": "RawStepResult" not in combined and "raw-step-result=false" in cxx,
    "no document content": "RawDocumentContent" not in combined and "DocumentText" not in combined and "StoresDocumentContent = false" in hxx and "storesDocumentContent=true" not in combined,
    "no main doc mutation api": "ScDoc" not in combined and "SdDrawDocument" not in combined and "GetDoc()" not in combined and "SetModified" not in combined,
    "no apply execution": "ExecuteList" not in combined and "ApplyPlan(" not in combined,
    "no llm/model runtime": "LLM" not in combined and "ModelDownloader" not in combined and "EmbeddingPipeline" not in combined,
    "no vector/sql runtime": "sqlite3" not in combined and "lancedb" not in combined.lower() and "VectorBackend" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no webview": "WebView" not in combined,
    "no auto resume true": "AutoResumeAllowed = true" not in combined and "autoResumeAllowed=true" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 agent task state runtime self-test passed. Checks: {len(checks)}")
PY
