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

# 5. Fixture baseline: 40 fixtures across 13 schemas all pass.
#    18→24→26→28→29→30→34→36→39→40 / 9→10→11→12→13 reflects V2 additions
#    (provider-request scenarios + provider-evidence + apply-plan-runtime
#     + W5 async-task valid/invalid + W5 async-task terminal-failed + cancelled
#     + W5 async-task pending/running/applied (L95 state-enum lifecycle coverage)
#     + W3 apply-plan-runtime utf8 multi-codepoint boundary
#     + W4 inline-action-request 4 fixtures + writer-custom
#     + W3 Day-1b apply-plan-runtime.writer-runtime runtime example).
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
if ! grep -Fq "Fixtures checked: 40" "$report"; then
    cat "$report" >&2
    fail "expected 40 fixtures (V1.5 18 + V2 8 + W5 async-task 7 [valid+invalid+terminal-failed+cancelled+pending+running+applied] + W3 utf8 boundary 1 + W4 inline-action 5 [valid+invalid+calc+impress+writer-custom] + W3 Day-1b writer-runtime 1)"
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
		# canonical line: "H1=26 / H2=50 / H3=26 / H4 full / H5 full / H6=39 / H7 full / H8=14 / H9=251 / H10=13."
# token after H4/H5/H7 is "full" or "partial" (auto-promotion)
canonical = extract(
    canonical_path,
    r'(H1=\d+\s*/\s*H2=\d+\s*/\s*H3=\d+\s*/\s*H4 (?:full|partial)\s*/\s*H5 (?:full|partial)\s*/\s*H6=\d+\s*/\s*H7 (?:full|partial)\s*/\s*H8=\d+\s*/\s*H9=\d+\s*/\s*H10=\d+)',
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
     r'(H1=\d+\s*/\s*H2=\d+\s*/\s*H3=\d+\s*/\s*H4 (?:full|partial)\s*/\s*H5 (?:full|partial)\s*/\s*H6=\d+\s*/\s*H7 (?:full|partial)\s*/\s*H8=\d+\s*/\s*H9=\d+\s*/\s*H10=\d+)'),
    ('bin/v2-harness-sweep.sh',
     r'(H1=\d+\s+H2=\d+\s+H3=\d+\s+H4 (?:full|partial)\s+H5 (?:full|partial)\s+H6=\d+\s+H7 (?:full|partial)\s+H8=\d+\s+H9=\d+\s+H10=\d+)'),
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

# 14. bin/v2-harness-sweep.sh executable-bit lock. The sweep script
#     is referenced from CLAUDE-NOTES + handoff doc + CI workflow as
#     the one-shot invocation; losing the 0755 mode bit would make
#     all 3 call sites fail with a cryptic "bash: permission denied"
#     without any single H2 check flagging it. Parallel to check 11
#     which does the same for tests/v2-*.sh paths.
sweep_script="bin/v2-harness-sweep.sh"
if [[ ! -f "$sweep_script" ]]; then
    fail "missing $sweep_script (referenced from CLAUDE-NOTES + handoff)"
fi
if [[ ! -x "$sweep_script" ]]; then
    fail "$sweep_script missing 0755 mode bit (referenced by CLAUDE-NOTES + handoff + CI)"
fi
pass_count=$((pass_count + 1))

# 15. Sweep enumeration ↔ disk parity. Every `tests/v2-*.sh` file on
#     disk MUST appear as a `bash tests/v2-*.sh` invocation line in
#     bin/v2-harness-sweep.sh, and vice versa. Catches the drift class
#     where a new V2 harness lands but no one updates the sweep script
#     — CI would then run the new harness directly (paths-filter
#     covers tests/v2-*.sh post-L62) but the local one-shot sweep
#     would silently skip it, producing false-green local runs while
#     CI catches regressions only at PR time. Parallel to check 11 +
#     check 14 (both verify that artifacts referenced from elsewhere
#     actually exist on disk); this check verifies the inverse —
#     artifacts on disk are referenced by the canonical entry point.
disk_harnesses=$(find tests -maxdepth 1 -type f -name 'v2-*.sh' \
    | sort -u)
sweep_harnesses=$(grep -oE 'tests/v2-[a-z0-9-]+\.sh' "$sweep_script" \
    | sort -u)
# Compare by canonical relative paths.
disk_only=$(comm -23 \
    <(printf '%s\n' "$disk_harnesses") \
    <(printf '%s\n' "$sweep_harnesses"))
sweep_only=$(comm -13 \
    <(printf '%s\n' "$disk_harnesses") \
    <(printf '%s\n' "$sweep_harnesses"))
if [[ -n "$disk_only" ]]; then
    fail "harnesses on disk but not in $sweep_script (sweep would skip them):
$disk_only"
fi
if [[ -n "$sweep_only" ]]; then
    fail "harnesses referenced in $sweep_script but missing from disk:
$sweep_only"
fi
pass_count=$((pass_count + 1))

# 16. Ledger ts well-formedness + UTC-normalized monotonicity. Every
#     row's `ts` field MUST parse as ISO-8601 with explicit timezone
#     offset, and the resulting UTC instants MUST be non-decreasing
#     across the file. Born from the L83 audit: rows 1-4 use +0800
#     while rows 5-N use +0000; naive string comparison flagged a
#     false NON-MONOTONIC at row 5 (raw "+0800" string > "+0000")
#     even though UTC instants were in order. The ledger row-shape
#     lock (check 12) only validates the JSON keys; this check
#     validates the ts VALUE. Drift class caught: future rows with
#     malformed ts ("2026-05-12" without time, missing tz, "Z"
#     suffix without parser support, or wall-clock backward edits
#     intended to retroactively reorder events). Parallel to
#     check 12 (row-shape) — together they lock both schema and
#     content of the canonical 4-key ledger envelope.
ledger="$ledger_path"
prev_utc=""
prev_n=0
n=0
while IFS= read -r line; do
    n=$((n + 1))
    ts=$(printf '%s' "$line" | jq -r '.ts')
    # Require explicit numeric tz offset (+HHMM or -HHMM); reject
    # bare "Z" suffix and tz-less strings — both have bitten before.
    if [[ ! "$ts" =~ [+-][0-9]{4}$ ]]; then
        fail "ledger row $n ts=\"$ts\" missing explicit numeric tz offset (+HHMM/-HHMM); 'Z' or naked datetime is rejected — see CLAUDE-NOTES §Ledger row shape"
    fi
    # Parse to epoch seconds via BSD date -j -f (portable on macOS;
    # GNU date uses different flags but this harness only runs in the
    # configured BUILDDIR which is macOS).
    epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$ts" +%s 2>/dev/null || true)
    if [[ -z "$epoch" ]]; then
        fail "ledger row $n ts=\"$ts\" failed BSD date parse (expected %Y-%m-%dT%H:%M:%S%z)"
    fi
    if [[ -n "$prev_utc" && "$epoch" -lt "$prev_utc" ]]; then
        fail "ledger row $n ts=\"$ts\" (UTC epoch $epoch) is BEFORE row $prev_n (epoch $prev_utc) — append-only timeline must be UTC-monotonic non-decreasing"
    fi
    prev_utc="$epoch"
    prev_n=$n
done < "$ledger"
pass_count=$((pass_count + 1))

# 17. L-anchor cross-doc cadence lock. Three sentinel docs each carry
#     a current-state L-number anchor that, when out of sync, has
#     repeatedly produced "where are we right now?" confusion (drift
#     class fixed manually multiple times across L81/L82/L85/L86/L88 —
#     see CLAUDE-NOTES §"V2 consistency locking architecture"; that
#     section header carries its own (post-L<N>) marker which moves
#     with each tier-4 extension and is intentionally NOT cited here
#     to avoid the meta-drift of a self-referential stale anchor in
#     this very comment). Sentinels:
#       (a) docs/v2-coordinator-handoff-2026-05-10.md title `(L<N>)`
#       (b) docs/CLAUDE-NOTES.md handoff anchor `refreshed ... / L<N>`
#       (c) docs/product/v2/STATUS-2026-05-11.md latest "## <N>." section
#           tail "L<X>→L<Y>" — Y is the section's covered tail
#     Invariant: max(a,b,c) - min(a,b,c) MUST be ≤ 3. Tolerance 3 is the
#     measured natural cadence (handoff lags ~4 commits per L82 finding;
#     anchors going more than 3 apart means at least one doc was forgotten
#     across a full cluster). Tighter (≤ 1 or ≤ 2) would force every
#     reversible commit to touch all three docs, which the cadence pattern
#     showed is unrealistic; looser (≤ 5+) lets a whole STATUS section
#     append cycle elapse before catching the drift, which is what L81/L86
#     had to clean up manually. ≤ 3 catches the divergence at the same
#     ~4-commit interval handoff refreshes naturally happen anyway.
handoff_doc="docs/v2-coordinator-handoff-2026-05-10.md"
notes_doc="docs/CLAUDE-NOTES.md"
status_doc="docs/product/v2/STATUS-2026-05-11.md"
handoff_l=$(grep -oE '\(L[0-9]+\)' "$handoff_doc" | head -1 | grep -oE '[0-9]+' || true)
notes_l=$(grep -oE 'refreshed [0-9-]+ / L[0-9]+' "$notes_doc" | head -1 | grep -oE '[0-9]+$' || true)
# STATUS sentinel: scan all "L<X>→L<Y>" range markers in section headings
# and take the max Y across them (= covered-tail of the latest delta section).
status_l=$(grep -oE 'L[0-9]+→L[0-9]+|L[0-9]+ ?→ ?L[0-9]+' "$status_doc" \
    | grep -oE 'L[0-9]+' | grep -oE '[0-9]+' \
    | sort -n | tail -1 || true)
if [[ -z "$handoff_l" || -z "$notes_l" || -z "$status_l" ]]; then
    fail "L-anchor extraction failed: handoff=$handoff_l notes=$notes_l status=$status_l (one of the 3 sentinel patterns is missing — check pattern stability in $handoff_doc / $notes_doc / $status_doc)"
fi
max_l=$handoff_l
min_l=$handoff_l
for l in "$notes_l" "$status_l"; do
    if (( l > max_l )); then max_l=$l; fi
    if (( l < min_l )); then min_l=$l; fi
done
gap=$((max_l - min_l))
if (( gap > 3 )); then
    fail "L-anchor cadence drift exceeded 3: handoff=L$handoff_l notes=L$notes_l status=L$status_l (max=$max_l min=$min_l gap=$gap). Refresh the lagging doc(s) to within 3 of the leader before merging — this is the drift class L81/L86/L88 had to clean up manually."
fi
pass_count=$((pass_count + 1))

printf 'Status: passed\n'
printf 'Checks: %d\n' "$pass_count"
printf 'Fixtures: 40 across 13 schemas\n'
printf 'V2 specs: master + 5 wave specs present\n'
