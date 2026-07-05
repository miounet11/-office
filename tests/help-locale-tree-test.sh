#!/usr/bin/env bash
# Verify offline help ships both zh-CN (default) and en-US locale trees.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
HELP_ROOT=""

for candidate in \
  "$REPO/test-install/可圈办公.app/Contents/Resources/help" \
  "$REPO/test-install/可圈office.app/Contents/Resources/help" \
  "$REPO/instdir/可圈办公.app/Contents/Resources/help" \
  "$REPO/instdir/可圈office.app/Contents/Resources/help"
do
  if [[ -d "$candidate/en-US/text" ]]; then
    HELP_ROOT="$candidate"
    break
  fi
done

die() { echo "help-locale-tree-test: $*" >&2; exit 1; }

[[ -n "$HELP_ROOT" ]] || die "no packaged help tree found"

[[ -d "$HELP_ROOT/zh-CN/text" ]] || die "missing help/zh-CN/text"
[[ -f "$HELP_ROOT/zh-CN/text/shared/guide/startcenter.html" ]] \
  || die "missing zh-CN startcenter help page"
[[ -f "$HELP_ROOT/languages.js" ]] || die "missing languages.js"

python3 - "$HELP_ROOT" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
langs = (root / "languages.js").read_text(encoding="utf-8")
if "zh-CN" not in langs or "en-US" not in langs:
    raise SystemExit("languages.js must declare zh-CN and en-US")

help2 = (root / "help2.js").read_text(encoding="utf-8")
if "languagesSet.has('zh-CN') ? 'zh-CN' : 'en-US'" not in help2:
    raise SystemExit("help2.js must prefer zh-CN as default help locale")

start = (root / "zh-CN/text/shared/guide/startcenter.html").read_text(encoding="utf-8")
if 'lang="zh-CN"' not in start:
    raise SystemExit("zh-CN startcenter.html must declare lang=zh-CN")
if "en-US/" in start:
    raise SystemExit("zh-CN startcenter.html still contains en-US/ links")
if "zh-CN/text/shared/05/new_help.html" not in start:
    raise SystemExit("zh-CN startcenter.html must link into zh-CN tree")

# Root index.html should route through existingLang(), which prefers zh-CN.
index = (root / "index.html").read_text(encoding="utf-8")
if "existingLang" not in index:
    raise SystemExit("help/index.html must call existingLang()")

print("help-locale-tree-test: OK")
PY