# V3-W3: Model Acquisition Policy

Status: **active contract** (2026-06-11; runtime downloader and embedding pipeline not started)
Scope: W3 Knowledge Index chunk contract and fixtures.

This policy resolves W3 Q1 for the BGE-m3 model acquisition path. The model is large enough that the product must not hide its cost in the installer or in first-run background network activity.

## Contract

- BGE-m3 is not bundled by default.
- BGE-m3 is never downloaded silently.
- Hybrid/vector retrieval requires explicit user confirmation before model download.
- Offline mode, missing model state, and declined download fall back to SQLite FTS5.
- Model acquisition has no public egress by default.
- Runtime downloader work remains not-started.
- Runtime embedding work remains not-started.

## Schema Lock

docs/schemas/knowledge-index-chunk.schema.json requires modelAcquisitionPolicy on every chunk fixture:

- modelFamily: none for FTS-only chunks, bge-m3 for hybrid chunks.
- bundledByDefault=false.
- downloadPolicy=not-required for FTS-only chunks.
- downloadPolicy=explicit-user-confirmed for hybrid chunks.
- userConfirmationRequired=true only when BGE-m3 is needed.
- fallbackWhenMissing=sqlite-fts5.
- publicEgressByDefault=false.
- runtimeDownloaderImplementation=not-started.
- runtimeEmbeddingImplementation=not-started.
- silentDownloadAllowed=false.

## Guard Fixture

docs/qa/fixtures/v3/knowledge-index-chunk/invalid/model-acquisition-silent-download.json must remain invalid. It represents the forbidden drift where BGE-m3 is bundled or downloaded silently, public egress is allowed by default, and runtime downloader/embedding implementation appears started before the W3 runtime gate.

## Runtime Boundary

This is a contract-only lock. It does not authorize changes under ai/source, officecfg, installer packaging, or any runtime download hook.
