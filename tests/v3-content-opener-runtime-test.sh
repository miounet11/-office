#!/usr/bin/env bash
# V3 W1/M2.4 - content opener route runtime smoke.

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

opener_hxx = src / "sfx2/source/sidebar/AIChatContentOpener.hxx"
opener_cxx = src / "sfx2/source/sidebar/AIChatContentOpener.cxx"
preview_cxx = src / "sfx2/source/sidebar/AIChatPreviewMatrix.cxx"
panel_cxx = src / "sfx2/source/sidebar/AIChatPanel.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
opener_policy = repo / "docs/product/v3/w1-content-opener-policy.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [opener_hxx, opener_cxx, preview_cxx, panel_cxx, library_mk, opener_policy, todo]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = opener_hxx.read_text()
cxx = opener_cxx.read_text()
preview = preview_cxx.read_text()
panel = panel_cxx.read_text()
mk = library_mk.read_text()
policy = opener_policy.read_text()
todo_text = todo.read_text()
combined = hxx + cxx + preview + panel

checks = {
    "todo records m2.4 complete": "[x] M2.4 Build content opener runtime" in todo_text,
    "policy supported targets": "opensIn=[main-document-window,sidebar-preview,diff-review]" in policy,
    "policy read only": "readOnlyPreview=true" in policy,
    "policy failure visible": "openFailureBehavior=fail-closed-user-visible" in policy,
    "opener class": "class AIChatContentOpener final" in hxx,
    "open result struct": "struct AIChatContentOpenResult" in hxx,
    "opener compiled": "sfx2/source/sidebar/AIChatContentOpener" in mk,
    "open method": "OpenReadOnlyPreview" in hxx + cxx,
    "resolve target": "ResolveOpenTarget" in hxx + cxx,
    "supported target guard": "IsSupportedTarget" in hxx + cxx,
    "document route": 'rEntry.Type == u"document"_ustr' in preview and "main-document-window" in preview,
    "task route": 'rEntry.Type == u"task-step"_ustr' in preview and "diff-review" in preview,
    "sidebar preview route": "sidebar-preview" in preview,
    "opener uses preview matrix": "AIChatPreviewMatrix aPreviewMatrix" in cxx and "BuildPreview(rEntry)" in cxx,
    "unsupported target fails": "open-failed reason=unsupported-target" in cxx,
    "missing id fails": "open-failed reason=missing-object-id" in cxx,
    "read only message": "read-only=true" in cxx,
    "no mutation message": "main-document-mutation=false" in cxx,
    "panel includes opener": '#include "AIChatContentOpener.hxx"' in panel,
    "panel invokes opener": "AIChatContentOpener aOpener" in panel and "aOpener.OpenReadOnlyPreview" in panel,
    "panel visible failure": "Open failed:" in panel and "open-failed reason=missing-registry-entry" in panel,
    "no direct document mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
    "no dispatch apply": "ExecuteList" not in cxx + preview and "ApplyPlan" not in cxx + preview,
    "no raw payload": "RawContent" not in combined and "Payload" not in combined and "PreviewBody" not in combined,
    "no webview": "WebView" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 content opener runtime self-test passed. Checks: {len(checks)}")
PY
