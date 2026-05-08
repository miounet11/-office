#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    cat <<'EOF'
Usage:
  source-status.sh [git-status-options...]

Shows a source-focused git status for the current 可圈office tree.
Generated build/install outputs are excluded so agent handoffs and reviews
can focus on real source and planning changes.

Examples:
  bin/source-status.sh
  bin/source-status.sh --porcelain
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

git -C "$repo_root" status "${@:-"--short"}" -- \
    . \
    ':(exclude).clavue/**' \
    ':(exclude)workdir/**' \
    ':(exclude)instdir/**' \
    ':(exclude)test-install/**' \
    ':(exclude)tmp/**' \
    ':(exclude)autom4te.cache/**' \
    ':(exclude)config.log' \
    ':(exclude)config.status' \
    ':(exclude)config_host.mk' \
    ':(exclude)config_host/**' \
    ':(exclude)autogen.lastrun' \
    ':(exclude)autogen.lastrun.bak'
