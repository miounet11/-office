# Mature Office Product Requirements

Generated from the current 可圈office workspace on 2026-04-28.

## Current Clavue Execution Status

Local status is active but not fully coordinated through native team sessions.

- Several `clavue` CLI sessions are running locally, and one `npm install clavue` process was active during inspection.
- `clavue team check` still reports agent teams disabled and native tool-calling validation failed.
- Practical coordination should therefore remain written handoffs plus bounded review, not shared-session automation.
- Clavue handoffs recorded in the active todolist say P1-04 Writer preview analyzer is done and locally validated.
- Clavue handoffs also say P1-07 normalized PPT outline schema fixture is done and locally validated.
- Codex completed P1-05 local/offline plugin manifest validator and integrated it into the control plane.

Current implication: Clavue is productive as an independent lane owner, but direct Clavue team-session orchestration is not reliable enough to be treated as a gate.

## Product Thesis

A mature office production tool is not only an editor. It is a trust system for creating, reviewing, exchanging, presenting, exporting, recovering, and automating business documents.

For 可圈office, the target should be:

- Reliable desktop office core first.
- China-office scenario-first task entry.
- High-confidence DOCX/XLSX/PPTX compatibility.
- Consistent Writer, Calc, and Impress interaction logic.
- Intelligent features that compress real workflows without weakening offline usefulness.
- Plugin and AI capabilities mounted through explicit safety, privacy, and failure contracts.

The maturity test is simple: a user should trust the product for important work even when AI, plugins, and cloud services are disabled.

## Capability Model

### 1. Core Document Trust

Required capabilities:

- Open, edit, save, reopen, export, print, and recover documents reliably.
- Preserve content, formatting, comments, tracked changes, formulas, charts, images, styles, notes, and document metadata.
- Provide dependable undo/redo for every user-visible edit.
- Support autosave, recovery, version restore, and crash-safe temporary files.
- Make read-only, locked, external, damaged, or partially unsupported files obvious before the user loses work.

Current project state:

- The core LibreOffice-style engine gives strong baseline editing capability.
- Current control-plane reports still need stronger recovery, save/reopen, and output-trust gates.

### 2. Compatibility Lab

Required capabilities:

- Treat DOCX/XLSX/PPTX fidelity as a release gate, not a slogan.
- Maintain golden Chinese workplace sample packs for Writer, Calc, and Impress.
- Measure round-trip conversion, visual fidelity, structural integrity, package size, validator status, and known-risk features.
- Validate ODF/PDF outputs with real validator assets when available.
- Track defect classes: pagination drift, table breakage, formula changes, chart changes, theme drift, font fallback, comments, tracked changes, animations, media, and embedded objects.

Current project state:

- Curated 27-sample compatibility smoke exists and passes conversion.
- The dashboard sees 6,194 QA compatibility samples.
- External validator assets remain missing, so validator-backed conformance is still beta-blocked.
- Visual/screenshot fidelity scoring is still missing.

### 3. Writer Production Depth

Required capabilities:

- Styles, headings, outline, TOC, page layout, headers/footers, tables, captions, comments, tracked changes, mail merge, citations, fields, lists, and templates.
- Chinese business writing helpers: weekly reports, meeting minutes, resumes, notices, official-style documents, contracts, and DOCX collaboration review.
- Intelligent diagnostics for heading hierarchy, mixed fonts, spacing, numbering, tables, accessibility, export risk, and compatibility risk.
- One-click formatting must always start with preview and must apply through undoable operations.

Current project state:

- First Writer preview-only analyzer exists.
- Apply/fix path is not implemented yet and should not be added until full preview diagnostics and undo grouping are proven.

### 4. Calc Production Depth

Required capabilities:

- Formula compatibility, large-sheet responsiveness, filtering, sorting, pivot tables, charts, conditional formatting, data validation, print areas, freeze panes, CSV import/export, and XLSX round-trip fidelity.
- Scenario templates for budget, sales tracking, project schedule, inventory, attendance, and financial summaries.
- Diagnostics for formula errors, suspicious ranges, hidden rows/columns, print overflow, chart data drift, and compatibility-risk functions.

Current project state:

- Compatibility sample inventory exists.
- Mature Calc-specific diagnostics and performance budgets are not yet defined.

### 5. Impress Production Depth

Required capabilities:

- Theme/master slide stability, editable placeholders, layouts, presenter notes, media, animation, transitions, export, and PPTX fidelity.
- Scenario workflows for work-report PPT, teaching PPT, business proposal, project review, and outline-to-slides.
- Deterministic PPT generation should use a normalized model before any UI command or AI generation.

Current project state:

- P1-07 normalized presentation outline schema fixture exists.
- A first internal/test-only Impress builder seed exists under Clavue's M2-07 work and creates editable title/body content in unit tests.
- Codex review accepted the speaker-notes unsupported diagnostic assertion before marking M2-07 done.
- No UI command, AI/provider path, PPTX export change, or legacy `SendOutlineToStarImpress` replacement should be added until the internal builder contract is accepted.

### 6. Scenario Workbench

Required capabilities:

- Launch surface should answer "what do you want to do?" before "which module do you want?"
- Top scenarios should be one click away, while blank Writer/Calc/Impress and recent files remain obvious.
- Templates must be ranked by real tasks, not only file type.
- First-run state should be calm, fast, and useful offline.

Current project state:

- Scenario templates and Start Center evidence exist.
- Manual and behavioral checks still need stronger keyboard, high-contrast, resize, VoiceOver, and click-dispatch proof.

### 7. Unified Interaction Logic

Required capabilities:

- One cross-suite command model across Writer, Calc, and Impress.
- Stable locations for Home, Insert, Layout, Review, View, Template, Export/Share, AI, and Advanced.
- Global command search or command palette for deep functionality.
- Context-aware side panels without hiding basic commands.
- Preview before destructive or broad operations.
- Every long operation should show progress, cancellation, and recoverable failure.

Interaction principles:

- Scenario-first, module-second.
- Common tasks visible; rare tasks progressively disclosed.
- AI suggestions are advisory until explicitly accepted.
- Do not surprise users with document mutation.
- Keep "open existing file" and "blank document" routes always visible.
- Use Chinese-facing explanations for diagnostics, failure states, and privacy choices.

### 8. Intelligent Office Layer

Required capabilities:

- Diagnostic contract: stable id, module, severity, Chinese title/message, location, actions, and evidence.
- One-click formatting: preview, diff summary, single-fix apply, undo grouping, and no silent deletion.
- Compatibility/export diagnostics from round-trip and validator evidence.
- PPT draft generation from normalized outline data into editable slides.
- AI writing, translation, summarization, formula explanation, and slide generation as optional workflow accelerators.

Safety requirements:

- Offline mode must remain fully usable.
- AI/provider failure must not mutate documents.
- External calls require explicit user action and visible context scope.
- Generated output must enter as preview or editable insertion, not hidden replacement.

Current project state:

- Diagnostic schema, plugin schema, presentation-outline schema, contract fixtures, plugin manifest validator, and Writer preview analyzer exist.
- Runtime plugin loader, diagnostic UI, apply path, and AI provider path are not implemented yet.

### 9. Plugin Platform

Required capabilities:

- Local/offline plugin manifests before arbitrary plugin execution.
- Capability declaration, module scope, network mode, privacy mode, entrypoints, failure behavior, and update/signing policy.
- Clear service modes: offline, local, private, cloud.
- Disable-all-plugins mode must preserve core editing.
- Plugin outputs must be previewable and undoable.

Current project state:

- Local/offline plugin manifest validator exists and is wired into the P0 gate wrapper.
- `docs/product/service-mode-policy.md` defines offline/local/private/cloud boundaries before runtime/provider work.
- Runtime discovery/loading and signed distribution policy are future work.

### 10. Performance and Responsiveness

Required capabilities:

- Fast cold launch, warm launch, blank document creation, document open, save, export, and close.
- Smooth typing, scrolling, selection, undo, spellcheck, layout, and sidebar interactions.
- Incremental layout and background operations for large documents.
- Memory ceilings for long sessions and large Office files.
- Cancelable conversions/exports and clear progress states.

Initial performance budget targets:

- Cold launch to Start Center: target under 3 seconds, beta gate under 5 seconds on the reference Mac.
- Warm launch to Start Center: target under 1.5 seconds.
- Blank Writer/Calc/Impress creation: target under 1 second after Start Center.
- Common DOCX/XLSX/PPTX open: target under 3 seconds for normal business files.
- Large file open/export: must show progress within 1 second and remain cancelable.
- Main UI responsiveness: avoid visible blocking during background diagnostics, plugin validation, and compatibility checks.
- Long-running compatibility or AI operations: never block core editing without explicit modal reason.

Current project state:

- GUI timing smoke proves process survival, not full responsiveness.
- Timing thresholds should be added before claiming performance maturity.

### 11. Accessibility and Localization

Required capabilities:

- Full keyboard navigation for Start Center, menus, dialogs, sidebars, and document surfaces.
- Screen reader labels, focus order, high contrast, scalable fonts, and robust resize behavior.
- Chinese-first terminology, templates, examples, and failure messages.
- Correct Chinese font fallback and typography behavior.

Current project state:

- Static Workbench accessibility gate exists.
- M2-06 evidence packet exists and the Workbench UITest smoke passes.
- Live VoiceOver, resize, high-contrast, keyboard traversal, Enter/Space activation, and fallback behavior remain beta debt.

### 12. Enterprise, Security, and Governance

Required capabilities:

- Admin deployment, update control, policy configuration, plugin allowlist, macro policy, certificate/signature handling, encryption, redaction, and privacy controls.
- Private/local service deployment for AI and translation.
- Optional crash reporting with privacy review.
- Clear release channels: alpha, beta, release candidate, stable.

Current project state:

- Release hygiene is not yet mature because generated/local dirty output is large.
- Source-focused status helps, but strict release hygiene should become a beta/release gate.

## Maturity Scorecard

| Area | Current State | Mature Target |
| --- | --- | --- |
| Core editing | Strong inherited baseline | Measured save/reopen/export/recovery trust |
| Compatibility | Curated conversion smoke | Golden corpus plus visual and validator gates |
| Workbench | Scenario surface exists | Behavior, accessibility, and timing proven |
| Unified UX | Partly planned | Cross-suite command model with predictable task flow |
| Writer intelligence | Preview analyzer exists | Full diagnostics plus undoable one-by-one fixes |
| PPT generation | Schema fixture exists | Deterministic editable deck builder |
| Plugin system | Manifest validator exists | Safe loader, policy, signing, local/private/cloud modes |
| Performance | Process timing smoke | Budgeted launch/open/save/export responsiveness gates |
| Accessibility | Static checklist | Manual and automated assistive-tech evidence |
| Release hygiene | Source-focused reporting | Strict source/generated separation before beta |

## Next Development Stage Execution Plan

The canonical execution plan for the next stage is `docs/product/next-stage-development-plan.md`. It translates this capability model into M2 rounds with owners, reviewers, guardrails, verification commands, and exit criteria.

M2 priorities:

1. Review and lock the P1-07 presentation-outline schema fixture before any Impress builder work.
2. Define China blank-document default policy as behavior requirements before config edits.
3. Add GUI timing budget thresholds to convert process-survival smoke into performance evidence.
4. Strengthen Writer analyzer tests to compare full diagnostic stability and both modified-state cases.
5. Add visual or layout comparison for one DOCX, one XLSX, and one PPTX compatibility sample.
6. Run manual Workbench accessibility review and store the result as durable evidence.
7. Finish the internal presentation outline builder revision, preserving the legacy Writer-to-Impress path and explicitly testing unsupported speaker notes.
8. Enforce the offline/local/private/cloud service policy before plugin runtime loading.
9. Install or document validator assets so ODF/PDF conformance can become a beta-hard gate.
10. Promote source hygiene, selected timing budgets, validator readiness, compatibility evidence, and accessibility evidence from advisory to strict only for beta/release candidate branches.

## Acceptance Bar For A Mature Release

可圈office should not be called mature until these are true:

- Common Chinese office workflows are faster from launch than module-first LibreOffice behavior.
- DOCX/XLSX/PPTX compatibility is measured with a representative corpus and known defect taxonomy.
- Core operations have explicit save/reopen/export/recovery proof.
- Startup and common document operations meet published local performance budgets.
- Workbench and key dialogs pass keyboard, high-contrast, resize, and screen-reader checks.
- Intelligent formatting is previewed, undoable, and never silently destructive.
- Plugin and AI features are optional, policy-bound, and failure-safe.
- Generated build output is separated from source review and release packaging.
