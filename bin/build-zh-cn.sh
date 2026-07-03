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

# Pre-build path fix
echo "[wrapper] pre-build path normalization..."
python3 <<PY
from pathlib import Path
fixed = 0
for root in ['$REPO/workdir', '$SRC/workdir']:
    if not Path(root).exists():
        continue
    for p in Path(root).rglob('*'):
        if not p.is_file(): continue
        try: txt = p.read_text(encoding='utf-8', errors='ignore')
        except: continue
        if '/private/tmp/kdoffice-ascii' in txt:
            p.write_text(txt.replace('/private/tmp/kdoffice-ascii', '/Users/lu/kdoffice-build'), encoding='utf-8')
            fixed += 1
print(f"  fixed: {fixed}")
PY

# Watchdog: scan list files every 3s during build
WATCHDOG_PID=""
start_watchdog() {
  (
    while true; do
      python3 -c "
from pathlib import Path
for p in Path('$REPO/workdir').rglob('*.list'):
    if not p.is_file(): continue
    try: txt = p.read_text(encoding='utf-8', errors='ignore')
    except: continue
    if '/private/tmp/kdoffice-ascii' in txt:
        p.write_text(txt.replace('/private/tmp/kdoffice-ascii', '/Users/lu/kdoffice-build'), encoding='utf-8')
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

# Run gmake
echo "[wrapper] gmake $TARGET ..."
LOG="$REPO/tmp/build-zh-cn-wrapper.log"
mkdir -p "$(dirname "$LOG")"
if ! gmake "$TARGET" > "$LOG" 2>&1; then
  echo "[wrapper] gmake $TARGET FAILED; tail:" >&2
  tail -20 "$LOG" >&2
  exit 1
fi
echo "[wrapper] gmake $TARGET OK"

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

stop_watchdog
echo "[wrapper] DONE"
