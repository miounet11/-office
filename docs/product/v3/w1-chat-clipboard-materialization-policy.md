# V3 W1 Chat Clipboard Materialization Policy

Status: contract-only policy lock for L244. Runtime implementation is not started.

W1 must treat large, rich, or structured clipboard content pasted into the chat composer as a local temporary content object before it enters the conversation. The chat transcript stores a stable reference, not the raw clipboard body. The object is then visible through the workspace content registry, artifact navigator, content openers, and source provenance surfaces.

## Locked Envelope

workspaceUi.clipboardMaterialization is required in every valid W1 in-app-chat fixture:

- visible=true
- scope=[chat-composer,current-workspace,current-document]
- materializesInputTypes=[plain-text-large,rich-text,html-fragment,table-range,image,local-file-reference]
- thresholdPolicy=large-or-structured-content
- storage=local-temp-content-object
- referenceInsertedIntoChat=true
- transcriptStoresReferenceOnly=true
- historyStoresReferenceOnly=true
- preservesFormattingMetadata=true
- usesContentRegistry=true
- usesArtifactNavigator=true
- usesContentOpeners=true
- usesSourceProvenance=true
- requiresHashReference=true
- requiresEvidenceLink=true
- rawClipboardContentInFixture=false
- rawContentInTranscript=false
- rawContentInHistory=false
- mainDocumentMutationAllowed=false
- autoApplyAllowed=false
- failureBehavior=fail-closed-user-visible
- runtimeClipboardMaterializationImplementation=not-started

## Product Meaning

This lock makes the chat composer behave like a Codex-style content workbench. Pasting a long passage, rich text fragment, spreadsheet range, HTML snippet, image, or local file reference must create an inspectable temporary content object. The composer inserts a compact reference into the message so the user can review, open, copy, cite, or remove the object without flooding the transcript or history store.

The temporary object is local and metadata-first. Fixtures may assert the routing, provenance, and storage semantics, but they must never embed raw clipboard bodies, rendered previews, prompt text, or transcript content.

## Invalid Guards

The W1 self-test rejects these regressions:

- clipboard-materialization-missing-envelope.json: the workspace omits clipboard materialization while claiming chat content-object handling.
- clipboard-materialization-raw-transcript.json: pasted content is stored directly in transcript/history instead of as a reference.
- clipboard-materialization-memory-only.json: pasted content stays as invisible in-memory chat state instead of a local temp content object.
- clipboard-materialization-runtime-started.json: fixture claims runtime clipboard materialization before W1 runtime authorization.

## Runtime Boundary

This policy does not authorize changes under product/runtime directories. W1 runtime work remains deferred until the W1 gate is explicitly opened.
