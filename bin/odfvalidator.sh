#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -n "${KDOFFICE_SRC_ROOT:-}" ]]; then
    src_root="$(cd -P "$KDOFFICE_SRC_ROOT" && pwd)"
elif [[ -d "$repo_root/libreoffice-core" ]]; then
    src_root="$(cd -P "$repo_root/libreoffice-core" && pwd)"
else
    src_root="$(cd -P "$repo_root" && pwd)"
fi
tarballs_dir="${KDOFFICE_TARBALLS_DIR:-$src_root/external/tarballs}"
jar="$tarballs_dir/odfvalidator-0.13.0-jar-with-dependencies.jar"

if [[ ! -f "$jar" ]]; then
    echo "Missing ODF Validator jar: $jar" >&2
    exit 2
fi

exec java \
    -Djavax.xml.validation.SchemaFactory:http://relaxng.org/ns/structure/1.0=org.iso_relax.verifier.jaxp.validation.RELAXNGSchemaFactoryImpl \
    -Dorg.iso_relax.verifier.VerifierFactoryLoader=com.sun.msv.verifier.jarv.FactoryLoaderImpl \
    -jar "$jar" "$@"