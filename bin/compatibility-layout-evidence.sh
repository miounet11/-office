#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$repo_root/tmp/compatibility-runs/v2-smoke-fidelity-manifest-final"
report_path="$repo_root/tmp/compatibility-layout-evidence.md"
lanes="docx,xlsx,pptx"

usage() {
    cat <<'EOF'
Usage:
  compatibility-layout-evidence.sh [options]

Options:
  --run-dir <path>   Existing compatibility-roundtrip run directory.
  --lanes <csv>      Format lanes to seed. Default: docx,xlsx,pptx.
  --report <path>    Output report path. Default: tmp/compatibility-layout-evidence.md.
  -h, --help

Builds a non-rendered layout evidence seed from existing compatibility
roundtrip artifacts. It does not launch LibreOffice; use it while GUI/build
resources are owned by another agent.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --run-dir)
            run_dir="$2"
            shift 2
            ;;
        --lanes)
            lanes="$2"
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

mkdir -p "$(dirname "$report_path")"

write_failure_report() {
    local reason="$1"
    local detail="$2"
    local action="$3"

    cat > "$report_path" <<EOF
# Compatibility Layout Evidence Seed

Generated at: $(date '+%Y-%m-%d %H:%M:%S %z')
Run directory: \`$run_dir\`
Requested lanes: \`$lanes\`

## Result

Status: **fail**

- reason: \`$reason\`
- detail: $detail
- action: $action

## Limitations

No layout proxy or visual evidence is available from this run. Do not use this report to claim compatibility layout coverage.
EOF
}

if [[ ! -d "$run_dir" ]]; then
    detail="Missing compatibility run directory: $run_dir"
    write_failure_report "missing-run-directory" "$detail" "Run the compatibility roundtrip gate first, then rerun this layout evidence seed."
    printf '%s\n' "$detail" >&2
    exit 1
fi

if [[ ! -f "$run_dir/samples.tsv" ]]; then
    detail="Missing compatibility samples file: $run_dir/samples.tsv"
    write_failure_report "missing-samples-file" "$detail" "Rerun compatibility-roundtrip so samples.tsv and conversion artifacts exist before this evidence pass."
    printf '%s\n' "$detail" >&2
    exit 1
fi

python3 - "$repo_root" "$run_dir" "$lanes" "$report_path" <<'PY'
from __future__ import annotations

from datetime import datetime
from pathlib import Path
from xml.etree import ElementTree as ET
import hashlib
import re
import sys
import zipfile

repo_root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2]).resolve()
requested_lanes = [item.strip().lower().lstrip(".") for item in sys.argv[3].split(",") if item.strip()]
report_path = Path(sys.argv[4])

allowed = {"docx", "xlsx", "pptx"}
unsupported = sorted(set(requested_lanes) - allowed)
if unsupported:
    raise SystemExit(f"Unsupported layout evidence lane(s): {', '.join(unsupported)}")
if not requested_lanes:
    raise SystemExit("No layout evidence lanes requested")

NS = {
    "w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
    "ss": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "p": "http://schemas.openxmlformats.org/presentationml/2006/main",
    "text": "urn:oasis:names:tc:opendocument:xmlns:text:1.0",
    "table": "urn:oasis:names:tc:opendocument:xmlns:table:1.0",
    "draw": "urn:oasis:names:tc:opendocument:xmlns:drawing:1.0",
}

COMPARE_KEYS = {
    "docx": ("paragraphs", "tables", "images", "sections"),
    "xlsx": ("sheets", "formulas", "charts", "media"),
    "pptx": ("slides", "shapes", "pictures", "media"),
}


def rel(path: Path | None) -> str:
    if path is None:
        return "missing"
    try:
        return path.resolve().relative_to(repo_root).as_posix()
    except ValueError:
        return path.as_posix()


def q(ns_key: str, name: str) -> str:
    return f"{{{NS[ns_key]}}}{name}"


def count_tag(root: ET.Element | None, ns_key: str, name: str) -> int:
    if root is None:
        return 0
    target = q(ns_key, name)
    return sum(1 for item in root.iter() if item.tag == target)


def read_xml(package: zipfile.ZipFile, name: str) -> ET.Element | None:
    try:
        return ET.fromstring(package.read(name))
    except Exception:
        return None


def sample_dir_name(lane: str, source_rel: str) -> str:
    path = Path(source_rel)
    stem = path.stem.replace(" ", "_")
    digest = hashlib.sha1(source_rel.encode("utf-8")).hexdigest()[:10]
    return f"{lane}-{stem}-{digest}"


def single_file(root: Path, suffix: str) -> Path | None:
    if not root.is_dir():
        return None
    matches = sorted(path for path in root.iterdir() if path.is_file() and path.suffix.lower() == f".{suffix}")
    return matches[0] if len(matches) == 1 else None


def compact(metrics: dict[str, object], keys: tuple[str, ...] | None = None) -> str:
    preferred = ("exists", "size_bytes", "zip_entries") + (keys or ())
    parts = [f"{key}={metrics[key]}" for key in preferred if key in metrics]
    for key in sorted(metrics):
        if key not in preferred:
            parts.append(f"{key}={metrics[key]}")
    return ", ".join(parts) if parts else "not-available"


def add_docx(package: zipfile.ZipFile, metrics: dict[str, object]) -> None:
    document = read_xml(package, "word/document.xml")
    metrics["paragraphs"] = count_tag(document, "w", "p")
    metrics["tables"] = count_tag(document, "w", "tbl")
    metrics["sections"] = count_tag(document, "w", "sectPr")
    metrics["images"] = len([name for name in package.namelist() if name.startswith("word/media/") and not name.endswith("/")])
    if document is not None:
        page_sizes = [node for node in document.iter() if node.tag == q("w", "pgSz")]
        if page_sizes:
            last = page_sizes[-1]
            width = last.attrib.get(q("w", "w"), "unknown")
            height = last.attrib.get(q("w", "h"), "unknown")
            metrics["last_page_twips"] = f"{width}x{height}"


def add_xlsx(package: zipfile.ZipFile, metrics: dict[str, object]) -> None:
    workbook = read_xml(package, "xl/workbook.xml")
    metrics["sheets"] = count_tag(workbook, "ss", "sheet")
    formulas = 0
    for name in package.namelist():
        if re.fullmatch(r"xl/worksheets/sheet\d+\.xml", name):
            formulas += count_tag(read_xml(package, name), "ss", "f")
    metrics["formulas"] = formulas
    metrics["charts"] = len([name for name in package.namelist() if name.startswith("xl/charts/") and name.endswith(".xml")])
    metrics["media"] = len([name for name in package.namelist() if name.startswith("xl/media/") and not name.endswith("/")])


def add_pptx(package: zipfile.ZipFile, metrics: dict[str, object]) -> None:
    slides = [name for name in package.namelist() if re.fullmatch(r"ppt/slides/slide\d+\.xml", name)]
    metrics["slides"] = len(slides)
    shapes = 0
    pictures = 0
    for name in slides:
        slide = read_xml(package, name)
        shapes += count_tag(slide, "p", "sp")
        pictures += count_tag(slide, "p", "pic")
    metrics["shapes"] = shapes
    metrics["pictures"] = pictures
    metrics["media"] = len([name for name in package.namelist() if name.startswith("ppt/media/") and not name.endswith("/")])


def add_odf(package: zipfile.ZipFile, metrics: dict[str, object]) -> None:
    content = read_xml(package, "content.xml")
    metrics["paragraphs"] = count_tag(content, "text", "p")
    metrics["headings"] = count_tag(content, "text", "h")
    metrics["tables"] = count_tag(content, "table", "table")
    metrics["draw_pages"] = count_tag(content, "draw", "page")
    metrics["draw_frames"] = count_tag(content, "draw", "frame")
    metrics["images"] = count_tag(content, "draw", "image")
    formula_attr = q("table", "formula")
    metrics["formulas"] = sum(1 for item in content.iter() if formula_attr in item.attrib) if content is not None else 0


def metrics_for(path: Path | None) -> dict[str, object]:
    if path is None or not path.exists():
        return {"exists": "missing"}
    metrics: dict[str, object] = {
        "exists": "yes",
        "size_bytes": path.stat().st_size,
    }
    if not zipfile.is_zipfile(path):
        metrics["zip_package"] = "no"
        return metrics
    metrics["zip_package"] = "yes"
    try:
        with zipfile.ZipFile(path) as package:
            names = package.namelist()
            metrics["zip_entries"] = len(names)
            suffix = path.suffix.lower().lstrip(".")
            if suffix == "docx":
                add_docx(package, metrics)
            elif suffix == "xlsx":
                add_xlsx(package, metrics)
            elif suffix == "pptx":
                add_pptx(package, metrics)
            elif suffix in {"odt", "ods", "odp"}:
                add_odf(package, metrics)
    except Exception as exc:
        metrics["package_error"] = type(exc).__name__
    return metrics


def delta_text(before: dict[str, object], after: dict[str, object], lane: str) -> str:
    parts = []
    for key in COMPARE_KEYS[lane]:
        lhs = before.get(key, "n/a")
        rhs = after.get(key, "n/a")
        parts.append(f"{key}:{lhs}->{rhs}")
    return ", ".join(parts)


def visual_pdf_path(item: dict[str, object], stage: str) -> Path:
    source_rel = str(item["source_rel"])
    stem = Path(source_rel).stem.replace(" ", "_")
    digest = hashlib.sha1(source_rel.encode("utf-8")).hexdigest()[:10]
    return repo_root / "tmp" / "compatibility-visual-evidence" / run_dir.name / f"{item['lane']}-{stem}-{digest}-{stage}.pdf"


samples: list[tuple[str, str, str]] = []
for raw in (run_dir / "samples.tsv").read_text(encoding="utf-8").splitlines():
    if not raw.strip():
        continue
    cols = raw.split("\t")
    if len(cols) < 2:
        continue
    lane = cols[0].strip().lower().lstrip(".")
    source_rel = cols[1].strip()
    note = cols[2].strip() if len(cols) >= 3 else ""
    samples.append((lane, source_rel, note))

statuses: list[str] = []
results_path = run_dir / "results.tsv"
if results_path.exists():
    for raw in results_path.read_text(encoding="utf-8").splitlines():
        cols = raw.split("\t")
        if len(cols) >= 2:
            statuses.append(cols[1].strip())

selected = []
seen_lanes: set[str] = set()
for index, (lane, source_rel, note) in enumerate(samples):
    if lane not in requested_lanes or lane in seen_lanes:
        continue
    status = statuses[index] if index < len(statuses) else "unknown"
    sample_dir = run_dir / sample_dir_name(lane, source_rel)
    first_ext = {"docx": "odt", "xlsx": "ods", "pptx": "odp"}[lane]
    input_file = single_file(sample_dir, lane)
    step1_file = single_file(sample_dir / "step1", first_ext)
    step2_file = single_file(sample_dir / "step2", lane)
    if input_file is None or step1_file is None or step2_file is None:
        continue
    selected.append(
        {
            "lane": lane,
            "source_rel": source_rel,
            "note": note,
            "status": status,
            "dir": sample_dir,
            "input": input_file,
            "step1": step1_file,
            "step2": step2_file,
            "input_metrics": metrics_for(input_file),
            "step1_metrics": metrics_for(step1_file),
            "step2_metrics": metrics_for(step2_file),
        }
    )
    seen_lanes.add(lane)

def write_failure(reason: str, detail: str, action: str) -> None:
    lines = [
        "# Compatibility Layout Evidence Seed",
        "",
        f"Generated at: {datetime.now().astimezone().strftime('%Y-%m-%d %H:%M:%S %z')}",
        f"Run directory: `{rel(run_dir)}`",
        f"Requested lanes: `{','.join(requested_lanes)}`",
        "",
        "## Result",
        "",
        "Status: **fail**",
        "",
        f"- reason: `{reason}`",
        f"- detail: {detail}",
        f"- action: {action}",
        "",
        "## Limitations",
        "",
        "No layout proxy or visual evidence is available from this run. Do not use this report to claim compatibility layout coverage.",
    ]
    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


missing = [lane for lane in requested_lanes if lane not in seen_lanes]
if missing:
    write_failure(
        "missing-lane-artifacts",
        f"Missing successful compatibility artifact for lane(s): {', '.join(missing)}",
        "Run `bin/compatibility-roundtrip.sh --manifest docs/compatibility/smoke-manifest.tsv --run-name v2-smoke-fidelity-manifest-final` and then rerun this evidence seed.",
    )
    raise SystemExit(f"Missing successful compatibility artifact for lane(s): {', '.join(missing)}")

artifact_failures = []
for item in selected:
    for key in ("input", "step1", "step2"):
        if item[key] is None:
            artifact_failures.append(f"{item['lane']} missing {key} artifact")
if artifact_failures:
    write_failure(
        "missing-artifacts",
        "; ".join(artifact_failures),
        "Rerun compatibility-roundtrip and inspect the per-sample artifact directories before claiming layout evidence.",
    )
    raise SystemExit("; ".join(artifact_failures))

lines = [
    "# Compatibility Layout Evidence Seed",
    "",
    f"Generated at: {datetime.now().astimezone().strftime('%Y-%m-%d %H:%M:%S %z')}",
    f"Run directory: `{rel(run_dir)}`",
    f"Requested lanes: `{','.join(requested_lanes)}`",
    "",
    "## Evidence Definition",
    "",
    "This seed records durable layout proxy evidence from existing roundtrip artifacts. It compares package/XML structure before and after the roundtrip, and records the intermediate ODF artifact path for follow-up rendering.",
    "",
    "It intentionally does not launch LibreOffice, export PDFs, take screenshots, or claim pixel fidelity. Those visual checks remain the next step after the active Clavue UI/build run releases the shared install tree.",
    "",
    "If this report is built from a strict-validator compatibility run, sample status may be `failure` even when conversion artifacts exist. In that case this report uses the conversion artifacts for layout-proxy evidence while preserving the failed compatibility status.",
    "",
    "## Seed Summary",
    "",
    "| Lane | Source sample | Scenario | Input artifact | Step1 artifact | Step2 artifact | Layout comparison |",
    "| --- | --- | --- | --- | --- | --- | --- |",
]

for item in selected:
    lane = item["lane"]
    lines.append(
        "| "
        + " | ".join(
            [
                f"`{lane}`",
                f"`{item['source_rel']}`",
                item["note"] or "",
                f"`{rel(item['input'])}`",
                f"`{rel(item['step1'])}`",
                f"`{rel(item['step2'])}`",
                delta_text(item["input_metrics"], item["step2_metrics"], lane),
            ]
        )
        + " |"
    )

lines.extend(["", "## Evidence Records", ""])

for item in selected:
    lane = item["lane"]
    compare_keys = COMPARE_KEYS[lane]
    lines.extend(
        [
            f"### `{lane}`: `{item['source_rel']}`",
            "",
            f"- scenario: {item['note'] or 'not specified'}",
            f"- compatibility status: `{item['status']}`",
            f"- input: `{rel(item['input'])}`",
            f"- step1 intermediate: `{rel(item['step1'])}`",
            f"- step2 roundtrip: `{rel(item['step2'])}`",
            f"- input metrics: {compact(item['input_metrics'], compare_keys)}",
            f"- step1 metrics: {compact(item['step1_metrics'])}",
            f"- step2 metrics: {compact(item['step2_metrics'], compare_keys)}",
            f"- layout proxy comparison: {delta_text(item['input_metrics'], item['step2_metrics'], lane)}",
            "",
        ]
    )

lines.extend(
    [
        "## Visual Evidence Readiness",
        "",
        "The rows below identify deterministic artifact pairs that are ready for a later rendered PDF/screenshot comparison pass. The proposed PDF paths are not generated by this script; they reserve stable evidence locations for the next command that is allowed to launch LibreOffice rendering.",
        "",
        "| Lane | Scenario | Source artifact | Roundtrip artifact | Proposed source PDF | Proposed roundtrip PDF |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
)

for item in selected:
    lines.append(
        "| "
        + " | ".join(
            [
                f"`{item['lane']}`",
                item["note"] or "not specified",
                f"`{rel(item['input'])}`",
                f"`{rel(item['step2'])}`",
                f"`{rel(visual_pdf_path(item, 'source'))}`",
                f"`{rel(visual_pdf_path(item, 'roundtrip'))}`",
            ]
        )
        + " |"
    )

lines.extend(
    [
        "",
        "## Limitations",
        "",
        "- This is layout proxy evidence, not visual proof.",
        "- It can catch missing packages, dropped sheets/slides, missing media, and obvious structural regressions.",
        "- It cannot prove font fidelity, exact pagination, chart rendering, shape geometry, animation behavior, formula recalculation correctness, or screen paint quality.",
        "- The next visual pass should export the selected input/step2 files to PDF or screenshots when no Clavue-owned GUI/build run is active.",
        "",
        "## Result",
        "",
        "Status: **pass**",
        "",
        "At least one DOCX, XLSX, and PPTX sample has a durable layout evidence record with artifact paths, structural comparison, and explicit limitations.",
    ]
)

report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Wrote compatibility layout evidence report to {report_path}")
PY
