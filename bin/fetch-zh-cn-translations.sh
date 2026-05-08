#!/usr/bin/env bash
# Fetch the LibreOffice translations submodule pinned by the SRCDIR core repo
# and stage it for `--with-lang=zh-CN` builds. Does NOT modify autogen.lastrun
# or trigger a rebuild. Operator must run `./autogen.sh && make build` after.
#
# Usage: bin/fetch-zh-cn-translations.sh [--src-root PATH] [--full]
#   --full   Fetch all languages, not only zh-CN sparse-checkout.

set -euo pipefail

SRC_ROOT="${KDOFFICE_SRC_ROOT:-/Users/lu/kdoffice-src}"
FULL="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --src-root) SRC_ROOT="${2:?}"; shift 2 ;;
    --full) FULL="1"; shift ;;
    -h|--help) echo "Usage: $0 [--src-root PATH] [--full]"; exit 0 ;;
    *) echo "Unknown: $1" >&2; exit 2 ;;
  esac
done

[[ -d "$SRC_ROOT/.git" || -f "$SRC_ROOT/.git" ]] || { echo "Not a git checkout: $SRC_ROOT" >&2; exit 2; }

cd "$SRC_ROOT"

PIN=$(git ls-tree HEAD translations | awk '{print $3}')
[[ -n "$PIN" ]] || { echo "translations submodule not declared in HEAD" >&2; exit 2; }

REMOTE="$(git config submodule.translations.url 2>/dev/null || true)"
if [[ -z "$REMOTE" || "$REMOTE" == "../translations" ]]; then
  ORIGIN="$(git config --get remote.origin.url)"
  # Resolve ../translations relative to origin: strip the last path component
  # of origin and append "translations".
  REMOTE="$(python3 -c "
import sys, urllib.parse as u
o = sys.argv[1]
if o.endswith('.git'): o = o[:-4]
parts = o.rsplit('/', 1)
print(parts[0] + '/translations.git')
" "$ORIGIN")"
fi
echo "submodule pin: $PIN"
echo "submodule url: $REMOTE"

if [[ -d translations/.git || -f translations/.git ]]; then
  echo "translations/ already initialized; fetching pin"
  cd translations
  git fetch --depth 1 origin "$PIN"
  git checkout "$PIN"
  cd ..
else
  echo "cloning translations (shallow, pin only)"
  rm -rf translations
  git clone --depth 1 --no-single-branch --filter=blob:none "$REMOTE" translations
  cd translations
  git fetch --depth 1 origin "$PIN"
  git checkout "$PIN"
  cd ..
fi

if [[ "$FULL" == "0" ]]; then
  echo "configuring sparse checkout for zh-CN only (use --full to fetch all langs)"
  cd translations
  git sparse-checkout init --cone 2>/dev/null || true
  git sparse-checkout set source/zh-CN
  cd ..
fi

zh_count=$(find translations/source/zh-CN -name "*.po" 2>/dev/null | wc -l | tr -d ' ')
zh_strings=$(grep -h "^msgid " translations/source/zh-CN/**/*.po 2>/dev/null | wc -l | tr -d ' ' || echo 0)
echo
echo "zh-CN po files: $zh_count"
[[ "$zh_strings" != "0" ]] && echo "zh-CN msgid count (approx): $zh_strings"
echo
echo "Next steps (operator):"
echo "  1. Edit autogen.lastrun: append '--with-lang=zh-CN'"
echo "  2. Run: cd $SRC_ROOT && ./autogen.sh"
echo "  3. Run: make build  (full rebuild ~1-2h on macOS-14)"
echo "  4. Run: bin/packaged-screenshots.sh  to verify ZH coverage"
