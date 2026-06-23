# V3 W1 Workspace Filter/Search Policy

Status: contract active (2026-06-11, L235)
Scope: W1 AI workspace filter/search surface; design/fixture contract only.
Runtime implementation: not-started

This policy refines the L229 artifact navigator, L230 review queue, L231 evidence inspector, L233 content preview matrix, and L234 workspace action bar policies. W1 needs fast ways to find AI work products across task progress, artifacts, review items, evidence, and previews, but that search must not become a hidden global index of document text, connector payloads, retrieval snippets, review bodies, or generated content.

## Locked Contract

All valid W1 in-app-chat fixtures must declare workspaceUi.filterSearch with:

visible=true
scope=[current-workspace,current-document]
surfaces=[tasks,artifacts,reviews,evidence,previews]
filterBy=[state,type,surface,source,evidence-status]
searchFields=[id,type,state,source-metadata,evidence-id,hash-reference]
sortOptions=[recent-first,type,state,source]
metadataOnly=true
hashOnlyReferences=true
redactsRawPayload=true
rawContentIndexed=false
rawContentInFixture=false
crossDocumentSearch=false
globalIndex=false
usesContentOpeners=true
requiresEvidenceLink=true
failureBehavior=fail-closed-user-visible
runtimeFilterSearchImplementation=not-started

The filter/search surface intentionally names metadata fields, scopes, filters, and sort options rather than storing UI labels, rendered snapshots, document text, connector payloads, retrieval snippets, evidence bodies, task payloads, review bodies, formatting previews, generated suggestions, or DiffReview bodies. Search results that open content must route through contentOpeners and remain evidence-linked. The contract is scoped to the current workspace/current document and cannot create a global or cross-document raw-content index.

## Invalid Guards

The W1 self-test must reject these drift classes:

filter-search-missing-envelope.json: omits the filter/search envelope while claiming searchable AI workspace content.
filter-search-scope-drift.json: expands search to global workspaces/all documents, enables cross-document search, or uses a global index.
filter-search-raw-index.json: indexes raw document or connector content, exposes raw payloads, disables hash-only references, or stores raw searchable content in fixtures.
filter-search-runtime-started.json: claims filter/search runtime is already started, bypasses contentOpeners, drops evidence links, or fails silently.
global-history-leakage.json: keeps rejecting cross-document/global history drift.
raw-context-preview.json: keeps rejecting raw context preview leakage.

## Non-Goals

No filter/search runtime is started by this policy.
No global search index, cross-document search, connector full-text index, Knowledge Index runtime query path, W1 sidebar runtime, content opener runtime, action bar runtime, preview matrix runtime, interaction chrome runtime, evidence inspector runtime, review queue runtime, artifact navigator runtime, W2 connector runtime, W3 retrieval runtime, W4 audit runtime, W6 task execution, or W7 companion runtime is authorized.
No new W1 schema is introduced.
No fixture may store raw document, prompt, connector, retrieval, evidence, task-step, review, formatting preview, suggestion, rendered UI, or DiffReview payload content.
No search result may mutate the main document before explicit human approval.
No hidden raw-content index or silent failure path is valid.

## Verification

tests/v3-in-app-chat-test.sh validates this policy, the 5 valid / 68 invalid fixture roster, and the filter/search envelope. It must report Checks: 19.
