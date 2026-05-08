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
tarballs_dir="${KDOFFICE_TARBALLS_DIR:-$src_root/external/tarballs}"
output_path="$repo_root/tmp/validator-readiness.md"
mode="advisory"

usage() {
    cat <<'EOF'
Usage:
  validator-readiness.sh [options] [output-file]

Options:
  --strict     Exit non-zero when any validator asset, wrapper, or Java runtime
               requirement is missing. Use this for beta/release gates.
  -h, --help

Reports whether optional document validators are available locally.
Missing validators are beta-readiness blockers, but advisory mode does not
download assets or fail alpha smoke gates.
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

python3 - "$repo_root" "$src_root" "$tarballs_dir" "$output_path" "$mode" <<'PY'
from pathlib import Path
import hashlib
import os
import shutil
import subprocess
import sys

repo_root = Path(sys.argv[1])
src_root = Path(sys.argv[2])
tarballs_dir = Path(sys.argv[3])
output_path = Path(sys.argv[4])
mode = sys.argv[5]

validators = [
    {
        "name": "ODF Validator",
        "asset": "odfvalidator-0.13.0-jar-with-dependencies.jar",
        "wrapper": "bin/odfvalidator.sh",
        "scope": "ODT/ODS/ODP package conformance",
        "source": "https://repo1.maven.org/maven2/org/odftoolkit/odfvalidator/0.13.0/odfvalidator-0.13.0-jar-with-dependencies.jar",
        "trust": "Maven Central artifact; upstream SHA-1 verified; Apache-2.0 per published POM.",
    },
    {
        "name": "Officeotron",
        "asset": "officeotron-0.8.8.jar",
        "wrapper": "bin/officeotron.sh",
        "scope": "ODF package best-practice checks",
        "source": "not acquired",
        "trust": "No trusted HTTPS release artifact for exact 0.8.8 filename was found locally or from project/vendor release sources in this round.",
    },
    {
        "name": "veraPDF",
        "asset": "verapdf-cli-1.29.0.jar",
        "wrapper": "bin/verapdf.sh",
        "scope": "PDF/PDF-A conformance checks",
        "source": "not acquired",
        "trust": "The vendor download page currently exposes installer archives, but no trusted exact verapdf-cli-1.29.0.jar artifact/checksum was found in this round.",
    },
]


def created_at() -> str:
    return subprocess.check_output(["date", "+%Y-%m-%d %H:%M:%S %z"], text=True).strip()


def file_state(path: Path) -> str:
    if not path.exists():
        return "missing"
    if not path.is_file():
        return "not-file"
    if not path.stat().st_size:
        return "empty"
    return "present"


def executable_state(path: Path) -> str:
    if not path.exists():
        return "missing"
    if not path.is_file():
        return "not-file"
    return "executable" if path.stat().st_mode & 0o111 else "not-executable"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def shell_quote(value: str) -> str:
    return "'" + value.replace("'", "'\\''") + "'"


def smoke_help_arg(name: str) -> str:
    return "-h" if name == "ODF Validator" else "--help"


def smoke_wrapper(wrapper_path: Path, name: str) -> tuple[str, str]:
    env = os.environ.copy()
    env["KDOFFICE_TARBALLS_DIR"] = str(tarballs_dir)
    try:
        proc = subprocess.run(
            [str(wrapper_path), smoke_help_arg(name)],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=15,
            env=env,
        )
    except Exception as exc:
        return "error", f"{type(exc).__name__}: {exc}"
    output = " ".join((proc.stdout or "").split())
    if len(output) > 240:
        output = output[:237] + "..."
    if proc.returncode == 0:
        return "passed", output or "no output"
    return "failed", output or f"exit {proc.returncode}"


def java_status() -> tuple[str, str]:
    java = shutil.which("java")
    if not java:
        return "missing", "java not found on PATH"
    try:
        proc = subprocess.run(
            [java, "-version"],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=8,
        )
        first = (proc.stdout or "").splitlines()[0] if proc.stdout else f"exit {proc.returncode}"
        if proc.returncode == 0:
            return "present", f"{java}: {first}"
        return "error", f"{java}: {first}"
    except Exception as exc:
        return "error", f"{java}: {type(exc).__name__}: {exc}"


java_state, java_detail = java_status()
rows = []
ready_count = 0

for item in validators:
    asset_path = tarballs_dir / item["asset"]
    wrapper_path = repo_root / item["wrapper"]
    asset_state = file_state(asset_path)
    wrapper_state = executable_state(wrapper_path)
    details = []
    if asset_state == "present":
        stat = asset_path.stat()
        details.append(f"size={stat.st_size}")
        details.append(f"sha256={sha256(asset_path)}")
    smoke_state = "not-run"
    smoke_detail = "unavailable until asset, wrapper, and Java are present"
    blockers = []
    if asset_state != "present":
        blockers.append(f"asset-{asset_state}")
    if wrapper_state != "executable":
        blockers.append(f"wrapper-{wrapper_state}")
    if java_state != "present":
        blockers.append("missing-java" if java_state == "missing" else "java-error")
    if not blockers:
        smoke_state, smoke_detail = smoke_wrapper(wrapper_path, item["name"])
        if smoke_state == "passed":
            state = "ready"
            ready_count += 1
        else:
            state = f"wrapper-smoke-{smoke_state}"
    else:
        state = ", ".join(blockers)
    rows.append({
        **item,
        "asset_path": asset_path,
        "asset_state": asset_state,
        "wrapper_state": wrapper_state,
        "smoke_state": smoke_state,
        "smoke_detail": smoke_detail,
        "state": state,
        "details": ", ".join(details) if details else "-",
    })

all_ready = ready_count == len(validators)
strict_failed = mode == "strict" and not all_ready

lines = []
lines.append("# Validator Readiness")
lines.append("")
lines.append(f"Generated at: {created_at()}")
lines.append(f"Mode: **{mode}**")
lines.append(f"Repo root: {repo_root}")
lines.append(f"Source root: {src_root}")
lines.append(f"Tarballs dir: `{tarballs_dir}`")
lines.append(f"Java: **{java_state}** ({java_detail})")
lines.append("")
lines.append("## Inventory")
lines.append("")
lines.append("| Validator | Scope | Asset | Wrapper | Smoke | State | Details | Source/Trust |")
lines.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
for row in rows:
    lines.append(
        f"| {row['name']} | {row['scope']} | `{row['asset_path']}` {row['asset_state']} | "
        f"`{row['wrapper']}` {row['wrapper_state']} | {row['smoke_state']} | **{row['state']}** | {row['details']} | {row['source']} — {row['trust']} |"
    )
lines.append("")
lines.append("## Summary")
lines.append("")
lines.append(f"- Ready validators: {ready_count}/{len(validators)}")
if all_ready:
    lines.append("- Status: **ready**")
elif mode == "strict":
    lines.append("- Status: **fail**")
else:
    lines.append("- Status: **missing-assets**")
lines.append("- Missing validators are reported as skipped in compatibility smoke runs during alpha.")
lines.append("- For beta/release, run this script with `--strict` and make missing assets blocking.")
lines.append("- See `docs/compatibility/validator-assets-release-packet.md` for acquisition, provenance, checksum, and licensing notes.")
lines.append("")
missing_rows = [row for row in rows if row["state"] != "ready"]
if missing_rows:
    lines.append("## Missing Asset Blockers")
    lines.append("")
    lines.append("These validators remain blockers until the exact asset is present, trusted, and wrapper-smoked. Required evidence fields: Source URL, Download method, Filename, File size, SHA-256, upstream checksum status, license / redistribution note, and Wrapper smoke command and result.")
    lines.append("")
    for row in missing_rows:
        lines.append(f"- `{row['asset']}` for {row['name']}: {row['state']}. Source/trust note: {row['source']} — {row['trust']}")
    lines.append("")
lines.append("## Wrapper Smoke Results")
lines.append("")
for row in rows:
    command = f"KDOFFICE_TARBALLS_DIR={shell_quote(str(tarballs_dir))} {shell_quote(str(repo_root / row['wrapper']))} {smoke_help_arg(row['name'])}"
    if row["smoke_state"] == "passed":
        lines.append(f"- {row['name']}: **passed** `{command}` — {row['smoke_detail']}")
    elif row["smoke_state"] in {"failed", "error"}:
        lines.append(f"- {row['name']}: **{row['smoke_state']}** `{command}` — {row['smoke_detail']}")
    else:
        lines.append(f"- {row['name']}: not run until `{row['asset']}` is trusted and present.")
lines.append("")
lines.append("## Required Local Assets")
lines.append("")
lines.append("Place these exact filenames in the tarballs directory or set `KDOFFICE_TARBALLS_DIR` to a directory containing them:")
lines.append("")
for item in validators:
    lines.append(f"- `{item['asset']}` for {item['name']}")
lines.append("")
lines.append("## Next Commands")
lines.append("")
lines.append("- `bin/validator-readiness.sh tmp/validator-readiness.md`")
lines.append("- `bin/validator-readiness.sh --strict tmp/validator-readiness-strict.md`")
lines.append("- `bin/compatibility-roundtrip.sh --manifest docs/compatibility/smoke-manifest.tsv --run-name <name>`")

output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Wrote validator readiness report to {output_path}")

if strict_failed:
    raise SystemExit(1)
PY
