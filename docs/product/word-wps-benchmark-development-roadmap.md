# Word/WPS Benchmark Development Roadmap

Date: 2026-04-30
Product: 可圈office
Controller/reviewer: Codex
Implementation owner for bounded source rounds: Clavue
Status: not beta-ready; next work is visible-product trust, localization completion, and evidence-backed workflow depth

## Current Upgrade Verdict

可圈office is moving in the right direction, but it is not yet competitive with Word or WPS for normal Chinese office users.

Current evidence:

- `tmp/clavue-passive-monitor-current.md` reports no active office-related Clavue build/test/process descendants, so a new handoff can be issued without interrupting a running office task.
- `tmp/localization-sweep/m3-01-inventory.md` exists and scanned 1,629 files with 59,959 candidate records. It is useful as an inventory, but it is not product completion.
- `tmp/localization-sweep/m3-02-writer.md` reports `Keep` only for the narrow Writer language/status lane. It fixed language-menu strings such as `Set Language for Paragraph` and `None (Do not check spelling)`, but explicitly leaves broader Writer context menus, sidebar labels, dialogs, style display names, Calc, Impress, and packaged-app screenshots open.
- `docs/product/full-ui-localization-sweep-handoff.md` remains active. Its completion definition is not met.
- M3 engine capability docs are strong: source-entry audit, contract fixtures, registry-stub design, and Writer apply guardrails exist. But Writer apply, Calc diagnostics, Workbench evidence console, provider runtime, plugin runtime, and AI mutation paths are still blocked until separate implementation packets are accepted.
- Beta blockers remain: strict validator readiness, strict source hygiene, and live Workbench accessibility evidence.

Conclusion: the next release-quality push must prioritize visible trust and real office workflows before adding broad AI/runtime features.

## Word/WPS User-Demand Signals

This roadmap is grounded in current Word/WPS official feature surfaces and user-review signals checked on 2026-04-30.

| Demand | Word/WPS signal | Product implication for 可圈office |
| --- | --- | --- |
| Professional document trust | Word users expect reliable complex editing, Track Changes, comments, PDF export, accessibility checks, and collaboration/version history. | Compatibility, review markup, PDF output, accessibility, and recovery must become hard evidence areas, not marketing copy. |
| Chinese-first daily usability | WPS wins on familiar UI, low friction, cross-device access, templates, PDF tools, and perceived lightweight use. | Visible English in menus/sidebar/dialogs must be eliminated in high-frequency Chinese workflows before beta. |
| PDF as a first-class workflow | WPS markets PDF edit/convert/sign/OCR/organize/compress/protect and AI PDF summarization; Word documents are commonly exported/shared as PDF. | PDF export confidence, Chinese font embedding, page-count stability, PDF/A/veraPDF readiness, and later PDF summarize/check workflows are P0/P1. |
| AI must be verifiable | Microsoft positions Copilot as draft/rewrite/research help; WPS emphasizes PDF summaries with clickable source verification and no-upload messaging. | AI must be preview-first, source-linked, and policy-controlled. No silent upload, no silent mutation, no unverifiable summaries. |
| Templates and workflow starts matter | WPS heavily promotes templates for resumes, invoices, reports, and business documents. | Chinese domain packs should be expanded around actual work: report, meeting minutes, budget, contract, resume, teaching/courseware, sales proposal. |
| Performance and reliability matter | WPS review pain points include slow load, bugs/crashes, sync failures, Excel limitations, ads, and premium lock-in. Word pain points include heaviness on large documents, formatting complexity, and collaboration confusion. | Opportunity: no ads, offline-first, fast startup, reliable save/reopen, clear feature states, and compatibility diagnostics for complex files. |
| Collaboration is expected but risky | Word supports co-authoring, comments, Track Changes, and version history; co-authoring has file-format/storage limits. | Do not fake cloud collaboration. First prove local comments/tracked-change preservation, version/recovery evidence, and share/export checks. |
| Accessibility is a baseline | Microsoft exposes an Accessibility Checker with categorized issues and recommended actions. | Workbench live accessibility and document accessibility diagnostics must be part of beta trust. |

Reference sources used:

- Microsoft Support: [Copilot in Word](https://support.microsoft.com/en-us/office/welcome-to-copilot-in-word-2135e85f-a467-463b-b2f0-c51a46d625d1), [Word collaboration](https://support.microsoft.com/en-us/office/collaborate-in-word-b3d7f2af-c6e9-46e7-96a7-dabda4423dd7), [real-time co-authoring](https://support.microsoft.com/en-us/office/collaborate-on-word-documents-with-real-time-co-authoring-7dd3040c-3f30-4fdd-bab0-8586492a1f1d), [Track Changes](https://support.microsoft.com/en-us/office/track-changes-in-word-197ba630-0f5f-4a8e-9a77-3712475e806a), [Accessibility tools](https://support.microsoft.com/en-us/office/accessibility-tools-for-word-5fa2c21f-0ef4-4d4a-ae2d-451fb7003518), and [PDF export](https://support.microsoft.com/en-us/office/export-word-document-as-pdf-4e89b30d-9d7d-4866-af77-3af5536b974c).
- WPS official pages: [WPS AI PDF Summarizer](https://www.wps.com/features/ai-pdf-summarizer/feature-ai-pdf-summarizer.html), [WPS PDF Summarizer](https://www.wps.com/feature/pdf-summarizer/), [WPS AI Summarizer](https://www.wps.com/feature/ai-summarizer/), [WPS Office for Windows compatibility](https://www.wps.com/office/windows/), [WPS system requirements/features](https://help.wps.com/articles/system-requirements-for-wps-office), and [WPS resume templates](https://template.wps.com/themes/professional-resumes-214/).
- Review pages: [Microsoft Word on Capterra](https://www.capterra.com/p/227146/Microsoft-Word/reviews/), [Microsoft Word on G2](https://www.g2.com/products/microsoft-word/reviews?qs=pros-and-cons), [WPS Office on Capterra](https://www.capterra.com/p/126794/WPS-Office/reviews/), and [WPS Office on G2](https://www.g2.com/products/wps-office/reviews?qs=pros-and-cons).

## Competitive Strategy

The product should not try to beat Word/WPS by copying every feature immediately. The defensible path is:

1. Chinese-first visible UI and task language.
2. Office/PDF compatibility trust with evidence.
3. Fast offline workflows for common Chinese office documents.
4. Safe document intelligence: diagnose, preview, apply one-by-one, verify, record evidence.
5. AI only when it is source-linked, preview-only by default, and policy-controlled.

The positioning should be: trustworthy Chinese office suite with no ad noise, no silent upload, and visible proof before document-changing actions.

## Development Phases

### Phase A: Visible Chinese Trust

Goal: remove first-minute trust breakers.

Immediate implementation order:

1. Continue M3-02 localization with Writer context/table/dialog lane.
2. Complete M3-03 shared sidebar, Calc, Impress, Draw, and Math visible chrome.
3. Decide style-display-name policy separately: display mapping/localization assets are allowed only if style lookup, macros, DOCX/ODF roundtrip, accelerators, and tests remain safe.
4. Capture packaged-app screenshots for Writer, Calc, Impress, and Start Center.

Clavue next implementation packet:

- Round: `L10N-02B Writer Context/Table/Dialog Chinese Lane`
- Owner: Clavue
- Reviewer: Codex
- Allowed source scope:
  - `/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/WriterCommands.xcu`
  - `/Users/lu/kdoffice-src/officecfg/registry/data/org/openoffice/Office/UI/GenericCommands.xcu`
  - `/Users/lu/kdoffice-src/sw/uiconfig/swriter/ui/tableproperties.ui`
  - `/Users/lu/kdoffice-src/sw/uiconfig/swriter/ui/insertcaption.ui`
  - `/Users/lu/kdoffice-src/cui/uiconfig/ui/pastespecial.ui` only if the lane remains small
  - `/Users/lu/kdoffice-src/cui/uiconfig/ui/splitcellsdialog.ui` only if the lane remains small
- Required targets:
  - `Insert Caption` -> `插入题注`
  - `Table Properties` -> `表格属性`
  - `Paste Special` -> `选择性粘贴`
  - `Properties` -> `属性`
  - common table/context menu labels from the user screenshots
- Explicitly excluded:
  - Style display names such as `Heading 1`, `Text body`, `Default Style`
  - UNO command ids
  - XML ids
  - schema nodes
  - real font names
  - generated build/install outputs
- Required evidence:
  - Update `tmp/localization-sweep/m3-02-writer.md` or create a new `tmp/localization-sweep/l10n-02b-writer-context.md`.
  - List touched files.
  - List fixed strings.
  - List intentionally preserved English with reason.
  - Run smallest relevant build, normally `gmake -C /Users/lu/kdoffice-src officecfg.build sw.build cui.build`.
  - Do not claim packaged UI completion without screenshots.

### Phase B: Beta Hardening And Release Hygiene

Goal: make readiness claims honest.

Required blockers to close:

- Trusted exact Officeotron asset readiness.
- Trusted exact veraPDF asset readiness.
- Strict source hygiene or approved release exception.
- Live Workbench accessibility evidence: Tab, Shift+Tab, Enter, Space, VoiceOver, high contrast, resize, and missing-template fallback.

Codex controls blocker semantics and final gate acceptance. Clavue may implement only bounded packets with exact write scope.

### Phase C: Compatibility Trust Lab

Goal: compete with Word/WPS on “my document survives.”

Next evidence upgrades:

- Expand curated compatibility corpus beyond 27 samples into representative Chinese DOCX/XLSX/PPTX lanes.
- Add true visual/PDF-rendered comparison for at least one DOCX, one XLSX, and one PPTX lane before changing import/export engines.
- Add PDF export confidence: Chinese font embedding, page-count stability, bookmarks/TOC, PDF/A readiness once veraPDF is available.
- Add tracked changes/comments preservation smoke for Writer.
- Add XLSX formula/chart/filter/print-area evidence.
- Add PPTX placeholder/text fitting/audio/media warning evidence before claiming presentation reliability.

No import/export engine edits should start without a failing representative sample and before/after evidence.

### Phase D: Workflow Compression Without Unsafe AI

Goal: turn common work into guided tasks.

Workflow targets:

- Prepare for sharing: document diagnostics, compatibility risks, accessibility risks, PDF export readiness.
- Clean formatting: preview-only first, one-by-one apply later.
- Meeting minutes: action owners, dates, deadlines, follow-up table.
- Business report: TOC, headings, captions, table overflow, PDF readiness.
- Budget/finance: formula errors, hidden rows, print overflow, date/currency inconsistency.
- Presentation draft: normalized outline to editable slides, text fitting, unsupported notes evidence.

Implementation sequencing:

1. Calc read-only diagnostic seed.
2. Deterministic Impress draft expansion with PPTX export evidence.
3. Writer one-by-one apply implementation only after a new accepted source packet, not from the guardrail doc alone.
4. Workbench evidence console states after live accessibility risks are controlled.

### Phase E: AI And Provider Preview Path

Goal: match modern Word/WPS AI expectations without sacrificing trust.

Allowed direction:

- Selected-context only.
- Visible context summary.
- Preview artifacts only.
- Clickable/source-linked evidence where summarizing or rewriting.
- Timeout, cancellation, and failure isolation.
- Local/offline default.
- Private/cloud disabled until consent, service-mode policy, admin controls, auditability, and no-mutation-on-failure tests exist.

Blocked until separate acceptance:

- Runtime provider calls.
- Runtime plugin loading.
- Silent upload.
- Whole-document cloud payload by default.
- Provider/plugin direct document handles.
- Silent replacement of document content.

## Clavue/Codex Operating Protocol

Codex controls product gates and review decisions. Clavue implements bounded source packets.

Before each Clavue implementation round:

- Codex refreshes passive coordination with `bin/clavue-passive-monitor.sh tmp/clavue-passive-monitor-current.md`.
- Codex gives Clavue one narrow packet with write scope, non-goals, commands, and return format.
- Clavue must not edit outside the packet.

During implementation:

- No overlapping Codex source edits in the same file family.
- No broad search/replace across source.
- No generated-output edits as source.
- No destructive cleanup.

After implementation:

- Clavue returns `Keep`, `Revise`, or `Blocked`.
- Codex reviews touched files, evidence, and remaining risks.
- A new round starts only after review.

## Metrics That Matter

| Metric | Target before beta/release claim |
| --- | --- |
| Visible Chinese UI | High-frequency Writer/Calc/Impress/Start Center smoke surfaces show no avoidable English. |
| Packaged evidence | Screenshots/manual observations exist for every claimed visible UI fix. |
| Compatibility | Curated DOCX/XLSX/PPTX corpus passes with validators when available and visual/layout evidence. |
| PDF | Chinese fonts, page count, PDF/A/veraPDF, bookmarks/TOC where relevant. |
| Accessibility | Live keyboard/screen-reader/high-contrast/resize evidence exists. |
| Performance | Launch and large-file operations have timing budgets, not only process survival. |
| Trust | Every document-changing intelligent action has preview, stale-revision rejection, undo, rollback/unchanged failure, and evidence. |
| Privacy | No AI/provider/plugin path can upload or mutate documents silently. |

## Stop Rules

Stop and report `Blocked` before:

- Claiming beta readiness while strict validator readiness, strict source hygiene, or live Workbench accessibility remains open.
- Claiming Chinese UI completion without packaged-app screenshots.
- Translating UNO ids, XML ids, schema nodes, service names, internal identifiers, or real font names.
- Renaming built-in style internals without compatibility tests.
- Implementing Writer apply from the guardrail doc without a separate accepted implementation packet.
- Adding provider/plugin runtime, private/cloud mode, or AI mutation paths.
- Editing import/export engines without a representative failing sample and before/after evidence.
- Running destructive cleanup in the dirty build tree.

## Immediate Decision

Proceed with `L10N-02B Writer Context/Table/Dialog Chinese Lane` as the next Clavue implementation round.

Codex should not open Writer apply, Calc diagnostics, Workbench evidence-console UI, provider runtime, plugin runtime, import/export changes, or broad style-display-name localization until the visible UI blocker and beta hardening lanes are under control.
