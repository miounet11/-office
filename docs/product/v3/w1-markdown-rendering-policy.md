# V3-W1: Markdown Rendering Policy

Status: **active contract** (2026-06-10; design/fixture only; runtime implementation not started)
Owner: V3-W1 In-App Chat

---

## 1. Decision

W1 chat answers render through a native rich-text Markdown subset inside the sfx2-sidebar. W1 must not embed a WebView or execute HTML for chat output.

Allowed block subset: paragraph, heading, list, code-fence, table.

| Concern | Policy |
|---|---|
| Renderer | native-rich-text |
| Format | markdown-subset |
| Blocks | paragraph, heading, list, code-fence, table |
| Raw HTML | rejected before render |
| Remote images | rejected before render |
| WebView | forbidden |
| Runtime gate | runtimeImplementation=not-started until V2 GA or explicit user authorization |

---

## 2. Fixture Envelope

Every valid docs/qa/fixtures/v3/in-app-chat/ fixture must declare:

- output.rendering.format = markdown-subset
- output.rendering.renderer = native-rich-text
- output.rendering.allowedBlocks = paragraph, heading, list, code-fence, table
- output.rendering.webView = false
- output.rendering.allowsRawHtml = false
- output.rendering.allowsRemoteImages = false

The envelope is part of the W1 fixture contract, not a new schema. W1 continues to reuse V2 Provider, V2 ApplyPlan runtime validation, V2 token locks, and V2 evidence records.

---

## 3. Guards

tests/v3-in-app-chat-test.sh rejects:

- raw-html-rendering.json: raw HTML or script-capable rendering.
- webview-renderer.json: WebView-backed chat output.
- remote-image-rendering.json: remote image fetches inside chat Markdown.

Existing W1 guards still apply: no new chat schema, no direct accelerator registration, explicit context only, no cloud history, no stored prompt content, and no runtime/source implementation before the gate opens.
