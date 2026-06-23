#!/usr/bin/env bash
# V3 W1/M2.3 - artifact navigator runtime smoke.

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

registry_hxx = src / "sfx2/source/sidebar/AIChatContentRegistry.hxx"
registry_cxx = src / "sfx2/source/sidebar/AIChatContentRegistry.cxx"
panel_hxx = src / "sfx2/source/sidebar/AIChatPanel.hxx"
panel_cxx = src / "sfx2/source/sidebar/AIChatPanel.cxx"
panel_ui = src / "sfx2/uiconfig/ui/aichatpanel.ui"
artifact_policy = repo / "docs/product/v3/w1-artifact-navigator-policy.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [registry_hxx, registry_cxx, panel_hxx, panel_cxx, panel_ui, artifact_policy, todo]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

registry_h = registry_hxx.read_text()
registry = registry_cxx.read_text()
hxx = panel_hxx.read_text()
cxx = panel_cxx.read_text()
ui = panel_ui.read_text()
policy = artifact_policy.read_text()
todo_text = todo.read_text()
combined = registry_h + registry + hxx + cxx + ui

checks = {
    "todo records m2.3 complete": "[x] M2.3 Build artifact navigator runtime" in todo_text,
    "policy visible": "visible=true" in policy,
    "policy open uses openers": "openUsesContentOpeners=true" in policy,
    "policy read only details": "readOnlyDetails=true" in policy,
    "registry load api": "LoadEntries" in registry_h + registry,
    "registry archive api": "ArchiveObject" in registry_h + registry,
    "registry bounded read": "MAX_REGISTRY_BYTES" in registry,
    "registry unescape parser": "UnescapeField" in registry and "ParseRegistryLine" in registry,
    "registry recent first": "std::reverse(aVisibleEntries.begin(), aVisibleEntries.end())" in registry,
    "registry hides archived": 'rEntry.State != u"archived"_ustr' in registry,
    "archive append state": 'aEntry.State = u"archived"_ustr' in registry,
    "artifact tree member": "std::unique_ptr<weld::TreeView> m_xArtifactTree" in hxx,
    "artifact details member": "m_xArtifactDetailsLabel" in hxx,
    "artifact action members": "m_xRefreshArtifactsButton" in hxx and "m_xOpenArtifactButton" in hxx and "m_xRemoveArtifactButton" in hxx,
    "artifact vector": "std::vector<AIChatContentRegistryEntry> m_aArtifacts" in hxx,
    "tree wired": 'weld_tree_view(u"artifact_tree"_ustr)' in cxx,
    "single selection": "SelectionMode::Single" in cxx,
    "selection handler": "OnArtifactSelectionChanged" in hxx + cxx,
    "row activated handler": "OnArtifactRowActivated" in hxx + cxx,
    "refresh handler": "OnRefreshArtifactsClicked" in hxx + cxx,
    "open handler": "OnOpenArtifactClicked" in hxx + cxx,
    "remove handler": "OnRemoveArtifactClicked" in hxx + cxx,
    "load navigator": "LoadArtifactNavigator" in hxx + cxx and "aRegistry.LoadEntries()" in cxx,
    "refresh after materialization": "LoadArtifactNavigator();" in cxx,
    "row format has evidence badge": "no-evidence" in cxx and "evidence" in cxx,
    "details metadata only": "FormatArtifactDetails" in cxx and "open-target=" in cxx and "preview-mode=" in cxx,
    "open uses content opener": "AIChatContentOpener aOpener" in cxx and "OpenReadOnlyPreview" in cxx,
    "remove archives": "aRegistry.ArchiveObject(sSelectedId)" in cxx and "artifact-archived id=" in cxx,
    "ui navigator box": 'id="artifact_navigator_box"' in ui,
    "ui tree": 'class="GtkTreeView" id="artifact_tree"' in ui,
    "ui details": 'id="artifact_details_label"' in ui,
    "ui refresh": 'id="refresh_artifacts_button"' in ui,
    "ui open": 'id="open_artifact_button"' in ui,
    "ui remove": 'id="remove_artifact_button"' in ui,
    "ui accessibility": "AI artifacts" in ui and "Lists registered AI workspace artifacts" in ui,
    "no raw payload field": "RawContent" not in combined and "Payload" not in combined and "PreviewBody" not in combined,
    "no main doc mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
    "no webview": "WebView" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

try:
    ET.parse(panel_ui)
except ET.ParseError as exc:
    raise SystemExit(f"FAIL: XML parse {panel_ui}: {exc}") from exc

print(f"V3 artifact navigator runtime self-test passed. Checks: {len(checks)}")
PY
