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
soffice_candidates=(
    "$repo_root/instdir/可圈办公.app/Contents/MacOS/soffice"
    "$repo_root/test-install/可圈办公.app/Contents/MacOS/soffice"
)
if [[ "$src_root" != "$repo_root" ]]; then
    soffice_candidates+=(
        "$src_root/test-install/可圈办公.app/Contents/MacOS/soffice"
        "$src_root/instdir/可圈办公.app/Contents/MacOS/soffice"
    )
fi

default_soffice_bin="${soffice_candidates[0]}"
for candidate in "${soffice_candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
        default_soffice_bin="$candidate"
        break
    fi
done
if [[ -n "${KDOFFICE_SOFFICE_BIN:-}" ]]; then
    soffice_bin="$KDOFFICE_SOFFICE_BIN"
elif [[ -n "${KDOFFICE_APP_BUNDLE:-}" ]]; then
    soffice_bin="$KDOFFICE_APP_BUNDLE/Contents/MacOS/soffice"
else
    soffice_bin="$default_soffice_bin"
fi
run_root_default="$repo_root/tmp/compatibility-runs"
format_arg="docx"
format_provided="0"
limit="1"
limit_provided="0"
run_name=""
report_path=""
manifest_path=""
strict_validators="0"
allow_extension_namespace="0"

usage() {
    cat <<'EOF'
Usage:
  compatibility-roundtrip.sh [options]

Options:
  --format <docx|xlsx|pptx|odt|ods|odp|doc|xls|ppt|pdf>
           Accepts a single format, a comma-separated list, or "smoke"
           (equivalent to docx,xlsx,pptx).
  --limit <n>
           Caps samples per format for auto-discovery. In manifest mode, this
           only applies when explicitly provided.
  --manifest <path>
           Curated TSV manifest. Columns: format<TAB>source-relative-path.
           An optional third column may describe the scenario/risk. Blank
           lines and lines beginning with "#" are ignored.
  --strict-validators
           Treat executed validator failures as roundtrip failures. Skipped validators
           still report readiness gaps but do not fail this command.
  --allow-extension-namespace
           In strict mode, treat ODF Validator `failed:extension-namespace` and
           `failed:lo-extension-dominant` as accepted alpha caveats. The first means
           every Error line references a LibreOffice extension namespace
           (loext/calcext/drawooo/officeooo/field). The second means at least 90%
           of Error lines do; the residual non-extension errors are tracked
           separately as alpha-acceptable serialization bugs and do not block
           strict mode. Other validator failures still fail strict mode.
  --run-name <name>
  --report <path>
  -h, --help

Environment:
  KDOFFICE_SRC_ROOT
           Source tree used for sample discovery and source-relative manifest paths.
           Defaults to repo_root/libreoffice-core when present, otherwise repo_root.
  KDOFFICE_APP_BUNDLE
           Explicit app bundle. Used to derive Contents/MacOS/soffice when
           KDOFFICE_SOFFICE_BIN is not set.
  KDOFFICE_SOFFICE_BIN
           Explicit soffice executable. Defaults to the first executable found in
           repo instdir, repo test-install, source-tree test-install, or source-tree
           instdir.

Examples:
  compatibility-roundtrip.sh --format docx --limit 2
  compatibility-roundtrip.sh --format docx,xlsx,pptx --limit 1
  compatibility-roundtrip.sh --format smoke --limit 1
EOF
}

require_option_value() {
    local option="$1"
    if [[ $# -lt 2 ]]; then
        printf 'Missing value for %s\n' "$option" >&2
        usage >&2
        exit 1
    fi
    if [[ "$2" == -* ]]; then
        printf 'Option %s requires a value\n' "$option" >&2
        usage >&2
        exit 1
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            require_option_value "$@"
            format_arg="$2"
            format_provided="1"
            shift 2
            ;;
        --limit)
            require_option_value "$@"
            limit="$2"
            limit_provided="1"
            shift 2
            ;;
        --manifest)
            require_option_value "$@"
            manifest_path="$2"
            shift 2
            ;;
        --strict-validators)
            strict_validators="1"
            shift
            ;;
        --allow-extension-namespace)
            allow_extension_namespace="1"
            shift
            ;;
        --run-name)
            require_option_value "$@"
            run_name="$2"
            shift 2
            ;;
        --report)
            require_option_value "$@"
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

if [[ -n "$manifest_path" ]]; then
    if [[ ! -f "$manifest_path" ]]; then
        printf 'Missing manifest: %s\n' "$manifest_path" >&2
        exit 1
    fi
    manifest_path="$(cd "$(dirname "$manifest_path")" && pwd)/$(basename "$manifest_path")"
fi

if [[ -z "$run_name" ]]; then
    sanitized_format="${format_csv//,/+}"
    if [[ -n "$manifest_path" ]]; then
        run_name="$(date '+%Y%m%d-%H%M%S')-manifest-$(basename "$manifest_path" .tsv)"
    else
        run_name="$(date '+%Y%m%d-%H%M%S')-$sanitized_format"
    fi
fi

if [[ ! "$run_name" =~ ^[A-Za-z0-9._+-]+$ ]]; then
    printf 'Invalid run name: %s\n' "$run_name" >&2
    exit 1
fi

if [[ -n "$manifest_path" && "$format_provided" == "0" ]]; then
    format_csv="manifest"
fi

run_dir="$run_root_default/$run_name"
mkdir -p "$run_dir"

if [[ -z "$report_path" ]]; then
    report_path="$run_dir/report.md"
fi

odf_validator="$repo_root/bin/odfvalidator.sh"
officeotron_validator="$repo_root/bin/officeotron.sh"
verapdf_validator="$repo_root/bin/verapdf.sh"

if [[ -n "$manifest_path" ]]; then
    python3 - "$src_root" "$format_csv" "$format_provided" "$limit" "$limit_provided" "$manifest_path" <<'PY' > "$run_dir/samples.tsv"
from collections import defaultdict
from pathlib import Path
import sys

src_root = Path(sys.argv[1]).resolve()
format_csv = sys.argv[2]
format_provided = sys.argv[3] == '1'
limit = int(sys.argv[4])
limit_provided = sys.argv[5] == '1'
manifest_path = Path(sys.argv[6])

requested_formats = [item.strip().lower().lstrip('.') for item in format_csv.split(',') if item.strip()]
allowed_formats = {'docx', 'xlsx', 'pptx', 'odt', 'ods', 'odp', 'doc', 'xls', 'ppt', 'pdf'}
if format_provided:
    unsupported = sorted(set(requested_formats) - allowed_formats)
    if unsupported:
        raise SystemExit(f'Unsupported format lane(s): {", ".join(unsupported)}')
    requested = set(requested_formats)
else:
    requested = set()

selected_by_lane: dict[str, int] = defaultdict(int)
seen: set[tuple[str, str]] = set()
selected: list[tuple[str, str, str]] = []

for line_number, raw_line in enumerate(manifest_path.read_text(encoding='utf-8').splitlines(), start=1):
    line = raw_line.strip()
    if not line or line.startswith('#'):
        continue

    columns = raw_line.split('\t')
    if len(columns) < 2:
        raise SystemExit(f'{manifest_path}:{line_number}: expected format<TAB>source-relative-path')

    lane = columns[0].strip().lower().lstrip('.')
    rel = columns[1].strip()
    note = columns[2].strip() if len(columns) >= 3 else ''
    if lane not in allowed_formats:
        raise SystemExit(f'{manifest_path}:{line_number}: unsupported format lane {lane!r}')
    if requested and lane not in requested:
        continue
    if not rel:
        raise SystemExit(f'{manifest_path}:{line_number}: empty source-relative-path')

    rel_path = Path(rel)
    if rel_path.is_absolute() or '..' in rel_path.parts:
        raise SystemExit(f'{manifest_path}:{line_number}: path must be source-relative and stay inside source root')

    source_path = (src_root / rel_path).resolve()
    if src_root not in (source_path, *source_path.parents):
        raise SystemExit(f'{manifest_path}:{line_number}: path must be source-relative and stay inside source root')
    if not source_path.is_file():
        raise SystemExit(f'{manifest_path}:{line_number}: sample does not exist: {rel}')
    if source_path.suffix.lower() != f'.{lane}':
        raise SystemExit(f'{manifest_path}:{line_number}: lane {lane!r} does not match sample extension {source_path.suffix!r}')

    key = (lane, rel)
    if key in seen:
        raise SystemExit(f'{manifest_path}:{line_number}: duplicate sample {lane} {rel}')
    seen.add(key)

    if limit_provided and selected_by_lane[lane] >= limit:
        continue
    selected_by_lane[lane] += 1
    selected.append((lane, rel, note))

if not selected:
    raise SystemExit(f'No manifest samples selected from {manifest_path}')

for lane, rel, note in selected:
    print(f'{lane}\t{rel}\t{note}')
PY
else
    python3 - "$src_root" "$format_csv" "$limit" <<'PY' > "$run_dir/samples.tsv"
from pathlib import Path
import sys

src_root = Path(sys.argv[1])
formats = [item.strip().lower().lstrip('.') for item in sys.argv[2].split(',') if item.strip()]
limit = int(sys.argv[3])
SCAN_ROOTS = (
    'sw/qa',
    'sc/qa',
    'sd/qa',
    'oox/qa',
    'filter/qa',
    'xmloff/qa',
    'chart2/qa',
    'sfx2/qa',
)
PREFERRED_ROOTS = {
    'docx': ('sw/qa', 'oox/qa', 'filter/qa', 'xmloff/qa', 'chart2/qa', 'sfx2/qa'),
    'doc': ('sw/qa', 'filter/qa', 'oox/qa', 'xmloff/qa', 'chart2/qa', 'sfx2/qa'),
    'odt': ('sw/qa', 'filter/qa', 'xmloff/qa', 'sfx2/qa'),
    'xlsx': ('sc/qa', 'oox/qa', 'filter/qa', 'xmloff/qa', 'chart2/qa', 'sfx2/qa'),
    'xls': ('sc/qa', 'filter/qa', 'oox/qa', 'xmloff/qa', 'chart2/qa', 'sfx2/qa'),
    'ods': ('sc/qa', 'filter/qa', 'xmloff/qa', 'sfx2/qa'),
    'pptx': ('sd/qa', 'oox/qa', 'filter/qa', 'xmloff/qa', 'chart2/qa', 'sfx2/qa'),
    'ppt': ('sd/qa', 'filter/qa', 'oox/qa', 'xmloff/qa', 'chart2/qa', 'sfx2/qa'),
    'odp': ('sd/qa', 'filter/qa', 'xmloff/qa', 'sfx2/qa'),
    'pdf': ('sw/qa', 'sc/qa', 'sd/qa', 'filter/qa', 'xmloff/qa', 'chart2/qa', 'sfx2/qa'),
}
ALLOWED_FORMATS = {'docx', 'xlsx', 'pptx', 'odt', 'ods', 'odp', 'doc', 'xls', 'ppt', 'pdf'}
EXCLUDED_SAMPLE_DIRS = {'fail'}

def is_smoke_candidate(item: str) -> bool:
    return EXCLUDED_SAMPLE_DIRS.isdisjoint(Path(item).parts)

def iter_matching_files(root: Path, needle: str):
    try:
        entries = sorted(root.iterdir(), key=lambda path: path.name)
    except OSError:
        return
    for entry in entries:
        try:
            if entry.is_dir():
                yield from iter_matching_files(entry, needle)
            elif entry.is_file() and entry.name.endswith(needle):
                yield entry
        except OSError:
            continue

def root_order_for(fmt: str):
    preferred = PREFERRED_ROOTS[fmt]
    return preferred + tuple(rel for rel in SCAN_ROOTS if rel not in preferred)

def select_samples(fmt: str):
    selected = []
    seen = set()
    needle = f'.{fmt}'
    for rel in root_order_for(fmt):
        for path in iter_matching_files(src_root / rel, needle):
            item = path.relative_to(src_root).as_posix()
            if item in seen or not is_smoke_candidate(item):
                continue
            selected.append(item)
            seen.add(item)
            if len(selected) >= limit:
                return selected
    return selected

for fmt in formats:
    if fmt not in ALLOWED_FORMATS:
        raise SystemExit(f'Unsupported format lane: {fmt}')
    for item in select_samples(fmt):
        print(f'{fmt}\t{item}\t')
PY
fi

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

sample_dir_name() {
    python3 - "$1" "$2" <<'PY'
from pathlib import Path
import hashlib
import sys

lane = sys.argv[1]
rel = sys.argv[2]
path = Path(rel)
stem = path.stem.replace(' ', '_')
digest = hashlib.sha1(rel.encode('utf-8')).hexdigest()[:10]
print(f"{lane}-{stem}-{digest}")
PY
}

find_single_output_file() {
    local dir_path="$1"
    local expected_ext="$2"

    python3 - "$dir_path" "$expected_ext" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
expected_ext = sys.argv[2].lower()
files = sorted(path for path in root.iterdir() if path.is_file())
matches = [path for path in files if path.suffix.lower() == f'.{expected_ext}']
if len(matches) == 1:
    print(matches[0])
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
lines = log_path.read_text(encoding='utf-8', errors='replace').splitlines()
out_path.write_text("\n".join(lines[-12:]) + ("\n" if lines else ""), encoding='utf-8')
PY
    fi
}

classify_odfvalidator_failure() {
    local log_path="$1"

    python3 - "$log_path" <<'PY'
from pathlib import Path
import re
import sys

log_path = Path(sys.argv[1])
text = log_path.read_text(encoding='utf-8', errors='replace') if log_path.exists() else ''
error_lines = [line for line in text.splitlines() if ' Error: ' in line]
if not error_lines:
    print('failed:unknown')
    raise SystemExit

extension_pattern = re.compile(r'(?:^|\W)(?:loext|calcext|drawooo|officeooo|field):')
ext_count = sum(1 for line in error_lines if extension_pattern.search(line))
total = len(error_lines)
if ext_count == total:
    print('failed:extension-namespace')
elif total > 0 and ext_count / total >= 0.90:
    print('failed:lo-extension-dominant')
else:
    print('failed')
PY
}

run_validator() {
    local validator_bin="$1"
    local target_file="$2"
    local log_path="$3"
    local status_path="$4"
    local validator_kind="${5:-generic}"

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
        elif [[ "$validator_kind" == "odfvalidator" ]]; then
            classify_odfvalidator_failure "$log_path" > "$status_path"
            summarize_log_tail "$log_path" "$log_path.tail"
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

write_fidelity_metrics() {
    local lane="$1"
    local input_file="$2"
    local step1_file="${3:-}"
    local step2_file="${4:-}"

    python3 - "$lane" "$input_file" "$step1_file" "$step2_file" <<'PY'
from pathlib import Path
from xml.etree import ElementTree as ET
import re
import sys
import zipfile

lane = sys.argv[1]
stage_paths = {
    "input": sys.argv[2],
    "step1": sys.argv[3],
    "step2": sys.argv[4],
}

NS = {
    "w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
    "ss": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "p": "http://schemas.openxmlformats.org/presentationml/2006/main",
    "text": "urn:oasis:names:tc:opendocument:xmlns:text:1.0",
    "table": "urn:oasis:names:tc:opendocument:xmlns:table:1.0",
    "draw": "urn:oasis:names:tc:opendocument:xmlns:drawing:1.0",
}

ORDER = [
    "exists",
    "size_bytes",
    "zip_package",
    "zip_entries",
    "paragraphs",
    "headings",
    "tables",
    "images",
    "sheets",
    "formulas",
    "slides",
    "shapes",
    "pictures",
    "media",
    "draw_pages",
    "draw_frames",
    "pdf_page_markers",
]

PRIMARY_KEYS = {
    "docx": ["paragraphs", "tables", "images"],
    "odt": ["paragraphs", "tables", "images"],
    "xlsx": ["sheets", "formulas"],
    "ods": ["sheets", "formulas"],
    "pptx": ["slides", "media"],
    "odp": ["draw_pages", "images"],
}


def q(ns_key: str, name: str) -> str:
    return f"{{{NS[ns_key]}}}{name}"


def count_tag(root: ET.Element | None, ns_key: str, name: str) -> int:
    if root is None:
        return 0
    target = q(ns_key, name)
    return sum(1 for item in root.iter() if item.tag == target)


def read_xml_from_zip(package: zipfile.ZipFile, name: str) -> ET.Element | None:
    try:
        return ET.fromstring(package.read(name))
    except Exception:
        return None


def add_ooxml_docx_metrics(package: zipfile.ZipFile, metrics: dict[str, object]) -> None:
    document = read_xml_from_zip(package, "word/document.xml")
    metrics["paragraphs"] = count_tag(document, "w", "p")
    metrics["tables"] = count_tag(document, "w", "tbl")
    metrics["images"] = len([name for name in package.namelist() if name.startswith("word/media/") and not name.endswith("/")])


def add_ooxml_xlsx_metrics(package: zipfile.ZipFile, metrics: dict[str, object]) -> None:
    workbook = read_xml_from_zip(package, "xl/workbook.xml")
    metrics["sheets"] = count_tag(workbook, "ss", "sheet")
    formulas = 0
    for name in package.namelist():
        if not re.fullmatch(r"xl/worksheets/sheet\d+\.xml", name):
            continue
        sheet = read_xml_from_zip(package, name)
        formulas += count_tag(sheet, "ss", "f")
    metrics["formulas"] = formulas
    metrics["media"] = len([name for name in package.namelist() if name.startswith("xl/media/") and not name.endswith("/")])


def add_ooxml_pptx_metrics(package: zipfile.ZipFile, metrics: dict[str, object]) -> None:
    slide_names = [name for name in package.namelist() if re.fullmatch(r"ppt/slides/slide\d+\.xml", name)]
    metrics["slides"] = len(slide_names)
    shapes = 0
    pictures = 0
    for name in slide_names:
        slide = read_xml_from_zip(package, name)
        shapes += count_tag(slide, "p", "sp")
        pictures += count_tag(slide, "p", "pic")
    metrics["shapes"] = shapes
    metrics["pictures"] = pictures
    metrics["media"] = len([name for name in package.namelist() if name.startswith("ppt/media/") and not name.endswith("/")])


def add_odf_metrics(package: zipfile.ZipFile, metrics: dict[str, object]) -> None:
    content = read_xml_from_zip(package, "content.xml")
    metrics["paragraphs"] = count_tag(content, "text", "p")
    metrics["headings"] = count_tag(content, "text", "h")
    metrics["tables"] = count_tag(content, "table", "table")
    metrics["sheets"] = metrics["tables"]
    metrics["draw_pages"] = count_tag(content, "draw", "page")
    metrics["draw_frames"] = count_tag(content, "draw", "frame")
    metrics["images"] = count_tag(content, "draw", "image")
    formulas = 0
    if content is not None:
        formula_attr = q("table", "formula")
        formulas = sum(1 for item in content.iter() if formula_attr in item.attrib)
    metrics["formulas"] = formulas


def add_pdf_metrics(path: Path, metrics: dict[str, object]) -> None:
    try:
        data = path.read_bytes()
    except OSError:
        return
    metrics["pdf_page_markers"] = len(re.findall(rb"/Type\s*/Page\b", data))


def metrics_for(path_text: str) -> dict[str, object]:
    if not path_text:
        return {"exists": "not-run"}

    path = Path(path_text)
    if not path.exists():
        return {"exists": "missing"}

    metrics: dict[str, object] = {
        "exists": "yes",
        "size_bytes": path.stat().st_size,
    }
    suffix = path.suffix.lower().lstrip(".")

    if zipfile.is_zipfile(path):
        metrics["zip_package"] = "yes"
        try:
            with zipfile.ZipFile(path) as package:
                metrics["zip_entries"] = len(package.namelist())
                if suffix == "docx":
                    add_ooxml_docx_metrics(package, metrics)
                elif suffix == "xlsx":
                    add_ooxml_xlsx_metrics(package, metrics)
                elif suffix == "pptx":
                    add_ooxml_pptx_metrics(package, metrics)
                elif suffix in {"odt", "ods", "odp"}:
                    add_odf_metrics(package, metrics)
        except Exception as exc:
            metrics["package_error"] = type(exc).__name__
    else:
        metrics["zip_package"] = "no"
        if suffix == "pdf":
            add_pdf_metrics(path, metrics)

    return metrics


def compact(metrics: dict[str, object]) -> str:
    parts = [f"{key}={metrics[key]}" for key in ORDER if key in metrics]
    for key in sorted(metrics):
        if key not in ORDER:
            parts.append(f"{key}={metrics[key]}")
    return ", ".join(parts) if parts else "not-available"


def ratio_text(current: int | None, baseline: int | None) -> str:
    if baseline is None or baseline <= 0 or current is None:
        return "not-available"
    return f"{(current / baseline) * 100:.1f}%"


def int_metric(metrics: dict[str, object], key: str) -> int | None:
    value = metrics.get(key)
    return value if isinstance(value, int) else None


metrics_by_stage = {stage: metrics_for(path) for stage, path in stage_paths.items()}

for stage in ("input", "step1", "step2"):
    print(f"- {stage} metrics: {compact(metrics_by_stage[stage])}")

warnings: list[str] = []
input_size = int_metric(metrics_by_stage["input"], "size_bytes")
step1_size = int_metric(metrics_by_stage["step1"], "size_bytes")
step2_size = int_metric(metrics_by_stage["step2"], "size_bytes")
print(f"- size sanity: step1/input={ratio_text(step1_size, input_size)}, step2/input={ratio_text(step2_size, input_size)}")

if step2_size == 0:
    warnings.append("step2 output has zero bytes")
if input_size and step1_size:
    intermediate_ratio = step1_size / input_size
    if intermediate_ratio > 20 and step1_size > 5 * 1024 * 1024:
        warnings.append("step1 output is more than 20x input size")
if input_size and step2_size:
    final_ratio = step2_size / input_size
    if final_ratio < 0.05:
        warnings.append("step2 output is less than 5% of input size")
    elif final_ratio > 20:
        warnings.append("step2 output is more than 20x input size")

primary_keys = PRIMARY_KEYS.get(lane, [])
structural_parts = []
for key in primary_keys:
    before = int_metric(metrics_by_stage["input"], key)
    after = int_metric(metrics_by_stage["step2"], key)
    if before is None or after is None:
        continue
    structural_parts.append(f"{key}={before}->{after}")
    if before > 0 and after == 0:
        warnings.append(f"{key} dropped to zero after roundtrip")

print(f"- structure sanity: {', '.join(structural_parts) if structural_parts else 'not-available'}")
print(f"- fidelity warnings: {'; '.join(warnings) if warnings else 'none'}")
PY
}

overall_success=0
overall_failure=0
results_tsv="$run_dir/results.tsv"
validator_gaps_tsv="$run_dir/validator-readiness-gaps.tsv"
: > "$results_tsv"
: > "$validator_gaps_tsv"

{
    printf '# Compatibility Roundtrip Report\n\n'
    printf 'Run name: %s\n' "$run_name"
    printf 'Format selection: %s\n' "$format_csv"
    if [[ -n "$manifest_path" ]]; then
        printf 'Manifest: %s\n' "$manifest_path"
    else
        printf 'Manifest: auto-discovery\n'
    fi
    printf 'Strict validators: %s\n' "$strict_validators"
    printf 'Generated at: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf 'Source root: %s\n' "$src_root"
    printf 'Packaged app: %s\n\n' "$soffice_bin"
    printf '## Samples\n\n'
    while IFS=$'\t' read -r lane rel scenario_note; do
        if [[ -n "${scenario_note:-}" ]]; then
            printf -- '- `%s` — `%s` — %s\n' "$lane" "$rel" "$scenario_note"
        else
            printf -- '- `%s` — `%s`\n' "$lane" "$rel"
        fi
    done < "$run_dir/samples.tsv"
    printf '\n## Results\n\n'
} > "$report_path"

while IFS=$'\t' read -r lane rel scenario_note; do
    read -r first_target second_target <<< "$(lane_targets "$lane")"

    sample_name="$(basename "$rel")"
    sample_dir="$run_dir/$(sample_dir_name "$lane" "$rel")"
    mkdir -p "$sample_dir/step1" "$sample_dir/step2" "$sample_dir/validators"
    cp "$src_root/$rel" "$sample_dir/"
    input_file="$sample_dir/$sample_name"
    step1_log="$sample_dir/step1.log"
    step2_log="$sample_dir/step2.log"
    conversion_result="success"
    result="success"
    notes=()

    step1_file=""
    step2_file=""
    validator_target=""
    validator_target_label="not-applicable"

    if [[ "$lane" == "pdf" ]]; then
        validator_target="$input_file"
        validator_target_label="input-pdf"
        printf 'skipped: pdf lane validates input directly, not export/roundtrip output\n' > "$step1_log"
        printf 'skipped: pdf lane validates input directly, not export/roundtrip output\n' > "$step2_log"
        notes+=("pdf lane validates input directly, not export/roundtrip output")
    else
        if ! "$soffice_bin" --headless --convert-to "$first_target" --outdir "$sample_dir/step1" "$input_file" > "$step1_log" 2>&1; then
            conversion_result="failure"
            result="failure"
            notes+=("step1 convert failed")
            summarize_log_tail "$step1_log" "$step1_log.tail"
        fi

        if [[ "$result" == "success" ]]; then
            step1_file="$(find_single_output_file "$sample_dir/step1" "$first_target")"
            if [[ -z "$step1_file" ]]; then
                conversion_result="failure"
                result="failure"
                notes+=("step1 output missing or ambiguous")
            fi
        fi

        if [[ "$result" == "success" ]]; then
            if ! "$soffice_bin" --headless --convert-to "$second_target" --outdir "$sample_dir/step2" "$step1_file" > "$step2_log" 2>&1; then
                conversion_result="failure"
                result="failure"
                notes+=("step2 convert failed")
                summarize_log_tail "$step2_log" "$step2_log.tail"
            fi
        fi

        if [[ "$result" == "success" ]]; then
            step2_file="$(find_single_output_file "$sample_dir/step2" "$second_target")"
            if [[ -z "$step2_file" ]]; then
                conversion_result="failure"
                result="failure"
                notes+=("step2 output missing or ambiguous")
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
                run_validator "$odf_validator" "$validator_target" "$sample_dir/validators/odfvalidator.log" "$sample_dir/validators/odfvalidator.status" odfvalidator
                run_validator "$officeotron_validator" "$validator_target" "$sample_dir/validators/officeotron.log" "$sample_dir/validators/officeotron.status"
                odf_status="$(get_status "$sample_dir/validators/odfvalidator.status")"
                officeotron_status="$(get_status "$sample_dir/validators/officeotron.status")"
                ;;
            pdf)
                run_validator "$verapdf_validator" "$validator_target" "$sample_dir/validators/verapdf.log" "$sample_dir/validators/verapdf.status"
                verapdf_status="$(get_status "$sample_dir/validators/verapdf.status")"
                ;;
        esac
    fi

    for validator_pair in "odfvalidator=$odf_status" "officeotron=$officeotron_status" "verapdf=$verapdf_status"; do
        if [[ "${validator_pair#*=}" == skipped:* && "${validator_pair#*=}" != "skipped:not-applicable" ]]; then
            printf '%s\t%s\t%s\n' "$lane" "${validator_pair%%=*}" "${validator_pair#*=}" >> "$validator_gaps_tsv"
        fi
    done

    if [[ "$strict_validators" == "1" ]]; then
        if [[ "${scenario_note:-}" == *"alpha-known-defect"* ]]; then
            notes+=("strict skipped: scenario note marks alpha-known-defect")
        else
            for validator_status in "$odf_status" "$officeotron_status" "$verapdf_status"; do
                if [[ "$validator_status" == failed* ]]; then
                    if [[ "$allow_extension_namespace" == "1" ]] && \
                       { [[ "$validator_status" == "failed:extension-namespace" ]] || \
                         [[ "$validator_status" == "failed:lo-extension-dominant" ]]; }; then
                        notes+=("odfvalidator $validator_status accepted as alpha caveat")
                        continue
                    fi
                    result="failure"
                    notes+=("validator failed in strict mode")
                    break
                fi
            done
        fi
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
        if [[ -n "${scenario_note:-}" ]]; then
            printf -- '- scenario note: %s\n' "$scenario_note"
        fi
        printf -- '- first target: `%s`\n' "$first_target"
        printf -- '- second target: `%s`\n' "$second_target"
        printf -- '- conversion result: **%s**\n' "$conversion_result"
        printf -- '- result: **%s**\n' "$result"
        printf -- '- step1 log: `%s`\n' "${step1_log#$repo_root/}"
        printf -- '- step2 log: `%s`\n' "${step2_log#$repo_root/}"
        if [[ -f "$step1_log.tail" ]]; then
            printf -- '- step1 failure tail: `%s`\n' "${step1_log#$repo_root/}.tail"
        fi
        if [[ -f "$step2_log.tail" ]]; then
            printf -- '- step2 failure tail: `%s`\n' "${step2_log#$repo_root/}.tail"
        fi
        if [[ -n "$step1_file" ]]; then
            printf -- '- step1 output: `%s`\n' "${step1_file#$repo_root/}"
        fi
        if [[ -n "$step2_file" ]]; then
            printf -- '- step2 output: `%s`\n' "${step2_file#$repo_root/}"
        fi
        printf -- '- fidelity mode: `advisory-package-heuristics`\n'
        write_fidelity_metrics "$lane" "$input_file" "$step1_file" "$step2_file"
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
    if [[ -s "$validator_gaps_tsv" ]]; then
        printf -- '- validator readiness gaps: `'
        awk -F '\t' '
            {
                key = $2 "=" $3
                if (!seen[key]++) ordered[++count] = key
            }
            END {
                for (i = 1; i <= count; i++) {
                    printf "%s%s", (i == 1 ? "" : ", "), ordered[i]
                }
            }
        ' "$validator_gaps_tsv"
        printf '`\n'
        printf -- '- validator readiness evidence: run `bin/validator-readiness.sh --strict tmp/validator-readiness-strict.md` and resolve `docs/compatibility/validator-assets-release-packet.md` before beta/release claims.\n'
    else
        printf -- '- validator readiness gaps: none observed in selected samples\n'
    fi
    printf -- '- validator note: sample successes mean conversion survived only; skipped validators and classified validator failures are alpha caveats, not quality passes. `--strict-validators` fails executed validator failures, while `bin/validator-readiness.sh --strict tmp/validator-readiness-strict.md` is still required before beta/release claims.\n'
    printf -- '- run directory: `%s`\n' "${run_dir#$repo_root/}"
} >> "$report_path"

printf 'Wrote roundtrip report to %s\n' "$report_path"

if [[ "$overall_failure" -gt 0 ]]; then
    exit 1
fi
