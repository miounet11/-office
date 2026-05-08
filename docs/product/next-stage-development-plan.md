# Next Stage Development Plan

Generated on 2026-04-28 from Codex and Clavue planning artifacts:

- `AUTORESEARCH_MATURE_OFFICE_PRODUCT_MODEL.md`
- `docs/product/mature-office-product-requirements.md`
- `AUTORESEARCH_EXECUTION_TODOLIST.md`
- `AUTORESEARCH_AGENT_COORDINATION_PLAN.md`
- `tmp/v2-upgrade-dashboard.md`

## Stage Objective

Move 可圈office from alpha control-plane proof into product-depth development while preserving core desktop trust.

The next stage is not "add many AI features." It is the first measured productization stage:

- make Chinese office task entry faster;
- turn compatibility into richer evidence;
- harden preview-only intelligence before any apply path;
- build deterministic PPT generation from a normalized model;
- add performance budgets and accessibility evidence;
- keep offline/core editing reliable.

## Current Baseline

Completed foundations:

- P1-04 Writer preview-only analyzer exists and passed targeted Writer unit validation.
- P1-05 local/offline plugin manifest validator exists and is wired into the P0 gate wrapper.
- P2-04 service-mode policy exists and blocks runtime plugin/provider work until offline/local/private/cloud boundaries are enforceable.
- P1-07 normalized PPT outline schema fixture exists and passed contract fixture validation.
- Curated 27-sample DOCX/XLSX/PPTX compatibility smoke passes conversion.
- Workbench scenario templates and UITest smoke evidence exist.
- Dashboard, source status, source hygiene, validator readiness, contract fixtures, and P0 gate scripts exist.

Known blockers:

- Clavue team sessions are still disabled; coordination remains written handoffs plus review.
- Validator assets are missing, so validator conformance is beta-blocked.
- GUI timing proves process survival, not user-perceived responsiveness.
- Workbench accessibility has an evidence packet and static/UITest proof; live VoiceOver, keyboard traversal, resize, and high-contrast review remain beta-blocked.
- Writer analyzer remains preview-only and intentionally narrow; M2-04 hardened its contract and document-state preservation tests.
- Presentation outline model has an internal/test-only Impress builder seed; UI/provider/export work remains blocked.
- Plugin manifest validation and service-mode policy exist, but runtime plugin loading and signing policy do not.
- Large generated/local dirty output means release hygiene is not beta-ready.

## Collaboration Model

Codex and Clavue should run as two independent lanes with explicit handoffs.

Rules:

- Do not use direct Clavue team sessions as a required gate until `clavue team check` passes.
- One owner per file family per round.
- Every round has a reviewer from the other agent.
- Every round declares target workflow, primary metric, guardrails, touched surfaces, and verification commands.
- No generated build output is edited as source.
- No import/export engine edits without a failing compatibility sample and rollback plan.
- No broad AI/provider work before local/offline failure-safe boundaries are proven.

## Ownership Split

| Lane | Primary Owner | Reviewer | File Families |
| --- | --- | --- | --- |
| Control gates, dashboard, reports | Codex | Clavue | `bin/`, `AUTORESEARCH_*`, `docs/product/`, `docs/compatibility/` |
| Product behavior and source risk | Clavue | Codex | `sw/`, `sd/`, `sfx2/`, `officecfg/`, UI/source behavior |
| Compatibility evidence | Codex | Clavue | manifests, reports, visual evidence tooling before filter edits |
| Writer intelligence | Clavue | Codex | Writer analyzer source and Writer QA |
| PPT generation | Clavue | Codex | normalized model review, later `sd/` builder |
| Plugin/service safety | Codex | Clavue | schema, validator, service-mode policy, no runtime execution yet |
| Workbench accessibility | Clavue | Codex | UI behavior review plus evidence packet |

## Next Stage Milestones

### M2-01: Review and Lock P1-07 Presentation Outline Contract

Owner: Codex review, Clavue responds.

Goal: verify the normalized PPT outline schema before any Impress builder.

Scope:

- Review `docs/schemas/presentation-outline.schema.json`.
- Review valid/invalid presentation outline fixtures.
- Check whether fixture shape covers title, ordered slides, sections, bullets, notes, source refs, and editable placeholder intent.
- Do not edit Impress source.

Acceptance:

- Contract fixture gate passes.
- Review records no blocking schema gaps, or records exact changes before builder work.

Verification:

- `bin/intelligent-contract-fixtures.sh tmp/intelligent-contract-fixtures.md`
- JSON syntax checks for schema and fixtures.

### M2-02: China Blank-Document Default Policy

Owner: Codex primary, Clavue reviewer.

Goal: define behavior requirements for fresh Writer, Calc, and Impress documents before config/source edits.

Scope:

- Create a policy document under `docs/product/`.
- Define Writer defaults: Chinese fonts, page size/margins, paragraph spacing, heading styles, punctuation/line rhythm.
- Define Calc defaults: Chinese-friendly font, sheet layout, number/date/currency expectations, print defaults.
- Define Impress defaults: widescreen ratio, theme font, title/body rhythm, Chinese presentation templates.
- Map possible repo surfaces, but do not change `officecfg` or templates in this round.

Acceptance:

- Behavior targets are explicit and testable.
- Risky policies are deferred: global locale forcing, default save format changes, broad factory template changes.

Verification:

- `bash -n bin/*.sh`
- `bin/v2-upgrade-dashboard.sh tmp/v2-upgrade-dashboard.md`

### M2-03: GUI Timing Budgets

Owner: Codex primary, Clavue reviewer.

Goal: convert process-alive GUI smoke into performance evidence.

Scope:

- Extend `bin/gui-smoke-timing.sh` with optional timing budget thresholds.
- Report survival status, timeout status, and timing-budget status separately.
- Keep advisory in alpha and beta-hard only after baseline data is stable.

Initial budgets:

- Cold Start Center target: under 3 seconds; beta gate under 5 seconds.
- Warm Start Center target: under 1.5 seconds.
- Blank Writer/Calc/Impress after launch: target under 1 second where measurable.

Acceptance:

- Existing smoke still works without thresholds.
- Threshold mode can fail when elapsed time exceeds budget.
- Reports distinguish crash, timeout, and budget miss.

Verification:

- `bash -n bin/gui-smoke-timing.sh`
- `bin/gui-smoke-timing.sh --mode startcenter --wait 12 --timeout 20 --max-elapsed 20 --run-name m2-budget-baseline`
- threshold self-check or controlled budget-fail run if safe.

### M2-04: Writer Analyzer Hardening

Owner: Clavue primary, Codex reviewer.

Goal: harden P1-04 before expanding diagnostics or adding apply actions.

Scope:

- Add tests for full diagnostic contract equality across repeated runs.
- Assert modified-state preservation for initially unmodified and initially modified documents.
- Keep analyzer preview-only and read-only.
- No UI, no apply path.

Acceptance:

- Existing long-paragraph diagnostic remains stable.
- Tests prove full diagnostic stability and document modified-state preservation.
- Status: done for implementation validation; Codex read-only review remains the cross-agent review gate.

Verification:

- `gmake -C /Users/lu/kdoffice-src CppunitTest_sw_uwriter` passed after the hardened test patch.
- Read-only code review from Codex.

### M2-05: Compatibility Visual Evidence Seed

Owner: Codex primary, Clavue reviewer.

Goal: add the first visual/layout evidence lane without editing import/export engines.

Scope:

- Select one DOCX, one XLSX, and one PPTX from the curated or representative corpus.
- Generate exported PDF or screenshot artifacts if current tooling supports it.
- While another agent owns the shared GUI/build tree, seed non-rendered layout proxy evidence from existing roundtrip artifacts.
- Record visual evidence path and limitations in a report.
- Keep failures advisory until the lane is stable.

Acceptance:

- At least one sample per DOCX/XLSX/PPTX has a durable visual/layout evidence record.
- Report does not claim full fidelity from process success alone.

Verification:

- `bin/compatibility-roundtrip.sh --manifest docs/compatibility/smoke-manifest.tsv --run-name m2-visual-seed`
- `bin/compatibility-layout-evidence.sh --report tmp/compatibility-layout-evidence.md`
- visual render command or documented manual artifact path after the shared install tree is free.

### M2-06: Workbench Accessibility Evidence Packet

Owner: Clavue primary, Codex reviewer.

Goal: turn Workbench accessibility from static checklist into evidence.

Scope:

- Manual keyboard traversal.
- VoiceOver labels for scenario cards, blank document routes, recent files, and template actions.
- Resize behavior.
- High-contrast or theme behavior.
- Confirm blank Writer/Calc/Impress remains easy to reach.

Acceptance:

- Evidence report records pass/fail findings and exact defects.
- No additional Workbench buttons are added in this round.

Verification:

- `bin/workbench-accessibility-check.sh tmp/workbench-accessibility-check.md`
- `gmake UITest_workbench_smoke`
- manual evidence report under `tmp/` or `docs/accessibility/`.

### M2-07: Presentation Outline Builder Design Review

Owner: Clavue primary, Codex reviewer.

Goal: design and seed the first deterministic Impress builder without implementing broad UI.

Scope:

- Map `presentation-outline.schema.json` to editable Impress placeholders.
- Preserve legacy `.uno:SendOutlineToStarImpress`.
- Define test fixture expectations: slide count, title text, bullet depth, notes, placeholder editability.
- No AI generation and no UI command yet.

Acceptance:

- Design identifies exact source surfaces and test target.
- Internal/test-only builder creates editable title/body slide content.
- Speaker notes are either materialized or explicitly reported as unsupported by a stable diagnostic.
- No UI/provider/plugin/export/legacy Writer-to-Impress scope is added.

Verification:

- Design review document and Codex review.
- `gmake -C /Users/lu/kdoffice-src CppunitTest_sd_misc_tests`

Current status:

- Clavue implemented an internal/test-only `sd/` builder seed and local `CppunitTest_sd_misc_tests` evidence reached final `OK (29)`.
- Codex read-only review is recorded in `docs/product/m2-07-presentation-outline-builder-review.md`.
- Decision is done for the internal/test-only seed after the speaker-notes unsupported diagnostic assertion was added and `CppunitTest_sd_misc_tests` passed.

## Parallel Execution Plan

Round A:

- Codex: M2-01 review P1-07 and M2-02 blank-document default policy.
- Clavue: M2-04 Writer analyzer hardening plan or patch.
- Shared gate: no overlapping analyzer edits by Codex; no dashboard/control edits by Clavue.

Round B:

- Codex: M2-03 GUI timing budgets and M2-05 compatibility visual evidence seed.
- Clavue: M2-06 Workbench accessibility evidence.
- Shared gate: Codex reviews Workbench findings; Clavue reviews timing/visual evidence for false confidence.

Round C:

- Clavue: completed M2-07 internal builder revision and M2-06 evidence packet.
- Codex: beta gate promotion and service-policy enforcement planning before runtime plugin loading.
- Shared gate: no plugin runtime, provider path, UI command, or export expansion until a new round packet is accepted.

## Stage Exit Criteria

The next stage is complete when:

- P1-07 presentation outline contract is reviewed and locked.
- China blank-document default policy exists.
- GUI smoke has timing budgets.
- Writer analyzer tests are hardened.
- At least one DOCX, XLSX, and PPTX sample has visual/layout evidence.
- Workbench has durable accessibility evidence plus explicit live beta blockers.
- Presentation builder internal seed is reviewed and accepted before UI/provider/runtime implementation.
- P0 gate wrapper remains green.

## Verification Budget

Minimum recurring commands:

- `bash -n bin/*.sh`
- `bin/intelligent-contract-fixtures.sh tmp/intelligent-contract-fixtures.md`
- `bin/plugin-manifest-validator.sh --self-test --report tmp/plugin-manifest-validator.md`
- `bin/intelligent-office-readiness.sh tmp/intelligent-office-readiness.md`
- `bin/v2-upgrade-dashboard.sh tmp/v2-upgrade-dashboard.md`
- `bin/source-status.sh`
- `bin/v2-p0-gates.sh <round-name>`

Source-specific commands:

- Writer analyzer changes: `make CppunitTest_sw_uwriter`
- Workbench source changes: `gmake UITest_workbench_smoke`
- Compatibility evidence: `bin/compatibility-roundtrip.sh --manifest docs/compatibility/smoke-manifest.tsv --run-name <round-name>`
- Validator readiness: `bin/validator-readiness.sh tmp/validator-readiness.md`

## Non-Negotiable Product Rules

- Do not ship AI that can corrupt documents.
- Do not claim compatibility without representative evidence.
- Do not count skipped validators as passes.
- Do not treat process-alive GUI smoke as usability proof.
- Do not replace legacy Writer-to-Impress flow before the deterministic helper is proven.
- Do not implement plugin runtime loading before local/offline policy, failure behavior, and consent boundaries are stable.
- Treat `docs/product/service-mode-policy.md` as the runtime/plugin blocker until signing, allowlist, consent, and failure-isolation tests exist.
- Do not make generated build output part of source review.
