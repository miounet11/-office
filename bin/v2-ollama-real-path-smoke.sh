#!/usr/bin/env bash
# V2 W1/W3 - local real Ollama runtime JSON smoke.
#
# This is intentionally not part of H1-H10: it depends on a local Ollama daemon
# and a non-embedding model. When available, it proves the real model path can
# produce a W3 apply-plan-runtime envelope with all 7 patch kinds.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mkdir -p tmp

raw_response="${V2_OLLAMA_RAW_RESPONSE:-tmp/v2-ollama-real-path-response.json}"
plan_response="${V2_OLLAMA_PLAN_RESPONSE:-tmp/v2-ollama-real-path-plan.json}"
report="${V2_OLLAMA_REPORT:-tmp/v2-ollama-real-path-smoke.md}"
model="${V2_OLLAMA_MODEL:-}"
host="${V2_OLLAMA_HOST:-http://127.0.0.1:11434}"
timeout="${V2_OLLAMA_TIMEOUT:-90}"

write_skip() {
    local reason="$1"
    {
        echo "# V2 Ollama Real Path Smoke"
        echo
        echo "- Status: skipped"
        echo "- Reason: $reason"
    } >"$report"
    echo "Status: skipped"
    echo "Reason: $reason"
    echo "Report: $report"
}

if ! command -v curl >/dev/null 2>&1; then
    write_skip "curl not available"
    exit 0
fi

if ! curl -fsS --max-time 2 "$host/api/tags" > tmp/v2-ollama-tags.json 2>/dev/null; then
    write_skip "Ollama daemon is not reachable at $host"
    exit 0
fi

rc=0
selected_model="$(python3 - "$model" tmp/v2-ollama-tags.json <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

preferred = sys.argv[1]
data = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
models = data.get("models") or []

def is_embedding(item: dict) -> bool:
    name = str(item.get("name") or item.get("model") or "").lower()
    details = item.get("details") or {}
    family = str(details.get("family") or "").lower()
    families = " ".join(str(v).lower() for v in details.get("families") or [])
    return "embed" in name or "embed" in family or "embed" in families or "bert" in family

names = [str(m.get("name") or m.get("model") or "") for m in models]
if preferred:
    if preferred in names:
        print(preferred)
        raise SystemExit(0)
    raise SystemExit(2)

for item in models:
    name = str(item.get("name") or item.get("model") or "")
    if name and not is_embedding(item):
        print(name)
        raise SystemExit(0)
raise SystemExit(1)
PY
)" || rc=$?
if [[ "$rc" == "2" ]]; then
    write_skip "requested model '$model' is not installed"
    exit 0
fi
if [[ "$rc" != "0" || -z "${selected_model:-}" ]]; then
    write_skip "no non-embedding Ollama model is installed"
    exit 0
fi

prompt="$(python3 - <<'PY'
from __future__ import annotations

import json

template = {
    "schema_version": "v2-w3-runtime-1",
    "plan_id": "ap-ollama-real-path-001",
    "source_diagnostic_id": "diag-ollama-real-path-001",
    "doc_snapshot_hash": "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    "preview_only": False,
    "patches": [
        {
            "patch_id": "p1",
            "kind": "paragraph-replace",
            "target": {"paragraph_id": "swpara-1"},
            "severity": "minor",
            "rationale": "local real ollama smoke",
            "before": "old paragraph",
            "after": "new paragraph",
        },
        {
            "patch_id": "p2",
            "kind": "paragraph-insert-after",
            "target": {"paragraph_id": "swpara-1"},
            "severity": "minor",
            "rationale": "local real ollama smoke",
            "after": "inserted paragraph",
        },
        {
            "patch_id": "p3",
            "kind": "paragraph-delete",
            "target": {"paragraph_id": "swpara-1"},
            "severity": "minor",
            "rationale": "local real ollama smoke",
            "force": True,
        },
        {
            "patch_id": "p4",
            "kind": "paragraph-format",
            "target": {"paragraph_id": "swpara-1"},
            "severity": "minor",
            "rationale": "local real ollama smoke",
            "format_changes": {"style": "Heading 2"},
        },
        {
            "patch_id": "p5",
            "kind": "paragraph-reformat",
            "target": {"paragraph_id": "swpara-1"},
            "severity": "minor",
            "rationale": "local real ollama smoke",
            "format_changes": {"first_line_indent": 24, "line_spacing": 1.5},
        },
        {
            "patch_id": "p6",
            "kind": "text-range-replace",
            "target": {"paragraph_id": "swpara-1"},
            "severity": "minor",
            "rationale": "local real ollama smoke",
            "range": {"start": 0, "length": 3},
            "before": "old",
            "after": "new",
        },
        {
            "patch_id": "p7",
            "kind": "text-format",
            "target": {"paragraph_id": "swpara-1"},
            "severity": "minor",
            "rationale": "local real ollama smoke",
            "range": {"start": 0, "length": 3},
            "format_changes": {"bold": True},
        },
    ],
}

print(
    "Return exactly the JSON object below. No markdown. No explanation. "
    "Do not change field names, string values, booleans, arrays, or object nesting. "
    "The target field must stay an object, preview_only must stay boolean false, "
    "and every patch must keep its kind. JSON object:\\n"
    + json.dumps(template, ensure_ascii=False, separators=(",", ":"))
)
PY
)"

python3 - "$selected_model" "$prompt" > tmp/v2-ollama-real-path-request.json <<'PY'
from __future__ import annotations

import json
import sys

model, prompt = sys.argv[1], sys.argv[2]
print(json.dumps({
    "model": model,
    "prompt": prompt,
    "stream": False,
    "format": "json",
    "options": {
        "temperature": 0
    },
}, ensure_ascii=False))
PY

curl -fsS --max-time "$timeout" "$host/api/generate" \
    -H 'Content-Type: application/json' \
    --data-binary @tmp/v2-ollama-real-path-request.json \
    >"$raw_response"

python3 - "$selected_model" "$raw_response" "$plan_response" "$report" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

model = sys.argv[1]
raw_path = Path(sys.argv[2])
plan_path = Path(sys.argv[3])
report_path = Path(sys.argv[4])

expected_kinds = [
    "paragraph-replace",
    "paragraph-insert-after",
    "paragraph-delete",
    "paragraph-format",
    "paragraph-reformat",
    "text-range-replace",
    "text-format",
]
expected_patch_ids = [f"p{i}" for i in range(1, 8)]
hash_re = re.compile(r"^sha256:[a-f0-9]{64}$")

raw = json.loads(raw_path.read_text(encoding="utf-8"))
response = raw.get("response")
violations: list[str] = []
plan = None

if not isinstance(response, str) or not response.strip():
    violations.append("missing non-empty Ollama response string")
else:
    try:
        plan = json.loads(response)
    except json.JSONDecodeError as e:
        violations.append(f"response is not a single JSON object: {e}")

if isinstance(plan, dict):
    plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if plan.get("schema_version") != "v2-w3-runtime-1":
        violations.append("schema_version != v2-w3-runtime-1")
    if plan.get("plan_id") != "ap-ollama-real-path-001":
        violations.append("plan_id mismatch")
    if plan.get("source_diagnostic_id") != "diag-ollama-real-path-001":
        violations.append("source_diagnostic_id mismatch")
    snapshot_hash = plan.get("doc_snapshot_hash")
    if not isinstance(snapshot_hash, str) or not snapshot_hash.startswith("sha256:"):
        violations.append("doc_snapshot_hash is not a sha256-prefixed string")
    if plan.get("preview_only") is not False:
        violations.append("preview_only must be false")
    patches = plan.get("patches")
    if not isinstance(patches, list):
        violations.append("patches is not an array")
        patches = []
    if len(patches) != 7:
        violations.append(f"patches length {len(patches)} != 7")
    kinds = [p.get("kind") if isinstance(p, dict) else None for p in patches]
    patch_ids = [p.get("patch_id") if isinstance(p, dict) else None for p in patches]
    if kinds != expected_kinds:
        violations.append(f"patch kinds {kinds!r} != {expected_kinds!r}")
    if patch_ids != expected_patch_ids:
        violations.append(f"patch ids {patch_ids!r} != {expected_patch_ids!r}")
    for idx, patch in enumerate(patches):
        if not isinstance(patch, dict):
            violations.append(f"patch {idx + 1} is not an object")
            continue
        target = patch.get("target")
        if not isinstance(target, dict) or target.get("paragraph_id") != "swpara-1":
            violations.append(f"patch {idx + 1} target.paragraph_id mismatch")
        if patch.get("severity") != "minor":
            violations.append(f"patch {idx + 1} severity mismatch")
        if not isinstance(patch.get("rationale"), str) or not patch["rationale"]:
            violations.append(f"patch {idx + 1} rationale missing")
else:
    plan_path.write_text("", encoding="utf-8")

lines = [
    "# V2 Ollama Real Path Smoke",
    "",
    f"- Status: {'passed' if not violations else 'failed'}",
    f"- Model: {model}",
    f"- Raw response: {raw_path}",
    f"- Extracted plan: {plan_path}",
    "- Hash note: Writer TryParseApplyPlanRuntimeJson overwrites doc_snapshot_hash with the live document hash before ApplyEngine runs; this smoke locks the sha256 prefix and runtime shape.",
]
if isinstance(plan, dict):
    lines.append(f"- Patch kinds: {', '.join(str(p.get('kind')) for p in plan.get('patches', []) if isinstance(p, dict))}")
if violations:
    lines.append("")
    lines.append("## Violations")
    lines.extend(f"- {v}" for v in violations)

report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Status: {'passed' if not violations else 'failed'}")
print(f"Model: {model}")
print(f"Report: {report_path}")
print(f"Raw response: {raw_path}")
print(f"Extracted plan: {plan_path}")
if violations:
    for v in violations:
        print(f"FAIL: {v}", file=sys.stderr)
    raise SystemExit(1)
PY
