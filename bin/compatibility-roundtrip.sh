#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src_root="$(cd -P "$repo_root/libreoffice-core" && pwd)"
soffice_bin="$repo_root/instdir/可圈office.app/Contents/MacOS/soffice"
run_root_default="$repo_root/tmp/compatibility-runs"
format_arg="docx"
limit="1"
run_name=""
report_path=""

usage() {
    cat <<'EOF'
Usage:
  compatibility-roundtrip.sh [options]

Options:
  --format <docx|xlsx|pptx|odt|ods|odp|doc|xls|ppt|pdf>
           Accepts a single format, a comma-separated list, or "smoke"
           (equivalent to docx,xlsx,pptx).
  --limit <n>
  --run-name <name>
  --report <path>
  -h, --help

Examples:
  compatibility-roundtrip.sh --format docx --limit 2
  compatibility-roundtrip.sh --format docx,xlsx,pptx --limit 1
  compatibility-roundtrip.sh --format smoke --limit 1
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            format_arg="$2"
            shift 2
            ;;
        --limit)
            limit="$2"
            shift 2
            ;;
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

if ! [[ "$limit" =~ ^[0-9]+$ ]] || [[ "$limit" -lt 1 ]]; then
    printf 'Limit must be a positive integer\n' >&2
    exit 1
fi

if [[ ! -x "$soffice_bin" ]]; then
    printf 'Missing packaged app executable: %s\n' "$soffice_bin" >&2
    exit 1
fi

format_csv="$format_arg"
if [[ "$format_arg" == "smoke" ]]; then
    format_csv="docx,xlsx,pptx"
fi

if [[ -z "$run_name" ]]; then
    sanitized_format="${format_csv//,/+}"
    run_name="$(date '+%Y%m%d-%H%M%S')-$sanitized_format"
fi

run_dir="$run_root_default/$run_name"
mkdir -p "$run_dir"

if [[ -z "$report_path" ]]; then
    report_path="$run_dir/report.md"
fi

odf_validator="$repo_root/bin/odfvalidator.sh"
officeotron_validator="$repo_root/bin/officeotron.sh"
verapdf_validator="$repo_root/bin/verapdf.sh"

python3 - "$src_root" "$format_csv" "$limit" <<'PY' > "$run_dir/samples.tsv"
from pathlib import Path
import sys

src_root = Path(sys.argv[1])
formats = [item.strip().lower().lstrip('.') for item in sys.argv[2].split(',') if item.strip()]
limit = int(sys.argv[3])
scan_roots = [
    'sw/qa',
    'sc/qa',
    'sd/qa',
    'sfx2/qa',
    'chart2/qa',
    'oox/qa',
    'filter/qa',
    'xmloff/qa',
]
allowed = {'docx', 'xlsx', 'pptx', 'odt', 'ods', 'odp', 'doc', 'xls', 'ppt', 'pdf'}

for fmt in formats:
    if fmt not in allowed:
        raise SystemExit(f'Unsupported format lane: {fmt}')
    items = []
    needle = f'.{fmt}'
    for rel in scan_roots:
        root = src_root / rel
        if not root.exists():
            continue
        for path in root.rglob(f'*{needle}'):
            if path.is_file():
                items.append(path.relative_to(src_root).as_posix())
    items.sort()
    for item in items[:limit]:
        print(f'{fmt}\t{item}')
PY

sample_count="$(wc -l < "$run_dir/samples.tsv" | tr -d ' ')"
if [[ "$sample_count" == "0" ]]; then
    printf 'No samples found for format selection %s\n' "$format_csv" >&2
    exit 1
fi

lane_targets() {
    case "$1" in
        docx) printf 'odt docx' ;;
        xlsx) printf 'ods xlsx' ;;
        pptx) printf 'odp pptx' ;;
        odt) printf 'docx odt' ;;
        ods) printf 'xlsx ods' ;;
        odp) printf 'pptx odp' ;;
        doc) printf 'odt doc' ;;
        xls) printf 'ods xls' ;;
        ppt) printf 'odp ppt' ;;
        pdf) printf 'input-pdf pdf' ;;
        *)
            printf 'Unsupported format lane: %s\n' "$1" >&2
            exit 1
            ;;
    esac
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
lines = log_path.read_text(encoding='utf-8', errors='replace').splitlines()
out_path.write_text("\n".join(lines[-12:]) + ("\n" if lines else ""), encoding='utf-8')
PY
    fi
}

run_validator() {
    local name="$1"
    local validator_bin="$2"
    local target_file="$3"
    local log_path="$4"
    local status_path="$5"

    if [[ ! -x "$validator_bin" ]]; then
        printf 'skipped:not-executable\n' > "$status_path"
        return 0
    fi

    if "$validator_bin" "$target_file" > "$log_path" 2>&1; then
        printf 'passed\n' > "$status_path"
    else
        local validator_exit=$?
        if [[ "$validator_exit" == "2" ]] && grep -q '^missing validator jar:' "$log_path"; then
            printf 'skipped:missing-asset\n' > "$status_path"
        else
            printf 'failed\n' > "$status_path"
            summarize_log_tail "$log_path" "$log_path.tail"
        fi
    fi
}

get_status() {
    local path="$1"
    if [[ -f "$path" ]]; then
        tr -d '\n' < "$path"
    else
        printf 'not-run'
    fi
}

overall_success=0
overall_failure=0
results_tsv="$run_dir/results.tsv"
: > "$results_tsv"

{
    printf '# Compatibility Roundtrip Report\n\n'
    printf 'Run name: %s\n' "$run_name"
    printf 'Format selection: %s\n' "$format_csv"
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf 'Source root: %s\n' "$src_root"
    printf 'Packaged app: %s\n\n' "$soffice_bin"
    printf '## Samples\n\n'
    while IFS=$'\t' read -r lane rel; do
        printf -- '- `%s` — `%s`\n' "$lane" "$rel"
    done < "$run_dir/samples.tsv"
    printf '\n## Results\n\n'
} > "$report_path"

while IFS=$'\t' read -r lane rel; do
    read -r first_target second_target <<< "$(lane_targets "$lane")"

    sample_name="$(basename "$rel")"
    sample_stem="${sample_name%.*}"
    safe_stem="${sample_stem// /_}"
    sample_dir="$run_dir/$lane-$safe_stem"
    mkdir -p "$sample_dir/step1" "$sample_dir/step2" "$sample_dir/validators"
    cp "$src_root/$rel" "$sample_dir/"
    input_file="$sample_dir/$sample_name"
    step1_log="$sample_dir/step1.log"
    step2_log="$sample_dir/step2.log"
    result="success"
    notes=()

    step1_file=""
    step2_file=""
    validator_target=""
    validator_target_label="not-applicable"

    if [[ "$lane" == "pdf" ]]; then
        validator_target="$input_file"
        validator_target_label="input-pdf"
        printf 'skipped: pdf lane validates input directly\n' > "$step1_log"
        printf 'skipped: pdf lane validates input directly\n' > "$step2_log"
    else
        if ! "$soffice_bin" --headless --convert-to "$first_target" --outdir "$sample_dir/step1" "$input_file" > "$step1_log" 2>&1; then
            result="failure"
            notes+=("step1 convert failed")
            summarize_log_tail "$step1_log" "$step1_log.tail"
        fi

        if [[ "$result" == "success" ]]; then
            step1_file="$(find "$sample_dir/step1" -maxdepth 1 -type f | head -n 1)"
            if [[ -z "$step1_file" ]]; then
                result="failure"
                notes+=("step1 output missing")
            fi
        fi

        if [[ "$result" == "success" ]]; then
            if ! "$soffice_bin" --headless --convert-to "$second_target" --outdir "$sample_dir/step2" "$step1_file" > "$step2_log" 2>&1; then
                result="failure"
                notes+=("step2 convert failed")
                summarize_log_tail "$step2_log" "$step2_log.tail"
            fi
        fi

        if [[ "$result" == "success" ]]; then
            step2_file="$(find "$sample_dir/step2" -maxdepth 1 -type f | head -n 1)"
            if [[ -z "$step2_file" ]]; then
                result="failure"
                notes+=("step2 output missing")
            fi
        fi

        if [[ -n "$step1_file" ]]; then
            case "${step1_file##*.}" in
                odt|ods|odp)
                    validator_target="$step1_file"
                    validator_target_label="step1-odf"
                    ;;
            esac
        fi
        if [[ -z "$validator_target" && -n "$step2_file" ]]; then
            case "${step2_file##*.}" in
                odt|ods|odp)
                    validator_target="$step2_file"
                    validator_target_label="step2-odf"
                    ;;
                pdf)
                    validator_target="$step2_file"
                    validator_target_label="step2-pdf"
                    ;;
            esac
        fi
    fi

    odf_status='skipped:not-applicable'
    officeotron_status='skipped:not-applicable'
    verapdf_status='skipped:not-applicable'

    if [[ -n "$validator_target" ]]; then
        case "${validator_target##*.}" in
            odt|ods|odp)
                run_validator odf "$odf_validator" "$validator_target" "$sample_dir/validators/odfvalidator.log" "$sample_dir/validators/odfvalidator.status"
                run_validator officeotron "$officeotron_validator" "$validator_target" "$sample_dir/validators/officeotron.log" "$sample_dir/validators/officeotron.status"
                odf_status="$(get_status "$sample_dir/validators/odfvalidator.status")"
                officeotron_status="$(get_status "$sample_dir/validators/officeotron.status")"
                ;;
            pdf)
                run_validator verapdf "$verapdf_validator" "$validator_target" "$sample_dir/validators/verapdf.log" "$sample_dir/validators/verapdf.status"
                verapdf_status="$(get_status "$sample_dir/validators/verapdf.status")"
                ;;
        esac
    fi

    if [[ "$result" == "success" ]]; then
        overall_success=$((overall_success + 1))
    else
        overall_failure=$((overall_failure + 1))
    fi
    printf '%s\t%s\n' "$lane" "$result" >> "$results_tsv"

    {
        printf '### `%s`\n\n' "$rel"
        printf -- '- format lane: `%s`\n' "$lane"
        printf -- '- first target: `%s`\n' "$first_target"
        printf -- '- second target: `%s`\n' "$second_target"
        printf -- '- result: **%s**\n' "$result"
        printf -- '- step1 log: `%s`\n' "${step1_log#$repo_root/}"
        printf -- '- step2 log: `%s`\n' "${step2_log#$repo_root/}"
        if [[ -f "$step1_log.tail" ]]; then
            printf -- '- step1 failure tail: `%s`\n' "${step1_log.tail#$repo_root/}"
        fi
        if [[ -f "$step2_log.tail" ]]; then
            printf -- '- step2 failure tail: `%s`\n' "${step2_log.tail#$repo_root/}"
        fi
        if [[ -n "$step1_file" ]]; then
            printf -- '- step1 output: `%s`\n' "${step1_file#$repo_root/}"
        fi
        if [[ -n "$step2_file" ]]; then
            printf -- '- step2 output: `%s`\n' "${step2_file#$repo_root/}"
        fi
        printf -- '- validator target: `%s`\n' "$validator_target_label"
        printf -- '- odfvalidator: `%s`\n' "$odf_status"
        if [[ -f "$sample_dir/validators/odfvalidator.log" ]]; then
            printf -- '- odfvalidator log: `%s`\n' "${sample_dir#$repo_root/}/validators/odfvalidator.log"
        fi
        if [[ -f "$sample_dir/validators/odfvalidator.log.tail" ]]; then
            printf -- '- odfvalidator failure tail: `%s`\n' "${sample_dir#$repo_root/}/validators/odfvalidator.log.tail"
        fi
        printf -- '- officeotron: `%s`\n' "$officeotron_status"
        if [[ -f "$sample_dir/validators/officeotron.log" ]]; then
            printf -- '- officeotron log: `%s`\n' "${sample_dir#$repo_root/}/validators/officeotron.log"
        fi
        if [[ -f "$sample_dir/validators/officeotron.log.tail" ]]; then
            printf -- '- officeotron failure tail: `%s`\n' "${sample_dir#$repo_root/}/validators/officeotron.log.tail"
        fi
        printf -- '- verapdf: `%s`\n' "$verapdf_status"
        if [[ -f "$sample_dir/validators/verapdf.log" ]]; then
            printf -- '- verapdf log: `%s`\n' "${sample_dir#$repo_root/}/validators/verapdf.log"
        fi
        if [[ -f "$sample_dir/validators/verapdf.log.tail" ]]; then
            printf -- '- verapdf failure tail: `%s`\n' "${sample_dir#$repo_root/}/validators/verapdf.log.tail"
        fi
        if [[ ${#notes[@]} -gt 0 ]]; then
            printf -- '- notes: %s\n' "$(IFS='; '; printf '%s' "${notes[*]}")"
        fi
        printf '\n'
    } >> "$report_path"
done < "$run_dir/samples.tsv"

{
    printf '## Lane Summary\n\n'
    awk -F '\t' '
        {
            samples[$1]++
            if ($2 == "success") successes[$1]++
            else failures[$1]++
            if (!seen[$1]++) order[++count] = $1
        }
        END {
            for (i = 1; i <= count; i++) {
                lane = order[i]
                printf "- `%s`: samples=%d successes=%d failures=%d\n", lane, samples[lane] + 0, successes[lane] + 0, failures[lane] + 0
            }
        }
    ' "$results_tsv"
    printf '\n## Summary\n\n'
    printf -- '- samples: %s\n' "$sample_count"
    printf -- '- successes: %s\n' "$overall_success"
    printf -- '- failures: %s\n' "$overall_failure"
    printf -- '- run directory: `%s`\n' "${run_dir#$repo_root/}"
} >> "$report_path"

printf 'Wrote roundtrip report to %s\n' "$report_path"
