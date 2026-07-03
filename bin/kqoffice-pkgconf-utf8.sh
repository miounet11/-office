#!/bin/sh
# UTF-8-safe pkg-config wrapper for BUILDDIR paths containing non-ASCII
# (harfbuzz Meson + Python 3 text mode). Not committed as /tmp path — copy:
#   install -m 755 bin/kqoffice-pkgconf-utf8.sh /tmp/kqoffice-pkgconf-utf8
REAL_PKG="${PKG_CONFIG_REAL:-/opt/homebrew/bin/pkg-config}"
stdout_tmp="${TMPDIR:-/tmp}/kqoffice-pkgconf-utf8.stdout.$$"
stderr_tmp="${TMPDIR:-/tmp}/kqoffice-pkgconf-utf8.stderr.$$"
trap 'rm -f "$stdout_tmp" "$stderr_tmp"' EXIT HUP INT TERM

"$REAL_PKG" "$@" >"$stdout_tmp" 2>"$stderr_tmp"
status=$?

sanitize() {
    python3 - "$1" <<'PY'
import sys
with open(sys.argv[1], "rb") as f:
    data = f.read()
out = bytearray()
i = 0
n = len(data)
while i < n:
    if data[i] == 0x5C and i + 1 < n and data[i + 1] >= 0x80:
        i += 2
        continue
    out.append(data[i])
    i += 1
sys.stdout.buffer.write(out)
PY
}

sanitize "$stdout_tmp"
sanitize "$stderr_tmp" >&2
exit "$status"
