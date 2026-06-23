# V3 W3 Watcher Scalability Policy

Status: **active contract** (2026-06-11; no watcher runtime implementation started)

This policy resolves W3 Q3 for the contract layer: large workspaces must not exhaust file descriptors or inode watcher limits before the gated W3 watcher runtime exists.

## Decision

| Field | Locked value |
|---|---|
| `trigger` | `background-watcher` |
| `debounceMs` | `5000` |
| `largeWorkspaceThresholdFiles` | `10000` |
| `largeWorkspaceStrategy` | `bounded-watch-plus-polling-fallback` |
| `perFileDescriptorWatch` | `false` |
| `maxOpenFileDescriptors` | `256` |
| `pollingFallbackIntervalSeconds` | `60` |
| `overflowBehavior` | `fail-closed-user-visible` |
| `runtimeWatcherImplementation` | `not-started` |

The default update trigger remains a background watcher with a 5 second debounce, but the contract forbids one file descriptor per indexed file. Workspaces above 10,000 files must use a bounded watcher plus polling fallback strategy, capped at 256 open file descriptors, and must surface overflow as a user-visible fail-closed state instead of silently dropping changes.

## Guard Fixture

`docs/qa/fixtures/v3/knowledge-index-chunk/invalid/watcher-per-file-fd-runtime.json` must remain invalid. It represents the forbidden drift where the watcher claims per-file descriptors, disables debounce/fallback, raises the file descriptor budget to the size of a large workspace, silently drops overflow, and starts runtime watcher implementation before the W3 gate.

## Runtime Boundary

This document does not authorize `ai/source/knowledge/Watcher.cxx`, OS-specific FSEvents/inotify/ReadDirectoryChangesW code, polling workers, index scheduling runtime, source integration, or product UI. Those remain future gated runtime work after V2 GA and explicit user authorization.
