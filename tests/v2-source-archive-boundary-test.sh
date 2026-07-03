#!/usr/bin/env bash
set -euo pipefail

# H10: source archive boundary gate.
#
# This validates that the dirty SRCDIR tree is split into explicit V2 archive
# batches before anyone stages commits. It is intentionally non-destructive.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ -n "${KDOFFICE_SRC_ROOT:-}" ]]; then
    src_root="$(cd -P "$KDOFFICE_SRC_ROOT" && pwd)"
elif [[ -d /Users/lu/kdoffice-src ]]; then
    src_root=/Users/lu/kdoffice-src
else
    echo "Status: skipped"
    echo "Reason: KDOFFICE_SRC_ROOT is not set and /Users/lu/kdoffice-src is absent"
    echo "Checks: 1"
    exit 0
fi

checks=0
report="$repo_root/tmp/v2-source-archive-boundary.md"

require_file() {
    local path="$1"
    local label="$2"
    if [[ ! -f "$path" ]]; then
        echo "FAIL: missing $label at $path" >&2
        exit 1
    fi
    checks=$((checks + 1))
}

require_token() {
    local token="$1"
    local path="$2"
    local label="$3"
    if ! grep -Fq "$token" "$path"; then
        echo "FAIL: missing $label token '$token' in $path" >&2
        exit 1
    fi
    checks=$((checks + 1))
}

require_file "bin/v2-source-archive-boundary.sh" "source archive boundary script"
if [[ ! -x bin/v2-source-archive-boundary.sh ]]; then
    echo "FAIL: bin/v2-source-archive-boundary.sh is not executable" >&2
    exit 1
fi
checks=$((checks + 1))

bash bin/v2-source-archive-boundary.sh --src-root "$src_root" --report "$report"
checks=$((checks + 1))

require_file "$report" "source archive boundary report"
require_token "Unknown paths: 0" "$report" "zero unknown source paths"
require_token "Split-needed shared paths:" "$report" "shared path count"
require_token "W1-provider" "$report" "W1 provider batch"
require_token "W2-command-palette" "$report" "W2 command palette batch"
require_token "W3-writer-apply" "$report" "W3 writer apply batch"
require_token "W4-select-to-act" "$report" "W4 select-to-act batch"
require_token "W5-cowork" "$report" "W5 cowork batch"
require_token "V3-native-ai-workspace" "$report" "V3 native AI workspace batch"
require_token "V3-agent-chat" "$report" "V3 agent chat batch"
require_token "V3-agent-mesh" "$report" "V3 agent mesh batch"
require_token "V3-ai-canvas" "$report" "V3 AI canvas batch"
require_token "V3-ai-filemgr" "$report" "V3 AI file manager batch"
require_token "V3-control-plane" "$report" "V3 control plane batch"
require_token "V3-i18n" "$report" "V3 i18n batch"
require_token "V1.5-branding-assets" "$report" "V1.5 branding assets batch"
require_token "build-infra" "$report" "build infra batch"
require_token "submodule-dirty" "$report" "dirty submodule batch"
require_token "Batch path lists:" "$report" "batch path-list directory"

batch_dir="$repo_root/tmp/v2-source-archive-batches"
require_file "$batch_dir/W4-select-to-act.paths" "W4 source archive path list"
require_file "$batch_dir/W5-cowork.paths" "W5 source archive path list"
require_file "$batch_dir/V3-native-ai-workspace.paths" "V3 native AI workspace path list"
require_file "$batch_dir/V3-agent-chat.paths" "V3 agent chat path list"
require_file "$batch_dir/V3-agent-mesh.paths" "V3 agent mesh path list"
require_file "$batch_dir/V3-ai-canvas.paths" "V3 AI canvas path list"
require_file "$batch_dir/V3-ai-filemgr.paths" "V3 AI file manager path list"
require_file "$batch_dir/V3-control-plane.paths" "V3 control plane path list"
require_file "$batch_dir/V3-i18n.paths" "V3 i18n path list"
require_file "$batch_dir/V1.5-branding-assets.paths" "V1.5 branding assets path list"
require_file "$batch_dir/build-infra.paths" "build infra path list"
require_file "$batch_dir/split-needed.paths" "split-needed source archive path list"
require_file "$batch_dir/unknown.paths" "unknown source archive path list"
require_token "sfx2/source/sidebar/AIChatComposer.cxx" "$batch_dir/V3-native-ai-workspace.paths" "V3 AIChatComposer path"
require_token "kqoffice/source/ai/chat/AgentChatStreamingClient.cxx" "$batch_dir/V3-agent-chat.paths" "V3 agent-chat path"
require_token "kqoffice/source/ai/mesh/WorkspaceAgentMesh.cxx" "$batch_dir/V3-agent-mesh.paths" "V3 agent-mesh path"
require_token "kqoffice/source/ai/canvas/AICanvasMode.cxx" "$batch_dir/V3-ai-canvas.paths" "V3 ai-canvas path"
require_token "kqoffice/source/ai/filemgr/AIFileManager.cxx" "$batch_dir/V3-ai-filemgr.paths" "V3 ai-filemgr path"
require_token "kqoffice/source/ai/control/SessionStore.cxx" "$batch_dir/V3-control-plane.paths" "V3 control-plane path"
require_token "kqoffice/source/ai/cowork/TaskRunner.cxx" "$batch_dir/W5-cowork.paths" "W5 worker path"
require_token "kqoffice/Library_kqoffice_ai.mk" "$batch_dir/split-needed.paths" "split-needed kqoffice library path"
if [[ -s "$batch_dir/unknown.paths" ]]; then
    echo "FAIL: unknown source archive path list is not empty" >&2
    exit 1
fi
checks=$((checks + 1))

echo "Status: passed"
echo "Checks: $checks"
