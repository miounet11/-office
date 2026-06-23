# V3 W1 AI Workspace UI Policy

Status: **contract active** (2026-06-11, L225)
Scope: W1 in-app chat interaction surface; design/fixture contract only.
Runtime implementation: **not-started**

This policy locks the Codex-like AI workspace direction for W1 before any
sidebar runtime implementation starts. W1 must not be only a text chat or a
file-editing prompt box. The first AI surface is an `ai-workspace-sidebar`
inside the existing `sfx2-sidebar` container, combining conversation,
task progress, review, preview, and openable evidence/context surfaces.

## Locked Contract

All valid W1 in-app-chat fixtures must declare:

- `workspaceUi.shell=ai-workspace-sidebar`
- `workspaceUi.container=sfx2-sidebar`
- `workspaceUi.interactionModel=conversation-plus-progress`
- `workspaceUi.conversationPanelVisible=true`
- `workspaceUi.taskProgress.visible=true`
- `workspaceUi.taskProgress.states=[pending,running,awaiting-review,applied,failed,cancelled]`
- `workspaceUi.taskProgress.stepListVisible=true`
- `workspaceUi.taskProgress.evidenceLinksVisible=true`
- `workspaceUi.reviewSurface.visible=true`
- `workspaceUi.reviewSurface.supportsContentReview=true`
- `workspaceUi.reviewSurface.supportsFormattingReview=true`
- `workspaceUi.reviewSurface.usesDiffReview=true`
- `workspaceUi.reviewSurface.requiresEvidenceLink=true`
- `workspaceUi.layoutPreview.visible=true`
- `workspaceUi.layoutPreview.mode=before-after-preview`
- `workspaceUi.layoutPreview.surfaces=[writer,calc,impress]`
- `workspaceUi.layoutPreview.mainDocumentUnchangedUntilApproval=true`
- `workspaceUi.contentOpeners.supportedTypes=[document,selection,connector-result,knowledge-index-result,evidence-record,task-step]`
- `workspaceUi.contentOpeners.opensIn=[main-document-window,sidebar-preview,diff-review]`
- `workspaceUi.contentOpeners.rawContentInFixture=false`
- `workspaceUi.contentOpeners.runtimeOpenImplementation=not-started`
- `workspaceUi.stylePolicy.denseUtilityUi=true`
- `workspaceUi.stylePolicy.usesNativeControls=true`
- `workspaceUi.stylePolicy.modalChatOnly=false`

The content type roster is intentionally broader than file editing: document, selection, connector-result, knowledge-index-result, evidence-record, task-step. This lets W1 become the shared AI workspace shell for content review,
formatting review, layout preview, evidence inspection, and later W6 task
execution without starting those runtimes in this contract batch.

## Invalid Guards

The W1 self-test must reject these drift classes:

- `workspace-modal-chat-only.json`: collapses the AI workspace into modal chat.
- `workspace-missing-task-progress.json`: hides task state, step list, or evidence links.
- `workspace-review-without-evidence.json`: removes content review, DiffReview reuse, or evidence linkage.
- `workspace-formatting-no-preview.json`: bypasses before/after layout preview or mutates the main document before approval.
- `workspace-openers-runtime-started.json`: narrows openable content types, stores raw content in fixtures, or claims content opener runtime is started.

## Non-Goals

- No product UI runtime is started by this policy.
- No new W1 schema is introduced.
- No WebView, floating modal-only chat, or standalone AI app surface is authorized.
- No raw document, connector, evidence, or task-step content is stored in fixtures.
- No content opener runtime, W6 agent runtime, W3 retrieval runtime, or W7 companion runtime is authorized.

## Verification

`tests/v3-in-app-chat-test.sh` validates this policy, the 5 valid / 28 invalid
fixture roster, and the `workspaceUi` envelope semantics. It must report
`Checks: 9`.
