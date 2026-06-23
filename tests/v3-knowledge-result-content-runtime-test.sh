#!/usr/bin/env bash
# V3 W3/M4.7 - Knowledge Index result to W1 content object runtime smoke.

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

bridge_hxx = src / "sfx2/source/sidebar/AIChatKnowledgeResultContentBridge.hxx"
bridge_cxx = src / "sfx2/source/sidebar/AIChatKnowledgeResultContentBridge.cxx"
retrieval_hxx = src / "sfx2/source/sidebar/AIChatKnowledgeRetrievalRuntime.hxx"
retrieval_cxx = src / "sfx2/source/sidebar/AIChatKnowledgeRetrievalRuntime.cxx"
registry_hxx = src / "sfx2/source/sidebar/AIChatContentRegistry.hxx"
registry_cxx = src / "sfx2/source/sidebar/AIChatContentRegistry.cxx"
provenance_hxx = src / "sfx2/source/sidebar/AIChatSourceProvenance.hxx"
provenance_cxx = src / "sfx2/source/sidebar/AIChatSourceProvenance.cxx"
preview_cxx = src / "sfx2/source/sidebar/AIChatPreviewMatrix.cxx"
opener_cxx = src / "sfx2/source/sidebar/AIChatContentOpener.cxx"
evidence_cxx = src / "sfx2/source/sidebar/AIChatEvidenceInspector.cxx"
review_cxx = src / "sfx2/source/sidebar/AIChatContentReviewStore.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
w3_spec = repo / "docs/product/v3/w3-knowledge-index-spec.md"
query_schema = repo / "docs/schemas/knowledge-index-query.schema.json"
result_schema = repo / "docs/schemas/knowledge-index-result.schema.json"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"
in_app = repo / "tests/v3-in-app-chat-test.sh"

for path in [
    bridge_hxx,
    bridge_cxx,
    retrieval_hxx,
    retrieval_cxx,
    registry_hxx,
    registry_cxx,
    provenance_hxx,
    provenance_cxx,
    preview_cxx,
    opener_cxx,
    evidence_cxx,
    review_cxx,
    library_mk,
    w3_spec,
    query_schema,
    result_schema,
    todo,
    in_app,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = bridge_hxx.read_text()
cxx = bridge_cxx.read_text()
retrieval = retrieval_hxx.read_text() + retrieval_cxx.read_text()
registry = registry_hxx.read_text() + registry_cxx.read_text()
provenance = provenance_hxx.read_text() + provenance_cxx.read_text()
preview = preview_cxx.read_text()
opener = opener_cxx.read_text()
evidence = evidence_cxx.read_text()
review = review_cxx.read_text()
mk = library_mk.read_text()
w3_text = w3_spec.read_text()
query_schema_text = query_schema.read_text()
result_schema_text = result_schema.read_text()
todo_text = todo.read_text()
in_app_text = in_app.read_text()
combined = hxx + cxx + retrieval + registry + provenance + preview + opener + evidence + review


def strip_leading_block_comments(text: str) -> str:
    body = text.lstrip()
    while body.startswith("/*") and "*/" in body:
        body = body.split("*/", 1)[1].lstrip()
    return body


cxx_body = strip_leading_block_comments(cxx)

result_fields = [
    "Success",
    "RegistryEntry",
    "SourceId",
    "CitationId",
    "EvidenceId",
    "HashReference",
    "Message",
]

checks = {
    "w3 result contract": "knowledge-index-query-result self-test" in w3_text and "snippetHash" in w3_text and "storesQueryText" in w3_text,
    "query schema metadata only": '"storesQueryText": {' in query_schema_text and '"const": false' in query_schema_text,
    "result schema metadata only": '"storesDocumentContent"' in result_schema_text and '"snippetHash"' in result_schema_text and '"rawSnippet"' not in result_schema_text,
    "bridge class": "class AIChatKnowledgeResultContentBridge final" in hxx,
    "bridge result struct": "struct AIChatKnowledgeResultContentBridgeResult" in hxx,
    "all result fields": all(field in hxx for field in result_fields),
    "register result api": "RegisterResult(const AIChatKnowledgeRetrievalResult& rResult) const" in hxx + cxx,
    "compiled": "sfx2/source/sidebar/AIChatKnowledgeResultContentBridge" in mk,
    "uses retrieval result": "AIChatKnowledgeRetrievalResult" in hxx + cxx and "AIChatKnowledgeRetrievalChunkResult" in retrieval,
    "requires successful query": "if (!rResult.Success)" in cxx and "query-not-successful" in cxx,
    "requires ids": "rResult.ResultId.isEmpty()" in cxx and "rResult.QueryId.isEmpty()" in cxx and "missing-result-or-query-id" in cxx,
    "requires chunks": "rResult.Chunks.empty()" in cxx and "missing-result-chunks" in cxx,
    "evidence helper": "MakeKnowledgeResultEvidenceId" in hxx + cxx and "rResult.Chunks.front().EvidenceId" in cxx,
    "fallback evidence id": "evidence:knowledge-query:" in cxx,
    "hash helper": "MakeKnowledgeResultHashReference" in hxx + cxx and "rResult.Chunks.front().SnippetHash" in cxx,
    "metadata hash fallback": "AIChatKnowledgeIndexStore::MakeMetadataHash" in cxx and "rResult.QueryId" in cxx and "rResult.ResultId" in cxx,
    "requires evidence hash": "missing-evidence-or-hash" in cxx,
    "registry object id": "aResult.RegistryEntry.ObjectId = rResult.ResultId" in cxx,
    "registry type": 'aResult.RegistryEntry.Type = u"knowledge-index-result"_ustr' in cxx,
    "registry source surface": 'aResult.RegistryEntry.SourceSurface = u"knowledge-index-query"_ustr' in cxx,
    "registry state": 'aResult.RegistryEntry.State = u"registered"_ustr' in cxx,
    "registry evidence": "aResult.RegistryEntry.EvidenceId = aResult.EvidenceId" in cxx,
    "registry hash": "aResult.RegistryEntry.HashReference = aResult.HashReference" in cxx,
    "registry target": 'aResult.RegistryEntry.OpenTarget = u"sidebar-preview"_ustr' in cxx,
    "registry preview mode": 'aResult.RegistryEntry.PreviewMode = u"metadata-summary"_ustr' in cxx,
    "registers content object": "AIChatContentRegistry aRegistry" in cxx and "aRegistry.RegisterObject(aResult.RegistryEntry)" in cxx,
    "registry write fail closed": "registry-write-failed" in cxx,
    "registers provenance": "AIChatSourceProvenance aProvenance" in cxx and "aProvenance.RegisterSource(aSource)" in cxx,
    "provenance source id": "AIChatSourceProvenance::MakeSourceId(rResult.ResultId)" in cxx,
    "provenance citation": "AIChatSourceProvenance::MakeCitationId(rResult.ResultId)" in cxx,
    "provenance source type": 'aSource.SourceType = u"knowledge-index-result"_ustr' in cxx,
    "provenance source surface": 'aSource.SourceSurface = u"knowledge-index-query"_ustr' in cxx,
    "provenance target": 'aSource.OpenTarget = u"sidebar-preview"_ustr' in cxx,
    "provenance span": "span:knowledge-query:" in cxx,
    "success message": "knowledge-result-registered result-id=" in cxx and "registry=true provenance=true" in cxx,
    "message target": "open-target=sidebar-preview" in cxx and "preview-mode=metadata-summary" in cxx,
    "message evidence hash citation": "evidence-id=" in cxx and "hash-reference=" in cxx and "citation-id=" in cxx,
    "message metadata only": "metadata-only=true" in cxx,
    "message no raw query": "raw-query-text=false" in cxx,
    "message no raw snippet": "raw-snippet=false" in cxx,
    "message no document content": "stores-document-content=false" in cxx,
    "message read only": "read-only=true" in cxx and "main-document-mutation=false" in cxx,
    "retrieval feeds snippets as hashes": "SnippetHash" in retrieval and "snippet-hash-only=true" in retrieval,
    "registry metadata only fields": "struct AIChatContentRegistryEntry" in registry and "HashReference" in registry and "PreviewMode" in registry,
    "provenance metadata only fields": "struct AIChatSourceProvenanceEntry" in provenance and "CitationId" in provenance and "HashReference" in provenance,
    "preview supports knowledge": 'rEntry.Type == u"knowledge-index-result"_ustr' in preview and "sidebar-preview" in preview and "metadata-summary" in preview,
    "opener read only preview": "OpenReadOnlyPreview" in opener and "read-only=true main-document-mutation=false" in opener,
    "evidence inspector supports knowledge": 'rSourceType == u"knowledge-index-result"_ustr' in evidence,
    "content review supports knowledge": 'rSourceType == u"knowledge-index-result"_ustr' in review,
    "in app runs result bridge smoke": "v3-knowledge-result-content-runtime-test.sh" in in_app_text,
    "todo has m4.7": "M4.7 Integrate Knowledge Index results into W1 content objects" in todo_text,
    "no raw query member": "QueryText;" not in combined and "RawQuery" not in combined and "RawText" not in combined,
    "no raw snippet member": "SnippetText" not in combined and "RawSnippet" not in combined and "PreviewBody" not in combined,
    "no raw payload": "Payload" not in hxx + cxx and "RawContent" not in hxx + cxx and "DocumentText" not in hxx + cxx,
    "no main doc mutation": "SwDoc" not in hxx + cxx and "ScDoc" not in hxx + cxx and "SdDrawDocument" not in hxx + cxx,
    "no connector writeback": "WriteBack" not in hxx + cxx and "writeback=true" not in cxx.lower(),
    "no sqlite runtime": "sqlite3" not in hxx + cxx and "sqlite3_" not in hxx + cxx,
    "no lancedb runtime": "lancedb::" not in hxx + cxx and "VectorBackend" not in hxx + cxx,
    "no model runtime": "EmbeddingPipeline" not in hxx + cxx and "ModelDownloader" not in hxx + cxx,
    "no network api": "INetURLObject" not in hxx + cxx and "curl" not in (hxx + cxx).lower() and "http://" not in cxx_body.lower() and "https://" not in cxx_body.lower(),
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 knowledge result content runtime self-test passed. Checks: {len(checks)}")
PY
