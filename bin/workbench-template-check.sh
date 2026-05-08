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
output_path="${1:-$repo_root/tmp/workbench-template-check.md}"

usage() {
    cat <<'EOF'
Usage:
  workbench-template-check.sh [output-file]

Verifies the scenario-workbench templates across source directories,
generated template archives, and installed runtime template files.
If no output file is provided, the report is written to:
  tmp/workbench-template-check.md
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

mkdir -p "$(dirname "$output_path")"

python3 - "$repo_root" "$src_root" "$output_path" <<'PY'
from pathlib import Path
from datetime import datetime
import sys

repo_root = Path(sys.argv[1])
src_root = Path(sys.argv[2])
output_path = Path(sys.argv[3])

templates = [
    ("工作汇报", "offimisc/Work_Report_CN", "offimisc/Work_Report_CN.ott"),
    ("会议纪要", "offimisc/Meeting_Minutes_CN", "offimisc/Meeting_Minutes_CN.ott"),
    ("通知", "officorr/Notice_CN", "officorr/Notice_CN.ott"),
    ("项目方案", "offimisc/Project_Plan_CN", "offimisc/Project_Plan_CN.ott"),
    ("演示提纲", "offimisc/PPT_Outline_CN", "offimisc/PPT_Outline_CN.ott"),
    ("预算总览", "spreadsheets/Budget_CN", "spreadsheets/Budget_CN.ots"),
    ("销售跟进", "spreadsheets/Sales_Tracker_CN", "spreadsheets/Sales_Tracker_CN.ots"),
    ("项目排期", "spreadsheets/Project_Schedule_CN", "spreadsheets/Project_Schedule_CN.ots"),
    ("商务路演", "presnt/Business_Pitch_CN", "presnt/Business_Pitch_CN.otp"),
    ("项目汇报", "presnt/Project_Report_CN", "presnt/Project_Report_CN.otp"),
    ("教学课件", "presnt/Teaching_Courseware_CN", "presnt/Teaching_Courseware_CN.otp"),
]

required_parts = ["mimetype", "META-INF/manifest.xml", "content.xml", "meta.xml", "styles.xml"]

def present(path: Path) -> str:
    return "present" if path.exists() else "missing"

def source_dir_for(rel_dir: str) -> Path:
    return src_root / "extras/source/templates" / rel_dir

def built_archive_for(rel_archive: str) -> Path:
    candidates = [
        repo_root / "workdir/CustomTarget/extras/source/templates" / rel_archive,
        src_root / "workdir/CustomTarget/extras/source/templates" / rel_archive,
    ]
    return next((path for path in candidates if path.exists()), candidates[0])

def runtime_archive_for(rel_archive: str) -> Path:
    candidates = [
        repo_root / "instdir/可圈office.app/Contents/Resources/template/common" / rel_archive,
        repo_root / "test-install/可圈office.app/Contents/Resources/template/common" / rel_archive,
        src_root / "test-install/可圈office.app/Contents/Resources/template/common" / rel_archive,
        src_root / "instdir/可圈office.app/Contents/Resources/template/common" / rel_archive,
    ]
    return next((path for path in candidates if path.exists()), candidates[0])

lines = []
lines.append("# Scenario Workbench Template Check")
lines.append("")
lines.append(f"Generated at: {datetime.now().astimezone().strftime('%Y-%m-%d %H:%M:%S %z')}")
lines.append(f"Repo root: {repo_root}")
lines.append(f"Source root: {src_root}")
lines.append("")
lines.append("## Template matrix")
lines.append("")
lines.append("| Scenario | Source dir | Required parts | Built archive | Runtime archive |")
lines.append("| --- | --- | --- | --- | --- |")

missing = []
for title, rel_dir, rel_archive in templates:
    src_dir = source_dir_for(rel_dir)
    built = built_archive_for(rel_archive)
    runtime = runtime_archive_for(rel_archive)
    missing_parts = [part for part in required_parts if not (src_dir / part).exists()]
    if not src_dir.exists():
        missing.append(f"source dir: {rel_dir}")
    if missing_parts:
        missing.append(f"source parts for {rel_dir}: {', '.join(missing_parts)}")
    if not built.exists():
        missing.append(f"built archive: {rel_archive}")
    if not runtime.exists():
        missing.append(f"runtime archive: {rel_archive}")
    parts_state = "present" if not missing_parts else "missing: " + ", ".join(missing_parts)
    lines.append(
        f"| {title} | `{rel_dir}` {present(src_dir)} | {parts_state} | "
        f"`{rel_archive}` {present(built)} | `{rel_archive}` {present(runtime)} |"
    )

lines.append("")
lines.append("## Result")
lines.append("")
if missing:
    lines.append("Status: **fail**")
    lines.append("")
    for item in missing:
        lines.append(f"- {item}")
else:
    lines.append("Status: **pass**")
    lines.append("")
    lines.append("All 11 scenario templates have source parts, generated archives, and installed runtime files.")

output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

if missing:
    raise SystemExit(1)
PY

printf 'Wrote workbench template report to %s\n' "$output_path"
