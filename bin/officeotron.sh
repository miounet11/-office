#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -n "${KDOFFICE_SRC_ROOT:-}" ]]; then
    src_root="$(cd -P "$KDOFFICE_SRC_ROOT" && pwd)"
elif [[ -d "$repo_root/libreoffice-core" ]]; then
    src_root="$(cd -P "$repo_root/libreoffice-core" && pwd)"
else
    src_root="$(cd -P "$repo_root" && pwd)"
fi
tarballs_dir="${KDOFFICE_TARBALLS_DIR:-$src_root/external/tarballs}"
jar="$tarballs_dir/officeotron-0.8.8.jar"

if [[ ! -f "$jar" ]]; then
    echo "Missing Officeotron jar: $jar" >&2
    exit 2
fi

exec java -jar "$jar" "$@"