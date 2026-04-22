#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src_root="$(cd -P "$repo_root/libreoffice-core" && pwd)"
tarballs_dir="${KDOFFICE_TARBALLS_DIR:-$src_root/external/tarballs}"
jar="$tarballs_dir/verapdf-cli-1.29.0.jar"

if [[ ! -r "$jar" ]]; then
    printf 'missing validator jar: %s\n' "$jar" >&2
    exit 2
fi

exec java -jar "$jar" --nonpdfext "$@"
