# V3 W6 Resume Policy

Status: **contract-only / resume runtime not started** (2026-06-10)

This policy resolves W6 Q5 for cross-session agent task resume. It does not
start AgentRuntime persistence, resume runtime, ShadowDoc serialization, source
integration, or product runtime implementation.

## Cross-Session Resume Contract

| Field | Required value |
|---|---|
| Cross-session resume allowed | `true` |
| Resume point | `evidence-complete-checkpoint` |
| Requires user confirmation | `true` |
| Requires document hash match | `true` |
| Requires shadow snapshot | `true` |
| Requires audit replay | `true` |
| Auto resume allowed | `false` |
| Stale checkpoint behavior | `fail-closed-user-visible` |
| Checkpoint evidence | `required` |
| Runtime resume implementation | `not-started` |

## Rules

- A W6 task may be resumed after app restart only from an evidence-complete
  checkpoint.
- Resume must be user-confirmed; reopening the app must not automatically
  continue agent execution.
- The current document hash must match the checkpoint. Stale or mismatched
  checkpoints fail closed and must be visible to the user.
- A checkpoint must include a shadow document snapshot and audit replay inputs
  before any future runtime can continue the task.
- Contract-only fixtures must not claim implemented resume persistence or
  runtime resume execution.

The future W6 runtime may add checkpoint persistence after a separate
implementation gate. Until then, the contract locks the resume safety decision
and prevents silent continuation after app restart.
