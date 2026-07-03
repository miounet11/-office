#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
script="$repo_root/bin/compatibility-roundtrip.sh"

failures=0

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/compat-roundtrip-test.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

assert_contains() {
    local file_path="$1"
    local needle="$2"
    if ! grep -Fq -- "$needle" "$file_path"; then
        printf 'FAIL: expected %s to contain: %s\n' "$file_path" "$needle" >&2
        failures=$((failures + 1))
    fi
}

run_script() {
    local name="$1"
    shift
    local stdout_path="$tmp_root/${name}.stdout"
    local stderr_path="$tmp_root/${name}.stderr"
    set +e
    "$script" "$@" >"$stdout_path" 2>"$stderr_path"
    local status=$?
    set -e
    printf '%s\n' "$status" > "$tmp_root/${name}.status"
}

run_script help --help
assert_contains "$tmp_root/help.stdout" 'Usage:'
assert_contains "$tmp_root/help.stdout" '--format <docx|xlsx|pptx|odt|ods|odp|doc|xls|ppt|pdf>'
assert_contains "$tmp_root/help.stdout" 'equivalent to docx,xlsx,pptx'

run_script missing_format_value --format
assert_contains "$tmp_root/missing_format_value.stderr" 'Missing value for --format'
assert_contains "$tmp_root/missing_format_value.stderr" 'Usage:'

run_script missing_limit_value --limit
assert_contains "$tmp_root/missing_limit_value.stderr" 'Missing value for --limit'
assert_contains "$tmp_root/missing_limit_value.stderr" 'Usage:'

run_script missing_manifest_value --manifest
assert_contains "$tmp_root/missing_manifest_value.stderr" 'Missing value for --manifest'
assert_contains "$tmp_root/missing_manifest_value.stderr" 'Usage:'

run_script missing_run_name_value --run-name
assert_contains "$tmp_root/missing_run_name_value.stderr" 'Missing value for --run-name'
assert_contains "$tmp_root/missing_run_name_value.stderr" 'Usage:'

run_script missing_report_value --report
assert_contains "$tmp_root/missing_report_value.stderr" 'Missing value for --report'
assert_contains "$tmp_root/missing_report_value.stderr" 'Usage:'

run_script bad_limit --limit 0
assert_contains "$tmp_root/bad_limit.stderr" 'Limit must be a positive integer'

traversal_repo="$tmp_root/traversal-repo"
traversal_src="$tmp_root/traversal-src"
mkdir -p "$traversal_repo/bin" "$traversal_src/test-install/可圈办公.app/Contents/MacOS"
cp "$script" "$traversal_repo/bin/compatibility-roundtrip.sh"
chmod +x "$traversal_repo/bin/compatibility-roundtrip.sh"
printf '#!/usr/bin/env bash\n' > "$traversal_src/test-install/可圈办公.app/Contents/MacOS/soffice"
chmod +x "$traversal_src/test-install/可圈办公.app/Contents/MacOS/soffice"
set +e
KDOFFICE_SRC_ROOT="$traversal_src" "$traversal_repo/bin/compatibility-roundtrip.sh" --format bogus --run-name ../../escape >"$tmp_root/run_name_traversal.stdout" 2>"$tmp_root/run_name_traversal.stderr"
run_name_traversal_status=$?
set -e
printf '%s\n' "$run_name_traversal_status" > "$tmp_root/run_name_traversal.status"
assert_contains "$tmp_root/run_name_traversal.stderr" 'Invalid run name'
if [[ -e "$traversal_repo/tmp/escape" ]]; then
    printf 'FAIL: path-traversing run name created %s\n' "$traversal_repo/tmp/escape" >&2
    failures=$((failures + 1))
fi

fake_src_root="$tmp_root/source-root"
mkdir -p "$fake_src_root/test-install/可圈办公.app/Contents/MacOS"
printf '#!/usr/bin/env bash\n' > "$fake_src_root/test-install/可圈办公.app/Contents/MacOS/soffice"
chmod +x "$fake_src_root/test-install/可圈办公.app/Contents/MacOS/soffice"
set +e
KDOFFICE_SRC_ROOT="$fake_src_root" "$script" --format '?' --run-name fallback-probe >"$tmp_root/source_fallback.stdout" 2>"$tmp_root/source_fallback.stderr"
source_fallback_status=$?
set -e
printf '%s\n' "$source_fallback_status" > "$tmp_root/source_fallback.status"
assert_contains "$tmp_root/source_fallback.stderr" "Unsupported format lane: ?"

run_script format_next_token_option --format --limit 1
assert_contains "$tmp_root/format_next_token_option.stderr" 'Option --format requires a value'
assert_contains "$tmp_root/format_next_token_option.stderr" 'Usage:'

if [[ "$(<"$tmp_root/help.status")" != "0" ]]; then
    printf 'FAIL: --help exited with %s\n' "$(<"$tmp_root/help.status")" >&2
    failures=$((failures + 1))
fi

for name in \
    missing_format_value \
    missing_limit_value \
    missing_manifest_value \
    missing_run_name_value \
    missing_report_value \
    bad_limit \
    run_name_traversal \
    source_fallback \
    format_next_token_option
    do
    if [[ "$(<"$tmp_root/${name}.status")" == "0" ]]; then
        printf 'FAIL: %s should fail\n' "$name" >&2
        failures=$((failures + 1))
    fi
done

isolated_repo="$tmp_root/isolated-repo"
isolated_src="$tmp_root/isolated-src"
mkdir -p "$isolated_repo/bin" "$isolated_src/samples"
cp "$script" "$isolated_repo/bin/compatibility-roundtrip.sh"
chmod +x "$isolated_repo/bin/compatibility-roundtrip.sh"
printf 'fake odt\n' > "$isolated_src/samples/ext.odt"
printf 'fake odt\n' > "$isolated_src/samples/unknown.odt"
printf 'fake docx\n' > "$isolated_src/samples/wrong.docx"
mkdir -p "$isolated_src/links" "$tmp_root/outside-source"
printf 'escaped odt\n' > "$tmp_root/outside-source/escaped.odt"
ln -s "$tmp_root/outside-source" "$isolated_src/links/outside"
printf 'odt\tsamples/ext.odt\textension namespace validator fixture\n' > "$tmp_root/odf-extension.tsv"
printf 'odt\tsamples/unknown.odt\tunknown validator failure fixture\n' > "$tmp_root/odf-unknown.tsv"
printf 'docx\tsamples/wrong.docx\twrong extension output fixture\n' > "$tmp_root/wrong-output.tsv"
printf 'odt\tlinks/outside/escaped.odt\tsymlink escape fixture\n' > "$tmp_root/symlink-escape.tsv"

cat > "$isolated_repo/bin/soffice" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
outdir=""
target=""
input=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --convert-to)
            target="$2"
            shift 2
            ;;
        --outdir)
            outdir="$2"
            shift 2
            ;;
        --headless)
            shift
            ;;
        *)
            input="$1"
            shift
            ;;
    esac
done
mkdir -p "$outdir"
base="$(basename "$input")"
stem="${base%.*}"
case "$base:$target" in
    wrong.docx:odt)
        printf 'converted %s to wrong extension\n' "$input" > "$outdir/$stem.txt"
        ;;
    *)
        printf 'converted %s to %s\n' "$input" "$target" > "$outdir/$stem.$target"
        ;;
esac
SH
chmod +x "$isolated_repo/bin/soffice"

cat > "$isolated_repo/bin/odfvalidator.sh" <<'SH'
#!/usr/bin/env bash
case "$1" in
    *unknown*)
        printf 'validator crashed before structured diagnostics\n' >&2
        ;;
    *)
        printf '%s/content.xml[2,10]:  Error: unexpected attribute "loext:decorative"\n' "$1" >&2
        printf '%s/styles.xml[2,20]:  Error: tag name "loext:theme" is not allowed\n' "$1" >&2
        ;;
esac
exit 1
SH
chmod +x "$isolated_repo/bin/odfvalidator.sh"

cat > "$isolated_repo/bin/officeotron.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$isolated_repo/bin/officeotron.sh"

cat > "$isolated_repo/bin/verapdf.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$isolated_repo/bin/verapdf.sh"

original_script="$script"
script="$isolated_repo/bin/compatibility-roundtrip.sh"
KDOFFICE_SRC_ROOT="$isolated_src" KDOFFICE_SOFFICE_BIN="$isolated_repo/bin/soffice" \
    run_script symlink_escape_manifest --manifest "$tmp_root/symlink-escape.tsv" --report "$tmp_root/symlink-escape.md"
assert_contains "$tmp_root/symlink_escape_manifest.stderr" 'path must be source-relative and stay inside source root'

KDOFFICE_SRC_ROOT="$isolated_src" KDOFFICE_SOFFICE_BIN="$isolated_repo/bin/soffice" \
    run_script odf_extension_advisory --manifest "$tmp_root/odf-extension.tsv" --report "$tmp_root/odf-extension-advisory.md"
assert_contains "$tmp_root/odf_extension_advisory.stdout" 'Wrote roundtrip report to'
assert_contains "$tmp_root/odf-extension-advisory.md" '- conversion result: **success**'
assert_contains "$tmp_root/odf-extension-advisory.md" '- result: **success**'
assert_contains "$tmp_root/odf-extension-advisory.md" '- odfvalidator: `failed:extension-namespace`'

KDOFFICE_SRC_ROOT="$isolated_src" KDOFFICE_SOFFICE_BIN="$isolated_repo/bin/soffice" \
    run_script odf_extension_strict --manifest "$tmp_root/odf-extension.tsv" --strict-validators --report "$tmp_root/odf-extension-strict.md"
assert_contains "$tmp_root/odf-extension-strict.md" '- conversion result: **success**'
assert_contains "$tmp_root/odf-extension-strict.md" '- result: **failure**'
assert_contains "$tmp_root/odf-extension-strict.md" '- odfvalidator: `failed:extension-namespace`'
assert_contains "$tmp_root/odf-extension-strict.md" '- notes: validator failed in strict mode'

KDOFFICE_SRC_ROOT="$isolated_src" KDOFFICE_SOFFICE_BIN="$isolated_repo/bin/soffice" \
    run_script odf_unknown_strict --manifest "$tmp_root/odf-unknown.tsv" --strict-validators --report "$tmp_root/odf-unknown-strict.md"
assert_contains "$tmp_root/odf-unknown-strict.md" '- conversion result: **success**'
assert_contains "$tmp_root/odf-unknown-strict.md" '- result: **failure**'
assert_contains "$tmp_root/odf-unknown-strict.md" '- odfvalidator: `failed:unknown`'
assert_contains "$tmp_root/odf-unknown-strict.md" '- notes: validator failed in strict mode'

KDOFFICE_SRC_ROOT="$isolated_src" KDOFFICE_SOFFICE_BIN="$isolated_repo/bin/soffice" \
    run_script wrong_output --manifest "$tmp_root/wrong-output.tsv" --report "$tmp_root/wrong-output.md"
assert_contains "$tmp_root/wrong-output.md" '- conversion result: **failure**'
assert_contains "$tmp_root/wrong-output.md" '- result: **failure**'
assert_contains "$tmp_root/wrong-output.md" '- notes: step1 output missing or ambiguous'
script="$original_script"

if [[ "$(<"$tmp_root/odf_extension_advisory.status")" != "0" ]]; then
    printf 'FAIL: odf_extension_advisory exited with %s\n' "$(<"$tmp_root/odf_extension_advisory.status")" >&2
    failures=$((failures + 1))
fi
if [[ "$(<"$tmp_root/odf_extension_strict.status")" == "0" ]]; then
    printf 'FAIL: odf_extension_strict should fail\n' >&2
    failures=$((failures + 1))
fi
if [[ "$(<"$tmp_root/odf_unknown_strict.status")" == "0" ]]; then
    printf 'FAIL: odf_unknown_strict should fail\n' >&2
    failures=$((failures + 1))
fi
if [[ "$(<"$tmp_root/wrong_output.status")" == "0" ]]; then
    printf 'FAIL: wrong_output should fail\n' >&2
    failures=$((failures + 1))
fi

if [[ "$(<"$tmp_root/symlink_escape_manifest.status")" == "0" ]]; then
    printf 'FAIL: symlink_escape_manifest should fail\n' >&2
    failures=$((failures + 1))
fi

if [[ "$failures" -ne 0 ]]; then
    exit 1
fi

printf 'compatibility-roundtrip argument checks passed\n'
