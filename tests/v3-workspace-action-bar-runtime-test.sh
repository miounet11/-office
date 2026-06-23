#!/usr/bin/env bash
# V3 W1/M3.5 - workspace action bar runtime smoke.

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

action_hxx = src / "sfx2/source/sidebar/AIChatWorkspaceActionBarStore.hxx"
action_cxx = src / "sfx2/source/sidebar/AIChatWorkspaceActionBarStore.cxx"
panel_hxx = src / "sfx2/source/sidebar/AIChatPanel.hxx"
panel_cxx = src / "sfx2/source/sidebar/AIChatPanel.cxx"
ui = src / "sfx2/uiconfig/ui/aichatpanel.ui"
queue_cxx = src / "sfx2/source/sidebar/AIChatReviewQueueStore.cxx"
opener_cxx = src / "sfx2/source/sidebar/AIChatContentOpener.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
policy = repo / "docs/product/v3/w1-workspace-action-bar-policy.md"
review_policy = repo / "docs/product/v3/w1-review-queue-policy.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [
    action_hxx,
    action_cxx,
    panel_hxx,
    panel_cxx,
    ui,
    queue_cxx,
    opener_cxx,
    library_mk,
    policy,
    review_policy,
    todo,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = action_hxx.read_text()
cxx = action_cxx.read_text()
panel_h = panel_hxx.read_text()
panel = panel_cxx.read_text()
ui_text = ui.read_text()
queue = queue_cxx.read_text()
opener = opener_cxx.read_text()
mk = library_mk.read_text()
policy_text = policy.read_text()
review_policy_text = review_policy.read_text()
todo_text = todo.read_text()
combined = hxx + cxx + panel_h + panel + ui_text + queue + opener

commands = [
    "open-preview",
    "open-diff-review",
    "approve-selected",
    "reject-selected",
    "copy-reference",
    "export-evidence",
    "filter",
    "sort",
    "retry",
    "cancel",
]
button_ids = [
    "open_artifact_button",
    "open_diff_review_button",
    "approve_selected_button",
    "reject_selected_button",
    "copy_reference_button",
    "export_evidence_button",
    "filter_workspace_button",
    "sort_workspace_button",
    "retry_button",
    "cancel_button",
]
callbacks = [
    "OnOpenDiffReviewClicked",
    "OnApproveSelectedClicked",
    "OnRejectSelectedClicked",
    "OnCopyReferenceClicked",
    "OnExportEvidenceClicked",
    "OnFilterWorkspaceClicked",
    "OnSortWorkspaceClicked",
]

checks = {
    "policy command roster": "commands=[open-preview,open-diff-review,approve-selected,reject-selected,copy-reference,export-evidence,filter,sort,retry,cancel]" in policy_text,
    "policy visible": "visible=true" in policy_text and "requiresVisibleState=true" in policy_text,
    "policy keyboard native": "keyboardAccessible=true" in policy_text and "usesNativeControls=true" in policy_text,
    "policy content opener": "usesContentOpeners=true" in policy_text,
    "policy diff review": "usesDiffReview=true" in policy_text,
    "policy approval guard": "bulkApplyRequiresExplicitHumanApproval=true" in policy_text,
    "policy no auto apply": "autoApplyAllowed=false" in policy_text,
    "policy no mutation": "mainDocumentMutationAllowed=false" in policy_text,
    "review policy bulk guard": "bulkActions=[approve-selected,reject-selected]" in review_policy_text,
    "todo has m3.5": "M3.5 Implement workspace action bar" in todo_text,
    "action class": "class AIChatWorkspaceActionBarStore final" in hxx,
    "dispatch result": "struct AIChatWorkspaceActionBarDispatchResult" in hxx,
    "compiled": "sfx2/source/sidebar/AIChatWorkspaceActionBarStore" in mk,
    "dispatch api": "DispatchCommand" in hxx + cxx,
    "command roster api": "GetCommandRoster" in hxx + cxx,
    "supported command api": "IsSupportedCommand" in hxx + cxx,
    "enabled state api": "IsCommandEnabled" in hxx + cxx,
    "all commands in store": all(f'u"{cmd}"_ustr' in cxx for cmd in commands),
    "target types": all(target in cxx for target in ["task-step", "review-item", "artifact", "evidence-record", "preview"]),
    "requires target": "RequiresSelectedTarget" in cxx and "missing-selected-target" in cxx,
    "requires evidence": "RequiresEvidenceLink" in cxx and "missing-evidence-link" in cxx,
    "visible state": "visible-state=true" in cxx,
    "keyboard accessible": "keyboard-accessible=true" in cxx,
    "native controls": "uses-native-controls=true" in cxx,
    "explicit approval": "explicit-human-approval=true" in cxx + panel,
    "bulk no apply": "bulk-apply=false" in cxx,
    "auto apply false": "auto-apply=false" in cxx,
    "hidden no": "hidden-action=false" in cxx,
    "mouse no": "mouse-only=false" in cxx,
    "read only no mutation": "read-only=true" in cxx and "main-document-mutation=false" in cxx + panel,
    "diff review dispatch": "uses-diff-review=true" in cxx and "open-diff-review" in panel,
    "approve state": 'aResult.ReviewState = u"approved"_ustr' in cxx,
    "reject state": 'aResult.ReviewState = u"rejected"_ustr' in cxx,
    "reference command": "MakeReference" in cxx and "@artifact:" in cxx and "@review:" in cxx,
    "export evidence metadata": "export-evidence=metadata-only" in cxx and "redacted=true" in cxx and "hash-only=true" in cxx,
    "filter sort visible": "Workspace filter visible: state,type,surface" in panel and "Workspace sort visible: recent-first" in panel,
    "panel owns store": "std::unique_ptr<AIChatWorkspaceActionBarStore> m_xWorkspaceActionBarStore" in panel_h,
    "panel includes store": '#include "AIChatWorkspaceActionBarStore.hxx"' in panel,
    "panel creates store": "std::make_unique<AIChatWorkspaceActionBarStore>()" in panel,
    "panel dispatch method": "bool DispatchWorkspaceAction" in panel_h and "DispatchWorkspaceAction" in panel,
    "panel dispatch gates open": "if (!DispatchWorkspaceAction(u\"open-preview\"_ustr))" in panel,
    "panel dispatch gates evidence": "if (!DispatchWorkspaceAction(u\"export-evidence\"_ustr))" in panel,
    "panel dispatch gates diff": "if (!DispatchWorkspaceAction(u\"open-diff-review\"_ustr)" in panel,
    "panel uses enabled state": "AIChatWorkspaceActionBarStore::IsCommandEnabled" in panel,
    "panel queue transition": "TransitionState(" in panel and "aQueueEntry.EvidenceId = aResult.EvidenceId" in panel and "aQueueEntry.HashReference = aResult.HashReference" in panel,
    "panel action activity": "RecordWorkspaceActivity" in panel and 'u"action-invoked"_ustr' in panel,
    "panel review activity": "RecordWorkspaceReviewActivity" in panel and 'u"review-state-changed"_ustr' in panel,
    "panel snapshot": "SaveSessionSnapshot" in panel and "SaveReviewSessionSnapshot" in panel,
    "all ui buttons": all(f'id="{button_id}"' in ui_text for button_id in button_ids),
    "ui keyboard reachable": all(
        f'id="{button_id}"' in ui_text
        and ui_text.split(f'id="{button_id}"', 1)[1].split("</object>", 1)[0].count('<property name="can-focus">True</property>') >= 1
        for button_id in button_ids
    ),
    "all callbacks": all(callback in panel_h + panel for callback in callbacks),
    "open uses content opener": "AIChatContentOpener aOpener" in panel and "OpenReadOnlyPreview" in panel and "read-only=true" in opener,
    "queue allows bulk only": "IsBulkActionAllowed" in queue and "approve-selected" in queue and "reject-selected" in queue,
    "no raw content": "RawContent" not in combined and "Payload" not in combined and "PreviewBody" not in combined and "SuggestionContent" not in combined,
    "no direct document mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
    "no apply path": "ApplyPlan" not in hxx + cxx + panel_h + panel and "ExecuteList" not in hxx + cxx + panel_h + panel,
    "no auto apply api": "autoApply" not in combined,
    "no webview": "WebView" not in combined,
    "no cloud": "cloud" not in cxx.lower(),
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 workspace action bar runtime self-test passed. Checks: {len(checks)}")
PY
