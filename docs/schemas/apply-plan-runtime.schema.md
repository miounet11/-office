# `apply-plan-runtime.schema.json` 人工解读手册

> Reader's guide for the V2 W3 runtime ApplyPlan envelope. The schema
> itself is the single source of truth
> (`docs/schemas/apply-plan-runtime.schema.json`, JSON Schema 2020-12,
> 6 required envelope keys, 7-token `patch.kind` enum,
> `schema_version: const "v2-w3-runtime-1"`,
> `additionalProperties: false` at envelope level, **open at
> `patches[]` item level by design**). This doc explains *why* each
> envelope key exists, why per-kind patch shape is intentionally open,
> and what's locked versus deferred.
>
> **Audience**: someone hand-writing a new `SwUndoApplyPatch`
> implementation (W3 Day-1b/c/d land one per patch kind), or a
> diagnostic-generator author producing a Plan for `SwDocShell::
> applyDiagnosticsPlan` to consume.
>
> **Token-lock anchors**: W3 spec §"Patch Kinds（v1）" and §"Apply
> Pipeline" (`docs/product/v2/w3-writer-apply-runtime-spec.md`).
>
> **Sibling reference**: `async-task.schema.md` (W5 envelope manual,
> L45) and `inline-action-request.schema.md` (W4 envelope manual,
> L49) — same documentation pattern.

## 1. Where this envelope lives

Per-call payload, not persistent. One Plan is constructed each time
an intelligent diagnostic pass wants to apply its recommendations to
a Writer document:

```
IntelligentWriterAnalyzer::emitPlan()
   → builds apply-plan-runtime envelope
   → SwDocShell::applyDiagnosticsPlan(plan)
   → each patch → SwUndoApplyPatch (per-kind impl)
   → single EnterListAction wraps the Plan → Cmd+Z undoes whole Plan
   → evidence_id written to provider-evidence record (W1)
   → envelope discarded after dispatch; replayable via fixture roster
```

- Distinct from `apply-plan.schema.json` (V1.5 m3-02
  per-capability descriptor: id / undo_group / failure_behavior).
  V2 invariants memory rule #5: **do not collapse these two
  schemas**. Runtime envelope ≠ capability metadata.
- Distinct from `async-task.schema.json` (W5 per-task persistent
  record) and `inline-action-request.schema.json` (W4 per-trigger
  request). This is the *result* envelope — an inline-action
  request or async-task step eventually produces one of these.

## 2. Envelope required keys (6)

| Key | Type | Pattern / enum | Why required |
|---|---|---|---|
| `schema_version` | string | `const: "v2-w3-runtime-1"` | Bumped only on non-additive change. The `-runtime-` infix distinguishes from V1.5 `apply-plan.schema.json`'s own versioning. Lets `SwDocShell::applyDiagnosticsPlan` fail fast on unknown envelopes instead of silently mis-applying. |
| `plan_id` | string | `^ap-[a-z0-9-]{3,80}$` | Per-Plan unique id. `ap-` prefix parallels `ev-` (evidence) and `iar-` (inline-action-request) shape — short prefix + opaque body. Used as the argument to `EnterListAction("Apply AI Plan {plan_id}")` so it surfaces verbatim in the Undo stack. |
| `source_diagnostic_id` | string | `^diag-[a-z0-9-]{3,80}$` | Back-pointer to the IntelligentWriterAnalyzer diagnostic that generated this Plan. Lets evidence walk Plan → Diagnostic → original rule. |
| `doc_snapshot_hash` | string | `^sha256:[a-f0-9]{64}$` | SHA-256 of the `SwDoc` state observed when the Plan was generated. `SwDocShell::applyDiagnosticsPlan` recomputes before apply — if it drifts, reject with `stale-snapshot` (W3 spec §"Failure Modes" row 2). This is the main guard against "user edited the doc between diagnostic and apply." |
| `patches` | array | `minItems: 1, maxItems: 256` | The actual patches. `minItems: 1` rejects empty Plans (no-op Plans should be suppressed upstream — empty is ambiguous between "diagnostic found nothing" and "generator bug"). `maxItems: 256` is a soft DoS ceiling — no real diagnostic pass should emit more than a few dozen patches; 256 is "clearly a bug" threshold. |
| `preview_only` | boolean | — | `true` = diff sidebar preview mode (no mutation); `false` = actually apply. Required (not optional with a default) because silent defaulting is a footgun — "did I just mutate the doc?" should never be unclear. |

## 3. Patch object (3 required + 2 optional + **open tail**)

```jsonc
{
  "patch_id": "p1",                            // ^p[0-9]+$
  "kind": "paragraph-replace",                 // 7-token enum
  "target": {"paragraph_id": "swpara-42"},     // ^swpara-[0-9]+$
  "severity": "minor",                         // minor | normal | major
  "rationale": "去除冗余表述",                  // optional, ≤2000 chars
  // per-kind fields below are INTENTIONALLY OPEN at schema layer
  "before": "本段表述太啰嗦，重复说了好几遍。",
  "after":  "本段表述简洁，无重复。"
}
```

### 3.1 Required patch keys (3)

| Key | Why required |
|---|---|
| `patch_id` | `^p[0-9]+$`, per-Plan ordinal. Used in evidence diff reports ("patch p3 applied; p4 rolled back") and in Undo stack sub-entries. |
| `kind` | 7-token enum; the discriminator that routes to the right `SwUndoApplyPatch` subclass. |
| `target` | `{paragraph_id: ^swpara-[0-9]+$}` — locked here because every v1 kind targets a single paragraph. v1.5 kinds (tables, inline objects, cross-paragraph ranges) will extend target shape and bump `schema_version`. |

### 3.2 Optional patch keys (2)

| Key | Why optional |
|---|---|
| `severity` | `minor \| normal \| major` — cosmetic hint for Diff sidebar grouping. Omitted = "unspecified," UI renders neutrally. Not used for dispatch decisions. |
| `rationale` | Free-form ≤2000 char explanation shown in Diff sidebar tooltip. Provider-supplied. 2000-char cap is a UI guard — no tooltip should show more. |

### 3.3 Why `patches[]` items are schema-open

The patch object has **no `additionalProperties: false`** at the
item level. The fixtures use `before`/`after`/`format_changes`/
`range` freely. This is intentional, not a schema gap:

- The envelope locks what's stable across all kinds (id / kind / target / severity / rationale).
- Per-kind payload (what a `paragraph-replace` carries vs. a `text-format`) lands with its `SwUndoApplyPatch` impl (W3 Day-1b/c/d), not here.
- Locking a union at envelope time would force every kind's full shape to be defined before any kind could ship.
- **The schema accepts a well-formed envelope with garbage per-kind fields.** That's not a bug — validation of per-kind fields is the implementation's job (`SwUndoApplyPatchParagraphReplace::validate()` etc.). The C++ ApplyPlanValidator returns one of 14 `ValidationCode` enum values; `apply-plan-unknown-kind-fields` is one of them (W3 Day-1c).

## 4. The 7-token `kind` enum (order locked)

From W3 spec §"Patch Kinds（v1）" table — order mirrors spec order:

| Token | 描述 | SwUndoApplyPatch impl owner |
|---|---|---|
| `paragraph-replace`       | 整段文字替换 (SetText + Undo)            | W3 Day-1b |
| `paragraph-insert-after`  | 在段落后插新段 (AppendTextNode)          | W3 Day-1b |
| `paragraph-delete`        | 删除段落 (DelFullPara)                   | W3 Day-1b |
| `paragraph-format`        | 改段落样式 (SetTxtFmtColl)               | W3 Day-1c |
| `paragraph-reformat`      | 改段落属性缩进/间距 (SwParaFormatProperty)| W3 Day-1c |
| `text-range-replace`      | 段落内 range 替换 (SwPaM + ReplaceRange) | W3 Day-1d |
| `text-format`             | 段落内 range 格式 (SetFormat)            | W3 Day-1d |

Not-in-v1 (deferred to W3.5; will bump `schema_version`):
`table-cell-*`, `inline-object-*`, cross-paragraph range ops.

## 5. What's intentionally NOT locked

Each of these would bump `schema_version` if promoted:

- **Per-kind payload shape** (§3.3). Intentionally deferred to
  `SwUndoApplyPatch` impls + C++ `ApplyPlanValidator`.
- **Cross-patch ordering dependencies**. The schema accepts
  `[p3, p1, p2]`. `SwDocShell::applyDiagnosticsPlan` applies in
  array order; if patches have ordering dependencies (e.g.
  `paragraph-delete` p1 before `paragraph-format` p2 that targets
  same paragraph), the generator is responsible for emitting the
  correct order.
- **Total-change size cap**. `maxItems: 256` caps patch count, not
  cumulative text bytes. A generator that emits 256 × 100KB
  `paragraph-replace` patches would be schema-valid and runtime-
  catastrophic. Budget enforcement is W3 spec §"Performance
  Budget" territory, not schema.
- **Cross-field `preview_only=true ⇒ doc_snapshot_hash ignored`**.
  The hash is always required and always checked; preview mode
  just skips mutation. Schema does not branch on this.
- **Per-patch evidence_id back-pointer**. Evidence is at Plan level
  (`ev-…`), not per-patch. A per-patch `evidence_id` may arrive
  when diff-review UI needs it (W4-D territory).

## 6. Fixture coverage matrix

3 fixtures under `docs/schemas/fixtures/` exercise the schema:

| Fixture | Locks |
|---|---|
| `apply-plan-runtime.valid.json` | 3-patch mixed-kind envelope (paragraph-replace + paragraph-format + text-format); exercises all 3 optional severity values (minor/minor/normal); per-kind open-tail fields (`before`/`after`/`format_changes`/`range`) populated to show the open-tail contract. |
| `apply-plan-runtime.utf8.json` | Extended-naming UTF-8 multi-codepoint boundary (L44): 4-byte emoji (U+1F389), ZWJ family sequence (11-byte grapheme), escaped quotes in format_changes, RTL Hebrew+Arabic mix, CJK Extension B (U+20000+) — all pass round-trip; locks `apv_readString` / `apv_findTopKey` byte-semantic behavior. |
| `apply-plan-runtime.invalid.json` | 5 distinct violations: `plan_id` pattern (uppercase), `doc_snapshot_hash` pattern (no sha256 prefix), `patch_id` pattern (uppercase + underscore), `kind` enum (bogus token), `target.paragraph_id` pattern (wrong prefix), `severity` enum (`critical` not in enum). |

Adding a 4th fixture: drop a new file matching
`apply-plan-runtime.<status-token>.json` (extended-naming) for
valid payloads, or `apply-plan-runtime.invalid.json` for invalid
(strict naming). H2 baseline must be bumped same-commit
(`tests/v2-plan-baseline-test.sh` fixture count assertion).

## 7. Reader checklist (SwDocShell / diagnostic generator / replay)

Before consuming a Plan envelope:

1. **Verify `schema_version == "v2-w3-runtime-1"`**. Fail loud on
   any other value — don't silently degrade to V1.5
   `apply-plan.schema.json` semantics (different schema entirely).
2. **Recompute `doc_snapshot_hash` against current `SwDoc`**.
   Mismatch ⇒ return `stale-snapshot`; caller must re-generate
   from the current doc state. This is the only envelope-level
   check that depends on runtime state.
3. **Iterate `patches[]` in array order**. Order is load-bearing
   (§5). Do not parallelize or reorder.
4. **Route each `kind`** through the matching `SwUndoApplyPatch`
   subclass. Unknown kind ⇒ `ApplyPlanValidator` emits
   `apply-plan-unknown-kind` (14-token enum — see W3 Day-1a).
5. **Wrap the full iteration in one `EnterListAction("Apply AI
   Plan {plan_id}")`**. Cmd+Z must undo the whole Plan as one
   entry. Partial failure mid-iteration: roll back the prior K-1
   applied patches, return `patch-failed` with per-patch status.
6. **Respect `preview_only`**. True ⇒ compute diff + render to
   sidebar, do not mutate. False ⇒ mutate.

## 8. Authority and change control

- Locked by **H2** (`tests/v2-plan-baseline-test.sh`) via the
  canonical contract fixtures run (3 fixtures × 1 schema counted
  in the 36/13 baseline).
- Locked by **H1** (`tests/v2-provider-evidence-schema-test.sh`)
  via the schema ↔ C++ apply-plan status-token drift check
  (13-token runtime enum; `apply-plan-unknown` is C++-only
  defensive, not in schema).
- ApplyPlanValidator 14-tag enum stability locked by
  `testApplyPlanCodeEnumStable` cppunit case; per-code messages
  locked by `testApplyPlanMessageDistinctPerCode`.
- Any change to the schema body requires same-batch updates to:
  - `docs/product/v2/w3-writer-apply-runtime-spec.md` §"Patch
    Kinds（v1）" if any kind moves
  - `docs/product/v2/lane-status.md` §"Drift locks" if a new lock
    class
  - `tests/v2-plan-baseline-test.sh` if fixture count moves
  - This document, if any §"What's NOT locked" item starts being
    locked
- Schema deletion is **not allowed** — replace via `schema_version`
  bump.

## 9. Cross-references

- Schema body: `docs/schemas/apply-plan-runtime.schema.json`
- Fixtures: `docs/schemas/fixtures/apply-plan-runtime.{valid,invalid,utf8}.json`
- Spec: `docs/product/v2/w3-writer-apply-runtime-spec.md`
- Harness: `tests/v2-plan-baseline-test.sh`,
  `tests/v2-provider-evidence-schema-test.sh`
- C++ validator: `kqoffice/source/ai/provider/ApplyPlanValidator.hxx`
  (header-only; 14 `ValidationCode` enum values; each maps to
  distinct status token + distinct zh-CN toast message + field path)
- Lane mirror: `docs/product/v2/lane-status.md`
  §"W3 — Writer Apply Runtime + ApplyPlanValidator"
- Sibling reader's manuals:
  `docs/schemas/async-task.schema.md` (W5),
  `docs/schemas/inline-action-request.schema.md` (W4)
