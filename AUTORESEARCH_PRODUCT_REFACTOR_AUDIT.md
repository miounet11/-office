# 可圈office Product Refactor Audit

This document follows an `autoresearch`-style loop: inspect the real bottleneck, make a bounded product decision, ship a focused round, verify the built app, and only then queue the next round. For `可圈office`, the key mistake would be to treat this as a translation-and-branding exercise. It is no longer that.

## Baseline

- The checked-in wrapper repo is `/Users/lu/可点office`.
- The real source tree is `/Users/lu/kdoffice-src`.
- Previous rounds already improved branding, Chinese copy, template bundles, file-type ordering, and Simplified Chinese font fallback.
- Those rounds matter, but they mostly changed presentation and defaults. The core product model still inherits upstream LibreOffice structure.

## What Is Already in Simple-Edit Territory

These are still worth doing, but they are not the main blockers anymore:

- Brand cleanup, app metadata, launcher names, help text, and visible copy.
- Chinese labels for factories, file types, menus, template names, and first-run prompts.
- File-type ordering and compatibility messaging in visible save/open UI.
- Locale-level font fallback tuning in `VCL.xcu`.
- Hiding empty marketing or extension URLs when no downstream service exists.
- Bundling more starter templates into existing package flows.

These are necessary polish tasks. They do not make the suite feel like a China-first Office365-class product on their own.

## What Definitely Requires Refactoring

### 1. Start Experience Must Become a Workbench, Not a Relabeled Start Center

Evidence:

- [`/Users/lu/kdoffice-src/sfx2/source/dialog/backingwindow.cxx:167`](/Users/lu/kdoffice-src/sfx2/source/dialog/backingwindow.cxx#L167) still wires the home shell around recent files, templates, module-create buttons, brand image, help, and extensions.
- [`/Users/lu/kdoffice-src/sfx2/source/dialog/backingwindow.cxx:201`](/Users/lu/kdoffice-src/sfx2/source/dialog/backingwindow.cxx#L201) only hides extensions when no URL exists. That is cleanup, not a redesigned product entry flow.
- [`/Users/lu/kdoffice-src/sfx2/uiconfig/ui/startcenter.ui:168`](/Users/lu/kdoffice-src/sfx2/uiconfig/ui/startcenter.ui#L168) and [`/Users/lu/kdoffice-src/sfx2/uiconfig/ui/startcenter.ui:221`](/Users/lu/kdoffice-src/sfx2/uiconfig/ui/startcenter.ui#L221) still define the classic left-nav launcher with recent files, templates, and module buttons.
- [`/Users/lu/kdoffice-src/cui/source/dialogs/welcomedlg.cxx:32`](/Users/lu/kdoffice-src/cui/source/dialogs/welcomedlg.cxx#L32) only provides two tabs, and [`/Users/lu/kdoffice-src/cui/source/dialogs/welcomedlg.cxx:108`](/Users/lu/kdoffice-src/cui/source/dialogs/welcomedlg.cxx#L108) only applies toolbar mode and appearance.

Why this is a refactor:

- Chinese office users do not think in terms of "recent vs templates vs module family" first. They think in terms of tasks: blank document, work report, meeting minutes, contract, invoice, budget, schedule, class PPT, defense deck, pitch deck, resume.
- The current structure is still document-type-first and file-browser-first.

Refactor target:

- Replace the current launcher with a scenario-first workbench.
- Merge first-run onboarding, recent work, recommended templates, cloud/open actions, and quick-create actions into one product shell.
- Introduce ranked task cards instead of exposing all modules at the same level on day one.

Acceptance gate:

- A first-time user should be able to start a common China-office task in one click from the home surface.
- The first-run flow should configure product behavior, not only toolbar skin and appearance.

### 2. Writer, Calc, and Impress Need a Unified Interaction Policy

Evidence:

- [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Setup.xcu:41`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Setup.xcu#L41) shows module factories still wired to inherited command/config references such as `WriterCommands`, `CalcCommands`, and `DrawImpressCommands`.
- [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/ToolbarMode.xcu:18`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/ToolbarMode.xcu#L18), [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/ToolbarMode.xcu:298`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/ToolbarMode.xcu#L298), and [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/ToolbarMode.xcu:547`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/ToolbarMode.xcu#L547) show that Writer, Calc, and Impress still default to `Active=Default`, not a notebookbar-first shell.
- [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/ToolbarMode.xcu:101`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/ToolbarMode.xcu#L101), [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/ToolbarMode.xcu:381`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/ToolbarMode.xcu#L381), and [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/ToolbarMode.xcu:605`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/ToolbarMode.xcu#L605) show that non-experimental `Tabbed` notebookbar modes already exist.
- [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/GenericCommands.xcu:6735`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/GenericCommands.xcu#L6735) still exposes a generic `ToolbarMode` and upstream-style `User Interface` selection model.
- [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/WriterWindowState.xcu:63`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/WriterWindowState.xcu#L63), [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/CalcWindowState.xcu:78`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/CalcWindowState.xcu#L78), and [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/ImpressWindowState.xcu:103`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/ImpressWindowState.xcu#L103) show Notebookbar as a window-state/resource concern, not a product-level command contract.
- The notebookbar surfaces are structurally huge:
  - [`/Users/lu/kdoffice-src/sw/uiconfig/swriter/ui/notebookbar.ui`](/Users/lu/kdoffice-src/sw/uiconfig/swriter/ui/notebookbar.ui) has 18,112 lines.
  - [`/Users/lu/kdoffice-src/sc/uiconfig/scalc/ui/notebookbar.ui`](/Users/lu/kdoffice-src/sc/uiconfig/scalc/ui/notebookbar.ui) has 17,144 lines.
  - [`/Users/lu/kdoffice-src/sd/uiconfig/simpress/ui/notebookbar.ui`](/Users/lu/kdoffice-src/sd/uiconfig/simpress/ui/notebookbar.ui) has 19,524 lines.

Why this is a refactor:

- Switching the suite to launch in `Tabbed` mode is mostly a config change.
- This is not one ribbon. It is three very large inherited command surfaces with partial overlap.
- A China-first Office-like experience needs a deliberate cross-module tab taxonomy, command naming policy, and visibility policy.

Refactor target:

- Define a single command architecture for the core trio: `Home`, `Insert`, `Layout`, `Review`, `View`, `AI/PPT Draft`, `Template`, `Export`.
- Push module-specific depth into predictable secondary groups instead of leaving upstream sprawl visible by default.
- Make Writer, Calc, and Impress feel like one suite, not three adjacent applications.

Acceptance gate:

- The top-level tabs and command grouping should be recognizable and stable across modules.
- A China-market user trained on Microsoft Office should not need to relearn basic command discovery.

### 3. The New-Document Pipeline Must Be Scenario-Driven, Not Category-Driven

Evidence:

- [`/Users/lu/kdoffice-src/sfx2/source/doc/doctemplates.cxx:180`](/Users/lu/kdoffice-src/sfx2/source/doc/doctemplates.cxx#L180) exposes a generic `XDocumentTemplates` service that stores, adds, removes, renames, and groups templates.
- [`/Users/lu/kdoffice-src/sfx2/uiconfig/ui/templatedlg.ui:41`](/Users/lu/kdoffice-src/sfx2/uiconfig/ui/templatedlg.ui#L41) is a manager-style dialog with search, application filter, category filter, and management actions.
- [`/Users/lu/kdoffice-src/sfx2/uiconfig/ui/loadtemplatedialog.ui:21`](/Users/lu/kdoffice-src/sfx2/uiconfig/ui/loadtemplatedialog.ui#L21) is still a category/tree/template selection flow.

Why this is a refactor:

- The current model assumes users browse by application and folder.
- Chinese productivity users usually start from use-case intent: weekly report, leave form, recruitment resume, meeting纪要, budget tracker, sales summary, classware, defense PPT.

Refactor target:

- Add scenario metadata above raw templates.
- Rank templates by task, role, industry, and recency.
- Add a "start from recommended scenario" layer before the traditional manager.
- Keep the existing template manager for power users, but stop making it the primary new-document entry.

Acceptance gate:

- Common scenarios should be available directly from the home/workbench flow.
- Templates should be ranked and labeled by task outcome, not only file family.

### 4. PPT Generation Needs a New Subsystem, Not Better Renaming

Evidence:

- [`/Users/lu/kdoffice-src/sw/source/uibase/app/docsh2.cxx:823`](/Users/lu/kdoffice-src/sw/source/uibase/app/docsh2.cxx#L823) shows the current Writer flow serializes document outline as RTF and dispatches `SendOutlineToImpress`.
- [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/WriterCommands.xcu:1400`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/WriterCommands.xcu#L1400) already renames this as `Generate PPT Draft from Headings`.
- [`/Users/lu/kdoffice-src/sd/source/ui/app/sdmod1.cxx:267`](/Users/lu/kdoffice-src/sd/source/ui/app/sdmod1.cxx#L267) creates a new Impress document, switches to outline view, and imports the outline payload.
- [`/Users/lu/kdoffice-src/sd/source/ui/app/sdmod1.cxx:588`](/Users/lu/kdoffice-src/sd/source/ui/app/sdmod1.cxx#L588) finalizes by reading RTF into the outline shell and updating slide previews.
- [`/Users/lu/kdoffice-src/sd/source/ui/dlg/PhotoAlbumDialog.cxx:89`](/Users/lu/kdoffice-src/sd/source/ui/dlg/PhotoAlbumDialog.cxx#L89), [`/Users/lu/kdoffice-src/sd/source/ui/view/viewshe3.cxx:316`](/Users/lu/kdoffice-src/sd/source/ui/view/viewshe3.cxx#L316), and [`/Users/lu/kdoffice-src/sd/source/ui/unoidl/unopage.cxx:590`](/Users/lu/kdoffice-src/sd/source/ui/unoidl/unopage.cxx#L590) show that Impress already has reusable machinery for slide insertion, auto-layout selection, and page-level theme/master manipulation.
- [`/Users/lu/kdoffice-src/sd/source/core/sdpage.cxx:1280`](/Users/lu/kdoffice-src/sd/source/core/sdpage.cxx#L1280) and [`/Users/lu/kdoffice-src/sd/source/ui/func/fuinsert.cxx:302`](/Users/lu/kdoffice-src/sd/source/ui/func/fuinsert.cxx#L302) show that placeholder-driven slide archetypes and chart/table insertion primitives already exist.
- [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/PresentationMinimizer.xcu:20`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/PresentationMinimizer.xcu#L20) is only presentation size optimization, not generation.

Why this is a refactor:

- The current codebase has good low-level authoring primitives and outline import, not true presentation generation.
- There is no first-class subsystem for prompt/spec intake, slide planning, layout mapping, chart generation, speaker notes, or asset orchestration.

Refactor target:

- Create a dedicated PPT generation pipeline with stages:
  - intake: topic, audience, duration, tone, scenario
  - planner: slide outline and section allocation
  - layout engine: choose slide types and master/theme variants
  - asset engine: charts, tables, image placeholders, icon blocks
  - copy engine: title, bullets, summary, note blocks
  - finalizer: editable Impress document with consistent theme and spacing

Acceptance gate:

- A user should be able to start from a brief and get a structured editable deck, not just an imported heading outline.

### 5. Office365-Like Behavior Requires a Real Service Layer

Evidence:

- [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/Common.xcu:438`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/Common.xcu#L438) still exposes a CMIS/remote-server list model.
- The existing startup shell includes `open_remote`, but there is no coherent China-first account, sync, recents, or template-delivery product model in the inspected code paths.

Why this is a refactor:

- "Chinese Office365" is not a menu entry. It implies account/session state, synchronized recent work, template delivery, settings sync, maybe cloud storage integration, and possibly collaboration hooks.
- The current repo has remote hooks, not a downstream service architecture.

Refactor target:

- Introduce a downstream service abstraction for:
  - account/session
  - recent-document sync
  - template/content delivery
  - settings sync
  - update/help portal ownership
- Keep it optional at first so local offline usage remains clean and easy.

Acceptance gate:

- Remote/open/cloud behavior should feel like one product capability, not scattered storage connectors.

### 6. Chinese Defaults Need a Product Policy Layer, Not Only Font Fallback

Evidence:

- [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/VCL.xcu:223`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/VCL.xcu#L223) already improves `zh-cn` font priority across display, text, presentation, spreadsheet, fixed, and UI sans/serif families.
- [`/Users/lu/kdoffice-src/unotools/source/config/fontcfg.cxx:101`](/Users/lu/kdoffice-src/unotools/source/config/fontcfg.cxx#L101) and [`/Users/lu/kdoffice-src/vcl/source/outdev/font.cxx:415`](/Users/lu/kdoffice-src/vcl/source/outdev/font.cxx#L415) show that `officecfg` default-font tables are the main low-risk control surface for module font defaults.
- [`/Users/lu/kdoffice-src/officecfg/registry/schema/org/openoffice/Office/Common.xcs:5216`](/Users/lu/kdoffice-src/officecfg/registry/schema/org/openoffice/Office/Common.xcs#L5216), [`/Users/lu/kdoffice-src/officecfg/registry/schema/org/openoffice/Office/Common.xcs:5579`](/Users/lu/kdoffice-src/officecfg/registry/schema/org/openoffice/Office/Common.xcs#L5579), and [`/Users/lu/kdoffice-src/officecfg/registry/schema/org/openoffice/Office/Common.xcs:5604`](/Users/lu/kdoffice-src/officecfg/registry/schema/org/openoffice/Office/Common.xcs#L5604) show that appearance, icon size, and notebookbar icon defaults are also mostly config policy.
- [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/Writer.xcu:726`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/Writer.xcu#L726) shows only a narrow locale-specific tab-stop override in the inspected range.
- [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Setup.xcu:41`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Setup.xcu#L41) and [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI.xcu:21`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI.xcu#L21) still reflect upstream factory/filter classification structure.
- [`/Users/lu/kdoffice-src/sw/source/uibase/app/docshini.cxx:240`](/Users/lu/kdoffice-src/sw/source/uibase/app/docshini.cxx#L240), [`/Users/lu/kdoffice-src/sd/source/core/drawdoc4.cxx:242`](/Users/lu/kdoffice-src/sd/source/core/drawdoc4.cxx#L242), [`/Users/lu/kdoffice-src/sd/source/core/stlpool.cxx:348`](/Users/lu/kdoffice-src/sd/source/core/stlpool.cxx#L348), and [`/Users/lu/kdoffice-src/sc/source/core/data/drwlayer.cxx:323`](/Users/lu/kdoffice-src/sc/source/core/data/drwlayer.cxx#L323) show that deeper semantic font sizes and style behavior are still seeded in module C++ code.

Why this is a refactor:

- Chinese office comfort depends on defaults for paragraph spacing, review display, table behavior, punctuation, numbering, page conventions, comment/revision habits, and export/save expectations.
- Font fallback helps rendering. It does not define default authoring behavior.

Refactor target:

- Add a downstream "China office defaults" layer for Writer, Calc, and Impress.
- Move blank-document behavior toward product-owned defaults instead of scattered template and locale side effects.
- Treat document defaults as a product system with tests, not as incidental config.
- Use `officecfg` first for the low-risk shell and font-policy changes, then refactor module seed code where the defaults are still hardcoded semantically.

Acceptance gate:

- A blank Chinese document, spreadsheet, and presentation should feel intentional before the user applies any template.

### 7. Real User Satisfaction Depends on Compatibility Engineering

Evidence:

- [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/TypeDetection/UISort.xcu:22`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/TypeDetection/UISort.xcu#L22) and [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI.xcu:21`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI.xcu#L21) show that visible filter ordering can be tuned.
- That does not change the underlying DOCX/XLSX/PPTX import-export engines, layout fidelity, formula fidelity, tracked-change behavior, or PPT animation fidelity.

Why this is a refactor:

- China-market acceptance is heavily driven by Microsoft Office interchange quality.
- Rewording warnings and reordering filters improves optics, not fidelity.

Refactor target:

- Build a compatibility backlog around the highest-frequency breakpoints:
  - Writer: pagination, comments, tracked changes, tables, floating objects
  - Calc: formulas, conditional formatting, chart fidelity, pivot/power-user sheets
  - Impress: theme fidelity, animation, text layout, grouped shapes, charts
- Add regression document packs and automated screenshot/content comparison where possible.

Acceptance gate:

- Target documents from Chinese workplace scenarios must survive round-trip and shared-edit workflows at materially higher fidelity than upstream defaults.

### 8. High Cleanliness Requires Product-Surface Pruning

Evidence:

- [`/Users/lu/kdoffice-src/sfx2/uiconfig/ui/startcenter.ui:221`](/Users/lu/kdoffice-src/sfx2/uiconfig/ui/startcenter.ui#L221) still exposes Draw, Math, and Database creation alongside the core trio.
- [`/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/Common.xcu:278`](/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/Common.xcu#L278) still keeps legacy wizard flows such as letter, fax, agenda, converter, and address data source in the product surface.

Why this is a refactor:

- A clean product is not the same as an upstream-complete product.
- If the core goal is a China-first office suite, low-value legacy surfaces should move behind advanced entry points instead of competing with high-frequency workflows.

Refactor target:

- Make Writer, Calc, Impress, and the main new-document scenarios the default front stage.
- Move Draw, Math, Base, old wizards, and low-frequency tools into advanced access paths.
- Preserve power-user capability without forcing novice and mainstream users to see every inherited feature first.

Acceptance gate:

- The first-run and daily-use surfaces should feel focused and modern, without removing expert capability from deeper menus or settings.

## Recommended Execution Sequence

### Program 0. Product Baseline and Verification Harness

- Define 10 to 15 real Chinese workflows.
- Rebuild and verify the app after every round.
- Track first-run completion time, task-entry clicks, OOXML fidelity regressions, and startup discoverability.

### Program 1. Home Workbench Refactor

- Replace the current Start Center plus shallow Welcome dialog with one scenario-first shell.
- Make this the new source of truth for task entry, onboarding, template recommendation, and recent work.

### Program 2. Unified Command Model and Ribbon Policy

- Stop treating Notebookbar as only a skin selection.
- Create a consistent cross-module command contract and reduce inherited surface noise.

### Program 3. Scenario and Template Engine

- Build intent-first template discovery.
- Keep the old manager as an advanced tool, not the main entry path.

### Program 4. China Office Defaults System

- Own blank-document behavior across Writer, Calc, and Impress.
- Treat defaults as product behavior with tests.

### Program 5. PPT Generation v1

- Productize the existing outline path as a fallback.
- Build a new structured deck-generation pipeline on top of it instead of pretending the old command is enough.

### Program 6. Service Layer and Cloud Capability

- Add downstream account/session, recents sync, template delivery, and service ownership.
- Keep offline mode clean.

### Program 7. Compatibility Lab

- Prioritize real DOCX/XLSX/PPTX pain instead of generic "format support" claims.
- Build golden documents and regression gates.

### Program 8. Surface Pruning and Packaging Cleanroom

- Hide or relocate low-value inherited surfaces.
- Ensure the packaged app feels focused, easy to install, and easy to use.

## Round Discipline

For each round:

1. Choose one product bottleneck, not a vague wishlist.
2. Change the real source and product policy, not only copy.
3. Rebuild the app and test visible behavior.
4. Keep the round only if it improves a concrete workflow.
5. Queue the next round from the observed bottleneck, not from personal preference.

## Current Verdict

`可圈office` has already made meaningful progress in branding, localization, startup polish, templates, and Chinese font fallback. That means the product is no longer blocked by superficial polish.

It is not yet a complete China-first Office365-class product.

The largest remaining gaps are structural:

- home/workbench architecture
- unified command model
- scenario-driven document creation
- real PPT generation
- downstream cloud/service layer
- product-owned Chinese defaults
- deep OOXML compatibility
- aggressive product-surface cleanup

If the goal is "Chinese users are satisfied," these are the programs that matter more than another pass of string replacement.

## Repo-Mapped Execution Matrix

### P0 — Must Win

| Priority | Program | Primary repo surfaces | User outcome | Verification |
| --- | --- | --- | --- | --- |
| P0-1 | Home workbench | `sfx2/source/dialog/backingwindow.cxx`, `sfx2/uiconfig/ui/startcenter.ui`, `cui/source/dialogs/welcomedlg.cxx` | First-run and daily entry become task-first instead of module-first | Rebuild `sfx2` / `cui`; confirm common tasks are one click from home; track clicks and first-task completion time |
| P0-2 | Unified command model | `officecfg/registry/data/org/openoffice/Office/UI/ToolbarMode.xcu`, `officecfg/registry/data/org/openoffice/Office/UI/*.xcu`, `sw/uiconfig/swriter/ui/notebookbar*.ui`, `sc/uiconfig/scalc/ui/notebookbar*.ui`, `sd/uiconfig/simpress/ui/notebookbar*.ui` | Writer, Calc, and Impress feel like one suite instead of three inherited apps | Rebuild `officecfg`, `sw`, `sc`, `sd`; compare tab taxonomy and top-command placement across modules |
| P0-3 | Compatibility lab | `oox`, `filter`, `xmloff`, app-specific import/export paths in `sw`, `sc`, `sd`, regression assets under `test` / `uitest` | Users can exchange DOCX/XLSX/PPTX with much less fear and less manual repair | Golden-document pack, screenshot/content diff, round-trip regression gates |
| P0-4 | PPT generation v1 | `sw/source/uibase/app/docsh2.cxx`, `sd/source/ui/app/sdmod1.cxx`, `sd/source/ui`, `sd/source/core`, command surfaces in `officecfg` and module UI files | A brief or outline becomes a usable editable deck, not just imported headings | Rebuild `sw` / `sd`; verify end-to-end draft-deck workflow with real Chinese presentation tasks |

### P1 — Product Leadership

| Priority | Program | Primary repo surfaces | User outcome | Verification |
| --- | --- | --- | --- | --- |
| P1-1 | Scenario/template engine | `sfx2/source/doc/doctemplates.cxx`, `sfx2/uiconfig/ui/templatedlg.ui`, `sfx2/uiconfig/ui/loadtemplatedialog.ui`, downstream template packaging in `extras`, `sysui`, module template trees | Users start from task intent such as report, budget, class PPT, resume, meeting minutes | Rebuild template packaging and `sfx2`; verify scenario ranking, category mapping, and task-oriented labels |
| P1-2 | China defaults system | `officecfg/registry/data/org/openoffice/VCL.xcu`, `officecfg/registry/data/org/openoffice/Office/*.xcu`, default seed paths in `sw`, `sc`, `sd` | Blank documents feel intentionally China-first before any template is applied | New-document snapshot tests plus manual checks for typography, spacing, styles, save/export defaults |
| P1-3 | Surface pruning | Start/home UI, `officecfg` command visibility policy, selected menu/notebookbar resources across `sw`, `sc`, `sd`, `dbaccess`, `starmath` | Mainstream users see the core trio and high-frequency workflows first; low-value inherited surfaces move to advanced paths | Rebuild affected modules; verify first-run/home/menu surfaces no longer compete with niche tools |
| P1-4 | AI office workflows | New downstream commands and UI entry points in `sw`, `sc`, `sd`, shared shell entry paths in `sfx2` / `cui` | AI becomes part of writing, analysis, and deck creation instead of a detached chat gimmick | Workflow tests for rewrite, summarize, formula assist, and deck drafting with measurable step reduction |

### P2 — Strategic Moat

| Priority | Program | Primary repo surfaces | User outcome | Verification |
| --- | --- | --- | --- | --- |
| P2-1 | Service layer | `officecfg` service config, `sfx2` / `cui` entry points, remote/open flows, downstream-owned account/session abstractions | Sync, templates, recents, and help feel like one coherent product capability | Offline/online mode checks, account/session flow tests, service ownership audit |
| P2-2 | Enterprise/private deployment mode | Packaging, config, installer, downstream service toggles, optional local AI/service endpoints | Government and enterprise users can deploy without public-cloud dependency | Install verification, policy/offline tests, controlled-environment acceptance packs |
| P2-3 | Cross-device continuity | `android`, `ios`, `libreofficekit`, service-layer integration points | The suite becomes an ecosystem instead of only a desktop app | Focused mobile/device smoke tests against shared documents, recents, and templates |

## Operating KPIs

### Product KPIs

- first useful task completion time
- clicks from launch to common-task start
- template/scenario adoption rate
- deck draft completion rate
- crash-free editing sessions

### Compatibility KPIs

- DOCX layout fidelity score
- XLSX formula and chart fidelity score
- PPTX theme/layout fidelity score
- comment / tracked-change parity score
- round-trip damage rate

### AI Workflow KPIs

- time saved per workflow
- acceptance rate of generated output
- edit distance from generated draft to final asset
- repeat usage rate of AI entry points

## Recommended Next Build Sequence

1. Build the verification harness and the first 10 to 15 real Chinese workflows.
2. Ship the home workbench refactor before another large localization-only pass.
3. Lock a unified Writer/Calc/Impress command contract.
4. Stand up the compatibility lab as a permanent release gate.
5. Build PPT generation as the wedge capability, then layer AI drafting on top.
6. Expand into service/private-deployment moat only after the desktop workflow is clearly superior.

## Workflow Verification Pack v1

These workflows define the first real downstream success baseline. Each one should be runnable against the packaged app, and each round should state whether it improved, regressed, or left the workflow unchanged.

### Writer workflows

1. **工作周报**
   - Entry: launch app -> choose a task-oriented report flow from home/workbench.
   - Success: a structured Chinese report document opens with usable title/body hierarchy and table section placeholders.
   - Verify: clicks to entry, time to first save, exported DOCX visual sanity check.

2. **会议纪要**
   - Entry: launch -> meeting minutes scenario.
   - Success: document starts with date, attendees, agenda, decisions, action items.
   - Verify: creation speed, usability without manual style repair, comment/review readiness.

3. **简历创建**
   - Entry: launch -> resume scenario.
   - Success: resume template is directly discoverable and produces a clean Chinese-first editable layout.
   - Verify: task-entry discoverability, print/PDF output quality, DOCX export sanity.

4. **正式通知 / 公文式通知**
   - Entry: launch -> notice/announcement scenario.
   - Success: default spacing, title hierarchy, and body typography feel intentional for Chinese office usage.
   - Verify: manual typography review, PDF export, print preview consistency.

5. **DOCX 协作修订**
   - Entry: open real DOCX with comments or tracked changes.
   - Success: comments, tracked changes, tables, and pagination survive without obvious breakage.
   - Verify: golden-document comparison, round-trip back to DOCX, screenshot/content diff.

### Calc workflows

6. **部门预算表**
   - Entry: launch -> budget scenario.
   - Success: a practical Chinese budget sheet opens with editable categories, totals, and presentable formatting.
   - Verify: formula correctness, print area sanity, XLSX export round-trip.

7. **销售跟踪表**
   - Entry: launch -> sales tracking scenario.
   - Success: user gets usable headers, status fields, totals, and chart-ready structure without rebuilding from scratch.
   - Verify: time to first data entry, chart generation sanity, XLSX fidelity.

8. **项目排期 / 进度跟踪**
   - Entry: launch -> schedule/project tracking scenario.
   - Success: timeline or milestone structure is usable immediately for Chinese business workflows.
   - Verify: conditional formatting/layout sanity, print/export quality, collaboration readability.

9. **复杂 XLSX 兼容**
   - Entry: open real enterprise XLSX.
   - Success: formulas, charts, merged regions, conditional formatting, and sheet structure remain trustworthy.
   - Verify: golden-file fidelity scoring and round-trip damage rate.

### Impress workflows

10. **工作汇报 PPT**
    - Entry: launch -> project/business report deck scenario.
    - Success: user gets a China-first deck starter with reasonable title/content page structures.
    - Verify: time to first usable deck, template quality, PPTX export sanity.

11. **教学课件 PPT**
    - Entry: launch -> teaching/courseware scenario.
    - Success: template and layout choices fit classroom presentation use instead of generic theme-only starts.
    - Verify: slide structure usefulness, text fit, print/handout output sanity.

12. **根据提纲生成 PPT 初稿**
    - Entry: from Writer outline or dedicated PPT draft flow.
    - Success: system produces an editable draft deck with section structure that is better than raw outline import.
    - Verify: end-to-end flow success rate, manual edit distance, presentation structure quality.

13. **PPTX 兼容演示文稿**
    - Entry: open real PPTX from Office/WPS users.
    - Success: layout, themes, text boxes, grouped objects, and charts remain materially usable.
    - Verify: screenshot diff, manual layout audit, export round-trip.

### Cross-suite workflows

14. **任务式首页进入**
    - Entry: cold launch to home/workbench.
    - Success: a new user can identify the correct task path without understanding module names like Writer/Calc/Impress first.
    - Verify: number of clicks to common tasks, first-run usability observation.

15. **统一命令心智**
    - Entry: switch between Writer, Calc, and Impress during one work session.
    - Success: top-level tabs, review/export behavior, and primary commands feel consistent across modules.
    - Verify: cross-module command placement audit and task completion without relearning navigation.

## First Execution Cut for Round 21

The smallest product-meaningful cut should target the home/workbench path rather than another broad cleanup sweep.

### Scope

- Reorder the home surface around the top workflow pack instead of module-first entry.
- Keep the current template and recent-file plumbing, but change what users see first.
- Do not attempt full cloud/service or AI integration in the first cut.

### Primary files to change first

- `sfx2/source/dialog/backingwindow.cxx`
- `sfx2/uiconfig/ui/startcenter.ui`
- `cui/source/dialogs/welcomedlg.cxx`
- Supporting labels/config only where needed to expose task-first entry text

### Acceptance gate for the first cut

- The home surface visibly prioritizes report, meeting minutes, budget, schedule, class PPT, and project/business report flows.
- Secondary module creation paths remain available but no longer dominate the first screen.
- The cut can be verified with focused `sfx2` / `cui` rebuilds and manual launch-path checks.

### Implemented result

- `sfx2/uiconfig/ui/startcenter.ui` now presents the page as `可圈办公工作台` and moves the scenario task block above the template browsing/filter controls.
- The first two scenario rows now prioritize the V1 work pack: work report, meeting minutes, budget overview, project schedule, PPT draft, project report, business pitch, and teaching courseware.
- Lower-priority but still useful starters such as project plan, sales follow-up, and notices remain available in the same task grid instead of disappearing into the template browser.
- The left rail keeps blank Writer/Calc/Impress entry points as `基础入口`, while secondary surfaces such as remote/recent/extensions and non-core module-first entries are still hidden in `sfx2/source/dialog/backingwindow.cxx` for this V1 workbench cut.
- Verification completed with `gmake -C /Users/lu/kdoffice-build2 sfx2.build`, and the rebuilt packaged Start Center resource at `instdir/可圈office.app/Contents/Resources/config/soffice.cfg/sfx/ui/startcenter.ui` contains the new hierarchy and task order.
