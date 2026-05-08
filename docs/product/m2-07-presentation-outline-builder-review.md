# M2-07 Presentation Outline Builder Review

Generated: 2026-04-28

## Decision

Done after Clavue revision.

The implementation direction is acceptable as an internal/test-only seed, and the required speaker-notes unsupported diagnostic assertion has been added to the test contract.

## Reviewed Scope

- `/Users/lu/kdoffice-src/sd/inc/PresentationOutline.hxx`
- `/Users/lu/kdoffice-src/sd/source/ui/tools/PresentationOutlineBuilder.cxx`
- `/Users/lu/kdoffice-src/sd/Library_sd.mk`
- `/Users/lu/kdoffice-src/sd/qa/unit/misc-tests.cxx`

Observed validation evidence:

- `gmake -C /Users/lu/kdoffice-src CppunitTest_sd_misc_tests`
- `workdir/CppunitTest/sd_misc_tests.test.log` shows `SdMiscTest::testPresentationOutlineBuilder`, `SdMiscTest::testPresentationOutlineBuilderValidation`, and final `OK (29)`.

## Keep Findings

- The builder is still internal/test-only; no UI command, sidebar, provider call, plugin runtime, import/export path, or PPTX export path was added.
- The legacy Writer-to-Impress command path remains separate. Search only found existing `.uno:SendOutlineToStarImpress` surfaces and the new builder symbols.
- The positive test asserts slide count, title text, body bullet text, placeholder materialization flag, and no diagnostics for the happy path.
- The validation test asserts zero-slide and missing-title-placeholder diagnostics.

## Required Revision

Completed.

- `sd/qa/unit/misc-tests.cxx` now asserts speaker-notes unsupported behavior in `SdMiscTest::testPresentationOutlineBuilderValidation`.
- The assertion covers a valid title/body outline with `maNotesZh`, successful slide creation, `mbSpeakerNotesMaterialized == false`, `SpeakerNotesUnsupported`, and diagnostic name `speaker-notes-unsupported`.
- This keeps notes visible as an unsupported/materialization gap rather than silently treating them as generated content.

## Non-Blocking Follow-Ups

- Add later coverage for bullet-level clamping.
- Add later coverage for two-column placeholder mapping.
- Add later coverage for table/image placeholder text.
- Keep these out of the accepted M2-07 seed; handle them only in a separate single-owner round.

## Revision Evidence

- `gmake -C /Users/lu/kdoffice-src CppunitTest_sd_misc_tests` passed after the speaker-notes diagnostic assertion was added.
- `git -C /Users/lu/kdoffice-src diff --check -- sd/qa/unit/misc-tests.cxx sd/inc/PresentationOutline.hxx sd/source/ui/tools/PresentationOutlineBuilder.cxx sd/Library_sd.mk` passed.
- No UI command, provider call, plugin runtime, import/export path, PPTX export path, or legacy Writer-to-Impress path was changed.

## Directive

Codex can now perform read-only closeout and mark M2-07 accepted if no false-confidence issue is found. Any further bullet-level, two-column, table, image, or notes materialization work should be a separate single-owner round.
