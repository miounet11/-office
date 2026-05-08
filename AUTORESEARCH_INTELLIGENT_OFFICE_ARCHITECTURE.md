# 可圈office Intelligent Office Architecture

This document turns the next product goal into an executable architecture: one-click formatting, intelligent document diagnostics, and plugin-mounted AI/translation features. The rule is that intelligence must improve real documents while preserving open/edit/save/export trust.

## North Star

可圈office should feel like a Chinese-first office copilot embedded inside a reliable desktop suite. Users should be able to open a messy document, understand what is wrong, fix formatting safely, and add optional AI or translation capabilities without making core editing depend on cloud services.

## Product Pillars

### 1. One-Click Formatting

Goal: turn common Chinese office documents into clean, readable, consistent output with one visible action.

First workflows:

- Writer: normalize headings, body text, line spacing, paragraph spacing, Chinese punctuation spacing, page margins, tables, captions, and list numbering.
- Calc: normalize header rows, column widths, number/date formats, frozen panes, table borders, conditional emphasis, and print area.
- Impress: normalize title/body hierarchy, alignment, spacing rhythm, theme colors, slide margins, and speaker-note structure.

Safety contract:

- Always preview the change list before applying broad changes.
- Apply via undoable document operations.
- Never silently delete user content.
- Keep a "restore previous formatting" path through normal undo.

### 2. Intelligent Diagnostics

Goal: explain document problems in Chinese and turn them into fixable actions.

Diagnostic categories:

- Content: typos, repeated text, missing titles, unclear section hierarchy, inconsistent terminology.
- Formatting: mixed fonts, chaotic spacing, broken numbering, weak tables, oversized images, bad slide alignment.
- Compatibility: risky DOCX/XLSX/PPTX elements, missing fonts, unsupported effects, suspicious layout changes after round-trip.
- Export: PDF readability, page overflow, print margin risk, accessibility warnings.

Each diagnostic should produce:

- a short Chinese message
- affected location
- severity: `提示`, `建议`, `警告`, `阻塞`
- action: `修复`, `忽略`, `查看详情`
- verification evidence if the issue is compatibility or export-related

### 3. Plugin-Mounted Capabilities

Goal: make AI, translation, template packs, and industry workflows mountable without hardwiring every feature into the editor core.

Plugin classes:

- AI providers: rewrite, summarize, classify, translate, generate outline, explain formula.
- Document transformers: one-click formatting packs, style packs, export checks.
- Template packs: industry/role-specific Writer, Calc, and Impress starters.
- Connectors: private knowledge base, local model, enterprise translation endpoint, cloud storage.

Rules:

- Core editor remains useful when every plugin is disabled.
- Plugins declare capability, scope, network requirement, privacy mode, and failure behavior.
- External AI calls require explicit user action and must not mutate documents on failure.
- Plugin output enters the document as editable content or a previewable patch.

## Repo-Mapped Architecture

| Layer | Purpose | Current Surfaces |
| --- | --- | --- |
| Command entry | expose actions consistently | `officecfg/registry/data/org/openoffice/Office/UI/*.xcu`, module `uiconfig` trees |
| Dispatch/extension | mount plugin actions | `officecfg/registry/data/org/openoffice/Office/Addons.xcu`, `ProtocolHandler.xcu`, `framework/`, `scripting/`, `extensions/` |
| Dialog/workbench | show task cards, diagnostics, previews | `sfx2/source/dialog/backingwindow.cxx`, `cui/`, `svx/`, module dialogs |
| Formatting engines | apply safe transformations | `sw/`, `sc/`, `sd/`, `editeng/`, `svx/` |
| Proofing/diagnostics | text, style, accessibility checks | `lingucomponent/`, `editeng/`, `svx` accessibility check surfaces |
| Compatibility evidence | verify document safety | `bin/compatibility-roundtrip.sh`, validator wrappers, module `qa` trees |

## Development TODO

### P0: Control Plane

- Add a readiness report for intelligent-office surfaces.
- Define diagnostic schema and user-facing Chinese severity vocabulary.
- Define plugin manifest fields before implementing provider code.
- Keep all new checks advisory until they have stable samples and tests.

### P1: Formatting MVP

- Implement Writer one-click formatting as the first workflow.
- Start with a preview-only analyzer: headings, body font, spacing, lists, tables.
- Add an undoable apply path only after analyzer output is stable.
- Create sample documents and expected diagnostic reports.

### P2: Diagnostics MVP

- Add a document quality panel or dialog that groups issues by severity.
- Wire "fix one issue" before "fix all".
- Add compatibility/export diagnostics based on round-trip and validator evidence.

### P3: Plugin MVP

- Define `kqoffice-plugin.json` with capability, module scope, network mode, privacy mode, commands, and entry points.
- Support local/offline plugins first: formatting pack, template pack, translation stub.
- Add AI provider plugins only after privacy, failure, and editable-output rules are enforced.

## Acceptance Gates

- One-click formatting produces a readable before/after report and is fully undoable.
- Diagnostics are actionable in Chinese and never overpromise unsupported fixes.
- Plugin-disabled mode remains fully usable for core office work.
- AI/translation plugins never modify the document when the provider call fails.
- Compatibility smoke and source hygiene reports are attached to every intelligent-office round.

## Next Implementation Split

- Codex: maintain control-plane docs, readiness tooling, dashboard integration, and first analyzer scaffolds.
- Clavue: review source surfaces, find smallest safe Writer formatting insertion points, and audit plugin/extension risk.
- Shared: compare findings before touching `sw/`, `sc/`, `sd`, `oox`, `xmloff`, or `filter` internals.
