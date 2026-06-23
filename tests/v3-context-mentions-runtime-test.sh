#!/usr/bin/env bash
# V3 W1 - chat-scoped explicit context mention runtime smoke.

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
from pathlib import Path

repo = Path(sys.argv[1])
src = Path(sys.argv[2])

panel_hxx = src / "sfx2/source/sidebar/AIChatPanel.hxx"
panel_cxx = src / "sfx2/source/sidebar/AIChatPanel.cxx"
context_policy = repo / "docs/product/v3/w1-context-syntax-policy.md"
autocomplete_policy = repo / "docs/product/v3/w1-context-autocomplete-policy.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [panel_hxx, panel_cxx, context_policy, autocomplete_policy, todo]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = panel_hxx.read_text()
cxx = panel_cxx.read_text()
context = context_policy.read_text()
autocomplete = autocomplete_policy.read_text()
todo_text = todo.read_text()
combined = hxx + cxx

checks = {
    "todo records m1.7 complete": "[x] M1.7 Add explicit context mentions and scoped autocomplete" in todo_text,
    "policy grammar": "@(selection|doc|connector:[a-z0-9-]+)" in context,
    "autocomplete scoped": "scope=chat-input-only" in autocomplete,
    "autocomplete delegates office": "officeAutocompletePolicy=delegate-existing-controls" in autocomplete,
    "mention result struct": "struct AIChatContextMentions" in hxx,
    "valid mention vector": "ValidMentions" in hxx,
    "invalid mention vector": "InvalidMentions" in hxx,
    "parse helper declared": "ParseContextMentions" in hxx,
    "parse helper implemented": "AIChatPanel::ParseContextMentions" in cxx,
    "update helper declared": "UpdateContextMentions" in hxx,
    "update helper implemented": "AIChatPanel::UpdateContextMentions" in cxx,
    "validate helper declared": "ValidateContextMentions" in hxx,
    "validate helper implemented": "AIChatPanel::ValidateContextMentions" in cxx,
    "changed updates mentions": "UpdateContextMentions();" in cxx and "OnPromptChanged" in cxx,
    "send validates mentions": "if (!ValidateContextMentions(sPrompt))" in cxx,
    "allowed selection": 'sMention == u"@selection"_ustr' in cxx,
    "allowed doc": 'sMention == u"@doc"_ustr' in cxx,
    "allowed connector": "IsValidConnectorMention" in cxx,
    "connector prefix": '@connector:' in cxx,
    "connector id chars": "IsConnectorIdChar" in cxx and "c == u'-'" in cxx,
    "mention boundary": "IsMentionBoundary" in cxx,
    "suggestion text": "Context: @selection, @doc, @connector:<id>" in cxx,
    "explicit context summary": "Explicit context:" in cxx,
    "invalid mention message": "Invalid context mention:" in cxx,
    "entry error state": "weld::EntryMessageType::Error" in cxx,
    "entry normal state": "weld::EntryMessageType::Normal" in cxx,
    "invalid fails closed": "SetState(AIChatPanelState::Failed)" in cxx,
    "invalid does not call provider first": cxx.find("if (!ValidateContextMentions(sPrompt))") < cxx.find("CallProvider(sPrompt)"),
    "no implicit document capture": "GetObjectShell()->GetMedium" not in cxx and "SwDoc" not in combined and "ScDoc" not in combined,
    "no connector fetch runtime": "ConnectorManager" not in cxx and "XConnector" not in cxx and "connector fetch" not in cxx.lower(),
    "no global autocomplete api": "set_entry_completion" not in combined and "EntryCompletion" not in combined,
    "no global office hook": "SfxViewFrame" not in cxx and "SID_AUTOCOMPLETE" not in combined,
    "no webview": "WebView" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

allowed_literals = set(re.findall(r'sMention == u"([^"]+)"_ustr', cxx))
if allowed_literals != {"@selection", "@doc"}:
    raise SystemExit(f"FAIL: unexpected direct mention literals {sorted(allowed_literals)}")

print(f"V3 context mentions runtime self-test passed. Checks: {len(checks) + 1}")
PY
