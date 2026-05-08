# Packet FEAT-WRITER-ANALYZER-CARVE: IntelligentWriterAnalyzer Feature Carve-Out

Date: 2026-05-07
Owner: Clavue
Reviewer: Codex
Source: `/Users/lu/kdoffice-src`
Audit basis: `tmp/localization-sweep/l10n-02b-writer-context.md` (Out-of-Scope section)

## Goal

Move the IntelligentWriterAnalyzer feature hunks (build glue + API surface + qa test) out of the L10N-02B mixed slice into their own reviewable feature packet. The feature is preview-only by contract — this packet does not enable any document mutation.

## Allowed source scope

| Path | Allowed hunks |
| --- | --- |
| `sw/Library_sw.mk` | Add the `sw/source/core/doc/IntelligentWriterAnalyzer` build object only. No other library changes. |
| `sw/inc/docsh.hxx` | Add `#include <rtl/string.hxx>` and the `SwDocShell::runIntelligentDiagnosticsPreview()` declaration only. Match existing declaration style. |
| `sw/inc/IntelligentWriterAnalyzer.hxx` | Already present in tree; no edit needed unless reviewer requests interface trim. |
| `sw/source/core/doc/IntelligentWriterAnalyzer.cxx` | Already present in tree; no edit needed unless reviewer requests behavior trim. |
| `sw/qa/core/uwriter.cxx` | Add `testIntelligentWriterAnalyzerPreviewOnly` only. No edits to existing tests. |

The two implementation files already exist in source; this packet primarily stages the build-glue + header + test additions that wire them in.

## Explicitly excluded (non-goals)

- Any `.ui` file edit, including pure label translation.
- Any `strings.hrc` edit.
- Any `notebookbar*.ui` edit.
- Any UNO dispatch slot, `.sdi`, or `officecfg` change to expose the analyzer to user UI (the contract is preview-only via direct call from a future packet, not a user-visible command yet).
- Any cross-module change (`framework`, `sfx2`, `cui`).
- Any change that would let the analyzer mutate the document (it's `runDiagnosticsPreview`, not `apply`).
- Any `IntelligentWriterAnalyzer.hxx`/`.cxx` interface change beyond what the existing test exercises.

## Required commands

```sh
gmake -C /Users/lu/kdoffice-src sw.build
gmake -C /Users/lu/kdoffice-src CppunitTest_sw_core_doc
gmake -C /Users/lu/kdoffice-src sw.unitcheck
```

The single-test target verifies `testIntelligentWriterAnalyzerPreviewOnly` runs without bringing in unrelated suites first.

## Required evidence

Write to `tmp/localization-sweep/feat-writer-analyzer-carve.md`:

- `git diff --stat` (must show exactly `Library_sw.mk`, `inc/docsh.hxx`, `qa/core/uwriter.cxx` plus the two pre-existing analyzer files if they appear)
- Confirmation that no `.ui`, `strings.hrc`, `officecfg`, `framework`, `sfx2`, `cui` files are touched
- Output of the three `gmake` commands (status + last 20 lines each)
- Note the contract surface: `SwDocShell::runIntelligentDiagnosticsPreview()` returns diagnostic data; no `apply()` path
- Cross-link to `docs/architecture/intelligent-office-implementation-boundaries.md` for the preview-only invariant

## Stop conditions

Abort and report `Blocked` if:

1. The diff brings in any `.ui`, `strings.hrc`, or `notebookbar*.ui` file.
2. The analyzer interface gains an `apply`/`mutate`/`writeBack` method.
3. A new UNO dispatch entry, `.sdi` slot, or `officecfg` registration is needed (those require a separate, signed-off control-plane packet).
4. `CppunitTest_sw_core_doc` fails after the change but passed before (gate against landing a broken test).
5. `sw.build` introduces a new external dependency not declared in `sw/Library_sw.mk`'s existing pattern.
