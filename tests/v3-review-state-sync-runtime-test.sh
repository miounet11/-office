#!/usr/bin/env bash
# V3 W1/M3.6 - review state sync runtime smoke.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src_root="$repo_root/libreoffice-core"

fail() {
    printf 'FAIL: %s\\n' "$1" >&2
    exit 1
}

[[ -d "$src_root" ]] || fail "missing source root $src_root"

python3 - "$repo_root" "$src_root" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

repo = Path(sys.argv[1])
src = Path(sys.argv[2])

sync_hxx = src / "sfx2/source/sidebar/AIChatReviewStateSyncStore.hxx"
sync_cxx = src / "sfx2/source/sidebar/AIChatReviewStateSyncStore.cxx"
queue_hxx = src / "sfx2/source/sidebar/AIChatReviewQueueStore.hxx"
queue_cxx = src / "sfx2/source/sidebar/AIChatReviewQueueStore.cxx"
preview_cxx = src / "sfx2/source/sidebar/AIChatPreviewMatrix.cxx"
evidence_cxx = src / "sfx2/source/sidebar/AIChatEvidenceInspector.cxx"
action_cxx = src / "sfx2/source/sidebar/AIChatWorkspaceActionBarStore.cxx"
panel_hxx = src / "sfx2/source/sidebar/AIChatPanel.hxx"
panel_cxx = src / "sfx2/source/sidebar/AIChatPanel.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
policy = repo / "docs/product/v3/w1-workspace-review-state-sync-policy.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [
    sync_hxx,
    sync_cxx,
    queue_hxx,
    queue_cxx,
    preview_cxx,
    evidence_cxx,
    action_cxx,
    panel_hxx,
    panel_cxx,
    library_mk,
    policy,
    todo,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = sync_hxx.read_text()
cxx = sync_cxx.read_text()
queue_h = queue_hxx.read_text()
queue = queue_cxx.read_text()
preview = preview_cxx.read_text()
evidence = evidence_cxx.read_text()
action = action_cxx.read_text()
panel_h = panel_hxx.read_text()
panel = panel_cxx.read_text()
mk = library_mk.read_text()
policy_text = policy.read_text()
todo_text = todo.read_text()
combined = hxx + cxx + queue_h + queue + preview + evidence + action + panel_h + panel

fields = [
    "ReviewId",
    "State",
    "TransitionEvent",
    "SourceSurface",
    "EvidenceId",
    "HashReference",
    "OpenTarget",
    "PreviewMode",
    "VisibleState",
    "Conflict",
]
states = ["queued", "open", "approved", "rejected", "applied", "failed"]
transitions = ["open", "approve", "reject", "apply", "fail"]
surfaces = [
    "review-queue",
    "diff-review",
    "preview-matrix",
    "evidence-inspector",
    "task-progress",
    "action-bar",
]

checks = {
    "policy sources": "stateSources=[review-queue,diff-review,preview-matrix,evidence-inspector,task-progress,action-bar]" in policy_text,
    "policy states": "states=[queued,open,approved,rejected,applied,failed]" in policy_text,
    "policy targets": "syncTargets=[review-queue,diff-review,preview-matrix,evidence-inspector,task-progress,action-bar]" in policy_text,
    "policy transitions": "transitionEvents=[open,approve,reject,apply,fail]" in policy_text,
    "policy metadata only": "metadataOnly=true" in policy_text and "hashOnlyReferences=true" in policy_text,
    "policy redaction": "redactsRawPayload=true" in policy_text,
    "policy approval guard": "requiresHumanApproval=true" in policy_text and "bulkApplyRequiresExplicitHumanApproval=true" in policy_text,
    "policy no mutation": "mainDocumentMutationAllowed=false" in policy_text and "autoApplyAllowed=false" in policy_text,
    "policy conflict": "conflictBehavior=fail-closed-user-visible" in policy_text,
    "sync class": "class AIChatReviewStateSyncStore final" in hxx,
    "sync result": "struct AIChatReviewStateSyncResult" in hxx,
    "sync entry fields": all(field in hxx for field in fields),
    "compiled": "sfx2/source/sidebar/AIChatReviewStateSyncStore" in mk,
    "local namespace": "kqoffice-v3-ai-review-state-sync" in cxx,
    "state file": "state.tsv" in cxx,
    "bounded read": "MAX_REVIEW_STATE_SYNC_BYTES" in cxx,
    "append only": "AppendUtf8Line" in cxx and "setPos(osl_Pos_Absolut, nSize)" in cxx,
    "escaped metadata": "EscapeField" in cxx and "UnescapeField" in cxx,
    "record api": "RecordTransition" in hxx + cxx and "RecordFromRegistry" in hxx + cxx,
    "latest api": "GetLatestState" in hxx + cxx,
    "valid states": all(f'rState == u"{state}"_ustr' in cxx for state in states),
    "valid transitions": all(f'rTransitionEvent == u"{transition}"_ustr' in cxx for transition in transitions),
    "valid surfaces": all(f'rSurface == u"{surface}"_ustr' in cxx for surface in surfaces),
    "normalize in review": 'rState == u"in-review"_ustr' in cxx and "NormalizeRegistryState" in cxx,
    "transition for state": "TransitionForState" in cxx,
    "visible state": "BuildVisibleState" in cxx and "visible-state=true" in cxx,
    "all surfaces visible": all(f"{surface}=true" in cxx for surface in surfaces),
    "requires evidence": "missing-evidence-link" in cxx and "rEvidenceId.isEmpty()" in cxx and "rHashReference.isEmpty()" in cxx,
    "conflict fail closed": "HasEvidenceConflict" in cxx and "conflict-behavior=fail-closed-user-visible" in cxx and 'aResult.Entry.State = u"failed"_ustr' in cxx,
    "metadata hash redacted": "metadata-only=true" in cxx and "hash-only=true" in cxx and "redacted=true" in cxx,
    "human approval no mutation": "requires-human-approval=true" in cxx and "main-document-mutation=false" in cxx,
    "no auto apply": "auto-apply=false" in cxx,
    "queue includes sync": '#include "AIChatReviewStateSyncStore.hxx"' in queue,
    "queue enqueue sync": "aStateSync.RecordFromRegistry" in queue and 'u"review-queue"_ustr' in queue,
    "queue transition sync": "TransitionState(const AIChatReviewQueueEntry& rEntry" in queue and "aStateSync.RecordTransition" in queue,
    "queue preserves evidence": "rEntry.EvidenceId" in queue and "rEntry.HashReference" in queue,
    "queue no state-only fallback": "return false;" in queue and "aEntry.EvidenceId" not in queue,
    "preview includes sync": '#include "AIChatReviewStateSyncStore.hxx"' in preview and "GetLatestState(rEntry.ObjectId)" in preview and 'u"preview-matrix"_ustr' in preview,
    "evidence includes sync": '#include "AIChatReviewStateSyncStore.hxx"' in evidence and "GetLatestState(rEntry.ObjectId)" in evidence and 'u"evidence-inspector"_ustr' in evidence,
    "action includes sync": '#include "AIChatReviewStateSyncStore.hxx"' in action and "NormalizeRegistryState" in action,
    "panel owns sync": "std::unique_ptr<AIChatReviewStateSyncStore> m_xReviewStateSyncStore" in panel_h,
    "panel creates sync": "std::make_unique<AIChatReviewStateSyncStore>()" in panel,
    "panel sync helper": "SyncReviewState" in panel_h + panel,
    "panel sync open": 'SyncReviewState(pSelected->ObjectId, u"open"_ustr, u"open"_ustr, u"diff-review"_ustr' in panel,
    "panel sync approve reject": 'u"approve"_ustr' in panel and 'u"reject"_ustr' in panel and "aQueueEntry.EvidenceId = aResult.EvidenceId" in panel,
    "panel fail visible": 'u"failure-reported"_ustr' in panel and "review-state-sync-failed" in cxx,
    "snapshot review state": "SaveReviewSessionSnapshot" in panel and "ReviewState" in panel_h + panel,
    "todo has m3.6": "M3.6 Implement review state sync" in todo_text,
    "no raw payload": "RawContent" not in combined and "Payload" not in combined and "PreviewBody" not in combined and "SuggestionContent" not in combined,
    "no direct document mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
    "no apply path": "ApplyPlan" not in combined and "ExecuteList" not in combined,
    "no auto apply api": "autoApply" not in combined,
    "no webview": "WebView" not in combined,
    "no cloud": "cloud" not in cxx.lower(),
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 review state sync runtime self-test passed. Checks: {len(checks)}")
PY
