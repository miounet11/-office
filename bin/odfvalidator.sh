#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src_root="$(cd -P "$repo_root/libreoffice-core" && pwd)"
tarballs_dir="${KDOFFICE_TARBALLS_DIR:-$src_root/external/tarballs}"
jar="$tarballs_dir/odfvalidator-0.13.0-jar-with-dependencies.jar"

if [[ ! -r "$jar" ]]; then
    printf 'missing validator jar: %s\n' "$jar" >&2
    exit 2
fi

exec java \
    -Djavax.xml.validation.SchemaFactory:http://relaxng.org/ns/structure/1.0=org.iso_relax.verifier.jaxp.validation.RELAXNGSchemaFactoryImpl \
    -Dorg.iso_relax.verifier.VerifierFactoryLoader=com.sun.msv.verifier.jarv.FactoryLoaderImpl \
    -jar "$jar" "$@"
