#!/usr/bin/env bash
# V2 plan baseline regression test.
#
# Owner: test-worker (Mao supervisor scope: tests/**)
# Purpose: Lock in the V2 planning artifacts landed in commit 31ff1aada
# (master plan + 5 wave specs) and the schema/fixture baseline they depend on.
# Run this before merging V2 implementation work to catch doc/schema drift early.
#
# Verification:
#   bash tests/v2-plan-baseline-test.sh
# Expected exit 0 with "Status: passed" on stdout.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

pass_count=0
check() {
    local label="$1"
    local path="$2"
    if [[ ! -e "$path" ]]; then
        fail "missing $label at $path"
    fi
    pass_count=$((pass_count + 1))
}

# 1. V2 master plan + wave specs (G1..G6 evidence in goals.json).
check "V2 master plan"        "docs/product/v2-master-plan.md"
check "W1 provider runtime"   "docs/product/v2/w1-provider-runtime-spec.md"
check "W2 cmd palette"        "docs/product/v2/w2-cmd-palette-spec.md"
check "W3 writer apply"       "docs/product/v2/w3-writer-apply-runtime-spec.md"
check "W4 select-to-act"      "docs/product/v2/w4-select-to-act-spec.md"
check "W5 async cowork"       "docs/product/v2/w5-async-cowork-spec.md"

# 2. Schemas referenced by V2 specs must exist on disk.
required_schemas=(
    "docs/schemas/provider-request.schema.json"
    "docs/schemas/evidence-record.schema.json"
    "docs/schemas/apply-plan.schema.json"
    "docs/schemas/document-snapshot.schema.json"
    "docs/schemas/intelligent-diagnostic.schema.json"
)
for s in "${required_schemas[@]}"; do
    check "schema $s" "$s"
done

# 3. Master plan minimum body size (≥ 3000 chars per goal G1 acceptance).
master_plan_size=$(wc -c < docs/product/v2-master-plan.md | tr -d ' ')
if (( master_plan_size < 3000 )); then
    fail "master plan body too small: $master_plan_size bytes (< 3000)"
fi
pass_count=$((pass_count + 1))

# 4. Each wave spec references its master plan + has a Test Strategy section.
for spec in docs/product/v2/w[1-5]-*.md; do
    if ! grep -q "v2-master-plan" "$spec"; then
        fail "$spec does not link back to v2-master-plan"
    fi
    if ! grep -qE "Test Strategy|测试" "$spec"; then
        fail "$spec missing Test Strategy section"
    fi
    pass_count=$((pass_count + 1))
done

# 5. Fixture baseline: 28 fixtures across 12 schemas all pass.
#    18→24→26→28 / 9→10→11→12 reflects V2 additions
#    (provider-request scenarios + provider-evidence + apply-plan-runtime
#     + W5 async-task).
report="$(mktemp -t v2-plan-baseline-fixtures.XXXXXX.md)"
trap 'rm -f "$report"' EXIT

if ! bin/intelligent-contract-fixtures.sh "$report" >/dev/null; then
    cat "$report" >&2
    fail "intelligent-contract-fixtures.sh failed"
fi

if ! grep -Fq "Status: **passed**" "$report"; then
    cat "$report" >&2
    fail "fixture report not in passed state"
fi
if ! grep -Fq "Fixtures checked: 28" "$report"; then
    cat "$report" >&2
    fail "expected 28 fixtures (V1.5 18 + V2 8 + W5 async-task 2)"
fi
if ! grep -Fq "Schemas covered: 12" "$report"; then
    cat "$report" >&2
    fail "expected 12 schemas covered (V1.5 9 + provider-evidence + apply-plan-runtime + async-task)"
fi
pass_count=$((pass_count + 3))

# 6. V2 goal artifact records completion (commit 31ff1aada landed all 7 goals).
if ! grep -Fq '"status": "completed"' .agent/goals/2026-05-08-v2-ai-native/goals.json; then
    fail "V2 goal artifact not marked completed"
fi
pass_count=$((pass_count + 1))

# 7. W4 + W5 specs each carry a Day-0 Entry-Point Plan section.
#    W1/W2/W3 graduated past Day-0 (provider runtime / cmd palette
#    controller / apply-plan validator are all in flight or landed),
#    so their spec bodies no longer need the entry-point block. W4
#    and W5 remain pre-implementation, and the skeleton-landing
#    contract that gates their first commits must stay locked.
for spec in docs/product/v2/w4-*.md docs/product/v2/w5-*.md; do
    if ! grep -qE "^## Day-0 Entry-Point Plan" "$spec"; then
        fail "$spec missing '## Day-0 Entry-Point Plan' section"
    fi
    pass_count=$((pass_count + 1))
done

# 8. W4 + W5 specs carry their enum-lock subsections (L37).
#    The lock tables are the single source of truth Day-0 headers,
#    schema enum lists, and harness drift-lock asserts must agree on.
if ! grep -qE "^### Action enum lock" docs/product/v2/w4-select-to-act-spec.md; then
    fail "w4-select-to-act-spec.md missing '### Action enum lock' subsection (L37)"
fi
pass_count=$((pass_count + 1))

if ! grep -qE "^### Token lock" docs/product/v2/w5-async-cowork-spec.md; then
    fail "w5-async-cowork-spec.md missing '### Token lock' subsection (L37)"
fi
pass_count=$((pass_count + 1))

# 9. lane-status.md ledger entry-count claim matches the actual
#    ledger.jsonl row count (catches the L37→L38 protocol-violation
#    class of drift where ledger grows but lane-status mirror stalls).
ledger_path=".agent/goals/2026-05-08-v2-ai-native/ledger.jsonl"
ledger_rows=$(wc -l < "$ledger_path" | tr -d ' ')
claimed_rows=$(grep -oE 'ledger\.jsonl\` \(([0-9]+) entries\)' \
    docs/product/v2/lane-status.md \
    | grep -oE '[0-9]+' | head -1)
if [[ -z "${claimed_rows:-}" ]]; then
    fail "lane-status.md does not state a ledger entry-count"
fi
if [[ "$claimed_rows" != "$ledger_rows" ]]; then
    fail "lane-status.md claims ledger has $claimed_rows entries; ledger.jsonl has $ledger_rows"
fi
pass_count=$((pass_count + 1))

printf 'Status: passed\n'
printf 'Checks: %d\n' "$pass_count"
printf 'Fixtures: 28 across 12 schemas\n'
printf 'V2 specs: master + 5 wave specs present\n'
