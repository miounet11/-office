#!/usr/bin/env python3
import os
import subprocess
import sys

REAL_PKGCONF = "/opt/homebrew/bin/pkgconf"


def normalize_pkgconf_bytes(data: bytes) -> bytes:
    out = bytearray()
    i = 0
    n = len(data)
    while i < n:
        if i + 1 < n and data[i] == 0x5C and data[i + 1] >= 0x80:
            out.append(data[i + 1])
            i += 2
            continue
        out.append(data[i])
        i += 1
    return bytes(out)


def main() -> int:
    kwargs = {
        "stdout": subprocess.PIPE,
        "stderr": subprocess.PIPE,
        "env": os.environ,
    }
    if not sys.stdin.isatty():
        kwargs["input"] = sys.stdin.buffer.read()
    proc = subprocess.run([REAL_PKGCONF, *sys.argv[1:]], **kwargs)
    sys.stdout.buffer.write(normalize_pkgconf_bytes(proc.stdout))
    sys.stderr.buffer.write(normalize_pkgconf_bytes(proc.stderr))
    return proc.returncode


if __name__ == "__main__":
    raise SystemExit(main())
