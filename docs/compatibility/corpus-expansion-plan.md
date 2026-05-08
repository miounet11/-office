# Compatibility Corpus Expansion Plan

This plan separates the current alpha smoke gate from the beta-quality compatibility matrix.

## Current Alpha Gate

Current manifest:

- `docs/compatibility/smoke-manifest.tsv`
- 27 samples total: 9 DOCX, 9 XLSX, 9 PPTX.
- Source: existing LibreOffice QA samples under `/Users/lu/kdoffice-src`.
- Gate command: `bin/compatibility-roundtrip.sh --manifest docs/compatibility/smoke-manifest.tsv --run-name <name>`.
- Beta/release strict validator command: `bin/compatibility-roundtrip.sh --manifest docs/compatibility/smoke-manifest.tsv --strict-validators --run-name <name>`.

What it proves:

- The packaged app can open and round-trip the selected samples.
- Basic package structure and coarse counts survive for the primary lanes.
- Validator status and advisory warnings are visible.

What it does not prove:

- Chinese workplace document fidelity.
- Pagination, comments, tracked changes, formulas, charts, pivot tables, animations, theme fidelity, macros, or accessibility.
- Visual fidelity or semantic equivalence.
- Validator conformance while ODF Validator, Officeotron, and veraPDF assets are missing.

## Beta Corpus Targets

Build the next corpus in explicit lanes. Keep private/user documents out of source control unless they are sanitized and license-safe.

| Lane | Target Count | Required Scenarios | Primary Risks |
| --- | ---: | --- | --- |
| DOCX Writer | 30 | government notice, weekly report, meeting minutes, resume, contract, table-heavy report, tracked-change review, comments, headers/footers | pagination, table layout, fonts, comments, redlines |
| XLSX Calc | 30 | budget, project schedule, sales tracker, formula workbook, chart workbook, filtered sheet, merged cells, conditional formatting, dates/currency | formulas, charts, filters, date/currency, merged layout |
| PPTX Impress | 30 | project report, teaching courseware, business pitch, image deck, embedded media, custom shapes, text fitting, theme-heavy deck, font-embedded deck | text fitting, theme colors, media, placeholders, fonts |
| ODF Control | 15 | ODT/ODS/ODP generated from curated templates and saved again | native regression, package conformance |
| PDF Export | 9 | one Writer, one Calc, one Impress sample per complexity tier | PDF/A conformance, embedded fonts, visual output |

## Selection Rules

- Prefer small, deterministic, redistributable samples.
- Do not include samples from paths marked `/fail/` in smoke gates.
- Include every sample with a scenario note and a specific risk label.
- Add a failing sample only when the corresponding bug is understood and the lane is marked targeted-regression, not smoke.
- Keep the alpha smoke manifest small enough for frequent local runs; put larger beta matrices in separate manifests.

## Proposed Manifest Files

- `docs/compatibility/smoke-manifest.tsv`: current alpha hard smoke.
- `docs/compatibility/beta-docx-manifest.tsv`: DOCX representative lane.
- `docs/compatibility/beta-xlsx-manifest.tsv`: XLSX representative lane.
- `docs/compatibility/beta-pptx-manifest.tsv`: PPTX representative lane.
- `docs/compatibility/beta-odf-pdf-manifest.tsv`: native ODF plus PDF export validation lane.

## Evidence Required Before Beta

- Validator assets ready: `bin/validator-readiness.sh --strict tmp/validator-readiness-strict.md`.
- Each beta manifest passes conversion.
- ODF Validator and Officeotron results are not skipped for ODF outputs.
- veraPDF results are not skipped for PDF outputs.
- `--strict-validators` is enabled so any ready validator failure blocks the roundtrip gate.
- At least one visual evidence path exists for DOCX, XLSX, and PPTX.
- Fidelity warnings are triaged by sample, not ignored.
- Any generated corpus from private documents has a provenance note and redaction confirmation.

## Next Implementation Slice

Do not expand the current P0 smoke blindly. First add a manifest generator/auditor that reports lane counts, scenario labels, duplicate paths, missing files, `/fail/` paths, and risk-label coverage. Then use it to build the beta manifests without changing import/export engine code.
