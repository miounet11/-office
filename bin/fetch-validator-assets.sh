#!/usr/bin/env bash
# Fetch and verify Java validator assets required by bin/officeotron.sh and bin/verapdf.sh.
# SHA-256 sourced from LibreOffice upstream download.lst.
# Usage: bin/fetch-validator-assets.sh [--src-root PATH]

set -euo pipefail

SRC_ROOT="${KDOFFICE_SRC_ROOT:-/Users/lu/kdoffice-src}"
[[ "${1:-}" == "--src-root" && -n "${2:-}" ]] && SRC_ROOT="$2"
TARGET="$SRC_ROOT/external/tarballs"

# name|sha256|primary_url|backup_url
ASSETS=(
'officeotron-0.8.8.jar|c72cdcb7fe7cfe917d1fb8766ddbc3f92b6124ecd5fb8c6dc0ddabb74a7e057c|https://dev-www.libreoffice.org/extern/officeotron-0.8.8.jar|https://sourceforge.net/projects/officeotron/files/officeotron/0.8.8/officeotron-0.8.8.jar/download'
'verapdf-cli-1.29.0.jar|bdeef807f7e883fe3ff4e0a4712dc216064ca670d5c857fbc94408266719f0f4|https://dev-www.libreoffice.org/extern/verapdf-cli-1.29.0.jar|https://software.verapdf.org/releases/verapdf-cli-1.29.0.jar'
)

sha() { shasum -a 256 "$1" | awk '{print $1}'; }

fetch_one() {
  local name="$1" expected="$2" primary="$3" backup="$4"
  local dest="$TARGET/$name" tmp="$TARGET/$name.tmp"

  if [[ -f "$dest" ]]; then
    local actual; actual=$(sha "$dest")
    if [[ "$actual" == "$expected" ]]; then
      echo "OK $name (already present, sha256 verified)"
      return 0
    fi
    echo "WARN $name present but sha256 mismatch: $actual" >&2
    echo "WARN refusing to overwrite; remove manually if intentional" >&2
    return 2
  fi

  rm -f "$tmp"
  echo "FETCH $name"
  if ! curl -fsSL --retry 3 --max-time 300 -o "$tmp" "$primary"; then
    echo "WARN primary URL failed, trying backup" >&2
    rm -f "$tmp"
    if ! curl -fsSL --retry 3 --max-time 300 -o "$tmp" "$backup"; then
      echo "ERROR both URLs failed for $name" >&2
      rm -f "$tmp"
      return 1
    fi
  fi

  local actual; actual=$(sha "$tmp")
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR sha256 mismatch for $name" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    rm -f "$tmp"
    return 2
  fi

  mv "$tmp" "$dest"
  echo "OK $name installed -> $dest"
}

mkdir -p "$TARGET"
rc=0
for spec in "${ASSETS[@]}"; do
  IFS='|' read -r name expected primary backup <<<"$spec"
  fetch_one "$name" "$expected" "$primary" "$backup" || rc=$?
done

if [[ $rc -eq 0 ]]; then
  echo
  echo "All validator assets ready in $TARGET"
  echo "Next: bin/validator-readiness.sh --strict tmp/validator-readiness-strict.md"
fi
exit $rc
