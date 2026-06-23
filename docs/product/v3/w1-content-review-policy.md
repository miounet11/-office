# V3 W1 Content Review Policy

Status: contract active (2026-06-11, L228)
Scope: W1 AI workspace content review; design/fixture contract only.
Runtime implementation: not-started

This policy refines the L225 AI workspace UI contract, L226 content opener policy, and L227 formatting review policy. W1 content review must be a first-class evidence-linked review surface for user-visible content suggestions, not a hidden rewrite, raw prompt transcript, or direct mutation path. Content review remains DiffReview-backed and human-approved before any main-document mutation.

## Locked Contract

All valid W1 in-app-chat fixtures must declare workspaceUi.contentReview with:

scope=[selection,document-section,connector-result,knowledge-index-result,evidence-record,task-step]
reviewMode=evidence-linked-content-diff
visible=true
usesDiffReview=true
requiresEvidenceLink=true
requiresHumanApproval=true
mainDocumentUnchangedUntilApproval=true
rawContentInFixture=false
suggestionContentInFixture=false
failureBehavior=fail-closed-user-visible
runtimeContentReviewImplementation=not-started

The scope intentionally spans direct document selections, broader document sections, connector results, Knowledge Index results, evidence records, and task steps. This keeps AI content suggestions reviewable and auditable across Writer, Calc, Impress, connector context, retrieval context, and later W6 task steps while preserving the W1 rule that fixtures store no raw document, connector, evidence, retrieval, or suggestion payload content.

## Invalid Guards

The W1 self-test must reject these drift classes:

content-review-missing-envelope.json: claims content review support without the required envelope.
content-review-no-evidence.json: bypasses DiffReview or evidence-linked review.
content-review-mutable-suggestion.json: mutates the main document before approval or uses a direct-rewrite review mode.
content-review-runtime-started.json: claims content review runtime is already started or stores raw/suggestion content in fixtures.
workspace-review-without-evidence.json: keeps rejecting broad review-surface evidence drift.

## Non-Goals

No content review runtime is started by this policy.
No raw document, connector, retrieval, evidence, task-step, or suggestion content is stored in fixtures.
No direct content mutation is authorized before human approval.
No W1 sidebar runtime, content opener runtime, formatting runtime, W2 connector runtime, W3 retrieval runtime, W6 task execution, or W7 companion runtime is authorized.

## Verification

tests/v3-in-app-chat-test.sh validates this policy, the 5 valid / 40 invalid fixture roster, and the content review envelope. It must report Checks: 12.
