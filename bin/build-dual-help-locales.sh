#!/usr/bin/env bash
# Build separate offline help trees:
#   help/en-US  -> upstream English .xhp
#   help/zh-CN  -> downstream Chinese .xhp snapshot
#
# LibreOffice generates all help langs from one source tree in a single pass,
# so we use a two-pass workflow and merge the results.
#
# Usage:
#   bin/build-dual-help-locales.sh

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${KDOFFICE_SRC_ROOT:-/Users/lu/kdoffice-src}"
BUILD="/Users/lu/可点office"
SNAPSHOT="$REPO/tmp/help-zh-cn-xhp-snapshot"
STAGE="$REPO/tmp/help-dual-locale-staging"
MAKE="${MAKE:-gmake}"

die() { echo "build-dual-help-locales: $*" >&2; exit 1; }

[[ -d "$SNAPSHOT" ]] || die "missing Chinese snapshot at $SNAPSHOT (run restore-help-en-us-upstream.sh first)"

help_dir() {
  for candidate in \
    "$BUILD/instdir/可圈办公.app/Contents/Resources/help" \
    "$BUILD/instdir/可圈office.app/Contents/Resources/help" \
    "$BUILD/test-install/可圈办公.app/Contents/Resources/help" \
    "$BUILD/test-install/可圈office.app/Contents/Resources/help"
  do
    if [[ -d "$candidate" ]]; then
      echo "$candidate"
      return
    fi
  done
  echo ""
}

restore_snapshot() {
  echo "[dual-help] restoring Chinese .xhp snapshot"
  python3 - "$SNAPSHOT" "$SRC/helpcontent2/source" <<'PY'
import pathlib
import shutil
import sys

snapshot = pathlib.Path(sys.argv[1])
target_root = pathlib.Path(sys.argv[2])
count = 0
for path in snapshot.rglob('*.xhp'):
    rel = path.relative_to(snapshot)
    target = target_root / rel
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, target)
    count += 1
print(f"[dual-help] restored {count} Chinese .xhp files")
PY
}

restore_upstream_english() {
  echo "[dual-help] restoring upstream English .xhp"
  (
    cd "$SRC/helpcontent2"
    find source -name '*.xhp' -print0 | xargs -0 git checkout HEAD --
  )
}

stage_tree() {
  local src="$1"
  local dst="$2"
  rm -rf "$dst"
  mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "$src/" "$dst/"
  else
    cp -R "$src/." "$dst/"
  fi
}

echo "[dual-help] pass 1/2: build English help/en-US"
restore_upstream_english
(
  cd "$BUILD"
  "$MAKE" helpcontent2.build
)

ROOT="$(help_dir)"
[[ -n "$ROOT" && -d "$ROOT/en-US" ]] || die "English help build did not produce help/en-US"
rm -rf "$STAGE"
stage_tree "$ROOT/en-US" "$STAGE/en-US"

echo "[dual-help] pass 2/2: build Chinese help and materialize zh-CN"
restore_snapshot
(
  cd "$BUILD"
  "$MAKE" helpcontent2.clean
  "$MAKE" helpcontent2.build
)
[[ -d "$ROOT/en-US" ]] || die "Chinese help build did not produce help/en-US"
"$REPO/bin/sync-help-zh-cn-tree.sh" --help-root "$ROOT"
[[ -d "$ROOT/zh-CN" ]] || die "zh-CN sync failed"
stage_tree "$ROOT/zh-CN" "$STAGE/zh-CN"

echo "[dual-help] merging staged locale trees into $ROOT"
stage_tree "$STAGE/en-US" "$ROOT/en-US"
stage_tree "$STAGE/zh-CN" "$ROOT/zh-CN"

restore_upstream_english

if [[ -d "$BUILD/test-install" ]]; then
  for app in "$BUILD/test-install/可圈办公.app" "$BUILD/test-install/可圈office.app"; do
    target="$app/Contents/Resources/help"
    if [[ -d "$(dirname "$target")" ]]; then
      mkdir -p "$target"
      stage_tree "$STAGE/en-US" "$target/en-US"
      stage_tree "$STAGE/zh-CN" "$target/zh-CN"
      cp -f "$BUILD/instdir/可圈办公.app/Contents/Resources/help/help2.js" "$target/help2.js" 2>/dev/null \
        || cp -f "$BUILD/instdir/可圈office.app/Contents/Resources/help/help2.js" "$target/help2.js" 2>/dev/null \
        || true
      cp -f "$BUILD/instdir/可圈办公.app/Contents/Resources/help/languages.js" "$target/languages.js" 2>/dev/null \
        || cp -f "$BUILD/instdir/可圈office.app/Contents/Resources/help/languages.js" "$target/languages.js" 2>/dev/null \
        || true
    fi
  done
fi

if [[ -x "$REPO/tests/help-locale-tree-test.sh" ]]; then
  HELP_ROOT="$ROOT" "$REPO/tests/help-locale-tree-test.sh" 2>/dev/null || "$REPO/tests/help-locale-tree-test.sh"
fi

echo "[dual-help] done"