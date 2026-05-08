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
output_path="${1:-$repo_root/tmp/workbench-accessibility-check.md}"

usage() {
    cat <<'EOF'
Usage:
  workbench-accessibility-check.sh [output-file]

Runs a static accessibility review for the task-first Start Center workbench.
This checks labels, focusability, tooltips, and static accessibility roles for
the custom scenario controls. Manual VoiceOver, high-contrast, keyboard order,
and resize checks are still required before beta.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

mkdir -p "$(dirname "$output_path")"

python3 - "$repo_root" "$src_root" "$output_path" <<'PY'
from pathlib import Path
from xml.etree import ElementTree as ET
import subprocess
import sys

repo_root = Path(sys.argv[1])
src_root = Path(sys.argv[2])
output_path = Path(sys.argv[3])
ui_path = src_root / "sfx2/uiconfig/ui/startcenter.ui"

scenario_buttons = [
    "scenario_report",
    "scenario_minutes",
    "scenario_notice",
    "scenario_plan",
    "scenario_outline",
    "scenario_budget",
    "scenario_sales",
    "scenario_schedule",
    "scenario_pitch",
    "scenario_project_report",
    "scenario_courseware",
    "scenario_compat_open",
]

static_labels = [
    "scenario_subtitle",
    "scenario_writer_group",
    "scenario_calc_group",
    "scenario_impress_group",
    "scenario_compat_group",
    "scenario_fallback_hint",
]

live_blocker_checks = [
    (
        "Tab and Shift+Tab traversal",
        "Scenario buttons, blank document routes, open/recent/template routes, recent/local views, filter/actions, help, extensions",
        "Start from a fresh profile on the Start Center; press Tab until focus cycles once; repeat with Shift+Tab; record every focused control in order.",
        "Forward and reverse order list with no traps, skipped visible critical controls, or dead-end panes.",
        "Focus disappears, loops before all critical controls, lands on unlabeled surfaces first, or cannot leave recent/local/filter/action areas.",
    ),
    (
        "Enter and Space activation",
        "All scenario buttons plus open_all, open_remote, open_recent, templates_all, writer_all, calc_all, impress_all, draw_all, math_all, database_all, help, extensions, mbActions",
        "Keyboard-focus each control; activate with Enter and Space where applicable; cancel/close opened dialogs or documents and return to Start Center.",
        "Activation result per control, including safe return path after dialogs/documents and no lost focus.",
        "Enter or Space does nothing on a button, opens the wrong route, traps focus in a dialog, or loses Start Center focus after cancel/close.",
    ),
    (
        "VoiceOver labels and order",
        "Scenario group labels/buttons, compatibility-open task, blank/open routes, recent/local items, filter/actions, fallback warning",
        "Enable VoiceOver; navigate by keyboard/VoiceOver commands; transcribe the spoken Chinese name, group/context, state, and intent for each control group.",
        "Transcript confirms clear Chinese names, useful group context, actionable task intent, and navigation order matching the visual task grouping.",
        "Unlabeled/generic announcements, missing group context, hidden/empty surfaces announced before useful tasks, or tooltip-only intent not spoken.",
    ),
    (
        "High/increased contrast visibility",
        "Focus rings, muted subtitle/body labels, group labels, button boundaries, warning hint, empty/recent states",
        "Enable macOS Increase Contrast or a high-contrast appearance; traverse focus and capture screenshots at normal, narrow, and warning states if available.",
        "Screenshots/notes show visible focus indication, readable muted text, visible button boundaries, and perceivable warning/empty states.",
        "Focus ring blends into background, muted labels become too faint, button boundaries disappear, or warning/empty-state text is not readable.",
    ),
    (
        "Narrow and short resize reachability",
        "Scenario grid, open/recent/template controls, recent/local panes, action menu, help/extensions",
        "Resize Start Center to narrow and short sizes; use keyboard only to reach all critical controls; capture dimensions and screenshots for failures.",
        "All critical controls remain reachable with no critical label clipping, overlap, or inaccessible off-screen content.",
        "Four-column scenario grid clips labels/buttons, panes hide keyboard focus, controls overlap, or scrolling cannot reach critical routes.",
    ),
    (
        "Missing-template fallback",
        "scenario_fallback_hint, failed scenario button, templates_all, blank document routes",
        "Force or simulate one missing scenario template; activate that scenario by keyboard; record warning visibility, announcement, and next focused fallback.",
        "Warning is visible/announced promptly and focus moves to a useful fallback such as templates_all or an appropriate blank document route.",
        "Failure is silent, warning appears off-screen/unannounced, focus stays on a broken task, or no usable fallback receives focus.",
    ),
]


def now() -> str:
    return subprocess.check_output(["date", "+%Y-%m-%d %H:%M:%S %z"], text=True).strip()


def prop(obj: ET.Element | None, name: str) -> str:
    if obj is None:
        return ""
    for child in obj:
        if child.tag == "property" and child.attrib.get("name") == name:
            return (child.text or "").strip()
    return ""


def find_object(root: ET.Element, object_id: str) -> ET.Element | None:
    for obj in root.iter("object"):
        if obj.attrib.get("id") == object_id:
            return obj
    return None


def accessible_role(root: ET.Element, object_id: str) -> str:
    atk = find_object(root, f"{object_id}-atkobject")
    return prop(atk, "AtkObject::accessible-role")


def row(lines: list[str], status: str, check: str, evidence: str) -> None:
    lines.append(f"| {status} | {check} | {evidence} |")


errors: list[str] = []
lines: list[str] = []
lines.append("# Workbench Accessibility Check")
lines.append("")
lines.append(f"Generated at: {now()}")
lines.append(f"Repo root: {repo_root}")
lines.append(f"Source root: {src_root}")
lines.append(f"UI file: `{ui_path}`")
lines.append("")

if not ui_path.exists():
    errors.append(f"missing UI file: {ui_path}")
    root = None
else:
    root = ET.parse(ui_path).getroot()

lines.append("## Static Gate")
lines.append("")
lines.append("| Status | Check | Evidence |")
lines.append("| --- | --- | --- |")

if root is None:
    row(lines, "fail", "Start Center UI file exists", "missing")
else:
    row(lines, "pass", "Start Center UI file exists", "present")

    for button_id in scenario_buttons:
        obj = find_object(root, button_id)
        if obj is None:
            errors.append(f"missing scenario button: {button_id}")
            row(lines, "fail", f"`{button_id}` exists", "missing")
            continue

        label = prop(obj, "label")
        can_focus = prop(obj, "can-focus")
        tooltip = prop(obj, "tooltip-text")

        if label:
            row(lines, "pass", f"`{button_id}` has label", label)
        else:
            errors.append(f"{button_id} missing label")
            row(lines, "fail", f"`{button_id}` has label", "missing")

        if can_focus == "True":
            row(lines, "pass", f"`{button_id}` is keyboard-focusable", "can-focus=True")
        else:
            errors.append(f"{button_id} not keyboard-focusable")
            row(lines, "fail", f"`{button_id}` is keyboard-focusable", f"can-focus={can_focus or 'missing'}")

        if tooltip:
            row(lines, "pass", f"`{button_id}` has task-intent tooltip", tooltip)
        else:
            errors.append(f"{button_id} missing tooltip")
            row(lines, "fail", f"`{button_id}` has task-intent tooltip", "missing")

    scenario_label = find_object(root, "scenario_label")
    mnemonic = prop(scenario_label, "mnemonic-widget")
    if mnemonic == "scenario_report":
        row(lines, "pass", "`scenario_label` points keyboard mnemonic to first scenario", "mnemonic-widget=scenario_report")
    else:
        errors.append("scenario_label mnemonic-widget is not scenario_report")
        row(lines, "fail", "`scenario_label` points keyboard mnemonic to first scenario", f"mnemonic-widget={mnemonic or 'missing'}")

    for label_id in static_labels:
        label_obj = find_object(root, label_id)
        label = prop(label_obj, "label")
        role = accessible_role(root, label_id)
        if label:
            row(lines, "pass", f"`{label_id}` has visible text", label)
        else:
            errors.append(f"{label_id} missing label")
            row(lines, "fail", f"`{label_id}` has visible text", "missing")
        if role == "static":
            row(lines, "pass", f"`{label_id}` exposes static accessible role", "AtkObject::accessible-role=static")
        else:
            errors.append(f"{label_id} missing static accessible role")
            row(lines, "fail", f"`{label_id}` exposes static accessible role", f"role={role or 'missing'}")

lines.append("")
lines.append("## Live Blocker Evidence Matrix")
lines.append("")
lines.append("These checks require a live GUI and assistive-technology review. They are not proven by this static gate. Each blocker names the controls to exercise, the evidence to capture, and the failure signal that should keep beta blocked.")
lines.append("")
lines.append("| Area | Controls to exercise | Operator steps | Pass evidence to capture | Blocker signals |")
lines.append("| --- | --- | --- | --- | --- |")
for area, controls, steps, pass_evidence, blocker_signals in live_blocker_checks:
    lines.append(f"| {area} | {controls} | {steps} | {pass_evidence} | {blocker_signals} |")

lines.append("")
lines.append("## Result")
lines.append("")
if errors:
    lines.append("Status: **fail**")
    lines.append("")
    for error in errors:
        lines.append(f"- {error}")
else:
    lines.append("Status: **pass**")
    lines.append("")
    lines.append("Static scenario-control accessibility expectations are present. Manual accessibility review remains a beta blocker.")

output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Wrote workbench accessibility report to {output_path}")

if errors:
    raise SystemExit(1)
PY
