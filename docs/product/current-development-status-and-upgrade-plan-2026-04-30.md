# Current Development Status And Upgrade Plan

Date: 2026-04-30
Product: 可圈office
Controller/reviewer: Codex
Implementation owner for bounded source packets: Clavue
Verdict: not feature-complete, not beta-ready, and not release-ready.

## Executive Verdict

The product has meaningful alpha foundations, especially around control-plane gates, compatibility smoke evidence, branding/default work, and recent Chinese UI localization. However, it is not yet a complete or world-class office product. The current strongest evidence is source/build progress, not packaged-app user proof.

Do not claim beta or release readiness until these are closed:

- Visible Chinese UI completion for high-frequency Writer, Calc, Impress, Draw, Start Center, and shared dialogs.
- Packaged-app screenshots/manual UI proof for every claimed localization surface.
- Strict validator readiness for external conformance tools/assets.
- Strict source hygiene or an explicit release exception packet.
- Live accessibility evidence, not only static checks.
- Broader compatibility and PDF visual/layout evidence.
- Product-depth workflows beyond preview-only intelligence.

## Current Evidence Snapshot

Recent completed localization lanes:

| Lane | Surface | Status |
| --- | --- | --- |
| `L10N-02B` to `L10N-24` | Writer/shared/CUI/Calc/Impress/Math selected surfaces | focused checks and accumulated sweep exist |
| `L10N-25` | `cui/uiconfig/ui/securityoptionsdialog.ui` | passed focused check, XML parse, full sweep, `gmake cui.build` |
| `L10N-26` | `cui/uiconfig/ui/bulletandposition.ui` | passed focused check, XML parse, full sweep, `gmake cui.build` |
| `L10N-27` | `cui/uiconfig/ui/fmsearchdialog.ui` | passed focused check, XML parse, full sweep, `gmake cui.build` |
| `L10N-28` | `cui/uiconfig/ui/menuassignpage.ui` | passed focused check, XML parse, full sweep, `gmake cui.build` |

Most recent source/build gate:

```text
Full accumulated localization sweep through L10N-28: passed
gmake cui.build: 0 new warnings, 0 new fatals
```

Known beta gate state from `tmp/v2-beta-gates/beta-03-source-hygiene-release-packet.md`:

| Gate | Status | Release meaning |
| --- | --- | --- |
| compatibility manifest audit | passed | useful, but narrow |
| compatibility roundtrip | passed | useful, but not visual fidelity proof |
| compatibility layout evidence | passed | seeded evidence, not full comparison |
| GUI smoke timing | passed | process/budget evidence, not full UX proof |
| workbench static accessibility | passed | not enough for beta |
| validator readiness strict | failed | beta blocker |
| source hygiene strict | failed | beta blocker |
| workbench live accessibility | failed | beta blocker |

## Remaining Visible UI Risk

The current heuristic source scan still finds many possible English user-visible strings. Counts include false positives and intentionally preserved technical names, but the scale shows that localization is not complete:

| Module surface | Files with possible English | Possible strings |
| --- | ---: | ---: |
| `cui/uiconfig/ui` | 181 | 2105 |
| `sw/uiconfig/swriter/ui` | 196 | 3353 |
| `sc/uiconfig/scalc/ui` | 177 | 2375 |
| `sfx2/uiconfig/ui` | 29 | 208 |
| `sd/uiconfig/simpress/ui` | 48 | 633 |
| `sd/uiconfig/sdraw/ui` | 17 | 215 |

Highest-priority examples still visible in the scan:

- CUI: `pageformatpage.ui`, `cellalignment.ui`, `swpossizepage.ui`, `textanimtabpage.ui`, `spellingdialog.ui`, `numberingformatpage.ui`, `colorpickerdialog.ui`.
- Writer: accessibility checker, auto abstract, address block, comments, ASCII filter, search prompts, table/context/style-related pages.
- Calc: advanced filter, ANOVA, AutoFormat, AutoSum, source data, consolidation, sort/filter/formula dialogs.
- Impress/Draw: custom animation, master slide menus, slide transition, duplicate/copy dialogs, printer options, draw page dialogs.
- SFX2/shared shell: target dialogs, redaction, template/property dialogs, start center/shared document properties.

Conclusion: current UI localization is a sustained multi-round program, not a finished feature.

## Functional Completeness Assessment

| Area | Current status | Missing before beta/release |
| --- | --- | --- |
| Chinese-first UI | Partial source localization; good lane discipline through `L10N-28` | finish high-frequency UI, package evidence, stock-button policy, style-display-name policy |
| Compatibility | 27-sample smoke and roundtrip evidence exist | larger Chinese corpus, true visual comparison, import/export failure triage, PDF proof |
| PDF workflow | some compatibility/layout evidence exists | Chinese font embedding, page count, bookmarks/TOC, PDF/A validator readiness, signing/export confidence |
| Accessibility | static workbench check passed | live keyboard, VoiceOver, high-contrast, resize, missing-template fallback |
| Performance | GUI timing smoke exists | startup/open/save/export budgets, large document budgets, regression tracking |
| Writer intelligence | preview-only analyzer exists and was hardened | no one-by-one apply path, no broad diagnostics, no user-facing evidence console |
| Calc intelligence | not product-ready | formula/date/currency/print-overflow diagnostics missing |
| Impress generation | schema/builder seed exists | user UI, editable slide proof, PPTX export evidence, text-fit tests |
| Plugin/provider runtime | manifest validator and policy exist | runtime loading/signing/provider execution blocked by policy and trust gates |
| Release hygiene | strict hygiene failing | classify dirty tree, separate generated outputs, approve/reject release exceptions |
| Packaging/release | source builds pass in lanes | test install, signed/notarized/package artifacts, app screenshots, regression matrix |

## Upgrade Strategy

The next stage should prioritize visible trust before broad feature expansion:

1. Remove first-minute English UI in normal Chinese workflows.
2. Prove the installed app matches source claims with screenshots and manual notes.
3. Harden beta blockers: validator assets, source hygiene, live accessibility.
4. Expand compatibility and PDF evidence to match real Word/WPS user expectations.
5. Add safe workflow intelligence only after preview/undo/failure boundaries are proven.

## Development Phases

### Phase 1: Chinese-First UI Completion

Goal: make normal Writer, Calc, Impress, Draw, and Start Center use feel Chinese-first.

Priority work:

- Continue CUI shared dialog cleanup: page format, alignment, position/size, spell, numbering format, color/gradient/transparency.
- Continue Writer high-frequency cleanup: comments, table dialogs, insert/caption, document properties, style/sidebar labels.
- Continue Calc cleanup: filter, sort, validation, import, formula/function, scenario, AutoFormat.
- Continue Impress/Draw cleanup: custom animation, master slides, transitions, duplicate/copy, presentation dialogs.
- Decide stock-button policy: leave GTK stock buttons as-is, or localize them through a separate global lane with tests.
- Decide style-display-name policy: display aliases may be localized only if style lookup, macros, accelerators, DOCX/ODF roundtrip, and tests remain safe.

Required evidence:

- Per-lane focused checker.
- XML parse for every edited `.ui`.
- Smallest relevant module build.
- Accumulated localization sweep.
- Evidence doc under `tmp/localization-sweep/`.

### Phase 2: Packaged UI And Accessibility Proof

Goal: prove the installed app, not only source XML.

Required checks:

- Writer: new document, status language menu, style dropdown, sidebar deck, context menu, table menu, Paste Special, Table Properties.
- Calc: new spreadsheet, cell context menu, row/column menu, function/sidebar labels, Paste Special, validation/sort/filter.
- Impress: new presentation, sidebar deck, animation, slide transition, master slide, slide context menu.
- Draw: page/object context menu, duplicate/copy, snap options, sidebar deck.
- Start Center/Workbench: scenario labels, blank document routes, recent files, template actions.
- Accessibility: Tab, Shift+Tab, Enter, Space, VoiceOver labels, high-contrast/theme behavior, resize.

Required output:

- `tmp/localization-sweep/m3-04-packaged-verification.md`.
- Screenshot folder path.
- Manual pass/fail notes with exact defects.
- Fresh non-hung UI test results where available.

### Phase 3: Beta Gate Closure

Goal: make readiness claims honest and reproducible.

Required work:

- Validator readiness: acquire/configure exact trusted validator assets and make strict readiness pass.
- Source hygiene: classify dirty files into source, generated, local-only, release-exception, or cleanup.
- Workbench live accessibility: produce evidence and fix any blockers.
- Re-run `bin/v2-beta-gates.sh` only after the above is materially changed.

Stop condition:

- If strict validators or source hygiene remain failed, beta/release claims remain blocked even if UI localization improves.

### Phase 4: Compatibility And PDF Trust Lab

Goal: prove documents survive, not merely open.

Required work:

- Expand DOCX/XLSX/PPTX corpus with representative Chinese business, education, finance, and presentation files.
- Add visual/PDF-rendered comparison for at least one representative DOCX, XLSX, and PPTX before any import/export engine edits.
- Add PDF export checks: Chinese font embedding, page count stability, bookmarks/TOC, PDF/A once validator assets exist.
- Add Writer track changes/comments preservation smoke.
- Add Calc formula/chart/filter/print-area evidence.
- Add Impress placeholder/text fitting/export evidence.

Stop condition:

- No import/export engine edits without a failing representative sample, before/after evidence, and rollback plan.

### Phase 5: Product Workflow Depth

Goal: become useful beyond a localized LibreOffice-style shell.

Allowed next features:

- Writer diagnostics: document sharing readiness, style consistency, table overflow, caption/TOC issues, accessibility warnings.
- Calc diagnostics: formula errors, inconsistent dates/currencies, hidden rows, print overflow, broken references.
- Impress draft workflow: normalized outline to editable slides, text-fit warnings, PPTX export proof.
- Workbench evidence console: show checks, warnings, and next actions without silent mutation.

Blocked until separate acceptance:

- Writer one-click apply or batch mutation.
- Runtime provider calls.
- Runtime plugin loading.
- Cloud/private provider mode.
- Any silent document upload or silent document mutation.

## Immediate Clavue Packets

### Packet `L10N-29`: CUI Page Format

Owner: Clavue
Reviewer: Codex
Write scope:

- `/Users/lu/kdoffice-src/cui/uiconfig/ui/pageformatpage.ui`
- `/Users/lu/可点office/tmp/localization-sweep/check-l10n-29-cui-page-format.py`
- `/Users/lu/可点office/tmp/localization-sweep/l10n-29-cui-page-format.md`

Required gates:

```sh
python3 tmp/localization-sweep/check-l10n-29-cui-page-format.py
xmllint --noout /Users/lu/kdoffice-src/cui/uiconfig/ui/pageformatpage.ui
gmake -C /Users/lu/kdoffice-src cui.build
```

### Packet `L10N-30`: CUI Cell Alignment

Owner: Clavue
Reviewer: Codex
Write scope:

- `/Users/lu/kdoffice-src/cui/uiconfig/ui/cellalignment.ui`
- focused checker and evidence doc under `/Users/lu/可点office/tmp/localization-sweep/`

Guardrails:

- Preserve technical typography terms when needed.
- Preserve widget IDs, relations, adjustment IDs, and GTK/ATK schema names.

### Packet `L10N-31`: CUI Position/Size

Owner: Clavue
Reviewer: Codex
Write scope:

- `/Users/lu/kdoffice-src/cui/uiconfig/ui/swpossizepage.ui`
- focused checker and evidence doc under `/Users/lu/可点office/tmp/localization-sweep/`

Guardrails:

- Preserve coordinate semantics, ratio behavior, anchoring behavior, object IDs, and source logic.

### Packet `BETA-01`: Source Hygiene Classification

Owner: Codex primary, Clavue support only if assigned
Write scope:

- `docs/product/source-hygiene-release-packet.md`
- `tmp/source-hygiene-report-strict.md`
- optional generated-output cleanup only after explicit approval

Goal:

- Turn the dirty worktree into a release-classified list: keep source, generated output, local-only, needs cleanup, needs human decision.

### Packet `BETA-02`: Packaged Screenshot Proof

Owner: Clavue primary, Codex review
Write scope:

- `tmp/localization-sweep/m3-04-packaged-verification.md`
- screenshot directory under `tmp/localization-sweep/screenshots/`

Goal:

- Prove the installed app shows the claimed Chinese UI in Writer/Calc/Impress/Start Center.

## Review Protocol

Every implementation round must return:

- Verdict: `Keep`, `Revise`, or `Blocked`.
- Touched files.
- English leaks fixed.
- English intentionally preserved with reason.
- Commands run and exact results.
- Remaining leaks.
- Stop-rule concerns.

Codex rejects the round if:

- It translates identifiers, UNO command IDs, schema nodes, service names, or real font names.
- It edits generated outputs as source.
- It claims packaged-app UI success without screenshots/manual evidence.
- It changes import/export behavior without a failing sample and rollback plan.
- It lacks a focused checker and evidence doc.

## Stop Rules

Stop and report `Blocked` before:

- Claiming all features are complete.
- Claiming beta/release readiness while validator readiness, source hygiene, or live accessibility is failed.
- Claiming Chinese UI completion without packaged-app screenshots.
- Running destructive cleanup in the dirty source tree.
- Broad search/replace across UI resources.
- Editing import/export engines without representative failure evidence.
- Adding runtime AI/provider/plugin paths before privacy, policy, and failure isolation gates pass.

## Completion Definition

The product can be considered beta-candidate only when:

- High-frequency Chinese UI surfaces are clean in packaged-app screenshots.
- `validator-readiness-strict`, `source-hygiene-strict`, and live Workbench accessibility are closed or explicitly accepted as release exceptions.
- Compatibility corpus has meaningful DOCX/XLSX/PPTX visual/layout evidence.
- PDF export has Chinese font/page-count/PDF-A evidence where applicable.
- Core module builds and targeted UI tests pass.
- All intelligent/document-changing features are preview-first or have explicit undo, rollback, stale-state rejection, and failure-no-mutation tests.
