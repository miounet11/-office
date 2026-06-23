#!/usr/bin/env bash
# V3 W1/M3.1 - evidence-linked content review runtime smoke.

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

review_hxx = src / "sfx2/source/sidebar/AIChatContentReviewStore.hxx"
review_cxx = src / "sfx2/source/sidebar/AIChatContentReviewStore.cxx"
registry_hxx = src / "sfx2/source/sidebar/AIChatContentRegistry.hxx"
opener_cxx = src / "sfx2/source/sidebar/AIChatContentOpener.cxx"
preview_cxx = src / "sfx2/source/sidebar/AIChatPreviewMatrix.cxx"
provenance_cxx = src / "sfx2/source/sidebar/AIChatSourceProvenance.cxx"
session_hxx = src / "sfx2/source/sidebar/AIChatWorkspaceSessionStore.hxx"
panel_hxx = src / "sfx2/source/sidebar/AIChatPanel.hxx"
panel_cxx = src / "sfx2/source/sidebar/AIChatPanel.cxx"
ui = src / "sfx2/uiconfig/ui/aichatpanel.ui"
library_mk = src / "sfx2/Library_sfx.mk"
policy = repo / "docs/product/v3/w1-content-review-policy.md"
timeline_policy = repo / "docs/product/v3/w1-workspace-activity-timeline-policy.md"
snapshot_policy = repo / "docs/product/v3/w1-workspace-session-snapshot-policy.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [
    review_hxx,
    review_cxx,
    registry_hxx,
    opener_cxx,
    preview_cxx,
    provenance_cxx,
    session_hxx,
    panel_hxx,
    panel_cxx,
    ui,
    library_mk,
    policy,
    timeline_policy,
    snapshot_policy,
    todo,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = review_hxx.read_text()
cxx = review_cxx.read_text()
registry_h = registry_hxx.read_text()
opener = opener_cxx.read_text()
preview = preview_cxx.read_text()
provenance = provenance_cxx.read_text()
session_h = session_hxx.read_text()
panel_h = panel_hxx.read_text()
panel = panel_cxx.read_text()
ui_text = ui.read_text()
mk = library_mk.read_text()
policy_text = policy.read_text()
timeline_text = timeline_policy.read_text()
snapshot_text = snapshot_policy.read_text()
todo_text = todo.read_text()
combined = hxx + cxx + registry_h + opener + preview + provenance + session_h + panel_h + panel + ui_text

required_review_fields = [
    "ReviewId",
    "SourceObjectId",
    "SourceType",
    "State",
    "ReviewMode",
    "EvidenceId",
    "HashReference",
    "OpenTarget",
    "PreviewMode",
    "RequiresHumanApproval",
    "MainDocumentMutationAllowed",
]

required_scope = [
    'rSourceType == u"selection"_ustr',
    'rSourceType == u"document-section"_ustr',
    'rSourceType == u"connector-result"_ustr',
    'rSourceType == u"knowledge-index-result"_ustr',
    'rSourceType == u"evidence-record"_ustr',
    'rSourceType == u"task-step"_ustr',
]

checks = {
    "policy review mode": "reviewMode=evidence-linked-content-diff" in policy_text,
    "policy requires evidence": "requiresEvidenceLink=true" in policy_text,
    "policy human approval": "requiresHumanApproval=true" in policy_text,
    "policy no mutation": "mainDocumentUnchangedUntilApproval=true" in policy_text,
    "review class": "class AIChatContentReviewStore final" in hxx,
    "review entry struct": "struct AIChatContentReviewEntry" in hxx,
    "review create result": "struct AIChatContentReviewCreateResult" in hxx,
    "all review fields": all(field in hxx for field in required_review_fields),
    "compiled": "sfx2/source/sidebar/AIChatContentReviewStore" in mk,
    "local namespace": "kqoffice-v3-ai-content-review" in cxx,
    "review file": "reviews.tsv" in cxx,
    "bounded read": "MAX_REVIEW_STORE_BYTES" in cxx,
    "append only store": "AppendUtf8Line" in cxx and "setPos(osl_Pos_Absolut, nSize)" in cxx,
    "escaped metadata": "EscapeField" in cxx and "UnescapeField" in cxx,
    "supported scope": all(needle in cxx for needle in required_scope),
    "no materialized type scope drift": 'rSourceType == u"plain-text-large"_ustr' not in cxx and 'rSourceType == u"structured-text"_ustr' not in cxx and 'rSourceType == u"content-suggestion"_ustr' not in cxx,
    "missing source guard": "review-create-failed reason=missing-source-object-id" in cxx,
    "unsupported source guard": "review-create-failed reason=unsupported-source-type" in cxx,
    "missing evidence guard": "review-create-failed reason=missing-evidence-link" in cxx,
    "missing hash guard": "review-create-failed reason=missing-hash-reference" in cxx,
    "review id helper": "MakeReviewId" in hxx + cxx and "review:" in cxx,
    "review mode runtime": 'aResult.Review.ReviewMode = u"evidence-linked-content-diff"_ustr' in cxx,
    "queued state": 'aResult.Review.State = u"queued"_ustr' in cxx,
    "diff review target": 'aResult.Review.OpenTarget = u"diff-review"_ustr' in cxx,
    "diff preview mode": 'aResult.Review.PreviewMode = u"diff-preview"_ustr' in cxx,
    "requires human approval": "RequiresHumanApproval = true" in cxx,
    "main mutation false": "MainDocumentMutationAllowed = false" in cxx,
    "registry review item": 'aResult.RegistryEntry.Type = u"review-item"_ustr' in cxx,
    "registry content review surface": 'aResult.RegistryEntry.SourceSurface = u"content-review"_ustr' in cxx,
    "registry in review state": 'aResult.RegistryEntry.State = u"in-review"_ustr' in cxx,
    "registry diff target": "aResult.RegistryEntry.OpenTarget = aResult.Review.OpenTarget" in cxx,
    "registry diff preview": "aResult.RegistryEntry.PreviewMode = aResult.Review.PreviewMode" in cxx,
    "registers review object": "AIChatContentRegistry aRegistry" in cxx and "aRegistry.RegisterObject(aResult.RegistryEntry)" in cxx,
    "registers provenance": "AIChatSourceProvenance aProvenance" in cxx and "aProvenance.RegisterSource(aSource)" in cxx,
    "provenance review item": 'aSource.SourceType = u"review-item"_ustr' in cxx,
    "source object span": "span:source-object:" in cxx,
    "success message": "content-review-created review-id=" in cxx,
    "uses diff review message": "uses-diff-review=true" in cxx,
    "approval message": "requires-human-approval=true" in cxx,
    "no mutation message": "main-document-mutation=false" in cxx,
    "preview routes review item": 'rEntry.Type == u"review-item"_ustr' in preview and "diff-review" in preview,
    "opener supports diff review": "diff-review" in opener and "read-only=true" in opener,
    "panel owns store": "std::unique_ptr<AIChatContentReviewStore> m_xContentReviewStore" in panel_h,
    "panel includes store": '#include "AIChatContentReviewStore.hxx"' in panel,
    "panel creates store": "std::make_unique<AIChatContentReviewStore>()" in panel,
    "ui review button": 'id="review_artifact_button"' in ui_text and "审查" in ui_text,
    "ui keyboard reachable": 'id="review_artifact_button"' in ui_text and '<property name="can-focus">True</property>' in ui_text,
    "panel wires review button": "OnReviewArtifactClicked" in panel_h + panel and "ReviewSelectedArtifact" in panel_h + panel,
    "panel create review": "m_xContentReviewStore->CreateReviewFromSource(*it)" in panel,
    "panel opens review through opener": "aOpener.OpenReadOnlyPreview(aReview.RegistryEntry)" in panel,
    "panel records review opened": 'u"review-opened"_ustr' in panel,
    "panel records review state": 'u"review-state-changed"_ustr' in panel,
    "timeline policy review events": "review-opened" in timeline_text and "review-state-changed" in timeline_text,
    "snapshot has review id": "OpenReviewId" in session_h and "open-review=" in panel,
    "snapshot has review state": "ReviewState" in session_h and "review-state=" in panel,
    "panel saves review snapshot": "SaveReviewSessionSnapshot" in panel_h + panel,
    "visible failure": "Review failed:" in panel and "review-create-failed reason=missing-registry-entry" in panel,
    "todo still at m3.1 or records m3": "M3.1 Implement content review runtime" in todo_text,
    "no raw review content": "RawContent" not in combined and "SuggestionContent" not in combined and "PreviewBody" not in combined and "Payload" not in combined,
    "no direct document mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
    "no apply path": "ApplyPlan" not in hxx + cxx + opener + preview + panel and "ExecuteList" not in hxx + cxx + opener + preview + panel,
    "no webview": "WebView" not in combined,
    "no cloud sync": "cloud" not in cxx.lower() and "sync" not in cxx.lower(),
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 content review runtime self-test passed. Checks: {len(checks)}")
PY
