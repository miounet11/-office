#!/usr/bin/env bash
# V2 build hardening: pkg-config UTF-8 wrapper contract.
#
# The wrapper exists to sanitize pkg-config output for non-ASCII build paths.
# It must preserve stdout/stderr separation so Autoconf cannot cache
# pkg-config failure diagnostics as compiler/linker flags.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

wrapper="bin/kqoffice-pkgconf-utf8.sh"
[[ -f "$wrapper" ]] || {
    echo "FAIL: missing $wrapper" >&2
    exit 1
}

tmpdir="$(mktemp -d -t v2-pkg-config-wrapper.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

fake_pkg="$tmpdir/pkg-config"
cat >"$fake_pkg" <<'SH'
#!/usr/bin/env bash
case "$1" in
    --exists)
        echo "missing package diagnostic" >&2
        exit 1
        ;;
    --cflags)
        printf '%s\n' '-I/Users/lu/可点office/include'
        exit 0
        ;;
    --libs)
        printf '%s\n' '-L/Users/lu/可点office/lib -lkqoffice'
        exit 0
        ;;
    *)
        echo "unknown invocation: $*" >&2
        exit 2
        ;;
esac
SH
chmod +x "$fake_pkg"

checks=0

stdout="$tmpdir/exists.out"
stderr="$tmpdir/exists.err"
if PKG_CONFIG_REAL="$fake_pkg" sh "$wrapper" --exists --print-errors missing >"$stdout" 2>"$stderr"; then
    echo "FAIL: missing package unexpectedly succeeded" >&2
    exit 1
fi
[[ ! -s "$stdout" ]] || {
    echo "FAIL: wrapper leaked pkg-config failure diagnostics to stdout" >&2
    cat "$stdout" >&2
    exit 1
}
grep -Fq "missing package diagnostic" "$stderr" || {
    echo "FAIL: wrapper did not preserve stderr diagnostics" >&2
    exit 1
}
checks=$((checks + 1))

stdout="$tmpdir/cflags.out"
stderr="$tmpdir/cflags.err"
PKG_CONFIG_REAL="$fake_pkg" sh "$wrapper" --cflags ok >"$stdout" 2>"$stderr"
grep -Fq "/Users/lu/可点office/include" "$stdout" || {
    echo "FAIL: wrapper did not preserve successful stdout" >&2
    exit 1
}
[[ ! -s "$stderr" ]] || {
    echo "FAIL: wrapper produced stderr for successful cflags" >&2
    cat "$stderr" >&2
    exit 1
}
checks=$((checks + 1))

stdout="$tmpdir/libs.out"
PKG_CONFIG_REAL="$fake_pkg" sh "$wrapper" --libs ok >"$stdout"
grep -Fq -- "-lkqoffice" "$stdout" || {
    echo "FAIL: wrapper did not preserve successful libs stdout" >&2
    exit 1
}
checks=$((checks + 1))

echo "Status: passed"
echo "Checks: $checks"
