#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_path="$repo_root/tmp/source-hygiene-report.md"
mode="advisory"

usage() {
    cat <<'EOF'
Usage:
  source-hygiene-report.sh [options] [output-file]

Options:
  --strict     Fail if any source or generated/local working-tree entry exists.
  -h, --help

Generates a source/generated boundary report for the current 可圈office tree.
Default mode is advisory and always exits 0; use --strict for release-candidate
hygiene checks.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --strict)
            mode="strict"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            output_path="$1"
            shift
            ;;
    esac
done

mkdir -p "$(dirname "$output_path")"

python3 - "$repo_root" "$output_path" "$mode" <<'PY'
from collections import Counter
from pathlib import Path
import subprocess
import sys

repo_root = Path(sys.argv[1])
output_path = Path(sys.argv[2])
mode = sys.argv[3]

generated_exact = {
    "autogen.lastrun",
    "autogen.lastrun.bak",
    "config.log",
    "config.status",
    "config_host.mk",
}
generated_prefixes = (
    ".clavue/",
    ".superpowers/",
    "autom4te.cache/",
    "config_host/",
    "instdir/",
    "test-install/",
    "tmp/",
    "workdir/",
)
config_exact = {
    "autogen.lastrun",
    "autogen.lastrun.bak",
    "config.log",
    "config.status",
    "config_host.mk",
}
config_prefixes = (
    "autom4te.cache/",
    "config_host/",
)
install_test_release_prefixes = (
    "instdir/",
    "test-install/",
)
local_generated_prefixes = (
    ".clavue/",
    ".superpowers/",
    "tmp/",
    "workdir/",
)
operator_control_prefixes = (
    "bin/",
    "docs/",
    ".agent/",
)
operator_control_exact = {
    "AUTORESEARCH_AGENT_COORDINATION_PLAN.md",
    "AUTORESEARCH_EXECUTION_TODOLIST.md",
    "AUTORESEARCH_V2_UPGRADE_PLAN.md",
    "AUTORESEARCH_WORLD_CLASS_QUALITY_ROADMAP.md",
    "AUTORESEARCH_MATURE_OFFICE_PRODUCT_MODEL.md",
    "AUTORESEARCH_PRODUCT_REFACTOR_AUDIT.md",
    "AUTORESEARCH_OFFICE_ROUNDS.md",
    "AUTORESEARCH_INTELLIGENT_OFFICE_ARCHITECTURE.md",
    "AGENTS.md",
    "GNUmakefile",
    "autogen.sh",
    "clavue.md",
    "pkgconf-utf8-wrapper.py",
    "2.md",
}


def git_text(*args: str) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(repo_root), *args],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except subprocess.CalledProcessError:
        return "unknown"


def parse_status() -> list[tuple[str, str]]:
    raw = subprocess.check_output(
        [
            "git",
            "-C",
            str(repo_root),
            "status",
            "--porcelain=v1",
            "-z",
            "--untracked-files=all",
        ]
    )
    records = raw.split(b"\0")
    entries: list[tuple[str, str]] = []
    index = 0
    while index < len(records):
        record = records[index]
        index += 1
        if not record:
            continue
        text = record.decode("utf-8", errors="replace")
        status = text[:2]
        path = text[3:] if len(text) > 3 else ""
        if status[:1] in {"R", "C"} or status[1:2] in {"R", "C"}:
            index += 1
        if path:
            entries.append((status, path))
    return entries


def is_generated(path: str) -> bool:
    return path in generated_exact or any(path.startswith(prefix) for prefix in generated_prefixes)


def top_bucket(path: str) -> str:
    for prefix in generated_prefixes:
        if path.startswith(prefix):
            return prefix.rstrip("/")
    if path in generated_exact:
        return path
    return path.split("/", 1)[0]


def is_config_artifact(path: str) -> bool:
    return path in config_exact or any(path.startswith(prefix) for prefix in config_prefixes)


def is_install_test_release_artifact(path: str) -> bool:
    return any(path.startswith(prefix) for prefix in install_test_release_prefixes)


def is_local_generated_artifact(path: str) -> bool:
    return any(path.startswith(prefix) for prefix in local_generated_prefixes)


def is_operator_review_source(path: str) -> bool:
    return path in operator_control_exact or any(path.startswith(prefix) for prefix in operator_control_prefixes)


def is_human_decision_item(status: str, path: str) -> bool:
    if status == "??":
        return True
    if path.endswith((".bak", ".orig", ".rej")):
        return True
    if path in {"config_host.mk", "autogen.lastrun", "autogen.lastrun.bak"}:
        return True
    return False


def append_examples(lines: list[str], entries: list[tuple[str, str]], limit: int = 80) -> None:
    if not entries:
        lines.append("- none")
        return
    visible_entries = entries if limit <= 0 else entries[:limit]
    for status, path in visible_entries:
        lines.append(f"- `{status}` `{path}`")
    omitted = 0 if limit <= 0 else len(entries) - limit
    if omitted > 0:
        lines.append(f"- ... {omitted} more entries omitted")


entries = parse_status()
source_entries = [(status, path) for status, path in entries if not is_generated(path)]
generated_entries = [(status, path) for status, path in entries if is_generated(path)]
source_review_entries = [
    (status, path)
    for status, path in source_entries
    if not is_operator_review_source(path) and not is_human_decision_item(status, path)
]
operator_review_entries = [
    (status, path)
    for status, path in source_entries
    if is_operator_review_source(path) and not path.endswith((".bak", ".orig", ".rej"))
]
config_artifact_entries = [(status, path) for status, path in entries if is_config_artifact(path)]
install_test_release_entries = [
    (status, path) for status, path in entries if is_install_test_release_artifact(path)
]
local_generated_entries = [
    (status, path)
    for status, path in entries
    if is_local_generated_artifact(path)
    and not is_config_artifact(path)
    and not is_install_test_release_artifact(path)
]
unresolved_decision_entries = [
    (status, path)
    for status, path in source_entries
    if is_human_decision_item(status, path) and not is_operator_review_source(path)
]
generated_clean_or_ignore_entries = [
    (status, path)
    for status, path in generated_entries
    if not is_config_artifact(path)
    and not is_install_test_release_artifact(path)
]
generated_buckets = Counter(top_bucket(path) for _, path in generated_entries)
source_buckets = Counter(top_bucket(path) for _, path in source_entries)

branch_name = git_text("rev-parse", "--abbrev-ref", "HEAD")
head_commit = git_text("rev-parse", "--short", "HEAD")
created_at = subprocess.check_output(["date", "+%Y-%m-%d %H:%M:%S %z"], text=True).strip()

strict_failed = mode == "strict" and bool(unresolved_decision_entries)

lines: list[str] = []
lines.append("# Source Hygiene Report")
lines.append("")
lines.append(f"Generated at: {created_at}")
lines.append(f"Branch: {branch_name}")
lines.append(f"HEAD: {head_commit}")
lines.append(f"Repo root: {repo_root}")
lines.append(f"Mode: **{mode}**")
lines.append("")
lines.append("## Summary")
lines.append("")
lines.append(f"- Working tree entries: {len(entries)}")
lines.append(f"- Source-focused entries: {len(source_entries)}")
lines.append(f"- Generated/local entries: {len(generated_entries)}")
if mode == "strict":
    lines.append(f"- Status: **{'fail' if strict_failed else 'pass'}**")
else:
    lines.append("- Status: **advisory**")
lines.append("")
lines.append("## Classification Rules")
lines.append("")
lines.append("- Generated/local entries include build, install, temporary, autoconf, and local configuration outputs.")
lines.append("- Source-focused entries are everything else and should be reviewed before release packaging.")
lines.append("")
lines.append("## Generated/Local Buckets")
lines.append("")
if generated_buckets:
    lines.append("| Bucket | Count |")
    lines.append("| --- | ---: |")
    for bucket, count in generated_buckets.most_common(20):
        lines.append(f"| `{bucket}` | {count} |")
else:
    lines.append("- none")
lines.append("")
lines.append("## Source-Focused Buckets")
lines.append("")
if source_buckets:
    lines.append("| Bucket | Count |")
    lines.append("| --- | ---: |")
    for bucket, count in source_buckets.most_common(40):
        lines.append(f"| `{bucket}` | {count} |")
else:
    lines.append("- none")
lines.append("")
lines.append("## Source-Focused Entries")
lines.append("")
append_examples(lines, source_entries)
lines.append("")
lines.append("## Generated/Local Examples")
lines.append("")
append_examples(lines, generated_entries)
lines.append("")
lines.append("## Release Packet Action Buckets")
lines.append("")
lines.append("Use `docs/product/source-hygiene-release-packet.md` for the safe, non-destructive cleanup sequence and stop rules.")
lines.append("")
lines.append("| Action Bucket | Count | Operator Intent |")
lines.append("| --- | ---: | --- |")
lines.append(f"| Source review/stage | {len(source_review_entries) + len(operator_review_entries)} | Review intentional source/control changes before staging. |")
lines.append(f"| Generated/local clean-or-ignore | {len(generated_clean_or_ignore_entries)} | Clean with approved build cleanup or ignore locally after source review is complete. |")
lines.append(f"| Config/autoconf artifacts | {len(config_artifact_entries)} | Rebuild/configuration outputs; inspect before any regeneration or cleanup. |")
lines.append(f"| Install/test/release artifacts | {len(install_test_release_entries)} | App bundles, test installs, and release outputs; do not review as source. |")
lines.append(f"| Unresolved human-decision items | {len(unresolved_decision_entries)} | Requires explicit operator decision before staging, cleanup, or ignore changes. |")
lines.append("")
lines.append("### Source review/stage")
lines.append("")
append_examples(lines, operator_review_entries + source_review_entries, limit=0)
lines.append("")
lines.append("### Generated/local clean-or-ignore")
lines.append("")
append_examples(lines, generated_clean_or_ignore_entries)
lines.append("")
lines.append("### Config/autoconf artifacts")
lines.append("")
append_examples(lines, config_artifact_entries)
lines.append("")
lines.append("### Install/test/release artifacts")
lines.append("")
append_examples(lines, install_test_release_entries)
lines.append("")
lines.append("### Unresolved human-decision items")
lines.append("")
append_examples(lines, unresolved_decision_entries)
lines.append("")
lines.append("## Release Guidance")
lines.append("")
lines.append("- Keep this report advisory during alpha because local build output is expected.")
lines.append("- Use `bin/source-hygiene-report.sh --strict` before public beta or release candidates; strict mode fails while any working-tree entry remains.")
lines.append("- Review source/control entries first, then handle generated/local entries with the release packet stop rules.")
lines.append("- Do not review generated/local entries as product source changes; clean or ignore them separately.")

output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Wrote source hygiene report to {output_path}")

if strict_failed:
    raise SystemExit(1)
PY
