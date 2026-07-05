#!/usr/bin/env bash
# Restore upstream English .xhp sources for the offline help corpus, then rebuild
# help/en-US only. Use this after bin/sync-help-zh-cn-tree.sh has materialized the
# Chinese-first corpus under help/zh-CN/.
#
# The script keeps a local snapshot of downstream Chinese .xhp files so they can
# be reapplied for future zh-CN refreshes.
#
# Usage:
#   bin/restore-help-en-us-upstream.sh [--snapshot-dir PATH] [--skip-build]
#
# Environment:
#   KDOFFICE_SRC_ROOT  source tree (default: /Users/lu/kdoffice-src)
#   KDOFFICE_BUILD_ROOT build tree (default: repo root)

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${KDOFFICE_SRC_ROOT:-/Users/lu/kdoffice-src}"
BUILD="${KDOFFICE_BUILD_ROOT:-$REPO}"
SNAPSHOT_DIR="$REPO/tmp/help-zh-cn-xhp-snapshot"
SKIP_BUILD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --snapshot-dir) SNAPSHOT_DIR="${2:?}"; shift 2 ;;
    --skip-build) SKIP_BUILD=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

HELPSRC="$SRC/helpcontent2/source"
if [[ ! -d "$HELPSRC" ]]; then
  echo "restore-help-en-us-upstream: missing $HELPSRC" >&2
  exit 1
fi

mkdir -p "$SNAPSHOT_DIR"

echo "[restore-help] snapshot downstream Chinese .xhp files -> $SNAPSHOT_DIR"
python3 - "$HELPSRC" "$SNAPSHOT_DIR" <<'PY'
import pathlib
import re
import shutil
import sys

src_root = pathlib.Path(sys.argv[1])
snapshot = pathlib.Path(sys.argv[2])
count = 0
for path in src_root.rglob('*.xhp'):
    try:
        text = path.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        continue
    if not re.search(r'[\u4e00-\u9fff]', text):
        continue
    rel = path.relative_to(src_root)
    target = snapshot / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, target)
    count += 1
print(f"[restore-help] snapshotted {count} Chinese .xhp files")
PY

echo "[restore-help] restoring upstream English .xhp from git"
(
  cd "$SRC/helpcontent2"
  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    echo "restore-help-en-us-upstream: helpcontent2 is not a git checkout" >&2
    exit 1
  fi
  find source -name '*.xhp' -print0 | xargs -0 git checkout HEAD --
)

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  if [[ -x "$REPO/bin/build-dual-help-locales.sh" ]]; then
    echo "[restore-help] building dual help locale trees"
    "$REPO/bin/build-dual-help-locales.sh"
  else
    echo "[restore-help] rebuilding helpcontent2 + postprocess"
    (
      cd "$BUILD"
      gmake helpcontent2.build postprocess
    )
  fi
fi

echo "[restore-help] done"
echo "[restore-help] Chinese .xhp snapshot kept at: $SNAPSHOT_DIR"
echo "[restore-help] Reapply downstream Chinese pages before the next zh-CN refresh if needed."