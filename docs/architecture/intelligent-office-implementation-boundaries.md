# Intelligent Office Implementation Boundaries

This document records the first product-safe implementation boundaries for Writer diagnostics and deterministic PPT generation. It is based on a read-only Codex/Clavue source audit against `/Users/lu/kdoffice-src` on 2026-04-28.

## P0-08 Writer Preview Analyzer Boundary

The first Writer analyzer must be preview-only. Its job is to inspect the document model and return contract-shaped diagnostics; it must not apply formatting, mutate content, mark the document modified, or alter undo state.

Recommended shape:

- Add a small Writer-internal analyzer API that takes `const SwDoc&`.
- Return diagnostics matching `docs/schemas/intelligent-diagnostic.schema.json`.
- Keep the first rules conservative: outline issues, direct-formatting hints, mixed-font warnings, paragraph spacing outliers, list-level anomalies, and table structure hints.
- Expose results through a later preview UI or sidebar command only after the analyzer has stable tests.

Safe read-only surfaces:

- Outline inspection: `sw/inc/IDocumentOutlineNodes.hxx`, `sw/inc/ndarr.hxx`.
- Text inspection: `sw/inc/ndtxt.hxx` via `SwTextNode::GetText()`.
- Formatting inspection: `sw/inc/node.hxx` and `sw/inc/ndtxt.hxx` via attr sets, paragraph attrs, text hints, and text collections.
- List inspection: `SwTextNode::GetNumRule()` and number-vector APIs in `sw/inc/ndtxt.hxx`.
- Table membership: `SwNode::GetTableBox()` and `SwNode::FindTableNode()` in `sw/inc/node.hxx`.

Hard constraints:

- No `SwWrtShell`, `SwCursorShell`, or UI-shell dependency in the analyzer core.
- No calls to mutators such as `SetAttr`, `ResetAttr`, `InsertText`, `EraseText`, `ChgFormatColl`, or outline update methods.
- No `StartAllAction` / `EndAllAction`.
- No undo manager writes.
- Analyzer runs must leave document modified state unchanged.
- Diagnostics must be stable across repeated runs on the same document.

Initial acceptance gate:

- Build the Writer module after adding the analyzer API.
- Run analyzer twice on a fixture and assert identical diagnostics.
- Assert the document modified flag is unchanged before and after analyzer execution.
- Keep all diagnostic actions preview-only until a separate undo-grouped apply path exists.

## P0-09 Deterministic PPT Generation Boundary

The existing Writer-to-Impress outline flow must be preserved. Do not replace `.uno:SendOutlineToStarImpress` or its RTF outline path.

Current legacy path:

- Writer command handling is in `sw/source/uibase/app/docsh2.cxx`.
- `FN_ABSTRACT_STARIMPRESS` builds a summary document, serializes RTF, then dispatches `SendOutlineToImpress`.
- `FN_OUTLINE_TO_IMPRESS` exports Writer outline RTF and dispatches `SendOutlineToImpress`.
- Impress receives `SID_OUTLINE_TO_IMPRESS` in `sd/source/ui/app/sdmod1.cxx`.
- `SdModule::OutlineToImpress()` passes the RTF bytes into an outline-view finalizer.
- `OutlineViewShell::ReadRtf()` in `sd/source/ui/view/outlnvsh.cxx` imports RTF into editable Impress outline content.

Reason to preserve it:

- The command is user-visible in Writer menus and command configuration.
- It depends on established RTF export/import semantics.
- It has asynchronous view activation and undo behavior that should not be disturbed by a new generator.

New deterministic helper boundary:

- Add a new Writer-side extractor: `const SwDoc& -> NormalizedPresentationOutline`.
- Add a new Impress-side builder: `NormalizedPresentationOutline -> SdDrawDocument`.
- Keep the model independent from RTF and independent from `OutlineViewShell::ReadRtf()`.
- Introduce a new command later, for example "Generate Presentation Draft", instead of reusing the legacy command.

Normalized model requirements:

- Document title.
- Ordered slides.
- Slide title.
- Bullet tree.
- Optional speaker notes.
- Source node or range references.
- Placeholder intent such as title, body, two-column, table, image-later.

Builder requirements:

- Generated slides must open in Impress.
- Slide count must equal the normalized model.
- Titles and bullets must remain editable placeholders, not flattened drawing text.
- PPTX export must succeed.
- Legacy `.uno:SendOutlineToStarImpress` must still work on the same fixture.

## Sequencing

1. Implement Writer preview diagnostics first, with no apply path.
2. Add deterministic model serialization tests for Writer-to-presentation extraction.
3. Build the Impress-side presentation builder only after the model is stable.
4. Add one-by-one fix actions and PPT generation UI commands after undo, preview, and export gates are proven.

## Non-Goals

- No cloud AI dependency.
- No generic chatbot detached from document context.
- No automatic destructive formatting.
- No import/export engine edits without a concrete failing compatibility sample.
- No changes to the legacy Writer-to-Impress RTF path for the deterministic PPT helper.
