#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_under_test="$repo_root/bin/workbench-a11y-preflight.sh"

tmp_root="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp_root"
}
trap cleanup EXIT

fake_repo="$tmp_root/repo"
mkdir -p "$fake_repo/bin" "$fake_repo/tmp" "$fake_repo/test-install/可圈办公.app/Contents/MacOS"
cp "$script_under_test" "$fake_repo/bin/workbench-a11y-preflight.sh"
chmod +x "$fake_repo/bin/workbench-a11y-preflight.sh"
touch "$fake_repo/test-install/可圈办公.app/Contents/MacOS/soffice"
chmod +x "$fake_repo/test-install/可圈办公.app/Contents/MacOS/soffice"

write_stub() {
    local stub_path="$1"
    local body="$2"
    cat > "$stub_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
$body
EOF
    chmod +x "$stub_path"
}

write_stub "$fake_repo/bin/workbench-accessibility-check.sh" 'printf "# static\n" > "$1"'
write_stub "$fake_repo/bin/workbench-template-check.sh" 'printf "# template\n" > "$1"'
write_stub "$fake_repo/bin/gui-smoke-timing.sh" 'run_name=""; while [[ $# -gt 0 ]]; do case "$1" in --run-name) run_name="$2"; shift 2 ;; *) shift ;; esac; done; mkdir -p "tmp/gui-smoke-timing/$run_name"; printf "# gui\n" > "tmp/gui-smoke-timing/$run_name/report.md"'

report="$fake_repo/tmp/preflight.md"
"$fake_repo/bin/workbench-a11y-preflight.sh" --app "$fake_repo/test-install/可圈办公.app" --output "$report" --run-name unit-preflight

for expected in \
    'Status: passed' \
    'Manual live accessibility satisfied: no' \
    'Accessibility claim allowed: no' \
    'Beta gate effect: support evidence only' \
    'Static Start Center accessibility' \
    'Scenario template availability' \
    'Packaged app Start Center GUI survival'
do
    if ! grep -F -q -- "$expected" "$report"; then
        printf 'Expected preflight report to include %s\n' "$expected" >&2
        exit 1
    fi
done

if grep -F -q -- 'Accessibility claim allowed: yes' "$report"; then
    printf 'Preflight report must not claim live accessibility approval\n' >&2
    exit 1
fi

write_stub "$fake_repo/bin/workbench-template-check.sh" 'printf "# template failed\n" > "$1"; exit 1'
blocked_report="$fake_repo/tmp/preflight-blocked.md"
if "$fake_repo/bin/workbench-a11y-preflight.sh" --app "$fake_repo/test-install/可圈办公.app" --output "$blocked_report" --run-name unit-preflight-blocked > "$tmp_root/blocked-stdout.log" 2> "$tmp_root/blocked-stderr.log"; then
    printf 'Expected preflight to fail when a support gate fails\n' >&2
    exit 1
fi

for expected in \
    'Status: blocked' \
    '| Scenario template availability | fail |' \
    'Accessibility claim allowed: no'
do
    if ! grep -F -q -- "$expected" "$blocked_report"; then
        printf 'Expected blocked preflight report to include %s\n' "$expected" >&2
        exit 1
    fi
done

printf 'workbench-a11y-preflight tests passed\n'
