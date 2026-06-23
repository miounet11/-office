#!/usr/bin/env bash
# V3 W3/M4.6 - Knowledge Index retrieval metadata runtime smoke.

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

runtime_hxx = src / "sfx2/source/sidebar/AIChatKnowledgeRetrievalRuntime.hxx"
runtime_cxx = src / "sfx2/source/sidebar/AIChatKnowledgeRetrievalRuntime.cxx"
store_hxx = src / "sfx2/source/sidebar/AIChatKnowledgeIndexStore.hxx"
store_cxx = src / "sfx2/source/sidebar/AIChatKnowledgeIndexStore.cxx"
extraction_hxx = src / "sfx2/source/sidebar/AIChatKnowledgeExtractionRuntime.hxx"
extraction_cxx = src / "sfx2/source/sidebar/AIChatKnowledgeExtractionRuntime.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
vector_policy = repo / "docs/product/v3/w3-vector-store-policy.md"
model_policy = repo / "docs/product/v3/w3-model-acquisition-policy.md"
w3_spec = repo / "docs/product/v3/w3-knowledge-index-spec.md"
query_schema = repo / "docs/schemas/knowledge-index-query.schema.json"
result_schema = repo / "docs/schemas/knowledge-index-result.schema.json"
chunk_test = repo / "tests/v3-knowledge-index-chunk-test.sh"
query_result_test = repo / "tests/v3-knowledge-index-query-result-test.sh"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"
in_app = repo / "tests/v3-in-app-chat-test.sh"

for path in [
    runtime_hxx,
    runtime_cxx,
    store_hxx,
    store_cxx,
    extraction_hxx,
    extraction_cxx,
    library_mk,
    vector_policy,
    model_policy,
    w3_spec,
    query_schema,
    result_schema,
    chunk_test,
    query_result_test,
    todo,
    in_app,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = runtime_hxx.read_text()
cxx = runtime_cxx.read_text()
store = store_hxx.read_text() + store_cxx.read_text()
extraction = extraction_hxx.read_text() + extraction_cxx.read_text()
mk = library_mk.read_text()
vector_text = vector_policy.read_text()
model_text = model_policy.read_text()
w3_text = w3_spec.read_text()
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

query_fields = [
    "WorkspaceIdentity",
    "QueryId",
    "QueryTextHash",
    "Intent",
    "Language",
    "Mode",
    "TopK",
    "IncludeMetadata",
    "UserConfirmedModelDownload",
    "VectorOptIn",
    "PublicEgressAllowed",
    "TenantPolicyApproved",
]

result_fields = [
    "ChunkId",
    "Rank",
    "ScoreBasisPoints",
    "SourceKind",
    "TextHash",
    "SnippetHash",
    "EvidenceId",
    "ResultId",
    "RetrievalMode",
    "Backend",
    "Rerank",
    "LatencyMs",
    "Truncated",
]

checks = {
    "vector policy locked": "sqlite-fts5" in vector_text and "default backend" in vector_text and "lancedb-local" in vector_text and "opt-in" in vector_text and "runtimeVectorStoreImplementation" in vector_text,
    "model policy locked": "never downloaded silently" in model_text and "explicit user confirmation" in model_text and "SQLite FTS5" in model_text,
    "w3 query result spec": "knowledge-index-query-result self-test" in w3_text and "topK<=10" in w3_text and "snippetHash" in w3_text,
    "query schema": '"storesQueryText": {' in query_schema_text and '"maximum": 10' in query_schema_text and '"publicEgress"' in query_schema_text,
    "result schema": '"snippetHash"' in result_schema_text and '"storesDocumentContent"' in result_schema_text and '"maximum": 500' in result_schema_text,
    "contract tests cover retrieval": "fts query must use only sqlite-fts5" in query_result_test_text and "hybrid query must use sqlite-fts5 + lancedb-local" in query_result_test_text,
    "chunk tests cover vector": "vector-store default backend must remain sqlite-fts5" in chunk_test_text and "explicit user-confirmed BGE-m3 acquisition" in chunk_test_text,
    "runtime class": "class AIChatKnowledgeRetrievalRuntime final" in hxx,
    "query result structs": "struct AIChatKnowledgeRetrievalQuery" in hxx and "struct AIChatKnowledgeRetrievalResult" in hxx and "struct AIChatKnowledgeRetrievalChunkResult" in hxx,
    "all fields": all(field in hxx for field in query_fields + result_fields),
    "compiled": "sfx2/source/sidebar/AIChatKnowledgeRetrievalRuntime" in mk,
    "uses sidecar chunks": "AIChatKnowledgeIndexStore aStore" in cxx and "aStore.LoadChunks()" in cxx,
    "topk guard": "IsTopKAllowed" in hxx + cxx and "nTopK >= 1 && nTopK <= 10" in cxx and "top-k-max=10" in cxx,
    "query hash guard": "QueryTextHash" in hxx + cxx and "query-text-hash-required" in cxx and "IsLowerHex64(rQuery.QueryTextHash)" in cxx,
    "tenant policy guard": "TenantPolicyApproved" in hxx and "tenant-policy-required" in cxx,
    "public egress guard": "PublicEgressAllowed" in hxx and "public-egress-forbidden" in cxx and "public-egress=false" in cxx,
    "fts default": "IsFtsQuery" in hxx + cxx and 'RetrievalMode = u"fts"_ustr' in cxx and 'Backend = u"sqlite-fts5"_ustr' in cxx and 'Rerank = u"none"_ustr' in cxx,
    "hybrid guarded": "IsHybridQuery" in hxx + cxx and "IsVectorPathAllowed" in hxx + cxx and "VectorOptIn" in hxx and "UserConfirmedModelDownload" in hxx,
    "hybrid allowed posture": 'RetrievalMode = u"hybrid"_ustr' in cxx and 'Backend = u"sqlite-fts5+lancedb-local"_ustr' in cxx and 'Rerank = u"bge-m3"_ustr' in cxx,
    "hybrid fallback": "vector-path-not-authorized" in cxx and "fallback=sqlite-fts5" in cxx and "vector-opt-in-required=true" in cxx,
    "ids": "MakeQueryId" in hxx + cxx and "kbq-" in cxx and "MakeResultId" in hxx + cxx and "kbr-" in cxx,
    "snippet hash": "MakeSnippetHash" in hxx + cxx and "SnippetHash" in hxx + cxx and "snippet-hash-only=true" in cxx,
    "rank score": "Rank" in hxx and "ScoreBasisPoints" in hxx and "10000 - ((nRank - 1) * 500)" in cxx,
    "source guard": "SourceKindAllowed" in cxx and 'rSourceKind == u"document"_ustr' in cxx and 'rSourceKind == u"connector"_ustr' in cxx,
    "evidence required": "EvidenceId" in hxx and "rChunk.EvidenceId.isEmpty()" in cxx,
    "latency bound": "LatencyMs" in hxx and "aResult.LatencyMs = 0" in cxx,
    "success metadata only": "knowledge-query-complete" in cxx and "metadata-only=true" in cxx,
    "no raw query": "stores-query-text=false" in cxx and "raw-query-text=false" in cxx,
    "no raw snippet": "raw-snippet=false" in cxx and "snippet-hash-only=true" in cxx,
    "no document content": "stores-document-content=false" in cxx,
    "no silent model download": "silent-model-download=false" in cxx,
    "runtime vector not started": "runtime-vector-store-implementation=not-started" in cxx,
    "storage extraction still present": "AIChatKnowledgeIndexStore" in store and "AIChatKnowledgeExtractionRuntime" in extraction,
    "in app runs retrieval smoke": "v3-knowledge-retrieval-runtime-test.sh" in in_app_text,
    "todo records m4.6 complete": "- [x] M4.6 Implement FTS5 retrieval and optional vector path" in todo_text and "Follow-up task id: M4.7" in todo_text,
    "no raw content members": "RawText" not in combined and "DocumentText" not in combined and "SnippetText" not in combined and "QueryText;" not in combined,
    "no sqlite runtime": "sqlite3" not in combined and "sqlite3_" not in combined and "FtsBackend" not in combined,
    "no lancedb runtime": "lancedb::" not in combined and "VectorBackend" not in combined,
    "no model runtime": "EmbeddingPipeline" not in combined and "ModelDownloader" not in combined,
    "no network api": "INetURLObject" not in combined and "curl" not in combined.lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
    "no document mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 knowledge retrieval runtime self-test passed. Checks: {len(checks)}")
PY
