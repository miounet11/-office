#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_under_test="$repo_root/bin/v2-beta-gates.sh"

tmp_root="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp_root"
}
trap cleanup EXIT

fake_repo="$tmp_root/repo"
mkdir -p "$fake_repo/bin" "$fake_repo/docs/accessibility" "$fake_repo/docs/compatibility" "$fake_repo/docs/product" "$fake_repo/tmp"
cp "$script_under_test" "$fake_repo/bin/v2-beta-gates.sh"
chmod +x "$fake_repo/bin/v2-beta-gates.sh"

touch "$fake_repo/docs/compatibility/smoke-manifest.tsv"
touch "$fake_repo/docs/product/beta-blocker-remediation-protocol.md"
cat > "$fake_repo/docs/accessibility/workbench-accessibility-evidence-m2-06.md" <<'EOF'
# accessibility evidence
EOF

write_stub() {
    local path="$1"
    local body="$2"
    cat > "$path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
$body
EOF
    chmod +x "$path"
}

write_stub "$fake_repo/bin/compatibility-manifest-audit.sh" 'exit 0'
write_stub "$fake_repo/bin/validator-readiness.sh" 'printf "validator strict failed\n" >&2; exit 1'
write_stub "$fake_repo/bin/compatibility-roundtrip.sh" 'printf "roundtrip strict failed\n" >&2; exit 1'
write_stub "$fake_repo/bin/workbench-accessibility-check.sh" 'exit 0'
write_stub "$fake_repo/bin/gui-smoke-timing.sh" 'exit 0'
write_stub "$fake_repo/bin/compatibility-layout-evidence.sh" 'exit 0'
write_stub "$fake_repo/bin/source-hygiene-report.sh" 'printf "source hygiene failed\n" >&2; exit 1'
write_stub "$fake_repo/bin/plugin-manifest-validator.sh" 'exit 0'

run_name="unit-remediation-order"
if "$fake_repo/bin/v2-beta-gates.sh" "$run_name" > "$tmp_root/stdout.log" 2> "$tmp_root/stderr.log"; then
    printf 'Expected beta gates to fail when strict validator, roundtrip, source hygiene, and live accessibility blockers fail\n' >&2
    exit 1
fi

report="$fake_repo/tmp/v2-beta-gates/$run_name.md"
json_report="$fake_repo/tmp/v2-beta-gates/$run_name.json"

for expected in \
    'Status: **failed**' \
    'validator-readiness-strict' \
    'compatibility-roundtrip' \
    'source-hygiene-strict' \
    'workbench-live-accessibility'
do
    if ! grep -F -q -- "$expected" "$report"; then
        printf 'Expected beta gate report to include %s\n' "$expected" >&2
        exit 1
    fi
done

if grep -F -q -- 'GUI survival diagnostics' "$report"; then
    printf 'Did not expect GUI remediation text when gui-smoke-timing-startcenter passed\n' >&2
    exit 1
fi

python3 - "$json_report" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

failed = [item["key"] for item in payload["failed_blockers"]]
expected = [
    "validator-readiness-strict",
    "compatibility-roundtrip",
    "source-hygiene-strict",
    "workbench-live-accessibility",
]
if failed != expected:
    raise SystemExit(f"unexpected failed blockers: {failed!r}")
PY

printf 'v2-beta-gates remediation-order tests passed\n'
