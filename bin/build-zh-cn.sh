#!/usr/bin/env bash
# Build 可圈办公 with --with-lang=zh-CN, working around the
# ASCII-workdir / Chinese-path incompatibility in xsltproc.
#
# Wraps gmake test-install with:
#  - background watchdog that rewrites stale `/private/tmp/kdoffice-ascii`
#    paths to `/Users/lu/kdoffice-build` (ASCII symlink to BUILDDIR)
#  - post-build patch of registry_zh-CN.xcd from XcuResTarget contents
#    (works around L10N pipeline list-generation bug)
#
# Usage: bin/build-zh-cn.sh [--target test-install|build]
# Default target: test-install

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${KDOFFICE_SRC_ROOT:-/Users/lu/kdoffice-src}"
ASCII_LINK="/Users/lu/kdoffice-build"
TARGET="test-install"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:?}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--target test-install|build]"
      exit 0 ;;
    *) echo "Unknown: $1" >&2; exit 2 ;;
  esac
done

# Ensure ASCII symlink exists (created by python to avoid zsh utf-8 quirks)
if [[ ! -L "$ASCII_LINK" ]]; then
  python3 -c "import os; os.path.lexists('$ASCII_LINK') or os.symlink('$REPO', '$ASCII_LINK')"
fi
[[ -d "$ASCII_LINK/workdir" ]] || { echo "ASCII symlink broken: $ASCII_LINK" >&2; exit 1; }

# Pre-build path fix: xsltproc breaks on non-ASCII workdir paths in *.list files.
normalize_workdir_lists() {
  python3 - "$REPO" "$SRC" "$ASCII_LINK" <<'PY'
import pathlib
import sys

repo, src, ascii_link = sys.argv[1:4]
replacements = [
    ('/private/tmp/kdoffice-ascii', ascii_link),
    (repo, ascii_link),
    ('/Users/lu/可点office', ascii_link),
    ('/Volumes/MobileDrive/devpc/可点office', ascii_link),
]
fixed = 0
for root in [pathlib.Path(repo) / 'workdir', pathlib.Path(src) / 'workdir']:
    if not root.exists():
        continue
    for path in root.rglob('*.list'):
        try:
            text = path.read_text(encoding='utf-8', errors='ignore')
        except OSError:
            continue
        updated = text
        for old, new in replacements:
            updated = updated.replace(old, new)
        if updated != text:
            path.write_text(updated, encoding='utf-8')
            fixed += 1
print(f"  fixed list files: {fixed}")
PY
}

echo "[wrapper] pre-build path normalization..."
normalize_workdir_lists

# Watchdog: scan list files every 3s during build
WATCHDOG_PID=""
start_watchdog() {
  (
    while true; do
      python3 -c "
import pathlib, sys
repo, ascii_link = '$REPO', '$ASCII_LINK'
replacements = [
    ('/private/tmp/kdoffice-ascii', ascii_link),
    (repo, ascii_link),
    ('/Users/lu/可点office', ascii_link),
    ('/Volumes/MobileDrive/devpc/可点office', ascii_link),
]
for p in pathlib.Path(repo, 'workdir').rglob('*.list'):
    if not p.is_file():
        continue
    try:
        txt = p.read_text(encoding='utf-8', errors='ignore')
    except OSError:
        continue
    updated = txt
    for old, new in replacements:
        updated = updated.replace(old, new)
    if updated != txt:
        p.write_text(updated, encoding='utf-8')
" 2>/dev/null
      sleep 3
    done
  ) &
  WATCHDOG_PID=$!
  echo "[wrapper] watchdog PID: $WATCHDOG_PID"
}
stop_watchdog() {
  [[ -n "${WATCHDOG_PID:-}" ]] && kill "$WATCHDOG_PID" 2>/dev/null || true
}
trap stop_watchdog EXIT INT TERM

start_watchdog

# Ensure Langpack-zh-CN.xcu exists (empty file breaks postprocess xslt).
ensure_langpack_xcu() {
  local xcu="$REPO/workdir/XcuLangpackTarget/Langpack-zh-CN.xcu"
  local tmpl="$SRC/officecfg/registry/data/org/openoffice/Langpack.xcu.tmpl"
  local sedfile="$SRC/officecfg/util/delcomment.sed"
  if [[ ! -s "$xcu" && -f "$tmpl" && -f "$sedfile" ]]; then
    echo "[wrapper] generating Langpack-zh-CN.xcu from template"
    mkdir -p "$(dirname "$xcu")"
    sed -e 's/__LANGUAGE__/zh-CN/' -f "$sedfile" "$tmpl" > "$xcu"
  fi
}

ensure_langpack_xcu

# Run gmake with ASCII workdir hint for postprocess xslt path rewriting.
echo "[wrapper] gmake $TARGET ..."
LOG="$REPO/tmp/build-zh-cn-wrapper.log"
mkdir -p "$(dirname "$LOG")"
export KQOFFICE_ASCII_WORKDIR="$ASCII_LINK/workdir"
if ! gmake "$TARGET" > "$LOG" 2>&1; then
  echo "[wrapper] gmake $TARGET FAILED; tail:" >&2
  tail -20 "$LOG" >&2
  exit 1
fi
echo "[wrapper] gmake $TARGET OK"

# Post-build: patch Langpack-zh-CN.xcd (InstalledLocales) if xslt failed earlier.
LANG_XCU="$REPO/workdir/XcuLangpackTarget/Langpack-zh-CN.xcu"
LANG_LIST="$REPO/workdir/CustomTarget/postprocess/registry/Langpack-zh-CN.list"
LANG_XCD="$REPO/workdir/XcdTarget/Langpack-zh-CN.xcd"
if [[ -s "$LANG_XCU" ]]; then
  echo "[wrapper] patching Langpack-zh-CN.xcd..."
  normalize_workdir_lists
  printf '%s\n' '<list><dependency file="main"/>' \
    "  <filename>${ASCII_LINK}/workdir/XcuLangpackTarget/Langpack-zh-CN.xcu</filename>" \
    '</list>' > "$LANG_LIST"
  ( cd "$ASCII_LINK" && xsltproc --nonet -o "workdir/XcdTarget/Langpack-zh-CN.xcd" \
      "$SRC/solenv/bin/packregistry.xslt" \
      "workdir/CustomTarget/postprocess/registry/Langpack-zh-CN.list" ) >/dev/null 2>&1 || true
  for dest in \
    "$REPO/instdir/可圈办公.app/Contents/Resources/registry/Langpack-zh-CN.xcd" \
    "$REPO/test-install/可圈办公.app/Contents/Resources/registry/Langpack-zh-CN.xcd" \
    "$REPO/test-install/可圈办公.app/Contents/Resources/registry/res/fcfg_langpack_zh-CN.xcd"
  do
    if [[ -f "$LANG_XCD" && -d "$(dirname "$dest")" ]]; then
      cp "$LANG_XCD" "$dest"
      echo "[wrapper] deployed Langpack-zh-CN.xcd -> ${dest##*/}"
    fi
  done
fi

# Post-build: patch registry_zh-CN.xcd
RES_DIR="$REPO/workdir/XcuResTarget/registry/zh-CN"
if [[ -d "$RES_DIR" ]]; then
  LIST="$REPO/workdir/CustomTarget/postprocess/registry/registry_zh-CN.list"
  XCD="$REPO/workdir/XcdTarget/registry_zh-CN.xcd"
  echo "[wrapper] patching registry_zh-CN.xcd from XcuResTarget..."
  python3 <<PY
from pathlib import Path
xcus = sorted(Path('$RES_DIR').rglob('*.xcu'))
ascii_paths = [str(p).replace('$REPO', '$ASCII_LINK') for p in xcus]
content = '<list>\n' + '\n'.join(f'  <filename>{p}</filename>' for p in ascii_paths) + '\n</list>\n'
Path('$LIST').write_text(content)
print(f"  list: {len(xcus)} entries")
PY
  ( cd "$ASCII_LINK" && xsltproc --nonet -o "workdir/XcdTarget/registry_zh-CN.xcd" \
      "$SRC/solenv/bin/packregistry.xslt" \
      "workdir/CustomTarget/postprocess/registry/registry_zh-CN.list" 2>&1 ) | head -3 >&2 || true

  # Deploy to test-install if it exists
  TEST_RES="$REPO/test-install/可圈办公.app/Contents/Resources/registry/res/registry_zh-CN.xcd"
  if [[ -d "$(dirname "$TEST_RES")" ]]; then
    cp "$XCD" "$TEST_RES"
    echo "[wrapper] deployed registry_zh-CN.xcd ($(stat -f%z "$XCD") bytes) -> test-install"
  fi
fi

# Build separate help/en-US (English) and help/zh-CN (Chinese) trees.
if [[ -x "$REPO/bin/build-dual-help-locales.sh" ]]; then
  echo "[wrapper] building dual help locale trees..."
  "$REPO/bin/build-dual-help-locales.sh" || {
    echo "[wrapper] warning: dual help locale build failed" >&2
  }
elif [[ -x "$REPO/bin/sync-help-zh-cn-tree.sh" ]]; then
  echo "[wrapper] syncing help/zh-CN tree..."
  "$REPO/bin/sync-help-zh-cn-tree.sh" || {
    echo "[wrapper] warning: help/zh-CN sync failed; F1 may still open en-US paths" >&2
  }
fi

stop_watchdog
echo "[wrapper] DONE"
