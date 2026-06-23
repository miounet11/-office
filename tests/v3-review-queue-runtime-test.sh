#!/usr/bin/env bash
# V3 W1/M3.3 - review queue runtime smoke.

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

queue_hxx = src / "sfx2/source/sidebar/AIChatReviewQueueStore.hxx"
queue_cxx = src / "sfx2/source/sidebar/AIChatReviewQueueStore.cxx"
content_review = src / "sfx2/source/sidebar/AIChatContentReviewStore.cxx"
format_review = src / "sfx2/source/sidebar/AIChatFormattingReviewStore.cxx"
opener_cxx = src / "sfx2/source/sidebar/AIChatContentOpener.cxx"
panel_hxx = src / "sfx2/source/sidebar/AIChatPanel.hxx"
panel_cxx = src / "sfx2/source/sidebar/AIChatPanel.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
policy = repo / "docs/product/v3/w1-review-queue-policy.md"
state_sync_policy = repo / "docs/product/v3/w1-workspace-review-state-sync-policy.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [
    queue_hxx,
    queue_cxx,
    content_review,
    format_review,
    opener_cxx,
    panel_hxx,
    panel_cxx,
    library_mk,
    policy,
    state_sync_policy,
    todo,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = queue_hxx.read_text()
cxx = queue_cxx.read_text()
content = content_review.read_text()
formatting = format_review.read_text()
opener = opener_cxx.read_text()
panel_h = panel_hxx.read_text()
panel = panel_cxx.read_text()
mk = library_mk.read_text()
policy_text = policy.read_text()
sync_text = state_sync_policy.read_text()
todo_text = todo.read_text()
combined = hxx + cxx + content + formatting + opener + panel_h + panel

fields = [
    "ReviewId",
    "ItemType",
    "State",
    "SourceSurface",
    "EvidenceId",
    "HashReference",
    "OpenTarget",
    "PreviewMode",
]
states = [
    'rState == u"queued"_ustr',
    'rState == u"open"_ustr',
    'rState == u"approved"_ustr',
    'rState == u"rejected"_ustr',
    'rState == u"applied"_ustr',
    'rState == u"failed"_ustr',
]

checks = {
    "policy item types": "itemTypes=[content-review,formatting-review,task-step]" in policy_text,
    "policy states": "states=[queued,open,approved,rejected,applied,failed]" in policy_text,
    "policy filters": "filterBy=[state,type,surface]" in policy_text,
    "policy bulk actions": "bulkActions=[approve-selected,reject-selected]" in policy_text,
    "policy no mutation": "mainDocumentMutationAllowed=false" in policy_text,
    "sync policy states": "transitionEvents=[open,approve,reject,apply,fail]" in sync_text,
    "queue class": "class AIChatReviewQueueStore final" in hxx,
    "queue entry": "struct AIChatReviewQueueEntry" in hxx,
    "queue filter": "struct AIChatReviewQueueFilter" in hxx,
    "all fields": all(field in hxx for field in fields),
    "compiled": "sfx2/source/sidebar/AIChatReviewQueueStore" in mk,
    "local namespace": "kqoffice-v3-ai-review-queue" in cxx,
    "queue file": "queue.tsv" in cxx,
    "bounded read": "MAX_REVIEW_QUEUE_BYTES" in cxx,
    "append only store": "AppendUtf8Line" in cxx and "setPos(osl_Pos_Absolut, nSize)" in cxx,
    "escaped metadata": "EscapeField" in cxx and "UnescapeField" in cxx,
    "enqueue api": "EnqueueFromRegistry" in hxx + cxx,
    "transition api": "TransitionState" in hxx + cxx,
    "load api": "LoadEntries" in hxx + cxx,
    "filter api": "FilterEntries" in hxx + cxx,
    "review queue entry guard": "IsReviewQueueEntry" in hxx + cxx,
    "valid states": all(needle in cxx for needle in states),
    "content review item type": 'return u"content-review"_ustr' in cxx,
    "formatting review item type": 'return u"formatting-review"_ustr' in cxx,
    "task step item type": 'return u"task-step"_ustr' in cxx,
    "unsupported guard": 'return u"unsupported"_ustr' in cxx,
    "requires evidence": "rEntry.EvidenceId.isEmpty()" in cxx,
    "state from registry": "StateFromRegistryState" in cxx and 'rState == u"in-review"_ustr' in cxx,
    "latest state wins": "std::find_if" in cxx and "*it = aEntry" in cxx,
    "filters state": "rFilter.State" in cxx and "rEntry.State != rFilter.State" in cxx,
    "filters type": "rFilter.ItemType" in cxx and "rEntry.ItemType != rFilter.ItemType" in cxx,
    "filters surface": "rFilter.Surface" in cxx and "rEntry.SourceSurface != rFilter.Surface" in cxx,
    "bulk approve only": "IsBulkActionAllowed" in hxx + cxx and 'rAction == u"approve-selected"_ustr' in cxx,
    "bulk reject only": 'rAction == u"reject-selected"_ustr' in cxx,
    "content review enqueues": "AIChatReviewQueueStore aQueue" in content and "aQueue.EnqueueFromRegistry(aResult.RegistryEntry)" in content,
    "formatting review enqueues": "AIChatReviewQueueStore aQueue" in formatting and "aQueue.EnqueueFromRegistry(aResult.RegistryEntry)" in formatting,
    "opener supports review queue target": "review-queue" in opener,
    "panel owns queue": "std::unique_ptr<AIChatReviewQueueStore> m_xReviewQueueStore" in panel_h,
    "panel includes queue": '#include "AIChatReviewQueueStore.hxx"' in panel,
    "panel creates queue": "std::make_unique<AIChatReviewQueueStore>()" in panel,
    "todo has m3.3": "M3.3 Implement review queue runtime" in todo_text,
    "no raw payload": "RawContent" not in combined and "Payload" not in combined and "PreviewBody" not in combined and "SuggestionContent" not in combined,
    "no direct document mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
    "no apply path": "ApplyPlan" not in combined and "ExecuteList" not in combined,
    "no auto apply": "auto-apply" not in cxx.lower() and "autoApply" not in cxx,
    "no webview": "WebView" not in combined,
    "no cloud": "cloud" not in cxx.lower(),
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 review queue runtime self-test passed. Checks: {len(checks)}")
PY
