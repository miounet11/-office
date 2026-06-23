# V3 W1 Content Opener Policy

Status: contract active (2026-06-11, L226)
Scope: W1 AI workspace content opening and preview routing; design/fixture contract only.
Runtime implementation: not-started

This policy refines the L225 AI workspace UI contract. W1 must support opening more than the current document, but every opener is a reviewed, evidence-linked, read-only preview until the existing approval path applies a patch.

## Locked Contract

All valid W1 in-app-chat fixtures must declare workspaceUi.contentOpeners with:

supportedTypes=[document,selection,connector-result,knowledge-index-result,evidence-record,task-step]
opensIn=[main-document-window,sidebar-preview,diff-review]
routePolicy.document=main-document-window
routePolicy.selection=sidebar-preview
routePolicy.connector-result=sidebar-preview
routePolicy.knowledge-index-result=sidebar-preview
routePolicy.evidence-record=sidebar-preview
routePolicy.task-step=diff-review
requiresEvidenceLink=true
readOnlyPreview=true
mainDocumentMutationAllowed=false
rawContentInFixture=false
openFailureBehavior=fail-closed-user-visible
runtimeOpenImplementation=not-started

The routing keeps user documents and proposed edits separate: normal documents open in the main document window, contextual artifacts open in a sidebar preview, and task steps open through DiffReview. This lets content review, formatting review, evidence inspection, Knowledge Index results, connector results, and W6 task steps share one workspace model without granting silent mutation rights.

## Invalid Guards

The W1 self-test must reject these drift classes:

opener-route-policy-drift.json: routes task steps or evidence to the wrong surface.
opener-missing-evidence-link.json: opens content without an evidence link.
opener-mutable-preview.json: turns preview into a mutating editor before approval.
opener-silent-failure.json: hides opener failures from the user.
workspace-openers-runtime-started.json: claims opener runtime is already started or stores raw content in fixtures.

## Non-Goals

No content opener runtime is started by this policy.
No raw document, connector, retrieval result, evidence, or task-step content is stored in fixtures.
No hidden mutation of the main document is authorized.
No W6 task execution, W3 retrieval runtime, W2 connector runtime, or W7 companion runtime is authorized.

## Verification

tests/v3-in-app-chat-test.sh validates this policy, the 5 valid / 32 invalid fixture roster, and the opener route policy. It must report Checks: 10.
