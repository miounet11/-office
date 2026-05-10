#!/usr/bin/env bash
# V2 W3 Day-1h — provider-evidence schema ↔ C++ emissions lock harness.
#
# Locks the on-disk JSON envelope written by
# kqoffice::ai::EvidenceRecorder against three independent sources of
# truth:
#
#   1. docs/schemas/provider-evidence.schema.json (status enum)
#   2. C++ apply-plan-* literal emissions in
#      kqoffice/source/ai/provider/ApplyPlanValidator.hxx
#      (ApplyPlanValidationCode → kebab-case via applyPlanValidationStatus)
#   3. C++ provider-runtime literal emissions in
#      kqoffice/source/ai/provider/Provider.cxx
#
# The schema is the single human-readable contract; this harness makes
# sure the contract still matches what real C++ code actually writes
# to ~/Library/Application Support/.../ai_provider_evidence/*.json.
#
# Verification:
#   bash tests/v2-provider-evidence-schema-test.sh
# Expected exit 0 with "Status: passed" on stdout.
#
# Owner: V2 W3 (provider runtime). Scoped to docs/schemas/ +
# kqoffice/source/ai/provider/. Does not touch V1.5
# evidence-record.schema.json.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# Source tree — kqoffice C++ provider runtime lives in the source
# checkout, not the build tree. autogen.lastrun records the path; we
# fall back to /Users/lu/kdoffice-src for the macOS premium build.
src_root="${KDOFFICE_SRC_ROOT:-/Users/lu/kdoffice-src}"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

if [[ ! -d "$src_root/kqoffice/source/ai/provider" ]]; then
    fail "kqoffice provider source not found at $src_root/kqoffice/source/ai/provider — set KDOFFICE_SRC_ROOT"
fi

schema="docs/schemas/provider-evidence.schema.json"
fixtures=(
    "docs/schemas/fixtures/provider-evidence.valid.json"
    "docs/schemas/fixtures/provider-evidence.apply-plan-failure.json"
    "docs/schemas/fixtures/provider-evidence.invalid.json"
)
expected_validity=("valid" "valid" "invalid")

for f in "$schema" "${fixtures[@]}"; do
    [[ -e "$f" ]] || fail "missing $f"
done

python3 - "$src_root" "$schema" "${fixtures[@]}" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

src_root = Path(sys.argv[1])
schema_path = Path(sys.argv[2])
fixture_paths = [Path(p) for p in sys.argv[3:]]
expected_validity = ["valid", "valid", "invalid"]

# ---------------------------------------------------------------------------
# 1. Schema → enum tokens.
# ---------------------------------------------------------------------------
schema = json.loads(schema_path.read_text(encoding="utf-8"))
status_enum = schema["properties"]["status"]["enum"]
schema_apply = sorted(t for t in status_enum if t.startswith("apply-plan-"))
schema_runtime = sorted(t for t in status_enum if not t.startswith("apply-plan-"))

# Required fields locked by EvidenceRecorder.cxx envelope.
required_keys = {
    "evidence_id", "timestamp", "service_mode", "provider", "capability",
    "status", "request_size_bytes", "response_size_bytes", "duration_ms",
}
schema_required = set(schema.get("required", []))
if schema_required != required_keys:
    print(f"FAIL: schema required keys mismatch", file=sys.stderr)
    print(f"  expected: {sorted(required_keys)}", file=sys.stderr)
    print(f"  got:      {sorted(schema_required)}", file=sys.stderr)
    sys.exit(1)

if schema.get("additionalProperties") is not False:
    print("FAIL: schema must set additionalProperties:false", file=sys.stderr)
    sys.exit(1)

# ---------------------------------------------------------------------------
# 2. C++ apply-plan-* emissions → tokens.
# Defensive fallback "apply-plan-unknown" is unreachable from a real
# ApplyPlanValidationCode value; it exists only so the switch has a
# default branch, and is deliberately excluded from the schema enum.
# ---------------------------------------------------------------------------
DEFENSIVE_TOKEN = "apply-plan-unknown"

provider_dir = src_root / "kqoffice" / "source" / "ai" / "provider"
cpp_apply_tokens: set[str] = set()
for path in list(provider_dir.rglob("*.cxx")) + list(provider_dir.rglob("*.hxx")):
    text = path.read_text(encoding="utf-8", errors="ignore")
    cpp_apply_tokens |= set(re.findall(r'"(apply-plan-[a-z-]+)"', text))

real_apply = sorted(cpp_apply_tokens - {DEFENSIVE_TOKEN})

if DEFENSIVE_TOKEN not in cpp_apply_tokens:
    print(f"FAIL: defensive {DEFENSIVE_TOKEN!r} no longer present in C++ — "
          f"either remove this assertion or restore the switch default.",
          file=sys.stderr)
    sys.exit(1)

if DEFENSIVE_TOKEN in schema_apply:
    print(f"FAIL: schema enum must not include defensive token "
          f"{DEFENSIVE_TOKEN!r}; it is unreachable from real "
          f"ApplyPlanValidationCode values.",
          file=sys.stderr)
    sys.exit(1)

if real_apply != schema_apply:
    only_cpp = sorted(set(real_apply) - set(schema_apply))
    only_schema = sorted(set(schema_apply) - set(real_apply))
    print("FAIL: schema apply-plan tokens drifted from C++ emissions",
          file=sys.stderr)
    if only_cpp:
        print(f"  emitted by C++ but missing from schema: {only_cpp}",
              file=sys.stderr)
    if only_schema:
        print(f"  in schema but no C++ emission: {only_schema}",
              file=sys.stderr)
    sys.exit(1)

# ---------------------------------------------------------------------------
# 3. C++ provider-runtime emissions → tokens.
# Provider.cxx currently emits {ok, provider-error, policy-denied}.
# `timeout` is contractually reserved in EvidenceRecorder.hxx field
# comment but not yet wired by any backend. Schema correctly carries
# all four so future timeout paths land without a schema bump; treat
# this as a "schema ⊇ emitted, schema ⊆ contracted" check.
# ---------------------------------------------------------------------------
PROVIDER_CPP = provider_dir / "Provider.cxx"
provider_text = PROVIDER_CPP.read_text(encoding="utf-8")
runtime_emitted: set[str] = set()
for tok in ("ok", "provider-error", "policy-denied", "timeout"):
    if re.search(rf'rsp\.status\s*=\s*"{re.escape(tok)}"', provider_text):
        runtime_emitted.add(tok)

CONTRACTED_RUNTIME = {"ok", "provider-error", "policy-denied", "timeout"}
schema_runtime_set = set(schema_runtime)

if schema_runtime_set != CONTRACTED_RUNTIME:
    print(f"FAIL: schema runtime tokens != contracted set",
          file=sys.stderr)
    print(f"  schema:     {sorted(schema_runtime_set)}", file=sys.stderr)
    print(f"  contracted: {sorted(CONTRACTED_RUNTIME)}", file=sys.stderr)
    sys.exit(1)

if not runtime_emitted.issubset(schema_runtime_set):
    rogue = sorted(runtime_emitted - schema_runtime_set)
    print(f"FAIL: Provider.cxx emits runtime tokens not in schema enum: {rogue}",
          file=sys.stderr)
    sys.exit(1)

# ---------------------------------------------------------------------------
# 4. Fixtures: enforce expected validity (re-implements the schema
# subset our fixtures actually exercise; full JSON Schema 2020-12
# validation is left to bin/intelligent-contract-fixtures.sh for the
# canonical .valid.json / .invalid.json pair).
# ---------------------------------------------------------------------------
EVIDENCE_ID_RE = re.compile(r"^ev-[0-9a-f]{16}$")
TIMESTAMP_RE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$")
SERVICE_MODES = {"offline", "private", "cloud"}

def fixture_errors(obj: dict) -> list[str]:
    errs: list[str] = []
    eid = obj.get("evidence_id", "")
    if not isinstance(eid, str) or not EVIDENCE_ID_RE.match(eid):
        errs.append("evidence_id pattern")
    ts = obj.get("timestamp", "")
    if not isinstance(ts, str) or not TIMESTAMP_RE.match(ts):
        errs.append("timestamp pattern")
    if obj.get("service_mode") not in SERVICE_MODES:
        errs.append("service_mode enum")
    if obj.get("status") not in status_enum:
        errs.append("status enum")
    for k in ("request_size_bytes", "response_size_bytes", "duration_ms"):
        v = obj.get(k)
        if not isinstance(v, int) or isinstance(v, bool) or v < 0:
            errs.append(f"{k} non-negative int")
    missing = required_keys - set(obj.keys())
    if missing:
        errs.append(f"missing: {sorted(missing)}")
    extras = set(obj.keys()) - required_keys
    if extras:
        errs.append(f"extras: {sorted(extras)}")
    return errs

fixture_status: list[tuple[str, str, str, list[str]]] = []
for path, expected in zip(fixture_paths, expected_validity):
    obj = json.loads(path.read_text(encoding="utf-8"))
    errs = fixture_errors(obj)
    observed = "valid" if not errs else "invalid"
    ok = observed == expected
    fixture_status.append((str(path), expected, observed, errs))
    if not ok:
        print(f"FAIL: {path} expected {expected}, observed {observed}",
              file=sys.stderr)
        for e in errs:
            print(f"  - {e}", file=sys.stderr)
        sys.exit(1)

# ---------------------------------------------------------------------------
# Report.
# ---------------------------------------------------------------------------
print("Status: passed")
print(f"Schema: {schema_path}")
print(f"  required keys: {len(required_keys)} (locked)")
print(f"  status enum: {len(status_enum)} tokens "
      f"= {len(schema_runtime)} runtime + {len(schema_apply)} apply-plan")
print(f"C++ apply-plan emissions (ex-defensive): {len(real_apply)} tokens")
print(f"  match schema: yes")
print(f"C++ provider-runtime emissions: {sorted(runtime_emitted)}")
print(f"  schema contracted set:        {sorted(schema_runtime_set)}")
print(f"  reserved (in schema, not yet emitted): "
      f"{sorted(schema_runtime_set - runtime_emitted)}")
print(f"Fixtures checked: {len(fixture_status)}")
for path, expected, observed, errs in fixture_status:
    rel = Path(path).name
    if errs:
        print(f"  {rel}: expected={expected} observed={observed} "
              f"reasons={errs}")
    else:
        print(f"  {rel}: expected={expected} observed={observed}")
PY
