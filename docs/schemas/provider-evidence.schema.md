# `provider-evidence.schema.json` 人工解读手册

<!-- schema-coherence
schema: docs/schemas/provider-evidence.schema.json
required_count: 9
total_props: 9
enum_count: service_mode=3
enum_count: status=17
-->

> Reader's guide for the V2 W1/W3 provider-evidence envelope. The
> schema itself is the single source of truth
> (`docs/schemas/provider-evidence.schema.json`, JSON Schema 2020-12,
> 9 required keys = 9 total props (closed envelope, no optional keys),
> `additionalProperties: false`, **no `schema_version`** field —
> intentional, see §2). This doc explains *why* each prop exists,
> what locks it, and the apply-plan-* status family.
>
> **Audience**: someone touching `kqoffice/source/ai/provider/
> EvidenceRecorder.{hxx,cxx}` to add a new status token, or a SOC /
> audit reviewer reading the on-disk evidence trail under
> `~/Library/Application Support/.../ai_provider_evidence/*.json`.
>
> **Token-lock anchors**: H1 harness
> (`tests/v2-provider-evidence-schema-test.sh`) is the programmatic
> guard that locks schema↔C++ apply-plan-* and runtime tokens
> together; this doc captures the *intent* H1 enforces mechanically.
>
> **Sibling reader's manuals**: `apply-plan-runtime.schema.md` (W3,
> L51), `inline-action-request.schema.md` (W4, L49),
> `async-task.schema.md` (W5, L45).

## 1. Where this envelope lives

```
~/Library/Application Support/<product>/ai_provider_evidence/<YYYY-MM-DD>/<evidence_id>.json
```

- One JSON file per `Provider::call()` invocation. `EvidenceRecorder`
  is the only writer.
- Distinct from V1.5 `evidence-record.schema.json` (m3-02 capability/
  diagnostic fixture-validator record — different fields entirely,
  locked by 27/27 strict roundtrip).
- Distinct from `apply-plan-runtime.schema.json` (the *plan* the
  provider proposes); evidence records *whether the plan was
  accepted*. A failed plan validation produces an evidence record
  with one of the apply-plan-* status tokens.

## 2. Why no `schema_version`

The other V2 envelopes (W3/W4/W5) carry a `schema_version` const
(`v2-w3-runtime-1`, `v2-w4-1`, `1`). This one deliberately does
not. Reasoning:

- This envelope is consumed only by the SOC/audit grep workflow
  and the H1 drift-lock harness — both walk *fields*, not version
  branches.
- Adding `schema_version` would force downstream readers
  (PowerShell/Python audit scripts, log-aggregator queries) to
  branch on version even when the change is purely additive.
- When a non-additive change is needed, the schema body's `$id`
  bump + `additionalProperties: false` will make any old envelope
  fail validation against the new schema — implicit version pin.

If a future change forces a `schema_version` add, that itself
counts as the breaking change that justifies introducing one. Do
not pre-introduce it.

## 3. Required keys (9, all required, no optional tail)

| Key | Type | Pattern / enum | Why required |
|---|---|---|---|
| `evidence_id`        | string  | `^ev-[0-9a-f]{16}$` | Per-process unique id minted by `EvidenceRecorder`. 16-hex format combines a wall-clock seed + monotonic counter, so two records minted in the same millisecond still get distinct ids. Prefix `ev-` parallels `ap-` (apply-plan-id), `iar-` (inline-action-request), `tk-` (task-id). |
| `timestamp`          | string  | `^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$` | ISO-8601 UTC, seconds precision, `Z` suffix. Same regex shape as W4/W5 timestamps. Wall-clock is enough — sub-second ordering is captured by `evidence_id`'s monotonic counter. |
| `service_mode`       | string  | `offline \| private \| cloud` | Active `ServiceModePolicy` mode at call time. Locked at recorder creation; the `ServiceModePolicy::shouldEscalate` audit invariant requires this be the *actual* mode, never an aspirational one. |
| `provider`           | string  | — | Backend identifier. Day-0/Day-1a: literal `"stub"`. With OllamaAdapter in path: `"ollama:<model>"` (e.g. `"ollama:qwen2.5:7b"`). Future cloud: `"cloud:<vendor>:<model>"`. Free-form (no enum) because new backends must be addable without schema bumps. |
| `capability`         | string  | — | Capability id requested. May be empty when the request was rejected by `IllegalArgumentException` *before* hitting the policy gate (the recorder still emits the envelope so the audit shows the rejection). |
| `status`             | string  | 17-token enum (see §4) | Canonical outcome token. ASCII-kebab so `grep` / `jq` / log-aggregator queries are locale-independent. The apply-plan-* family is emitted by `ApplyPlanValidator` via `applyPlanValidationStatus`. |
| `request_size_bytes`  | integer | `minimum: 0` | Wire-size of the outbound request payload. 0 is legal (some rejection paths emit the envelope before composing the wire payload). |
| `response_size_bytes` | integer | `minimum: 0` | Wire-size of the inbound response. 0 when no response was received (provider-error / timeout / policy-denied). |
| `duration_ms`        | integer | `minimum: 0` | Wall-clock duration, milliseconds. 0 is rare but legal (cached / pre-rejected). Used by the SOC dashboard to spot regressions in provider latency. |

## 4. The 17-token `status` enum

Canonical outcome of one `Provider::call()` invocation. ASCII-kebab,
locale-independent, used as the SOC grep key. Order locked by H1
harness against `Provider.cxx` runtime-token subset + ApplyPlanValidator
apply-plan-* token set.

### 4.1 Runtime tokens (4)

| Token | When emitted | Source |
|---|---|---|
| `ok`              | Call completed, response composed, plan validation passed (or no plan in response). | `Provider.cxx::call()` |
| `provider-error`  | Backend returned an error (network, HTTP non-2xx, malformed body that wasn't an apply-plan). | `Provider.cxx` + `OllamaAdapter` error paths |
| `policy-denied`   | `ServiceModePolicy` rejected the request before reaching the backend. | `Provider.cxx::checkPolicy` |
| `timeout`         | Backend exceeded `timeout_policy.timeout_ms` (W1 spec: 100ms probe, 30s generate). | `OllamaAdapter` timeout branch |

### 4.2 ApplyPlan validation rejection tokens (13)

Emitted exclusively by `ApplyPlanValidator` (header-only,
`kqoffice/source/ai/provider/ApplyPlanValidator.hxx`) via
`applyPlanValidationStatus`. Each token names the *first* validation
rule that failed; subsequent rules don't run. The 14th
`ValidationCode` (`apply-plan-unknown`) is a defensive C++-only
fallback for impossible enum drift — it intentionally is **not** in
the schema enum (locked by H1: "Defensive `apply-plan-unknown`
present in C++, absent from schema").

Token order matches `ApplyPlanValidator::ValidationCode` enum
declaration order:

| # | Token | Trigger |
|---|---|---|
| 1  | `apply-plan-not-json`                | Top-level body is not parseable JSON |
| 2  | `apply-plan-missing-field`           | A required envelope field is absent |
| 3  | `apply-plan-schema-version-mismatch` | `schema_version` not the expected V1.5 m3-02 const |
| 4  | `apply-plan-id-pattern`              | `id` doesn't match `^[a-z0-9][a-z0-9.-]{2,80}$` |
| 5  | `apply-plan-revision-precondition`   | `revision_precondition` shape wrong |
| 6  | `apply-plan-deterministic-false`     | `deterministic: false` (only `true` is acceptable for V2 audit) |
| 7  | `apply-plan-rollback-false`          | `rollback_supported: false` |
| 8  | `apply-plan-undo-group-mode`         | `undo_group_mode` not in the V1.5 m3-02 enum |
| 9  | `apply-plan-undo-label-empty`        | `undo_label` is empty string |
| 10 | `apply-plan-failure-behavior`        | `failure_behavior` not in the V1.5 m3-02 enum |
| 11 | `apply-plan-failure-message-empty`   | `failure_message_zh` is empty string |
| 12 | `apply-plan-operation-summary-empty` | `operation_summary_zh` is empty string |
| 13 | `apply-plan-repeated-diagnostics`    | `diagnostics` array has duplicate id within one apply-plan |

The 17 = 4 + 13 split is load-bearing — the SOC dashboard groups
runtime errors separately from validation rejections (validation
rejections never reach a backend, so they don't count toward backend
SLO).

## 5. Fixture coverage matrix

3 fixtures under `docs/schemas/fixtures/`:

| Fixture | Locks |
|---|---|
| `provider-evidence.valid.json`              | Minimal-required envelope; `status: provider-error`; `provider: stub`; `capability: rewrite`. Exercises the smallest legal record. |
| `provider-evidence.apply-plan-failure.json` | Extended-naming fixture (resolves to `expectation=valid`); `status: apply-plan-failure-behavior`; `provider: ollama:qwen2.5:7b`; `capability: writer.diagnostics.style-spacing`. Pins the apply-plan-* status family alive in the fixture roster. |
| `provider-evidence.invalid.json`            | 3 distinct violations: `evidence_id` pattern (not 16-hex), `status` enum (`totally-bogus`), `request_size_bytes` non-negative int (`-1`). |

Adding a 4th fixture: drop a new file matching
`provider-evidence.<status-token>.json` (extended-naming) for valid
payloads, or extend the invalid fixture if a new violation class
needs covering. H2 baseline must be bumped same-commit
(`tests/v2-plan-baseline-test.sh` fixture count assertion).

## 6. Reader checklist (audit grep / SOC dashboard / replay)

Before consuming an evidence envelope:

1. **Validate against the schema body** — H1 harness covers this in
   CI. For ad-hoc audit, use `bin/intelligent-contract-fixtures.sh`
   to validate.
2. **Branch on `status`** at the 4-vs-13 split (runtime vs
   validation-rejection). They're different SLOs.
3. **For apply-plan-* statuses**: cross-reference the C++ source
   `ApplyPlanValidator.hxx::ValidationCode` enum + the zh-CN toast
   in `applyPlanValidationMessage` for user-facing context.
4. **For `provider-error` / `timeout`**: check `duration_ms` against
   the W1 spec budgets (100ms probe / 30s generate).
5. **Reject any unknown top-level key** —
   `additionalProperties: false` is set; readers should not accept
   payloads with extras.

## 7. Authority and change control

- Locked by **H1** (`tests/v2-provider-evidence-schema-test.sh`):
  - schema status enum ↔ C++ apply-plan-* emissions (13/13)
  - defensive `apply-plan-unknown` present in C++, absent from schema
  - `Provider.cxx` runtime-token subset ⊆ schema runtime enum
  - 9-key envelope shape locked
- Locked by **H6** (`tests/v2-schema-manual-coherence-test.sh`)
  via this manual's fact-block:
  - `required_count == 9` (= total_props == 9, no optional tail)
  - `service_mode` enum cardinality = 3
  - `status` enum cardinality = 17
  - `schema_version_const == none` (asserts schema deliberately
    has no schema_version field; see §2)
- Locked by **H2** (`tests/v2-plan-baseline-test.sh`) via the
  3-fixture run (counted in 36/13 baseline).
- Any change to the schema body requires same-batch updates to:
  - `kqoffice/source/ai/provider/EvidenceRecorder.{hxx,cxx}` if
    the envelope shape moves
  - `kqoffice/source/ai/provider/ApplyPlanValidator.hxx`
    `ValidationCode` enum if status family moves
  - This document, if any §"Why no schema_version" justification
    stops holding
- Schema deletion is **not allowed** — replace via `$id` bump +
  retire path.

## 8. Cross-references

- Schema body: `docs/schemas/provider-evidence.schema.json`
- Fixtures: `docs/schemas/fixtures/provider-evidence.{valid,invalid,apply-plan-failure}.json`
- C++ writer: `kqoffice/source/ai/provider/EvidenceRecorder.{hxx,cxx}`
- C++ validator: `kqoffice/source/ai/provider/ApplyPlanValidator.hxx`
- W1 spec: `docs/product/v2/w1-provider-runtime-spec.md`
- W3 spec: `docs/product/v2/w3-writer-apply-runtime-spec.md` (apply-plan validation flow)
- Harnesses: `tests/v2-provider-evidence-schema-test.sh` (H1),
  `tests/v2-schema-manual-coherence-test.sh` (H6),
  `tests/v2-plan-baseline-test.sh` (H2)
- Lane mirror: `docs/product/v2/lane-status.md` §"W1 — Provider
  Runtime" + §"Drift locks"
- Sibling reader's manuals:
  `apply-plan-runtime.schema.md` (W3),
  `inline-action-request.schema.md` (W4),
  `async-task.schema.md` (W5)
