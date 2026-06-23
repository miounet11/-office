#!/usr/bin/env bash
# V3 W1 - V2 Provider-backed streaming UI smoke.

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

panel_hxx = src / "sfx2/source/sidebar/AIChatPanel.hxx"
panel_cxx = src / "sfx2/source/sidebar/AIChatPanel.cxx"
streaming_policy = repo / "docs/product/v3/w1-streaming-state-policy.md"
xprovider = src / "offapi/com/sun/star/ai/XProvider.idl"
provider_request = src / "offapi/com/sun/star/ai/ProviderRequest.idl"
provider_response = src / "offapi/com/sun/star/ai/ProviderResponse.idl"

for path in [panel_hxx, panel_cxx, streaming_policy, xprovider, provider_request, provider_response]:
    if not path.exists():
        raise SystemExit(f"FAIL: missing {path}")

hxx = panel_hxx.read_text()
cxx = panel_cxx.read_text()
policy = streaming_policy.read_text()
xprovider_text = xprovider.read_text()
request_text = provider_request.read_text()
response_text = provider_response.read_text()

checks = {
    "policy source": "Source | v2-provider-chunk" in policy,
    "policy states": "idle, requesting, streaming, awaiting-approval, applied, failed, cancelled" in policy,
    "state idle": "AIChatPanelState::Idle" in hxx + cxx,
    "state requesting": "AIChatPanelState::Requesting" in hxx + cxx,
    "state streaming": "AIChatPanelState::Streaming" in hxx + cxx,
    "state awaiting approval": "AIChatPanelState::AwaitingApproval" in hxx + cxx,
    "state applied": "AIChatPanelState::Applied" in hxx + cxx,
    "state failed": "AIChatPanelState::Failed" in hxx + cxx,
    "state cancelled": "AIChatPanelState::Cancelled" in hxx + cxx,
    "provider response include": "ProviderResponse.hpp" in hxx,
    "provider request include": "ProviderRequest.hpp" in cxx,
    "xprovider include": "XProvider.hpp" in cxx,
    "process factory": "comphelper::getProcessComponentContext" in cxx,
    "service name": "com.sun.star.ai.Provider" in cxx,
    "call provider helper": "AIChatPanel::CallProvider" in cxx,
    "provider call": "xProvider->call(aRequest)" in cxx,
    "capability summarize": 'aRequest.capability = u"summarize"_ustr' in cxx,
    "timeout": "PROVIDER_TIMEOUT_MS" in cxx,
    "requesting before call": "SetState(AIChatPanelState::Requesting)" in cxx,
    "streaming after call": "SetState(AIChatPanelState::Streaming)" in cxx,
    "chunk helper": "AppendAssistantChunk" in hxx + cxx,
    "append-only chunk buffer": "m_sStreamingBuffer" in hxx + cxx,
    "chunk tokenization": "getToken(0, ' ', nIndex)" in cxx,
    "markdown per chunk": "AppendAssistantMarkdown(rChunk)" in cxx,
    "awaiting approval on ok": "SetState(AIChatPanelState::AwaitingApproval)" in cxx,
    "failed on non-ok": "SetState(AIChatPanelState::Failed)" in cxx,
    "terminal evidence helper": "AppendTerminalEvidence" in hxx + cxx,
    "terminal evidence id": "aResponse.evidenceId" in cxx,
    "cancel busy states": "AIChatPanelState::Requesting" in cxx and "AIChatPanelState::Streaming" in cxx,
    "retry resets idle": "SetState(AIChatPanelState::Idle)" in cxx,
    "xprovider remains sync": "ProviderResponse call" in xprovider_text and "sequence<ProviderResponse>" not in xprovider_text,
    "request has no stream field": "timeoutMs" in request_text and "boolean stream" not in request_text and "string stream" not in request_text,
    "response evidence": "evidenceId" in response_text,
    "no document mutation": "SfxObjectShell" not in cxx and "SwDoc" not in cxx and "ScDoc" not in cxx,
    "no new provider schema": "XStreaming" not in cxx + hxx,
}

failed = [name for name, passed in checks.items() if not passed]
if failed:
    raise SystemExit("FAIL: " + ", ".join(failed))

print(f"V3 provider streaming UI self-test passed. Checks: {len(checks)}")
PY
