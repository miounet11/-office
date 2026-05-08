# Native Office UI Modernization Design

## Objective

Upgrade 可圈office toward a modern, premium desktop productivity interface while preserving native LibreOffice/VCL workflows. The product must feel like software for daily document work, not like a website or landing page.

## Approved Direction

Use an Executive Calm desktop style with selective Fluent-like command clarity:

- native desktop layout and platform behavior
- restrained blue/indigo business accent
- quiet chrome, fewer heavy frames, less visual competition
- document and task content as the visual priority
- familiar Writer/Calc/Impress command model

The first implementation lane covers the Start Center and brand identity surfaces because they have the highest first-minute visual impact and already exist as bounded native resources.

## Surface Scope

### Start Center

The Start Center should read as a native office workbench:

- left rail acts as compact navigation and creation control
- right content area starts with a concise workbench heading
- task templates are grouped by real office workflows
- recent/template browser controls are quiet and utilitarian
- scroll areas use minimal shadowing and spacing rather than heavy boxed borders

### Brand Identity

The visible product identity should move away from the current green-heavy treatment and toward a restrained blue/indigo business palette. Branding remains SVG-based and package-native.

Affected brand surfaces:

- start-center brand mark
- about dialog art and wordmark
- app and generated platform icons through the existing generator palette

### Main Editing Chrome

This lane does not restructure toolbars or document editing. It establishes the visual language and guardrails for later toolbar/sidebar quieting.

## Visual System

Palette:

- primary chrome: platform window/dialog color
- secondary chrome: platform face/dialog color
- accent: `#2F5FD7`, supported by `#5B84F1` and `#8FB6FF`
- text: platform text colors; no low-contrast custom text
- warnings/destructive states: keep platform conventions

Spacing:

- left rail padding increases from ad hoc 6 px groups to a calmer 10-14 px rhythm
- section gaps use spacing, not separators, where possible
- grouped task buttons keep compact office density

Typography:

- platform fonts remain authoritative
- section labels are bold and slightly larger
- headings are clear but not hero-sized

## Interaction Rules

- Do not introduce browser/web runtime UI.
- Do not change document creation commands.
- Do not remove keyboard focusability from existing controls.
- Keep recent files and template browsing reachable by F6 focus flow.
- Preserve Chinese-first visible strings.
- Respect platform high-contrast and dark-mode behavior by using style settings rather than hard-coded control text colors in C++.

## gpt-image-2 Reference Prompts

These prompts are for concept mockups only. They are not shipped UI assets.

### Start Center Concept

Use case: ui-mockup
Asset type: desktop productivity app concept mockup
Primary request: Create a native desktop office suite Start Center for 可圈office using an Executive Calm design language.
Scene/backdrop: macOS-style desktop application window, not a website, no browser chrome.
Subject: left navigation rail with open file, recent files, task templates, blank document and blank spreadsheet actions; main area with workbench heading, grouped task template buttons, compact recent/template browser controls.
Style/medium: high-fidelity desktop software UI mockup.
Composition/framing: 16:10 landscape app window, dense but calm, document-work focused.
Color palette: soft neutral chrome, restrained blue/indigo accent, deep charcoal text.
Text: Chinese UI labels only; include 可圈office, 工作台, 打开本地文件, 最近文件, 任务模板, 空白文档, 空白表格, 工作汇报, 预算总览, 项目排期.
Constraints: native software interface; no landing page, hero section, marketing cards, decorative gradient blobs, web navigation bar, browser address bar, or oversized consumer app spacing.

### Editing Chrome Concept

Use case: ui-mockup
Asset type: desktop office editor concept mockup
Primary request: Create a native Writer document editing window for 可圈office with quieter toolbars and sidebars.
Scene/backdrop: desktop office suite document editor.
Subject: compact top toolbar groups, document canvas centered, restrained right inspector/sidebar, quiet status bar.
Style/medium: high-fidelity desktop software UI mockup.
Composition/framing: 16:10 landscape app window, document canvas dominates.
Color palette: soft neutral chrome with blue/indigo active states.
Text: Chinese UI labels where readable.
Constraints: keep office-suite familiarity; no website layout, no marketing hero, no floating decorative cards, no translucent glass as the main style.

## Implementation Boundaries

First lane files:

- `/Users/lu/kdoffice-src/sfx2/uiconfig/ui/startcenter.ui`
- `/Users/lu/kdoffice-src/sfx2/source/dialog/backingwindow.cxx`
- `/Users/lu/kdoffice-src/downstream-branding/*.svg`
- `/Users/lu/kdoffice-src/downstream-branding/shell/*.svg`
- `/Users/lu/kdoffice-src/downstream-branding/generate_icon_assets.py`
- `/Users/lu/可点office/tmp/ui-modernization/check-native-office-ui-modernization.py`

Generated package outputs are not hand-edited. The asset generator remains the source for generated icon families.

## Verification

- focused checker for Start Center and branding palette
- XML parse for `startcenter.ui`
- Python compile for the checker
- `gmake -C /Users/lu/kdoffice-src sfx2.build` when feasible

If the full module build is blocked by unrelated dirty-tree or pre-existing build issues, report the exact blocker and keep the focused checks passing.
