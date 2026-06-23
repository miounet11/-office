#!/usr/bin/env bash
# V3 W1 - CommandPalette chat fallback route smoke.

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

import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

repo = Path(sys.argv[1])
src = Path(sys.argv[2])

command_palette = src / "cui/source/dialogs/commandpalette/CommandPalette.cxx"
dispatcher_hxx = src / "sfx2/inc/dispatch/CommandPaletteDispatcher.hxx"
dispatcher_cxx = src / "sfx2/source/dispatch/CommandPaletteDispatcher.cxx"
generic_commands = src / "officecfg/registry/data/org/openoffice/Office/UI/GenericCommands.xcu"
accelerators = src / "officecfg/registry/data/org/openoffice/Office/Accelerators.xcu"
sidebar = src / "officecfg/registry/data/org/openoffice/Office/UI/Sidebar.xcu"
dispatcher_test = src / "cui/qa/unit/CommandPaletteDispatcherTest.cxx"
w1_spec = repo / "docs/product/v3/w1-in-app-chat-spec.md"
shortcut_survey = repo / "docs/product/v3/w1-keyboard-shortcut-survey.md"

for path in [
    command_palette,
    dispatcher_hxx,
    dispatcher_cxx,
    generic_commands,
    accelerators,
    sidebar,
    dispatcher_test,
    w1_spec,
    shortcut_survey,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

command_palette_text = command_palette.read_text()
dispatcher_hxx_text = dispatcher_hxx.read_text()
dispatcher_cxx_text = dispatcher_cxx.read_text()
generic_commands_text = generic_commands.read_text()
accelerators_text = accelerators.read_text()
sidebar_text = sidebar.read_text()
dispatcher_test_text = dispatcher_test.read_text()
w1_spec_text = w1_spec.read_text()
shortcut_survey_text = shortcut_survey.read_text()

checks = {
    "entry activate handler": "m_xSearch->connect_activate" in command_palette_text,
    "activate callback declared": "OnSearchActivated" in command_palette_text,
    "first result selected": "m_xResults->select(0)" in command_palette_text,
    "command results short circuit": "if (!m_aLastResults.empty())" in command_palette_text,
    "first result enter fallback": "nRow = 0" in command_palette_text,
    "selected command first": "dispatchResultAt(nRow)" in command_palette_text,
    "fallback only after result guard": "const OUString aPrompt = m_xSearch->get_text().trim()" in command_palette_text,
    "non-empty prompt guard": "m_xSearch->get_text().trim()" in command_palette_text,
    "chat fallback call": "dispatchChatFallback(rFrame, aPrompt)" in command_palette_text,
    "result reuse helper": "bool CommandPalettePopover::dispatchResultAt(int nRow)" in command_palette_text,
    "recent command only for commands": "RecentStore::recordUse(aUserInst, aUrl)" in command_palette_text,
    "dispatcher header method": "dispatchChatFallback(SfxViewFrame& rFrame, OUString const& rPrompt)" in dispatcher_hxx_text,
    "dispatcher sidebar deck url": ".uno:SidebarDeck.AIChatDeck" in dispatcher_cxx_text,
    "dispatcher trims prompt": "rPrompt.trim()" in dispatcher_cxx_text,
    "dispatcher empty prompt guard": "aPrompt.isEmpty()" in dispatcher_cxx_text,
    "route attribution log": "chat fallback route" in dispatcher_cxx_text,
    "generic command registered": ".uno:SidebarDeck.AIChatDeck" in generic_commands_text,
    "generic command label": "Open the AI Chat Deck" in generic_commands_text,
    "sidebar deck exists": "AIChatDeck" in sidebar_text,
    "dispatcher cppunit guard": "testChatFallbackCommandRegistered" in dispatcher_test_text,
    "spec route locked": "CommandPalette chat fallback" in w1_spec_text,
    "shortcut survey route locked": "CommandPalette -> chat fallback" in shortcut_survey_text,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

if re.search(r"SidebarDeck\.AIChatDeck", accelerators_text):
    raise SystemExit("FAIL: W1 chat fallback must not add a direct accelerator")

try:
    ET.parse(generic_commands)
    ET.parse(sidebar)
except ET.ParseError as exc:
    raise SystemExit(f"FAIL: XML parse: {exc}") from exc

print(f"V3 CommandPalette chat fallback self-test passed. Checks: {len(checks) + 1}")
PY
