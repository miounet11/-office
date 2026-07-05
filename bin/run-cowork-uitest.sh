#!/usr/bin/env bash
# Run UITest_cui_cowork with macOS-safe env (ASCII workdir, single instance).
#
# Usage:
#   bin/run-cowork-uitest.sh
#   bin/run-cowork-uitest.sh --test test_cowork_dialog.CoworkDialog.test_a_cowork_dialog_controls_smoke

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${KDOFFICE_SRC_ROOT:-/Volumes/MobileDrive/devpc/kdoffice-src}"
ASCII_LINK="/Users/lu/kdoffice-build"
TEST_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test) TEST_NAME="${2:?}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--test Module.Class.method]"
      exit 0 ;;
    *) echo "Unknown: $1" >&2; exit 2 ;;
  esac
done

if [[ ! -L "$ASCII_LINK" ]]; then
  python3 -c "import os; os.path.lexists('$ASCII_LINK') or os.symlink('$REPO', '$ASCII_LINK')"
fi

# Avoid stale concurrent UITest/soffice fighting over the same user profile.
pkill -x soffice 2>/dev/null || true
pkill -x LibreOfficePython 2>/dev/null || true
sleep 1

python3 - "$REPO" "$ASCII_LINK" <<'PY'
import pathlib
import sys

repo, ascii_link = sys.argv[1:3]
for p in pathlib.Path(repo, "workdir/CustomTarget/postprocess/registry").glob("*.list"):
    text = p.read_text()
    new = text
    for old, nw in [
        (repo, ascii_link),
        ("/Volumes/MobileDrive/devpc/可点office", ascii_link),
        ("/Users/lu/可点office", ascii_link),
    ]:
        new = new.replace(old, nw)
    if new != text:
        p.write_text(new)
PY

export PKG_CONFIG="${PKG_CONFIG:-/tmp/kqoffice-pkgconf-utf8}"
export KQOFFICE_ASCII_WORKDIR="$ASCII_LINK/workdir"
export KDOFFICE_SRC_ROOT="$SRC"
export PYTHONUNBUFFERED=1

bash "$REPO/bin/normalize-workdir-build-paths.sh" >/dev/null
[[ -n "$TEST_NAME" ]] && export UITEST_TEST_NAME="$TEST_NAME"

cd "$REPO"
make UITest_cui_cowork