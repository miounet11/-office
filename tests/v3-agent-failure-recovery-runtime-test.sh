#!/usr/bin/env bash
# V3 W6/M5.5 - Agent failure recovery UX runtime smoke.

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

bridge_hxx = src / "sfx2/source/sidebar/AIChatAgentFailureRecoveryBridge.hxx"
bridge_cxx = src / "sfx2/source/sidebar/AIChatAgentFailureRecoveryBridge.cxx"
task_hxx = src / "sfx2/source/sidebar/AIChatAgentTaskStateStore.hxx"
task_cxx = src / "sfx2/source/sidebar/AIChatAgentTaskStateStore.cxx"
action_hxx = src / "sfx2/source/sidebar/AIChatWorkspaceActionBarStore.hxx"
action_cxx = src / "sfx2/source/sidebar/AIChatWorkspaceActionBarStore.cxx"
session_hxx = src / "sfx2/source/sidebar/AIChatWorkspaceSessionStore.hxx"
session_cxx = src / "sfx2/source/sidebar/AIChatWorkspaceSessionStore.cxx"
state_sync_cxx = src / "sfx2/source/sidebar/AIChatReviewStateSyncStore.cxx"
evidence_cxx = src / "sfx2/source/sidebar/AIChatEvidenceInspector.cxx"
provenance_hxx = src / "sfx2/source/sidebar/AIChatSourceProvenance.hxx"
registry_hxx = src / "sfx2/source/sidebar/AIChatContentRegistry.hxx"
library_mk = src / "sfx2/Library_sfx.mk"
action_policy = repo / "docs/product/v3/w1-workspace-action-bar-policy.md"
activity_policy = repo / "docs/product/v3/w1-workspace-activity-timeline-policy.md"
session_policy = repo / "docs/product/v3/w1-workspace-session-snapshot-policy.md"
state_policy = repo / "docs/product/v3/w1-workspace-review-state-sync-policy.md"
resume_policy = repo / "docs/product/v3/w6-resume-policy.md"
plan_policy = repo / "docs/product/v3/w6-plan-validation-policy.md"
agent_spec = repo / "docs/product/v3/w6-agent-multistep-spec.md"
error_recovery_test = repo / "tests/v3-error-recovery-ux-test.sh"
in_app = repo / "tests/v3-in-app-chat-test.sh"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [
    bridge_hxx,
    bridge_cxx,
    task_hxx,
    task_cxx,
    action_hxx,
    action_cxx,
    session_hxx,
    session_cxx,
    state_sync_cxx,
    evidence_cxx,
    provenance_hxx,
    registry_hxx,
    library_mk,
    action_policy,
    activity_policy,
    session_policy,
    state_policy,
    resume_policy,
    plan_policy,
    agent_spec,
    error_recovery_test,
    in_app,
    todo,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = bridge_hxx.read_text()
cxx = bridge_cxx.read_text()
task = task_hxx.read_text() + task_cxx.read_text()
action = action_hxx.read_text() + action_cxx.read_text()
session = session_hxx.read_text() + session_cxx.read_text()
state_sync = state_sync_cxx.read_text()
evidence = evidence_cxx.read_text()
provenance = provenance_hxx.read_text()
registry = registry_hxx.read_text()
mk = library_mk.read_text()
action_text = action_policy.read_text()
activity_text = activity_policy.read_text()
session_text = session_policy.read_text()
state_text = state_policy.read_text()
resume_text = resume_policy.read_text()
plan_text = plan_policy.read_text()
agent_text = agent_spec.read_text()
error_recovery_text = error_recovery_test.read_text()
in_app_text = in_app.read_text()
todo_text = todo.read_text()
combined = hxx + cxx


def strip_leading_block_comments(text: str) -> str:
    body = text.lstrip()
    while body.startswith("/*") and "*/" in body:
        body = body.split("*/", 1)[1].lstrip()
    return body


cxx_body = strip_leading_block_comments(cxx)

result_fields = [
    "Success",
    "TaskStepObjectId",
    "FailureCode",
    "EvidenceId",
    "HashReference",
    "RetryActionState",
    "CancelActionState",
    "OpenTarget",
    "PreviewMode",
    "ActivityCursor",
    "Message",
]

checks = {
    "bridge class": "class AIChatAgentFailureRecoveryBridge final" in hxx,
    "result struct": "struct AIChatAgentFailureRecoveryResult" in hxx,
    "result fields": all(field in hxx for field in result_fields),
    "compiled": "sfx2/source/sidebar/AIChatAgentFailureRecoveryBridge" in mk,
    "publish api": "PublishFailedStep" in hxx + cxx,
    "document binding guard": "IsDocumentBindingAllowed" in hxx + cxx and 'rDocumentBinding.startsWith(u"doc-"_ustr)' in cxx,
    "recoverable guard": "IsFailedStepRecoverable" in hxx + cxx,
    "failed state guard": 'rStepResult.Status == u"failed"_ustr' in cxx and 'rTaskState.State == u"failed"_ustr' in cxx,
    "task match guard": "rStepResult.TaskId == rTaskState.TaskId" in cxx and "rStepResult.StepIndex == rTaskState.CurrentStepIndex" in cxx,
    "failure code guard": "rStepResult.FailureCode != u\"none\"_ustr" in cxx,
    "retry guard": "rStepResult.FailureRecoverable && rStepResult.RetryAllowed" in cxx,
    "decision guard": "rTaskState.UserDecisionRequired" in cxx and "rTaskState.ResumeRequiresUserConfirmation" in cxx,
    "checkpoint guard": "EvidenceCompleteCheckpoint" in cxx and "CheckpointId" in cxx and "ShadowSnapshotRef" in cxx and "AuditReplayRef" in cxx,
    "main doc guard": "MainDocumentUnchanged" in cxx and "MainDocumentUnchangedOnFailure" in cxx,
    "task object": "MakeFailureStepObjectId" in cxx and "failure-recovery" in cxx,
    "hash only": "MakeFailureHashReference" in cxx and "AIChatKnowledgeIndexStore::MakeMetadataHash" in cxx,
    "registry entry": "AIChatContentRegistryEntry aEntry" in cxx and 'aEntry.Type = u"task-step"_ustr' in cxx and 'aEntry.SourceSurface = u"agent-failure-recovery"_ustr' in cxx,
    "failed registry state": 'aEntry.State = u"failed"_ustr' in cxx and 'aEntry.OpenTarget = u"task-progress"_ustr' in cxx,
    "registry write": "AIChatContentRegistry aRegistry" in cxx and "aRegistry.RegisterObject(aEntry)" in cxx,
    "source provenance": "AIChatSourceProvenanceEntry aSource" in cxx and "AIChatSourceProvenance aProvenance" in cxx and "aProvenance.RegisterSource(aSource)" in cxx,
    "evidence inspector": "AIChatEvidenceInspector aEvidenceInspector" in cxx and "aEvidenceInspector.Inspect(aEntry)" in cxx,
    "state sync": "AIChatReviewStateSyncStore aStateSync" in cxx and 'u"fail"_ustr' in cxx and 'u"failed"_ustr' in cxx and 'u"task-progress"_ustr' in cxx,
    "action bar": "AIChatWorkspaceActionBarStore aActionBar" in cxx and 'DispatchCommand(u"retry"_ustr' in cxx and 'DispatchCommand(u"cancel"_ustr' in cxx,
    "retry explicit": "RetryActionState" in cxx and "auto-retry=false" in cxx and "retryRequiresUserConfirmation=true" in cxx,
    "cancel explicit": "CancelActionState" in cxx and "background-cancel=false" in cxx and "cancelRequiresUserConfirmation=true" in cxx,
    "activity timeline": "AIChatWorkspaceSessionStore aSession" in cxx and "AIChatWorkspaceActivityEntry aFailureActivity" in cxx,
    "failure event": 'aFailureActivity.Event = u"failure-reported"_ustr' in cxx,
    "action event": 'aRetryActivity.Event = u"action-invoked"_ustr' in cxx and 'aCancelActivity.Event = u"action-invoked"_ustr' in cxx,
    "session snapshot": "AIChatSessionSnapshot aSnapshot" in cxx and "aSession.SaveSnapshot(aSnapshot)" in cxx,
    "snapshot failure": "aSnapshot.FailureState = aResult.FailureCode" in cxx and 'aSnapshot.ReviewState = u"failed"_ustr' in cxx,
    "success message": "agent-failure-recovery-published" in cxx and "visible-failure=true" in cxx and "failed-step-reason=true" in cxx,
    "open evidence": "open-evidence=true" in cxx and "source-links=true" in cxx,
    "no execution message": "no-actor-observer-execution=true" in cxx and "no-apply-plan-execution=true" in cxx,
    "task state supports failure": "FailureCode" in task and "FailureRecoverable" in task and "RetryAllowed" in task,
    "task cancel policy": "RequestCancel" in task and "userDecisionRequired=true" in task and "cancel-request-evidence=true" in task,
    "resume explicit": "ValidateResumeCheckpoint" in task and "autoResumeAllowed=false" in task,
    "action roster": "retry" in action and "cancel" in action and "task-control=true" in action,
    "action task target": "IsTaskStepEntry" in action and 'u"task-step"_ustr' in action,
    "action retry failed task": 'rCommand == u"retry"_ustr' in action and 'pEntry->State == u"failed"_ustr' in action,
    "action cancel failed task": 'rCommand == u"cancel"_ustr' in action and 'pEntry->State == u"failed"_ustr' in action,
    "session failure field": "FailureState" in session,
    "state sync failure": "failed" in state_sync and "TransitionForState" in state_sync and 'return u"fail"_ustr' in state_sync,
    "evidence supports task step": 'rSourceType == u"task-step"_ustr' in evidence,
    "provenance supports refs": "HashReference" in provenance and "SpanReference" in provenance,
    "registry metadata fields": all(field in registry for field in ["ObjectId", "Type", "SourceSurface", "State", "EvidenceId", "HashReference", "OpenTarget", "PreviewMode"]),
    "policy action retry cancel": "commands=[open-preview,open-diff-review,approve-selected,reject-selected,copy-reference,export-evidence,filter,sort,retry,cancel]" in action_text and "Retry and cancel are task controls only" in action_text,
    "policy activity failure": "failure-reported" in activity_text and "action-invoked" in activity_text,
    "policy session failure": "failure-state" in session_text and "requiresExplicitResume=true" in session_text,
    "policy state failed": "states=[queued,open,approved,rejected,applied,failed]" in state_text,
    "policy resume explicit": "Auto resume allowed" in resume_text and "false" in resume_text,
    "policy plan no silent retry": "Auto retry allowed" in plan_text and "false" in plan_text,
    "agent spec failed recovery fixture": "impress-step-failed-recovery.json" in agent_text,
    "w9 recovery contract": "openable-evidence" in error_recovery_text and "retry" in error_recovery_text,
    "in app runs failure recovery smoke": "v3-agent-failure-recovery-runtime-test.sh" in in_app_text,
    "todo m5.5 complete": "- [x] M5.5 Add failure recovery UX." in todo_text
    and "Follow-up task id: M6.1." in todo_text,
    "todo advanced beyond m5.5": (
        "Active cursor: M6.1 Implement tenant context runtime" in todo_text
        or "Active cursor: M6.2 Implement policy engine" in todo_text
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
        "Completed runtime foundation: M1.1-M5.5." in todo_text
        or "Completed runtime foundation: M1.1-M6.1." in todo_text
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
    "no raw task payload": "RawTask" not in combined and "TaskPayload" not in combined and "Payload" not in combined,
    "no raw failure body": "RawFailure" not in combined and "FailureBody" not in combined and "FailureDetails" not in combined,
    "no raw evidence": "EvidenceBody" not in combined and "EvidencePayload" not in combined,
    "no raw document": "DocumentText" not in combined and "RawDocumentContent" not in combined and "storesDocumentContent=true" not in combined,
    "no main doc mutation api": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined and "SetModified" not in combined,
    "no actor observer execution": "ActorRuntime" not in combined and "ObserverRuntime" not in combined and "ExecuteStep" not in combined,
    "no apply execution": "ExecuteList" not in combined and "ApplyPlan(" not in combined and "applyDiagnosticsPlan" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no webview": "WebView" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 agent failure recovery runtime self-test passed. Checks: {len(checks)}")
PY
