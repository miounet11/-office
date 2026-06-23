#!/usr/bin/env bash
# V3 W1/M2.5 - content preview matrix runtime smoke.

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

preview_hxx = src / "sfx2/source/sidebar/AIChatPreviewMatrix.hxx"
preview_cxx = src / "sfx2/source/sidebar/AIChatPreviewMatrix.cxx"
opener_hxx = src / "sfx2/source/sidebar/AIChatContentOpener.hxx"
opener_cxx = src / "sfx2/source/sidebar/AIChatContentOpener.cxx"
panel_cxx = src / "sfx2/source/sidebar/AIChatPanel.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
preview_policy = repo / "docs/product/v3/w1-content-preview-matrix-policy.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [preview_hxx, preview_cxx, opener_hxx, opener_cxx, panel_cxx, library_mk, preview_policy, todo]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = preview_hxx.read_text()
cxx = preview_cxx.read_text()
opener_h = opener_hxx.read_text()
opener = opener_cxx.read_text()
panel = panel_cxx.read_text()
mk = library_mk.read_text()
policy = preview_policy.read_text()
todo_text = todo.read_text()
combined = hxx + cxx + opener_h + opener + panel

checks = {
    "todo records m2.5 complete": "[x] M2.5 Build preview matrix runtime" in todo_text,
    "policy modes": "previewModes=[metadata-summary,read-only-preview,diff-preview,evidence-summary]" in policy,
    "policy evidence badge": "showsEvidenceBadge=true" in policy,
    "policy source metadata": "showsSourceMetadata=true" in policy,
    "policy redacts raw": "redactsRawPayload=true" in policy and "hashOnlyReferences=true" in policy,
    "preview class": "class AIChatPreviewMatrix final" in hxx,
    "preview result": "struct AIChatPreviewResult" in hxx,
    "preview compiled": "sfx2/source/sidebar/AIChatPreviewMatrix" in mk,
    "build preview api": "BuildPreview" in hxx + cxx,
    "resolve target api": "ResolvePreviewTarget" in hxx + cxx,
    "resolve mode api": "ResolvePreviewMode" in hxx + cxx,
    "document target": 'rEntry.Type == u"document"_ustr' in cxx and "main-document-window" in cxx,
    "selection target": 'rEntry.Type == u"selection"_ustr' in cxx and "sidebar-preview" in cxx,
    "connector target": 'rEntry.Type == u"connector-result"_ustr' in cxx,
    "knowledge target": 'rEntry.Type == u"knowledge-index-result"_ustr' in cxx,
    "evidence target": 'rEntry.Type == u"evidence-record"_ustr' in cxx,
    "task target": 'rEntry.Type == u"task-step"_ustr' in cxx and "diff-review" in cxx,
    "review item target": 'rEntry.Type == u"review-item"_ustr' in cxx and "diff-review" in cxx,
    "diff mode": "diff-preview" in cxx,
    "evidence mode": "evidence-summary" in cxx,
    "metadata mode": "metadata-summary" in cxx,
    "evidence badge": "evidence=missing" in cxx and "evidence=linked" in cxx,
    "source metadata": "SourceMetadata" in hxx + cxx and "source=" in cxx and "hash=" in cxx,
    "redacted summary": "redacted=true" in cxx and "hash-only=true" in cxx and "read-only=true" in cxx,
    "visible failure": "preview-failed reason=missing-object-id" in cxx and "preview-failed reason=unsupported-target" in cxx,
    "opener stores preview summary": "OUString PreviewSummary" in opener_h,
    "opener uses matrix": "AIChatPreviewMatrix aPreviewMatrix" in opener and "aPreviewMatrix.BuildPreview" in opener,
    "opener marks matrix": "preview-matrix=true" in opener,
    "panel includes preview matrix": '#include "AIChatPreviewMatrix.hxx"' in panel,
    "panel details show preview": "preview-target=" in panel and "preview-summary=" in panel and "source-metadata=" in panel,
    "no raw payload": "RawContent" not in combined and "Payload" not in combined and "PreviewBody" not in combined,
    "no main doc mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
    "no webview": "WebView" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 preview matrix runtime self-test passed. Checks: {len(checks)}")
PY
