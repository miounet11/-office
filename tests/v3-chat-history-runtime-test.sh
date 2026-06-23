#!/usr/bin/env bash
# V3 W1 - per-document local AI chat history runtime smoke.

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
import xml.etree.ElementTree as ET
from pathlib import Path

repo = Path(sys.argv[1])
src = Path(sys.argv[2])

store_hxx = src / "sfx2/source/sidebar/AIChatHistoryStore.hxx"
store_cxx = src / "sfx2/source/sidebar/AIChatHistoryStore.cxx"
panel_hxx = src / "sfx2/source/sidebar/AIChatPanel.hxx"
panel_cxx = src / "sfx2/source/sidebar/AIChatPanel.cxx"
panel_ui = src / "sfx2/uiconfig/ui/aichatpanel.ui"
library_mk = src / "sfx2/Library_sfx.mk"
history_policy = repo / "docs/product/v3/w1-chat-history-policy.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [store_hxx, store_cxx, panel_hxx, panel_cxx, panel_ui, library_mk, history_policy, todo]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

store_header = store_hxx.read_text()
store = store_cxx.read_text()
panel_header = panel_hxx.read_text()
panel = panel_cxx.read_text()
ui = panel_ui.read_text()
mk = library_mk.read_text()
policy = history_policy.read_text()
todo_text = todo.read_text()

combined = store_header + store + panel_header + panel + ui + mk

checks = {
    "history policy per doc local": "history.scope = per-doc-local" in policy and "| Scope | per-doc-local |" in policy,
    "history policy sidecar": "history.storage = local-sqlite-sidecar" in policy and "| Storage | local-sqlite-sidecar |" in policy,
    "todo records m1.6 complete": "[x] M1.6 Add per-document local chat history" in todo_text,
    "store header class": "class AIChatHistoryStore final" in store_header,
    "store compiled": "sfx2/source/sidebar/AIChatHistoryStore" in mk,
    "current document identity": "ResolveCurrentDocumentIdentity" in store_header + store,
    "document shell current": "SfxObjectShell::Current()" in store,
    "document url binding": "GetURLObject().GetMainURL" in store,
    "unsaved document key": "unsaved-object-shell:" in store,
    "document hash helper": "MakeDocumentHash" in store_header + store,
    "sha256 document id hash": "comphelper::HashType::SHA256" in store and "hashToString" in store,
    "user config sidecar root": "SvtPathOptions" in store and "GetUserConfigPath()" in store,
    "local sidecar namespace": "kqoffice-v3-ai-chat-history" in store,
    "sidecar suffix": ".history" in store,
    "no cloud sync runtime": "cloud" not in store.lower() and "sync" not in store.lower(),
    "no global index runtime": "GlobalHistory" not in store and "GlobalIndex" not in store and "globalIndex" not in store,
    "append message api": "AppendMessage" in store_header + store,
    "load transcript api": "LoadTranscript" in store_header + store,
    "clear api": "Clear() const" in store_header + store,
    "clear deletes sidecar": "osl::File::remove" in store,
    "bounded history read": "MAX_HISTORY_BYTES" in store,
    "utf8 sidecar serialization": "RTL_TEXTENCODING_UTF8" in store,
    "escaped records": "EscapeField" in store and "UnescapeField" in store,
    "panel owns history store": "std::unique_ptr<AIChatHistoryStore> m_xHistoryStore" in panel_header,
    "panel constructs history store": "std::make_unique<AIChatHistoryStore>()" in panel,
    "panel loads document history": "LoadDocumentHistory();" in panel and "AIChatPanel::LoadDocumentHistory" in panel,
    "history loaded marker": "history-loaded document-id-hash=" in panel,
    "append persists history": "m_xHistoryStore->AppendMessage" in panel,
    "clear history handler": "OnClearHistoryClicked" in panel_header + panel,
    "clear history method": "ClearDocumentHistory" in panel_header + panel,
    "clear calls store": "m_xHistoryStore->Clear()" in panel,
    "clear does not persist marker": "history-cleared for current document" in panel and "false);" in panel,
    "clear button in ui": 'id="clear_history_button"' in ui,
    "clear button accessible": "Clears local AI chat history for the current document." in ui,
    "clear button wired": "weld_button(u\"clear_history_button\"_ustr)" in panel,
    "clear disabled busy": "m_xClearHistoryButton->set_sensitive(!bBusy)" in panel,
    "history does not mutate document": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
    "no webview": "WebView" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

try:
    ET.parse(panel_ui)
except ET.ParseError as exc:
    raise SystemExit(f"FAIL: XML parse {panel_ui}: {exc}") from exc

print(f"V3 chat history runtime self-test passed. Checks: {len(checks)}")
PY
