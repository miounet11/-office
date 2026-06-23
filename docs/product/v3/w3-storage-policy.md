# V3-W3 Knowledge Index Storage Policy

Status: **active contract** (2026-06-11; runtime storage implementation not started)

This policy resolves W3 Q5: knowledge-index files live under the application data directory as a per-workspace sidecar. They must not be placed next to user documents, synced as part of user document folders, or store raw document content.

## Locked Decisions

| Field | Required value |
|---|---|
| `indexRoot` | `application-data-directory` |
| `workspacePartition` | `per-workspace` |
| `pathIdentity` | `workspace-hash` |
| `colocatedWithUserDocuments` | `false` |
| `syncsWithUserDocuments` | `false` |
| `storesDocumentContent` | `false` |
| `runtimeStorageImplementation` | `not-started` |

## Rationale

The index is derived cache/evidence metadata, not a user-authored document. Keeping it under the application data directory avoids polluting document folders, prevents accidental sync/upload through a user's document provider, and gives tenant policy a single local storage boundary to audit. `workspace-hash` avoids raw local paths in the storage location while preserving stable per-workspace partitioning.

This policy does not start a storage runtime. The eventual implementation must still prove platform-specific application data paths, cleanup behavior, backup policy, and migration behavior before the W3 runtime gate opens.

## Guard Fixture

`docs/qa/fixtures/v3/knowledge-index-chunk/invalid/storage-user-documents-sync-runtime.json` must remain invalid. It represents forbidden drift where indexes are placed in a user document directory, partitioned per document, keyed by raw path, synced with user documents, store document content, and start runtime storage before the W3 gate.

## Self-Test

`tests/v3-knowledge-index-chunk-test.sh` validates this policy through `storagePolicy` on every valid W3 chunk fixture and the invalid user-document sync guard. The self-test reports `Checks: 12`.
