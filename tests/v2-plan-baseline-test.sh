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

# 5. Fixture baseline: 36 fixtures across 13 schemas all pass.
#    18→24→26→28→29→30→34→36 / 9→10→11→12→13 reflects V2 additions
#    (provider-request scenarios + provider-evidence + apply-plan-runtime
#     + W5 async-task valid/invalid + W5 async-task terminal-failed + cancelled
#     + W3 apply-plan-runtime utf8 multi-codepoint boundary
#     + W4 inline-action-request 4 fixtures + writer-custom).
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
if ! grep -Fq "Fixtures checked: 36" "$report"; then
    cat "$report" >&2
    fail "expected 36 fixtures (V1.5 18 + V2 8 + W5 async-task 4 [valid+invalid+terminal-failed+cancelled] + W3 utf8 boundary 1 + W4 inline-action 5 [valid+invalid+calc+impress+writer-custom])"
fi
if ! grep -Fq "Schemas covered: 13" "$report"; then
    cat "$report" >&2
    fail "expected 13 schemas covered (V1.5 9 + provider-evidence + apply-plan-runtime + async-task + inline-action-request)"
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

# 10. lane-status.md §"Schemas (V2)" reader's-manual references match
#     the on-disk reader's-manual roster bidirectionally:
#       (a) every docs/schemas/*.schema.md is referenced by at least
#           one "Reader's manual: ..." line in lane-status;
#       (b) every "Reader's manual: <path>" line in lane-status
#           points at a file that actually exists.
#     Catches the drift class where someone adds a 5th reader's
#     manual but forgets to mirror it in lane-status (or removes a
#     manual but leaves a stale reference). Symmetric to the H6 lock
#     which already verifies fact-block ↔ schema-body coherence.
shopt -s nullglob
manuals_on_disk=( docs/schemas/*.schema.md )
shopt -u nullglob
for m in "${manuals_on_disk[@]}"; do
    if ! grep -Fq "Reader's manual: \`$m\`" docs/product/v2/lane-status.md; then
        fail "lane-status.md missing reader's-manual reference for $m"
    fi
    pass_count=$((pass_count + 1))
done
referenced_manuals=$(grep -oE "Reader's manual: \`docs/schemas/[a-z0-9-]+\.schema\.md\`" \
    docs/product/v2/lane-status.md \
    | sed -E "s/Reader's manual: \`([^\`]+)\`/\1/" || true)
while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    if [[ ! -f "$ref" ]]; then
        fail "lane-status.md references missing reader's manual: $ref"
    fi
    pass_count=$((pass_count + 1))
done <<< "$referenced_manuals"

# 11. Every `tests/v2-*.sh` harness path referenced from
#     lane-status.md must exist on disk. Catches the class of
#     drift where a harness gets renamed or removed but
#     lane-status keeps claiming it exists. Complements check 10
#     (which does the same for reader's manuals).
referenced_harnesses=$(grep -oE '`tests/v2-[a-z0-9-]+\.sh`' \
    docs/product/v2/lane-status.md \
    | sed -E 's/`([^`]+)`/\1/' \
    | sort -u || true)
while IFS= read -r h; do
    [[ -z "$h" ]] && continue
    if [[ ! -f "$h" ]]; then
        fail "lane-status.md references missing harness: $h"
    fi
    if [[ ! -x "$h" ]]; then
        fail "lane-status.md references non-executable harness: $h (expected 0755 mode bit)"
    fi
    pass_count=$((pass_count + 1))
done <<< "$referenced_harnesses"

# 12. ledger.jsonl row-shape lock. Every row MUST be valid JSON with
#     EXACTLY the canonical keys: event, goal_id, notes, ts. Catches
#     the L65-class drift where a new entry quietly drops `event` or
#     adds ad-hoc fields (e.g. `turn`, `artifacts`, `status`,
#     `v2_harnesses`) — append-only ledgers depend on uniform shape
#     for downstream tooling and historical greppability.
shape_violations=$(python3 - "$ledger_path" <<'PY'
import json, sys
path = sys.argv[1]
expected = ('event', 'goal_id', 'notes', 'ts')
violations = []
with open(path, encoding='utf-8') as f:
    for i, line in enumerate(f, 1):
        line = line.rstrip('\n')
        if not line.strip():
            continue
        try:
            d = json.loads(line)
        except json.JSONDecodeError as e:
            violations.append(f'row {i}: invalid JSON ({e})')
            continue
        keys = tuple(sorted(d.keys()))
        if keys != expected:
            violations.append(
                f'row {i}: keys {keys} != canonical {expected}'
            )
for v in violations:
    print(v)
PY
)
if [[ -n "$shape_violations" ]]; then
    printf 'FAIL: ledger.jsonl row-shape violations:\n%s\n' \
        "$shape_violations" >&2
    exit 1
fi
pass_count=$((pass_count + 1))

# 13. Pass-count baseline cross-doc lock. The H_N=count string is
#     replicated in 3 in-repo places (CLAUDE-NOTES = canonical,
#     coordinator handoff doc, bin/v2-harness-sweep.sh header).
#     L66 required touching all 3 for one H2 bump (41 -> 42); this
#     check enforces the mutual consistency. Memory dir lives outside
#     the repo and is excluded — keep it manually mirrored.
baseline_violations=$(python3 - <<'PY'
import re, sys

def extract(path, pattern):
    with open(path, encoding='utf-8') as f:
        text = f.read()
    m = re.search(pattern, text)
    return m.group(1).strip() if m else None

canonical_path = 'docs/CLAUDE-NOTES.md'
# canonical line: "H1=26 / H2=42 / H3=26 / H4 partial / H5 partial / H6=39 / H7 partial."
canonical = extract(
    canonical_path,
    r'(H1=\d+\s*/\s*H2=\d+\s*/\s*H3=\d+\s*/\s*H4 partial\s*/\s*H5 partial\s*/\s*H6=\d+\s*/\s*H7 partial)',
)
if not canonical:
    print(f'canonical baseline not found in {canonical_path}')
    sys.exit(0)

# Normalize whitespace for comparison
def norm(s):
    return re.sub(r'\s+', ' ', s).strip()

canonical_n = norm(canonical)

mirrors = [
    ('docs/v2-coordinator-handoff-2026-05-10.md',
     r'(H1=\d+\s*/\s*H2=\d+\s*/\s*H3=\d+\s*/\s*H4 partial\s*/\s*H5 partial\s*/\s*H6=\d+\s*/\s*H7 partial)'),
    ('bin/v2-harness-sweep.sh',
     r'(H1=\d+\s+H2=\d+\s+H3=\d+\s+H4 partial\s+H5 partial\s+H6=\d+\s+H7 partial)'),
]
violations = []
for path, pat in mirrors:
    v = extract(path, pat)
    if not v:
        violations.append(f'{path}: baseline string not found')
        continue
    # sweep-script uses spaces, canonical uses ' / '; normalize separators
    vn = re.sub(r'\s*/\s*', ' ', norm(v))
    cn = re.sub(r'\s*/\s*', ' ', canonical_n)
    if vn != cn:
        violations.append(
            f'{path}: baseline {v!r} != canonical {canonical!r}'
        )
for v in violations:
    print(v)
PY
)
if [[ -n "$baseline_violations" ]]; then
    printf 'FAIL: pass-count baseline cross-doc drift:\n%s\n' \
        "$baseline_violations" >&2
    exit 1
fi
pass_count=$((pass_count + 1))

printf 'Status: passed\n'
printf 'Checks: %d\n' "$pass_count"
printf 'Fixtures: 36 across 13 schemas\n'
printf 'V2 specs: master + 5 wave specs present\n'
