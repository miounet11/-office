# Native Office UI Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade 可圈office Start Center and brand identity toward a modern native desktop office UI without changing document workflows.

**Architecture:** Keep the implementation inside the existing LibreOffice-style native stack: GtkBuilder `.ui` resources, `weld` controller sizing/styling, and downstream SVG branding assets. Use a focused checker to enforce the approved design constraints, then patch Start Center layout spacing, quiet scroll chrome, and blue/indigo branding sources.

**Tech Stack:** LibreOffice gbuild, GtkBuilder XML, C++ VCL/weld, SVG branding assets, Python focused checker.

---

## File Structure

- `/Users/lu/kdoffice-src/sfx2/uiconfig/ui/startcenter.ui`
  - Native Start Center layout, spacing, labels, scroll-window chrome, and task group visibility.
- `/Users/lu/kdoffice-src/sfx2/source/dialog/backingwindow.cxx`
  - Runtime font sizing, background colors, module visibility, and Start Center control sizing.
- `/Users/lu/kdoffice-src/downstream-branding/*.svg`
  - Editable custom brand assets shipped by `Package_branding_custom.mk`.
- `/Users/lu/kdoffice-src/downstream-branding/shell/*.svg`
  - Shell copies consumed by runtime image loading.
- `/Users/lu/kdoffice-src/downstream-branding/generate_icon_assets.py`
  - Generated icon palette source for app and platform icon families.
- `/Users/lu/可点office/tmp/ui-modernization/check-native-office-ui-modernization.py`
  - Focused source checker for this UI modernization lane.

## Task 1: Add Focused Design Checker

**Files:**
- Create: `/Users/lu/可点office/tmp/ui-modernization/check-native-office-ui-modernization.py`
- Test: run the checker before and after implementation

- [ ] **Step 1: Write the failing checker**

Create the checker with assertions that encode this lane's design rules:

```python
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

ROOT = Path("/Users/lu/kdoffice-src")
STARTCENTER = ROOT / "sfx2/uiconfig/ui/startcenter.ui"
BACKINGWINDOW = ROOT / "sfx2/source/dialog/backingwindow.cxx"
BRANDING = ROOT / "downstream-branding"

BLUE_TOKENS = {"#2F5FD7", "#5B84F1", "#8FB6FF"}
GREEN_TOKENS = {"#4ADE80", "#22C55E", "#16A34A", "#86EFAC", "#A7F3D0", "#DCFCE7", "#14532D"}


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    sys.exit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def prop_text(root: ET.Element, object_id: str, prop_name: str) -> str:
    for obj in root.iter("object"):
        if obj.attrib.get("id") != object_id:
            continue
        for prop in obj.findall("property"):
            if prop.attrib.get("name") == prop_name:
                return prop.text or ""
        fail(f"{object_id} is missing property {prop_name}")
    fail(f"missing object {object_id}")
    return ""


def prop_int(root: ET.Element, object_id: str, prop_name: str) -> int:
    value = prop_text(root, object_id, prop_name)
    try:
        return int(value)
    except ValueError:
        fail(f"{object_id}.{prop_name} is not an integer: {value!r}")
    return 0


def has_style_class(root: ET.Element, object_id: str, class_name: str) -> bool:
    for obj in root.iter("object"):
        if obj.attrib.get("id") != object_id:
            continue
        return any(
            child.tag == "style"
            and any(node.tag == "class" and node.attrib.get("name") == class_name for node in child)
            for child in obj
        )
    fail(f"missing object {object_id}")
    return False


def packing_text(root: ET.Element, object_id: str, prop_name: str) -> str:
    for child in root.iter("child"):
        objects = [node for node in child if node.tag == "object"]
        if not objects or objects[0].attrib.get("id") != object_id:
            continue
        for packing in child.findall("packing"):
            for prop in packing.findall("property"):
                if prop.attrib.get("name") == prop_name:
                    return prop.text or ""
        fail(f"{object_id} packing is missing property {prop_name}")
    fail(f"missing packed object {object_id}")
    return ""


def check_startcenter() -> None:
    root = ET.parse(STARTCENTER).getroot()
    require(prop_int(root, "buttons_box", "spacing") >= 6, "left rail button spacing must be calmer")
    require(prop_int(root, "open_all", "margin-start") >= 10, "left rail buttons need larger start margin")
    require(prop_int(root, "create_label", "margin-top") >= 12, "create section needs stronger separation")
    require(prop_text(root, "scenario_impress_group", "visible") == "True", "Impress task group must be visible in UI XML")
    require(prop_text(root, "scenario_outline", "visible") == "True", "presentation outline task must be visible in UI XML")
    require(prop_text(root, "scenario_pitch", "visible") == "True", "business pitch task must be visible in UI XML")
    require(prop_text(root, "scenario_project_report", "visible") == "True", "project report task must be visible in UI XML")
    require(prop_text(root, "scrollrecent", "shadow-type") == "none", "recent scroll area should not use heavy inset shadow")
    require(prop_text(root, "scrolllocal", "shadow-type") == "none", "template scroll area should not use heavy inset shadow")
    require(has_style_class(root, "scenario_compat_open", "suggested-action"), "primary compatibility open action should be styled as suggested")
    require(packing_text(root, "scenario_compat_group", "top-attach") == "5", "compatibility heading must not overlap Impress heading")
    require(packing_text(root, "scenario_compat_open", "top-attach") == "6", "compatibility open action must live on its own row")
    require(packing_text(root, "scenario_compat_open", "width") == "3", "compatibility open action should span the task grid")
    require("filter_impress" in STARTCENTER.read_text(encoding="utf-8"), "Start Center browser filter must include Impress")


def check_backingwindow() -> None:
    text = BACKINGWINDOW.read_text(encoding="utf-8")
    require("GetDialogColor()" in text, "Start Center background should use dialog chrome color")
    require("GetFaceColor()" in text, "Start Center secondary controls should use face chrome color")
    require("TYPE_IMPRESS" in text, "recent-file and template filtering must include Impress")
    normal_mode = text.split("if (officecfg::Office::Common::Misc::ViewerAppMode::get())", 1)[0]
    require("mxImpressAllButton->set_visible(false)" not in normal_mode, "Impress creation should not be hidden in normal workbench mode")
    require("mxScenarioImpressGroup->set_visible(false)" not in normal_mode, "Impress scenario group should not be hidden in normal workbench mode")


def check_branding() -> None:
    files = [
        BRANDING / "logo.svg",
        BRANDING / "logo_inverted.svg",
        BRANDING / "logo-sc.svg",
        BRANDING / "logo-sc_inverted.svg",
        BRANDING / "about.svg",
        BRANDING / "app-icon.svg",
        BRANDING / "shell/logo.svg",
        BRANDING / "shell/logo_inverted.svg",
        BRANDING / "shell/logo-sc.svg",
        BRANDING / "shell/logo-sc_inverted.svg",
        BRANDING / "shell/about.svg",
    ]
    combined = "\n".join(path.read_text(encoding="utf-8") for path in files)
    require(any(token in combined for token in BLUE_TOKENS), "branding must include approved blue/indigo tokens")
    leaked = sorted(token for token in GREEN_TOKENS if token in combined)
    require(not leaked, f"branding still contains old green-heavy tokens: {', '.join(leaked)}")

    generator = (BRANDING / "generate_icon_assets.py").read_text(encoding="utf-8")
    require('GREEN_RING_START = "#8FB6FF"' in generator, "generator main ring start must use blue accent")
    require('GREEN_RING_END = "#2F5FD7"' in generator, "generator main ring end must use blue accent")
    require('GREEN_SWEEP = "#DCE6F8"' in generator, "generator sweep must use calm blue highlight")


def main() -> None:
    check_startcenter()
    check_backingwindow()
    check_branding()
    print("native office UI modernization checks passed")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run checker and verify it fails before implementation**

Run:

```bash
python3 /Users/lu/可点office/tmp/ui-modernization/check-native-office-ui-modernization.py
```

Expected: fails on at least one current Start Center or branding rule.

## Task 2: Quiet and Expand the Native Start Center

**Files:**
- Modify: `/Users/lu/kdoffice-src/sfx2/uiconfig/ui/startcenter.ui`
- Modify: `/Users/lu/kdoffice-src/sfx2/source/dialog/backingwindow.cxx`

- [ ] **Step 1: Patch Start Center XML spacing and chrome**

Apply these XML changes:

- `buttons_box` spacing from `3` to `6`
- main left-rail button horizontal margins from `6` to `10`
- `create_label` top margin from `8` to `14`, bottom margin from `8` to `6`
- `scenario_grid` row and column spacing from `8` to `10`
- `actions` margins from `6/4/8` to `10/6/10`
- `scrollrecent` and `scrolllocal` `shadow-type` from `in` to `none`
- visible flags for `scenario_impress_group`, `scenario_outline`, `scenario_pitch`, `scenario_project_report`, and `scenario_courseware` to `True`
- add `<style><class name="suggested-action"/></style>` to `scenario_compat_open`

- [ ] **Step 2: Patch Start Center runtime policy**

In `ApplyStyleSettings()`, use:

```cpp
const Color aWorkbenchBackground(rStyleSettings.GetDialogColor());
const Color aRailBackground(rStyleSettings.GetFaceColor());
...
mxAllButtonsBox->set_background(aRailBackground);
mxSmallButtonsBox->set_background(aRailBackground);
SetBackground(aWorkbenchBackground);
```

In `checkInstalledModules()`, stop hiding Impress task entry points. Keep Draw, Math, Database, remote documents, and extensions hidden for this first lane.

- [ ] **Step 3: Run XML parse**

Run:

```bash
python3 -m xml.etree.ElementTree /Users/lu/kdoffice-src/sfx2/uiconfig/ui/startcenter.ui
```

Expected: exits 0.

## Task 3: Refresh Brand Identity Palette

**Files:**
- Modify: `/Users/lu/kdoffice-src/downstream-branding/logo.svg`
- Modify: `/Users/lu/kdoffice-src/downstream-branding/logo_inverted.svg`
- Modify: `/Users/lu/kdoffice-src/downstream-branding/logo-sc.svg`
- Modify: `/Users/lu/kdoffice-src/downstream-branding/logo-sc_inverted.svg`
- Modify: `/Users/lu/kdoffice-src/downstream-branding/about.svg`
- Modify: `/Users/lu/kdoffice-src/downstream-branding/app-icon.svg`
- Modify: `/Users/lu/kdoffice-src/downstream-branding/shell/logo.svg`
- Modify: `/Users/lu/kdoffice-src/downstream-branding/shell/logo_inverted.svg`
- Modify: `/Users/lu/kdoffice-src/downstream-branding/shell/logo-sc.svg`
- Modify: `/Users/lu/kdoffice-src/downstream-branding/shell/logo-sc_inverted.svg`
- Modify: `/Users/lu/kdoffice-src/downstream-branding/shell/about.svg`
- Modify: `/Users/lu/kdoffice-src/downstream-branding/generate_icon_assets.py`

- [ ] **Step 1: Replace green-heavy logo assets with blue/indigo variants**

Use the same mark geometry and product text, but replace green fills and gradients with:

- ring: `#8FB6FF` to `#2F5FD7`
- highlight: `#E9F1FF` to `#A7C2FF`
- dark mark panel: `#1A2438`
- light mark panel: `#E9EEF9`
- light field: `#F5F7FB`
- dark text: `#23324D` to `#111827`

Keep shell and top-level custom branding copies in sync.

- [ ] **Step 2: Update generator palette constants**

In `generate_icon_assets.py`, set:

```python
GREEN_RING_START = "#8FB6FF"
GREEN_RING_END = "#2F5FD7"
GREEN_SWEEP = "#DCE6F8"
```

Update `APP_SVG_GENERATED["main"]` and `APP_SVG_GENERATED["startcenter"]` to:

```python
Palette("#8FB6FF", "#2F5FD7", "#2F5FD7", "#EEF4FF")
```

- [ ] **Step 3: Parse SVG files as XML**

Run:

```bash
python3 -m xml.etree.ElementTree /Users/lu/kdoffice-src/downstream-branding/logo.svg
python3 -m xml.etree.ElementTree /Users/lu/kdoffice-src/downstream-branding/about.svg
python3 -m xml.etree.ElementTree /Users/lu/kdoffice-src/downstream-branding/shell/logo.svg
python3 -m xml.etree.ElementTree /Users/lu/kdoffice-src/downstream-branding/shell/about.svg
```

Expected: all exit 0.

## Task 4: Verify and Build

**Files:**
- Test: checker and module build

- [ ] **Step 1: Run focused checker**

Run:

```bash
python3 /Users/lu/可点office/tmp/ui-modernization/check-native-office-ui-modernization.py
```

Expected: `native office UI modernization checks passed`.

- [ ] **Step 2: Compile checker**

Run:

```bash
python3 -m py_compile /Users/lu/可点office/tmp/ui-modernization/check-native-office-ui-modernization.py
```

Expected: exits 0.

- [ ] **Step 3: Build the owning module**

Run:

```bash
gmake -C /Users/lu/kdoffice-src sfx2.build
```

Expected: exits 0, or report exact unrelated blocker if the local dirty build state prevents completion.
