# Presentation Outline Contract Review

Review date: 2026-04-28

Status update: Superseded by M2-07 internal/test-only builder acceptance in `docs/product/m2-07-presentation-outline-builder-review.md`. The pre-implementation warnings below now mean: do not expand the accepted seed into UI/provider/plugin/runtime/export behavior without a new accepted round packet.

Reviewed surfaces:

- `docs/schemas/presentation-outline.schema.json`
- `docs/schemas/fixtures/presentation-outline.valid.json`
- `docs/schemas/fixtures/presentation-outline.invalid.json`
- `bin/intelligent-contract-fixtures.sh`

## Verdict

P1-07 is acceptable as a fixture-only normalized outline contract. It is ready to use as the design boundary for the next presentation-builder design round.

Do not expand the accepted internal/test-only Impress builder into a UI command, provider path, plugin runtime, import/export path, or PPTX export path until the semantic hardening items below are either addressed or explicitly accepted in a new round.

## What The Contract Covers Well

- Document-level identity with stable `id`.
- Chinese title through `title_zh`.
- Language scope through `language`.
- Source module scope through `source_module`.
- Ordered `slides` array.
- Slide-level `id`, `title_zh`, `section_zh`, `layout`, `bullets`, `notes_zh`, and `placeholders`.
- Editable placeholder intent through `placeholders[].intent` and `editable: true`.
- Source traceability through `source_refs` and `source_ref` fields.
- Negative fixture rejects flattened/non-editable image-style output.

This is the correct first boundary because it describes an editable target model instead of replacing the existing Writer-to-Impress RTF path.

## Non-Blocking Gaps

These are not blockers for P1-07, but they should be handled before or inside the first builder implementation:

- `bullets[].level` has no `minimum`, so negative or very deep levels are schema-valid today.
- `source_ref` fields are plain strings and are not schema-validated against top-level `source_refs[].id`.
- Slide ids and placeholder ids are not globally unique across the whole outline; uniqueness is only enforced within each `placeholders` array.
- `notes_zh` is a free string, while placeholder intent includes `speaker-notes`; the builder must define whether notes are represented by `notes_zh`, a placeholder, or both.
- Table and image-later layouts define placeholder intent but no structured table/image metadata yet.
- There is no explicit deck theme, page size, aspect ratio, or template reference; the first builder should use safe defaults and record them.

## Builder Rules Derived From The Contract

The first implementation must:

- Preserve legacy `.uno:SendOutlineToStarImpress`.
- Create editable Impress placeholders, not flattened rendered images.
- Preserve slide order exactly as the `slides` array order.
- Preserve `title_zh`, bullet text, bullet level, notes, and source references where supported.
- Treat unknown or unsupported source references as warnings, not fatal crashes.
- Keep AI/provider generation out of the builder round.
- Avoid a UI command until an internal test proves slide count, title text, bullet depth, notes, and placeholder editability.

## Required Builder Test Shape

The first builder test should assert:

- output deck opens as an Impress document;
- generated slide count equals `slides.length`;
- each generated title remains editable text;
- body placeholders remain editable text;
- bullet levels map deterministically;
- speaker notes are preserved or explicitly recorded as not implemented;
- source refs survive as internal metadata or are reported in a builder result;
- no legacy Writer-to-Impress command behavior is changed.

## Verification Performed

Passed:

- `bin/intelligent-contract-fixtures.sh tmp/intelligent-contract-fixtures.md`
- `python3 -m json.tool docs/schemas/presentation-outline.schema.json`
- `python3 -m json.tool docs/schemas/fixtures/presentation-outline.valid.json`
- `python3 -m json.tool docs/schemas/fixtures/presentation-outline.invalid.json`

## Keep / Reject Decision

Keep P1-07.

The contract was good enough for the M2-07 internal/test-only builder seed. Further work should be separate single-owner semantic hardening or UI/provider planning, not scope expansion inside the accepted M2-07 seed.
