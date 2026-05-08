#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_under_test="$repo_root/bin/validator-readiness.sh"

tmp_root="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp_root"
}
trap cleanup EXIT

bash_path="$(command -v bash)"
date_path="$(command -v date)"
dirname_path="$(command -v dirname)"
mkdir_path="$(command -v mkdir)"
python3_path="$(command -v python3)"

fake_repo="$tmp_root/repo"
mkdir -p "$fake_repo/bin" "$fake_repo/libreoffice-core/external/tarballs" "$tmp_root/fakebin"
cp "$script_under_test" "$fake_repo/bin/validator-readiness.sh"

for wrapper in odfvalidator officeotron verapdf; do
    cat > "$fake_repo/bin/$wrapper.sh" <<'WRAPPER'
#!/usr/bin/env bash
printf 'wrapper smoke placeholder\n'
WRAPPER
    chmod +x "$fake_repo/bin/$wrapper.sh"
done

cat > "$tmp_root/fakebin/java" <<'JAVA'
#!/usr/bin/env bash
printf 'openjdk version "21.0.0"\n' >&2
JAVA
chmod +x "$tmp_root/fakebin/java"

broken_java_bin="$tmp_root/broken-java-bin"
mkdir -p "$broken_java_bin"
cat > "$broken_java_bin/java" <<'JAVA'
#!/usr/bin/env bash
printf 'broken java\n' >&2
exit 9
JAVA
chmod +x "$broken_java_bin/java"

report_path="$fake_repo/tmp/validator-readiness.md"
PATH="$tmp_root/fakebin:$PATH" KDOFFICE_TARBALLS_DIR="$fake_repo/libreoffice-core/external/tarballs" \
    "$fake_repo/bin/validator-readiness.sh" "$report_path" > "$tmp_root/stdout.log"

if ! grep -q '^## Missing Asset Blockers$' "$report_path"; then
    printf 'Expected report to include a missing asset blockers section\n' >&2
    exit 1
fi

for expected in \
    '`officeotron-0.8.8.jar`' \
    '`verapdf-cli-1.29.0.jar`' \
    'Required evidence fields' \
    'Source URL' \
    'Download method' \
    'Wrapper smoke command and result'
do
    if ! grep -F -q -- "$expected" "$report_path"; then
        printf 'Expected report to include %s\n' "$expected" >&2
        exit 1
    fi
done

all_ready_repo="$tmp_root/all-ready-repo"
mkdir -p "$all_ready_repo/bin" "$all_ready_repo/libreoffice-core/external/tarballs" "$all_ready_repo/tmp"
cp "$script_under_test" "$all_ready_repo/bin/validator-readiness.sh"

for asset in \
    odfvalidator-0.13.0-jar-with-dependencies.jar \
    officeotron-0.8.8.jar \
    verapdf-cli-1.29.0.jar
do
    printf 'fake asset for %s\n' "$asset" > "$all_ready_repo/libreoffice-core/external/tarballs/$asset"
done

cat > "$all_ready_repo/bin/odfvalidator.sh" <<'WRAPPER'
#!/usr/bin/env bash
printf 'odf help ok\n'
WRAPPER
cat > "$all_ready_repo/bin/officeotron.sh" <<'WRAPPER'
#!/usr/bin/env bash
printf 'officeotron help failed\n' >&2
exit 7
WRAPPER
cat > "$all_ready_repo/bin/verapdf.sh" <<'WRAPPER'
#!/usr/bin/env bash
printf 'verapdf help ok\n'
WRAPPER
chmod +x "$all_ready_repo/bin/odfvalidator.sh" "$all_ready_repo/bin/officeotron.sh" "$all_ready_repo/bin/verapdf.sh"

strict_report_path="$all_ready_repo/tmp/validator-readiness-strict.md"
if PATH="$tmp_root/fakebin:$PATH" KDOFFICE_TARBALLS_DIR="$all_ready_repo/libreoffice-core/external/tarballs" \
    "$all_ready_repo/bin/validator-readiness.sh" --strict "$strict_report_path" > "$tmp_root/strict-stdout.log" 2> "$tmp_root/strict-stderr.log"; then
    printf 'Expected strict readiness to fail when a wrapper smoke command fails\n' >&2
    exit 1
fi

for expected in \
    'wrapper-smoke-failed' \
    'officeotron help failed' \
    'Wrapper Smoke Results'
do
    if ! grep -F -q -- "$expected" "$strict_report_path"; then
        printf 'Expected strict report to include %s\n' "$expected" >&2
        exit 1
    fi
done

java_error_report_path="$all_ready_repo/tmp/validator-readiness-java-error.md"
if PATH="$broken_java_bin:$PATH" KDOFFICE_TARBALLS_DIR="$all_ready_repo/libreoffice-core/external/tarballs" \
    "$all_ready_repo/bin/validator-readiness.sh" --strict "$java_error_report_path" > "$tmp_root/java-error-stdout.log" 2> "$tmp_root/java-error-stderr.log"; then
    printf 'Expected strict readiness to fail when java -version exits non-zero\n' >&2
    exit 1
fi

for expected in \
    'Java: **error**' \
    'java-error' \
    'broken java'
do
    if ! grep -F -q -- "$expected" "$java_error_report_path"; then
        printf 'Expected java error report to include %s\n' "$expected" >&2
        exit 1
    fi
done

missing_java_bin="$tmp_root/missing-java-bin"
mkdir -p "$missing_java_bin"
ln -s "$bash_path" "$missing_java_bin/bash"
ln -s "$date_path" "$missing_java_bin/date"
ln -s "$dirname_path" "$missing_java_bin/dirname"
ln -s "$mkdir_path" "$missing_java_bin/mkdir"
ln -s "$python3_path" "$missing_java_bin/python3"
missing_java_report_path="$all_ready_repo/tmp/validator-readiness-missing-java.md"
if PATH="$missing_java_bin" KDOFFICE_TARBALLS_DIR="$all_ready_repo/libreoffice-core/external/tarballs" \
    /usr/bin/env bash "$all_ready_repo/bin/validator-readiness.sh" --strict "$missing_java_report_path" > "$tmp_root/missing-java-stdout.log" 2> "$tmp_root/missing-java-stderr.log"; then
    printf 'Expected strict readiness to fail when java is missing from PATH\n' >&2
    exit 1
fi

for expected in \
    'Java: **missing**' \
    'missing-java' \
    'java not found on PATH'
do
    if ! grep -F -q -- "$expected" "$missing_java_report_path"; then
        printf 'Expected missing java report to include %s\n' "$expected" >&2
        exit 1
    fi
done

wrapper_state_repo="$tmp_root/wrapper-state-repo"
mkdir -p "$wrapper_state_repo/bin" "$wrapper_state_repo/libreoffice-core/external/tarballs" "$wrapper_state_repo/tmp"
cp "$script_under_test" "$wrapper_state_repo/bin/validator-readiness.sh"
for asset in \
    odfvalidator-0.13.0-jar-with-dependencies.jar \
    officeotron-0.8.8.jar \
    verapdf-cli-1.29.0.jar
do
    printf 'fake asset for %s\n' "$asset" > "$wrapper_state_repo/libreoffice-core/external/tarballs/$asset"
done
cat > "$wrapper_state_repo/bin/odfvalidator.sh" <<'WRAPPER'
#!/usr/bin/env bash
printf 'odf help ok\n'
WRAPPER
cat > "$wrapper_state_repo/bin/verapdf.sh" <<'WRAPPER'
#!/usr/bin/env bash
printf 'verapdf help ok\n'
WRAPPER
chmod +x "$wrapper_state_repo/bin/odfvalidator.sh" "$wrapper_state_repo/bin/verapdf.sh"
cat > "$wrapper_state_repo/bin/officeotron.sh" <<'WRAPPER'
#!/usr/bin/env bash
printf 'officeotron help ok\n'
WRAPPER
wrapper_state_report_path="$wrapper_state_repo/tmp/validator-readiness-wrapper-state.md"
if PATH="$tmp_root/fakebin:$PATH" KDOFFICE_TARBALLS_DIR="$wrapper_state_repo/libreoffice-core/external/tarballs" \
    "$wrapper_state_repo/bin/validator-readiness.sh" --strict "$wrapper_state_report_path" > "$tmp_root/wrapper-state-stdout.log" 2> "$tmp_root/wrapper-state-stderr.log"; then
    printf 'Expected strict readiness to fail when a wrapper is not executable\n' >&2
    exit 1
fi

if ! grep -F -q -- 'wrapper-not-executable' "$wrapper_state_report_path"; then
    printf 'Expected wrapper state report to include wrapper-not-executable\n' >&2
    exit 1
fi

rm "$wrapper_state_repo/bin/officeotron.sh"
wrapper_missing_report_path="$wrapper_state_repo/tmp/validator-readiness-wrapper-missing.md"
if PATH="$tmp_root/fakebin:$PATH" KDOFFICE_TARBALLS_DIR="$wrapper_state_repo/libreoffice-core/external/tarballs" \
    "$wrapper_state_repo/bin/validator-readiness.sh" --strict "$wrapper_missing_report_path" > "$tmp_root/wrapper-missing-stdout.log" 2> "$tmp_root/wrapper-missing-stderr.log"; then
    printf 'Expected strict readiness to fail when a wrapper is missing\n' >&2
    exit 1
fi

if ! grep -F -q -- 'wrapper-missing' "$wrapper_missing_report_path"; then
    printf 'Expected wrapper missing report to include wrapper-missing\n' >&2
    exit 1
fi

smoke_contract_repo="$tmp_root/smoke-contract-repo"
mkdir -p "$smoke_contract_repo/bin" "$smoke_contract_repo/libreoffice-core/external/tarballs" "$smoke_contract_repo/tmp"
cp "$script_under_test" "$smoke_contract_repo/bin/validator-readiness.sh"
for asset in \
    odfvalidator-0.13.0-jar-with-dependencies.jar \
    officeotron-0.8.8.jar \
    verapdf-cli-1.29.0.jar
do
    printf 'fake asset for %s\n' "$asset" > "$smoke_contract_repo/libreoffice-core/external/tarballs/$asset"
done
cat > "$smoke_contract_repo/bin/odfvalidator.sh" <<'WRAPPER'
#!/usr/bin/env bash
if [[ "$1" != '-h' ]]; then
    printf 'expected -h, got %s\n' "${1:-}" >&2
    exit 11
fi
if [[ "$KDOFFICE_TARBALLS_DIR" != */libreoffice-core/external/tarballs ]]; then
    printf 'unexpected tarballs dir: %s\n' "$KDOFFICE_TARBALLS_DIR" >&2
    exit 12
fi
printf 'odf contract ok\n'
WRAPPER
cat > "$smoke_contract_repo/bin/officeotron.sh" <<'WRAPPER'
#!/usr/bin/env bash
if [[ "$1" != '--help' ]]; then
    printf 'expected --help, got %s\n' "${1:-}" >&2
    exit 13
fi
if [[ "$KDOFFICE_TARBALLS_DIR" != */libreoffice-core/external/tarballs ]]; then
    printf 'unexpected tarballs dir: %s\n' "$KDOFFICE_TARBALLS_DIR" >&2
    exit 14
fi
printf 'officeotron contract ok\n'
WRAPPER
cat > "$smoke_contract_repo/bin/verapdf.sh" <<'WRAPPER'
#!/usr/bin/env bash
if [[ "$1" != '--help' ]]; then
    printf 'expected --help, got %s\n' "${1:-}" >&2
    exit 15
fi
if [[ "$KDOFFICE_TARBALLS_DIR" != */libreoffice-core/external/tarballs ]]; then
    printf 'unexpected tarballs dir: %s\n' "$KDOFFICE_TARBALLS_DIR" >&2
    exit 16
fi
printf 'verapdf contract ok\n'
WRAPPER
chmod +x "$smoke_contract_repo/bin/odfvalidator.sh" "$smoke_contract_repo/bin/officeotron.sh" "$smoke_contract_repo/bin/verapdf.sh"
smoke_contract_report_path="$smoke_contract_repo/tmp/validator-readiness-smoke-contract.md"
PATH="$tmp_root/fakebin:$PATH" KDOFFICE_TARBALLS_DIR="$smoke_contract_repo/libreoffice-core/external/tarballs" \
    "$smoke_contract_repo/bin/validator-readiness.sh" --strict "$smoke_contract_report_path" > "$tmp_root/smoke-contract-stdout.log"

for expected in \
    'ODF Validator: **passed**' \
    'Officeotron: **passed**' \
    'veraPDF: **passed**' \
    'odf contract ok' \
    'officeotron contract ok' \
    'verapdf contract ok'
do
    if ! grep -F -q -- "$expected" "$smoke_contract_report_path"; then
        printf 'Expected smoke contract report to include %s\n' "$expected" >&2
        exit 1
    fi
done

success_repo="$tmp_root/success-repo"
mkdir -p "$success_repo/bin" "$success_repo/libreoffice-core/external/tarballs" "$success_repo/tmp"
cp "$script_under_test" "$success_repo/bin/validator-readiness.sh"
for asset in \
    odfvalidator-0.13.0-jar-with-dependencies.jar \
    officeotron-0.8.8.jar \
    verapdf-cli-1.29.0.jar
do
    printf 'fake asset for %s\n' "$asset" > "$success_repo/libreoffice-core/external/tarballs/$asset"
done
for wrapper in odfvalidator officeotron verapdf; do
    cat > "$success_repo/bin/$wrapper.sh" <<'WRAPPER'
#!/usr/bin/env bash
printf 'help ok\n'
WRAPPER
    chmod +x "$success_repo/bin/$wrapper.sh"
done
success_report_path="$success_repo/tmp/validator-readiness-strict.md"
PATH="$tmp_root/fakebin:$PATH" KDOFFICE_TARBALLS_DIR="$success_repo/libreoffice-core/external/tarballs" \
    "$success_repo/bin/validator-readiness.sh" --strict "$success_report_path" > "$tmp_root/success-stdout.log"

for expected in \
    'Ready validators: 3/3' \
    'Status: **ready**' \
    'ODF Validator: **passed**' \
    'Officeotron: **passed**' \
    'veraPDF: **passed**'
do
    if ! grep -F -q -- "$expected" "$success_report_path"; then
        printf 'Expected all-ready report to include %s\n' "$expected" >&2
        exit 1
    fi
done

printf 'validator-readiness missing asset, wrapper state, wrapper smoke, java, and all-ready tests passed\n'
