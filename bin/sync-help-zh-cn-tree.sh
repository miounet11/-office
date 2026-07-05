#!/usr/bin/env bash
# Sync the Chinese-first help corpus from help/en-US/ into help/zh-CN/.
#
# Downstream rewrites live in the en-US help source tree today; this post-build
# step materializes the expected zh-CN install path and rewrites internal links
# so F1 / Help menu routing can prefer zh-CN while en-US remains the English
# locale path (restored separately via bin/restore-help-en-us-upstream.sh).
#
# Usage:
#   bin/sync-help-zh-cn-tree.sh [--help-root PATH]
#
# Default help root: first existing path among
#   test-install/可圈办公.app/Contents/Resources/help
#   test-install/可圈office.app/Contents/Resources/help
#   instdir/可圈办公.app/Contents/Resources/help
#   instdir/可圈office.app/Contents/Resources/help

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
HELP_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help-root) HELP_ROOT="${2:?}"; shift 2 ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$HELP_ROOT" ]]; then
  for candidate in \
    "$REPO/test-install/可圈办公.app/Contents/Resources/help" \
    "$REPO/test-install/可圈office.app/Contents/Resources/help" \
    "$REPO/instdir/可圈办公.app/Contents/Resources/help" \
    "$REPO/instdir/可圈office.app/Contents/Resources/help"
  do
    if [[ -d "$candidate/en-US" ]]; then
      HELP_ROOT="$candidate"
      break
    fi
  done
fi

if [[ -z "$HELP_ROOT" || ! -d "$HELP_ROOT/en-US" ]]; then
  echo "sync-help-zh-cn-tree: no help/en-US tree found (pass --help-root)" >&2
  exit 1
fi

SRC="$HELP_ROOT/en-US"
DST="$HELP_ROOT/zh-CN"

echo "[sync-help] $SRC -> $DST"

rm -rf "$DST"
mkdir -p "$DST"

if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "$SRC/" "$DST/"
else
  cp -R "$SRC/." "$DST/"
fi

# Rewrite locale-specific references inside the zh-CN tree.
python3 - "$DST" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
text_ext = {'.html', '.htm', '.js', '.css', '.xsl'}
changed_files = 0
changed_hits = 0

patterns = [
    (re.compile(r'\ben-US/'), 'zh-CN/'),
    (re.compile(r'lang="en-US"'), 'lang="zh-CN"'),
    (re.compile(r"lang='en-US'"), "lang='zh-CN'"),
    (re.compile(r'\?Language=en-US\b'), '?Language=zh-CN'),
    (re.compile(r'&Language=en-US\b'), '&Language=zh-CN'),
]

for path in root.rglob('*'):
    if not path.is_file():
        continue
    if path.suffix.lower() not in text_ext:
        continue
    try:
        original = path.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        continue
    updated = original
    hits = 0
    for pattern, repl in patterns:
        updated, n = pattern.subn(repl, updated)
        hits += n
    if updated != original:
        path.write_text(updated, encoding='utf-8')
        changed_files += 1
        changed_hits += hits

print(f"[sync-help] rewrote {changed_hits} locale references in {changed_files} files under zh-CN")
PY

# Root-level help assets already declare both locales; nothing to do there.
if [[ ! -d "$DST/text" ]]; then
  echo "sync-help-zh-cn-tree: zh-CN/text missing after sync" >&2
  exit 1
fi

echo "[sync-help] zh-CN help tree ready ($(find "$DST" -type f | wc -l | tr -d ' ') files)"