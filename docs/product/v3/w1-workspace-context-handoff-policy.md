# V3 W1 Workspace Context Handoff Policy

Status: contract active (2026-06-11, L236)
Scope: W1 AI workspace context handoff between search, opening, preview, evidence, and review surfaces; design/fixture contract only.
Runtime implementation: not-started

This policy refines the L229 artifact navigator, L230 review queue, L231 evidence inspector, L233 content preview matrix, L234 workspace action bar, and L235 workspace filter/search policies. W1 is not only a chat box or file editor: when a user opens an artifact, preview, evidence record, review item, or filtered result, the workspace must carry the relevant task, evidence, preview, and review state forward visibly instead of dropping context or mutating the document.

## Locked Contract

All valid W1 in-app-chat fixtures must declare workspaceUi.contextHandoff with:

visible=true
entrySurfaces=[filter-search-result,artifact-navigator-item,review-queue-item,evidence-inspector-link,preview-matrix-item,action-bar-command]
handoffTargets=[preview,diff-review,evidence-inspector,review-queue,task-progress,composer]
preserves=[active-task-id,source-surface,evidence-id,hash-reference,preview-mode,review-state]
requiresVisibleBreadcrumb=true
requiresBackNavigation=true
requiresFocusReturn=true
requiresEvidenceLink=true
usesContentOpeners=true
usesDiffReview=true
metadataOnly=true
hashOnlyReferences=true
redactsRawPayload=true
rawContentInFixture=false
previewContentInFixture=false
mainDocumentMutationAllowed=false
autoApplyAllowed=false
failureBehavior=fail-closed-user-visible
runtimeContextHandoffImplementation=not-started

The handoff surface intentionally stores only metadata, ids, evidence ids, hash references, preview modes, and review states. It must preserve enough visible state for users to move from search results or content openers into preview, evidence inspection, review queues, DiffReview, task progress, and the composer without losing the reason the content is open. It must never store raw document text, connector payloads, retrieval snippets, prompt bodies, evidence bodies, preview bodies, review bodies, suggestions, or DiffReview payloads in fixtures.

## Invalid Guards

The W1 self-test must reject these drift classes:

context-handoff-missing-envelope.json: omits the context handoff envelope while claiming cross-surface AI workspace navigation.
context-handoff-target-drift.json: drops required entry surfaces, handoff targets, preserved metadata, breadcrumb, back navigation, focus return, content opener reuse, DiffReview reuse, or evidence links.
context-handoff-raw-payload.json: stores raw or preview payload content, disables metadata-only/hash-only/redaction requirements, or carries raw handoff payloads.
context-handoff-runtime-started.json: claims context handoff runtime is already started, enables auto-apply, mutates the main document, or fails silently.
filter-search-runtime-started.json: keeps rejecting filter/search open paths that bypass contentOpeners or evidence links.
preview-matrix-runtime-started.json: keeps rejecting preview open paths that bypass the read-only preview matrix.

## Non-Goals

No context handoff runtime is started by this policy.
No W1 sidebar runtime, content opener runtime, preview matrix runtime, action bar runtime, filter/search runtime, evidence inspector runtime, review queue runtime, artifact navigator runtime, formatting review runtime, content review runtime, W2 connector runtime, W3 retrieval runtime, W4 audit runtime, W6 task execution, or W7 companion runtime is authorized.
No new W1 schema is introduced.
No fixture may store raw document, prompt, connector, retrieval, evidence, task-step, review, formatting preview, suggestion, rendered UI, handoff payload, or DiffReview payload content.
No handoff may mutate the main document or apply changes before explicit human approval.
No hidden, context-dropping, or silent failure path is valid.

## Verification

tests/v3-in-app-chat-test.sh validates this policy, the 5 valid / 72 invalid fixture roster, and the context handoff envelope. It must report Checks: 20.
