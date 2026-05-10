# V2 Day-1 Progress Log

Date: 2026-05-08
Wave: V2 W1 (Provider Runtime)
Spec: `docs/product/v2-master-plan.md`, `docs/product/v2/w1-provider-runtime-spec.md`
Companion: `docs/product/v2/day0-skeleton-landed.md`

## Scope of this log

Day-1 work proceeds incrementally on top of the Day-0 skeleton. Each
sub-step (Day-1a, Day-1b, …) is its own landing entry below. Items still
listed in `day0-skeleton-landed.md`'s "Day-1 next picks" but not yet
landed remain pending and are tracked in the goal ledger
(`.agent/goals/2026-05-08-v2-ai-native/ledger.jsonl`).

## W1 Day-1b — EvidenceRecorder + provider-error evidence id (LANDED)

Picked out of order before W1 Day-1a because evidence persistence is the
foundation other Day-1 picks (Ollama adapter, Cmd+K dispatcher) will
depend on for trust + auditability — V2 invariant: every approved AI
mutation must carry an `evidenceId` traceable to a per-request envelope.

### What landed

- New `EvidenceRecorder` (in `kqoffice/source/ai/provider/`):
  - Mints evidence id format `ev-<YYYYMMDDHHMMSS>-<seq>`,
    where `<seq>` is a monotonically increasing per-process counter
    so two calls in the same second still produce distinct ids.
  - Persists request envelope as JSON to
    `${UserInstallation}/ai-evidence/YYYY-MM/<evidence_id>.json`.
    Month-bucketed directory keeps a single evidence dir from growing
    unbounded over a project lifetime; matches the
    `preview→approve→apply→evidence` pipeline invariant.
  - Envelope fields: `evidenceId`, `capability`, `serviceMode`,
    `promptHash` (not raw prompt — V2 invariant: no silent upload, and
    even local evidence avoids storing raw user prose by default),
    `timestampUtc`, `status`.
- `Provider::call()` updated:
  - On the `provider-error` path (capability allowed by
    `ServiceModePolicy` but no backend wired in Day-0/Day-1a),
    Provider now mints an evidence id via `EvidenceRecorder` and
    populates `ProviderResponse.evidenceId` before returning.
  - On the `policy-denied` path, `evidenceId` stays empty by design —
    a denied request never reached the provider runtime, so there is
    no envelope to persist. This is asserted in
    `testEvidenceIdEmptyOnPolicyDenied` (carried over from Day-0).

### Test results

`CppunitTest_kqoffice_provider` grew from 7 to **10 cases**, all green:

- (existing 7 from Day-0): policy gating × 4, empty-input rejection,
  mode accessor, stub error contract.
- (new) `testEvidenceIdMintedOnProviderError` — provider-error path
  returns non-empty `evidenceId` matching `^ev-\d{14}-\d+$`.
- (new) `testEvidenceFileWrittenWithCapability` — after a call, the
  expected JSON file exists under
  `${UserInstallation}/ai-evidence/YYYY-MM/` and contains the
  request's `capability` field.
- (new) `testEvidenceIdsAreUniqueAcrossCalls` — three back-to-back
  calls produce three distinct evidence ids (guards the seq counter).

Run log: `workdir/CppunitTest/kqoffice_provider.test.log` —
final line `OK (10)`.

### Files touched (SRCDIR — out of docs-worker scope, reported as blocker)

```
new   kqoffice/source/ai/provider/EvidenceRecorder.{cxx,hxx}
edit  kqoffice/source/ai/provider/Provider.cxx          (+ recorder wiring)
edit  kqoffice/source/ai/provider/Provider.hxx          (+ recorder member)
edit  kqoffice/Library_kqoffice_ai.mk                   (+ EvidenceRecorder.cxx)
edit  kqoffice/qa/cppunit/test_provider.cxx             (+ 3 cases, ~80 lines)
```

The doc-side update is `day0-skeleton-landed.md` (renumbered "Day-1
next picks" to 4 items, added "Landed in W1 Day-1b" block) plus this
file.

### Invariants preserved

- Offline-first: no network call introduced; recorder writes only to
  `${UserInstallation}` (per-profile, on-disk, never auto-uploaded).
- No silent upload: envelope stores `promptHash` only, not raw prompt.
- ApplyPlan-based structured patches: unchanged — Day-1b is
  pre-mutation telemetry, no patch surface touched.
- preview→approve→apply→evidence pipeline: this lands the **evidence**
  endpoint; upstream stages remain Day-1+/W2+ work.
- V1.5 8/9 beta gates: unchanged (no V1.5 code path modified).
- 18 contract fixtures: unchanged (no fixture rename/delete).
- No ApplyPlan/Evidence forks: `EvidenceRecorder` is the single
  evidence writer; nothing else writes under `ai-evidence/`.

## W1 Day-1 step 3 — Library_kqoffice_ai as real UNO component (LANDED)

Closes Day-1 step 3: `kqoffice_ai` is wired as a SharedLibrary UNO
component, registered through the install pipeline, and discoverable by
`com.sun.star.ai.Provider` via the runtime services rdb.

### What landed

- `kqoffice/util/kqoffice_ai.component` — descriptor:
  - `loader=com.sun.star.loader.SharedLibrary`, `environment=@CPPU_ENV@`
    (resolves to `gcc3` on this build).
  - `implementation name="com.kqoffice.ai.Provider"` with constructor
    `com_kqoffice_ai_Provider_get_implementation`.
  - `service name="com.sun.star.ai.Provider"`.
- `kqoffice/Library_kqoffice_ai.mk:25` — adds
  `gb_Library_set_componentfile,kqoffice_ai,kqoffice/util/kqoffice_ai,services`
  so the component file is captured and copied into `services.rdb`.
- `Provider.cxx` — exposes
  `_com_kqoffice_ai_Provider_get_implementation` factory using the sw
  WriterFilter idiom (`::cppu::acquire(new Provider())`).
- `Repository.mk:444` — `kqoffice_ai` registered for install in the
  `OOOLIBS,ooo` group (sits with other shared runtime libs the suite
  loads at boot, no scripting/db gating).

### Acceptance evidence

- `make CppunitTest_kqoffice_provider` → `OK (13)` — pure-logic suite
  unchanged, no use_ure / use_vcl / BootstrapFixture.
- `nm -gU instdir/可圈office.app/Contents/Frameworks/libkqoffice_ailo.dylib`
  shows the factory + every Provider/OllamaAdapter/ServiceModePolicy/
  EvidenceRecorder member symbol exported (see Day-1 step-2 entry for
  the rationale on `SAL_DLLPUBLIC_EXPORT` over `SAL_DLLPUBLIC_RTTI`).
- `workdir/Rdb/services.rdb` and
  `instdir/可圈office.app/Contents/Resources/services/services.rdb` both
  advertise `com.kqoffice.ai.Provider` with
  `uri="vnd.sun.star.expand:$LO_LIB_DIR/libkqoffice_ailo.dylib"`.
- V1.5 27/27 strict roundtrip last reconfirmed under run name
  `v2-w1-d1-step3-postvis-compatibility-smoke` (docx 9/9, xlsx 9/9,
  pptx 9/9). Not re-run for this doc-only landing — no code path
  touched on the V1.5 surface.

### Invariants preserved

- 13/13 cppunit + V1.5 27/27 stay green.
- Provider IDL/impl/service names unchanged: `com.sun.star.ai.XProvider`,
  `com.kqoffice.ai.Provider`, `com.sun.star.ai.Provider`. No
  `com.kdoffice.AI`.
- OllamaAdapter still pure BSD socket — no libcurl, no TLS introduced.
- `policy-denied` remains the only branch with empty `evidenceId`.
- Same TUs compile into Library_kqoffice_ai and
  CppunitTest_kqoffice_provider; cppunit does **not** gain
  `use_library_objects(kqoffice_ai)` (cppunit stays decoupled).

### Files touched

```
new   kqoffice/util/kqoffice_ai.component
edit  kqoffice/Library_kqoffice_ai.mk          (+ set_componentfile)
edit  kqoffice/source/ai/provider/Provider.cxx (+ factory entry point)
edit  Repository.mk                            (+ kqoffice_ai in OOOLIBS,ooo)
```

### Optional (not required for step-3 close)

Runtime UNO loader smoke — instantiate `com.sun.star.ai.Provider` via
the service manager from a running `soffice` and call `getServiceMode()`
— deferred to W1 Day-1a where the full provider/Ollama path becomes
exercisable end-to-end. Static install-side proof above is sufficient
to consider step 3 closed.

## W2 Day-1a — `CommandIndex` + `FuzzyMatcher` fast-test split (LANDED)

W2 (Cmd+K Command Palette) Day-1a lands the corpus + matcher pieces
that the popover will consume in Day-1b. Both are pure-logic and
header-only so cppunit can exercise them without bringing the cui
library into the test link graph.

### What landed

- New `cui/source/inc/commandpalette/CommandIndex.hxx` — corpus type
  (`std::vector<CommandEntry>`) with `unoCommand`, English label,
  zh-CN label, `pinyinFirst`, `pinyinFull`, and `frequency` fields.
  Persisted form is filled by `RecentStore::applyFrequencies`.
- New `cui/source/inc/commandpalette/FuzzyMatcher.hxx` — header-only
  matcher returning ranked `Hit{ entry*, score }`. Score blends prefix
  + substring + pinyin-prefix + recency boost (`frequency / 10`).
- New cppunit binaries:
  - `CppunitTest_cui_commandpalette_index` (8 cases) — corpus build,
    de-dup, frequency apply.
  - `CppunitTest_cui_commandpalette_fuzzy` (8 cases) — pure-logic
    ranking + tie-break.
- `cui/Module_cui.mk` registers both under `add_check_targets`.

### Test results

Both binaries report `OK` under `make CppunitTest_cui_commandpalette_index`
and `make CppunitTest_cui_commandpalette_fuzzy`. Total fast-test cppunit
across W2 Day-1a: **16 cases** (8 + 8).

### Files touched (SRCDIR)

```
new   cui/source/inc/commandpalette/CommandIndex.hxx
new   cui/source/inc/commandpalette/FuzzyMatcher.hxx
new   cui/qa/unit/CommandIndexTest.cxx
new   cui/qa/unit/FuzzyMatcherTest.cxx
new   cui/CppunitTest_cui_commandpalette_index.mk
new   cui/CppunitTest_cui_commandpalette_fuzzy.mk
edit  cui/Module_cui.mk                                (+ add_check_targets)
```

## W2 Day-1a' — `RecentStore` persistence + ranking integration (LANDED)

Closes the W2 Day-1a corpus path: persists `useCount` + `lastUsed` to
`${UserInstallation}/cmdpalette/recent.json` and feeds the data back
into the fuzzy ranking through `applyFrequencies`.

### What landed

- New `cui/source/inc/commandpalette/RecentStore.hxx` (header-only):
  - `parseRecentJson` / `serializeRecentJson` — round-trippable JSON
    with `version: 1` schema.
  - `bump(entries, unoCommand, lastUsed, maxEntries=...)` — increments
    or inserts; sorts by `useCount desc`, `lastUsed desc`; caps to
    `maxEntries`.
  - `applyFrequencies(corpus, recents)` — maps `useCount × 10` into
    `CommandEntry.frequency` so `FuzzyMatcher::match` adds a `freq/10`
    recency boost to ranked hits.
- `CppunitTest_cui_commandpalette_recent` (10 cases) — round-trip,
  schema-version reject, bump merge/cap, recency-boost-affects-ranking.

### Test results

`make CppunitTest_cui_commandpalette_recent` → green. Suite total
for W2 Day-1a + Day-1a' is **26 cases** (8 + 8 + 10), zero use of
`use_ure` / `use_vcl` / BootstrapFixture.

### Schema notes

- File path: `${UserInstallation}/cmdpalette/recent.json`.
- Body: `{ "version": 1, "entries": [{ "unoCommand": ".uno:Bold",
  "lastUsed": "2026-05-08T13:00:00", "useCount": 42 }, … ] }`.
- Older readers must opt out cleanly when `version` differs — the
  `testParseRejectsWrongVersion` case enforces it.

### Files touched (SRCDIR)

```
new   cui/source/inc/commandpalette/RecentStore.hxx
new   cui/qa/unit/RecentStoreTest.cxx
new   cui/CppunitTest_cui_commandpalette_recent.mk
edit  cui/Module_cui.mk                                (+ add_check_targets)
```

## W3 Day-1a — `ApplyPlanValidator` header-only schema guard (LANDED)

W3 (Writer Apply Runtime) starts with the **runtime guard** that gates
every server-issued ApplyPlan before any document mutation. The
authoritative contract is the frozen
`docs/schemas/apply-plan.schema.json` (m3-02). `ApplyPlanValidator`
encodes that schema as a pure-logic, header-only check so a future
`SwDocShell::applyDiagnosticsPlan` call site can fail closed without
dragging a JSON Schema runtime into the build.

### What landed

- New `kqoffice/source/ai/provider/ApplyPlanValidator.hxx`:
  - `enum class ApplyPlanValidationCode` — 14 codes (1 OK + 13 specific
    failure tags). Tags map 1:1 to schema-violation classes so a
    localized UI layer can surface "stale revision" / "schema mismatch"
    without re-implementing the schema.
  - `struct ApplyPlanValidationResult { code, errorPath }` — `errorPath`
    is JSON-pointer-ish (e.g. `/undo_group/label_zh`) so toast strings
    can name the exact failed key.
  - `static ApplyPlanValidator::validate(const OString&)` — single entry
    point, header-only inline so it can be exercised from cppunit
    without linking libkqoffice_ai (matches the FuzzyMatcher /
    CommandIndex / RecentStore fast-test pattern).
  - Linear-scan parser in `detail::` — `apv_findTopKey` (depth-aware,
    quote-aware, top-level only), `apv_readString` (with full JSON
    escape handling), `apv_readBool`, `apv_idPatternOk`
    (regex `^[a-z0-9][a-z0-9.-]{2,80}$` rendered as a hand loop). No
    third-party JSON parser — same hermetic style as
    `OllamaAdapter::parseModelsJson` / `RecentStore::parseRecentJson`.

### Test results

`CppunitTest_kqoffice_provider` grew from **15 to 30 cases** (15 new
ApplyPlan cases on top of W1 Day-0/1b base), all green. Suite total
across ai-native cppunit binaries:

```
kqoffice_provider          15 → 30   (+15)
cui_commandpalette_fuzzy        8    (unchanged)
cui_commandpalette_index        8    (unchanged)
cui_commandpalette_recent      10    (unchanged)
─────────────────────────────────
total                      41 → 60   (+19, no regressions)
```

ValidationCode coverage is 14/14 (100%), including:

- **`Ok` × 3** — valid fixture, 81-char id boundary (longest legal),
  unknown extension keys (forward-compat is intentional).
- **`NotJsonObject`** — empty / `[1,2,3]` / `null`.
- **`MissingField`** — drop `schema_version`; reports
  `errorPath="/schema_version"`.
- **`SchemaVersionMismatch`** — `m3-99` instead of `m3-02`.
- **`IdPatternMismatch` × 3** — uppercase (`Writer.X`), too short (2
  chars), too long (82 chars). Boundary tests nail the 81/82
  off-by-one.
- **`RevisionPreconditionBad`** — `any-revision`.
- **`DeterministicNotTrue`**, **`RollbackRequiredNotTrue`**,
  **`RepeatedDiagnosticsBad`** — explicit `false`.
- **`UndoGroupModeBad`** — `per-paragraph` instead of `one-user-action`.
- **`UndoLabelEmpty`**, **`OperationSummaryEmpty`**,
  **`FailureMessageEmpty`** — empty required strings.
- **`FailureBehaviorBad`** — `"partial"` instead of required `"none"`,
  flagged on the `apply-plan.invalid.json` fixture.
- **Metaguard** `testApplyPlanCodeEnumStable` — locks enum count = 14
  so a future contributor that adds a 15th code without a matching
  cppunit case trips the assertion immediately.

Inline JSON literals are embedded in the test TU per case (mirrors of
`docs/schemas/fixtures/apply-plan.{valid,invalid}.json`) — no disk
reads, no SRCDIR lookup, suite stays hermetic.

### Files touched (SRCDIR — out of docs-worker scope, reported as blocker)

```
new   kqoffice/source/ai/provider/ApplyPlanValidator.hxx       (~310 lines)
edit  kqoffice/qa/cppunit/test_provider.cxx                    (+15 cases, ~440 lines)
```

`CppunitTest_kqoffice_provider.mk` already had
`-I$(SRCDIR)/kqoffice/source/ai/provider` on its include path, so no
makefile change was required to surface the header to the test TU.

### Invariants preserved

- Header-only validator (fdo#47246-safe): no library linkage, no
  `Library_kqoffice_ai.mk` edit; the test binary inlines the
  `validate()` body without dragging libkqoffice_ai into its link
  graph.
- `ApplyPlanValidator` runs **before** any document mutation — the
  whole point of the W3 guardrail. No SwDocShell wiring yet (deferred
  to W3 Day-1b which gates on authorization for the SwDocShell apply
  surface).
- Provider IDL/impl/service names unchanged: `com.sun.star.ai.XProvider`,
  `com.kqoffice.ai.Provider`, `com.sun.star.ai.Provider`.
- OllamaAdapter unchanged — no libcurl, no TLS introduced.
- 18 contract fixtures: unchanged.
- V1.5 27/27 strict roundtrip not re-run for this header-only landing
  (no V1.5 code path touched).

### Why header-only

The validator is a 14-tag classifier on a small schema; no .cxx
compilation unit means:

1. cppunit can exercise it without `use_library_objects` /
   `use_libraries` plumbing — the test TU's `#include` is enough.
2. The future call site (`SwDocShell::applyDiagnosticsPlan`) can
   include the header directly and let the optimizer inline the const
   comparisons, which dominate the validation cost on the hot path.
3. No fdo#47246 macOS hidden-visibility duplicate-object risk.

### Pending W3 picks (not started)

1. **W3 Day-1b** — wire `ApplyPlanValidator::validate()` into
   `SwDocShell::applyDiagnosticsPlan` (or its V2 successor) so a
   non-OK result short-circuits the apply with a typed error code.
   Gated on authorization — touches the sw apply surface.

## W3 Day-1c — `applyPlanValidationMessage` localized toast helper (LANDED)

Pure-logic complement to W3 Day-1a: maps every `ApplyPlanValidationCode`
to a terse zh-CN toast string and appends the failed `errorPath` when
present. Lives in the same header so the future `SwDocShell` call site
can use it without an extra TU.

### What landed

- `kqoffice/source/ai/provider/ApplyPlanValidator.hxx`:
  - New free function `applyPlanValidationMessage(const
    ApplyPlanValidationResult&) → OUString`. Returns `""` on `Ok`, a
    distinct localized string per failure code, and appends
    "（字段：<errorPath>）" when non-empty. All 14 codes covered in a
    single switch.
- `kqoffice/qa/cppunit/test_provider.cxx`:
  - +4 cases (38 total). `testApplyPlanMessageDistinctPerCode` does an
    O(N²) pair-wise comparison of every base message to guard against
    copy-paste collisions; `testApplyPlanMessageHandlesEmptyPath`
    locks the no-suffix branch for `NotJsonObject`.

### Test results

`CppunitTest_kqoffice_provider` 34 → **38 cases**, all green. Full
ai-native cppunit total: **64** (38 + 26).

### Why a free function (not a class method)

`applyPlanValidationMessage` is a pure mapping with no state — making
it a free function avoids forcing every call site to construct a
`Localizer` object, and keeps the helper trivially inlineable. The
linkage matches the rest of the file (`inline` in `kqoffice::ai::`).

### Files touched (SRCDIR)

```
edit  kqoffice/source/ai/provider/ApplyPlanValidator.hxx (+ ~70 lines)
edit  kqoffice/qa/cppunit/test_provider.cxx              (+ 4 cases, ~95 lines)
```

### Invariants preserved

- Header-only: no library linkage change, no `Library_kqoffice_ai.mk`
  edit. Suite stays decoupled from libkqoffice_ai.
- All zh-CN strings are inline `u"…"_ustr` literals, not RID lookups —
  this matches existing kqoffice/ai status strings (no .src/.po
  surface added).
- No regression on validate() — body unchanged.

## W3 Day-1d — `apv_findTopKey` / `apv_readString` micro-tests (LANDED)

Adds direct micro-coverage for the two parser primitives that
`validate()` builds on. Every `validate()` failure mode is already
end-to-end covered (W3 Day-1a, 16/14 codes), but the helpers
themselves had no isolated tests — a future refactor that broke their
contract could shift the failure mode (wrong errorPath, false
positive on nested keys, etc.) without breaking any black-box test.

### What landed

`kqoffice/qa/cppunit/test_provider.cxx`, +5 cases:

- `testApvFindTopKeyBasic` — locates `"schema_version"`, returns byte
  index right after the colon; missing key → `-1`.
- `testApvFindTopKeyIgnoresNestedSameKey` — `"label_zh"` inside
  `undo_group` must NOT match a top-level lookup. Depth-aware lookup
  is the whole point of this helper.
- `testApvFindTopKeyIgnoresKeyInStringValue` — `"schema_version"`
  appearing inside another value's string literal must not be
  matched. Quote-awareness regression guard.
- `testApvReadStringDecodesEscapes` — locks the standard escape table
  (`\" \\ \/ \n \t \r \b \f`) and the unknown-escape passthrough
  policy.
- `testApvReadStringRejectsNonString` — number / bool / empty input
  → `isPresent=false`, so callers fall through to the bool reader.

### Test results

`CppunitTest_kqoffice_provider` 38 → **43 cases**, all green.

## W3 Day-1e — `applyPlanValidationStatus` ASCII status tokens (LANDED)

Companion to the localized toast helper. Maps every
`ApplyPlanValidationCode` to a stable kebab-case ASCII token used for
the evidence record's `status` field. zh-CN toast strings are user-facing;
the status token is for grep-ability in audit logs and stays ASCII
regardless of locale.

### What landed

- `kqoffice/source/ai/provider/ApplyPlanValidator.hxx`:
  - New free function
    `applyPlanValidationStatus(ApplyPlanValidationCode) → OString`.
    Returns `"ok"` for success, `"apply-plan-<reason>"` for each
    failure code. All 14 codes covered.
- `kqoffice/qa/cppunit/test_provider.cxx`:
  - +3 cases (46 total).
    `testApplyPlanStatusOkString` —
    success token is `"ok"`, matching what `EvidenceRecorder` already
    writes for successful provider calls. The future SwDocShell apply
    surface can therefore use the same token on the success branch.
    `testApplyPlanStatusDistinctPerCode` — O(N²) collision guard.
    `testApplyPlanStatusIsAsciiKebab` — every byte must be in
    `[a-z0-9-]`, all failure tokens must start with `"apply-plan-"`.

### Test results

`CppunitTest_kqoffice_provider` 43 → **46 cases**, all green. Total
ai-native cppunit suite **72 cases** (46 provider + 26 cui).

### Why a separate function (vs reusing the localized message)

- Locale independence: audit greps shouldn't depend on the user's UI
  language.
- Bandwidth: tokens are 11–35 bytes vs. ~30 zh-CN code points
  (≈ 60+ bytes UTF-8). At V2 scale (every refused apply emits one
  envelope) this matters.
- Testability: the kebab-case shape is a hard schema, so the
  `testApplyPlanStatusIsAsciiKebab` byte-by-byte check is a real
  regression guard.

### Files touched (SRCDIR)

```
edit  kqoffice/source/ai/provider/ApplyPlanValidator.hxx (+ ~30 lines)
edit  kqoffice/qa/cppunit/test_provider.cxx              (+ 3 cases, ~80 lines)
```

### Invariants preserved

- Header-only: no library linkage change.
- `validate()` body unchanged.
- Token namespace `apply-plan-*` does not collide with existing
  Provider status strings (`"ok"`, `"provider-error"`,
  `"policy-denied"`).

## W3 Day-1g — Multi-codepoint UTF-8 boundary fixtures (LANDED)

End-to-end coverage so far had been ASCII-only. Real Chinese-market
ApplyPlan payloads carry zh-CN summaries, emoji in undo labels, and
the occasional fullwidth-ASCII mojibake from input methods. This
landing pins down the validator's behavior on those inputs without
changing any production code.

### What landed

`kqoffice/qa/cppunit/test_provider.cxx`, +5 cases (51 total):

- `testApplyPlanAcceptsLongZhCnSummary` — `operation_summary_zh`
  carrying a 50× repeated 6-character zh-CN phrase (~ 1200 UTF-8
  bytes) must validate cleanly. Schema has no upper length on this
  field; this test guards a future regression that adds one.
- `testApplyPlanAcceptsEmojiInLabel` — `undo_group.label_zh` with
  a 4-byte UTF-8 emoji `📝` must pass. Catches any future
  byte-counting bug that miscounts supplementary-plane codepoints.
- `testApplyPlanRejectsEmojiInId` — same emoji inside `id` must
  fail with `IdPatternMismatch`. Locks the ASCII-only invariant of
  `apv_idPatternOk` (one of the emoji bytes has the high bit set,
  so the byte-level scan correctly rejects).
- `testApplyPlanRejectsFullwidthInId` — fullwidth `ａｐｐｌｙ`
  (U+FF41 etc.) is a frequent mojibake source from Chinese IME
  output. 3-byte UTF-8 → not 1-byte ASCII a-z → rejected. This is
  the case a naive `tolower` workaround would silently accept.
- `testApplyPlanAcceptsEscapedQuoteInLabel` — `label_zh` containing
  escaped quotes (`x\"y\"z`) must validate. Regression guard for
  the parser primitive's quote-tracking — the inner `\"` must not
  terminate the JSON string scan.

### Test results

`CppunitTest_kqoffice_provider` 46 → **51 cases**, all green.
ai-native cppunit suite total: **77** (51 provider + 26 cui).

### Why these specific cases

- **Emoji in label, not id**: real product feature (custom undo
  labels with status icons). The asymmetry — emoji OK in label but
  not in id — is now codified.
- **Fullwidth ASCII**: a real production hazard from copy-paste
  through Chinese-IME-aware text fields. Without this test a future
  contributor might "fix" the regex to be Unicode-aware and
  accidentally accept these.
- **Escaped quotes in label**: zh-CN production text routinely uses
  `“…”` (curly quotes) but JSON serializers may output them as
  `\"…\"` straight ASCII. Locks parser correctness.

### Files touched (SRCDIR)

```
edit  kqoffice/qa/cppunit/test_provider.cxx  (+ 5 cases, ~155 lines)
```

### Invariants preserved

- No production code change — validator and helpers untouched.
- All fixtures are inline byte literals (`\xF0\x9F\x93\x9D` for
  `📝`, `\xEF\xBD\x81…` for fullwidth `ａ`); suite stays hermetic.


## W3 Day-1f — provider-evidence JSON Schema + fixtures

**Date**: 2026-05-09
**Goal**: codify the on-disk JSON envelope written by
`kqoffice::ai::EvidenceRecorder` (per `Provider::call()` audit
record) so external tooling can validate `~/Library/Application
Support/.../ai_provider_evidence/*.json` without grepping C++.

### What landed (build-tree DOCDIR — no C++ change)

```
new   docs/schemas/provider-evidence.schema.json                      (~80 lines)
new   docs/schemas/fixtures/provider-evidence.valid.json
new   docs/schemas/fixtures/provider-evidence.apply-plan-failure.json
new   docs/schemas/fixtures/provider-evidence.invalid.json
```

### Schema shape — `provider-evidence.schema.json`

JSON Schema 2020-12, `additionalProperties: false`, 9 required keys
matching `EvidenceRecorder.cxx` field order:

| field | constraint |
|---|---|
| `evidence_id` | `^ev-[0-9a-f]{16}$` (matches `EvidenceRecorder::mintId`) |
| `timestamp` | `^YYYY-MM-DDTHH:MM:SSZ$` (UTC, second precision) |
| `service_mode` | enum: `offline` / `private` / `cloud` |
| `provider` | free string (`stub`, `ollama:<model>`, `cloud:<vendor>:<model>`) |
| `capability` | free string |
| `status` | flat enum, **17 tokens** |
| `request_size_bytes` | int ≥ 0 |
| `response_size_bytes` | int ≥ 0 |
| `duration_ms` | int ≥ 0 |

### status enum — 17 tokens, single flat list

4 provider-runtime: `ok`, `provider-error`, `policy-denied`,
`timeout`.

13 `apply-plan-*` (emitted by `applyPlanValidationStatus`, one per
real `ApplyPlanValidationCode`):

```
apply-plan-deterministic-false
apply-plan-failure-behavior
apply-plan-failure-message-empty
apply-plan-id-pattern
apply-plan-missing-field
apply-plan-not-json
apply-plan-operation-summary-empty
apply-plan-repeated-diagnostics
apply-plan-revision-precondition
apply-plan-rollback-false
apply-plan-schema-version-mismatch
apply-plan-undo-group-mode
apply-plan-undo-label-empty
```

`apply-plan-unknown` is the C++ `default:` defensive fallback in
`applyPlanValidationStatus` — unreachable when input is a real
`ValidationCode` value, so it is **deliberately excluded from the
schema**.

### Why distinct from `evidence-record.schema.json` (V1.5)

`evidence-record.schema.json` is the V1.5 m3-02 capability /
diagnostic fixture-validator record. Different fields entirely
(`source`, `budget_status`, `validator_status`,
`compatibility_status`, `failure_reason_zh`,
`stores_document_content`). The `provider-evidence` envelope is
per-call provider audit trail. They are not the same schema and
must not be conflated; V1.5 27/27 strict roundtrip stays untouched.

### Fixtures

- `provider-evidence.valid.json` — `evidence_id=ev-a1b2c3d4e5f60718`,
  `service_mode=offline`, `provider=stub`, `status=provider-error`.
  Baseline pass.
- `provider-evidence.apply-plan-failure.json` —
  `provider=ollama:qwen2.5:7b`,
  `capability=writer.diagnostics.style-spacing`,
  `status=apply-plan-failure-behavior`, sizes/duration realistic.
  Locks the apply-plan rejection path through to provider envelope.
- `provider-evidence.invalid.json` — three deliberate violations:
  `evidence_id` not `^ev-[0-9a-f]{16}$`, `status=totally-bogus` not
  in enum, `request_size_bytes=-1` violates `minimum: 0`.

### Cross-check (python harness, scratch)

```
schema apply-plan tokens: 13
schema other tokens:      ['ok', 'policy-denied', 'provider-error', 'timeout']
real cpp apply-plan tokens (ex-unknown): 13
diff schema-cpp: set()
defensive unknown present in cpp: True

[OK] provider-evidence.valid.json                 expected=valid    observed=valid
[OK] provider-evidence.apply-plan-failure.json    expected=valid    observed=valid
[OK] provider-evidence.invalid.json               expected=invalid  observed=invalid
       reasons: evidence_id pattern, status enum, request_size_bytes non-negative int

== schema vs cpp apply-plan tokens match: True ==
```

13/13 alignment between schema enum and real C++ emissions; all 3
fixtures match expected validity.

### Invariants preserved

- **Zero production code change**. Schema + fixtures only.
- `evidence-record.schema.json` not touched — V1.5 27/27 strict
  roundtrip baseline unaffected.
- Filename `provider-evidence.schema.json` is symmetric with the
  existing `provider-request.schema.json` family.

### Files touched (build-tree DOCDIR)

```
new   docs/schemas/provider-evidence.schema.json
new   docs/schemas/fixtures/provider-evidence.valid.json
new   docs/schemas/fixtures/provider-evidence.apply-plan-failure.json
new   docs/schemas/fixtures/provider-evidence.invalid.json
edit  docs/product/v2/day1-progress.md   (this section)
edit  .agent/goals/2026-05-08-v2-ai-native/ledger.jsonl   (Day-1f entry)
```

### Next (W3 Day-1h)

Land a programmatic fixture-vs-schema harness (cppunit on the C++
side, or a python check in `tests/`) so CI mechanically locks the
17-token enum to the C++ emissions and the fixture catalog. Closes
the loop currently held in this commit's scratch script.


## W3 Day-1h — provider-evidence schema lock harness

**Date**: 2026-05-09
**Goal**: turn the Day-1f scratch python check into a checked-in CI
harness so future schema drift fails loudly instead of silently
diverging from real `EvidenceRecorder` output.

### What landed (tests/ only — no production code change)

```
new   tests/v2-provider-evidence-schema-test.sh   (~190 lines, executable)
```

### What the harness locks

Three independent assertions, each rejecting drift in a different
direction:

1. **Schema shape** — `additionalProperties:false`, the 9-key
   `required` set must equal the `EvidenceRecorder.cxx` envelope
   field set exactly.
2. **apply-plan-\* token parity** — the schema enum's `apply-plan-*`
   subset must equal the set of `apply-plan-*` literals grepped from
   `kqoffice/source/ai/provider/*.{cxx,hxx}` minus the defensive
   `apply-plan-unknown`. The defensive token must remain present in
   C++ (asserted) and absent from the schema (asserted) — if a
   future contributor either removes the C++ default or adds the
   token to the schema, this harness fails loudly so the policy
   stays explicit.
3. **provider-runtime token parity** — schema runtime enum must
   equal the contracted set `{ok, provider-error, policy-denied,
   timeout}`. `Provider.cxx` is grepped for `rsp.status = "<token>"`
   and the harness asserts every emitted token is in the schema
   (subset, not equality, because `timeout` is reserved for future
   backend wiring and not yet emitted by any current backend).

Plus: replays the 3 fixtures from Day-1f and asserts each matches
its expected validity.

### Negative-test verified

```
$ python3 -c "import json; ..."   # inject 'apply-plan-bogus-drift-canary'
$ bash tests/v2-provider-evidence-schema-test.sh
FAIL: schema apply-plan tokens drifted from C++ emissions
  in schema but no C++ emission: ['apply-plan-bogus-drift-canary']
```

### Run output (steady state)

```
Status: passed
Schema: docs/schemas/provider-evidence.schema.json
  required keys: 9 (locked)
  status enum: 17 tokens = 4 runtime + 13 apply-plan
C++ apply-plan emissions (ex-defensive): 13 tokens
  match schema: yes
C++ provider-runtime emissions: ['ok', 'policy-denied', 'provider-error']
  schema contracted set:        ['ok', 'policy-denied', 'provider-error', 'timeout']
  reserved (in schema, not yet emitted): ['timeout']
Fixtures checked: 3
  provider-evidence.valid.json: expected=valid observed=valid
  provider-evidence.apply-plan-failure.json: expected=valid observed=valid
  provider-evidence.invalid.json: expected=invalid observed=invalid reasons=[...]
```

### Why a tests/ shell harness rather than a cppunit test

Cppunit can grep its own source file, but it cannot read
`docs/schemas/*.json` without dragging in JSON-parser dependencies
and turning the pure-logic suite into one that needs the build-tree
DOCDIR layout. A shell + python stdlib harness in `tests/` matches
the existing `v2-plan-baseline-test.sh` pattern and stays
release-pipeline-friendly. The `KDOFFICE_SRC_ROOT` env override
keeps it portable when the source checkout moves.

### Files touched

```
new   tests/v2-provider-evidence-schema-test.sh
edit  docs/product/v2/day1-progress.md   (this section)
edit  .agent/goals/2026-05-08-v2-ai-native/ledger.jsonl   (Day-1h entry)
```

### Invariants preserved

- Zero production C++ change; provider cppunit still **OK (51)**.
- V1.5 27/27 strict roundtrip untouched.
- Harness is self-contained: `set -euo pipefail` + python stdlib,
  no extra deps.
- Defensive `apply-plan-unknown` policy now codified in test, not
  just code-comment.

### Next

W3 Day-1b — `SwDocShell::applyDiagnosticsPlan` wiring (gated on
authorization to touch the sw apply surface).




