# V2 Coordinator Handoff — last refreshed 2026-05-11 (L63)

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
- `ai-native` cppunit suite at OK(84): 51 provider + 33 cui (8 idx + 8 fuzzy + 10 recent + 7 controller)
- V1.5 27/27 strict roundtrip baseline untouched
- 63 ledger rows on `main` as of 2026-05-11 (L63 = persistent memory seed)
- CI workflow `.github/workflows/v2-contract-harnesses.yml` invokes ALL 7 harnesses (post-L62; pre-L62 only ran 4)
- Persistent memory seeded at `/Users/lu/.clavue/projects/-Users-lu---office-clmpx2/memory/` (L63):
  `MEMORY.md`, `v2_entry_pointer.md`, `v2_invariants.md`,
  `v2_locking_architecture.md`, `authorization_gates.md`,
  `workspace_layout.md`, `feedback_terse_verifiable.md`
- 4 reader's manuals on disk; H6 glob-discovers them and locks fact-blocks against schema bodies; H2 check 10 locks lane-status references bidirectionally

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

| Resolved | When | What |
|---|---|---|
| ~~D2 W1 Day-1a OllamaAdapter~~ | L32 (2026-05-10) | Audit found landed: BSD-socket HTTP/1.0, bounded reads, 5 cppunit cases included in OK(84) |
| ~~D7 runtime ApplyPlan schema~~ | L26 (2026-05-10) | `docs/schemas/apply-plan-runtime.schema.json` envelope locked + fixtures; per-kind shape stays open until SwUndoApplyPatch impls land |
| ~~CI 4/7 harness gap~~ | L62 (2026-05-11) | `.github/workflows/v2-contract-harnesses.yml` now invokes all 7; H4/H5/H6/H7 had been silently skipped pre-L62 |

**None of the open rows are reversible without authorization.** Coordinator MUST NOT attempt them autonomously. clavue.md is explicit: `git commit/push` and touching `kqoffice/source/`, `cui/source/dialogs/commandpalette/`, `sw/source/uibase/app/docsh*.cxx`, `officecfg/`, `i18npool/` all need explicit user authorization.

## What does NOT need a new ledger entry

If you're tempted to bump a count field in a doc and append a ledger entry recording the bump — STOP. Turn 8 (L23) already eliminated two such self-referential drift sources (`docs/product/v2-master-plan.md` and `docs/CLAUDE-NOTES.md`). Living counts live ONLY in `docs/product/v2/lane-status.md`. H2 check 9 enforces that lane-status's `(N entries)` claim matches `wc -l` of `ledger.jsonl`.

## Production-ready gate (run before claiming completion)

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

Current pass-count baselines: H1=26 / H2=41 / H3=26 / H4 partial / H5 partial / H6=39 / H7 partial. ai-native cppunit total = 84.

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
