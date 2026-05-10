#!/usr/bin/env bash
# V2 Day-0 skeleton documentation-coherence test.
#
# Owner: test-worker-2 (Mao supervisor scope: tests/**)
# Purpose: Lock in the file-map manifest in
#   docs/product/v2/day0-skeleton-landed.md (W1 Provider Runtime + W2
#   Command Palette Day-0 skeleton). The skeleton implementation lives in
#   sibling worktrees, so this test asserts documentation coherence rather
#   than working-tree existence: it pins the headline file map so any
#   future drift in the manifest fails the regression check.
#
# Verification:
#   bash tests/v2-day0-skeleton-test.sh
# Expected exit 0 with "Status: passed" on stdout.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

pass_count=0
pass() {
    pass_count=$((pass_count + 1))
}

doc="docs/product/v2/day0-skeleton-landed.md"

# 1. Doc must exist.
[[ -f "$doc" ]] || fail "missing $doc"
pass

# 2. File-map heading must be present (anchor for the manifest block).
grep -q '^## File map (this commit)$' "$doc" || fail "heading '## File map (this commit)' not in $doc"
pass

# 3. Representative manifest entries — one per W1 surface area + one per W2 surface area.
manifest_entries=(
    'offapi/com/sun/star/ai/XProvider.idl'
    'offapi/com/sun/star/ai/ProviderRequest.idl'
    'offapi/com/sun/star/ai/ProviderResponse.idl'
    'kqoffice/Library_kqoffice_ai.mk'
    'kqoffice/CppunitTest_kqoffice_provider.mk'
    'kqoffice/source/ai/provider/Provider.{cxx,hxx}'
    'kqoffice/source/ai/provider/ServiceModePolicy.{cxx,hxx}'
    'kqoffice/qa/cppunit/test_provider.cxx'
    'cui/source/inc/commandpalette/FuzzyMatcher.hxx'
    'cui/source/inc/commandpalette/CommandPalette.hxx'
    'cui/source/dialogs/commandpalette/CommandPalette.cxx'
    'cui/uiconfig/ui/commandpalette.ui'
    'cui/qa/unit/CommandPaletteFuzzyTest.cxx'
    'cui/CppunitTest_cui_commandpalette_fuzzy.mk'
)
for entry in "${manifest_entries[@]}"; do
    grep -qF "$entry" "$doc" || fail "manifest entry '$entry' missing from $doc"
    pass
done

# 4. Modified-file (edit) entries — Repository plumbing must be pinned.
edit_entries=(
    'Repository.mk'
    'RepositoryModule_host.mk'
    'offapi/UnoApi_offapi.mk'
    'cui/Library_cui.mk'
    'cui/Module_cui.mk'
    'cui/UIConfig_cui.mk'
)
for entry in "${edit_entries[@]}"; do
    grep -qF "$entry" "$doc" || fail "edit entry '$entry' missing from $doc"
    pass
done

# 5. Manifest line counts: at least 16 'new ' rows and 6 'edit ' rows
#    (matching the current 19-files-summarized-as-16-rows / 6-edits manifest;
#    two rows use {cxx,hxx} brace expansion to cover 4 files).
new_lines=$(grep -c '^new   ' "$doc" || true)
edit_lines=$(grep -c '^edit  ' "$doc" || true)
[[ "$new_lines" -ge 16 ]] || fail "expected >=16 'new   ' lines in $doc, got $new_lines"
pass
[[ "$edit_lines" -ge 6 ]] || fail "expected >=6 'edit  ' lines in $doc, got $edit_lines"
pass

# 6. Headline summary — '19 new files, 6 modified.' should be present so the
#    aggregate count pinned in the manifest cannot silently drift.
grep -qF '19 new files, 6 modified.' "$doc" || fail "headline summary '19 new files, 6 modified.' missing from $doc"
pass

# 7. W1 Day-1b evidence-recorder addendum — the doc should still surface the
#    10/10 cppunit case count so a future shrink shows up here.
grep -qF 'OK (10)' "$doc" || fail "W1 Day-1b 'OK (10)' green-bar marker missing from $doc"
pass

printf 'Status: passed, Checks: %s, Doc: %s\n' "$pass_count" "$doc"
