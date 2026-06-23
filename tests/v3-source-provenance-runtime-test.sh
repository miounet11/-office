#!/usr/bin/env bash
# V3 W1/M2.6 - source provenance runtime smoke.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src_root="$repo_root/libreoffice-core"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

[[ -d "$src_root" ]] || fail "missing source root $src_root"

python3 - "$repo_root" "$src_root" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

repo = Path(sys.argv[1])
src = Path(sys.argv[2])

prov_hxx = src / "sfx2/source/sidebar/AIChatSourceProvenance.hxx"
prov_cxx = src / "sfx2/source/sidebar/AIChatSourceProvenance.cxx"
object_store = src / "sfx2/source/sidebar/AIChatContentObjectStore.cxx"
preview = src / "sfx2/source/sidebar/AIChatPreviewMatrix.cxx"
panel = src / "sfx2/source/sidebar/AIChatPanel.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
policy = repo / "docs/product/v3/w1-workspace-source-provenance-policy.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [prov_hxx, prov_cxx, object_store, preview, panel, library_mk, policy, todo]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = prov_hxx.read_text()
cxx = prov_cxx.read_text()
store = object_store.read_text()
preview_text = preview.read_text()
panel_text = panel.read_text()
mk = library_mk.read_text()
policy_text = policy.read_text()
todo_text = todo.read_text()
combined = hxx + cxx + store + preview_text + panel_text

required_fields = [
    "SourceId",
    "SourceType",
    "CitationId",
    "EvidenceId",
    "HashReference",
    "SourceSurface",
    "OpenTarget",
    "SpanReference",
    "ReviewId",
]

checks = {
    "todo records m2.6 complete": "[x] M2.6 Build source provenance runtime" in todo_text,
    "policy required fields": "requiredFields=[source-id,source-type,citation-id,evidence-id,hash-reference,source-surface,open-target,span-reference,review-id]" in policy_text,
    "policy metadata only": "metadataOnly=true" in policy_text and "hashOnlyReferences=true" in policy_text,
    "policy visible citation": "requiresVisibleCitationBadge=true" in policy_text,
    "provenance class": "class AIChatSourceProvenance final" in hxx,
    "entry struct": "struct AIChatSourceProvenanceEntry" in hxx,
    "all fields": all(field in hxx for field in required_fields),
    "compiled": "sfx2/source/sidebar/AIChatSourceProvenance" in mk,
    "local namespace": "kqoffice-v3-ai-source-provenance" in cxx,
    "provenance file": "provenance.tsv" in cxx,
    "bounded read": "MAX_PROVENANCE_BYTES" in cxx,
    "register api": "RegisterSource" in hxx + cxx,
    "load api": "LoadEntries" in hxx + cxx,
    "parse api": "ParseProvenanceLine" in cxx,
    "escaped metadata": "EscapeField" in cxx and "UnescapeField" in cxx,
    "source id helper": "MakeSourceId" in hxx + cxx and "source:" in cxx,
    "citation id helper": "MakeCitationId" in hxx + cxx and "citation:" in cxx,
    "local evidence helper": "MakeLocalEvidenceId" in hxx + cxx and "evidence:local-materialized:" in cxx,
    "materialization evidence": "AIChatSourceProvenance::MakeLocalEvidenceId(aContent.ObjectId)" in store,
    "materialization registers provenance": "AIChatSourceProvenance aProvenance" in store and "aProvenance.RegisterSource(aSource)" in store,
    "source type content suggestion": 'aSource.SourceType = u"content-suggestion"_ustr' in store,
    "span whole object": 'aSource.SpanReference = u"span:whole-object"_ustr' in store,
    "review pending": 'aSource.ReviewId = u"review:pending"_ustr' in store,
    "preview has source metadata": "source-id=" in preview_text and "citation-id=" in preview_text and "evidence-id=" in preview_text,
    "panel shows source metadata": "source-metadata=" in panel_text,
    "no raw source content": "SourceContent" not in combined and "RawContent" not in combined and "Payload" not in combined and "PreviewBody" not in combined,
    "no main doc mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
    "no webview": "WebView" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 source provenance runtime self-test passed. Checks: {len(checks)}")
PY
