#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_under_test="$repo_root/bin/compatibility-roundtrip.sh"

tmp_root="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp_root"
}
trap cleanup EXIT

fake_repo="$tmp_root/repo"
mkdir -p "$fake_repo/bin"
cp "$script_under_test" "$fake_repo/bin/compatibility-roundtrip.sh"

mkdir -p "$fake_repo/libreoffice-core/sw/qa/import"
: > "$fake_repo/libreoffice-core/sw/qa/import/sample.docx"
mkdir -p "$fake_repo/instdir/可圈office.app/Contents/MacOS"
cat > "$fake_repo/instdir/可圈office.app/Contents/MacOS/soffice" <<'SOFFICE'
#!/usr/bin/env bash
printf 'simulated conversion failure\n' >&2
exit 1
SOFFICE
chmod +x "$fake_repo/instdir/可圈office.app/Contents/MacOS/soffice"

run_name="conversion-failure"
report_path="$fake_repo/tmp/report.md"
mkdir -p "$(dirname "$report_path")"

set +e
"$fake_repo/bin/compatibility-roundtrip.sh" --format docx --limit 1 --run-name "$run_name" --report "$report_path" > "$tmp_root/stdout.log" 2> "$tmp_root/stderr.log"
status=$?
set -e

if [[ "$status" -eq 0 ]]; then
    printf 'Expected non-zero exit when a roundtrip conversion fails\n' >&2
    printf 'stdout:\n' >&2
    python3 - "$tmp_root/stdout.log" <<'PY' >&2
from pathlib import Path
import sys
print(Path(sys.argv[1]).read_text())
PY
    printf 'stderr:\n' >&2
    python3 - "$tmp_root/stderr.log" <<'PY' >&2
from pathlib import Path
import sys
print(Path(sys.argv[1]).read_text())
PY
    exit 1
fi

if ! grep -q -- '- failures: 1' "$report_path"; then
    printf 'Expected report to record one failed sample\n' >&2
    exit 1
fi

override_src_root="$tmp_root/override-src"
override_soffice_bin="$tmp_root/override-soffice"
override_report_path="$fake_repo/tmp/override-report.md"
override_manifest_path="$tmp_root/override-manifest.tsv"
mkdir -p "$override_src_root/sw/qa/import" "$(dirname "$override_report_path")"
: > "$override_src_root/sw/qa/import/override-only.docx"
printf 'docx\tsw/qa/import/override-only.docx\toverride source root sample\n' > "$override_manifest_path"
cat > "$override_soffice_bin" <<'SOFFICE'
#!/usr/bin/env bash
set -euo pipefail
outdir=""
target=""
input=""
while [[ $# -gt 0 ]]; do
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
stem="$(basename "$input")"
stem="${stem%.*}"
: > "$outdir/$stem.$target"
SOFFICE
chmod +x "$override_soffice_bin"

KDOFFICE_SRC_ROOT="$override_src_root" KDOFFICE_SOFFICE_BIN="$override_soffice_bin" \
    "$fake_repo/bin/compatibility-roundtrip.sh" --manifest "$override_manifest_path" --run-name "override-source-root" --report "$override_report_path" > "$tmp_root/override-stdout.log" 2> "$tmp_root/override-stderr.log"

if ! grep -q -- '- successes: 1' "$override_report_path"; then
    printf 'Expected override source root and soffice bin to produce one successful sample\n' >&2
    printf 'stdout:\n' >&2
    python3 - "$tmp_root/override-stdout.log" <<'PY' >&2
from pathlib import Path
import sys
print(Path(sys.argv[1]).read_text())
PY
    printf 'stderr:\n' >&2
    python3 - "$tmp_root/override-stderr.log" <<'PY' >&2
from pathlib import Path
import sys
print(Path(sys.argv[1]).read_text())
PY
    exit 1
fi

fallback_repo="$tmp_root/fallback-repo"
fallback_report_path="$fallback_repo/tmp/fallback-report.md"
mkdir -p "$fallback_repo/bin" "$fallback_repo/libreoffice-core/sw/qa/import" "$fallback_repo/test-install/可圈office.app/Contents/MacOS" "$(dirname "$fallback_report_path")"
cp "$script_under_test" "$fallback_repo/bin/compatibility-roundtrip.sh"
: > "$fallback_repo/libreoffice-core/sw/qa/import/fallback.docx"
cat > "$fallback_repo/test-install/可圈office.app/Contents/MacOS/soffice" <<'SOFFICE'
#!/usr/bin/env bash
set -euo pipefail
outdir=""
target=""
input=""
while [[ $# -gt 0 ]]; do
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
stem="$(basename "$input")"
stem="${stem%.*}"
: > "$outdir/$stem.$target"
SOFFICE
chmod +x "$fallback_repo/test-install/可圈office.app/Contents/MacOS/soffice"

"$fallback_repo/bin/compatibility-roundtrip.sh" --format docx --limit 1 --run-name "test-install-fallback" --report "$fallback_report_path" > "$tmp_root/fallback-stdout.log" 2> "$tmp_root/fallback-stderr.log"

if ! grep -q -- '- successes: 1' "$fallback_report_path"; then
    printf 'Expected test-install soffice fallback to produce one successful sample\n' >&2
    printf 'stdout:\n' >&2
    python3 - "$tmp_root/fallback-stdout.log" <<'PY' >&2
from pathlib import Path
import sys
print(Path(sys.argv[1]).read_text())
PY
    printf 'stderr:\n' >&2
    python3 - "$tmp_root/fallback-stderr.log" <<'PY' >&2
from pathlib import Path
import sys
print(Path(sys.argv[1]).read_text())
PY
    exit 1
fi

strict_gap_repo="$tmp_root/strict-gap-repo"
strict_gap_report_path="$strict_gap_repo/tmp/strict-gap-report.md"
mkdir -p "$strict_gap_repo/bin" "$strict_gap_repo/libreoffice-core/sw/qa/import" "$strict_gap_repo/instdir/可圈office.app/Contents/MacOS" "$(dirname "$strict_gap_report_path")"
cp "$script_under_test" "$strict_gap_repo/bin/compatibility-roundtrip.sh"
: > "$strict_gap_repo/libreoffice-core/sw/qa/import/strict-gap.docx"
cat > "$strict_gap_repo/instdir/可圈office.app/Contents/MacOS/soffice" <<'SOFFICE'
#!/usr/bin/env bash
set -euo pipefail
outdir=""
target=""
input=""
while [[ $# -gt 0 ]]; do
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
stem="$(basename "$input")"
stem="${stem%.*}"
: > "$outdir/$stem.$target"
SOFFICE
chmod +x "$strict_gap_repo/instdir/可圈office.app/Contents/MacOS/soffice"
cat > "$strict_gap_repo/bin/odfvalidator.sh" <<'VALIDATOR'
#!/usr/bin/env bash
exit 0
VALIDATOR
chmod +x "$strict_gap_repo/bin/odfvalidator.sh"
cat > "$strict_gap_repo/bin/officeotron.sh" <<'VALIDATOR'
#!/usr/bin/env bash
printf 'missing validator jar: /missing/officeotron-0.8.8.jar\n' >&2
exit 2
VALIDATOR
chmod +x "$strict_gap_repo/bin/officeotron.sh"
cat > "$strict_gap_repo/bin/verapdf.sh" <<'VALIDATOR'
#!/usr/bin/env bash
exit 0
VALIDATOR
chmod +x "$strict_gap_repo/bin/verapdf.sh"

"$strict_gap_repo/bin/compatibility-roundtrip.sh" --format docx --limit 1 --strict-validators --run-name "strict-validator-readiness-gap" --report "$strict_gap_report_path" > "$tmp_root/strict-gap-stdout.log" 2> "$tmp_root/strict-gap-stderr.log"

if ! grep -q -- '- validator readiness gaps: `officeotron=skipped:missing-asset`' "$strict_gap_report_path"; then
    printf 'Expected strict report to summarize missing validator asset readiness gaps\n' >&2
    exit 1
fi

if ! grep -q -- 'docs/compatibility/validator-assets-release-packet.md' "$strict_gap_report_path"; then
    printf 'Expected strict report to point to the validator asset release packet\n' >&2
    exit 1
fi

printf 'compatibility-roundtrip failure exit test passed\n'
printf 'compatibility-roundtrip source/soffice override test passed\n'
printf 'compatibility-roundtrip test-install fallback test passed\n'
printf 'compatibility-roundtrip strict validator readiness gap test passed\n'
