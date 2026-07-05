#!/usr/bin/env bash
# V2 W4 — post-test-install bundle verification (static instdir checks only).
#
# Avoids a headless soffice launch + SAL_INFO scrape (too heavy for CI). Instead
# verifies that test-install/instdir contains:
#   - kqoffice_ai runtime (standalone lib or merged into libmergedlo.dylib)
#   - services.rdb registration for com.sun.star.ai.Provider
#   - registry / GenericCommands wiring for .uno:CommandPalette (W2)
#
# Install policy:
#   - Runs `make test-install` only when explicitly requested with
#     --force-install. Contract harnesses verify existing static bundle
#     contents and never build test-install implicitly.
#   - Uses PKG_CONFIG wrapper for non-ASCII BUILDDIR (no secrets in repo).
#
# Usage:
#   v2-w4-smoke-installdir.sh [--force-install] [--no-install] [--app <bundle-path>]
#
# Environment:
#   PKG_CONFIG   Defaults to /tmp/kqoffice-pkgconf-utf8; falls back to
#                bin/kqoffice-pkgconf-utf8.sh when the /tmp copy is absent.
#   KDOFFICE_APP_BUNDLE  Explicit .app bundle path (skips discovery).
#   V2_SMOKE_NO_INSTALL  Set to 1 to fail fast instead of running test-install.
#
# Exit codes:
#   0  all checks passed
#   1  bundle missing after install attempt
#   2  kqoffice_ai runtime / component artifact missing
#   3  com.sun.star.ai.Provider not found in services.rdb (provider registration)
#   4  .uno:CommandPalette not found in installed registry
#
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ -n "${PKG_CONFIG:-}" && -x "${PKG_CONFIG:-}" ]]; then
    :
elif [[ -x /tmp/kqoffice-pkgconf-utf8 ]]; then
    export PKG_CONFIG=/tmp/kqoffice-pkgconf-utf8
elif [[ -f "$repo_root/bin/kqoffice-pkgconf-utf8.sh" ]]; then
    export PKG_CONFIG="$repo_root/bin/kqoffice-pkgconf-utf8.sh"
else
    printf 'WARN: PKG_CONFIG wrapper missing; set PKG_CONFIG or install bin/kqoffice-pkgconf-utf8.sh to /tmp/kqoffice-pkgconf-utf8\n' >&2
fi
V2_SMOKE_PARALLELISM="${V2_SMOKE_PARALLELISM:-2}"

force_install=0
no_install=0
app_override=""

usage() {
    cat <<'EOF'
Usage:
  v2-w4-smoke-installdir.sh [options]

Options:
  --force-install   Always run `make test-install` before checks
  --no-install      Never run `make test-install`; require an existing bundle
  --app <path>      App bundle (.app) to verify; default: instdir then test-install
  -h, --help

Static checks (no soffice launch):
  - kqoffice_ai runtime present (libkqoffice_ailo.dylib or libmergedlo.dylib)
  - services.rdb contains com.sun.star.ai.Provider (+ kqoffice marker)
  - registry contains .uno:CommandPalette (main.xcd / GenericCommands merge)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --force-install)
            force_install=1
            shift
            ;;
        --no-install)
            no_install=1
            shift
            ;;
        --app)
            app_override="${2:?}"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

instdir_app="$repo_root/instdir/可圈办公.app"
testinstall_app="$repo_root/test-install/可圈办公.app"

need_install=0
if [[ "$force_install" == "1" ]]; then
    need_install=1
fi
if [[ "$no_install" == "1" || "${V2_SMOKE_NO_INSTALL:-0}" == "1" ]]; then
    need_install=0
fi

echo "=== V2 W4 installdir smoke (static bundle checks) ==="
printf 'PKG_CONFIG=%s\n' "${PKG_CONFIG:-<unset>}"

if [[ "$need_install" == "1" ]]; then
    if [[ "$force_install" == "1" ]]; then
        echo "--- make test-install (--force-install) ---"
    else
        echo "--- make test-install (instdir bundle missing) ---"
    fi
    make PARALLELISM="$V2_SMOKE_PARALLELISM" test-install
elif [[ -n "$app_override" || -n "${KDOFFICE_APP_BUNDLE:-}" ]]; then
    echo "SKIP install: explicit app bundle supplied; verifying existing bundle only"
elif [[ "$no_install" == "1" || "${V2_SMOKE_NO_INSTALL:-0}" == "1" ]]; then
    echo "SKIP install: no-install mode; verifying existing bundle only"
else
    echo "SKIP install: $instdir_app already present"
fi

resolve_app() {
    if [[ -n "$app_override" ]]; then
        printf '%s' "$app_override"
        return 0
    fi
    if [[ -n "${KDOFFICE_APP_BUNDLE:-}" ]]; then
        printf '%s' "$KDOFFICE_APP_BUNDLE"
        return 0
    fi
    local candidate
    for candidate in "$instdir_app" "$testinstall_app"; do
        if [[ -d "$candidate/Contents/Resources" ]]; then
            printf '%s' "$candidate"
            return 0
        fi
    done
    return 1
}

app=""
if ! app="$(resolve_app)"; then
    echo "FAIL: no static 可圈办公.app resources under instdir/ or test-install/"
    exit 1
fi

echo "App bundle: $app"

frameworks_dir="$app/Contents/Frameworks"
resources_dir="$app/Contents/Resources"
failures=0

record_pass() {
    printf 'PASS: %s\n' "$1"
}

record_fail() {
    local code="$1"
    local message="$2"
    printf 'FAIL[%s]: %s\n' "$code" "$message"
    failures="$code"
}

record_file_present() {
    local code="$1"
    local path="$2"
    local label="$3"
    if [[ -f "$path" ]]; then
        record_pass "$label shipped (${path#$app/})"
    else
        record_fail "$code" "$label missing: ${path#$app/}"
    fi
}

registry_contains() {
    local needle="$1"
    find "$resources_dir/registry" -maxdepth 3 -type f \( -name '*.xcd' -o -name '*.xcu' \) -print0 2>/dev/null \
        | xargs -0 grep -aqF "$needle" 2>/dev/null
}

# --- kqoffice_ai runtime -------------------------------------------------------
kq_lib=""
for candidate in \
    "$frameworks_dir/libkqoffice_ailo.dylib" \
    "$frameworks_dir/libkqoffice_ai.dylib"; do
    if [[ -f "$candidate" ]]; then
        kq_lib="$candidate"
        break
    fi
done

if [[ -n "$kq_lib" ]]; then
    record_pass "kqoffice_ai runtime present ($(basename "$kq_lib"))"
else
    merged_lib="$frameworks_dir/libmergedlo.dylib"
    if [[ -f "$merged_lib" ]] \
        && grep -q 'kqoffice_ai_Provider_get_implementation' < <(nm -gU "$merged_lib" 2>/dev/null); then
        record_pass "kqoffice_ai runtime present in libmergedlo.dylib"
    else
        record_fail 2 "kqoffice_ai runtime missing under Contents/Frameworks"
    fi
fi

# --- services.rdb: com.sun.star.ai.Provider ----------------------------------
services_rdb="$resources_dir/services/services.rdb"
provider_needles=(
    'com.sun.star.ai.Provider'
    'com.kqoffice.ai.Provider'
    'kqoffice'
)

if [[ ! -f "$services_rdb" ]]; then
    record_fail 3 "services.rdb missing: $services_rdb"
else
    provider_hits=0
    for needle in "${provider_needles[@]}"; do
        if LC_ALL=C grep -aqF "$needle" "$services_rdb" 2>/dev/null \
            || strings "$services_rdb" 2>/dev/null | LC_ALL=C grep -qF "$needle"; then
            provider_hits=$((provider_hits + 1))
            record_pass "services.rdb contains '$needle'"
        fi
    done
    if [[ "$provider_hits" -lt 2 ]]; then
        record_fail 3 "com.sun.star.ai.Provider / kqoffice registration incomplete in $services_rdb"
    fi
fi

# --- Command palette registry (installed bundle only) --------------------------
palette_hits=0
installed_palette_paths=()

registry_main="$resources_dir/registry/main.xcd"
if [[ -f "$registry_main" ]]; then
    installed_palette_paths+=("$registry_main")
fi

while IFS= read -r xcu_path; do
    installed_palette_paths+=("$xcu_path")
done < <(find "$resources_dir/registry" -name 'GenericCommands*.xcu' 2>/dev/null || true)

for palette_file in "${installed_palette_paths[@]:-}"; do
    [[ -f "$palette_file" ]] || continue
    if grep -qF '.uno:CommandPalette' "$palette_file" 2>/dev/null; then
        palette_hits=$((palette_hits + 1))
        record_pass "CommandPalette in bundle: ${palette_file#$app/}"
    fi
done

if [[ -n "${KDOFFICE_SRC_ROOT:-}" ]]; then
    src_root="$(cd -P "$KDOFFICE_SRC_ROOT" && pwd)"
elif [[ -d "$repo_root/libreoffice-core" ]]; then
    src_root="$(cd -P "$repo_root/libreoffice-core" && pwd)"
elif [[ -d /Users/lu/kdoffice-src ]]; then
    src_root=/Users/lu/kdoffice-src
else
    src_root="$repo_root"
fi
src_generic="$src_root/officecfg/registry/data/org/openoffice/Office/UI/GenericCommands.xcu"
if [[ -f "$src_generic" ]] && grep -qF '.uno:CommandPalette' "$src_generic" 2>/dev/null; then
    record_pass "SRCDIR GenericCommands.xcu defines .uno:CommandPalette (rebuild if bundle miss)"
fi

ui_palette="$resources_dir/config/soffice.cfg/cui/ui/commandpalette.ui"
if [[ -f "$ui_palette" ]]; then
    record_pass "commandpalette.ui shipped"
fi

if [[ "$palette_hits" -eq 0 ]]; then
    record_fail 4 ".uno:CommandPalette not found in installed registry (main.xcd / GenericCommands)"
fi

# --- V2 product entrypoints shipped in app bundle -----------------------------
record_file_present 5 "$resources_dir/config/soffice.cfg/cui/ui/commandpalette.ui" "commandpalette.ui"
record_file_present 5 "$resources_dir/config/soffice.cfg/cui/ui/cowork-dialog.ui" "cowork-dialog.ui"
record_file_present 5 "$resources_dir/config/soffice.cfg/modules/swriter/ui/select-to-act-popover.ui" "Writer select-to-act popover"
record_file_present 5 "$resources_dir/config/soffice.cfg/modules/scalc/ui/cell-range-popover.ui" "Calc cell-range popover"
record_file_present 5 "$resources_dir/config/soffice.cfg/modules/simpress/ui/slide-element-popover.ui" "Impress slide-element popover"
record_file_present 5 "$resources_dir/config/soffice.cfg/svx/ui/diff-review-panel.ui" "DiffReview panel ui"

for needle in \
    '.uno:CommandPalette' \
    '.uno:CoworkTaskManager' \
    'K_SHIFT_MOD1' \
    'T_SHIFT_MOD1' \
    'DiffReviewDeck'; do
    if registry_contains "$needle"; then
        record_pass "installed registry contains $needle"
    else
        record_fail 4 "installed registry missing $needle"
    fi
done

echo ""
if [[ "$failures" -eq 0 ]]; then
    echo "=== W4 installdir smoke: OK ==="
    exit 0
fi

echo "=== W4 installdir smoke: FAILED (exit $failures) ==="
exit "$failures"
