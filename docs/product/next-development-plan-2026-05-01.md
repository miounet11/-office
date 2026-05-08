# Next Development Plan

Date: 2026-05-01
Product: 可圈office
Controller/reviewer: Codex
Primary implementation owner: Clavue
Status: alpha development continues; not beta-ready; not release-ready.

This document supersedes the stale localization portions of `comprehensive-development-master-plan-2026-05-01.md` and `next-stage-development-plan.md`. Those documents remain useful for product strategy, but the active execution baseline is now localization evidence through `L10N-33`.

## 1. Current Verdict

可圈office is improving, but it is not yet convenient, stable, or complete enough to be called world-class. The strongest evidence is now in bounded source/build localization lanes, not in full packaged-product quality.

Current facts:

- Localization evidence exists through `L10N-33`.
- `L10N-32` completed Calc Standard Filter and aligned UI-test selectors/resource strings that text-match filter conditions.
- `L10N-33` completed Calc Advanced Filter.
- Accumulated localization checks through `L10N-33` passed.
- `gmake sc.build` passed with `0 new errors`, `6 new warnings`, and `0 new fatals`.
- The remaining Calc warnings are unrelated UI accessibility warnings and must be handled in a dedicated accessibility lane.
- The source tree is heavily dirty across product source, branding, icons, packaging, templates, and generated/local artifacts; source hygiene remains a release blocker.
- Source/build evidence is not packaged-app evidence. Beta/release claims remain blocked until screenshots, accessibility, compatibility, and source hygiene gates close.

Correct posture:

```text
Alpha: continue.
Beta: blocked.
Release: blocked.
World-class claim: blocked until evidence proves it.
```

## 2. Benchmark Inputs

Use the autoresearch pattern as the operating model: bounded hypothesis, fixed evaluation budget, one clear metric, keep/revise/blocked decision, and durable experiment logs. For office software, the metric is not only "strings changed"; it is "visible user-facing defects removed without breaking compatibility, accessibility, or source hygiene."

External benchmark signals to keep in view:

- `karpathy/autoresearch`: a small controlled loop with constrained edit scope, fixed evaluation, and repeatable keep/reject decisions: <https://github.com/karpathy/autoresearch>
- Microsoft 365 accessibility expectations: Word, Excel, and PowerPoint accessibility tools and Accessibility Checker are first-class product surfaces: <https://support.microsoft.com/en-us/office/accessibility-tools-for-microsoft-365-b5087b20-1387-4686-a0a5-8e11c5f46cdf>
- Microsoft Copilot in Word sets the user expectation for document summary/chat/drafting, but it also documents license, storage, and citation limitations that we must not hide: <https://support.microsoft.com/en-us/office/create-a-summary-of-your-document-with-copilot-in-word-79bb7a0a-3bf7-41fe-8c09-56f855b669bf>
- WPS positions PDF, OCR, conversion, templates, AI PDF chat, presentation generation, cloud sync, and Microsoft Office compatibility as core user-facing value: <https://explore.wps.com/features>

Implication for 可圈office:

- Chinese-first UI is the immediate trust foundation.
- Accessibility must be live, not only static.
- PDF and conversion workflows are core office-product expectations, not optional extras.
- AI features must be preview-first, reversible, privacy-visible, and document-format-aware.

## 3. Active Repeatable Evaluation Loop

Every Clavue implementation lane must follow this loop:

1. Baseline: identify the exact visible user surface and current leaks/defects.
2. Scope: declare owned files before editing; avoid shared file families unless explicitly assigned.
3. Patch: edit only source files and evidence files for the lane.
4. Focused checker: add or update `tmp/localization-sweep/check-l10n-XX-*.py`.
5. Parse gate: run XML parse for every touched `.ui` file.
6. Checker gate: run the focused checker.
7. Accumulated gate: run all localization checkers through the new lane.
8. Build gate: run the smallest relevant module build, such as `gmake sc.build`, `gmake sw.build`, `gmake cui.build`, or `gmake sd.build`.
9. Evidence report: write `tmp/localization-sweep/l10n-XX-*.md` with scope, touched files, fixed strings, preserved strings, commands, and stop-rule concerns.
10. Decision: mark the lane `Keep`, `Revise`, or `Blocked`.

Required stop discipline:

- If a UI sanitizer warning becomes fatal, stop the lane and report the exact file/control.
- If code text-matches a visible label, align resource strings and tests in the same lane or stop.
- If UI tests select by localized text, update the tests in the same lane or stop.
- If the patch requires generated output, packaging artifacts, or broad cleanup, stop and split the lane.

## 4. Next Major Phases

### Phase A: Finish Calc High-Frequency Localization Spine

Goal: remove English from normal Calc filtering, conditional formatting, table, sidebar, and compact workflow surfaces.

Immediate lane order:

| Lane | Surface | Primary source target | Reason |
| --- | --- | --- | --- |
| `L10N-34` | Calc Pivot Filter | `/Users/lu/kdoffice-src/sc/uiconfig/scalc/ui/pivotfilterdialog.ui` | Small continuation of standard/advanced filter vocabulary; fastest safe next keep/revise loop. |
| `L10N-35` | Calc Conditional Formatting Entry | `/Users/lu/kdoffice-src/sc/uiconfig/scalc/ui/conditionalentry.ui` | High visible count and high user frequency; must review test selectors before editing. |
| `L10N-36` | Calc Table Sidebar | `sidebardatabase.ui`, `tablestylesbox.ui` | Table-style controls are exposed in normal spreadsheet editing. |
| `L10N-37` | Calc Sparkline/Validation/Sort Follow-Up | `sparklinedialog.ui`, `validationdialog.ui`, `sortdialog.ui` as split lanes if needed | These are high-value spreadsheet workflows; split if the checker becomes too broad. |

Acceptance:

- Each lane has focused checker, XML parse, accumulated sweep, evidence report, and `gmake sc.build`.
- Known unrelated Calc UI accessibility warnings remain unchanged unless the lane is explicitly accessibility-owned.
- No claim that Calc localization is complete until packaged-app screenshots prove it.

### Phase B: Writer Knowledge Navigation And Long-Document Workflows

Goal: make Writer trustworthy for Chinese users working with long documents, tables of contents, headings, navigator, and context menus.

Lane order:

| Lane | Surface | Primary source target | Reason |
| --- | --- | --- | --- |
| `L10N-38` | Writer TOC/Index Main Page | `sw/uiconfig/swriter/ui/tocindexpage.ui` | High visible English count and core long-document workflow. |
| `L10N-39` | Writer TOC Entries Page | `sw/uiconfig/swriter/ui/tocentriespage.ui` | Complex labels/tooltips; must preserve structure tokens and internal placeholders. |
| `L10N-40` | Writer Navigator Context/Panel | `navigatorcontextmenu.ui`, `navigatorpanel.ui` | High-frequency navigation and outline workflow; visible in normal editing. |
| `L10N-41` | Writer Style Display Follow-Up | Writer style names and sidebar/style controls | High risk because style display names can touch compatibility; requires dedicated policy and tests. |

Acceptance:

- `gmake sw.build` after each Writer lane.
- Any style-name work must explicitly separate display aliases from internal style IDs.
- No DOCX/ODF import/export behavior changes in these lanes.

### Phase C: Packaged-App Proof And Accessibility Cleanup

Goal: prove the localized source actually appears in the running product and that the UI is usable.

Work packets:

- Create `tmp/localization-sweep/m3-04-packaged-verification.md`.
- Capture screenshots for Writer, Calc, Impress, Draw, Start Center, and Workbench.
- Build or refresh runnable app with `gmake test-install` when source lanes are stable enough.
- Open a dedicated `A11Y-01 Calc UI Sanitizer Warnings` lane for the six known Calc warnings.
- Run live keyboard traversal checks for high-frequency dialogs.
- Add VoiceOver/manual evidence for Start Center, Workbench, Writer navigator, Calc filters, and conditional formatting.

Acceptance:

- Every fixed surface has packaged-app screenshot evidence or an explicit reason it cannot yet be captured.
- Remaining English is classified as technical term, font name, identifier, fixture-only, intentionally preserved stock label, or unresolved defect.
- Accessibility defects have file/control references and a remediation packet.

### Phase D: Compatibility, PDF, Performance, And Product Depth

Goal: move beyond translation into actual world-class office reliability.

Work packets:

- Expand the compatibility corpus with Chinese DOCX/XLSX/PPTX samples from business, finance, education, government, resume, contract, report, and presentation workflows.
- Add visual comparison evidence, not only open/save success.
- Add PDF export trust checks: page count, Chinese font embedding, bookmarks/TOC, PDF/A where supported, and stable layout.
- Add performance budgets for start, open, save, export PDF, and large document scrolling.
- Keep Writer intelligence preview-only until diagnostics are stable, reversible, and proven not to dirty documents.
- Keep Impress outline builder internal/test-only until editable placeholder behavior and export evidence are proven.
- Do not enable provider/plugin runtime until service-mode policy, signing, offline/private/cloud boundaries, and user consent are enforceable.

Acceptance:

- Compatibility results include before/after artifacts and stop rules for regressions.
- PDF evidence includes actual exported files and validator results where tooling exists.
- Performance reports separate crash, timeout, and budget miss.
- AI features never silently upload, silently mutate, or hide uncertainty.

## 5. Immediate Clavue Execution Packet

Clavue should start with `L10N-34 Calc Pivot Filter`.

Owned source:

- `/Users/lu/kdoffice-src/sc/uiconfig/scalc/ui/pivotfilterdialog.ui`

Owned evidence:

- `/Users/lu/可点office/tmp/localization-sweep/check-l10n-34-calc-pivot-filter.py`
- `/Users/lu/可点office/tmp/localization-sweep/l10n-34-calc-pivot-filter.md`

Required actions:

- Localize visible dialog title, logical operator labels, field/condition/value labels, options expander, filter options, copy-result controls, shrink/maximize descriptions, and accessible names/descriptions.
- Preserve `_OK`, `_Cancel`, `_Help` unless a dedicated stock-button lane is opened.
- Preserve comparison symbols, widget IDs, context IDs, object IDs, response IDs, relation targets, schema names, and internal placeholders.
- Search for direct test selectors before changing condition labels.
- If code text-matches pivot filter strings, update the corresponding resource strings/tests in the same lane.

Required verification:

```sh
python3 /Users/lu/可点office/tmp/localization-sweep/check-l10n-34-calc-pivot-filter.py
python3 -m xml.etree.ElementTree /Users/lu/kdoffice-src/sc/uiconfig/scalc/ui/pivotfilterdialog.ui
python3 -m py_compile /Users/lu/可点office/tmp/localization-sweep/check-l10n-34-calc-pivot-filter.py
for f in /Users/lu/可点office/tmp/localization-sweep/check-l10n-*.py; do python3 "$f" || exit 1; done
gmake -C /Users/lu/kdoffice-src sc.build
```

Required report:

- Scope.
- Touched files.
- English leaks fixed.
- English intentionally preserved.
- Exact command output summary.
- New warnings/errors/fatals count from `gmake sc.build`.
- `Keep`, `Revise`, or `Blocked` verdict.

## 6. Codex Control And Review Protocol

Codex controls quality gates; Clavue implements bounded packets.

Codex duties:

- Keep the roadmap current.
- Review every Clavue report against source/build evidence.
- Reject broad claims that lack packaged-app or compatibility proof.
- Split lanes when touched files or risk become too broad.
- Maintain beta/release blocker list.

Clavue duties:

- Implement one bounded lane at a time.
- Never revert unrelated dirty work.
- Never edit generated build output as source.
- Return exact touched files and verification commands.
- Report preserved English explicitly.
- Stop instead of guessing when a label has code/test coupling.

Review rule:

```text
No lane is accepted because it "looks translated."
A lane is accepted only when source diff, focused checker, accumulated checker, parse gate, module build, and evidence report agree.
```

## 7. Top Risks And Stop Rules

| Risk | Stop rule |
| --- | --- |
| Translating identifiers | Stop if a proposed change touches widget IDs, UNO commands, schema nodes, internal style IDs, service names, or real font names. |
| Code text-match breakage | Stop unless resource strings and UI tests are updated in the same lane. |
| UI sanitizer fatal | Stop and create a dedicated accessibility remediation packet. |
| Broad dirty tree confusion | Stop if implementation requires cleanup/reset/staging of unrelated files. |
| False beta claim | Stop any beta/release wording until validator, source hygiene, accessibility, packaged UI, compatibility, and packaging gates pass. |
| AI feature overreach | Stop any feature that silently uploads, silently mutates documents, or lacks preview/revert boundaries. |
| Visual compatibility regression | Stop if a compatibility sample loses layout, formulas, comments, tracked changes, fonts, or slide editability without a documented exception. |

## 8. Beta Exit Criteria

可圈office can only move from alpha toward beta after all of the following are true:

- Normal Chinese workflows in Writer, Calc, Impress, Draw, Start Center, and Workbench have no unresolved high-severity visible English.
- Packaged-app screenshot evidence exists for all claimed localized surfaces.
- Live accessibility evidence exists for keyboard traversal, VoiceOver labels, resize behavior, and high contrast/theme behavior.
- Known UI sanitizer warnings are either fixed or explicitly accepted as non-blocking with rationale.
- Compatibility corpus includes representative Chinese DOCX/XLSX/PPTX files with open/save/export and visual evidence.
- PDF export evidence covers Chinese fonts and real document layouts.
- Source hygiene strict mode is passed or every remaining dirty item has a release exception.
- Packaging/signing/notarization/download artifact checks are complete for the target platform.
- AI/provider/plugin paths are blocked by policy unless consent, offline/private/cloud boundaries, signing, and rollback behavior are implemented.

Until then, the project remains alpha.
