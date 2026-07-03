#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -n "${KDOFFICE_SRC_ROOT:-}" ]]; then
    src_root_default="$(cd -P "$KDOFFICE_SRC_ROOT" && pwd)"
elif [[ -d "$repo_root/libreoffice-core" ]]; then
    src_root_default="$(cd -P "$repo_root/libreoffice-core" && pwd)"
else
    src_root_default="$(cd -P "$repo_root" && pwd)"
fi
output_path="${1:-$repo_root/tmp/compatibility-lab-baseline.md}"

usage() {
    cat <<'EOF'
Usage:
  compatibility-lab.sh [output-file]

Generates a compatibility-lab baseline report from the real source tree.
If no output file is provided, the report is written to:
  tmp/compatibility-lab-baseline.md
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

mkdir -p "$(dirname "$output_path")"

python3 - "$repo_root" "$src_root_default" "$output_path" <<'PY'
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
import sys

repo_root = Path(sys.argv[1])
src_root = Path(sys.argv[2])
output_path = Path(sys.argv[3])

scan_roots = [
    "sw/qa",
    "sc/qa",
    "sd/qa",
    "oox/qa",
    "filter/qa",
    "xmloff/qa",
    "chart2/qa",
    "sfx2/qa",
]
preferred_roots = {
    ".docx": ["sw/qa", "oox/qa", "filter/qa", "xmloff/qa", "chart2/qa", "sfx2/qa"],
    ".doc": ["sw/qa", "filter/qa", "oox/qa", "xmloff/qa", "chart2/qa", "sfx2/qa"],
    ".odt": ["sw/qa", "filter/qa", "xmloff/qa", "sfx2/qa"],
    ".xlsx": ["sc/qa", "oox/qa", "filter/qa", "xmloff/qa", "chart2/qa", "sfx2/qa"],
    ".xls": ["sc/qa", "filter/qa", "oox/qa", "xmloff/qa", "chart2/qa", "sfx2/qa"],
    ".ods": ["sc/qa", "filter/qa", "xmloff/qa", "sfx2/qa"],
    ".pptx": ["sd/qa", "oox/qa", "filter/qa", "xmloff/qa", "chart2/qa", "sfx2/qa"],
    ".ppt": ["sd/qa", "filter/qa", "oox/qa", "xmloff/qa", "chart2/qa", "sfx2/qa"],
    ".odp": ["sd/qa", "filter/qa", "xmloff/qa", "sfx2/qa"],
    ".pdf": ["sw/qa", "sc/qa", "sd/qa", "filter/qa", "xmloff/qa", "chart2/qa", "sfx2/qa"],
}
fallback_roots = [
    "sw/qa",
    "sc/qa",
    "sd/qa",
    "sfx2/qa",
    "chart2/qa",
    "oox/qa",
    "filter/qa",
    "xmloff/qa",
]
allowed_exts = [".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".odt", ".ods", ".odp", ".pdf"]
preferred_order = [".docx", ".xlsx", ".pptx", ".doc", ".xls", ".ppt", ".odt", ".ods", ".odp", ".pdf"]

samples = []
root_counts = Counter()
ext_counts = Counter()
by_ext = defaultdict(list)
resolved_roots = []

for rel in scan_roots:
    root = src_root / rel
    if not root.exists():
        continue
    resolved_roots.append(rel)
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        suffix = path.suffix.lower()
        if suffix not in allowed_exts:
            continue
        rel_path = path.relative_to(src_root).as_posix()
        samples.append(rel_path)
        ext_counts[suffix] += 1
        root_counts[rel] += 1
        by_ext[suffix].append(rel_path)

samples.sort()
for key in by_ext:
    by_ext[key].sort()

def representative_for(suffix: str, limit: int = 3) -> list[str]:
    selected = []
    seen = set()
    def is_smoke_candidate(item: str) -> bool:
        return "fail" not in item.split("/")
    for rel in preferred_roots.get(suffix, fallback_roots):
        matches = [
            item for item in by_ext.get(suffix, [])
            if item.startswith(f"{rel}/") and is_smoke_candidate(item)
        ]
        for item in matches:
            if item not in seen:
                selected.append(item)
                seen.add(item)
            if len(selected) >= limit:
                return selected
    for item in by_ext.get(suffix, []):
        if item not in seen and is_smoke_candidate(item):
            selected.append(item)
            seen.add(item)
        if len(selected) >= limit:
            return selected
    return selected

app_candidates = [
    repo_root / "instdir/可圈办公.app/Contents/MacOS/soffice",
    repo_root / "test-install/可圈办公.app/Contents/MacOS/soffice",
]
if src_root != repo_root:
    app_candidates.extend([
        src_root / "test-install/可圈办公.app/Contents/MacOS/soffice",
        src_root / "instdir/可圈办公.app/Contents/MacOS/soffice",
    ])
app_path = next((path for path in app_candidates if path.exists()), app_candidates[0])
validators = [
    "bin/odfvalidator.sh",
    "bin/officeotron.sh",
    "bin/verapdf.sh",
]

lines = []
lines.append("# 可圈办公 Compatibility Lab Baseline")
lines.append("")
lines.append(f"Generated at: {datetime.now().astimezone().strftime('%Y-%m-%d %H:%M:%S %z')}")
lines.append(f"Repo root: {repo_root}")
lines.append(f"Source root: {src_root}")
lines.append(f"Packaged app executable: {'present' if app_path.exists() else 'missing'}")
lines.append("")
lines.append("## Scan scope")
lines.append("")
for rel in resolved_roots:
    lines.append(f"- `{rel}`")
lines.append("")
lines.append("## Format inventory")
lines.append("")
lines.append("| Format | Count |")
lines.append("| --- | ---: |")
for suffix in preferred_order:
    lines.append(f"| `{suffix}` | {ext_counts.get(suffix, 0)} |")
lines.append(f"| **Total** | **{len(samples)}** |")
lines.append("")
lines.append("## Root distribution")
lines.append("")
lines.append("| Root | Count |")
lines.append("| --- | ---: |")
for rel, count in root_counts.most_common():
    lines.append(f"| `{rel}` | {count} |")
lines.append("")
lines.append("## Representative smoke pack")
lines.append("")
for suffix in preferred_order:
    picked = representative_for(suffix, 3)
    if not picked:
        continue
    lines.append(f"### `{suffix}`")
    for rel_path in picked:
        lines.append(f"- `{rel_path}`")
    lines.append("")
lines.append("## Validation entry points")
lines.append("")
for rel in validators:
    state = "present" if (repo_root / rel).exists() else "missing"
    lines.append(f"- `{rel}` — {state}")
lines.append("")
lines.append("## First round-trip command template")
lines.append("")
lines.append("```bash")
lines.append(f'"{app_path}" --headless --convert-to odt --outdir /tmp <sample.docx>')
lines.append(f'"{app_path}" --headless --convert-to docx --outdir /tmp <sample.odt>')
lines.append("bin/odfvalidator.sh /tmp/<file>")
lines.append("bin/verapdf.sh /tmp/<file.pdf>")
lines.append("```")
lines.append("")
lines.append("## Round checklist")
lines.append("")
lines.append("1. Pick one format lane: DOCX, XLSX, PPTX, or ODF.")
lines.append("2. Choose a smoke pack from the representative samples above.")
lines.append("3. Declare exact import, save, export, and validation commands.")
lines.append("4. Record visible regressions and successful round-trips.")
lines.append("5. Keep the round only if fidelity or reliability improves without new failures.")
lines.append("")
output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

printf 'Wrote compatibility lab report to %s\n' "$output_path"
