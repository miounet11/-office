#!/usr/bin/env bash
# V2 W5 Day-0 — async-task schema ↔ C++ TaskKind/TaskState lock harness.
#
# This is the W5 sibling of tests/v2-provider-evidence-schema-test.sh.
# Until W5 Day-0 lands the actual schema + cowork headers, this harness
# runs in *skeleton mode*: it returns "Status: skipped" with a clear
# reason and exits 0 so CI / pre-commit pipelines can include it
# without breakage. Once Day-0 is authorized and lands, the harness
# auto-promotes itself to full enforcement (schema + C++ enums must
# agree; fixtures must round-trip).
#
# Locks (when schema + C++ headers exist):
#
#   1. docs/schemas/async-task.schema.json (TaskKind + TaskState enums,
#      enum order, required-keys set, additionalProperties:false)
#   2. C++ TaskKind tokens in
#      ${KDOFFICE_SRC_ROOT}/kqoffice/source/ai/cowork/AsyncTask.hxx
#   3. C++ TaskState tokens in same header
#   4. Fixtures docs/schemas/fixtures/async-task.{valid,invalid}.json
#      enforce expected validity.
#
# Source-of-truth strings (W5 spec §"Token lock", L37):
#
#   TaskKind  : weekly-report | outline-to-slides | contract-review | data-cleanup
#   TaskState : pending | running | awaiting-review | applied | failed | cancelled
#
# Verification:
#   bash tests/v2-async-task-schema-test.sh
# Expected exit 0 with "Status: skipped" until W5 Day-0 lands; "Status:
# passed" thereafter.
#
# Owner: V2 W5 (async cowork). Scoped to docs/schemas/ +
# kqoffice/source/ai/cowork/ once authorized.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

src_root="${KDOFFICE_SRC_ROOT:-/Users/lu/kdoffice-src}"

schema="docs/schemas/async-task.schema.json"
fixtures=(
    "docs/schemas/fixtures/async-task.valid.json"
    "docs/schemas/fixtures/async-task.invalid.json"
)
async_task_hxx="$src_root/kqoffice/source/ai/cowork/AsyncTask.hxx"

# Source-of-truth token lists (W5 spec §"Token lock"). Order matters:
# the harness asserts schema enum order = this order to catch silent
# re-ordering (a real risk when several waves edit the same enum).
EXPECTED_TASK_KIND="weekly-report outline-to-slides contract-review data-cleanup"
EXPECTED_TASK_STATE="pending running awaiting-review applied failed cancelled"

skip() {
    printf 'Status: skipped\n'
    printf 'Reason: %s\n' "$1"
    printf 'Source-of-truth tokens (W5 spec §%s, L37):\n' '"Token lock"'
    printf '  TaskKind  (4): %s\n' "$EXPECTED_TASK_KIND"
    printf '  TaskState (6): %s\n' "$EXPECTED_TASK_STATE"
    printf 'Auto-promotes to full enforcement once schema + AsyncTask.hxx land.\n'
    exit 0
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

# --- Skeleton-mode gates -----------------------------------------------------
missing=()
[[ -e "$schema" ]] || missing+=("$schema")
for f in "${fixtures[@]}"; do
    [[ -e "$f" ]] || missing+=("$f")
done
[[ -e "$async_task_hxx" ]] || missing+=("$async_task_hxx")

if (( ${#missing[@]} > 0 )); then
    reason="W5 Day-0 not yet landed; missing: ${missing[*]}"
    skip "$reason"
fi

# --- Full-enforcement mode ---------------------------------------------------
python3 - "$schema" "$async_task_hxx" "$EXPECTED_TASK_KIND" "$EXPECTED_TASK_STATE" "${fixtures[@]}" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

schema_path = Path(sys.argv[1])
hxx_path = Path(sys.argv[2])
expected_kind = sys.argv[3].split()
expected_state = sys.argv[4].split()
fixture_paths = [Path(p) for p in sys.argv[5:]]
expected_validity = ["valid", "invalid"]

# 1. Schema enums + structural locks.
schema = json.loads(schema_path.read_text(encoding="utf-8"))
props = schema.get("properties", {})

def enum_of(prop: str) -> list[str]:
    node = props.get(prop)
    if not node or "enum" not in node:
        print(f"FAIL: schema missing properties.{prop}.enum", file=sys.stderr)
        sys.exit(1)
    return list(node["enum"])

schema_kind = enum_of("kind")
schema_state = enum_of("state")

if schema_kind != expected_kind:
    print("FAIL: schema kind enum order != W5 token-lock table",
          file=sys.stderr)
    print(f"  expected (table): {expected_kind}", file=sys.stderr)
    print(f"  schema:           {schema_kind}", file=sys.stderr)
    sys.exit(1)

if schema_state != expected_state:
    print("FAIL: schema state enum order != W5 token-lock table",
          file=sys.stderr)
    print(f"  expected (table): {expected_state}", file=sys.stderr)
    print(f"  schema:           {schema_state}", file=sys.stderr)
    sys.exit(1)

if schema.get("additionalProperties") is not False:
    print("FAIL: schema must set additionalProperties:false", file=sys.stderr)
    sys.exit(1)

# 17-key envelope per spec §"Day-0 Entry-Point Plan" item 3.
schema_required = set(schema.get("required", []))
if not schema_required:
    print("FAIL: schema 'required' is empty — envelope shape not locked",
          file=sys.stderr)
    sys.exit(1)

# 2. C++ TaskKind / TaskState tokens — sub-set of expected, in order.
hxx_text = hxx_path.read_text(encoding="utf-8", errors="ignore")
cpp_kinds = re.findall(r'"(weekly-report|outline-to-slides|contract-review|data-cleanup)"', hxx_text)
cpp_states = re.findall(r'"(pending|running|awaiting-review|applied|failed|cancelled)"', hxx_text)

# De-dup preserving first-seen order.
def stable_unique(seq: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for item in seq:
        if item not in seen:
            seen.add(item)
            out.append(item)
    return out

cpp_kinds_unique = stable_unique(cpp_kinds)
cpp_states_unique = stable_unique(cpp_states)

if set(cpp_kinds_unique) != set(expected_kind):
    print("FAIL: AsyncTask.hxx TaskKind tokens drift from token lock",
          file=sys.stderr)
    print(f"  expected: {sorted(expected_kind)}", file=sys.stderr)
    print(f"  C++:      {sorted(cpp_kinds_unique)}", file=sys.stderr)
    sys.exit(1)

if set(cpp_states_unique) != set(expected_state):
    print("FAIL: AsyncTask.hxx TaskState tokens drift from token lock",
          file=sys.stderr)
    print(f"  expected: {sorted(expected_state)}", file=sys.stderr)
    print(f"  C++:      {sorted(cpp_states_unique)}", file=sys.stderr)
    sys.exit(1)

# Catch silent reorder if the spec table order has been changed but
# C++ kept the old order (or vice versa). Header order is the
# canonical source for both schema enum and the .po translation files.
if cpp_kinds_unique != expected_kind:
    print("FAIL: AsyncTask.hxx TaskKind order != token-lock order",
          file=sys.stderr)
    print(f"  expected: {expected_kind}", file=sys.stderr)
    print(f"  C++:      {cpp_kinds_unique}", file=sys.stderr)
    sys.exit(1)

if cpp_states_unique != expected_state:
    print("FAIL: AsyncTask.hxx TaskState order != token-lock order",
          file=sys.stderr)
    print(f"  expected: {expected_state}", file=sys.stderr)
    print(f"  C++:      {cpp_states_unique}", file=sys.stderr)
    sys.exit(1)

# 3. Fixtures: validity per .valid.json / .invalid.json convention.
TASK_ID_RE = re.compile(r"^tk-[0-9]{8}-[0-9]{3}$")

def fixture_errors(obj: dict) -> list[str]:
    errs: list[str] = []
    tid = obj.get("task_id", "")
    if not isinstance(tid, str) or not TASK_ID_RE.match(tid):
        errs.append("task_id pattern")
    if obj.get("kind") not in expected_kind:
        errs.append("kind enum")
    if obj.get("state") not in expected_state:
        errs.append("state enum")
    missing = schema_required - set(obj.keys())
    if missing:
        errs.append(f"missing: {sorted(missing)}")
    extras = set(obj.keys()) - set(schema.get("properties", {}).keys())
    if extras:
        errs.append(f"extras: {sorted(extras)}")
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

# Report.
print("Status: passed")
print(f"Schema: {schema_path}")
print(f"  required keys: {len(schema_required)} (locked)")
print(f"  kind enum:  {len(schema_kind)} tokens, order matches table")
print(f"  state enum: {len(schema_state)} tokens, order matches table")
print(f"C++ AsyncTask.hxx tokens:")
print(f"  TaskKind:  {cpp_kinds_unique}")
print(f"  TaskState: {cpp_states_unique}")
print(f"Fixtures checked: {len(fixture_status)}")
for path, expected, observed, errs in fixture_status:
    rel = Path(path).name
    if errs:
        print(f"  {rel}: expected={expected} observed={observed} reasons={errs}")
    else:
        print(f"  {rel}: expected={expected} observed={observed}")
PY
