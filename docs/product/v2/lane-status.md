# V2 Lane Status — Living Index

> **Generated**: 2026-05-10 (refresh manually after each ledger entry)
> **Authoritative ledger**: `.agent/goals/2026-05-08-v2-ai-native/ledger.jsonl`
> **Authoritative narratives**: `docs/product/v2/day{0,1}-progress.md`
>
> This file is a **read-only crosswalk** so any contributor (human or
> agent worker) can see at a glance which V2 sub-step is landed,
> which is gated, and which is next-up. It must not contain new
> design decisions — those go in the wave specs (`w[1-5]-*.md`).
>
> Update protocol: after appending a `step_closed` entry to
> `ledger.jsonl`, mirror the row here within the same edit batch.
> If the row already exists with `landed=yes`, only refresh the
> "Last verified" column.

## Wave roll-up

| Wave | Focus | Sub-steps landed | Gated | Pure-logic cppunit |
|---|---|---|---|---|
| W1  | Provider runtime (Ollama-first sandbox)        | step3 + Day-1b      | Day-1c (i18n threading), Day-1d (cloud TLS) | 51 (kqoffice_provider) |
| W2  | Cmd+K palette                                  | Day-1a + RecentStore | Day-1b (.uno: dispatch), Day-1c (pinyin) | 26 (8 idx + 8 fuzzy + 10 recent) |
| W3  | Writer apply-runtime + ApplyPlan validator     | Day-1a/c/d/e/f/g/h   | Day-1b (SwDocShell wiring) | 51 (counted in W1 binary) |
| W4  | Select-to-act (Writer/Calc/Impress action bubble) | —                  | spec-only at this milestone | 0 |
| W5  | Async cowork (long-running tasks + diff review)   | —                  | spec-only at this milestone | 0 |

**ai-native cppunit suite total**: 77 cases (51 provider + 26 cui).

## W1 — Provider Runtime

| Step | Landed | Files | Ledger row | Notes |
|---|---|---|---|---|
| Day-1 step3 | ✅ | `kqoffice/Library_kqoffice_ai.mk`, `Repository.mk:444`, `services.rdb` | L5 | Real UNO component; V1.5 27/27 strict roundtrip post-vis green |
| Day-1b | ✅ | `EvidenceRecorder.{hxx,cxx}`, `Provider.cxx` | (in narrative, pre-ledger) | 16-hex `evidence_id`, JSON envelope locked |
| Day-1c | ⛔ gated | i18npool threading (waiting on auth) | — | Requires touching shared i18n surface |
| Day-1d | ⛔ gated | cloud-mode TLS bring-up | — | Out of scope until offline path stabilizes |

## W2 — Cmd+K Command Palette

| Step | Landed | Files | Ledger row | Notes |
|---|---|---|---|---|
| Day-1a | ✅ | `cui/source/inc/commandpalette/CommandIndex.hxx`, `cui/qa/unit/{CommandIndex,FuzzyMatcher}Test.cxx` | L7 | Header-only fast-test split, 8+8 cases |
| RecentStore | ✅ | `cui/source/inc/commandpalette/RecentStore.hxx`, `cui/qa/unit/RecentStoreTest.cxx` | L8 | JSON round-trip + ranking integration, 10 cases |
| Day-1b | ⛔ gated | `.uno:CommandPalette` accelerator + sfx2 dispatch | — | Touches sfx2 dispatch surface |
| Day-1c | ⛔ gated | i18npool Transliteration_pinyin integration | — | Touches shared i18n surface |

## W3 — Writer Apply Runtime + ApplyPlanValidator

| Step | Landed | Files | Ledger row | Notes |
|---|---|---|---|---|
| Day-1a | ✅ | `kqoffice/source/ai/provider/ApplyPlanValidator.hxx`, `kqoffice/qa/cppunit/test_provider.cxx` | L6 | Header-only schema guard; 14/14 ValidationCode coverage |
| Day-1b | ⛔ gated | `SwDocShell::applyDiagnosticsPlan` wiring | — | Touches sw apply surface |
| Day-1c | ✅ | `applyPlanValidationMessage` zh-CN toast helper (header-only) | L9 | 14 distinct toast strings + field-path suffix |
| Day-1d | ✅ | `apv_findTopKey` / `apv_readString` micro-tests | L10 | +5 cases isolating parser primitives |
| Day-1e | ✅ | `applyPlanValidationStatus` ASCII kebab tokens | L11 | +3 cases; locks 14-token output set |
| Day-1f | ✅ | `docs/schemas/provider-evidence.schema.json` + 3 fixtures | L13 | JSON Schema 2020-12; 17-token enum |
| Day-1g | ✅ | Multi-codepoint UTF-8 boundary fixtures | L12 | +5 cases (emoji, fullwidth, escaped quotes) |
| Day-1h | ✅ | `tests/v2-provider-evidence-schema-test.sh` | L14 | Programmatic schema↔C++ drift lock |

## W4 — Select-to-act

Spec only (`docs/product/v2/w4-select-to-act-spec.md`). No
implementation steps started; no cppunit binaries yet.

## W5 — Async cowork

Spec only (`docs/product/v2/w5-async-cowork-spec.md`). No
implementation steps started.

## Authoritative artifacts

- **Goals** (status snapshot): `.agent/goals/2026-05-08-v2-ai-native/goals.json`
- **Ledger** (append-only timeline): `.agent/goals/2026-05-08-v2-ai-native/ledger.jsonl` (20 entries)
- **Narratives**:
  - `docs/product/v2/day0-skeleton-landed.md` — Day-0 skeleton landing
  - `docs/product/v2/day1-progress.md` — Day-1{a..h} per-step rationale
- **Schemas (V2)**:
  - `docs/schemas/provider-request.schema.json` — request envelope (W1)
  - `docs/schemas/provider-evidence.schema.json` — runtime audit envelope (W1 / W3 Day-1f)
  - `docs/schemas/apply-plan-runtime.schema.json` — W3 Day-1b runtime ApplyPlan envelope (envelope-only; per-kind patch shape lands with each `SwUndoApplyPatch` impl)
- **Schemas explicitly NOT touched**:
  - `docs/schemas/evidence-record.schema.json` — V1.5 m3-02 capability/diagnostic record (different fields, locked by 27/27 strict roundtrip baseline)
  - `docs/schemas/apply-plan.schema.json` — V1.5 m3-02 capability descriptor (per-capability metadata: id / undo_group / failure_behavior). Distinct from V2 `apply-plan-runtime.schema.json` per V2 invariants memory rule #5; do not collapse.

## Drift locks (programmatic)

| Lock | Verified by | Last green |
|---|---|---|
| Schema status enum ↔ C++ apply-plan-* emissions (13/13) | `tests/v2-provider-evidence-schema-test.sh` | 2026-05-09 |
| Defensive `apply-plan-unknown` present in C++, absent from schema | same harness | 2026-05-09 |
| Provider.cxx runtime token subset ⊆ schema runtime enum | same harness | 2026-05-09 |
| 9-key `EvidenceRecorder` envelope shape locked | same harness | 2026-05-09 |
| ApplyPlanValidator.hxx 14-tag enum stable | `testApplyPlanCodeEnumStable` cppunit case | 2026-05-09 |
| `applyPlanValidationStatus` distinct-per-code | `testApplyPlanStatusDistinctPerCode` | 2026-05-09 |
| `applyPlanValidationMessage` distinct-per-code | `testApplyPlanMessageDistinctPerCode` | 2026-05-09 |
| V1.5 27/27 strict roundtrip | `bin/intelligent-contract-fixtures.sh` + downstream pipeline | 2026-05-08 |

## Extended fixture naming (resolved 2026-05-10)

`docs/schemas/fixtures/provider-request.{ok,policy-denied,provider-error}.json`
and `provider-evidence.apply-plan-failure.json` use the
`<schema>.<status-token>.json` extended-naming form. Resolved as
`expectation=valid` against `<schema>.schema.json` by
`bin/intelligent-contract-fixtures.sh`. Strict
`<schema>.{valid,invalid}.json` semantics preserved — only the
fallback branch was added. Verified by canary injection
(broken extended-name fixture → harness FAIL with field-level
diagnostics; swapped-valid `<schema>.invalid.json` → harness FAIL).

## Known issues surfaced by 8-worker sweep (2026-05-10)

Findings from parallel `/parallel --agents 8` lane survey. Each
item names the scope that must own the fix; none are taken silently
because they cross worker scopes or touch release policy.

### I1 — `tests/v2-plan-baseline-test.sh` ✅ RESOLVED 2026-05-10

**Symptom (was)**: `bash tests/v2-plan-baseline-test.sh` exits non-zero.

**Root cause** (test-worker handoff):

1. `bin/intelligent-contract-fixtures.sh` rejected 4 fixtures whose
   names didn't match the `<schema>.{valid,invalid}.json`
   convention:
   - `docs/schemas/fixtures/provider-evidence.apply-plan-failure.json`
     (W3 Day-1f)
   - `docs/schemas/fixtures/provider-request.ok.json` (W1 early)
   - `docs/schemas/fixtures/provider-request.policy-denied.json` (W1 early)
   - `docs/schemas/fixtures/provider-request.provider-error.json` (W1 early)

2. `tests/v2-plan-baseline-test.sh` hard-coded counts
   `Fixtures checked: 18` / `Schemas covered: 9`; actual was `24 / 10`
   once V2 additions were counted.

**Fix landed (2026-05-10)**:

- `bin/intelligent-contract-fixtures.sh` extended-naming branch:
  if a fixture isn't `.valid.json` / `.invalid.json`, take the
  basename's first dot-segment, look for `<candidate>.schema.json`,
  treat as `expectation=valid` if the schema exists. Strict pair
  semantics preserved: `<schema>.invalid.json` is still required
  to actually be invalid; `<schema>.valid.json` still required to
  be valid. Verified by negative tests:
  - `provider-request.broken-canary.json` (extended-name, broken
    payload) → harness reports `failed` with missing-field detail.
  - Swap a valid payload into `provider-request.invalid.json` →
    harness reports `failed` for that pair.
- `tests/v2-plan-baseline-test.sh` baseline counts `18→24`,
  `9→10`. Status banner `Fixtures: 24 across 10 schemas`.
- Report table now carries `Schema` column so any future extended
  fixture's resolved schema is visible at a glance.

**Verification (steady state)**:

```
$ bash tests/v2-plan-baseline-test.sh
Status: passed
Checks: 21
Fixtures: 24 across 10 schemas
V2 specs: master + 5 wave specs present
```

### I2 — CI installer workflow drifts from `autogen.lastrun` (partially RESOLVED 2026-05-10)

**Symptom** (integration-worker-2 handoff): CI
(`.github/workflows/build-installers.yml`) builds produce artifacts
that do not match the local `autogen.lastrun` configuration.

**Drift items**:

| Flag | `autogen.lastrun` | CI workflow | Status |
|---|---|---|---|
| `--with-lang=zh-CN` | ✅ set | ✅ **landed both jobs (2026-05-10)** | RESOLVED |
| `--with-macosx-bundle-identifier=com.kdoffice.app` | ✅ set | ✅ **landed macOS job (2026-05-10)** | RESOLVED |
| `--with-branding=<path>` | `/Users/lu/kdoffice-src/downstream-branding` | `$PWD/downstream-branding` (if dir exists) | **Open — D5 residual** |
| `--enable-macosx-code-signing` | ✅ set | ❌ omitted (README documents this) | Intentional pending Developer ID / EV cert |

**Fix landed (2026-05-10)** — `.github/workflows/build-installers.yml`:

- macOS configure: added `--with-lang=zh-CN` and
  `--with-macosx-bundle-identifier=com.kdoffice.app`.
- Windows configure: added `--with-lang=zh-CN`.
- Branding handling unchanged (still gated on
  `[ -d ".../downstream-branding" ]`); no auto-fetch added.

**Open — D5 residual**: `downstream-branding/` is absent from this
repository. Three documented paths point at it (clavue.md →
`.worktrees/...`, autogen.lastrun → `/Users/lu/kdoffice-src/...`,
workflow → `$PWD/...`), and CI silently builds without branding.
Resolving this requires a release-policy decision (commit
`downstream-branding/` into the repo, fetch as CI step from a
private source, or formally accept skipped branding for upstream
artifacts). Coordinator does **not** auto-pick because each option
has different release/legal implications.

**Verification**:

```
$ python3 -c "import re; ..."   # structural YAML check
jobs: 2, steps: 16
Structural check: OK
$ grep -nE 'with-lang|bundle-identifier' .github/workflows/build-installers.yml
65:            --with-lang=zh-CN
66:            --with-macosx-bundle-identifier=com.kdoffice.app
180:           --with-lang=zh-CN
```

## Open decisions for supervisor

From the 8-worker sweep, concrete picks awaiting user authorization:

| # | Decision | Unblocks |
|---|---|---|
| D1 | Authorize **W3 Day-1b** (`SwDocShell::applyDiagnosticsPlan` wiring, `sw/source/uibase/app/docsh*.cxx`) | code-worker; closes the last W3 Day-1 gate |
| D2 | Authorize **W1 Day-1a** (OllamaAdapter real-backend implementation) | any code-scoped worker; unlocks real provider path |
| D3 | Authorize **W2 popover controller** (`cui/source/dialogs/commandpalette/CommandPalette.cxx` + sfx2 dispatch wiring) | W2 Day-1b; pure-logic substrate already landed |
| D4 | ~~Decide I1 fix~~ | **RESOLVED 2026-05-10** — `bin/` extended-naming + `tests/` count bump landed |
| D5 | ~~Decide I2 fix~~ | **PARTIALLY RESOLVED 2026-05-10** — lang + bundle id landed; branding source-of-truth still open |
| D6 | Re-scope worker owned-paths from `src/**` / `tests/**` (non-existent in this LO build tree) to per-module `<module>/source/**` / `<module>/qa/**` | code-worker-2, test-worker-2 |


