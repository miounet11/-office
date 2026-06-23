# V3 W1 Content Preview Matrix Policy

Status: contract active (2026-06-11, L233)
Scope: W1 AI workspace content preview/open matrix; design/fixture contract only.
Runtime implementation: not-started

This policy refines the L226 content opener route policy, L229 artifact navigator policy, L231 evidence inspector policy, and L232 interaction chrome policy. W1 must support more than file editing and chat: documents, selections, connector results, Knowledge Index results, evidence records, task steps, and review items need predictable preview behavior when users inspect what AI touched, cited, or proposed.

## Locked Contract

All valid W1 in-app-chat fixtures must declare workspaceUi.previewMatrix with:

visible=true
contentTypes=[document,selection,connector-result,knowledge-index-result,evidence-record,task-step,review-item]
previewTargets.document=main-document-window
previewTargets.selection=sidebar-preview
previewTargets.connector-result=sidebar-preview
previewTargets.knowledge-index-result=sidebar-preview
previewTargets.evidence-record=sidebar-preview
previewTargets.task-step=diff-review
previewTargets.review-item=diff-review
previewModes=[metadata-summary,read-only-preview,diff-preview,evidence-summary]
showsEvidenceBadge=true
showsSourceMetadata=true
openUsesContentOpeners=true
readOnlyPreview=true
redactsRawPayload=true
hashOnlyReferences=true
rawContentInFixture=false
previewContentInFixture=false
mainDocumentMutationAllowed=false
failureBehavior=fail-closed-user-visible
runtimePreviewMatrixImplementation=not-started

The preview matrix intentionally separates preview semantics from runtime opener implementation. It may name content types, preview targets, modes, source metadata, and badges, but it cannot store raw document text, connector payloads, retrieval snippets, evidence bodies, task payloads, review bodies, formatting previews, generated suggestions, rendered UI payloads, or DiffReview bodies in fixtures. Review items route to DiffReview as a preview target while runtime open behavior remains gated.

## Invalid Guards

The W1 self-test must reject these drift classes:

preview-matrix-missing-envelope.json: omits the preview matrix while claiming multi-content AI workspace opening.
preview-matrix-type-drift.json: drops connector, Knowledge Index, task-step, review-item, or evidence preview coverage.
preview-matrix-raw-payload.json: stores raw or preview payload content, disables redaction, or uses non-hash references.
preview-matrix-runtime-started.json: claims preview runtime is already started, bypasses contentOpeners, mutates the main document, or fails silently.
opener-mutable-preview.json: keeps rejecting broader read-only preview drift.
interaction-chrome-modal-only.json: keeps rejecting surfaces that hide previewable content behind modal chat.

## Non-Goals

No content preview runtime is started by this policy.
No W1 content opener route expansion is implemented by this policy.
No new W1 schema is introduced.
No raw document, prompt, connector, retrieval, evidence, task-step, review, formatting preview, suggestion, rendered UI, or DiffReview payload content is stored in fixtures.
No preview may mutate the main document before explicit human approval.
No W1 sidebar runtime, content opener runtime, formatting runtime, content review runtime, artifact navigator runtime, review queue runtime, evidence inspector runtime, interaction chrome runtime, W2 connector runtime, W3 retrieval runtime, W4 audit runtime, W6 task execution, or W7 companion runtime is authorized.

## Verification

tests/v3-in-app-chat-test.sh validates this policy, the 5 valid / 60 invalid fixture roster, and the preview matrix envelope. It must report Checks: 17.
