# V3 W1 Workspace Review State Sync Policy

Status: contract active (2026-06-11, L237)
Scope: W1 AI workspace review-state synchronization across queue, preview, evidence, task progress, action bar, and DiffReview surfaces; design/fixture contract only.
Runtime implementation: not-started

This policy refines the L230 review queue, L231 evidence inspector, L233 content preview matrix, L234 workspace action bar, and L236 context handoff policies. When users review AI changes, the same item state must be visible everywhere it appears. Approving, rejecting, opening, failing, or applying a review item cannot silently desynchronize the queue, preview, evidence, task progress, action bar, or DiffReview.

## Locked Contract

All valid W1 in-app-chat fixtures must declare workspaceUi.reviewStateSync with:

visible=true
stateSources=[review-queue,diff-review,preview-matrix,evidence-inspector,task-progress,action-bar]
states=[queued,open,approved,rejected,applied,failed]
syncTargets=[review-queue,diff-review,preview-matrix,evidence-inspector,task-progress,action-bar]
transitionEvents=[open,approve,reject,apply,fail]
requiresEvidenceLink=true
requiresVisibleState=true
requiresHumanApproval=true
bulkApplyRequiresExplicitHumanApproval=true
usesDiffReview=true
usesContentOpeners=true
metadataOnly=true
hashOnlyReferences=true
redactsRawPayload=true
rawContentInFixture=false
mainDocumentMutationAllowed=false
autoApplyAllowed=false
conflictBehavior=fail-closed-user-visible
failureBehavior=fail-closed-user-visible
runtimeReviewStateSyncImplementation=not-started

The sync surface intentionally stores only ids, state names, transition names, evidence ids, and hash references. It must make the current state visible in every surface that exposes a review item, and conflicts must fail closed visibly instead of silently choosing one state. The contract does not allow review-state sync to apply changes by itself.

## Invalid Guards

The W1 self-test must reject these drift classes:

review-state-sync-missing-envelope.json: omits the review-state sync envelope while claiming shared review state.
review-state-sync-target-drift.json: drops a required source, target, state, transition, visible state, evidence link, DiffReview reuse, or content opener reuse.
review-state-sync-auto-apply.json: enables auto-apply, allows main-document mutation, skips human approval, or applies bulk changes without explicit human approval.
review-state-sync-runtime-started.json: claims review-state sync runtime is already started, stores raw payload content, disables metadata-only/hash-only/redaction requirements, or fails silently.
review-queue-bulk-auto-apply.json: keeps rejecting batch auto-apply drift.
action-bar-hidden-mouse-only.json: keeps rejecting hidden or inaccessible review actions.

## Non-Goals

No review-state sync runtime is started by this policy.
No W1 sidebar runtime, review queue runtime, DiffReview runtime change, preview matrix runtime, action bar runtime, context handoff runtime, content opener runtime, evidence inspector runtime, W2 connector runtime, W3 retrieval runtime, W4 audit runtime, W6 task execution, or W7 companion runtime is authorized.
No new W1 schema is introduced.
No fixture may store raw document, prompt, connector, retrieval, evidence, task-step, review, formatting preview, suggestion, rendered UI, state-sync payload, or DiffReview payload content.
No sync path may mutate the main document or apply changes before explicit human approval.
No hidden, stale, split-brain, or silent review-state failure path is valid.

## Verification

tests/v3-in-app-chat-test.sh validates this policy, the 5 valid / 76 invalid fixture roster, and the review-state sync envelope. It must report Checks: 21.
