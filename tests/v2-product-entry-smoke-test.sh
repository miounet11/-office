#!/usr/bin/env bash
# V2 product-entry smoke harness (H8).
#
# Locks the installed app-bundle entrypoints for the current V2 product loop:
# W2 CommandPalette, W4 select-to-act/DiffReview, W5 Cowork, and provider
# service registration. This is a static bundle proof, not a GUI click-through.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ ! -x bin/v2-w4-smoke-installdir.sh ]]; then
    echo "FAIL: missing executable bin/v2-w4-smoke-installdir.sh" >&2
    exit 1
fi

echo "=== V2 H8 product-entry smoke (app bundle static) ==="

tmp_log="$(mktemp -t v2-product-entry-smoke.XXXXXX.log)"
trap 'rm -f "$tmp_log"' EXIT

if [[ -z "${KDOFFICE_APP_BUNDLE:-}" ]]; then
    export V2_SMOKE_NO_INSTALL=1
fi

if [[ -n "${KDOFFICE_APP_BUNDLE:-}" ]]; then
    smoke_cmd=(bin/v2-w4-smoke-installdir.sh --app "$KDOFFICE_APP_BUNDLE")
else
    smoke_cmd=(bin/v2-w4-smoke-installdir.sh --no-install)
fi

if ! bash "${smoke_cmd[@]}" >"$tmp_log" 2>&1; then
    cat "$tmp_log"
    echo "FAIL: installdir product-entry smoke failed" >&2
    if [[ -z "${KDOFFICE_APP_BUNDLE:-}" ]]; then
        echo "FAIL: H8 requires KDOFFICE_APP_BUNDLE or a prebuilt instdir/test-install app bundle; it will not run make test-install inside the contract harness" >&2
    fi
    exit 1
fi

required_lines=(
    "PASS: kqoffice_ai library present"
    "PASS: services.rdb contains 'com.sun.star.ai.Provider'"
    "PASS: installed registry contains .uno:CommandPalette"
    "PASS: installed registry contains .uno:CoworkTaskManager"
    "PASS: installed registry contains K_SHIFT_MOD1"
    "PASS: installed registry contains T_SHIFT_MOD1"
    "PASS: installed registry contains DiffReviewDeck"
    "PASS: commandpalette.ui shipped"
    "PASS: cowork-dialog.ui shipped"
    "PASS: Writer select-to-act popover shipped"
    "PASS: Calc cell-range popover shipped"
    "PASS: Impress slide-element popover shipped"
    "PASS: DiffReview panel ui shipped"
    "=== W4 installdir smoke: OK ==="
)

for line in "${required_lines[@]}"; do
    if ! grep -Fq "$line" "$tmp_log"; then
        cat "$tmp_log"
        echo "FAIL: product-entry smoke missing expected line: $line" >&2
        exit 1
    fi
done

cat "$tmp_log"
echo "Status: passed"
echo "Checks: ${#required_lines[@]}"
