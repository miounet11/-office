# Mature Office Productivity Product Model

This document defines what a mature office productivity suite must provide, and maps those requirements back to the current 可圈office V2 work. It is a product analysis artifact, not an implementation patch.

## Current Codex Execution Status

Codex completed the P1-05 local/offline plugin manifest validator lane and the project is now in the M2 next-stage planning/execution transition.

Observed status on 2026-04-28:

- Codex accepted the split: Clavue handled P1-04 and P1-07; Codex handled P1-05 control-plane/plugin work.
- Codex reviewed P1-04 and reported no blocking findings.
- `bin/plugin-manifest-validator.sh --self-test --report tmp/plugin-manifest-validator.md` passes local/offline manifest validation and rejects invalid/provider/unsafe-command/missing-failure-message cases.
- `bin/v2-p0-gates.sh` includes the plugin manifest validator and current dashboard/control-plane reports list P1-05 as verified rather than active.
- `clavue team check` still reports shared native team sessions disabled, so the practical collaboration mode remains written handoffs plus bounded peer review.

Use `docs/product/mature-office-product-requirements.md` for the canonical capability model and `docs/product/next-stage-development-plan.md` for the M2 execution plan.

## Executive Thesis

A mature office production tool is not just a document editor. It is a trust system for creating, editing, exchanging, presenting, printing, recovering, and automating high-value work artifacts.

For 可圈office, the winning product shape is:

1. reliable desktop office core first;
2. China-office scenario entry instead of raw module entry;
3. strong DOCX/XLSX/PPTX compatibility evidence;
4. unified Writer/Calc/Impress interaction logic;
5. AI and plugins only where they compress real office work;
6. offline-first operation with optional local/private/cloud service modes;
7. measurable quality gates before marketing claims.

## 1. Core Functional Capability

### 1.1 Writer

A mature Writer must cover:

- fast blank document creation;
- Chinese business reports, notices, resumes, meeting minutes, contracts, policies, and public-institution style documents;
- stable styles, headings, lists, tables, images, headers/footers, page numbering, footnotes/endnotes, references, comments, and tracked changes;
- reliable DOCX/ODT/PDF import/export;
- review workflows: comments, revisions, compare, accept/reject, protected sections;
- template-driven creation for high-frequency local office scenarios;
- diagnostics for readability, formatting consistency, missing headings, long paragraphs, mixed fonts, and export risk.

Current project alignment:

- P1-04 implemented the first preview-only Writer diagnostic analyzer.
- The current analyzer is intentionally small: a long-paragraph read-only diagnostic. This is correct for alpha because it proves the safety boundary first.
- The next Writer maturity step is not broad AI writing; it is richer preview diagnostics with unchanged modified state and stable repeated results.

### 1.2 Calc

A mature Calc must cover:

- fast opening and editing of medium/large spreadsheets;
- formulas, named ranges, tables, filters, sorting, conditional formatting, charts, pivot-style analysis, validation, comments, and protected sheets;
- XLS/XLSX/ODS round-trip fidelity;
- Chinese workplace templates: budgets, reimbursement sheets, sales trackers, project schedules, inventory, attendance, KPI tables;
- formula explanation, error diagnosis, range cleanup, and chart suggestion as assisted workflows;
- safe recalculation and no silent formula corruption.

Current project gap:

- Calc is present as a full LibreOffice-derived module, but current V2 evidence is mostly compatibility smoke and scenario templates.
- Mature-product proof still needs Calc-specific workflow gates: formula fidelity, chart fidelity, conditional formatting, large-sheet performance, and XLSX round-trip tests.

### 1.3 Impress

A mature Impress must cover:

- editable decks, master pages, themes, layouts, placeholders, notes, transitions, animations, media, charts, tables, and exports;
- PPTX/ODP/PDF round-trip and display fidelity;
- Chinese business report decks, teaching courseware, project summaries, pitch decks, defense decks, and training materials;
- deterministic outline-to-deck and draft-generation flows that preserve editability.

Current project alignment:

- P1-07 added a normalized presentation-outline schema and fixtures.
- This is the correct first step because it defines title, ordered slides, sections, bullets, notes, source references, and editable placeholder intent before touching Impress builders.
- The mature next step is an Impress-side builder that creates editable placeholders from the normalized model, while preserving the legacy `.uno:SendOutlineToStarImpress` RTF path.

## 2. Compatibility and Interchange Capability

For an office suite, compatibility is a product moat, not a slogan.

A mature product needs:

- curated DOCX/XLSX/PPTX regression corpus;
- scenario tags for every test document;
- import, edit, save, reopen, export, and PDF validation loops;
- visual/layout comparison for representative files;
- external validators where available;
- explicit handling of skipped validators as blockers, not passes;
- separate alpha, beta, and release gates.

Minimum compatibility lanes:

| Lane | Examples | Required Evidence |
| --- | --- | --- |
| Writer DOCX | pagination, tables, floating objects, comments, tracked changes | round-trip plus layout/content checks |
| Calc XLSX | formulas, charts, conditional formatting, filters, pivots | formula result and chart fidelity checks |
| Impress PPTX | themes, text boxes, grouped shapes, charts, animations | visual/layout and export checks |
| PDF | print/export correctness, fonts, links | rendered output and validator checks |
| ODF | native fidelity and recovery | open/save/reopen and validator checks |

Current project alignment:

- A curated 27-sample manifest exists and passes conversion smoke.
- Fidelity heuristics exist, but they are advisory.
- Validator assets remain missing and must stay beta blockers.
- Mature status requires larger representative corpus coverage and screenshot/layout comparison, especially for PPTX and complex DOCX.

## 3. Stability, Reliability, and Data Trust

A mature office product must protect user work under bad conditions.

Required capabilities:

- crash-free common editing sessions;
- repeated open/save/export loops without corruption;
- autosave and recovery that preserve recent edits;
- undo/redo correctness across formatting, insertion, deletion, tables, slides, and charts;
- robust behavior with large files, damaged files, missing fonts, missing linked images, locked files, network paths, and permission failures;
- no silent data loss;
- clear error messages when an operation cannot be completed.

Core gates:

- save/reopen correctness;
- export/print/PDF consistency;
- recovery success;
- long-session memory/resource stability;
- startup/open/close timing and crash-free rate.

Current project gap:

- Fresh-profile GUI launch smoke proves process survival, not usability or long-session stability.
- Mature-product verification needs repeated editing loops, recovery tests, and output comparisons.

## 4. Performance Capability

Performance must be measured by user-visible workflows, not only raw build speed.

### 4.1 Startup and First Useful Action

A mature product should feel ready quickly:

- cold start to home/workbench;
- warm start;
- open recent file;
- create blank Writer/Calc/Impress document;
- open a template;
- first keystroke latency.

Required gates:

- timing budgets per mode;
- regression thresholds;
- fresh-profile and existing-profile measurements;
- measurement on representative macOS hardware.

Current project gap:

- `bin/gui-smoke-timing.sh` exists and proves launch survival.
- It needs explicit timing budgets and regression failure thresholds before beta.

### 4.2 Editing Responsiveness

Mature editing must stay responsive for:

- large Writer documents with images/tables/comments;
- large Calc spreadsheets with formulas/charts;
- large PPT decks with images/themes;
- scrolling, selection, typing, undo, save, export, and print preview.

Performance dimensions:

- input latency;
- scroll latency;
- save/export duration;
- memory growth;
- CPU spikes;
- background task interference.

### 4.3 Compatibility Performance

Compatibility is also performance:

- large DOCX/PPTX files must open without long hangs;
- large intermediate ODP/ODT expansion must be flagged;
- export should not explode file size unexpectedly;
- embedded fonts/images/charts need clear resource budgets.

Current evidence:

- The compatibility report already surfaced a useful embedded-font PPTX expansion signal. This should become a tracked performance/fidelity metric.

## 5. Interaction Logic and Product Experience

A mature office suite must reduce user decision cost.

### 5.1 Task-First Workbench

The home surface should answer: “What work are you trying to finish?”

Required workbench entries:

- blank document/spreadsheet/presentation;
- weekly report;
- meeting minutes;
- resume;
- formal notice/document;
- budget sheet;
- sales tracker;
- project schedule;
- work report PPT;
- teaching courseware;
- PPT draft from outline;
- open local file;
- recent documents;
- template center;
- compatibility-safe open.

Good interaction logic:

- primary tasks visible immediately;
- blank creation still available;
- recent files not hidden;
- advanced modules do not dominate the first screen;
- failed templates fall back clearly;
- keyboard navigation and screen-reader labels work.

Current alignment:

- Workbench scenario templates and smoke checks exist.
- Manual VoiceOver, resize, high-contrast, and full keyboard traversal remain beta debt.

### 5.2 Unified Command Model

Writer, Calc, and Impress should feel like one suite.

Recommended top-level taxonomy:

1. Home
2. Insert
3. Layout
4. Review
5. View
6. Template
7. Export / Share
8. AI / Assist
9. Advanced

Maturity requirements:

- same command names for same concepts;
- same placement for common actions;
- module-specific actions grouped predictably;
- low-frequency inherited functions moved out of the default path;
- consistent Chinese naming and shortcut logic.

Current gap:

- The project has evidence that a tabbed/default policy exists, but a full cross-suite command taxonomy is not yet implemented as a hard product contract.

### 5.3 Error and Failure Interaction

Mature software must fail safely.

Required behavior:

- failed AI/plugin calls do not mutate documents;
- failed save/export explains recovery options;
- missing validator/plugin assets are reported as missing, not passed;
- import warnings distinguish fidelity risk from fatal failure;
- all risky operations have undo or preview first.

Current alignment:

- Plugin manifest schema and validator work are moving toward this.
- P1-04 and P1-07 correctly use preview/fixture-first sequencing.

## 6. AI, Diagnostics, and Plugin Capability

AI should be workflow compression, not a generic chatbot.

Mature assisted workflows:

- Writer: summarize, rewrite, polish, check tone, generate outline, diagnose formatting, convert meeting notes to minutes.
- Calc: explain formulas, detect anomalies, clean ranges, suggest charts, build formulas from intent.
- Impress: generate outline, map outline to editable slides, create speaker notes, suggest structure and layout.
- Cross-suite: turn document into PPT, spreadsheet into chart deck, meeting transcript into tasks.

Safety requirements:

- offline/local/private/cloud capability modes;
- explicit user consent for document context;
- no document mutation on failed calls;
- preview before apply;
- undo grouping for apply;
- plugin manifests validate capabilities, modules, network mode, privacy, entrypoints, and failure behavior;
- deterministic fixtures before runtime loaders.

Current alignment:

- P1-04 established preview-only Writer diagnostics.
- P1-05 established local/offline plugin manifest validation and is integrated into the control plane.
- P1-07 established a deterministic presentation-outline contract fixture.
- Runtime plugin loader and actual Impress builder are intentionally not implemented yet.

## 7. Offline, Local, Private, and Cloud Modes

A mature office product should not force public cloud dependency.

Recommended capability modes:

| Mode | Meaning | Examples |
| --- | --- | --- |
| Offline | no network required | editing, templates, local diagnostics |
| Local | local services only | local model, local OCR, local validator |
| Private | enterprise-controlled endpoint | private AI, private template server |
| Cloud | vendor-hosted service | sync, cloud AI, collaboration |

Rules:

- core editing works offline;
- AI/provider failures never corrupt documents;
- user consent is required before sending document context;
- service features degrade gracefully;
- enterprise/private deployment must be possible without rewriting desktop UX.

## 8. Accessibility and Internationalization

Maturity requires access for more users and more environments.

Required capabilities:

- keyboard-only task completion;
- VoiceOver/screen-reader labels on custom workbench surfaces;
- high-contrast and dark/light theme behavior;
- resize and small-screen behavior;
- Chinese-first copy with consistent terminology;
- font fallback and blank-document defaults appropriate for Chinese office work;
- no invisible controls or dead-end focus traps.

Current alignment:

- Static Workbench accessibility check exists.
- Manual assistive-technology evidence remains required before beta.

## 9. Release, Packaging, and Operations

A mature product needs a dependable delivery system.

Required capabilities:

- clean source/generated boundary;
- repeatable builds;
- signed and runnable app bundle;
- update policy;
- release notes tied to verified gates;
- crash/log collection policy if services exist;
- strict beta/release gate promotion.

Current gap:

- The working tree has large generated/local noise.
- Source-focused reports exist, but release candidates need stricter hygiene and explicit packaging verification.

## 10. Maturity Scorecard for 可圈office

| Capability Area | Current Direction | Maturity Gap | Next Evidence Needed |
| --- | --- | --- | --- |
| Core editing | Full LibreOffice-derived core exists | product-specific trust gates are incomplete | repeated save/reopen/export/recovery loops |
| Workbench | scenario templates and smoke exist | manual GUI/a11y proof still missing | keyboard/VoiceOver/resize/high-contrast review |
| Compatibility | curated 27-sample manifest passes | corpus is not representative enough | expanded corpus and visual/layout comparison |
| Writer diagnostics | first preview analyzer implemented | only one conservative rule | more read-only diagnostics plus full contract equality tests |
| Calc intelligence | mostly roadmap-level | no Calc diagnostic lane yet | formula/chart/range diagnostics fixtures |
| PPT generation | normalized outline fixture exists | no builder/runtime | editable Impress deck builder from normalized model |
| Plugin safety | P1-05 manifest validator verified | runtime loader absent | offline/private/cloud service policy before loader work |
| Performance | launch smoke exists | no budgets or thresholds | startup/open/save/export timing budgets |
| Accessibility | static checks exist | manual evidence missing | VoiceOver/keyboard/high-contrast test packet |
| Release hygiene | source-status tooling exists | generated noise remains large | strict release-mode source hygiene gate |

## 11. Recommended Next Execution Order

1. Review and lock the P1-07 presentation-outline schema fixture before any Impress builder work.
2. Define China blank-document defaults for Writer, Calc, and Impress before config/module edits.
3. Add timing budgets to GUI smoke instead of only survival checks.
4. Harden P1-04 Writer analyzer tests to compare the full diagnostic contract and both modified/unmodified initial states.
5. Add a visual/layout comparison seed for one DOCX, one XLSX, and one PPTX compatibility sample.
6. Add a manual Workbench accessibility evidence packet.
7. Design the first deterministic Impress builder from `presentation-outline.schema.json`, keeping legacy `.uno:SendOutlineToStarImpress` untouched.
8. Add offline/local/private/cloud service policy before plugin runtime loading.
9. Promote missing validators, accessibility evidence, selected timing budgets, and source hygiene from advisory to beta-hard gates.

## 12. Non-Negotiable Product Rules

- Do not ship AI that can corrupt documents.
- Do not claim compatibility without representative evidence.
- Do not count skipped validators as passes.
- Do not make Start Center prettier while leaving task entry confusing.
- Do not replace mature LibreOffice edit/save/export paths without a failing sample and a rollback plan.
- Do not let plugins or services become mandatory for basic office work.
- Do not accept process-alive GUI smoke as proof of usability.

## Conclusion

A mature office suite is measured by trust under real work pressure. For 可圈office, the fastest credible path is not broad feature expansion. It is a sequence of bounded, verified upgrades: scenario-first entry, compatibility evidence, read-only diagnostics, deterministic PPT generation contracts, plugin safety, performance budgets, and strict release hygiene.

The current project is moving in the right direction. It has strong control-plane momentum and early intelligent-office contracts. It is not beta-mature yet because validators, representative compatibility, accessibility evidence, performance budgets, and runtime intelligent features still need hard proof.
