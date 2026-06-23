# V3-W1: Streaming State Policy

Status: **active contract** (2026-06-10; design/fixture only; runtime implementation not started)
Owner: V3-W1 In-App Chat

---

## 1. Decision

W1 chat streaming reuses V2 Provider chunk semantics and presents a deterministic sidebar state machine. Streaming output is display-only until an ApplyPlan is complete and the user approves it.

State roster: idle, requesting, streaming, awaiting-approval, applied, failed, cancelled.

| Concern | Policy |
|---|---|
| Source | v2-provider-chunk |
| States | idle, requesting, streaming, awaiting-approval, applied, failed, cancelled |
| Chunk rendering | append-only during stream |
| Main document | unchanged while streaming |
| Cancel | supported |
| Retry | supported |
| Partial chunk persistence | forbidden |
| Chunk content in fixtures | forbidden |
| Evidence | terminal states emit evidence |
| Runtime gate | runtimeImplementation=not-started until V2 GA or explicit user authorization |

---

## 2. Fixture Envelope

Every valid docs/qa/fixtures/v3/in-app-chat/ fixture must declare:

- streamingUi.source = v2-provider-chunk
- streamingUi.states = idle, requesting, streaming, awaiting-approval, applied, failed, cancelled
- streamingUi.appendOnlyDuringStream = true
- streamingUi.mainDocumentUnchangedWhileStreaming = true
- streamingUi.cancelSupported = true
- streamingUi.retrySupported = true
- streamingUi.partialChunksPersisted = false
- streamingUi.chunkContentInFixture = false
- streamingUi.evidenceOnTerminalState = true

This envelope defines the sidebar state contract only. It does not authorize streaming UI implementation, sidebar timers, cancellation wiring, retry wiring, partial transcript persistence, or provider runtime changes.

---

## 3. Guards

tests/v3-in-app-chat-test.sh rejects:

- streaming-mutates-document.json: main-document mutation before final approval.
- partial-chunks-persisted.json: partial chunk persistence or fixture chunk content storage.
- missing-terminal-evidence.json: no evidence on applied, failed, or cancelled terminal states.
- unsupported-stream-state.json: state names outside the locked roster.

Existing W1 guards still apply: explicit context only, per-doc-local history, native Markdown subset rendering, no new chat schema, no direct accelerator registration, no stored prompt content in evidence, and no runtime/source implementation before the gate opens.
