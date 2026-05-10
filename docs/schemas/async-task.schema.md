# `async-task.schema.json` 人工解读手册

<!-- schema-coherence
schema: docs/schemas/async-task.schema.json
schema_version_const: 1
required_count: 11
total_props: 14
enum_count: kind=4
enum_count: state=6
-->

> Reader's guide for the V2 W5 async-task envelope. The schema itself
> is the single source of truth (`docs/schemas/async-task.schema.json`,
> JSON Schema 2020-12, 14 props / 11 required / `additionalProperties:false`,
> `schema_version: const 1`). This doc explains *why* each prop exists,
> what locks it, and what's intentionally not locked yet.
>
> **Audience**: someone hand-deriving `kqoffice/source/ai/cowork/AsyncTask.hxx`
> when W5 Day-0 C++ scope auth lands, or a downstream tool author
> consuming the on-disk task records.
>
> **Token-lock anchors**: W5 spec §"Token lock" and §"4 个前期场景"
> (`docs/product/v2/w5-async-cowork-spec.md`).

## 1. Where this envelope lives

```
${UserInstallation}/ai-tasks/YYYY-MM/<task_id>.json
```

- One JSON file per task. `TaskStore` (W5 Day-0 C++) is the only
  writer; readers can be C++ (TaskManager UI), the cron-trigger
  daemon, or external tooling (companion-app pairing, audit).
- Distinct from `provider-evidence.schema.json` (per-call audit) and
  `apply-plan-runtime.schema.json` (per-call apply payload). A task
  envelope *references* evidence ids and apply-plan ids; it is not
  itself a provider call record.

## 2. Required envelope (11 keys)

| Key | Type | Pattern / enum | Why required |
|---|---|---|---|
| `schema_version` | integer | `const: 1` | Bumped only on non-additive change. Day-0 ships v1. Lets readers fail fast on an envelope they don't know how to interpret. |
| `task_id` | string | `^tk-[0-9]{8}-[0-9]{3}$` | Per-day ordinal (`tk-YYYYMMDD-NNN`). Filename = `<task_id>.json` so the id encodes its own location. |
| `kind` | string enum (4 tokens) | `weekly-report` \| `outline-to-slides` \| `contract-review` \| `data-cleanup` | One scenario per token (W5 spec §"4 个前期场景"). Order locked by H4 schema enum-order check. |
| `state` | string enum (6 tokens) | `pending` \| `running` \| `awaiting-review` \| `applied` \| `failed` \| `cancelled` | Matches the §"状态机" diagram. **Not** `needs-review`/`rejected` (a token-drift incident at L35 is locked against by H4). Order locked. |
| `title` | string (1..200 chars) | — | Surfaced verbatim in TaskManager UI and notification toasts. minLength 1 prevents UI rendering an empty row. |
| `created_at` | string | `^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$` | ISO-8601 UTC with seconds + `Z` suffix. Set once at `pending` and never rewritten. |
| `updated_at` | string | same pattern | Rewritten on every state-machine transition. Reader can compute task duration as `updated_at - created_at` once state is terminal. |
| `service_mode` | string enum | `offline` \| `private` \| `cloud` | Active `ServiceModePolicy` mode at task accept. **Locked at creation** — a task started offline will not silently escalate to cloud (W5 spec §"安全"). |
| `input` | object | `additionalProperties: true` | Per-kind input payload. Day-0 envelope-only — the per-kind shape (e.g. weekly-report's `meeting_notes[]`) lands incrementally as each kind ships. The `additionalProperties: true` here is intentional and contained: only this single nested object is open. |
| `steps` | array of step objects | see §3 | Per-step progress. Ordering = execution order. |
| `evidence_ids` | array of strings | each `^ev-[0-9a-f]{16}$` | Flat denormalized list. Mirrors `steps[].evidence` when present. Lets a reader walk all evidence without traversing steps. |

## 3. Step object (3 required keys)

```jsonc
{
  "step_id": "s1",          // ^s[0-9]+$ — per-task ordinal
  "title": "提取决策",       // human-readable, minLength 1
  "state": "completed",     // enum below — narrower than TaskState
  "evidence": "ev-..."      // optional; ^ev-[0-9a-f]{16}$
}
```

**Step `state` enum**: `pending | running | completed | failed`.

This is **narrower** than `TaskState` by design — steps never enter
`awaiting-review`. The apply-plan that triggers `awaiting-review`
is a *task-level rollup* assembled from completed steps, not a
state any individual step can reach.

A failed step still mints an evidence id (the provider call
recorded its own audit) — see `async-task.terminal-failed.json`
fixture for the canonical pattern.

`additionalProperties: false` on the step object — a future
extension (e.g. per-step retry counter) requires a schema_version
bump.

## 4. Optional keys (3)

| Key | Type | When present | Why |
|---|---|---|---|
| `result_plan_id` | `null` \| `^ap-[0-9a-f]{16}$` | null while `pending`/`running`/`failed`/`cancelled`; required string when state is `awaiting-review` or `applied` | Joins task → ApplyPlan record. The `oneOf` shape (not just optional) is what makes "is the apply-plan ready?" a single-field check. |
| `review_decisions[]` | array of `{patch_id, decision}` | populated only when state has reached `awaiting-review` and the user has acted | Per-patch user actions (`accept` \| `reject` \| `refine`). Empty array = user has not acted yet. **Not** a count — explicit array so UI can render diff badges. |
| `failure_reason` | string (≤500 chars) | required iff `state == 'failed'` | Free-form short cause string. **Not** a structured error code yet — Day-0 stays envelope-only. The 500-char cap exists so the TaskManager UI can show the full reason in a tooltip without truncation. |

## 5. What's intentionally NOT locked

These are deferred to incremental ships (each will bump
`schema_version` if it lands as a non-additive change):

- **Per-kind `input` shape**. Today open-object. When weekly-report
  lands its real input, we add a `oneOf` keyed on `kind`. Until
  then, downstream consumers must not assume `input.source_docs[]`
  exists for all kinds.
- **Per-step `output` shape**. A completed step that produced an
  apply-plan fragment puts its evidence id in `evidence`; the
  fragment itself is in the provider-evidence record, not here.
- **Cron schedule fields**. Recurring tasks (weekly-report each
  Monday) keep their schedule in a sibling file
  `${UserInstallation}/ai-cron/<cron_id>.json` — explicitly out
  of this schema.
- **Companion-app pairing token**. Per W5 spec §"安全", pairing
  state lives in
  `${UserInstallation}/companion/<device_id>.json` and never
  embeds in a task record.
- **Sub-second timestamp precision**. Seconds is enough for ledger
  ordering; sub-second would force a schema_version bump because
  the regex tightens.

## 6. State-machine transitions (locked by H4 partial-enforce)

```
            ┌─────────┐
            │ pending │
            └────┬────┘
                 │  TaskStore::startNext()
                 ▼
            ┌─────────┐         user cancels
   ┌────────┤ running ├──────────────────────────┐
   │        └────┬────┘                          │
   │             │                                │
   │   all steps completed       any step failed  │
   │   ApplyPlan assembled                        │
   │             │                                │
   │             ▼                                ▼
   │   ┌─────────────────┐                ┌──────────┐
   │   │ awaiting-review │                │  failed  │
   │   └────────┬────────┘                └──────────┘
   │            │  user accepts patches
   │            ▼
   │       ┌─────────┐
   │       │ applied │
   │       └─────────┘
   │
   ▼
┌───────────┐
│ cancelled │
└───────────┘
```

- **No re-entry**: terminal states `applied | failed | cancelled`
  don't transition back. To retry, accept the task is dead and
  spawn a fresh `task_id`.
- **`updated_at` invariant**: rewritten on *every* arrow above.
- **`result_plan_id` invariant**: null in `pending | running |
  failed | cancelled`; non-null `^ap-[0-9a-f]{16}$` in
  `awaiting-review | applied`.

## 7. Fixture coverage matrix

The schema is exercised by 7 fixtures under `docs/schemas/fixtures/`
— one per `state` enum value plus the all-violations negative case.
Every state in §6's diagram has at least one validity-locked
fixture, so any future enum drift surfaces in the H4 sweep:

| Fixture | State branch | Locks |
|---|---|---|
| `async-task.pending.json` | pending (3 pending steps, no evidence) | accept-time envelope: `result_plan_id=null`, `evidence_ids=[]`, all step states pending |
| `async-task.running.json` | running (mixed steps: completed+running+pending) | mid-flight envelope: `result_plan_id=null`, partial `evidence_ids` mirroring only completed steps, step state-machine independence from task state |
| `async-task.valid.json` | awaiting-review (3 completed steps) | happy path, full evidence_ids, real result_plan_id |
| `async-task.applied.json` | applied (3 completed steps) | post-apply envelope: `result_plan_id` populated as `^ap-[0-9a-f]{16}$`, `review_decisions` populated with accept/refine/reject mix |
| `async-task.terminal-failed.json` | failed (mixed step terminal states) | `state=failed`, `failure_reason` populated, `result_plan_id=null` branch of oneOf, evidence_ids ⊊ steps[].evidence |
| `async-task.cancelled.json` | cancelled (mid-flight cancel) | terminal cancel: `result_plan_id=null`, no `failure_reason` (distinguishes cancel from failure), partial steps frozen |
| `async-task.invalid.json` | 11 distinct schema violations at once | enum drift defenses (`needs-review`/`rejected`/`online`), pattern guards (task_id case, evidence non-hex), additionalProperties:false (`rogue_extra_field`), required-key absence (`schema_version`), naive datetime (no `Z`) |

Adding an 8th fixture: drop a new file under `docs/schemas/fixtures/`
matching `async-task.<status-token>.json` (extended-naming) for
valid payloads, or extend `async-task.invalid.json` for invalid
payloads (strict naming required for the negative case — only one
`async-task.invalid.json` per dir). H2 baseline must be bumped in
the same commit (`tests/v2-plan-baseline-test.sh` fixture count
assertion).

## 8. Reader checklist (downstream tools)

Before reading a task envelope:

1. **Verify `schema_version == 1`**. Fail loud on any other value
   — don't silently degrade.
2. **Validate `additionalProperties:false`** by walking the top-level
   key set against the 14-prop allow-list. Unknown keys mean the
   envelope was written by a newer producer; stop.
3. **Cross-check the state ↔ result_plan_id invariant** (§6):
   `awaiting-review`/`applied` with null `result_plan_id` is
   corruption.
4. **Cross-check the state ↔ failure_reason invariant**:
   `failed` without `failure_reason` is corruption.
5. **De-duplicate `evidence_ids` against `steps[].evidence`**. They
   should be a flat mirror; a divergence means the writer crashed
   mid-write.

## 9. Authority and change control

- This schema is locked by **H4** (`tests/v2-async-task-schema-test.sh`)
  in partial-enforce mode (auto-promotes to full-enforce when
  `${KDOFFICE_SRC_ROOT}/kqoffice/source/ai/cowork/AsyncTask.hxx`
  lands).
- Any change to the schema body requires same-batch updates to:
  - `docs/product/v2/w5-async-cowork-spec.md` §"Token lock" if
    enums move.
  - `docs/product/v2/lane-status.md` §"Drift locks" if a new
    drift class is added.
  - `tests/v2-plan-baseline-test.sh` if fixture count moves.
  - This document, if any §"What's NOT locked yet" item starts
    being locked.
- Schema deletion is **not allowed** — replace via `schema_version`
  bump, keep v1 readable for ~6 months while task records age out.

## 10. Cross-references

- Schema body: `docs/schemas/async-task.schema.json`
- Fixtures: `docs/schemas/fixtures/async-task.{valid,invalid,pending,running,applied,terminal-failed,cancelled}.json`
- Spec: `docs/product/v2/w5-async-cowork-spec.md`
- Harness: `tests/v2-async-task-schema-test.sh`
- Baseline regression lock: `tests/v2-plan-baseline-test.sh`
- Lane mirror: `docs/product/v2/lane-status.md` §"W5 — Async cowork"
