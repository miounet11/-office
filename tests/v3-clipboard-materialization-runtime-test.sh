#!/usr/bin/env bash
# V3 W1/M2.1 - Codex-style chat clipboard/content materialization smoke.

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

store_hxx = src / "sfx2/source/sidebar/AIChatContentObjectStore.hxx"
store_cxx = src / "sfx2/source/sidebar/AIChatContentObjectStore.cxx"
panel_hxx = src / "sfx2/source/sidebar/AIChatPanel.hxx"
panel_cxx = src / "sfx2/source/sidebar/AIChatPanel.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
clipboard_policy = repo / "docs/product/v3/w1-chat-clipboard-materialization-policy.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [store_hxx, store_cxx, panel_hxx, panel_cxx, library_mk, clipboard_policy, todo]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = store_hxx.read_text()
cxx = store_cxx.read_text()
panel_h = panel_hxx.read_text()
panel = panel_cxx.read_text()
mk = library_mk.read_text()
policy = clipboard_policy.read_text()
todo_text = todo.read_text()
combined = hxx + cxx + panel_h + panel

checks = {
    "todo records m2.1 complete": "[x] M2.1 Implement chat clipboard materialization runtime" in todo_text,
    "policy local temp object": "storage=local-temp-content-object" in policy,
    "policy reference inserted": "referenceInsertedIntoChat=true" in policy,
    "policy transcript reference only": "transcriptStoresReferenceOnly=true" in policy,
    "content object class": "class AIChatContentObjectStore final" in hxx,
    "materialized content struct": "struct AIChatMaterializedContent" in hxx,
    "object types": "PlainTextLarge" in hxx and "StructuredText" in hxx,
    "store compiled": "sfx2/source/sidebar/AIChatContentObjectStore" in mk,
    "local object namespace": "kqoffice-v3-ai-chat-objects" in cxx,
    "sidecar suffix": ".content" in cxx,
    "large text threshold": "LARGE_TEXT_THRESHOLD = 2000" in cxx,
    "structured text threshold": "STRUCTURED_TEXT_THRESHOLD = 40" in cxx,
    "structured detection": "LooksStructured" in cxx and "rText.indexOf(u'\\t')" in cxx,
    "sha256 object id": "comphelper::HashType::SHA256" in cxx and "hashToString" in cxx,
    "artifact reference": '@artifact:' in cxx,
    "user config storage": "SvtPathOptions" in cxx and "GetUserConfigPath()" in cxx,
    "utf8 payload file": "WriteUtf8File" in cxx and "RTL_TEXTENCODING_UTF8" in cxx,
    "panel owns store": "std::unique_ptr<AIChatContentObjectStore> m_xContentObjectStore" in panel_h,
    "panel constructs store": "std::make_unique<AIChatContentObjectStore>()" in panel,
    "insert text hook declared": "OnPromptInsertText" in panel_h,
    "insert text hook wired": "connect_insert_text(LINK(this, AIChatPanel, OnPromptInsertText))" in panel,
    "materialize helper": "MaterializeInsertedContent" in panel_h + panel,
    "insert text replaced with reference": "rInsertedText = aContent.Reference" in panel,
    "system metadata line": "materialized-content reference=" in panel,
    "metadata type line": "type=" in panel,
    "status feedback": "Content object inserted:" in panel,
    "no raw clipboard symbol in transcript": "rawClipboard" not in combined and "clipboard body" not in combined.lower(),
    "no main doc mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
    "no cloud sync": "cloud" not in cxx.lower() and "sync" not in cxx.lower(),
    "no webview": "WebView" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 clipboard materialization runtime self-test passed. Checks: {len(checks)}")
PY
