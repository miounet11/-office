#!/usr/bin/env bash
set -euo pipefail

# v3-eval-sweep.sh — V3 contract harness sweep.
#
# Wraps the V2 sweep and chains the new V3 harnesses:
#   H8  V3 connector-manifest contract (W2)
#   H9  V3 eval-baseline (W5/W6 token + score/judge-policy lock)
#   H10 V3 local-cloud-no-egress (W8)
#   H11 V3 perf-baseline (W9 启动/首 token/召回)
#   H12 V3 crash-recovery (W9 autosave 30s + 重启 0 丢失)
#   W1  in-app-chat self-test (fixture + AI workspace UI + content opener + formatting review + content review + artifact navigator + review queue + evidence inspector + interaction chrome + content preview matrix + workspace action bar + workspace filter/search + workspace context handoff + workspace review state sync + workspace activity timeline + workspace session snapshot + workspace attention routing + workspace native style + workspace content registry + source provenance + chat clipboard materialization policy contracts, no new schema)
#   W3  knowledge-index-chunk self-test (chunk schema/fixtures)
#   W3  knowledge-index-query-result self-test (query/result schema/fixtures)
#   W4  audit-log-entry self-test (tenant/policy/audit schema/fixtures)
#   W4  policy-tenant self-test (policy rule + tenant context schema/fixtures)
#   W5  eval-report self-test (report schema/template/archive policy fields)
#   W6  agent-step-plan self-test (Plan-Act-Observe schema/fixtures)
#   W6  agent-step-result-state self-test (lifecycle result/state schema/fixtures)
#   W7  companion-contract self-test (pairing/diff/approval schema/fixtures)
#   W8  sync-message self-test (sync-server message schema/fixtures)
#   W9  onboarding-flow self-test (first-run flow schema/fixtures)
#   W9  starter-pack self-test (30-template manifest schema/fixtures)
#   W9  edition-policy self-test (freemium/audit-lock schema/fixtures)
#   W9  i18n-locale self-test (locale/output-language schema/fixtures)
#   W9  manual-docs self-test (embedded/online manual schema/fixtures)
#   W9  distribution-update self-test (distribution/update schema/fixtures)
#   W9  error-recovery-ux self-test (inline recovery schema/fixtures)
#   W9  release-ga-checklist self-test (GA checklist schema/fixtures)
#
# H8, H9 seed, H10 no-egress config contract, H11 perf target contract,
# and H12 crash-recovery target contract are active.
#
# Usage:
#   bin/v3-eval-sweep.sh                  # V2 H1-H10 + V3 H8/H9/H10/H11/H12 active
#   bin/v3-eval-sweep.sh --with-fixtures  # also run V1.5+V2 fixture sweep
#   bin/v3-eval-sweep.sh --v3-only        # skip V2 sweep, only H8-H12
#   bin/v3-eval-sweep.sh --self-test      # run V3 meta self-tests (W1/W3/W4/W5/W6/W7/W8/W9)
#   bin/v3-eval-sweep.sh -h | --help
#
# Exit codes:
#   0   all active harnesses green
#   !0  first failing harness's exit code

usage() {
    cat <<'EOF'
Usage:
  v3-eval-sweep.sh [--with-fixtures] [--v3-only]
  v3-eval-sweep.sh --self-test

Runs V3 contract sweep. Order:

  V2 baseline (delegated to bin/v2-harness-sweep.sh):
    H1-H10  V2 contract sweep                    (active)

  V3 additions:
    H8  connector-manifest contract              (active — W2)
    H9  eval-baseline seed                       (active — W5)
    H10 local-cloud-no-egress                    (active — W8)
    H11 perf-baseline                            (active — W9 target contract)
    H12 crash-recovery                           (active — W9 target contract)
    W1  in-app-chat self-test                    (active — fixture + AI workspace UI + content opener + formatting review + content review + artifact navigator + review queue + evidence inspector + interaction chrome + content preview matrix + workspace action bar + workspace filter/search + workspace context handoff + workspace review state sync + workspace activity timeline + workspace session snapshot + workspace attention routing + workspace native style + workspace content registry + source provenance + chat clipboard materialization policy contracts, no new schema)
    W3  knowledge-index-chunk self-test          (active — schema/fixtures)
    W3  knowledge-index-query-result self-test   (active — schema/fixtures)
    W4  audit-log-entry self-test                (active — schema/fixtures)
    W4  policy-tenant self-test                  (active — schema/fixtures)
    W5  eval-report self-test                    (active — report/archive fields)
    W6  agent-step-plan self-test                (active — schema/fixtures)
    W6  agent-step-result-state self-test        (active — schema/fixtures)
    W7  companion-contract self-test             (active — schema/fixtures)
    W8  sync-message self-test                   (active — schema/fixtures)
    W9  onboarding-flow self-test                (active — schema/fixtures)
    W9  starter-pack self-test                   (active — schema/fixtures)
    W9  edition-policy self-test                 (active — schema/fixtures)
    W9  i18n-locale self-test                    (active — schema/fixtures)
    W9  manual-docs self-test                    (active — schema/fixtures)
    W9  distribution-update self-test            (active — schema/fixtures)
    W9  error-recovery-ux self-test              (active — schema/fixtures)
    W9  release-ga-checklist self-test           (active — schema/fixtures)

Flags:
  --with-fixtures  also run bin/intelligent-contract-fixtures.sh
  --v3-only        skip V2 sweep, only run V3 harness slots
  --self-test      run V3 meta self-tests

V3 baseline (post-L242):
  H8=16  H9=9  H10=10  H11=8  H12=9
  in-app-chat self-test=28
  knowledge-index-chunk self-test=12
  knowledge-index-query-result self-test=8
  audit-log-entry self-test=7
  policy-tenant self-test=8
  report self-test=10
  agent-step-plan self-test=13
  agent-step-result-state self-test=8
  companion-contract self-test=9
  sync-message self-test=8
  onboarding-flow self-test=8
  starter-pack self-test=8
  edition-policy self-test=8
  i18n-locale self-test=8
  manual-docs self-test=8
  distribution-update self-test=8
  error-recovery-ux self-test=8
  release-ga-checklist self-test=8
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

with_fixtures=0
v3_only=0
self_test=0
for arg in "$@"; do
    case "$arg" in
        --with-fixtures) with_fixtures=1 ;;
        --v3-only)       v3_only=1 ;;
        --self-test)     self_test=1 ;;
        *) echo "unknown arg: $arg" >&2; usage; exit 2 ;;
    esac
done

if [[ $self_test -eq 1 && ( $with_fixtures -eq 1 || $v3_only -eq 1 ) ]]; then
    echo "--self-test cannot be combined with --with-fixtures or --v3-only" >&2
    usage
    exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

banner() {
    printf '\n=== %s ===\n' "$1"
}

if [[ $self_test -eq 1 ]]; then
    banner "W1 in-app-chat self-test (V3 W1)"
    if [[ -x tests/v3-in-app-chat-test.sh ]]; then
        bash tests/v3-in-app-chat-test.sh
    else
        echo "  FAIL: tests/v3-in-app-chat-test.sh missing or not executable" >&2
        exit 1
    fi

    banner "W3 knowledge-index-chunk self-test (V3 W3)"
    if [[ -x tests/v3-knowledge-index-chunk-test.sh ]]; then
        bash tests/v3-knowledge-index-chunk-test.sh
    else
        echo "  FAIL: tests/v3-knowledge-index-chunk-test.sh missing or not executable" >&2
        exit 1
    fi

    banner "W3 knowledge-index-query-result self-test (V3 W3)"
    if [[ -x tests/v3-knowledge-index-query-result-test.sh ]]; then
        bash tests/v3-knowledge-index-query-result-test.sh
    else
        echo "  FAIL: tests/v3-knowledge-index-query-result-test.sh missing or not executable" >&2
        exit 1
    fi

    banner "W4 audit-log-entry self-test (V3 W4)"
    if [[ -x tests/v3-audit-log-entry-test.sh ]]; then
        bash tests/v3-audit-log-entry-test.sh
    else
        echo "  FAIL: tests/v3-audit-log-entry-test.sh missing or not executable" >&2
        exit 1
    fi

    banner "W4 policy-tenant self-test (V3 W4)"
    if [[ -x tests/v3-policy-tenant-test.sh ]]; then
        bash tests/v3-policy-tenant-test.sh
    else
        echo "  FAIL: tests/v3-policy-tenant-test.sh missing or not executable" >&2
        exit 1
    fi

    banner "W5 eval-report self-test (V3 W5)"
    if [[ -x tests/v3-eval-report-self-test.sh ]]; then
        bash tests/v3-eval-report-self-test.sh
    else
        echo "  FAIL: tests/v3-eval-report-self-test.sh missing or not executable" >&2
        exit 1
    fi

    banner "W6 agent-step-plan self-test (V3 W6)"
    if [[ -x tests/v3-agent-step-plan-test.sh ]]; then
        bash tests/v3-agent-step-plan-test.sh
    else
        echo "  FAIL: tests/v3-agent-step-plan-test.sh missing or not executable" >&2
        exit 1
    fi

    banner "W6 agent-step-result-state self-test (V3 W6)"
    if [[ -x tests/v3-agent-step-result-state-test.sh ]]; then
        bash tests/v3-agent-step-result-state-test.sh
    else
        echo "  FAIL: tests/v3-agent-step-result-state-test.sh missing or not executable" >&2
        exit 1
    fi

    banner "W7 companion-contract self-test (V3 W7)"
    if [[ -x tests/v3-companion-contract-test.sh ]]; then
        bash tests/v3-companion-contract-test.sh
    else
        echo "  FAIL: tests/v3-companion-contract-test.sh missing or not executable" >&2
        exit 1
    fi

    banner "W8 sync-message self-test (V3 W8)"
    if [[ -x tests/v3-sync-message-test.sh ]]; then
        bash tests/v3-sync-message-test.sh
    else
        echo "  FAIL: tests/v3-sync-message-test.sh missing or not executable" >&2
        exit 1
    fi

    banner "W9 onboarding-flow self-test (V3 W9)"
    if [[ -x tests/v3-onboarding-flow-test.sh ]]; then
        bash tests/v3-onboarding-flow-test.sh
    else
        echo "  FAIL: tests/v3-onboarding-flow-test.sh missing or not executable" >&2
        exit 1
    fi

    banner "W9 starter-pack self-test (V3 W9)"
    if [[ -x tests/v3-starter-pack-test.sh ]]; then
        bash tests/v3-starter-pack-test.sh
    else
        echo "  FAIL: tests/v3-starter-pack-test.sh missing or not executable" >&2
        exit 1
    fi

    banner "W9 edition-policy self-test (V3 W9)"
    if [[ -x tests/v3-edition-policy-test.sh ]]; then
        bash tests/v3-edition-policy-test.sh
    else
        echo "  FAIL: tests/v3-edition-policy-test.sh missing or not executable" >&2
        exit 1
    fi

    banner "W9 i18n-locale self-test (V3 W9)"
    if [[ -x tests/v3-i18n-locale-test.sh ]]; then
        bash tests/v3-i18n-locale-test.sh
    else
        echo "  FAIL: tests/v3-i18n-locale-test.sh missing or not executable" >&2
        exit 1
    fi

    banner "W9 manual-docs self-test (V3 W9)"
    if [[ -x tests/v3-manual-docs-test.sh ]]; then
        bash tests/v3-manual-docs-test.sh
    else
        echo "  FAIL: tests/v3-manual-docs-test.sh missing or not executable" >&2
        exit 1
    fi

    banner "W9 distribution-update self-test (V3 W9)"
    if [[ -x tests/v3-distribution-update-test.sh ]]; then
        bash tests/v3-distribution-update-test.sh
    else
        echo "  FAIL: tests/v3-distribution-update-test.sh missing or not executable" >&2
        exit 1
    fi

    banner "W9 error-recovery-ux self-test (V3 W9)"
    if [[ -x tests/v3-error-recovery-ux-test.sh ]]; then
        bash tests/v3-error-recovery-ux-test.sh
    else
        echo "  FAIL: tests/v3-error-recovery-ux-test.sh missing or not executable" >&2
        exit 1
    fi

    banner "W9 release-ga-checklist self-test (V3 W9)"
    if [[ -x tests/v3-release-ga-checklist-test.sh ]]; then
        bash tests/v3-release-ga-checklist-test.sh
    else
        echo "  FAIL: tests/v3-release-ga-checklist-test.sh missing or not executable" >&2
        exit 1
    fi

    banner "V3 self-test complete"
    exit 0
fi

if [[ $v3_only -eq 0 ]]; then
    banner "V2 sweep (H1-H10)"
    if [[ $with_fixtures -eq 1 ]]; then
        bash bin/v2-harness-sweep.sh --with-fixtures
    else
        bash bin/v2-harness-sweep.sh
    fi
fi

banner "H8 connector-manifest contract (V3 W2)"
if [[ -x tests/v3-connector-manifest-contract-test.sh ]]; then
    bash tests/v3-connector-manifest-contract-test.sh
else
    echo "  FAIL: tests/v3-connector-manifest-contract-test.sh missing or not executable" >&2
    exit 1
fi

banner "H9 eval-baseline seed (V3 W5)"
if [[ -x tests/v3-eval-baseline-test.sh ]]; then
    bash tests/v3-eval-baseline-test.sh
else
    echo "  FAIL: tests/v3-eval-baseline-test.sh missing or not executable" >&2
    exit 1
fi

banner "H10 local-cloud-no-egress (V3 W8)"
if [[ -x tests/v3-local-cloud-no-egress-test.sh ]]; then
    bash tests/v3-local-cloud-no-egress-test.sh
else
    echo "  FAIL: tests/v3-local-cloud-no-egress-test.sh missing or not executable" >&2
    exit 1
fi

banner "H11 perf-baseline target contract (V3 W9)"
if [[ -x tests/v3-perf-baseline-test.sh ]]; then
    bash tests/v3-perf-baseline-test.sh
else
    echo "  FAIL: tests/v3-perf-baseline-test.sh missing or not executable" >&2
    exit 1
fi

banner "H12 crash-recovery target contract (V3 W9)"
if [[ -x tests/v3-crash-recovery-test.sh ]]; then
    bash tests/v3-crash-recovery-test.sh
else
    echo "  FAIL: tests/v3-crash-recovery-test.sh missing or not executable" >&2
    exit 1
fi

banner "V3 sweep complete"
