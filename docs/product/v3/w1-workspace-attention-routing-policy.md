# V3 W1 Workspace Attention Routing Policy

Status: contract active (2026-06-11, L240)
Scope: W1 AI workspace visible attention routing for approval, review readiness, failures, missing evidence, and resumable sessions; design/fixture contract only.
Runtime implementation: not-started

This policy refines the L225 AI workspace UI, L234 action bar, L238 activity timeline, and L239 session snapshot policies. AI work must not hide important state in chat text. When work needs approval, a review is ready, a task fails, evidence is missing, or a resumable session exists, the workbench must expose a visible, keyboard-accessible route back to the right task, review, evidence, timeline, or resume summary.

## Locked Contract

All valid W1 in-app-chat fixtures must declare workspaceUi.attentionRouting with:

visible=true
scope=[current-workspace,current-document]
triggers=[approval-required,review-ready,task-failed,evidence-missing,resume-available]
surfaces=[sidebar-badge,tab-badge,task-row-highlight,review-queue-badge,activity-timeline-event,resume-banner]
routesTo=[task-progress,review-queue,diff-review,evidence-inspector,activity-timeline,session-snapshot]
requiresOpenTarget=true
requiresVisibleReason=true
requiresVisibleTimestamp=true
requiresKeyboardAccess=true
usesNativeControls=true
usesActionBar=true
usesActivityTimeline=true
usesSessionSnapshot=true
usesEvidenceInspector=true
usesDiffReview=true
metadataOnly=true
hashOnlyReferences=true
redactsRawPayload=true
rawContentInFixture=false
previewContentInFixture=false
transcriptContentInFixture=false
systemNotificationRuntime=not-started
cloudPush=false
autoOpenAllowed=false
autoApplyAllowed=false
mainDocumentMutationAllowed=false
failureBehavior=fail-closed-user-visible
runtimeAttentionRoutingImplementation=not-started

The route is an in-workbench attention contract, not a system notification implementation. It records only ids, state labels, timestamps, visible reasons, evidence ids, and hash references. It cannot store prompt text, raw document content, preview payloads, connector payloads, review suggestions, transcript content, or DiffReview payload content. It also cannot auto-open a target or apply a change; the user must intentionally open the surfaced target.

## Invalid Guards

The W1 self-test must reject these drift classes:

attention-routing-missing-envelope.json: omits the attention routing envelope while claiming workspace attention support.
attention-routing-surface-drift.json: changes trigger/surface/target rosters, drops open target, hides visible reason or timestamp, removes keyboard access, or routes back to chat-only instead of the owning task/review/evidence/timeline/session surface.
attention-routing-raw-payload.json: stores raw document, preview, transcript, prompt, connector, retrieval, evidence, review, or attention payload content instead of metadata-only hash references, or enables cloud push.
attention-routing-runtime-started.json: claims attention routing or system notification runtime is already started, auto-opens content, allows auto-apply or main-document mutation, or fails silently.
action-bar-hidden-mouse-only.json: keeps rejecting hidden or mouse-only workbench actions.
activity-timeline-runtime-started.json: keeps rejecting premature timeline runtime claims.
session-snapshot-runtime-started.json: keeps rejecting premature resume runtime claims.

## Non-Goals

No attention routing runtime or system notification runtime is started by this policy.
No W1 sidebar runtime, workspace UI runtime opener, content opener runtime, formatting review runtime, content review runtime, artifact navigator runtime, review queue runtime, evidence inspector runtime, interaction chrome runtime, preview matrix runtime, action bar runtime, filter/search runtime, context handoff runtime, review state sync runtime, activity timeline runtime, session snapshot runtime, W2 connector runtime, W3 retrieval runtime, W4 audit runtime, W6 task execution, or W7 companion runtime is authorized.
No cloud push, public egress, or external notification service is introduced.
No new W1 schema is introduced.
No fixture may store raw document, prompt, connector, retrieval, evidence, task-step, review, formatting preview, suggestion, rendered UI, timeline, session, attention, transcript, or DiffReview payload content.
No attention route may mutate the main document, auto-open content, or apply changes before explicit human approval.
No hidden, chat-only, mouse-only, raw-content, cloud-pushed, auto-open, auto-apply, or silent failure path is valid.

## Verification

tests/v3-in-app-chat-test.sh validates this policy, the 5 valid / 88 invalid fixture roster, and the attention routing envelope. It must report Checks: 24.
