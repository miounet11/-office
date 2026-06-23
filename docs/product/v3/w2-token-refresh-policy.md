# V3 W2 Token Refresh Policy

Status: **Contract-only** (2026-06-10: H8 token-refresh guard active; runtime implementation not started)

## Decision

V3 v0 connector manifests must declare an `auth.refreshPolicy` envelope. The policy is deliberately conservative until W8 secret-broker runtime and W2 connector runtime exist:

| Auth type | Strategy | Background refresh | Refresh token storage | Runtime refresh implementation |
|---|---|---|---|---|
| `oauth2` | `reauth-on-expiry` | `false` | `false` | `not-started` |
| `api-key` | `manual-rotate` | `false` | `false` | `not-started` |
| `none` | `not-applicable` | `false` | `false` | `not-started` |

This resolves W2 Q3 for the V3 v0 contract layer. Expired OAuth access requires explicit user reauthorization. API keys require explicit user or admin rotation. Connectors may not claim background token refresh, refresh-token persistence, silent renewal, or runtime refresh implementation before a separate W8/W2 runtime gate authorizes it.

## Contract

`docs/schemas/connector-manifest.schema.json` requires `auth.refreshPolicy` with:

- `strategy`: one of `reauth-on-expiry`, `manual-rotate`, or `not-applicable`
- `backgroundRefresh=false`
- `storesRefreshToken=false`
- `runtimeRefreshImplementation=not-started`

`tests/v3-connector-manifest-contract-test.sh` enforces auth-type semantics:

- `oauth2` must use `reauth-on-expiry`
- `api-key` must use `manual-rotate`
- `none` must use `not-applicable`
- all auth types must reject background refresh, refresh-token storage, and runtime refresh implementation drift

## Guard Fixtures

The H8 invalid roster includes:

- `background-refresh-enabled.json`
- `refresh-token-stored.json`
- `runtime-refresh-implementation-started.json`

These fixtures prevent a manifest-only change from silently authorizing token-refresh behavior before runtime secret handling and evidence contracts are ready.

## Non-Goals

This document does not authorize OAuth UI, embedded browser flows, background daemons, refresh-token persistence, platform secure-store implementation, token refresh evidence emission, connector registry loading, or product integration. Those remain future gated runtime work after V2 GA and explicit user authorization.
