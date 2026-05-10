# V2 Coordinator Handoff — last refreshed 2026-05-12 (L88)

> Authoritative wait-state snapshot. Read this first if a previous
> session ended in /goal mode without explicit user authorization.
>
> **Refresh policy**: when significant locks/baselines change, update
> the four numbered sections inline. Do not append historical
> snapshots — the lane-status.md ledger row count is canonical for
> "when". The session-id source links live in the per-row notes of
> `.agent/goals/2026-05-08-v2-ai-native/ledger.jsonl`.

## State at handoff

- All 7 V2 contract harnesses green (H1–H7; see §"Production-ready gate" below)
- `ai-native` cppunit suite at OK(84) **claimed**: 51 provider + 33 cui (8 idx + 8 fuzzy + 10 recent + 7 controller). Workdir log evidence (L72): OK(77) verified across 3 binaries (`kqoffice_provider` 51 + `cui_commandpalette_fuzzy` 8 + `cui_commandpalette_index` 8 + `cui_commandpalette_recent` 10); the 7-case `cui_commandpalette_controller` test exists in SRCDIR (`cui/qa/unit/CommandPaletteControllerTest.cxx` registers 7 `CPPUNIT_TEST(...)` macros) but `workdir/CppunitTest/cui_commandpalette_controller.test.log` is absent. **L75 (2026-05-11)**: attempted `make CppunitTest_cui_commandpalette_controller` to upgrade evidence 77 → 84; build FAILED at the harfbuzz external dep — `meson.build:114:16: ERROR: Unhandled python exception` (`UnicodeDecodeError: 'utf-8' codec can't decode byte 0xe5 in position 13: invalid continuation byte`, traced to non-ASCII path component `可点office` in BUILDDIR root that meson's pkgconf invocation cannot decode). This is **B2-class** (build environment toolchain mismatch, not a V2 invariant regression). Full log: `/tmp/cppunit-controller-build.log` (1561 lines). OK(84) upgrade is **blocked on B2 resolution**, NOT just wall-clock budget. Until B2 is resolved (rename BUILDDIR to ASCII-only, or patch meson invocation to set `LC_ALL=C` env), the OK(7) controller component remains workdir-unverified despite SRCDIR source presence.
- V1.5 27/27 strict roundtrip baseline untouched
- 87 ledger rows on `main` as of 2026-05-12 (L85-L87 = dawn doc-refresh cadence cluster: L85 handoff enumeration extend, L86 CLAUDE-NOTES anchor refresh, L87 STATUS-2026-05-11 §15 append covering L84-L86; L88 in-flight = this anchor sync + memory refresh batch, bumps to 88)
- CI workflow `.github/workflows/v2-contract-harnesses.yml` invokes ALL 7 harnesses (post-L62; pre-L62 only ran 4); paths-filter covers `bin/v2-harness-sweep.sh` and `.agent/goals/2026-05-08-v2-ai-native/**` (post-L73; previously these inputs could regress without triggering CI)
- Persistent memory seeded at `/Users/lu/.clavue/projects/-Users-lu---office-clmpx2/memory/` (L63):
  `MEMORY.md`, `v2_entry_pointer.md`, `v2_invariants.md`,
  `v2_locking_architecture.md`, `authorization_gates.md`,
  `workspace_layout.md`, `feedback_terse_verifiable.md`
- 4 reader's manuals on disk; H6 glob-discovers them and locks fact-blocks against schema bodies; H2 check 10 locks lane-status references bidirectionally
- L65 bin/v2-harness-sweep.sh one-shot sweep; L66 ledger row-shape lock (H2 check 12); L67 pass-count baseline cross-doc lock (H2 check 13); L68 lock-system semantics docs (CLAUDE-NOTES §Ledger row shape + §Pass-count baseline replicas + 4-tier matrix); L69 negative-canary protocol; L70 sweep-script exec-bit lock (H2 check 14); L71 D8/D9 handoff blockers; L72 OK(84) claim vs OK(77) workdir-verified honest split; L73 CI trigger covers sweep + ledger paths; L74 handoff refresh L67→L73; L75 cppunit OK(84) upgrade B2-blocked honesty correction (4 docs); L76 sweep-enumeration ↔ disk parity (H2 check 15, baseline 44→45); L77 canary section extended to cover checks 14+15; L78 handoff refresh L73→L77; L79 STATUS-2026-05-11 evening §13 L47-L78 delta append-only; L80 v2-commit-manifest superseded-banner; L81 CLAUDE-NOTES stale L-pointer refresh (L63→L77 handoff anchor + post-L67→post-L76 heading); L82 handoff refresh L77→L81 + cadence pattern emerges ("~4-commit handoff staleness"); L83 ledger ts tz-normalize lock (H2 check 16) + canary 16A/16B; L84 STATUS-2026-05-11 §14 append-only delta L78→L84 (baseline 45→46); L85 handoff enumeration extend L81→L84 = cadence-pattern 4th recurrence (L74/L78/L82/L85) confirming the ~4-commit handoff-doc-enumeration drift class; L86 CLAUDE-NOTES line-9 anchor refresh L77→L85 (cross-doc anchor cadence faster than handoff cadence, recurred 2 commits in); L87 STATUS-2026-05-11 §15 dawn append-only delta covering L84-L86 + cadence pattern quantitative summary (handoff ~4 commits / CLAUDE-NOTES ~2-4 / STATUS section ~3-6 self-accelerating); L88 handoff title + state + line 24 enumeration extend L85→L87 + 7-file off-repo memory L-anchor batch refresh (L42-L84→L42-L87, ledger 84→87, 45→48 commits accepted)

Working tree may have uncommitted noise (sysui/desktop/macosx/LaunchConstraint.plist, generated config). Nothing has been pushed (B3 — no SSH key, HTTPS hits 500MB pack limit).

## What's actually blocked (do NOT keep churning)

| ID | Decision needed | Owner | Blocks |
|---|---|---|---|
| D1 | Authorize touching `sw/source/uibase/app/docsh*.cxx` + new files in `sw/source/core/{doc,undo}/` | user | W3 Day-1b (`SwDocShell::applyDiagnosticsPlan` wiring) — closes last W3 Day-1 gate |
| D3 | Authorize sfx2 sdi (`.uno:CommandPalette` slot) + `cui/source/dialogs/commandpalette/` GUI shell + accelerator config | user | W2 Day-1b end-to-end. `CommandPaletteController` thin-wrapper class already lives in BUILDDIR; missing surface is sfx2 dispatch + popover GUI |
| D5 | Pick `downstream-branding/` source-of-truth (commit / submodule / skip) | user | CI installer artifacts have correct branding |
| D6 | Re-scope worker owned-paths from `src/**`/`tests/**` to per-module | user | code-worker-2, test-worker-2 lane usability — blocked on Clavue CLI internal `/parallel` template, not this repo |
| W4 scope | Authorize `sw/source/uibase/inline-actions/`, `sc/source/ui/inline-actions/`, `sd/source/ui/inline-actions/`, `svx/source/sidebar/diff-review/` | user | W4 Day-0 C++; H5 auto-promotes from partial → full on header arrival |
| W5 scope | Authorize `kqoffice/source/ai/cowork/**` + `kqoffice/qa/cppunit/test_cowork*` | user | W5 Day-0 C++; H4 auto-promotes from partial → full on `AsyncTask.hxx` arrival |
| D8 | Decide `sysui/desktop/macosx/LaunchConstraint.plist` `team-identifier` value (currently empty in working tree, was `2B7JZ4N26U` on `main`) | user | macOS code signing / notarization. Empty value will be rejected by `--enable-macosx-code-signing` builds. Either revert to `2B7JZ4N26U`, intentionally clear (for unsigned dev), or substitute the correct team. Working tree change is unattributed |
| D9 | Decide whether to commit SRCDIR `officecfg/.../GenericCommands.xcu` `.uno:CommandPalette` 11-line en-US label (D3.3a authorized scope but uncommitted in `/Users/lu/kdoffice-src` HEAD `8fe469f71`) | user | W2 Cmd+K end-to-end. D3 popover GUI is the bigger gate, but committing the xcu label closes the smallest D3 sub-step independently |

| Resolved | When | What |
|---|---|---|
| ~~D2 W1 Day-1a OllamaAdapter~~ | L32 (2026-05-10) | Audit found landed: BSD-socket HTTP/1.0, bounded reads, 5 cppunit cases included in OK(84) |
| ~~D7 runtime ApplyPlan schema~~ | L26 (2026-05-10) | `docs/schemas/apply-plan-runtime.schema.json` envelope locked + fixtures; per-kind shape stays open until SwUndoApplyPatch impls land |
| ~~CI 4/7 harness gap~~ | L62 (2026-05-11) | `.github/workflows/v2-contract-harnesses.yml` now invokes all 7; H4/H5/H6/H7 had been silently skipped pre-L62 |

**None of the open rows are reversible without authorization.** Coordinator MUST NOT attempt them autonomously. clavue.md is explicit: `git commit/push` and touching `kqoffice/source/`, `cui/source/dialogs/commandpalette/`, `sw/source/uibase/app/docsh*.cxx`, `officecfg/`, `i18npool/` all need explicit user authorization.

## What does NOT need a new ledger entry

If you're tempted to bump a count field in a doc and append a ledger entry recording the bump — STOP. Turn 8 (L23) already eliminated two such self-referential drift sources (`docs/product/v2-master-plan.md` and `docs/CLAUDE-NOTES.md`). Living counts live ONLY in `docs/product/v2/lane-status.md`. H2 check 9 enforces that lane-status's `(N entries)` claim matches `wc -l` of `ledger.jsonl`.

## Production-ready gate (run before claiming completion)

One-shot sweep (preferred — single source of truth):

```bash
bash bin/v2-harness-sweep.sh                  # H1→H7
bash bin/v2-harness-sweep.sh --with-fixtures  # also V1.5+V2 fixtures w/ ≥36/0 assert
```

Manual equivalent (if you need to inspect individual harness output):

```bash
bash tests/v2-provider-evidence-schema-test.sh       # H1
bash tests/v2-plan-baseline-test.sh                  # H2
bash tests/v2-day0-skeleton-test.sh                  # H3
bash tests/v2-async-task-schema-test.sh              # H4 partial
bash tests/v2-inline-action-request-schema-test.sh   # H5 partial
bash tests/v2-schema-manual-coherence-test.sh        # H6
bash tests/v2-apply-plan-runtime-schema-test.sh      # H7 partial
bash bin/intelligent-contract-fixtures.sh            # V1.5 + V2 fixtures
grep -c '| passed |' tmp/intelligent-contract-fixtures.md  # must be ≥ 36
grep -c '| failed |' tmp/intelligent-contract-fixtures.md  # must be 0
```

Current pass-count baselines: H1=26 / H2=47 / H3=26 / H4 partial / H5 partial / H6=39 / H7 partial. ai-native cppunit total = 84.

Or rely on `.github/workflows/v2-contract-harnesses.yml` to run all 7 + V1.5 fixtures step on PR (post-L62).

## Coordinator-reversible scope (proceed without asking)

- `docs/` (except `CLAUDE.md`/`AGENTS.md`/`clavue.md` — those are regenerated by `clavue /init`; durable guidance goes in `docs/CLAUDE-NOTES.md`)
- `docs/schemas/` (schemas, fixtures, reader's manuals — H6 auto-enrolls new manuals via glob)
- `tests/` (new harness; preserve 0755 mode bit — H2 check 11 enforces)
- `bin/` (extending validators; do NOT touch `bffvalidator.sh` mode bit)
- `.github/workflows/*.yml` (CI gates)
- `/Users/lu/.clavue/projects/-Users-lu---office-clmpx2/memory/` (persistent memory; outside BUILDDIR, no git pollution)
- `.agent/goals/2026-05-08-v2-ai-native/ledger.jsonl` (append only)
- `.agent/goals/2026-05-08-v2-ai-native/goals.json` (status updates only)

## When in doubt

Pause the goal. Idle turns produce drift, not progress. But check the persistent memory directory FIRST — durable knowledge gaps there are reversible high-value work that isn't visible from inside the BUILDDIR file tree (this was the L62→L63 lesson).
