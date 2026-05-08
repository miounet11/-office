# Engine Capability Source Entry Audit

Generated: 2026-04-28

## Executive verdict

M3-01 is approved to proceed only to M3-02 contract fixtures and control-plane readiness work.

Do not start runtime registry implementation, provider calls, runtime plugin loading, UI commands, import/export changes, Workbench source changes, Calc mutation, Writer apply mutation, or replacement of legacy Writer-to-Impress behavior yet. The safe next step is to make the engine capability contract spine measurable with schema fixtures and reports, then use a later single-owner round for each source implementation surface.

The platform direction remains sound if every capability follows the rule from `docs/product/engine-capability-upgrade-plan.md`: document trust first, task acceleration second, AI optional, preview-first, and policy-controlled.

## Scope and non-goals

This audit maps safe source entry points and blockers for the engine capability platform. It is not an implementation design freeze and does not introduce runtime code.

In scope:

- Capability Registry source placement risks.
- Shared contract ownership options.
- Writer Apply adapter boundaries.
- Calc Diagnostics read-only seed boundaries.
- Impress deterministic builder boundaries.
- Workbench capability-state display surfaces.
- Plugin and Provider isolation blockers.
- Verification expectations for M3-02.

Out of scope:

- No Writer analyzer edits.
- No Writer Apply implementation.
- No Calc Diagnostics implementation.
- No Workbench UI implementation.
- No source registry stub implementation.
- No Plugin runtime implementation.
- No Provider implementation.
- No import/export filter edits.
- No UI command additions.
- No replacement of legacy `.uno:SendOutlineToStarImpress` behavior.

## Source-entry map

| Area | Candidate source entry | Current evidence | Safe next action | Blocked action |
| --- | --- | --- | --- | --- |
| Contract spine | `docs/schemas/`, `docs/schemas/fixtures/`, `bin/intelligent-contract-fixtures.sh` | `docs/architecture/engine-capability-platform-architecture.md` defines `DocumentSnapshot`, `Diagnostic`, `PreviewAction`, `ApplyPlan`, `CapabilityManifest`, `ProviderRequest`, and `EvidenceRecord`. | Add M3-02 schema fixtures for missing contracts. | Choosing a compiled shared C++ library before dependency audit. |
| Capability Registry | Future shared layer around `sfx2`, `officecfg`, and `configmgr` | Architecture identifies registry responsibilities: module scope, service mode, permissions, UI state, budgets, and apply support. | Design built-in/local/offline registry contract and fixture output. | Runtime Plugin loading, Provider enablement, or UI hardcoding. |
| Writer diagnostics | `/Users/lu/kdoffice-src/sw/inc/IntelligentWriterAnalyzer.hxx` and `/Users/lu/kdoffice-src/sw/source/core/doc/IntelligentWriterAnalyzer.cxx` | Existing `sw::intelligent::AnalyzeWriterDocumentPreview(const SwDoc&)` returns preview diagnostics without mutation. | Keep as preview-only contract evidence for M3-02 fixtures. | Editing analyzer implementation or adding apply in M3-01. |
| Writer Apply | `/Users/lu/kdoffice-src/sw/inc/docsh.hxx`, `/Users/lu/kdoffice-src/sw/source/uibase/app/docst.cxx`, future Writer module adapter | Writer document shell/app code is the likely place to preserve document lifecycle, undo, and modified-state semantics. | Define future preconditions and evidence fields in `ApplyPlan` fixtures. | Applying changes without revision checks, one undo unit, rollback proof, and repeated diagnostics. |
| Calc Diagnostics | Future `sc` module adapter using read-only `ScDocument` query-style APIs | M3 roadmap lists formula errors, suspicious blanks, hidden rows/columns, print-area overflow, and date/currency inconsistency. | Define read-only diagnostic fixture examples before source work. | Recalculation, formatting, undo-stack edits, document modified-state changes, or XLSX filter changes. |
| Impress builder | `/Users/lu/kdoffice-src/sd/source/ui/tools/PresentationOutlineBuilder.cxx` | Existing deterministic builder materializes editable title/body placeholders, clamps bullet levels, and reports unsupported speaker notes. | Treat as deterministic local builder boundary for future M3-06. | Provider calls, UI commands, PPTX export changes, or legacy Writer-to-Impress replacement. |
| Workbench | Future `sfx2` Start Center/task-card surfaces and accessibility evidence docs | Roadmap defines states: Available, Preview only, Blocked by policy, Needs document, Beta disabled, Requires compatibility proof. | Define state vocabulary and fixture evidence; keep accessible labels mandatory. | Hardcoding Provider/Plugin logic into UI cards or using color-only status. |
| Plugin | Future `extensions`, `scripting`, `desktop`, packaging/admin policy surfaces | `docs/product/service-mode-policy.md` and plugin manifest validation keep runtime blocked. | Keep manifest validation local/offline and extend fixture coverage. | Arbitrary in-process execution, unsigned plugins, missing disable-all switch, no quarantine, or document mutation. |
| Provider | Future local/private/cloud service-mode surfaces | Architecture requires explicit user action, visible context summary, scoped payload, timeout/cancellation, consent, and preview artifacts only. | Add `ProviderRequest` valid/invalid fixtures with blocked private/cloud defaults. | Cloud/private enablement, silent upload, live document handles, or direct mutation. |

## Contract spine recommendation

M3-02 should extend schema fixtures before compiled source contracts. The contract spine should remain in docs and scripts until dependency direction is proven.

Recommended M3-02 fixture set:

- `DocumentSnapshot`: module, scope, revision token, locale/language hints, redaction mode, size limit, unsupported-content summary.
- `PreviewAction`: action id, capability id, affected range/object summary, before/after summary, risk level, service mode, apply preconditions, undo support, unsupported cases, evidence record id.
- `ApplyPlan`: revision precondition, deterministic operation description, rollback requirement, undo group expectation, failure behavior.
- `Capability Registry` entry: capability id, module scope, availability state, service mode, network mode, preview/apply support, trust level, budget, blocked reason.
- `ProviderRequest`: explicit user action, visible context summary, scoped payload, timeout/cancellation, consent id for private/cloud, preview-only result.
- `EvidenceRecord`: schema version, elapsed time, budget status, diagnostic count, validator/compatibility status, failure reason, no document content by default.

Do not choose the final compiled shared-library owner in this round. `sfx2` is a plausible orchestrator because it already sits near document shell and UI state, but contract structs may need a dedicated shared library or module-owned adapters to avoid circular dependencies.

## Built-in capability registry entry point recommendation

The first Capability Registry should be built-in, local/offline, and read-only from the perspective of document content.

Minimum safe registry responsibilities:

- Report active module.
- List built-in capabilities only.
- Distinguish available, preview-only, blocked by policy, disabled, beta disabled, needs document, and requires compatibility proof.
- Report service mode and network mode.
- Report preview/apply support separately.
- Report evidence and budget requirements.
- Return explicit blocked reasons suitable for Workbench display.

The registry must not:

- Load runtime plugins.
- Enable Provider calls.
- Accept arbitrary extension code.
- Perform document mutation.
- Let UI commands bypass service-mode policy, preview contracts, or undo grouping.

## Writer diagnostics/apply path audit

Current Writer intelligent code is preview-only. `sw/inc/IntelligentWriterAnalyzer.hxx` exposes `sw::intelligent::AnalyzeWriterDocumentPreview(const SwDoc&)`, returning diagnostic-shaped data for Writer without mutation. That surface is suitable as evidence for the diagnostic side of the contract spine, not as an apply engine.

Future Writer Apply work should be a separate single-owner round. It should likely enter through Writer document shell/module adapter code rather than direct analyzer mutation, because apply must coordinate document revision, undo grouping, modified-state restoration, rollback, and repeated diagnostics.

Future Writer Apply requirements:

- User sees a preview before every mutation.
- Apply rejects if the document revision changed after preview.
- One accepted user action creates one undo unit.
- Failure either rolls back or leaves the document unchanged.
- Undo restores prior document state.
- Both initially-modified and initially-unmodified documents are covered by tests.
- Repeated diagnostics after apply are deterministic.
- Provider or Plugin output never receives live mutation handles.

M3-01 must not edit the Writer analyzer or apply source.

## Calc read-only diagnostic seed audit

Calc should enter engine capability work through read-only diagnostics first. The safest seed is a module adapter that queries document state and returns diagnostics, not fixes.

Candidate first diagnostics:

- Formula error cells.
- Suspicious blank ranges.
- Hidden rows/columns.
- Print-area overflow.
- Date/currency inconsistency.

Required constraints:

- Use read-only `ScDocument` query-style access.
- Do not recalculate.
- Do not format cells.
- Do not create undo actions.
- Do not change modified state.
- Do not touch XLSX import/export paths.
- Prove repeated-run stability with the same document state.

M3-02 can represent these as fixture examples before any `sc` source work begins.

## Impress deterministic builder boundary audit

The existing deterministic builder in `/Users/lu/kdoffice-src/sd/source/ui/tools/PresentationOutlineBuilder.cxx` is the right reference boundary for future Impress draft expansion. It operates on normalized outline data and produces local editable slides. The current source also reports unsupported speaker notes rather than pretending notes are materialized.

Safe future expansion areas:

- Placeholder editability evidence.
- Title/body placeholder materialization checks.
- Bullet-depth diagnostics.
- Text-fitting diagnostics.
- Stable unsupported diagnostics for speaker notes until notes are intentionally implemented.
- PPTX export verification as evidence after builder work, not in this audit.

Blocked areas:

- No Provider calls.
- No Plugin execution.
- No UI command path in M3-01.
- No PPTX export engine changes.
- No replacement of legacy `.uno:SendOutlineToStarImpress` or Writer outline flow.

## Workbench/evidence state surface audit

Workbench should eventually show capability state and trust evidence, but M3-01 should only define state vocabulary and source-entry risks.

Recommended states:

- Available.
- Preview only.
- Blocked by policy.
- Needs document.
- Beta disabled.
- Requires compatibility proof.
- Provider unavailable.
- Plugin runtime disabled.
- Budget exceeded.
- Unsupported content.

Workbench must receive state from a registry/policy surface, not hardcode Provider or Plugin logic in UI cards. Every visible state needs accessible text, not color-only presentation. Future UI work should verify keyboard traversal, screen-reader labels, resize behavior, high-contrast behavior, and missing-template fallback before any beta claim.

## Provider/plugin isolation and policy blockers

Plugin and Provider execution must remain blocked until isolation and policy gates are proven.

Plugin blockers:

- Signing/trust model.
- Allowlist.
- Disable-all switch.
- Quarantine.
- Crash isolation.
- Service-mode enforcement.
- Scoped payloads only.
- No live document object access.
- No document mutation on failure.
- Clear Chinese-facing failure behavior.

Provider blockers:

- Explicit user action.
- Visible selected-context summary.
- Local/offline default.
- Private/cloud disabled until consent and admin policy exist.
- No silent whole-document upload.
- Timeout and cancellation.
- Preview artifacts only.
- Local evidence without document content by default.

The first registry and fixture work may describe blocked private/cloud capabilities, but it must not enable them.

## Verification Expectations

M3-01 verification is documentation-focused. The required check is that this audit exists and contains the major handoff surfaces:

```sh
test -s docs/architecture/engine-capability-source-entry-audit.md && rg -n 'Capability Registry|Writer Apply|Calc Diagnostics|Workbench|Plugin|Provider|Verification' docs/architecture/engine-capability-source-entry-audit.md
```

M3-02 should then verify contract coverage with:

```sh
bin/intelligent-contract-fixtures.sh tmp/intelligent-contract-fixtures.md
```

A future dashboard update may also run:

```sh
bin/v2-upgrade-dashboard.sh tmp/v2-upgrade-dashboard.md
```

## M3-02 Handoff Checklist

Proceed to M3-02 with these constraints:

- Add contract fixtures before source runtime work.
- Include valid and invalid fixtures for `DocumentSnapshot`, `PreviewAction`, `ApplyPlan`, `Capability Registry`, `ProviderRequest`, and `EvidenceRecord`.
- Keep built-in capabilities discoverable without Plugin runtime loading.
- Keep private/cloud Provider capabilities blocked by policy.
- Expose blocked/preview-only/available state as data, not UI hardcoding.
- Include evidence records that do not store document content by default.
- Keep Writer Apply, Calc Diagnostics implementation, Workbench UI, Provider integration, Plugin runtime, import/export changes, and `.uno:SendOutlineToStarImpress` changes out of M3-02 unless a later approved round explicitly scopes them.
