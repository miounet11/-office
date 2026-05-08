# Comprehensive Development Master Plan

Date: 2026-05-01
Product: 可圈office
Controller/reviewer: Codex
Primary implementation owner for bounded packets: Clavue
Verdict: not function-complete, not beta-ready, not release-ready.

## 1. Current Verdict

可圈office has moved from pure concept/control-plane work into real source development, but it is still an alpha-stage product. The recent Chinese localization lanes are disciplined and useful, yet they are only source/build evidence for selected surfaces.

The product is not yet "fully complete" because:

- High-frequency UI still contains visible English across Writer, Calc, Impress, Draw, CUI, and shared SFX2 dialogs.
- Source-level localization has not yet been proven in the packaged application with screenshot/manual evidence.
- Strict beta gates still have known blockers: validator readiness, source hygiene, and live accessibility.
- Compatibility evidence is still too narrow for Word/WPS-class trust.
- PDF workflow evidence is incomplete.
- Product-depth workflows are not mature enough: Writer intelligence is preview-only, Calc diagnostics are missing, Impress generation is not productized, provider/plugin runtime remains blocked.
- Release packaging, signing, notarization, and artifact verification are not closed.

The correct product posture is:

```text
Alpha development continues.
Beta claims are blocked.
Release claims are blocked.
World-class claims are blocked until evidence proves them.
```

## 2. Evidence Snapshot

### Completed Recently

The localization program has completed focused lanes through `L10N-28`.

Most recent confirmed lanes:

| Lane | Main surface | Evidence |
| --- | --- | --- |
| `L10N-25` | CUI security options dialog | focused checker, XML parse, full sweep, `gmake cui.build` |
| `L10N-26` | CUI bullets/numbering position dialog | focused checker, XML parse, full sweep, `gmake cui.build` |
| `L10N-27` | CUI record search dialog | focused checker, XML parse, full sweep, `gmake cui.build` |
| `L10N-28` | CUI menu/toolbar assignment page | focused checker, XML parse, full sweep, `gmake cui.build` |

Accumulated evidence exists under:

- `/Users/lu/可点office/tmp/localization-sweep/`
- `/Users/lu/可点office/docs/product/current-development-status-and-upgrade-plan-2026-04-30.md`
- `/Users/lu/可点office/docs/product/full-ui-localization-sweep-handoff.md`
- `/Users/lu/可点office/docs/product/word-wps-benchmark-development-roadmap.md`

### Current Source Hygiene Risk

The wrapper repository has massive generated/build-output dirt, including `instdir/`, `workdir/`, config/autoconf outputs, and release-stage artifacts. This confirms `source-hygiene-strict` remains a real release blocker.

The source tree `/Users/lu/kdoffice-src` also has many intentional product edits across CUI, Writer, Calc, Impress/Draw, SFX2, officecfg, branding, templates, packaging, icons, and intelligent-office source files. These must be classified before beta.

Do not clean, reset, delete, or stage broadly without a dedicated source-hygiene packet.

### Remaining Visible English Risk

Fresh May 1 heuristic scan of selected UI folders still shows large remaining possible English UI exposure. Counts include false positives and intentionally preserved technical terms, but the volume is enough to prove localization is not complete:

| Surface | Files with possible English | Possible strings |
| --- | ---: | ---: |
| `cui/uiconfig/ui` | 180 | 2103 |
| `sw/uiconfig/swriter/ui` | 196 | 3353 |
| `sc/uiconfig/scalc/ui` | 177 | 2375 |
| `sd/uiconfig/simpress/ui` | 48 | 633 |
| `sd/uiconfig/sdraw/ui` | 17 | 215 |
| `sfx2/uiconfig/ui` | 29 | 208 |
| `desktop/uiconfig/ui` | 0 | 0 |

Highest-count examples from the scan:

| File | Count | Example strings |
| --- | ---: | --- |
| `sc/uiconfig/scalc/ui/standardfilterdialog.ui` | 119 | `Standard Filter`, `_Clear` |
| `sc/uiconfig/scalc/ui/conditionalentry.ui` | 95 | `All Cells`, `Formula is` |
| `sw/uiconfig/swriter/ui/tocindexpage.ui` | 94 | `Open`, `_New...`, `Type:` |
| `sw/uiconfig/swriter/ui/tocentriespage.ui` | 79 | `_Level`, `_Structure:` |
| `sw/uiconfig/swriter/ui/navigatorcontextmenu.ui` | 71 | `Send Outline to Clipboard`, `Go to` |
| `sc/uiconfig/scalc/ui/sidebardatabase.ui` | 71 | `Header Row`, `Total Row` |
| `sc/uiconfig/scalc/ui/tablestylesbox.ui` | 69 | `Header Row`, `Filter Buttons` |
| `sw/uiconfig/swriter/ui/notebookbar_groups.ui` | 66 | `Default`, `Grayscale` |
| `sw/uiconfig/swriter/ui/navigatorpanel.ui` | 64 | `_Index`, `File` |
| `sc/uiconfig/scalc/ui/sparklinedialog.ui` | 61 | `Sparkline Properties`, `Shrink` |

## 3. Product Completeness Matrix

| Area | Current status | Completion gap |
| --- | --- | --- |
| Chinese UI | Partial source cleanup with strong lane evidence | finish high-frequency UI, verify packaged app, decide stock/style policy |
| Writer basics | Core editor exists; selected UI localized; preview analyzer exists | TOC, navigator, frame, view/options, comments, table/style flows still need cleanup and proof |
| Calc basics | Core spreadsheet exists; selected UI localized | filter/sort/conditional formatting/formula/sidebar UI and diagnostics need work |
| Impress/Draw basics | Core presentation/draw exists; selected UI localized | animation/master/transition/sidebar/export proof incomplete |
| Start Center/Workbench | Some Chinese and smoke evidence exists | live accessibility, packaged screenshots, missing-template fallback proof |
| Compatibility | 27-sample smoke/roundtrip exists | representative Chinese corpus, true visual comparison, validator-backed proof |
| PDF | layout evidence seed exists | Chinese font embedding, page count, PDF/A/veraPDF, bookmark/TOC, signing proof |
| Accessibility | static checks exist | live keyboard, VoiceOver, high contrast, resize, manual evidence |
| Performance | GUI timing smoke exists | open/save/export/large-doc budgets and trend dashboard |
| Reliability | module builds pass for lanes | crash recovery, autosave, dirty-state, undo/rollback evidence |
| Writer intelligence | preview-only, hardened in narrow tests | apply path blocked; broader diagnostics and evidence console missing |
| Calc intelligence | not productized | formula/range/date/currency/print diagnostics missing |
| Impress generation | schema/builder seed exists | UI, editable slides, text fitting, export evidence missing |
| Plugin/provider runtime | validators/policy exist | runtime loading/signing/provider calls blocked |
| Packaging/release | local build artifacts exist | strict hygiene, signed/notarized release, download artifact validation |

## 4. Development Principles

1. Evidence beats claims. A feature is not done until source, build, test, and user-visible evidence agree.
2. Chinese-first trust comes before AI breadth.
3. Compatibility changes require failing samples and before/after evidence.
4. Document-changing intelligence must be preview-first, reversible, and failure-safe.
5. No silent upload. No silent mutation. No runtime provider/plugin path without policy gates.
6. Generated build outputs are not source.
7. Clavue implements bounded packets; Codex controls gates and review.

## 5. Major Roadmap

### Phase 0: Control And Hygiene Stabilization

Goal: keep development safe while the tree is dirty and many lanes are active.

Required work:

- Classify dirty worktree into source, generated, local evidence, config/autoconf, release-stage, and human-decision buckets.
- Preserve evidence under `tmp/` until referenced reports are superseded.
- Separate source changes from build outputs before beta.
- Maintain one owner per file family per round.

Deliverables:

- Updated `docs/product/source-hygiene-release-packet.md`.
- Fresh `tmp/source-hygiene-report-strict.md`.
- Human-approved cleanup or release-exception list.

Acceptance:

- `source-hygiene-strict` passes or every remaining entry has an explicit release exception.

### Phase 1: Chinese-First UI Completion

Goal: remove visible English from normal Chinese office workflows.

Priority order:

1. CUI common dialogs: page format, cell alignment, position/size, spelling, number format, color picker, gradient, transparency, line, image, password.
2. Writer high-frequency flows: navigator, TOC/index, comments, table, frame, view/options, styles, notebookbar, context menus.
3. Calc high-frequency flows: standard filter, conditional formatting, table styles, database sidebar, sort/filter, formula/function, validation.
4. Impress/Draw flows: animation, slide transition, master slides, drawing pages, duplicate/copy, presentation settings.
5. SFX2/shared shell: document properties, template dialogs, password, print options, redaction, target dialogs.
6. Stock button policy and style-display-name policy as separate high-risk lanes.

Per-lane acceptance:

- Focused checker added.
- XML parse passes.
- Relevant module build passes.
- Accumulated localization sweep passes.
- Evidence doc lists preserved English.
- No IDs, UNO command names, schema nodes, real font names, or generated files translated.

### Phase 2: Packaged UI Verification

Goal: prove source localization appears in the installed app.

Required manual/screenshot matrix:

| Module | Required surfaces |
| --- | --- |
| Writer | new document, status language menu, style dropdown, navigator, sidebar, text context menu, table context menu, Paste Special, Table Properties, TOC/index |
| Calc | new sheet, cell context menu, standard filter, conditional formatting, table styles, formula/function, row/column menus |
| Impress | new presentation, sidebar, custom animation, slide transition, master slide, slide context menu, export/PDF path |
| Draw | page/object context menu, duplicate/copy, snap options, sidebar |
| Start Center | Workbench scenarios, blank document routes, recent files, templates |

Deliverables:

- `tmp/localization-sweep/m3-04-packaged-verification.md`.
- Screenshot directory under `tmp/localization-sweep/screenshots/`.
- Explicit remaining-English list by severity.

Acceptance:

- Claimed fixed surfaces have packaged-app proof.
- Any remaining English is classified as technical, font name, identifier, fixture-only, or unresolved defect.

### Phase 3: Accessibility And Interaction Reliability

Goal: make the UI usable, not merely translated.

Required work:

- Keyboard traversal: Tab, Shift+Tab, Enter, Space, Esc.
- VoiceOver labels for Workbench and high-frequency dialogs.
- High-contrast/theme behavior.
- Resize behavior.
- Missing-template and missing-resource fallback behavior.
- Accessibility labels for icon-only controls.

Acceptance:

- Static accessibility check passes.
- Live accessibility evidence packet exists.
- Any blocker has a file/line and remediation packet.

### Phase 4: Compatibility And PDF Trust Lab

Goal: compete on document survival and fidelity.

Required work:

- Expand DOCX/XLSX/PPTX corpus with Chinese business, finance, education, government, and presentation samples.
- Add true visual/PDF-rendered comparison for representative samples.
- Add tracked changes/comments preservation for Writer.
- Add XLSX formula/chart/filter/print-area evidence.
- Add PPTX placeholder/text-fit/media warning evidence.
- Add PDF export checks: Chinese font embedding, page count, bookmarks/TOC, PDF/A, signing where applicable.

Acceptance:

- Compatibility reports distinguish open/save success, visual fidelity, PDF fidelity, and validator conformance.
- Import/export engine edits require failing sample, before/after evidence, and rollback plan.

### Phase 5: Performance, Stability, And Recovery

Goal: make daily use reliable at real workload sizes.

Required budgets:

- Cold Start Center under beta budget.
- Warm Start Center under target budget.
- Blank Writer/Calc/Impress launch under target budget.
- Open/save/export budgets for medium and large Chinese documents.
- PDF export time and memory tracking.
- Crash recovery and autosave smoke.

Acceptance:

- `gui-smoke-timing` reports crash, timeout, and budget miss separately.
- Performance data is trended across runs.
- Regressions block release unless explicitly accepted.

### Phase 6: Product Workflow Depth

Goal: make 可圈office useful beyond a localized shell.

Workflow targets:

- Prepare document for sharing: compatibility, accessibility, metadata/privacy, PDF readiness.
- Clean formatting: preview-only first, one-by-one apply later.
- Meeting minutes: actions, owners, dates, follow-up table.
- Business report: headings, TOC, captions, table overflow, PDF readiness.
- Budget workbook: formula errors, hidden rows, inconsistent dates/currency, print overflow.
- Presentation draft: normalized outline to editable slides, text fitting, notes, export warnings.

Acceptance:

- Every workflow has deterministic checks.
- Every document-changing action has preview, undo, stale-state rejection, and failure-no-mutation tests.

### Phase 7: Safe AI And Plugin Runtime

Goal: match modern office expectations without sacrificing trust.

Allowed only after policy gates:

- Selected-context only.
- Visible context summary.
- Preview artifacts first.
- Source-linked/clickable evidence for summaries.
- Local/offline default.
- Timeout, cancellation, and failure isolation.
- Admin/user consent for private/cloud providers.

Blocked until separate approval:

- Runtime provider calls.
- Runtime plugin loading.
- Direct document handles for plugins/providers.
- Whole-document cloud payload by default.
- Silent content replacement.

### Phase 8: Packaging, Release, And Distribution

Goal: produce a trustworthy installable product.

Required work:

- `gmake test-install`.
- Signed/notarized macOS app where applicable.
- Release artifact checksum and provenance.
- App icon, bundle metadata, MIME/file association verification.
- Download/install smoke.
- Clean release notes with known limitations.

Acceptance:

- Release artifact can be installed and smoke-tested on a clean profile.
- Source hygiene and beta gates pass or have approved exceptions.

## 6. Immediate Clavue Packets

## 6A. Milestone Execution Plan

### Milestone A: Alpha Stabilization

Purpose: continue development safely without pretending the product is beta-ready.

Exit criteria:

- Source hygiene is classified into explicit buckets.
- `L10N-29` to `L10N-32` are completed or deliberately reprioritized.
- The accumulated localization sweep still passes.
- No new broad generated-output edits are treated as source.
- A current blocker report exists for validator readiness, source hygiene, live accessibility, and packaged UI proof.

Primary owner split:

- Clavue: bounded source localization and small UI remediation packets.
- Codex: gate review, source hygiene classification, acceptance/rejection, next-packet control.

### Milestone B: Beta Candidate

Purpose: make a beta claim honest.

Exit criteria:

- `validator-readiness-strict` passes or has a signed explicit exception.
- `source-hygiene-strict` passes or has a signed explicit exception.
- Live Workbench accessibility evidence exists and blocking findings are fixed.
- Packaged-app screenshots prove claimed Chinese UI fixes in Writer, Calc, Impress, Draw, and Start Center.
- Compatibility reports include representative DOCX/XLSX/PPTX samples and at least seed visual/PDF evidence.
- `gmake test-install` succeeds on the current release candidate tree.

No beta claim is allowed before these are true.

### Milestone C: Release Candidate

Purpose: stop adding broad features and prove stability.

Exit criteria:

- No open P0/P1 user-visible English leaks in high-frequency flows.
- No known data-loss, save/reopen, export, or crash-recovery blockers.
- PDF export checks pass for Chinese documents.
- Accessibility live evidence is clean or all remaining issues are documented non-blockers.
- Performance budgets for launch/open/save/export are measured and not regressing.
- Release notes list known limitations honestly.

Feature freeze rule:

- Only blocker fixes, evidence improvements, localization corrections, and packaging fixes are allowed.
- AI/runtime/provider/plugin expansion is not allowed in RC unless it is already behind a disabled/default-off policy gate.

### Milestone D: Public Release

Purpose: ship a trustworthy installable artifact.

Exit criteria:

- Signed/notarized package where applicable.
- Checksums and artifact provenance recorded.
- Clean install smoke passes.
- Start Center, Writer, Calc, Impress, Draw, and Math launch from installed artifact.
- Basic open/save/export smoke passes on clean profile.
- Download/install documentation is accurate.

## 6B. Workstream Ownership

| Workstream | Primary owner | Reviewer | Notes |
| --- | --- | --- | --- |
| Chinese UI localization | Clavue | Codex | bounded per module/file family; focused checker required |
| Packaged screenshot proof | Clavue | Codex | no source claim accepted without installed-app evidence |
| Source hygiene | Codex | Clavue support | no destructive cleanup without explicit approval |
| Compatibility/PDF lab | Codex for evidence, Clavue for bounded fixes | cross-review | engine edits require failing sample and rollback plan |
| Accessibility | Clavue for manual/live evidence, Codex for gate | cross-review | static checks are not enough |
| Performance/stability | Codex for gates, Clavue for source fixes | cross-review | distinguish crash, timeout, budget miss |
| Writer/Calc/Impress intelligence | Clavue | Codex | preview-first until apply/failure safety is proven |
| AI/provider/plugin runtime | blocked by default | Codex gate | no runtime path before policy acceptance |

## 6C. Global Verification Ladder

Use this order for every significant round:

1. Focused checker for the exact changed surface.
2. XML/schema syntax validation where applicable.
3. Smallest relevant module build.
4. Accumulated sweep or gate wrapper for the changed domain.
5. Packaged-app proof if the round claims user-visible UI behavior.
6. Beta gate rerun only after blockers materially change.

### `L10N-29`: CUI Page Format

Write scope:

- `/Users/lu/kdoffice-src/cui/uiconfig/ui/pageformatpage.ui`
- `/Users/lu/可点office/tmp/localization-sweep/check-l10n-29-cui-page-format.py`
- `/Users/lu/可点office/tmp/localization-sweep/l10n-29-cui-page-format.md`

Gates:

```sh
python3 tmp/localization-sweep/check-l10n-29-cui-page-format.py
xmllint --noout /Users/lu/kdoffice-src/cui/uiconfig/ui/pageformatpage.ui
gmake -C /Users/lu/kdoffice-src cui.build
```

### `L10N-30`: CUI Cell Alignment

Write scope:

- `/Users/lu/kdoffice-src/cui/uiconfig/ui/cellalignment.ui`
- focused checker and evidence doc under `/Users/lu/可点office/tmp/localization-sweep/`

Guardrails:

- Preserve rotation semantics, Asian layout semantics, widget IDs, relations, and adjustment IDs.

### `L10N-31`: Writer TOC/Navigator High-Frequency Lane

Write scope to be proposed by Clavue before edits:

- `sw/uiconfig/swriter/ui/tocindexpage.ui`
- `sw/uiconfig/swriter/ui/tocentriespage.ui`
- `sw/uiconfig/swriter/ui/navigatorcontextmenu.ui`
- `sw/uiconfig/swriter/ui/navigatorpanel.ui`

Guardrails:

- Do not translate internal style IDs, UNO IDs, or command identifiers.
- Preserve compatibility of existing documents and macros.

### `L10N-32`: Calc Filter And Conditional Formatting Lane

Write scope to be proposed by Clavue before edits:

- `sc/uiconfig/scalc/ui/standardfilterdialog.ui`
- `sc/uiconfig/scalc/ui/conditionalentry.ui`
- potentially related Calc filter/condition dialogs only if the lane remains bounded.

Guardrails:

- Preserve formula keywords, function names, operators, and internal condition IDs unless they are explicitly UI labels.

### `BETA-01`: Source Hygiene Classification

Owner: Codex primary, Clavue support after assignment.

Goal:

- Turn dirty-tree chaos into an actionable release list.

Rules:

- No destructive cleanup.
- No broad staging.
- No generated-output deletion without explicit approval.

### `BETA-02`: Packaged Screenshot Proof

Owner: Clavue primary, Codex review.

Goal:

- Produce actual app screenshots for the surfaces already claimed fixed by source/build evidence.

Output:

- `tmp/localization-sweep/m3-04-packaged-verification.md`.
- screenshot folder path.
- pass/fail list.

## 7. Clavue Return Format

Every implementation round must return:

- Verdict: `Keep`, `Revise`, or `Blocked`.
- Packet ID.
- Touched files.
- English leaks fixed.
- English intentionally preserved with reason.
- Commands run and exact results.
- Evidence paths.
- Remaining leaks.
- Stop-rule concerns.

Codex review must reject a round if:

- It edits outside the packet scope.
- It translates IDs, UNO commands, schema nodes, services, or real font names.
- It changes import/export behavior without sample evidence.
- It edits generated outputs as source.
- It claims packaged proof without screenshots/manual evidence.
- It lacks a focused checker for source localization.

## 8. Release Stop Rules

Stop before any beta/release claim if:

- `validator-readiness-strict` fails.
- `source-hygiene-strict` fails without approved exception.
- live accessibility evidence is missing.
- packaged screenshots do not exist for claimed UI fixes.
- compatibility evidence lacks representative visual/PDF proof.
- runtime AI/provider/plugin paths can upload or mutate silently.
- any broad cleanup would delete or revert unrelated local/user work.

## 9. Definition Of World-Class

可圈office can be called world-class only when:

- Chinese users can complete common Writer/Calc/Impress tasks without avoidable English UI.
- Word/WPS-style documents open, roundtrip, export, and print with measured fidelity.
- PDF export is reliable for Chinese documents.
- Accessibility and keyboard operation are proven live.
- Startup/open/save/export performance has budgets and trend evidence.
- Recovery, autosave, undo, and failure handling are trustworthy.
- Intelligent workflows are preview-first, reversible, source-linked, and policy-controlled.
- Release artifacts are clean, signed, verified, and reproducible.

Until then, the product remains in evidence-driven alpha development.
