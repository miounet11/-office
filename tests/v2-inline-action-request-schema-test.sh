#!/usr/bin/env bash
# V2 W4 Day-0 — inline-action-request schema ↔ C++ Action enum lock harness.
#
# This is the W4 sibling of tests/v2-async-task-schema-test.sh.
# Until W4 Day-0 lands the actual *.hxx headers, this harness runs in
# *partial-enforce* mode: it locks the schema enum order against the
# spec §"Action enum lock" tables and walks the fixture roster, but
# skips C++ string-literal extraction. Once W4 Day-0 is authorized
# and the per-surface enum headers land, the harness auto-promotes
# itself to full enforcement (schema + C++ enums must agree).
#
# Locks (when schema + C++ headers exist):
#
#   1. docs/schemas/inline-action-request.schema.json — three oneOf
#      branches (writer-paragraph / calc-cell / impress-slide-element)
#      each carry an action enum locked to the spec §"Action enum lock"
#      table order.
#   2. C++ ParagraphAction string literals in
#      ${KDOFFICE_SRC_ROOT}/sw/source/uibase/inline-actions/ParagraphActions.cxx
#      (.hxx existence triggers full-enforce; .cxx is the literal source-of-truth.)
#   3. C++ CellAction string literals in
#      ${KDOFFICE_SRC_ROOT}/sc/source/ui/inline-actions/CellActions.cxx
#   4. C++ SlideElementAction string literals in
#      ${KDOFFICE_SRC_ROOT}/sd/source/ui/inline-actions/SlideElementActions.cxx
#   5. Fixtures docs/schemas/fixtures/inline-action-request.*.json
#      enforce expected validity via canonical fixture validator.
#
# Source-of-truth strings (W4 spec §"Action enum lock", L37):
#
#   ParagraphAction     : rewrite | expand | shorten | translate-en | format-clean | explain | custom
#   CellAction          : explain-data | suggest-chart | generate-formula | format-clean | format-change
#   SlideElementAction  : rewrite-text | adjust-color | relayout | translate-text
#
# Verification:
#   bash tests/v2-inline-action-request-schema-test.sh
# Expected exit 0 with "Status: skipped" if schema missing, "Status:
# passed (partial)" until W4 Day-0 lands the *.hxx headers, "Status:
# passed" thereafter.
#
# Owner: V2 W4 (select-to-act). Scoped to docs/schemas/ +
# sw/source/uibase/inline-actions/ +
# sc/source/ui/inline-actions/ + sd/source/ui/inline-actions/
# once authorized.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

src_root="${KDOFFICE_SRC_ROOT:-/Users/lu/kdoffice-src}"

schema="docs/schemas/inline-action-request.schema.json"
fixtures=(
    "docs/schemas/fixtures/inline-action-request.valid.json"
    "docs/schemas/fixtures/inline-action-request.invalid.json"
    "docs/schemas/fixtures/inline-action-request.calc-suggest-chart.json"
    "docs/schemas/fixtures/inline-action-request.impress-translate.json"
)
expected_validity=("valid" "invalid" "valid" "valid")

paragraph_actions_hxx="$src_root/sw/source/uibase/inline-actions/ParagraphActions.hxx"
cell_actions_hxx="$src_root/sc/source/ui/inline-actions/CellActions.hxx"
slide_actions_hxx="$src_root/sd/source/ui/inline-actions/SlideElementActions.hxx"

# String literals live in the matching .cxx (enum-to-token helpers); .hxx is
# enum-only. Full-enforce mode reads literals from .cxx — matches the H7
# pattern of grepping literal strings rather than enum declarations.
paragraph_actions_cxx="$src_root/sw/source/uibase/inline-actions/ParagraphActions.cxx"
cell_actions_cxx="$src_root/sc/source/ui/inline-actions/CellActions.cxx"
slide_actions_cxx="$src_root/sd/source/ui/inline-actions/SlideElementActions.cxx"

EXPECTED_PARAGRAPH="rewrite expand shorten translate-en format-clean explain custom"
EXPECTED_CELL="explain-data suggest-chart generate-formula format-clean format-change"
EXPECTED_SLIDE="rewrite-text adjust-color relayout translate-text"

skip() {
    printf 'Status: skipped\n'
    printf 'Reason: %s\n' "$1"
    printf 'Source-of-truth tokens (W4 spec §%s, L37):\n' '"Action enum lock"'
    printf '  ParagraphAction    (7): %s\n' "$EXPECTED_PARAGRAPH"
    printf '  CellAction         (5): %s\n' "$EXPECTED_CELL"
    printf '  SlideElementAction (4): %s\n' "$EXPECTED_SLIDE"
    printf 'Auto-promotes to full enforcement once schema + the 3 *.hxx land.\n'
    exit 0
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

# --- Mode selection ----------------------------------------------------------
schema_present=true
fixtures_present=true
hxx_count=0

[[ -e "$schema" ]] || schema_present=false
for f in "${fixtures[@]}"; do
    [[ -e "$f" ]] || fixtures_present=false
done
[[ -e "$paragraph_actions_hxx" ]] && hxx_count=$((hxx_count + 1))
[[ -e "$cell_actions_hxx" ]] && hxx_count=$((hxx_count + 1))
[[ -e "$slide_actions_hxx" ]] && hxx_count=$((hxx_count + 1))

if ! $schema_present || ! $fixtures_present; then
    missing=()
    $schema_present || missing+=("$schema")
    for f in "${fixtures[@]}"; do
        [[ -e "$f" ]] || missing+=("$f")
    done
    skip "W4 Day-0 schema/fixtures not yet landed; missing: ${missing[*]}"
fi

mode="partial-enforce"
if (( hxx_count == 3 )); then
    mode="full-enforce"
fi

python3 - "$schema" "$mode" \
    "$paragraph_actions_cxx" "$cell_actions_cxx" "$slide_actions_cxx" \
    "$EXPECTED_PARAGRAPH" "$EXPECTED_CELL" "$EXPECTED_SLIDE" \
    "${fixtures[@]}" "----" "${expected_validity[@]}" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

schema_path = Path(sys.argv[1])
mode = sys.argv[2]
paragraph_cxx = Path(sys.argv[3])
cell_cxx = Path(sys.argv[4])
slide_cxx = Path(sys.argv[5])
expected_paragraph = sys.argv[6].split()
expected_cell = sys.argv[7].split()
expected_slide = sys.argv[8].split()

# Split fixtures from expected_validity at "----" sentinel.
rest = sys.argv[9:]
sep = rest.index("----")
fixture_paths = [Path(p) for p in rest[:sep]]
expected_validity = rest[sep + 1:]

if len(fixture_paths) != len(expected_validity):
    print("FAIL: fixture count != expected_validity count", file=sys.stderr)
    sys.exit(1)

# 1. Schema oneOf branch enums + structural locks.
schema = json.loads(schema_path.read_text(encoding="utf-8"))

if schema.get("additionalProperties") is not False:
    print("FAIL: schema must set additionalProperties:false at top level",
          file=sys.stderr)
    sys.exit(1)

one_of = schema.get("oneOf")
if not isinstance(one_of, list) or len(one_of) != 3:
    print("FAIL: schema.oneOf must have exactly 3 branches "
          "(writer-paragraph / calc-cell / impress-slide-element)",
          file=sys.stderr)
    sys.exit(1)


def find_branch(surface_const: str) -> dict:
    for branch in one_of:
        props = branch.get("properties", {})
        s = props.get("surface", {})
        if s.get("const") == surface_const:
            return branch
    print(f"FAIL: schema.oneOf missing branch for surface={surface_const}",
          file=sys.stderr)
    sys.exit(1)


def branch_action_enum(branch: dict) -> list[str]:
    action_node = branch.get("properties", {}).get("action", {})
    enum_vals = action_node.get("enum")
    if not isinstance(enum_vals, list):
        print("FAIL: oneOf branch missing properties.action.enum",
              file=sys.stderr)
        sys.exit(1)
    return list(enum_vals)


writer_branch = find_branch("writer-paragraph")
calc_branch = find_branch("calc-cell")
slide_branch = find_branch("impress-slide-element")

writer_actions = branch_action_enum(writer_branch)
calc_actions = branch_action_enum(calc_branch)
slide_actions = branch_action_enum(slide_branch)


def lock_order(label: str, expected: list[str], actual: list[str]) -> None:
    if actual != expected:
        print(f"FAIL: schema {label} enum order != W4 spec §'Action enum lock'",
              file=sys.stderr)
        print(f"  expected: {expected}", file=sys.stderr)
        print(f"  schema:   {actual}", file=sys.stderr)
        sys.exit(1)


lock_order("writer-paragraph.action", expected_paragraph, writer_actions)
lock_order("calc-cell.action", expected_cell, calc_actions)
lock_order("impress-slide-element.action", expected_slide, slide_actions)

# 2. C++ enum tokens — only in full-enforce mode.
cpp_paragraph_unique: list[str] = []
cpp_cell_unique: list[str] = []
cpp_slide_unique: list[str] = []

if mode == "full-enforce":
    def stable_unique(seq: list[str]) -> list[str]:
        seen: set[str] = set()
        out: list[str] = []
        for item in seq:
            if item not in seen:
                seen.add(item)
                out.append(item)
        return out

    def extract(cxx: Path, expected: list[str], label: str) -> list[str]:
        text = cxx.read_text(encoding="utf-8", errors="ignore")
        # Build alternation pattern from expected tokens, escaped.
        # Match u"token"_ustr or "token" — .cxx carries the literal mapping
        # tables (enum<->string helpers); .hxx is enum-only.
        pat = "|".join(re.escape(t) for t in expected)
        found = re.findall(rf'u?"({pat})"', text)
        unique = stable_unique(found)
        if set(unique) != set(expected):
            print(f"FAIL: {label} tokens drift from W4 spec §'Action enum lock'",
                  file=sys.stderr)
            print(f"  expected: {sorted(expected)}", file=sys.stderr)
            print(f"  C++:      {sorted(unique)}", file=sys.stderr)
            sys.exit(1)
        if unique != expected:
            print(f"FAIL: {label} order != spec table order", file=sys.stderr)
            print(f"  expected: {expected}", file=sys.stderr)
            print(f"  C++:      {unique}", file=sys.stderr)
            sys.exit(1)
        return unique

    cpp_paragraph_unique = extract(paragraph_cxx, expected_paragraph,
                                    "ParagraphActions.cxx")
    cpp_cell_unique = extract(cell_cxx, expected_cell, "CellActions.cxx")
    cpp_slide_unique = extract(slide_cxx, expected_slide,
                                "SlideElementActions.cxx")

# 3. Fixtures: validity assertion. Detailed reasons for invalids.
TOP_REQUIRED = {"schema_version", "request_id", "surface", "action",
                "target", "service_mode", "created_at"}
REQUEST_ID_RE = re.compile(r"^iar-[0-9a-f]{16}$")
SURFACE_VALUES = {"writer-paragraph", "calc-cell", "impress-slide-element"}
SCHEMA_VERSION_CONST = "v2-w4-1"

surface_actions = {
    "writer-paragraph": set(expected_paragraph),
    "calc-cell": set(expected_cell),
    "impress-slide-element": set(expected_slide),
}


def fixture_errors(obj: dict) -> list[str]:
    errs: list[str] = []
    if not isinstance(obj, dict):
        return ["top-level not object"]
    missing = TOP_REQUIRED - set(obj.keys())
    if missing:
        errs.append(f"missing: {sorted(missing)}")
    extras = set(obj.keys()) - {*TOP_REQUIRED, "user_prompt", "expected_capability"}
    if extras:
        errs.append(f"extras: {sorted(extras)}")
    if obj.get("schema_version") != SCHEMA_VERSION_CONST:
        errs.append("schema_version const")
    rid = obj.get("request_id", "")
    if not isinstance(rid, str) or not REQUEST_ID_RE.match(rid):
        errs.append("request_id pattern")
    surface = obj.get("surface")
    if surface not in SURFACE_VALUES:
        errs.append("surface enum")
    elif obj.get("action") not in surface_actions[surface]:
        errs.append("action not in surface enum")
    if obj.get("service_mode") not in {"offline", "private", "cloud"}:
        errs.append("service_mode enum")
    ts = obj.get("created_at", "")
    if not re.match(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",
                    str(ts)):
        errs.append("created_at pattern")
    target = obj.get("target")
    if not isinstance(target, dict):
        errs.append("target not object")
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
print(f"  oneOf branches:    3 (locked)")
print(f"  ParagraphAction enum:    {len(writer_actions)} tokens, order matches table")
print(f"  CellAction enum:         {len(calc_actions)} tokens, order matches table")
print(f"  SlideElementAction enum: {len(slide_actions)} tokens, order matches table")
if mode == "full-enforce":
    print(f"C++ ParagraphActions.cxx:    {cpp_paragraph_unique}")
    print(f"C++ CellActions.cxx:         {cpp_cell_unique}")
    print(f"C++ SlideElementActions.cxx: {cpp_slide_unique}")
else:
    print(f"C++ headers: not yet landed (skipped); will auto-promote on arrival")
print(f"Fixtures checked: {len(fixture_status)}")
for path, expected, observed, errs in fixture_status:
    rel = Path(path).name
    if errs:
        print(f"  {rel}: expected={expected} observed={observed} reasons={errs}")
    else:
        print(f"  {rel}: expected={expected} observed={observed}")
PY
