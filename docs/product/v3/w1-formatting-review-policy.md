# V3 W1 Formatting Review Policy

Status: contract active (2026-06-11, L227)
Scope: W1 AI workspace formatting/layout review; design/fixture contract only.
Runtime implementation: not-started

This policy refines the L225 AI workspace UI contract and the L226 content opener policy. W1 must support AI-assisted formatting review as a first-class review surface, not as silent direct formatting or a text-only suggestion. Formatting review remains evidence-linked, preview-first, and human-approved before any main-document mutation.

## Locked Contract

All valid W1 in-app-chat fixtures must declare workspaceUi.formattingReview with:

scope=[paragraph-style,character-style,table-layout,cell-format,slide-layout]
reviewMode=before-after-layout-diff
visible=true
usesDiffReview=true
requiresEvidenceLink=true
requiresHumanApproval=true
mainDocumentUnchangedUntilApproval=true
rawContentInFixture=false
previewContentInFixture=false
failureBehavior=fail-closed-user-visible
runtimeFormattingImplementation=not-started

The scope intentionally spans Writer, Calc, and Impress formatting: paragraph and character style changes, table layout changes, cell formatting, and slide layout changes. W1 may describe proposed formatting changes, but the fixture contract stores no raw document text, rendered preview payloads, screenshots, or private connector content.

## Invalid Guards

The W1 self-test must reject these drift classes:

formatting-review-missing-envelope.json: claims formatting review support without the required envelope.
formatting-review-no-diffreview.json: bypasses DiffReview or evidence-linked review.
formatting-review-mutable-preview.json: mutates the main document before approval or uses a direct-format mode.
formatting-review-runtime-started.json: claims formatting runtime is already started or stores raw/preview content in fixtures.
workspace-formatting-no-preview.json: keeps rejecting broad layout-preview bypass drift.

## Non-Goals

No formatting review runtime is started by this policy.
No rendered preview, document content, connector content, screenshot, or raw formatting payload is stored in fixtures.
No direct formatting mutation is authorized before human approval.
No W1 sidebar runtime, W4 runtime, W6 task execution, W3 retrieval runtime, or W7 companion runtime is authorized.

## Verification

tests/v3-in-app-chat-test.sh validates this policy, the 5 valid / 36 invalid fixture roster, and the formatting review envelope. It must report Checks: 11.
