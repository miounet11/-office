#!/usr/bin/env bash
# V3 W6/M5.4 - Agent step to W1 review surfaces runtime smoke.

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

bridge_hxx = src / "sfx2/source/sidebar/AIChatAgentReviewSurfaceBridge.hxx"
bridge_cxx = src / "sfx2/source/sidebar/AIChatAgentReviewSurfaceBridge.cxx"
shadow_hxx = src / "sfx2/source/sidebar/AIChatAgentShadowDocBridge.hxx"
shadow_cxx = src / "sfx2/source/sidebar/AIChatAgentShadowDocBridge.cxx"
queue_cxx = src / "sfx2/source/sidebar/AIChatReviewQueueStore.cxx"
content_review_cxx = src / "sfx2/source/sidebar/AIChatContentReviewStore.cxx"
evidence_cxx = src / "sfx2/source/sidebar/AIChatEvidenceInspector.cxx"
state_sync_cxx = src / "sfx2/source/sidebar/AIChatReviewStateSyncStore.cxx"
session_hxx = src / "sfx2/source/sidebar/AIChatWorkspaceSessionStore.hxx"
session_cxx = src / "sfx2/source/sidebar/AIChatWorkspaceSessionStore.cxx"
opener_cxx = src / "sfx2/source/sidebar/AIChatContentOpener.cxx"
preview_cxx = src / "sfx2/source/sidebar/AIChatPreviewMatrix.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
activity_policy = repo / "docs/product/v3/w1-workspace-activity-timeline-policy.md"
session_policy = repo / "docs/product/v3/w1-workspace-session-snapshot-policy.md"
review_policy = repo / "docs/product/v3/w1-review-queue-policy.md"
evidence_policy = repo / "docs/product/v3/w1-evidence-inspector-policy.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"
in_app = repo / "tests/v3-in-app-chat-test.sh"

for path in [
    bridge_hxx,
    bridge_cxx,
    shadow_hxx,
    shadow_cxx,
    queue_cxx,
    content_review_cxx,
    evidence_cxx,
    state_sync_cxx,
    session_hxx,
    session_cxx,
    opener_cxx,
    preview_cxx,
    library_mk,
    activity_policy,
    session_policy,
    review_policy,
    evidence_policy,
    todo,
    in_app,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = bridge_hxx.read_text()
cxx = bridge_cxx.read_text()
shadow = shadow_hxx.read_text() + shadow_cxx.read_text()
queue = queue_cxx.read_text()
content_review = content_review_cxx.read_text()
evidence = evidence_cxx.read_text()
state_sync = state_sync_cxx.read_text()
session = session_hxx.read_text() + session_cxx.read_text()
opener = opener_cxx.read_text()
preview = preview_cxx.read_text()
mk = library_mk.read_text()
activity_text = activity_policy.read_text()
session_text = session_policy.read_text()
review_text = review_policy.read_text()
evidence_text = evidence_policy.read_text()
todo_text = todo.read_text()
in_app_text = in_app.read_text()
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
    "ReviewId",
    "QueueState",
    "EvidenceId",
    "HashReference",
    "OpenTarget",
    "PreviewMode",
    "ActivityCursor",
    "Message",
]

checks = {
    "activity policy": "review-opened" in activity_text and "review-state-changed" in activity_text and "metadataOnly=true" in activity_text,
    "session policy": "active-task-id" in session_text and "open-review-id" in session_text and "requiresExplicitResume=true" in session_text,
    "review policy": "itemTypes=[content-review,formatting-review,task-step]" in review_text and "mainDocumentMutationAllowed=false" in review_text,
    "evidence policy": "sourceTypes=[evidence-record,connector-result,knowledge-index-result,task-step,review-item]" in evidence_text,
    "bridge class": "class AIChatAgentReviewSurfaceBridge final" in hxx,
    "result struct": "struct AIChatAgentReviewSurfaceResult" in hxx,
    "result fields": all(field in hxx for field in result_fields),
    "compiled": "sfx2/source/sidebar/AIChatAgentReviewSurfaceBridge" in mk,
    "publish api": "PublishShadowDocResult" in hxx + cxx,
    "document binding guard": "IsDocumentBindingAllowed" in hxx + cxx and 'rDocumentBinding.startsWith(u"doc-"_ustr)' in cxx,
    "shadow result guard": "IsShadowDocResultPublishable" in hxx + cxx and "rShadowResult.Success" in cxx,
    "task step guard": 'rShadowResult.RegistryEntry.Type == u"task-step"_ustr' in cxx and 'rShadowResult.RegistryEntry.SourceSurface == u"agent-shadow-doc"_ustr' in cxx,
    "awaiting review guard": 'rShadowResult.RegistryEntry.State == u"awaiting-review"_ustr' in cxx and 'rShadowResult.TaskState.State == u"awaiting-review"_ustr' in cxx,
    "diff route guard": 'rShadowResult.RegistryEntry.OpenTarget == u"diff-review"_ustr' in cxx and 'rShadowResult.RegistryEntry.PreviewMode == u"diff-preview"_ustr' in cxx,
    "shadow isolation guard": 'rShadowResult.StepResult.SandboxMode == u"shadow-doc"_ustr' in cxx and "MainDocumentUnchanged" in cxx and "StoresDocumentContent" in cxx,
    "checkpoint guard": "EvidenceCompleteCheckpoint" in cxx,
    "review queue": "AIChatReviewQueueStore aQueue" in cxx and "aQueue.EnqueueFromRegistry(rShadowResult.RegistryEntry)" in cxx,
    "content review": "AIChatContentReviewStore aContentReview" in cxx and "CreateReviewFromSource(rShadowResult.RegistryEntry)" in cxx,
    "evidence inspector": "AIChatEvidenceInspector aEvidenceInspector" in cxx and "aEvidenceInspector.Inspect(rShadowResult.RegistryEntry)" in cxx,
    "state sync": "AIChatReviewStateSyncStore aStateSync" in cxx and "RecordFromRegistry" in cxx and 'u"task-progress"_ustr' in cxx,
    "activity timeline": "AIChatWorkspaceSessionStore aSession" in cxx and "AIChatWorkspaceActivityEntry aReadyActivity" in cxx and "aSession.RecordActivity(aReadyActivity)" in cxx,
    "review opened event": 'aReadyActivity.Event = u"review-opened"_ustr' in cxx,
    "review state changed event": 'aStateActivity.Event = u"review-state-changed"_ustr' in cxx,
    "agent actor": 'aReadyActivity.Actor = u"agent"_ustr' in cxx,
    "session snapshot": "AIChatSessionSnapshot aSnapshot" in cxx and "aSession.SaveSnapshot(aSnapshot)" in cxx,
    "snapshot task": "aSnapshot.ActiveTaskId = rShadowResult.TaskState.TaskId" in cxx,
    "snapshot review": "aSnapshot.OpenReviewId = aResult.ReviewId" in cxx,
    "snapshot evidence": "aSnapshot.ActiveEvidenceId = aResult.EvidenceId" in cxx,
    "snapshot state": 'aSnapshot.ReviewState = u"queued"_ustr' in cxx,
    "fail closed guards": "review-queue-write-failed" in cxx and "content-review-write-failed" in cxx and "evidence-inspector-link-failed" in cxx and "activity-timeline-write-failed" in cxx and "session-snapshot-write-failed" in cxx,
    "success message": "agent-review-surface-published task-step-id=" in cxx and "review-queue=true" in cxx and "content-review=true" in cxx and "diff-review=true" in cxx and "evidence-inspector=true" in cxx and "activity-timeline=true" in cxx and "session-snapshot=true" in cxx,
    "approval guard message": "requires-human-approval=true" in cxx and "auto-apply=false" in cxx,
    "metadata message": "metadata-only=true" in cxx and "main-document-mutation=false" in cxx,
    "shadow foundation": "class AIChatAgentShadowDocBridge final" in shadow and "agent-shadow-doc-prepared" in shadow,
    "queue supports task step": 'return u"task-step"_ustr' in queue,
    "content review supports task step": 'rSourceType == u"task-step"_ustr' in content_review,
    "evidence supports task step": 'rSourceType == u"task-step"_ustr' in evidence,
    "state sync task progress": 'rSurface == u"task-progress"_ustr' in state_sync,
    "session store": "RecordActivity" in session and "SaveSnapshot" in session,
    "opener diff route": "diff-review" in opener and "read-only=true main-document-mutation=false" in opener,
    "preview task step": 'rEntry.Type == u"task-step"_ustr' in preview and "diff-preview" in preview,
    "in app runs review surface smoke": "v3-agent-review-surface-runtime-test.sh" in in_app_text,
    "todo m5.4 complete": "- [x] M5.4 Integrate W1 review surfaces." in todo_text
    and "Follow-up task id: M5.5." in todo_text,
    "todo advanced beyond m5.4": (
        "Active cursor: M5.5 Add failure recovery UX" in todo_text
        or "Active cursor: M6.1 Implement tenant context runtime" in todo_text
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
        "Completed runtime foundation: M1.1-M5.4." in todo_text
        or "Completed runtime foundation: M1.1-M5.5." in todo_text
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
    "no raw review payload": "RawReview" not in combined and "ReviewBody" not in combined and "Payload" not in combined,
    "no raw activity payload": "RawActivity" not in combined and "TimelinePayload" not in combined,
    "no raw diff": "RawDiff" not in combined and "DiffBody" not in combined,
    "no document content": "DocumentText" not in combined and "RawDocumentContent" not in combined and "storesDocumentContent=true" not in combined,
    "no main doc mutation api": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined and "SetModified" not in combined,
    "no apply execution": "ExecuteList" not in combined and "ApplyPlan(" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no webview": "WebView" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 agent review surface bridge runtime self-test passed. Checks: {len(checks)}")
PY
