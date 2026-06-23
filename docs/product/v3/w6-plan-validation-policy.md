# V3 W6 Plan Validation Policy

Status: **contract-only / planner runtime not started** (2026-06-10)

This policy resolves W6 Q2 for invalid Planner output. It does not start the
Planner, AgentRuntime, LLM calls, retry loop, source integration, or product
runtime implementation.

## Invalid Plan Contract

| Field | Required value |
|---|---|
| Validation phase | `before-execution` |
| On invalid plan | `fail-closed-user-visible` |
| Blocks execution | `true` |
| Auto retry allowed | `false` |
| Auto simplification allowed | `false` |
| User retry allowed | `true` |
| Invalid plan evidence | `required` |
| Runtime planner implementation | `not-started` |

## Rules

- A Planner output must validate against `agent-step-plan.schema.json` before
  any step execution starts.
- Invalid Planner output fails closed and must be visible to the user.
- The contract forbids silent retries and automatic simplification because both
  can hide planner drift and weaken audit evidence.
- A user-visible retry is allowed as a future runtime action, but the retry
  loop is not implemented in contract-only mode.
- Invalid plan evidence is required before a failed plan can be dismissed or
  retried.
