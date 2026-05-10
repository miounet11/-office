#!/usr/bin/env bash
# V2 W3 Day-1b — apply-plan-runtime schema ↔ C++ kind enum lock harness (H7).
#
# Sibling of:
#   tests/v2-async-task-schema-test.sh           (H4, W5)
#   tests/v2-inline-action-request-schema-test.sh (H5, W4)
#
# Until W3 Day-1b/c/d land per-kind SwUndoApplyPatch impls under
# sw/source/uibase/<...>, this harness runs in *partial-enforce*
# mode: it locks the schema kind enum order against W3 spec
# §"Patch Kinds（v1）" table order and walks the fixture roster,
# but skips C++ string-literal extraction. Once all 7 SwUndoApplyPatch
# subclasses (or a single SwUndoApplyPatch.hxx that lists them all)
# land in SRCDIR, the harness auto-promotes itself to full enforcement.
#
# Locks (when schema + C++ headers all exist):
#
#   1. docs/schemas/apply-plan-runtime.schema.json — patches.items.
#      properties.kind enum order matches W3 spec §"Patch Kinds（v1）"
#      table top-to-bottom.
#   2. C++ kind tokens (string literals) in
#      ${KDOFFICE_SRC_ROOT}/sw/source/uibase/inline-actions/SwUndoApplyPatch.hxx
#      OR (if that file doesn't exist) the per-kind subclass headers
#      under sw/source/uibase/inline-actions/SwUndoApplyPatch*.hxx.
#   3. Fixtures docs/schemas/fixtures/apply-plan-runtime.{valid,invalid,utf8}.json
#      enforce expected validity via canonical fixture validator.
#
# Source-of-truth strings (W3 spec §"Patch Kinds（v1）"):
#
#   kind: paragraph-replace | paragraph-insert-after | paragraph-delete |
#         paragraph-format | paragraph-reformat | text-range-replace |
#         text-format
#
# Verification:
#   bash tests/v2-apply-plan-runtime-schema-test.sh
# Expected exit 0 with "Status: skipped" if schema missing, "Status:
# passed (partial)" until W3 Day-1b/c/d land the SwUndoApplyPatch
# header(s), "Status: passed" thereafter.
#
# Owner: V2 W3 (writer apply runtime). Scoped to docs/schemas/ +
# sw/source/uibase/inline-actions/SwUndoApplyPatch*.hxx once authorized.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

src_root="${KDOFFICE_SRC_ROOT:-/Users/lu/kdoffice-src}"

schema="docs/schemas/apply-plan-runtime.schema.json"
fixtures=(
    "docs/schemas/fixtures/apply-plan-runtime.valid.json"
    "docs/schemas/fixtures/apply-plan-runtime.invalid.json"
    "docs/schemas/fixtures/apply-plan-runtime.utf8.json"
)
expected_validity=("valid" "invalid" "valid")

# Either a single aggregator header lists all 7, or per-kind subclass
# headers each name their own kind. Harness accepts either layout.
patch_aggregator_hxx="$src_root/sw/source/uibase/inline-actions/SwUndoApplyPatch.hxx"
patch_subclass_glob="$src_root/sw/source/uibase/inline-actions/SwUndoApplyPatch*.hxx"

EXPECTED_KINDS="paragraph-replace paragraph-insert-after paragraph-delete paragraph-format paragraph-reformat text-range-replace text-format"

skip() {
    printf 'Status: skipped\n'
    printf 'Reason: %s\n' "$1"
    printf 'Source-of-truth tokens (W3 spec §%s):\n' '"Patch Kinds（v1）"'
    printf '  kind (7): %s\n' "$EXPECTED_KINDS"
    printf 'Auto-promotes to full enforcement once schema + SwUndoApplyPatch*.hxx land.\n'
    exit 0
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

# --- Mode selection ----------------------------------------------------------
schema_present=true
fixtures_present=true

[[ -e "$schema" ]] || schema_present=false
for f in "${fixtures[@]}"; do
    [[ -e "$f" ]] || fixtures_present=false
done

if ! $schema_present || ! $fixtures_present; then
    missing=()
    $schema_present || missing+=("$schema")
    for f in "${fixtures[@]}"; do
        [[ -e "$f" ]] || missing+=("$f")
    done
    skip "W3 schema/fixtures not yet landed; missing: ${missing[*]}"
fi

# Detect headers: either aggregator OR ≥1 subclass match.
hxx_files=()
if [[ -e "$patch_aggregator_hxx" ]]; then
    hxx_files+=("$patch_aggregator_hxx")
fi
shopt -s nullglob
subclass_matches=( $patch_subclass_glob )
shopt -u nullglob
if (( ${#subclass_matches[@]} > 0 )); then
    for f in "${subclass_matches[@]}"; do
        # Skip if it's already the aggregator we added.
        [[ "$f" == "$patch_aggregator_hxx" ]] && continue
        hxx_files+=("$f")
    done
fi

mode="partial-enforce"
if (( ${#hxx_files[@]} >= 1 )); then
    mode="full-enforce"
fi

python3 - "$schema" "$mode" "$EXPECTED_KINDS" ${hxx_files[@]+"${hxx_files[@]}"} "----" \
    "${fixtures[@]}" "----" "${expected_validity[@]}" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

schema_path = Path(sys.argv[1])
mode = sys.argv[2]
expected_kinds = sys.argv[3].split()

# Split: hxx_files ---- fixture_paths ---- expected_validity.
rest = sys.argv[4:]
sep1 = rest.index("----")
hxx_files = [Path(p) for p in rest[:sep1]]
rest = rest[sep1 + 1:]
sep2 = rest.index("----")
fixture_paths = [Path(p) for p in rest[:sep2]]
expected_validity = rest[sep2 + 1:]

if len(fixture_paths) != len(expected_validity):
    print("FAIL: fixture count != expected_validity count", file=sys.stderr)
    sys.exit(1)

# 1. Schema kind enum + structural locks.
schema = json.loads(schema_path.read_text(encoding="utf-8"))

if schema.get("additionalProperties") is not False:
    print("FAIL: schema must set additionalProperties:false at top level",
          file=sys.stderr)
    sys.exit(1)

sv_const = schema.get("properties", {}).get("schema_version", {}).get("const")
if sv_const != "v2-w3-runtime-1":
    print(f"FAIL: schema_version const must be 'v2-w3-runtime-1'; got {sv_const!r}",
          file=sys.stderr)
    sys.exit(1)

patches_node = schema.get("properties", {}).get("patches", {})
items_node = patches_node.get("items", {})
kind_node = items_node.get("properties", {}).get("kind", {})
schema_kinds = kind_node.get("enum")
if not isinstance(schema_kinds, list):
    print("FAIL: schema.patches.items.properties.kind.enum missing", file=sys.stderr)
    sys.exit(1)

if schema_kinds != expected_kinds:
    print("FAIL: schema kind enum order != W3 spec §'Patch Kinds（v1）'",
          file=sys.stderr)
    print(f"  expected: {expected_kinds}", file=sys.stderr)
    print(f"  schema:   {schema_kinds}", file=sys.stderr)
    sys.exit(1)

# 2. C++ kind tokens — only in full-enforce mode.
cpp_kinds_unique: list[str] = []

if mode == "full-enforce":
    seen: set[str] = set()
    pat = "|".join(re.escape(t) for t in expected_kinds)
    for hxx in hxx_files:
        text = hxx.read_text(encoding="utf-8", errors="ignore")
        for tok in re.findall(rf'"({pat})"', text):
            if tok not in seen:
                seen.add(tok)
                cpp_kinds_unique.append(tok)

    if set(cpp_kinds_unique) != set(expected_kinds):
        print("FAIL: SwUndoApplyPatch* tokens drift from W3 spec §'Patch Kinds（v1）'",
              file=sys.stderr)
        print(f"  expected: {sorted(expected_kinds)}", file=sys.stderr)
        print(f"  C++:      {sorted(cpp_kinds_unique)}", file=sys.stderr)
        sys.exit(1)

# 3. Fixtures: validity assertion. Detailed reasons for invalids.
TOP_REQUIRED = {"schema_version", "plan_id", "source_diagnostic_id",
                "doc_snapshot_hash", "patches", "preview_only"}
PLAN_ID_RE = re.compile(r"^ap-[a-z0-9-]{3,80}$")
DIAG_ID_RE = re.compile(r"^diag-[a-z0-9-]{3,80}$")
HASH_RE = re.compile(r"^sha256:[a-f0-9]{64}$")
PATCH_ID_RE = re.compile(r"^p[0-9]+$")
PARA_ID_RE = re.compile(r"^swpara-[0-9]+$")
SCHEMA_VERSION_CONST = "v2-w3-runtime-1"
SEVERITIES = {"minor", "normal", "major"}


def fixture_errors(obj: dict) -> list[str]:
    errs: list[str] = []
    if not isinstance(obj, dict):
        return ["top-level not object"]
    missing = TOP_REQUIRED - set(obj.keys())
    if missing:
        errs.append(f"missing: {sorted(missing)}")
    if obj.get("schema_version") != SCHEMA_VERSION_CONST:
        errs.append("schema_version const")
    pid = obj.get("plan_id", "")
    if not isinstance(pid, str) or not PLAN_ID_RE.match(pid):
        errs.append("plan_id pattern")
    did = obj.get("source_diagnostic_id", "")
    if not isinstance(did, str) or not DIAG_ID_RE.match(did):
        errs.append("source_diagnostic_id pattern")
    h = obj.get("doc_snapshot_hash", "")
    if not isinstance(h, str) or not HASH_RE.match(h):
        errs.append("doc_snapshot_hash pattern")
    if not isinstance(obj.get("preview_only"), bool):
        errs.append("preview_only not bool")
    patches = obj.get("patches")
    if not isinstance(patches, list) or not patches:
        errs.append("patches not non-empty list")
    else:
        kinds_set = set(expected_kinds)
        for i, p in enumerate(patches):
            if not isinstance(p, dict):
                errs.append(f"patches[{i}] not object")
                continue
            patch_id = p.get("patch_id", "")
            if not isinstance(patch_id, str) or not PATCH_ID_RE.match(patch_id):
                errs.append(f"patches[{i}].patch_id pattern")
            if p.get("kind") not in kinds_set:
                errs.append(f"patches[{i}].kind enum")
            target = p.get("target", {})
            if not isinstance(target, dict):
                errs.append(f"patches[{i}].target not object")
            else:
                pid_str = target.get("paragraph_id", "")
                if not isinstance(pid_str, str) or not PARA_ID_RE.match(pid_str):
                    errs.append(f"patches[{i}].target.paragraph_id pattern")
            sev = p.get("severity")
            if sev is not None and sev not in SEVERITIES:
                errs.append(f"patches[{i}].severity enum")
    return errs


fixture_status: list[tuple[str, str, str, list[str]]] = []
for path, expected in zip(fixture_paths, expected_validity):
    obj = json.loads(path.read_text(encoding="utf-8"))
    errs = fixture_errors(obj)
    observed = "valid" if not errs else "invalid"
    fixture_status.append((str(path), expected, observed, errs))
    if observed != expected:
        print(f"FAIL: {path} expected {expected}, observed {observed}",
              file=sys.stderr)
        for e in errs:
            print(f"  - {e}", file=sys.stderr)
        sys.exit(1)

status_label = "passed" if mode == "full-enforce" else "passed (partial)"
print(f"Status: {status_label}")
print(f"Mode: {mode}")
print(f"Schema: {schema_path}")
print(f"  schema_version const:  {sv_const}")
print(f"  kind enum:             {len(schema_kinds)} tokens, order matches table")
if mode == "full-enforce":
    print(f"C++ headers scanned: {len(hxx_files)}")
    print(f"  unique kind tokens: {cpp_kinds_unique}")
else:
    print(f"C++ SwUndoApplyPatch*.hxx: not yet landed (skipped); will auto-promote on arrival")
print(f"Fixtures checked: {len(fixture_status)}")
for path, expected, observed, errs in fixture_status:
    rel = Path(path).name
    if errs:
        print(f"  {rel}: expected={expected} observed={observed} reasons={errs}")
    else:
        print(f"  {rel}: expected={expected} observed={observed}")
PY
