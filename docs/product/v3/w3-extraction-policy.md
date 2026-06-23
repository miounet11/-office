# V3-W3 Knowledge Index Extraction Policy

Status: **active contract** (2026-06-11; runtime extraction implementation not started)

This policy resolves W3 Q4: when a user edits PPT/PPTX content, the knowledge index must extract text from the document as LibreOffice imported it, not through a standalone PPT parser.

## Locked Decisions

| Field | Required value |
|---|---|
| `textExtractionPath` for Writer/Calc/Impress documents | `document-model` |
| `usesLibreOfficeImportFilter` for Writer/Calc/Impress documents | `true` |
| `usesDocumentModel` for Writer/Calc/Impress documents | `true` |
| `documentFamily` for PPTX | `impress` |
| `inputFormat` for PPTX | `pptx` |
| `preservesSlideElementRefs` for PPTX | `true` |
| `standalonePptParserAllowed` | `false` |
| `runtimeExtractionImplementation` | `not-started` |

## Rationale

PPTX text extraction must follow the existing LibreOffice import filter and Impress document model path. This keeps indexing aligned with what the user sees after import, preserves slide element references for future evidence and patch routing, and avoids a parallel PPT parser with divergent layout, comments, speaker notes, or shape-text behavior.

Connector content remains separate: connector chunks use `connector-normalized-markdown`, do not claim LibreOffice import filters, and do not claim document-model extraction.

## Guard Fixture

`docs/qa/fixtures/v3/knowledge-index-chunk/invalid/ppt-standalone-parser-runtime.json` must remain invalid. It represents forbidden drift where PPTX text is extracted through `standalone-ppt-parser`, the LibreOffice import filter and Impress document model are bypassed, slide element refs are not preserved, `standalonePptParserAllowed=true`, and runtime extraction starts before the W3 gate.

## Self-Test

`tests/v3-knowledge-index-chunk-test.sh` validates this policy through `extractionPolicy`, the valid `impress-pptx-slide-fts.json` fixture, and the invalid standalone-parser guard. The self-test reports `Checks: 11`.
