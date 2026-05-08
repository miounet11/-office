#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_name="${1:-v2-beta-$(date '+%Y%m%d-%H%M%S')}"
report_path="$repo_root/tmp/v2-beta-gates/$run_name.md"
json_report_path="$repo_root/tmp/v2-beta-gates/$run_name.json"

usage() {
    cat <<'EOF'
Usage:
  v2-beta-gates.sh [run-name]

Runs the current beta-readiness gates for 可圈office.

Unlike bin/v2-p0-gates.sh, this wrapper treats missing validators, strict
source hygiene, and missing manual accessibility evidence as blockers for beta
claims. Service-policy enforcement is beta-hard and must pass before any
plugin/provider runtime readiness claim. This wrapper is expected to fail until
those assets/evidence are complete.

Reports are written to:
  tmp/v2-beta-gates/<run-name>.md
  tmp/v2-beta-gates/<run-name>.json
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ ! "$run_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
    printf 'Invalid run name: %s\n' "$run_name" >&2
    printf 'Use only letters, digits, dot, underscore, and hyphen.\n' >&2
    exit 2
fi

mkdir -p "$(dirname "$report_path")"

escape_md() {
    local value="${1-}"
    value="${value//\`/\\\`}"
    printf '%s' "$value"
}

format_command() {
    local arg
    local display_arg
    local formatted=()
    for arg in "$@"; do
        display_arg="$arg"
        if [[ "$display_arg" == "$repo_root"/* ]]; then
            display_arg="\$repo_root/${display_arg#$repo_root/}"
        fi
        if [[ "$display_arg" =~ [[:space:]\`\$\\] ]]; then
            display_arg="'${display_arg//\'/\'\\\'\'}'"
        fi
        formatted+=("$display_arg")
    done
    local IFS=' '
    printf '%s' "${formatted[*]}"
}

declare -a step_names=()
declare -a step_statuses=()
declare -a step_tiers=()
declare -a step_commands=()
declare -a step_logs=()
declare -a step_actions=()

record_step_result() {
    local name="$1"
    local status="$2"
    local tier="$3"
    local command="$4"
    local log="$5"
    local action="$6"

    step_names+=("$name")
    step_statuses+=("$status")
    step_tiers+=("$tier")
    step_commands+=("$command")
    step_logs+=("$log")
    step_actions+=("$action")
}

run_step() {
    local name="$1"
    local tier="$2"
    shift
    shift
    local log_path="$repo_root/tmp/v2-beta-gates/$run_name.$name.log"
    local log_rel="${log_path#$repo_root/}"
    local status="passed"
    local command
    command="$(format_command "$@")"

    if "$@" > "$log_path" 2>&1; then
        status="passed"
    else
        status="failed"
    fi

    record_step_result "$name" "$status" "$tier" "$command" "$log_rel" ""

    {
        printf '## %s\n\n' "$name"
        printf -- '- status: **%s**\n' "$status"
        printf -- '- tier: `%s`\n' "$tier"
        printf -- '- command: `%s`\n' "$(escape_md "$command")"
        printf -- '- log: `%s`\n\n' "$log_rel"
    } >> "$report_path"

    if [[ "$status" == "failed" ]]; then
        return 1
    fi
}

record_manual_blocker() {
    local name="$1"
    local detail="$2"
    record_step_result "$name" "failed" "beta-hard" "manual evidence review" "" "$detail"
    {
        printf '## %s\n\n' "$name"
        printf -- '- status: **failed**\n'
        printf -- '- tier: `beta-hard`\n'
        printf -- '- evidence: %s\n\n' "$detail"
    } >> "$report_path"
    return 1
}

failures=0
failed_steps=()

record_failure() {
    failed_steps+=("$1")
    failures=$((failures + 1))
}

set_step_action() {
    local name="$1"
    local action="$2"
    local index
    for index in "${!step_names[@]}"; do
        if [[ "${step_names[$index]}" == "$name" ]]; then
            step_actions[$index]="$action"
            return 0
        fi
    done
    return 1
}

write_json_report() {
    local status="passed"
    if [[ "$failures" -ne 0 ]]; then
        status="failed"
    fi

    BETA_GATE_STEP_NAMES="$(join_by_unit_separator "${step_names[@]}")" \
    BETA_GATE_STEP_STATUSES="$(join_by_unit_separator "${step_statuses[@]}")" \
    BETA_GATE_STEP_TIERS="$(join_by_unit_separator "${step_tiers[@]}")" \
    BETA_GATE_STEP_COMMANDS="$(join_by_unit_separator "${step_commands[@]}")" \
    BETA_GATE_STEP_LOGS="$(join_by_unit_separator "${step_logs[@]}")" \
    BETA_GATE_STEP_ACTIONS="$(join_by_unit_separator "${step_actions[@]}")" \
    python3 - "$json_report_path" "$run_name" "$repo_root" "$report_path" "$status" "$failures" <<'PY'
import json
import os
import sys

output_path, run_name, repo_root, report_path, status, failures = sys.argv[1:7]
step_names = os.environ.get("BETA_GATE_STEP_NAMES", "").split("\x1f") if os.environ.get("BETA_GATE_STEP_NAMES") else []
step_statuses = os.environ.get("BETA_GATE_STEP_STATUSES", "").split("\x1f") if os.environ.get("BETA_GATE_STEP_STATUSES") else []
step_tiers = os.environ.get("BETA_GATE_STEP_TIERS", "").split("\x1f") if os.environ.get("BETA_GATE_STEP_TIERS") else []
step_commands = os.environ.get("BETA_GATE_STEP_COMMANDS", "").split("\x1f") if os.environ.get("BETA_GATE_STEP_COMMANDS") else []
step_logs = os.environ.get("BETA_GATE_STEP_LOGS", "").split("\x1f") if os.environ.get("BETA_GATE_STEP_LOGS") else []
step_actions = os.environ.get("BETA_GATE_STEP_ACTIONS", "").split("\x1f") if os.environ.get("BETA_GATE_STEP_ACTIONS") else []

default_actions = {
    "compatibility-manifest-audit": "Inspect tmp/compatibility-manifest-audit-smoke-manifest.md and fix manifest path, scenario-note, or sample availability issues without editing import/export engines.",
    "compatibility-roundtrip": "Resolve validator-readiness-strict first, then rerun strict manifest roundtrip and inspect the generated compatibility run report.",
    "validator-readiness-strict": "Inspect tmp/validator-readiness-strict.md and docs/compatibility/validator-assets-release-packet.md for missing trusted validator assets, checksums, and wrapper smoke status.",
    "workbench-accessibility-static": "Inspect tmp/workbench-accessibility-check.md and keep static accessibility evidence separate from live manual accessibility evidence.",
    "gui-smoke-timing-startcenter": "Inspect the gui-smoke-timing report and referenced soffice log for survival, timeout, and timing-budget classification.",
    "compatibility-layout-evidence": "Inspect tmp/compatibility-layout-evidence.md; do not treat layout-proxy evidence as pixel-fidelity proof.",
    "source-hygiene-strict": "Inspect tmp/source-hygiene-report-strict.md and docs/product/source-hygiene-release-packet.md before cleaning, ignoring, or staging any working-tree entries.",
    "service-policy-enforcement": "Inspect tmp/plugin-manifest-validator.md; runtime plugin/provider readiness remains blocked beyond manifest self-tests.",
    "workbench-live-accessibility": "Complete manual Tab/Shift+Tab, Enter/Space, VoiceOver, high-contrast, resize, and missing-template fallback review with evidence.",
}

steps = []
failed_blockers = []
for index, name in enumerate(step_names):
    action = step_actions[index] if index < len(step_actions) else ""
    if not action:
        action = default_actions.get(name, "Inspect the step log and preserve beta-hard failure status until evidence passes.")
    step = {
        "key": name,
        "status": step_statuses[index] if index < len(step_statuses) else "unknown",
        "tier": step_tiers[index] if index < len(step_tiers) else "unknown",
        "command": step_commands[index] if index < len(step_commands) else "",
        "log": step_logs[index] if index < len(step_logs) else "",
        "action": action,
    }
    steps.append(step)
    if step["status"] == "failed":
        failed_blockers.append({
            "key": step["key"],
            "tier": step["tier"],
            "log": step["log"],
            "action": step["action"],
        })

payload = {
    "schema_version": 1,
    "run_name": run_name,
    "repo_root": repo_root,
    "markdown_report": os.path.relpath(report_path, repo_root),
    "overall_status": status,
    "failed_blocker_count": int(failures),
    "failed_blockers": failed_blockers,
    "steps": steps,
    "beta_readiness_claim_allowed": status == "passed",
    "note": "Machine-readable beta gate summary. Failed beta-hard blockers remain unresolved until their gates pass with evidence.",
}

with open(output_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY
}

join_by_unit_separator() {
    local IFS=$'\x1f'
    printf '%s' "$*"
}

{
    printf '# 可圈office V2 Beta Gates\n\n'
    printf 'Run name: %s\n' "$run_name"
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf 'Repo root: %s\n\n' "$repo_root"
    printf '## Gate Semantics\n\n'
    printf -- '- `beta-hard`: must pass before beta/release quality claims.\n'
    printf -- '- This wrapper may fail while alpha iteration remains acceptable.\n'
    printf -- '- Failed or missing validators, strict hygiene failures, and missing live a11y evidence are blockers, not skipped passes.\n\n'
} > "$report_path"

run_step compatibility-manifest-audit beta-hard \
    "$repo_root/bin/compatibility-manifest-audit.sh" \
    --manifest "$repo_root/docs/compatibility/smoke-manifest.tsv" \
    --report "$repo_root/tmp/compatibility-manifest-audit-smoke-manifest.md" || record_failure compatibility-manifest-audit

run_step validator-readiness-strict beta-hard \
    "$repo_root/bin/validator-readiness.sh" \
    --strict "$repo_root/tmp/validator-readiness-strict.md" || {
    action='inspect `tmp/validator-readiness-strict.md` and `docs/compatibility/validator-assets-release-packet.md` for exact missing validator assets, provenance, checksums, and wrapper smoke status.'
    set_step_action validator-readiness-strict "$action"
    {
        printf -- '- action: %s\n\n' "$action"
    } >> "$report_path"
    record_failure validator-readiness-strict
}

run_step compatibility-roundtrip beta-hard \
    "$repo_root/bin/compatibility-roundtrip.sh" \
    --manifest "$repo_root/docs/compatibility/smoke-manifest.tsv" \
    --strict-validators \
    --allow-extension-namespace \
    --run-name "$run_name-compatibility-smoke" || record_failure compatibility-roundtrip

run_step workbench-accessibility-static beta-hard \
    "$repo_root/bin/workbench-accessibility-check.sh" \
    "$repo_root/tmp/workbench-accessibility-check.md" || record_failure workbench-accessibility-static

run_step gui-smoke-timing-startcenter beta-hard \
    "$repo_root/bin/gui-smoke-timing.sh" \
    --mode startcenter \
    --wait 12 \
    --timeout 20 \
    --max-elapsed 20 \
    --run-name "$run_name-gui-budget" || record_failure gui-smoke-timing-startcenter

run_step compatibility-layout-evidence beta-hard \
    "$repo_root/bin/compatibility-layout-evidence.sh" \
    --run-dir "$repo_root/tmp/compatibility-runs/$run_name-compatibility-smoke" \
    --report "$repo_root/tmp/compatibility-layout-evidence.md" || record_failure compatibility-layout-evidence

run_step source-hygiene-strict beta-hard \
    "$repo_root/bin/source-hygiene-report.sh" \
    --strict "$repo_root/tmp/source-hygiene-report-strict.md" || {
    action='inspect `tmp/source-hygiene-report-strict.md` and `docs/product/source-hygiene-release-packet.md` for source review, generated/local cleanup, config/autoconf, install/test/release, and human-decision buckets.'
    set_step_action source-hygiene-strict "$action"
    {
        printf -- '- action: %s\n\n' "$action"
    } >> "$report_path"
    record_failure source-hygiene-strict
}

run_step service-policy-enforcement beta-hard \
    "$repo_root/bin/plugin-manifest-validator.sh" \
    --self-test \
    --report "$repo_root/tmp/plugin-manifest-validator.md" || record_failure service-policy-enforcement

record_manual_blocker workbench-live-accessibility \
    'docs/accessibility/workbench-accessibility-evidence-m2-06.md keeps live Tab/Shift+Tab, Enter/Space, VoiceOver, high-contrast, resize, and missing-template fallback review as beta blockers.' || record_failure workbench-live-accessibility

{
    remediation_index=1
    printf '## Remediation Order\n\n'
    printf 'Failed beta blockers must be remediated in this order; do not claim beta readiness until every beta-hard item passes with evidence. Missing validators and live accessibility remain beta-hard failures.\n\n'
    if [[ " ${failed_steps[*]} " == *" validator-readiness-strict "* || " ${failed_steps[*]} " == *" compatibility-roundtrip "* ]]; then
        printf '%s. **Missing validator assets / strict compatibility**: resolve `validator-readiness-strict` first, then rerun `compatibility-roundtrip` with strict validators. Evidence: `tmp/validator-readiness-strict.md`, validator asset provenance/checksums, wrapper smoke output, and the roundtrip report under `tmp/compatibility-roundtrip/`.\n' "$remediation_index"
        remediation_index=$((remediation_index + 1))
    fi
    if [[ " ${failed_steps[*]} " == *" gui-smoke-timing-startcenter "* ]]; then
        printf '%s. **GUI survival diagnostics**: resolve `gui-smoke-timing-startcenter` using the GUI report pid, exit status/classification, and soffice log tail. Evidence: `tmp/gui-smoke-timing/%s-gui-budget/report.md` plus the referenced soffice log.\n' "$remediation_index" "$run_name"
        remediation_index=$((remediation_index + 1))
    fi
    if [[ " ${failed_steps[*]} " == *" source-hygiene-strict "* ]]; then
        printf '%s. **Source hygiene**: resolve `source-hygiene-strict` without deleting/resetting unrelated generated outputs. Evidence: `tmp/source-hygiene-report-strict.md` and any reviewed release packet decisions.\n' "$remediation_index"
        remediation_index=$((remediation_index + 1))
    fi
    if [[ " ${failed_steps[*]} " == *" workbench-live-accessibility "* ]]; then
        printf '%s. **Live accessibility**: complete manual Tab/Shift+Tab, Enter/Space, VoiceOver, high-contrast, resize, and missing-template fallback review. Evidence: updated live accessibility packet; static accessibility alone is insufficient.\n' "$remediation_index"
        remediation_index=$((remediation_index + 1))
    fi
    printf '%s. **Regression sweep**: rerun this beta gate wrapper and retain logs for all previously failed blockers.\n\n' "$remediation_index"
    if [[ "${#failed_steps[@]}" -gt 0 ]]; then
        printf 'Failed blocker keys in this run: `%s`\n\n' "$(IFS=', '; printf '%s' "${failed_steps[*]}")"
    fi
    printf 'See also: `docs/product/beta-blocker-remediation-protocol.md`\n\n'
    printf '## Summary\n\n'
    if [[ "$failures" -eq 0 ]]; then
        printf 'Status: **passed**\n'
    else
        printf 'Status: **failed**\n'
        printf 'Failed beta blockers: %s\n' "$failures"
    fi
    printf 'Report: `%s`\n' "${report_path#$repo_root/}"
    printf 'JSON report: `%s`\n' "${json_report_path#$repo_root/}"
} >> "$report_path"

write_json_report

printf 'Wrote V2 beta gates report to %s\n' "$report_path"
printf 'Wrote V2 beta gates JSON report to %s\n' "$json_report_path"

if [[ "$failures" -ne 0 ]]; then
    exit 1
fi
