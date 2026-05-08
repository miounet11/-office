# M3-04 Writer One-by-One Apply Guardrail Packet

Generated: 2026-04-29

## Executive verdict

M3-04 accepts only a documentation and acceptance guardrail for future Writer one-by-one apply work. It does not authorize Writer apply implementation, document mutation, undo wiring, UI dispatch commands, runtime registry integration, Provider calls, Plugin execution, Calc diagnostics, Impress workflow changes, import/export changes, or Workbench UI work.

The next implementation round may begin only after this packet is reviewed and accepted as the source contract for a single-owner Writer apply slice. Until that happens, Writer capability state must remain preview-only or apply-blocked in registry and Workbench-facing evidence.

Safe M3-04 outcome:

- name the Writer source surfaces that a future apply round must inspect;
- define preconditions that must exist before any mutation path starts;
- require preview revision checks, one-action/one-undo semantics, rollback or unchanged failure behavior, modified-state coverage, and repeated diagnostics;
- keep Provider and Plugin output unable to receive live document handles or directly mutate documents.

## Scope and non-goals

In scope:

- Writer apply guardrail and acceptance rules.
- Future source-surface map for a module-owned Writer apply adapter.
- Required evidence before any apply-capable registry state can be reported.
- Test expectations for initially modified and initially unmodified documents.
- Failure and rollback evidence requirements.

Out of scope:

- No C++ source edits.
- No Writer analyzer edits.
- No document mutation.
- No undo manager wiring.
- No UNO command or UI dispatch integration.
- No runtime registry source implementation.
- No Provider/private/cloud enablement.
- No runtime Plugin loading.
- No Calc, Impress, Workbench, import/export, or packaging changes.

## Source surfaces for future implementation

| Surface | Role in future apply round | M3-04 decision |
| --- | --- | --- |
| `sw/inc/IntelligentWriterAnalyzer.hxx` | Existing preview analyzer contract surface. | Keep preview/read-only; do not turn analyzer into a mutator. |
| `sw/source/core/doc/IntelligentWriterAnalyzer.cxx` | Existing diagnostic implementation. | May provide deterministic diagnostics before/after apply, but must not own document mutation in this packet. |
| `sw/inc/docsh.hxx` | Writer document shell lifecycle, modified-state, and undo-related orchestration candidate. | Future apply adapter must inspect this surface for document lifecycle and modified-state semantics. |
| `sw/source/uibase/app/docst.cxx` | Writer app/document-shell behavior candidate near user-visible document state transitions. | Future apply adapter must inspect this surface before choosing apply entry placement. |
| Future Writer module adapter under `sw/` | Module-owned deterministic apply path. | Required before apply support can become true; exact file placement is deferred to implementation design. |
| Future orchestration layer near `sfx2` or a dedicated shared layer | Capability policy, preview/apply lifecycle, and evidence coordination. | Must not be selected without dependency audit; no shared runtime source in M3-04. |

The current Writer analyzer is evidence for preview diagnostics only. A future apply adapter must be module-owned and must coordinate with Writer document lifecycle code rather than letting diagnostics, registry lookup, Provider output, Plugin output, or UI cards mutate document state directly.

## Preconditions before any future implementation

A future Writer apply round may start only when it can state all of the following before editing source:

1. The exact diagnostic/action being applied, limited to one deterministic local fix.
2. The source owner and file family for the apply adapter.
3. The document revision token or equivalent precondition checked after preview and before mutation.
4. The undo grouping API that guarantees one accepted user action creates one undo unit.
5. The modified-state behavior for both initially modified and initially unmodified documents.
6. The failure behavior: rollback or unchanged document, with no extra dirty state and no misleading undo entry.
7. The repeated-diagnostic expectation after apply.
8. The evidence record fields that prove preview, apply, undo, rollback, and diagnostics results without storing document content by default.
9. The registry state change that remains blocked until tests pass: `apply_support` must stay false before proof.

If any precondition is not answerable, the implementation round must stop at design review and keep Writer apply blocked.

## Preview and revision contract

Writer apply is allowed only after a user-visible preview for the exact action.

Required behavior:

- Analyze document and create a preview action.
- Store a document revision token or equivalent source-state precondition with that preview.
- Reject apply if the document changed after preview.
- Reject apply if the preview action no longer maps to the same range/object/content summary.
- Do not silently rebase provider/plugin/action output onto changed document content.
- Report `source changed since preview` as a blocked state or failure reason.

The rejection path must leave the document unchanged and must not create an undo entry.

## One-action/one-undo semantics

The future apply path must implement the rule from `docs/architecture/engine-capability-platform-architecture.md`: one accepted user action equals one undo unit.

Acceptance requirements:

- One user acceptance of one preview action creates exactly one undoable operation.
- Undo restores the prior document content and relevant formatting state for that action.
- Failed apply does not leave multiple partial undo entries.
- Batch or “fix all” behavior is not part of the first apply round unless it is represented as reviewed preview groups and still has clear undo semantics.
- UI commands must not bypass preview, revision checks, policy, registry state, or undo grouping.

## Modified-state test matrix

The future implementation must include tests or equivalent evidence for both initial document states.

| Initial state | Apply success expectation | Undo expectation | Failure expectation |
| --- | --- | --- | --- |
| Initially unmodified document | Successful apply may mark the document modified because user-visible content changed. | Undo returns document content to the original state and restores the unmodified state if Writer semantics allow that for a clean document. | Document remains unchanged and unmodified. |
| Initially modified document | Successful apply preserves the fact that the document already had unsaved changes while adding one new undoable change. | Undo removes only the accepted apply change and leaves the prior unsaved changes intact. | Document remains in the same modified state it had before the failed apply. |

Tests must explicitly cover repeated diagnostics after apply and after undo. The diagnostic result should be deterministic for the same document state.

## Rollback and unchanged-failure evidence

A future apply-capable Writer round must prove one of these failure models for every mutation attempt:

- full rollback to the pre-apply document state; or
- unchanged document on failure because mutation did not begin.

Required evidence:

- failure injection or a controlled negative case;
- document content/state comparison before and after the failure;
- modified-state comparison before and after the failure;
- undo-stack behavior showing no misleading partial apply entry;
- evidence record that reports failure reason without storing document content by default.

No apply path may claim support if partial mutation can survive a failure without an explicit rollback/repair strategy and test evidence.

## Provider and Plugin isolation rule

Provider and Plugin output must never receive live Writer document handles and must never directly mutate Writer documents.

Allowed future data flow:

1. Writer creates a bounded snapshot or selected-context payload.
2. Provider or Plugin returns preview artifacts only.
3. Local policy and registry gates decide whether the preview can be shown.
4. A module-owned Writer apply adapter converts an accepted local preview into deterministic document operations.
5. Evidence records the result without document content by default.

Blocked data flow:

- Provider or Plugin gets `SwDoc`, shell, cursor, UNO controller, or any live mutation handle.
- Registry lookup dispatches mutation directly.
- UI card invokes apply without preview and revision checks.
- Cloud/private provider response is applied silently or automatically.

## Registry and Workbench state implications

M3-04 does not change runtime registry behavior. It defines the evidence needed before Writer apply can be reported as supported.

Until a future implementation round passes the guardrails:

- Writer diagnostic entries may be `preview-only`.
- Writer apply entries must keep `apply_support: false`.
- Workbench-facing state should say apply is blocked by missing undo/rollback/repeated-diagnostic proof.
- Provider/private/cloud and Plugin entries remain blocked by policy or disabled.
- No UI command should present an enabled apply action for this capability.

## Acceptance gate for the next round

A future M3 Writer apply implementation packet is accepted only if it includes:

- one deterministic local Writer fix action;
- named source files and owner;
- preview fixture or equivalent user-visible preview evidence;
- revision-stale rejection evidence;
- one-action/one-undo evidence;
- initially modified and initially unmodified document tests;
- rollback or unchanged-failure evidence;
- repeated diagnostics after apply and undo;
- registry state showing apply support remains false until evidence passes;
- explicit confirmation that Provider/Plugin/UI/registry do not directly mutate documents.

## Implementation block

This packet explicitly blocks implementation in M3-04. Do not edit Writer source, add apply commands, wire UI dispatch, mutate documents, enable registry apply states, call Providers, load Plugins, or add import/export behavior as part of this round.

The only approved M3-04 repository change is this documentation packet plus the active todolist status update that points to it.

## Verification checklist

Documentation verification for M3-04:

```sh
git diff -- docs/architecture/engine-capability-writer-apply-guardrail-m3-04.md AUTORESEARCH_EXECUTION_TODOLIST.md
```

Optional contract/dashboard refresh, if shell permissions allow:

```sh
bin/intelligent-contract-fixtures.sh tmp/intelligent-contract-fixtures.md
bin/v2-upgrade-dashboard.sh tmp/v2-upgrade-dashboard.md
```

No clean, build, source mutation, document mutation, Provider, Plugin, UI, or import/export commands are part of this round.
