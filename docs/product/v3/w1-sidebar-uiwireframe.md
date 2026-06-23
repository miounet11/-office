# V3-W1 Sidebar UI Wireframe

Status: **design-only** (2026-06-10: no runtime UI files created)
Owner spec: `docs/product/v3/w1-in-app-chat-spec.md`

## 1. Surface

W1 Chat renders in an `sfx2-sidebar` panel after the `command-palette-chat-fallback` route resolves. It is not a standalone app, floating chat window, or WebView.

## 2. Layout Contract

```
+------------------------------------------------------+
| AI Chat                                              |
|------------------------------------------------------|
| Context chips: @selection  @doc  @connector:<id>     |
|------------------------------------------------------|
| Conversation stream                                  |
|  - user message                                      |
|  - assistant draft                                   |
|  - pending ApplyPlan preview summary                 |
|------------------------------------------------------|
| Evidence row: local evidence id + open review        |
|------------------------------------------------------|
| Composer                                             |
|  [prompt input....................................]  |
|  [Send] [Attach selection] [Open review]             |
+------------------------------------------------------+
```

## 3. Required States

| State | Contract |
|---|---|
| Empty | Shows no document content until the user adds an explicit context mention. |
| Drafting | Streams chunks through the V2 Provider path; no cloud history storage. |
| Patch ready | Shows a summary and routes the structured ApplyPlan to the existing review/apply path. |
| Awaiting approval | Main document remains unchanged until human approval. |
| Connector context | Shows connector id and evidence category only; connector content is not stored in the fixture. |
| Error | Delegates recoverable errors to the W9 error-recovery UX contract. |

## 4. Non-Goals

- No standalone chat app.
- No new W1 schema.
- No direct accelerator registration.
- No WebView requirement.
- No stored prompt or raw document content in contract fixtures.
- No runtime `sfx2/`, `sw/`, `sc/`, `sd/`, or `officecfg/` implementation in this design increment.
