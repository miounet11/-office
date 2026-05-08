# Packet L10N-02B-C-BEHAVIOR: Notebookbar Behavior Carve-Out

Date: 2026-05-07
Owner: Clavue
Reviewer: Codex
Source: `/Users/lu/kdoffice-src`
Audit basis: `tmp/localization-sweep/l10n-02b-writer-context.md` (notebookbar partial-candidate notes)

## Goal

Isolate the non-localization hunks in the four Writer notebookbar `.ui` files — specifically the underline-control deletions and other non-label removals — into their own packet so they receive product/UX review separately from translation.

This packet is **not** about translation. The localizable substrings inside the same `notebookbar*.ui` files are deferred until this behavior packet is decided (keep / revert / reshape); the L10N follow-up then runs as `L10N-02B-A2` against whichever notebookbar layout survives.

## Allowed source scope

| Path | Allowed hunks |
| --- | --- |
| `sw/uiconfig/swriter/ui/notebookbar.ui` | Underline control deletions and non-label structural deletions present in the current working tree. |
| `sw/uiconfig/swriter/ui/notebookbar_compact.ui` | Same class of behavior hunks per the audit. |
| `sw/uiconfig/swriter/ui/notebookbar_groupedbar_compact.ui` | Same class of behavior hunks per the audit. |
| `sw/uiconfig/swriter/ui/notebookbar_groupedbar_full.ui` | Same class of behavior hunks per the audit. |

For every staged hunk the diff line MUST be a `<child>`/`<object>`/widget removal or a `<property name="visible">false</property>` flip. No `<property name="label|title|tooltip">` translation enters this packet.

## Explicitly excluded (non-goals)

- Any pure label/title/tooltip translation in the same files (deferred to a follow-up `L10N-02B-A2` slice).
- Any other `.ui` file (Packet A scope).
- Any `.mk`, `.hxx`, `.cxx` change (Packet B scope).
- Any UNO command id rename, accelerator change, or shortcut binding.
- Any change to non-Writer notebookbar files (Calc/Impress).

## Required commands

```sh
gmake -C /Users/lu/kdoffice-src sw.build
gmake -C /Users/lu/kdoffice-src sw.unitcheck
bin/packaged-screenshots.sh
```

The screenshot run is part of the evidence — the underline-control deletion is a visible behavior change and must be inspected against the captured Writer PNG.

## Required evidence

Write to `tmp/localization-sweep/l10n-02b-c-behavior.md`:

- `git diff --stat` showing only the four `notebookbar*.ui` files
- Per-file list of removed widgets/properties with widget id and parent group
- Product rationale per removal (why this control is gone — clutter? duplicate? superseded?)
- Output of `gmake sw.build` and `gmake sw.unitcheck`
- Side-by-side: pre-change vs post-change `tmp/product-completion/screenshots/writer.png`
- Any UNO command id that loses its UI presence — list with replacement entry point (menu/keyboard) so the command is not orphaned

## Stop conditions

Abort and report `Blocked` if:

1. Any `<property name="label|title|tooltip|accessible_name|accessible_description">` text edit appears in the diff (translation must not ride this packet).
2. A removed control has no remaining entry point (would orphan a UNO command).
3. The change crosses into Calc/Impress notebookbars.
4. `sw.unitcheck` fails on a path that exercises the removed widgets.
5. The visual diff in the screenshots reveals layout collapse or unintended cropping not anticipated in the rationale.
6. A removal includes accelerators (`<accelerator/>`) that other dialogs depend on.
