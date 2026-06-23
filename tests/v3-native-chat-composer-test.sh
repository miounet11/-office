#!/usr/bin/env bash
# V3 W1 - native AI chat composer/transcript smoke.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src_root="$repo_root/libreoffice-core"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -d "$src_root" ]] || fail "missing source root $src_root"

python3 - "$src_root" <<'PY'
from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path

src = Path(sys.argv[1])

panel_hxx = src / "sfx2/source/sidebar/AIChatPanel.hxx"
panel_cxx = src / "sfx2/source/sidebar/AIChatPanel.cxx"
panel_ui = src / "sfx2/uiconfig/ui/aichatpanel.ui"

for path in [panel_hxx, panel_cxx, panel_ui]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = panel_hxx.read_text()
cxx = panel_cxx.read_text()
ui = panel_ui.read_text()

checks = {
    "state enum": "enum class AIChatPanelState" in hxx,
    "idle state": "AIChatPanelState::Idle" in hxx + cxx,
    "requesting state": "AIChatPanelState::Requesting" in hxx + cxx,
    "streaming state": "AIChatPanelState::Streaming" in hxx + cxx,
    "awaiting-approval state": "AIChatPanelState::AwaitingApproval" in hxx + cxx,
    "failed state": "AIChatPanelState::Failed" in hxx + cxx,
    "cancelled state": "AIChatPanelState::Cancelled" in hxx + cxx,
    "state label helper": "StateToLabel" in hxx + cxx,
    "focus prompt helper": "FocusPrompt()" in hxx + cxx,
    "entry activate sends": "connect_activate(LINK(this, AIChatPanel, OnPromptActivated))" in cxx,
    "send button sends": "connect_clicked(LINK(this, AIChatPanel, OnSendClicked))" in cxx,
    "cancel button wired": "connect_clicked(LINK(this, AIChatPanel, OnCancelClicked))" in cxx,
    "retry button wired": "connect_clicked(LINK(this, AIChatPanel, OnRetryClicked))" in cxx,
    "trim empty prompt": "get_text().trim()" in cxx and "sPrompt.isEmpty()" in cxx,
    "append user message": 'AppendTranscript(u"User"_ustr, sPrompt)' in cxx,
    "append assistant chunks": "AppendAssistantChunk" in cxx,
    "clear prompt after send": "m_xPromptEntry->set_text(OUString())" in cxx,
    "focus returns after send": "FocusPrompt();" in cxx,
    "cancel limited to busy states": "m_eState != AIChatPanelState::Requesting" in cxx and "m_eState != AIChatPanelState::Streaming" in cxx,
    "retry restores prompt": "m_xPromptEntry->set_text(m_sLastPrompt)" in cxx,
    "prompt disabled while busy": "m_xPromptEntry->set_sensitive(!bBusy)" in cxx,
    "send disabled while busy": "m_xSendButton->set_sensitive(bHasPrompt && !bBusy)" in cxx,
    "cancel enabled while busy": "m_xCancelButton->set_sensitive(bBusy)" in cxx,
    "retry disabled while busy": "m_xRetryButton->set_sensitive(!m_sLastPrompt.isEmpty() && !bBusy)" in cxx,
    "native transcript textview": 'class="GtkTextView" id="transcript_view"' in ui,
    "native prompt entry": 'class="GtkEntry" id="prompt_entry"' in ui,
    "native action box": 'id="action_box"' in ui,
    "no webview": "WebView" not in cxx + ui,
    "no direct kqoffice provider include": "#include <kqoffice" not in cxx and "#include <provider" not in cxx,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

try:
    ET.parse(panel_ui)
except ET.ParseError as exc:
    raise SystemExit(f"FAIL: XML parse {panel_ui}: {exc}") from exc

print(f"V3 native chat composer self-test passed. Checks: {len(checks)}")
PY
