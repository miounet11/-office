#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_path="${1:-$repo_root/tmp/v2-upgrade-dashboard.md}"
if [[ "$output_path" != /* ]]; then
    output_path="$repo_root/$output_path"
fi
if [[ -n "${KDOFFICE_SRC_ROOT:-}" ]]; then
    src_root_default="$(cd -P "$KDOFFICE_SRC_ROOT" && pwd)"
elif [[ -d "$repo_root/libreoffice-core" ]]; then
    src_root_default="$(cd -P "$repo_root/libreoffice-core" && pwd)"
else
    src_root_default="$(cd -P "$repo_root" && pwd)"
fi

usage() {
    cat <<'EOF'
Usage:
  v2-upgrade-dashboard.sh [output-file]

Generates a V2 upgrade dashboard for the current 可圈办公 tree.
If no output file is provided, the report is written to:
  tmp/v2-upgrade-dashboard.md
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

mkdir -p "$(dirname "$output_path")"

branch_name="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unknown')"
head_commit="$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
status_count="$(git -C "$repo_root" status --short 2>/dev/null | wc -l | tr -d ' ')"
source_status_count="$(
    git -C "$repo_root" status --short -- \
        . \
        ':(exclude).clavue/**' \
        ':(exclude)workdir/**' \
        ':(exclude)instdir/**' \
        ':(exclude)test-install/**' \
        ':(exclude)tmp/**' \
        ':(exclude)autom4te.cache/**' \
        ':(exclude)config.log' \
        ':(exclude)config.status' \
        ':(exclude)config_host.mk' \
        ':(exclude)config_host/**' \
        ':(exclude)autogen.lastrun' \
        ':(exclude)autogen.lastrun.bak' \
        2>/dev/null | wc -l | tr -d ' '
)"
created_at="$(date '+%Y-%m-%d %H:%M:%S %z')"

python3 - "$repo_root" "$src_root_default" "$output_path" "$branch_name" "$head_commit" "$status_count" "$source_status_count" "$created_at" <<'PY'
from collections import Counter, defaultdict
from pathlib import Path
import sys

repo_root = Path(sys.argv[1])
src_root = Path(sys.argv[2]).resolve()
output_path = Path(sys.argv[3])
branch_name = sys.argv[4]
head_commit = sys.argv[5]
status_count = sys.argv[6]
source_status_count = sys.argv[7]
created_at = sys.argv[8]

roadmap_files = [
    "AUTORESEARCH_EXECUTION_TODOLIST.md",
    "2.md",
    "AUTORESEARCH_V2_UPGRADE_PLAN.md",
    "AUTORESEARCH_WORLD_CLASS_QUALITY_ROADMAP.md",
    "AUTORESEARCH_MATURE_OFFICE_PRODUCT_MODEL.md",
    "docs/product/mature-office-product-requirements.md",
    "docs/product/next-stage-development-plan.md",
    "docs/product/engine-capability-upgrade-plan.md",
    "docs/product/presentation-outline-contract-review.md",
    "docs/product/china-blank-document-default-policy.md",
    "docs/product/service-mode-policy.md",
    "docs/product/m2-07-presentation-outline-builder-review.md",
    "AUTORESEARCH_PRODUCT_REFACTOR_AUDIT.md",
    "AUTORESEARCH_OFFICE_ROUNDS.md",
    "AUTORESEARCH_INTELLIGENT_OFFICE_ARCHITECTURE.md",
    "docs/architecture/intelligent-office-implementation-boundaries.md",
    "docs/architecture/engine-capability-platform-architecture.md",
    "docs/architecture/engine-capability-source-entry-audit.md",
    "docs/architecture/engine-capability-registry-stub-design.md",
    "docs/schemas/presentation-outline.schema.json",
    "docs/accessibility/workbench-accessibility-checklist.md",
    "docs/compatibility/corpus-expansion-plan.md",
]

script_files = [
    "bin/source-status.sh",
    "bin/source-hygiene-report.sh",
    "bin/intelligent-office-readiness.sh",
    "bin/intelligent-contract-fixtures.sh",
    "bin/plugin-manifest-validator.sh",
    "bin/quality-baseline.sh",
    "bin/workbench-template-check.sh",
    "bin/workbench-template-smoke.sh",
    "bin/workbench-accessibility-check.sh",
    "bin/gui-smoke-timing.sh",
    "bin/packaged-screenshots.sh",
    "bin/workbench-a11y-live.sh",
    "bin/pdf-confidence-check.sh",
    "bin/fetch-validator-assets.sh",
    "bin/fetch-zh-cn-translations.sh",
    "bin/build-zh-cn.sh",
    "bin/clavue-passive-monitor.sh",
    "bin/validator-readiness.sh",
    "bin/compatibility-manifest-audit.sh",
    "bin/compatibility-lab.sh",
    "bin/compatibility-roundtrip.sh",
    "bin/compatibility-layout-evidence.sh",
    "bin/compatibility-visual-evidence.sh",
    "bin/v2-p0-gates.sh",
    "bin/v2-beta-gates.sh",
    "bin/v2-upgrade-dashboard.sh",
]

ui_test_targets = [
    ("Workbench scenario buttons", "uitest/UITest_workbench_smoke.mk", "gmake UITest_workbench_smoke"),
    ("Workbench scenario test module", "uitest/workbench_tests/start_center_scenarios.py", "gmake UITest_workbench_smoke"),
]

workflow_surfaces = {
    "Workbench": [
        "sfx2/source/dialog/backingwindow.cxx",
        "sfx2/uiconfig/ui/startcenter.ui",
        "cui/source/dialogs/welcomedlg.cxx",
    ],
    "Unified commands": [
        "officecfg/registry/data/org/openoffice/Office/UI/ToolbarMode.xcu",
        "sw/uiconfig/swriter/ui/notebookbar.ui",
        "sc/uiconfig/scalc/ui/notebookbar.ui",
        "sd/uiconfig/simpress/ui/notebookbar.ui",
    ],
    "Compatibility": [
        "oox",
        "filter",
        "xmloff",
        "sw/qa",
        "sc/qa",
        "sd/qa",
    ],
    "AI/PPT generation": [
        "docs/schemas/presentation-outline.schema.json",
        "docs/schemas/fixtures/presentation-outline.valid.json",
        "docs/schemas/fixtures/presentation-outline.invalid.json",
        "sw/source/uibase/app/docsh2.cxx",
        "sd/source/ui/app/sdmod1.cxx",
        "sd/source/ui",
        "sd/source/core",
    ],
    "Writer diagnostics": [
        "sw/inc/IntelligentWriterAnalyzer.hxx",
        "sw/source/core/doc/IntelligentWriterAnalyzer.cxx",
        "sw/qa/core/uwriter.cxx",
    ],
    "China defaults": [
        "officecfg/registry/data/org/openoffice/VCL.xcu",
        "officecfg/registry/data/org/openoffice/Office/Writer.xcu",
        "officecfg/registry/data/org/openoffice/Office/Calc.xcu",
        "officecfg/registry/data/org/openoffice/Office/Impress.xcu",
    ],
}

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
compat_exts = [".docx", ".xlsx", ".pptx", ".doc", ".xls", ".ppt", ".odt", ".ods", ".odp", ".pdf"]
preferred_exts = [".docx", ".xlsx", ".pptx", ".doc", ".xls", ".ppt", ".odt", ".ods", ".odp", ".pdf"]

def state(path: Path) -> str:
    return "present" if path.exists() else "missing"

ext_counts = Counter()
root_counts = Counter()
by_ext = defaultdict(list)
if src_root.exists():
    for rel_root in scan_roots:
        root = src_root / rel_root
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if not path.is_file():
                continue
            suffix = path.suffix.lower()
            if suffix not in compat_exts:
                continue
            rel = path.relative_to(src_root).as_posix()
            ext_counts[suffix] += 1
            root_counts[rel_root] += 1
            by_ext[suffix].append(rel)
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
    repo_root / "instdir/可圈办公.app",
    repo_root / "test-install/可圈办公.app",
]
if src_root != repo_root:
    app_candidates.extend([
        src_root / "test-install/可圈办公.app",
        src_root / "instdir/可圈办公.app",
    ])
app_bundle = next((path for path in app_candidates if (path / "Contents/MacOS/soffice").exists()), app_candidates[0])
app_bin = app_bundle / "Contents/MacOS/soffice"

v2_gates = [
    ("Core editing", "Create/edit/save/reopen/export/print-preview smoke remains green."),
    ("Compatibility", "DOCX/XLSX/PPTX smoke packs have recorded round-trip results."),
    ("Workbench", "Scenario templates and Start Center scenario buttons have automated smoke coverage; manual visual/a11y review still required."),
    ("AI safety", "AI output is editable and failed calls do not alter documents unexpectedly."),
    ("Offline", "Core product remains useful without login, cloud, or AI provider."),
    ("Service-policy enforcement", "Wrapper gates reject private/cloud plugin manifests until signing, consent, service-mode enforcement, allowlist/update/quarantine policy, auditability, and failure isolation exist; this is not runtime/provider readiness."),
    ("Packaging", "Runnable local install is verified separately from release signing."),
]

writer_analyzer_present = (
    (src_root / "sw/inc/IntelligentWriterAnalyzer.hxx").exists()
    and (src_root / "sw/source/core/doc/IntelligentWriterAnalyzer.cxx").exists()
)

next_rounds = [
    (
        "M2-1",
        "Presentation outline contract review",
        "done: docs/product/presentation-outline-contract-review.md",
    ),
    ("M2-02", "China blank-document default policy", "done: docs/product/china-blank-document-default-policy.md"),
    ("M2-03", "GUI timing budgets", "bin/gui-smoke-timing.sh --mode startcenter --wait 12 --timeout 20 --max-elapsed 20 --run-name <name>"),
    ("M2-04", "Writer analyzer hardening", "make CppunitTest_sw_uwriter"),
    ("M2-05", "Compatibility visual/layout evidence seed", "bin/compatibility-layout-evidence.sh --report tmp/compatibility-layout-evidence.md"),
    ("M2-06", "Workbench accessibility evidence packet", "done: evidence packet plus UITest; live assistive-tech review remains beta blocker"),
    ("M2-07", "Presentation outline builder implementation review", "done: CppunitTest_sd_misc_tests plus Codex read-only review"),
    ("M2-08", "Run current alpha P0 gates", "bin/v2-p0-gates.sh <run-name>"),
    ("P2-04", "Service-mode policy for offline/local/private/cloud", "done: docs/product/service-mode-policy.md plus wrapper enforcement; runtime/provider readiness still blocked"),
    ("BETA-03", "Source hygiene release packet", "bin/source-hygiene-report.sh tmp/source-hygiene-report.md; strict remains failing until operator resolves report buckets"),
    ("BETA-04", "Validator assets readiness", "docs/compatibility/validator-assets-release-packet.md; strict remains failing until Officeotron and veraPDF exact assets are trusted and present"),
    ("M3-01", "Engine capability source-entry audit", "Clavue source-entry audit only; no runtime plugin/provider/UI command/document mutation"),
    ("P2-05", "Promote beta hard gates", "bin/v2-beta-gates.sh <run-name> (expected to fail until validator asset provenance, strict hygiene buckets, and live a11y evidence are complete)"),
]

beta_blockers = [
    "Compatibility evidence is stronger after a curated 27-sample manifest and advisory fidelity metrics, but it is still not a representative DOCX/XLSX/PPTX matrix.",
    "Validator readiness remains beta-blocked: ODF Validator is locally acquired and checksum-verified, but Officeotron 0.8.8 and veraPDF CLI 1.29.0 exact assets still need trusted project/vendor provenance before skipped validators can count as passes.",
    "Startup/open/close feel now has advisory timing-budget evidence for Start Center, but not full open/save/export/close responsiveness budgets.",
    "Chinese-first coverage is strong in curated surfaces, but broad advanced dialogs, menus, help, and docs still need targeted passes.",
    "Workbench accessibility has an M2-06 evidence packet plus static/UITest evidence, but live keyboard traversal, Enter/Space activation, VoiceOver, high-contrast, resize, and missing-template fallback review remain beta blockers.",
    "Strict source hygiene remains a beta blocker, but `docs/product/source-hygiene-release-packet.md` and `tmp/source-hygiene-report.md` now separate source review, generated/local cleanup, config/autoconf artifacts, install/test/release artifacts, and human-decision items.",
    "Intelligent formatting, diagnostics, plugin manifests, and PPT outlines have first local fixtures; the Impress builder seed is internal/test-only and accepted, but UI/provider/runtime work remains blocked.",
    "M3-02 engine capability contract fixtures now cover document snapshots, preview actions, apply plans, capability registry entries, provider requests, and evidence records; runtime registry/provider/plugin/UI/apply implementation remains blocked.",
    "Runtime plugin loading, provider integration, and signing policy are not implemented; wrapper service-policy enforcement now rejects private/cloud manifests, but runtime/provider readiness remains blocked until signing, consent, service-mode enforcement, allowlist/update/quarantine policy, auditability, and failure isolation exist.",
]

lines = []
lines.append("# 可圈办公 V2 Upgrade Dashboard")
lines.append("")
lines.append(f"Generated at: {created_at}")
lines.append(f"Branch: {branch_name}")
lines.append(f"HEAD: {head_commit}")
lines.append(f"Working tree entries: {status_count}")
lines.append(f"Source-focused entries: {source_status_count}")
lines.append(f"Repo root: {repo_root}")
lines.append(f"Source root: {src_root} ({state(src_root)})")
lines.append("")
lines.append("## V2 control objective")
lines.append("")
lines.append("Turn 可圈办公 into a task-first, compatibility-trustworthy, AI-assisted office product while preserving reliable desktop editing and offline usability.")
lines.append("")
lines.append("## Planning and operating sources")
lines.append("")
lines.append("| File | State |")
lines.append("| --- | --- |")
for rel in roadmap_files:
    lines.append(f"| `{rel}` | {state(repo_root / rel)} |")
lines.append("")
lines.append("## Automation entry points")
lines.append("")
lines.append("| Script | State |")
lines.append("| --- | --- |")
for rel in script_files:
    lines.append(f"| `{rel}` | {state(repo_root / rel)} |")
lines.append("")
lines.append("## Automated workflow coverage")
lines.append("")
lines.append("| Coverage | Evidence | Verification command |")
lines.append("| --- | --- | --- |")
for name, rel, command in ui_test_targets:
    lines.append(f"| {name} | `{rel}` {state(src_root / rel)} | `{command}` |")
coverage_checks = [
    ("Scenario template package check", "bin/workbench-template-check.sh", "bin/workbench-template-check.sh tmp/workbench-template-check.md"),
    ("Scenario template runtime smoke", "bin/workbench-template-smoke.sh", "bin/workbench-template-smoke.sh --run-name <name>"),
    ("Workbench accessibility static check", "bin/workbench-accessibility-check.sh", "bin/workbench-accessibility-check.sh tmp/workbench-accessibility-check.md"),
    ("Fresh-profile GUI launch smoke", "bin/gui-smoke-timing.sh", "bin/gui-smoke-timing.sh --mode startcenter --wait 12 --timeout 20 --max-elapsed 20 --run-name <name>"),
    ("Packaged-app screenshot capture (R5 evidence)", "bin/packaged-screenshots.sh", "bin/packaged-screenshots.sh"),
    ("Live accessibility 24-item interactive review", "bin/workbench-a11y-live.sh", "bin/workbench-a11y-live.sh"),
    ("PDF confidence trio (PDF/A + page stability + CJK fonts)", "bin/pdf-confidence-check.sh", "bin/pdf-confidence-check.sh --run-name <name>"),
    ("Validator asset acquisition (Officeotron + veraPDF)", "bin/fetch-validator-assets.sh", "bin/fetch-validator-assets.sh"),
    ("zh-CN translations acquisition (LibreOffice upstream PO)", "bin/fetch-zh-cn-translations.sh", "bin/fetch-zh-cn-translations.sh"),
    ("zh-CN build wrapper (ASCII workdir watchdog + registry patch)", "bin/build-zh-cn.sh", "bin/build-zh-cn.sh"),
    ("Clavue passive coordination monitor", "bin/clavue-passive-monitor.sh", "bin/clavue-passive-monitor.sh tmp/clavue-passive-monitor.md"),
    ("Validator readiness", "bin/validator-readiness.sh", "bin/validator-readiness.sh tmp/validator-readiness.md"),
    ("Compatibility manifest audit", "bin/compatibility-manifest-audit.sh", "bin/compatibility-manifest-audit.sh --manifest docs/compatibility/smoke-manifest.tsv"),
    ("Source/generated hygiene", "bin/source-hygiene-report.sh", "bin/source-hygiene-report.sh tmp/source-hygiene-report.md"),
    ("Intelligent office readiness", "bin/intelligent-office-readiness.sh", "bin/intelligent-office-readiness.sh tmp/intelligent-office-readiness.md"),
    ("Intelligent contract fixtures", "bin/intelligent-contract-fixtures.sh", "bin/intelligent-contract-fixtures.sh tmp/intelligent-contract-fixtures.md"),
    ("Service-policy enforcement for plugin manifests", "bin/plugin-manifest-validator.sh", "bin/plugin-manifest-validator.sh --self-test --report tmp/plugin-manifest-validator.md"),
    ("Auto-discovered Office-format smoke", "bin/compatibility-roundtrip.sh", "bin/compatibility-roundtrip.sh --format smoke --limit <n> --run-name <name>"),
    ("Curated Office-format smoke manifest with fidelity heuristics", "docs/compatibility/smoke-manifest.tsv", "bin/compatibility-roundtrip.sh --manifest docs/compatibility/smoke-manifest.tsv --run-name <name>"),
    ("Compatibility visual/layout evidence seed", "bin/compatibility-layout-evidence.sh", "bin/compatibility-layout-evidence.sh --report tmp/compatibility-layout-evidence.md"),
    ("Compatibility PDF/PNG visual evidence (P2-01)", "bin/compatibility-visual-evidence.sh", "bin/compatibility-visual-evidence.sh --run-dir tmp/compatibility-runs/<run-name>-compatibility-smoke"),
    ("Beta native ODF control matrix", "docs/compatibility/beta-odf-manifest.tsv", "bin/compatibility-roundtrip.sh --manifest docs/compatibility/beta-odf-manifest.tsv --strict-validators --run-name <name>"),
    ("Beta PDF import matrix (advisory veraPDF)", "docs/compatibility/beta-pdf-import-manifest.tsv", "bin/compatibility-roundtrip.sh --manifest docs/compatibility/beta-pdf-import-manifest.tsv --run-name <name>"),
    ("Beta hard gate wrapper", "bin/v2-beta-gates.sh", "bin/v2-beta-gates.sh <run-name>"),
]
for name, rel, command in coverage_checks:
    lines.append(f"| {name} | `{rel}` {state(repo_root / rel)} | `{command}` |")
lines.append("")
lines.append("## Runtime package state")
lines.append("")
lines.append(f"- App bundle: `{app_bundle}` — {state(app_bundle)}")
lines.append(f"- App executable: `{app_bin}` — {state(app_bin)}")
lines.append("")
lines.append("## V2 program surface map")
lines.append("")
for program, rels in workflow_surfaces.items():
    lines.append(f"### {program}")
    lines.append("")
    for rel in rels:
        root = src_root if not (repo_root / rel).exists() else repo_root
        lines.append(f"- `{rel}` — {state(root / rel)}")
    lines.append("")
lines.append("## Compatibility inventory")
lines.append("")
lines.append("| Format | Count |")
lines.append("| --- | ---: |")
for suffix in preferred_exts:
    lines.append(f"| `{suffix}` | {ext_counts.get(suffix, 0)} |")
lines.append(f"| **Total** | **{sum(ext_counts.values())}** |")
lines.append("")
lines.append("## Compatibility sample roots")
lines.append("")
lines.append("| Root | Count |")
lines.append("| --- | ---: |")
for rel_root, count in root_counts.most_common():
    lines.append(f"| `{rel_root}` | {count} |")
lines.append("")
lines.append("## Representative smoke candidates")
lines.append("")
for suffix in preferred_exts:
    samples = representative_for(suffix, 3)
    if not samples:
        continue
    lines.append(f"### `{suffix}`")
    lines.append("")
    for sample in samples:
        lines.append(f"- `{sample}`")
    lines.append("")
lines.append("## V2 release gates")
lines.append("")
for name, detail in v2_gates:
    lines.append(f"- [ ] **{name}:** {detail}")
lines.append("")
lines.append("## Current Beta Blockers (manually maintained)")
lines.append("")
for item in beta_blockers:
    lines.append(f"- {item}")
lines.append("")
lines.append("## Recommended next execution queue")
lines.append("")
lines.append("| Priority | Round | Verification command |")
lines.append("| --- | --- | --- |")
for priority, round_name, command in next_rounds:
    lines.append(f"| {priority} | {round_name} | `{command}` |")
lines.append("")
lines.append("## Round acceptance template")
lines.append("")
lines.append("- Round name:")
lines.append("- Target workflow:")
lines.append("- Primary metric:")
lines.append("- Guardrails:")
lines.append("- Source surfaces changed:")
lines.append("- Verification commands:")
lines.append("- Result:")
lines.append("- Keep/reject decision:")
lines.append("- Next bottleneck:")

output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

printf 'Wrote V2 upgrade dashboard to %s\n' "$output_path"
