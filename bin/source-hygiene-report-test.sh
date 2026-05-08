#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_under_test="$repo_root/bin/source-hygiene-report.sh"

tmp_root="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp_root"
}
trap cleanup EXIT

fake_repo="$tmp_root/repo"
mkdir -p "$fake_repo/bin" "$fake_repo/docs/product" "$fake_repo/workdir/generated" "$fake_repo/instdir/app" "$fake_repo/.superpowers/session"
cp "$script_under_test" "$fake_repo/bin/source-hygiene-report.sh"
chmod +x "$fake_repo/bin/source-hygiene-report.sh"

git -C "$fake_repo" init -q
git -C "$fake_repo" config user.email source-hygiene-test@example.invalid
git -C "$fake_repo" config user.name "Source Hygiene Test"
printf 'tracked\n' > "$fake_repo/2.md"
git -C "$fake_repo" add 2.md bin/source-hygiene-report.sh
git -C "$fake_repo" commit -q -m 'seed tracked files'
printf 'modified\n' >> "$fake_repo/2.md"

cat > "$fake_repo/docs/product/source-hygiene-release-packet.md" <<'DOC'
# Source Hygiene Release Packet
DOC
cat > "$fake_repo/bin/v2-beta-gates.sh" <<'BIN'
#!/usr/bin/env bash
exit 0
BIN
for index in $(seq -w 1 85); do
    printf 'operator evidence %s\n' "$index" > "$fake_repo/docs/product/operator-$index.md"
done
printf 'generated\n' > "$fake_repo/workdir/generated/output.txt"
printf 'bundle\n' > "$fake_repo/instdir/app/output.txt"
printf 'session\n' > "$fake_repo/.superpowers/session/server.pid"
printf 'local\n' > "$fake_repo/local-note.txt"

report_path="$fake_repo/tmp/source-hygiene-report.md"
"$fake_repo/bin/source-hygiene-report.sh" "$report_path" > "$tmp_root/stdout.log"

if ! grep -q '| Source review/stage | 88 |' "$report_path"; then
    printf 'Expected source review/stage to include modified tracked and untracked operator-controlled source files\n' >&2
    exit 1
fi

for expected in \
    '` M` `2.md`' \
    '`??` `bin/v2-beta-gates.sh`' \
    '`??` `docs/product/source-hygiene-release-packet.md`'
do
    if ! awk '/^### Source review\/stage$/{in_section=1; next} /^### /{in_section=0} in_section{print}' "$report_path" | grep -q -- "$expected"; then
        printf 'Expected Source review/stage section to include %s\n' "$expected" >&2
        exit 1
    fi
    if awk '/^### Unresolved human-decision items$/{in_section=1; next} /^## / || /^### /{in_section=0} in_section{print}' "$report_path" | grep -q -- "$expected"; then
        printf 'Did not expect Unresolved human-decision items section to include %s\n' "$expected" >&2
        exit 1
    fi
done

if ! awk '/^### Unresolved human-decision items$/{in_section=1; next} /^## / || /^### /{in_section=0} in_section{print}' "$report_path" | grep -q -- '`??` `local-note.txt`'; then
    printf 'Expected unrelated untracked source file to remain an unresolved human-decision item\n' >&2
    exit 1
fi

if ! awk '/^### Generated\/local clean-or-ignore$/{in_section=1; next} /^### /{in_section=0} in_section{print}' "$report_path" | grep -q -- '`??` `.superpowers/session/server.pid`'; then
    printf 'Expected .superpowers session files to be classified as generated/local clean-or-ignore entries\n' >&2
    exit 1
fi

printf 'source-hygiene operator-controlled untracked classification test passed\n'
