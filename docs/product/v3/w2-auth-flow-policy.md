# V3 W2 Auth Flow Policy

Status: **Contract-only** (2026-06-10: H8 auth-flow guard active; runtime implementation not started)

## Decision

V3 v0 connector manifests must declare an `auth.flow` envelope. OAuth2 connectors use the system browser and a loopback callback only:

| Auth type | Strategy | Embedded WebView | Callback | Runtime auth implementation |
|---|---|---|---|---|
| `oauth2` | `system-browser-loopback` | `false` | `loopback-127.0.0.1` | `not-started` |
| `api-key` | `manual-secret-entry` | `false` | `manual-entry` | `not-started` |
| `none` | `not-applicable` | `false` | `none` | `not-started` |

This resolves W2 Q1 for the V3 v0 contract layer. Embedded WebViews are forbidden because they create an opaque credential-capture surface and would duplicate W8/W7 browser-security decisions before those runtimes exist. OAuth2 must use the OS/system browser with a `127.0.0.1` loopback callback. API keys require explicit manual secret entry. Connectors may not claim auth runtime implementation before a separate runtime gate authorizes it.

## Contract

`docs/schemas/connector-manifest.schema.json` requires `auth.flow` with:

- `strategy`: one of `system-browser-loopback`, `manual-secret-entry`, or `not-applicable`
- `embeddedWebView=false`
- `callback`: one of `loopback-127.0.0.1`, `manual-entry`, or `none`
- `runtimeAuthImplementation=not-started`

`tests/v3-connector-manifest-contract-test.sh` enforces auth-type semantics:

- `oauth2` must use `system-browser-loopback` and `loopback-127.0.0.1`
- `api-key` must use `manual-secret-entry` and `manual-entry`
- `none` must use `not-applicable` and `none`
- all auth types must reject embedded WebViews and runtime auth implementation drift

## Guard Fixtures

The H8 invalid roster includes:

- `embedded-webview-auth-flow.json`
- `oauth-non-loopback-callback.json`
- `runtime-auth-implementation-started.json`

These fixtures prevent a manifest-only change from silently authorizing credential capture, non-loopback OAuth redirects, or auth runtime claims before W8/W2 runtime work is approved.

## Non-Goals

This document does not authorize OAuth UI, an embedded browser, loopback listener implementation, API key secure-store implementation, token refresh runtime, connector registry loading, `Connectors.xcu` registration, or product integration. Those remain future gated runtime work after V2 GA and explicit user authorization.
