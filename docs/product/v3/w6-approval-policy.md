# V3 W6 Approval Policy

Status: **contract-only / approval UI runtime not started** (2026-06-10)

This policy resolves W6 Q3 for agent-step approval UX. It does not start the
AgentRuntime, Planner, Actor, Observer, ShadowDoc, approval UI, source
integration, or product runtime implementation.

## Approval UX Contract

| Field | Required value |
|---|---|
| Default mode | `whole-task` |
| Per-step mode source | `explicit-user-choice` |
| Per-step requires explicit user choice | `true` |
| Implicit per-step prompts allowed | `false` |
| Whole-task prompt strategy | `final-review-only` |
| Per-step prompt strategy | `explicit-per-step-review` |
| Review step required | `true` |
| Approval evidence | `user-approval` |
| Runtime approval UI implementation | `not-started` |

## Rules

- Whole-task approval is the default because long W6 tasks should not interrupt
  the user at every step.
- Per-step approval is allowed only when the user explicitly chooses it before
  the plan is accepted.
- A Planner must not select per-step approval implicitly or because a task has
  many steps.
- Every valid plan still needs a review step that emits `user-approval`
  evidence before merge.
- Contract-only fixtures must not claim an implemented approval UI runtime.

The future W6 runtime may add the approval UI after a separate implementation
gate. Until then, the contract locks the UX decision and prevents silent drift
toward noisy per-step prompts.
