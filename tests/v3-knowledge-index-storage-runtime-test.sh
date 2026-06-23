#!/usr/bin/env bash
# V3 W3/M4.4 - Knowledge Index sidecar storage runtime smoke.

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

store_hxx = src / "sfx2/source/sidebar/AIChatKnowledgeIndexStore.hxx"
store_cxx = src / "sfx2/source/sidebar/AIChatKnowledgeIndexStore.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
storage_policy = repo / "docs/product/v3/w3-storage-policy.md"
w3_spec = repo / "docs/product/v3/w3-knowledge-index-spec.md"
chunk_schema = repo / "docs/schemas/knowledge-index-chunk.schema.json"
query_schema = repo / "docs/schemas/knowledge-index-query.schema.json"
result_schema = repo / "docs/schemas/knowledge-index-result.schema.json"
chunk_test = repo / "tests/v3-knowledge-index-chunk-test.sh"
query_result_test = repo / "tests/v3-knowledge-index-query-result-test.sh"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"
in_app = repo / "tests/v3-in-app-chat-test.sh"

for path in [
    store_hxx,
    store_cxx,
    library_mk,
    storage_policy,
    w3_spec,
    chunk_schema,
    query_schema,
    result_schema,
    chunk_test,
    query_result_test,
    todo,
    in_app,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = store_hxx.read_text()
cxx = store_cxx.read_text()
mk = library_mk.read_text()
storage_text = storage_policy.read_text()
w3_text = w3_spec.read_text()
chunk_schema_text = chunk_schema.read_text()
query_schema_text = query_schema.read_text()
result_schema_text = result_schema.read_text()
chunk_test_text = chunk_test.read_text()
query_result_test_text = query_result_test.read_text()
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
    "ChunkId",
    "WorkspaceHash",
    "SourceKind",
    "SourceUriHash",
    "SourceId",
    "SnapshotId",
    "ContentHash",
    "TextHash",
    "Granularity",
    "Ordinal",
    "TokenCount",
    "Language",
    "RetrievalMode",
    "Backend",
    "EvidenceId",
    "HashReference",
]

storage_policy_literals = [
    "application-data-directory",
    "per-workspace",
    "workspace-hash",
    "colocated-with-user-documents=false",
    "syncs-with-user-documents=false",
    "stores-document-content=false",
    "runtime-storage-implementation=not-started",
]

forbidden_field_guards = [
    'rFieldName == u"text"_ustr',
    'rFieldName == u"content"_ustr',
    'rFieldName == u"rawText"_ustr',
    'rFieldName == u"body"_ustr',
    'rFieldName == u"documentText"_ustr',
    'rFieldName == u"contentText"_ustr',
    'rFieldName == u"queryText"_ustr',
    'rFieldName == u"snippetText"_ustr',
]

checks = {
    "storage policy locked": "application data directory" in storage_text and "per-workspace sidecar" in storage_text and "workspace-hash" in storage_text,
    "w3 spec storage": "application data directory + per-workspace sidecar" in w3_text and "runtime storage implementation" in w3_text,
    "schema storage policy": '"indexRoot": {' in chunk_schema_text and '"const": "application-data-directory"' in chunk_schema_text and '"runtimeStorageImplementation"' in chunk_schema_text,
    "query result no raw": "storesQueryText" in query_schema_text and "snippetHash" in result_schema_text,
    "contract tests present": "Storage policy: app data per-workspace sidecar" in chunk_test_text and "storesQueryText" in query_result_test_text and "snippetHash" in query_result_test_text,
    "store class": "class AIChatKnowledgeIndexStore final" in hxx,
    "chunk struct": "struct AIChatKnowledgeIndexChunk" in hxx,
    "result struct": "struct AIChatKnowledgeIndexStoreResult" in hxx,
    "all fields": all(field in hxx for field in fields),
    "compiled": "sfx2/source/sidebar/AIChatKnowledgeIndexStore" in mk,
    "app data root": "SvtPathOptions" in cxx and "GetUserConfigPath()" in cxx and "kqoffice-v3-knowledge-index" in cxx,
    "per workspace sidecar": "m_sWorkspaceHash" in cxx and "m_sWorkspaceSidecarDirUrl = m_sStorageRootUrl" in cxx and "chunks.tsv" in cxx,
    "workspace hash": "MakeWorkspaceHash" in hxx + cxx and "workspace-hash:" in cxx and "comphelper::Hash::calculateHash" in cxx,
    "source uri hash": "SourceUriHash" in hxx + cxx and "MakeSourceUriHash" in hxx + cxx and "source-uri:" in cxx,
    "chunk id": "MakeChunkId" in hxx + cxx and "kbch-" in cxx,
    "metadata hash": "MakeMetadataHash" in hxx + cxx and "HashType::SHA256" in cxx,
    "bounded sidecar read": "MAX_KNOWLEDGE_INDEX_BYTES" in cxx,
    "utf8 sidecar": "RTL_TEXTENCODING_UTF8" in cxx and "EscapeField" in cxx and "UnescapeField" in cxx,
    "append load clear": "RegisterChunkMetadata" in hxx + cxx and "LoadChunks" in hxx + cxx and "ClearWorkspaceSidecar" in hxx + cxx,
    "storage policy method": "IsValidStoragePolicy" in hxx + cxx and all(token in cxx for token in storage_policy_literals),
    "no user document sync": "!bColocatedWithUserDocuments" in cxx and "!bSyncsWithUserDocuments" in cxx and "!bStoresDocumentContent" in cxx,
    "hash only validation": "IsLowerHex64" in cxx and "hash-reference-required" in cxx and "ContentHash" in hxx and "TextHash" in hxx,
    "source kind validation": 'SourceKind != u"document"_ustr' in cxx and 'SourceKind != u"connector"_ustr' in cxx,
    "granularity validation": 'Granularity != u"paragraph"_ustr' in cxx and "sentence-fallback" in cxx,
    "token count validation": "TokenCount <= 0" in cxx and "TokenCount > 2048" in cxx,
    "retrieval metadata validation": 'RetrievalMode != u"fts"_ustr' in cxx and 'Backend != u"sqlite-fts5"_ustr' in cxx and "vector-backend-requires-hybrid" in cxx,
    "evidence required": "evidence-and-hash-required" in cxx and "EvidenceId" in hxx and "HashReference" in hxx,
    "raw field guard": "ContainsRawContentFieldName" in hxx + cxx and all(guard in cxx for guard in forbidden_field_guards),
    "success metadata only": "knowledge-index-chunk-stored" in cxx and "metadata-only=true" in cxx,
    "no raw payload": "raw-document-content=false" in cxx and "raw-query-text=false" in cxx and "raw-snippet=false" in cxx,
    "no public egress": "public-egress=false" in cxx,
    "no silent model download": "silent-model-download=false" in cxx,
    "vector default guarded": "vector-default=sqlite-fts5" in cxx,
    "in app runs storage smoke": "v3-knowledge-index-storage-runtime-test.sh" in in_app_text,
    "todo completed m4.4": "- [x] M4.4 Implement Knowledge Index sidecar storage" in todo_text and "Follow-up task id: M4.5" in todo_text,
    "no raw content members": "RawText" not in combined and "DocumentText" not in combined and "QueryText" not in combined and "SnippetText" not in combined and "SourceUri;" not in combined,
    "no sqlite runtime": "sqlite3" not in combined and "FTS5" not in combined,
    "no model runtime": "EmbeddingPipeline" not in combined and "ModelDownloader" not in combined and "runtimeDownloaderImplementation" not in cxx_body,
    "no watcher runtime": "FSEvent" not in combined and "inotify" not in combined and "ReadDirectoryChanges" not in combined,
    "no network api": "INetURLObject" in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no document mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 knowledge index storage runtime self-test passed. Checks: {len(checks)}")
PY
