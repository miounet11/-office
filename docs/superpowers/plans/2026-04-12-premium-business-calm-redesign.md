# Premium Business Calm Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework 可圈office’s highest-visibility brand and entry surfaces so the product feels calmer, more premium, and more coherent without changing core workflows.

**Architecture:** Keep the redesign inside the existing LibreOffice-style stack: refresh the branding assets in `downstream-branding`, wire the splash packaging path so edited assets actually ship, then tune the start center, about, welcome, and shared chrome/sidebar surfaces through the existing `.ui` files and their small controller hooks. Avoid broad framework changes; use the current `weld`/Glade resources and packaging rules as the implementation boundary.

**Tech Stack:** LibreOffice gbuild, GtkBuilder `.ui` resources, C++ `weld` controllers, SVG/PNG branding assets, Python asset generation script, macOS `sips` for deterministic PNG exports.

---

## File structure / responsibilities

- `libreoffice-core/downstream-branding/`
  - Editable source branding assets for logo, about art, splash exports, and app icon family.
  - `generate_icon_assets.py` is the existing repo-local place for deterministic asset regeneration.
- `libreoffice-core/icon-themes/colibre/brand` and `libreoffice-core/icon-themes/colibre/brand_dev`
  - Packaged intro splash PNG locations currently used by `desktop/Package_branding.mk`.
- `libreoffice-core/desktop/Package_branding.mk`
  - Desktop packaging rules for intro assets.
- `libreoffice-core/static/CustomTarget_emscripten_fs_image.mk`
  - Static packaging list showing the shipped asset names (`intro*.png`, `shell/about.svg`, `shell/logo*.svg`).
- `libreoffice-core/sfx2/uiconfig/ui/startcenter.ui`
  - Start center layout, spacing, separators, labels, scrolled-window chrome, and scenario grid.
- `libreoffice-core/sfx2/source/dialog/backingwindow.cxx`
  - Start center controller, brand image sizing, button sizing, and left-rail wiring.
- `libreoffice-core/cui/uiconfig/ui/aboutdialog.ui`
  - Main native about dialog composition.
- `libreoffice-core/cui/source/dialogs/about.cxx`
  - Runtime loading/scaling of `shell/logo*` and `shell/about` brand art.
- `libreoffice-core/vcl/uiconfig/ui/aboutbox.ui`
  - Simpler about surface used by the VCL about box path.
- `libreoffice-core/cui/uiconfig/ui/welcomedialog.ui`
  - Welcome dialog shell chrome and spacing.
- `libreoffice-core/cui/source/dialogs/welcomedlg.cxx`
  - Welcome dialog tab wiring and button state flow.
- `libreoffice-core/svtools/uiconfig/ui/managedtoolbar.ui`
  - Shared toolbar wrapper.
- `libreoffice-core/svtools/uiconfig/ui/subtoolbar.ui`
  - Shared popover/subtoolbar wrapper.
- `libreoffice-core/svx/uiconfig/ui/sidebarparagraph.ui`
  - Dense representative sidebar panel with heavy border/spacing defaults.
- `libreoffice-core/svx/uiconfig/ui/sidebarstylespanel.ui`
  - Representative style sidebar panel for broader chrome quieting.

### Task 1: Codify the branding asset source/build path

**Files:**
- Modify: `libreoffice-core/downstream-branding/generate_icon_assets.py:548-557`
- Verify against: `libreoffice-core/desktop/Package_branding.mk:10-23`
- Verify against: `libreoffice-core/static/CustomTarget_emscripten_fs_image.mk:31-37`
- Verify against: `libreoffice-core/sfx2/source/dialog/backingwindow.cxx:111-115`
- Verify against: `libreoffice-core/cui/source/dialogs/about.cxx:120-130`
- Test: inline Python verification command (no dedicated automated test exists today)

- [ ] **Step 1: Add an explicit intro sync helper to the existing asset generator**

```python
# libreoffice-core/downstream-branding/generate_icon_assets.py

INTRO_EXPORTS = ["intro.png", "intro-highres.png"]
INTRO_PACKAGE_DIRS = [
    ROOT / "icon-themes/colibre/brand",
    ROOT / "icon-themes/colibre/brand_dev",
]


def sync_intro_exports() -> None:
    branding_root = ROOT / "downstream-branding"
    for name in INTRO_EXPORTS:
        src = branding_root / name
        for out_dir in INTRO_PACKAGE_DIRS:
            out_dir.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, out_dir / name)
```

- [ ] **Step 2: Call the sync helper from `main()` so one command refreshes all editable branding outputs**

```python
# libreoffice-core/downstream-branding/generate_icon_assets.py

def main() -> None:
    generate_app_svgs()
    doc_sources = generate_doc_svgs()
    render_hicolor_app_pngs()
    render_hicolor_doc_pngs(doc_sources)
    render_macos_iconsets()
    sync_intro_exports()
```

- [ ] **Step 3: Run the generator and verify it still completes cleanly**

Run:
```bash
python3 libreoffice-core/downstream-branding/generate_icon_assets.py
```

Expected: command exits 0 with no traceback and updates generated icon files plus both packaged intro PNG copies.

- [ ] **Step 4: Verify the editable-source vs packaged-output mapping explicitly**

Run:
```bash
python3 - <<'PY'
from pathlib import Path
import hashlib
root = Path('libreoffice-core')
files = [
    'downstream-branding/intro.png',
    'downstream-branding/intro-highres.png',
    'icon-themes/colibre/brand/intro.png',
    'icon-themes/colibre/brand/intro-highres.png',
    'icon-themes/colibre/brand_dev/intro.png',
    'icon-themes/colibre/brand_dev/intro-highres.png',
]
for rel in files:
    p = root / rel
    print(rel, hashlib.sha256(p.read_bytes()).hexdigest())
PY
```

Expected: the two `downstream-branding` hashes match both `brand` and `brand_dev` copies for the intro assets.

- [ ] **Step 5: Commit**

```bash
git add libreoffice-core/downstream-branding/generate_icon_assets.py
git commit -m "build: codify branding asset sync"
```

### Task 2: Rebuild the logo/about asset family around a calmer premium palette

**Files:**
- Modify: `libreoffice-core/downstream-branding/logo.svg:1-31`
- Modify: `libreoffice-core/downstream-branding/logo_inverted.svg:1-31`
- Modify: `libreoffice-core/downstream-branding/logo-sc.svg:1-31`
- Modify: `libreoffice-core/downstream-branding/logo-sc_inverted.svg:1-31`
- Modify: `libreoffice-core/downstream-branding/about.svg:1-32`
- Modify: `libreoffice-core/downstream-branding/app-icon.svg:1-999`
- Regenerate: `libreoffice-core/sysui/desktop/icons/hicolor/**`
- Regenerate: `libreoffice-core/sysui/desktop/icons/macos/**`
- Test: generated asset existence + clean build of changed modules

- [ ] **Step 1: Replace the current green-heavy wordmark treatment in `logo.svg` with a restrained blue/indigo business palette**

```svg
<svg width="900" height="260" viewBox="0 0 900 260" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="ring" x1="56" y1="42" x2="236" y2="222" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#8FB6FF"/>
      <stop offset="1" stop-color="#2F5FD7"/>
    </linearGradient>
    <linearGradient id="spark" x1="156" y1="70" x2="214" y2="126" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#E9F1FF"/>
      <stop offset="1" stop-color="#A7C2FF"/>
    </linearGradient>
    <linearGradient id="word" x1="302" y1="68" x2="844" y2="194" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#F6F8FC"/>
      <stop offset="1" stop-color="#DCE6F8"/>
    </linearGradient>
  </defs>
  <rect width="900" height="260" rx="40" fill="#111827"/>
  <g transform="translate(38 28)">
    <rect x="0" y="0" width="204" height="204" rx="56" fill="#1A2438"/>
    <circle cx="102" cy="102" r="64" fill="none" stroke="url(#ring)" stroke-width="26"/>
    <circle cx="102" cy="102" r="18" fill="#F8FAFC"/>
    <path d="M147 55a64 64 0 0 1 14 38" fill="none" stroke="url(#spark)" stroke-linecap="round" stroke-width="14"/>
    <circle cx="46" cy="46" r="11" fill="#5B84F1" opacity=".95"/>
    <circle cx="158" cy="46" r="11" fill="#5B84F1" opacity=".72"/>
    <circle cx="46" cy="158" r="11" fill="#5B84F1" opacity=".72"/>
    <circle cx="158" cy="158" r="11" fill="#5B84F1" opacity=".95"/>
  </g>
  <g fill="url(#word)">
    <text x="286" y="114" font-family="'PingFang SC','Noto Sans SC','Microsoft YaHei',sans-serif" font-size="62" font-weight="700" letter-spacing="3">可圈可点</text>
    <text x="286" y="196" font-family="'Avenir Next','Helvetica Neue',Arial,sans-serif" font-size="80" font-weight="700" letter-spacing="1.5">office</text>
  </g>
</svg>
```

- [ ] **Step 2: Apply the same geometry and calmer palette to the light-background variants and the about art**

```svg
<!-- logo_inverted.svg / logo-sc_inverted.svg: keep dimensions and geometry, switch to light background + dark word gradient -->
<rect width="960" height="240" rx="36" fill="#F5F7FB"/>
<rect x="0" y="0" width="188" height="188" rx="48" fill="#E9EEF9"/>
<stop offset="0" stop-color="#729BFF"/>
<stop offset="1" stop-color="#2F5FD7"/>
<stop offset="0" stop-color="#23324D"/>
<stop offset="1" stop-color="#111827"/>

<!-- about.svg: preserve 720x720 size, keep centered mark + product typography, but switch to soft neutral field and blue accent family -->
<rect width="720" height="720" rx="96" fill="#F5F7FB"/>
<rect x="58" y="58" width="604" height="604" rx="84" fill="#FFFFFF" opacity=".88"/>
<circle cx="152" cy="152" r="98" fill="none" stroke="url(#ring)" stroke-width="34"/>
<text x="124" y="514" font-family="'PingFang SC','Noto Sans SC','Microsoft YaHei',sans-serif" font-size="86" font-weight="700" letter-spacing="4" fill="#1E293B">可圈可点</text>
<text x="124" y="602" font-family="'Avenir Next','Helvetica Neue',Arial,sans-serif" font-size="94" font-weight="700" letter-spacing="2" fill="#0F172A">office</text>
```

- [ ] **Step 3: Update the master app icon so generated platform icons inherit the calmer identity**

```svg
<!-- libreoffice-core/downstream-branding/app-icon.svg -->
<svg width="512" height="512" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="64" y1="48" x2="432" y2="464" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#F8FAFD"/>
      <stop offset="1" stop-color="#E6ECF8"/>
    </linearGradient>
    <linearGradient id="ring" x1="112" y1="96" x2="304" y2="288" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#8FB6FF"/>
      <stop offset="1" stop-color="#2F5FD7"/>
    </linearGradient>
  </defs>
  <rect width="512" height="512" rx="120" fill="url(#bg)"/>
  <rect x="54" y="54" width="404" height="404" rx="92" fill="#FFFFFF" opacity=".9"/>
  <circle cx="256" cy="256" r="128" fill="none" stroke="url(#ring)" stroke-width="42"/>
  <circle cx="256" cy="256" r="30" fill="#FFFFFF"/>
  <circle cx="146" cy="146" r="18" fill="#5B84F1" opacity=".9"/>
  <circle cx="366" cy="146" r="18" fill="#5B84F1" opacity=".72"/>
  <circle cx="146" cy="366" r="18" fill="#5B84F1" opacity=".72"/>
  <circle cx="366" cy="366" r="18" fill="#5B84F1" opacity=".9"/>
</svg>
```

- [ ] **Step 4: Regenerate all derived icon outputs and build the modules that consume them**

Run:
```bash
python3 libreoffice-core/downstream-branding/generate_icon_assets.py && make desktop.build vcl.build cui.build sfx2.build
```

Expected: generator exits 0, `make` exits 0, and regenerated assets appear under `libreoffice-core/sysui/desktop/icons/hicolor` and `libreoffice-core/sysui/desktop/icons/macos`.

- [ ] **Step 5: Verify the runtime asset names still resolve to the shipped files**

Run:
```bash
python3 - <<'PY'
from pathlib import Path
root = Path('libreoffice-core')
for rel in [
    'downstream-branding/logo.svg',
    'downstream-branding/logo-sc.svg',
    'downstream-branding/about.svg',
    'sysui/desktop/icons/hicolor/scalable/apps/main.svg',
    'sysui/desktop/icons/hicolor/scalable/apps/startcenter.svg',
]:
    p = root / rel
    print(rel, p.exists(), p.stat().st_size)
PY
```

Expected: every file prints `True` with a non-zero size.

- [ ] **Step 6: Commit**

```bash
git add libreoffice-core/downstream-branding/logo.svg \
        libreoffice-core/downstream-branding/logo_inverted.svg \
        libreoffice-core/downstream-branding/logo-sc.svg \
        libreoffice-core/downstream-branding/logo-sc_inverted.svg \
        libreoffice-core/downstream-branding/about.svg \
        libreoffice-core/downstream-branding/app-icon.svg \
        libreoffice-core/sysui/desktop/icons/hicolor \
        libreoffice-core/sysui/desktop/icons/macos
git commit -m "feat: refresh premium calm brand assets"
```

### Task 3: Add an editable splash master and export deterministic intro PNGs

**Files:**
- Create: `libreoffice-core/downstream-branding/intro.svg`
- Modify: `libreoffice-core/downstream-branding/intro.png`
- Modify: `libreoffice-core/downstream-branding/intro-highres.png`
- Test: intro export dimensions + packaged copy verification

- [ ] **Step 1: Create a vector splash master so the intro art is editable and consistent with the new identity**

```svg
<svg width="990" height="254" viewBox="0 0 990 254" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="990" y2="254" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#F7F9FD"/>
      <stop offset="1" stop-color="#E9EEF8"/>
    </linearGradient>
    <linearGradient id="ring" x1="54" y1="30" x2="208" y2="184" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#8FB6FF"/>
      <stop offset="1" stop-color="#2F5FD7"/>
    </linearGradient>
    <linearGradient id="word" x1="260" y1="64" x2="852" y2="192" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#1F2D47"/>
      <stop offset="1" stop-color="#0F172A"/>
    </linearGradient>
  </defs>
  <rect width="990" height="254" rx="28" fill="url(#bg)"/>
  <rect x="26" y="24" width="210" height="206" rx="42" fill="#FFFFFF" opacity=".88"/>
  <circle cx="131" cy="127" r="62" fill="none" stroke="url(#ring)" stroke-width="22"/>
  <circle cx="131" cy="127" r="16" fill="#FFFFFF"/>
  <circle cx="76" cy="72" r="9" fill="#5B84F1" opacity=".92"/>
  <circle cx="186" cy="72" r="9" fill="#5B84F1" opacity=".72"/>
  <circle cx="76" cy="182" r="9" fill="#5B84F1" opacity=".72"/>
  <circle cx="186" cy="182" r="9" fill="#5B84F1" opacity=".92"/>
  <text x="274" y="108" font-family="'PingFang SC','Noto Sans SC','Microsoft YaHei',sans-serif" font-size="50" font-weight="700" letter-spacing="2" fill="url(#word)">可圈可点</text>
  <text x="274" y="178" font-family="'Avenir Next','Helvetica Neue',Arial,sans-serif" font-size="76" font-weight="700" letter-spacing="1.2" fill="#0F172A">office</text>
  <text x="276" y="214" font-family="'PingFang SC','Noto Sans SC','Microsoft YaHei',sans-serif" font-size="18" font-weight="500" fill="#51627F">Business documents, spreadsheets, presentations — calmer by design.</text>
</svg>
```

- [ ] **Step 2: Export the two shipped PNG sizes directly from the SVG master**

Run:
```bash
sips -z 199 644 libreoffice-core/downstream-branding/intro.svg --out libreoffice-core/downstream-branding/intro.png && \
sips -z 254 990 libreoffice-core/downstream-branding/intro.svg --out libreoffice-core/downstream-branding/intro-highres.png
```

Expected: both PNG exports are updated in place with no conversion errors.

- [ ] **Step 3: Sync the exported intro PNGs into the packaged locations**

Run:
```bash
python3 libreoffice-core/downstream-branding/generate_icon_assets.py
```

Expected: `icon-themes/colibre/brand/intro*.png` and `brand_dev/intro*.png` are refreshed from the new exports.

- [ ] **Step 4: Verify exact output dimensions and packaged copies**

Run:
```bash
sips -g pixelWidth -g pixelHeight libreoffice-core/downstream-branding/intro.png && \
sips -g pixelWidth -g pixelHeight libreoffice-core/downstream-branding/intro-highres.png
```

Expected:
- `intro.png` = `644 x 199`
- `intro-highres.png` = `990 x 254`

- [ ] **Step 5: Commit**

```bash
git add libreoffice-core/downstream-branding/intro.svg \
        libreoffice-core/downstream-branding/intro.png \
        libreoffice-core/downstream-branding/intro-highres.png \
        libreoffice-core/icon-themes/colibre/brand/intro.png \
        libreoffice-core/icon-themes/colibre/brand/intro-highres.png \
        libreoffice-core/icon-themes/colibre/brand_dev/intro.png \
        libreoffice-core/icon-themes/colibre/brand_dev/intro-highres.png
git commit -m "feat: refresh splash intro artwork"
```

### Task 4: Quiet the start center hierarchy and let the brand/content blocks breathe

**Files:**
- Modify: `libreoffice-core/sfx2/uiconfig/ui/startcenter.ui:83-840`
- Modify: `libreoffice-core/sfx2/source/dialog/backingwindow.cxx:165-443`
- Test: local build + manual launch to inspect start center layout

- [ ] **Step 1: Remove unnecessary separators and rebalance left-rail spacing in `startcenter.ui`**

```xml
<!-- libreoffice-core/sfx2/uiconfig/ui/startcenter.ui -->
<object class="GtkBox" id="buttons_box">
  <property name="visible">True</property>
  <property name="can-focus">False</property>
  <property name="vexpand">True</property>
  <property name="orientation">vertical</property>
  <property name="spacing">8</property>
  <property name="margin-start">8</property>
  <property name="margin-end">8</property>
  <property name="margin-top">10</property>
  <property name="margin-bottom">6</property>
</object>

<object class="GtkLabel" id="create_label">
  <property name="visible">True</property>
  <property name="can-focus">False</property>
  <property name="margin-start">14</property>
  <property name="margin-top">14</property>
  <property name="margin-bottom">6</property>
  <property name="label" translatable="yes" context="startcenter|create_label">基础入口</property>
  <property name="xalign">0</property>
</object>

<!-- delete separator1, separator2, separator3 instead of keeping hard dividing lines -->
```

- [ ] **Step 2: Calm the main copy block and scenario grid so the content side feels intentionally designed rather than mechanically packed**

```xml
<object class="GtkLabel" id="local_view_label">
  <property name="can-focus">False</property>
  <property name="margin-start">10</property>
  <property name="margin-end">10</property>
  <property name="margin-top">28</property>
  <property name="margin-bottom">14</property>
  <property name="xalign">0</property>
  <property name="yalign">0</property>
  <property name="wrap">True</property>
  <property name="label" translatable="yes" context="startcenter|local_view_label">可圈办公工作台&#10;按任务开始，快速创建报告、预算、排期与演示文稿。</property>
  <attributes>
    <attribute name="weight" value="600" start="0" end="7"/>
    <attribute name="scale" value="1.18" start="0" end="7"/>
    <attribute name="foreground-alpha" value="72%" start="8" end="32"/>
  </attributes>
</object>

<object class="GtkBox" id="scenario_box">
  <property name="visible">True</property>
  <property name="can-focus">False</property>
  <property name="orientation">vertical</property>
  <property name="spacing">14</property>
  <property name="margin-start">10</property>
  <property name="margin-end">10</property>
  <property name="margin-top">8</property>
  <property name="margin-bottom">14</property>
</object>

<object class="GtkGrid" id="scenario_grid">
  <property name="visible">True</property>
  <property name="can-focus">False</property>
  <property name="row-spacing">12</property>
  <property name="column-spacing">12</property>
  <property name="column-homogeneous">True</property>
</object>
```

- [ ] **Step 3: Remove inset scroller chrome and slightly reduce left-rail visual loudness in the controller**

```cpp
// libreoffice-core/sfx2/source/dialog/backingwindow.cxx
float const g_fMultiplier = 1.1f;

// keep the action menu square, but give the brand mark a little more breathing room
mxBrandImage->ConfigureForWidth(
    aPrefSize.Width() - (pDrawingArea->get_margin_start() + pDrawingArea->get_margin_end()) - 24);
```

```xml
<!-- libreoffice-core/sfx2/uiconfig/ui/startcenter.ui -->
<object class="GtkScrolledWindow" id="scrollrecent">
  <property name="visible">True</property>
  <property name="can-focus">True</property>
  <property name="hexpand">True</property>
  <property name="vexpand">True</property>
  <property name="shadow-type">none</property>
</object>

<object class="GtkScrolledWindow" id="scrolllocal">
  <property name="visible">True</property>
  <property name="can-focus">True</property>
  <property name="hexpand">True</property>
  <property name="vexpand">True</property>
  <property name="shadow-type">none</property>
</object>
```

- [ ] **Step 4: Build and manually inspect the start center**

Run:
```bash
make sfx2.build && make test-install && make debugrun
```

Expected: build/install succeeds and the start center visibly shows less border noise, more even spacing, and a calmer brand block without broken button wiring.

- [ ] **Step 5: Commit**

```bash
git add libreoffice-core/sfx2/uiconfig/ui/startcenter.ui \
        libreoffice-core/sfx2/source/dialog/backingwindow.cxx
git commit -m "feat: calm start center layout"
```

### Task 5: Polish the about, about-box, and welcome surfaces into one identity family

**Files:**
- Modify: `libreoffice-core/cui/uiconfig/ui/aboutdialog.ui:10-479`
- Modify: `libreoffice-core/cui/source/dialogs/about.cxx:72-140`
- Modify: `libreoffice-core/vcl/uiconfig/ui/aboutbox.ui:5-136`
- Modify: `libreoffice-core/cui/uiconfig/ui/welcomedialog.ui:5-188`
- Modify: `libreoffice-core/cui/source/dialogs/welcomedlg.cxx:32-68`
- Test: local build + manual launch of about / welcome dialogs

- [ ] **Step 1: Recompose the main about dialog so the brand art and metadata feel lighter and more premium**

```xml
<!-- libreoffice-core/cui/uiconfig/ui/aboutdialog.ui -->
<object class="GtkGrid">
  <property name="visible">True</property>
  <property name="can-focus">False</property>
  <property name="hexpand">True</property>
  <property name="vexpand">True</property>
  <property name="row-spacing">10</property>
  <property name="column-spacing">18</property>
</object>

<object class="GtkImage" id="imAbout">
  <property name="visible">True</property>
  <property name="can-focus">False</property>
  <property name="halign">center</property>
  <property name="valign">center</property>
  <property name="margin-start">18</property>
  <property name="margin-end">32</property>
  <property name="hexpand">True</property>
  <property name="vexpand">True</property>
</object>

<object class="GtkBox">
  <property name="visible">True</property>
  <property name="can-focus">False</property>
  <property name="halign">start</property>
  <property name="spacing">14</property>
</object>
```

- [ ] **Step 2: Tune the runtime image scaling so the logo and about art use whitespace more deliberately**

```cpp
// libreoffice-core/cui/source/dialogs/about.cxx
if (SfxApplication::loadBrandSvg(
        Application::GetSettings().GetStyleSettings().GetDialogColor().IsDark()
            ? u"shell/logo_inverted"
            : u"shell/logo",
        aBackgroundBitmap, nWidth * 0.74))
{
    Graphic aGraphic(aBackgroundBitmap);
    m_pBrandImage->set_image(aGraphic.GetXGraphic());
}
if (SfxApplication::loadBrandSvg(u"shell/about", aBackgroundBitmap, nWidth * 0.84))
{
    Graphic aGraphic(aBackgroundBitmap);
    m_pAboutImage->set_image(aGraphic.GetXGraphic());
}
```

- [ ] **Step 3: Give the VCL about box the same spacing rhythm and calmer density**

```xml
<!-- libreoffice-core/vcl/uiconfig/ui/aboutbox.ui -->
<object class="GtkBox" id="about">
  <property name="visible">True</property>
  <property name="can-focus">False</property>
  <property name="hexpand">True</property>
  <property name="vexpand">True</property>
  <property name="orientation">vertical</property>
  <property name="spacing">18</property>
  <property name="margin-start">18</property>
  <property name="margin-end">18</property>
  <property name="margin-top">18</property>
  <property name="margin-bottom">18</property>
</object>

<object class="GtkLabel" id="description">
  <property name="visible">True</property>
  <property name="can-focus">False</property>
  <property name="hexpand">True</property>
  <property name="justify">center</property>
  <property name="wrap">True</property>
  <property name="max-width-chars">56</property>
</object>
```

- [ ] **Step 4: Make the welcome dialog feel less utility-heavy and more in-family with the new brand surfaces**

```xml
<!-- libreoffice-core/cui/uiconfig/ui/welcomedialog.ui -->
<object class="GtkDialog" id="WelcomeDialog">
  <property name="can-focus">False</property>
  <property name="border-width">12</property>
  <property name="title" translatable="yes" context="welcomedialog|WelcomeDialog">欢迎使用 %PRODUCTNAME</property>
  <property name="resizable">False</property>
  <property name="modal">True</property>
</object>

<object class="GtkBox" id="dialog-vbox1">
  <property name="can-focus">False</property>
  <property name="orientation">vertical</property>
  <property name="spacing">18</property>
  <property name="margin-start">8</property>
  <property name="margin-end">8</property>
  <property name="margin-top">8</property>
  <property name="margin-bottom">4</property>
</object>
```

```cpp
// libreoffice-core/cui/source/dialogs/welcomedlg.cxx
m_xDialog->set_title(SfxResId(STR_WELCOME_LINE1));
m_xShowAgain->set_visible(!m_bFirstStart);
m_xNextBtn->set_label(m_bFirstStart ? CuiResId(RID_CUISTR_TABPAGE_NEXT) : CuiResId(RID_CUISTR_CLOSE));
m_xActionBtn->set_label(CuiResId(RID_CUISTR_APPLY));
```

- [ ] **Step 5: Build and check the dialog surfaces together**

Run:
```bash
make cui.build && make vcl.build && make test-install && make debugrun
```

Expected: build succeeds and the About / Welcome surfaces share the calmer palette, improved spacing, and less utility-first composition.

- [ ] **Step 6: Commit**

```bash
git add libreoffice-core/cui/uiconfig/ui/aboutdialog.ui \
        libreoffice-core/cui/source/dialogs/about.cxx \
        libreoffice-core/vcl/uiconfig/ui/aboutbox.ui \
        libreoffice-core/cui/uiconfig/ui/welcomedialog.ui \
        libreoffice-core/cui/source/dialogs/welcomedlg.cxx
git commit -m "feat: polish branded dialog surfaces"
```

### Task 6: Apply an initial shared chrome/sidebar/toolbar quieting pass

**Files:**
- Modify: `libreoffice-core/svtools/uiconfig/ui/managedtoolbar.ui:5-20`
- Modify: `libreoffice-core/svtools/uiconfig/ui/subtoolbar.ui:5-18`
- Modify: `libreoffice-core/svx/uiconfig/ui/sidebarparagraph.ui:68-260`
- Modify: `libreoffice-core/svx/uiconfig/ui/sidebarstylespanel.ui:6-110`
- Test: local build + manual Writer/Calc/Impress chrome inspection

- [ ] **Step 1: Add breathing room to the shared toolbar wrappers instead of relying on hard visual separation**

```xml
<!-- libreoffice-core/svtools/uiconfig/ui/managedtoolbar.ui -->
<object class="GtkBox" id="toolbarcontainer">
  <property name="visible">True</property>
  <property name="can-focus">False</property>
  <property name="orientation">vertical</property>
  <property name="margin-start">4</property>
  <property name="margin-end">4</property>
  <property name="margin-top">2</property>
  <property name="margin-bottom">2</property>
</object>

<!-- libreoffice-core/svtools/uiconfig/ui/subtoolbar.ui -->
<object class="GtkBox" id="container">
  <property name="visible">True</property>
  <property name="can-focus">False</property>
  <property name="orientation">vertical</property>
  <property name="spacing">6</property>
  <property name="margin-start">6</property>
  <property name="margin-end">6</property>
  <property name="margin-top">6</property>
  <property name="margin-bottom">6</property>
</object>
```

- [ ] **Step 2: Reduce cramped density in the representative paragraph sidebar panel**

```xml
<!-- libreoffice-core/svx/uiconfig/ui/sidebarparagraph.ui -->
<object class="GtkGrid" id="grid1">
  <property name="visible">True</property>
  <property name="can-focus">False</property>
  <property name="hexpand">True</property>
  <property name="border-width">10</property>
  <property name="row-spacing">6</property>
  <property name="column-spacing">8</property>
  <property name="column-homogeneous">True</property>
</object>

<object class="GtkBox" id="box1">
  <property name="visible">True</property>
  <property name="can-focus">False</property>
  <property name="spacing">8</property>
</object>

<object class="GtkBox" id="box3">
  <property name="visible">True</property>
  <property name="can-focus">False</property>
  <property name="orientation">vertical</property>
  <property name="spacing">6</property>
</object>
```

- [ ] **Step 3: Give the style sidebar panel the same calmer density and remove the cramped action cluster feeling**

```xml
<!-- libreoffice-core/svx/uiconfig/ui/sidebarstylespanel.ui -->
<object class="GtkGrid" id="grid1">
  <property name="visible">True</property>
  <property name="can-focus">False</property>
  <property name="hexpand">True</property>
  <property name="border-width">10</property>
  <property name="row-spacing">6</property>
  <property name="column-spacing">8</property>
</object>

<object class="GtkToolbar" id="style">
  <property name="visible">True</property>
  <property name="can-focus">True</property>
  <property name="margin-start">0</property>
  <property name="toolbar-style">icons</property>
  <property name="show-arrow">False</property>
</object>
```

- [ ] **Step 4: Build the shared chrome surfaces and inspect real modules that exercise them**

Run:
```bash
make svtools.build && make svx.build && make sw.build && make sc.build && make sd.build && make debugrun
```

Expected: build succeeds and Writer/Calc/Impress show quieter shared toolbars/sidebar panels with improved spacing and no broken control groups.

- [ ] **Step 5: Commit**

```bash
git add libreoffice-core/svtools/uiconfig/ui/managedtoolbar.ui \
        libreoffice-core/svtools/uiconfig/ui/subtoolbar.ui \
        libreoffice-core/svx/uiconfig/ui/sidebarparagraph.ui \
        libreoffice-core/svx/uiconfig/ui/sidebarstylespanel.ui
git commit -m "feat: quiet shared chrome surfaces"
```

## Self-review

### Spec coverage
- **Splash screen:** covered by Task 3.
- **Start center:** covered by Task 4.
- **About / product identity surfaces:** covered by Task 5, plus Task 2 brand asset family.
- **Main working UI / quiet chrome / sidebars / toolbars:** covered by Task 6.
- **Brand source/build-path ambiguity:** covered first in Task 1.
- **Premium-through-restraint / one accent strategy:** implemented through the shared calm blue/indigo asset family in Tasks 2-5.

### Placeholder scan
- No `TODO`, `TBD`, or “implement later” markers remain.
- Every task names exact files and concrete commands.
- Verification is explicit where automated tests do not exist.

### Type / name consistency
- Start center runtime brand asset names stay aligned with current code paths: `shell/logo`, `shell/logo_inverted`, `shell/logo-sc`, `shell/logo-sc_inverted`, `shell/about`.
- Intro packaging references stay aligned with current packaging rules: `intro.png`, `intro-highres.png`.
- The plan keeps all edits in real source files under `libreoffice-core`, not installed app bundles.
