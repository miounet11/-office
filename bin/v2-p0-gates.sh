#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_name="${1:-v2-p0-$(date '+%Y%m%d-%H%M%S')}"
report_path="$repo_root/tmp/v2-p0-gates/$run_name.md"

usage() {
    cat <<'EOF'
Usage:
  v2-p0-gates.sh [run-name]

Runs the current P0 verification gates for 可圈office:
  1. source-focused status
  2. quality baseline
  3. scenario workbench template package check
  4. scenario workbench template runtime smoke
  5. compatibility inventory
  6. curated DOCX/XLSX/PPTX compatibility manifest smoke
  7. compatibility manifest audit
  8. validator readiness report
  9. source/generated boundary report
  10. intelligent-office readiness report
  11. intelligent contract fixture validation
  12. service-policy enforcement via local/offline plugin manifest validation
  13. Workbench accessibility static check
  14. GUI timing budget smoke
  15. compatibility layout evidence seed
  16. V2 dashboard refresh

Validator readiness, Workbench accessibility static evidence, GUI smoke timing,
and layout proxy evidence are beta-readiness evidence, not mandatory alpha-hard
gates in this wrapper. Live Workbench accessibility review remains a beta blocker.
Source hygiene and intelligent-office readiness are recorded in advisory mode
here; use strict gates only for public beta or release-candidate checks.
Run the advisory checks separately with:
  bin/validator-readiness.sh tmp/validator-readiness.md
  bin/compatibility-manifest-audit.sh --manifest docs/compatibility/smoke-manifest.tsv
  bin/gui-smoke-timing.sh --mode startcenter --wait 12 --timeout 20 --max-elapsed 20 --run-name <name>
  bin/compatibility-layout-evidence.sh --report tmp/compatibility-layout-evidence.md
  bin/source-hygiene-report.sh tmp/source-hygiene-report.md
  bin/intelligent-office-readiness.sh tmp/intelligent-office-readiness.md
  bin/intelligent-contract-fixtures.sh tmp/intelligent-contract-fixtures.md
  bin/plugin-manifest-validator.sh --self-test --report tmp/plugin-manifest-validator.md
  bin/workbench-accessibility-check.sh tmp/workbench-accessibility-check.md

The report is written to:
  tmp/v2-p0-gates/<run-name>.md
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

mkdir -p "$(dirname "$report_path")"

run_step() {
    local name="$1"
    local tier="$2"
    shift
    shift
    local log_path="$repo_root/tmp/v2-p0-gates/$run_name.$name.log"
    local status="passed"

    if "$@" > "$log_path" 2>&1; then
        status="passed"
    else
        status="failed"
    fi

    {
        printf '## %s\n\n' "$name"
        printf -- '- status: **%s**\n' "$status"
        printf -- '- tier: `%s`\n' "$tier"
        printf -- '- command: `%s`\n' "$*"
        printf -- '- log: `%s`\n\n' "${log_path#$repo_root/}"
    } >> "$report_path"

    if [[ "$status" == "failed" ]]; then
        printf 'Gate failed: %s\nSee: %s\n' "$name" "$log_path" >&2
        return 1
    fi
}

{
    printf '# 可圈office V2 P0 Gates\n\n'
    printf 'Run name: %s\n' "$run_name"
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf 'Repo root: %s\n\n' "$repo_root"
} > "$report_path"

{
    printf '## Gate Tiers\n\n'
    printf -- '- `alpha-hard`: must pass for the current P0 control-plane loop.\n'
    printf -- '- `alpha-advisory`: evidence only in alpha; broken scripts still fail this wrapper.\n'
    printf -- '- `beta-blocker-advisory`: does not block alpha, but must be resolved before beta/release claims.\n\n'
} >> "$report_path"

run_step source-status alpha-hard "$repo_root/bin/source-status.sh"
run_step quality-baseline alpha-hard "$repo_root/bin/quality-baseline.sh" "$repo_root/tmp/world-class-quality-baseline.md"
run_step workbench-template-check alpha-hard "$repo_root/bin/workbench-template-check.sh" "$repo_root/tmp/workbench-template-check.md"
run_step workbench-template-smoke alpha-hard "$repo_root/bin/workbench-template-smoke.sh" --run-name "$run_name-workbench-template-smoke"
run_step compatibility-lab alpha-hard "$repo_root/bin/compatibility-lab.sh" "$repo_root/tmp/compatibility-lab-baseline.md"
run_step compatibility-manifest-audit alpha-hard "$repo_root/bin/compatibility-manifest-audit.sh" --manifest "$repo_root/docs/compatibility/smoke-manifest.tsv" --report "$repo_root/tmp/compatibility-manifest-audit-smoke-manifest.md"
run_step compatibility-roundtrip alpha-hard "$repo_root/bin/compatibility-roundtrip.sh" --manifest "$repo_root/docs/compatibility/smoke-manifest.tsv" --run-name "$run_name-compatibility-smoke"
run_step validator-readiness beta-blocker-advisory "$repo_root/bin/validator-readiness.sh" "$repo_root/tmp/validator-readiness.md"
run_step source-hygiene alpha-advisory "$repo_root/bin/source-hygiene-report.sh" "$repo_root/tmp/source-hygiene-report.md"
run_step intelligent-office-readiness alpha-advisory "$repo_root/bin/intelligent-office-readiness.sh" "$repo_root/tmp/intelligent-office-readiness.md"
run_step intelligent-contract-fixtures alpha-hard "$repo_root/bin/intelligent-contract-fixtures.sh" "$repo_root/tmp/intelligent-contract-fixtures.md"
run_step service-policy-enforcement alpha-hard "$repo_root/bin/plugin-manifest-validator.sh" --self-test --report "$repo_root/tmp/plugin-manifest-validator.md"
run_step workbench-accessibility beta-blocker-advisory "$repo_root/bin/workbench-accessibility-check.sh" "$repo_root/tmp/workbench-accessibility-check.md"
run_step gui-smoke-timing alpha-advisory "$repo_root/bin/gui-smoke-timing.sh" --mode startcenter --wait 12 --timeout 20 --max-elapsed 20 --run-name "$run_name-gui-budget"
run_step compatibility-layout-evidence alpha-advisory "$repo_root/bin/compatibility-layout-evidence.sh" --report "$repo_root/tmp/compatibility-layout-evidence.md"
run_step v2-dashboard alpha-hard "$repo_root/bin/v2-upgrade-dashboard.sh" "$repo_root/tmp/v2-upgrade-dashboard.md"

{
    printf '## Summary\n\n'
    printf 'Status: **passed**\n'
    printf 'Report: `%s`\n' "${report_path#$repo_root/}"
} >> "$report_path"

printf 'Wrote V2 P0 gates report to %s\n' "$report_path"
