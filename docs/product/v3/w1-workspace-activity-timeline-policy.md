# V3 W1 Workspace Activity Timeline Policy

Status: contract active (2026-06-11, L238)
Scope: W1 AI workspace visible activity timeline across chat, tasks, artifacts, reviews, evidence, previews, and action bar; design/fixture contract only.
Runtime implementation: not-started

This policy refines the L225 AI workspace UI, L229 artifact navigator, L230 review queue, L231 evidence inspector, L233 preview matrix, L234 action bar, L236 context handoff, and L237 review state sync policies. AI-assisted work cannot live only as chat prose. The workspace must expose a compact chronological activity trail for the work users need to audit: requests, tasks, created artifacts, opened content, review openings, review-state changes, evidence links, invoked actions, and visible failures.

## Locked Contract

All valid W1 in-app-chat fixtures must declare workspaceUi.activityTimeline with:

visible=true
events=[chat-requested,task-started,artifact-created,content-opened,review-opened,review-state-changed,evidence-linked,action-invoked,failure-reported]
surfaces=[chat,tasks,artifacts,reviews,evidence,previews,action-bar]
links=[task-id,artifact-id,review-id,evidence-id,hash-reference]
order=chronological
appendOnly=true
requiresEvidenceLink=true
requiresVisibleTimestamp=true
requiresVisibleActor=true
requiresOpenTarget=true
usesContentOpeners=true
usesDiffReview=true
usesEvidenceInspector=true
metadataOnly=true
hashOnlyReferences=true
redactsRawPayload=true
rawContentInFixture=false
previewContentInFixture=false
transcriptContentInFixture=false
mainDocumentMutationAllowed=false
autoApplyAllowed=false
failureBehavior=fail-closed-user-visible
runtimeActivityTimelineImplementation=not-started

The timeline intentionally stores only ids, timestamps, actor labels, event names, target names, evidence ids, and hash references. It must let users reopen the relevant content through existing openers, DiffReview, or the evidence inspector without embedding raw document, prompt, connector, retrieval, preview, transcript, or review payload content in the fixture.

## Invalid Guards

The W1 self-test must reject these drift classes:

activity-timeline-missing-envelope.json: omits the activity timeline envelope while claiming visible workspace history.
activity-timeline-event-drift.json: drops a required event, surface, link, visible timestamp, visible actor, open target, content opener reuse, DiffReview reuse, or evidence inspector reuse.
activity-timeline-raw-payload.json: stores raw document, preview, transcript, prompt, connector, retrieval, evidence, review, or activity payload content instead of metadata-only hash references.
activity-timeline-runtime-started.json: claims activity timeline runtime is already started, disables append-only behavior, allows auto-apply or main-document mutation, or fails silently.
context-handoff-raw-payload.json: keeps rejecting raw cross-surface handoff payloads.
review-state-sync-runtime-started.json: keeps rejecting premature review-state runtime claims.

## Non-Goals

No activity timeline runtime is started by this policy.
No W1 sidebar runtime, activity timeline runtime, review-state sync runtime, context handoff runtime, filter/search runtime, action bar runtime, preview matrix runtime, evidence inspector runtime, review queue runtime, artifact navigator runtime, content review runtime, formatting review runtime, content opener runtime, W2 connector runtime, W3 retrieval runtime, W4 audit runtime, W6 task execution, or W7 companion runtime is authorized.
No new W1 schema is introduced.
No fixture may store raw document, prompt, connector, retrieval, evidence, task-step, review, formatting preview, suggestion, rendered UI, timeline, transcript, or DiffReview payload content.
No timeline path may mutate the main document or apply changes before explicit human approval.
No hidden, mutable, non-chronological, non-append-only, or silent activity failure path is valid.

## Verification

tests/v3-in-app-chat-test.sh validates this policy, the 5 valid / 80 invalid fixture roster, and the activity timeline envelope. It must report Checks: 22.
