#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -n "${KDOFFICE_SRC_ROOT:-}" ]]; then
    src_root="$(cd -P "$KDOFFICE_SRC_ROOT" && pwd)"
elif [[ -d "$repo_root/libreoffice-core" ]]; then
    src_root="$(cd -P "$repo_root/libreoffice-core" && pwd)"
else
    src_root="$(cd -P "$repo_root" && pwd)"
fi
app_candidates=(
    "$repo_root/instdir/可圈办公.app"
    "$repo_root/test-install/可圈办公.app"
)
if [[ "$src_root" != "$repo_root" ]]; then
    app_candidates+=(
        "$src_root/test-install/可圈办公.app"
        "$src_root/instdir/可圈办公.app"
    )
fi
app_bundle="${KDOFFICE_APP_BUNDLE:-${app_candidates[0]}}"
for candidate in "${app_candidates[@]}"; do
    if [[ -x "$candidate/Contents/MacOS/soffice" ]]; then
        app_bundle="$candidate"
        break
    fi
done
soffice_bin="${KDOFFICE_SOFFICE_BIN:-$app_bundle/Contents/MacOS/soffice}"
run_root_default="$repo_root/tmp/workbench-template-smoke"
run_name="$(date '+%Y%m%d-%H%M%S')"
report_path=""

usage() {
    cat <<'EOF'
Usage:
  workbench-template-smoke.sh [options]

Options:
  --run-name <name>
  --report <path>
  -h, --help

Converts each installed scenario-workbench template with the packaged
soffice binary. This checks that the runtime templates are readable and
loadable without launching the GUI.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --run-name)
            run_name="$2"
            shift 2
            ;;
        --report)
            report_path="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ ! -x "$soffice_bin" ]]; then
    printf 'Missing packaged app executable: %s\n' "$soffice_bin" >&2
    exit 1
fi

run_dir="$run_root_default/$run_name"
mkdir -p "$run_dir"

if [[ -z "$report_path" ]]; then
    report_path="$run_dir/report.md"
fi

template_root="${KDOFFICE_TEMPLATE_ROOT:-$app_bundle/Contents/Resources/template/common}"
templates=(
    "writer|工作汇报|offimisc/Work_Report_CN.ott|odt"
    "writer|会议纪要|offimisc/Meeting_Minutes_CN.ott|odt"
    "writer|通知|officorr/Notice_CN.ott|odt"
    "writer|项目方案|offimisc/Project_Plan_CN.ott|odt"
    "writer|演示提纲|offimisc/PPT_Outline_CN.ott|odt"
    "calc|预算总览|spreadsheets/Budget_CN.ots|ods"
    "calc|销售跟进|spreadsheets/Sales_Tracker_CN.ots|ods"
    "calc|项目排期|spreadsheets/Project_Schedule_CN.ots|ods"
    "impress|商务路演|presnt/Business_Pitch_CN.otp|odp"
    "impress|项目汇报|presnt/Project_Report_CN.otp|odp"
    "impress|教学课件|presnt/Teaching_Courseware_CN.otp|odp"
)

slugify() {
    python3 - "$1" "$2" <<'PY'
from pathlib import Path
import hashlib
import re
import sys

title = sys.argv[1]
rel = sys.argv[2]
stem = re.sub(r"[^A-Za-z0-9_.-]+", "_", Path(rel).stem).strip("_")
digest = hashlib.sha1(f"{title}|{rel}".encode("utf-8")).hexdigest()[:10]
print(f"{stem}-{digest}")
PY
}

summarize_log_tail() {
    local log_path="$1"
    local summary_path="$2"
    if [[ -f "$log_path" ]]; then
        python3 - "$log_path" "$summary_path" <<'PY'
from pathlib import Path
import sys

log_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
lines = log_path.read_text(encoding="utf-8", errors="replace").splitlines()
out_path.write_text("\n".join(lines[-12:]) + ("\n" if lines else ""), encoding="utf-8")
PY
    fi
}

overall_success=0
overall_failure=0
results_tsv="$run_dir/results.tsv"
: > "$results_tsv"

{
    printf '# Scenario Workbench Template Smoke\n\n'
    printf 'Run name: %s\n' "$run_name"
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf 'Packaged app: %s\n' "$soffice_bin"
    printf 'Template root: %s\n\n' "$template_root"
    printf '## Results\n\n'
} > "$report_path"

for entry in "${templates[@]}"; do
    IFS='|' read -r lane title rel target <<< "$entry"
    input_file="$template_root/$rel"
    sample_dir="$run_dir/$(slugify "$title" "$rel")"
    out_dir="$sample_dir/out"
    mkdir -p "$out_dir"
    log_path="$sample_dir/convert.log"
    result="success"
    notes=()

    if [[ ! -f "$input_file" ]]; then
        result="failure"
        notes+=("template missing")
        printf 'missing template: %s\n' "$input_file" > "$log_path"
    elif ! "$soffice_bin" --headless --convert-to "$target" --outdir "$out_dir" "$input_file" > "$log_path" 2>&1; then
        result="failure"
        notes+=("conversion failed")
        tail_path="$log_path.tail"
        summarize_log_tail "$log_path" "$tail_path"
    fi

    output_count="$(find "$out_dir" -maxdepth 1 -type f -name "*.$target" 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$result" == "success" && "$output_count" == "0" ]]; then
        result="failure"
        notes+=("output missing")
    fi

    if [[ "$result" == "success" ]]; then
        overall_success=$((overall_success + 1))
    else
        overall_failure=$((overall_failure + 1))
    fi
    printf '%s\t%s\t%s\n' "$lane" "$rel" "$result" >> "$results_tsv"

    {
        printf '### %s\n\n' "$title"
        printf -- '- lane: `%s`\n' "$lane"
        printf -- '- template: `%s`\n' "$rel"
        printf -- '- target: `%s`\n' "$target"
        printf -- '- result: **%s**\n' "$result"
        printf -- '- log: `%s`\n' "${log_path#$repo_root/}"
        if [[ -f "$log_path.tail" ]]; then
            tail_path="$log_path.tail"
            printf -- '- failure tail: `%s`\n' "${tail_path#$repo_root/}"
        fi
        if [[ "$output_count" != "0" ]]; then
            while IFS= read -r output_file; do
                printf -- '- output: `%s`\n' "${output_file#$repo_root/}"
            done < <(find "$out_dir" -maxdepth 1 -type f -name "*.$target" | sort)
        fi
        if [[ ${#notes[@]} -gt 0 ]]; then
            printf -- '- notes: %s\n' "$(IFS='; '; printf '%s' "${notes[*]}")"
        fi
        printf '\n'
    } >> "$report_path"
done

{
    printf '## Lane Summary\n\n'
    awk -F '\t' '
        {
            lane=$1
            samples[lane]++
            if ($3 == "success") successes[lane]++
            else failures[lane]++
            if (!seen[lane]++) order[++count] = lane
        }
        END {
            for (i = 1; i <= count; i++) {
                lane = order[i]
                printf "- `%s`: samples=%d successes=%d failures=%d\n", lane, samples[lane] + 0, successes[lane] + 0, failures[lane] + 0
            }
        }
    ' "$results_tsv"
    printf '\n## Summary\n\n'
    printf -- '- samples: %s\n' "${#templates[@]}"
    printf -- '- successes: %s\n' "$overall_success"
    printf -- '- failures: %s\n' "$overall_failure"
    printf -- '- run directory: `%s`\n' "${run_dir#$repo_root/}"
} >> "$report_path"

printf 'Wrote workbench template smoke report to %s\n' "$report_path"

if [[ "$overall_failure" -gt 0 ]]; then
    exit 1
fi
