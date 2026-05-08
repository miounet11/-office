# 可圈office Execution Todolist

This is the active working plan for Codex + Clavue collaboration. It consolidates the current repo evidence, Clavue's independent review, and current agent-practice references into one execution backlog.

## Current Verdict

The project has a strong control plane, but product proof is not yet strong enough.

| Area | Current Rating | Verdict |
| --- | ---: | --- |
| Planning clarity | 8/10 | Strong. Roadmaps, lanes, and contracts exist. |
| Execution efficiency | 7/10 | Good for alpha. Needs fewer advisory passes and more machine-readable gates. |
| Quality evidence | 6/10 | Better after curated 27-sample conversion smoke plus advisory fidelity metrics, but still lacks external validators, GUI usability, recovery, and accessibility proof. |
| Architecture readiness | 7.5/10 | Writer preview analyzer and deterministic PPT boundaries are documented; runtime implementation is still missing. |
| Product implementation depth | 3.5/10 | Workbench/templates/branding exist, compatibility gates are stronger, but intelligent-office runtime features are not implemented yet. |
| Engine capability strategy | 7/10 | M3 product and platform plans now exist; source-entry audit, contract fixtures, registry stub, and preview/apply contracts are still pending. |

Answer to the two practical questions:

- Is efficiency high enough? Good enough for controlled alpha iteration, not high enough for beta/release. The slow part is no longer "how to run checks"; it is that checks still produce too many advisory reports instead of hard decisions.
- Is quality good enough? Not yet. The strategy is stronger after curated compatibility and advisory fidelity evidence, but skipped validators and process-alive GUI smoke still cannot support a world-class claim.

## Evidence Snapshot

- `clavue team check` reports agent-team sessions are disabled and native tool calling validation failed, so direct shared Clavue team sessions are not reliable yet.
- A non-interactive Clavue review was run with `clavue -p`; it independently flagged the same main gaps: shallow compatibility proof, advisory P0 gates, missing GUI behavior gates, missing intelligent-office runtime implementation, and release hygiene risk.
- `bin/source-status.sh` shows the source-focused working set is planning/docs/scripts, while generated build/install output remains large and must stay out of product reviews.
- `bin/source-hygiene-report.sh tmp/source-hygiene-report.md` reports 23,987 working tree entries, with 60 source-focused and 23,927 generated/local entries after the latest control-plane additions.
- `bin/intelligent-office-readiness.sh tmp/intelligent-office-readiness.md` reports all planned surfaces, the contract fixture gate present, and the first Writer preview-only analyzer implemented; runtime plugin loader remains missing.
- `bin/intelligent-contract-fixtures.sh tmp/intelligent-contract-fixtures.md` passed 18 fixtures across 9 schemas: `apply-plan`, `capability-registry-entry`, `document-snapshot`, `evidence-record`, `intelligent-diagnostic`, `kqoffice-plugin`, `presentation-outline`, `preview-action`, and `provider-request`.
- `bin/plugin-manifest-validator.sh --self-test --report tmp/plugin-manifest-validator.md` passed local/offline policy validation: valid offline manifests pass, invalid/provider/unsafe-command/missing-failure-message cases fail with Chinese-facing failure behavior requirements.
- `docs/product/mature-office-product-requirements.md` now records the mature office-suite capability model, current Clavue execution status, performance targets, interaction principles, and next execution order.
- `AUTORESEARCH_MATURE_OFFICE_PRODUCT_MODEL.md` records Clavue's parallel mature-office product model and confirms the same next bottlenecks: performance budgets, fuller compatibility evidence, accessibility proof, hardened Writer diagnostics, and deterministic PPT builder design.
- `docs/product/next-stage-development-plan.md` consolidates Codex and Clavue plans into the next-stage M2 execution plan with ownership, sequencing, gates, and collaboration rules.
- `docs/product/presentation-outline-contract-review.md` approves P1-07 as a fixture-only contract and lists non-blocking semantic hardening items before an Impress builder.
- `docs/product/china-blank-document-default-policy.md` defines Writer/Calc/Impress blank-document behavior targets before config or template edits.
- `bin/validator-readiness.sh tmp/validator-readiness.md` reports missing ODF Validator, Officeotron, and veraPDF assets. This is a beta-readiness blocker.
- `bin/compatibility-roundtrip.sh --format smoke --limit 9 --run-name v2-smoke-limit9` passed 27/27 conversion samples: 9 DOCX, 9 XLSX, and 9 PPTX.
- `docs/compatibility/smoke-manifest.tsv` now pins the 27-sample smoke set so future compatibility smoke does not depend on recursive file discovery order.
- `bin/compatibility-roundtrip.sh --manifest docs/compatibility/smoke-manifest.tsv --run-name v2-smoke-manifest` passed 27/27 manifest-selected samples.
- `bin/compatibility-roundtrip.sh --manifest docs/compatibility/smoke-manifest.tsv --limit 1 --run-name v2-smoke-manifest-limit1-label-check` passed 3/3 and confirmed manifest-mode reporting uses `Format selection: manifest`.
- `bin/compatibility-roundtrip.sh --manifest docs/compatibility/smoke-manifest.tsv --run-name v2-smoke-fidelity-manifest-final` passed 27/27 and now records scenario notes, package metrics, size sanity, structure sanity, validator status, and advisory fidelity warnings. It surfaced one useful advisory: the embedded-font PPTX expands to a 62 MB intermediate ODP.
- `gmake UITest_workbench_smoke` completed successfully and exercised the active source Workbench scenario buttons.
- `bin/gui-smoke-timing.sh` passed fresh-profile process/timing smoke for Start Center, Writer, Calc, and Impress. This proves launch survival only, not GUI usability or accessibility.
- `tmp/gui-smoke-timing/m2-gui-budget-startcenter/report.md` passed with separate survival, timeout, and timing-budget statuses.
- `tmp/compatibility-layout-evidence.md` records one DOCX, one XLSX, and one PPTX durable layout-proxy evidence seed. It is not pixel fidelity proof.
- `bin/v2-p0-gates.sh v2-p0-tiered-contracts` passed and now labels gate tiers as `alpha-hard`, `alpha-advisory`, and `beta-blocker-advisory`.
- `bin/v2-p0-gates.sh m2-codex-gui-layout-evidence` passed all alpha-hard and advisory gates after M2-03/M2-05.
- `bin/v2-p0-gates.sh` now uses the curated 27-sample manifest instead of recursive `--format smoke --limit 3`.
- `docs/architecture/intelligent-office-implementation-boundaries.md` records the Clavue-reviewed Writer preview-only analyzer boundary and the separate deterministic PPT generation boundary.
- A follow-up read-only Clavue review approved the next alpha implementation round with caveats: compatibility remains conversion/heuristic evidence, validators must become beta-hard, P1-04 Writer analyzer is the highest-risk next task, and P1-03 should precede implementation.
- `bin/workbench-accessibility-check.sh tmp/workbench-accessibility-check.md` passed and records static Start Center accessibility expectations; manual VoiceOver, resize, high-contrast, and keyboard traversal remain beta evidence.
- Clavue owns P1-04 locally. Codex must not edit the Writer analyzer implementation files until Clavue reports back.
- Codex parallel slice is now source hygiene, validator asset inventory, and compatibility corpus expansion planning.
- `bin/validator-readiness.sh tmp/validator-readiness.md` reports Java and wrappers present but all three validator assets missing; `--strict` correctly fails as beta-hard evidence.
- `bin/compatibility-manifest-audit.sh --manifest docs/compatibility/smoke-manifest.tsv --report tmp/compatibility-manifest-audit-smoke-manifest.md` passed with 27 entries, 27/27 scenario notes, and no warnings.
- `docs/compatibility/corpus-expansion-plan.md` defines the beta corpus lanes and evidence requirements without changing import/export engines.
- `bin/v2-upgrade-dashboard.sh tmp/v2-upgrade-dashboard.md` reports 6,194 compatibility samples exist in QA trees; the current alpha smoke is curated but still not a full representative matrix.
- `bash -n bin/*.sh` passed.
- `bash -n bin/*.sh && bin/intelligent-office-readiness.sh tmp/intelligent-office-readiness.md && bin/v2-upgrade-dashboard.sh tmp/v2-upgrade-dashboard.md && make CppunitTest_sw_uwriter` passed after the Writer analyzer preview action-mode and report updates.
- `gmake -C /Users/lu/kdoffice-src CppunitTest_sw_uwriter` passed after M2-04 hardening; it now covers the full Writer analyzer long-paragraph diagnostic contract, repeated-run stability, and preservation of both initially unmodified and initially modified document states.
- Clavue completed M2-07 source implementation under `sd/` after the design document. Observed surfaces include `sd/inc/PresentationOutline.hxx`, `sd/source/ui/tools/PresentationOutlineBuilder.cxx`, `sd/Library_sd.mk`, and `sd/qa/unit/misc-tests.cxx`. Validation log for `CppunitTest_sd_misc_tests` shows the builder tests ran and final status was `OK (29)`.
- `docs/product/executive-operating-model.md` now defines Codex as product-control owner and Clavue as bounded source implementer/reviewer.
- `bin/clavue-passive-monitor.sh tmp/clavue-passive-monitor.md` reports no active office-related Clavue build/test/process descendants at the latest snapshot, so Codex can update governance and reports without interrupting Clavue.
- `docs/product/m2-07-presentation-outline-builder-review.md` records Codex's read-only M2-07 review and final keep decision after the speaker-notes unsupported diagnostic assertion was added.
- `docs/product/service-mode-policy.md` records P2-04 offline/local/private/cloud boundaries and keeps plugin runtime/provider work blocked until signing, consent, policy, and failure-isolation gates exist.
- `docs/product/engine-capability-upgrade-plan.md` records the M3 direction: document trust first, task acceleration second, AI optional/preview-first, with domain packs and workflow-compression gates.
- `docs/architecture/engine-capability-platform-architecture.md` defines the proposed contract spine, document intelligence core, module adapters, capability registry, execution orchestrator, plugin/provider isolation, UI layer, and policy layer.
- Clavue accepted the executive injection in `tmp/clavue-executive-injection.md`, completed the M2-07 speaker-notes diagnostic revision, and produced the M2-06 Workbench accessibility evidence packet.
- Codex read-only closeout confirms M2-07 is accepted: `sd/qa/unit/misc-tests.cxx` now asserts `SpeakerNotesUnsupported`, `mbSpeakerNotesMaterialized == false`, and diagnostic name `speaker-notes-unsupported`; `CppunitTest_sd_misc_tests` log ends with `OK (29)`.
- `docs/accessibility/workbench-accessibility-evidence-m2-06.md` records M2-06 evidence and keeps live Tab/Shift+Tab, Enter/Space, VoiceOver, high-contrast, resize, and missing-template fallback review as beta blockers.
- `bin/v2-beta-gates.sh p2-05-beta-gate-promotion` wrote `tmp/v2-beta-gates/p2-05-beta-gate-promotion.md` and correctly failed beta status with 3 blockers: strict validator readiness, strict source hygiene, and live Workbench accessibility. Retry attempts for `bash -n ./bin/v2-beta-gates.sh`, `bash -n ./bin/v2-upgrade-dashboard.sh`, and `./bin/v2-upgrade-dashboard.sh tmp/v2-upgrade-dashboard.md` were denied by the current tool permission classifier, so syntax validation and dashboard regeneration remain explicitly unverified in this session.

## Agent Methodology Applied

The operating model borrows only the useful parts of the referenced agent systems:

- From `agent-skills`: use a lifecycle gate of define, plan, build, verify, review, ship. Each round must have a spec, atomic task, proof command, and review gate.
- From `gbrain`: use brain-first context and durable written memory. This repo's memory is the `AUTORESEARCH_*` docs plus generated reports under `tmp/`; decisions should be appended as evidence, not kept in chat only.
- From `gbrain` minion routing: deterministic work should be shell scripts and reports; judgment work should go to Codex/Clavue review. Do not spend agent reasoning on repeatable scans that scripts can perform.
- From `gstack`: use specialist lanes and second-opinion review. Codex owns control-plane implementation, Clavue acts as independent reviewer or source-behavior owner, and every significant round gets a cross-agent check.

## Collaboration Protocol

Until Clavue team sessions are fixed, collaboration uses written handoffs and non-interactive review.

1. Codex starts each round by updating or reading this file, `AUTORESEARCH_AGENT_COORDINATION_PLAN.md`, and the latest `tmp/*` reports.
2. Codex owns scripts, dashboards, schemas, and gate semantics.
3. Clavue owns independent review of source-behavior risk, GUI/workbench behavior, and implementation-entry audits.
4. Use `clavue -p --permission-mode dontAsk` for read-only review prompts when a second opinion is needed.
5. Do not let Codex and Clavue edit the same module or file family in the same round.
6. Do not edit `workdir/`, `instdir/`, `test-install/`, `tmp/`, `autom4te.cache/`, `config_*`, `config.log`, `config.status`, `autogen.lastrun`, or `autogen.lastrun.bak` as source.
7. Prefer source edits under `/Users/lu/kdoffice-src` for product behavior; update this wrapper only for planning, scripts, reports, and build orchestration.

## Codex / Clavue Split

| Lane | Codex Primary | Clavue Primary | Shared Gate |
| --- | --- | --- | --- |
| Control tower | P0/P1/P2 gate scripts, dashboard, source hygiene, report semantics | Review whether gates create false confidence | No "pass" may hide skipped blockers |
| Workbench | Review verification output and add gate integration | Verify Start Center scenario dispatch, fallback behavior, keyboard path, visual/a11y risks | `gmake UITest_workbench_smoke` plus manual/fresh-profile evidence |
| Compatibility lab | Curated manifests, validator readiness, smoke scaling, report format | Review sample representativeness and import/export risk before source changes | Expanded DOCX/XLSX/PPTX matrix before engine edits |
| Intelligent office | Schemas, fixtures, contract tests, dashboard integration | Source insertion audit for Writer analyzer and plugin boundaries | Preview-only analyzer before apply path |
| PPT generation | Gate design and acceptance metrics | Audit current Writer-to-Impress flow and propose separate deterministic helper | Preserve legacy `.uno:SendOutlineToStarImpress` path |
| Release hygiene | Source-only status and strict release mode | Review generated/source separation before commit/release | Strict hygiene only for beta/release candidate |

## Hard Rules

- Trust before novelty: open/edit/save/export/recover compatibility outranks AI, redesign, and visual polish.
- Scenario-first, module-second: optimize for weekly report, meeting minutes, resume, budget, schedule, work-report PPT, teaching PPT, and PPT draft generation.
- Office-format compatibility is a lab, not copywriting.
- AI must be workflow compression, not a generic chatbot.
- Offline mode must remain first-class.
- Missing validators are beta blockers, not quality passes.
- A GUI process staying alive is not proof that the GUI is usable.

## P0 Todolist

| ID | Task | Owner | Status | Acceptance Gate |
| --- | --- | --- | --- | --- |
| P0-01 | Separate alpha, beta, and release gate semantics in the control docs/scripts. | Codex | Done | `tmp/v2-p0-gates/v2-p0-tiered-contracts.md` labels hard, advisory, and beta-blocker-advisory gates. |
| P0-02 | Run validator readiness and treat missing assets as beta blockers. | Codex | Done | `tmp/validator-readiness.md` records validator asset state; beta blocker remains open until ODF Validator, Officeotron, and veraPDF are all trusted and callable. |
| P0-03 | Expand compatibility smoke from 3 samples per format to 9 per format. | Codex | Done | `tmp/compatibility-runs/v2-smoke-limit9/report.md` passed 27/27 samples. |
| P0-04 | Add curated compatibility manifest design before changing import/export engines. | Codex | Done | `tmp/compatibility-runs/v2-smoke-manifest/report.md` passed 27/27 manifest-selected samples. |
| P0-05 | Prove Workbench scenario-button behavior, not only template packaging. | Clavue | Done | `gmake UITest_workbench_smoke` completed successfully against active source. |
| P0-06 | Run fresh-profile GUI timing smoke for Start Center, Writer, Calc, and Impress. | Clavue | Done | `tmp/gui-smoke-timing/v2-gui-*/report.md` reports all four modes passed process survival. |
| P0-07 | Add diagnostic/plugin schema fixture tests. | Codex | Done | `bin/intelligent-contract-fixtures.sh` validates good/bad JSON fixtures for both schemas. |
| P0-08 | Write the Writer preview-only analyzer implementation boundary. | Clavue | Done | `docs/architecture/intelligent-office-implementation-boundaries.md` documents source insertion points, read-only APIs, and undo/preview constraints. |
| P0-09 | Audit PPT generation as a separate deterministic subsystem. | Clavue | Done | `docs/architecture/intelligent-office-implementation-boundaries.md` maps the current RTF outline path and proposes a separate normalized-model helper without replacing the legacy path. |
| P0-10 | Keep source reviews using `bin/source-status.sh`, not raw `git status`. | Codex | Ongoing | Every handoff mentions source-focused status and ignores generated output unless intentional. |

## P1 Todolist

| ID | Task | Owner | Status | Acceptance Gate |
| --- | --- | --- | --- | --- |
| P1-01 | Implement compatibility manifest support in `bin/compatibility-roundtrip.sh`. | Codex | Done | `bin/compatibility-roundtrip.sh --manifest docs/compatibility/smoke-manifest.tsv` runs a fixed manifest independent of recursive sample discovery. |
| P1-02 | Add simple fidelity heuristics to compatibility reports. | Codex | Done | `tmp/compatibility-runs/v2-smoke-fidelity-manifest-final/report.md` includes output existence, validator status, scenario notes, package metrics, size sanity, structure sanity, and advisory warnings. |
| P1-03 | Add Workbench keyboard/accessibility review checklist. | Codex | Done | `docs/accessibility/workbench-accessibility-checklist.md` and `tmp/workbench-accessibility-check.md` record static checks plus manual VoiceOver, keyboard, resize, and high-contrast requirements. |
| P1-04 | Implement the first Writer diagnostic analyzer in preview-only mode. | Clavue | Done | `make CppunitTest_sw_uwriter` passed; analyzer returns contract-shaped preview diagnostics, is stable across repeated runs, and does not mutate document modified state. |
| P1-05 | Add local/offline plugin manifest validator before any provider integration. | Codex | Done | `bin/plugin-manifest-validator.sh --self-test --report tmp/plugin-manifest-validator.md` passes valid offline manifests and rejects invalid/provider/unsafe-command/missing-failure-message cases with clear Chinese-facing failure behavior requirements. |
| P1-06 | Define China office blank-document default policy. | Codex | Done | `docs/product/china-blank-document-default-policy.md` lists Writer/Calc/Impress behavior targets before config/module changes. |
| P1-07 | Build a PPT generation normalized outline model. | Clavue | Done | `bin/intelligent-contract-fixtures.sh tmp/intelligent-contract-fixtures.md` passed; schema fixture covers title, ordered slides, sections, bullets, notes, source refs, and editable placeholder intent. |
| P1-08 | Add validator asset inventory and compatibility corpus expansion plan. | Codex | Done | `tmp/validator-readiness.md`, `tmp/validator-readiness-strict.md`, `docs/compatibility/corpus-expansion-plan.md`, and `tmp/compatibility-manifest-audit-smoke-manifest.md` document validator blockers and corpus expansion without touching Writer analyzer files. |

## P2 Todolist

| ID | Task | Owner | Status | Acceptance Gate |
| --- | --- | --- | --- | --- |
| P2-01 | Add true screenshot/PDF-rendered visual comparison for selected compatibility samples. | Codex | Todo | At least one DOCX, XLSX, and PPTX sample has rendered visual evidence; M2-05 layout-proxy evidence does not close this. |
| P2-02 | Implement one-by-one diagnostic fix action with undo grouping. | Single owner per round | Todo | Fix one issue, undo restores prior document state. |
| P2-03 | Add deterministic PPT helper that creates editable slides from normalized outline data. | Single owner per round | Todo | Generated deck opens, slide count matches model, placeholders are editable. |
| P2-04 | Add service-mode boundary for offline/local/private/cloud capabilities. | Codex | Done | `docs/product/service-mode-policy.md` defines offline/local/private/cloud boundaries before cloud/provider code and requires the plugin validator to remain local/offline by default. |
| P2-05 | Promote beta hard gates. | Codex | In progress | `bin/v2-beta-gates.sh <run-name>` remains expected to fail until strict validator readiness, strict source hygiene, and live Workbench accessibility are resolved. Source hygiene failures now point to the BETA-03 release packet instead of a vague dirty-tree complaint. |
| BETA-03 | Make strict source hygiene operationally actionable. | Clavue | Done | `docs/product/source-hygiene-release-packet.md` plus `tmp/source-hygiene-report.md` classify source review/stage, generated/local clean-or-ignore, config/autoconf artifacts, install/test/release artifacts, and unresolved human-decision items; strict mode remains honest and failing while any working-tree entry exists. |
| BETA-04 | Operationalize validator asset readiness. | Clavue | Deferred | `docs/compatibility/validator-assets-release-packet.md` records ODF Validator provenance/checksum and defers Officeotron/veraPDF until trusted exact assets are acquired; strict validator readiness remains honest and failing until all three validators are callable. |

## M3 Engine Capability Todolist

| ID | Task | Owner | Status | Acceptance Gate |
| --- | --- | --- | --- | --- |
| M3-00 | Consolidate engine capability roadmap and platform architecture. | Codex | Done | `docs/product/engine-capability-upgrade-plan.md` and `docs/architecture/engine-capability-platform-architecture.md` define the M3 direction, contracts, gates, domain packs, and anti-goals. |
| M3-01 | Audit safe source entry points for the engine capability platform. | Clavue | Done | `docs/architecture/engine-capability-source-entry-audit.md` maps registry, shared contracts, Writer apply adapter, Calc diagnostics, Workbench state surfaces, and plugin/provider isolation without implementing runtime code. |
| M3-02 | Add schema fixtures for preview action, apply plan, evidence record, capability registry, provider request, and document snapshot. | Codex | Done | `tmp/intelligent-contract-fixtures.md` passed 18 fixtures across 9 schemas. |
| M3-03 | Design built-in capability registry stub before UI/provider work. | Single owner per round | Done | `docs/architecture/engine-capability-registry-stub-design.md` defines built-in/offline registry states, source constraints, preview/apply separation, budget/evidence fields, and policy blockers without runtime plugin loading. |
| M3-04 | Accept Writer one-by-one apply guardrail packet before implementation. | Single owner per round | Done | `docs/architecture/engine-capability-writer-apply-guardrail-m3-04.md` names Writer source surfaces, preconditions, one-action/one-undo semantics, modified-state tests, rollback evidence, and explicitly blocks Writer apply implementation until a separate accepted source round. |
| M3-05 | Add first read-only Calc diagnostic seed. | Single owner per round | Todo | Repeated diagnostics are stable and do not mutate modified state or undo state. |
| M3-06 | Expand deterministic Impress draft workflow. | Single owner per round | Todo | Editable slides, text-fitting diagnostics, PPTX export, legacy Writer-to-Impress path preserved. |
| M3-07 | Design Workbench evidence console states. | Single owner per round | Todo | Workbench can represent available, preview-only, blocked-by-policy, needs-document, beta-disabled, and requires-proof states with accessible labels. |
| M3-08 | Design local/offline plugin runtime prerequisites. | Codex with Clavue review | Todo | Signing, allowlist, disable-all, quarantine, crash isolation, service-mode enforcement, and no-mutation-on-failure tests are specified before runtime implementation. |

## M2 Next-Stage Todolist

| ID | Task | Owner | Status | Acceptance Gate |
| --- | --- | --- | --- | --- |
| M2-01 | Review and lock P1-07 presentation outline contract before builder work. | Codex review, Clavue responds | Done | `docs/product/presentation-outline-contract-review.md` keeps P1-07 and lists semantic builder constraints; `bin/intelligent-contract-fixtures.sh tmp/intelligent-contract-fixtures.md` passes. |
| M2-02 | Define China blank-document default policy. | Codex | Done | `docs/product/china-blank-document-default-policy.md` lists Writer/Calc/Impress behavior targets before `officecfg` or template edits. |
| M2-03 | Add GUI timing budget thresholds. | Codex | Done | `tmp/gui-smoke-timing/m2-gui-budget-startcenter/report.md` reports survival pass, timeout pass, and timing-budget pass with `--wait 12 --timeout 20 --max-elapsed 20`. |
| M2-04 | Harden Writer analyzer tests. | Clavue | Done | `gmake -C /Users/lu/kdoffice-src CppunitTest_sw_uwriter` passed; test now proves full diagnostic stability plus modified/unmodified initial-state preservation. |
| M2-05 | Add compatibility visual/layout evidence seed. | Codex | Done | `tmp/compatibility-layout-evidence.md` records one DOCX, one XLSX, and one PPTX layout proxy evidence path plus limitations; true screenshot/PDF rendering remains follow-up. |
| M2-06 | Produce Workbench accessibility evidence packet. | Clavue | Done | `docs/accessibility/workbench-accessibility-evidence-m2-06.md` records static/source/UITest evidence plus explicit live beta blockers; `bin/workbench-accessibility-check.sh tmp/workbench-accessibility-check.md` and `gmake -C /Users/lu/kdoffice-src UITest_workbench_smoke` passed in Clavue handoff. |
| M2-07 | Design and seed internal presentation outline builder before UI/provider work. | Clavue | Done | Speaker-notes unsupported diagnostic assertion added to `sd/qa/unit/misc-tests.cxx`; `gmake -C /Users/lu/kdoffice-src CppunitTest_sd_misc_tests` passed with `OK (29)`. Codex read-only review found no UI/provider/plugin/export or legacy Writer-to-Impress scope creep. |
| M2-08 | Keep current alpha P0 wrapper green. | Codex | Done | `tmp/v2-p0-gates/m2-codex-gui-layout-evidence.md` passed all alpha-hard and advisory gates after M2-03/M2-05, including 27-sample roundtrip, GUI budget, and layout evidence. |

## Round Template

Each implementation round must use this template:

- Round name:
- Owner:
- Reviewer:
- Target workflow:
- Bottleneck:
- Primary metric:
- Guardrails:
- Source surfaces changed:
- Generated surfaces intentionally regenerated:
- Verification commands:
- Result:
- Keep/reject decision:
- Next bottleneck:

## Current Executive Queue

Codex is acting as product-control owner. Clavue is the bounded source implementer/reviewer. M2 is now evidence-complete for alpha, but beta blockers remain.

Current active split:

- Codex owns M3 roadmap, future M3-04 round-packet/guardrail acceptance, dashboard/readiness gates, beta gate promotion, service-policy enforcement, and read-only review of Clavue handoffs.
- Clavue completed M3-01 source-entry audit, M3-02 contract fixtures are accepted, and M3-03 registry stub design is accepted/completed as documentation-only control-plane work.
- Next high-value work is a separately accepted M3-04 guardrail/round packet plus continuing beta hardening: acquire trusted exact Officeotron and veraPDF assets, complete live Workbench accessibility review, expand the representative compatibility matrix, and execute the source-hygiene release packet until strict mode passes.
- M3-04 is a guardrail/acceptance packet, not implementation: module-owned Writer apply code, document mutation, undo wiring, UI dispatch, or runtime registry integration is blocked until that packet is reviewed and accepted.
- Do not implement runtime registry code, UI commands, provider/plugin runtime, import/export, Writer apply path, Calc diagnostics, Workbench UI, or document mutation without a new accepted round packet.

Stop/go rules:

- Keep: targeted test passes, no scope creep, source surfaces match assignment, limitations are explicit.
- Revise: correct direction but missing assertion, missing handoff, or unclear limitation.
- Stop: UI/provider/export/plugin/runtime scope appears inside M2-07, legacy `.uno:SendOutlineToStarImpress` is changed, or another owner's file family is edited without coordination.
- Defer: useful work exists but does not address validator assets, live accessibility review, representative compatibility evidence, service-policy enforcement, strict source hygiene, or beta gate promotion.

Clavue sequencing advice:

- M3-01 is accepted as an audit-only round, M3-02 contract fixtures are accepted, and M3-03 built-in local/offline registry stub design is accepted/completed; future runtime, UI, provider, plugin, or apply-path work requires a new accepted round packet.
- M2-07 is accepted; future bullet-level, two-column, table/image, or notes-materialization work must be a separate single-owner round.
- M2-06 evidence is accepted for alpha; beta still requires live keyboard traversal, VoiceOver, resize, high-contrast, and missing-template fallback review.
- Do not add UI commands, AI/provider calls, plugin runtime, capability registry code, apply-path mutations, PPTX export changes, or legacy Writer-to-Impress changes without a new accepted round packet.
- Use `tmp/clavue-current-directive.md` as the current file-based directive if direct session injection is unavailable.

Verification budget:

- `bash -n bin/*.sh`
- `bin/intelligent-contract-fixtures.sh tmp/intelligent-contract-fixtures.md`
- `bin/workbench-accessibility-check.sh tmp/workbench-accessibility-check.md`
- `bin/validator-readiness.sh tmp/validator-readiness.md`
- `bin/validator-readiness.sh --strict tmp/validator-readiness-strict.md` should fail until assets are installed.
- `bin/compatibility-manifest-audit.sh --manifest docs/compatibility/smoke-manifest.tsv --report tmp/compatibility-manifest-audit-smoke-manifest.md`
- `bin/compatibility-layout-evidence.sh --report tmp/compatibility-layout-evidence.md`
- `bin/clavue-passive-monitor.sh tmp/clavue-passive-monitor.md`
- `gmake -C /Users/lu/kdoffice-src CppunitTest_sd_misc_tests`
- `gmake UITest_workbench_smoke`
- `Writer analyzer modified-state stability test`
- `Normalized PPT outline model fixture test`
- `bin/compatibility-roundtrip.sh --manifest docs/compatibility/smoke-manifest.tsv --run-name v2-smoke-fidelity-manifest-final`
- `bin/v2-upgrade-dashboard.sh tmp/v2-upgrade-dashboard.md`
- `bin/v2-beta-gates.sh p2-05-beta-gate-promotion` should fail in the current state; after validator assets, strict source hygiene, and live Workbench accessibility evidence are complete, revise the manual blocker in the wrapper before expecting a pass.
- `bin/source-hygiene-report.sh tmp/source-hygiene-report.md`
