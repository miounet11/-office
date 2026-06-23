#!/usr/bin/env bash
# V3 W3/M4.5 - Knowledge Index extraction metadata runtime smoke.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src_root="$repo_root/libreoffice-core"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -d "$src_root" ]] || fail "missing source root $src_root"

python3 - "$repo_root" "$src_root" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

repo = Path(sys.argv[1])
src = Path(sys.argv[2])

runtime_hxx = src / "sfx2/source/sidebar/AIChatKnowledgeExtractionRuntime.hxx"
runtime_cxx = src / "sfx2/source/sidebar/AIChatKnowledgeExtractionRuntime.cxx"
store_hxx = src / "sfx2/source/sidebar/AIChatKnowledgeIndexStore.hxx"
store_cxx = src / "sfx2/source/sidebar/AIChatKnowledgeIndexStore.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
extraction_policy = repo / "docs/product/v3/w3-extraction-policy.md"
w3_spec = repo / "docs/product/v3/w3-knowledge-index-spec.md"
chunk_schema = repo / "docs/schemas/knowledge-index-chunk.schema.json"
chunk_test = repo / "tests/v3-knowledge-index-chunk-test.sh"
valid_impress = repo / "docs/qa/fixtures/v3/knowledge-index-chunk/valid/impress-pptx-slide-fts.json"
invalid_ppt = repo / "docs/qa/fixtures/v3/knowledge-index-chunk/invalid/ppt-standalone-parser-runtime.json"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"
in_app = repo / "tests/v3-in-app-chat-test.sh"

for path in [
    runtime_hxx,
    runtime_cxx,
    store_hxx,
    store_cxx,
    library_mk,
    extraction_policy,
    w3_spec,
    chunk_schema,
    chunk_test,
    valid_impress,
    invalid_ppt,
    todo,
    in_app,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = runtime_hxx.read_text()
cxx = runtime_cxx.read_text()
store = store_hxx.read_text() + store_cxx.read_text()
mk = library_mk.read_text()
policy_text = extraction_policy.read_text()
w3_text = w3_spec.read_text()
schema_text = chunk_schema.read_text()
chunk_test_text = chunk_test.read_text()
valid_impress_text = valid_impress.read_text()
invalid_ppt_text = invalid_ppt.read_text()
todo_text = todo.read_text()
in_app_text = in_app.read_text()
combined = hxx + cxx

def strip_leading_block_comments(text: str) -> str:
    body = text.lstrip()
    while body.startswith("/*") and "*/" in body:
        body = body.split("*/", 1)[1].lstrip()
    return body

cxx_body = strip_leading_block_comments(cxx)

fields = [
    "WorkspaceIdentity",
    "SourceKind",
    "SourceUriHash",
    "SourceId",
    "SnapshotId",
    "ContentHash",
    "TextHash",
    "DocumentFamily",
    "InputFormat",
    "Granularity",
    "Ordinal",
    "TokenCount",
    "Language",
    "EvidenceId",
    "HashReference",
    "UsesLibreOfficeImportFilter",
    "UsesDocumentModel",
    "PreservesSlideElementRefs",
    "StandalonePptParserAllowed",
]

checks = {
    "policy locked": "LibreOffice import filter" in policy_text and "Impress document model" in policy_text and "standalone PPT parser" in policy_text and "runtimeExtractionImplementation" in policy_text,
    "w3 spec extraction": "LibreOffice import filter + Impress document model" in w3_text and "禁止 standalone PPT parser" in w3_text,
    "schema extraction": '"extractionPolicy": {' in schema_text and '"textExtractionPath"' in schema_text and '"standalonePptParserAllowed"' in schema_text,
    "fixtures lock pptx": '"documentFamily": "impress"' in valid_impress_text and '"inputFormat": "pptx"' in valid_impress_text and '"preservesSlideElementRefs": true' in valid_impress_text,
    "invalid ppt guard": '"standalonePptParserAllowed": true' in invalid_ppt_text and '"runtimeExtractionImplementation": "started"' in invalid_ppt_text,
    "contract test checks extraction": "PPT/PPTX extraction must not use a standalone parser" in chunk_test_text and "LibreOffice import filters" in chunk_test_text,
    "runtime class": "class AIChatKnowledgeExtractionRuntime final" in hxx,
    "request result structs": "struct AIChatKnowledgeExtractionRequest" in hxx and "struct AIChatKnowledgeExtractionResult" in hxx,
    "all fields": all(field in hxx for field in fields),
    "compiled": "sfx2/source/sidebar/AIChatKnowledgeExtractionRuntime" in mk,
    "uses store": '#include "AIChatKnowledgeIndexStore.hxx"' in hxx and "AIChatKnowledgeIndexStore aStore" in cxx and "RegisterChunkMetadata" in cxx,
    "supported families": 'rDocumentFamily == u"writer"_ustr' in cxx and 'rDocumentFamily == u"calc"_ustr' in cxx and 'rDocumentFamily == u"impress"_ustr' in cxx and 'rDocumentFamily == u"connector"_ustr' in cxx,
    "writer odt document model": 'DocumentFamily == u"writer"_ustr' in cxx and 'InputFormat == u"odt"_ustr' in cxx,
    "calc ods document model": 'DocumentFamily == u"calc"_ustr' in cxx and 'InputFormat == u"ods"_ustr' in cxx,
    "impress odp pptx document model": 'DocumentFamily == u"impress"_ustr' in cxx and 'InputFormat == u"odp"_ustr' in cxx and 'InputFormat == u"pptx"_ustr' in cxx,
    "libreoffice import required": "UsesLibreOfficeImportFilter" in hxx and "!rRequest.UsesLibreOfficeImportFilter" in cxx and "uses-libreoffice-import-filter" in cxx,
    "document model required": "UsesDocumentModel" in hxx and "!rRequest.UsesDocumentModel" in cxx and "uses-document-model" in cxx,
    "pptx refs preserved": "PreservesSlideElementRefs" in hxx and "rRequest.PreservesSlideElementRefs" in cxx and "preserves-slide-element-refs" in cxx,
    "standalone ppt rejected": "StandalonePptParserAllowed" in hxx and "rRequest.StandalonePptParserAllowed" in cxx and "standalone-ppt-parser-allowed=false" in cxx,
    "pptx failure message": "pptx-must-use-libreoffice-import-filter" in cxx,
    "connector extraction": "IsConnectorExtraction" in hxx + cxx and "connector-normalized-markdown" in cxx and 'InputFormat == u"connector-markdown"_ustr' in cxx,
    "document extraction path": "ResolveTextExtractionPath" in hxx + cxx and 'return u"document-model"_ustr' in cxx,
    "metadata chunk": "AIChatKnowledgeIndexChunk aChunk" in cxx and 'RetrievalMode = u"fts"_ustr' in cxx and 'Backend = u"sqlite-fts5"_ustr' in cxx,
    "store raw guard reused": "ContainsRawContentFieldName" in cxx and "documentText" in cxx and "snippetText" in cxx,
    "success metadata only": "knowledge-extraction-metadata-created" in cxx and "metadata-only=true" in cxx,
    "no raw payload": "stores-document-content=false" in cxx and "raw-document-content=false" in cxx and "raw-query-text=false" in cxx and "raw-snippet=false" in cxx,
    "no public egress": "public-egress=false" in cxx,
    "runtime not started label": "runtime-extraction-implementation=not-started" in cxx,
    "storage remains sidecar": "application-data-directory" in store and "per-workspace" in store and "workspace-hash" in store,
    "in app runs extraction smoke": "v3-knowledge-extraction-runtime-test.sh" in in_app_text,
    "todo completed m4.5": "- [x] M4.5 Implement document extraction through LibreOffice filters" in todo_text and "Follow-up task id: M4.6" in todo_text,
    "no raw content members": "RawText" not in combined and "DocumentText" not in combined and "QueryText" not in combined and "SnippetText" not in combined and "SourceUri;" not in combined,
    "no standalone parser runtime": "standalone-ppt-parser" in cxx and "StandalonePptParserRuntime" not in combined and "PPTParserRuntime" not in combined,
    "no fts runtime": "sqlite3" not in combined and "FTS5" not in combined,
    "no watcher runtime": "FSEvent" not in combined and "inotify" not in combined and "ReadDirectoryChanges" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no document mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 knowledge extraction runtime self-test passed. Checks: {len(checks)}")
PY
