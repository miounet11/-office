#!/usr/bin/env bash
# V3 W1/M3.4 - evidence inspector runtime smoke.

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

inspector_hxx = src / "sfx2/source/sidebar/AIChatEvidenceInspector.hxx"
inspector_cxx = src / "sfx2/source/sidebar/AIChatEvidenceInspector.cxx"
provenance_hxx = src / "sfx2/source/sidebar/AIChatSourceProvenance.hxx"
provenance_cxx = src / "sfx2/source/sidebar/AIChatSourceProvenance.cxx"
opener_cxx = src / "sfx2/source/sidebar/AIChatContentOpener.cxx"
preview_cxx = src / "sfx2/source/sidebar/AIChatPreviewMatrix.cxx"
panel_hxx = src / "sfx2/source/sidebar/AIChatPanel.hxx"
panel_cxx = src / "sfx2/source/sidebar/AIChatPanel.cxx"
ui = src / "sfx2/uiconfig/ui/aichatpanel.ui"
library_mk = src / "sfx2/Library_sfx.mk"
policy = repo / "docs/product/v3/w1-evidence-inspector-policy.md"
source_policy = repo / "docs/product/v3/w1-workspace-source-provenance-policy.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [
    inspector_hxx,
    inspector_cxx,
    provenance_hxx,
    provenance_cxx,
    opener_cxx,
    preview_cxx,
    panel_hxx,
    panel_cxx,
    ui,
    library_mk,
    policy,
    source_policy,
    todo,
]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = inspector_hxx.read_text()
cxx = inspector_cxx.read_text()
prov_h = provenance_hxx.read_text()
prov_c = provenance_cxx.read_text()
opener = opener_cxx.read_text()
preview = preview_cxx.read_text()
panel_h = panel_hxx.read_text()
panel = panel_cxx.read_text()
ui_text = ui.read_text()
mk = library_mk.read_text()
policy_text = policy.read_text()
source_policy_text = source_policy.read_text()
todo_text = todo.read_text()
combined = hxx + cxx + prov_h + prov_c + opener + preview + panel_h + panel + ui_text

fields = [
    "SourceId",
    "SourceType",
    "CitationId",
    "EvidenceId",
    "HashReference",
    "OpenTarget",
    "AuditTrail",
    "Summary",
]
source_types = [
    'rSourceType == u"evidence-record"_ustr',
    'rSourceType == u"connector-result"_ustr',
    'rSourceType == u"knowledge-index-result"_ustr',
    'rSourceType == u"task-step"_ustr',
    'rSourceType == u"review-item"_ustr',
]

checks = {
    "policy source types": "sourceTypes=[evidence-record,connector-result,knowledge-index-result,task-step,review-item]" in policy_text,
    "policy citation links": "showsCitationLinks=true" in policy_text,
    "policy audit trail": "showsAuditTrail=true" in policy_text,
    "policy content openers": "openUsesContentOpeners=true" in policy_text,
    "policy redaction": "redactsRawPayload=true" in policy_text and "hashOnlyReferences=true" in policy_text,
    "policy evidence link": "requiresEvidenceLink=true" in policy_text,
    "source provenance inspector surface": "evidence-inspector" in source_policy_text,
    "inspector class": "class AIChatEvidenceInspector final" in hxx,
    "inspector result": "struct AIChatEvidenceInspectionResult" in hxx,
    "all fields": all(field in hxx for field in fields),
    "compiled": "sfx2/source/sidebar/AIChatEvidenceInspector" in mk,
    "inspect api": "Inspect" in hxx + cxx,
    "source type api": "IsSupportedSourceType" in hxx + cxx,
    "supported source types": all(needle in cxx for needle in source_types),
    "formatting preview source accepted": 'rSourceType == u"formatting-preview"_ustr' in cxx,
    "missing id guard": "evidence-inspection-failed reason=missing-object-id" in cxx,
    "unsupported source guard": "evidence-inspection-failed reason=unsupported-source-type" in cxx,
    "missing evidence guard": "evidence-inspection-failed reason=missing-evidence-link" in cxx,
    "missing hash guard": "evidence-inspection-failed reason=missing-hash-reference" in cxx,
    "uses provenance": "AIChatSourceProvenance aProvenance" in cxx and "aProvenance.LoadEntries()" in cxx,
    "citation helper": "MakeCitationId" in cxx,
    "source helper": "MakeSourceId" in cxx,
    "citation output": "citation-id=" in cxx and "shows-citation-links=true" in cxx,
    "audit output": "audit-trail=metadata-only" in cxx and "shows-audit-trail=true" in cxx,
    "hash only output": "hash-only=true" in cxx,
    "redacted output": "redacted=true" in cxx,
    "read only output": "read-only=true" in cxx,
    "no mutation output": "main-document-mutation=false" in cxx,
    "evidence target": "evidence-inspector" in cxx,
    "opener supports target": "evidence-inspector" in opener,
    "preview supports target": "evidence-inspector" in preview,
    "panel owns inspector": "std::unique_ptr<AIChatEvidenceInspector> m_xEvidenceInspector" in panel_h,
    "panel includes inspector": '#include "AIChatEvidenceInspector.hxx"' in panel,
    "panel creates inspector": "std::make_unique<AIChatEvidenceInspector>()" in panel,
    "ui evidence button": 'id="inspect_evidence_button"' in ui_text and "证据" in ui_text,
    "ui keyboard reachable": 'id="inspect_evidence_button"' in ui_text and '<property name="can-focus">True</property>' in ui_text,
    "panel wires button": "OnInspectEvidenceClicked" in panel_h + panel and "InspectSelectedEvidence" in panel_h + panel,
    "panel invokes inspector": "m_xEvidenceInspector->Inspect(*pSelected)" in panel,
    "panel records evidence event": 'u"evidence-linked"_ustr' in panel,
    "panel evidence snapshot": 'u"evidence-summary"_ustr' in panel,
    "visible failure": "Evidence inspection failed:" in panel and "evidence-inspection-failed reason=missing-registry-entry" in panel,
    "todo has m3.4": "M3.4 Implement evidence inspector runtime" in todo_text,
    "no raw payload": "RawContent" not in combined and "Payload" not in combined and "PreviewBody" not in combined and "SourceContent" not in combined,
    "no direct document mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
    "no apply path": "ApplyPlan" not in combined and "ExecuteList" not in combined,
    "no webview": "WebView" not in combined,
    "no cloud": "cloud" not in cxx.lower(),
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 evidence inspector runtime self-test passed. Checks: {len(checks)}")
PY
