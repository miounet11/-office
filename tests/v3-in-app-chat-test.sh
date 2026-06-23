#!/usr/bin/env bash
# V3 W1 - in-app chat fixture contract self-test.
#
# Contract-first gate for the W1 sidebar chat path. It locks the
# CommandPalette chat-fallback route, Markdown rendering subset,
# per-document local history, streaming UI states, context autocomplete,
# AI workspace review/progress/opening UI, plus reuse of V2 Provider,
# ApplyPlan runtime validation, approval, and evidence contracts
# without adding a W1 schema or touching product/runtime code.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

bash tests/v3-ai-chat-panel-registration-test.sh >/dev/null
bash tests/v3-command-palette-chat-fallback-test.sh >/dev/null
bash tests/v3-native-chat-composer-test.sh >/dev/null
bash tests/v3-markdown-rendering-runtime-test.sh >/dev/null
bash tests/v3-provider-streaming-ui-test.sh >/dev/null
bash tests/v3-chat-history-runtime-test.sh >/dev/null
bash tests/v3-context-mentions-runtime-test.sh >/dev/null
bash tests/v3-clipboard-materialization-runtime-test.sh >/dev/null
bash tests/v3-content-registry-runtime-test.sh >/dev/null
bash tests/v3-artifact-navigator-runtime-test.sh >/dev/null
bash tests/v3-content-opener-runtime-test.sh >/dev/null
bash tests/v3-preview-matrix-runtime-test.sh >/dev/null
bash tests/v3-source-provenance-runtime-test.sh >/dev/null
bash tests/v3-workspace-session-runtime-test.sh >/dev/null
bash tests/v3-content-review-runtime-test.sh >/dev/null
bash tests/v3-formatting-review-runtime-test.sh >/dev/null
bash tests/v3-review-queue-runtime-test.sh >/dev/null
bash tests/v3-evidence-inspector-runtime-test.sh >/dev/null
bash tests/v3-workspace-action-bar-runtime-test.sh >/dev/null
bash tests/v3-review-state-sync-runtime-test.sh >/dev/null
bash tests/v3-connector-manifest-loader-runtime-test.sh >/dev/null
bash tests/v3-connector-operation-runtime-test.sh >/dev/null
bash tests/v3-connector-auth-flow-runtime-test.sh >/dev/null
bash tests/v3-knowledge-index-storage-runtime-test.sh >/dev/null
bash tests/v3-knowledge-extraction-runtime-test.sh >/dev/null
bash tests/v3-knowledge-retrieval-runtime-test.sh >/dev/null
bash tests/v3-knowledge-result-content-runtime-test.sh >/dev/null
bash tests/v3-agent-planner-runtime-test.sh >/dev/null
bash tests/v3-agent-task-state-runtime-test.sh >/dev/null
bash tests/v3-agent-shadow-doc-runtime-test.sh >/dev/null
bash tests/v3-agent-review-surface-runtime-test.sh >/dev/null
bash tests/v3-agent-failure-recovery-runtime-test.sh >/dev/null

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

w1_spec="docs/product/v3/w1-in-app-chat-spec.md"
shortcut_survey="docs/product/v3/w1-keyboard-shortcut-survey.md"
sidebar_wireframe="docs/product/v3/w1-sidebar-uiwireframe.md"
context_policy="docs/product/v3/w1-context-syntax-policy.md"
autocomplete_policy="docs/product/v3/w1-context-autocomplete-policy.md"
markdown_policy="docs/product/v3/w1-markdown-rendering-policy.md"
history_policy="docs/product/v3/w1-chat-history-policy.md"
streaming_policy="docs/product/v3/w1-streaming-state-policy.md"
workspace_ui_policy="docs/product/v3/w1-ai-workspace-ui-policy.md"
content_opener_policy="docs/product/v3/w1-content-opener-policy.md"
formatting_review_policy="docs/product/v3/w1-formatting-review-policy.md"
content_review_policy="docs/product/v3/w1-content-review-policy.md"
artifact_navigator_policy="docs/product/v3/w1-artifact-navigator-policy.md"
review_queue_policy="docs/product/v3/w1-review-queue-policy.md"
evidence_inspector_policy="docs/product/v3/w1-evidence-inspector-policy.md"
interaction_chrome_policy="docs/product/v3/w1-interaction-chrome-policy.md"
preview_matrix_policy="docs/product/v3/w1-content-preview-matrix-policy.md"
action_bar_policy="docs/product/v3/w1-workspace-action-bar-policy.md"
filter_search_policy="docs/product/v3/w1-workspace-filter-search-policy.md"
context_handoff_policy="docs/product/v3/w1-workspace-context-handoff-policy.md"
review_state_sync_policy="docs/product/v3/w1-workspace-review-state-sync-policy.md"
activity_timeline_policy="docs/product/v3/w1-workspace-activity-timeline-policy.md"
session_snapshot_policy="docs/product/v3/w1-workspace-session-snapshot-policy.md"
attention_routing_policy="docs/product/v3/w1-workspace-attention-routing-policy.md"
native_style_policy="docs/product/v3/w1-workspace-native-style-policy.md"
content_registry_policy="docs/product/v3/w1-workspace-content-registry-policy.md"
source_provenance_policy="docs/product/v3/w1-workspace-source-provenance-policy.md"
clipboard_policy="docs/product/v3/w1-chat-clipboard-materialization-policy.md"
w5_spec="docs/product/v3/w5-eval-harness-spec.md"
master_plan="docs/product/v3-master-plan.md"
sweep="bin/v3-eval-sweep.sh"
workflow=".github/workflows/v3-contract-harnesses.yml"
valid_dir="docs/qa/fixtures/v3/in-app-chat/valid"
invalid_dir="docs/qa/fixtures/v3/in-app-chat/invalid"

[[ -f "$w1_spec" ]] || fail "missing $w1_spec"
[[ -f "$shortcut_survey" ]] || fail "missing $shortcut_survey"
[[ -f "$sidebar_wireframe" ]] || fail "missing $sidebar_wireframe"
[[ -f "$context_policy" ]] || fail "missing $context_policy"
[[ -f "$autocomplete_policy" ]] || fail "missing $autocomplete_policy"
[[ -f "$markdown_policy" ]] || fail "missing $markdown_policy"
[[ -f "$history_policy" ]] || fail "missing $history_policy"
[[ -f "$streaming_policy" ]] || fail "missing $streaming_policy"
[[ -f "$workspace_ui_policy" ]] || fail "missing $workspace_ui_policy"
[[ -f "$content_opener_policy" ]] || fail "missing $content_opener_policy"
[[ -f "$formatting_review_policy" ]] || fail "missing $formatting_review_policy"
[[ -f "$content_review_policy" ]] || fail "missing $content_review_policy"
[[ -f "$artifact_navigator_policy" ]] || fail "missing $artifact_navigator_policy"
[[ -f "$review_queue_policy" ]] || fail "missing $review_queue_policy"
[[ -f "$evidence_inspector_policy" ]] || fail "missing $evidence_inspector_policy"
[[ -f "$interaction_chrome_policy" ]] || fail "missing $interaction_chrome_policy"
[[ -f "$preview_matrix_policy" ]] || fail "missing $preview_matrix_policy"
[[ -f "$action_bar_policy" ]] || fail "missing $action_bar_policy"
[[ -f "$filter_search_policy" ]] || fail "missing $filter_search_policy"
[[ -f "$context_handoff_policy" ]] || fail "missing $context_handoff_policy"
[[ -f "$review_state_sync_policy" ]] || fail "missing $review_state_sync_policy"
[[ -f "$activity_timeline_policy" ]] || fail "missing $activity_timeline_policy"
[[ -f "$session_snapshot_policy" ]] || fail "missing $session_snapshot_policy"
[[ -f "$attention_routing_policy" ]] || fail "missing $attention_routing_policy"
[[ -f "$native_style_policy" ]] || fail "missing $native_style_policy"
[[ -f "$content_registry_policy" ]] || fail "missing $content_registry_policy"
[[ -f "$source_provenance_policy" ]] || fail "missing $source_provenance_policy"
[[ -f "$clipboard_policy" ]] || fail "missing $clipboard_policy"
[[ -f "$w5_spec" ]] || fail "missing $w5_spec"
[[ -f "$master_plan" ]] || fail "missing $master_plan"
[[ -f "$sweep" ]] || fail "missing $sweep"
[[ -f "$workflow" ]] || fail "missing $workflow"
[[ -d "$valid_dir" ]] || fail "missing $valid_dir"
[[ -d "$invalid_dir" ]] || fail "missing $invalid_dir"

python3 - "$w1_spec" "$shortcut_survey" "$sidebar_wireframe" "$context_policy" "$autocomplete_policy" "$markdown_policy" "$history_policy" "$streaming_policy" "$workspace_ui_policy" "$content_opener_policy" "$formatting_review_policy" "$content_review_policy" "$artifact_navigator_policy" "$review_queue_policy" "$evidence_inspector_policy" "$interaction_chrome_policy" "$preview_matrix_policy" "$action_bar_policy" "$filter_search_policy" "$context_handoff_policy" "$review_state_sync_policy" "$activity_timeline_policy" "$session_snapshot_policy" "$attention_routing_policy" "$native_style_policy" "$content_registry_policy" "$source_provenance_policy" "$clipboard_policy" "$w5_spec" "$master_plan" "$sweep" "$workflow" "$valid_dir" "$invalid_dir" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

w1_spec = Path(sys.argv[1])
shortcut_survey = Path(sys.argv[2])
sidebar_wireframe = Path(sys.argv[3])
context_policy = Path(sys.argv[4])
autocomplete_policy = Path(sys.argv[5])
markdown_policy = Path(sys.argv[6])
history_policy = Path(sys.argv[7])
streaming_policy = Path(sys.argv[8])
workspace_ui_policy = Path(sys.argv[9])
content_opener_policy = Path(sys.argv[10])
formatting_review_policy = Path(sys.argv[11])
content_review_policy = Path(sys.argv[12])
artifact_navigator_policy = Path(sys.argv[13])
review_queue_policy = Path(sys.argv[14])
evidence_inspector_policy = Path(sys.argv[15])
interaction_chrome_policy = Path(sys.argv[16])
preview_matrix_policy = Path(sys.argv[17])
action_bar_policy = Path(sys.argv[18])
filter_search_policy = Path(sys.argv[19])
context_handoff_policy = Path(sys.argv[20])
review_state_sync_policy = Path(sys.argv[21])
activity_timeline_policy = Path(sys.argv[22])
session_snapshot_policy = Path(sys.argv[23])
attention_routing_policy = Path(sys.argv[24])
native_style_policy = Path(sys.argv[25])
content_registry_policy = Path(sys.argv[26])
source_provenance_policy = Path(sys.argv[27])
clipboard_policy = Path(sys.argv[28])
w5_spec = Path(sys.argv[29])
master_plan = Path(sys.argv[30])
sweep_path = Path(sys.argv[31])
workflow_path = Path(sys.argv[32])
valid_dir = Path(sys.argv[33])
invalid_dir = Path(sys.argv[34])

EXPECTED_VALID_FILES = {
    "writer-rewrite-formal.json",
    "writer-doc-summary.json",
    "calc-format-date.json",
    "impress-summarize-bullets.json",
    "connector-context-readonly.json",
}
EXPECTED_INVALID_FILES = {
    "cloud-history-enabled.json",
    "bypasses-apply-plan-runtime.json",
    "missing-human-approval.json",
    "introduces-new-chat-schema.json",
    "direct-accelerator-registration.json",
    "implicit-full-doc-context.json",
    "unknown-context-mention.json",
    "connector-write-context.json",
    "raw-html-rendering.json",
    "webview-renderer.json",
    "remote-image-rendering.json",
    "global-history-leakage.json",
    "cloud-history-sync.json",
    "raw-transcript-history.json",
    "missing-history-clear-control.json",
    "streaming-mutates-document.json",
    "partial-chunks-persisted.json",
    "missing-terminal-evidence.json",
    "unsupported-stream-state.json",
    "global-autocomplete-hijack.json",
    "unknown-connector-suggestion.json",
    "raw-context-preview.json",
    "autocomplete-runtime-parser-started.json",
    "workspace-modal-chat-only.json",
    "workspace-missing-task-progress.json",
    "workspace-review-without-evidence.json",
    "workspace-formatting-no-preview.json",
    "workspace-openers-runtime-started.json",
    "opener-route-policy-drift.json",
    "opener-missing-evidence-link.json",
    "opener-mutable-preview.json",
    "opener-silent-failure.json",
    "formatting-review-missing-envelope.json",
    "formatting-review-no-diffreview.json",
    "formatting-review-mutable-preview.json",
    "formatting-review-runtime-started.json",
    "content-review-missing-envelope.json",
    "content-review-no-evidence.json",
    "content-review-mutable-suggestion.json",
    "content-review-runtime-started.json",
    "artifact-navigator-missing-envelope.json",
    "artifact-navigator-type-drift.json",
    "artifact-navigator-mutable-details.json",
    "artifact-navigator-runtime-started.json",
    "review-queue-missing-envelope.json",
    "review-queue-no-filter.json",
    "review-queue-bulk-auto-apply.json",
    "review-queue-runtime-started.json",
    "evidence-inspector-missing-envelope.json",
    "evidence-inspector-source-drift.json",
    "evidence-inspector-raw-payload.json",
    "evidence-inspector-runtime-started.json",
    "interaction-chrome-missing-envelope.json",
    "interaction-chrome-modal-only.json",
    "interaction-chrome-no-keyboard.json",
    "interaction-chrome-runtime-started.json",
    "preview-matrix-missing-envelope.json",
    "preview-matrix-type-drift.json",
    "preview-matrix-raw-payload.json",
    "preview-matrix-runtime-started.json",
    "action-bar-missing-envelope.json",
    "action-bar-command-drift.json",
    "action-bar-hidden-mouse-only.json",
    "action-bar-runtime-started.json",
    "filter-search-missing-envelope.json",
    "filter-search-scope-drift.json",
    "filter-search-raw-index.json",
    "filter-search-runtime-started.json",
    "context-handoff-missing-envelope.json",
    "context-handoff-target-drift.json",
    "context-handoff-raw-payload.json",
    "context-handoff-runtime-started.json",
    "review-state-sync-missing-envelope.json",
    "review-state-sync-target-drift.json",
    "review-state-sync-auto-apply.json",
    "review-state-sync-runtime-started.json",
    "activity-timeline-missing-envelope.json",
    "activity-timeline-event-drift.json",
    "activity-timeline-raw-payload.json",
    "activity-timeline-runtime-started.json",
    "session-snapshot-missing-envelope.json",
    "session-snapshot-scope-drift.json",
    "session-snapshot-raw-payload.json",
    "session-snapshot-runtime-started.json",
    "attention-routing-missing-envelope.json",
    "attention-routing-surface-drift.json",
    "attention-routing-raw-payload.json",
    "attention-routing-runtime-started.json",
    "native-style-missing-envelope.json",
    "native-style-density-drift.json",
    "native-style-card-layout.json",
    "native-style-runtime-started.json",
    "content-registry-missing-envelope.json",
    "content-registry-type-drift.json",
    "content-registry-raw-payload.json",
    "content-registry-runtime-started.json",
    "source-provenance-missing-envelope.json",
    "source-provenance-type-drift.json",
    "source-provenance-raw-payload.json",
    "source-provenance-runtime-started.json",
    "clipboard-materialization-missing-envelope.json",
    "clipboard-materialization-raw-transcript.json",
    "clipboard-materialization-memory-only.json",
    "clipboard-materialization-runtime-started.json",
}
EXPECTED_TOKEN_LOCK = {
    "ParagraphAction": 7,
    "CellAction": 5,
    "SlideElementAction": 4,
}
EXPECTED_MARKDOWN_BLOCKS = [
    "paragraph",
    "heading",
    "list",
    "code-fence",
    "table",
]
EXPECTED_HISTORY = {
    "scope": "per-doc-local",
    "storage": "local-sqlite-sidecar",
    "documentBinding": "document-id-hash",
    "cloudSync": False,
    "globalIndex": False,
    "crossDocumentRestore": False,
    "rawContentInFixture": False,
    "requiresUserClearControl": True,
    "deleteWithDocument": True,
}
EXPECTED_STREAMING_STATES = [
    "idle",
    "requesting",
    "streaming",
    "awaiting-approval",
    "applied",
    "failed",
    "cancelled",
]
EXPECTED_STREAMING_UI = {
    "source": "v2-provider-chunk",
    "states": EXPECTED_STREAMING_STATES,
    "appendOnlyDuringStream": True,
    "mainDocumentUnchangedWhileStreaming": True,
    "cancelSupported": True,
    "retrySupported": True,
    "partialChunksPersisted": False,
    "chunkContentInFixture": False,
    "evidenceOnTerminalState": True,
}
EXPECTED_MENTIONS_UI = {
    "trigger": "@",
    "scope": "chat-input-only",
    "suggestions": ["@selection", "@doc", "@connector:<id>"],
    "officeAutocompletePolicy": "delegate-existing-controls",
    "hijacksGlobalAutocomplete": False,
    "requiresExplicitCommit": True,
    "connectorSuggestionsRequireW2Manifest": True,
    "unknownConnectorSuggestions": False,
    "rawPreviewContent": False,
    "rawContentInFixture": False,
    "runtimeParserImplementation": "not-started",
}
EXPECTED_WORKSPACE_STATES = [
    "pending",
    "running",
    "awaiting-review",
    "applied",
    "failed",
    "cancelled",
]
EXPECTED_WORKSPACE_CONTENT_TYPES = [
    "document",
    "selection",
    "connector-result",
    "knowledge-index-result",
    "evidence-record",
    "task-step",
]
EXPECTED_CONTENT_REGISTRY_TYPES = [
    "document",
    "selection",
    "connector-result",
    "knowledge-index-result",
    "evidence-record",
    "task-step",
    "review-item",
    "formatting-preview",
    "content-suggestion",
]
EXPECTED_CONTENT_REGISTRY_STATES = [
    "registered",
    "opened",
    "previewed",
    "in-review",
    "applied",
    "failed",
    "archived",
]
EXPECTED_CONTENT_REGISTRY_FIELDS = [
    "object-id",
    "type",
    "source-surface",
    "state",
    "evidence-id",
    "hash-reference",
    "open-target",
    "preview-mode",
]
EXPECTED_CONTENT_REGISTRY_OPEN_TARGETS = [
    "main-document-window",
    "sidebar-preview",
    "diff-review",
    "evidence-inspector",
    "review-queue",
]
EXPECTED_SOURCE_PROVENANCE_SOURCE_TYPES = [
    "document",
    "selection",
    "connector-result",
    "knowledge-index-result",
    "evidence-record",
    "task-step",
    "review-item",
    "formatting-preview",
    "content-suggestion",
]
EXPECTED_SOURCE_PROVENANCE_REQUIRED_FIELDS = [
    "source-id",
    "source-type",
    "citation-id",
    "evidence-id",
    "hash-reference",
    "source-surface",
    "open-target",
    "span-reference",
    "review-id",
]
EXPECTED_SOURCE_PROVENANCE_SURFACES = [
    "content-review",
    "formatting-review",
    "preview-matrix",
    "evidence-inspector",
    "review-queue",
    "activity-timeline",
    "composer",
]
EXPECTED_CLIPBOARD_MATERIALIZATION_INPUT_TYPES = [
    "plain-text-large",
    "rich-text",
    "html-fragment",
    "table-range",
    "image",
    "local-file-reference",
]
EXPECTED_WORKSPACE_OPEN_TARGETS = [
    "main-document-window",
    "sidebar-preview",
    "diff-review",
]
EXPECTED_WORKSPACE_ROUTE_POLICY = {
    "document": "main-document-window",
    "selection": "sidebar-preview",
    "connector-result": "sidebar-preview",
    "knowledge-index-result": "sidebar-preview",
    "evidence-record": "sidebar-preview",
    "task-step": "diff-review",
}
EXPECTED_FORMATTING_REVIEW_SCOPE = [
    "paragraph-style",
    "character-style",
    "table-layout",
    "cell-format",
    "slide-layout",
]
EXPECTED_CONTENT_REVIEW_SCOPE = [
    "selection",
    "document-section",
    "connector-result",
    "knowledge-index-result",
    "evidence-record",
    "task-step",
]
EXPECTED_REVIEW_QUEUE_TYPES = [
    "content-review",
    "formatting-review",
    "task-step",
]
EXPECTED_REVIEW_QUEUE_STATES = [
    "queued",
    "open",
    "approved",
    "rejected",
    "applied",
    "failed",
]
EXPECTED_REVIEW_QUEUE_FILTERS = [
    "state",
    "type",
    "surface",
]
EXPECTED_REVIEW_QUEUE_BULK_ACTIONS = [
    "approve-selected",
    "reject-selected",
]
EXPECTED_EVIDENCE_INSPECTOR_SOURCE_TYPES = [
    "evidence-record",
    "connector-result",
    "knowledge-index-result",
    "task-step",
    "review-item",
]
EXPECTED_INTERACTION_PANELS = [
    "chat",
    "tasks",
    "artifacts",
    "reviews",
    "evidence",
]
EXPECTED_INTERACTION_TAB_ORDER = [
    "composer",
    "panel-tabs",
    "active-panel",
    "review-actions",
]
EXPECTED_PREVIEW_MATRIX_TYPES = [
    "document",
    "selection",
    "connector-result",
    "knowledge-index-result",
    "evidence-record",
    "task-step",
    "review-item",
]
EXPECTED_PREVIEW_MATRIX_TARGETS = {
    "document": "main-document-window",
    "selection": "sidebar-preview",
    "connector-result": "sidebar-preview",
    "knowledge-index-result": "sidebar-preview",
    "evidence-record": "sidebar-preview",
    "task-step": "diff-review",
    "review-item": "diff-review",
}
EXPECTED_PREVIEW_MATRIX_MODES = [
    "metadata-summary",
    "read-only-preview",
    "diff-preview",
    "evidence-summary",
]
EXPECTED_ACTION_BAR_COMMANDS = [
    "open-preview",
    "open-diff-review",
    "approve-selected",
    "reject-selected",
    "copy-reference",
    "export-evidence",
    "filter",
    "sort",
    "retry",
    "cancel",
]
EXPECTED_ACTION_BAR_TARGETS = [
    "task-step",
    "review-item",
    "artifact",
    "evidence-record",
    "preview",
]
EXPECTED_FILTER_SEARCH_SURFACES = [
    "tasks",
    "artifacts",
    "reviews",
    "evidence",
    "previews",
]
EXPECTED_FILTER_SEARCH_FILTERS = [
    "state",
    "type",
    "surface",
    "source",
    "evidence-status",
]
EXPECTED_FILTER_SEARCH_FIELDS = [
    "id",
    "type",
    "state",
    "source-metadata",
    "evidence-id",
    "hash-reference",
]
EXPECTED_CONTEXT_HANDOFF_ENTRY_SURFACES = [
    "filter-search-result",
    "artifact-navigator-item",
    "review-queue-item",
    "evidence-inspector-link",
    "preview-matrix-item",
    "action-bar-command",
]
EXPECTED_CONTEXT_HANDOFF_TARGETS = [
    "preview",
    "diff-review",
    "evidence-inspector",
    "review-queue",
    "task-progress",
    "composer",
]
EXPECTED_CONTEXT_HANDOFF_PRESERVES = [
    "active-task-id",
    "source-surface",
    "evidence-id",
    "hash-reference",
    "preview-mode",
    "review-state",
]
EXPECTED_REVIEW_STATE_SYNC_SURFACES = [
    "review-queue",
    "diff-review",
    "preview-matrix",
    "evidence-inspector",
    "task-progress",
    "action-bar",
]
EXPECTED_REVIEW_STATE_SYNC_TRANSITIONS = [
    "open",
    "approve",
    "reject",
    "apply",
    "fail",
]
EXPECTED_ACTIVITY_TIMELINE_EVENTS = [
    "chat-requested",
    "task-started",
    "artifact-created",
    "content-opened",
    "review-opened",
    "review-state-changed",
    "evidence-linked",
    "action-invoked",
    "failure-reported",
]
EXPECTED_ACTIVITY_TIMELINE_SURFACES = [
    "chat",
    "tasks",
    "artifacts",
    "reviews",
    "evidence",
    "previews",
    "action-bar",
]
EXPECTED_ACTIVITY_TIMELINE_LINKS = [
    "task-id",
    "artifact-id",
    "review-id",
    "evidence-id",
    "hash-reference",
]
EXPECTED_SESSION_SNAPSHOT_RESTORES = [
    "active-task-id",
    "open-artifact-id",
    "open-review-id",
    "active-evidence-id",
    "preview-mode",
    "review-state",
    "activity-cursor",
    "failure-state",
]
EXPECTED_SESSION_SNAPSHOT_SURFACES = [
    "chat",
    "tasks",
    "artifacts",
    "reviews",
    "evidence",
    "previews",
    "activity-timeline",
]
EXPECTED_ATTENTION_ROUTING_TRIGGERS = [
    "approval-required",
    "review-ready",
    "task-failed",
    "evidence-missing",
    "resume-available",
]
EXPECTED_ATTENTION_ROUTING_SURFACES = [
    "sidebar-badge",
    "tab-badge",
    "task-row-highlight",
    "review-queue-badge",
    "activity-timeline-event",
    "resume-banner",
]
EXPECTED_ATTENTION_ROUTING_TARGETS = [
    "task-progress",
    "review-queue",
    "diff-review",
    "evidence-inspector",
    "activity-timeline",
    "session-snapshot",
]
EXPECTED_NATIVE_STYLE_STABLE_DIMENSIONS = [
    "toolbar-buttons",
    "tab-badges",
    "task-rows",
    "review-rows",
    "evidence-rows",
    "preview-tiles",
]
EXPECTED_NATIVE_STYLE_SURFACES = [
    "composer",
    "panel-tabs",
    "task-rail",
    "artifact-rail",
    "review-queue",
    "evidence-inspector",
    "preview-matrix",
    "action-bar",
]
EXPECTED_WORKSPACE_UI = {
    "shell": "ai-workspace-sidebar",
    "container": "sfx2-sidebar",
    "interactionModel": "conversation-plus-progress",
    "conversationPanelVisible": True,
    "taskProgress": {
        "visible": True,
        "states": EXPECTED_WORKSPACE_STATES,
        "stepListVisible": True,
        "evidenceLinksVisible": True,
    },
    "reviewSurface": {
        "visible": True,
        "supportsContentReview": True,
        "supportsFormattingReview": True,
        "usesDiffReview": True,
        "requiresEvidenceLink": True,
    },
    "contentReview": {
        "scope": EXPECTED_CONTENT_REVIEW_SCOPE,
        "reviewMode": "evidence-linked-content-diff",
        "visible": True,
        "usesDiffReview": True,
        "requiresEvidenceLink": True,
        "requiresHumanApproval": True,
        "mainDocumentUnchangedUntilApproval": True,
        "rawContentInFixture": False,
        "suggestionContentInFixture": False,
        "failureBehavior": "fail-closed-user-visible",
        "runtimeContentReviewImplementation": "not-started",
    },
    "layoutPreview": {
        "visible": True,
        "mode": "before-after-preview",
        "surfaces": ["writer", "calc", "impress"],
        "mainDocumentUnchangedUntilApproval": True,
    },
    "formattingReview": {
        "scope": EXPECTED_FORMATTING_REVIEW_SCOPE,
        "reviewMode": "before-after-layout-diff",
        "visible": True,
        "usesDiffReview": True,
        "requiresEvidenceLink": True,
        "requiresHumanApproval": True,
        "mainDocumentUnchangedUntilApproval": True,
        "rawContentInFixture": False,
        "previewContentInFixture": False,
        "failureBehavior": "fail-closed-user-visible",
        "runtimeFormattingImplementation": "not-started",
    },
    "contentOpeners": {
        "supportedTypes": EXPECTED_WORKSPACE_CONTENT_TYPES,
        "opensIn": EXPECTED_WORKSPACE_OPEN_TARGETS,
        "routePolicy": EXPECTED_WORKSPACE_ROUTE_POLICY,
        "requiresEvidenceLink": True,
        "readOnlyPreview": True,
        "mainDocumentMutationAllowed": False,
        "rawContentInFixture": False,
        "openFailureBehavior": "fail-closed-user-visible",
        "runtimeOpenImplementation": "not-started",
    },
    "contentRegistry": {
        "visible": True,
        "scope": ["current-workspace", "current-document"],
        "types": EXPECTED_CONTENT_REGISTRY_TYPES,
        "states": EXPECTED_CONTENT_REGISTRY_STATES,
        "requiredFields": EXPECTED_CONTENT_REGISTRY_FIELDS,
        "openTargets": EXPECTED_CONTENT_REGISTRY_OPEN_TARGETS,
        "previewModes": EXPECTED_PREVIEW_MATRIX_MODES,
        "usesContentOpeners": True,
        "usesPreviewMatrix": True,
        "usesEvidenceInspector": True,
        "usesReviewQueue": True,
        "metadataOnly": True,
        "hashOnlyReferences": True,
        "redactsRawPayload": True,
        "rawContentInFixture": False,
        "previewContentInFixture": False,
        "transcriptContentInFixture": False,
        "mainDocumentMutationAllowed": False,
        "autoOpenAllowed": False,
        "autoApplyAllowed": False,
        "failureBehavior": "fail-closed-user-visible",
        "runtimeContentRegistryImplementation": "not-started",
    },
    "sourceProvenance": {
        "visible": True,
        "scope": ["current-workspace", "current-document"],
        "sourceTypes": EXPECTED_SOURCE_PROVENANCE_SOURCE_TYPES,
        "requiredFields": EXPECTED_SOURCE_PROVENANCE_REQUIRED_FIELDS,
        "surfaces": EXPECTED_SOURCE_PROVENANCE_SURFACES,
        "citationTargets": EXPECTED_CONTENT_REGISTRY_OPEN_TARGETS,
        "mapsAiClaimsToSources": True,
        "mapsSuggestionsToEvidence": True,
        "mapsFormattingChangesToStyleSources": True,
        "requiresEvidenceLink": True,
        "requiresOpenTarget": True,
        "requiresVisibleCitationBadge": True,
        "usesContentRegistry": True,
        "usesContentOpeners": True,
        "usesEvidenceInspector": True,
        "usesReviewQueue": True,
        "usesDiffReview": True,
        "metadataOnly": True,
        "hashOnlyReferences": True,
        "redactsRawPayload": True,
        "rawContentInFixture": False,
        "sourceContentInFixture": False,
        "previewContentInFixture": False,
        "transcriptContentInFixture": False,
        "mainDocumentMutationAllowed": False,
        "autoOpenAllowed": False,
        "autoApplyAllowed": False,
        "failureBehavior": "fail-closed-user-visible",
        "runtimeSourceProvenanceImplementation": "not-started",
    },
    "clipboardMaterialization": {
        "visible": True,
        "scope": ["chat-composer", "current-workspace", "current-document"],
        "materializesInputTypes": EXPECTED_CLIPBOARD_MATERIALIZATION_INPUT_TYPES,
        "thresholdPolicy": "large-or-structured-content",
        "storage": "local-temp-content-object",
        "referenceInsertedIntoChat": True,
        "transcriptStoresReferenceOnly": True,
        "historyStoresReferenceOnly": True,
        "preservesFormattingMetadata": True,
        "usesContentRegistry": True,
        "usesArtifactNavigator": True,
        "usesContentOpeners": True,
        "usesSourceProvenance": True,
        "requiresHashReference": True,
        "requiresEvidenceLink": True,
        "rawClipboardContentInFixture": False,
        "rawContentInTranscript": False,
        "rawContentInHistory": False,
        "mainDocumentMutationAllowed": False,
        "autoApplyAllowed": False,
        "failureBehavior": "fail-closed-user-visible",
        "runtimeClipboardMaterializationImplementation": "not-started",
    },
    "artifactNavigator": {
        "visible": True,
        "scope": ["current-workspace", "current-document"],
        "managedTypes": EXPECTED_WORKSPACE_CONTENT_TYPES,
        "groupBy": ["type", "task"],
        "sort": "recent-first",
        "evidenceBadgeVisible": True,
        "openUsesContentOpeners": True,
        "readOnlyDetails": True,
        "rawContentInFixture": False,
        "mainDocumentMutationAllowed": False,
        "failureBehavior": "fail-closed-user-visible",
        "runtimeArtifactNavigatorImplementation": "not-started",
    },
    "reviewQueue": {
        "visible": True,
        "itemTypes": EXPECTED_REVIEW_QUEUE_TYPES,
        "states": EXPECTED_REVIEW_QUEUE_STATES,
        "filterBy": EXPECTED_REVIEW_QUEUE_FILTERS,
        "openUsesDiffReview": True,
        "requiresEvidenceLink": True,
        "bulkActions": EXPECTED_REVIEW_QUEUE_BULK_ACTIONS,
        "bulkApplyRequiresExplicitHumanApproval": True,
        "mainDocumentMutationAllowed": False,
        "rawContentInFixture": False,
        "failureBehavior": "fail-closed-user-visible",
        "runtimeReviewQueueImplementation": "not-started",
    },
    "evidenceInspector": {
        "visible": True,
        "sourceTypes": EXPECTED_EVIDENCE_INSPECTOR_SOURCE_TYPES,
        "showsCitationLinks": True,
        "showsAuditTrail": True,
        "openUsesContentOpeners": True,
        "redactsRawPayload": True,
        "hashOnlyReferences": True,
        "requiresEvidenceLink": True,
        "rawContentInFixture": False,
        "mainDocumentMutationAllowed": False,
        "failureBehavior": "fail-closed-user-visible",
        "runtimeEvidenceInspectorImplementation": "not-started",
    },
    "interactionChrome": {
        "layout": "sidebar-workbench",
        "navigation": "segmented-tabs",
        "panels": EXPECTED_INTERACTION_PANELS,
        "defaultPanel": "chat",
        "persistentComposer": True,
        "taskRailVisible": True,
        "artifactRailVisible": True,
        "reviewRailVisible": True,
        "evidenceRailVisible": True,
        "keyboardNavigation": {
            "tabOrder": EXPECTED_INTERACTION_TAB_ORDER,
            "escapeReturnsFocus": True,
            "focusTrap": False,
        },
        "density": "compact-utility",
        "usesNativeControls": True,
        "modalChatOnly": False,
        "rawContentInFixture": False,
        "failureBehavior": "fail-closed-user-visible",
        "runtimeInteractionChromeImplementation": "not-started",
    },
    "previewMatrix": {
        "visible": True,
        "contentTypes": EXPECTED_PREVIEW_MATRIX_TYPES,
        "previewTargets": EXPECTED_PREVIEW_MATRIX_TARGETS,
        "previewModes": EXPECTED_PREVIEW_MATRIX_MODES,
        "showsEvidenceBadge": True,
        "showsSourceMetadata": True,
        "openUsesContentOpeners": True,
        "readOnlyPreview": True,
        "redactsRawPayload": True,
        "hashOnlyReferences": True,
        "rawContentInFixture": False,
        "previewContentInFixture": False,
        "mainDocumentMutationAllowed": False,
        "failureBehavior": "fail-closed-user-visible",
        "runtimePreviewMatrixImplementation": "not-started",
    },
    "actionBar": {
        "visible": True,
        "placement": "sidebar-workbench-header",
        "commands": EXPECTED_ACTION_BAR_COMMANDS,
        "commandTargets": EXPECTED_ACTION_BAR_TARGETS,
        "keyboardAccessible": True,
        "usesNativeControls": True,
        "requiresVisibleState": True,
        "requiresEvidenceLink": True,
        "usesContentOpeners": True,
        "usesDiffReview": True,
        "bulkApplyRequiresExplicitHumanApproval": True,
        "autoApplyAllowed": False,
        "hiddenActionsAllowed": False,
        "mouseOnlyActionsAllowed": False,
        "rawContentInFixture": False,
        "mainDocumentMutationAllowed": False,
        "failureBehavior": "fail-closed-user-visible",
        "runtimeActionBarImplementation": "not-started",
    },
    "filterSearch": {
        "visible": True,
        "scope": ["current-workspace", "current-document"],
        "surfaces": EXPECTED_FILTER_SEARCH_SURFACES,
        "filterBy": EXPECTED_FILTER_SEARCH_FILTERS,
        "searchFields": EXPECTED_FILTER_SEARCH_FIELDS,
        "sortOptions": ["recent-first", "type", "state", "source"],
        "metadataOnly": True,
        "hashOnlyReferences": True,
        "redactsRawPayload": True,
        "rawContentIndexed": False,
        "rawContentInFixture": False,
        "crossDocumentSearch": False,
        "globalIndex": False,
        "usesContentOpeners": True,
        "requiresEvidenceLink": True,
        "failureBehavior": "fail-closed-user-visible",
        "runtimeFilterSearchImplementation": "not-started",
    },
    "contextHandoff": {
        "visible": True,
        "entrySurfaces": EXPECTED_CONTEXT_HANDOFF_ENTRY_SURFACES,
        "handoffTargets": EXPECTED_CONTEXT_HANDOFF_TARGETS,
        "preserves": EXPECTED_CONTEXT_HANDOFF_PRESERVES,
        "requiresVisibleBreadcrumb": True,
        "requiresBackNavigation": True,
        "requiresFocusReturn": True,
        "requiresEvidenceLink": True,
        "usesContentOpeners": True,
        "usesDiffReview": True,
        "metadataOnly": True,
        "hashOnlyReferences": True,
        "redactsRawPayload": True,
        "rawContentInFixture": False,
        "previewContentInFixture": False,
        "mainDocumentMutationAllowed": False,
        "autoApplyAllowed": False,
        "failureBehavior": "fail-closed-user-visible",
        "runtimeContextHandoffImplementation": "not-started",
    },
    "reviewStateSync": {
        "visible": True,
        "stateSources": EXPECTED_REVIEW_STATE_SYNC_SURFACES,
        "states": EXPECTED_REVIEW_QUEUE_STATES,
        "syncTargets": EXPECTED_REVIEW_STATE_SYNC_SURFACES,
        "transitionEvents": EXPECTED_REVIEW_STATE_SYNC_TRANSITIONS,
        "requiresEvidenceLink": True,
        "requiresVisibleState": True,
        "requiresHumanApproval": True,
        "bulkApplyRequiresExplicitHumanApproval": True,
        "usesDiffReview": True,
        "usesContentOpeners": True,
        "metadataOnly": True,
        "hashOnlyReferences": True,
        "redactsRawPayload": True,
        "rawContentInFixture": False,
        "mainDocumentMutationAllowed": False,
        "autoApplyAllowed": False,
        "conflictBehavior": "fail-closed-user-visible",
        "failureBehavior": "fail-closed-user-visible",
        "runtimeReviewStateSyncImplementation": "not-started",
    },
    "activityTimeline": {
        "visible": True,
        "events": EXPECTED_ACTIVITY_TIMELINE_EVENTS,
        "surfaces": EXPECTED_ACTIVITY_TIMELINE_SURFACES,
        "links": EXPECTED_ACTIVITY_TIMELINE_LINKS,
        "order": "chronological",
        "appendOnly": True,
        "requiresEvidenceLink": True,
        "requiresVisibleTimestamp": True,
        "requiresVisibleActor": True,
        "requiresOpenTarget": True,
        "usesContentOpeners": True,
        "usesDiffReview": True,
        "usesEvidenceInspector": True,
        "metadataOnly": True,
        "hashOnlyReferences": True,
        "redactsRawPayload": True,
        "rawContentInFixture": False,
        "previewContentInFixture": False,
        "transcriptContentInFixture": False,
        "mainDocumentMutationAllowed": False,
        "autoApplyAllowed": False,
        "failureBehavior": "fail-closed-user-visible",
        "runtimeActivityTimelineImplementation": "not-started",
    },
    "sessionSnapshot": {
        "visible": True,
        "scope": ["current-workspace", "current-document"],
        "restores": EXPECTED_SESSION_SNAPSHOT_RESTORES,
        "surfaces": EXPECTED_SESSION_SNAPSHOT_SURFACES,
        "resumeSummaryVisible": True,
        "requiresExplicitResume": True,
        "requiresVisibleTimestamp": True,
        "requiresVisibleDocumentBinding": True,
        "usesContentOpeners": True,
        "usesDiffReview": True,
        "usesEvidenceInspector": True,
        "usesActivityTimeline": True,
        "metadataOnly": True,
        "hashOnlyReferences": True,
        "redactsRawPayload": True,
        "rawContentInFixture": False,
        "previewContentInFixture": False,
        "transcriptContentInFixture": False,
        "crossDocumentRestore": False,
        "cloudSync": False,
        "mainDocumentMutationAllowed": False,
        "autoApplyAllowed": False,
        "failureBehavior": "fail-closed-user-visible",
        "runtimeSessionSnapshotImplementation": "not-started",
    },
    "attentionRouting": {
        "visible": True,
        "scope": ["current-workspace", "current-document"],
        "triggers": EXPECTED_ATTENTION_ROUTING_TRIGGERS,
        "surfaces": EXPECTED_ATTENTION_ROUTING_SURFACES,
        "routesTo": EXPECTED_ATTENTION_ROUTING_TARGETS,
        "requiresOpenTarget": True,
        "requiresVisibleReason": True,
        "requiresVisibleTimestamp": True,
        "requiresKeyboardAccess": True,
        "usesNativeControls": True,
        "usesActionBar": True,
        "usesActivityTimeline": True,
        "usesSessionSnapshot": True,
        "usesEvidenceInspector": True,
        "usesDiffReview": True,
        "metadataOnly": True,
        "hashOnlyReferences": True,
        "redactsRawPayload": True,
        "rawContentInFixture": False,
        "previewContentInFixture": False,
        "transcriptContentInFixture": False,
        "systemNotificationRuntime": "not-started",
        "cloudPush": False,
        "autoOpenAllowed": False,
        "autoApplyAllowed": False,
        "mainDocumentMutationAllowed": False,
        "failureBehavior": "fail-closed-user-visible",
        "runtimeAttentionRoutingImplementation": "not-started",
    },
    "nativeStyle": {
        "layout": "sidebar-workbench",
        "density": "compact-utility",
        "surfaces": EXPECTED_NATIVE_STYLE_SURFACES,
        "navigation": "segmented-tabs",
        "usesNativeControls": True,
        "stableDimensions": EXPECTED_NATIVE_STYLE_STABLE_DIMENSIONS,
        "textOverflowPolicy": "wrap-or-ellipsize-no-overlap",
        "cardPileLayout": False,
        "modalOnly": False,
        "marketingHero": False,
        "keyboardAccessible": True,
        "focusReturn": True,
        "metadataOnly": True,
        "rawContentInFixture": False,
        "previewContentInFixture": False,
        "transcriptContentInFixture": False,
        "mainDocumentMutationAllowed": False,
        "autoApplyAllowed": False,
        "failureBehavior": "fail-closed-user-visible",
        "runtimeNativeStyleImplementation": "not-started",
    },
    "stylePolicy": {
        "denseUtilityUi": True,
        "usesNativeControls": True,
        "modalChatOnly": False,
    },
}
EXPECTED_ACTION_BY_SURFACE = {
    "writer": "ParagraphAction",
    "calc": "CellAction",
    "impress": "SlideElementAction",
}
CONNECTOR_MENTION = re.compile(r"^@connector:[a-z0-9-]+$")


def die(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def load(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        die(f"{path} top-level must be an object")
    return value


def semantic_errors(value: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    scenario_type = value.get("scenarioType")
    surface = value.get("surface")
    entry = value.get("entry", {})
    context = value.get("context", {})
    mentions_ui = value.get("mentionsUi", {})
    history = value.get("history", {})
    streaming_ui = value.get("streamingUi", {})
    workspace_ui = value.get("workspaceUi", {})
    provider = value.get("provider", {})
    output = value.get("output", {})
    approval = value.get("approval", {})
    evidence = value.get("evidence", {})
    gates = value.get("gates", {})

    required = [
        "id",
        "schemaVersion",
        "scenarioType",
        "surface",
        "entry",
        "context",
        "mentionsUi",
        "history",
        "streamingUi",
        "workspaceUi",
        "provider",
        "output",
        "approval",
        "evidence",
        "gates",
    ]
    for key in required:
        if key not in value:
            errors.append(f"missing required key {key}")

    if value.get("schemaVersion") != 1:
        errors.append("schemaVersion must stay at fixture contract version 1")
    if "declaredSchema" in value or value.get("usesNewChatSchema") is True:
        errors.append("W1 must not introduce a new chat schema")
    if scenario_type not in {"document-chat", "connector-context"}:
        errors.append("scenarioType must be document-chat or connector-context")
    if surface not in EXPECTED_ACTION_BY_SURFACE:
        errors.append("surface must be writer/calc/impress")

    if not isinstance(entry, dict):
        errors.append("entry must be object")
    else:
        if entry.get("shortcut") != "Cmd+Shift+K":
            errors.append("entry shortcut must be Cmd+Shift+K")
        if entry.get("route") != "command-palette-chat-fallback":
            errors.append("entry route must be command-palette-chat-fallback")
        if entry.get("container") != "sfx2-sidebar":
            errors.append("entry container must be sfx2-sidebar")
        if entry.get("directAcceleratorRegistration") is not False:
            errors.append("W1 must not register a direct chat accelerator")
        if entry.get("standaloneApp") is not False:
            errors.append("W1 must not become a standalone chat app")

    if not isinstance(context, dict):
        errors.append("context must be object")
    else:
        if context.get("defaultScope") != "none":
            errors.append("default context scope must be none")
        if context.get("historyScope") != "per-doc-local":
            errors.append("chat history must be per-doc local")
        if context.get("storesCloudHistory") is not False:
            errors.append("chat history must not be stored in cloud")
        explicit = context.get("explicitMentions", [])
        if not isinstance(explicit, list) or not explicit:
            errors.append("context must require explicit @ mentions")
        else:
            for mention in explicit:
                if not isinstance(mention, str):
                    errors.append("context mention must be a string")
                elif mention not in {"@selection", "@doc"} and CONNECTOR_MENTION.fullmatch(mention) is None:
                    errors.append(f"unsupported context mention {mention}")

    if not isinstance(mentions_ui, dict):
        errors.append("mentionsUi must be object")
    else:
        if mentions_ui.get("trigger") != "@":
            errors.append("mentions UI trigger must be @")
        if mentions_ui.get("scope") != "chat-input-only":
            errors.append("mentions UI must stay scoped to the chat input")
        if mentions_ui.get("suggestions") != EXPECTED_MENTIONS_UI["suggestions"]:
            errors.append("mentions UI suggestion roster drifted")
        if mentions_ui.get("officeAutocompletePolicy") != "delegate-existing-controls":
            errors.append("mentions UI must delegate existing Office autocomplete controls")
        if mentions_ui.get("hijacksGlobalAutocomplete") is not False:
            errors.append("mentions UI must not hijack global Office autocomplete")
        if mentions_ui.get("requiresExplicitCommit") is not True:
            errors.append("mentions UI must require explicit commit")
        if mentions_ui.get("connectorSuggestionsRequireW2Manifest") is not True:
            errors.append("connector suggestions must require W2 manifest")
        if mentions_ui.get("unknownConnectorSuggestions") is not False:
            errors.append("mentions UI must not suggest unknown connectors")
        if mentions_ui.get("rawPreviewContent") is not False:
            errors.append("mentions UI must not preview raw context content")
        if mentions_ui.get("rawContentInFixture") is not False:
            errors.append("fixtures must not store raw context preview content")
        if mentions_ui.get("runtimeParserImplementation") != "not-started":
            errors.append("mentions UI parser/runtime implementation must stay not-started")

    if not isinstance(history, dict):
        errors.append("history must be object")
    else:
        if history.get("scope") != "per-doc-local":
            errors.append("chat history scope must be per-doc-local")
        if history.get("storage") != "local-sqlite-sidecar":
            errors.append("chat history storage must be local-sqlite-sidecar")
        if history.get("documentBinding") != "document-id-hash":
            errors.append("chat history must bind to a document-id hash")
        if history.get("cloudSync") is not False:
            errors.append("chat history must not cloud-sync")
        if history.get("globalIndex") is not False:
            errors.append("chat history must not enter a global index")
        if history.get("crossDocumentRestore") is not False:
            errors.append("chat history must not restore across documents")
        if history.get("rawContentInFixture") is not False:
            errors.append("fixtures must not store raw chat/document content")
        if history.get("requiresUserClearControl") is not True:
            errors.append("chat history must expose a user clear control")
        if history.get("deleteWithDocument") is not True:
            errors.append("chat history must be deleted with the document")

    if not isinstance(streaming_ui, dict):
        errors.append("streamingUi must be object")
    else:
        if streaming_ui.get("source") != "v2-provider-chunk":
            errors.append("streaming UI must use V2 provider chunk source")
        if streaming_ui.get("states") != EXPECTED_STREAMING_STATES:
            errors.append("streaming UI states drifted")
        if streaming_ui.get("appendOnlyDuringStream") is not True:
            errors.append("streaming UI must append chunks without rewriting prior chunks")
        if streaming_ui.get("mainDocumentUnchangedWhileStreaming") is not True:
            errors.append("main document must stay unchanged while streaming")
        if streaming_ui.get("cancelSupported") is not True:
            errors.append("streaming UI must support cancel")
        if streaming_ui.get("retrySupported") is not True:
            errors.append("streaming UI must support retry")
        if streaming_ui.get("partialChunksPersisted") is not False:
            errors.append("partial chunks must not be persisted")
        if streaming_ui.get("chunkContentInFixture") is not False:
            errors.append("fixtures must not store chunk content")
        if streaming_ui.get("evidenceOnTerminalState") is not True:
            errors.append("terminal streaming states must emit evidence")

    if not isinstance(workspace_ui, dict):
        errors.append("workspaceUi must be object")
    else:
        if workspace_ui.get("shell") != "ai-workspace-sidebar":
            errors.append("AI workspace must use the sidebar shell")
        if workspace_ui.get("container") != "sfx2-sidebar":
            errors.append("AI workspace must stay in the sfx2 sidebar container")
        if workspace_ui.get("interactionModel") != "conversation-plus-progress":
            errors.append("AI workspace must combine conversation and task progress")
        if workspace_ui.get("conversationPanelVisible") is not True:
            errors.append("conversation panel must be visible")
        task_progress = workspace_ui.get("taskProgress")
        if not isinstance(task_progress, dict):
            errors.append("workspace taskProgress must be object")
        else:
            if task_progress.get("visible") is not True:
                errors.append("workspace task progress must be visible")
            if task_progress.get("states") != EXPECTED_WORKSPACE_STATES:
                errors.append("workspace task progress state roster drifted")
            if task_progress.get("stepListVisible") is not True:
                errors.append("workspace task steps must be visible")
            if task_progress.get("evidenceLinksVisible") is not True:
                errors.append("workspace task progress must show evidence links")
        review_surface = workspace_ui.get("reviewSurface")
        if not isinstance(review_surface, dict):
            errors.append("workspace reviewSurface must be object")
        else:
            if review_surface.get("visible") is not True:
                errors.append("workspace review surface must be visible")
            if review_surface.get("supportsContentReview") is not True:
                errors.append("workspace must support content review")
            if review_surface.get("supportsFormattingReview") is not True:
                errors.append("workspace must support formatting review")
            if review_surface.get("usesDiffReview") is not True:
                errors.append("workspace review must reuse DiffReview")
            if review_surface.get("requiresEvidenceLink") is not True:
                errors.append("workspace review must link evidence")
        content_review = workspace_ui.get("contentReview")
        if not isinstance(content_review, dict):
            errors.append("workspace contentReview must be object")
        else:
            if content_review.get("scope") != EXPECTED_CONTENT_REVIEW_SCOPE:
                errors.append("workspace content review scope roster drifted")
            if content_review.get("reviewMode") != "evidence-linked-content-diff":
                errors.append("workspace content review must use evidence-linked-content-diff")
            if content_review.get("visible") is not True:
                errors.append("workspace content review must be visible")
            if content_review.get("usesDiffReview") is not True:
                errors.append("workspace content review must reuse DiffReview")
            if content_review.get("requiresEvidenceLink") is not True:
                errors.append("workspace content review must link evidence")
            if content_review.get("requiresHumanApproval") is not True:
                errors.append("workspace content review must require human approval")
            if content_review.get("mainDocumentUnchangedUntilApproval") is not True:
                errors.append("workspace content review must not mutate main document before approval")
            if content_review.get("rawContentInFixture") is not False:
                errors.append("workspace content review fixtures must not store raw content")
            if content_review.get("suggestionContentInFixture") is not False:
                errors.append("workspace content review fixtures must not store suggestion content")
            if content_review.get("failureBehavior") != "fail-closed-user-visible":
                errors.append("workspace content review failure behavior drifted")
            if content_review.get("runtimeContentReviewImplementation") != "not-started":
                errors.append("workspace content review runtime must stay not-started")
        layout_preview = workspace_ui.get("layoutPreview")
        if not isinstance(layout_preview, dict):
            errors.append("workspace layoutPreview must be object")
        else:
            if layout_preview.get("visible") is not True:
                errors.append("workspace layout preview must be visible")
            if layout_preview.get("mode") != "before-after-preview":
                errors.append("workspace layout preview must use before-after-preview mode")
            if layout_preview.get("surfaces") != ["writer", "calc", "impress"]:
                errors.append("workspace layout preview surface roster drifted")
            if layout_preview.get("mainDocumentUnchangedUntilApproval") is not True:
                errors.append("workspace layout preview must not mutate main document before approval")
        formatting_review = workspace_ui.get("formattingReview")
        if not isinstance(formatting_review, dict):
            errors.append("workspace formattingReview must be object")
        else:
            if formatting_review.get("scope") != EXPECTED_FORMATTING_REVIEW_SCOPE:
                errors.append("workspace formatting review scope roster drifted")
            if formatting_review.get("reviewMode") != "before-after-layout-diff":
                errors.append("workspace formatting review must use before-after-layout-diff")
            if formatting_review.get("visible") is not True:
                errors.append("workspace formatting review must be visible")
            if formatting_review.get("usesDiffReview") is not True:
                errors.append("workspace formatting review must reuse DiffReview")
            if formatting_review.get("requiresEvidenceLink") is not True:
                errors.append("workspace formatting review must link evidence")
            if formatting_review.get("requiresHumanApproval") is not True:
                errors.append("workspace formatting review must require human approval")
            if formatting_review.get("mainDocumentUnchangedUntilApproval") is not True:
                errors.append("workspace formatting review must not mutate main document before approval")
            if formatting_review.get("rawContentInFixture") is not False:
                errors.append("workspace formatting review fixtures must not store raw content")
            if formatting_review.get("previewContentInFixture") is not False:
                errors.append("workspace formatting review fixtures must not store preview content")
            if formatting_review.get("failureBehavior") != "fail-closed-user-visible":
                errors.append("workspace formatting review failure behavior drifted")
            if formatting_review.get("runtimeFormattingImplementation") != "not-started":
                errors.append("workspace formatting review runtime must stay not-started")
        content_openers = workspace_ui.get("contentOpeners")
        if not isinstance(content_openers, dict):
            errors.append("workspace contentOpeners must be object")
        else:
            if content_openers.get("supportedTypes") != EXPECTED_WORKSPACE_CONTENT_TYPES:
                errors.append("workspace content opener type roster drifted")
            if content_openers.get("opensIn") != EXPECTED_WORKSPACE_OPEN_TARGETS:
                errors.append("workspace content opener target roster drifted")
            if content_openers.get("routePolicy") != EXPECTED_WORKSPACE_ROUTE_POLICY:
                errors.append("workspace content opener route policy drifted")
            if content_openers.get("requiresEvidenceLink") is not True:
                errors.append("workspace content openers must require evidence links")
            if content_openers.get("readOnlyPreview") is not True:
                errors.append("workspace content opener preview must be read-only")
            if content_openers.get("mainDocumentMutationAllowed") is not False:
                errors.append("workspace content openers must not mutate the main document")
            if content_openers.get("rawContentInFixture") is not False:
                errors.append("workspace opener fixtures must not store raw content")
            if content_openers.get("openFailureBehavior") != "fail-closed-user-visible":
                errors.append("workspace content opener failures must be fail-closed and visible")
            if content_openers.get("runtimeOpenImplementation") != "not-started":
                errors.append("workspace opener runtime must stay not-started")
        content_registry = workspace_ui.get("contentRegistry")
        if not isinstance(content_registry, dict):
            errors.append("workspace contentRegistry must be object")
        else:
            if content_registry.get("visible") is not True:
                errors.append("workspace content registry must be visible")
            if content_registry.get("scope") != ["current-workspace", "current-document"]:
                errors.append("workspace content registry scope drifted")
            if content_registry.get("types") != EXPECTED_CONTENT_REGISTRY_TYPES:
                errors.append("workspace content registry type roster drifted")
            if content_registry.get("states") != EXPECTED_CONTENT_REGISTRY_STATES:
                errors.append("workspace content registry state roster drifted")
            if content_registry.get("requiredFields") != EXPECTED_CONTENT_REGISTRY_FIELDS:
                errors.append("workspace content registry required field roster drifted")
            if content_registry.get("openTargets") != EXPECTED_CONTENT_REGISTRY_OPEN_TARGETS:
                errors.append("workspace content registry open target roster drifted")
            if content_registry.get("previewModes") != EXPECTED_PREVIEW_MATRIX_MODES:
                errors.append("workspace content registry preview mode roster drifted")
            if content_registry.get("usesContentOpeners") is not True:
                errors.append("workspace content registry must use content openers")
            if content_registry.get("usesPreviewMatrix") is not True:
                errors.append("workspace content registry must use preview matrix")
            if content_registry.get("usesEvidenceInspector") is not True:
                errors.append("workspace content registry must use evidence inspector")
            if content_registry.get("usesReviewQueue") is not True:
                errors.append("workspace content registry must use review queue")
            if content_registry.get("metadataOnly") is not True:
                errors.append("workspace content registry must be metadata-only")
            if content_registry.get("hashOnlyReferences") is not True:
                errors.append("workspace content registry must use hash-only references")
            if content_registry.get("redactsRawPayload") is not True:
                errors.append("workspace content registry must redact raw payloads")
            if content_registry.get("rawContentInFixture") is not False:
                errors.append("workspace content registry fixtures must not store raw content")
            if content_registry.get("previewContentInFixture") is not False:
                errors.append("workspace content registry fixtures must not store preview content")
            if content_registry.get("transcriptContentInFixture") is not False:
                errors.append("workspace content registry fixtures must not store transcript content")
            if content_registry.get("mainDocumentMutationAllowed") is not False:
                errors.append("workspace content registry must not mutate the main document")
            if content_registry.get("autoOpenAllowed") is not False:
                errors.append("workspace content registry must not auto-open objects")
            if content_registry.get("autoApplyAllowed") is not False:
                errors.append("workspace content registry must not auto-apply objects")
            if content_registry.get("failureBehavior") != "fail-closed-user-visible":
                errors.append("workspace content registry failure behavior drifted")
            if content_registry.get("runtimeContentRegistryImplementation") != "not-started":
                errors.append("workspace content registry runtime must stay not-started")
        source_provenance = workspace_ui.get("sourceProvenance")
        if not isinstance(source_provenance, dict):
            errors.append("workspace sourceProvenance must be object")
        else:
            if source_provenance.get("visible") is not True:
                errors.append("workspace source provenance must be visible")
            if source_provenance.get("scope") != ["current-workspace", "current-document"]:
                errors.append("workspace source provenance scope drifted")
            if source_provenance.get("sourceTypes") != EXPECTED_SOURCE_PROVENANCE_SOURCE_TYPES:
                errors.append("workspace source provenance source type roster drifted")
            if source_provenance.get("requiredFields") != EXPECTED_SOURCE_PROVENANCE_REQUIRED_FIELDS:
                errors.append("workspace source provenance required field roster drifted")
            if source_provenance.get("surfaces") != EXPECTED_SOURCE_PROVENANCE_SURFACES:
                errors.append("workspace source provenance surface roster drifted")
            if source_provenance.get("citationTargets") != EXPECTED_CONTENT_REGISTRY_OPEN_TARGETS:
                errors.append("workspace source provenance citation target roster drifted")
            if source_provenance.get("mapsAiClaimsToSources") is not True:
                errors.append("workspace source provenance must map AI claims to sources")
            if source_provenance.get("mapsSuggestionsToEvidence") is not True:
                errors.append("workspace source provenance must map suggestions to evidence")
            if source_provenance.get("mapsFormattingChangesToStyleSources") is not True:
                errors.append("workspace source provenance must map formatting changes to style sources")
            if source_provenance.get("requiresEvidenceLink") is not True:
                errors.append("workspace source provenance must require evidence links")
            if source_provenance.get("requiresOpenTarget") is not True:
                errors.append("workspace source provenance must require open targets")
            if source_provenance.get("requiresVisibleCitationBadge") is not True:
                errors.append("workspace source provenance must show citation badges")
            if source_provenance.get("usesContentRegistry") is not True:
                errors.append("workspace source provenance must use content registry")
            if source_provenance.get("usesContentOpeners") is not True:
                errors.append("workspace source provenance must use content openers")
            if source_provenance.get("usesEvidenceInspector") is not True:
                errors.append("workspace source provenance must use evidence inspector")
            if source_provenance.get("usesReviewQueue") is not True:
                errors.append("workspace source provenance must use review queue")
            if source_provenance.get("usesDiffReview") is not True:
                errors.append("workspace source provenance must use DiffReview")
            if source_provenance.get("metadataOnly") is not True:
                errors.append("workspace source provenance must be metadata-only")
            if source_provenance.get("hashOnlyReferences") is not True:
                errors.append("workspace source provenance must use hash-only references")
            if source_provenance.get("redactsRawPayload") is not True:
                errors.append("workspace source provenance must redact raw payloads")
            if source_provenance.get("rawContentInFixture") is not False:
                errors.append("workspace source provenance fixtures must not store raw content")
            if source_provenance.get("sourceContentInFixture") is not False:
                errors.append("workspace source provenance fixtures must not store source content")
            if source_provenance.get("previewContentInFixture") is not False:
                errors.append("workspace source provenance fixtures must not store preview content")
            if source_provenance.get("transcriptContentInFixture") is not False:
                errors.append("workspace source provenance fixtures must not store transcript content")
            if source_provenance.get("mainDocumentMutationAllowed") is not False:
                errors.append("workspace source provenance must not mutate the main document")
            if source_provenance.get("autoOpenAllowed") is not False:
                errors.append("workspace source provenance must not auto-open content")
            if source_provenance.get("autoApplyAllowed") is not False:
                errors.append("workspace source provenance must not allow auto-apply")
            if source_provenance.get("failureBehavior") != "fail-closed-user-visible":
                errors.append("workspace source provenance failure behavior drifted")
            if source_provenance.get("runtimeSourceProvenanceImplementation") != "not-started":
                errors.append("workspace source provenance runtime must stay not-started")
        clipboard_materialization = workspace_ui.get("clipboardMaterialization")
        if not isinstance(clipboard_materialization, dict):
            errors.append("workspace clipboardMaterialization must be object")
        else:
            if clipboard_materialization.get("visible") is not True:
                errors.append("workspace clipboard materialization must be visible")
            if clipboard_materialization.get("scope") != ["chat-composer", "current-workspace", "current-document"]:
                errors.append("workspace clipboard materialization scope drifted")
            if clipboard_materialization.get("materializesInputTypes") != EXPECTED_CLIPBOARD_MATERIALIZATION_INPUT_TYPES:
                errors.append("workspace clipboard materialization input type roster drifted")
            if clipboard_materialization.get("thresholdPolicy") != "large-or-structured-content":
                errors.append("workspace clipboard materialization threshold policy drifted")
            if clipboard_materialization.get("storage") != "local-temp-content-object":
                errors.append("workspace clipboard materialization must use local temp content objects")
            if clipboard_materialization.get("referenceInsertedIntoChat") is not True:
                errors.append("workspace clipboard materialization must insert a chat reference")
            if clipboard_materialization.get("transcriptStoresReferenceOnly") is not True:
                errors.append("workspace clipboard materialization transcript must store references only")
            if clipboard_materialization.get("historyStoresReferenceOnly") is not True:
                errors.append("workspace clipboard materialization history must store references only")
            if clipboard_materialization.get("preservesFormattingMetadata") is not True:
                errors.append("workspace clipboard materialization must preserve formatting metadata")
            if clipboard_materialization.get("usesContentRegistry") is not True:
                errors.append("workspace clipboard materialization must use content registry")
            if clipboard_materialization.get("usesArtifactNavigator") is not True:
                errors.append("workspace clipboard materialization must use artifact navigator")
            if clipboard_materialization.get("usesContentOpeners") is not True:
                errors.append("workspace clipboard materialization must use content openers")
            if clipboard_materialization.get("usesSourceProvenance") is not True:
                errors.append("workspace clipboard materialization must use source provenance")
            if clipboard_materialization.get("requiresHashReference") is not True:
                errors.append("workspace clipboard materialization must require hash references")
            if clipboard_materialization.get("requiresEvidenceLink") is not True:
                errors.append("workspace clipboard materialization must require evidence links")
            if clipboard_materialization.get("rawClipboardContentInFixture") is not False:
                errors.append("workspace clipboard materialization fixtures must not store raw clipboard content")
            if clipboard_materialization.get("rawContentInTranscript") is not False:
                errors.append("workspace clipboard materialization must not store raw transcript content")
            if clipboard_materialization.get("rawContentInHistory") is not False:
                errors.append("workspace clipboard materialization must not store raw history content")
            if clipboard_materialization.get("mainDocumentMutationAllowed") is not False:
                errors.append("workspace clipboard materialization must not mutate the main document")
            if clipboard_materialization.get("autoApplyAllowed") is not False:
                errors.append("workspace clipboard materialization must not allow auto-apply")
            if clipboard_materialization.get("failureBehavior") != "fail-closed-user-visible":
                errors.append("workspace clipboard materialization failure behavior drifted")
            if clipboard_materialization.get("runtimeClipboardMaterializationImplementation") != "not-started":
                errors.append("workspace clipboard materialization runtime must stay not-started")
        artifact_navigator = workspace_ui.get("artifactNavigator")
        if not isinstance(artifact_navigator, dict):
            errors.append("workspace artifactNavigator must be object")
        else:
            if artifact_navigator.get("visible") is not True:
                errors.append("workspace artifact navigator must be visible")
            if artifact_navigator.get("scope") != ["current-workspace", "current-document"]:
                errors.append("workspace artifact navigator scope drifted")
            if artifact_navigator.get("managedTypes") != EXPECTED_WORKSPACE_CONTENT_TYPES:
                errors.append("workspace artifact navigator type roster drifted")
            if artifact_navigator.get("groupBy") != ["type", "task"]:
                errors.append("workspace artifact navigator grouping drifted")
            if artifact_navigator.get("sort") != "recent-first":
                errors.append("workspace artifact navigator sort drifted")
            if artifact_navigator.get("evidenceBadgeVisible") is not True:
                errors.append("workspace artifact navigator must show evidence badges")
            if artifact_navigator.get("openUsesContentOpeners") is not True:
                errors.append("workspace artifact navigator must use content openers")
            if artifact_navigator.get("readOnlyDetails") is not True:
                errors.append("workspace artifact navigator details must be read-only")
            if artifact_navigator.get("rawContentInFixture") is not False:
                errors.append("workspace artifact navigator fixtures must not store raw content")
            if artifact_navigator.get("mainDocumentMutationAllowed") is not False:
                errors.append("workspace artifact navigator must not mutate the main document")
            if artifact_navigator.get("failureBehavior") != "fail-closed-user-visible":
                errors.append("workspace artifact navigator failure behavior drifted")
            if artifact_navigator.get("runtimeArtifactNavigatorImplementation") != "not-started":
                errors.append("workspace artifact navigator runtime must stay not-started")
        review_queue = workspace_ui.get("reviewQueue")
        if not isinstance(review_queue, dict):
            errors.append("workspace reviewQueue must be object")
        else:
            if review_queue.get("visible") is not True:
                errors.append("workspace review queue must be visible")
            if review_queue.get("itemTypes") != EXPECTED_REVIEW_QUEUE_TYPES:
                errors.append("workspace review queue item type roster drifted")
            if review_queue.get("states") != EXPECTED_REVIEW_QUEUE_STATES:
                errors.append("workspace review queue state roster drifted")
            if review_queue.get("filterBy") != EXPECTED_REVIEW_QUEUE_FILTERS:
                errors.append("workspace review queue filters drifted")
            if review_queue.get("openUsesDiffReview") is not True:
                errors.append("workspace review queue must open items in DiffReview")
            if review_queue.get("requiresEvidenceLink") is not True:
                errors.append("workspace review queue must require evidence links")
            if review_queue.get("bulkActions") != EXPECTED_REVIEW_QUEUE_BULK_ACTIONS:
                errors.append("workspace review queue bulk actions drifted")
            if review_queue.get("bulkApplyRequiresExplicitHumanApproval") is not True:
                errors.append("workspace review queue bulk apply must require explicit human approval")
            if review_queue.get("mainDocumentMutationAllowed") is not False:
                errors.append("workspace review queue must not mutate the main document")
            if review_queue.get("rawContentInFixture") is not False:
                errors.append("workspace review queue fixtures must not store raw content")
            if review_queue.get("failureBehavior") != "fail-closed-user-visible":
                errors.append("workspace review queue failure behavior drifted")
            if review_queue.get("runtimeReviewQueueImplementation") != "not-started":
                errors.append("workspace review queue runtime must stay not-started")
        evidence_inspector = workspace_ui.get("evidenceInspector")
        if not isinstance(evidence_inspector, dict):
            errors.append("workspace evidenceInspector must be object")
        else:
            if evidence_inspector.get("visible") is not True:
                errors.append("workspace evidence inspector must be visible")
            if evidence_inspector.get("sourceTypes") != EXPECTED_EVIDENCE_INSPECTOR_SOURCE_TYPES:
                errors.append("workspace evidence inspector source type roster drifted")
            if evidence_inspector.get("showsCitationLinks") is not True:
                errors.append("workspace evidence inspector must show citation links")
            if evidence_inspector.get("showsAuditTrail") is not True:
                errors.append("workspace evidence inspector must show audit trail")
            if evidence_inspector.get("openUsesContentOpeners") is not True:
                errors.append("workspace evidence inspector must use content openers")
            if evidence_inspector.get("redactsRawPayload") is not True:
                errors.append("workspace evidence inspector must redact raw payloads")
            if evidence_inspector.get("hashOnlyReferences") is not True:
                errors.append("workspace evidence inspector must use hash-only references")
            if evidence_inspector.get("requiresEvidenceLink") is not True:
                errors.append("workspace evidence inspector must require evidence links")
            if evidence_inspector.get("rawContentInFixture") is not False:
                errors.append("workspace evidence inspector fixtures must not store raw content")
            if evidence_inspector.get("mainDocumentMutationAllowed") is not False:
                errors.append("workspace evidence inspector must not mutate the main document")
            if evidence_inspector.get("failureBehavior") != "fail-closed-user-visible":
                errors.append("workspace evidence inspector failure behavior drifted")
            if evidence_inspector.get("runtimeEvidenceInspectorImplementation") != "not-started":
                errors.append("workspace evidence inspector runtime must stay not-started")
        interaction_chrome = workspace_ui.get("interactionChrome")
        if not isinstance(interaction_chrome, dict):
            errors.append("workspace interactionChrome must be object")
        else:
            if interaction_chrome.get("layout") != "sidebar-workbench":
                errors.append("workspace interaction chrome must use sidebar-workbench layout")
            if interaction_chrome.get("navigation") != "segmented-tabs":
                errors.append("workspace interaction chrome must use segmented tabs")
            if interaction_chrome.get("panels") != EXPECTED_INTERACTION_PANELS:
                errors.append("workspace interaction chrome panel roster drifted")
            if interaction_chrome.get("defaultPanel") != "chat":
                errors.append("workspace interaction chrome default panel must be chat")
            if interaction_chrome.get("persistentComposer") is not True:
                errors.append("workspace interaction chrome must keep the composer persistent")
            if interaction_chrome.get("taskRailVisible") is not True:
                errors.append("workspace interaction chrome must show the task rail")
            if interaction_chrome.get("artifactRailVisible") is not True:
                errors.append("workspace interaction chrome must show the artifact rail")
            if interaction_chrome.get("reviewRailVisible") is not True:
                errors.append("workspace interaction chrome must show the review rail")
            if interaction_chrome.get("evidenceRailVisible") is not True:
                errors.append("workspace interaction chrome must show the evidence rail")
            keyboard = interaction_chrome.get("keyboardNavigation")
            if not isinstance(keyboard, dict):
                errors.append("workspace interaction chrome keyboardNavigation must be object")
            else:
                if keyboard.get("tabOrder") != EXPECTED_INTERACTION_TAB_ORDER:
                    errors.append("workspace interaction chrome tab order drifted")
                if keyboard.get("escapeReturnsFocus") is not True:
                    errors.append("workspace interaction chrome Escape must return focus")
                if keyboard.get("focusTrap") is not False:
                    errors.append("workspace interaction chrome must not trap focus")
            if interaction_chrome.get("density") != "compact-utility":
                errors.append("workspace interaction chrome density drifted")
            if interaction_chrome.get("usesNativeControls") is not True:
                errors.append("workspace interaction chrome must use native controls")
            if interaction_chrome.get("modalChatOnly") is not False:
                errors.append("workspace interaction chrome must not collapse to modal chat only")
            if interaction_chrome.get("rawContentInFixture") is not False:
                errors.append("workspace interaction chrome fixtures must not store raw content")
            if interaction_chrome.get("failureBehavior") != "fail-closed-user-visible":
                errors.append("workspace interaction chrome failure behavior drifted")
            if interaction_chrome.get("runtimeInteractionChromeImplementation") != "not-started":
                errors.append("workspace interaction chrome runtime must stay not-started")
        preview_matrix = workspace_ui.get("previewMatrix")
        if not isinstance(preview_matrix, dict):
            errors.append("workspace previewMatrix must be object")
        else:
            if preview_matrix.get("visible") is not True:
                errors.append("workspace preview matrix must be visible")
            if preview_matrix.get("contentTypes") != EXPECTED_PREVIEW_MATRIX_TYPES:
                errors.append("workspace preview matrix content type roster drifted")
            if preview_matrix.get("previewTargets") != EXPECTED_PREVIEW_MATRIX_TARGETS:
                errors.append("workspace preview matrix target roster drifted")
            if preview_matrix.get("previewModes") != EXPECTED_PREVIEW_MATRIX_MODES:
                errors.append("workspace preview matrix mode roster drifted")
            if preview_matrix.get("showsEvidenceBadge") is not True:
                errors.append("workspace preview matrix must show evidence badges")
            if preview_matrix.get("showsSourceMetadata") is not True:
                errors.append("workspace preview matrix must show source metadata")
            if preview_matrix.get("openUsesContentOpeners") is not True:
                errors.append("workspace preview matrix must use content openers")
            if preview_matrix.get("readOnlyPreview") is not True:
                errors.append("workspace preview matrix previews must be read-only")
            if preview_matrix.get("redactsRawPayload") is not True:
                errors.append("workspace preview matrix must redact raw payloads")
            if preview_matrix.get("hashOnlyReferences") is not True:
                errors.append("workspace preview matrix must use hash-only references")
            if preview_matrix.get("rawContentInFixture") is not False:
                errors.append("workspace preview matrix fixtures must not store raw content")
            if preview_matrix.get("previewContentInFixture") is not False:
                errors.append("workspace preview matrix fixtures must not store preview content")
            if preview_matrix.get("mainDocumentMutationAllowed") is not False:
                errors.append("workspace preview matrix must not mutate the main document")
            if preview_matrix.get("failureBehavior") != "fail-closed-user-visible":
                errors.append("workspace preview matrix failure behavior drifted")
            if preview_matrix.get("runtimePreviewMatrixImplementation") != "not-started":
                errors.append("workspace preview matrix runtime must stay not-started")
        action_bar = workspace_ui.get("actionBar")
        if not isinstance(action_bar, dict):
            errors.append("workspace actionBar must be object")
        else:
            if action_bar.get("visible") is not True:
                errors.append("workspace action bar must be visible")
            if action_bar.get("placement") != "sidebar-workbench-header":
                errors.append("workspace action bar placement drifted")
            if action_bar.get("commands") != EXPECTED_ACTION_BAR_COMMANDS:
                errors.append("workspace action bar command roster drifted")
            if action_bar.get("commandTargets") != EXPECTED_ACTION_BAR_TARGETS:
                errors.append("workspace action bar target roster drifted")
            if action_bar.get("keyboardAccessible") is not True:
                errors.append("workspace action bar must be keyboard accessible")
            if action_bar.get("usesNativeControls") is not True:
                errors.append("workspace action bar must use native controls")
            if action_bar.get("requiresVisibleState") is not True:
                errors.append("workspace action bar must expose visible command state")
            if action_bar.get("requiresEvidenceLink") is not True:
                errors.append("workspace action bar must require evidence links")
            if action_bar.get("usesContentOpeners") is not True:
                errors.append("workspace action bar must use content openers")
            if action_bar.get("usesDiffReview") is not True:
                errors.append("workspace action bar must use DiffReview")
            if action_bar.get("bulkApplyRequiresExplicitHumanApproval") is not True:
                errors.append("workspace action bar bulk apply must require explicit human approval")
            if action_bar.get("autoApplyAllowed") is not False:
                errors.append("workspace action bar must not allow auto-apply")
            if action_bar.get("hiddenActionsAllowed") is not False:
                errors.append("workspace action bar must not allow hidden actions")
            if action_bar.get("mouseOnlyActionsAllowed") is not False:
                errors.append("workspace action bar must not allow mouse-only actions")
            if action_bar.get("rawContentInFixture") is not False:
                errors.append("workspace action bar fixtures must not store raw content")
            if action_bar.get("mainDocumentMutationAllowed") is not False:
                errors.append("workspace action bar must not mutate the main document")
            if action_bar.get("failureBehavior") != "fail-closed-user-visible":
                errors.append("workspace action bar failure behavior drifted")
            if action_bar.get("runtimeActionBarImplementation") != "not-started":
                errors.append("workspace action bar runtime must stay not-started")
        filter_search = workspace_ui.get("filterSearch")
        if not isinstance(filter_search, dict):
            errors.append("workspace filterSearch must be object")
        else:
            if filter_search.get("visible") is not True:
                errors.append("workspace filter/search must be visible")
            if filter_search.get("scope") != ["current-workspace", "current-document"]:
                errors.append("workspace filter/search scope drifted")
            if filter_search.get("surfaces") != EXPECTED_FILTER_SEARCH_SURFACES:
                errors.append("workspace filter/search surface roster drifted")
            if filter_search.get("filterBy") != EXPECTED_FILTER_SEARCH_FILTERS:
                errors.append("workspace filter/search filter roster drifted")
            if filter_search.get("searchFields") != EXPECTED_FILTER_SEARCH_FIELDS:
                errors.append("workspace filter/search field roster drifted")
            if filter_search.get("sortOptions") != ["recent-first", "type", "state", "source"]:
                errors.append("workspace filter/search sort roster drifted")
            if filter_search.get("metadataOnly") is not True:
                errors.append("workspace filter/search must be metadata-only")
            if filter_search.get("hashOnlyReferences") is not True:
                errors.append("workspace filter/search must use hash-only references")
            if filter_search.get("redactsRawPayload") is not True:
                errors.append("workspace filter/search must redact raw payloads")
            if filter_search.get("rawContentIndexed") is not False:
                errors.append("workspace filter/search must not index raw content")
            if filter_search.get("rawContentInFixture") is not False:
                errors.append("workspace filter/search fixtures must not store raw content")
            if filter_search.get("crossDocumentSearch") is not False:
                errors.append("workspace filter/search must not search across documents")
            if filter_search.get("globalIndex") is not False:
                errors.append("workspace filter/search must not use a global index")
            if filter_search.get("usesContentOpeners") is not True:
                errors.append("workspace filter/search must use content openers")
            if filter_search.get("requiresEvidenceLink") is not True:
                errors.append("workspace filter/search must require evidence links")
            if filter_search.get("failureBehavior") != "fail-closed-user-visible":
                errors.append("workspace filter/search failure behavior drifted")
            if filter_search.get("runtimeFilterSearchImplementation") != "not-started":
                errors.append("workspace filter/search runtime must stay not-started")
        context_handoff = workspace_ui.get("contextHandoff")
        if not isinstance(context_handoff, dict):
            errors.append("workspace contextHandoff must be object")
        else:
            if context_handoff.get("visible") is not True:
                errors.append("workspace context handoff must be visible")
            if context_handoff.get("entrySurfaces") != EXPECTED_CONTEXT_HANDOFF_ENTRY_SURFACES:
                errors.append("workspace context handoff entry surface roster drifted")
            if context_handoff.get("handoffTargets") != EXPECTED_CONTEXT_HANDOFF_TARGETS:
                errors.append("workspace context handoff target roster drifted")
            if context_handoff.get("preserves") != EXPECTED_CONTEXT_HANDOFF_PRESERVES:
                errors.append("workspace context handoff preserved metadata roster drifted")
            if context_handoff.get("requiresVisibleBreadcrumb") is not True:
                errors.append("workspace context handoff must show a visible breadcrumb")
            if context_handoff.get("requiresBackNavigation") is not True:
                errors.append("workspace context handoff must support back navigation")
            if context_handoff.get("requiresFocusReturn") is not True:
                errors.append("workspace context handoff must return focus")
            if context_handoff.get("requiresEvidenceLink") is not True:
                errors.append("workspace context handoff must require evidence links")
            if context_handoff.get("usesContentOpeners") is not True:
                errors.append("workspace context handoff must use content openers")
            if context_handoff.get("usesDiffReview") is not True:
                errors.append("workspace context handoff must use DiffReview")
            if context_handoff.get("metadataOnly") is not True:
                errors.append("workspace context handoff must be metadata-only")
            if context_handoff.get("hashOnlyReferences") is not True:
                errors.append("workspace context handoff must use hash-only references")
            if context_handoff.get("redactsRawPayload") is not True:
                errors.append("workspace context handoff must redact raw payloads")
            if context_handoff.get("rawContentInFixture") is not False:
                errors.append("workspace context handoff fixtures must not store raw content")
            if context_handoff.get("previewContentInFixture") is not False:
                errors.append("workspace context handoff fixtures must not store preview content")
            if context_handoff.get("mainDocumentMutationAllowed") is not False:
                errors.append("workspace context handoff must not mutate the main document")
            if context_handoff.get("autoApplyAllowed") is not False:
                errors.append("workspace context handoff must not allow auto-apply")
            if context_handoff.get("failureBehavior") != "fail-closed-user-visible":
                errors.append("workspace context handoff failure behavior drifted")
            if context_handoff.get("runtimeContextHandoffImplementation") != "not-started":
                errors.append("workspace context handoff runtime must stay not-started")
        review_state_sync = workspace_ui.get("reviewStateSync")
        if not isinstance(review_state_sync, dict):
            errors.append("workspace reviewStateSync must be object")
        else:
            if review_state_sync.get("visible") is not True:
                errors.append("workspace review state sync must be visible")
            if review_state_sync.get("stateSources") != EXPECTED_REVIEW_STATE_SYNC_SURFACES:
                errors.append("workspace review state sync source roster drifted")
            if review_state_sync.get("states") != EXPECTED_REVIEW_QUEUE_STATES:
                errors.append("workspace review state sync state roster drifted")
            if review_state_sync.get("syncTargets") != EXPECTED_REVIEW_STATE_SYNC_SURFACES:
                errors.append("workspace review state sync target roster drifted")
            if review_state_sync.get("transitionEvents") != EXPECTED_REVIEW_STATE_SYNC_TRANSITIONS:
                errors.append("workspace review state sync transition roster drifted")
            if review_state_sync.get("requiresEvidenceLink") is not True:
                errors.append("workspace review state sync must require evidence links")
            if review_state_sync.get("requiresVisibleState") is not True:
                errors.append("workspace review state sync must expose visible state")
            if review_state_sync.get("requiresHumanApproval") is not True:
                errors.append("workspace review state sync must require human approval")
            if review_state_sync.get("bulkApplyRequiresExplicitHumanApproval") is not True:
                errors.append("workspace review state sync bulk apply must require explicit human approval")
            if review_state_sync.get("usesDiffReview") is not True:
                errors.append("workspace review state sync must use DiffReview")
            if review_state_sync.get("usesContentOpeners") is not True:
                errors.append("workspace review state sync must use content openers")
            if review_state_sync.get("metadataOnly") is not True:
                errors.append("workspace review state sync must be metadata-only")
            if review_state_sync.get("hashOnlyReferences") is not True:
                errors.append("workspace review state sync must use hash-only references")
            if review_state_sync.get("redactsRawPayload") is not True:
                errors.append("workspace review state sync must redact raw payloads")
            if review_state_sync.get("rawContentInFixture") is not False:
                errors.append("workspace review state sync fixtures must not store raw content")
            if review_state_sync.get("mainDocumentMutationAllowed") is not False:
                errors.append("workspace review state sync must not mutate the main document")
            if review_state_sync.get("autoApplyAllowed") is not False:
                errors.append("workspace review state sync must not allow auto-apply")
            if review_state_sync.get("conflictBehavior") != "fail-closed-user-visible":
                errors.append("workspace review state sync conflict behavior drifted")
            if review_state_sync.get("failureBehavior") != "fail-closed-user-visible":
                errors.append("workspace review state sync failure behavior drifted")
            if review_state_sync.get("runtimeReviewStateSyncImplementation") != "not-started":
                errors.append("workspace review state sync runtime must stay not-started")
        activity_timeline = workspace_ui.get("activityTimeline")
        if not isinstance(activity_timeline, dict):
            errors.append("workspace activityTimeline must be object")
        else:
            if activity_timeline.get("visible") is not True:
                errors.append("workspace activity timeline must be visible")
            if activity_timeline.get("events") != EXPECTED_ACTIVITY_TIMELINE_EVENTS:
                errors.append("workspace activity timeline event roster drifted")
            if activity_timeline.get("surfaces") != EXPECTED_ACTIVITY_TIMELINE_SURFACES:
                errors.append("workspace activity timeline surface roster drifted")
            if activity_timeline.get("links") != EXPECTED_ACTIVITY_TIMELINE_LINKS:
                errors.append("workspace activity timeline link roster drifted")
            if activity_timeline.get("order") != "chronological":
                errors.append("workspace activity timeline order drifted")
            if activity_timeline.get("appendOnly") is not True:
                errors.append("workspace activity timeline must be append-only")
            if activity_timeline.get("requiresEvidenceLink") is not True:
                errors.append("workspace activity timeline must require evidence links")
            if activity_timeline.get("requiresVisibleTimestamp") is not True:
                errors.append("workspace activity timeline must expose visible timestamps")
            if activity_timeline.get("requiresVisibleActor") is not True:
                errors.append("workspace activity timeline must expose visible actors")
            if activity_timeline.get("requiresOpenTarget") is not True:
                errors.append("workspace activity timeline must expose open targets")
            if activity_timeline.get("usesContentOpeners") is not True:
                errors.append("workspace activity timeline must use content openers")
            if activity_timeline.get("usesDiffReview") is not True:
                errors.append("workspace activity timeline must use DiffReview")
            if activity_timeline.get("usesEvidenceInspector") is not True:
                errors.append("workspace activity timeline must use evidence inspector")
            if activity_timeline.get("metadataOnly") is not True:
                errors.append("workspace activity timeline must be metadata-only")
            if activity_timeline.get("hashOnlyReferences") is not True:
                errors.append("workspace activity timeline must use hash-only references")
            if activity_timeline.get("redactsRawPayload") is not True:
                errors.append("workspace activity timeline must redact raw payloads")
            if activity_timeline.get("rawContentInFixture") is not False:
                errors.append("workspace activity timeline fixtures must not store raw content")
            if activity_timeline.get("previewContentInFixture") is not False:
                errors.append("workspace activity timeline fixtures must not store preview content")
            if activity_timeline.get("transcriptContentInFixture") is not False:
                errors.append("workspace activity timeline fixtures must not store transcript content")
            if activity_timeline.get("mainDocumentMutationAllowed") is not False:
                errors.append("workspace activity timeline must not mutate the main document")
            if activity_timeline.get("autoApplyAllowed") is not False:
                errors.append("workspace activity timeline must not allow auto-apply")
            if activity_timeline.get("failureBehavior") != "fail-closed-user-visible":
                errors.append("workspace activity timeline failure behavior drifted")
            if activity_timeline.get("runtimeActivityTimelineImplementation") != "not-started":
                errors.append("workspace activity timeline runtime must stay not-started")
        session_snapshot = workspace_ui.get("sessionSnapshot")
        if not isinstance(session_snapshot, dict):
            errors.append("workspace sessionSnapshot must be object")
        else:
            if session_snapshot.get("visible") is not True:
                errors.append("workspace session snapshot must be visible")
            if session_snapshot.get("scope") != ["current-workspace", "current-document"]:
                errors.append("workspace session snapshot scope drifted")
            if session_snapshot.get("restores") != EXPECTED_SESSION_SNAPSHOT_RESTORES:
                errors.append("workspace session snapshot restore roster drifted")
            if session_snapshot.get("surfaces") != EXPECTED_SESSION_SNAPSHOT_SURFACES:
                errors.append("workspace session snapshot surface roster drifted")
            if session_snapshot.get("resumeSummaryVisible") is not True:
                errors.append("workspace session snapshot must expose resume summary")
            if session_snapshot.get("requiresExplicitResume") is not True:
                errors.append("workspace session snapshot must require explicit resume")
            if session_snapshot.get("requiresVisibleTimestamp") is not True:
                errors.append("workspace session snapshot must expose visible timestamp")
            if session_snapshot.get("requiresVisibleDocumentBinding") is not True:
                errors.append("workspace session snapshot must expose document binding")
            if session_snapshot.get("usesContentOpeners") is not True:
                errors.append("workspace session snapshot must use content openers")
            if session_snapshot.get("usesDiffReview") is not True:
                errors.append("workspace session snapshot must use DiffReview")
            if session_snapshot.get("usesEvidenceInspector") is not True:
                errors.append("workspace session snapshot must use evidence inspector")
            if session_snapshot.get("usesActivityTimeline") is not True:
                errors.append("workspace session snapshot must use activity timeline")
            if session_snapshot.get("metadataOnly") is not True:
                errors.append("workspace session snapshot must be metadata-only")
            if session_snapshot.get("hashOnlyReferences") is not True:
                errors.append("workspace session snapshot must use hash-only references")
            if session_snapshot.get("redactsRawPayload") is not True:
                errors.append("workspace session snapshot must redact raw payloads")
            if session_snapshot.get("rawContentInFixture") is not False:
                errors.append("workspace session snapshot fixtures must not store raw content")
            if session_snapshot.get("previewContentInFixture") is not False:
                errors.append("workspace session snapshot fixtures must not store preview content")
            if session_snapshot.get("transcriptContentInFixture") is not False:
                errors.append("workspace session snapshot fixtures must not store transcript content")
            if session_snapshot.get("crossDocumentRestore") is not False:
                errors.append("workspace session snapshot must not restore across documents")
            if session_snapshot.get("cloudSync") is not False:
                errors.append("workspace session snapshot must not sync to cloud")
            if session_snapshot.get("mainDocumentMutationAllowed") is not False:
                errors.append("workspace session snapshot must not mutate the main document")
            if session_snapshot.get("autoApplyAllowed") is not False:
                errors.append("workspace session snapshot must not allow auto-apply")
            if session_snapshot.get("failureBehavior") != "fail-closed-user-visible":
                errors.append("workspace session snapshot failure behavior drifted")
            if session_snapshot.get("runtimeSessionSnapshotImplementation") != "not-started":
                errors.append("workspace session snapshot runtime must stay not-started")
        attention_routing = workspace_ui.get("attentionRouting")
        if not isinstance(attention_routing, dict):
            errors.append("workspace attentionRouting must be object")
        else:
            if attention_routing.get("visible") is not True:
                errors.append("workspace attention routing must be visible")
            if attention_routing.get("scope") != ["current-workspace", "current-document"]:
                errors.append("workspace attention routing scope drifted")
            if attention_routing.get("triggers") != EXPECTED_ATTENTION_ROUTING_TRIGGERS:
                errors.append("workspace attention routing trigger roster drifted")
            if attention_routing.get("surfaces") != EXPECTED_ATTENTION_ROUTING_SURFACES:
                errors.append("workspace attention routing surface roster drifted")
            if attention_routing.get("routesTo") != EXPECTED_ATTENTION_ROUTING_TARGETS:
                errors.append("workspace attention routing target roster drifted")
            if attention_routing.get("requiresOpenTarget") is not True:
                errors.append("workspace attention routing must expose open target")
            if attention_routing.get("requiresVisibleReason") is not True:
                errors.append("workspace attention routing must expose visible reason")
            if attention_routing.get("requiresVisibleTimestamp") is not True:
                errors.append("workspace attention routing must expose visible timestamp")
            if attention_routing.get("requiresKeyboardAccess") is not True:
                errors.append("workspace attention routing must support keyboard access")
            if attention_routing.get("usesNativeControls") is not True:
                errors.append("workspace attention routing must use native controls")
            if attention_routing.get("usesActionBar") is not True:
                errors.append("workspace attention routing must use action bar")
            if attention_routing.get("usesActivityTimeline") is not True:
                errors.append("workspace attention routing must use activity timeline")
            if attention_routing.get("usesSessionSnapshot") is not True:
                errors.append("workspace attention routing must use session snapshot")
            if attention_routing.get("usesEvidenceInspector") is not True:
                errors.append("workspace attention routing must use evidence inspector")
            if attention_routing.get("usesDiffReview") is not True:
                errors.append("workspace attention routing must use DiffReview")
            if attention_routing.get("metadataOnly") is not True:
                errors.append("workspace attention routing must be metadata-only")
            if attention_routing.get("hashOnlyReferences") is not True:
                errors.append("workspace attention routing must use hash-only references")
            if attention_routing.get("redactsRawPayload") is not True:
                errors.append("workspace attention routing must redact raw payloads")
            if attention_routing.get("rawContentInFixture") is not False:
                errors.append("workspace attention routing fixtures must not store raw content")
            if attention_routing.get("previewContentInFixture") is not False:
                errors.append("workspace attention routing fixtures must not store preview content")
            if attention_routing.get("transcriptContentInFixture") is not False:
                errors.append("workspace attention routing fixtures must not store transcript content")
            if attention_routing.get("systemNotificationRuntime") != "not-started":
                errors.append("workspace attention routing system notification runtime must stay not-started")
            if attention_routing.get("cloudPush") is not False:
                errors.append("workspace attention routing must not use cloud push")
            if attention_routing.get("autoOpenAllowed") is not False:
                errors.append("workspace attention routing must not auto-open content")
            if attention_routing.get("autoApplyAllowed") is not False:
                errors.append("workspace attention routing must not allow auto-apply")
            if attention_routing.get("mainDocumentMutationAllowed") is not False:
                errors.append("workspace attention routing must not mutate the main document")
            if attention_routing.get("failureBehavior") != "fail-closed-user-visible":
                errors.append("workspace attention routing failure behavior drifted")
            if attention_routing.get("runtimeAttentionRoutingImplementation") != "not-started":
                errors.append("workspace attention routing runtime must stay not-started")
        style_policy = workspace_ui.get("stylePolicy")
        if not isinstance(style_policy, dict):
            errors.append("workspace stylePolicy must be object")
        else:
            if style_policy.get("denseUtilityUi") is not True:
                errors.append("workspace UI must be dense utility UI")
            if style_policy.get("usesNativeControls") is not True:
                errors.append("workspace UI must use native controls")
            if style_policy.get("modalChatOnly") is not False:
                errors.append("workspace UI must not collapse to modal chat only")
        native_style = workspace_ui.get("nativeStyle")
        if not isinstance(native_style, dict):
            errors.append("workspace nativeStyle must be object")
        else:
            if native_style.get("layout") != "sidebar-workbench":
                errors.append("workspace native style layout drifted")
            if native_style.get("density") != "compact-utility":
                errors.append("workspace native style density drifted")
            if native_style.get("surfaces") != EXPECTED_NATIVE_STYLE_SURFACES:
                errors.append("workspace native style surface roster drifted")
            if native_style.get("navigation") != "segmented-tabs":
                errors.append("workspace native style navigation drifted")
            if native_style.get("usesNativeControls") is not True:
                errors.append("workspace native style must use native controls")
            if native_style.get("stableDimensions") != EXPECTED_NATIVE_STYLE_STABLE_DIMENSIONS:
                errors.append("workspace native style stable dimension roster drifted")
            if native_style.get("textOverflowPolicy") != "wrap-or-ellipsize-no-overlap":
                errors.append("workspace native style text overflow policy drifted")
            if native_style.get("cardPileLayout") is not False:
                errors.append("workspace native style must not use card-pile layout")
            if native_style.get("modalOnly") is not False:
                errors.append("workspace native style must not be modal-only")
            if native_style.get("marketingHero") is not False:
                errors.append("workspace native style must not use marketing hero layout")
            if native_style.get("keyboardAccessible") is not True:
                errors.append("workspace native style must be keyboard accessible")
            if native_style.get("focusReturn") is not True:
                errors.append("workspace native style must return focus")
            if native_style.get("metadataOnly") is not True:
                errors.append("workspace native style must be metadata-only")
            if native_style.get("rawContentInFixture") is not False:
                errors.append("workspace native style fixtures must not store raw content")
            if native_style.get("previewContentInFixture") is not False:
                errors.append("workspace native style fixtures must not store preview content")
            if native_style.get("transcriptContentInFixture") is not False:
                errors.append("workspace native style fixtures must not store transcript content")
            if native_style.get("mainDocumentMutationAllowed") is not False:
                errors.append("workspace native style must not mutate the main document")
            if native_style.get("autoApplyAllowed") is not False:
                errors.append("workspace native style must not allow auto-apply")
            if native_style.get("failureBehavior") != "fail-closed-user-visible":
                errors.append("workspace native style failure behavior drifted")
            if native_style.get("runtimeNativeStyleImplementation") != "not-started":
                errors.append("workspace native style runtime must stay not-started")

    if not isinstance(provider, dict):
        errors.append("provider must be object")
    else:
        if provider.get("usesV2Provider") is not True:
            errors.append("chat must reuse V2 Provider")
        if provider.get("serviceMode") not in {"offline", "private"}:
            errors.append("chat provider mode must stay offline/private")
        if provider.get("streaming") != "chunk":
            errors.append("streaming must reuse V2 chunk semantics")

    if not isinstance(output, dict):
        errors.append("output must be object")
    else:
        expected_action = EXPECTED_ACTION_BY_SURFACE.get(surface)
        if output.get("kind") != "apply-plan":
            errors.append("chat output must be ApplyPlan")
        if output.get("actionKind") != expected_action:
            errors.append(f"{surface} actionKind must be {expected_action}")
        if output.get("applyPlanRuntimeValidation") is not True:
            errors.append("ApplyPlan runtime validation is required")
        if output.get("v2TokenLock") != EXPECTED_TOKEN_LOCK:
            errors.append("V2 ApplyPlan token lock drifted")
        rendering = output.get("rendering")
        if not isinstance(rendering, dict):
            errors.append("output rendering envelope is required")
        else:
            if rendering.get("format") != "markdown-subset":
                errors.append("chat rendering format must be markdown-subset")
            if rendering.get("renderer") != "native-rich-text":
                errors.append("chat rendering must use native-rich-text")
            if rendering.get("allowedBlocks") != EXPECTED_MARKDOWN_BLOCKS:
                errors.append("Markdown rendering block subset drifted")
            if rendering.get("webView") is not False:
                errors.append("W1 Markdown rendering must not use WebView")
            if rendering.get("allowsRawHtml") is not False:
                errors.append("W1 Markdown rendering must reject raw HTML")
            if rendering.get("allowsRemoteImages") is not False:
                errors.append("W1 Markdown rendering must reject remote images")

    if not isinstance(approval, dict):
        errors.append("approval must be object")
    else:
        if approval.get("humanRequired") is not True:
            errors.append("human approval is required")
        if approval.get("mainDocumentUnchangedUntilApproval") is not True:
            errors.append("main document must stay unchanged until approval")

    if not isinstance(evidence, dict):
        errors.append("evidence must be object")
    else:
        if evidence.get("usesV2EvidenceRecord") is not True:
            errors.append("chat must reuse V2 evidence-record")
        if evidence.get("storesPromptContent") is not False:
            errors.append("fixture must not store prompt content")
        if evidence.get("localOnly") is not True:
            errors.append("evidence must stay local-only")

    if not isinstance(gates, dict):
        errors.append("gates must be object")
    else:
        if gates.get("runtimeImplementation") != "not-started":
            errors.append("runtime implementation must stay not-started")
        if gates.get("requiresExplicitUserAuthorization") is not True:
            errors.append("runtime gate must require explicit user authorization")

    connector = value.get("connector")
    explicit_mentions = context.get("explicitMentions", []) if isinstance(context, dict) else []
    if scenario_type == "connector-context":
        if not isinstance(connector, dict):
            errors.append("connector-context scenario must declare connector")
        else:
            if connector.get("access") != "read-only":
                errors.append("connector context must stay read-only")
            if connector.get("requiresW2Manifest") is not True:
                errors.append("connector context must require W2 manifest")
            if connector.get("evidenceCategory") != "data-fetch":
                errors.append("connector context must emit data-fetch evidence")
        if not any(str(item).startswith("@connector:") for item in explicit_mentions):
            errors.append("connector context must be explicit via @connector")
    elif connector is not None:
        errors.append("document-chat scenarios must not include connector context")

    return errors


pass_count = 0

valid_files = {path.name for path in valid_dir.glob("*.json")}
invalid_files = {path.name for path in invalid_dir.glob("*.json")}
if valid_files != EXPECTED_VALID_FILES:
    die(f"valid fixture roster drifted: {sorted(valid_files)!r}")
if invalid_files != EXPECTED_INVALID_FILES:
    die(f"invalid fixture roster drifted: {sorted(invalid_files)!r}")
pass_count += 1

valid_values = [load(valid_dir / name) for name in sorted(EXPECTED_VALID_FILES)]
for value in valid_values:
    errors = semantic_errors(value)
    if errors:
        die(f"{value.get('id')} should be valid: {errors}")
pass_count += 1

for name in sorted(EXPECTED_INVALID_FILES):
    value = load(invalid_dir / name)
    if not semantic_errors(value):
        die(f"{name} should be rejected by W1 chat semantics")
pass_count += 1

surfaces = {value["surface"] for value in valid_values}
scenario_types = {value["scenarioType"] for value in valid_values}
if surfaces != {"writer", "calc", "impress"}:
    die(f"surface coverage drifted: {sorted(surfaces)!r}")
if "connector-context" not in scenario_types:
    die("missing connector-context valid fixture")
pass_count += 1

for value in valid_values:
    if value["provider"]["usesV2Provider"] is not True:
        die("valid fixture does not reuse V2 Provider")
    if value["output"]["kind"] != "apply-plan":
        die("valid fixture does not output ApplyPlan")
    if value["output"]["v2TokenLock"] != EXPECTED_TOKEN_LOCK:
        die("valid fixture token lock drifted")
    if value["evidence"]["usesV2EvidenceRecord"] is not True:
        die("valid fixture does not reuse V2 evidence-record")
pass_count += 1

for value in valid_values:
    if value["approval"]["humanRequired"] is not True:
        die("valid fixture missing human approval")
    if value["approval"]["mainDocumentUnchangedUntilApproval"] is not True:
        die("valid fixture mutates main document before approval")
    if value["context"]["storesCloudHistory"] is not False:
        die("valid fixture stores cloud history")
    if value["history"] != EXPECTED_HISTORY:
        die("valid fixture history envelope drifted")
    if value["streamingUi"] != EXPECTED_STREAMING_UI:
        die("valid fixture streaming UI envelope drifted")
    if value["mentionsUi"] != EXPECTED_MENTIONS_UI:
        die("valid fixture mentions UI envelope drifted")
    if value["evidence"]["storesPromptContent"] is not False:
        die("valid fixture stores prompt content")
pass_count += 1

for value in valid_values:
    if value["workspaceUi"] != EXPECTED_WORKSPACE_UI:
        die("valid fixture workspace UI envelope drifted")
pass_count += 1

for value in valid_values:
    content_openers = value["workspaceUi"]["contentOpeners"]
    if content_openers["routePolicy"] != EXPECTED_WORKSPACE_ROUTE_POLICY:
        die("valid fixture content opener route policy drifted")
    if content_openers["requiresEvidenceLink"] is not True:
        die("valid fixture content opener missing evidence link requirement")
    if content_openers["readOnlyPreview"] is not True:
        die("valid fixture content opener preview is not read-only")
    if content_openers["mainDocumentMutationAllowed"] is not False:
        die("valid fixture content opener allows main document mutation")
    if content_openers["openFailureBehavior"] != "fail-closed-user-visible":
        die("valid fixture content opener failure behavior drifted")
pass_count += 1

for value in valid_values:
    formatting_review = value["workspaceUi"]["formattingReview"]
    if formatting_review["scope"] != EXPECTED_FORMATTING_REVIEW_SCOPE:
        die("valid fixture formatting review scope drifted")
    if formatting_review["reviewMode"] != "before-after-layout-diff":
        die("valid fixture formatting review mode drifted")
    if formatting_review["usesDiffReview"] is not True:
        die("valid fixture formatting review does not reuse DiffReview")
    if formatting_review["requiresEvidenceLink"] is not True:
        die("valid fixture formatting review missing evidence link requirement")
    if formatting_review["requiresHumanApproval"] is not True:
        die("valid fixture formatting review missing human approval requirement")
    if formatting_review["mainDocumentUnchangedUntilApproval"] is not True:
        die("valid fixture formatting review mutates main document before approval")
    if formatting_review["rawContentInFixture"] is not False:
        die("valid fixture formatting review stores raw content")
    if formatting_review["previewContentInFixture"] is not False:
        die("valid fixture formatting review stores preview content")
    if formatting_review["failureBehavior"] != "fail-closed-user-visible":
        die("valid fixture formatting review failure behavior drifted")
    if formatting_review["runtimeFormattingImplementation"] != "not-started":
        die("valid fixture formatting review runtime drifted")
pass_count += 1

for value in valid_values:
    content_review = value["workspaceUi"]["contentReview"]
    if content_review["scope"] != EXPECTED_CONTENT_REVIEW_SCOPE:
        die("valid fixture content review scope drifted")
    if content_review["reviewMode"] != "evidence-linked-content-diff":
        die("valid fixture content review mode drifted")
    if content_review["usesDiffReview"] is not True:
        die("valid fixture content review does not reuse DiffReview")
    if content_review["requiresEvidenceLink"] is not True:
        die("valid fixture content review missing evidence link requirement")
    if content_review["requiresHumanApproval"] is not True:
        die("valid fixture content review missing human approval requirement")
    if content_review["mainDocumentUnchangedUntilApproval"] is not True:
        die("valid fixture content review mutates main document before approval")
    if content_review["rawContentInFixture"] is not False:
        die("valid fixture content review stores raw content")
    if content_review["suggestionContentInFixture"] is not False:
        die("valid fixture content review stores suggestion content")
    if content_review["failureBehavior"] != "fail-closed-user-visible":
        die("valid fixture content review failure behavior drifted")
    if content_review["runtimeContentReviewImplementation"] != "not-started":
        die("valid fixture content review runtime drifted")
pass_count += 1

for value in valid_values:
    artifact_navigator = value["workspaceUi"]["artifactNavigator"]
    if artifact_navigator["scope"] != ["current-workspace", "current-document"]:
        die("valid fixture artifact navigator scope drifted")
    if artifact_navigator["managedTypes"] != EXPECTED_WORKSPACE_CONTENT_TYPES:
        die("valid fixture artifact navigator managed type roster drifted")
    if artifact_navigator["groupBy"] != ["type", "task"]:
        die("valid fixture artifact navigator grouping drifted")
    if artifact_navigator["sort"] != "recent-first":
        die("valid fixture artifact navigator sort drifted")
    if artifact_navigator["evidenceBadgeVisible"] is not True:
        die("valid fixture artifact navigator missing evidence badge")
    if artifact_navigator["openUsesContentOpeners"] is not True:
        die("valid fixture artifact navigator bypasses content openers")
    if artifact_navigator["readOnlyDetails"] is not True:
        die("valid fixture artifact navigator details are not read-only")
    if artifact_navigator["rawContentInFixture"] is not False:
        die("valid fixture artifact navigator stores raw content")
    if artifact_navigator["mainDocumentMutationAllowed"] is not False:
        die("valid fixture artifact navigator allows main document mutation")
    if artifact_navigator["failureBehavior"] != "fail-closed-user-visible":
        die("valid fixture artifact navigator failure behavior drifted")
    if artifact_navigator["runtimeArtifactNavigatorImplementation"] != "not-started":
        die("valid fixture artifact navigator runtime drifted")
pass_count += 1

for value in valid_values:
    review_queue = value["workspaceUi"]["reviewQueue"]
    if review_queue["itemTypes"] != EXPECTED_REVIEW_QUEUE_TYPES:
        die("valid fixture review queue item type roster drifted")
    if review_queue["states"] != EXPECTED_REVIEW_QUEUE_STATES:
        die("valid fixture review queue state roster drifted")
    if review_queue["filterBy"] != EXPECTED_REVIEW_QUEUE_FILTERS:
        die("valid fixture review queue filters drifted")
    if review_queue["openUsesDiffReview"] is not True:
        die("valid fixture review queue bypasses DiffReview")
    if review_queue["requiresEvidenceLink"] is not True:
        die("valid fixture review queue missing evidence link requirement")
    if review_queue["bulkActions"] != EXPECTED_REVIEW_QUEUE_BULK_ACTIONS:
        die("valid fixture review queue bulk actions drifted")
    if review_queue["bulkApplyRequiresExplicitHumanApproval"] is not True:
        die("valid fixture review queue bulk apply does not require explicit human approval")
    if review_queue["mainDocumentMutationAllowed"] is not False:
        die("valid fixture review queue allows main document mutation")
    if review_queue["rawContentInFixture"] is not False:
        die("valid fixture review queue stores raw content")
    if review_queue["failureBehavior"] != "fail-closed-user-visible":
        die("valid fixture review queue failure behavior drifted")
    if review_queue["runtimeReviewQueueImplementation"] != "not-started":
        die("valid fixture review queue runtime drifted")
pass_count += 1

for value in valid_values:
    evidence_inspector = value["workspaceUi"]["evidenceInspector"]
    if evidence_inspector["sourceTypes"] != EXPECTED_EVIDENCE_INSPECTOR_SOURCE_TYPES:
        die("valid fixture evidence inspector source type roster drifted")
    if evidence_inspector["showsCitationLinks"] is not True:
        die("valid fixture evidence inspector does not show citation links")
    if evidence_inspector["showsAuditTrail"] is not True:
        die("valid fixture evidence inspector does not show audit trail")
    if evidence_inspector["openUsesContentOpeners"] is not True:
        die("valid fixture evidence inspector bypasses content openers")
    if evidence_inspector["redactsRawPayload"] is not True:
        die("valid fixture evidence inspector does not redact raw payloads")
    if evidence_inspector["hashOnlyReferences"] is not True:
        die("valid fixture evidence inspector does not use hash-only references")
    if evidence_inspector["requiresEvidenceLink"] is not True:
        die("valid fixture evidence inspector missing evidence link requirement")
    if evidence_inspector["rawContentInFixture"] is not False:
        die("valid fixture evidence inspector stores raw content")
    if evidence_inspector["mainDocumentMutationAllowed"] is not False:
        die("valid fixture evidence inspector allows main document mutation")
    if evidence_inspector["failureBehavior"] != "fail-closed-user-visible":
        die("valid fixture evidence inspector failure behavior drifted")
    if evidence_inspector["runtimeEvidenceInspectorImplementation"] != "not-started":
        die("valid fixture evidence inspector runtime drifted")
pass_count += 1

for value in valid_values:
    interaction_chrome = value["workspaceUi"]["interactionChrome"]
    if interaction_chrome["layout"] != "sidebar-workbench":
        die("valid fixture interaction chrome layout drifted")
    if interaction_chrome["navigation"] != "segmented-tabs":
        die("valid fixture interaction chrome navigation drifted")
    if interaction_chrome["panels"] != EXPECTED_INTERACTION_PANELS:
        die("valid fixture interaction chrome panel roster drifted")
    if interaction_chrome["defaultPanel"] != "chat":
        die("valid fixture interaction chrome default panel drifted")
    if interaction_chrome["persistentComposer"] is not True:
        die("valid fixture interaction chrome composer is not persistent")
    if interaction_chrome["taskRailVisible"] is not True:
        die("valid fixture interaction chrome task rail is hidden")
    if interaction_chrome["artifactRailVisible"] is not True:
        die("valid fixture interaction chrome artifact rail is hidden")
    if interaction_chrome["reviewRailVisible"] is not True:
        die("valid fixture interaction chrome review rail is hidden")
    if interaction_chrome["evidenceRailVisible"] is not True:
        die("valid fixture interaction chrome evidence rail is hidden")
    keyboard = interaction_chrome["keyboardNavigation"]
    if keyboard["tabOrder"] != EXPECTED_INTERACTION_TAB_ORDER:
        die("valid fixture interaction chrome tab order drifted")
    if keyboard["escapeReturnsFocus"] is not True:
        die("valid fixture interaction chrome Escape focus behavior drifted")
    if keyboard["focusTrap"] is not False:
        die("valid fixture interaction chrome traps focus")
    if interaction_chrome["density"] != "compact-utility":
        die("valid fixture interaction chrome density drifted")
    if interaction_chrome["usesNativeControls"] is not True:
        die("valid fixture interaction chrome does not use native controls")
    if interaction_chrome["modalChatOnly"] is not False:
        die("valid fixture interaction chrome collapsed to modal chat only")
    if interaction_chrome["rawContentInFixture"] is not False:
        die("valid fixture interaction chrome stores raw content")
    if interaction_chrome["failureBehavior"] != "fail-closed-user-visible":
        die("valid fixture interaction chrome failure behavior drifted")
    if interaction_chrome["runtimeInteractionChromeImplementation"] != "not-started":
        die("valid fixture interaction chrome runtime drifted")
pass_count += 1

for value in valid_values:
    preview_matrix = value["workspaceUi"]["previewMatrix"]
    if preview_matrix["contentTypes"] != EXPECTED_PREVIEW_MATRIX_TYPES:
        die("valid fixture preview matrix content type roster drifted")
    if preview_matrix["previewTargets"] != EXPECTED_PREVIEW_MATRIX_TARGETS:
        die("valid fixture preview matrix target roster drifted")
    if preview_matrix["previewModes"] != EXPECTED_PREVIEW_MATRIX_MODES:
        die("valid fixture preview matrix mode roster drifted")
    if preview_matrix["showsEvidenceBadge"] is not True:
        die("valid fixture preview matrix does not show evidence badge")
    if preview_matrix["showsSourceMetadata"] is not True:
        die("valid fixture preview matrix does not show source metadata")
    if preview_matrix["openUsesContentOpeners"] is not True:
        die("valid fixture preview matrix bypasses content openers")
    if preview_matrix["readOnlyPreview"] is not True:
        die("valid fixture preview matrix preview is not read-only")
    if preview_matrix["redactsRawPayload"] is not True:
        die("valid fixture preview matrix does not redact raw payloads")
    if preview_matrix["hashOnlyReferences"] is not True:
        die("valid fixture preview matrix does not use hash-only references")
    if preview_matrix["rawContentInFixture"] is not False:
        die("valid fixture preview matrix stores raw content")
    if preview_matrix["previewContentInFixture"] is not False:
        die("valid fixture preview matrix stores preview content")
    if preview_matrix["mainDocumentMutationAllowed"] is not False:
        die("valid fixture preview matrix allows main document mutation")
    if preview_matrix["failureBehavior"] != "fail-closed-user-visible":
        die("valid fixture preview matrix failure behavior drifted")
    if preview_matrix["runtimePreviewMatrixImplementation"] != "not-started":
        die("valid fixture preview matrix runtime drifted")
pass_count += 1

for value in valid_values:
    action_bar = value["workspaceUi"]["actionBar"]
    if action_bar["placement"] != "sidebar-workbench-header":
        die("valid fixture action bar placement drifted")
    if action_bar["commands"] != EXPECTED_ACTION_BAR_COMMANDS:
        die("valid fixture action bar command roster drifted")
    if action_bar["commandTargets"] != EXPECTED_ACTION_BAR_TARGETS:
        die("valid fixture action bar target roster drifted")
    if action_bar["keyboardAccessible"] is not True:
        die("valid fixture action bar is not keyboard accessible")
    if action_bar["usesNativeControls"] is not True:
        die("valid fixture action bar does not use native controls")
    if action_bar["requiresVisibleState"] is not True:
        die("valid fixture action bar lacks visible command state")
    if action_bar["requiresEvidenceLink"] is not True:
        die("valid fixture action bar missing evidence link requirement")
    if action_bar["usesContentOpeners"] is not True:
        die("valid fixture action bar bypasses content openers")
    if action_bar["usesDiffReview"] is not True:
        die("valid fixture action bar does not use DiffReview")
    if action_bar["bulkApplyRequiresExplicitHumanApproval"] is not True:
        die("valid fixture action bar bulk apply lacks explicit human approval")
    if action_bar["autoApplyAllowed"] is not False:
        die("valid fixture action bar allows auto-apply")
    if action_bar["hiddenActionsAllowed"] is not False:
        die("valid fixture action bar allows hidden actions")
    if action_bar["mouseOnlyActionsAllowed"] is not False:
        die("valid fixture action bar allows mouse-only actions")
    if action_bar["rawContentInFixture"] is not False:
        die("valid fixture action bar stores raw content")
    if action_bar["mainDocumentMutationAllowed"] is not False:
        die("valid fixture action bar allows main document mutation")
    if action_bar["failureBehavior"] != "fail-closed-user-visible":
        die("valid fixture action bar failure behavior drifted")
    if action_bar["runtimeActionBarImplementation"] != "not-started":
        die("valid fixture action bar runtime drifted")
pass_count += 1

for value in valid_values:
    filter_search = value["workspaceUi"]["filterSearch"]
    if filter_search["scope"] != ["current-workspace", "current-document"]:
        die("valid fixture filter/search scope drifted")
    if filter_search["surfaces"] != EXPECTED_FILTER_SEARCH_SURFACES:
        die("valid fixture filter/search surface roster drifted")
    if filter_search["filterBy"] != EXPECTED_FILTER_SEARCH_FILTERS:
        die("valid fixture filter/search filter roster drifted")
    if filter_search["searchFields"] != EXPECTED_FILTER_SEARCH_FIELDS:
        die("valid fixture filter/search field roster drifted")
    if filter_search["sortOptions"] != ["recent-first", "type", "state", "source"]:
        die("valid fixture filter/search sort roster drifted")
    if filter_search["metadataOnly"] is not True:
        die("valid fixture filter/search is not metadata-only")
    if filter_search["hashOnlyReferences"] is not True:
        die("valid fixture filter/search does not use hash-only references")
    if filter_search["redactsRawPayload"] is not True:
        die("valid fixture filter/search does not redact raw payloads")
    if filter_search["rawContentIndexed"] is not False:
        die("valid fixture filter/search indexes raw content")
    if filter_search["rawContentInFixture"] is not False:
        die("valid fixture filter/search stores raw content")
    if filter_search["crossDocumentSearch"] is not False:
        die("valid fixture filter/search crosses documents")
    if filter_search["globalIndex"] is not False:
        die("valid fixture filter/search uses a global index")
    if filter_search["usesContentOpeners"] is not True:
        die("valid fixture filter/search bypasses content openers")
    if filter_search["requiresEvidenceLink"] is not True:
        die("valid fixture filter/search missing evidence link requirement")
    if filter_search["failureBehavior"] != "fail-closed-user-visible":
        die("valid fixture filter/search failure behavior drifted")
    if filter_search["runtimeFilterSearchImplementation"] != "not-started":
        die("valid fixture filter/search runtime drifted")
pass_count += 1

for value in valid_values:
    context_handoff = value["workspaceUi"]["contextHandoff"]
    if context_handoff["entrySurfaces"] != EXPECTED_CONTEXT_HANDOFF_ENTRY_SURFACES:
        die("valid fixture context handoff entry surface roster drifted")
    if context_handoff["handoffTargets"] != EXPECTED_CONTEXT_HANDOFF_TARGETS:
        die("valid fixture context handoff target roster drifted")
    if context_handoff["preserves"] != EXPECTED_CONTEXT_HANDOFF_PRESERVES:
        die("valid fixture context handoff preserved metadata roster drifted")
    if context_handoff["requiresVisibleBreadcrumb"] is not True:
        die("valid fixture context handoff missing visible breadcrumb")
    if context_handoff["requiresBackNavigation"] is not True:
        die("valid fixture context handoff missing back navigation")
    if context_handoff["requiresFocusReturn"] is not True:
        die("valid fixture context handoff missing focus return")
    if context_handoff["requiresEvidenceLink"] is not True:
        die("valid fixture context handoff missing evidence link requirement")
    if context_handoff["usesContentOpeners"] is not True:
        die("valid fixture context handoff bypasses content openers")
    if context_handoff["usesDiffReview"] is not True:
        die("valid fixture context handoff bypasses DiffReview")
    if context_handoff["metadataOnly"] is not True:
        die("valid fixture context handoff is not metadata-only")
    if context_handoff["hashOnlyReferences"] is not True:
        die("valid fixture context handoff does not use hash-only references")
    if context_handoff["redactsRawPayload"] is not True:
        die("valid fixture context handoff does not redact raw payloads")
    if context_handoff["rawContentInFixture"] is not False:
        die("valid fixture context handoff stores raw content")
    if context_handoff["previewContentInFixture"] is not False:
        die("valid fixture context handoff stores preview content")
    if context_handoff["mainDocumentMutationAllowed"] is not False:
        die("valid fixture context handoff allows main document mutation")
    if context_handoff["autoApplyAllowed"] is not False:
        die("valid fixture context handoff allows auto-apply")
    if context_handoff["failureBehavior"] != "fail-closed-user-visible":
        die("valid fixture context handoff failure behavior drifted")
    if context_handoff["runtimeContextHandoffImplementation"] != "not-started":
        die("valid fixture context handoff runtime drifted")
pass_count += 1

for value in valid_values:
    review_state_sync = value["workspaceUi"]["reviewStateSync"]
    if review_state_sync["stateSources"] != EXPECTED_REVIEW_STATE_SYNC_SURFACES:
        die("valid fixture review state sync source roster drifted")
    if review_state_sync["states"] != EXPECTED_REVIEW_QUEUE_STATES:
        die("valid fixture review state sync state roster drifted")
    if review_state_sync["syncTargets"] != EXPECTED_REVIEW_STATE_SYNC_SURFACES:
        die("valid fixture review state sync target roster drifted")
    if review_state_sync["transitionEvents"] != EXPECTED_REVIEW_STATE_SYNC_TRANSITIONS:
        die("valid fixture review state sync transition roster drifted")
    if review_state_sync["requiresEvidenceLink"] is not True:
        die("valid fixture review state sync missing evidence link requirement")
    if review_state_sync["requiresVisibleState"] is not True:
        die("valid fixture review state sync does not expose visible state")
    if review_state_sync["requiresHumanApproval"] is not True:
        die("valid fixture review state sync missing human approval")
    if review_state_sync["bulkApplyRequiresExplicitHumanApproval"] is not True:
        die("valid fixture review state sync bulk apply lacks explicit human approval")
    if review_state_sync["usesDiffReview"] is not True:
        die("valid fixture review state sync bypasses DiffReview")
    if review_state_sync["usesContentOpeners"] is not True:
        die("valid fixture review state sync bypasses content openers")
    if review_state_sync["metadataOnly"] is not True:
        die("valid fixture review state sync is not metadata-only")
    if review_state_sync["hashOnlyReferences"] is not True:
        die("valid fixture review state sync does not use hash-only references")
    if review_state_sync["redactsRawPayload"] is not True:
        die("valid fixture review state sync does not redact raw payloads")
    if review_state_sync["rawContentInFixture"] is not False:
        die("valid fixture review state sync stores raw content")
    if review_state_sync["mainDocumentMutationAllowed"] is not False:
        die("valid fixture review state sync allows main document mutation")
    if review_state_sync["autoApplyAllowed"] is not False:
        die("valid fixture review state sync allows auto-apply")
    if review_state_sync["conflictBehavior"] != "fail-closed-user-visible":
        die("valid fixture review state sync conflict behavior drifted")
    if review_state_sync["failureBehavior"] != "fail-closed-user-visible":
        die("valid fixture review state sync failure behavior drifted")
    if review_state_sync["runtimeReviewStateSyncImplementation"] != "not-started":
        die("valid fixture review state sync runtime drifted")
pass_count += 1

for value in valid_values:
    activity_timeline = value["workspaceUi"]["activityTimeline"]
    if activity_timeline["events"] != EXPECTED_ACTIVITY_TIMELINE_EVENTS:
        die("valid fixture activity timeline event roster drifted")
    if activity_timeline["surfaces"] != EXPECTED_ACTIVITY_TIMELINE_SURFACES:
        die("valid fixture activity timeline surface roster drifted")
    if activity_timeline["links"] != EXPECTED_ACTIVITY_TIMELINE_LINKS:
        die("valid fixture activity timeline link roster drifted")
    if activity_timeline["order"] != "chronological":
        die("valid fixture activity timeline order drifted")
    if activity_timeline["appendOnly"] is not True:
        die("valid fixture activity timeline is not append-only")
    if activity_timeline["requiresEvidenceLink"] is not True:
        die("valid fixture activity timeline missing evidence link requirement")
    if activity_timeline["requiresVisibleTimestamp"] is not True:
        die("valid fixture activity timeline missing visible timestamp")
    if activity_timeline["requiresVisibleActor"] is not True:
        die("valid fixture activity timeline missing visible actor")
    if activity_timeline["requiresOpenTarget"] is not True:
        die("valid fixture activity timeline missing open target")
    if activity_timeline["usesContentOpeners"] is not True:
        die("valid fixture activity timeline bypasses content openers")
    if activity_timeline["usesDiffReview"] is not True:
        die("valid fixture activity timeline bypasses DiffReview")
    if activity_timeline["usesEvidenceInspector"] is not True:
        die("valid fixture activity timeline bypasses evidence inspector")
    if activity_timeline["metadataOnly"] is not True:
        die("valid fixture activity timeline is not metadata-only")
    if activity_timeline["hashOnlyReferences"] is not True:
        die("valid fixture activity timeline does not use hash-only references")
    if activity_timeline["redactsRawPayload"] is not True:
        die("valid fixture activity timeline does not redact raw payloads")
    if activity_timeline["rawContentInFixture"] is not False:
        die("valid fixture activity timeline stores raw content")
    if activity_timeline["previewContentInFixture"] is not False:
        die("valid fixture activity timeline stores preview content")
    if activity_timeline["transcriptContentInFixture"] is not False:
        die("valid fixture activity timeline stores transcript content")
    if activity_timeline["mainDocumentMutationAllowed"] is not False:
        die("valid fixture activity timeline allows main document mutation")
    if activity_timeline["autoApplyAllowed"] is not False:
        die("valid fixture activity timeline allows auto-apply")
    if activity_timeline["failureBehavior"] != "fail-closed-user-visible":
        die("valid fixture activity timeline failure behavior drifted")
    if activity_timeline["runtimeActivityTimelineImplementation"] != "not-started":
        die("valid fixture activity timeline runtime drifted")
pass_count += 1

for value in valid_values:
    session_snapshot = value["workspaceUi"]["sessionSnapshot"]
    if session_snapshot["scope"] != ["current-workspace", "current-document"]:
        die("valid fixture session snapshot scope drifted")
    if session_snapshot["restores"] != EXPECTED_SESSION_SNAPSHOT_RESTORES:
        die("valid fixture session snapshot restore roster drifted")
    if session_snapshot["surfaces"] != EXPECTED_SESSION_SNAPSHOT_SURFACES:
        die("valid fixture session snapshot surface roster drifted")
    if session_snapshot["resumeSummaryVisible"] is not True:
        die("valid fixture session snapshot missing resume summary")
    if session_snapshot["requiresExplicitResume"] is not True:
        die("valid fixture session snapshot does not require explicit resume")
    if session_snapshot["requiresVisibleTimestamp"] is not True:
        die("valid fixture session snapshot missing visible timestamp")
    if session_snapshot["requiresVisibleDocumentBinding"] is not True:
        die("valid fixture session snapshot missing visible document binding")
    if session_snapshot["usesContentOpeners"] is not True:
        die("valid fixture session snapshot bypasses content openers")
    if session_snapshot["usesDiffReview"] is not True:
        die("valid fixture session snapshot bypasses DiffReview")
    if session_snapshot["usesEvidenceInspector"] is not True:
        die("valid fixture session snapshot bypasses evidence inspector")
    if session_snapshot["usesActivityTimeline"] is not True:
        die("valid fixture session snapshot bypasses activity timeline")
    if session_snapshot["metadataOnly"] is not True:
        die("valid fixture session snapshot is not metadata-only")
    if session_snapshot["hashOnlyReferences"] is not True:
        die("valid fixture session snapshot does not use hash-only references")
    if session_snapshot["redactsRawPayload"] is not True:
        die("valid fixture session snapshot does not redact raw payloads")
    if session_snapshot["rawContentInFixture"] is not False:
        die("valid fixture session snapshot stores raw content")
    if session_snapshot["previewContentInFixture"] is not False:
        die("valid fixture session snapshot stores preview content")
    if session_snapshot["transcriptContentInFixture"] is not False:
        die("valid fixture session snapshot stores transcript content")
    if session_snapshot["crossDocumentRestore"] is not False:
        die("valid fixture session snapshot restores across documents")
    if session_snapshot["cloudSync"] is not False:
        die("valid fixture session snapshot syncs to cloud")
    if session_snapshot["mainDocumentMutationAllowed"] is not False:
        die("valid fixture session snapshot allows main document mutation")
    if session_snapshot["autoApplyAllowed"] is not False:
        die("valid fixture session snapshot allows auto-apply")
    if session_snapshot["failureBehavior"] != "fail-closed-user-visible":
        die("valid fixture session snapshot failure behavior drifted")
    if session_snapshot["runtimeSessionSnapshotImplementation"] != "not-started":
        die("valid fixture session snapshot runtime drifted")
pass_count += 1

for value in valid_values:
    attention_routing = value["workspaceUi"]["attentionRouting"]
    if attention_routing["scope"] != ["current-workspace", "current-document"]:
        die("valid fixture attention routing scope drifted")
    if attention_routing["triggers"] != EXPECTED_ATTENTION_ROUTING_TRIGGERS:
        die("valid fixture attention routing trigger roster drifted")
    if attention_routing["surfaces"] != EXPECTED_ATTENTION_ROUTING_SURFACES:
        die("valid fixture attention routing surface roster drifted")
    if attention_routing["routesTo"] != EXPECTED_ATTENTION_ROUTING_TARGETS:
        die("valid fixture attention routing target roster drifted")
    if attention_routing["requiresOpenTarget"] is not True:
        die("valid fixture attention routing missing open target")
    if attention_routing["requiresVisibleReason"] is not True:
        die("valid fixture attention routing missing visible reason")
    if attention_routing["requiresVisibleTimestamp"] is not True:
        die("valid fixture attention routing missing visible timestamp")
    if attention_routing["requiresKeyboardAccess"] is not True:
        die("valid fixture attention routing missing keyboard access")
    if attention_routing["usesNativeControls"] is not True:
        die("valid fixture attention routing bypasses native controls")
    if attention_routing["usesActionBar"] is not True:
        die("valid fixture attention routing bypasses action bar")
    if attention_routing["usesActivityTimeline"] is not True:
        die("valid fixture attention routing bypasses activity timeline")
    if attention_routing["usesSessionSnapshot"] is not True:
        die("valid fixture attention routing bypasses session snapshot")
    if attention_routing["usesEvidenceInspector"] is not True:
        die("valid fixture attention routing bypasses evidence inspector")
    if attention_routing["usesDiffReview"] is not True:
        die("valid fixture attention routing bypasses DiffReview")
    if attention_routing["metadataOnly"] is not True:
        die("valid fixture attention routing is not metadata-only")
    if attention_routing["hashOnlyReferences"] is not True:
        die("valid fixture attention routing does not use hash-only references")
    if attention_routing["redactsRawPayload"] is not True:
        die("valid fixture attention routing does not redact raw payloads")
    if attention_routing["rawContentInFixture"] is not False:
        die("valid fixture attention routing stores raw content")
    if attention_routing["previewContentInFixture"] is not False:
        die("valid fixture attention routing stores preview content")
    if attention_routing["transcriptContentInFixture"] is not False:
        die("valid fixture attention routing stores transcript content")
    if attention_routing["systemNotificationRuntime"] != "not-started":
        die("valid fixture attention routing starts system notification runtime")
    if attention_routing["cloudPush"] is not False:
        die("valid fixture attention routing uses cloud push")
    if attention_routing["autoOpenAllowed"] is not False:
        die("valid fixture attention routing allows auto-open")
    if attention_routing["autoApplyAllowed"] is not False:
        die("valid fixture attention routing allows auto-apply")
    if attention_routing["mainDocumentMutationAllowed"] is not False:
        die("valid fixture attention routing allows main document mutation")
    if attention_routing["failureBehavior"] != "fail-closed-user-visible":
        die("valid fixture attention routing failure behavior drifted")
    if attention_routing["runtimeAttentionRoutingImplementation"] != "not-started":
        die("valid fixture attention routing runtime drifted")
pass_count += 1

for value in valid_values:
    native_style = value["workspaceUi"]["nativeStyle"]
    if native_style["layout"] != "sidebar-workbench":
        die("valid fixture native style layout drifted")
    if native_style["density"] != "compact-utility":
        die("valid fixture native style density drifted")
    if native_style["surfaces"] != EXPECTED_NATIVE_STYLE_SURFACES:
        die("valid fixture native style surface roster drifted")
    if native_style["navigation"] != "segmented-tabs":
        die("valid fixture native style navigation drifted")
    if native_style["usesNativeControls"] is not True:
        die("valid fixture native style bypasses native controls")
    if native_style["stableDimensions"] != EXPECTED_NATIVE_STYLE_STABLE_DIMENSIONS:
        die("valid fixture native style stable dimension roster drifted")
    if native_style["textOverflowPolicy"] != "wrap-or-ellipsize-no-overlap":
        die("valid fixture native style text overflow policy drifted")
    if native_style["cardPileLayout"] is not False:
        die("valid fixture native style uses card-pile layout")
    if native_style["modalOnly"] is not False:
        die("valid fixture native style is modal-only")
    if native_style["marketingHero"] is not False:
        die("valid fixture native style uses marketing hero layout")
    if native_style["keyboardAccessible"] is not True:
        die("valid fixture native style missing keyboard accessibility")
    if native_style["focusReturn"] is not True:
        die("valid fixture native style missing focus return")
    if native_style["metadataOnly"] is not True:
        die("valid fixture native style is not metadata-only")
    if native_style["rawContentInFixture"] is not False:
        die("valid fixture native style stores raw content")
    if native_style["previewContentInFixture"] is not False:
        die("valid fixture native style stores preview content")
    if native_style["transcriptContentInFixture"] is not False:
        die("valid fixture native style stores transcript content")
    if native_style["mainDocumentMutationAllowed"] is not False:
        die("valid fixture native style allows main document mutation")
    if native_style["autoApplyAllowed"] is not False:
        die("valid fixture native style allows auto-apply")
    if native_style["failureBehavior"] != "fail-closed-user-visible":
        die("valid fixture native style failure behavior drifted")
    if native_style["runtimeNativeStyleImplementation"] != "not-started":
        die("valid fixture native style runtime drifted")
pass_count += 1

for value in valid_values:
    content_registry = value["workspaceUi"]["contentRegistry"]
    if content_registry["scope"] != ["current-workspace", "current-document"]:
        die("valid fixture content registry scope drifted")
    if content_registry["types"] != EXPECTED_CONTENT_REGISTRY_TYPES:
        die("valid fixture content registry type roster drifted")
    if content_registry["states"] != EXPECTED_CONTENT_REGISTRY_STATES:
        die("valid fixture content registry state roster drifted")
    if content_registry["requiredFields"] != EXPECTED_CONTENT_REGISTRY_FIELDS:
        die("valid fixture content registry required field roster drifted")
    if content_registry["openTargets"] != EXPECTED_CONTENT_REGISTRY_OPEN_TARGETS:
        die("valid fixture content registry open target roster drifted")
    if content_registry["previewModes"] != EXPECTED_PREVIEW_MATRIX_MODES:
        die("valid fixture content registry preview mode roster drifted")
    if content_registry["usesContentOpeners"] is not True:
        die("valid fixture content registry bypasses content openers")
    if content_registry["usesPreviewMatrix"] is not True:
        die("valid fixture content registry bypasses preview matrix")
    if content_registry["usesEvidenceInspector"] is not True:
        die("valid fixture content registry bypasses evidence inspector")
    if content_registry["usesReviewQueue"] is not True:
        die("valid fixture content registry bypasses review queue")
    if content_registry["metadataOnly"] is not True:
        die("valid fixture content registry is not metadata-only")
    if content_registry["hashOnlyReferences"] is not True:
        die("valid fixture content registry does not use hash-only references")
    if content_registry["redactsRawPayload"] is not True:
        die("valid fixture content registry does not redact raw payloads")
    if content_registry["rawContentInFixture"] is not False:
        die("valid fixture content registry stores raw content")
    if content_registry["previewContentInFixture"] is not False:
        die("valid fixture content registry stores preview content")
    if content_registry["transcriptContentInFixture"] is not False:
        die("valid fixture content registry stores transcript content")
    if content_registry["mainDocumentMutationAllowed"] is not False:
        die("valid fixture content registry allows main document mutation")
    if content_registry["autoOpenAllowed"] is not False:
        die("valid fixture content registry allows auto-open")
    if content_registry["autoApplyAllowed"] is not False:
        die("valid fixture content registry allows auto-apply")
    if content_registry["failureBehavior"] != "fail-closed-user-visible":
        die("valid fixture content registry failure behavior drifted")
    if content_registry["runtimeContentRegistryImplementation"] != "not-started":
        die("valid fixture content registry runtime drifted")
pass_count += 1

for value in valid_values:
    source_provenance = value["workspaceUi"]["sourceProvenance"]
    if source_provenance["scope"] != ["current-workspace", "current-document"]:
        die("valid fixture source provenance scope drifted")
    if source_provenance["sourceTypes"] != EXPECTED_SOURCE_PROVENANCE_SOURCE_TYPES:
        die("valid fixture source provenance source type roster drifted")
    if source_provenance["requiredFields"] != EXPECTED_SOURCE_PROVENANCE_REQUIRED_FIELDS:
        die("valid fixture source provenance required field roster drifted")
    if source_provenance["surfaces"] != EXPECTED_SOURCE_PROVENANCE_SURFACES:
        die("valid fixture source provenance surface roster drifted")
    if source_provenance["citationTargets"] != EXPECTED_CONTENT_REGISTRY_OPEN_TARGETS:
        die("valid fixture source provenance citation target roster drifted")
    if source_provenance["mapsAiClaimsToSources"] is not True:
        die("valid fixture source provenance does not map AI claims to sources")
    if source_provenance["mapsSuggestionsToEvidence"] is not True:
        die("valid fixture source provenance does not map suggestions to evidence")
    if source_provenance["mapsFormattingChangesToStyleSources"] is not True:
        die("valid fixture source provenance does not map formatting changes")
    if source_provenance["requiresEvidenceLink"] is not True:
        die("valid fixture source provenance missing evidence link")
    if source_provenance["requiresOpenTarget"] is not True:
        die("valid fixture source provenance missing open target")
    if source_provenance["requiresVisibleCitationBadge"] is not True:
        die("valid fixture source provenance missing visible citation badge")
    if source_provenance["usesContentRegistry"] is not True:
        die("valid fixture source provenance bypasses content registry")
    if source_provenance["usesContentOpeners"] is not True:
        die("valid fixture source provenance bypasses content openers")
    if source_provenance["usesEvidenceInspector"] is not True:
        die("valid fixture source provenance bypasses evidence inspector")
    if source_provenance["usesReviewQueue"] is not True:
        die("valid fixture source provenance bypasses review queue")
    if source_provenance["usesDiffReview"] is not True:
        die("valid fixture source provenance bypasses DiffReview")
    if source_provenance["metadataOnly"] is not True:
        die("valid fixture source provenance is not metadata-only")
    if source_provenance["hashOnlyReferences"] is not True:
        die("valid fixture source provenance does not use hash-only references")
    if source_provenance["redactsRawPayload"] is not True:
        die("valid fixture source provenance does not redact raw payloads")
    if source_provenance["rawContentInFixture"] is not False:
        die("valid fixture source provenance stores raw content")
    if source_provenance["sourceContentInFixture"] is not False:
        die("valid fixture source provenance stores source content")
    if source_provenance["previewContentInFixture"] is not False:
        die("valid fixture source provenance stores preview content")
    if source_provenance["transcriptContentInFixture"] is not False:
        die("valid fixture source provenance stores transcript content")
    if source_provenance["mainDocumentMutationAllowed"] is not False:
        die("valid fixture source provenance allows main document mutation")
    if source_provenance["autoOpenAllowed"] is not False:
        die("valid fixture source provenance allows auto-open")
    if source_provenance["autoApplyAllowed"] is not False:
        die("valid fixture source provenance allows auto-apply")
    if source_provenance["failureBehavior"] != "fail-closed-user-visible":
        die("valid fixture source provenance failure behavior drifted")
    if source_provenance["runtimeSourceProvenanceImplementation"] != "not-started":
        die("valid fixture source provenance runtime drifted")
pass_count += 1

for value in valid_values:
    clipboard_materialization = value["workspaceUi"]["clipboardMaterialization"]
    if clipboard_materialization["scope"] != ["chat-composer", "current-workspace", "current-document"]:
        die("valid fixture clipboard materialization scope drifted")
    if clipboard_materialization["materializesInputTypes"] != EXPECTED_CLIPBOARD_MATERIALIZATION_INPUT_TYPES:
        die("valid fixture clipboard materialization input roster drifted")
    if clipboard_materialization["thresholdPolicy"] != "large-or-structured-content":
        die("valid fixture clipboard materialization threshold drifted")
    if clipboard_materialization["storage"] != "local-temp-content-object":
        die("valid fixture clipboard materialization storage drifted")
    if clipboard_materialization["referenceInsertedIntoChat"] is not True:
        die("valid fixture clipboard materialization does not insert chat references")
    if clipboard_materialization["transcriptStoresReferenceOnly"] is not True:
        die("valid fixture clipboard materialization transcript is not reference-only")
    if clipboard_materialization["historyStoresReferenceOnly"] is not True:
        die("valid fixture clipboard materialization history is not reference-only")
    if clipboard_materialization["preservesFormattingMetadata"] is not True:
        die("valid fixture clipboard materialization drops formatting metadata")
    if clipboard_materialization["usesContentRegistry"] is not True:
        die("valid fixture clipboard materialization bypasses content registry")
    if clipboard_materialization["usesArtifactNavigator"] is not True:
        die("valid fixture clipboard materialization bypasses artifact navigator")
    if clipboard_materialization["usesContentOpeners"] is not True:
        die("valid fixture clipboard materialization bypasses content openers")
    if clipboard_materialization["usesSourceProvenance"] is not True:
        die("valid fixture clipboard materialization bypasses source provenance")
    if clipboard_materialization["requiresHashReference"] is not True:
        die("valid fixture clipboard materialization lacks hash references")
    if clipboard_materialization["requiresEvidenceLink"] is not True:
        die("valid fixture clipboard materialization lacks evidence links")
    if clipboard_materialization["rawClipboardContentInFixture"] is not False:
        die("valid fixture clipboard materialization stores raw clipboard content")
    if clipboard_materialization["rawContentInTranscript"] is not False:
        die("valid fixture clipboard materialization stores raw transcript content")
    if clipboard_materialization["rawContentInHistory"] is not False:
        die("valid fixture clipboard materialization stores raw history content")
    if clipboard_materialization["mainDocumentMutationAllowed"] is not False:
        die("valid fixture clipboard materialization allows main document mutation")
    if clipboard_materialization["autoApplyAllowed"] is not False:
        die("valid fixture clipboard materialization allows auto-apply")
    if clipboard_materialization["failureBehavior"] != "fail-closed-user-visible":
        die("valid fixture clipboard materialization failure behavior drifted")
    if clipboard_materialization["runtimeClipboardMaterializationImplementation"] != "not-started":
        die("valid fixture clipboard materialization runtime drifted")
pass_count += 1

if list(Path("docs/schemas").glob("in-app-chat*.schema.json")):
    die("W1 in-app-chat must not introduce a V3 schema file")
for value in valid_values:
    if value["gates"] != {
        "runtimeImplementation": "not-started",
        "requiresExplicitUserAuthorization": True,
    }:
        die("valid fixture runtime gate drifted")
pass_count += 1

w1_text = w1_spec.read_text(encoding="utf-8")
shortcut_text = shortcut_survey.read_text(encoding="utf-8")
wireframe_text = sidebar_wireframe.read_text(encoding="utf-8")
context_text = context_policy.read_text(encoding="utf-8")
autocomplete_text = autocomplete_policy.read_text(encoding="utf-8")
markdown_text = markdown_policy.read_text(encoding="utf-8")
history_text = history_policy.read_text(encoding="utf-8")
streaming_text = streaming_policy.read_text(encoding="utf-8")
workspace_ui_text = workspace_ui_policy.read_text(encoding="utf-8")
content_opener_text = content_opener_policy.read_text(encoding="utf-8")
formatting_review_text = formatting_review_policy.read_text(encoding="utf-8")
content_review_text = content_review_policy.read_text(encoding="utf-8")
artifact_navigator_text = artifact_navigator_policy.read_text(encoding="utf-8")
review_queue_text = review_queue_policy.read_text(encoding="utf-8")
evidence_inspector_text = evidence_inspector_policy.read_text(encoding="utf-8")
interaction_chrome_text = interaction_chrome_policy.read_text(encoding="utf-8")
preview_matrix_text = preview_matrix_policy.read_text(encoding="utf-8")
action_bar_text = action_bar_policy.read_text(encoding="utf-8")
filter_search_text = filter_search_policy.read_text(encoding="utf-8")
context_handoff_text = context_handoff_policy.read_text(encoding="utf-8")
review_state_sync_text = review_state_sync_policy.read_text(encoding="utf-8")
activity_timeline_text = activity_timeline_policy.read_text(encoding="utf-8")
session_snapshot_text = session_snapshot_policy.read_text(encoding="utf-8")
attention_routing_text = attention_routing_policy.read_text(encoding="utf-8")
native_style_text = native_style_policy.read_text(encoding="utf-8")
content_registry_text = content_registry_policy.read_text(encoding="utf-8")
source_provenance_text = source_provenance_policy.read_text(encoding="utf-8")
clipboard_text = clipboard_policy.read_text(encoding="utf-8")
w5_text = w5_spec.read_text(encoding="utf-8")
master_text = master_plan.read_text(encoding="utf-8")
sweep_text = sweep_path.read_text(encoding="utf-8")
workflow_text = workflow_path.read_text(encoding="utf-8")
required_refs = [
    (w1_text, "in-app-chat fixture self-test active", "W1 status"),
    (w1_text, "docs/product/v3/w1-keyboard-shortcut-survey.md", "W1 shortcut survey"),
    (w1_text, "docs/product/v3/w1-sidebar-uiwireframe.md", "W1 sidebar wireframe"),
    (w1_text, "docs/product/v3/w1-context-syntax-policy.md", "W1 context syntax policy"),
    (w1_text, "docs/product/v3/w1-context-autocomplete-policy.md", "W1 context autocomplete policy"),
    (w1_text, "docs/product/v3/w1-markdown-rendering-policy.md", "W1 Markdown policy"),
    (w1_text, "docs/product/v3/w1-chat-history-policy.md", "W1 chat history policy"),
    (w1_text, "docs/product/v3/w1-streaming-state-policy.md", "W1 streaming policy"),
    (w1_text, "docs/product/v3/w1-ai-workspace-ui-policy.md", "W1 AI workspace UI policy"),
    (w1_text, "docs/product/v3/w1-content-opener-policy.md", "W1 content opener policy"),
    (w1_text, "docs/product/v3/w1-formatting-review-policy.md", "W1 formatting review policy"),
    (w1_text, "docs/product/v3/w1-content-review-policy.md", "W1 content review policy"),
    (w1_text, "docs/product/v3/w1-artifact-navigator-policy.md", "W1 artifact navigator policy"),
    (w1_text, "docs/product/v3/w1-review-queue-policy.md", "W1 review queue policy"),
    (w1_text, "docs/product/v3/w1-evidence-inspector-policy.md", "W1 evidence inspector policy"),
    (w1_text, "docs/product/v3/w1-interaction-chrome-policy.md", "W1 interaction chrome policy"),
    (w1_text, "docs/product/v3/w1-content-preview-matrix-policy.md", "W1 content preview matrix policy"),
    (w1_text, "docs/product/v3/w1-workspace-action-bar-policy.md", "W1 workspace action bar policy"),
    (w1_text, "docs/product/v3/w1-workspace-filter-search-policy.md", "W1 workspace filter/search policy"),
    (w1_text, "docs/product/v3/w1-workspace-context-handoff-policy.md", "W1 workspace context handoff policy"),
    (w1_text, "docs/product/v3/w1-workspace-review-state-sync-policy.md", "W1 workspace review state sync policy"),
    (w1_text, "docs/product/v3/w1-workspace-activity-timeline-policy.md", "W1 workspace activity timeline policy"),
    (w1_text, "docs/product/v3/w1-workspace-session-snapshot-policy.md", "W1 workspace session snapshot policy"),
    (w1_text, "docs/product/v3/w1-workspace-attention-routing-policy.md", "W1 workspace attention routing policy"),
    (w1_text, "docs/product/v3/w1-workspace-native-style-policy.md", "W1 workspace native style policy"),
    (w1_text, "docs/product/v3/w1-workspace-content-registry-policy.md", "W1 workspace content registry policy"),
    (w1_text, "docs/product/v3/w1-workspace-source-provenance-policy.md", "W1 workspace source provenance policy"),
    (w1_text, "docs/product/v3/w1-chat-clipboard-materialization-policy.md", "W1 chat clipboard materialization policy"),
    (w1_text, "docs/qa/fixtures/v3/in-app-chat/", "W1 fixture dir"),
    (w1_text, "tests/v3-in-app-chat-test.sh", "W1 self-test"),
    (shortcut_text, "command-palette-chat-fallback", "shortcut fallback route"),
    (shortcut_text, "directAcceleratorRegistration=false", "shortcut direct registration guard"),
    (wireframe_text, "sfx2-sidebar", "wireframe sidebar container"),
    (wireframe_text, "No direct accelerator registration", "wireframe non-goal"),
    (context_text, "@(selection|doc|connector:[a-z0-9-]+)", "context grammar"),
    (context_text, "implicit-full-doc-context.json", "implicit context guard"),
    (context_text, "unknown-context-mention.json", "unknown mention guard"),
    (context_text, "connector-write-context.json", "connector write guard"),
    (autocomplete_text, "chat-input-only", "autocomplete chat input scope"),
    (autocomplete_text, "delegate-existing-controls", "autocomplete Office delegation"),
    (autocomplete_text, "global-autocomplete-hijack.json", "global autocomplete guard"),
    (autocomplete_text, "unknown-connector-suggestion.json", "unknown connector suggestion guard"),
    (autocomplete_text, "raw-context-preview.json", "raw context preview guard"),
    (autocomplete_text, "autocomplete-runtime-parser-started.json", "autocomplete runtime guard"),
    (markdown_text, "paragraph, heading, list, code-fence, table", "Markdown block subset"),
    (markdown_text, "raw-html-rendering.json", "raw HTML rendering guard"),
    (markdown_text, "webview-renderer.json", "WebView rendering guard"),
    (markdown_text, "remote-image-rendering.json", "remote image rendering guard"),
    (history_text, "per-doc-local", "history per-doc-local scope"),
    (history_text, "global-history-leakage.json", "global history guard"),
    (history_text, "cloud-history-sync.json", "cloud history sync guard"),
    (history_text, "raw-transcript-history.json", "raw transcript history guard"),
    (history_text, "missing-history-clear-control.json", "history clear control guard"),
    (streaming_text, "idle, requesting, streaming, awaiting-approval, applied, failed, cancelled", "streaming state roster"),
    (streaming_text, "streaming-mutates-document.json", "streaming mutation guard"),
    (streaming_text, "partial-chunks-persisted.json", "partial chunks guard"),
    (streaming_text, "missing-terminal-evidence.json", "terminal evidence guard"),
    (streaming_text, "unsupported-stream-state.json", "unsupported state guard"),
    (workspace_ui_text, "conversation-plus-progress", "workspace conversation plus progress"),
    (workspace_ui_text, "ai-workspace-sidebar", "workspace sidebar shell"),
    (workspace_ui_text, "content review", "workspace content review"),
    (workspace_ui_text, "formatting review", "workspace formatting review"),
    (workspace_ui_text, "before-after-preview", "workspace layout preview"),
    (workspace_ui_text, "document, selection, connector-result, knowledge-index-result, evidence-record, task-step", "workspace content type roster"),
    (workspace_ui_text, "workspace-modal-chat-only.json", "workspace modal-only guard"),
    (workspace_ui_text, "workspace-missing-task-progress.json", "workspace missing progress guard"),
    (workspace_ui_text, "workspace-review-without-evidence.json", "workspace review evidence guard"),
    (workspace_ui_text, "workspace-formatting-no-preview.json", "workspace formatting preview guard"),
    (workspace_ui_text, "workspace-openers-runtime-started.json", "workspace opener runtime guard"),
    (content_opener_text, "routePolicy.task-step=diff-review", "content opener task-step route"),
    (content_opener_text, "openFailureBehavior=fail-closed-user-visible", "content opener failure behavior"),
    (content_opener_text, "opener-route-policy-drift.json", "content opener route guard"),
    (content_opener_text, "opener-missing-evidence-link.json", "content opener evidence guard"),
    (content_opener_text, "opener-mutable-preview.json", "content opener mutability guard"),
    (content_opener_text, "opener-silent-failure.json", "content opener failure guard"),
    (formatting_review_text, "reviewMode=before-after-layout-diff", "formatting review mode"),
    (formatting_review_text, "runtimeFormattingImplementation=not-started", "formatting review runtime gate"),
    (formatting_review_text, "formatting-review-missing-envelope.json", "formatting review missing envelope guard"),
    (formatting_review_text, "formatting-review-no-diffreview.json", "formatting review DiffReview guard"),
    (formatting_review_text, "formatting-review-mutable-preview.json", "formatting review mutability guard"),
    (formatting_review_text, "formatting-review-runtime-started.json", "formatting review runtime guard"),
    (content_review_text, "reviewMode=evidence-linked-content-diff", "content review mode"),
    (content_review_text, "runtimeContentReviewImplementation=not-started", "content review runtime gate"),
    (content_review_text, "content-review-missing-envelope.json", "content review missing envelope guard"),
    (content_review_text, "content-review-no-evidence.json", "content review evidence guard"),
    (content_review_text, "content-review-mutable-suggestion.json", "content review mutability guard"),
    (content_review_text, "content-review-runtime-started.json", "content review runtime guard"),
    (artifact_navigator_text, "managedTypes=[document,selection,connector-result,knowledge-index-result,evidence-record,task-step]", "artifact navigator type roster"),
    (artifact_navigator_text, "runtimeArtifactNavigatorImplementation=not-started", "artifact navigator runtime gate"),
    (artifact_navigator_text, "artifact-navigator-missing-envelope.json", "artifact navigator missing envelope guard"),
    (artifact_navigator_text, "artifact-navigator-type-drift.json", "artifact navigator type guard"),
    (artifact_navigator_text, "artifact-navigator-mutable-details.json", "artifact navigator mutability guard"),
    (artifact_navigator_text, "artifact-navigator-runtime-started.json", "artifact navigator runtime guard"),
    (review_queue_text, "itemTypes=[content-review,formatting-review,task-step]", "review queue item roster"),
    (review_queue_text, "runtimeReviewQueueImplementation=not-started", "review queue runtime gate"),
    (review_queue_text, "review-queue-missing-envelope.json", "review queue missing envelope guard"),
    (review_queue_text, "review-queue-no-filter.json", "review queue filter guard"),
    (review_queue_text, "review-queue-bulk-auto-apply.json", "review queue bulk guard"),
    (review_queue_text, "review-queue-runtime-started.json", "review queue runtime guard"),
    (evidence_inspector_text, "sourceTypes=[evidence-record,connector-result,knowledge-index-result,task-step,review-item]", "evidence inspector source roster"),
    (evidence_inspector_text, "runtimeEvidenceInspectorImplementation=not-started", "evidence inspector runtime gate"),
    (evidence_inspector_text, "evidence-inspector-missing-envelope.json", "evidence inspector missing envelope guard"),
    (evidence_inspector_text, "evidence-inspector-source-drift.json", "evidence inspector source guard"),
    (evidence_inspector_text, "evidence-inspector-raw-payload.json", "evidence inspector raw payload guard"),
    (evidence_inspector_text, "evidence-inspector-runtime-started.json", "evidence inspector runtime guard"),
    (interaction_chrome_text, "panels=[chat,tasks,artifacts,reviews,evidence]", "interaction chrome panel roster"),
    (interaction_chrome_text, "runtimeInteractionChromeImplementation=not-started", "interaction chrome runtime gate"),
    (interaction_chrome_text, "interaction-chrome-missing-envelope.json", "interaction chrome missing envelope guard"),
    (interaction_chrome_text, "interaction-chrome-modal-only.json", "interaction chrome modal-only guard"),
    (interaction_chrome_text, "interaction-chrome-no-keyboard.json", "interaction chrome keyboard guard"),
    (interaction_chrome_text, "interaction-chrome-runtime-started.json", "interaction chrome runtime guard"),
    (preview_matrix_text, "contentTypes=[document,selection,connector-result,knowledge-index-result,evidence-record,task-step,review-item]", "preview matrix type roster"),
    (preview_matrix_text, "runtimePreviewMatrixImplementation=not-started", "preview matrix runtime gate"),
    (preview_matrix_text, "preview-matrix-missing-envelope.json", "preview matrix missing envelope guard"),
    (preview_matrix_text, "preview-matrix-type-drift.json", "preview matrix type guard"),
    (preview_matrix_text, "preview-matrix-raw-payload.json", "preview matrix raw payload guard"),
    (preview_matrix_text, "preview-matrix-runtime-started.json", "preview matrix runtime guard"),
    (action_bar_text, "commands=[open-preview,open-diff-review,approve-selected,reject-selected,copy-reference,export-evidence,filter,sort,retry,cancel]", "action bar command roster"),
    (action_bar_text, "runtimeActionBarImplementation=not-started", "action bar runtime gate"),
    (action_bar_text, "action-bar-missing-envelope.json", "action bar missing envelope guard"),
    (action_bar_text, "action-bar-command-drift.json", "action bar command guard"),
    (action_bar_text, "action-bar-hidden-mouse-only.json", "action bar accessibility guard"),
    (action_bar_text, "action-bar-runtime-started.json", "action bar runtime guard"),
    (filter_search_text, "surfaces=[tasks,artifacts,reviews,evidence,previews]", "filter/search surface roster"),
    (filter_search_text, "runtimeFilterSearchImplementation=not-started", "filter/search runtime gate"),
    (filter_search_text, "filter-search-missing-envelope.json", "filter/search missing envelope guard"),
    (filter_search_text, "filter-search-scope-drift.json", "filter/search scope guard"),
    (filter_search_text, "filter-search-raw-index.json", "filter/search raw index guard"),
    (filter_search_text, "filter-search-runtime-started.json", "filter/search runtime guard"),
    (context_handoff_text, "entrySurfaces=[filter-search-result,artifact-navigator-item,review-queue-item,evidence-inspector-link,preview-matrix-item,action-bar-command]", "context handoff entry surface roster"),
    (context_handoff_text, "runtimeContextHandoffImplementation=not-started", "context handoff runtime gate"),
    (context_handoff_text, "context-handoff-missing-envelope.json", "context handoff missing envelope guard"),
    (context_handoff_text, "context-handoff-target-drift.json", "context handoff target guard"),
    (context_handoff_text, "context-handoff-raw-payload.json", "context handoff raw payload guard"),
    (context_handoff_text, "context-handoff-runtime-started.json", "context handoff runtime guard"),
    (review_state_sync_text, "stateSources=[review-queue,diff-review,preview-matrix,evidence-inspector,task-progress,action-bar]", "review state sync source roster"),
    (review_state_sync_text, "runtimeReviewStateSyncImplementation=not-started", "review state sync runtime gate"),
    (review_state_sync_text, "review-state-sync-missing-envelope.json", "review state sync missing envelope guard"),
    (review_state_sync_text, "review-state-sync-target-drift.json", "review state sync target guard"),
    (review_state_sync_text, "review-state-sync-auto-apply.json", "review state sync auto-apply guard"),
    (review_state_sync_text, "review-state-sync-runtime-started.json", "review state sync runtime guard"),
    (activity_timeline_text, "events=[chat-requested,task-started,artifact-created,content-opened,review-opened,review-state-changed,evidence-linked,action-invoked,failure-reported]", "activity timeline event roster"),
    (activity_timeline_text, "runtimeActivityTimelineImplementation=not-started", "activity timeline runtime gate"),
    (activity_timeline_text, "activity-timeline-missing-envelope.json", "activity timeline missing envelope guard"),
    (activity_timeline_text, "activity-timeline-event-drift.json", "activity timeline event guard"),
    (activity_timeline_text, "activity-timeline-raw-payload.json", "activity timeline raw payload guard"),
    (activity_timeline_text, "activity-timeline-runtime-started.json", "activity timeline runtime guard"),
    (session_snapshot_text, "restores=[active-task-id,open-artifact-id,open-review-id,active-evidence-id,preview-mode,review-state,activity-cursor,failure-state]", "session snapshot restore roster"),
    (session_snapshot_text, "runtimeSessionSnapshotImplementation=not-started", "session snapshot runtime gate"),
    (session_snapshot_text, "session-snapshot-missing-envelope.json", "session snapshot missing envelope guard"),
    (session_snapshot_text, "session-snapshot-scope-drift.json", "session snapshot scope guard"),
    (session_snapshot_text, "session-snapshot-raw-payload.json", "session snapshot raw payload guard"),
    (session_snapshot_text, "session-snapshot-runtime-started.json", "session snapshot runtime guard"),
    (attention_routing_text, "triggers=[approval-required,review-ready,task-failed,evidence-missing,resume-available]", "attention routing trigger roster"),
    (attention_routing_text, "surfaces=[sidebar-badge,tab-badge,task-row-highlight,review-queue-badge,activity-timeline-event,resume-banner]", "attention routing surface roster"),
    (attention_routing_text, "routesTo=[task-progress,review-queue,diff-review,evidence-inspector,activity-timeline,session-snapshot]", "attention routing target roster"),
    (attention_routing_text, "runtimeAttentionRoutingImplementation=not-started", "attention routing runtime gate"),
    (attention_routing_text, "attention-routing-missing-envelope.json", "attention routing missing envelope guard"),
    (attention_routing_text, "attention-routing-surface-drift.json", "attention routing surface guard"),
    (attention_routing_text, "attention-routing-raw-payload.json", "attention routing raw payload guard"),
    (attention_routing_text, "attention-routing-runtime-started.json", "attention routing runtime guard"),
    (native_style_text, "layout=sidebar-workbench", "native style layout"),
    (native_style_text, "density=compact-utility", "native style density"),
    (native_style_text, "stableDimensions=[toolbar-buttons,tab-badges,task-rows,review-rows,evidence-rows,preview-tiles]", "native style stable dimension roster"),
    (native_style_text, "runtimeNativeStyleImplementation=not-started", "native style runtime gate"),
    (native_style_text, "native-style-missing-envelope.json", "native style missing envelope guard"),
    (native_style_text, "native-style-density-drift.json", "native style density guard"),
    (native_style_text, "native-style-card-layout.json", "native style card layout guard"),
    (native_style_text, "native-style-runtime-started.json", "native style runtime guard"),
    (content_registry_text, "types=[document,selection,connector-result,knowledge-index-result,evidence-record,task-step,review-item,formatting-preview,content-suggestion]", "content registry type roster"),
    (content_registry_text, "requiredFields=[object-id,type,source-surface,state,evidence-id,hash-reference,open-target,preview-mode]", "content registry required field roster"),
    (content_registry_text, "runtimeContentRegistryImplementation=not-started", "content registry runtime gate"),
    (content_registry_text, "content-registry-missing-envelope.json", "content registry missing envelope guard"),
    (content_registry_text, "content-registry-type-drift.json", "content registry type guard"),
    (content_registry_text, "content-registry-raw-payload.json", "content registry raw payload guard"),
    (content_registry_text, "content-registry-runtime-started.json", "content registry runtime guard"),
    (source_provenance_text, "sourceTypes=[document,selection,connector-result,knowledge-index-result,evidence-record,task-step,review-item,formatting-preview,content-suggestion]", "source provenance source type roster"),
    (source_provenance_text, "requiredFields=[source-id,source-type,citation-id,evidence-id,hash-reference,source-surface,open-target,span-reference,review-id]", "source provenance required field roster"),
    (source_provenance_text, "runtimeSourceProvenanceImplementation=not-started", "source provenance runtime gate"),
    (source_provenance_text, "source-provenance-missing-envelope.json", "source provenance missing envelope guard"),
    (source_provenance_text, "source-provenance-type-drift.json", "source provenance type guard"),
    (source_provenance_text, "source-provenance-raw-payload.json", "source provenance raw payload guard"),
    (source_provenance_text, "source-provenance-runtime-started.json", "source provenance runtime guard"),
    (clipboard_text, "materializesInputTypes=[plain-text-large,rich-text,html-fragment,table-range,image,local-file-reference]", "clipboard materialization input roster"),
    (clipboard_text, "storage=local-temp-content-object", "clipboard materialization storage"),
    (clipboard_text, "transcriptStoresReferenceOnly=true", "clipboard materialization transcript reference lock"),
    (clipboard_text, "runtimeClipboardMaterializationImplementation=not-started", "clipboard materialization runtime gate"),
    (clipboard_text, "clipboard-materialization-missing-envelope.json", "clipboard materialization missing envelope guard"),
    (clipboard_text, "clipboard-materialization-raw-transcript.json", "clipboard materialization raw transcript guard"),
    (clipboard_text, "clipboard-materialization-memory-only.json", "clipboard materialization memory-only guard"),
    (clipboard_text, "clipboard-materialization-runtime-started.json", "clipboard materialization runtime guard"),
    (w5_text, "tests/v3-in-app-chat-test.sh", "W5 self-test roster"),
    (w5_text, "docs/product/v3/w1-markdown-rendering-policy.md", "W5 Markdown policy roster"),
    (w5_text, "docs/product/v3/w1-context-autocomplete-policy.md", "W5 autocomplete policy roster"),
    (w5_text, "docs/product/v3/w1-chat-history-policy.md", "W5 history policy roster"),
    (w5_text, "docs/product/v3/w1-streaming-state-policy.md", "W5 streaming policy roster"),
    (w5_text, "docs/product/v3/w1-ai-workspace-ui-policy.md", "W5 AI workspace UI policy roster"),
    (w5_text, "docs/product/v3/w1-content-opener-policy.md", "W5 content opener policy roster"),
    (w5_text, "docs/product/v3/w1-formatting-review-policy.md", "W5 formatting review policy roster"),
    (w5_text, "docs/product/v3/w1-content-review-policy.md", "W5 content review policy roster"),
    (w5_text, "docs/product/v3/w1-artifact-navigator-policy.md", "W5 artifact navigator policy roster"),
    (w5_text, "docs/product/v3/w1-review-queue-policy.md", "W5 review queue policy roster"),
    (w5_text, "docs/product/v3/w1-evidence-inspector-policy.md", "W5 evidence inspector policy roster"),
    (w5_text, "docs/product/v3/w1-interaction-chrome-policy.md", "W5 interaction chrome policy roster"),
    (w5_text, "docs/product/v3/w1-content-preview-matrix-policy.md", "W5 content preview matrix policy roster"),
    (w5_text, "docs/product/v3/w1-workspace-action-bar-policy.md", "W5 workspace action bar policy roster"),
    (w5_text, "docs/product/v3/w1-workspace-filter-search-policy.md", "W5 workspace filter/search policy roster"),
    (w5_text, "docs/product/v3/w1-workspace-context-handoff-policy.md", "W5 workspace context handoff policy roster"),
    (w5_text, "docs/product/v3/w1-workspace-review-state-sync-policy.md", "W5 workspace review state sync policy roster"),
    (w5_text, "docs/product/v3/w1-workspace-activity-timeline-policy.md", "W5 workspace activity timeline policy roster"),
    (w5_text, "docs/product/v3/w1-workspace-session-snapshot-policy.md", "W5 workspace session snapshot policy roster"),
    (w5_text, "docs/product/v3/w1-workspace-attention-routing-policy.md", "W5 workspace attention routing policy roster"),
    (w5_text, "docs/product/v3/w1-workspace-native-style-policy.md", "W5 workspace native style policy roster"),
    (w5_text, "docs/product/v3/w1-workspace-content-registry-policy.md", "W5 workspace content registry policy roster"),
    (w5_text, "docs/product/v3/w1-workspace-source-provenance-policy.md", "W5 workspace source provenance policy roster"),
    (w5_text, "docs/product/v3/w1-chat-clipboard-materialization-policy.md", "W5 chat clipboard materialization policy roster"),
    (w5_text, "docs/qa/fixtures/v3/in-app-chat/", "W5 fixture roster"),
    (master_text, "in-app-chat fixture self-test", "master status"),
    (master_text, "AI workspace UI", "master AI workspace UI status"),
    (master_text, "tests/v3-in-app-chat-test.sh", "master self-test roster"),
    (sweep_text, "W1 in-app-chat self-test", "sweep banner/comment"),
    (sweep_text, "tests/v3-in-app-chat-test.sh", "sweep runner"),
    (workflow_text, "docs/qa/fixtures/v3/**", "workflow fixture path"),
    (workflow_text, "tests/v3-*.sh", "workflow test path"),
]
for text, needle, label in required_refs:
    if needle not in text:
        die(f"missing {label} reference: {needle}")
pass_count += 1

if pass_count != 28:
    die(f"expected 28 checks, got {pass_count}")

print("Status: passed")
print("Harness: W1 in-app-chat fixture self-test")
print("Valid fixtures: 5")
print("Invalid fixtures: 104")
print("Contract: explicit context syntax, context autocomplete, Markdown subset rendering, per-doc local history, streaming UI states, AI workspace review/progress/opening UI, content opener route policy, formatting review policy, content review policy, artifact navigator policy, review queue policy, evidence inspector policy, interaction chrome policy, content preview matrix policy, workspace action bar policy, workspace filter/search policy, workspace context handoff policy, workspace review state sync policy, workspace activity timeline policy, workspace session snapshot policy, workspace attention routing policy, workspace native style policy, workspace content registry policy, workspace source provenance policy, chat clipboard materialization policy, CommandPalette fallback, V2 Provider/ApplyPlan/evidence reuse, no new schema")
print("Runtime implementation: deferred until W1 gate")
print(f"Checks: {pass_count}")
PY
