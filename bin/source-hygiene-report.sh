#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_path="$repo_root/tmp/source-hygiene-report.md"
mode="advisory"
decision_input_path=""
json_output_path=""

usage() {
    cat <<'EOF'
Usage:
  source-hygiene-report.sh [options] [output-file]

Options:
  --strict     Fail if any source or generated/local working-tree entry exists.
  --decision-summary <file>
               Write an operator decision checklist instead of the full report.
  --decision-json <file>
               Write a machine-readable operator decision manifest.
  --decision-packets <dir>
               Write per-bucket operator review packets.
  --validate-decisions <decision-json> [output-file]
               Validate an operator-filled decision manifest against current git status.
  --decision-progress <decision-json> [output-file]
               Write a read-only source hygiene decision progress summary.
  --decision-plan <decision-json> [output-file]
               Write a non-destructive dry-run plan from a validated decision manifest.
  --json-output <file>
               With --decision-progress or --decision-plan, also write JSON evidence.
  -h, --help

Generates a source/generated boundary report for the current 可圈办公 tree.
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
        --decision-summary)
            mode="decision-summary"
            output_path="${2:?missing --decision-summary output file}"
            shift 2
            ;;
        --decision-json)
            mode="decision-json"
            output_path="${2:?missing --decision-json output file}"
            shift 2
            ;;
        --decision-packets)
            mode="decision-packets"
            output_path="${2:?missing --decision-packets output dir}"
            shift 2
            ;;
        --validate-decisions)
            mode="validate-decisions"
            decision_input_path="${2:?missing --validate-decisions decision JSON file}"
            output_path="$repo_root/tmp/source-hygiene-decision-validation.md"
            shift 2
            ;;
        --decision-progress)
            mode="decision-progress"
            decision_input_path="${2:?missing --decision-progress decision JSON file}"
            output_path="$repo_root/tmp/source-hygiene-decision-progress.md"
            shift 2
            ;;
        --decision-plan)
            mode="decision-plan"
            decision_input_path="${2:?missing --decision-plan decision JSON file}"
            output_path="$repo_root/tmp/source-hygiene-decision-plan.md"
            shift 2
            ;;
        --json-output)
            json_output_path="${2:?missing --json-output file}"
            shift 2
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

python3 - "$repo_root" "$output_path" "$mode" "$decision_input_path" "$json_output_path" <<'PY'
from collections import Counter
from pathlib import Path
import json
import subprocess
import sys

repo_root = Path(sys.argv[1])
output_path = Path(sys.argv[2])
mode = sys.argv[3]
decision_input_path = Path(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[4] else None
json_output_path = Path(sys.argv[5]) if len(sys.argv) > 5 and sys.argv[5] else None

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
repo_backup_prefixes = (
    ".git.bak-",
)
odd_local_exact = {
    ":-",
    "config.warn",
    "config_host_lang.mk",
}
odd_local_prefixes = ()
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


def repo_relative(path: Path | None) -> str | None:
    if path is None:
        return None
    try:
        return str(path.resolve().relative_to(repo_root.resolve()))
    except (OSError, ValueError):
        return None


def is_validation_generated_evidence(path: str) -> bool:
    return path.startswith("tmp/source-hygiene-")


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


def is_repo_backup_artifact(path: str) -> bool:
    return any(path.startswith(prefix) for prefix in repo_backup_prefixes)


def is_odd_local_item(path: str) -> bool:
    return path in odd_local_exact or any(path.startswith(prefix) for prefix in odd_local_prefixes)


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


validation_ignored_paths = set()
decision_modes = {"validate-decisions", "decision-packets", "decision-progress", "decision-plan"}
if mode in decision_modes:
    for ignored_path in (decision_input_path, output_path):
        rel_path = repo_relative(ignored_path)
        if rel_path:
            validation_ignored_paths.add(rel_path)

entries = [
    (status, path)
    for status, path in parse_status()
    if path not in validation_ignored_paths
    and not (mode in decision_modes and is_validation_generated_evidence(path))
]
source_entries = [(status, path) for status, path in entries if not is_generated(path)]
generated_entries = [(status, path) for status, path in entries if is_generated(path)]
repo_backup_entries = [(status, path) for status, path in source_entries if is_repo_backup_artifact(path)]
odd_local_entries = [
    (status, path)
    for status, path in source_entries
    if is_odd_local_item(path) and not is_repo_backup_artifact(path)
]
source_review_entries = [
    (status, path)
    for status, path in source_entries
    if not is_operator_review_source(path)
    and not is_human_decision_item(status, path)
    and not is_repo_backup_artifact(path)
    and not is_odd_local_item(path)
]
operator_review_entries = [
    (status, path)
    for status, path in source_entries
    if is_operator_review_source(path)
    and not path.endswith((".bak", ".orig", ".rej"))
    and not is_repo_backup_artifact(path)
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
    if is_human_decision_item(status, path)
    and not is_operator_review_source(path)
    and not is_repo_backup_artifact(path)
    and not is_odd_local_item(path)
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

strict_failed = mode == "strict" and bool(entries)

def append_decision_section(lines: list[str], title: str, entries: list[tuple[str, str]], decisions: list[str]) -> None:
    lines.append(f"### {title}")
    lines.append("")
    lines.append("Decision owner:")
    lines.append("Decision timestamp:")
    lines.append("")
    lines.append("Allowed decisions:")
    for decision in decisions:
        lines.append(f"- [ ] {decision}")
    lines.append("")
    lines.append("Paths:")
    append_examples(lines, entries, limit=0)
    lines.append("")

decision_buckets = [
    ("source_review_stage", "Source review/stage", operator_review_entries + source_review_entries, [
        "stage approved release source/control changes",
        "defer unrelated work to a later branch",
        "reject accidental changes only after explicit approval",
    ]),
    ("repo_backup_human_decision", "Repo backup human-decision items", repo_backup_entries, [
        "preserve as local recovery data",
        "archive outside the repository",
        "ignore locally after approval",
        "clean only in a separate approved cleanup packet",
    ]),
    ("odd_local_human_decision", "Odd/local human-decision items", odd_local_entries, [
        "stage as intentional release support files",
        "preserve locally outside the release packet",
        "ignore locally after approval",
        "clean only after explicit approval",
    ]),
    ("unresolved_human_decision", "Unresolved human-decision items", unresolved_decision_entries, [
        "stage as intentional source/control work",
        "defer unrelated user-authored files",
        "ignore locally after approval",
        "clean only after explicit approval",
    ]),
    ("generated_local_clean_or_ignore", "Generated/local clean-or-ignore", generated_clean_or_ignore_entries, [
        "preserve as release evidence",
        "clean with approved build cleanup",
        "ignore locally after approval",
    ]),
    ("config_autoconf_artifacts", "Config/autoconf artifacts", config_artifact_entries, [
        "preserve active local configuration",
        "regenerate intentionally",
        "clean only after explicit approval",
    ]),
    ("install_test_release_artifacts", "Install/test/release artifacts", install_test_release_entries, [
        "preserve as release evidence",
        "regenerate intentionally",
        "clean only after explicit approval",
    ]),
]

current_decision_entries = {}
classification_errors: list[str] = []
for key, title, bucket_entries, decisions in decision_buckets:
    for status, path in bucket_entries:
        if path in current_decision_entries:
            classification_errors.append(
                f"{path} is classified in both {current_decision_entries[path]['bucket']} and {key}"
            )
            continue
        current_decision_entries[path] = {
            "status": status,
            "bucket": key,
            "title": title,
            "allowed_decisions": decisions,
        }

missing_classification_paths = sorted({path for _, path in entries} - set(current_decision_entries))
for path in missing_classification_paths:
    classification_errors.append(f"{path} has no release decision bucket")


def entry_with_decision_template(status: str, path: str) -> dict:
    return {
        "status": status,
        "path": path,
        "decision": "",
        "decision_owner": "",
        "decision_timestamp": "",
        "decision_note": "",
    }


def decision_value(entry: dict) -> str:
    for field in ("decision", "selected_decision", "operator_decision"):
        value = entry.get(field)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def collect_operator_decisions(payload: dict) -> tuple[list[dict], list[str]]:
    collected: list[dict] = []
    structural_errors: list[str] = []

    def collect(entry: dict, source: str, bucket_key: str = "") -> None:
        if not isinstance(entry, dict):
            structural_errors.append(f"{source} is not an object")
            return
        decision = decision_value(entry)
        if not decision:
            return
        path = entry.get("path")
        if not isinstance(path, str) or not path:
            structural_errors.append(f"{source} has a decision but no path")
            return
        if path in validation_ignored_paths or is_validation_generated_evidence(path):
            return
        status = entry.get("status")
        if status is not None and not isinstance(status, str):
            structural_errors.append(f"{source} has a non-string status")
            return
        entry_bucket = entry.get("bucket") or entry.get("bucket_key") or entry.get("key") or bucket_key
        if entry_bucket is not None and not isinstance(entry_bucket, str):
            structural_errors.append(f"{source} has a non-string bucket")
            return
        collected.append({
            "source": source,
            "path": path,
            "status": status or "",
            "bucket": entry_bucket or "",
            "decision": decision,
        })

    for index, entry in enumerate(payload.get("operator_decisions", [])):
        collect(entry, f"operator_decisions[{index}]")

    for bucket_index, bucket in enumerate(payload.get("buckets", [])):
        if not isinstance(bucket, dict):
            structural_errors.append(f"buckets[{bucket_index}] is not an object")
            continue
        bucket_key = bucket.get("key", "")
        if bucket_key is not None and not isinstance(bucket_key, str):
            structural_errors.append(f"buckets[{bucket_index}].key is not a string")
            bucket_key = ""
        entries_payload = bucket.get("entries", [])
        if not isinstance(entries_payload, list):
            structural_errors.append(f"buckets[{bucket_index}].entries is not a list")
            continue
        for entry_index, entry in enumerate(entries_payload):
            collect(entry, f"buckets[{bucket_index}].entries[{entry_index}]", bucket_key or "")

    return collected, structural_errors


def append_validation_entries(lines: list[str], entries: list[str], empty_text: str = "- none") -> None:
    if not entries:
        lines.append(empty_text)
        return
    for entry in entries:
        lines.append(f"- {entry}")


def evaluate_decision_manifest() -> dict:
    payload = None
    payload_errors: list[str] = []
    if decision_input_path is None:
        payload_errors.append("missing decision manifest path")
    else:
        try:
            with decision_input_path.open(encoding="utf-8") as handle:
                payload = json.load(handle)
        except FileNotFoundError:
            payload_errors.append(f"decision manifest does not exist: {decision_input_path}")
        except json.JSONDecodeError as exc:
            payload_errors.append(f"decision manifest is not valid JSON: {exc}")

    if payload is not None and not isinstance(payload, dict):
        payload_errors.append("decision manifest root must be a JSON object")
        payload = None
    if payload is not None and payload.get("schema_version") != 1:
        payload_errors.append("decision manifest schema_version must be 1")

    operator_decisions: list[dict] = []
    structural_errors: list[str] = []
    if payload is not None:
        operator_decisions, structural_errors = collect_operator_decisions(payload)

    decisions_by_path: dict[str, list[dict]] = {}
    for decision in operator_decisions:
        decisions_by_path.setdefault(decision["path"], []).append(decision)

    duplicate_paths = sorted(path for path, values in decisions_by_path.items() if len(values) > 1)
    stale_paths = sorted(path for path in decisions_by_path if path not in current_decision_entries)
    missing_paths = sorted(path for path in current_decision_entries if path not in decisions_by_path)
    invalid_decisions: list[str] = []
    valid_decisions: list[dict] = []

    for path, decisions_for_path in sorted(decisions_by_path.items()):
        if path in stale_paths or path in duplicate_paths:
            continue
        current = current_decision_entries.get(path)
        if current is None:
            continue
        decision = decisions_for_path[0]
        path_errors = []
        if decision["status"] and decision["status"] != current["status"]:
            path_errors.append(f"status {decision['status']} does not match current {current['status']}")
        if decision["bucket"] and decision["bucket"] != current["bucket"]:
            path_errors.append(f"bucket {decision['bucket']} does not match current {current['bucket']}")
        if decision["decision"] not in current["allowed_decisions"]:
            path_errors.append(
                f"decision {decision['decision']} is not allowed for {current['bucket']}"
            )
        if path_errors:
            invalid_decisions.append(f"{path} from {decision['source']}: " + "; ".join(path_errors))
        else:
            valid_decisions.append({
                "path": path,
                "status": current["status"],
                "bucket": current["bucket"],
                "title": current["title"],
                "decision": decision["decision"],
            })

    duplicate_errors = [
        f"{path} has {len(decisions_by_path[path])} decisions"
        for path in duplicate_paths
    ]
    stale_errors = [
        f"{path} is not present in current git status"
        for path in stale_paths
    ]
    invalid_paths = []
    for invalid in invalid_decisions:
        invalid_paths.append(invalid.split(" from ", 1)[0])

    missing_by_bucket = Counter(current_decision_entries[path]["bucket"] for path in missing_paths)
    valid_by_bucket = Counter(decision["bucket"] for decision in valid_decisions)
    invalid_by_bucket = Counter(
        current_decision_entries[path]["bucket"]
        for path in invalid_paths
        if path in current_decision_entries
    )
    duplicate_by_bucket = Counter(
        current_decision_entries[path]["bucket"]
        for path in duplicate_paths
        if path in current_decision_entries
    )
    stale_by_top_bucket = Counter(top_bucket(path) for path in stale_paths)
    valid_by_decision = Counter(decision["decision"] for decision in valid_decisions)

    failed = bool(
        payload_errors
        or structural_errors
        or classification_errors
        or duplicate_errors
        or stale_errors
        or missing_paths
        or invalid_decisions
    )

    return {
        "payload_errors": payload_errors,
        "structural_errors": structural_errors,
        "operator_decisions": operator_decisions,
        "decisions_by_path": decisions_by_path,
        "duplicate_paths": duplicate_paths,
        "duplicate_errors": duplicate_errors,
        "stale_paths": stale_paths,
        "stale_errors": stale_errors,
        "missing_paths": missing_paths,
        "invalid_decisions": invalid_decisions,
        "valid_decisions": valid_decisions,
        "valid_paths": {decision["path"] for decision in valid_decisions},
        "missing_by_bucket": missing_by_bucket,
        "valid_by_bucket": valid_by_bucket,
        "invalid_by_bucket": invalid_by_bucket,
        "duplicate_by_bucket": duplicate_by_bucket,
        "stale_by_top_bucket": stale_by_top_bucket,
        "valid_by_decision": valid_by_decision,
        "failed": failed,
    }


if mode == "decision-progress":
    result = evaluate_decision_manifest()
    total = len(current_decision_entries)
    valid_count = len(result["valid_decisions"])
    missing_count = len(result["missing_paths"])
    invalid_count = len(result["invalid_decisions"])
    duplicate_count = len(result["duplicate_errors"])
    stale_count = len(result["stale_errors"])
    classification_count = len(classification_errors)
    manifest_count = len(result["payload_errors"]) + len(result["structural_errors"])
    status = "blocked" if result["failed"] else "ready"
    progress_percent = round((valid_count / total) * 100, 2) if total else 100.0

    lines: list[str] = []
    lines.append("# Source Hygiene Decision Progress")
    lines.append("")
    lines.append(f"Generated at: {created_at}")
    lines.append(f"Branch: {branch_name}")
    lines.append(f"HEAD: {head_commit}")
    lines.append(f"Repo root: {repo_root}")
    lines.append(f"Decision manifest: {decision_input_path if decision_input_path else ''}")
    lines.append("")
    lines.append("## Verdict")
    lines.append("")
    lines.append(f"- Status: **{status}**")
    lines.append(f"- Current working-tree entries requiring decisions: {total}")
    lines.append(f"- Valid path decisions: {valid_count}")
    lines.append(f"- Progress percent: {progress_percent:.2f}")
    lines.append(f"- Missing path decisions: {missing_count}")
    lines.append(f"- Invalid path decisions: {invalid_count}")
    lines.append(f"- Duplicate path decisions: {duplicate_count}")
    lines.append(f"- Stale path decisions: {stale_count}")
    lines.append(f"- Manifest/structure errors: {manifest_count}")
    lines.append(f"- Classification errors: {classification_count}")
    lines.append("- Executes changes: no")
    lines.append("")
    lines.append("## Bucket Progress")
    lines.append("")
    lines.append("| Bucket | Current | Valid | Missing | Invalid | Duplicate |")
    lines.append("| --- | ---: | ---: | ---: | ---: | ---: |")
    for key, title, bucket_entries, _ in decision_buckets:
        current_count = len({path for _, path in bucket_entries})
        lines.append(
            f"| {title} | {current_count} | {result['valid_by_bucket'][key]} | "
            f"{result['missing_by_bucket'][key]} | {result['invalid_by_bucket'][key]} | "
            f"{result['duplicate_by_bucket'][key]} |"
        )
    lines.append("")
    lines.append("## Valid Decisions By Choice")
    lines.append("")
    if result["valid_by_decision"]:
        lines.append("| Decision | Count |")
        lines.append("| --- | ---: |")
        for decision, count in sorted(result["valid_by_decision"].items()):
            lines.append(f"| {decision} | {count} |")
    else:
        lines.append("- none")
    lines.append("")
    lines.append("## Next Step")
    lines.append("")
    if status == "ready":
        lines.append("- Review tmp/source-hygiene-decision-plan.md and tmp/source-hygiene-apply-plan-dry-run.md before any operator-selected batch.")
    else:
        lines.append("- Fill missing decisions, resolve invalid/duplicate/stale entries, rerun --validate-decisions, then regenerate this progress report.")

    progress_payload = {
        "schema_version": 1,
        "generated_at": created_at,
        "branch": branch_name,
        "head": head_commit,
        "repo_root": str(repo_root),
        "decision_manifest": str(decision_input_path) if decision_input_path else "",
        "status": status,
        "executes_changes": False,
        "progress_percent": progress_percent,
        "counts": {
            "current_working_tree_entries_requiring_decisions": total,
            "valid_path_decisions": valid_count,
            "missing_path_decisions": missing_count,
            "invalid_path_decisions": invalid_count,
            "duplicate_path_decisions": duplicate_count,
            "stale_path_decisions": stale_count,
            "manifest_structure_errors": manifest_count,
            "classification_errors": classification_count,
        },
        "bucket_progress": [
            {
                "key": key,
                "title": title,
                "current": len({path for _, path in bucket_entries}),
                "valid": result["valid_by_bucket"][key],
                "missing": result["missing_by_bucket"][key],
                "invalid": result["invalid_by_bucket"][key],
                "duplicate": result["duplicate_by_bucket"][key],
            }
            for key, title, bucket_entries, _ in decision_buckets
        ],
        "valid_decisions_by_choice": dict(sorted(result["valid_by_decision"].items())),
        "stale_decisions_by_top_bucket": dict(sorted(result["stale_by_top_bucket"].items())),
        "next_action": "review dry-run plans" if status == "ready" else "fill or fix operator decisions",
    }

    if json_output_path is not None:
        json_output_path.parent.mkdir(parents=True, exist_ok=True)
        json_output_path.write_text(json.dumps(progress_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote source hygiene decision progress to {output_path}")
    if status != "ready":
        raise SystemExit(1)
    raise SystemExit(0)


if mode == "validate-decisions":
    lines: list[str] = []
    lines.append("# Source Hygiene Decision Validation")
    lines.append("")
    lines.append(f"Generated at: {created_at}")
    lines.append(f"Branch: {branch_name}")
    lines.append(f"HEAD: {head_commit}")
    lines.append(f"Repo root: {repo_root}")
    lines.append(f"Decision manifest: {decision_input_path if decision_input_path else ''}")
    if validation_ignored_paths:
        lines.append(f"Ignored generated evidence paths: {', '.join(sorted(validation_ignored_paths))}")
    lines.append("")

    payload = None
    payload_errors: list[str] = []
    if decision_input_path is None:
        payload_errors.append("missing decision manifest path")
    else:
        try:
            with decision_input_path.open(encoding="utf-8") as handle:
                payload = json.load(handle)
        except FileNotFoundError:
            payload_errors.append(f"decision manifest does not exist: {decision_input_path}")
        except json.JSONDecodeError as exc:
            payload_errors.append(f"decision manifest is not valid JSON: {exc}")

    if payload is not None and not isinstance(payload, dict):
        payload_errors.append("decision manifest root must be a JSON object")
        payload = None
    if payload is not None and payload.get("schema_version") != 1:
        payload_errors.append("decision manifest schema_version must be 1")

    operator_decisions: list[dict] = []
    structural_errors: list[str] = []
    if payload is not None:
        operator_decisions, structural_errors = collect_operator_decisions(payload)

    decisions_by_path: dict[str, list[dict]] = {}
    for decision in operator_decisions:
        decisions_by_path.setdefault(decision["path"], []).append(decision)

    duplicate_paths = sorted(path for path, values in decisions_by_path.items() if len(values) > 1)
    stale_paths = sorted(path for path in decisions_by_path if path not in current_decision_entries)
    missing_paths = sorted(path for path in current_decision_entries if path not in decisions_by_path)
    invalid_decisions: list[str] = []
    valid_paths: set[str] = set()

    for path, decisions_for_path in sorted(decisions_by_path.items()):
        if path in stale_paths or path in duplicate_paths:
            continue
        current = current_decision_entries.get(path)
        if current is None:
            continue
        decision = decisions_for_path[0]
        path_errors = []
        if decision["status"] and decision["status"] != current["status"]:
            path_errors.append(f"status {decision['status']} does not match current {current['status']}")
        if decision["bucket"] and decision["bucket"] != current["bucket"]:
            path_errors.append(f"bucket {decision['bucket']} does not match current {current['bucket']}")
        if decision["decision"] not in current["allowed_decisions"]:
            path_errors.append(
                f"decision {decision['decision']} is not allowed for {current['bucket']}"
            )
        if path_errors:
            invalid_decisions.append(f"{path} from {decision['source']}: " + "; ".join(path_errors))
        else:
            valid_paths.add(path)

    duplicate_errors = [
        f"{path} has {len(decisions_by_path[path])} decisions"
        for path in duplicate_paths
    ]
    stale_errors = [
        f"{path} is not present in current git status"
        for path in stale_paths
    ]
    missing_errors = [
        f"{current_decision_entries[path]['status']} {path} in {current_decision_entries[path]['bucket']}"
        for path in missing_paths[:120]
    ]
    if len(missing_paths) > 120:
        missing_errors.append(f"... {len(missing_paths) - 120} more missing decisions omitted")

    failed = bool(
        payload_errors
        or structural_errors
        or classification_errors
        or duplicate_errors
        or stale_errors
        or missing_paths
        or invalid_decisions
    )

    lines.append("## Verdict")
    lines.append("")
    lines.append(f"- Status: **{'fail' if failed else 'pass'}**")
    lines.append(f"- Current working-tree entries requiring decisions: {len(current_decision_entries)}")
    lines.append(f"- Valid path decisions: {len(valid_paths)}")
    lines.append(f"- Missing path decisions: {len(missing_paths)}")
    lines.append(f"- Invalid path decisions: {len(invalid_decisions)}")
    lines.append(f"- Duplicate path decisions: {len(duplicate_errors)}")
    lines.append(f"- Stale path decisions: {len(stale_errors)}")
    lines.append(f"- Classification errors: {len(classification_errors)}")
    lines.append("- Beta gate effect: support evidence only; source-hygiene-strict still blocks release claims until the working tree is intentionally resolved.")
    lines.append("")

    lines.append("## Manifest Problems")
    lines.append("")
    append_validation_entries(lines, payload_errors + structural_errors)
    lines.append("")
    lines.append("## Classification Problems")
    lines.append("")
    append_validation_entries(lines, classification_errors)
    lines.append("")
    lines.append("## Invalid Decisions")
    lines.append("")
    append_validation_entries(lines, invalid_decisions)
    lines.append("")
    lines.append("## Duplicate Decisions")
    lines.append("")
    append_validation_entries(lines, duplicate_errors)
    lines.append("")
    lines.append("## Stale Decisions")
    lines.append("")
    append_validation_entries(lines, stale_errors)
    lines.append("")
    lines.append("## Missing Decisions")
    lines.append("")
    append_validation_entries(lines, missing_errors)
    lines.append("")
    lines.append("## Bucket Counts")
    lines.append("")
    lines.append("| Bucket | Current entries | Valid decisions | Missing decisions |")
    lines.append("| --- | ---: | ---: | ---: |")
    missing_path_set = set(missing_paths)
    for key, title, bucket_entries, _ in decision_buckets:
        bucket_paths = {path for _, path in bucket_entries}
        valid_count = len(bucket_paths & valid_paths)
        missing_count = len(bucket_paths & missing_path_set)
        lines.append(f"| {title} | {len(bucket_paths)} | {valid_count} | {missing_count} |")

    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote source hygiene decision validation to {output_path}")
    if failed:
        raise SystemExit(1)
    raise SystemExit(0)

if mode == "decision-plan":
    lines: list[str] = []
    lines.append("# Source Hygiene Decision Plan")
    lines.append("")
    lines.append(f"Generated at: {created_at}")
    lines.append(f"Branch: {branch_name}")
    lines.append(f"HEAD: {head_commit}")
    lines.append(f"Repo root: {repo_root}")
    lines.append(f"Decision manifest: {decision_input_path if decision_input_path else ''}")
    lines.append("")

    payload = None
    payload_errors: list[str] = []
    if decision_input_path is None:
        payload_errors.append("missing decision manifest path")
    else:
        try:
            with decision_input_path.open(encoding="utf-8") as handle:
                payload = json.load(handle)
        except FileNotFoundError:
            payload_errors.append(f"decision manifest does not exist: {decision_input_path}")
        except json.JSONDecodeError as exc:
            payload_errors.append(f"decision manifest is not valid JSON: {exc}")

    if payload is not None and not isinstance(payload, dict):
        payload_errors.append("decision manifest root must be a JSON object")
        payload = None
    if payload is not None and payload.get("schema_version") != 1:
        payload_errors.append("decision manifest schema_version must be 1")

    operator_decisions: list[dict] = []
    structural_errors: list[str] = []
    if payload is not None:
        operator_decisions, structural_errors = collect_operator_decisions(payload)

    decisions_by_path: dict[str, list[dict]] = {}
    for decision in operator_decisions:
        decisions_by_path.setdefault(decision["path"], []).append(decision)

    duplicate_paths = sorted(path for path, values in decisions_by_path.items() if len(values) > 1)
    stale_paths = sorted(path for path in decisions_by_path if path not in current_decision_entries)
    missing_paths = sorted(path for path in current_decision_entries if path not in decisions_by_path)
    invalid_decisions: list[str] = []
    valid_decisions: list[dict] = []

    for path, decisions_for_path in sorted(decisions_by_path.items()):
        if path in stale_paths or path in duplicate_paths:
            continue
        current = current_decision_entries.get(path)
        if current is None:
            continue
        decision = decisions_for_path[0]
        path_errors = []
        if decision["status"] and decision["status"] != current["status"]:
            path_errors.append(f"status {decision['status']} does not match current {current['status']}")
        if decision["bucket"] and decision["bucket"] != current["bucket"]:
            path_errors.append(f"bucket {decision['bucket']} does not match current {current['bucket']}")
        if decision["decision"] not in current["allowed_decisions"]:
            path_errors.append(
                f"decision {decision['decision']} is not allowed for {current['bucket']}"
            )
        if path_errors:
            invalid_decisions.append(f"{path} from {decision['source']}: " + "; ".join(path_errors))
        else:
            valid_decisions.append({
                "path": path,
                "status": current["status"],
                "bucket": current["bucket"],
                "title": current["title"],
                "decision": decision["decision"],
            })

    duplicate_errors = [
        f"{path} has {len(decisions_by_path[path])} decisions"
        for path in duplicate_paths
    ]
    stale_errors = [
        f"{path} is not present in current git status"
        for path in stale_paths
    ]

    failed = bool(
        payload_errors
        or structural_errors
        or classification_errors
        or duplicate_errors
        or stale_errors
        or missing_paths
        or invalid_decisions
    )

    grouped: dict[str, list[dict]] = {}
    for decision in valid_decisions:
        grouped.setdefault(decision["decision"], []).append(decision)

    lines.append("## Verdict")
    lines.append("")
    lines.append(f"- Status: **{'blocked' if failed else 'ready'}**")
    lines.append(f"- Dry-run only: yes")
    lines.append(f"- Current working-tree entries requiring decisions: {len(current_decision_entries)}")
    lines.append(f"- Valid path decisions: {len(valid_decisions)}")
    lines.append(f"- Missing path decisions: {len(missing_paths)}")
    lines.append(f"- Invalid path decisions: {len(invalid_decisions)}")
    lines.append(f"- Duplicate path decisions: {len(duplicate_errors)}")
    lines.append(f"- Stale path decisions: {len(stale_errors)}")
    lines.append(f"- Classification errors: {len(classification_errors)}")
    lines.append("- Executes changes: no")
    lines.append("")
    lines.append("## Stop Rules")
    lines.append("")
    lines.append("- This plan is evidence only and does not stage, delete, ignore, reset, archive, or clean files.")
    lines.append("- Execute any batch only after an operator accepts the exact path list and command family.")
    lines.append("- Rerun --validate-decisions and --strict after each accepted batch.")
    lines.append("")

    if failed:
        lines.append("## Blocking Problems")
        lines.append("")
        append_validation_entries(lines, payload_errors + structural_errors + classification_errors)
        if missing_paths:
            lines.append(f"- {len(missing_paths)} paths still have no valid decision")
        append_validation_entries(lines, invalid_decisions, empty_text="- no invalid decisions")
        append_validation_entries(lines, duplicate_errors, empty_text="- no duplicate decisions")
        append_validation_entries(lines, stale_errors, empty_text="- no stale decisions")
        lines.append("")
        lines.append("## Next Step")
        lines.append("")
        lines.append("- Fill missing decisions in tmp/source-hygiene-decision-summary.json using tmp/source-hygiene-decision-packets/index.md, then rerun this plan.")
    else:
        lines.append("## Planned Decision Groups")
        lines.append("")
        for decision_text in sorted(grouped):
            rows = grouped[decision_text]
            lines.append(f"### {decision_text}")
            lines.append("")
            lines.append(f"- Count: {len(rows)}")
            lines.append("")
            lines.append("| Status | Bucket | Path |")
            lines.append("| --- | --- | --- |")
            for row in rows:
                safe_path = row["path"].replace("|", "\\|")
                lines.append(f"| {row['status']} | {row['bucket']} | {safe_path} |")
            lines.append("")

    plan_payload = {
        "schema_version": 1,
        "generated_at": created_at,
        "branch": branch_name,
        "head": head_commit,
        "repo_root": str(repo_root),
        "decision_manifest": str(decision_input_path) if decision_input_path else "",
        "status": "blocked" if failed else "ready",
        "dry_run_only": True,
        "executes_changes": False,
        "counts": {
            "current_working_tree_entries_requiring_decisions": len(current_decision_entries),
            "valid_path_decisions": len(valid_decisions),
            "missing_path_decisions": len(missing_paths),
            "invalid_path_decisions": len(invalid_decisions),
            "duplicate_path_decisions": len(duplicate_errors),
            "stale_path_decisions": len(stale_errors),
            "classification_errors": len(classification_errors),
        },
        "blocking_problems": {
            "manifest_errors": payload_errors + structural_errors,
            "classification_errors": classification_errors,
            "invalid_decisions": invalid_decisions,
            "duplicate_decisions": duplicate_errors,
            "stale_decisions": stale_errors,
            "missing_path_decision_count": len(missing_paths),
        },
        "decision_groups": [
            {
                "decision": decision_text,
                "count": len(grouped[decision_text]),
                "entries": [
                    {
                        "status": row["status"],
                        "bucket": row["bucket"],
                        "path": row["path"],
                    }
                    for row in grouped[decision_text]
                ],
            }
            for decision_text in sorted(grouped)
        ],
        "stop_rules": [
            "this plan is evidence only and does not stage, delete, ignore, reset, archive, or clean files",
            "execute any batch only after an operator accepts the exact path list and command family",
            "rerun --validate-decisions and --strict after each accepted batch",
        ],
    }

    if json_output_path is not None:
        json_output_path.parent.mkdir(parents=True, exist_ok=True)
        json_output_path.write_text(json.dumps(plan_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote source hygiene decision plan to {output_path}")
    if failed:
        raise SystemExit(1)
    raise SystemExit(0)

if mode == "decision-packets":
    output_path.mkdir(parents=True, exist_ok=True)
    packet_files: list[tuple[str, str, int]] = []
    total_entries = sum(len(bucket_entries) for _, _, bucket_entries, _ in decision_buckets)

    for index, (key, title, bucket_entries, decisions) in enumerate(decision_buckets, start=1):
        packet_name = f"{index:02d}-{key}.md"
        packet_path = output_path / packet_name
        packet_files.append((packet_name, title, len(bucket_entries)))

        packet_lines: list[str] = []
        packet_lines.append(f"# Source Hygiene Packet: {title}")
        packet_lines.append("")
        packet_lines.append(f"Generated at: {created_at}")
        packet_lines.append(f"Branch: {branch_name}")
        packet_lines.append(f"HEAD: {head_commit}")
        packet_lines.append(f"Repo root: {repo_root}")
        packet_lines.append(f"Bucket key: {key}")
        packet_lines.append(f"Entry count: {len(bucket_entries)}")
        packet_lines.append("")
        packet_lines.append("## Stop Rules")
        packet_lines.append("")
        packet_lines.append("- Do not delete, stage, ignore, reset, archive, or clean entries from this packet without an explicit operator decision.")
        packet_lines.append("- Keep repo backups and odd local paths outside automated cleanup.")
        packet_lines.append("- Rerun source hygiene validation after every decision batch.")
        packet_lines.append("")
        packet_lines.append("## Allowed Decisions")
        packet_lines.append("")
        for decision in decisions:
            packet_lines.append(f"- [ ] {decision}")
        packet_lines.append("")
        packet_lines.append("## Paths")
        packet_lines.append("")
        if bucket_entries:
            packet_lines.append("| Status | Path | Decision | Owner | Timestamp | Note |")
            packet_lines.append("| --- | --- | --- | --- | --- | --- |")
            for status, path in bucket_entries:
                safe_path = path.replace("|", "\\|")
                packet_lines.append(f"| {status} | {safe_path} |  |  |  |  |")
        else:
            packet_lines.append("- none")
        packet_lines.append("")
        packet_lines.append("## Validation")
        packet_lines.append("")
        packet_lines.append("After decisions are transcribed into the JSON manifest, run:")
        packet_lines.append("bin/source-hygiene-report.sh --validate-decisions tmp/source-hygiene-decision-summary.json tmp/source-hygiene-decision-validation.md")
        packet_path.write_text("\n".join(packet_lines) + "\n", encoding="utf-8")

    index_lines: list[str] = []
    index_lines.append("# Source Hygiene Decision Packets")
    index_lines.append("")
    index_lines.append(f"Generated at: {created_at}")
    index_lines.append(f"Branch: {branch_name}")
    index_lines.append(f"HEAD: {head_commit}")
    index_lines.append(f"Repo root: {repo_root}")
    index_lines.append(f"Total entries requiring decisions: {total_entries}")
    index_lines.append("")
    index_lines.append("## Packets")
    index_lines.append("")
    index_lines.append("| Packet | Bucket | Entries |")
    index_lines.append("| --- | --- | ---: |")
    for packet_name, title, count in packet_files:
        index_lines.append(f"| {packet_name} | {title} | {count} |")
    index_lines.append("")
    index_lines.append("## Workflow")
    index_lines.append("")
    index_lines.append("1. Review one packet at a time.")
    index_lines.append("2. Record path-level decisions in tmp/source-hygiene-decision-summary.json.")
    index_lines.append("3. Validate with bin/source-hygiene-report.sh --validate-decisions tmp/source-hygiene-decision-summary.json tmp/source-hygiene-decision-validation.md.")
    index_lines.append("4. Only after valid operator decisions exist, perform the approved staging, defer, archive, ignore, or cleanup batch.")
    (output_path / "index.md").write_text("\n".join(index_lines) + "\n", encoding="utf-8")

    print(f"Wrote source hygiene decision packets to {output_path}")
    raise SystemExit(0)

if mode == "decision-json":
    bucket_payload = []
    for key, title, bucket_entries, decisions in decision_buckets:
        bucket_payload.append({
            "key": key,
            "title": title,
            "count": len(bucket_entries),
            "allowed_decisions": decisions,
            "entries": [entry_with_decision_template(status, path) for status, path in bucket_entries],
        })
    payload = {
        "schema_version": 1,
        "generated_at": created_at,
        "branch": branch_name,
        "head": head_commit,
        "repo_root": str(repo_root),
        "strict_status": "fail" if entries else "pass",
        "operator_decision_required": bool(entries),
        "counts": {
            "working_tree_entries": len(entries),
            "source_focused_entries": len(source_entries),
            "generated_local_entries": len(generated_entries),
            "source_review_stage": len(operator_review_entries) + len(source_review_entries),
            "repo_backup_human_decision": len(repo_backup_entries),
            "odd_local_human_decision": len(odd_local_entries),
            "unresolved_human_decision": len(unresolved_decision_entries),
            "generated_local_clean_or_ignore": len(generated_clean_or_ignore_entries),
            "config_autoconf_artifacts": len(config_artifact_entries),
            "install_test_release_artifacts": len(install_test_release_entries),
        },
        "buckets": bucket_payload,
        "operator_decision_instructions": {
            "path_level_required": True,
            "fill_fields": ["decision", "decision_owner", "decision_timestamp", "decision_note"],
            "validation_command": "bin/source-hygiene-report.sh --validate-decisions <decision-json> tmp/source-hygiene-decision-validation.md",
        },
        "stop_rules": [
            "do not delete, stage, ignore, or reset entries without an explicit operator decision",
            "handle repo backups and odd/local paths outside automated cleanup",
            "rerun strict source hygiene after every decision batch",
        ],
    }
    output_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote source hygiene decision JSON to {output_path}")
    raise SystemExit(0)

if mode == "decision-summary":
    summary_lines: list[str] = []
    summary_lines.append("# Source Hygiene Decision Summary")
    summary_lines.append("")
    summary_lines.append(f"Generated at: {created_at}")
    summary_lines.append(f"Branch: {branch_name}")
    summary_lines.append(f"HEAD: {head_commit}")
    summary_lines.append(f"Repo root: {repo_root}")
    if entries:
        summary_lines.append("Strict status: fail until every working-tree entry is intentionally resolved")
    else:
        summary_lines.append("Strict status: pass")
    summary_lines.append("")
    summary_lines.append("## Counts")
    summary_lines.append("")
    summary_lines.append("| Bucket | Count | Required decision |")
    summary_lines.append("| --- | ---: | --- |")
    summary_lines.append(f"| Source review/stage | {len(source_review_entries) + len(operator_review_entries)} | stage / defer / reject |")
    summary_lines.append(f"| Repo backup human-decision items | {len(repo_backup_entries)} | preserve / archive outside repo / ignore later / clean with approval |")
    summary_lines.append(f"| Odd/local human-decision items | {len(odd_local_entries)} | stage / preserve / ignore later / clean with approval |")
    summary_lines.append(f"| Unresolved human-decision items | {len(unresolved_decision_entries)} | explicit per-path decision |")
    summary_lines.append(f"| Generated/local clean-or-ignore | {len(generated_clean_or_ignore_entries)} | preserve evidence / clean with approval / ignore later |")
    summary_lines.append(f"| Config/autoconf artifacts | {len(config_artifact_entries)} | preserve active config / regenerate / clean with approval |")
    summary_lines.append(f"| Install/test/release artifacts | {len(install_test_release_entries)} | preserve evidence / clean with approval |")
    summary_lines.append("")
    summary_lines.append("## Operator Decisions")
    summary_lines.append("")
    for _, title, bucket_entries, decisions in decision_buckets:
        append_decision_section(summary_lines, title, bucket_entries, decisions)
    output_path.write_text("\n".join(summary_lines) + "\n", encoding="utf-8")
    print(f"Wrote source hygiene decision summary to {output_path}")
    raise SystemExit(0)

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
lines.append(f"- Repo-backup human-decision entries: {len(repo_backup_entries)}")
lines.append(f"- Odd/local human-decision entries: {len(odd_local_entries)}")
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
lines.append(f"| Repo backup human-decision items | {len(repo_backup_entries)} | Confirm whether local Git backup directories should be archived, ignored, or cleaned outside this packet. |")
lines.append(f"| Odd/local human-decision items | {len(odd_local_entries)} | Inspect unusual top-level/local governance files before cleanup, ignore, or staging. |")
lines.append(f"| Unresolved human-decision items | {len(unresolved_decision_entries)} | Requires explicit operator decision before staging, cleanup, or ignore changes. |")
lines.append("")
lines.append("## Suggested Non-Destructive Triage")
lines.append("")
lines.append("Run these commands from the repository root to inspect the largest blocker classes before any cleanup or staging decision:")
lines.append("")
lines.append("```sh")
lines.append("git status --short -- bin docs tests .github sysui kqoffice")
lines.append("git status --short -- '.git.bak-*'")
lines.append("git status --short -- ':(literal):-' config.warn config_host_lang.mk")
lines.append("```")
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
lines.append("### Repo backup human-decision items")
lines.append("")
append_examples(lines, repo_backup_entries)
lines.append("")
lines.append("### Odd/local human-decision items")
lines.append("")
append_examples(lines, odd_local_entries)
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
