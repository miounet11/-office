# V3 W6 Dependency Policy

Status: **contract-only / runtime scheduler not started** (2026-06-10)

This policy resolves W6 Q4 for agent step dependencies. It does not start the
AgentRuntime, Planner, Actor, Observer, ShadowDoc, scheduler parallelism, or any
source-level integration.

## Dependency Graph Contract

| Field | Required value |
|---|---|
| Graph type | `forward-only-dag` |
| Execution order | `topological-index` |
| Allows fan-in | `true` |
| Allows fan-out | `true` |
| Allows cycles | `false` |
| Allows future dependencies | `false` |
| Allows parallel runtime | `false` |
| Runtime scheduler implementation | `not-started` |

## Rules

- A step may depend only on earlier step indexes.
- Multiple dependencies are allowed for fan-in.
- Multiple later steps may depend on the same earlier step for fan-out.
- The serialized plan remains index-topological even when the logical graph is
  a DAG.
- Contract-only fixtures must not claim runtime parallel execution.

The future W6 scheduler may choose to execute independent branches in parallel
only after a separate runtime implementation gate. Until then, the contract
locks dependency shape and prevents circular or future-index drift.
