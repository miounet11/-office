# V3-W1: Chat History Policy

Status: **active contract** (2026-06-10; design/fixture only; runtime implementation not started)
Owner: V3-W1 In-App Chat

---

## 1. Decision

W1 chat history is per-doc-local. A chat thread can be restored only for the document it belongs to, and the fixture contract must not create global chat history, cloud sync, cross-document restore, or raw transcript storage.

| Concern | Policy |
|---|---|
| Scope | per-doc-local |
| Storage | local-sqlite-sidecar |
| Binding | document-id-hash |
| Cloud sync | forbidden |
| Global index | forbidden |
| Cross-document restore | forbidden |
| Raw content in fixtures | forbidden |
| User control | visible clear-history control required |
| Deletion | history deleted with the document |
| Runtime gate | runtimeImplementation=not-started until V2 GA or explicit user authorization |

---

## 2. Fixture Envelope

Every valid docs/qa/fixtures/v3/in-app-chat/ fixture must declare:

- history.scope = per-doc-local
- history.storage = local-sqlite-sidecar
- history.documentBinding = document-id-hash
- history.cloudSync = false
- history.globalIndex = false
- history.crossDocumentRestore = false
- history.rawContentInFixture = false
- history.requiresUserClearControl = true
- history.deleteWithDocument = true

This envelope defines the history locality contract only. It does not authorize a SQLite implementation, sidebar state persistence, document-id derivation, or migration code.

---

## 3. Guards

tests/v3-in-app-chat-test.sh rejects:

- global-history-leakage.json: global history, global index, or cross-document restore.
- cloud-history-sync.json: cloud-backed chat history or sync.
- raw-transcript-history.json: raw prompt/document/chat transcript storage in fixtures.
- missing-history-clear-control.json: no visible clear-history control or no delete-with-document behavior.

Existing W1 guards still apply: explicit context only, no new chat schema, no direct accelerator registration, no WebView/raw HTML/remote image rendering, no cloud history, no stored prompt content in evidence, and no runtime/source implementation before the gate opens.
