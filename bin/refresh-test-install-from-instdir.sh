#!/usr/bin/env bash
# Refresh test-install/可圈办公.app from the current instdir bundle when ooinstall
# output is incomplete or stale. Verifies --version before replacing.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src_app="$repo_root/instdir/可圈办公.app"
dst_app="$repo_root/test-install/可圈办公.app"

if [[ ! -x "$src_app/Contents/MacOS/soffice" ]]; then
    echo "Missing instdir app: $src_app" >&2
    exit 1
fi

if ! KQOFFICE_AI_STUB_RUNTIME=1 "$src_app/Contents/MacOS/soffice" --version >/dev/null 2>&1; then
    echo "instdir soffice --version failed; refusing to refresh test-install" >&2
    exit 1
fi

rm -rf "$dst_app"
mkdir -p "$(dirname "$dst_app")"
cp -R "$src_app" "$dst_app"

if ! KQOFFICE_AI_STUB_RUNTIME=1 "$dst_app/Contents/MacOS/soffice" --version >/dev/null 2>&1; then
    echo "test-install refresh failed: soffice --version still broken" >&2
    exit 1
fi

echo "Refreshed $dst_app from $src_app"