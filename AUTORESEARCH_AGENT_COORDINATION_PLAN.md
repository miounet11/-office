# 可圈office Agent Coordination Plan

## Purpose

This plan defines how Codex and Clavue should collaborate on 可圈office without duplicating work, trampling generated build outputs, or making broad product changes without evidence. The goal is not to make many simultaneous edits. The goal is to move the product toward a world-class China-first office suite through measured, reviewable rounds.

## Current Coordination Status

- Clavue is installed at `/opt/homebrew/bin/clavue`.
- `clavue team check` reports agent-team sessions are disabled and provider native tool-calling validation failed.
- Direct shared-session discussion is therefore not reliable in the current environment.
- Coordination should use `AUTORESEARCH_EXECUTION_TODOLIST.md` as the active todo control document, `docs/product/next-stage-development-plan.md` as the M2 execution plan, plus this document, `clavue.md`, and the rest of the `AUTORESEARCH_*` roadmap documents as supporting context.
- Current ownership reservation: Codex owns control-plane/plugin/service-policy lanes; Clavue owns Writer behavior, Workbench behavior/accessibility review, implementation-risk audit, and presentation-builder boundary review.
- P1-04 Writer preview analyzer, P1-05 plugin manifest validator, and P1-07 presentation outline fixtures are implemented and locally validated; M2 work should harden and review them rather than relist them as active P1 implementation.

## Non-Negotiable Rules

1. Do not edit `workdir/`, `instdir/`, `test-install/`, `tmp/`, `autom4te.cache/`, or generated `config_*` files as source.
2. Do not let two agents edit the same module or file family in the same round.
3. Every round must declare one bottleneck, one target workflow, one validation budget, and explicit guardrails.
4. Compatibility, save/reopen, export, startup, and recovery trust outrank visual novelty and AI features.
5. Prefer source edits under `/Users/lu/kdoffice-src` or the active source worktree when changing product behavior; update generated build-tree files only through normal regeneration.

## Shared Product North Star

可圈office should become:

- a reliable desktop office suite first
- China-office scenario-first, not upstream-module-first
- compatible enough with DOCX/XLSX/PPTX to be trusted in daily work
- consistent across Writer, Calc, and Impress
- AI-assisted only where it compresses real office workflows
- usable offline, with optional service/private/cloud modes later

## Work Lanes

### Lane A: Control Tower and Quality Gates

Owner: Codex primary, Clavue reviewer.

Scope:

- Maintain `bin/quality-baseline.sh`, `bin/compatibility-lab.sh`, `bin/compatibility-roundtrip.sh`, and future dashboard scripts.
- Convert roadmaps into repeatable round reports.
- Keep git status readable by separating source changes from generated build noise.

Validation:

- `bash -n bin/*.sh`
- `bin/v2-p0-gates.sh v2-p0-current-limit3`
- `bin/quality-baseline.sh tmp/world-class-quality-baseline.md`
- `bin/compatibility-lab.sh tmp/compatibility-lab-baseline.md`

Latest gate result:

- `bin/v2-p0-gates.sh v2-p0-tiered-contracts` passed.
- Report path: `tmp/v2-p0-gates/v2-p0-tiered-contracts.md`.
- Current P0 gates cover source-focused status, quality baseline, Workbench template package check, Workbench template runtime smoke, compatibility inventory, curated manifest audit, curated 27-sample DOCX/XLSX/PPTX manifest smoke with advisory fidelity heuristics, validator readiness, source hygiene, intelligent-office readiness, contract fixtures, Workbench accessibility static checks, and dashboard refresh.

### Lane B: Scenario Workbench

Owner: Clavue primary, Codex reviewer.

Scope:

- Stabilize and verify the existing task-first Start Center workbench before adding new UI.
- Prioritize weekly report, meeting minutes, resume, budget sheet, project schedule, work report PPT, teaching PPT, and PPT draft generation.
- Preserve blank document creation and recent files.

Primary surfaces:

- `sfx2/source/dialog/backingwindow.cxx`
- `sfx2/uiconfig/ui/startcenter.ui`
- `cui/source/dialogs/welcomedlg.cxx`

Validation:

- `bin/workbench-template-check.sh tmp/workbench-template-check.md`
- `bin/workbench-template-smoke.sh --run-name v2-workbench-template-smoke`
- `make sfx2.build`
- `make cui.build` if onboarding changes are touched
- manual app launch through `make test-install` when build cost is acceptable

Current Clavue handoff:

- `backingwindow.cxx` already contains scenario workbench logic, click handlers, fallback/template hub behavior, and a scenario template registry.
- `startcenter.ui` should be checked for the expected `scenario_*` widgets before redesigning the layout.
- First implementation should verify template availability and deterministic fallback, not add more buttons.
- Priority template filenames to verify include `Work_Report_CN.ott`, `Meeting_Minutes_CN.ott`, `Budget_CN.ots`, `Project_Schedule_CN.ots`, `Project_Report_CN.otp`, `Teaching_Courseware_CN.otp`, and `PPT_Outline_CN.ott`.

Latest template result:

- `bin/workbench-template-check.sh tmp/workbench-template-check.md` passed.
- All 11 scenario templates have source parts, generated archives, and installed runtime files.
- `bin/workbench-template-smoke.sh --run-name v2-workbench-template-smoke` passed.
- All 11 installed runtime templates converted successfully through packaged `soffice`.
- The next Workbench risk is GUI click/dispatch behavior, not template packaging or template loadability.

### Lane C: Unified Command Model

Owner: Codex primary, Clavue reviewer.

Scope:

- Align Writer, Calc, and Impress around a shared command taxonomy: Home, Insert, Layout, Review, View, Template, Export/Share, AI, Advanced.
- Start with configuration and small UI policy changes before editing huge notebookbar files.

Primary surfaces:

- `officecfg/registry/data/org/openoffice/Office/UI/ToolbarMode.xcu`
- `officecfg/registry/data/org/openoffice/Office/UI/*.xcu`
- `sw/uiconfig/swriter/ui/notebookbar*.ui`
- `sc/uiconfig/scalc/ui/notebookbar*.ui`
- `sd/uiconfig/simpress/ui/notebookbar*.ui`

Validation:

- `make officecfg.build`
- targeted module build for touched UI modules
- screenshot or manual command-discovery check before acceptance

Current Clavue handoff:

- Writer, Calc, and Impress already default to `Tabbed` mode in `ToolbarMode.xcu`.
- Their `Tabbed` mode maps to `notebookbar.ui`; no first-pass config change is needed for default-mode unification.
- Do not edit large `notebookbar*.ui` files until a command taxonomy issue is proven by user workflow evidence.
- If the product intentionally wants classic toolbars instead, the smallest config-only lever is changing only the three `Active` values from `Tabbed` to `Default`, but that is a product behavior change rather than a unification fix.

### Lane D: Compatibility Lab

Owner: Codex primary for manifests/reports/tooling, Clavue reviewer for representativeness and import/export risk.

Scope:

- Build a real Office-format regression pack around Chinese workplace documents.
- Prioritize DOCX pagination/tables/tracked changes, XLSX formulas/charts, and PPTX layout/theme/text fidelity.
- Improve automation before deep import/export surgery.

Primary surfaces:

- `bin/compatibility-roundtrip.sh`
- `bin/compatibility-manifest-audit.sh`
- `docs/compatibility/corpus-expansion-plan.md`
- `oox/`, `filter/`, `xmloff/`
- app-specific import/export paths in `sw/`, `sc/`, and `sd/`

Validation:

- round-trip smoke for DOCX/XLSX/PPTX sample packs
- validators: `bin/odfvalidator.sh`, `bin/officeotron.sh`, `bin/verapdf.sh` where relevant

Current Clavue handoff:

- V1 seed should use existing QA documents only and existing round-trip tooling.
- The curated 27-sample manifest is the current P0 compatibility gate: `bin/compatibility-roundtrip.sh --manifest docs/compatibility/smoke-manifest.tsv --run-name <name>`.
- Smoke sample selection should prefer module-owned samples first: Writer for DOCX, Calc for XLSX, Impress for PPTX.
- Smoke sample selection excludes paths explicitly marked `/fail/`; those are useful for targeted regression work, not baseline health gates.
- Missing validators or assets must be recorded as skipped, not confused with conversion success.
- No import/export engine edits belong in the seed round.

Latest seed result:

- `bin/compatibility-roundtrip.sh --manifest docs/compatibility/smoke-manifest.tsv --run-name v2-smoke-fidelity-manifest-final` succeeded on 27 samples.
- `bin/compatibility-manifest-audit.sh --manifest docs/compatibility/smoke-manifest.tsv` validates manifest structure before conversion.
- Selected samples include 9 DOCX, 9 XLSX, and 9 PPTX manifest-pinned QA files with scenario notes.
- Report path: `tmp/compatibility-runs/v2-smoke-fidelity-manifest-final/report.md`.
- ODF validators were skipped as missing assets; conversion infrastructure itself passed.
- Advisory fidelity metrics flagged one useful storage/performance signal: embedded-font PPTX expanded to a 62 MB intermediate ODP.
- Corpus expansion plan: `docs/compatibility/corpus-expansion-plan.md`.

### Lane E: Chinese Defaults and Templates

Owner: Codex primary, Clavue reviewer.

Scope:

- Make blank Writer, Calc, and Impress documents feel intentional for Chinese office work.
- Use `officecfg` and templates first; only change module seed code when config cannot express the policy.

Primary surfaces:

- `officecfg/registry/data/org/openoffice/VCL.xcu`
- Writer/Calc/Impress default config and template packaging
- `extras/` and downstream branding/template assets

Validation:

- `make officecfg.build`
- relevant module build
- open blank documents and verify defaults by behavior, not only diff

Current Clavue handoff:

- `VCL.xcu` already contains a robust Simplified Chinese font fallback policy.
- `Setup.xcu` already has localized `zh-CN` factory names, but factory default template files remain empty.
- `UISort.xcu` already favors OOXML first in visible filter ordering, which supports compatibility UX but is not a default-save policy.
- Chinese scenario templates are already packaged and have `zh-CN` metadata.
- Do not force global locale, currency, default save format, or factory template assignment until runtime behavior is verified with a fresh profile.
- The safest next work is template visibility/runtime validation, not more broad config changes.

### Lane F: PPT Generation V2

Owner: shared design, single implementation owner per round.

Scope:

- Move beyond heading import into a pipeline: intake, planner, layout mapping, asset placeholders, copy, speaker notes, final editable Impress document.
- Start with a local deterministic pipeline before service or AI dependency.

Primary surfaces:

- Writer command entry for outline/deck generation
- `sd/source/ui/app/sdmod1.cxx`
- Impress slide insertion/layout/theme primitives

Validation:

- generated deck opens as editable Impress document
- slide count, section titles, placeholders, and notes are deterministic
- `make sd.build`

Current Clavue handoff:

- Existing Writer flow serializes outline/summary to RTF and dispatches `SendOutlineToImpress`.
- Existing Impress flow creates a new document, switches to Outline View, reads RTF, inserts slides from outline paragraphs, and finalizes previews asynchronously.
- Do not replace `.uno:SendOutlineToStarImpress` or mutate the legacy path first.
- Smallest safe V2 step is a separate deterministic internal Impress helper that accepts a normalized outline model and creates slides without RTF or async Outline View activation.
- First implementation should be test/internal only, with assertions on slide count, title text, bullet text/depth, and layout. No AI generation, UI command, or PPTX export changes in the first step.
- Boundary doc: `docs/architecture/intelligent-office-implementation-boundaries.md`.

## Immediate Next Five Tasks

1. Codex M2-07 review closeout: keep `sd/` read-only and verify the speaker-notes unsupported diagnostic assertion now exists after Clavue's revision.
2. Codex M2-06 review: review `docs/accessibility/workbench-accessibility-evidence-m2-06.md` for false confidence around keyboard traversal, VoiceOver, resize, high contrast, blank document routes, recent/open routes, scenario buttons, and fallback behavior.
3. Codex service lane: keep `docs/product/service-mode-policy.md` enforced as a blocker before runtime plugin loading or provider work.
4. Control tower M2-08/P2-05: keep `bin/v2-p0-gates.sh <round-name>` green and record skipped validators, missing live a11y evidence, and source hygiene limits as blockers/advisories rather than hidden passes.
5. Clavue next source lane: wait for Codex review before expanding `sd/`, Workbench, provider, UI command, plugin runtime, or import/export scope.

## 2026-05-01 Parallel Scope Integration Matrix

| Worker | Edit status | Scope findings | Coordinator decision |
| --- | --- | --- | --- |
| `scope-worker` (`a58398e311b89385d`) | No edits | Existing Workbench source changes are already coupled across `sfx2/source/dialog/backingwindow.cxx`, `sfx2/source/dialog/backingwindow.hxx`, `sfx2/uiconfig/ui/startcenter.ui`, and `cui/uiconfig/ui/welcomedialog.ui`; template packaging and `officecfg` defaults are safer verification slices. XML parse validation passed for the inspected UI/config files, but no build or GUI test was run. | Treat source UI implementation as verification-only/manual-merge-required. Do not add overlapping Workbench edits until the current `kdoffice-src` changes are reviewed, built, and visually checked. Next safe actions are `make sfx2.build`, template archive structure validation, and manual Start Center scenario-button testing. |
| `scope-worker-2` (`aa4f36efb0f948071`) | No edits | V1 product scope is desktop Writer + Calc with local open/edit/save, DOCX/XLSX, PDF export, Chinese UI/templates, and installable app. Round 28 already pivots Start Center to `可圈office 工作台`, intentionally hiding remote/extensions/Draw/Math/Base/Impress entry points and wiring seven real Writer/Calc templates. Hidden presentation UI/templates remain coordination-sensitive because V1 excludes PPT while later roadmaps discuss Writer-to-PPT. | Keep Impress/PPT scenario cards hidden unless product scope explicitly expands. Runtime visual validation of the rebuilt Start Center is the next source UI gate; source review alone is insufficient for spacing/card hierarchy. Toolbar/default policy changes stay verification-only until UX policy is confirmed. |
| `integration-worker` (`a9a2f769af8104e0f`) | Preserved edits in isolated worktree | Worktree `/Users/lu/可点office/.clavue/worktrees/agent-a9a2f769` changed `.github/workflows/build-installers.yml` and `bin/compatibility-roundtrip.sh`. It adds a post-`test-install` macOS compatibility smoke step, copies `tmp/compatibility-runs` into macOS logs, adds `KDOFFICE_SRC_ROOT`/`KDOFFICE_SOFFICE_BIN` overrides, supports direct source-tree layout, and falls back from `instdir/可圈office.app` to `test-install/可圈office.app`. Worker verification passed `bash -n`, `--help`, workflow text assertions, `git diff --check`, and a 3-sample smoke roundtrip with 3 conversion successes. ODF validation failed and Officeotron remained `skipped:missing-asset`, so validator evidence is not beta-ready. | Manual consolidation required. The source-root/app override patch is a safe candidate to fold into the current `bin/compatibility-roundtrip.sh` manifest/fidelity work; the workflow smoke step should wait until the harness patch is reviewed in the main worktree and validator failures are documented as non-readiness evidence. Do not claim full compatibility validation from this worker because validator/tooling blockers remain. |

## Codex Execution Injection

Current Clavue-to-Codex handoff, updated 2026-04-28:

Clavue has completed the narrow M2-07 revision and produced the M2-06 evidence packet. Codex should stop re-planning and execute the next bounded owner tasks in this order:

1. **M2-07 read-only review closeout:** use `docs/product/m2-07-presentation-outline-builder-review.md` as the decision record and verify the speaker-notes unsupported diagnostic assertion exists in the `sd/` test lane.
2. **M2-06 evidence review:** review `docs/accessibility/workbench-accessibility-evidence-m2-06.md` for false confidence. It records static/source/UITest evidence and intentionally keeps live VoiceOver, Tab/Shift+Tab, Enter/Space, high-contrast, resize, and missing-template fallback as beta blockers.
3. **Passive monitoring:** run `bin/clavue-passive-monitor.sh tmp/clavue-passive-monitor.md` before starting long GUI/build work and do not interrupt a running Clavue build/test.
4. **Dashboard accuracy:** update dashboard blockers so timing budgets, internal/test-only builder status, Workbench a11y evidence, and plugin/service policy blockers are not stale.
5. **Service policy enforcement:** use `docs/product/service-mode-policy.md` as the offline/local/private/cloud blocker before any plugin runtime or AI provider implementation.

Codex guardrails: one owner per file family, no Writer analyzer source edits during Clavue-owned analyzer rounds, no Workbench or presentation-builder source edits while reviewing Clavue's M2-06/M2-07 handoff, and no `sd/` edits in the read-only review closeout. Codex should focus on `bin/`, `docs/product/`, `docs/compatibility/`, schemas/reports, dashboards, plugin/service policy, and read-only review evidence. No generated build output as source, and no claim that skipped validators, static checks, or process-alive smoke are quality passes. Required recurring verification: `bin/v2-p0-gates.sh <round-name>` plus the lane-specific command above.

ICC peer-terminal discovery was attempted from this session but blocked by the local permission classifier, so this file-based handoff is the current control channel until ICC access is available.

## Source-Only Status Recipe

Use this before assigning or reviewing work so agents do not reason from generated build noise:

```sh
bin/source-status.sh
```

The helper wraps this explicit filter:

```sh
git status --short -- \
  ':(exclude)workdir/**' \
  ':(exclude)instdir/**' \
  ':(exclude)test-install/**' \
  ':(exclude)tmp/**' \
  ':(exclude)autom4te.cache/**' \
  ':(exclude)config.log' \
  ':(exclude)config.status' \
  ':(exclude)config_host.mk' \
  ':(exclude)config_host/**' \
  ':(exclude)autogen.lastrun' \
  ':(exclude)autogen.lastrun.bak'
```

Generated-output changes may be inspected for build diagnosis, but they are not reviewable product source changes unless the round explicitly says so.

## Review Protocol

Before implementation, the primary owner writes a short round packet:

- objective
- owned files
- non-goals
- validation commands
- rollback plan

The reviewer checks the packet before broad edits. After implementation, the reviewer checks diffs, runs the agreed validation budget if feasible, and records accept/reject evidence.

## Session Handoff Prompt

Use this prompt when starting Clavue or Codex on a lane:

```text
You are working on 可圈office in /Users/lu/可点office. Read AGENTS.md, clavue.md, CLAUDE.md, AUTORESEARCH_EXECUTION_TODOLIST.md, AUTORESEARCH_AGENT_COORDINATION_PLAN.md, AUTORESEARCH_V2_UPGRADE_PLAN.md, and AUTORESEARCH_WORLD_CLASS_QUALITY_ROADMAP.md. Own only the assigned lane and files. Do not edit generated build outputs. Produce a round packet before implementation, then make bounded source edits and run the declared validation budget.
```
