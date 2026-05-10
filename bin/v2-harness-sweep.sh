#!/usr/bin/env bash
set -euo pipefail

# v2-harness-sweep.sh — run all 7 V2 contract harnesses in canonical H1→H7
# order as a single command. Single source of truth for the production-ready
# gate referenced from docs/CLAUDE-NOTES.md, docs/v2-coordinator-handoff-*.md,
# persistent memory v2_entry_pointer, and .github/workflows/v2-contract-harnesses.yml.
#
# Usage:
#   bin/v2-harness-sweep.sh              # H1-H7 only
#   bin/v2-harness-sweep.sh --with-fixtures   # also V1.5+V2 fixture sweep
#   bin/v2-harness-sweep.sh -h | --help
#
# Exit codes:
#   0  all harnesses green
#   !0 first failing harness's exit code (pipeline aborts on first red)

usage() {
    cat <<'EOF'
Usage:
  v2-harness-sweep.sh [--with-fixtures]

Runs the 7 V2 contract harnesses in canonical order:

  H1  tests/v2-provider-evidence-schema-test.sh       (schema ↔ C++ tokens, full)
  H2  tests/v2-plan-baseline-test.sh                  (spec+fixture+ledger+manifest)
  H3  tests/v2-day0-skeleton-test.sh                  (day-0 doc structure)
  H4  tests/v2-async-task-schema-test.sh              (W5 async-task, partial)
  H5  tests/v2-inline-action-request-schema-test.sh   (W4 inline-action, partial)
  H6  tests/v2-schema-manual-coherence-test.sh        (reader's manual fact-block)
  H7  tests/v2-apply-plan-runtime-schema-test.sh      (W3 apply-plan-runtime, partial)

With --with-fixtures the V1.5 + V2 fixture validator also runs:
  bin/intelligent-contract-fixtures.sh

Pass-count baselines (post-L89):
  H1=26  H2=47  H3=26  H4 partial  H5 partial  H6=39  H7 partial
  fixtures: 36 passed / 0 failed across 13 schemas
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

with_fixtures=0
if [[ "${1:-}" == "--with-fixtures" ]]; then
    with_fixtures=1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

banner() {
    printf '\n=== %s ===\n' "$1"
}

banner "H1 provider-evidence (schema ↔ C++ tokens, full)"
bash tests/v2-provider-evidence-schema-test.sh

banner "H2 plan-baseline (spec+fixture+ledger+manifest)"
bash tests/v2-plan-baseline-test.sh

banner "H3 day0-skeleton (W1+W2 file-map ↔ landed doc)"
bash tests/v2-day0-skeleton-test.sh

banner "H4 async-task (W5, partial-enforce)"
bash tests/v2-async-task-schema-test.sh

banner "H5 inline-action-request (W4, partial-enforce)"
bash tests/v2-inline-action-request-schema-test.sh

banner "H6 schema-manual-coherence (reader's manual fact-block)"
bash tests/v2-schema-manual-coherence-test.sh

banner "H7 apply-plan-runtime (W3, partial-enforce)"
bash tests/v2-apply-plan-runtime-schema-test.sh

if [[ $with_fixtures -eq 1 ]]; then
    banner "V1.5 + V2 fixture sweep (intelligent-contract-fixtures)"
    bash bin/intelligent-contract-fixtures.sh
    report="$repo_root/tmp/intelligent-contract-fixtures.md"
    if [[ -f "$report" ]]; then
        passed="$(grep -c '| passed |' "$report" || true)"
        failed="$(grep -c '| failed |' "$report" || true)"
        printf 'fixture report: %s passed / %s failed\n' "$passed" "$failed"
        if [[ "$failed" -ne 0 ]]; then
            printf 'FAIL: fixture report has %s failed rows\n' "$failed" >&2
            exit 1
        fi
        if [[ "$passed" -lt 36 ]]; then
            printf 'FAIL: fixture report has %s < 36 passed rows\n' "$passed" >&2
            exit 1
        fi
    fi
fi

printf '\n=== sweep complete: 7 harnesses passed%s ===\n' \
    "$([[ $with_fixtures -eq 1 ]] && echo ' + V1.5/V2 fixtures' || echo '')"
