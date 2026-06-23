#!/usr/bin/env bash
set -euo pipefail

# v2-harness-sweep.sh — run all V2 contract/build-hardening harnesses in canonical H1→H11
# order as a single command. Single source of truth for the production-ready
# gate referenced from docs/CLAUDE-NOTES.md, docs/v2-coordinator-handoff-*.md,
# persistent memory v2_entry_pointer, and .github/workflows/v2-contract-harnesses.yml.
#
# Usage:
#   bin/v2-harness-sweep.sh              # H1-H11 only
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

Runs the 11 V2 contract/build-hardening harnesses in canonical order:

  H1  tests/v2-provider-evidence-schema-test.sh       (schema ↔ C++ tokens, full)
  H2  tests/v2-plan-baseline-test.sh                  (spec+fixture+ledger+manifest)
  H3  tests/v2-day0-skeleton-test.sh                  (day-0 doc structure)
  H4  tests/v2-async-task-schema-test.sh              (W5 async-task, full-enforce)
  H5  tests/v2-inline-action-request-schema-test.sh   (W4 inline-action, full-enforce)
  H6  tests/v2-schema-manual-coherence-test.sh        (reader's manual fact-block)
  H7  tests/v2-apply-plan-runtime-schema-test.sh      (W3 apply-plan-runtime, full-enforce)
  H8  tests/v2-product-entry-smoke-test.sh            (W2/W4/W5 app-bundle entrypoints)
  H9  tests/v2-worker-ui-lifecycle-test.sh            (W5 worker-thread/UI/visible-review/apply lifecycle evidence)
  H10 tests/v2-source-archive-boundary-test.sh        (SRCDIR dirty path archive boundary)
  H11 tests/v2-pkg-config-wrapper-test.sh             (pkg-config wrapper stdout/stderr hardening)

With --with-fixtures the V1.5 + V2 fixture validator also runs:
  bin/intelligent-contract-fixtures.sh

			Pass-count baselines (post-L176 + build hardening):
			  H1=26  H2=50  H3=26  H4 full  H5 full  H6=39  H7 full  H8=14  H9=278  H10=26  H11=3
  fixtures: 40 passed / 0 failed across 13 schemas
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

banner "H4 async-task (W5, full-enforce)"
bash tests/v2-async-task-schema-test.sh

banner "H5 inline-action-request (W4, full-enforce)"
bash tests/v2-inline-action-request-schema-test.sh

banner "H6 schema-manual-coherence (reader's manual fact-block)"
bash tests/v2-schema-manual-coherence-test.sh

banner "H7 apply-plan-runtime (W3, full-enforce)"
bash tests/v2-apply-plan-runtime-schema-test.sh

banner "H8 product-entry smoke (W2/W4/W5 app bundle)"
bash tests/v2-product-entry-smoke-test.sh

banner "H9 worker/UI/review-open lifecycle (W5 scheduler evidence)"
bash tests/v2-worker-ui-lifecycle-test.sh

banner "H10 source-archive boundary (SRCDIR dirty path classification)"
bash tests/v2-source-archive-boundary-test.sh

banner "H11 pkg-config wrapper (build hardening)"
bash tests/v2-pkg-config-wrapper-test.sh

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

printf '\n=== sweep complete: 11 harnesses passed%s ===\n' \
    "$([[ $with_fixtures -eq 1 ]] && echo ' + V1.5/V2 fixtures' || echo '')"
