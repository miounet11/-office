# V3 W1 Review Queue Policy

Status: contract active (2026-06-11, L230)
Scope: W1 AI workspace review queue for content/formatting/task-step review items; design/fixture contract only.
Runtime implementation: not-started

This policy refines the L225-L229 Codex-style AI workspace contracts. Content review, formatting review, and task-step review items must be manageable as a visible queue, not only as individual chat replies or one-off DiffReview panels. The queue gives users a compact way to inspect pending AI suggestions, filter them, open the right review surface, and approve or reject explicitly.

## Locked Contract

All valid W1 in-app-chat fixtures must declare workspaceUi.reviewQueue with:

visible=true
itemTypes=[content-review,formatting-review,task-step]
states=[queued,open,approved,rejected,applied,failed]
filterBy=[state,type,surface]
openUsesDiffReview=true
requiresEvidenceLink=true
bulkActions=[approve-selected,reject-selected]
bulkApplyRequiresExplicitHumanApproval=true
mainDocumentMutationAllowed=false
rawContentInFixture=false
failureBehavior=fail-closed-user-visible
runtimeReviewQueueImplementation=not-started

The queue intentionally stays metadata-only in fixtures. It can name review item types and states, but it cannot store document text, connector payloads, retrieval snippets, formatting previews, suggestion bodies, or raw DiffReview content.

## Invalid Guards

The W1 self-test must reject these drift classes:

review-queue-missing-envelope.json: omits the review queue while claiming visible review management.
review-queue-no-filter.json: drops required state/type/surface filters or review states.
review-queue-bulk-auto-apply.json: adds auto-apply bulk behavior, bypasses DiffReview, or allows main-document mutation before explicit approval.
review-queue-runtime-started.json: claims review queue runtime is already started or stores raw review content in fixtures.
workspace-review-without-evidence.json: keeps rejecting broad review-without-evidence drift.

## Non-Goals

No review queue runtime is started by this policy.
No batch auto-apply path is authorized.
No raw content, formatting preview, suggestion body, connector payload, retrieval snippet, evidence payload, task-step payload, or DiffReview body is stored in fixtures.
No queued item may mutate the main document before explicit human approval.
No W1 sidebar runtime, review queue runtime, content opener runtime, formatting runtime, content review runtime, artifact navigator runtime, W2 connector runtime, W3 retrieval runtime, W6 task execution, or W7 companion runtime is authorized.

## Verification

tests/v3-in-app-chat-test.sh validates this policy, the 5 valid / 48 invalid fixture roster, and the review queue envelope. It must report Checks: 14.
