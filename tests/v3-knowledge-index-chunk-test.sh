#!/usr/bin/env bash
# V3 W3 - knowledge-index-chunk contract self-test.
#
# Contract-first gate for W3. It does not start the gated IndexManager,
# FTS/vector backend, chunker, watcher, embedding pipeline, or query API.
# It locks the retrieval chunk envelope, local/private data boundary,
# BGE-m3 vector dimensions, explicit model acquisition policy,
# vector-store backend default/fallback policy, watcher scalability
# policy, PPTX extraction path policy, index storage-location policy,
# no raw document-content storage, and document-snapshot separation.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

schema="docs/schemas/knowledge-index-chunk.schema.json"
w3_spec="docs/product/v3/w3-knowledge-index-spec.md"
w5_spec="docs/product/v3/w5-eval-harness-spec.md"
master_plan="docs/product/v3-master-plan.md"
model_policy_doc="docs/product/v3/w3-model-acquisition-policy.md"
vector_policy_doc="docs/product/v3/w3-vector-store-policy.md"
watcher_policy_doc="docs/product/v3/w3-watcher-scalability-policy.md"
extraction_policy_doc="docs/product/v3/w3-extraction-policy.md"
storage_policy_doc="docs/product/v3/w3-storage-policy.md"
sweep="bin/v3-eval-sweep.sh"
workflow=".github/workflows/v3-contract-harnesses.yml"
valid_dir="docs/qa/fixtures/v3/knowledge-index-chunk/valid"
invalid_dir="docs/qa/fixtures/v3/knowledge-index-chunk/invalid"

[[ -f "$schema" ]] || fail "missing $schema"
[[ -f "$w3_spec" ]] || fail "missing $w3_spec"
[[ -f "$w5_spec" ]] || fail "missing $w5_spec"
[[ -f "$master_plan" ]] || fail "missing $master_plan"
[[ -f "$model_policy_doc" ]] || fail "missing $model_policy_doc"
[[ -f "$vector_policy_doc" ]] || fail "missing $vector_policy_doc"
[[ -f "$watcher_policy_doc" ]] || fail "missing $watcher_policy_doc"
[[ -f "$extraction_policy_doc" ]] || fail "missing $extraction_policy_doc"
[[ -f "$storage_policy_doc" ]] || fail "missing $storage_policy_doc"
[[ -f "$sweep" ]] || fail "missing $sweep"
[[ -f "$workflow" ]] || fail "missing $workflow"
[[ -d "$valid_dir" ]] || fail "missing $valid_dir"
[[ -d "$invalid_dir" ]] || fail "missing $invalid_dir"

python3 - "$schema" "$w3_spec" "$w5_spec" "$master_plan" "$model_policy_doc" "$vector_policy_doc" "$watcher_policy_doc" "$extraction_policy_doc" "$storage_policy_doc" "$sweep" "$workflow" "$valid_dir" "$invalid_dir" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

schema_path = Path(sys.argv[1])
w3_spec = Path(sys.argv[2])
w5_spec = Path(sys.argv[3])
master_plan = Path(sys.argv[4])
model_policy_doc = Path(sys.argv[5])
vector_policy_doc = Path(sys.argv[6])
watcher_policy_doc = Path(sys.argv[7])
extraction_policy_doc = Path(sys.argv[8])
storage_policy_doc = Path(sys.argv[9])
sweep_path = Path(sys.argv[10])
workflow_path = Path(sys.argv[11])
valid_dir = Path(sys.argv[12])
invalid_dir = Path(sys.argv[13])

EXPECTED_REQUIRED = [
    "id",
    "schemaVersion",
    "createdAt",
    "workspace",
    "source",
    "chunk",
    "index",
    "modelAcquisitionPolicy",
    "vectorStorePolicy",
    "watcherPolicy",
    "extractionPolicy",
    "storagePolicy",
    "boundary",
    "evidence",
]
EXPECTED_VALID_FILES = {
    "writer-paragraph-fts.json",
    "calc-sentence-fallback-fts.json",
    "connector-hybrid-private.json",
    "impress-pptx-slide-fts.json",
}
EXPECTED_INVALID_FILES = {
    "stores-document-content.json",
    "public-egress-cloud.json",
    "embedding-dimension-drift.json",
    "model-acquisition-silent-download.json",
    "vector-store-lancedb-default-runtime.json",
    "watcher-per-file-fd-runtime.json",
    "ppt-standalone-parser-runtime.json",
    "storage-user-documents-sync-runtime.json",
}
EXPECTED_GRANULARITIES = {"paragraph", "sentence-fallback"}
EXPECTED_SOURCE_KINDS = {"document", "connector"}
EXPECTED_BACKENDS = {"sqlite-fts5", "lancedb-local"}
EXPECTED_DOCUMENT_FAMILIES = {"writer", "calc", "impress", "connector"}
EXPECTED_INPUT_FORMATS = {"odt", "ods", "pptx", "connector-markdown"}
FORBIDDEN_CONTENT_FIELDS = {
    "text",
    "content",
    "rawText",
    "body",
    "documentText",
    "contentText",
}
ROOT_EVIDENCE = {"document-snapshot", "index-update", "no-public-egress"}


def die(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def load(path: Path) -> Any:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def json_pointer(path: list[str]) -> str:
    if not path:
        return "$"
    return "$" + "".join(f"/{part}" for part in path)


def type_matches(value: Any, expected: str) -> bool:
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    return True


def validate(value: Any, schema: dict[str, Any], path: list[str]) -> list[str]:
    errors: list[str] = []
    expected_type = schema.get("type")
    if isinstance(expected_type, str) and not type_matches(value, expected_type):
        return [f"{json_pointer(path)} expected {expected_type}"]

    if "const" in schema and value != schema["const"]:
        errors.append(f"{json_pointer(path)} expected const {schema['const']!r}")

    enum_values = schema.get("enum")
    if isinstance(enum_values, list) and value not in enum_values:
        errors.append(f"{json_pointer(path)} expected one of {enum_values!r}")

    if isinstance(value, str):
        pattern = schema.get("pattern")
        if isinstance(pattern, str) and re.search(pattern, value) is None:
            errors.append(f"{json_pointer(path)} does not match {pattern!r}")
        min_length = schema.get("minLength")
        max_length = schema.get("maxLength")
        if isinstance(min_length, int) and len(value) < min_length:
            errors.append(f"{json_pointer(path)} shorter than minLength {min_length}")
        if isinstance(max_length, int) and len(value) > max_length:
            errors.append(f"{json_pointer(path)} longer than maxLength {max_length}")

    if isinstance(value, int) and not isinstance(value, bool):
        minimum = schema.get("minimum")
        maximum = schema.get("maximum")
        if isinstance(minimum, int) and value < minimum:
            errors.append(f"{json_pointer(path)} below minimum {minimum}")
        if isinstance(maximum, int) and value > maximum:
            errors.append(f"{json_pointer(path)} above maximum {maximum}")

    if isinstance(value, list):
        min_items = schema.get("minItems")
        max_items = schema.get("maxItems")
        if isinstance(min_items, int) and len(value) < min_items:
            errors.append(f"{json_pointer(path)} has fewer than minItems {min_items}")
        if isinstance(max_items, int) and len(value) > max_items:
            errors.append(f"{json_pointer(path)} has more than maxItems {max_items}")
        if schema.get("uniqueItems") is True:
            seen: set[str] = set()
            for index, item in enumerate(value):
                key = json.dumps(item, sort_keys=True, ensure_ascii=False)
                if key in seen:
                    errors.append(f"{json_pointer(path + [str(index)])} duplicates an earlier item")
                seen.add(key)
        item_schema = schema.get("items")
        if isinstance(item_schema, dict):
            for index, item in enumerate(value):
                errors.extend(validate(item, item_schema, path + [str(index)]))

    if isinstance(value, dict):
        properties = schema.get("properties")
        property_names = set(properties.keys()) if isinstance(properties, dict) else set()
        required = schema.get("required")
        if isinstance(required, list):
            for key in required:
                if isinstance(key, str) and key not in value:
                    errors.append(f"{json_pointer(path + [key])} is required")
        if schema.get("additionalProperties") is False:
            for key in sorted(value):
                if key not in property_names:
                    errors.append(f"{json_pointer(path + [key])} is not allowed")
        if isinstance(properties, dict):
            for key, child_schema in properties.items():
                if key in value and isinstance(child_schema, dict):
                    errors.extend(validate(value[key], child_schema, path + [key]))
    return errors


def find_forbidden_content_keys(value: Any, path: list[str]) -> list[str]:
    errors: list[str] = []
    if isinstance(value, dict):
        for key, child in value.items():
            if key in FORBIDDEN_CONTENT_FIELDS:
                errors.append(f"{json_pointer(path + [key])} must not embed document content")
            errors.extend(find_forbidden_content_keys(child, path + [key]))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            errors.extend(find_forbidden_content_keys(child, path + [str(index)]))
    return errors


def semantic_errors(chunk: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    source = chunk.get("source", {})
    chunk_body = chunk.get("chunk", {})
    index = chunk.get("index", {})
    policy = chunk.get("modelAcquisitionPolicy", {})
    vector_policy = chunk.get("vectorStorePolicy", {})
    watcher_policy = chunk.get("watcherPolicy", {})
    extraction_policy = chunk.get("extractionPolicy", {})
    storage_policy = chunk.get("storagePolicy", {})
    boundary = chunk.get("boundary", {})
    evidence = chunk.get("evidence", {})

    errors.extend(find_forbidden_content_keys(chunk, []))
    if chunk_body.get("storesDocumentContent") is not False:
        errors.append("knowledge-index chunks must store hashes, not document content")
    if index.get("scope") != "per-workspace":
        errors.append("knowledge index scope must be per-workspace")
    if index.get("topKMax") != 10:
        errors.append("topKMax must stay locked at 10 for synchronous query path")
    if index.get("incrementalUpdate") is not True:
        errors.append("chunks must be incremental-update capable")
    if boundary.get("publicEgress") is not False:
        errors.append("knowledge index chunks must not require public egress")
    if boundary.get("serviceMode") not in {"offline", "private"}:
        errors.append("serviceMode must stay offline/private for W3 chunks")
    if boundary.get("localEmbedding") is not True:
        errors.append("embedding must stay local")
    if boundary.get("tenantPolicyRequired") is not True:
        errors.append("tenant policy must be required for indexed chunks")
    if policy.get("bundledByDefault") is not False:
        errors.append("BGE-m3 must not be silently bundled by default")
    if policy.get("fallbackWhenMissing") != "sqlite-fts5":
        errors.append("missing model fallback must stay sqlite-fts5")
    if policy.get("publicEgressByDefault") is not False:
        errors.append("model acquisition must not allow public egress by default")
    if policy.get("runtimeDownloaderImplementation") != "not-started":
        errors.append("runtime model downloader must remain not-started")
    if policy.get("runtimeEmbeddingImplementation") != "not-started":
        errors.append("runtime embedding implementation must remain not-started")
    if policy.get("silentDownloadAllowed") is not False:
        errors.append("silent model download must not be allowed")
    if vector_policy.get("defaultBackend") != "sqlite-fts5":
        errors.append("vector-store default backend must remain sqlite-fts5")
    if vector_policy.get("fallbackBackend") != "sqlite-fts5":
        errors.append("vector-store fallback backend must remain sqlite-fts5")
    if vector_policy.get("lancedbDefaultAllowed") is not False:
        errors.append("lancedb-local must not become the default backend before platform proof")
    if vector_policy.get("lancedbMacosArm64Status") != "pending-runtime-spike":
        errors.append("lancedb macOS arm64 status must remain pending-runtime-spike")
    if vector_policy.get("runtimeVectorStoreImplementation") != "not-started":
        errors.append("runtime vector-store implementation must remain not-started")
    if watcher_policy.get("trigger") != "background-watcher":
        errors.append("watcher trigger must remain background-watcher")
    if watcher_policy.get("debounceMs") != 5000:
        errors.append("watcher debounce must remain 5000ms")
    if watcher_policy.get("largeWorkspaceThresholdFiles") != 10000:
        errors.append("large workspace threshold must remain 10000 files")
    if watcher_policy.get("largeWorkspaceStrategy") != "bounded-watch-plus-polling-fallback":
        errors.append("large workspace watcher strategy must remain bounded-watch-plus-polling-fallback")
    if watcher_policy.get("perFileDescriptorWatch") is not False:
        errors.append("watcher must not use one file descriptor per file")
    if watcher_policy.get("maxOpenFileDescriptors") != 256:
        errors.append("watcher max open file descriptors must remain 256")
    if watcher_policy.get("pollingFallbackIntervalSeconds") != 60:
        errors.append("watcher polling fallback interval must remain 60 seconds")
    if watcher_policy.get("overflowBehavior") != "fail-closed-user-visible":
        errors.append("watcher overflow behavior must remain fail-closed-user-visible")
    if watcher_policy.get("runtimeWatcherImplementation") != "not-started":
        errors.append("runtime watcher implementation must remain not-started")
    if extraction_policy.get("standalonePptParserAllowed") is not False:
        errors.append("PPT/PPTX extraction must not use a standalone parser")
    if extraction_policy.get("runtimeExtractionImplementation") != "not-started":
        errors.append("runtime extraction implementation must remain not-started")
    if storage_policy.get("indexRoot") != "application-data-directory":
        errors.append("knowledge index storage root must stay in application data directory")
    if storage_policy.get("workspacePartition") != "per-workspace":
        errors.append("knowledge index storage partition must stay per-workspace")
    if storage_policy.get("pathIdentity") != "workspace-hash":
        errors.append("knowledge index storage must use workspace-hash path identity")
    if storage_policy.get("colocatedWithUserDocuments") is not False:
        errors.append("index files must not be colocated with user documents")
    if storage_policy.get("syncsWithUserDocuments") is not False:
        errors.append("index files must not sync with user documents by default")
    if storage_policy.get("storesDocumentContent") is not False:
        errors.append("index storage policy must not store document content")
    if storage_policy.get("runtimeStorageImplementation") != "not-started":
        errors.append("runtime storage implementation must remain not-started")

    document_family = extraction_policy.get("documentFamily")
    input_format = extraction_policy.get("inputFormat")
    extraction_path = extraction_policy.get("textExtractionPath")
    if source.get("kind") == "connector":
        if document_family != "connector":
            errors.append("connector chunks must use connector documentFamily")
        if input_format != "connector-markdown":
            errors.append("connector chunks must use connector-markdown inputFormat")
        if extraction_path != "connector-normalized-markdown":
            errors.append("connector chunks must use connector-normalized-markdown extraction path")
        if extraction_policy.get("usesLibreOfficeImportFilter") is not False:
            errors.append("connector chunks must not use LibreOffice import filters")
        if extraction_policy.get("usesDocumentModel") is not False:
            errors.append("connector chunks must not claim document-model extraction")
        if extraction_policy.get("preservesSlideElementRefs") is not False:
            errors.append("connector chunks must not preserve slide element refs")
    elif source.get("kind") == "document":
        expected_formats = {"writer": "odt", "calc": "ods", "impress": "pptx"}
        if document_family not in expected_formats:
            errors.append("document chunks must use writer/calc/impress documentFamily")
        elif input_format != expected_formats[document_family]:
            errors.append(f"{document_family} chunks must use {expected_formats[document_family]} inputFormat")
        if extraction_path != "document-model":
            errors.append("document chunks must extract through the LibreOffice document model")
        if extraction_policy.get("usesLibreOfficeImportFilter") is not True:
            errors.append("document chunks must use LibreOffice import filters")
        if extraction_policy.get("usesDocumentModel") is not True:
            errors.append("document chunks must use the loaded document model")
        if document_family == "impress":
            if input_format != "pptx":
                errors.append("impress W3 fixture must cover PPTX input")
            if extraction_policy.get("preservesSlideElementRefs") is not True:
                errors.append("PPTX extraction must preserve Impress slide element refs")
            if not str(source.get("uri", "")).endswith(".pptx"):
                errors.append("impress PPTX fixture must point at a .pptx source")
        elif extraction_policy.get("preservesSlideElementRefs") is not False:
            errors.append("non-Impress document chunks must not preserve slide element refs")

    mode = index.get("retrievalMode")
    backend = index.get("backend")
    model = index.get("embeddingModel")
    dimensions = index.get("embeddingDimensions")
    if mode == "fts" or backend == "sqlite-fts5":
        if backend != "sqlite-fts5" or model != "none" or dimensions != 0:
            errors.append("fts chunks must use sqlite-fts5 with no embedding vector")
        if (
            vector_policy.get("selectedBackend") != "sqlite-fts5"
            or vector_policy.get("requiresPlatformSmokeBeforeDefault") is not False
        ):
            errors.append("fts chunks must use sqlite-fts5 vector policy without platform-smoke default gate")
        if (
            policy.get("modelFamily") != "none"
            or policy.get("downloadPolicy") != "not-required"
            or policy.get("userConfirmationRequired") is not False
        ):
            errors.append("fts chunks must not require a model download")
    if mode == "hybrid" or backend == "lancedb-local":
        if backend != "lancedb-local" or model != "bge-m3" or dimensions != 1024:
            errors.append("hybrid/vector chunks must use local lancedb + bge-m3 1024 dimensions")
        if (
            vector_policy.get("selectedBackend") != "lancedb-local"
            or vector_policy.get("requiresPlatformSmokeBeforeDefault") is not True
        ):
            errors.append("hybrid/vector chunks must keep lancedb opt-in and require platform smoke before default")
        if (
            policy.get("modelFamily") != "bge-m3"
            or policy.get("downloadPolicy") != "explicit-user-confirmed"
            or policy.get("userConfirmationRequired") is not True
        ):
            errors.append("hybrid/vector chunks must require explicit user-confirmed BGE-m3 acquisition")

    required_evidence = set(evidence.get("required", []))
    if not ROOT_EVIDENCE.issubset(required_evidence):
        errors.append("chunks must require document-snapshot, index-update, and no-public-egress evidence")
    if source.get("kind") == "connector" and "connector-fetch" not in required_evidence:
        errors.append("connector chunks must require connector-fetch evidence")
    if source.get("kind") == "document" and "connector-fetch" in required_evidence:
        errors.append("document chunks must not require connector-fetch evidence")
    return errors


schema = load(schema_path)
if not isinstance(schema, dict):
    die("schema top-level is not an object")

pass_count = 0

if schema.get("required") != EXPECTED_REQUIRED:
    die(f"schema.required drifted: {schema.get('required')!r}")
if schema.get("additionalProperties") is not False:
    die("schema must set top-level additionalProperties:false")
pass_count += 1

props = schema.get("properties", {})
if props.get("id", {}).get("pattern") != "^kbch-[0-9a-f]{16}$":
    die("id pattern drifted")
if props.get("chunk", {}).get("properties", {}).get("storesDocumentContent", {}).get("const") is not False:
    die("storesDocumentContent must be const false")
if props.get("index", {}).get("properties", {}).get("scope", {}).get("const") != "per-workspace":
    die("index scope must be per-workspace")
if props.get("index", {}).get("properties", {}).get("embeddingDimensions", {}).get("enum") != [0, 1024]:
    die("embedding dimensions must lock none=0 and bge-m3=1024")
if props.get("boundary", {}).get("properties", {}).get("publicEgress", {}).get("const") is not False:
    die("publicEgress must be const false")
pass_count += 1

policy_schema = props.get("modelAcquisitionPolicy", {})
policy_required = policy_schema.get("required")
expected_policy_required = [
    "modelFamily",
    "bundledByDefault",
    "downloadPolicy",
    "userConfirmationRequired",
    "fallbackWhenMissing",
    "publicEgressByDefault",
    "runtimeDownloaderImplementation",
    "runtimeEmbeddingImplementation",
    "silentDownloadAllowed",
]
if policy_required != expected_policy_required:
    die(f"modelAcquisitionPolicy.required drifted: {policy_required!r}")
policy_props = policy_schema.get("properties", {})
if policy_props.get("bundledByDefault", {}).get("const") is not False:
    die("model policy must forbid default model bundling")
if policy_props.get("fallbackWhenMissing", {}).get("const") != "sqlite-fts5":
    die("model policy fallback must stay sqlite-fts5")
if policy_props.get("publicEgressByDefault", {}).get("const") is not False:
    die("model policy must forbid public egress by default")
if policy_props.get("runtimeDownloaderImplementation", {}).get("const") != "not-started":
    die("runtime downloader implementation must remain not-started")
if policy_props.get("runtimeEmbeddingImplementation", {}).get("const") != "not-started":
    die("runtime embedding implementation must remain not-started")
if policy_props.get("silentDownloadAllowed", {}).get("const") is not False:
    die("silent model download must be forbidden")
pass_count += 1

vector_schema = props.get("vectorStorePolicy", {})
vector_required = vector_schema.get("required")
expected_vector_required = [
    "defaultBackend",
    "selectedBackend",
    "lancedbDefaultAllowed",
    "lancedbMacosArm64Status",
    "requiresPlatformSmokeBeforeDefault",
    "fallbackBackend",
    "runtimeVectorStoreImplementation",
]
if vector_required != expected_vector_required:
    die(f"vectorStorePolicy.required drifted: {vector_required!r}")
vector_props = vector_schema.get("properties", {})
if vector_props.get("defaultBackend", {}).get("const") != "sqlite-fts5":
    die("vector-store default backend must stay sqlite-fts5")
if vector_props.get("selectedBackend", {}).get("enum") != ["sqlite-fts5", "lancedb-local"]:
    die("vector-store selected backend enum drifted")
if vector_props.get("lancedbDefaultAllowed", {}).get("const") is not False:
    die("lancedb default must stay forbidden until platform proof")
if vector_props.get("lancedbMacosArm64Status", {}).get("const") != "pending-runtime-spike":
    die("lancedb macOS arm64 status must remain pending-runtime-spike")
if vector_props.get("fallbackBackend", {}).get("const") != "sqlite-fts5":
    die("vector-store fallback backend must stay sqlite-fts5")
if vector_props.get("runtimeVectorStoreImplementation", {}).get("const") != "not-started":
    die("runtime vector-store implementation must remain not-started")
pass_count += 1

watcher_schema = props.get("watcherPolicy", {})
watcher_required = watcher_schema.get("required")
expected_watcher_required = [
    "trigger",
    "debounceMs",
    "largeWorkspaceThresholdFiles",
    "largeWorkspaceStrategy",
    "perFileDescriptorWatch",
    "maxOpenFileDescriptors",
    "pollingFallbackIntervalSeconds",
    "overflowBehavior",
    "runtimeWatcherImplementation",
]
if watcher_required != expected_watcher_required:
    die(f"watcherPolicy.required drifted: {watcher_required!r}")
watcher_props = watcher_schema.get("properties", {})
if watcher_props.get("trigger", {}).get("const") != "background-watcher":
    die("watcher trigger must stay background-watcher")
if watcher_props.get("debounceMs", {}).get("const") != 5000:
    die("watcher debounce must stay 5000ms")
if watcher_props.get("largeWorkspaceThresholdFiles", {}).get("const") != 10000:
    die("large workspace threshold must stay 10000 files")
if watcher_props.get("largeWorkspaceStrategy", {}).get("const") != "bounded-watch-plus-polling-fallback":
    die("large workspace strategy must stay bounded-watch-plus-polling-fallback")
if watcher_props.get("perFileDescriptorWatch", {}).get("const") is not False:
    die("per-file descriptor watch must stay forbidden")
if watcher_props.get("maxOpenFileDescriptors", {}).get("const") != 256:
    die("watcher max open file descriptors must stay 256")
if watcher_props.get("pollingFallbackIntervalSeconds", {}).get("const") != 60:
    die("watcher polling fallback interval must stay 60 seconds")
if watcher_props.get("overflowBehavior", {}).get("const") != "fail-closed-user-visible":
    die("watcher overflow behavior must stay fail-closed-user-visible")
if watcher_props.get("runtimeWatcherImplementation", {}).get("const") != "not-started":
    die("runtime watcher implementation must remain not-started")
pass_count += 1

extraction_schema = props.get("extractionPolicy", {})
extraction_required = extraction_schema.get("required")
expected_extraction_required = [
    "documentFamily",
    "inputFormat",
    "textExtractionPath",
    "usesLibreOfficeImportFilter",
    "usesDocumentModel",
    "standalonePptParserAllowed",
    "preservesSlideElementRefs",
    "runtimeExtractionImplementation",
]
if extraction_required != expected_extraction_required:
    die(f"extractionPolicy.required drifted: {extraction_required!r}")
extraction_props = extraction_schema.get("properties", {})
if extraction_props.get("documentFamily", {}).get("enum") != ["writer", "calc", "impress", "connector"]:
    die("extraction documentFamily enum drifted")
if extraction_props.get("inputFormat", {}).get("enum") != ["odt", "ods", "odp", "pptx", "connector-markdown"]:
    die("extraction inputFormat enum drifted")
if extraction_props.get("textExtractionPath", {}).get("enum") != ["document-model", "connector-normalized-markdown"]:
    die("extraction textExtractionPath enum drifted")
if extraction_props.get("standalonePptParserAllowed", {}).get("const") is not False:
    die("standalone PPT parser must stay forbidden")
if extraction_props.get("runtimeExtractionImplementation", {}).get("const") != "not-started":
    die("runtime extraction implementation must remain not-started")
pass_count += 1

storage_schema = props.get("storagePolicy", {})
storage_required = storage_schema.get("required")
expected_storage_required = [
    "indexRoot",
    "workspacePartition",
    "pathIdentity",
    "colocatedWithUserDocuments",
    "syncsWithUserDocuments",
    "storesDocumentContent",
    "runtimeStorageImplementation",
]
if storage_required != expected_storage_required:
    die(f"storagePolicy.required drifted: {storage_required!r}")
storage_props = storage_schema.get("properties", {})
if storage_props.get("indexRoot", {}).get("const") != "application-data-directory":
    die("storage indexRoot must stay application-data-directory")
if storage_props.get("workspacePartition", {}).get("const") != "per-workspace":
    die("storage workspacePartition must stay per-workspace")
if storage_props.get("pathIdentity", {}).get("const") != "workspace-hash":
    die("storage pathIdentity must stay workspace-hash")
if storage_props.get("colocatedWithUserDocuments", {}).get("const") is not False:
    die("storage must not colocate indexes with user documents")
if storage_props.get("syncsWithUserDocuments", {}).get("const") is not False:
    die("storage must not sync indexes with user documents by default")
if storage_props.get("storesDocumentContent", {}).get("const") is not False:
    die("storage policy must not store document content")
if storage_props.get("runtimeStorageImplementation", {}).get("const") != "not-started":
    die("runtime storage implementation must remain not-started")
pass_count += 1

valid_paths = sorted(valid_dir.glob("*.json"))
invalid_paths = sorted(invalid_dir.glob("*.json"))
if {path.name for path in valid_paths} != EXPECTED_VALID_FILES:
    die(f"valid fixture roster drifted: {[path.name for path in valid_paths]!r}")
if {path.name for path in invalid_paths} != EXPECTED_INVALID_FILES:
    die(f"invalid fixture roster drifted: {[path.name for path in invalid_paths]!r}")
pass_count += 1

granularities: set[str] = set()
source_kinds: set[str] = set()
backends: set[str] = set()
document_families: set[str] = set()
input_formats: set[str] = set()
for path in valid_paths:
    entry = load(path)
    if not isinstance(entry, dict):
        die(f"{path} top-level must be object")
    schema_errors = validate(entry, schema, [])
    if schema_errors:
        die(f"{path} violates schema:\n" + "\n".join(schema_errors))
    errors = semantic_errors(entry)
    if errors:
        die(f"{path} violates W3 semantics:\n" + "\n".join(errors))
    granularities.add(entry["chunk"]["granularity"])
    source_kinds.add(entry["source"]["kind"])
    backends.add(entry["index"]["backend"])
    document_families.add(entry["extractionPolicy"]["documentFamily"])
    input_formats.add(entry["extractionPolicy"]["inputFormat"])
pass_count += 1

if granularities != EXPECTED_GRANULARITIES:
    die(f"valid fixtures must cover granularities {sorted(EXPECTED_GRANULARITIES)}, saw {sorted(granularities)}")
if source_kinds != EXPECTED_SOURCE_KINDS:
    die(f"valid fixtures must cover source kinds {sorted(EXPECTED_SOURCE_KINDS)}, saw {sorted(source_kinds)}")
if backends != EXPECTED_BACKENDS:
    die(f"valid fixtures must cover backends {sorted(EXPECTED_BACKENDS)}, saw {sorted(backends)}")
if document_families != EXPECTED_DOCUMENT_FAMILIES:
    die(f"valid fixtures must cover extraction families {sorted(EXPECTED_DOCUMENT_FAMILIES)}, saw {sorted(document_families)}")
if input_formats != EXPECTED_INPUT_FORMATS:
    die(f"valid fixtures must cover input formats {sorted(EXPECTED_INPUT_FORMATS)}, saw {sorted(input_formats)}")
pass_count += 1

for path in invalid_paths:
    entry = load(path)
    if not isinstance(entry, dict):
        die(f"{path} top-level must be object")
    schema_errors = validate(entry, schema, [])
    errors = semantic_errors(entry)
    if not schema_errors and not errors:
        die(f"{path} unexpectedly passed schema+semantic validation")
    if path.name == "ppt-standalone-parser-runtime.json":
        text = path.read_text(encoding="utf-8")
        for needle in [
            "standalone-ppt-parser",
            '"standalonePptParserAllowed": true',
            '"runtimeExtractionImplementation": "started"',
        ]:
            if needle not in text:
                die(f"{path} missing PPT standalone-parser drift marker {needle!r}")
    if path.name == "storage-user-documents-sync-runtime.json":
        text = path.read_text(encoding="utf-8")
        for needle in [
            "user-document-directory",
            '"colocatedWithUserDocuments": true',
            '"syncsWithUserDocuments": true',
            '"runtimeStorageImplementation": "started"',
        ]:
            if needle not in text:
                die(f"{path} missing storage-location drift marker {needle!r}")
pass_count += 1

w3_text = w3_spec.read_text(encoding="utf-8")
w5_text = w5_spec.read_text(encoding="utf-8")
master_text = master_plan.read_text(encoding="utf-8")
policy_text = model_policy_doc.read_text(encoding="utf-8")
vector_policy_text = vector_policy_doc.read_text(encoding="utf-8")
watcher_policy_text = watcher_policy_doc.read_text(encoding="utf-8")
extraction_policy_text = extraction_policy_doc.read_text(encoding="utf-8")
storage_policy_text = storage_policy_doc.read_text(encoding="utf-8")
sweep_text = sweep_path.read_text(encoding="utf-8")
workflow_text = workflow_path.read_text(encoding="utf-8")
for path, text, needles in [
    (w3_spec, w3_text, ["knowledge-index-chunk self-test", "Checks: 12", "BGE-m3", "storesDocumentContent", "per-workspace", "watcher scalability policy", "extraction policy", "storage policy"]),
    (w5_spec, w5_text, ["tests/v3-knowledge-index-chunk-test.sh", "knowledge-index-chunk self-test", "Checks: 12"]),
    (master_plan, master_text, ["knowledge-index-chunk.schema.json", "tests/v3-knowledge-index-chunk-test.sh", "knowledge-index-chunk self-test", "12 checks"]),
    (model_policy_doc, policy_text, ["explicit user confirmation", "SQLite FTS5", "no public egress", "not-started"]),
    (vector_policy_doc, vector_policy_text, ["sqlite-fts5", "lancedb-local", "pending-runtime-spike", "not-started"]),
    (watcher_policy_doc, watcher_policy_text, ["background-watcher", "bounded-watch-plus-polling-fallback", "10000", "not-started"]),
    (extraction_policy_doc, extraction_policy_text, ["LibreOffice import filter", "Impress document model", "standalone PPT parser", "not-started"]),
    (storage_policy_doc, storage_policy_text, ["application-data-directory", "per-workspace", "user document", "not-started"]),
    (sweep_path, sweep_text, ["tests/v3-knowledge-index-chunk-test.sh", "W3 knowledge-index-chunk self-test", "knowledge-index-chunk self-test=12"]),
    (workflow_path, workflow_text, ["docs/schemas/knowledge-index-chunk.schema.json", "bin/v3-eval-sweep.sh --self-test"]),
]:
    for needle in needles:
        if needle not in text:
            die(f"{path} missing {needle!r}")
pass_count += 1

print("Status: passed")
print("Harness: W3 knowledge-index-chunk self-test")
print(f"Schema: {schema_path}")
print(f"Valid fixtures: {len(valid_paths)}")
print(f"Invalid fixtures: {len(invalid_paths)}")
print("Chunk contract: per-workspace, no raw document content, local embedding")
print("Model acquisition: explicit user download, FTS fallback, no public egress")
print("Vector store: sqlite-fts5 default, lancedb opt-in pending macOS arm64 spike")
print("Watcher policy: 5s debounce, bounded watchers, polling fallback for >10k files")
print("Extraction policy: LibreOffice import/document model for PPTX, no standalone parser")
print("Storage policy: app data per-workspace sidecar, no user-document sync")
print("Runtime implementation: deferred until W3 gate")
print(f"Checks: {pass_count}")
PY
