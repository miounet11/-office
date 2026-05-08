# China Blank Document Default Policy

Policy date: 2026-04-28

This document defines behavior targets for fresh Writer, Calc, and Impress documents before any `officecfg`, template, or module edits. It is intentionally a policy and audit artifact, not an implementation patch.

## Objective

Blank documents should feel ready for Chinese office work without making risky global configuration changes.

The target is not to force every user into one style. The target is to make the first blank document legible, familiar, compatible, printable, and easy to turn into common Chinese workplace artifacts.

## Current Evidence

Existing surfaces already provide useful Chinese-first foundations:

- `officecfg/registry/data/org/openoffice/VCL.xcu` contains zh-CN font fallback stacks for display, heading, presentation, spreadsheet, text, fixed, sans, and serif categories.
- `officecfg/registry/data/org/openoffice/Setup.xcu` has zh-CN factory names for Writer, Calc, Impress, Draw, Math, Base, and related factories.
- `officecfg/registry/data/org/openoffice/TypeDetection/UISort.xcu` puts Office Open XML filters before native ODF filters in visible Writer, Calc, and Impress filter ordering.
- Chinese scenario templates exist under `extras/source/templates/`.
- `extras/Package_templates.mk` and `extras/Package_tplpresnt.mk` package Chinese Writer/Calc/Impress scenario templates.
- `sfx2/source/dialog/backingwindow.cxx` maps Start Center scenario buttons to Chinese templates.

This means the next safe step is behavior verification and policy clarity, not immediate broad config mutation.

## Global Rules

- Do not force global locale, currency, date format, or default save format in this policy round.
- Do not assign factory default templates until fresh-profile behavior is verified.
- Do not change import/export filters without failing compatibility evidence.
- Keep blank Writer, Calc, and Impress creation obvious from the Workbench.
- Keep scenario templates separate from blank-document defaults.
- Prefer source-readable policy and targeted tests before changing `officecfg`.

## Writer Blank Document Targets

Fresh Writer documents should:

- use a Chinese-readable font stack through existing zh-CN fallback policy;
- preserve compatibility with DOCX exchange and PDF export;
- start with clean body text, heading styles, list styles, table styles, and page styles;
- use A4 portrait as the expected Chinese office baseline unless runtime evidence shows otherwise;
- use margins suitable for printing and PDF export;
- avoid surprising first-line indents or line-spacing changes unless they are style-defined and tested;
- make headings, body text, tables, captions, page numbers, comments, and tracked changes reliable before adding visual decoration;
- expose scenario templates such as work report, meeting minutes, resume, formal notice, and PPT outline from Workbench/template routes rather than forcing a default template.

Do not yet:

- force a government-document template as the generic blank Writer default;
- change default save format to DOCX;
- hard-code one Chinese font without fallback;
- alter Writer core style generation without a fresh-profile comparison.

Verification before implementation:

- fresh profile creates blank Writer document quickly;
- body text renders with expected zh-CN fallback;
- save/reopen to ODT works;
- export to PDF works;
- DOCX save/export remains available and visible;
- Workbench template routes still open scenario templates.

## Calc Blank Spreadsheet Targets

Fresh Calc documents should:

- use a Chinese-readable spreadsheet font stack through existing zh-CN fallback policy;
- keep grid, formula entry, filters, sorting, chart creation, and print setup discoverable;
- make date, number, currency, and percentage formats easy to use for Chinese business data;
- keep common templates such as budget, project schedule, sales tracking, and attendance as scenario/template entries;
- preserve XLSX compatibility and formula fidelity as the top priority.

Do not yet:

- force RMB currency or China locale globally;
- change default save format to XLSX;
- assign a budget template as the generic blank spreadsheet;
- modify formula behavior or recalculation policy without tests.

Verification before implementation:

- fresh profile creates blank Calc document quickly;
- typed Chinese headers and numeric data render correctly;
- basic formulas calculate correctly;
- save/reopen to ODS works;
- XLSX export remains visible and round-trip smoke remains green;
- budget/project templates remain available as scenario entries.

## Impress Blank Presentation Targets

Fresh Impress documents should:

- use a Chinese-readable presentation font stack through existing zh-CN fallback policy;
- default to an aspect ratio and theme suitable for modern workplace presentations, with widescreen as the likely target after verification;
- keep title, subtitle, body, two-column, table, image-later, closing, and speaker-note concepts compatible with the normalized presentation outline model;
- preserve editable placeholders and PPTX compatibility;
- keep work-report PPT, teaching courseware, and outline-to-PPT templates as scenario entries.

Do not yet:

- replace the legacy `.uno:SendOutlineToStarImpress` behavior;
- assign a project-report deck as the generic blank presentation;
- flatten generated content into images;
- change PPTX export behavior without compatibility samples.

Verification before implementation:

- fresh profile creates blank Impress document quickly;
- title/body placeholders are editable;
- speaker notes remain available;
- PPTX export works on a simple deck;
- scenario templates open from Workbench;
- normalized presentation outline builder design preserves editable placeholders.

## Candidate Implementation Surfaces

Only consider these after behavior verification:

- `officecfg/registry/data/org/openoffice/VCL.xcu` for font fallback adjustments.
- `officecfg/registry/data/org/openoffice/Setup.xcu` for factory metadata and template assignment.
- `officecfg/registry/data/org/openoffice/TypeDetection/UISort.xcu` for visible filter ordering.
- `extras/source/templates/` for scenario template content.
- `extras/Package_templates.mk` and `extras/Package_tplpresnt.mk` for template packaging.
- `sfx2/source/dialog/backingwindow.cxx` for scenario template routing.

## Acceptance Criteria

The default-policy round is complete when:

- Writer, Calc, and Impress blank-document behavior targets are documented.
- Existing Chinese-first surfaces are mapped.
- Risky default changes are explicitly deferred.
- Verification commands are listed for any future implementation round.
- No product source behavior is changed by this policy document.

## Recommended Next Step

Run a fresh-profile observation round before editing defaults:

- open blank Writer, Calc, and Impress from Start Center;
- record visible font, page/sheet/slide defaults, template routes, save/export visibility, and timing;
- compare against this policy;
- only then decide whether a config/template implementation round is justified.
