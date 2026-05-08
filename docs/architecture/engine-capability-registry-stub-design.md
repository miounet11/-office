# Engine Capability Registry Stub Design

Generated: 2026-04-28

## Executive verdict

M3-03 should design a built-in, local/offline capability registry stub before any runtime registry implementation, Workbench UI wiring, provider calls, plugin loading, or document mutation work.

The registry stub is a control-plane contract surface. Its first job is to make capability state discoverable and policy-explainable, not executable. It may report that a capability is available, preview-only, blocked, disabled, or waiting for proof, but it must not dispatch commands or load implementation code.

## Scope and non-goals

In scope:

- Built-in capability metadata shape.
- Availability and policy state vocabulary.
- Module scope, service mode, network mode, trust level, budget, and evidence fields.
- Preview/apply support separation.
- Local/offline data-source recommendation.
- Handoff gates for a future source stub.

Out of scope:

- No C++ registry implementation.
- No Workbench UI implementation.
- No UNO command or dispatch integration.
- No runtime plugin loading.
- No Provider/private/cloud enablement.
- No Writer apply, Calc diagnostic, Impress export, or document mutation path.
- No final shared-library ownership decision before dependency audit.

## Contract baseline

The M3-03 registry stub should use the accepted M3-02 fixture evidence as its source contract:

- `docs/schemas/capability-registry-entry.schema.json`
- `docs/schemas/fixtures/capability-registry-entry.valid.json`
- `tmp/intelligent-contract-fixtures.md`

`tmp/intelligent-contract-fixtures.md` currently reports 18 fixtures across 9 schemas with status **passed**. That means the registry design can proceed from schema-backed fields without claiming runtime support.

Minimum entry fields:

- `schema_version`
- `capability_id`
- `module_scope`
- `availability_state`
- `service_mode`
- `network_mode`
- `preview_support`
- `apply_support`
- `trust_level`
- `budget`
- `blocked_reason_zh`
- `source_kind`

## Data source recommendation

The first registry stub should be compiled or packaged as built-in local/offline data. It should behave like a static catalog that the application can query after a document/module context exists.

Recommended source direction for a later implementation round:

1. Keep the canonical field model aligned with `capability-registry-entry.schema.json`.
2. Represent first entries as built-in data only, not extension-discovered data.
3. Allow a future source adapter to filter entries by active module and policy.
4. Keep private/cloud/provider/plugin entries visible only as blocked or disabled states until the relevant policy gates are proven.
5. Emit evidence-friendly state and reason strings suitable for Workbench display, without implementing the display in this round.

Do not choose between `sfx2`, a dedicated shared library, or module-owned adapters in M3-03. `sfx2` remains a plausible orchestration surface because it is close to document shells and UI state, but dependency ownership must be validated before source placement.

## State vocabulary

The registry stub should preserve these availability states from the M3-02 contract:

| State | Meaning | First safe use |
| --- | --- | --- |
| `available` | Capability may run in the current context after normal policy and budget checks. | Future read-only/local deterministic features only. |
| `preview-only` | Capability can analyze or propose a preview, but cannot mutate the document. | Current Writer diagnostics and future preview surfaces. |
| `blocked-by-policy` | Service mode, admin policy, trust, or consent blocks execution. | Provider/plugin/private/cloud entries. |
| `needs-document` | Capability requires an open document or compatible selection. | Workbench task cards before a document is open. |
| `beta-disabled` | Capability is intentionally hidden or disabled outside beta/test channels. | Unproven apply or UI workflows. |
| `requires-compatibility-proof` | Compatibility, export, validator, or layout evidence is not sufficient. | Import/export-sensitive workflows. |
| `provider-unavailable` | Provider path is not configured or not allowed. | AI/provider preview entries. |
| `plugin-runtime-disabled` | Plugin runtime is not trusted or enabled. | Future plugin-discovered capabilities. |
| `budget-exceeded` | Declared time, token, document-size, or memory budget is exceeded. | Long-running diagnostics or provider previews. |
| `unsupported-content` | Current document content cannot be safely analyzed or previewed. | Complex objects, unsupported fields, or speaker-notes limitations. |

Every blocked or disabled state must provide `blocked_reason_zh` so UI and reports can explain the gate without inventing product copy later.

## Built-in seed entries

The first registry data set should be small and conservative:

| Capability | Module scope | State | Service/network | Preview | Apply | Reason |
| --- | --- | --- | --- | ---: | ---: | --- |
| `writer.diagnostics.style-spacing` | Writer | `preview-only` | `offline` / `none` | yes | no | Existing Writer analyzer evidence is preview/read-only only. |
| `calc.diagnostics.business-risk` | Calc | `beta-disabled` or `requires-compatibility-proof` | `offline` / `none` | no | no | Calc diagnostic source round has not started. |
| `impress.builder.outline-draft` | Impress | `requires-compatibility-proof` | `offline` / `none` | no | no | Deterministic builder exists, but workflow expansion/export proof is future work. |
| `provider.rewrite.selected-context` | Shared | `blocked-by-policy` or `provider-unavailable` | `private`/`cloud` as configured, never default | no | no | Provider path requires explicit consent, scoped payload, and preview-only return proof. |
| `plugin.capability.runtime` | Shared | `plugin-runtime-disabled` | `offline` or `local` only until proven | no | no | Signing, allowlist, quarantine, crash isolation, and disable-all gates are missing. |

The exact seed list can change in the implementation round, but all first entries should be built-in and conservative. It is safer to report fewer capabilities than to imply support that cannot be verified.

## Preview/apply separation

The registry must report preview and apply support independently.

Rules:

- `preview_support: true` does not imply mutation capability.
- `apply_support: true` is allowed only after a module-owned apply round proves revision checks, one undo unit, rollback or unchanged failure behavior, and repeated diagnostics.
- Provider and plugin output must not receive live document handles and must not directly mutate documents.
- UI entries must not convert preview-only capabilities into apply commands.
- Apply support should remain `false` for all initial M3-03 registry stub entries unless a future accepted implementation round proves otherwise.

## Budget and evidence fields

The registry stub should make budgets and evidence requirements visible before execution.

Budget guidance:

- `kind: none` with `status: not-required` for static or trivial entries.
- `kind: document-size` for local analyzers bounded by snapshot size.
- `kind: time` for deterministic local workflows with timeout requirements.
- `kind: token` only for future provider paths and only while blocked unless provider policy is accepted.

Evidence guidance:

- Registry entries should point users and reports toward evidence gates, but not store document content.
- Evidence records must keep `stores_document_content: false` by default.
- Missing validator, compatibility, accessibility, or undo/rollback proof should map to blocked or proof-required states, not optimistic availability.

## Policy blockers

M3-03 must keep these areas blocked:

- Runtime plugin loading.
- Arbitrary extension code discovery.
- Private/cloud provider calls.
- Silent upload or background provider context collection.
- Live document handles in provider/plugin requests.
- Direct document mutation from registry lookup.
- UI dispatch commands that bypass service-mode policy.
- Apply-capable states without undo, rollback, and repeated-diagnostic proof.

Future provider/plugin work remains blocked until signing/trust, allowlist/disable-all, quarantine, crash isolation, service-mode enforcement, selected-context consent, and no-document-mutation-on-failure evidence exist.

## Handoff checklist for source implementation

A future M3 registry stub implementation round may start only when it can answer:

- Which source owner is selected after dependency audit: `sfx2`, dedicated shared library, or module-owned adapters?
- Where is built-in registry data stored so it is local/offline and testable?
- Which test proves built-in capabilities are discoverable without plugin loading?
- Which test proves private/cloud/provider/plugin entries remain blocked by default?
- Which test proves preview and apply support are reported separately?
- Which report shows blocked reasons and budget/evidence fields without storing document content?
- Which Workbench-facing state vocabulary is exposed without implementing Workbench UI in the registry round?

## M3-04 guardrail

After M3-03, the next source-facing work should still be narrow. A Writer one-by-one apply path must be its own round with preview revision checks, one undo unit, rollback or unchanged document on failure, modified-state tests, and repeated diagnostics. Registry design acceptance alone does not authorize apply mutation.