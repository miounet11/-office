#!/usr/bin/env bash
# V2 schema reader's-manual coherence regression test (H6).
#
# Owner: test-worker (Mao supervisor scope: tests/**)
# Purpose: Lock the numerical claims each reader's manual makes about
# its schema body (schema_version const, required-key count, total
# property count) against the schema itself. Without this lock, a
# schema body change drifts silently from its manual; the manual
# becomes stale prose that misleads anyone hand-deriving C++.
#
# Each manual carries an HTML-comment fact-block at the top:
#
#   <!-- schema-coherence
#   schema: docs/schemas/<name>.schema.json
#   schema_version_const: <value>
#   required_count: <int>
#   total_props: <int>
#   -->
#
# This test parses each fact-block, opens the named schema, and
# asserts the three numbers match. Any mismatch fails loud with the
# specific drift.
#
# Verification:
#   bash tests/v2-schema-manual-coherence-test.sh
# Expected exit 0 with "Status: passed" on stdout.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

pass_count=0
# Glob-discovered manual roster: every docs/schemas/*.schema.md MUST
# carry a fact-block. Symmetric to H2 check 10 (which locks the
# manual ↔ lane-status reference). New manual files auto-enroll;
# the H2 lock then forces the lane-status mirror in the same PR.
shopt -s nullglob
manuals=( docs/schemas/*.schema.md )
shopt -u nullglob
if (( ${#manuals[@]} == 0 )); then
    fail "no docs/schemas/*.schema.md reader's manuals found"
fi

for manual in "${manuals[@]}"; do
    [[ -f "$manual" ]] || fail "missing manual $manual"
    pass_count=$((pass_count + 1))

    # Parse fact-block. Each line shape: 'key: value' between
    # '<!-- schema-coherence' and '-->'.
    schema=$(awk '/<!-- schema-coherence/,/-->/' "$manual" \
        | grep -E '^schema:' | sed 's/^schema: *//' || true)
    sv_const=$(awk '/<!-- schema-coherence/,/-->/' "$manual" \
        | grep -E '^schema_version_const:' \
        | sed 's/^schema_version_const: *//' || true)
    req_count=$(awk '/<!-- schema-coherence/,/-->/' "$manual" \
        | grep -E '^required_count:' \
        | sed 's/^required_count: *//' || true)
    prop_count=$(awk '/<!-- schema-coherence/,/-->/' "$manual" \
        | grep -E '^total_props:' \
        | sed 's/^total_props: *//' || true)

    [[ -n "$schema" ]]     || fail "$manual fact-block missing 'schema:'"
    [[ -n "$req_count" ]]  || fail "$manual fact-block missing 'required_count:'"
    [[ -n "$prop_count" ]] || fail "$manual fact-block missing 'total_props:'"
    # schema_version_const is optional: some schemas (e.g. provider-evidence)
    # carry no schema_version property. Use literal 'none' or omit the line.
    pass_count=$((pass_count + 1))

    # Reject unknown fact-block keys. Mirrors `additionalProperties: false`
    # at schema-body level — typos like 'requires_count' or 'enum-count'
    # would otherwise be silently ignored, defeating the whole lock.
    # Allowed keys: schema, schema_version_const, required_count,
    # total_props, enum_count.
    fact_block_keys=$(awk '/<!-- schema-coherence/,/-->/' "$manual" \
        | grep -E '^[a-z_]+:' \
        | sed 's/:.*//' \
        | sort -u || true)
    while IFS= read -r k; do
        [[ -z "$k" ]] && continue
        case "$k" in
            schema|schema_version_const|required_count|total_props|enum_count) ;;
            *) fail "$manual fact-block has unknown key '$k' (allowed: schema, schema_version_const, required_count, total_props, enum_count)" ;;
        esac
    done <<< "$fact_block_keys"
    pass_count=$((pass_count + 1))

    [[ -f "$schema" ]] || fail "$manual references missing schema $schema"
    pass_count=$((pass_count + 1))

    # Pull schema facts via python3 (already a hard dep of
    # bin/intelligent-contract-fixtures.sh).
    actual=$(python3 - "$schema" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
sv = s.get("properties", {}).get("schema_version", {}).get("const")
print(f"sv_const={sv if sv is not None else 'none'}")
print(f"required_count={len(s.get('required', []))}")
print(f"total_props={len(s.get('properties', {}))}")
PY
)
    actual_sv=$(echo "$actual" | grep '^sv_const=' | cut -d= -f2-)
    actual_req=$(echo "$actual" | grep '^required_count=' | cut -d= -f2)
    actual_props=$(echo "$actual" | grep '^total_props=' | cut -d= -f2)

    # If sv_const claim absent, treat it as 'none' (asserts schema also lacks one).
    claim_sv="${sv_const:-none}"
    if [[ "$actual_sv" != "$claim_sv" ]]; then
        fail "$manual claims schema_version_const='$claim_sv'; schema body has '$actual_sv'"
    fi
    pass_count=$((pass_count + 1))

    if [[ "$actual_req" != "$req_count" ]]; then
        fail "$manual claims required_count=$req_count; schema body has $actual_req"
    fi
    pass_count=$((pass_count + 1))

    if [[ "$actual_props" != "$prop_count" ]]; then
        fail "$manual claims total_props=$prop_count; schema body has $actual_props"
    fi
    pass_count=$((pass_count + 1))

    # Optional enum_count claims (multiple). Each line shape:
    #   enum_count: <dot-path>=<int>
    # dot-path resolves against the schema root; numeric segments index
    # into JSON arrays (e.g. oneOf.0.action), word segments index
    # 'properties.<word>' implicitly when not literally in the schema.
    enum_lines=$(awk '/<!-- schema-coherence/,/-->/' "$manual" \
        | grep -E '^enum_count:' \
        | sed 's/^enum_count: *//' || true)

    if [[ -n "$enum_lines" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            claim_path="${line%%=*}"
            claim_count="${line##*=}"
            actual_enum_count=$(python3 - "$schema" "$claim_path" <<'PY'
import json, sys
schema_path, dot_path = sys.argv[1], sys.argv[2]
s = json.load(open(schema_path))
node = s
segments = dot_path.split(".")
for seg in segments:
    try:
        if seg.isdigit():
            idx = int(seg)
            if not isinstance(node, list) or idx >= len(node):
                print(f"PATH_NOT_FOUND:{dot_path}:stuck_at:{seg}")
                sys.exit(0)
            node = node[idx]
        elif isinstance(node, dict) and seg in node:
            node = node[seg]
        elif isinstance(node, dict) and "properties" in node and seg in node["properties"]:
            node = node["properties"][seg]
        else:
            print(f"PATH_NOT_FOUND:{dot_path}:stuck_at:{seg}")
            sys.exit(0)
    except (KeyError, IndexError, TypeError):
        print(f"PATH_NOT_FOUND:{dot_path}:stuck_at:{seg}")
        sys.exit(0)
# Resolve to enum array
if isinstance(node, dict) and "enum" in node:
    print(len(node["enum"]))
elif isinstance(node, dict) and "items" in node and isinstance(node["items"], dict) and "enum" in node["items"]:
    print(len(node["items"]["enum"]))
else:
    print(f"NOT_AN_ENUM:{dot_path}")
PY
)
            if [[ "$actual_enum_count" == PATH_NOT_FOUND* ]] || [[ "$actual_enum_count" == NOT_AN_ENUM* ]]; then
                fail "$manual enum_count '$claim_path': $actual_enum_count"
            fi
            if [[ "$actual_enum_count" != "$claim_count" ]]; then
                fail "$manual claims enum_count $claim_path=$claim_count; schema body has $actual_enum_count"
            fi
            pass_count=$((pass_count + 1))
        done <<< "$enum_lines"
    fi
done

printf 'Status: passed\n'
printf 'Checks: %d\n' "$pass_count"
printf 'Manuals locked: %d (glob-discovered docs/schemas/*.schema.md)\n' "${#manuals[@]}"
for m in "${manuals[@]}"; do
    printf '  - %s\n' "$m"
done
