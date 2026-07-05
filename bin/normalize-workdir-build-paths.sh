#!/usr/bin/env bash
# Rewrite stale BUILDDIR paths in generated workdir artifacts after migrating
# e.g. /Users/lu/可点office -> /Volumes/MobileDrive/devpc/可点office.
#
# Safe to run multiple times. Skips binary-ish outputs under CxxObject, etc.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ASCII_LINK="${KQOFFICE_ASCII_LINK:-/Users/lu/kdoffice-build}"

python3 - "$REPO" "$ASCII_LINK" <<'PY'
import pathlib
import sys

repo = pathlib.Path(sys.argv[1])
ascii_link = sys.argv[2]
workdir = repo / "workdir"
if not workdir.is_dir():
    raise SystemExit(f"workdir missing: {workdir}")

replacements = [
    ("/Users/lu/可点office", str(repo)),
    ("/private/tmp/kdoffice-ascii", ascii_link),
    (ascii_link, str(repo)),  # normalize ASCII alias back to canonical BUILDDIR
]

skip_dirs = {
    "CxxObject", "ObjCxxObject", "LinkTarget", "Headers", "Dep",
    "UnpackedTarball", "Pycache", "UITest",
}

text_suffixes = {
    ".mk", ".list", ".filelist", ".cxx", ".hxx", ".xml", ".xcu", ".xcs",
    ".ui", ".sed", ".cmd", ".sh", ".txt", ".log", ".d", ".xcu",
}

fixed_files = 0
fixed_hits = 0

for path in workdir.rglob("*"):
    if not path.is_file():
        continue
    if any(part in skip_dirs for part in path.parts):
        continue
    if path.suffix not in text_suffixes and path.name not in {
        "buildid", "config.status", "repository.mk",
    }:
        continue
    try:
        data = path.read_text(encoding="utf-8", errors="surrogateescape")
    except OSError:
        continue
    new = data
    local_hits = 0
    for old, new_path in replacements:
        if old in new:
            count = new.count(old)
            new = new.replace(old, new_path)
            local_hits += count
    if new != data:
        path.write_text(new, encoding="utf-8", errors="surrogateescape")
        fixed_files += 1
        fixed_hits += local_hits

print(f"normalize-workdir-build-paths: fixed {fixed_files} files ({fixed_hits} replacements)")
PY