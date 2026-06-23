# V3 W1 Workspace Content Registry Policy

Status: contract-only policy lock for L242. Runtime implementation is not started.

W1 must treat every AI-visible workspace object as a registered content object before it can be opened, previewed, reviewed, linked as evidence, or resumed. The registry is metadata-only: it records stable ids, object type, source surface, lifecycle state, evidence id, hash reference, open target, and preview mode. It must not store raw document text, connector payloads, preview bodies, transcript bodies, or suggestion content in fixtures.

## Locked Envelope

workspaceUi.contentRegistry is required in every valid W1 in-app-chat fixture:

- visible=true
- scope=[current-workspace,current-document]
- types=[document,selection,connector-result,knowledge-index-result,evidence-record,task-step,review-item,formatting-preview,content-suggestion]
- states=[registered,opened,previewed,in-review,applied,failed,archived]
- requiredFields=[object-id,type,source-surface,state,evidence-id,hash-reference,open-target,preview-mode]
- openTargets=[main-document-window,sidebar-preview,diff-review,evidence-inspector,review-queue]
- previewModes=[metadata-summary,read-only-preview,diff-preview,evidence-summary]
- usesContentOpeners=true
- usesPreviewMatrix=true
- usesEvidenceInspector=true
- usesReviewQueue=true
- metadataOnly=true
- hashOnlyReferences=true
- redactsRawPayload=true
- rawContentInFixture=false
- previewContentInFixture=false
- transcriptContentInFixture=false
- mainDocumentMutationAllowed=false
- autoOpenAllowed=false
- autoApplyAllowed=false
- failureBehavior=fail-closed-user-visible
- runtimeContentRegistryImplementation=not-started

## Product Meaning

This lock turns the AI workspace from a chat transcript into a content workbench. A document, selection, connector result, knowledge-index result, evidence record, task step, review item, formatting preview, and content suggestion must be addressable by id and opened through the existing content opener, preview matrix, evidence inspector, or review queue.

The registry is an index of handles, not a content cache. It may point at local evidence and hash references, but any raw text, extracted connector payload, preview body, or transcript content must stay outside W1 fixtures. Missing source metadata or evidence links must fail closed with a user-visible state.

## Invalid Guards

The W1 self-test rejects these regressions:

- content-registry-missing-envelope.json: the workspace lacks the required content registry envelope.
- content-registry-type-drift.json: the type roster no longer covers AI-reviewed/opened content objects.
- content-registry-raw-payload.json: registry metadata is replaced by raw payload storage or payload exposure.
- content-registry-runtime-started.json: fixture claims a runtime registry implementation before W1 runtime authorization.

## Runtime Boundary

This policy does not authorize changes under product/runtime directories. W1 runtime work remains deferred until the W1 gate is explicitly opened.
