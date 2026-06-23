# V3-W1 Context Syntax Policy

Status: **context syntax contract active** (2026-06-10: design-only; parser/runtime implementation not started)
Owner spec: `docs/product/v3/w1-in-app-chat-spec.md`

## 1. Decision

W1 Chat must start with no implicit document context. The user has to opt into context with one of the locked mentions:

| Mention | Meaning | Contract |
|---|---|---|
| `@selection` | Current selection only | Allowed on Writer/Calc/Impress; no raw selected content stored in fixtures. |
| `@doc` | Current document summary context | Requires explicit mention and human-visible scope; no implicit full-document capture. |
| `@connector:<id>` | Read-only connector context | Requires a W2 connector manifest, read-only access, and `data-fetch` evidence. |

The accepted grammar is `@(selection|doc|connector:[a-z0-9-]+)`. Any unknown mention, empty implicit context, connector write-back, or raw document/prompt payload in a fixture is invalid.

## 2. Privacy Rules

- `defaultScope` stays `none` for every valid fixture.
- `explicitMentions` must be non-empty.
- Fixtures store mention names, ids, and evidence categories only; they do not store raw document, prompt, selection, or connector content.
- `@doc` is a scope request, not permission to persist document content.
- `@connector:<id>` is read-only in W1 v0 and must be backed by W2 manifest policy.

## 3. Test Coverage

`tests/v3-in-app-chat-test.sh` validates this policy by requiring valid fixtures to use only `@selection`, `@doc`, or `@connector:<id>`, and by rejecting:

- `implicit-full-doc-context.json`
- `unknown-context-mention.json`
- `connector-write-context.json`

## 4. Runtime Gate

No parser, autocomplete, context extraction, connector fetch, or sidebar UI behavior is authorized by this policy. Those remain W1 runtime implementation work after V2 GA and explicit user authorization.
