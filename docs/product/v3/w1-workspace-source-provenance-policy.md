# V3 W1 Workspace Source Provenance Policy

Status: contract-only policy lock for L243. Runtime implementation is not started.

W1 must keep every AI claim, content suggestion, formatting change, and review item tied to a visible source provenance record. The record is metadata-only: it stores source ids, source type, citation id, evidence id, hash reference, source surface, open target, span reference, and review id. It must not store raw document text, connector payloads, preview bodies, transcript bodies, or source content in fixtures.

## Locked Envelope

workspaceUi.sourceProvenance is required in every valid W1 in-app-chat fixture:

- visible=true
- scope=[current-workspace,current-document]
- sourceTypes=[document,selection,connector-result,knowledge-index-result,evidence-record,task-step,review-item,formatting-preview,content-suggestion]
- requiredFields=[source-id,source-type,citation-id,evidence-id,hash-reference,source-surface,open-target,span-reference,review-id]
- surfaces=[content-review,formatting-review,preview-matrix,evidence-inspector,review-queue,activity-timeline,composer]
- citationTargets=[main-document-window,sidebar-preview,diff-review,evidence-inspector,review-queue]
- mapsAiClaimsToSources=true
- mapsSuggestionsToEvidence=true
- mapsFormattingChangesToStyleSources=true
- requiresEvidenceLink=true
- requiresOpenTarget=true
- requiresVisibleCitationBadge=true
- usesContentRegistry=true
- usesContentOpeners=true
- usesEvidenceInspector=true
- usesReviewQueue=true
- usesDiffReview=true
- metadataOnly=true
- hashOnlyReferences=true
- redactsRawPayload=true
- rawContentInFixture=false
- sourceContentInFixture=false
- previewContentInFixture=false
- transcriptContentInFixture=false
- mainDocumentMutationAllowed=false
- autoOpenAllowed=false
- autoApplyAllowed=false
- failureBehavior=fail-closed-user-visible
- runtimeSourceProvenanceImplementation=not-started

## Product Meaning

This lock turns AI participation into an evidence-backed workspace flow. A content review finding, layout suggestion, formatting preview, connector-derived answer, or task result must show what it is based on and where the user can open it. The citation badge is not decorative; it is the user-facing handle for inspecting evidence, opening the relevant source, and returning to the review item.

Source provenance records are handles, not content caches. They may point at local evidence ids, hash references, and span references, but any raw source text or preview body must stay outside W1 fixtures. If a citation cannot be opened through the registered target or cannot be tied to evidence, W1 must fail closed with a user-visible state.

## Invalid Guards

The W1 self-test rejects these regressions:

- source-provenance-missing-envelope.json: the workspace lacks the required source provenance envelope.
- source-provenance-type-drift.json: the source type roster no longer covers AI-reviewed, AI-opened, and AI-suggested content objects.
- source-provenance-raw-payload.json: provenance metadata is replaced by raw source payload storage or citation content exposure.
- source-provenance-runtime-started.json: fixture claims a runtime source provenance implementation before W1 runtime authorization.

## Runtime Boundary

This policy does not authorize changes under product/runtime directories. W1 runtime work remains deferred until the W1 gate is explicitly opened.
