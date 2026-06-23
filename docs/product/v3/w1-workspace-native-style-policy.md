# V3 W1 Workspace Native Style Policy

Status: contract active (2026-06-11, L241)
Scope: W1 AI workspace native workbench style, density, stable dimensions, and keyboard-friendly interaction; design/fixture contract only.
Runtime implementation: not-started

This policy refines the L225 AI workspace UI, L232 interaction chrome, L234 action bar, L235 filter/search, L236 context handoff, L237 review state sync, L238 activity timeline, L239 session snapshot, and L240 attention routing policies. The AI surface must feel like a compact native office workbench, not a modal chat room, landing page, card feed, or marketing-style assistant shell.

The goal is not visual decoration. It locks the interaction shape needed for AI-assisted content review, formatting review, artifact opening, evidence inspection, and task management: scannable rows, predictable tabs, stable badges, keyboard routes, visible focus return, and no text overlap.

## Locked Contract

All valid W1 in-app-chat fixtures must declare workspaceUi.nativeStyle with:

layout=sidebar-workbench
density=compact-utility
surfaces=[composer,panel-tabs,task-rail,artifact-rail,review-queue,evidence-inspector,preview-matrix,action-bar]
navigation=segmented-tabs
usesNativeControls=true
stableDimensions=[toolbar-buttons,tab-badges,task-rows,review-rows,evidence-rows,preview-tiles]
textOverflowPolicy=wrap-or-ellipsize-no-overlap
cardPileLayout=false
modalOnly=false
marketingHero=false
keyboardAccessible=true
focusReturn=true
metadataOnly=true
rawContentInFixture=false
previewContentInFixture=false
transcriptContentInFixture=false
mainDocumentMutationAllowed=false
autoApplyAllowed=false
failureBehavior=fail-closed-user-visible
runtimeNativeStyleImplementation=not-started

The native style envelope records only UI policy metadata. It cannot store rendered UI screenshots, raw prompt text, raw document content, connector payloads, preview text, transcript content, review suggestions, or DiffReview payload content. Stable dimensions are a contract for later runtime design: toolbar buttons, tab badges, task rows, review rows, evidence rows, and preview tiles must not resize or shift when labels, badges, hover states, streaming states, or status text change.

## Invalid Guards

The W1 self-test must reject these drift classes:

native-style-missing-envelope.json: omits workspaceUi.nativeStyle while claiming the AI workspace can manage review, formatting, opening, evidence, and task surfaces.
native-style-density-drift.json: changes compact-utility density to a spacious/card/feed model, drops required surfaces, changes segmented navigation, weakens stable dimensions, or allows text overlap.
native-style-card-layout.json: changes the sidebar workbench into a card pile, modal-only assistant, or marketing hero layout; also rejects missing keyboard accessibility or focus return.
native-style-runtime-started.json: claims native style runtime is already started, stores raw/preview/transcript content, allows auto-apply or main-document mutation, or changes failure behavior away from fail-closed-user-visible.
interaction-chrome-modal-only.json: keeps rejecting modal-only workspace chrome.
action-bar-hidden-mouse-only.json: keeps rejecting hidden or mouse-only controls.
preview-matrix-type-drift.json: keeps rejecting preview surface drift that would make stable workbench rows meaningless.

## Non-Goals

No native style runtime, sidebar renderer, layout engine, theme integration, or UI implementation is started by this policy.
No W1 sidebar runtime, workspace UI runtime opener, content opener runtime, formatting review runtime, content review runtime, artifact navigator runtime, review queue runtime, evidence inspector runtime, interaction chrome runtime, preview matrix runtime, action bar runtime, filter/search runtime, context handoff runtime, review state sync runtime, activity timeline runtime, session snapshot runtime, attention routing runtime, W2 connector runtime, W3 retrieval runtime, W4 audit runtime, W6 task execution, or W7 companion runtime is authorized.
No new W1 schema is introduced.
No fixture may store raw document, prompt, connector, retrieval, evidence, task-step, review, formatting preview, suggestion, rendered UI, timeline, session, attention, transcript, or DiffReview payload content.
No native style policy may mutate the main document, auto-open content, auto-apply changes, hide actions behind mouse-only affordances, or replace the workbench with a card pile, modal-only chat, or marketing hero.

## Verification

tests/v3-in-app-chat-test.sh validates this policy, the 5 valid / 92 invalid fixture roster, and the native style envelope. It must report Checks: 25.
