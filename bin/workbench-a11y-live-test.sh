#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_under_test="$repo_root/bin/workbench-a11y-live.sh"

tmp_root="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp_root"
}
dump_failure() {
    local status=$?
    if [[ "$status" -ne 0 ]]; then
        printf 'workbench-a11y-live-test failed; tmp=%s\n' "$tmp_root" >&2
        for log in "$tmp_root/stdout.log" "$tmp_root/stderr.log" "${report:-}" "${fake_soffice_log:-}" "${fake_open_log:-}"; do
            if [[ -n "$log" && -f "$log" ]]; then
                printf -- '--- %s ---\n' "$log" >&2
                sed -n '1,160p' "$log" >&2 || true
            fi
        done
    fi
    cleanup
    exit "$status"
}
trap dump_failure EXIT

fake_repo="$tmp_root/repo"
fake_app="$fake_repo/test-install/可圈办公.app"
mkdir -p "$fake_repo/bin" "$fake_app/Contents/MacOS" "$fake_repo/fake-bin" "$fake_repo/tmp/product-completion"
resolved_fake_app="$(cd -P "$fake_app" && pwd)"
cp "$script_under_test" "$fake_repo/bin/workbench-a11y-live.sh"
chmod +x "$fake_repo/bin/workbench-a11y-live.sh"

cat > "$fake_app/Contents/MacOS/soffice" <<'SOFFICE'
#!/usr/bin/env bash
set -euo pipefail
printf 'soffice %s\n' "$*" >> "${KDOFFICE_A11Y_FAKE_SOFFICE_LOG:?missing fake log}"
SOFFICE
chmod +x "$fake_app/Contents/MacOS/soffice"

cat > "$fake_repo/fake-bin/open" <<'OPEN'
#!/usr/bin/env bash
printf 'open was called\n' >> "${KDOFFICE_A11Y_FAKE_OPEN_LOG:?missing open log}"
exit 0
OPEN
chmod +x "$fake_repo/fake-bin/open"

input_path="$tmp_root/input.txt"
for _ in $(seq 1 24); do
    printf '\npass\n'
done > "$input_path"

report="$fake_repo/tmp/product-completion/live-accessibility-proof.md"
fake_soffice_log="$tmp_root/soffice.log"
fake_open_log="$tmp_root/open.log"
touch "$fake_open_log"

checklist_report="$fake_repo/tmp/product-completion/live-accessibility-checklist.md"
checklist_proof="$fake_repo/tmp/product-completion/live-accessibility-checklist-proof.md"
checklist_soffice_log="$tmp_root/checklist-soffice.log"
PATH="$fake_repo/fake-bin:$PATH" \
KDOFFICE_A11Y_FAKE_SOFFICE_LOG="$checklist_soffice_log" \
KDOFFICE_A11Y_FAKE_OPEN_LOG="$fake_open_log" \
KDOFFICE_A11Y_PROFILE_DIR="$fake_repo/tmp/a11y-checklist-profile" \
    "$fake_repo/bin/workbench-a11y-live.sh" --app "$fake_app" --output "$checklist_proof" --checklist "$checklist_report" > "$tmp_root/checklist-stdout.log" 2> "$tmp_root/checklist-stderr.log"

for expected in \
    '# Live Accessibility Manual Review Checklist' \
    '- Status: support-only' \
    '- Accessibility claim allowed: no' \
    '- Manual proof required: yes' \
    'Only a completed proof with 24 pass results can satisfy workbench-live-accessibility.'
do
    if ! grep -F -q -- "$expected" "$checklist_report"; then
        printf 'Expected checklist report to include %s\n' "$expected" >&2
        exit 1
    fi
done

check_count="$(grep -E -c '^\| [0-9]+ \|' "$checklist_report")"
if [[ "$check_count" != "24" ]]; then
    printf 'Expected checklist to include 24 checks, got %s\n' "$check_count" >&2
    exit 1
fi

if [[ -e "$checklist_proof" ]]; then
    printf 'Expected checklist mode not to write live proof evidence\n' >&2
    exit 1
fi
if [[ -s "$checklist_soffice_log" ]] && grep -F -q -- 'soffice ' "$checklist_soffice_log"; then
    printf 'Expected checklist mode not to launch soffice\n' >&2
    exit 1
fi

printf 'workbench-a11y-live checklist test passed\n'

PATH="$fake_repo/fake-bin:$PATH" \
KDOFFICE_A11Y_FAKE_SOFFICE_LOG="$fake_soffice_log" \
KDOFFICE_A11Y_FAKE_OPEN_LOG="$fake_open_log" \
KDOFFICE_A11Y_PROFILE_DIR="$fake_repo/tmp/a11y-profile" \
    "$fake_repo/bin/workbench-a11y-live.sh" --app "$fake_app" --output "$report" < "$input_path" > "$tmp_root/stdout.log" 2> "$tmp_root/stderr.log"

for _ in $(seq 1 50); do
    if [[ -f "$fake_soffice_log" ]] && [[ "$(grep -c '^soffice ' "$fake_soffice_log")" == "24" ]]; then
        break
    fi
    sleep 0.1
done

for expected in \
    '- Status: passed' \
    '- Accessibility claim allowed: yes' \
    '- Total pass: 24 / fail: 0 / skip: 0' \
    '- Launch method: direct soffice executable' \
    "$resolved_fake_app/Contents/MacOS/soffice"
do
    if ! grep -F -q -- "$expected" "$report"; then
        printf 'Expected live accessibility proof to include %s\n' "$expected" >&2
        exit 1
    fi
done

if [[ -s "$fake_open_log" ]]; then
    printf 'Expected live accessibility helper to avoid macOS open routing\n' >&2
    exit 1
fi

launch_count="$(grep -c '^soffice ' "$fake_soffice_log")"
if [[ "$launch_count" != "24" ]]; then
    printf 'Expected 24 direct soffice launches, got %s\n' "$launch_count" >&2
    exit 1
fi

for expected in '--writer' '--calc' '--impress' '--draw'; do
    if ! grep -F -q -- "$expected" "$fake_soffice_log"; then
        printf 'Expected fake soffice log to include %s\n' "$expected" >&2
        exit 1
    fi
done

printf 'workbench-a11y-live direct-launch test passed\n'

resume_report="$fake_repo/tmp/product-completion/live-accessibility-resume-proof.md"
resume_soffice_log="$tmp_root/resume-soffice.log"
resume_input_one="$tmp_root/resume-one.txt"
resume_input_remaining="$tmp_root/resume-remaining.txt"
printf '\npass\n' > "$resume_input_one"
for _ in $(seq 1 23); do
    printf '\npass\n'
done > "$resume_input_remaining"

PATH="$fake_repo/fake-bin:$PATH" \
KDOFFICE_A11Y_FAKE_SOFFICE_LOG="$resume_soffice_log" \
KDOFFICE_A11Y_FAKE_OPEN_LOG="$fake_open_log" \
KDOFFICE_A11Y_PROFILE_DIR="$fake_repo/tmp/a11y-resume-profile" \
    "$fake_repo/bin/workbench-a11y-live.sh" --app "$fake_app" --output "$resume_report" < "$resume_input_one" > "$tmp_root/resume-one-stdout.log" 2> "$tmp_root/resume-one-stderr.log" || true

if ! grep -F -q -- '- Total pass: 1 / fail: 0 / skip: 0' "$resume_report"; then
    printf 'Expected first partial proof to record one pass\n' >&2
    exit 1
fi

PATH="$fake_repo/fake-bin:$PATH" \
KDOFFICE_A11Y_FAKE_SOFFICE_LOG="$resume_soffice_log" \
KDOFFICE_A11Y_FAKE_OPEN_LOG="$fake_open_log" \
KDOFFICE_A11Y_PROFILE_DIR="$fake_repo/tmp/a11y-resume-profile" \
    "$fake_repo/bin/workbench-a11y-live.sh" --resume --app "$fake_app" --output "$resume_report" < "$resume_input_remaining" > "$tmp_root/resume-remaining-stdout.log" 2> "$tmp_root/resume-remaining-stderr.log"

for expected in \
    'Resumed 1 completed live accessibility checks' \
    'Already recorded: pass; skipping.'
do
    if ! grep -F -q -- "$expected" "$tmp_root/resume-remaining-stdout.log"; then
        printf 'Expected resume stdout to include %s\n' "$expected" >&2
        exit 1
    fi
done

if ! grep -F -q -- '- Total pass: 24 / fail: 0 / skip: 0' "$resume_report"; then
    printf 'Expected resumed proof to complete 24 passes\n' >&2
    exit 1
fi

resume_launch_count="$(grep -c '^soffice ' "$resume_soffice_log")"
if [[ "$resume_launch_count" != "24" ]]; then
    printf 'Expected resume flow to launch 24 total checks, got %s\n' "$resume_launch_count" >&2
    exit 1
fi

printf 'workbench-a11y-live resume test passed\n'
