# V3 W1 Workspace Action Bar Policy

Status: contract active (2026-06-11, L234)
Scope: W1 AI workspace command/action surface; design/fixture contract only.
Runtime implementation: not-started

This policy refines the L232 interaction chrome and L233 content preview matrix policies. W1 must expose the common actions users need while reviewing AI work, opening content, checking evidence, and managing task progress. Those actions must be visible and keyboard reachable inside the native sidebar workbench instead of living as hidden transcript affordances, mouse-only controls, or implicit auto-apply behavior.

## Locked Contract

All valid W1 in-app-chat fixtures must declare workspaceUi.actionBar with:

visible=true
placement=sidebar-workbench-header
commands=[open-preview,open-diff-review,approve-selected,reject-selected,copy-reference,export-evidence,filter,sort,retry,cancel]
commandTargets=[task-step,review-item,artifact,evidence-record,preview]
keyboardAccessible=true
usesNativeControls=true
requiresVisibleState=true
requiresEvidenceLink=true
usesContentOpeners=true
usesDiffReview=true
bulkApplyRequiresExplicitHumanApproval=true
autoApplyAllowed=false
hiddenActionsAllowed=false
mouseOnlyActionsAllowed=false
rawContentInFixture=false
mainDocumentMutationAllowed=false
failureBehavior=fail-closed-user-visible
runtimeActionBarImplementation=not-started

The action bar intentionally names stable command semantics and targets, not button labels, rendered UI snapshots, prompt text, document content, connector payloads, retrieval snippets, evidence bodies, task payloads, review bodies, formatting previews, generated suggestions, or DiffReview bodies. Commands that inspect or open content must route through contentOpeners or DiffReview. Commands that approve or reject work must stay evidence-linked and human-mediated. Retry and cancel are task controls only; they must not mutate the main document.

## Invalid Guards

The W1 self-test must reject these drift classes:

action-bar-missing-envelope.json: omits the action bar while claiming a Codex-style workbench command surface.
action-bar-command-drift.json: drops required commands or adds auto-apply style commands outside the locked roster.
action-bar-hidden-mouse-only.json: hides command state, removes keyboard access, or makes actions mouse-only.
action-bar-runtime-started.json: claims action bar runtime is already started, allows auto-apply, bypasses explicit human approval, mutates the main document, or fails silently.
review-queue-bulk-auto-apply.json: keeps rejecting bulk review commands that bypass explicit human approval.
preview-matrix-runtime-started.json: keeps rejecting opener bypass and premature preview runtime claims.

## Non-Goals

No action bar runtime is started by this policy.
No command palette runtime, W1 sidebar runtime, content opener runtime, formatting runtime, content review runtime, artifact navigator runtime, review queue runtime, evidence inspector runtime, interaction chrome runtime, preview matrix runtime, W2 connector runtime, W3 retrieval runtime, W4 audit runtime, W6 task execution, or W7 companion runtime is authorized.
No new W1 schema is introduced.
No fixture may store raw document, prompt, connector, retrieval, evidence, task-step, review, formatting preview, suggestion, rendered UI, or DiffReview payload content.
No action may mutate the main document before explicit human approval.
No hidden, mouse-only, or silent action path is valid.

## Verification

tests/v3-in-app-chat-test.sh validates this policy, the 5 valid / 64 invalid fixture roster, and the action bar envelope. It must report Checks: 18.
