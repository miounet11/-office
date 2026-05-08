# Engine Capability Platform Architecture

Generated: 2026-04-28

This architecture defines how 可圈office can support richer built-in features and AI-assisted workflows while preserving office-suite trust.

## Architecture Layers

| Layer | Responsibility | Likely Surfaces |
| --- | --- | --- |
| Contract spine | Schemas and fixture gates for diagnostics, previews, apply plans, capability manifests, provider requests, evidence, and budgets. | `docs/schemas/`, `docs/schemas/fixtures/`, `bin/intelligent-contract-fixtures.sh` |
| Document intelligence core | Shared non-UI contracts for immutable snapshots, diagnostics, preview plans, apply plans, evidence records, and performance budgets. | Future shared layer after dependency audit, likely `sfx2/` or a dedicated source library. |
| Module adapters | Read-only extractors and deterministic apply adapters for Writer, Calc, and Impress. | `sw/`, `sc/`, `sd/` |
| Capability registry | Built-in capability catalog, module scope, service mode, permissions, UI state, budget, and apply support. | `sfx2/`, `officecfg/`, `configmgr/` after audit |
| Execution orchestrator | Enforces preview-before-apply, cancellation, revision checks, one undo group, rollback, and failure isolation. | `sfx2` document-shell level plus module apply adapters |
| Provider/plugin isolation | Future out-of-process or sandboxed execution. Plugins receive scoped payloads and return preview artifacts only. | `extensions/`, `scripting/`, `desktop/`, packaging policy after blockers |
| UI layer | Renders task cards, diagnostics, previews, consent text, evidence, and failure states. | `sfx2/`, `cui/`, `vcl/`, module `uiconfig/ui/` |
| Packaging/admin policy | Signing, allowlist, disable-all, quarantine, service settings, enterprise policy. | `desktop/`, `extensions/`, `scp2/`, `instsetoo_native/`, `officecfg/` |

## Core Contracts

### DocumentSnapshot

Immutable document view used by analyzers and providers.

Required properties:

- module: Writer, Calc, Impress, Draw, PDF/export
- scope: document, selection, range, sheet, slide, object
- revision token
- locale and language hints
- redaction mode
- size limit
- unsupported-content summary

### Diagnostic

Current diagnostic schema remains the base.

Required properties:

- stable id
- module
- severity
- Chinese-facing message
- location
- confidence
- actions
- evidence
- unsupported reason when applicable

### PreviewAction

Preview-first user-visible proposal.

Required properties:

- action id
- capability id
- affected range/object summary
- before/after summary
- risk level
- service mode
- apply preconditions
- undo group support
- unsupported cases
- evidence record id

### ApplyPlan

Deterministic operation plan owned by the module.

Rules:

- rejected if document revision changed after preview
- one accepted user action equals one undo unit
- partial failure must rollback or leave one clean undo entry
- provider/plugin output cannot contain live mutation handles

### CapabilityManifest

Describes built-in and future plugin capabilities.

Required properties:

- capability id
- module scope
- service mode
- network mode
- required permissions
- preview support
- apply support
- budget
- trust level
- isolation mode
- failure behavior

### ProviderRequest

Future AI/local/private/cloud request contract.

Rules:

- explicit user action only
- visible context summary
- no live document object
- scoped payload
- timeout and cancellation
- consent id for private/cloud
- result returns preview artifacts only

### EvidenceRecord

Local proof attached to a run.

Required properties:

- capability id
- schema version
- elapsed time
- budget status
- diagnostic count
- validator/compatibility status when relevant
- failure reason
- no document content by default

## Execution State Machine

```text
Idle
-> Document Opened
-> Task Selected
-> Capability Check
-> Policy Gate
-> Engine Availability Gate
-> Analyze
-> Preview
-> Await User Review
-> Apply One / Apply And Next / Fix All Preview / Reject
-> Verify Result
-> Evidence Record
-> Return To Task Queue
```

Blocked states:

- blocked by policy
- preview-only
- compatibility proof missing
- AI unavailable
- source changed since preview
- budget exceeded
- undo unavailable
- unsupported content

## Performance Rules

- No heavy analyzer work on the UI thread beyond a small dispatch window.
- Every long-running capability must be cancellable.
- Snapshot size must be bounded.
- Each capability declares timeout and memory budget.
- Repeated analyzer runs must be deterministic.
- Budget failures produce local evidence, not silent degradation.

## Implementation Sequence

1. Harden contracts and fixtures.
2. Add capability registry design and built-in-only stub.
3. Expand read-only analyzers: Writer, then Calc, then Impress.
4. Add preview UI without apply/provider calls.
5. Add one deterministic local Writer apply path with undo/rollback tests.
6. Expand deterministic non-AI workflows: PPT builder, formatting fixes, compatibility diagnostics, accessibility checks.
7. Design local/offline plugin runtime after signing/trust prerequisites.
8. Design local provider path before private/cloud.
9. Keep private/cloud blocked until consent, admin policy, scoped context, audit-without-content, and failure isolation are proven.

## Anti-Goals

- No generic chatbot detached from document context.
- No cloud dependency for core editing, save, export, print, templates, or compatibility workflows.
- No direct document mutation by plugins or providers.
- No silent whole-document upload.
- No arbitrary in-process plugin execution.
- No replacement of the legacy Writer-to-Impress RTF outline path.
- No import/export filter edits without a concrete failing sample.
- No telemetry, analytics, training upload, or remote evidence collection.
- No UI command that bypasses registry, service-mode policy, preview contracts, or undo grouping.

## First Source Audit Questions

Clavue should answer these before implementation:

- Where can a built-in capability registry live without pulling module internals into UI code?
- Which shared library can own contract structs without creating circular dependencies?
- How should Writer expose the first one-by-one apply adapter while preserving undo grouping?
- Which Calc read-only APIs can support formula/range/hidden-row diagnostics without mutation?
- Which Workbench surfaces can show capability states without hardcoding provider logic?
- Which future plugin runtime surfaces can enforce isolation, signing, and disable-all before execution?
