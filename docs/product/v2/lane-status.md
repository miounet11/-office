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
| W1  | Provider runtime (Ollama-first sandbox)        | step3 + Day-1a/b + capability reflection + durationMs + runtime JSON stub + local real Ollama 7-patch smoke + app-level real-provider DiffReview click-through | Day-1c (i18n threading), Day-1d (cloud TLS) | 55 (kqoffice_provider) |
| W2  | Cmd+K palette                                  | Day-1a/b/c (dispatcher + popover + Cmd+Shift+K + recents + pinyin hint) | Day-1c i18npool pinyin, multi-monitor/manual app smoke | 38 (8+8+10+7+5 cppunit) |
| W3  | Writer apply-runtime + ApplyPlan validator     | ApplyEngine 7/7 patch kinds + multi-patch runtime JSON + doc-backed apply + Writer real-provider prompt contract | UITest Writer load under svp | sw_apply_engine `OK(35)` + sw_uwriter doc E2E `OK(74)` |
| W4  | Select-to-act (Writer/Calc/Impress action bubble) | Writer/Calc/Impress popovers + provider dispatch + DiffReview apply loop + triple-surface apply + product-entry bundle smoke + W3 runtime JSON provider prompt + visible Writer Select-to-act, visible Calc/Impress Select-to-act, DiffReview Accept/Reject click-through, Writer/Calc/Impress factory document-window UITest zero-skip, and Writer Start Center UITest creation-path coverage | none known after L174 | sw `OK(10)`; sc `OK(6)`; sd `OK(5)`; `UITest_sw/sc/sd_select_to_act OK(skipped=0)` |
| W5  | Async cowork (long-running tasks + diff review)   | Day-1 **CoworkDialog** + TaskStore + TaskQueue + TaskScheduler + TaskRunner worker-thread/notification lifecycle + TaskReviewBridge click-to-review/open/apply core + visible non-modal DiffReview + selected-task accept UI + new-task selection retention + current-bundle pending/running rows + live nonblocking pending→running transition + new-task→awaiting-review→DiffReview→accept-task→applied click-through + AutoOpenReviewNotificationSink + OS-notification gateway payload/click core + native macOS/Windows backends + current-builddir macOS native notification submit/click/review-open proof + CoworkUiBridge + Help menu / Cmd+Shift+T hook; H9 worker-thread/UI evidence gate; mergedlo links `kqoffice_ai` | Windows host compile/manual toast proof | 45 (cowork cppunit) |

**ai-native cppunit suite total**: 125 counted core/evidence cases (55 provider + 38 cui + 32 W5 lifecycle evidence contracts). **Workdir logs verify the core plus product-surface side suites** under `PKG_CONFIG=/tmp/kqoffice-pkgconf-utf8`: four `cui_commandpalette_*` = `OK(8)+OK(8)+OK(10)+OK(7)` (L102), `cui_dispatcher` = `OK(5)` (L110), `kqoffice_provider` = `OK(55)` (L169), `sw_apply_engine` = `OK(35)` (L121/L126), `sw/sc/sd_inline_actions` = `OK(10)+OK(6)+OK(5)` (L146/L120/L126), and `kqoffice_cowork` = `OK(45)` (L168). L126 adds app-bundle product-entry smoke; L127 promotes it to H8 (`tests/v2-product-entry-smoke-test.sh`, 14 checks); L130 promotes W5 lifecycle evidence to H9; L131 extends H9 to TaskScheduler success/failure/restart-recovery; L132 extends H9 to TaskRunner real worker-thread/in-process notification events; L133 extends H9 to TaskReviewBridge open-review-request evidence; L134 extends H9 to stored-task diff-review-opened evidence; L135 extends H9 to AutoOpenReviewNotificationSink notification→stored-task diff-review-opened evidence; L136 extends H9 to CoworkUiBridge dialog-run evidence; L137 extends H9 to review accept → applied evidence; L138 extends H9 to visible DiffReview open + selected-task accept UI evidence; L139 extends H9 to OS-notification gateway payload/click core; L140 extends H9 to Cowork UI OS-notification sink seam; L141 extends H9 to native OS notification backend/fallback and macOS NSUserNotification submitter; L142 extends H9 to native click payload → stored review open handler; L143 extends H9 to macOS delegate/click-sink dispatch into CoworkDialog stored review open; L144 extends H9 to Windows Shell_NotifyIcon backend source/build wiring and click dispatch; L165 extends H9 to the non-modal DiffReview controller, VCL main-thread UI handoff, packaged dialog UI, preferred task-id selection, and transient empty-selection protection; L167 extends H9 to CoworkUiTaskBridgeJob nonblocking pending/running/complete evidence; L168 extends H9 to native notification evidence log/smoke-click gating and macOS submit/dispatch-review-open proof (`tests/v2-worker-ui-lifecycle-test.sh`, 278 checks). L146 adds local real Ollama 7-patch runtime JSON smoke (`bin/v2-ollama-real-path-smoke.sh`) and Writer provider prompt contract coverage; L169 locks Ollama `/api/generate` JSON-mode request shape and proves visible DiffReview click-through with a real `ollama: qwen3:0.6b` provider. L170 reduces `UITest_sw_select_to_act` to one known svp skip, L171 makes the Writer factory document-window suite zero-skip, L172 adds zero-skip Calc/Impress factory document-window UITests through `load_empty_file("calc")` / `load_empty_file("impress")`, L173 proves exact-pid visible Calc/Impress Select-to-act popover click-through at 16/0/0 through `bin/v2-visible-suite-select-to-act-smoke.sh`, L174 fixes the Start Center Writer creation-path svp hang and promotes `UITest_sw_select_to_act` to 4 tests / 0 skipped including `create_doc_in_start_center("writer")`, L175 refreshes H10 archive classification for the expanded dirty tree, and L176 adds explicit H10 batch path lists for source-archive planning.
L145 adds H10 source archive boundary classification (`tests/v2-source-archive-boundary-test.sh`, initially 13 checks): the initial SRCDIR snapshot had 165 dirty paths, 0 unknown paths, and 9 split-needed shared build files. L175 refreshes the current H10 map after Start Center and suite UITest work: 175 dirty paths, 0 unknown paths, 9 split-needed shared paths, and 96 W4-select-to-act paths. L176 emits explicit `tmp/v2-source-archive-batches/*.paths` files for W1/W2/W3/W4/W5/build-infra/submodule-dirty/split-needed/unknown, locks representative W4/W5/split-needed paths, requires `unknown.paths` empty, and raises H10 to 23 checks. L147 adds app-level launch/init smoke via `bin/v2-app-launch-smoke.sh`; L148 adds Writer document-processing smoke via `bin/v2-writer-document-smoke.sh`; L149 adds suite document-processing smoke via `bin/v2-suite-document-smoke.sh`; L150 adds user-entry chain smoke via `bin/v2-user-entry-smoke.sh`; L151 adds live UNO dispatch smoke via `bin/v2-uno-dispatch-smoke.sh`; L152 adds suite-surface UNO dispatch smoke via `bin/v2-suite-dispatch-smoke.sh`; L153 adds GUI readiness/install-route parity smoke via `bin/v2-gui-readiness-smoke.sh`; L154 adds visible current-bundle launch/resource smoke via `bin/v2-visible-current-bundle-smoke.sh`; L155 hardens it into a strict PID-attribution gate; L156 stabilizes direct builddir launch; L157 switches to native AX-by-PID and proves current-bundle File > New > Text Document click-through; L158 proves visible CommandPalette UNO dispatch and AX nodes on the exact current builddir pid; L159 proves the physical Cmd+Shift+K CommandPalette shortcut on that pid; L160 adds visible Cowork Cmd+Shift+T dialog proof via `bin/v2-visible-cowork-smoke.sh`; L161 records a temporary visible GUI/AX attribution regression; L162 restores current-builddir AX attribution and revalidates app launch (3/0/0), current-bundle CommandPalette visible smoke (10/0/0), and Cowork Cmd+Shift+T visible smoke (6/0/0); L163 fixes Writer text-selection hook coverage and adds visible Writer Select-to-act click-through smoke (9/0/0); L164 adds visible DiffReview Accept/Reject click-through (16/0/0); L165 adds the current-bundle Cowork new-task→awaiting-review→DiffReview→accept-task→applied click-through (12/0/0), closing the remaining manual Cowork loop; L166 adds stable exact-pid `[pending]`/`[running]` row proof while retaining the real loop (14/0/0); L167 makes the real New Task path nonblocking and proves the same live task reaches visible `pending`, `running`, awaiting-review, DiffReview, accept-task, and `applied` states (16/0/0); L168 proves current-builddir macOS native notification submit/click-dispatch/stored-review-open evidence through the same visible Cowork smoke (19/0/0); L169 adds an opt-in visible DiffReview real-provider mode and proves Rewrite→DiffReview→Accept/Reject with real Ollama evidence (18/0/0); L170 removes the Writer UNO factory smoke skip in `UITest_sw_select_to_act`; L171 removes the remaining `writer_edit` skip by covering it through the same Writer factory document-window path and verifies the suite at 3 tests / 0 skipped; L172 adds `UITest_sc_select_to_act` and `UITest_sd_select_to_act`, each passing 3 tests / 0 skipped on the factory document-window path; L173 adds `bin/v2-visible-suite-select-to-act-smoke.sh` and proves exact-pid visible Calc `CellRangePopover` / Impress `SlideElementPopover` click-through at 16/0/0; L174 changes the UITest post-action idle to `TaskPriority::DEFAULT` and proves Start Center Writer creation in `UITest_demo_ui` plus `UITest_sw_select_to_act` at 4 tests / 0 skipped.

## W1 — Provider Runtime

| Step | Landed | Files | Ledger row | Notes |
|---|---|---|---|---|
| Day-1 step3 | ✅ | `kqoffice/Library_kqoffice_ai.mk`, `Repository.mk:444`, `services.rdb` | L5 | Real UNO component; V1.5 27/27 strict roundtrip post-vis green |
| Day-1a | ✅ | `kqoffice/source/ai/provider/OllamaAdapter.{hxx,cxx}`, `Provider.cxx` dispatch branch | L32 (audit) | Real BSD-socket HTTP/1.0 against `127.0.0.1:11434`; 100ms probe + 30s generate timeouts; bounded reads (8KB tags / 256KB generate); JSON parser linear-scan for `models[].name` and `response`; 5 cppunit cases (parse/probe/no-hang) |
| Day-1b | ✅ | `EvidenceRecorder.{hxx,cxx}`, `Provider.cxx` | (in narrative, pre-ledger) | 16-hex `evidence_id`, JSON envelope locked |
| Day-1c | ⛔ gated | i18npool threading (waiting on auth) | — | Requires touching shared i18n surface |
| Day-1d | ⛔ gated | cloud-mode TLS bring-up | — | Out of scope until offline path stabilizes |

## W2 — Cmd+K Command Palette

| Step | Landed | Files | Ledger row | Notes |
|---|---|---|---|---|
| Day-1a | ✅ | `cui/source/inc/commandpalette/CommandIndex.hxx`, `cui/qa/unit/{CommandIndex,FuzzyMatcher}Test.cxx` | L7 | Header-only fast-test split, 8+8 cases |
| RecentStore | ✅ | `cui/source/inc/commandpalette/RecentStore.hxx`, `cui/qa/unit/RecentStoreTest.cxx` | L8 | JSON round-trip + ranking integration, 10 cases |
| Controller | ✅ | `cui/source/inc/commandpalette/CommandPalette.hxx` (header-only inline; mirrors FuzzyMatcher fdo#47246 layout), `cui/qa/unit/CommandPaletteControllerTest.cxx`, `cui/CppunitTest_cui_commandpalette_controller.mk` | L34 (commit `8fe469f71`) | 7 cppunit cases covering corpus replacement, query routing, topN cap, shouldDispatch invariant. `CommandPalette.cxx` is now a placeholder TU reserved for Day-1b popover glue (sfx2 dispatch / Enter / ESC); still compiled into libcui so future symbols land without re-registration |
| Day-1b spec | ✅ | `docs/superpowers/specs/2026-05-12-w2-day1b-design.md` | L100 | A-slim 设计批准；12 文件清单（sfx2 dispatcher × 4 + cui loader/popover × 4 + accel xcu × 1 + cppunit harness × 3）；按 §2 拆 D3a/b/c/d 分层授权；本机 sfx2.build + cui.build 可验编译，cppunit 受 B2 阻 |
| Day-1b code | ✅ | sfx2 `CommandPaletteDispatcher` + cui `CommandPaletteLoader` + popover + Global `K_SHIFT_MOD1`→`.uno:CommandPalette` (B1 option B); `CppunitTest_cui_dispatcher` OK(5) pure path | L110 | MergedLibs: link `libmergedlo` + `SAL_DLLPUBLIC_EXPORT` cui symbols; non-ASCII BUILDDIR skips UnoApiTest integration |
| Day-1c | ⛔ gated | i18npool Transliteration_pinyin integration | — | Touches shared i18n surface |

## W3 — Writer Apply Runtime + ApplyPlanValidator

| Step | Landed | Files | Ledger row | Notes |
|---|---|---|---|---|
| Day-1a | ✅ | `kqoffice/source/ai/provider/ApplyPlanValidator.hxx`, `kqoffice/qa/cppunit/test_provider.cxx` | L6 | Header-only schema guard; 14/14 ValidationCode coverage |
| Day-1b/D1 | ✅ | ApplyEngine 7/7 + multi-patch `ParseApplyPlanRuntimeJson`; cppunit **OK(34)** | L120 | Full fixture E2E with live doc; UITest pending |
| Day-1c | ✅ | `applyPlanValidationMessage` zh-CN toast helper (header-only) | L9 | 14 distinct toast strings + field-path suffix |
| Day-1d | ✅ | `apv_findTopKey` / `apv_readString` micro-tests | L10 | +5 cases isolating parser primitives |
| Day-1e | ✅ | `applyPlanValidationStatus` ASCII kebab tokens | L11 | +3 cases; locks 14-token output set |
| Day-1f | ✅ | `docs/schemas/provider-evidence.schema.json` + 3 fixtures | L13 | JSON Schema 2020-12; 17-token enum |
| Day-1g | ✅ | Multi-codepoint UTF-8 boundary fixtures | L12 | +5 cppunit cases (emoji, fullwidth, escaped quotes); schema-level extended-naming fixture `apply-plan-runtime.utf8.json` (L44) covers ZWJ family emoji + RTL mix + CJK ext-B + nested escape — round-trip verified by canonical fixture validator |
| Day-1h | ✅ | `tests/v2-provider-evidence-schema-test.sh` | L14 | Programmatic schema↔C++ drift lock |
| Schema lock H7 | ✅ | `tests/v2-apply-plan-runtime-schema-test.sh` (3 fixtures) | L55, L98 | Schema kind enum order ↔ W3 spec §"Patch Kinds（v1）" table; `additionalProperties:false` envelope guard; `schema_version="v2-w3-runtime-1"` const guard. Promoted to **full-enforce** at L98 once `${KDOFFICE_SRC_ROOT}/sw/source/uibase/inline-actions/SwUndoApplyPatch*.hxx` (aggregator + 1 subclass) landed in SRCDIR. |

## W4 — Select-to-act

Spec + Day-0 entry-point plan + enum lock + **schema + 5 fixtures + H5
full-enforce** (`docs/schemas/inline-action-request.schema.json`,
oneOf 3 branches keyed on surface; `docs/schemas/fixtures/inline-action-request.{valid,invalid,calc-suggest-chart,impress-translate,writer-custom}.json`;
`tests/v2-inline-action-request-schema-test.sh` promoted to
**full-enforce** at L97 once ParagraphActions.hxx + CellActions.hxx +
SlideElementActions.hxx all landed in SRCDIR). Day-0 C++ skeleton
landed at L97 (3 surfaces × header+TU + 3 cppunit + Library/CppunitTest
mk wired; signal-only, VCL-free) — `sw/source/uibase/inline-actions/`,
`sc/source/ui/inline-actions/`, `sd/source/ui/inline-actions/`. The
`svx/source/sidebar/diff-review/` surface stays gated.
Enum tokens locked (L37): `ParagraphAction` 7-token, `CellAction`
5-token, `SlideElementAction` 4-token — see spec §"Action enum lock"
table for the canonical strings + UI labels + Diff-routing column.
Schema oneOf branch enum order locked against the same spec table by
H5; the partial→full promotion was the auto-trigger written into the
harness header at L46.
`writer-custom.json` (L48) covers the `action=custom` branch with
mandatory `user_prompt` populated — the spec rule that ties prompt
required-ness to action token, exercised at fixture layer.

B2 update (L101): the harfbuzz Meson blocker is workaround-resolved via
`PKG_CONFIG=/tmp/kqoffice-pkgconf-utf8`. L107 fixed sc/sd source-link by
exporting the free functions with `SC_DLLPUBLIC` / `SD_DLLPUBLIC`; L108
closed the Writer compile/link side with the W3 D1 include/undo fixes. L112-L120
then moved W4 from skeleton to product loop: Writer/Calc/Impress popovers,
selection hooks, provider dispatch, DiffReview bridge, provider JSON parse,
  and triple-surface apply. L126/L127 product-entry smoke confirms the installed
app bundle ships the Writer/Calc/Impress popovers, DiffReview panel,
CommandPalette, Cowork dialog, provider service, and registry accelerators.
Current side logs: `CppunitTest_sw_inline_actions`
= `OK(9)`, `CppunitTest_sc_inline_actions` = `OK(6)`, and
`CppunitTest_sd_inline_actions` = `OK(5)`; later workdir evidence also
has `sw_inline_actions OK(10)`. `UITest_sw_select_to_act`,
`UITest_sc_select_to_act`, and `UITest_sd_select_to_act` are now
`OK(skipped=0)` after L172: Writer/Calc/Impress factory document-window
smokes all run unskipped through `load_empty_file()`.
No W4 UITest svp risk is currently open after L174; source-link, suite
visible popover click-through, factory windows, and Writer Start Center
creation all have direct evidence.

## W5 — Async cowork

Spec + Day-0 entry-point plan + token lock + schema + fixtures
(`docs/product/v2/w5-async-cowork-spec.md` §"Day-0 Entry-Point Plan"
→ §"Token lock"; `docs/schemas/async-task.schema.json` +
`docs/schemas/fixtures/async-task.{valid,invalid,pending,running,applied,terminal-failed,cancelled}.json`;
harness `tests/v2-async-task-schema-test.sh` promoted to **full-enforce**
at L96 once `${KDOFFICE_SRC_ROOT}/kqoffice/source/ai/cowork/AsyncTask.hxx`
landed). Day-0 C++ skeleton landed at L96 (4 cowork sources +
cppunit + Library/Module/CppunitTest mk wired). Baseline grew
26/11 → 28/12 → 29/12 → 36/13 → 39/13 (L95 added pending/running/applied
state-enum coverage; L48 added `async-task.cancelled.json` extended-naming
boundary fixture covering `state=cancelled` + user-interrupt path
+ `result_plan_id=null` + empty `evidence_ids` since no provider
call completed before cancel).
Enum tokens locked (L37): `TaskKind` 4-token (one per scenario at
spec §"4 个前期场景"), `TaskState` 6-token (matches §"状态机" diagram
exactly: pending / running / awaiting-review / applied / failed /
cancelled — `awaiting-review` is the standard, **not**
`needs-review`). H4 runs in full-enforce: schema enum order +
fixture validity + AsyncTask.hxx token presence all locked.

B2 update (L101): the original harfbuzz Meson `UnicodeDecodeError` is
workaround-resolved for W5 by `PKG_CONFIG=/tmp/kqoffice-pkgconf-utf8`;
`CppunitTest_kqoffice_cowork` reached `[build CUT] kqoffice_cowork` and
exited 0. W5 is no longer documented as B2-blocked/unbuilt.

Product update (L121-L144): `CoworkDialog`, `cowork-dialog.ui`,
`TaskStore`, pure-logic `TaskQueue` lifecycle, `TaskScheduler`, `TaskRunner`, `TaskReviewBridge`, and H9
worker-thread/UI evidence gate landed. L128 covers enqueue, dispatch,
awaiting-review, applied, cancel, failed→refine; L130 adds reason-aware
cancel evidence and locks the CoworkDialog TaskStore-backed list surface;
L131 adds scheduler success/failure/restart-recovery evidence; L132 adds
real OSL worker-thread execution and in-process notification events; L133 adds
platform-independent notification click-to-review request creation; L134 adds
stored-task review-open request handling and stale-state/plan-mismatch guards;
L135 adds `AutoOpenReviewNotificationSink` to connect TaskRunner
awaiting-review notifications to stored-task `diff-review-opened` results;
L136 adds `CoworkUiBridge` so the CoworkDialog new-task action enqueues
and runs one TaskRunner worker into `diff-review-opened`; L137 adds
`acceptReviewResult` so an opened stored review can validate state/plan
and persist `applied`; L138 opens the real `svx` DiffReview panel from
CoworkDialog and adds a selected-task accept button; L139 adds an
OS-notification request/click gateway that forwards TaskRunner notifications
and opens stored reviews from validated click payloads; L140 wires the
CoworkDialog/CoworkUiBridge runner path into that OS notification sink seam;
L141 adds the native backend abstraction, fallback backend, and macOS
NSUserNotification submitter; L142 converts native click metadata back into
stored-review open requests through the shared validation path; L143 binds
macOS notification activation into a registered CoworkDialog click sink that
opens stored review; L144 adds the Windows Shell_NotifyIcon notification-area
backend, WNT `shell32` build wiring, and click dispatch into the same native
click sink path. L165 makes the DiffReview surface a real non-modal weld
dialog, posts worker review callbacks to the VCL main event queue, preserves
the new task selection across refresh/transient empty-selection events, and
proves the current-bundle new-task→awaiting-review→DiffReview→accept-task→applied
loop with 12/0/0 visible checks. L166 adds stable AX-visible `[pending]` and
`[running]` rows in the real Cowork dialog, removes the seeded state fixtures
before the real click-through, and retains the full loop at 14/0/0. L167
switches the Cowork New Task UI path to a nonblocking job, keeps the live task
visible through pending and running before awaiting-review, and retains
DiffReview/accept/apply at 16/0/0. L168 adds current-builddir macOS native
notification product proof: the smoke-gated evidence log records native submit,
click dispatch, and CoworkDialog stored-review open for the same live task. L169
adds an opt-in visible DiffReview real-provider mode and proves the current-builddir
Rewrite path against `ollama: qwen3:0.6b` while retaining Accept/Reject evidence.
H9 now carries 278 checks.
Earlier rows: `CoworkDialog`, `cowork-dialog.ui`, and
`TaskStore` landed; L122 wired `.uno:CoworkTaskManager` through
`CoworkPanelDispatcher`, Help menus, and Cmd+Shift+T; L123 extended the
menu hook to Calc/Impress/Draw. `kqoffice_cowork` is now `OK(45)`.
Windows host compile/manual toast proof remains open.

## Authoritative artifacts

- **Goals** (status snapshot): `.agent/goals/2026-05-08-v2-ai-native/goals.json`
- **Ledger** (append-only timeline): `.agent/goals/2026-05-08-v2-ai-native/ledger.jsonl` (242 entries)
- **Narratives**:
  - `docs/product/v2/day0-skeleton-landed.md` — Day-0 skeleton landing
  - `docs/product/v2/day1-progress.md` — Day-1{a..h} per-step rationale
- **Schemas (V2)**:
  - `docs/schemas/provider-request.schema.json` — request envelope (W1)
  - `docs/schemas/provider-evidence.schema.json` — runtime audit envelope (W1 / W3 Day-1f). Reader's manual: `docs/schemas/provider-evidence.schema.md` (L56).
  - `docs/schemas/apply-plan-runtime.schema.json` — W3 Day-1b runtime ApplyPlan envelope (envelope-only; per-kind patch shape lands with each `SwUndoApplyPatch` impl). Reader's manual: `docs/schemas/apply-plan-runtime.schema.md` (L51).
  - `docs/schemas/async-task.schema.json` — W5 per-task envelope (TaskKind 4-token / TaskState 6-token / 11-required-key envelope; landed L41 ahead of C++ Day-0). Reader's manual: `docs/schemas/async-task.schema.md` (L45).
  - `docs/schemas/inline-action-request.schema.json` — W4 per-trigger inline-action envelope (3-branch oneOf keyed on surface; ParagraphAction 7-token / CellAction 5-token / SlideElementAction 4-token; landed L46 ahead of C++ Day-0). Reader's manual: `docs/schemas/inline-action-request.schema.md` (L49).
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
| W5 async-task schema enum order = token-lock table order | `tests/v2-async-task-schema-test.sh` | 2026-05-12 (full, since L96) |
| W3 apply-plan-runtime schema kind enum order = W3 spec §"Patch Kinds（v1）" table order | `tests/v2-apply-plan-runtime-schema-test.sh` | 2026-05-11 (full) |
| W4 inline-action-request schema oneOf 3-branch action enum order = W4 spec §"Action enum lock" table order | `tests/v2-inline-action-request-schema-test.sh` | 2026-05-12 (full, since L97) |
| W4 + W5 specs carry `## Day-0 Entry-Point Plan` section | `tests/v2-plan-baseline-test.sh` (check 7) | 2026-05-10 |
| W4 spec carries `### Action enum lock` subsection (L37) | `tests/v2-plan-baseline-test.sh` (check 8) | 2026-05-10 |
| W5 spec carries `### Token lock` subsection (L37) | `tests/v2-plan-baseline-test.sh` (check 8) | 2026-05-10 |
| lane-status.md ledger entry-count claim = `wc -l` of ledger.jsonl | `tests/v2-plan-baseline-test.sh` (check 9) | 2026-05-10 |
| W1/W3/W4/W5 reader's-manual fact-blocks (schema_version const opt + required_count + total_props + enum_count multi-claim + unknown-key rejection) ↔ schema body | `tests/v2-schema-manual-coherence-test.sh` | 2026-05-11 |
| Bidirectional `docs/schemas/*.schema.md` ↔ lane-status.md "Reader's manual:" reference roster | `tests/v2-plan-baseline-test.sh` (check 10) | 2026-05-11 |
| `tests/v2-*.sh` harness paths referenced from lane-status.md exist + 0755 mode bit | `tests/v2-plan-baseline-test.sh` (check 11) | 2026-05-11 |
| H8 product-entry smoke: installed app bundle ships provider, W2 CommandPalette, W4 select-to-act/DiffReview, W5 Cowork entrypoints | `tests/v2-product-entry-smoke-test.sh` | 2026-06-08 |
| H9 worker-thread/UI lifecycle evidence: TaskQueue reason tokens + TaskScheduler success/failure/restart-recovery + TaskRunner real thread/in-process notification tokens + TaskReviewBridge open-review-request + stored-task diff-review-opened core + review accept → applied core + AutoOpenReviewNotificationSink notification→diff-review-opened bridge + CoworkUiBridge dialog-run bridge + CoworkDialog visible DiffReview open sink + selected-task accept UI + OS-notification gateway payload/click core + Cowork UI OS-notification sink seam + native OS notification backend/fallback + macOS NSUserNotification submitter + native click payload → stored review open handler + macOS delegate/click-sink dispatch into CoworkDialog stored review open + Windows Shell_NotifyIcon backend/click dispatch + TaskStore-backed list surface + CoworkUiTaskBridgeJob nonblocking pending/running/complete transition + `kqoffice_cowork OK(45)` | `tests/v2-worker-ui-lifecycle-test.sh` | 2026-06-10 |
| H10 source archive boundary: SRCDIR dirty paths classify into W1/W2/W3/W4/W5/build-infra/submodule batches with zero unknown paths; report emitted at `tmp/v2-source-archive-boundary.md` and explicit batch lists at `tmp/v2-source-archive-batches/*.paths` | `tests/v2-source-archive-boundary-test.sh` | 2026-06-10 |
| V2 Day-0 skeleton file-map manifest (W1 provider runtime + W2 command palette) ↔ `docs/product/v2/day0-skeleton-landed.md` body | `tests/v2-day0-skeleton-test.sh` | 2026-05-11 |
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

## Current L241 blockers

L108-L225 moved V2 past the old D1/D3/D9/D1d/W4 source-link
authorization rows, landed W5 pure-logic `TaskQueue`, added the first
`TaskScheduler` lifecycle primitive, added a real `TaskRunner` worker-thread
and in-process notification primitive, added `TaskReviewBridge` click-to-review/open/apply handler core plus AutoOpenReviewNotificationSink auto-open bridge, added CoworkUiBridge dialog-run evidence, added CoworkDialog visible DiffReview/apply UI, added OS-notification gateway payload/click core, and promoted H9 worker-thread/UI
evidence to a contract harness, wired the Cowork UI runner path into the
OS notification sink seam, added the native backend/fallback plus macOS
notification submitter, added the native click payload → stored review
open handler, bound macOS notification activation into CoworkDialog's
registered native click sink, and added the Windows Shell notification-area
backend/click dispatch source path, added H10 source archive boundary
classification for the dirty SRCDIR tree, refreshed H10 to classify the L174-expanded dirty tree with 175 dirty paths and 0 unknowns, emitted explicit source archive batch path lists under `tmp/v2-source-archive-batches/`, hardened Writer real-provider prompt output to W3 runtime JSON, added local real Ollama 7-patch smoke evidence, proved the installed app bundle can launch/init with AI runtime env, proved the installed Writer path can convert a UTF-8 text document to ODT and preserve content, proved the installed suite can process Writer/Calc/Impress documents through real app-bundle filters, proved the installed user-entry command/shortcut/menu/sidebar/UI chain remains coherent, proved a real app-session UNO bridge can resolve V2 commands on a live Writer frame and execute non-modal dispatches, proved shared V2 entrypoints resolve and non-modal dispatches execute across live Writer/Calc/Impress frames, proved the host GUI automation path is available while the default visible app instance is routed to an older /Applications bundle missing V2 entry parity, proved current-bundle V2 resource parity plus direct builddir process launch with isolated profile, proved native AX-by-PID can bind the exact current builddir pid and click File > New > Text Document, proved visible CommandPalette UNO dispatch plus CommandPalette/search/results AX nodes on that same pid, proved physical Cmd+Shift+K opens CommandPalette on that pid after the Writer-family accelerator override fix, then proved physical Cmd+Shift+T opens the Cowork dialog on that pid and exposes `异步任务`, `btn_new_task`, `btn_accept_task`, and `task_list_view`. L161's temporary visible AX window/menu attribution regression is resolved by L162: the current app-launch smoke passes 3/0/0, the current-bundle visible CommandPalette smoke passes 10/0/0, and the Cowork visible smoke passes 6/0/0 on the exact current builddir pid. L163 adds visible Writer Select-to-act click-through: current pid, real Writer text selection, `SelectToActPopover` AX nodes, Rewrite click, and post-click dispatch evidence all pass 9/0/0. L164 adds visible DiffReview `Accept`/`Reject`: Rewrite changes the document, Accept restores the original text through one undo, and Reject removes the patch row; the strict current-bundle report passes 16/0/0. L165 adds a real non-modal DiffReview host, selection retention for the new Cowork task, and exact-pid visible new-task→awaiting-review→DiffReview→accept-task→applied proof; the Cowork report passes 12/0/0 and H9 passes 251 checks. L166 adds exact-pid AX proof that the real Cowork list renders `[pending]` and `[running]`, while retaining the real review/apply loop at 14/0/0. L167 switches New Task to a nonblocking job and proves the same live task reaches pending, running, awaiting-review, visible DiffReview, accept-task, and applied at 16/0/0; H9 passes 264 checks. L168 proves macOS native notification submit/dispatch/stored-review-open in the current-builddir visible Cowork smoke at 19/0/0, with H9 passing 278 checks. L169 proves the visible DiffReview Rewrite path against the real Ollama provider (`provider=ollama: qwen3:0.6b`, `status=ok`, `capability=rewrite`) and keeps Accept/Reject at 18/0/0. L170 reduces `UITest_sw_select_to_act` to one known skip; L171 proves the suite is zero-skip for the Writer factory document-window path; L172 adds zero-skip Calc/Impress factory document-window UITests; L173 proves exact-pid visible Calc/Impress Select-to-act popovers and action clicks at 16/0/0; L174 resolves the Start Center Writer creation-path svp hang and proves `UITest_sw_select_to_act` at 4 tests / 0 skipped including the Start Center route; L175 refreshes H10 archive classification at 175/0/9; L176 raises H10 to 23 checks by locking explicit per-batch `.paths` files. Treat the table
L184 adds the V3 W4 audit-log-entry self-test. L185 adds the V3 W3 knowledge-index-chunk self-test. L186 adds the V3 W3 knowledge-index-query/result self-test. L187 adds the V3 W4 policy-tenant self-test. L188 adds the V3 W6 agent-step-result-state self-test. L189 adds the V3 W7 companion-contract self-test. L190 adds the V3 W8 sync-message self-test. L191 adds the V3 W9 onboarding-flow self-test. L192 adds the V3 W9 starter-pack self-test. L193 adds the V3 W9 edition-policy self-test. L194 adds the V3 W9 i18n-locale self-test. L195 adds the V3 W9 manual-docs self-test. L196 adds the V3 W9 distribution-update self-test. L197 adds the V3 W9 error-recovery-ux self-test. L198 adds the V3 W9 release-ga-checklist self-test. L199 adds the V3 W1 in-app-chat fixture self-test. L200 tightens the V3 W1 CommandPalette chat fallback entry-route design. L201 locks the V3 W1 explicit context syntax policy. L202 locks the V3 W1 Markdown rendering subset policy. L203 locks the V3 W1 per-document local history policy. L204 locks the V3 W1 streaming UI state policy. L205 locks the V3 W1 context autocomplete/no-conflict policy. L206 locks the V3 W2 connector manifest trust-chain policy. L207 locks the V3 W2 connector read-only/writeback policy. L208 locks the V3 W2 connector token-refresh policy. L209 locks the V3 W2 connector auth-flow policy. L210 locks the V3 W5 eval fixture schemas and raises H9 to 7 checks. L211 locks the V3 W5 capability eval reference baseline to V2 GA acceptance and raises H9 to 8 checks. L212 locks the V3 W5 LLM-judge reproducibility policy and raises H9 to 9 checks. L213 locks the V3 W5 per-release eval report archive policy and raises the W5 report self-test to 10 checks. L214 locks the V3 W6 forward-only DAG dependency policy and raises the W6 agent-step-plan self-test to 8 checks. L215 locks the V3 W6 fail-closed plan validation policy and raises the W6 agent-step-plan self-test to 9 checks. L216 locks the V3 W6 approval UX policy and raises the W6 agent-step-plan self-test to 10 checks. L217 locks the V3 W6 cross-session resume policy and raises the W6 agent-step-plan self-test to 11 checks. L218 locks the V3 W6 ShadowDoc compatibility policy to the V2-W3 SwDocShell ApplyPlan path and raises the W6 agent-step-plan self-test to 12 checks. L219 locks the V3 W6 deterministic Plan-Act-Observe prompt library policy and raises the W6 agent-step-plan self-test to 13 checks. L220 locks the V3 W3 BGE-m3 model acquisition policy. L221 locks the V3 W3 vector-store backend default/fallback policy and raises the W3 chunk self-test to 9 checks. L222 locks the V3 W3 watcher scalability policy and raises the W3 chunk self-test to 10 checks. L223 locks the V3 W3 PPTX extraction policy and raises the W3 chunk self-test to 11 checks. L224 locks the V3 W3 index storage policy and raises the W3 chunk self-test to 12 checks. L225 locks the V3 W1 AI workspace UI policy and raises the W1 self-test to 9 checks with 5 valid / 28 invalid fixtures.
L226 locks the V3 W1 content opener route policy and raises the W1 self-test to 10 checks with 5 valid / 32 invalid fixtures.
L227 locks the V3 W1 formatting review policy and raises the W1 self-test to 11 checks with 5 valid / 36 invalid fixtures.
L228 locks the V3 W1 content review policy and raises the W1 self-test to 12 checks with 5 valid / 40 invalid fixtures.
L229 locks the V3 W1 artifact/content navigator policy and raises the W1 self-test to 13 checks with 5 valid / 44 invalid fixtures.
L230 locks the V3 W1 review queue policy and raises the W1 self-test to 14 checks with 5 valid / 48 invalid fixtures.
L231 locks the V3 W1 evidence/citation inspector policy and raises the W1 self-test to 15 checks with 5 valid / 52 invalid fixtures.
L232 locks the V3 W1 interaction chrome policy and raises the W1 self-test to 16 checks with 5 valid / 56 invalid fixtures.
L233 locks the V3 W1 content preview matrix policy and raises the W1 self-test to 17 checks with 5 valid / 60 invalid fixtures.
L234 locks the V3 W1 workspace action bar policy and raises the W1 self-test to 18 checks with 5 valid / 64 invalid fixtures.
L235 locks the V3 W1 workspace filter/search policy and raises the W1 self-test to 19 checks with 5 valid / 68 invalid fixtures.
L236 locks the V3 W1 workspace context handoff policy and raises the W1 self-test to 20 checks with 5 valid / 72 invalid fixtures.
L237 locks the V3 W1 workspace review state sync policy and raises the W1 self-test to 21 checks with 5 valid / 76 invalid fixtures.
L238 locks the V3 W1 workspace activity timeline policy and raises the W1 self-test to 22 checks with 5 valid / 80 invalid fixtures.
L239 locks the V3 W1 workspace session snapshot policy and raises the W1 self-test to 23 checks with 5 valid / 84 invalid fixtures.
L240 locks the V3 W1 workspace attention routing policy and raises the W1 self-test to 24 checks with 5 valid / 88 invalid fixtures.
L241 locks the V3 W1 workspace native style policy and raises the W1 self-test to 25 checks with 5 valid / 92 invalid fixtures.
L242 locks the V3 W1 workspace content registry policy and raises the W1 self-test to 26 checks with 5 valid / 96 invalid fixtures.
below as the current open-state; do not reopen the 2026-05-10 8-worker
decisions unless new evidence contradicts the L242 handoff.

| ID | Decision needed | Owner | Blocks |
|---|---|---|---|
| Source archive | Split and commit `/Users/lu/kdoffice-src` dirty SRCDIR changes by wave (W1/W2/W3/W4/W5/build infra) | user / repo owner | H10 currently classifies 175 SRCDIR dirty paths into archive batches with 0 unknown paths and 9 split-needed shared files, and emits explicit `tmp/v2-source-archive-batches/*.paths` lists; actual staging/commit remains open and must not use `git add .`. |
| UITest svp root cause | **RESOLVED L174** — Start Center Writer creation path no longer stalls under svp | V2 UI/test owner | `ExecuteWrapper::ExecuteActionHdl` now waits on a DEFAULT completion idle after CLICK; `UITest_demo_ui` Start Center repro passes, and `UITest_sw_select_to_act` is `OK` with 4 tests / 0 skipped including `create_doc_in_start_center("writer")`. |
| Product-entry static smoke | Installed app-bundle services, registry commands/accelerators, and W2/W4/W5 UI resources verified by `tests/v2-product-entry-smoke-test.sh` | coordinator | **RESOLVED L127** as H8; visible click-through is covered by L163-L169 and full GUI/worker E2E remains open separately. |
| Current-builddir AX window/menu attribution | **RESOLVED L162** — restore and revalidate visible current builddir app pid AX windows/menus | V2 UI/test owner | `V2_VISIBLE_CURRENT_READY_TIMEOUT=30 bash bin/v2-visible-current-bundle-smoke.sh` passes 10/0/0 and `V2_VISIBLE_COWORK_READY_TIMEOUT=35 bash bin/v2-visible-cowork-smoke.sh` passes 6/0/0; both report `Target attribution: ready` on the exact current builddir pid. |
| Full GUI/worker E2E | Prove Windows host compile/manual toast behavior | V2 UI/test owner | L165 proves the real app awaiting-review→DiffReview→applied click-through; L166 proves stable visible `[pending]`/`[running]` rows; L167 proves the live nonblocking pending→running transition; L168 proves current-builddir macOS native notification submit/click-dispatch/stored-review-open; L169 proves real-provider DiffReview click-through. H9 is green at 278 checks; Windows host compile/manual toast proof remains outside this macOS build. |
| Manual product smoke | **RESOLVED L173** — verify Writer/Calc/Impress Select-to-act, DiffReview, real-provider Rewrite, the Cowork task loop, and macOS native notification proof on a visible app session | release/test owner | L147-L173 prove app launch, document processing, installed entry parity, current-bundle PID attribution, CommandPalette, Cowork dialog entry, Writer Select-to-act, Calc/Impress Select-to-act, DiffReview Accept/Reject, real Ollama provider evidence, Cowork new-task→awaiting-review→DiffReview→accept-task→applied, live pending→running transition, and macOS native notification submit/dispatch/stored-review proof. |
| D5 | Pick `downstream-branding/` source-of-truth (commit / submodule / skip) | user | CI installer artifacts have correct branding. |
| D8 | Decide `sysui/desktop/macosx/LaunchConstraint.plist` `team-identifier` value | user | macOS code signing / notarization. |
| B3 push | Resolve 500MB pack + SSH/LFS/shallow push strategy | user | Sharing/PR path for both builddir and srcdir. |

### Resolved 2026-05-10 sweep decisions

| # | Resolution |
|---|---|
| D1 W3 apply wiring | **RESOLVED L108-L122** — `SwDocShell::applyDiagnosticsPlan`, ApplyEngine 7/7 patch kinds, undo, parser, and doc-backed apply landed with cppunit evidence. |
| D2 W1 OllamaAdapter | **RESOLVED L32** — audit found real BSD-socket HTTP/1.0 backend against `127.0.0.1:11434`, bounded reads, probe/listModels/generate, and 5 cppunit cases. |
| D3 W2 Day-1b + D9 label | **RESOLVED L108-L111** — sfx2 dispatcher, cui loader/popover, GenericCommands label, Cmd+Shift+K binding, and dispatcher cppunit landed. |
| D1d W1 honesty pair | **RESOLVED L108-L123/L169** — listCapabilities reflection, durationMs, runtime JSON stub, and Ollama JSON-mode request lock landed; provider suite is `OK(55)`. |
| W4 source/link residual | **RESOLVED L108-L120** — Writer/Calc/Impress source-link, popovers, provider dispatch, DiffReview bridge, and triple-surface apply landed. |
| Ollama full path | **RESOLVED L146/L169** — `bin/v2-ollama-real-path-smoke.sh` hit local Ollama `qwen3:0.6b`, extracted a W3 runtime JSON plan with all 7 patch kinds, Writer provider dispatch asks for runtime JSON via `buildWriterRuntimeJsonPromptForProvider`, and `V2_VISIBLE_DIFF_REVIEW_REAL_PROVIDER=1 bin/v2-visible-diff-review-smoke.sh` proves app-level Rewrite→DiffReview→Accept/Reject with real `ollama: qwen3:0.6b` evidence. |
| App launch/init smoke | **RESOLVED L147** — `bin/v2-app-launch-smoke.sh` runs H8 static bundle checks, `soffice --version`, and real `soffice --headless --terminate_after_init` with isolated profile plus AI runtime env; visible click-through remains covered by Manual product smoke / Full GUI E2E. |
| Writer document-processing smoke | **RESOLVED L148** — `bin/v2-writer-document-smoke.sh` runs H8 static checks, converts a UTF-8 text file to ODT through the installed app bundle's Writer filter, stores `tmp/v2-writer-document-output.odt`, and verifies the generated `content.xml` contains the expected text; visible click-through remains covered by Manual product smoke / Full GUI E2E. |
| Suite document-processing smoke | **RESOLVED L149** — `bin/v2-suite-document-smoke.sh` runs H8 static checks and proves real app-bundle document processing across Writer txt→ODT, Calc CSV→ODS, Impress ODP→PDF, and Impress PPTX→ODP with stable artifacts under `tmp/v2-suite-*`; visible click-through remains covered by Manual product smoke / Full GUI E2E. |
| User-entry chain smoke | **RESOLVED L150** — `bin/v2-user-entry-smoke.sh` verifies installed CommandPalette/Cowork commands, Cmd+Shift+K/T shortcuts, Cowork menu entries, DiffReviewDeck, shipped V2 UI controls, and SRCDIR SFX/registry anchors; visible click-through remains covered by Manual product smoke / Full GUI E2E. |
| Live UNO dispatch smoke | **RESOLVED L151** — `bin/v2-uno-dispatch-smoke.sh` starts the installed app with a UNO socket, opens a hidden Writer frame, queryDispatch-resolves CommandPalette/Cowork/PropertyDeck/DiffReviewDeck, and dispatches non-modal PropertyDeck + CommandPalette; visible click-through remains covered by Manual product smoke / Full GUI E2E. |
| Suite-surface UNO dispatch smoke | **RESOLVED L152** — `bin/v2-suite-dispatch-smoke.sh` starts the installed app with a UNO socket, opens hidden Writer/Calc/Impress frames, queryDispatch-resolves CommandPalette/Cowork/PropertyDeck/DiffReviewDeck on every surface, and dispatches non-modal PropertyDeck + CommandPalette across all three; visible click-through remains covered by Manual product smoke / Full GUI E2E. |
| GUI readiness/install-route parity smoke | **RESOLVED L153** — `bin/v2-gui-readiness-smoke.sh` proves osascript/System Events/AX access is available, records LaunchServices routing to `/Applications/可圈office.app`, and classifies readiness as blocked because that visible app bundle lacks V2 entry-resource parity while the builddir instdir bundle has it. |
| Visible current-bundle launch/resource smoke | **RESOLVED L154** — `bin/v2-visible-current-bundle-smoke.sh` proved current-bundle V2 entry parity and builddir process launch with `open -n`; the unbound same-name-process GUI attribution claim is superseded by L155. |
| Strict current-bundle PID-attribution gate | **RESOLVED L155** — `bin/v2-visible-current-bundle-smoke.sh` now passes newly-started builddir pid(s) into System Events and only drives menus/shortcuts when AX exposes that exact pid; current report is `Status: blocked`, 2 passed / 5 blocked / 0 failed. |
| Direct-launch PID-attribution stabilization | **RESOLVED L156** — `bin/v2-visible-current-bundle-smoke.sh` now launches the current builddir `Contents/MacOS/soffice` directly with an isolated profile, waits for a new builddir pid, and still reports `Status: blocked`, 2 passed / 5 blocked / 0 failed because AX exposes only the existing `/Applications` pid. |
| Native AX-by-PID current-bundle menu click-through | **RESOLVED L157** — `bin/v2-visible-current-bundle-smoke.sh` now uses `AXUIElementCreateApplication(pid)` for the exact builddir pid and clicks File > New > Text Document; current report is `Status: blocked`, 6 passed / 1 blocked / 0 failed, with Cmd+Shift+K shortcut injection still open. |
| Visible CommandPalette UNO/AX proof | **RESOLVED L158** — `bin/v2-visible-current-bundle-smoke.sh` dispatches `.uno:CommandPalette` on the visible Writer frame and verifies CommandPalette/search/results AX nodes on the same builddir pid; current report is `Status: blocked`, `Target attribution: ready`, 8 passed / 1 blocked / 0 failed, with physical Cmd+Shift+K shortcut injection still open. |
| Physical Cmd+Shift+K visible CommandPalette proof | **RESOLVED L159** — Writer-family module `K_SHIFT_MOD1` en-US overrides now map to `.uno:CommandPalette` instead of `.uno:SmallCaps`; after `gmake officecfg.build postprocess.build`, `bin/v2-visible-current-bundle-smoke.sh` posts Cmd+Shift+K via native CGEvent and verifies CommandPalette/search/results AX nodes on the exact builddir pid. Current report is `Status: passed`, `Target attribution: ready`, 9 passed / 0 blocked / 0 failed. |
| Physical Cmd+Shift+T visible Cowork dialog proof | **RESOLVED L160** — `bin/v2-visible-cowork-smoke.sh` launches the current builddir app with an isolated profile, binds the exact builddir pid through native AX-by-PID, posts Cmd+Shift+T via native CGEvent, and verifies `异步任务`, `btn_new_task`, `btn_accept_task`, and `task_list_view` on that pid. Current report is `Status: passed`, `Target attribution: ready`, 5 passed / 0 blocked / 0 failed. |
| Current visible GUI/AX recheck | **RESOLVED L162** — app launch smoke passes 3/0/0; current-bundle visible smoke passes 10/0/0 with `Target attribution: ready`; Cowork visible smoke passes 6/0/0 with `Target attribution: ready`. |
| Visible Writer Select-to-act click-through | **RESOLVED L163** — `bin/v2-visible-select-to-act-smoke.sh` proves current-builddir pid attribution, real Writer text selection, `SelectToActPopover`/Rewrite/Expand/Shorten AX nodes, Rewrite click, and post-click dispatch evidence; current report is `Status: passed`, 9 passed / 0 blocked / 0 failed. |
| Visible DiffReview Accept/Reject click-through | **RESOLVED L164** — `bin/v2-visible-diff-review-smoke.sh` proves current-builddir pid attribution, visible Rewrite-to-DiffReview, applied Writer text change, Accept undo to original text, and Reject patch-row removal; current report is `Status: passed`, 16 passed / 0 blocked / 0 failed. |
| Visible Cowork task-loop click-through | **RESOLVED L165** — `bin/v2-visible-cowork-smoke.sh` proves current-builddir pid attribution, new-task→awaiting-review→visible DiffReview→accept-task→applied, with selection retention and VCL main-thread UI handoff locked by H9; current report is `Status: passed`, 12 passed / 0 blocked / 0 failed. |
| Visible Cowork pending/running rows | **RESOLVED L166** — `bin/v2-visible-cowork-smoke.sh` seeds isolated current-month pending/running envelopes, proves `[pending]`/`[running]` rows on the exact builddir pid, removes those fixtures before New Task, and retains the real loop; current report is `Status: passed`, 14 passed / 0 blocked / 0 failed. |
| Visible Cowork live nonblocking transition | **RESOLVED L167** — `bin/v2-visible-cowork-smoke.sh` clicks `btn_new_task` in the current builddir app and proves the same live task reaches `pending`, `running`, `awaiting-review`, visible DiffReview, `btn_accept_task`, and `applied`; current report is `Status: passed`, 16 passed / 0 blocked / 0 failed. |
| Visible Cowork macOS native notification proof | **RESOLVED L168** — `bin/v2-visible-cowork-smoke.sh` sets smoke-only native notification evidence env, clicks `btn_new_task` in the current builddir app, and proves `native-os-notification-submit`, `native-os-notification-click-dispatch`, and `native-os-notification-review-open` for the same live task; current report is `Status: passed`, 19 passed / 0 blocked / 0 failed. |
| Visible DiffReview real Ollama provider click-through | **RESOLVED L169** — `V2_VISIBLE_DIFF_REVIEW_REAL_PROVIDER=1 bin/v2-visible-diff-review-smoke.sh` clears stub/probe bypass, writes evidence under `tmp/v2-visible-diff-review-real-provider-evidence`, proves `provider=ollama: qwen3:0.6b`, `status=ok`, `capability=rewrite`, and retains Rewrite→DiffReview→Accept/Reject; current report is `Status: passed`, 18 passed / 0 blocked / 0 failed. |
| `UITest_sw_select_to_act` Writer factory document-window smoke | **RESOLVED L170/L171** — targeted UNO factory and `writer_edit` reachability tests now run unskipped through `self.ui_test.load_empty_file("writer")`; full `UITest_sw_select_to_act` is `OK` with 3 tests discovered and 0 skipped. |
| `UITest_sc/sd_select_to_act` factory document-window smokes | **RESOLVED L172** — registered Calc and Impress UITest targets run through `self.ui_test.load_empty_file("calc")` / `self.ui_test.load_empty_file("impress")`; both suites are `OK` with 3 tests discovered and 0 skipped. |
| Visible Calc/Impress Select-to-act click-through | **RESOLVED L173** — `bin/v2-visible-suite-select-to-act-smoke.sh` launches the current builddir app with isolated Calc/Impress profiles, binds AX to the exact pid, verifies `CellRangePopover`/`SlideElementPopover` action buttons, clicks `btn_explain_data`/`btn_rewrite_text` with real mouse input, and records popover closure after click; current report is `Status: passed`, 16 passed / 0 blocked / 0 failed. |
| Start Center Writer UITest creation path | **RESOLVED L174** — `UITest_demo_ui` repro through `create_doc_in_start_center("writer")` passes with `Ran 1 test`, `OK`; `UITest_sw_select_to_act` now includes `test_writer_start_center_create_smoke` and passes with `Ran 4 tests`, `OK`, `Tests skipped: 0`. |
| Source archive boundary refresh | **RESOLVED L175** — `bin/v2-source-archive-boundary.sh` classifies the L174-expanded W4/source dirty set; H10 passes with 175 dirty paths, 0 unknown paths, 9 split-needed shared paths, and 96 W4-select-to-act paths. |
| Source archive explicit batch path lists | **RESOLVED L176** — H10 now requires per-batch path-list files under `tmp/v2-source-archive-batches/`, locks representative W4/W5/split-needed paths, requires `unknown.paths` empty, and passes with 23 checks. |
| V3 H8/H9/H10/H11/H12 contract gates + W5/W6 meta self-tests | **RESOLVED L177-L183/L210-L219** — V3 contract-only sweep now runs connector manifest H8 (16 checks), eval baseline H9 (9 checks, including eval fixture schema lock, V2 GA reference baseline lock, and LLM-judge reproducibility lock), LocalCloud no-egress H10 (10 checks), perf-baseline target H11 (8 checks), and crash-recovery target H12 (9 checks); `bin/v3-eval-sweep.sh --self-test` now locks the W5 eval-report schema/template/sample/archive policy at 10 checks and W6 agent-step-plan schema/fixtures/dependency/plan-validation/approval/resume/shadow-doc/prompt policies at 13 checks, without starting gated V3 runtime implementation. |
| V3 W4 audit-log-entry self-test | **RESOLVED L184** — `tests/v3-audit-log-entry-test.sh` validates `audit-log-entry.schema.json`, 3 valid/3 invalid audit fixtures, evidenceId `ev-[0-9a-f]{16}`, no embedded evidence-record fields, `storesDocumentContent=false`, and timestamp-ordered append-only hash-chain continuity; it is wired into `bin/v3-eval-sweep.sh --self-test` plus `.github/workflows/v3-contract-harnesses.yml`. |
| V3 W3 knowledge-index-chunk self-test | **RESOLVED L185/L220/L221/L222/L223/L224** — `tests/v3-knowledge-index-chunk-test.sh` validates `knowledge-index-chunk.schema.json`, 4 valid/8 invalid chunk fixtures, paragraph/sentence-fallback granularity, document/connector source coverage, Writer/Calc/Impress/connector extraction-family coverage, per-workspace scope, local sqlite-fts5 and BGE-m3 1024-dimension hybrid retrieval, `modelAcquisitionPolicy`, `vectorStorePolicy`, `watcherPolicy`, `extractionPolicy`, `storagePolicy`, sqlite-fts5 default backend, lancedb-local opt-in only with macOS arm64 status pending runtime spike, 5s watcher debounce, bounded watcher plus polling fallback for >10k files, PPTX extraction through LibreOffice import filter + Impress document model, standalone PPT parser forbidden, application-data-directory per-workspace sidecar storage, user-document sync forbidden, no raw document content fields, no public egress, and now reports 12 checks; it is wired into `bin/v3-eval-sweep.sh --self-test` plus `.github/workflows/v3-contract-harnesses.yml`. |
| V3 W3 knowledge-index-query/result self-test | **RESOLVED L186** — `tests/v3-knowledge-index-query-result-test.sh` validates `knowledge-index-query.schema.json`, `knowledge-index-result.schema.json`, 3 valid/3 invalid paired fixtures, `topK<=10`, query/result linkage, workspace parity, hash-only `snippetHash` results, no raw query/snippet/document content fields, and no public egress; it is wired into `bin/v3-eval-sweep.sh --self-test` plus `.github/workflows/v3-contract-harnesses.yml`. |
| V3 W4 policy-tenant self-test | **RESOLVED L187** — `tests/v3-policy-tenant-test.sh` validates `tenant-context.schema.json`, `policy-rule.schema.json`, 4 valid/3 invalid paired fixtures, tenant isolation, local-only admin panel, audit sink port 17803, effect/enforcement semantics, audit/evidence requirements, and evidence-record schema-collapse guards; it is wired into `bin/v3-eval-sweep.sh --self-test` plus `.github/workflows/v3-contract-harnesses.yml`. |
| V3 W6 agent-step-result-state self-test | **RESOLVED L188** — `tests/v3-agent-step-result-state-test.sh` validates `agent-step-result.schema.json`, `agent-task-state.schema.json`, 4 valid/3 invalid paired lifecycle fixtures, V2 async cowork scheduling, shadow-doc isolation, `mainDocumentUnchanged`, approval-before-merge, ApplyPlan runtime validation, failure/cancel evidence, and evidence-record schema-collapse guards; it is wired into `bin/v3-eval-sweep.sh --self-test` plus `.github/workflows/v3-contract-harnesses.yml`. |
| V3 W7 companion-contract self-test | **RESOLVED L189** — `tests/v3-companion-contract-test.sh` validates `companion-pairing-token.schema.json`, `companion-diff-summary.schema.json`, `companion-approval-request.schema.json`, 7 valid/4 invalid fixtures, short pairing token TTL, device binding, read-only diff summaries, no document content storage, online-only biometric approval, LAN push port 17801, and cloud push opt-in guards; it is wired into `bin/v3-eval-sweep.sh --self-test` plus `.github/workflows/v3-contract-harnesses.yml`. |
| V3 W8 sync-message self-test | **RESOLVED L190** — `tests/v3-sync-message-test.sh` validates `sync-message.schema.json`, 4 valid/4 invalid sync fixtures, local-socket loopback and LAN gRPC coverage, hash-only refs, `storesDocumentContent=false`, `containsRawPayload=false`, `ackRequired=true`, `publicEgress=false`, mTLS, W8 sync port 17802, and evidence/audit links; it is wired into `bin/v3-eval-sweep.sh --self-test` plus `.github/workflows/v3-contract-harnesses.yml`. |
| V3 W9 onboarding-flow self-test | **RESOLVED L191** — `tests/v3-onboarding-flow-test.sh` validates `onboarding-flow.schema.json`, 3 valid/4 invalid first-run fixtures, five ordered steps, download-to-patch `maxMinutes=5`, no-silent-upload/local-first privacy confirmation, skippable local model setup, optional at-most-one connector, demo-patch success/undo/evidence, locale/edition/surface coverage, and runtime-not-started gates; it is wired into `bin/v3-eval-sweep.sh --self-test` plus `.github/workflows/v3-contract-harnesses.yml`. |
| V3 W9 starter-pack self-test | **RESOLVED L192** — `tests/v3-starter-pack-test.sh` validates `starter-pack-manifest.schema.json`, one full 30-template manifest and four invalid guards, 10 business scenarios, Writer/Calc/Impress counts of 10 each, surface-matched sample patch action kinds, sample patch success/undo/evidence, no-network install, local-only data boundary, W8 self-host compatibility, and runtime-not-started gates; it is wired into `bin/v3-eval-sweep.sh --self-test` plus `.github/workflows/v3-contract-harnesses.yml`. |
| V3 W9 edition-policy self-test | **RESOLVED L193** — `tests/v3-edition-policy-test.sh` validates `edition-policy.schema.json`, one valid freemium/audit-lock policy and four invalid guards, personal-free ¥0/full local AI, personal-pro ¥39/month, enterprise audit mandatory, enterprise self-hosted W8 deployment, scale-only limits, no feature locks, no audit bypass, and no public-cloud requirement; it is wired into `bin/v3-eval-sweep.sh --self-test` plus `.github/workflows/v3-contract-harnesses.yml`. |
| V3 W9 i18n-locale self-test | **RESOLVED L194** — `tests/v3-i18n-locale-test.sh` validates `i18n-locale-policy.schema.json`, four valid launch locale manifests and four invalid guards, zh-CN/en-US/ja-JP/zh-TW coverage, UI follows OS locale through existing i18npool, AI output follows UI locale, explicit-only `/lang` override, no silent locale switching/persistence, manual zh-CN/en-US baseline, evidence requirements, and runtime-not-started gates; it is wired into `bin/v3-eval-sweep.sh --self-test` plus `.github/workflows/v3-contract-harnesses.yml`. |
| V3 W9 manual-docs self-test | **RESOLVED L195** — `tests/v3-manual-docs-test.sh` validates `manual-docs-manifest.schema.json`, one valid manual manifest and four invalid guards, embedded + online mirror policy, `?` help key, Help menu entry, offline-readable zh-CN/en-US manual baseline, eight required topics, no public internet requirement, W8 self-host/release-bundle update path, evidence requirements, and runtime-not-started gates; it is wired into `bin/v3-eval-sweep.sh --self-test` plus `.github/workflows/v3-contract-harnesses.yml`. |
| V3 W9 distribution-update self-test | **RESOLVED L196** — `tests/v3-distribution-update-test.sh` validates `distribution-update.schema.json`, one valid distribution/update manifest and four invalid guards, DMG/MSI/AppImage/docker first-launch channels, artifact signing/checksum/notarization, installer smoke and download-to-first-patch ≤ 5min, prompt + one-click W8 self-host update, deferrable/no forced update, LAN/no-public-internet policy, rollback proof, evidence requirements, and runtime-not-started gates; it is wired into `bin/v3-eval-sweep.sh --self-test` plus `.github/workflows/v3-contract-harnesses.yml`. |
| V3 W9 error-recovery-ux self-test | **RESOLVED L197** — `tests/v3-error-recovery-ux-test.sh` validates `error-recovery-ux.schema.json`, one valid recoverable error UX manifest and four invalid guards, provider-timeout / connector-auth-expired / policy-denied / patch-apply-failed scenarios, Writer/Calc/Impress/Companion coverage, inline guidance, required next steps, openable evidence, diagnostics export, no toast-only dead ends, main-document-unchanged recovery guarantees, and runtime-not-started gates; it is wired into `bin/v3-eval-sweep.sh --self-test` plus `.github/workflows/v3-contract-harnesses.yml`. |
| V3 W9 release-ga-checklist self-test | **RESOLVED L198** — `tests/v3-release-ga-checklist-test.sh` validates `release-ga-checklist.schema.json`, one valid GA checklist manifest and four invalid guards, 16 GA readiness gates, V2 regression, H8-H12, W9 onboarding/starter-pack/edition/i18n/manual/distribution/error-recovery gates, source archive cleanup, Windows toast proof, release policy decisions, mandatory human approval, automated approval forbidden, `canShip=false`, signoff evidence, and runtime-not-started gates; it is wired into `bin/v3-eval-sweep.sh --self-test` plus `.github/workflows/v3-contract-harnesses.yml`. |
| V3 W1 in-app-chat fixture self-test | **RESOLVED L199/L225/L226/L227/L228/L229/L230/L231/L232/L233/L234/L235/L236/L237/L238/L239/L240/L241/L242** — `tests/v3-in-app-chat-test.sh` validates 5 valid / 96 invalid fixtures, Writer/Calc/Impress surface coverage, connector-context coverage, Cmd+Shift+K sfx2-sidebar entry semantics, scoped context autocomplete, Markdown subset rendering, per-doc local history, streaming states, AI workspace UI review/progress/opening semantics, content opener route policy, formatting review policy, content review policy, artifact navigator policy, review queue policy, evidence inspector policy, interaction chrome policy, content preview matrix policy, workspace action bar policy, workspace filter/search policy, workspace context handoff policy, workspace review state sync policy, workspace activity timeline policy, workspace session snapshot policy, workspace attention routing policy, workspace native style policy, workspace content registry policy, V2 Provider/ApplyPlan/evidence reuse, human approval before main-document mutation, no cloud history, no stored prompt content, no raw search indexing, raw handoff payloads, raw review-state payloads, raw activity/transcript payloads, raw session/transcript payloads, raw attention payloads, raw native style payloads, or raw content registry payloads, no card-pile/modal-only/marketing-hero drift, no text-overlap policy drift, no new W1 schema, and runtime-not-started gates; it is wired into `bin/v3-eval-sweep.sh --self-test` and reports 26 checks. |
| V3 W1 in-app-chat entry-route design | **RESOLVED L200** — `docs/product/v3/w1-keyboard-shortcut-survey.md` locks W1 to `Cmd+Shift+K` → V2 CommandPalette → `command-palette-chat-fallback` → `sfx2-sidebar`, `docs/product/v3/w1-sidebar-uiwireframe.md` locks the design-only sidebar states, and `tests/v3-in-app-chat-test.sh` now rejects direct accelerator registration with 4 valid / 5 invalid fixtures while preserving no-new-schema and runtime-not-started gates. |
| V3 W1 explicit context syntax policy | **RESOLVED L201** — `docs/product/v3/w1-context-syntax-policy.md` locks valid mentions to `@selection`, `@doc`, and `@connector:<id>`, requires `defaultScope=none` plus explicit mentions, forbids implicit full-document capture, unknown mentions, connector write-back, and raw content storage, and `tests/v3-in-app-chat-test.sh` now passes with 5 valid / 8 invalid fixtures while preserving no-new-schema and runtime-not-started gates. |
| V3 W1 Markdown rendering subset policy | **RESOLVED L202** — `docs/product/v3/w1-markdown-rendering-policy.md` locks native-rich-text Markdown rendering to paragraph/heading/list/code-fence/table blocks, forbids WebView/raw HTML/remote images, updates every W1 chat fixture with `output.rendering`, and `tests/v3-in-app-chat-test.sh` now passes with 5 valid / 11 invalid fixtures while preserving no-new-schema and runtime-not-started gates. |
| V3 W1 per-document local history policy | **RESOLVED L203** — `docs/product/v3/w1-chat-history-policy.md` locks `per-doc-local` + `local-sqlite-sidecar` + `document-id-hash`, forbids cloud sync/global index/cross-document restore/raw transcript fixture storage, requires clear-history/delete-with-document behavior, and `tests/v3-in-app-chat-test.sh` now passes with 5 valid / 15 invalid fixtures while preserving no-new-schema and runtime-not-started gates. |
| V3 W1 streaming UI state policy | **RESOLVED L204** — `docs/product/v3/w1-streaming-state-policy.md` locks V2 provider chunk source, states idle/requesting/streaming/awaiting-approval/applied/failed/cancelled, append-only chunks, main-document unchanged while streaming, no partial chunk persistence, terminal evidence, and `tests/v3-in-app-chat-test.sh` now passes with 5 valid / 19 invalid fixtures while preserving no-new-schema and runtime-not-started gates. |
| V3 W1 context autocomplete/no-conflict policy | **RESOLVED L205** — `docs/product/v3/w1-context-autocomplete-policy.md` locks scoped `@` suggestions to `chat-input-only`, delegates existing Office autocomplete controls, gates connector suggestions on W2 manifests, forbids unknown connector suggestions/raw context previews/global autocomplete hijack, and `tests/v3-in-app-chat-test.sh` now passes with 5 valid / 23 invalid fixtures while preserving no-new-schema and runtime-not-started gates. |
| V3 W1 AI workspace UI policy | **RESOLVED L225** — `docs/product/v3/w1-ai-workspace-ui-policy.md` locks `ai-workspace-sidebar` + `conversation-plus-progress`, visible task progress/step list/evidence links, content review, formatting review, DiffReview reuse, before/after layout preview, and openers for document/selection/connector-result/knowledge-index-result/evidence-record/task-step; modal-only chat, missing progress, review without evidence, formatting without preview, and opener runtime drift are rejected by 5 new invalid guards. |
| V3 W1 content opener route policy | **RESOLVED L226** — `docs/product/v3/w1-content-opener-policy.md` locks document → main-document-window, selection/connector-result/knowledge-index-result/evidence-record → sidebar-preview, task-step → diff-review, requires evidence-linked read-only previews, forbids main-document mutation before approval, fails closed visibly, and keeps opener runtime `not-started`; 4 new invalid guards raise W1 to 32 invalid fixtures. |
| V3 W1 formatting review policy | **RESOLVED L227** — `docs/product/v3/w1-formatting-review-policy.md` locks before-after-layout-diff review for paragraph/character/table/cell/slide layout changes, requires visible DiffReview, evidence link, human approval, no main-document mutation before approval, no raw/preview fixture content, fail-closed visible failure behavior, and formatting runtime `not-started`; 4 new invalid guards raise W1 to 36 invalid fixtures. |
| V3 W1 content review policy | **RESOLVED L228** — `docs/product/v3/w1-content-review-policy.md` locks evidence-linked-content-diff review for selection/document-section/connector-result/knowledge-index-result/evidence-record/task-step suggestions, requires visible DiffReview, evidence link, human approval, no main-document mutation before approval, no raw/suggestion fixture content, fail-closed visible failure behavior, and content review runtime `not-started`; 4 new invalid guards raise W1 to 40 invalid fixtures. |
| V3 W1 artifact navigator policy | **RESOLVED L229** — `docs/product/v3/w1-artifact-navigator-policy.md` locks a visible artifact/content navigator for document/selection/connector-result/knowledge-index-result/evidence-record/task-step management, current-workspace/current-document scope, type/task grouping, evidence badges, content opener integration, read-only details, no main-document mutation, no raw artifact fixture content, fail-closed visible failure behavior, and artifact navigator runtime `not-started`; 4 new invalid guards raise W1 to 44 invalid fixtures. |
| V3 W1 review queue policy | **RESOLVED L230** — `docs/product/v3/w1-review-queue-policy.md` locks a visible review queue for content-review/formatting-review/task-step items, queued/open/approved/rejected/applied/failed states, state/type/surface filters, DiffReview opening, evidence links, explicit human approval for bulk approve/reject, no batch auto-apply, no raw review fixture content, no main-document mutation before approval, fail-closed visible failure behavior, and review queue runtime `not-started`; 4 new invalid guards raise W1 to 48 invalid fixtures. |
| V3 W1 evidence inspector policy | **RESOLVED L231** — `docs/product/v3/w1-evidence-inspector-policy.md` locks a visible evidence/citation inspector for evidence-record, connector-result, knowledge-index-result, task-step, and review-item sources; it shows citation links and audit trail metadata, opens through contentOpeners, redacts raw payloads, uses hash-only references, requires evidence links, forbids raw evidence/citation fixture content and main-document mutation, fails closed visibly, and keeps evidence inspector runtime `not-started`; 4 new invalid guards raise W1 to 52 invalid fixtures. |
| V3 W1 interaction chrome policy | **RESOLVED L232** — `docs/product/v3/w1-interaction-chrome-policy.md` locks the Codex-like sidebar workbench shell with segmented tabs for chat/tasks/artifacts/reviews/evidence, persistent composer, visible task/artifact/review/evidence rails, keyboard tab order, Escape focus return, focusTrap=false, compact native controls, modalChatOnly=false, fail-closed visible behavior, and interaction chrome runtime `not-started`; 4 new invalid guards raise W1 to 56 invalid fixtures. |
| V3 W1 content preview matrix policy | **RESOLVED L233** — `docs/product/v3/w1-content-preview-matrix-policy.md` locks read-only preview semantics for document/selection/connector-result/knowledge-index-result/evidence-record/task-step/review-item content, with main-window/sidebar/DiffReview preview targets, metadata/read-only/diff/evidence modes, evidence badges, source metadata, content opener integration, redaction, hash-only references, no raw or preview fixture payloads, no main-document mutation, fail-closed visible behavior, and preview matrix runtime `not-started`; 4 new invalid guards raise W1 to 60 invalid fixtures. |
| V3 W1 workspace action bar policy | **RESOLVED L234** — `docs/product/v3/w1-workspace-action-bar-policy.md` locks a visible native sidebar workbench action surface for open-preview/open-diff-review/approve-selected/reject-selected/copy-reference/export-evidence/filter/sort/retry/cancel commands, requires keyboard access, visible command state, evidence links, contentOpeners/DiffReview reuse, explicit human approval for bulk apply, no auto-apply, no hidden or mouse-only actions, no main-document mutation, fail-closed visible behavior, and action bar runtime `not-started`; 4 new invalid guards raise W1 to 64 invalid fixtures. |
| V3 W1 workspace filter/search policy | **RESOLVED L235** — `docs/product/v3/w1-workspace-filter-search-policy.md` locks visible metadata-only filtering and search for tasks/artifacts/reviews/evidence/previews across current workspace/current document scope, requires state/type/surface/source/evidence-status filters, id/type/state/source-metadata/evidence-id/hash-reference search fields, recent/type/state/source sorting, content opener and evidence-link reuse, hash-only references, redacted raw payloads, no raw content indexing, no cross-document/global index, fail-closed visible behavior, and filter/search runtime `not-started`; 4 new invalid guards raise W1 to 68 invalid fixtures. |
| V3 W1 workspace context handoff policy | **RESOLVED L236** — `docs/product/v3/w1-workspace-context-handoff-policy.md` locks visible cross-surface context handoff from filter-search results, artifact navigator items, review queue items, evidence links, preview matrix items, and action-bar commands into preview, DiffReview, evidence inspector, review queue, task progress, and composer targets; it preserves active-task/source/evidence/hash/preview/review metadata, requires breadcrumb, back navigation, focus return, evidence links, contentOpeners/DiffReview reuse, metadata-only hash-only redaction, no raw handoff payloads, no auto-apply, no main-document mutation, fail-closed visible behavior, and context handoff runtime `not-started`; 4 new invalid guards raise W1 to 72 invalid fixtures. |
| V3 W1 workspace review state sync policy | **RESOLVED L237** — `docs/product/v3/w1-workspace-review-state-sync-policy.md` locks visible review-state synchronization across review queue, DiffReview, preview matrix, evidence inspector, task progress, and action bar surfaces; it keeps queued/open/approved/rejected/applied/failed states and open/approve/reject/apply/fail transitions aligned, requires evidence links, visible state, contentOpeners/DiffReview reuse, explicit human approval for bulk apply, no auto-apply, no raw review-state payloads, no main-document mutation, fail-closed visible behavior, and review-state sync runtime `not-started`; 4 new invalid guards raise W1 to 76 invalid fixtures. |
| V3 W1 workspace activity timeline policy | **RESOLVED L238** — `docs/product/v3/w1-workspace-activity-timeline-policy.md` locks a visible chronological append-only activity trail across chat, tasks, artifacts, reviews, evidence, previews, and action bar surfaces; it records metadata-only events for chat requests, task starts, artifact creation, content opening, review opening, review-state changes, evidence links, invoked actions, and failures; it requires visible timestamp/actor/open target, evidence links, contentOpeners/DiffReview/evidence inspector reuse, no raw activity/transcript/preview payloads, no auto-apply, no main-document mutation, fail-closed visible behavior, and activity timeline runtime `not-started`; 4 new invalid guards raise W1 to 80 invalid fixtures. |
| V3 W1 workspace session snapshot policy | **RESOLVED L239** — `docs/product/v3/w1-workspace-session-snapshot-policy.md` locks visible resume state across chat, tasks, artifacts, reviews, evidence, previews, and activity timeline surfaces for the current workspace/current document; it restores active task, open artifact/review/evidence, preview mode, review state, activity cursor, and failure state through an explicit resume summary with visible timestamp and document binding, requires contentOpeners/DiffReview/evidence inspector/activity timeline reuse, metadata-only hash-only redaction, no raw session/transcript/preview payloads, no cross-document restore, no cloud sync, no auto-apply, no main-document mutation, fail-closed visible behavior, and session snapshot runtime `not-started`; 4 new invalid guards raise W1 to 84 invalid fixtures. |
| V3 W1 workspace attention routing policy | **RESOLVED L240** — `docs/product/v3/w1-workspace-attention-routing-policy.md` locks visible in-workbench attention routing for approval-required, review-ready, task-failed, evidence-missing, and resume-available triggers; it uses sidebar/tab badges, task-row highlights, review queue badges, activity timeline events, and resume banners to route users to task progress, review queue, DiffReview, evidence inspector, activity timeline, or session snapshot with open target, visible reason/timestamp, keyboard access, native controls, metadata-only hash-only redaction, no raw attention/transcript/preview payloads, no cloud push, no auto-open, no auto-apply, no main-document mutation, fail-closed visible behavior, and attention routing runtime `not-started`; 4 new invalid guards raise W1 to 88 invalid fixtures. |
| V3 W1 workspace native style policy | **RESOLVED L241** — `docs/product/v3/w1-workspace-native-style-policy.md` locks the Codex-like AI workspace as a compact native sidebar workbench with segmented tabs, composer/panel/task/artifact/review/evidence/preview/action surfaces, native controls, stable toolbar/tab/row/tile dimensions, wrap-or-ellipsize text overflow with no overlap, keyboard access, and focus return; it rejects card-pile layouts, modal-only chat, marketing hero treatment, raw/preview/transcript fixture content, auto-apply, main-document mutation, and native style runtime `started`; 4 new invalid guards raise W1 to 92 invalid fixtures. |
| V3 W1 workspace content registry policy | **RESOLVED L242** — `docs/product/v3/w1-workspace-content-registry-policy.md` locks metadata-only registration for document, selection, connector-result, knowledge-index-result, evidence-record, task-step, review-item, formatting-preview, and content-suggestion handles; it requires object-id/type/source-surface/state/evidence-id/hash-reference/open-target/preview-mode fields, contentOpeners/previewMatrix/evidenceInspector/reviewQueue reuse, no raw/preview/transcript fixture payloads, no auto-open, no auto-apply, and content registry runtime `not-started`; 4 new invalid guards raise W1 to 96 invalid fixtures. |
| V3 W2 connector manifest trust-chain policy | **RESOLVED L206** — `docs/product/v3/w2-manifest-trust-policy.md` locks `trust.source/publisher/manifestSha256/reviewState/installScope/signatureRequired/allowUnsigned`, makes `trust` required in `connector-manifest.schema.json`, expands H8 to 7 valid / 7 invalid fixtures, rejects unsigned/unhashed/unreviewed/tenant-unapproved manifests, and preserves contract-only/no-runtime-started gates. |
| V3 W2 connector read-only/writeback policy | **RESOLVED L207** — `docs/product/v3/w2-connector-operations-policy.md` locks `operations.mode=read-only`, `allowedActions=["read"]`, `writeback=false`, `writeScopesAllowed=false`, and `runtimeWriteImplementation=not-started`; H8 now rejects writeback, write scopes, `data-write` evidence, and runtime write implementation drift with 7 valid / 11 invalid fixtures. |
| V3 W2 connector token-refresh policy | **RESOLVED L208** — `docs/product/v3/w2-token-refresh-policy.md` locks `auth.refreshPolicy` to OAuth2 `reauth-on-expiry`, API key `manual-rotate`, auth none `not-applicable`, `backgroundRefresh=false`, `storesRefreshToken=false`, and `runtimeRefreshImplementation=not-started`; H8 now rejects background refresh, refresh-token storage, and runtime refresh drift with 7 valid / 14 invalid fixtures. |
| V3 W2 connector auth-flow policy | **RESOLVED L209** — `docs/product/v3/w2-auth-flow-policy.md` locks `auth.flow` to OAuth2 `system-browser-loopback` + `loopback-127.0.0.1`, API key `manual-secret-entry`, auth none `not-applicable`, `embeddedWebView=false`, and `runtimeAuthImplementation=not-started`; H8 now rejects embedded WebView, non-loopback OAuth callback, and runtime auth drift with 7 valid / 17 invalid fixtures. |
| V3 W5 eval fixture schema lock | **RESOLVED L210** — `docs/schemas/eval-capability-fixture.schema.json`, `docs/schemas/eval-expected-patch.schema.json`, and `docs/schemas/eval-regression-fixture.schema.json` lock H9 capability, expected-patch, and V2 regression fixture shape; invalid guards reject runtime-score drift, missing undo preservation, and V2 sweep downgrade; H9 now reports 7 checks and V3 report totals now represent 50 contract checks. |
| V3 W5 eval reference baseline lock | **RESOLVED L211** — H9 capability fixtures now require `referenceBaseline.id=v2-ga-acceptance`, `source=v2-ga`, `versionPolicy=frozen-at-v2-ga`, `frozenAtLedger=L211`, `requiresV2RegressionGreen=true`, and `runtimeReferenceImplementation=not-started`; W1 v0 is rejected as the frozen reference baseline, H9 now reports 8 checks, and V3 report totals now represent 51 contract checks. |
| V3 W5 LLM-judge reproducibility lock | **RESOLVED L212** — `docs/product/v3/w5-judge-prompt-library.md` locks prompt `judge-v3-capability-v1` with deterministic `temperature=0` / `topP=1` / `seedRequired=true`; H9 capability fixtures require `llmJudgePolicy`, reject default release gating and nondeterministic parameters, keep runtime judge implementation `not-started`, and raise H9 to 9 checks / V3 report totals to 52 contract checks. |
| V3 W5 report archive policy lock | **RESOLVED L213** — `docs/product/v3/w5-report-archive-policy.md` locks per-release reports under `docs/product/v3/eval-reports/<release>/`, keeps JSON/Markdown reports git-tracked, keeps screenshots/recordings/raw runtime samples/large binaries out of git by default, requires an explicit release-artifact/LFS decision for large artifacts, keeps archive automation `not-started`, and raises the W5 report self-test to 10 checks. |
| V3 W6 dependency policy lock | **RESOLVED L214** — `docs/product/v3/w6-dependency-policy.md` locks agent step dependencies to a forward-only DAG with index-topological serialization, fan-in/fan-out allowed, cycles/future dependencies/runtime parallelism forbidden, runtime scheduler implementation `not-started`, and raises the W6 agent-step-plan self-test to 8 checks with 3 valid / 4 invalid fixtures. |
| V3 W6 plan validation policy lock | **RESOLVED L215** — `docs/product/v3/w6-plan-validation-policy.md` locks invalid Planner output to fail closed before execution, blocks execution, forbids silent retry and automatic simplification, requires invalid-plan evidence, keeps runtime Planner implementation `not-started`, and raises the W6 agent-step-plan self-test to 9 checks with 3 valid / 5 invalid fixtures. |
| V3 W6 approval policy lock | **RESOLVED L216** — `docs/product/v3/w6-approval-policy.md` locks whole-task approval as the default, allows per-step approval only from explicit user choice, forbids implicit per-step prompts, keeps approval UI runtime `not-started`, and raises the W6 agent-step-plan self-test to 10 checks with 3 valid / 6 invalid fixtures. |
| V3 W6 resume policy lock | **RESOLVED L217** — `docs/product/v3/w6-resume-policy.md` locks cross-session resume to evidence-complete checkpoints, requires user confirmation, document hash match, shadow snapshot, and audit replay, forbids auto resume, keeps resume runtime `not-started`, and raises the W6 agent-step-plan self-test to 11 checks with 3 valid / 7 invalid fixtures. |
| V3 W6 ShadowDoc compatibility policy lock | **RESOLVED L218** — `docs/product/v3/w6-shadow-doc-policy.md` locks ShadowDoc compatibility to the V2-W3 SwDocShell ApplyPlan path, forbids a new DocShell type, forbids main-document mutation before approval, keeps ShadowDoc runtime `not-started`, and raises the W6 agent-step-plan self-test to 12 checks with 3 valid / 8 invalid fixtures. |
| V3 W6 prompt library policy lock | **RESOLVED L219** — `docs/product/v3/w6-prompt-library.md` locks prompt set `w6-plan-act-observe-v1` with Planner/Actor/Observer prompt ids `planner-v1` / `actor-v1` / `observer-v1`, deterministic `temperature=0` / `topP=1` / `seedRequired=true`, no public egress, and prompt runtime `not-started`; W6 plan fixtures require `promptPolicy`, reject public-egress/runtime/nondeterministic drift, and raise the W6 agent-step-plan self-test to 13 checks with 3 valid / 9 invalid fixtures. |
| V3 W3 model acquisition policy lock | **RESOLVED L220** — `docs/product/v3/w3-model-acquisition-policy.md` locks BGE-m3 as not bundled by default and never silently downloaded; hybrid/vector retrieval requires explicit user confirmation, offline/missing/declined model states fall back to SQLite FTS5, public egress stays false by default, runtime downloader and embedding implementation remain `not-started`, and the W3 chunk self-test now reports 8 checks with 3 valid / 4 invalid fixtures. |
| V3 W3 vector-store backend policy lock | **RESOLVED L221** — `docs/product/v3/w3-vector-store-policy.md` locks sqlite-fts5 as the default and fallback backend, keeps lancedb-local opt-in only until macOS arm64 platform smoke exists, records `lancedbMacosArm64Status=pending-runtime-spike`, keeps runtime vector-store implementation `not-started`, and raises the W3 chunk self-test to 9 checks with 3 valid / 5 invalid fixtures. |
| V3 W3 watcher scalability policy lock | **RESOLVED L222** — `docs/product/v3/w3-watcher-scalability-policy.md` locks background watcher debounce to 5s, forbids per-file descriptor watch, requires bounded watcher plus polling fallback above 10k files, caps open file descriptors at 256, makes overflow `fail-closed-user-visible`, keeps runtime watcher implementation `not-started`, and raises the W3 chunk self-test to 10 checks with 3 valid / 6 invalid fixtures. |
| V3 W3 extraction policy lock | **RESOLVED L223** — `docs/product/v3/w3-extraction-policy.md` resolves PPT/PPTX text extraction through the LibreOffice import filter and Impress document model, forbids a standalone PPT parser, requires slide element refs for PPTX chunks, keeps runtime extraction implementation `not-started`, and raises the W3 chunk self-test to 11 checks with 4 valid / 7 invalid fixtures. |
| V3 W3 storage policy lock | **RESOLVED L224** — `docs/product/v3/w3-storage-policy.md` resolves index file location to application-data-directory per-workspace sidecars, forbids colocating indexes with user documents or syncing them as user documents, requires workspace-hash path identity, keeps runtime storage implementation `not-started`, and raises the W3 chunk self-test to 12 checks with 4 valid / 8 invalid fixtures. |
| D4 I1 fixture baseline | **RESOLVED 2026-05-10** — `bin/` extended-naming + `tests/` count bump landed. |
| D6 worker owned-path mapping | **PARTIALLY RESOLVED 2026-05-10** — `docs/CLAUDE-NOTES.md` documents repo-specific worker scope overrides; Clavue CLI template support remains external. |
