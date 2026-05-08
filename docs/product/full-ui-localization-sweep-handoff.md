# Full UI Chinese Localization Sweep Handoff

Date: 2026-04-30
Owner: Clavue
Controller/reviewer: Codex
Product: 可圈office
Status: implementation required; not beta/release acceptable for Chinese users

## Current Verdict

可圈office is not Chinese-first enough for beta or release. The Workbench and selected Chinese templates are improving, but high-frequency document editing surfaces still expose English in visible UI. This is a product-quality blocker because it appears in the first minutes of normal Writer use: status bar language menus, style/font controls, sidebar deck menus, text context menus, and table context menus.

This packet is separate from validator/source-hygiene/live-accessibility beta gates. Do not use this work to claim beta readiness unless the existing beta gates also pass.

## User Evidence To Reproduce

The screenshots show these leak classes:

| Surface | Examples observed | Expected behavior |
| --- | --- | --- |
| Status bar language menu | `Set Language for Paragraph`, `None (Do not check spelling)` | Fully Chinese menu labels and spell-check wording. |
| Style/font toolbar area | `Heading 1` and other style labels | Built-in style display names should be localized or mapped to Chinese display aliases. Real font family names must remain literal. |
| Sidebar deck/menu list | `Properties`, `Styles`, `Gallery`, `Navigator`, `Accessibility Check` | Sidebar deck names, command labels, and tooltips should be Chinese. |
| Writer context menus | `Paste`, `Paste Special`, `Split Cells`, `Table Properties`, `Insert Caption` | Common edit/table/context commands should be Chinese. |

Initial source evidence already points to these areas:

| Leak class | Likely source files |
| --- | --- |
| Language status menu | `framework/inc/strings.hrc`, `framework/source/uielement/langselectionstatusbarcontroller.cxx`, `sw/inc/strings.hrc`, `sw/uiconfig/swriter/ui/spellmenu.ui` |
| Sidebar deck labels | `officecfg/registry/data/org/openoffice/Office/UI/Sidebar.xcu`, `officecfg/registry/data/org/openoffice/Office/UI/GenericCommands.xcu`, `officecfg/registry/data/org/openoffice/Office/UI/WriterCommands.xcu`, `officecfg/registry/data/org/openoffice/Office/UI/DrawImpressCommands.xcu`, `officecfg/registry/data/org/openoffice/Office/UI/CalcCommands.xcu` |
| Writer context/table commands | `officecfg/registry/data/org/openoffice/Office/UI/WriterCommands.xcu`, `officecfg/registry/data/org/openoffice/Office/UI/GenericCommands.xcu`, `sw/uiconfig/swriter/popupmenu/*.xml`, `sw/uiconfig/swriter/menubar/*.xml`, `cui/uiconfig/ui/pastespecial.ui`, `cui/uiconfig/ui/splitcellsdialog.ui`, `sw/uiconfig/swriter/ui/tableproperties.ui`, `sw/uiconfig/swriter/ui/insertcaption.ui` |
| Style display names | `sw/inc/strings.hrc`, `sw/inc/app.hrc`, `officecfg/registry/data/org/openoffice/Office/Accelerators.xcu`, `svx/uiconfig/ui/sidebarstylespanel.ui`, `svx/uiconfig/ui/sidebartextpanel.ui`, `svx/uiconfig/ui/fontnamebox.ui` |

Important build context: the current local config reports `WITH_LANG=` and `WITH_LANG_LIST=en-US`. Clavue must determine whether product policy is to add/ship `zh-CN` localization assets, downstream-overlay visible strings, or both. A hard-coded source-string patch may be acceptable for branded fork surfaces, but broad upstream English replacement without a localization strategy is risky.

## Autoresearch-Style Loop For Office Localization

Use the `karpathy/autoresearch` pattern: bounded change scope, fixed evaluation budget, objective metric, keep/revise decision, and a durable experiment log. Adapt it as follows:

1. Baseline: create `tmp/localization-sweep/<run>/baseline.md` with visible English leaks from automated grep plus manual screenshots.
2. Hypothesis: pick one surface lane only, such as language menu or sidebar deck labels.
3. Patch: edit only the lane-owned source files; do not touch generated `workdir/`, `instdir/`, `test-install/`, or binary artifacts.
4. Build: run the smallest module targets that cover the changed files.
5. Evaluate: capture repeatable evidence from source grep, UITest where available, and packaged-app/manual screenshots.
6. Decision: mark the round `Keep`, `Revise`, or `Blocked`.
7. Repeat: continue until the high-frequency Writer/Calc/Impress matrix below is clean or explicitly blocked.

The metric is not "number of strings changed." The metric is "visible English leaks remaining in the defined user surfaces." A round is only `Keep` if the observed UI surface is improved and no identifiers/font names/compatibility behavior were damaged.

## Major Phases

### M3-01: Inventory And Classification

Goal: produce a complete visible-English inventory before patching broadly.

Clavue must scan these source types:

- `*.xcu` under `officecfg/registry/data/org/openoffice/Office/UI/`
- `*.ui` under `sw/`, `sc/`, `sd/`, `sfx2/`, `svx/`, `cui/`, `desktop/`, `framework/`
- `*.hrc` under high-frequency UI modules
- `menubar/*.xml`, `popupmenu/*.xml`, `toolbar/*.xml`, and `statusbar/*.xml`
- Existing Chinese template/default policy docs to avoid inconsistent terminology

Classify every candidate into one of these buckets:

- `visible-ui-translate`: visible label, tooltip, menu entry, dialog title, sidebar title, status menu text.
- `style-display-name`: built-in style name shown to users; requires compatibility-aware handling.
- `preserve-font-name`: actual font family names such as `Arial`, `Liberation Sans`, `Apple SD Gothic Neo`, `Noto Sans CJK SC`.
- `preserve-identifier`: UNO command IDs, style internal IDs, XML node names, service names, schema keys.
- `test-fixture-only`: QA data, imported sample documents, comments, or assertions not shown in product runtime.
- `help-or-dev-tool`: help content or developer-only UI; lower priority unless visible in normal user flow.

Required output:

- `tmp/localization-sweep/m3-01-inventory.md`
- Candidate count by bucket.
- Top 50 high-frequency visible leaks with source path and proposed Chinese wording.
- List of files Clavue proposes to edit in M3-02 and M3-03 before editing.

### M3-02: Writer High-Frequency Remediation

Goal: remove English from the normal Writer editing path shown in the screenshots.

Priority surfaces:

- Status bar language menu and spell-check language menu.
- Text right-click menu.
- Table right-click menu.
- Paste and Paste Special dialog/menu labels.
- Split Cells, Insert Caption, Table Properties, rows/columns/cell menus.
- Paragraph/character/table style display names seen in toolbar, sidebar, and context menus.

Suggested Chinese terminology:

| English | Preferred Chinese |
| --- | --- |
| Set Language for Paragraph | 设置段落语言 |
| Set Language for Selection | 设置所选内容语言 |
| None (Do not check spelling) | 无（不检查拼写） |
| Properties | 属性 |
| Styles | 样式 |
| Gallery | 图库 |
| Navigator | 导航 |
| Accessibility Check | 辅助功能检查 |
| Paste | 粘贴 |
| Paste Special | 选择性粘贴 |
| Split Cells | 拆分单元格 |
| Table Properties | 表格属性 |
| Insert Caption | 插入题注 |
| Heading 1 | 标题 1 |
| Text body | 正文 |
| Default Style | 默认样式 |
| No Character Style | 无字符样式 |
| All Styles | 全部样式 |
| Hidden Styles | 隐藏样式 |

Required output:

- `tmp/localization-sweep/m3-02-writer.md`
- Before/after screenshots for each user-evidence category.
- Exact touched files.
- Explanation of any English intentionally preserved.

### M3-03: Sidebar, Calc, Impress, And Shared Chrome

Goal: avoid a Writer-only fix. Clean the same visible leak patterns in shared UI and other modules.

Priority surfaces:

- Sidebar deck list in Writer, Calc, Impress, Draw, Math.
- Shared command labels from `GenericCommands.xcu`.
- Calc common edit/context commands and sidebar decks.
- Impress/Draw sidebar decks: Shapes, Master Slides, Animation, Slide Transition, Navigator.
- Start Center and Workbench must be rechecked but not redesigned in this packet.

Required output:

- `tmp/localization-sweep/m3-03-shared-modules.md`
- Module matrix with Writer, Calc, Impress, Draw, Math rows and menu/sidebar/status/dialog columns.
- Remaining English leaks grouped by severity and whether they are user-visible.

### M3-04: Packaged App Verification And Release Gate

Goal: prove the installed app, not just source grep, is Chinese-first on the defined surfaces.

Verification matrix:

| Module | Required checks |
| --- | --- |
| Writer | New document, status bar language menu, style dropdown, sidebar deck menu, text context menu, table context menu, Paste Special, Table Properties. |
| Calc | New spreadsheet, sidebar deck menu, cell context menu, Paste Special, row/column menu, function/sidebar labels. |
| Impress | New presentation, sidebar deck menu, slide context menu, Shapes, Animation, Slide Transition, Master Slides. |
| Start Center | Workbench scenario labels remain Chinese and no regression in existing UITest smoke. |

Required output:

- `tmp/localization-sweep/m3-04-packaged-verification.md`
- Screenshot folder path with before/after evidence.
- Build and test command results.
- Final `Keep`, `Revise`, or `Blocked` verdict.

## Owned Write Scope

Clavue may edit source files under:

- `libreoffice-core/framework/`
- `libreoffice-core/sw/`
- `libreoffice-core/sc/`
- `libreoffice-core/sd/`
- `libreoffice-core/sfx2/`
- `libreoffice-core/svx/`
- `libreoffice-core/cui/`
- `libreoffice-core/officecfg/registry/data/org/openoffice/Office/UI/`
- `libreoffice-core/officecfg/registry/data/org/openoffice/Office/Accelerators.xcu` only with explicit style-display-name rationale

Clavue may write evidence only under:

- `tmp/localization-sweep/`
- Optional final review doc under `docs/product/`

Before broad edits, Clavue must return the proposed touched-file list. Codex review decides whether to split the work.

## Non-Goals

- Do not translate real font family names.
- Do not translate UNO command IDs such as `.uno:SidebarDeck.PropertyDeck`.
- Do not rename schema nodes, services, XML IDs, or internal style identifiers unless a compatibility test proves it is safe.
- Do not edit import/export layout engines.
- Do not change DOCX/ODF compatibility behavior to make labels look Chinese.
- Do not edit generated `workdir/`, `instdir/`, `test-install/`, `tmp/` build outputs as source.
- Do not delete, reset, clean, or stage unrelated dirty worktree files.
- Do not claim "all UI is Chinese" without packaged-app screenshots and a remaining-leak list.

## Validation Commands

Use the smallest relevant build first:

```sh
gmake -C /Users/lu/kdoffice-src officecfg.build
gmake -C /Users/lu/kdoffice-src framework.build sw.build sfx2.build svx.build cui.build
gmake -C /Users/lu/kdoffice-src sc.build sd.build
```

If Workbench or Start Center source is touched:

```sh
gmake -C /Users/lu/kdoffice-src UITest_workbench_smoke
```

For broader confidence after all phases:

```sh
gmake -C /Users/lu/kdoffice-src test-install
```

Optional beta-control rerun is allowed only after this localization packet is complete:

```sh
bin/v2-beta-gates.sh localization-sweep-postcheck
```

The localization packet should not be blocked by missing Officeotron/veraPDF/source-hygiene gates, but the final product release remains blocked by those gates.

## Review Protocol

Codex controls the gate; Clavue implements.

Each Clavue round must return:

- Verdict: `Keep`, `Revise`, or `Blocked`.
- Phase id: `M3-01`, `M3-02`, `M3-03`, or `M3-04`.
- Touched files.
- English leaks fixed by category.
- English intentionally preserved with reason.
- Commands run and exact results.
- Screenshot/evidence paths.
- Remaining leaks and proposed next round.
- Stop-rule concerns.

Codex review will reject a round if:

- It only fixes the screenshots and does not update the inventory.
- It translates identifiers or font family names.
- It changes compatibility/import/export behavior.
- It lacks packaged UI evidence for claimed visible fixes.
- It introduces inconsistent Chinese terminology.

## Stop Rules

Stop and report `Blocked` before:

- Translating internal IDs, UNO command names, schema node names, service names, or real font names.
- Renaming built-in styles in a way that breaks existing documents, accelerators, macros, tests, DOCX/ODF roundtrip, or style lookup.
- Making broad source edits without an inventory and touched-file list.
- Claiming completion when screenshots still show high-frequency English UI.
- Running destructive cleanup in the dirty build tree.
- Treating source grep as sufficient proof without installed-app/manual UI evidence.

## Completion Definition

This packet is complete only when:

- `M3-01` inventory exists and classifies candidates correctly.
- Writer screenshot surfaces are visibly Chinese.
- Sidebar deck labels are Chinese across Writer, Calc, Impress/Draw, and Math where visible.
- Common context menus and dialogs in Writer/Calc/Impress no longer show avoidable English.
- Font family names and internal identifiers are preserved.
- A packaged-app verification report and screenshot evidence exist.
- Remaining English is explicitly listed as preserved, lower-priority, or blocked with a reason.

