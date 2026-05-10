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
manuals=(
    "docs/schemas/async-task.schema.md"
    "docs/schemas/inline-action-request.schema.md"
    "docs/schemas/apply-plan-runtime.schema.md"
)

for manual in "${manuals[@]}"; do
    [[ -f "$manual" ]] || fail "missing manual $manual"
    pass_count=$((pass_count + 1))

    # Parse fact-block. Each line shape: 'key: value' between
    # '<!-- schema-coherence' and '-->'.
    schema=$(awk '/<!-- schema-coherence/,/-->/' "$manual" \
        | grep -E '^schema:' | sed 's/^schema: *//')
    sv_const=$(awk '/<!-- schema-coherence/,/-->/' "$manual" \
        | grep -E '^schema_version_const:' \
        | sed 's/^schema_version_const: *//')
    req_count=$(awk '/<!-- schema-coherence/,/-->/' "$manual" \
        | grep -E '^required_count:' \
        | sed 's/^required_count: *//')
    prop_count=$(awk '/<!-- schema-coherence/,/-->/' "$manual" \
        | grep -E '^total_props:' \
        | sed 's/^total_props: *//')

    [[ -n "$schema" ]]     || fail "$manual fact-block missing 'schema:'"
    [[ -n "$sv_const" ]]   || fail "$manual fact-block missing 'schema_version_const:'"
    [[ -n "$req_count" ]]  || fail "$manual fact-block missing 'required_count:'"
    [[ -n "$prop_count" ]] || fail "$manual fact-block missing 'total_props:'"
    pass_count=$((pass_count + 1))

    [[ -f "$schema" ]] || fail "$manual references missing schema $schema"
    pass_count=$((pass_count + 1))

    # Pull schema facts via python3 (already a hard dep of
    # bin/intelligent-contract-fixtures.sh).
    actual=$(python3 - "$schema" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
sv = s.get("properties", {}).get("schema_version", {}).get("const")
print(f"sv_const={sv}")
print(f"required_count={len(s.get('required', []))}")
print(f"total_props={len(s.get('properties', {}))}")
PY
)
    actual_sv=$(echo "$actual" | grep '^sv_const=' | cut -d= -f2-)
    actual_req=$(echo "$actual" | grep '^required_count=' | cut -d= -f2)
    actual_props=$(echo "$actual" | grep '^total_props=' | cut -d= -f2)

    if [[ "$actual_sv" != "$sv_const" ]]; then
        fail "$manual claims schema_version_const='$sv_const'; schema body has '$actual_sv'"
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
done

printf 'Status: passed\n'
printf 'Checks: %d\n' "$pass_count"
printf 'Manuals locked: %d (W3 apply-plan-runtime + W4 inline-action-request + W5 async-task)\n' "${#manuals[@]}"
