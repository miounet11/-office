# `inline-action-request.schema.json` 人工解读手册

<!-- schema-coherence
schema: docs/schemas/inline-action-request.schema.json
schema_version_const: v2-w4-1
required_count: 7
total_props: 9
-->

> Reader's guide for the V2 W4 inline-action-request envelope. The
> schema itself is the single source of truth
> (`docs/schemas/inline-action-request.schema.json`, JSON Schema 2020-12,
> 7 top-level required keys, 9 properties total,
> `additionalProperties: false`, **3-branch `oneOf` keyed on `surface`
> const**, `schema_version: const "v2-w4-1"`). This doc explains *why*
> each prop and each oneOf branch exists, what locks them, and what's
> intentionally not locked yet.
>
> **Audience**: someone hand-deriving
> `sw/source/uibase/inline-actions/ParagraphActions.hxx` (or the Calc /
> Impress siblings) when W4 Day-0 C++ scope auth lands, or a downstream
> tool author replaying inline-action triggers for testing.
>
> **Token-lock anchors**: W4 spec §"Action enum lock" and §"Naming
> rules" (`docs/product/v2/w4-select-to-act-spec.md`).
>
> **Sibling reference**: `async-task.schema.md` (W5 envelope manual,
> L45) — same documentation pattern.

## 1. Where this envelope lives

Per-trigger envelope, not on-disk persistent (vs. async-task which
persists under `${UserInstallation}/ai-tasks/`). One JSON record is
constructed each time a user clicks an action in the inline floating
bubble:

```
SelectToActPopover::dispatchSelected(action_token)
   → builds InlineActionRequest envelope
   → hands to XProvider::call() (or local helper for format-clean /
     explain branches)
   → discarded after dispatch returns; replayable for tests via
     fixture roster
```

- Distinct from `async-task.schema.json` (per-task persistent record)
  and `apply-plan-runtime.schema.json` (per-call apply payload). An
  inline-action-request triggers *one* provider call (or one local
  helper); its output (an `apply-plan-runtime` envelope) is what
  gets persisted.
- The envelope is intentionally short-lived. Nothing here should
  carry "task" semantics — that's W5's job.

## 2. Top-level required keys (7)

| Key | Type | Pattern / enum | Why required |
|---|---|---|---|
| `schema_version` | string | `const: "v2-w4-1"` | Bumped only on non-additive change. Day-0 ships v2-w4-1. Lets a replay tool fail fast on unknown envelopes. |
| `request_id` | string | `^iar-[0-9a-f]{16}$` | Per-trigger unique id (`iar-` prefix matches `evidence_id`'s `ev-` and `apply-plan-id`'s `ap-` shape: short prefix + 16-hex). Used to correlate the request with its provider-evidence record. |
| `surface` | string enum | `writer-paragraph` \| `calc-cell` \| `impress-slide-element` | Which W4 surface raised the popover. Order matches W4-A/W4-B/W4-C section order in the spec. **This is the discriminator** — the entire `oneOf` keys off this const. |
| `action` | string | per-branch enum (see §3) | ASCII kebab-case action token. Validated *per-branch*, not as a single union enum — design choice that makes cross-surface drift fail informatively (§4). |
| `target` | object | per-branch shape (see §3) | Surface-specific target identifier. Open at envelope level; each oneOf branch locks the shape. |
| `service_mode` | string enum | `offline` \| `private` \| `cloud` | Active `ServiceModePolicy` mode at trigger time. **Locked at trigger creation** — no silent escalation per W5 spec §"安全". |
| `created_at` | string | `^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$` | ISO-8601 UTC timestamp at popover dispatch. Seconds precision, `Z` suffix. Mirrors `async-task` shape — same regex string. |

## 3. The 3 oneOf branches

The `oneOf` is a hard branch on `surface` const. Each branch locks
its own action enum + target shape. Token order = W4 spec §"Action
enum lock" table order.

### Writer paragraph (`surface == "writer-paragraph"`)

```jsonc
{
  "surface": "writer-paragraph",
  "action": "rewrite",     // 7-token ParagraphAction enum
  "target": {
    "paragraph_id": "swpara-42"   // ^swpara-[0-9]+$
  }
}
```

**ParagraphAction enum** (7 tokens, order locked):

| Token | UI label (zh-CN) | W1 capability | Diff? |
|---|---|---|---|
| `rewrite`       | 改写        | `rewrite`       | yes |
| `expand`        | 扩写        | `expand`        | yes |
| `shorten`       | 简写        | `shorten`       | yes |
| `translate-en`  | 翻译为英文  | `translate-en`  | yes |
| `format-clean`  | 清理格式    | n/a (local)     | yes |
| `explain`       | 解释        | `explain`       | **no** (popup-only) |
| `custom`        | 自定义提示  | `custom`        | yes |

`custom` requires `user_prompt` populated (cross-field rule, §5). All
other tokens make `user_prompt` optional.

### Calc cell/range (`surface == "calc-cell"`)

```jsonc
{
  "surface": "calc-cell",
  "action": "suggest-chart",   // 5-token CellAction enum
  "target": {
    "sheet": "Q2-销售",          // 1+ chars
    "range": "B2:E15"            // A1-style ^[A-Z]+[0-9]+(:[A-Z]+[0-9]+)?$
  }
}
```

**CellAction enum** (5 tokens, order locked):

| Token | UI label (zh-CN) | Diff? |
|---|---|---|
| `explain-data`     | 解释这些数据   | **no** (popup-only) |
| `suggest-chart`    | 建议图表       | yes |
| `generate-formula` | 生成公式       | yes |
| `format-clean`     | 清理格式       | yes |
| `format-change`    | 改格式         | yes (date/currency/%) |

### Impress slide element (`surface == "impress-slide-element"`)

```jsonc
{
  "surface": "impress-slide-element",
  "action": "translate-text",  // 4-token SlideElementAction enum
  "target": {
    "slide_index": 3,           // ≥0 integer
    "element_id": "sdobj-17"   // ^sdobj-[0-9]+$
  }
}
```

**SlideElementAction enum** (4 tokens, order locked):

| Token | UI label (zh-CN) | Diff? |
|---|---|---|
| `rewrite-text`   | 改写文字   | yes |
| `adjust-color`   | 调整配色   | yes |
| `relayout`       | 重新排版   | yes |
| `translate-text` | 翻译       | yes |

## 4. Why per-branch action enum (not a union)

A naïve schema would put all 16 tokens (7+5+4) in one giant `action`
enum at the top level. That accepts a payload like:

```jsonc
{
  "surface": "writer-paragraph",
  "action": "suggest-chart",   // a Calc action on a Writer surface!
  ...
}
```

The current design rejects this at the schema layer because the
`writer-paragraph` branch's `action` enum doesn't list
`suggest-chart`. **Cross-surface drift fails informatively** instead
of leaking through to runtime.

## 5. Optional keys (2)

| Key | Type | When present | Why |
|---|---|---|---|
| `user_prompt` | string ≤2000 chars | optional schema-side; **required at C++ layer iff action=`custom` (Writer)** | Free-form operator instruction. The 2000-char cap is a UI guard — the input box can't reasonably accept more, and any provider would truncate anyway. |
| `expected_capability` | string | optional; skipped for popup-only actions (`explain` / `explain-data`) | Names the W1 capability id the popover expects to dispatch through. Lets the dispatch layer assert "did I really hit the W1 capability the popover thought I would?" |

## 6. What's intentionally NOT locked

These are deferred (each will bump `schema_version` if it lands as
non-additive):

- **Cross-field `action=custom ⇒ user_prompt required`**. Schema
  has no `if/then/else`; this rule is enforced at C++ dispatch.
  Locking it in schema would require JSON Schema's conditional
  branch (`if-then-else`) which complicates the simple oneOf
  design.
- **Result correlation**. The envelope has no `result_plan_id` /
  `evidence_id` field — that's by design, this is a *request*, not
  a record. The provider call's evidence_id is correlated externally
  via `request_id`.
- **Multi-target trigger**. Today each request targets exactly one
  `paragraph_id` / cell range / slide element. Multi-paragraph
  rewrites (W5 territory) go through async-task, not inline-action.
- **Action chaining**. No `next_action` or callback shape. Inline
  actions are atomic.
- **Telemetry / latency probes**. Out of scope; pre-trigger
  observability is W1 evidence-record's job.

## 7. Fixture coverage matrix

5 fixtures under `docs/schemas/fixtures/` exercise the schema:

| Fixture | Branch | Locks |
|---|---|---|
| `inline-action-request.valid.json` | writer-paragraph rewrite | minimal-required envelope (no user_prompt, no expected_capability) |
| `inline-action-request.calc-suggest-chart.json` | calc-cell suggest-chart | extended-naming, sheet+range pattern, optional `expected_capability` |
| `inline-action-request.impress-translate.json` | impress-slide-element translate-text | extended-naming, slide_index+element_id pattern |
| `inline-action-request.writer-custom.json` | writer-paragraph custom | **cross-field rule pin** — `action=custom` with `user_prompt` populated (~80 chars) |
| `inline-action-request.invalid.json` | — | 9 distinct violations: wrong const, non-hex id, surface drift (`draw-shape`), participle action (`rewriting`), target type, service_mode drift, naive datetime, prompt overflow, additionalProperties:false |

Adding a 6th fixture: drop a new file matching
`inline-action-request.<status-token>.json` (extended-naming) for
valid payloads, or `inline-action-request.invalid.json` for invalid
(strict naming). H2 baseline must be bumped same-commit
(`tests/v2-plan-baseline-test.sh` fixture count assertion).

## 8. Reader checklist (downstream tools / replay)

Before consuming a request envelope:

1. **Verify `schema_version == "v2-w4-1"`**. Fail loud on any other
   value — don't silently degrade.
2. **Pick the oneOf branch by `surface`** before validating
   `action`. The action enum is per-branch.
3. **Cross-check action against branch's enum**. Reject
   cross-surface drift (e.g. `surface=writer-paragraph` +
   `action=suggest-chart` ⇒ reject).
4. **Check the `action=custom ⇒ user_prompt populated` rule** at
   the C++ dispatch layer (not schema layer).
5. **Reject any unknown top-level key** — `additionalProperties:false`
   is set; readers should not accept payloads with extras.

## 9. Authority and change control

- Locked by **H5** (`tests/v2-inline-action-request-schema-test.sh`)
  in partial-enforce mode (auto-promotes to full-enforce when
  `${KDOFFICE_SRC_ROOT}/sw/source/uibase/inline-actions/ParagraphActions.hxx`
  + `sc/source/ui/inline-actions/CellActions.hxx`
  + `sd/source/ui/inline-actions/SlideElementActions.hxx` all land).
- Any change to the schema body requires same-batch updates to:
  - `docs/product/v2/w4-select-to-act-spec.md` §"Action enum lock"
    if any enum moves
  - `docs/product/v2/lane-status.md` §"Drift locks" if a new lock class
  - `tests/v2-plan-baseline-test.sh` if fixture count moves
  - This document, if any §"What's NOT locked yet" item starts being
    locked
- Schema deletion is **not allowed** — replace via `schema_version`
  bump.

## 10. Cross-references

- Schema body: `docs/schemas/inline-action-request.schema.json`
- Fixtures: `docs/schemas/fixtures/inline-action-request.{valid,invalid,calc-suggest-chart,impress-translate,writer-custom}.json`
- Spec: `docs/product/v2/w4-select-to-act-spec.md`
- Harness: `tests/v2-inline-action-request-schema-test.sh`
- Baseline regression lock: `tests/v2-plan-baseline-test.sh`
- Lane mirror: `docs/product/v2/lane-status.md` §"W4 — Select-to-act"
- Sibling reader's manual: `docs/schemas/async-task.schema.md` (W5)
