# V3 W1 Workspace Session Snapshot Policy

Status: contract active (2026-06-11, L239)
Scope: W1 AI workspace visible session snapshot and explicit resume summary across current workspace/current document; design/fixture contract only.
Runtime implementation: not-started

This policy refines the L203 per-document local history, L225 AI workspace UI, L236 context handoff, L237 review state sync, and L238 activity timeline policies. When a user returns to a document or workspace, the AI workspace must show what can be resumed: the active task, open artifact, open review, active evidence, preview mode, review state, activity cursor, and failure state. Resuming must be explicit, visible, metadata-only, and document-bound.

## Locked Contract

All valid W1 in-app-chat fixtures must declare workspaceUi.sessionSnapshot with:

visible=true
scope=[current-workspace,current-document]
restores=[active-task-id,open-artifact-id,open-review-id,active-evidence-id,preview-mode,review-state,activity-cursor,failure-state]
surfaces=[chat,tasks,artifacts,reviews,evidence,previews,activity-timeline]
resumeSummaryVisible=true
requiresExplicitResume=true
requiresVisibleTimestamp=true
requiresVisibleDocumentBinding=true
usesContentOpeners=true
usesDiffReview=true
usesEvidenceInspector=true
usesActivityTimeline=true
metadataOnly=true
hashOnlyReferences=true
redactsRawPayload=true
rawContentInFixture=false
previewContentInFixture=false
transcriptContentInFixture=false
crossDocumentRestore=false
cloudSync=false
mainDocumentMutationAllowed=false
autoApplyAllowed=false
failureBehavior=fail-closed-user-visible
runtimeSessionSnapshotImplementation=not-started

The snapshot intentionally stores only ids, timestamps, state names, preview modes, failure states, evidence ids, and hash references. It cannot restore raw chat transcripts, raw document content, preview payloads, connector payloads, retrieval snippets, review suggestions, or DiffReview payload content. It also cannot resume or apply work without a visible user action.

## Invalid Guards

The W1 self-test must reject these drift classes:

session-snapshot-missing-envelope.json: omits the session snapshot envelope while claiming resume support.
session-snapshot-scope-drift.json: changes current-workspace/current-document scope, drops a restore key or surface, hides resume summary, skips explicit resume, hides timestamp/document binding, or bypasses contentOpeners/DiffReview/evidence inspector/activity timeline.
session-snapshot-raw-payload.json: stores raw document, preview, transcript, prompt, connector, retrieval, evidence, review, or session payload content instead of metadata-only hash references.
session-snapshot-runtime-started.json: claims session snapshot runtime is already started, enables cloud sync or cross-document restore, allows auto-apply or main-document mutation, or fails silently.
global-history-leakage.json: keeps rejecting cross-document chat history leakage.
activity-timeline-raw-payload.json: keeps rejecting raw timeline payloads.

## Non-Goals

No session snapshot runtime is started by this policy.
No W1 sidebar runtime, session snapshot runtime, activity timeline runtime, review-state sync runtime, context handoff runtime, filter/search runtime, action bar runtime, preview matrix runtime, evidence inspector runtime, review queue runtime, artifact navigator runtime, content review runtime, formatting review runtime, content opener runtime, W2 connector runtime, W3 retrieval runtime, W4 audit runtime, W6 task execution, or W7 companion runtime is authorized.
No new W1 schema is introduced.
No fixture may store raw document, prompt, connector, retrieval, evidence, task-step, review, formatting preview, suggestion, rendered UI, timeline, session, transcript, or DiffReview payload content.
No snapshot path may mutate the main document or apply changes before explicit human approval.
No hidden, automatic, cross-document, cloud-synced, raw-content, or silent resume failure path is valid.

## Verification

tests/v3-in-app-chat-test.sh validates this policy, the 5 valid / 84 invalid fixture roster, and the session snapshot envelope. It must report Checks: 23.
