# Presentation Outline Builder Design Review

Generated: 2026-04-28
Owner: Clavue
Reviewer: Codex
Milestone: M2-07

## Objective

Design the first deterministic Impress builder from `docs/schemas/presentation-outline.schema.json` before any source implementation. The builder must create editable Impress content from a normalized model while preserving the legacy Writer `.uno:SendOutlineToStarImpress` RTF flow.

## Non-Goals

- No source implementation in this round.
- No UI command, toolbar button, sidebar, or AI/provider entry point.
- No PPTX export/import engine changes.
- No replacement or mutation of `.uno:SendOutlineToStarImpress`.
- No use of `OutlineViewShell::ReadRtf()` for the deterministic helper.

## Existing Legacy Flow to Preserve

The current Writer-to-Impress path remains intact:

1. Writer command handling in `sw/source/uibase/app/docsh2.cxx` dispatches Writer outline/abstract data.
2. Impress receives `SID_OUTLINE_TO_IMPRESS` in `sd/source/ui/app/sdmod1.cxx`.
3. `SdModule::OutlineToImpress()` creates an Impress document, loads it into Outline View, and schedules `OutlineToImpressFinalizer`.
4. `OutlineToImpressFinalizer::operator()` calls `OutlineViewShell::ReadRtf()` and updates previews for each slide.
5. The legacy undo buffer is cleared at the end of the legacy flow.

This path is user-visible and depends on established RTF import behavior, asynchronous view activation, and existing command wiring. The deterministic builder must be separate.

## Normalized Model Inputs

The locked model is `presentation-outline.schema.json` with fixtures under `docs/schemas/fixtures/`.

Required top-level fields:

- `id`
- `title_zh`
- `language`
- `source_module`
- `slides`

Optional top-level evidence:

- `source_refs[]`: stable references back to document/heading/paragraph/table/image/range sources.

Per-slide fields:

- `id`: stable slide identifier.
- `section_zh`: optional grouping label.
- `title_zh`: required slide title.
- `layout`: one of `title`, `title-body`, `two-column`, `table`, `image-later`, `closing`.
- `bullets[]`: optional ordered text items with `level` and optional `source_ref`.
- `notes_zh`: optional speaker notes.
- `placeholders[]`: required editable placeholder intents.

Placeholder intents:

- `title`
- `body`
- `two-column-left`
- `two-column-right`
- `table`
- `image-later`
- `speaker-notes`

All placeholders currently require `editable: true`, which is the right contract for the first builder round.

## Proposed Implementation Boundary

### New model representation

Add a small internal C++ representation in the source tree, not a UI object:

- Candidate header: `sd/inc/PresentationOutline.hxx`
- Candidate source: `sd/source/ui/tools/PresentationOutlineBuilder.cxx` or a nearby non-UI helper path chosen by the sd maintainer.

Recommended structs:

- `PresentationOutline`
- `PresentationOutlineSlide`
- `PresentationOutlineBullet`
- `PresentationOutlinePlaceholder`
- `PresentationOutlineSourceRef`

The first implementation may construct these structs directly in tests. JSON parsing is not required in the first source round because the schema fixture already validates contract shape at the wrapper level.

### New builder entry point

Add one internal function that takes an existing or newly created Impress document model and populates it deterministically:

```cpp
namespace sd::intelligent
{
BuildPresentationOutlineResult BuildPresentationFromOutline(
    SdDrawDocument& rDocument,
    const PresentationOutline& rOutline);
}
```

The result should report:

- success/failure
- slide count created
- unsupported layout or placeholder diagnostics
- whether notes/placeholders were materialized

The first implementation should be test/internal only.

### Implementation-round preflight

Before editing `sd/`, the implementation owner must inspect the live source tree and name the exact gbuild test target. The round packet should identify:

- the chosen helper location;
- the chosen unit-test file or new test file;
- the slide/page insertion API used by existing sd tests;
- the text-object API used to assert editable title/body placeholders;
- whether notes insertion has a stable API in the selected surface.

If any of those cannot be named from current source, the implementation round should remain design-only instead of guessing against generated build artifacts.

## Layout Mapping

| Schema layout | Builder behavior | Required editable placeholders |
| --- | --- | --- |
| `title` | Create title slide with title placeholder text from `slide.title_zh`. | `title`; optional `speaker-notes` if `notes_zh` exists. |
| `title-body` | Create title plus body text placeholder; bullets are inserted in order. | `title`, `body`; optional `speaker-notes`. |
| `two-column` | Create title plus two editable body placeholders; distribute bullets deterministically. | `title`, `two-column-left`, `two-column-right`; optional `speaker-notes`. |
| `table` | Create title plus editable table/content placeholder; first implementation may create a text placeholder labelled for later table editing if table object creation is deferred. | `title`, `table`; optional `speaker-notes`. |
| `image-later` | Create title plus editable image placeholder text such as `图片占位：后续插入`. Do not embed generated images. | `title`, `image-later`; optional `speaker-notes`. |
| `closing` | Create closing slide with title/summary placeholder. | `title`; optional `body` or `speaker-notes` only if present in model. |

Two-column distribution must be deterministic:

- Prefer placeholder `source_ref` when it maps bullets to a side.
- If no explicit mapping exists, split bullet list by stable order: first half left, second half right.
- Preserve bullet order within each side.

## Bullet Mapping

Builder requirements:

- `bullets[]` order is the display order.
- Missing `level` means level 1.
- Minimum supported depth in the first implementation: levels 1 and 2.
- Levels greater than 2 may be clamped or rejected, but the behavior must be deterministic and reported in the result.
- Bullet text must remain editable text in Impress, not flattened images.

## Speaker Notes Mapping

`notes_zh` and any placeholder with intent `speaker-notes` should map to Impress speaker notes if a stable notes API is available in the chosen source surface.

If notes insertion is not implemented in the first builder patch:

- the builder result must explicitly report `speakerNotesMaterialized=false`;
- the test must not silently pass notes coverage;
- the design remains accepted only for title/body/placeholder editability until notes API proof is added.

## Source Reference Mapping

`source_refs[]` and per-placeholder/per-bullet `source_ref` values are traceability metadata. The first builder should not expose them to users unless there is an existing safe metadata channel.

Allowed first-round uses:

- include source refs in test expectations;
- use source refs to choose two-column placement;
- optionally store source refs in object metadata only if the sd maintainer identifies an existing stable field.

Disallowed first-round uses:

- comments or visible source-reference text added to slides;
- external links back to local/private paths;
- hidden macros, scripts, or provider callbacks.

## Test Target

Preferred test location: an sd CppUnit target, likely near existing model tests such as `sd/qa/unit/misc-tests.cxx` or a new focused sd unit test file if that is cleaner for the maintainer.

First fixture should construct a `PresentationOutline` equivalent to `presentation-outline.valid.json` and assert:

1. slide count equals `outline.slides.size()`;
2. slide 1 title text is `周报汇报草稿`;
3. slide 2 title text is `本周进展`;
4. slide 2 body contains bullets `完成兼容性冒烟验证` and `补充智能办公契约测试` in order;
5. bullet level/depth is preserved at least for level 1 and one level 2 fixture item added in the source test;
6. slide 3 uses a two-column layout with editable left/right text placeholders;
7. every schema placeholder with `editable: true` maps to an editable Impress object or a reported unsupported placeholder result;
8. optional notes are either materialized and asserted or explicitly reported as not yet materialized;
9. legacy `.uno:SendOutlineToStarImpress` behavior remains untouched by the new test/helper.

Suggested validation command for implementation round:

```sh
gmake -C /Users/lu/kdoffice-src sd.build
gmake -C /Users/lu/kdoffice-src CppunitTest_sd_misc_tests
```

If the final test target differs, the implementation owner must name the exact generated gbuild target before editing source.

## Ownership Gate Before Source Work

The next source round must have exactly one implementation owner for the `sd/` file family. Codex may review the design and schema fixtures, but should not edit `sd/` while Clavue is implementing the builder. Conversely, if Codex takes the builder implementation round, Clavue should switch to read-only review of source diffs and test evidence.

Required handoff before implementation:

- Codex review of this design records no blocking boundary issue, or records exact changes needed.
- `bin/intelligent-contract-fixtures.sh tmp/intelligent-contract-fixtures.md` is current and passing, or the implementation owner records why the existing 2026-04-28 fixture report remains sufficient for this design-only handoff.
- The round packet restates that the helper is internal/test-only and not wired to UI, AI generation, import/export filters, or the legacy Writer-to-Impress dispatch.

## Failure Behavior

The builder should reject or report, not guess, when it receives:

- zero slides;
- unknown layout;
- missing title placeholder for a title-bearing slide;
- non-editable placeholders;
- unsupported placeholder intents;
- impossible bullet levels if the implementation chooses strict mode.

Because schema validation already rejects most malformed model shapes, source-level builder checks should focus on semantic mapping, not duplicating the whole JSON schema validator.

## Acceptance for This Design Round

Status: **ready for Codex review before implementation**

This design identifies the builder boundary, source surfaces, model-to-Impress mapping, test expectations, and non-goals. Implementation must remain a later single-owner round and must not alter the legacy RTF outline flow.
