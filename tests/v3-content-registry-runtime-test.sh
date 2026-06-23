#!/usr/bin/env bash
# V3 W1/M2.2 - metadata-only workspace content registry runtime smoke.

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

registry_hxx = src / "sfx2/source/sidebar/AIChatContentRegistry.hxx"
registry_cxx = src / "sfx2/source/sidebar/AIChatContentRegistry.cxx"
object_store = src / "sfx2/source/sidebar/AIChatContentObjectStore.cxx"
library_mk = src / "sfx2/Library_sfx.mk"
registry_policy = repo / "docs/product/v3/w1-workspace-content-registry-policy.md"
todo = repo / "docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md"

for path in [registry_hxx, registry_cxx, object_store, library_mk, registry_policy, todo]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = registry_hxx.read_text()
cxx = registry_cxx.read_text()
store = object_store.read_text()
mk = library_mk.read_text()
policy = registry_policy.read_text()
todo_text = todo.read_text()
combined = hxx + cxx + store

required_fields = [
    "ObjectId",
    "Type",
    "SourceSurface",
    "State",
    "EvidenceId",
    "HashReference",
    "OpenTarget",
    "PreviewMode",
]

checks = {
    "todo records m2.2 complete": "[x] M2.2 Register materialized content in the workspace content registry" in todo_text,
    "policy metadata only": "metadataOnly=true" in policy,
    "policy required fields": "requiredFields=[object-id,type,source-surface,state,evidence-id,hash-reference,open-target,preview-mode]" in policy,
    "registry class": "class AIChatContentRegistry final" in hxx,
    "entry struct": "struct AIChatContentRegistryEntry" in hxx,
    "all required fields": all(field in hxx for field in required_fields),
    "registry compiled": "sfx2/source/sidebar/AIChatContentRegistry" in mk,
    "local registry namespace": "kqoffice-v3-ai-content-registry" in cxx,
    "registry file": "registry.tsv" in cxx,
    "register object api": "RegisterObject" in hxx + cxx,
    "append only metadata": "AppendUtf8Line" in cxx and "setPos(osl_Pos_Absolut, nSize)" in cxx,
    "escaped metadata fields": "EscapeField" in cxx,
    "utf8 registry": "RTL_TEXTENCODING_UTF8" in cxx,
    "object store registers": "AIChatContentRegistry aRegistry" in store,
    "object id registered": "aEntry.ObjectId = aContent.ObjectId" in store,
    "type registered": "aEntry.Type = DetectTypeLabel(aContent.Type)" in store,
    "source surface registered": 'aEntry.SourceSurface = u"chat-composer"_ustr' in store,
    "state registered": 'aEntry.State = u"registered"_ustr' in store,
    "hash reference registered": "aEntry.HashReference = aContent.Reference" in store,
    "open target registered": 'aEntry.OpenTarget = u"sidebar-preview"_ustr' in store,
    "preview mode registered": 'aEntry.PreviewMode = u"metadata-summary"_ustr' in store,
    "no raw payload field": "Payload" not in combined and "RawContent" not in combined and "PreviewBody" not in combined,
    "no transcript body field": "Transcript" not in hxx and "SuggestionContent" not in combined,
    "no cloud sync": "cloud" not in cxx.lower() and "sync" not in cxx.lower(),
    "no main doc mutation": "SwDoc" not in combined and "ScDoc" not in combined and "SdDrawDocument" not in combined,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 content registry runtime self-test passed. Checks: {len(checks)}")
PY
