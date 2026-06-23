#!/usr/bin/env bash
# V3 W3 - knowledge-index-query/result contract self-test.
#
# Contract-first gate for W3 query and result envelopes. It does not start
# the gated IndexManager, FTS/vector backend, embedding pipeline, or query
# API. It locks topK<=10 synchronous queries, local/private retrieval,
# no raw query/snippet storage, result-to-query linkage, and hash-only
# returned chunk references.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

query_schema="docs/schemas/knowledge-index-query.schema.json"
result_schema="docs/schemas/knowledge-index-result.schema.json"
w3_spec="docs/product/v3/w3-knowledge-index-spec.md"
w5_spec="docs/product/v3/w5-eval-harness-spec.md"
master_plan="docs/product/v3-master-plan.md"
sweep="bin/v3-eval-sweep.sh"
workflow=".github/workflows/v3-contract-harnesses.yml"
valid_dir="docs/qa/fixtures/v3/knowledge-index-query-result/valid"
invalid_dir="docs/qa/fixtures/v3/knowledge-index-query-result/invalid"

[[ -f "$query_schema" ]] || fail "missing $query_schema"
[[ -f "$result_schema" ]] || fail "missing $result_schema"
[[ -f "$w3_spec" ]] || fail "missing $w3_spec"
[[ -f "$w5_spec" ]] || fail "missing $w5_spec"
[[ -f "$master_plan" ]] || fail "missing $master_plan"
[[ -f "$sweep" ]] || fail "missing $sweep"
[[ -f "$workflow" ]] || fail "missing $workflow"
[[ -d "$valid_dir" ]] || fail "missing $valid_dir"
[[ -d "$invalid_dir" ]] || fail "missing $invalid_dir"

python3 - "$query_schema" "$result_schema" "$w3_spec" "$w5_spec" "$master_plan" "$sweep" "$workflow" "$valid_dir" "$invalid_dir" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

query_schema_path = Path(sys.argv[1])
result_schema_path = Path(sys.argv[2])
w3_spec = Path(sys.argv[3])
w5_spec = Path(sys.argv[4])
master_plan = Path(sys.argv[5])
sweep_path = Path(sys.argv[6])
workflow_path = Path(sys.argv[7])
valid_dir = Path(sys.argv[8])
invalid_dir = Path(sys.argv[9])

QUERY_REQUIRED = ["id", "schemaVersion", "createdAt", "workspace", "query", "retrieval", "boundary", "evidence"]
RESULT_REQUIRED = ["id", "schemaVersion", "queryId", "createdAt", "workspace", "summary", "chunks", "boundary", "evidence"]
EXPECTED_VALID_FILES = {
    "keyword-document-fts.json",
    "hybrid-connector-private.json",
    "semantic-local-hybrid.json",
}
EXPECTED_INVALID_FILES = {
    "query-stores-raw-text.json",
    "result-stores-snippet.json",
    "public-egress-query.json",
}
EXPECTED_INTENTS = {"keyword", "semantic", "hybrid"}
EXPECTED_MODES = {"fts", "hybrid"}
EXPECTED_SOURCE_KINDS = {"document", "connector"}
FORBIDDEN_CONTENT_FIELDS = {
    "queryText",
    "snippetText",
    "text",
    "content",
    "rawText",
    "body",
    "documentText",
    "contentText",
}
QUERY_EVIDENCE = {"policy-decision", "no-public-egress", "kb-query"}
RESULT_EVIDENCE = {"kb-query", "chunk-read", "no-public-egress"}


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
                errors.append(f"{json_pointer(path + [key])} must not embed query/result content")
            errors.extend(find_forbidden_content_keys(child, path + [key]))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            errors.extend(find_forbidden_content_keys(child, path + [str(index)]))
    return errors


def semantic_errors(pair: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    query = pair.get("query", {})
    result = pair.get("result", {})
    q_body = query.get("query", {})
    retrieval = query.get("retrieval", {})
    q_boundary = query.get("boundary", {})
    r_summary = result.get("summary", {})
    r_boundary = result.get("boundary", {})
    chunks = result.get("chunks", [])

    errors.extend(find_forbidden_content_keys(pair, []))
    if q_body.get("storesQueryText") is not False:
        errors.append("queries must store textHash, not raw query text")
    if r_summary.get("storesDocumentContent") is not False or r_boundary.get("storesDocumentContent") is not False:
        errors.append("results must store hashes, not document content")
    if q_boundary.get("publicEgress") is not False or r_boundary.get("publicEgress") is not False:
        errors.append("query/result must not require public egress")
    if q_boundary.get("serviceMode") not in {"offline", "private"}:
        errors.append("query serviceMode must stay offline/private")
    if q_boundary.get("localEmbedding") is not True:
        errors.append("query embedding must stay local")
    if q_boundary.get("tenantPolicyRequired") is not True:
        errors.append("query must require tenant policy")
    if result.get("queryId") != query.get("id"):
        errors.append("result.queryId must match query.id")
    if result.get("workspace") != query.get("workspace"):
        errors.append("query/result workspace mismatch")
    if r_summary.get("retrievalMode") != retrieval.get("mode"):
        errors.append("result retrievalMode must match query retrieval.mode")
    if r_summary.get("resultCount") != len(chunks):
        errors.append("summary.resultCount must equal chunks length")
    if isinstance(q_body.get("topK"), int) and isinstance(r_summary.get("resultCount"), int):
        if r_summary["resultCount"] > q_body["topK"]:
            errors.append("resultCount must not exceed query.topK")
    if isinstance(retrieval.get("timeoutMs"), int) and isinstance(r_summary.get("latencyMs"), int):
        if r_summary["latencyMs"] > retrieval["timeoutMs"]:
            errors.append("result latencyMs must not exceed query timeoutMs")

    mode = retrieval.get("mode")
    backends = set(retrieval.get("backends", []))
    rerank = retrieval.get("rerank")
    if mode == "fts":
        if backends != {"sqlite-fts5"} or rerank != "none":
            errors.append("fts query must use only sqlite-fts5 and no rerank")
    if mode == "hybrid":
        if not {"sqlite-fts5", "lancedb-local"}.issubset(backends) or rerank != "bge-m3":
            errors.append("hybrid query must use sqlite-fts5 + lancedb-local with bge-m3 rerank")

    if not QUERY_EVIDENCE.issubset(set(query.get("evidence", {}).get("required", []))):
        errors.append("query evidence requirements drifted")
    if not RESULT_EVIDENCE.issubset(set(result.get("evidence", {}).get("required", []))):
        errors.append("result evidence requirements drifted")

    query_source_kinds = set(retrieval.get("sourceKinds", []))
    seen_ranks: set[int] = set()
    for offset, chunk in enumerate(chunks, start=1):
        rank = chunk.get("rank")
        if rank != offset:
            errors.append(f"chunk rank must be sequential: expected {offset}, saw {rank!r}")
        if rank in seen_ranks:
            errors.append(f"duplicate chunk rank {rank}")
        seen_ranks.add(rank)
        if chunk.get("sourceKind") not in query_source_kinds:
            errors.append(f"chunk sourceKind {chunk.get('sourceKind')!r} not allowed by query sourceKinds")
    return errors


query_schema = load(query_schema_path)
result_schema = load(result_schema_path)
if not isinstance(query_schema, dict) or not isinstance(result_schema, dict):
    die("schema top-level must be objects")

pass_count = 0

if query_schema.get("required") != QUERY_REQUIRED:
    die(f"query schema.required drifted: {query_schema.get('required')!r}")
if query_schema.get("additionalProperties") is not False:
    die("query schema must set top-level additionalProperties:false")
q_props = query_schema.get("properties", {})
if q_props.get("query", {}).get("properties", {}).get("topK", {}).get("maximum") != 10:
    die("query.topK maximum must be 10")
if q_props.get("query", {}).get("properties", {}).get("storesQueryText", {}).get("const") is not False:
    die("storesQueryText must be const false")
if q_props.get("boundary", {}).get("properties", {}).get("publicEgress", {}).get("const") is not False:
    die("query publicEgress must be const false")
pass_count += 1

if result_schema.get("required") != RESULT_REQUIRED:
    die(f"result schema.required drifted: {result_schema.get('required')!r}")
if result_schema.get("additionalProperties") is not False:
    die("result schema must set top-level additionalProperties:false")
r_props = result_schema.get("properties", {})
if r_props.get("summary", {}).get("properties", {}).get("resultCount", {}).get("maximum") != 10:
    die("summary.resultCount maximum must be 10")
if r_props.get("summary", {}).get("properties", {}).get("latencyMs", {}).get("maximum") != 500:
    die("summary.latencyMs maximum must be 500")
if r_props.get("boundary", {}).get("properties", {}).get("storesDocumentContent", {}).get("const") is not False:
    die("result storesDocumentContent must be const false")
pass_count += 1

valid_paths = sorted(valid_dir.glob("*.json"))
invalid_paths = sorted(invalid_dir.glob("*.json"))
if {path.name for path in valid_paths} != EXPECTED_VALID_FILES:
    die(f"valid fixture roster drifted: {[path.name for path in valid_paths]!r}")
if {path.name for path in invalid_paths} != EXPECTED_INVALID_FILES:
    die(f"invalid fixture roster drifted: {[path.name for path in invalid_paths]!r}")
pass_count += 1

intents: set[str] = set()
modes: set[str] = set()
source_kinds: set[str] = set()
for path in valid_paths:
    pair = load(path)
    if not isinstance(pair, dict) or not isinstance(pair.get("query"), dict) or not isinstance(pair.get("result"), dict):
        die(f"{path} must contain query and result objects")
    errors = validate(pair["query"], query_schema, ["query"]) + validate(pair["result"], result_schema, ["result"])
    if errors:
        die(f"{path} violates schema:\n" + "\n".join(errors))
    semantic = semantic_errors(pair)
    if semantic:
        die(f"{path} violates W3 query/result semantics:\n" + "\n".join(semantic))
    intents.add(pair["query"]["query"]["intent"])
    modes.add(pair["query"]["retrieval"]["mode"])
    source_kinds.update(pair["query"]["retrieval"]["sourceKinds"])
pass_count += 1

if intents != EXPECTED_INTENTS:
    die(f"valid fixtures must cover intents {sorted(EXPECTED_INTENTS)}, saw {sorted(intents)}")
if modes != EXPECTED_MODES:
    die(f"valid fixtures must cover modes {sorted(EXPECTED_MODES)}, saw {sorted(modes)}")
if source_kinds != EXPECTED_SOURCE_KINDS:
    die(f"valid fixtures must cover sourceKinds {sorted(EXPECTED_SOURCE_KINDS)}, saw {sorted(source_kinds)}")
pass_count += 1

for path in invalid_paths:
    pair = load(path)
    if not isinstance(pair, dict) or not isinstance(pair.get("query"), dict) or not isinstance(pair.get("result"), dict):
        die(f"{path} must contain query and result objects")
    schema_errors = validate(pair["query"], query_schema, ["query"]) + validate(pair["result"], result_schema, ["result"])
    semantic = semantic_errors(pair)
    if not schema_errors and not semantic:
        die(f"{path} unexpectedly passed schema+semantic validation")
pass_count += 1

for path in valid_paths:
    pair = load(path)
    if pair["result"]["queryId"] != pair["query"]["id"]:
        die(f"{path} query/result link drifted")
    if pair["result"]["summary"]["resultCount"] != len(pair["result"]["chunks"]):
        die(f"{path} resultCount drifted from chunks length")
pass_count += 1

w3_text = w3_spec.read_text(encoding="utf-8")
w5_text = w5_spec.read_text(encoding="utf-8")
master_text = master_plan.read_text(encoding="utf-8")
sweep_text = sweep_path.read_text(encoding="utf-8")
workflow_text = workflow_path.read_text(encoding="utf-8")
for path, text, needles in [
    (w3_spec, w3_text, ["knowledge-index-query-result self-test", "Checks: 8", "topK<=10", "storesQueryText", "snippetHash"]),
    (w5_spec, w5_text, ["tests/v3-knowledge-index-query-result-test.sh", "knowledge-index-query-result self-test"]),
    (master_plan, master_text, ["knowledge-index-query.schema.json", "knowledge-index-result.schema.json", "tests/v3-knowledge-index-query-result-test.sh"]),
    (sweep_path, sweep_text, ["tests/v3-knowledge-index-query-result-test.sh", "W3 knowledge-index-query-result self-test"]),
    (workflow_path, workflow_text, ["docs/schemas/knowledge-index-query.schema.json", "docs/schemas/knowledge-index-result.schema.json", "bin/v3-eval-sweep.sh --self-test"]),
]:
    for needle in needles:
        if needle not in text:
            die(f"{path} missing {needle!r}")
pass_count += 1

print("Status: passed")
print("Harness: W3 knowledge-index-query-result self-test")
print(f"Query schema: {query_schema_path}")
print(f"Result schema: {result_schema_path}")
print(f"Valid fixtures: {len(valid_paths)}")
print(f"Invalid fixtures: {len(invalid_paths)}")
print("Query/result contract: topK<=10, hash-only snippets, no public egress")
print("Runtime implementation: deferred until W3 gate")
print(f"Checks: {pass_count}")
PY
