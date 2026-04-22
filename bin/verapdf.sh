#!/usr/bin/env bash

jar="/Users/lu/kdoffice-src/external/tarballs/verapdf-cli-1.29.0.jar"

if [[ ! -r "$jar" ]]; then
    printf 'missing validator jar: %s\n' "$jar" >&2
    exit 2
fi

exec java -jar "$jar" --nonpdfext "$@"
