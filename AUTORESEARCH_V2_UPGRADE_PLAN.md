# 可圈office V2 Upgrade Plan

This document consolidates the current project state into a V2 execution plan. It assumes V1 already has the foundation of a usable branded desktop office suite, and upgrades the product toward higher efficiency, stronger trust, and AI-assisted workflows without destabilizing the core editor.

## Executive thesis

V2 should not be "add a chat window to LibreOffice." V2 should turn 可圈office into a task-first, compatibility-trustworthy, AI-assisted office product.

The winning direction is:

1. keep the desktop core reliable
2. make launch and document creation scenario-first
3. lock a unified command model across Writer, Calc, and Impress
4. make Office-format compatibility measurable and release-gated
5. add AI only where it shortens real office workflows
6. prepare service/private-deployment architecture without forcing cloud dependency

The product goal is "基础办公可信 + 高频任务更快 + AI 明显省时间".

## Current project diagnosis

### What is already in place

- A configured macOS 可圈office build tree exists with generated build and install outputs.
- Product direction is already established as premium, business, calm, and non-disruptive to office workflows.
- The V1/V2/V3 high-level route already exists: V1 core MVP, V2 AI enhancement, V3 domestic/industry expansion.
- A world-class quality roadmap already defines the operating loop around compatibility, stability, interaction logic, and reliability.
- Product audit work already identified the structural gaps: workbench, unified command model, scenario templates, PPT generation, service layer, Chinese defaults, compatibility engineering, and surface pruning.
- Baseline tools already exist:
  - `bin/quality-baseline.sh`
  - `bin/compatibility-lab.sh`
  - `bin/compatibility-roundtrip.sh`

### What is still blocking a strong V2

The main blockers are no longer simple branding or translation tasks. The current bottlenecks are structural:

1. **Start experience** still needs to become a full workbench, not just a better Start Center.
2. **Command model** still risks feeling like three inherited applications instead of one suite.
3. **Templates** need scenario ranking, not only category browsing.
4. **Compatibility** must become a measurable product gate, not a marketing claim.
5. **AI** needs workflow integration with document context, not a disconnected assistant.
6. **Build/release efficiency** needs faster, repeatable verification lanes.
7. **Service architecture** needs clear offline/private/cloud modes before V3 industry deployment.

## V2 north-star outcomes

V2 succeeds when a user can:

- open and round-trip common DOCX/XLSX/PPTX files with visibly lower risk
- launch the app and start a real Chinese office task quickly
- move between Writer, Calc, and Impress without relearning the UI
- use AI to produce or improve concrete office artifacts, not just chat
- export, print, recover, and save with high confidence
- install and run the product through a repeatable release pipeline

## V2 operating principles

### 1. Trust before novelty

AI and new UX cannot break editing, saving, exporting, printing, recovery, or compatibility. Every V2 feature must preserve core document trust.

### 2. Scenario-first, module-second

The product should lead with tasks such as weekly report, meeting minutes, budget sheet, project schedule, business report deck, teaching courseware, and PPT draft generation. Writer/Calc/Impress remain available, but user intent comes first.

### 3. AI as workflow compression

AI is accepted only when it reduces steps in a real workflow:

- draft this report
- summarize this document
- rewrite this paragraph
- generate formulas
- explain spreadsheet errors
- turn outline into slides
- create speaker notes
- clean formatting
- prepare export/share copy

### 4. Compatibility is a lab, not a slogan

DOCX/XLSX/PPTX regressions must be collected, scored, and used as release gates. Compatibility work should prioritize high-frequency Chinese workplace documents.

### 5. Keep offline mode first-class

V2 may introduce AI and services, but the desktop suite must remain clean and useful without account login or public cloud access.

## V2 program architecture

## Program A — V2 quality and efficiency control tower

### Goal

Create the permanent measurement system for V2 execution.

### Scope

- Convert existing baseline scripts into the mandatory round entry point.
- Create one V2 dashboard report that combines:
  - build state
  - compatibility sample inventory
  - round-trip smoke results
  - target workflow coverage
  - open blockers
- Define acceptance gates per round.

### Key artifacts

- `bin/quality-baseline.sh`
- `bin/compatibility-lab.sh`
- `bin/compatibility-roundtrip.sh`
- `tmp/world-class-quality-baseline.md`
- `tmp/compatibility-lab-baseline.md`
- future: `tmp/v2-upgrade-dashboard.md`

### Acceptance gates

- Every V2 round declares one target workflow, one metric, and one verification budget.
- No V2 round is accepted without a recorded result.
- Compatibility smoke can run against at least DOCX/XLSX/PPTX samples.

### Efficiency upgrade

This prevents vague improvement loops. Each round becomes a measurable product experiment instead of broad manual polishing.

## Program B — Scenario workbench V2

### Goal

Upgrade the start experience into a task-first workbench.

### Scope

- Make the home surface prioritize high-frequency office scenarios.
- Keep blank Writer/Calc/Impress entry points as secondary but visible.
- Integrate recent files, templates, AI draft actions, and compatibility-safe opening into one workbench logic.
- Add first-run defaults that configure product behavior, not only appearance.

### Priority scenarios

Writer:

1. 工作周报
2. 会议纪要
3. 简历
4. 正式通知 / 公文式通知
5. DOCX 协作修订

Calc:

1. 部门预算表
2. 销售跟踪表
3. 项目排期 / 进度跟踪
4. 复杂 XLSX 兼容检查

Impress:

1. 工作汇报 PPT
2. 教学课件 PPT
3. 根据提纲生成 PPT 初稿
4. PPTX 兼容演示

### Primary repo surfaces

- `sfx2/source/dialog/backingwindow.cxx`
- `sfx2/uiconfig/ui/startcenter.ui`
- `cui/source/dialogs/welcomedlg.cxx`
- template packaging surfaces in `extras`, module template trees, and source branding resources

### Acceptance gates

- A first-time user can start a top scenario from home in one click.
- Recent files and blank document creation remain easy.
- Low-frequency inherited modules do not dominate the first screen.

## Program C — Unified command model V2

### Goal

Make Writer, Calc, and Impress feel like one coherent 可圈office suite.

### Scope

- Define a cross-module command taxonomy.
- Make default toolbar/notebookbar policy intentional.
- Align top-level actions and naming across modules.
- Move low-frequency inherited commands into advanced paths.

### Target cross-suite tabs/groups

1. Home
2. Insert
3. Layout
4. Review
5. View
6. AI
7. Template
8. Export / Share
9. Advanced

### Primary repo surfaces

- `officecfg/registry/data/org/openoffice/Office/UI/ToolbarMode.xcu`
- `officecfg/registry/data/org/openoffice/Office/UI/*.xcu`
- `sw/uiconfig/swriter/ui/notebookbar*.ui`
- `sc/uiconfig/scalc/ui/notebookbar*.ui`
- `sd/uiconfig/simpress/ui/notebookbar*.ui`

### Acceptance gates

- Top-level command placement is predictable across Writer, Calc, and Impress.
- Review/export/template/AI entry points use consistent names and locations.
- Users trained on common office suites can find basic commands without learning upstream structure.

## Program D — Compatibility lab V2

### Goal

Turn compatibility into the core release moat.

### Scope

- Build golden document packs for Chinese workplace scenarios.
- Run automated smoke round-trips for DOCX/XLSX/PPTX.
- Record fidelity gaps by document type and defect class.
- Gate V2 releases on compatibility health.

### Defect taxonomy

Writer DOCX:

- pagination drift
- table layout changes
- comments and tracked changes
- floating objects
- font fallback and Chinese typography

Calc XLSX:

- formula fidelity
- chart fidelity
- merged regions
- conditional formatting
- pivot and complex workbook behavior

Impress PPTX:

- theme fidelity
- text box layout
- grouped shapes
- charts
- animations and transitions

### Primary repo surfaces

- `oox`
- `filter`
- `xmloff`
- `sw`, `sc`, `sd` import/export paths
- `test`, `uitest`, and QA sample roots
- `bin/compatibility-lab.sh`
- `bin/compatibility-roundtrip.sh`

### Acceptance gates

- V2 has a known sample inventory.
- Smoke round-trip reports are reproducible.
- Top breakpoints are ranked by real user impact.
- No release proceeds with unreviewed severe compatibility regressions.

## Program E — AI office workflow layer V2

### Goal

Add AI as a real office productivity layer, not a side chat feature.

### Scope

Implement AI in four workflow lanes:

1. **Writer AI**
   - draft report
   - summarize document
   - rewrite paragraph
   - polish tone
   - extract action items
   - convert notes to meeting minutes

2. **Calc AI**
   - formula assistant
   - explain formula
   - detect spreadsheet errors
   - generate summary from selected range
   - suggest chart or table structure

3. **Impress AI**
   - brief to deck outline
   - outline to editable slides
   - speaker notes
   - slide title/bullet rewrite
   - business report deck starter

4. **Cross-suite AI assistant**
   - contextual commands from selected text/range/slides
   - document-aware actions
   - export/share preparation
   - privacy-aware local/private/cloud mode selection

### Product rules

- AI output must be inserted as editable document content.
- AI actions must be available from the context where users work.
- AI must never block normal editing.
- AI must have clear privacy boundaries.
- Offline/no-account mode remains usable.

### Suggested architecture

- A downstream AI service abstraction with provider-independent request/response types.
- UI entry points in Writer/Calc/Impress.
- Document-context extraction layer per module.
- Prompt templates owned by product scenarios.
- Optional private endpoint configuration for enterprise deployments.

### Acceptance gates

- Each AI feature maps to one real workflow and one measurable step reduction.
- Generated output is editable and recoverable through normal undo/redo.
- Failure mode is graceful: the document remains unchanged if AI fails.
- AI never bypasses user consent for external service calls.

## Program F — PPT generation V2 wedge

### Goal

Make presentation generation the flagship V2 AI workflow.

### Scope

Build a structured deck-generation pipeline:

1. intake: topic, audience, duration, tone, scenario
2. planner: sections, slide count, narrative flow
3. layout engine: slide archetypes and master/theme selection
4. asset engine: charts, tables, image placeholders, icons
5. copy engine: titles, bullets, summaries, speaker notes
6. finalizer: editable Impress document

### Primary repo surfaces

- `sw/source/uibase/app/docsh2.cxx`
- `sd/source/ui/app/sdmod1.cxx`
- `sd/source/ui`
- `sd/source/core`
- command/UI registration in `officecfg`, `sw`, and `sd`

### Acceptance gates

- A user can start from a brief or Writer outline and receive an editable deck.
- Result is better than raw heading import.
- The generated deck has usable structure, not just text copied onto slides.
- PPTX export remains sane after generation.

## Program G — China office defaults V2

### Goal

Make blank documents feel intentionally designed for Chinese office use.

### Scope

- Font defaults and fallback.
- Paragraph spacing and title hierarchy.
- Default page conventions.
- Review/comment behavior.
- Table defaults.
- Print/PDF/export defaults.
- Presentation typography and layout defaults.

### Primary repo surfaces

- `officecfg/registry/data/org/openoffice/VCL.xcu`
- `officecfg/registry/data/org/openoffice/Office/*.xcu`
- blank-document seed paths in `sw`, `sc`, `sd`

### Acceptance gates

- Blank Writer, Calc, and Impress files feel usable without a template.
- Chinese typography is stable across view, print, PDF, and OOXML export.
- Default behavior is verified with new-document snapshots or manual baseline reports.

## Program H — Service and private deployment foundation

### Goal

Prepare V2 for AI/service capabilities while keeping V3 enterprise deployment possible.

### Scope

- Define account/session abstraction.
- Define service endpoint configuration.
- Define template/content delivery channel.
- Define recents/settings sync interface.
- Define local/private/cloud AI modes.
- Keep all service features optional.

### Deployment modes

1. **Local desktop mode**
   - no login required
   - no AI/service dependency
   - all core editing works

2. **Cloud-enhanced mode**
   - AI provider enabled
   - optional template/content service
   - optional account/session

3. **Private enterprise mode**
   - private AI endpoint
   - controlled template service
   - no public cloud requirement
   - policy-managed settings

### Acceptance gates

- Product can run without service configuration.
- Service configuration is explicit and auditable.
- Enterprise/private deployment path is not blocked by V2 AI design.

## Program I — Build, release, and verification efficiency

### Goal

Reduce wasted iteration by using targeted builds and fixed verification budgets.

### Scope

- Use module builds for focused changes:
  - `make sfx2.build`
  - `make cui.build`
  - `make sw.build`
  - `make sc.build`
  - `make sd.build`
  - `make officecfg.build`
  - `make desktop.build`
- Use compatibility scripts for smoke checks.
- Use `make test-install` for runnable app verification.
- Keep release signing separate from local verification.

### Acceptance gates

- Every implementation round lists exact commands run.
- Local smoke verification is possible without release signing.
- Packaging changes have a deterministic verification path.
- CI/release work never pretends unsigned local builds are signed release artifacts.

## V2 phased execution roadmap

## Phase 0 — Baseline lock

### Objective

Make current quality measurable before adding V2 complexity.

### Deliverables

- Generate current quality baseline.
- Generate compatibility lab baseline.
- Run smoke round-trip where local app is available.
- Create V2 dashboard report format.

### Verification

- `bin/quality-baseline.sh tmp/world-class-quality-baseline.md`
- `bin/compatibility-lab.sh tmp/compatibility-lab-baseline.md`
- `bin/compatibility-roundtrip.sh --format smoke --limit 1 --run-name v2-baseline-smoke` when packaged app is available

## Phase 1 — Efficiency-first product shell

### Objective

Make the product faster to start and easier to understand.

### Deliverables

- Workbench V2 hierarchy.
- Scenario entry cards.
- Secondary blank document/module entry.
- First-run behavior defaults.
- Product-surface pruning for low-frequency inherited entries.

### Verification

- focused `sfx2` and `cui` builds
- manual launch-path check
- click count for top scenarios

## Phase 2 — Compatibility release gate

### Objective

Make compatibility failures visible before release.

### Deliverables

- Golden sample taxonomy.
- Smoke document pack.
- Round-trip reports.
- Top compatibility defect backlog.
- Release gate policy.

### Verification

- compatibility lab baseline report
- smoke round-trip reports
- manual review of severe defects

## Phase 3 — Unified command and defaults

### Objective

Make the suite feel coherent during daily editing.

### Deliverables

- Cross-module command taxonomy.
- Default toolbar/notebookbar policy.
- Review/export/template consistency.
- China defaults system v1.

### Verification

- `officecfg`, `sw`, `sc`, `sd` targeted builds
- cross-module command placement audit
- blank document snapshot/manual baseline

## Phase 4 — AI workflow MVP

### Objective

Ship AI only in workflows where it clearly saves time.

### Deliverables

- AI service abstraction.
- Writer rewrite/summarize/draft actions.
- Calc formula/explain actions.
- Impress outline/deck draft action.
- Privacy/offline failure rules.

### Verification

- selected text/range/outline workflow checks
- undo/redo safety check
- no-document-change failure check
- local/private/cloud configuration audit

## Phase 5 — PPT generation flagship

### Objective

Make deck generation a V2 differentiator.

### Deliverables

- Brief intake.
- Slide planner.
- Layout mapping.
- Editable Impress output.
- Speaker notes.
- PPTX export sanity check.

### Verification

- end-to-end deck generation check
- manual deck usefulness review
- PPTX export and reopen check

## Phase 6 — V2 release hardening

### Objective

Turn V2 features into a stable release candidate.

### Deliverables

- Fixed release verification matrix.
- Crash/stability smoke loops.
- Compatibility regression summary.
- AI privacy/failure-mode report.
- Install/package verification.

### Verification

- targeted module builds
- `make test-install`
- compatibility smoke
- manual launch/edit/save/export/reopen checks

## V2 KPI system

### Product efficiency KPIs

- clicks from launch to top scenario
- time to first useful document
- scenario/template adoption rate
- command discovery consistency score
- deck draft completion rate

### Compatibility KPIs

- DOCX round-trip damage rate
- XLSX formula/chart fidelity score
- PPTX layout/theme fidelity score
- comment/tracked-change parity score
- PDF export correctness rate

### Reliability KPIs

- startup success rate
- crash-free editing session rate
- save/reopen correctness rate
- export/print consistency score
- undo/redo trust pass rate

### AI KPIs

- accepted AI output rate
- time saved per workflow
- edit distance from AI draft to final document
- repeated usage rate
- failed-call safe recovery rate

### Engineering efficiency KPIs

- round verification pass rate
- time from source change to targeted verification
- number of regressions caught before release
- compatibility sample coverage
- reproducible baseline report availability

## V2 release gates

A V2 release candidate must pass these gates:

1. **Core editing gate**
   - Writer/Calc/Impress can create, edit, save, reopen, export PDF, and print-preview common documents.

2. **Compatibility gate**
   - DOCX/XLSX/PPTX smoke packs have recorded round-trip results.
   - Severe regressions are reviewed before release.

3. **Workbench gate**
   - Top scenarios are directly discoverable from launch.
   - Blank module entry remains available.

4. **AI safety gate**
   - AI failure does not alter documents unexpectedly.
   - AI output is editable.
   - External service calls are explicit and configurable.

5. **Offline gate**
   - The product remains useful without login, cloud, or AI provider.

6. **Packaging gate**
   - Local runnable install is verified.
   - Release signing status is clearly separated from local build success.

## Recommended immediate next execution cut

The next high-efficiency cut should be Phase 0 plus the first part of Phase 1:

1. Generate a fresh quality baseline.
2. Generate a fresh compatibility lab baseline.
3. Run smoke round-trip if packaged app is executable.
4. Add a V2 dashboard report generated from those inputs.
5. Use that dashboard to drive the next workbench and AI workflow cuts.

This gives V2 a control tower before adding expensive AI or service work.

## Priority backlog

### P0 — Must happen before real V2 feature expansion

1. V2 dashboard report.
2. Compatibility smoke baseline.
3. Workbench V2 scenario hierarchy.
4. Cross-module command taxonomy document.
5. AI privacy/offline architecture decision.

### P1 — First visible V2 product wins

1. Writer AI rewrite/summarize/draft actions.
2. Calc formula assistant.
3. PPT outline-to-deck MVP.
4. Scenario template ranking.
5. China defaults v1.

### P2 — Release moat

1. Golden compatibility packs.
2. PPT generation structured pipeline.
3. Service/private deployment abstraction.
4. Installer/release verification improvements.
5. Enterprise policy mode.

## Final V2 definition

V2 is complete when 可圈office is no longer only a branded office build. It should become a measurable, task-first, AI-assisted office product where:

- daily Chinese office tasks start faster
- document compatibility is continuously measured
- AI saves real workflow steps
- core editing remains trustworthy
- offline/private deployment remains possible
- every improvement is verified through repeatable quality gates
