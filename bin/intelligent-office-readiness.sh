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
output_path="${1:-$repo_root/tmp/intelligent-office-readiness.md}"

usage() {
    cat <<'EOF'
Usage:
  intelligent-office-readiness.sh [output-file]

Reports readiness for the intelligent-office track: one-click formatting,
Chinese diagnostics, and plugin-mounted AI/translation capabilities.
This is advisory evidence; it does not mutate source files.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

mkdir -p "$(dirname "$output_path")"

python3 - "$repo_root" "$src_root" "$output_path" <<'PY'
from pathlib import Path
import subprocess
import sys

repo_root = Path(sys.argv[1])
src_root = Path(sys.argv[2])
output_path = Path(sys.argv[3])

checks = [
    ("architecture", "Intelligent office architecture plan", repo_root / "AUTORESEARCH_INTELLIGENT_OFFICE_ARCHITECTURE.md"),
    ("architecture", "Intelligent office contracts", repo_root / "docs/architecture/intelligent-office-contracts.md"),
    ("architecture", "Intelligent implementation boundaries", repo_root / "docs/architecture/intelligent-office-implementation-boundaries.md"),
    ("architecture", "Engine capability platform architecture", repo_root / "docs/architecture/engine-capability-platform-architecture.md"),
    ("architecture", "Engine capability upgrade plan", repo_root / "docs/product/engine-capability-upgrade-plan.md"),
    ("architecture", "Plugin manifest schema", repo_root / "docs/schemas/kqoffice-plugin.schema.json"),
    ("architecture", "Diagnostic schema", repo_root / "docs/schemas/intelligent-diagnostic.schema.json"),
    ("architecture", "Presentation outline schema", repo_root / "docs/schemas/presentation-outline.schema.json"),
    ("architecture", "Intelligent contract fixture gate", repo_root / "bin/intelligent-contract-fixtures.sh"),
    ("architecture", "Intelligent contract fixtures", repo_root / "docs/schemas/fixtures"),
    ("architecture", "Plugin manifest validator", repo_root / "bin/plugin-manifest-validator.sh"),
    ("control-plane", "V2 dashboard script", repo_root / "bin/v2-upgrade-dashboard.sh"),
    ("control-plane", "P0 gate script", repo_root / "bin/v2-p0-gates.sh"),
    ("quality", "Workbench accessibility static gate", repo_root / "bin/workbench-accessibility-check.sh"),
    ("quality", "Workbench accessibility checklist", repo_root / "docs/accessibility/workbench-accessibility-checklist.md"),
    ("quality", "Compatibility round-trip smoke", repo_root / "bin/compatibility-roundtrip.sh"),
    ("quality", "Source hygiene report", repo_root / "bin/source-hygiene-report.sh"),
    ("command", "Generic command registry", src_root / "officecfg/registry/data/org/openoffice/Office/UI/GenericCommands.xcu"),
    ("command", "Writer command registry", src_root / "officecfg/registry/data/org/openoffice/Office/UI/WriterCommands.xcu"),
    ("command", "Calc command registry", src_root / "officecfg/registry/data/org/openoffice/Office/UI/CalcCommands.xcu"),
    ("command", "Impress command registry", src_root / "officecfg/registry/data/org/openoffice/Office/UI/DrawImpressCommands.xcu"),
    ("plugin", "Addons registry", src_root / "officecfg/registry/data/org/openoffice/Office/Addons.xcu"),
    ("plugin", "Protocol handler registry", src_root / "officecfg/registry/data/org/openoffice/Office/ProtocolHandler.xcu"),
    ("plugin", "Extension module", src_root / "extensions"),
    ("plugin", "Scripting module", src_root / "scripting"),
    ("diagnostics", "Linguistic module", src_root / "lingucomponent"),
    ("diagnostics", "Edit engine module", src_root / "editeng"),
    ("diagnostics", "Shared drawing/formatting module", src_root / "svx"),
    ("diagnostics", "Writer preview analyzer API", src_root / "sw/inc/IntelligentWriterAnalyzer.hxx"),
    ("diagnostics", "Writer preview analyzer implementation", src_root / "sw/source/core/doc/IntelligentWriterAnalyzer.cxx"),
    ("formatting", "Writer source", src_root / "sw"),
    ("formatting", "Calc source", src_root / "sc"),
    ("formatting", "Impress source", src_root / "sd"),
    ("ui", "Start Center controller", src_root / "sfx2/source/dialog/backingwindow.cxx"),
    ("ui", "Start Center UI", src_root / "sfx2/uiconfig/ui/startcenter.ui"),
    ("test", "Writer QA", src_root / "sw/qa"),
    ("test", "Calc QA", src_root / "sc/qa"),
    ("test", "Impress QA", src_root / "sd/qa"),
    ("test", "Shared UI tests", src_root / "uitest"),
]

phases = [
    ("P0", "Control plane", "Architecture, readiness reports, schema, and advisory checks."),
    ("P1", "Formatting MVP", "Preview-only Writer formatting analyzer, then undoable apply."),
    ("P2", "Diagnostics MVP", "Chinese issue list with severity, location, and one-by-one fixes."),
    ("P3", "Plugin MVP", "Manifest-driven local plugins before external AI providers."),
    ("M3", "Capability platform", "Contract spine, registry stub, preview/apply safety, evidence, and service-mode enforcement."),
]

analyzer_present = (
    (src_root / "sw/inc/IntelligentWriterAnalyzer.hxx").exists()
    and (src_root / "sw/source/core/doc/IntelligentWriterAnalyzer.cxx").exists()
)

risks = [
    "Writer preview analyzer exists and must remain read-only until undo-grouped apply is proven."
    if analyzer_present
    else "No implemented one-click formatting analyzer is detected yet.",
    "Plugin and diagnostic contracts plus a local/offline manifest validator exist, but no runtime loader is implemented yet."
    if analyzer_present
    else "Plugin and diagnostic contracts plus a local/offline manifest validator exist, but no runtime loader/analyzer is implemented yet.",
    "Engine capability platform docs exist, but preview action, apply plan, evidence record, provider request, and capability registry contracts still need schema fixtures.",
    "AI/translation provider code must remain optional and failure-safe.",
    "Core import/export filters should not be changed without failing samples.",
]


def state(path: Path) -> str:
    return "present" if path.exists() else "missing"


def git_value(*args: str) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(repo_root), *args],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except subprocess.CalledProcessError:
        return "unknown"


created_at = subprocess.check_output(["date", "+%Y-%m-%d %H:%M:%S %z"], text=True).strip()
present = sum(1 for _, _, path in checks if path.exists())

lines: list[str] = []
lines.append("# Intelligent Office Readiness")
lines.append("")
lines.append(f"Generated at: {created_at}")
lines.append(f"Branch: {git_value('rev-parse', '--abbrev-ref', 'HEAD')}")
lines.append(f"HEAD: {git_value('rev-parse', '--short', 'HEAD')}")
lines.append(f"Repo root: {repo_root}")
lines.append(f"Source root: {src_root} ({state(src_root)})")
lines.append("")
lines.append("## Summary")
lines.append("")
lines.append(f"- Surface checks present: {present}/{len(checks)}")
lines.append("- Status: **advisory**")
lines.append("- Current lane: first Writer preview-only analyzer implemented" if analyzer_present else "- Current lane: control plane before core editor mutations")
lines.append("")
lines.append("## Surface Map")
lines.append("")
lines.append("| Category | Surface | State |")
lines.append("| --- | --- | --- |")
for category, label, path in checks:
    rel = path
    try:
        rel = path.relative_to(repo_root)
    except ValueError:
        try:
            rel = path.relative_to(src_root)
        except ValueError:
            pass
    lines.append(f"| {category} | `{rel}` | {state(path)} |")
lines.append("")
lines.append("## Phase TODO")
lines.append("")
lines.append("| Phase | Target | Exit Criteria |")
lines.append("| --- | --- | --- |")
for phase, target, criteria in phases:
    lines.append(f"| {phase} | {target} | {criteria} |")
lines.append("")
lines.append("## Current Gaps")
lines.append("")
for item in risks:
    lines.append(f"- {item}")
lines.append("")
lines.append("## Next Safe Commands")
lines.append("")
lines.append("- `bin/intelligent-office-readiness.sh tmp/intelligent-office-readiness.md`")
lines.append("- `bin/intelligent-contract-fixtures.sh tmp/intelligent-contract-fixtures.md`")
lines.append("- `bin/plugin-manifest-validator.sh --self-test --report tmp/plugin-manifest-validator.md`")
lines.append("- `bin/source-hygiene-report.sh tmp/source-hygiene-report.md`")
lines.append("- `bin/v2-upgrade-dashboard.sh tmp/v2-upgrade-dashboard.md`")
lines.append("- `bin/v2-p0-gates.sh <run-name>`")

output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Wrote intelligent office readiness report to {output_path}")
PY
