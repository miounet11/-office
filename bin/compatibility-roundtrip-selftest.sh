#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/bin/compatibility-roundtrip.sh"
work_root="$(mktemp -d "${TMPDIR:-/tmp}/compat-roundtrip-selftest.XXXXXX")"
trap 'rm -rf "$work_root"' EXIT

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_file_contains() {
    local path="$1"
    local needle="$2"
    if ! python3 - "$path" "$needle" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
needle = sys.argv[2]
text = path.read_text(encoding='utf-8', errors='replace')
if needle not in text:
    raise SystemExit(1)
PY
    then
        fail "expected $path to contain: $needle"
    fi
}

assert_file_not_contains() {
    local path="$1"
    local needle="$2"
    if python3 - "$path" "$needle" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
needle = sys.argv[2]
text = path.read_text(encoding='utf-8', errors='replace')
if needle in text:
    raise SystemExit(0)
raise SystemExit(1)
PY
    then
        fail "expected $path not to contain: $needle"
    fi
}

assert_line_count() {
    local path="$1"
    local expected="$2"
    local actual
    actual="$(python3 - "$path" <<'PY'
from pathlib import Path
import sys
print(len(Path(sys.argv[1]).read_text(encoding='utf-8').splitlines()))
PY
)"
    [[ "$actual" == "$expected" ]] || fail "expected $path to have $expected lines, got $actual"
}

fake_repo="$work_root/repo"
fake_src="$work_root/src"
mkdir -p "$fake_repo/bin" "$fake_repo/instdir/可圈办公.app/Contents/MacOS" \
    "$fake_src/sw/qa" "$fake_src/sc/qa" "$fake_src/sd/qa" "$fake_src/oox/qa"
ln -s "$fake_src" "$fake_repo/libreoffice-core"
cp "$script" "$fake_repo/bin/compatibility-roundtrip.sh"

cat > "$fake_repo/instdir/可圈办公.app/Contents/MacOS/soffice" <<'EOF'
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
[[ -n "$outdir" && -n "$target" && -n "$input" ]] || exit 64
mkdir -p "$outdir"
stem="$(basename "$input")"
stem="${stem%.*}"
printf 'fake %s conversion\n' "$target" > "$outdir/$stem.$target"
EOF
chmod +x "$fake_repo/instdir/可圈办公.app/Contents/MacOS/soffice"

cat > "$fake_repo/bin/odfvalidator.sh" <<'EOF'
#!/usr/bin/env bash
printf 'fake odfvalidator %s\n' "$*"
EOF
cat > "$fake_repo/bin/officeotron.sh" <<'EOF'
#!/usr/bin/env bash
printf 'missing validator jar: fake officeotron\n' >&2
exit 2
EOF
cat > "$fake_repo/bin/verapdf.sh" <<'EOF'
#!/usr/bin/env bash
printf 'fake verapdf %s\n' "$*"
EOF
chmod +x "$fake_repo/bin/odfvalidator.sh" "$fake_repo/bin/officeotron.sh" "$fake_repo/bin/verapdf.sh"

printf 'docx a\n' > "$fake_src/sw/qa/alpha.docx"
printf 'docx b\n' > "$fake_src/sw/qa/beta.docx"
printf 'xlsx\n' > "$fake_src/sc/qa/calc.xlsx"
printf 'pptx\n' > "$fake_src/sd/qa/deck.pptx"
printf 'pdf\n' > "$fake_src/oox/qa/sample.pdf"

report="$work_root/report.md"
"$fake_repo/bin/compatibility-roundtrip.sh" --format smoke --limit 1 --run-name selftest --report "$report" >/dev/null
assert_file_contains "$report" 'Format selection: docx,xlsx,pptx'
assert_file_contains "$report" '- `docx`: samples=1 successes=1 failures=0'
assert_file_contains "$report" '- `xlsx`: samples=1 successes=1 failures=0'
assert_file_contains "$report" '- `pptx`: samples=1 successes=1 failures=0'
assert_file_contains "$report" '- officeotron: `skipped:missing-asset`'
assert_line_count "$fake_repo/tmp/compatibility-runs/selftest/samples.tsv" 3

limit_report="$work_root/limit-report.md"
"$fake_repo/bin/compatibility-roundtrip.sh" --format docx --limit 1 --run-name limit-selftest --report "$limit_report" >/dev/null
assert_file_contains "$limit_report" '- `docx` — `sw/qa/alpha.docx`'
assert_file_not_contains "$limit_report" 'sw/qa/beta.docx'
assert_line_count "$fake_repo/tmp/compatibility-runs/limit-selftest/samples.tsv" 1

pdf_report="$work_root/pdf-report.md"
"$fake_repo/bin/compatibility-roundtrip.sh" --format pdf --limit 1 --run-name pdf-selftest --report "$pdf_report" >/dev/null
assert_file_contains "$pdf_report" '- validator target: `input-pdf`'
assert_file_contains "$pdf_report" '- verapdf: `passed`'
assert_file_contains "$pdf_report" '- `pdf`: samples=1 successes=1 failures=0'

if "$fake_repo/bin/compatibility-roundtrip.sh" --format bogus --limit 1 --run-name bad-selftest --report "$work_root/bad.md" >"$work_root/bad.out" 2>"$work_root/bad.err"; then
    fail 'unsupported format unexpectedly succeeded'
fi
assert_file_contains "$work_root/bad.err" 'Unsupported format lane: bogus'

if "$fake_repo/bin/compatibility-roundtrip.sh" --format docx --limit 0 --run-name bad-limit --report "$work_root/bad-limit.md" >"$work_root/bad-limit.out" 2>"$work_root/bad-limit.err"; then
    fail 'zero limit unexpectedly succeeded'
fi
assert_file_contains "$work_root/bad-limit.err" 'Limit must be a positive integer'

printf 'compatibility-roundtrip selftest passed\n'
