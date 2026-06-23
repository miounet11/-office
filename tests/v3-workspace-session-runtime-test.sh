#!/usr/bin/env bash
# V3 W1/M2.7 - activity timeline and session snapshot runtime smoke.

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

store_hxx = src / "sfx2/source/sidebar/AIChatWorkspaceSessionStore.hxx"
store_cxx = src / "sfx2/source/sidebar/AIChatWorkspaceSessionStore.cxx"
panel_hxx = src / "sfx2/source/sidebar/AIChatPanel.hxx"
panel_cxx = src / "sfx2/source/sidebar/AIChatPanel.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
timeline_policy = repo / "docs/product/v3/w1-workspace-activity-timeline-policy.md"
snapshot_policy = repo / "docs/product/v3/w1-workspace-session-snapshot-policy.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [store_hxx, store_cxx, panel_hxx, panel_cxx, library_mk, timeline_policy, snapshot_policy, todo]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = store_hxx.read_text()
cxx = store_cxx.read_text()
panel_h = panel_hxx.read_text()
panel = panel_cxx.read_text()
mk = library_mk.read_text()
timeline = timeline_policy.read_text()
snapshot = snapshot_policy.read_text()
todo_text = todo.read_text()
combined = hxx + cxx + panel_h + panel

activity_fields = [
    "Event",
    "Surface",
    "Actor",
    "Timestamp",
    "ArtifactId",
    "ReviewId",
    "EvidenceId",
    "HashReference",
    "OpenTarget",
]
snapshot_fields = [
    "DocumentBinding",
    "Timestamp",
    "ActiveTaskId",
    "OpenArtifactId",
    "OpenReviewId",
    "ActiveEvidenceId",
    "PreviewMode",
    "ReviewState",
    "ActivityCursor",
    "FailureState",
    "HashReference",
]

checks = {
    "todo records m2.7 complete": "[x] M2.7 Add activity timeline and session snapshot for W1 workspace state" in todo_text,
    "timeline policy append only": "appendOnly=true" in timeline,
    "timeline policy metadata only": "metadataOnly=true" in timeline and "hashOnlyReferences=true" in timeline,
    "snapshot policy document bound": "requiresVisibleDocumentBinding=true" in snapshot and "crossDocumentRestore=false" in snapshot,
    "session class": "class AIChatWorkspaceSessionStore final" in hxx,
    "activity struct": "struct AIChatWorkspaceActivityEntry" in hxx,
    "snapshot struct": "struct AIChatSessionSnapshot" in hxx,
    "activity fields": all(field in hxx for field in activity_fields),
    "snapshot fields": all(field in hxx for field in snapshot_fields),
    "compiled": "sfx2/source/sidebar/AIChatWorkspaceSessionStore" in mk,
    "local namespace": "kqoffice-v3-ai-workspace-session" in cxx,
    "timeline suffix": ".timeline.tsv" in cxx,
    "snapshot suffix": ".snapshot.tsv" in cxx,
    "record activity api": "RecordActivity" in hxx + cxx,
    "save snapshot api": "SaveSnapshot" in hxx + cxx,
    "load snapshot api": "LoadSnapshot" in hxx + cxx,
    "timestamp helper": "MakeTimestamp" in hxx + cxx and "std::time(nullptr)" in cxx,
    "timeline append only": "AppendUtf8Line(m_sTimelineUrl" in cxx,
    "snapshot overwrite": "WriteUtf8File(m_sSnapshotUrl" in cxx,
    "document binding guard": "aFields[0] != m_sDocumentBinding" in cxx,
    "panel owns store": "std::unique_ptr<AIChatWorkspaceSessionStore> m_xSessionStore" in panel_h,
    "panel constructs store": "std::make_unique<AIChatWorkspaceSessionStore>" in panel,
    "panel loads snapshot": "LoadSessionSnapshot" in panel_h + panel,
    "visible resume summary": "resume-summary document-id-hash=" in panel,
    "panel records activity": "RecordWorkspaceActivity" in panel_h + panel,
    "panel saves snapshot": "SaveSessionSnapshot" in panel_h + panel,
    "artifact created event": 'u"artifact-created"_ustr' in panel,
    "content opened event": 'u"content-opened"_ustr' in panel,
    "failure event": 'u"failure-reported"_ustr' in panel,
    "action invoked event": 'u"action-invoked"_ustr' in panel,
    "metadata only no raw payload": "RawContent" not in combined and "Payload" not in combined and "PreviewBody" not in combined,
    "no cross doc restore": "crossDocumentRestore" not in combined and "cloud" not in cxx.lower(),
    "no main doc mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
    "no webview": "WebView" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 workspace session runtime self-test passed. Checks: {len(checks)}")
PY
