# V3 W1 Artifact Navigator Policy

Status: contract active (2026-06-11, L229)
Scope: W1 AI workspace artifact/content navigator; design/fixture contract only.
Runtime implementation: not-started

This policy refines the L225 AI workspace UI contract plus the L226-L228 content opener, formatting review, and content review policies. W1 must manage AI-related artifacts as a visible workspace surface, not as hidden chat transcript state or one-off previews. The artifact navigator is a sidebar list for documents, selections, connector results, Knowledge Index results, evidence records, and task steps, with evidence badges and content opener integration.

## Locked Contract

All valid W1 in-app-chat fixtures must declare workspaceUi.artifactNavigator with:

visible=true
scope=[current-workspace,current-document]
managedTypes=[document,selection,connector-result,knowledge-index-result,evidence-record,task-step]
groupBy=[type,task]
sort=recent-first
evidenceBadgeVisible=true
openUsesContentOpeners=true
readOnlyDetails=true
rawContentInFixture=false
mainDocumentMutationAllowed=false
failureBehavior=fail-closed-user-visible
runtimeArtifactNavigatorImplementation=not-started

The navigator intentionally shares the content type roster with W1 content openers and review surfaces. It gives users a Codex-like way to inspect what the AI touched, opened, cited, or proposed, while preserving the existing rule that fixtures store metadata only and never raw document, connector, retrieval, evidence, task-step, or suggestion payload content.

## Invalid Guards

The W1 self-test must reject these drift classes:

artifact-navigator-missing-envelope.json: omits the navigator while claiming the AI workspace can manage/open artifacts.
artifact-navigator-type-drift.json: drops connector, Knowledge Index, evidence, or task-step artifacts from the managed type roster.
artifact-navigator-mutable-details.json: turns read-only artifact details into a mutation path or bypasses contentOpeners.
artifact-navigator-runtime-started.json: claims navigator runtime is already started or stores raw artifact content in fixtures.
workspace-openers-runtime-started.json: keeps rejecting broad opener/runtime/raw-content drift.

## Non-Goals

No artifact navigator runtime is started by this policy.
No raw document, connector, retrieval, evidence, task-step, or suggestion content is stored in fixtures.
No artifact detail view is allowed to mutate the main document before approval.
No W1 sidebar runtime, content opener runtime, formatting runtime, content review runtime, W2 connector runtime, W3 retrieval runtime, W6 task execution, or W7 companion runtime is authorized.

## Verification

tests/v3-in-app-chat-test.sh validates this policy, the 5 valid / 44 invalid fixture roster, and the artifact navigator envelope. It must report Checks: 13.
