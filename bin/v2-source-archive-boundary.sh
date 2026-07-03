#!/usr/bin/env bash
set -euo pipefail

# Non-destructive archive-boundary gate for /Users/lu/kdoffice-src.
# It classifies dirty SRCDIR paths into reviewable V2 batches and fails when
# a path is outside the known W1/W2/W3/W4/W5/build-infra/submodule boundary.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src_root="${KDOFFICE_SRC_ROOT:-/Users/lu/kdoffice-src}"
report="$repo_root/tmp/v2-source-archive-boundary.md"

usage() {
    cat <<'EOF'
Usage:
  v2-source-archive-boundary.sh [--src-root PATH] [--report PATH]

Checks SRCDIR dirty paths against the V2 source archive batches.
This script does not stage, commit, reset, or otherwise mutate SRCDIR.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --src-root)
            src_root="$2"
            shift 2
            ;;
        --report)
            report="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "FAIL: unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

mkdir -p "$(dirname "$report")"

python3 - "$src_root" "$report" <<'PY'
import datetime as dt
import pathlib
import subprocess
import sys
from collections import Counter

src_root = pathlib.Path(sys.argv[1]).resolve()
report_path = pathlib.Path(sys.argv[2]).resolve()
batch_dir = report_path.parent / "v2-source-archive-batches"

if not (src_root / ".git").exists():
    print(f"FAIL: SRCDIR is not a git worktree: {src_root}", file=sys.stderr)
    sys.exit(1)

def exact(path, *labels):
    return ("exact", path, frozenset(labels))

def prefix(path, *labels):
    return ("prefix", path, frozenset(labels))

rules = [
    exact("kqoffice/Library_kqoffice_ai.mk", "W1-provider", "W5-cowork", "V3-agent-chat", "V3-agent-mesh", "V3-ai-canvas", "V3-ai-filemgr", "V3-control-plane"),
    exact("kqoffice/Module_kqoffice.mk", "W1-provider", "W5-cowork", "V3-agent-chat", "V3-agent-mesh", "V3-ai-canvas", "V3-ai-filemgr", "V3-control-plane"),
    exact("cui/Library_cui.mk", "W2-command-palette", "W5-cowork"),
    exact("cui/Module_cui.mk", "W2-command-palette", "W5-cowork"),
    exact("cui/UIConfig_cui.mk", "W2-command-palette", "W5-cowork"),
    exact("sfx2/Library_sfx.mk", "W2-command-palette", "W5-cowork", "V3-native-ai-workspace"),
    exact("sfx2/UIConfig_sfx.mk", "V3-native-ai-workspace"),
    exact("sfx2/util/sfx.component", "V3-native-ai-workspace"),
    exact("sw/Library_sw.mk", "W3-writer-apply", "W4-select-to-act"),
    exact("sw/Module_sw.mk", "W3-writer-apply", "W4-select-to-act"),
    exact("sw/UIConfig_swriter.mk", "W3-writer-apply", "W4-select-to-act"),

    exact("kqoffice/qa/cppunit/test_provider.cxx", "W1-provider"),
    prefix("kqoffice/source/ai/provider/", "W1-provider"),

    exact("cui/CppunitTest_cui_dispatcher.mk", "W2-command-palette"),
    prefix("cui/qa/unit/", "W2-command-palette"),
    prefix("cui/source/dialogs/commandpalette/", "W2-command-palette"),
    prefix("cui/source/inc/commandpalette/", "W2-command-palette"),
    exact("cui/uiconfig/ui/commandpalette.ui", "W2-command-palette"),
    exact("include/sfx2/sfxsids.hrc", "W2-command-palette"),
    exact("officecfg/registry/data/org/openoffice/Office/Accelerators.xcu", "W2-command-palette"),
    exact("officecfg/registry/data/org/openoffice/Office/UI/Factories.xcu", "V3-native-ai-workspace"),
    exact("officecfg/registry/data/org/openoffice/Office/UI/GenericCommands.xcu", "W2-command-palette"),
    exact("sfx2/sdi/appslots.sdi", "W2-command-palette"),
    exact("sfx2/sdi/sfx.sdi", "W2-command-palette"),
    exact("sfx2/source/appl/appserv.cxx", "W2-command-palette"),
    exact("sfx2/inc/dispatch/CommandPaletteDispatcher.hxx", "W2-command-palette"),
    exact("sfx2/source/dispatch/CommandPaletteDispatcher.cxx", "W2-command-palette"),

    exact("sw/CppunitTest_sw_uwriter.mk", "W3-writer-apply"),
    exact("sw/CppunitTest_sw_apply_engine.mk", "W3-writer-apply"),
    exact("sw/inc/IntelligentWriterAnalyzer.hxx", "W3-writer-apply"),
    exact("sw/inc/IntelligentWriterApplyEngine.hxx", "W3-writer-apply"),
    exact("sw/inc/docsh.hxx", "W3-writer-apply"),
    prefix("sw/qa/core/", "W3-writer-apply"),
    prefix("sw/source/core/doc/", "W3-writer-apply"),
    exact("sw/source/core/inc/UndoApplyPatch.hxx", "W3-writer-apply"),
    exact("sw/source/core/undo/UndoApplyPatch.cxx", "W3-writer-apply"),
    exact("sw/source/uibase/app/docst.cxx", "W3-writer-apply"),

    exact("include/svx/sidebar/DiffReviewPanel.hxx", "W4-select-to-act"),
    exact("sc/Library_sc.mk", "W4-select-to-act"),
    exact("sc/Module_sc.mk", "W4-select-to-act"),
    exact("sc/UIConfig_scalc.mk", "W4-select-to-act"),
    prefix("sc/qa/cppunit/", "W4-select-to-act"),
    prefix("sc/qa/uitest/selectToAct/", "W4-select-to-act"),
    prefix("sc/source/ui/inline-actions/", "W4-select-to-act"),
    exact("sc/source/ui/view/tabview3.cxx", "W4-select-to-act"),
    exact("sc/uiconfig/scalc/menubar/menubar.xml", "W4-select-to-act"),
    exact("sc/uiconfig/scalc/ui/cell-range-popover.ui", "W4-select-to-act"),
    exact("sc/CppunitTest_sc_inline_actions.mk", "W4-select-to-act"),
    exact("sc/UITest_sc_select_to_act.mk", "W4-select-to-act"),
    exact("sd/Library_sd.mk", "W4-select-to-act"),
    exact("sd/Module_sd.mk", "W4-select-to-act"),
    exact("sd/UIConfig_simpress.mk", "W4-select-to-act"),
    prefix("sd/qa/cppunit/", "W4-select-to-act"),
    prefix("sd/qa/uitest/selectToAct/", "W4-select-to-act"),
    prefix("sd/source/ui/inline-actions/", "W4-select-to-act"),
    exact("sd/source/ui/view/drviews1.cxx", "W4-select-to-act"),
    exact("sd/uiconfig/sdraw/menubar/menubar.xml", "W4-select-to-act"),
    exact("sd/uiconfig/simpress/menubar/menubar.xml", "W4-select-to-act"),
    exact("sd/uiconfig/simpress/ui/slide-element-popover.ui", "W4-select-to-act"),
    exact("sd/CppunitTest_sd_inline_actions.mk", "W4-select-to-act"),
    exact("sd/UITest_sd_select_to_act.mk", "W4-select-to-act"),
    exact("svx/Library_svx.mk", "W4-select-to-act"),
    exact("svx/UIConfig_svx.mk", "W4-select-to-act"),
    prefix("svx/source/sidebar/diff-review/", "W4-select-to-act"),
    exact("svx/uiconfig/ui/diff-review-dialog.ui", "W4-select-to-act"),
    exact("svx/uiconfig/ui/diff-review-panel.ui", "W4-select-to-act"),
    exact("sw/CppunitTest_sw_inline_actions.mk", "W4-select-to-act"),
    exact("sw/UITest_sw_select_to_act.mk", "W4-select-to-act"),
    prefix("sw/qa/cppunit/", "W4-select-to-act"),
    prefix("sw/qa/uitest/selectToAct/", "W4-select-to-act"),
    prefix("sw/source/uibase/ai/", "W4-select-to-act"),
    prefix("sw/source/uibase/inline-actions/", "W4-select-to-act"),
    exact("sw/source/uibase/uiview/view.cxx", "W4-select-to-act"),
    exact("sw/source/uibase/wrtsh/select.cxx", "W4-select-to-act"),
    exact("sw/source/uibase/wrtsh/wrtsh3.cxx", "W4-select-to-act"),
    exact("sw/uiconfig/sglobal/menubar/menubar.xml", "W4-select-to-act"),
    exact("sw/uiconfig/swriter/menubar/menubar.xml", "W4-select-to-act"),
    exact("sw/uiconfig/swriter/ui/select-to-act-popover.ui", "W4-select-to-act"),
    exact("vcl/source/uitest/uno/uiobject_uno.cxx", "W4-select-to-act"),

    exact("Library_merged.mk", "W5-cowork"),
    exact("officecfg/registry/data/org/openoffice/Office/UI/Sidebar.xcu", "W5-cowork"),
    prefix("cui/source/dialogs/cowork/", "W5-cowork"),
    prefix("cui/source/inc/cowork/", "W5-cowork"),
    exact("cui/uiconfig/ui/cowork-dialog.ui", "W5-cowork"),
    exact("kqoffice/CppunitTest_kqoffice_cowork.mk", "W5-cowork"),
    exact("kqoffice/qa/cppunit/test_cowork.cxx", "W5-cowork"),
    prefix("kqoffice/source/ai/cowork/", "W5-cowork"),
    exact("sfx2/inc/dispatch/CoworkPanelDispatcher.hxx", "W5-cowork"),
    exact("sfx2/source/dispatch/CoworkPanelDispatcher.cxx", "W5-cowork"),

    prefix("sfx2/source/sidebar/AIChat", "V3-native-ai-workspace"),
    exact("sfx2/uiconfig/ui/aichatpanel.ui", "V3-native-ai-workspace"),
    exact("sfx2/source/dialog/backingwindow.cxx", "V3-native-ai-workspace"),
    exact("sfx2/uiconfig/ui/startcenter.ui", "V3-native-ai-workspace"),

    # V3 agent-chat (in-app chat runtime)
    exact("kqoffice/CppunitTest_kqoffice_agent_chat.mk", "V3-agent-chat"),
    exact("kqoffice/qa/cppunit/test_agent_chat.cxx", "V3-agent-chat"),
    prefix("kqoffice/source/ai/chat/", "V3-agent-chat"),

    # V3 agent-mesh (multi-agent orchestration)
    exact("kqoffice/CppunitTest_kqoffice_agent_mesh.mk", "V3-agent-mesh"),
    exact("kqoffice/qa/cppunit/test_agent_mesh.cxx", "V3-agent-mesh"),
    prefix("kqoffice/source/ai/mesh/", "V3-agent-mesh"),

    # V3 ai-canvas (AI canvas workspace)
    exact("kqoffice/CppunitTest_kqoffice_ai_canvas.mk", "V3-ai-canvas"),
    exact("kqoffice/qa/cppunit/test_ai_canvas.cxx", "V3-ai-canvas"),
    prefix("kqoffice/source/ai/canvas/", "V3-ai-canvas"),

    # V3 ai-filemgr (AI file manager)
    exact("kqoffice/CppunitTest_kqoffice_ai_filemgr.mk", "V3-ai-filemgr"),
    exact("kqoffice/qa/cppunit/test_ai_filemgr.cxx", "V3-ai-filemgr"),
    prefix("kqoffice/source/ai/filemgr/", "V3-ai-filemgr"),

    # V3 control-plane (resource budget, safe restore, session store)
    exact("kqoffice/CppunitTest_kqoffice_control_plane.mk", "V3-control-plane"),
    exact("kqoffice/qa/cppunit/test_control_plane.cxx", "V3-control-plane"),
    prefix("kqoffice/source/ai/control/", "V3-control-plane"),

    # V3 i18n (AI strings)
    exact("kqoffice/source/ai/i18n/AiI18nStrings.hxx", "V3-i18n"),

    # V1.5 branding assets (icons, templates, branding)
    prefix("downstream-branding/", "V1.5-branding-assets"),
    prefix("extras/", "V1.5-branding-assets"),
    prefix("sysui/desktop/icons/", "V1.5-branding-assets"),

    exact("postprocess/CustomTarget_registry.mk", "build-infra"),
    prefix("solenv/", "build-infra"),
    exact("dictionaries", "submodule-dirty"),
    exact("helpcontent2", "submodule-dirty"),
]

def labels_for(path):
    labels = set()
    for kind, pattern, rule_labels in rules:
        if kind == "exact" and path == pattern:
            labels.update(rule_labels)
        elif kind == "prefix" and path.startswith(pattern):
            labels.update(rule_labels)
    return tuple(sorted(labels))

raw = subprocess.check_output(
    ["git", "-C", str(src_root), "status", "--porcelain=v1", "-z", "--untracked-files=all"]
)
parts = [p for p in raw.split(b"\0") if p]

items = []
i = 0
while i < len(parts):
    entry = parts[i].decode("utf-8", "replace")
    status = entry[:2]
    path = entry[3:]
    if "R" in status or "C" in status:
        if i + 1 < len(parts):
            old_path = parts[i + 1].decode("utf-8", "replace")
            path = f"{old_path} -> {path}"
            i += 1
    labels = labels_for(path.split(" -> ")[-1])
    items.append((status, path, labels))
    i += 1

unknown = [(s, p) for s, p, labels in items if not labels]
shared = [(s, p, labels) for s, p, labels in items if len(labels) > 1]
counts = Counter()
for _, _, labels in items:
    for label in labels:
        counts[label] += 1

batch_labels = [
    "W1-provider",
    "W2-command-palette",
    "W3-writer-apply",
    "W4-select-to-act",
    "W5-cowork",
    "V3-native-ai-workspace",
    "V3-agent-chat",
    "V3-agent-mesh",
    "V3-ai-canvas",
    "V3-ai-filemgr",
    "V3-control-plane",
    "V3-i18n",
    "V1.5-branding-assets",
    "build-infra",
    "submodule-dirty",
]

batch_dir.mkdir(parents=True, exist_ok=True)
for stale in batch_dir.glob("*.paths"):
    stale.unlink()
for label in batch_labels:
    paths = sorted(path for _, path, labels in items if label in labels)
    (batch_dir / f"{label}.paths").write_text(
        "".join(f"{path}\n" for path in paths),
        encoding="utf-8",
    )
(batch_dir / "split-needed.paths").write_text(
    "".join(f"{path}\t{', '.join(labels)}\n" for _, path, labels in shared),
    encoding="utf-8",
)
(batch_dir / "unknown.paths").write_text(
    "".join(f"{path}\n" for _, path in unknown),
    encoding="utf-8",
)

now = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S%z")
lines = [
    "# V2 Source Archive Boundary Report",
    "",
    f"- Generated: {now}",
    f"- SRCDIR: {src_root}",
    f"- Dirty paths: {len(items)}",
    f"- Unknown paths: {len(unknown)}",
    f"- Split-needed shared paths: {len(shared)}",
    f"- Batch path lists: {batch_dir}",
    "",
    "## Batch Counts",
    "",
    "| Batch | Dirty paths |",
    "|---|---:|",
]
for label in batch_labels:
    lines.append(f"| {label} | {counts[label]} |")

if shared:
    lines.extend(["", "## Split-Needed Paths", "", "| Status | Path | Labels |", "|---|---|---|"])
    for status, path, labels in shared:
        lines.append(f"| {status} | {path} | {', '.join(labels)} |")

lines.extend(["", "## Dirty Path Classification", "", "| Status | Path | Labels |", "|---|---|---|"])
for status, path, labels in items:
    label_text = ", ".join(labels) if labels else "UNKNOWN"
    lines.append(f"| {status} | {path} | {label_text} |")

if unknown:
    lines.extend(["", "## Unknown Paths", ""])
    for status, path in unknown:
        lines.append(f"- {status} {path}")

report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

print(f"Status: {'failed' if unknown else 'passed'}")
print(f"Report: {report_path}")
print(f"Dirty paths: {len(items)}")
print(f"Unknown paths: {len(unknown)}")
print(f"Split-needed shared paths: {len(shared)}")
print(f"Batch path lists: {batch_dir}")
for label in sorted(counts):
    print(f"{label}: {counts[label]}")

if unknown:
    print("FAIL: unclassified SRCDIR dirty paths found; update the archive boundary before staging.", file=sys.stderr)
    sys.exit(1)
PY
