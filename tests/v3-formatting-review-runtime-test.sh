#!/usr/bin/env bash
# V3 W1/M3.2 - formatting/layout review runtime smoke.

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

fmt_hxx = src / "sfx2/source/sidebar/AIChatFormattingReviewStore.hxx"
fmt_cxx = src / "sfx2/source/sidebar/AIChatFormattingReviewStore.cxx"
preview_cxx = src / "sfx2/source/sidebar/AIChatPreviewMatrix.cxx"
opener_cxx = src / "sfx2/source/sidebar/AIChatContentOpener.cxx"
panel_hxx = src / "sfx2/source/sidebar/AIChatPanel.hxx"
panel_cxx = src / "sfx2/source/sidebar/AIChatPanel.cxx"
ui = src / "sfx2/uiconfig/ui/aichatpanel.ui"
library_mk = src / "sfx2/Library_sfx.mk"
policy = repo / "docs/product/v3/w1-formatting-review-policy.md"
registry_policy = repo / "docs/product/v3/w1-workspace-content-registry-policy.md"
provenance_policy = repo / "docs/product/v3/w1-workspace-source-provenance-policy.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [
    fmt_hxx,
    fmt_cxx,
    preview_cxx,
    opener_cxx,
    panel_hxx,
    panel_cxx,
    ui,
    library_mk,
    policy,
    registry_policy,
    provenance_policy,
    todo,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = fmt_hxx.read_text()
cxx = fmt_cxx.read_text()
preview = preview_cxx.read_text()
opener = opener_cxx.read_text()
panel_h = panel_hxx.read_text()
panel = panel_cxx.read_text()
ui_text = ui.read_text()
mk = library_mk.read_text()
policy_text = policy.read_text()
registry_policy_text = registry_policy.read_text()
provenance_policy_text = provenance_policy.read_text()
todo_text = todo.read_text()
combined = hxx + cxx + preview + opener + panel_h + panel + ui_text

required_fields = [
    "ReviewId",
    "SourceObjectId",
    "FormattingScope",
    "State",
    "ReviewMode",
    "EvidenceId",
    "HashReference",
    "OpenTarget",
    "PreviewMode",
    "RequiresHumanApproval",
    "MainDocumentMutationAllowed",
]
required_scopes = [
    'rScope == u"paragraph-style"_ustr',
    'rScope == u"character-style"_ustr',
    'rScope == u"table-layout"_ustr',
    'rScope == u"cell-format"_ustr',
    'rScope == u"slide-layout"_ustr',
]

checks = {
    "policy scope": "scope=[paragraph-style,character-style,table-layout,cell-format,slide-layout]" in policy_text,
    "policy mode": "reviewMode=before-after-layout-diff" in policy_text,
    "policy diff review": "usesDiffReview=true" in policy_text,
    "policy evidence": "requiresEvidenceLink=true" in policy_text,
    "policy approval": "requiresHumanApproval=true" in policy_text,
    "policy no mutation": "mainDocumentUnchangedUntilApproval=true" in policy_text,
    "registry supports formatting preview": "formatting-preview" in registry_policy_text,
    "provenance supports formatting preview": "formatting-preview" in provenance_policy_text,
    "formatting class": "class AIChatFormattingReviewStore final" in hxx,
    "formatting entry struct": "struct AIChatFormattingReviewEntry" in hxx,
    "formatting create result": "struct AIChatFormattingReviewCreateResult" in hxx,
    "all fields": all(field in hxx for field in required_fields),
    "compiled": "sfx2/source/sidebar/AIChatFormattingReviewStore" in mk,
    "local namespace": "kqoffice-v3-ai-formatting-review" in cxx,
    "review file": "formatting-reviews.tsv" in cxx,
    "bounded read": "MAX_FORMATTING_REVIEW_STORE_BYTES" in cxx,
    "append only store": "AppendUtf8Line" in cxx and "setPos(osl_Pos_Absolut, nSize)" in cxx,
    "escaped metadata": "EscapeField" in cxx and "UnescapeField" in cxx,
    "supported scopes": all(needle in cxx for needle in required_scopes),
    "missing source guard": "formatting-review-create-failed reason=missing-source-object-id" in cxx,
    "unsupported scope guard": "formatting-review-create-failed reason=unsupported-formatting-scope" in cxx,
    "missing evidence guard": "formatting-review-create-failed reason=missing-evidence-link" in cxx,
    "missing hash guard": "formatting-review-create-failed reason=missing-hash-reference" in cxx,
    "review id helper": "MakeReviewId" in hxx + cxx and "formatting-review:" in cxx,
    "before after mode": 'aResult.Review.ReviewMode = u"before-after-layout-diff"_ustr' in cxx,
    "queued state": 'aResult.Review.State = u"queued"_ustr' in cxx,
    "diff target": 'aResult.Review.OpenTarget = u"diff-review"_ustr' in cxx,
    "diff preview": 'aResult.Review.PreviewMode = u"diff-preview"_ustr' in cxx,
    "requires human approval": "RequiresHumanApproval = true" in cxx,
    "main mutation false": "MainDocumentMutationAllowed = false" in cxx,
    "registry formatting preview": 'aResult.RegistryEntry.Type = u"formatting-preview"_ustr' in cxx,
    "registry surface": 'aResult.RegistryEntry.SourceSurface = u"formatting-review"_ustr' in cxx,
    "registry in review": 'aResult.RegistryEntry.State = u"in-review"_ustr' in cxx,
    "registers registry": "AIChatContentRegistry aRegistry" in cxx and "aRegistry.RegisterObject(aResult.RegistryEntry)" in cxx,
    "registers provenance": "AIChatSourceProvenance aProvenance" in cxx and "aProvenance.RegisterSource(aSource)" in cxx,
    "provenance source type": 'aSource.SourceType = u"formatting-preview"_ustr' in cxx,
    "formatting span": "span:formatting-scope:" in cxx,
    "success message": "formatting-review-created review-id=" in cxx,
    "mode message": "review-mode=before-after-layout-diff" in cxx,
    "diff review message": "uses-diff-review=true" in cxx,
    "approval message": "requires-human-approval=true" in cxx,
    "no mutation message": "main-document-mutation=false" in cxx,
    "preview routes formatting preview": 'rEntry.Type == u"formatting-preview"_ustr' in preview and "diff-review" in preview and "diff-preview" in preview,
    "opener remains read only": "read-only=true" in opener and "main-document-mutation=false" in opener,
    "panel owns store": "std::unique_ptr<AIChatFormattingReviewStore> m_xFormattingReviewStore" in panel_h,
    "panel includes store": '#include "AIChatFormattingReviewStore.hxx"' in panel,
    "panel creates store": "std::make_unique<AIChatFormattingReviewStore>()" in panel,
    "ui formatting button": 'id="format_artifact_button"' in ui_text and "排版审查" in ui_text,
    "ui keyboard reachable": 'id="format_artifact_button"' in ui_text and '<property name="can-focus">True</property>' in ui_text,
    "panel wires button": "OnFormatArtifactClicked" in panel_h + panel and "ReviewSelectedFormatting" in panel_h + panel,
    "panel scope guard": "AIChatFormattingReviewStore::IsSupportedFormattingScope(pSelected->Type)" in panel,
    "panel creates review": "m_xFormattingReviewStore->CreateReviewFromSource(*it)" in panel,
    "panel opens through opener": "aOpener.OpenReadOnlyPreview(aReview.RegistryEntry)" in panel,
    "panel records review opened": 'u"review-opened"_ustr' in panel,
    "panel records review state": 'u"review-state-changed"_ustr' in panel,
    "visible failure": "Formatting review failed:" in panel and "formatting-review-create-failed reason=missing-registry-entry" in panel,
    "todo has m3.2": "M3.2 Implement formatting review runtime" in todo_text,
    "no raw preview content": "RawContent" not in combined and "PreviewBody" not in combined and "Payload" not in combined and "RenderedPreview" not in combined and "Screenshot" not in combined,
    "no direct document mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
    "no apply path": "ApplyPlan" not in combined and "ExecuteList" not in combined,
    "no webview": "WebView" not in combined,
    "no cloud sync": "cloud" not in cxx.lower() and "sync" not in cxx.lower(),
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 formatting review runtime self-test passed. Checks: {len(checks)}")
PY
