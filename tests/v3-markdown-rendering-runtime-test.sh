#!/usr/bin/env bash
# V3 W1 - native Markdown subset rendering smoke.

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

policy = repo / "docs/product/v3/w1-markdown-rendering-policy.md"
panel_hxx = src / "sfx2/source/sidebar/AIChatPanel.hxx"
panel_cxx = src / "sfx2/source/sidebar/AIChatPanel.cxx"
renderer_hxx = src / "sfx2/source/sidebar/AIChatMarkdownRenderer.hxx"
renderer_cxx = src / "sfx2/source/sidebar/AIChatMarkdownRenderer.cxx"
library = src / "sfx2/Library_sfx.mk"

for path in [policy, panel_hxx, panel_cxx, renderer_hxx, renderer_cxx, library]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

policy_text = policy.read_text()
panel_hxx_text = panel_hxx.read_text()
panel_cxx_text = panel_cxx.read_text()
renderer_hxx_text = renderer_hxx.read_text()
renderer_cxx_text = renderer_cxx.read_text()
library_text = library.read_text()

checks = {
    "policy allows paragraph": "paragraph" in policy_text,
    "policy allows heading": "heading" in policy_text,
    "policy allows list": "list" in policy_text,
    "policy allows code-fence": "code-fence" in policy_text,
    "policy allows table": "table" in policy_text,
    "renderer header result": "AIChatMarkdownRenderResult" in renderer_hxx_text,
    "renderer entry point": "RenderMarkdownSubset" in renderer_hxx_text + renderer_cxx_text,
    "renderer registered in sfx": "sfx2/source/sidebar/AIChatMarkdownRenderer" in library_text,
    "heading renderer": "StripHeadingMarker" in renderer_cxx_text,
    "list renderer": "StripListMarker" in renderer_cxx_text,
    "code fence marker": "CODE_FENCE_MARKER" in renderer_cxx_text,
    "code fence output": "[code]" in renderer_cxx_text and "[/code]" in renderer_cxx_text,
    "table renderer": "RenderTableLine" in renderer_cxx_text,
    "table separator skip": "IsTableSeparator" in renderer_cxx_text,
    "raw html guard": "ContainsRawHtml" in renderer_cxx_text,
    "script guard": "<script" in renderer_cxx_text,
    "iframe guard": "<iframe" in renderer_cxx_text,
    "html image guard": "<img" in renderer_cxx_text,
    "remote image guard": "ContainsRemoteImage" in renderer_cxx_text,
    "http image guard": "](http://" in renderer_cxx_text,
    "https image guard": "](https://" in renderer_cxx_text,
    "raw html rejection reason": "raw-html" in renderer_cxx_text,
    "remote image rejection reason": "remote-image" in renderer_cxx_text,
    "panel has markdown append": "AppendAssistantMarkdown" in panel_hxx_text + panel_cxx_text,
    "panel calls renderer": "RenderMarkdownSubset(rMarkdown)" in panel_cxx_text,
    "panel rejection transcript": "Markdown rejected:" in panel_cxx_text,
    "streaming chunks go through markdown": "AppendAssistantMarkdown(rChunk)" in panel_cxx_text,
    "no webview": "WebView" not in renderer_cxx_text + panel_cxx_text,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 Markdown renderer self-test passed. Checks: {len(checks)}")
PY
