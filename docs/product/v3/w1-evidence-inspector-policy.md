# V3 W1 Evidence Inspector Policy

Status: contract active (2026-06-11, L231)
Scope: W1 AI workspace evidence/citation inspector; design/fixture contract only.
Runtime implementation: not-started

This policy refines the L225-L230 Codex-style AI workspace contracts. AI content review, formatting review, artifact navigation, and review queues must be traceable to evidence without turning fixtures into raw transcript, document, connector, retrieval, or review payload storage. The evidence inspector is the read-only workspace surface for citation links, audit trail metadata, and hash-only references behind AI-generated or AI-reviewed content.

## Locked Contract

All valid W1 in-app-chat fixtures must declare workspaceUi.evidenceInspector with:

visible=true
sourceTypes=[evidence-record,connector-result,knowledge-index-result,task-step,review-item]
showsCitationLinks=true
showsAuditTrail=true
openUsesContentOpeners=true
redactsRawPayload=true
hashOnlyReferences=true
requiresEvidenceLink=true
rawContentInFixture=false
mainDocumentMutationAllowed=false
failureBehavior=fail-closed-user-visible
runtimeEvidenceInspectorImplementation=not-started

The inspector intentionally crosses AI workspace surfaces. It can point from a content review item, formatting review item, task step, connector result, Knowledge Index result, or evidence record to metadata that explains why an AI suggestion exists. It cannot store the original prompt, document text, connector payload, retrieval snippet, evidence body, task payload, review body, or DiffReview body in the fixture. References are hash-only and open through W1 contentOpeners so the same read-only preview, evidence-link, and fail-closed rules apply.

## Invalid Guards

The W1 self-test must reject these drift classes:

evidence-inspector-missing-envelope.json: omits the inspector while claiming AI evidence/citation inspection.
evidence-inspector-source-drift.json: drops connector, Knowledge Index, task-step, or review-item source coverage.
evidence-inspector-raw-payload.json: stores raw payload content, disables redaction, or uses non-hash references.
evidence-inspector-runtime-started.json: claims evidence inspector runtime is already started, bypasses contentOpeners, or allows main-document mutation.
review-queue-runtime-started.json: keeps rejecting broad review runtime/raw-content drift.
opener-missing-evidence-link.json: keeps rejecting evidence-free open paths.

## Non-Goals

No evidence inspector runtime is started by this policy.
No raw prompt, document, connector, retrieval, evidence, task-step, review, formatting preview, suggestion, or DiffReview payload content is stored in fixtures.
No inspector view may mutate the main document before approval.
No inspector view may bypass W1 contentOpeners for opening cited artifacts.
No W1 sidebar runtime, content opener runtime, formatting runtime, content review runtime, artifact navigator runtime, review queue runtime, W2 connector runtime, W3 retrieval runtime, W4 audit runtime, W6 task execution, or W7 companion runtime is authorized.

## Verification

tests/v3-in-app-chat-test.sh validates this policy, the 5 valid / 52 invalid fixture roster, and the evidence inspector envelope. It must report Checks: 15.
