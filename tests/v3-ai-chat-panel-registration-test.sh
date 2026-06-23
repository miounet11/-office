#!/usr/bin/env bash
# V3 W1 - AI chat sidebar panel registration smoke.

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

sidebar = src / "officecfg/registry/data/org/openoffice/Office/UI/Sidebar.xcu"
factories = src / "officecfg/registry/data/org/openoffice/Office/UI/Factories.xcu"
component = src / "sfx2/util/sfx.component"
library = src / "sfx2/Library_sfx.mk"
uiconfig = src / "sfx2/UIConfig_sfx.mk"
panel_cxx = src / "sfx2/source/sidebar/AIChatPanel.cxx"
factory_cxx = src / "sfx2/source/sidebar/AIChatPanelFactory.cxx"
panel_ui = src / "sfx2/uiconfig/ui/aichatpanel.ui"

for path in [sidebar, factories, component, library, uiconfig, panel_cxx, factory_cxx, panel_ui]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

sidebar_text = sidebar.read_text()
factory_text = factories.read_text()
component_text = component.read_text()
library_text = library.read_text()
uiconfig_text = uiconfig.read_text()
panel_cxx_text = panel_cxx.read_text()
factory_cxx_text = factory_cxx.read_text()
panel_ui_text = panel_ui.read_text()

checks = {
    "AIChatDeck": "AIChatDeck" in sidebar_text,
    "AIChatPanel": "AIChatPanel" in sidebar_text,
    "ImplementationURL": "private:resource/toolpanel/SfxAIChatPanelFactory/AIChatPanel" in sidebar_text,
    "Writer context": "WriterVariants, any, visible" in sidebar_text,
    "Calc context": "Calc, any, visible" in sidebar_text,
    "DrawImpress context": "DrawImpress, any, visible" in sidebar_text,
    "Factory registry": "SfxAIChatPanelFactory" in factory_text,
    "Factory implementation": "org.kqoffice.comp.sfx2.sidebar.AIChatPanelFactory" in factory_text,
    "Component implementation": "org.kqoffice.comp.sfx2.sidebar.AIChatPanelFactory" in component_text,
    "Component constructor": "org_kqoffice_comp_sfx2_sidebar_AIChatPanelFactory_get_implementation" in component_text,
    "Panel object": "sfx2/source/sidebar/AIChatPanel" in library_text,
    "Factory object": "sfx2/source/sidebar/AIChatPanelFactory" in library_text,
    "UI resource": "sfx2/uiconfig/ui/aichatpanel" in uiconfig_text,
    "Native PanelLayout": "PanelLayout(pParent, u\"AIChatPanel\"_ustr" in panel_cxx_text,
    "No direct provider implementation": "#include <kqoffice" not in panel_cxx_text and "#include <provider" not in panel_cxx_text,
    "Factory resource guard": "rResourceURL.endsWith(u\"/AIChatPanel\"_ustr)" in factory_cxx_text,
    "Composer entry": 'id="prompt_entry"' in panel_ui_text,
    "Transcript view": 'id="transcript_view"' in panel_ui_text,
    "Send button": 'id="send_button"' in panel_ui_text,
    "Cancel button": 'id="cancel_button"' in panel_ui_text,
    "Retry button": 'id="retry_button"' in panel_ui_text,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

for path in [sidebar, factories, component, panel_ui]:
    try:
        ET.parse(path)
    except ET.ParseError as exc:
        raise SystemExit(f"FAIL: XML parse {path}: {exc}") from exc

print(f"V3 AI chat panel registration self-test passed. Checks: {len(checks)}")
PY
