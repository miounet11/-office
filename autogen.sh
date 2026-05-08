#!/bin/sh

GNUMAKE=${GNUMAKE:-$(command -v gmake 2>/dev/null)}
export GNUMAKE

exec /Users/lu/kdoffice-src/autogen.sh "$@"
