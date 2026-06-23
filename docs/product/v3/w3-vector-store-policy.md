# V3 W3 Vector Store Backend Policy

Status: **Contract-only** (2026-06-11: W3 Q2 guard active; runtime implementation not started)

This policy resolves W3 Q2 for the local vector-store backend. It does not start lancedb, add vector runtime dependencies, add build/package wiring, or promote lancedb-local to the default backend.

## Decision

- `sqlite-fts5` remains the default backend for all W3 chunks.
- `lancedb-local` is allowed only as an opt-in hybrid/vector backend.
- `lancedb-local` must not become the default before a platform smoke proves macOS arm64 stability.
- macOS arm64 lancedb status remains `pending-runtime-spike`.
- Missing, declined, unstable, or unproven vector backend state falls back to `sqlite-fts5`.
- `runtimeVectorStoreImplementation` remains `not-started`.

## Schema Lock

`docs/schemas/knowledge-index-chunk.schema.json` requires `vectorStorePolicy` on every chunk fixture:

- `defaultBackend=sqlite-fts5`
- `selectedBackend=sqlite-fts5|lancedb-local`
- `lancedbDefaultAllowed=false`
- `lancedbMacosArm64Status=pending-runtime-spike`
- `fallbackBackend=sqlite-fts5`
- `runtimeVectorStoreImplementation=not-started`

FTS chunks set `selectedBackend=sqlite-fts5` and do not need a platform smoke before default. Hybrid/vector chunks may set `selectedBackend=lancedb-local`, but they must keep `requiresPlatformSmokeBeforeDefault=true` because lancedb is still opt-in and not default.

## Invalid Guard

`docs/qa/fixtures/v3/knowledge-index-chunk/invalid/vector-store-lancedb-default-runtime.json` must remain invalid. It represents the forbidden drift where lancedb-local becomes the default backend, macOS arm64 is claimed stable without the runtime spike, FTS fallback is removed, and vector-store runtime implementation appears started before the W3 gate.

## Runtime Boundary

This policy does not authorize `ai/source/knowledge/VectorBackend.cxx`, lancedb package dependencies, index-file migrations, build-system linkage, installer contents, runtime platform smokes, or product integration. Those remain future gated W3 runtime work after V2 GA and explicit user authorization.
