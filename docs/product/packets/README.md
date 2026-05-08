# L10N-02B Three-Way Slice Index

Date: 2026-05-07

The original L10N-02B packet was returned `blocked / revise` (see `tmp/localization-sweep/l10n-02b-writer-context.md`) because the working tree mixed three change classes that have different review owners and risk profiles. This index splits them.

## Packets

| ID | Scope | File |
| --- | --- | --- |
| **L10N-02B-A** | Pure visible-label/title/tooltip slice across `sw/inc/strings.hrc` + 17 dialog `.ui` files | [`L10N-02B-A.md`](L10N-02B-A.md) |
| **FEAT-WRITER-ANALYZER-CARVE** | IntelligentWriterAnalyzer build glue + API surface + qa test | [`FEAT-WRITER-ANALYZER-CARVE.md`](FEAT-WRITER-ANALYZER-CARVE.md) |
| **L10N-02B-C-BEHAVIOR** | Underline-control + non-label deletions in 4 `notebookbar*.ui` files | [`L10N-02B-C-BEHAVIOR.md`](L10N-02B-C-BEHAVIOR.md) |

The two `notebookbar*.ui` localizable substrings are deferred to a follow-up `L10N-02B-A2` slice that runs after L10N-02B-C-BEHAVIOR settles, so translation never lands on top of behavior that may still flip.

## Recommended execution order

1. **L10N-02B-A first.** Lowest risk, largest unblock for the visible-Chinese gate. Touches only label text on dialog files that have no behavior change.
2. **FEAT-WRITER-ANALYZER-CARVE second.** The implementation files are already in tree; this packet just stages the wiring and the test. Locks the preview-only contract.
3. **L10N-02B-C-BEHAVIOR last.** Highest risk because removing notebookbar controls is a visible UX decision. Needs product sign-off and screenshot diff. Run only after Packet A has reduced English noise so that the screenshot review focuses on layout, not text.

## Cross-packet invariant

No file may appear in more than one packet. If a hunk does not match any of the three scopes above, it is out of L10N-02B entirely and needs its own packet proposal before staging.
