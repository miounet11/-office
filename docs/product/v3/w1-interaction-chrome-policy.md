# V3 W1 Interaction Chrome Policy

Status: contract active (2026-06-11, L232)
Scope: W1 AI workspace interaction chrome and navigation; design/fixture contract only.
Runtime implementation: not-started

This policy refines the L225-L231 Codex-style AI workspace contracts. W1 must not degrade into a modal chat box or a long transcript with hidden work products. The AI workspace needs a compact native workbench shell that keeps chat, task progress, artifacts, review items, and evidence inspection visible and reachable from one sidebar interaction model.

## Locked Contract

All valid W1 in-app-chat fixtures must declare workspaceUi.interactionChrome with:

layout=sidebar-workbench
navigation=segmented-tabs
panels=[chat,tasks,artifacts,reviews,evidence]
defaultPanel=chat
persistentComposer=true
taskRailVisible=true
artifactRailVisible=true
reviewRailVisible=true
evidenceRailVisible=true
keyboardNavigation.tabOrder=[composer,panel-tabs,active-panel,review-actions]
keyboardNavigation.escapeReturnsFocus=true
keyboardNavigation.focusTrap=false
density=compact-utility
usesNativeControls=true
modalChatOnly=false
rawContentInFixture=false
failureBehavior=fail-closed-user-visible
runtimeInteractionChromeImplementation=not-started

The chrome intentionally names the stable workbench surfaces instead of storing UI text, rendered snapshots, document bodies, prompt bodies, review bodies, or evidence payloads. It keeps the composer persistent while users inspect task progress, artifacts, reviews, and evidence. It also keeps keyboard traversal explicit so the future native UI cannot trap focus in a chat input or hide review actions behind mouse-only interactions.

## Invalid Guards

The W1 self-test must reject these drift classes:

interaction-chrome-missing-envelope.json: omits the interaction chrome while claiming a Codex-style AI workspace.
interaction-chrome-modal-only.json: collapses the workspace to a modal chat-only surface and hides task/artifact/review/evidence rails.
interaction-chrome-no-keyboard.json: removes required keyboard traversal, traps focus, or makes Escape fail to return focus.
interaction-chrome-runtime-started.json: claims interaction chrome runtime is already started, uses non-native controls, stores raw content in fixtures, or fails silently.
workspace-modal-chat-only.json: keeps rejecting the older broad modal-only workspace drift.

## Non-Goals

No interaction chrome runtime is started by this policy.
No new W1 schema is introduced.
No fixture may store raw document, prompt, connector, retrieval, evidence, task-step, review, formatting preview, suggestion, rendered UI, or DiffReview payload content.
No in-app WebView, standalone chat app, or modal-only chat surface is authorized.
No W1 sidebar runtime, content opener runtime, formatting runtime, content review runtime, artifact navigator runtime, review queue runtime, evidence inspector runtime, W2 connector runtime, W3 retrieval runtime, W4 audit runtime, W6 task execution, or W7 companion runtime is authorized.

## Verification

tests/v3-in-app-chat-test.sh validates this policy, the 5 valid / 56 invalid fixture roster, and the interaction chrome envelope. It must report Checks: 16.
