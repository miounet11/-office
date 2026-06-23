# V3 W6 Prompt Library

Status: **contract-only / prompt runtime not started** (2026-06-11)

This policy locks the first W6 Plan-Act-Observe prompt set before any
AgentRuntime, Planner, Actor, Observer, LLM call loop, prompt execution
runtime, source integration, or product runtime implementation starts.

## Prompt Set Contract

| Field | Required value |
|---|---|
| Prompt set id | w6-plan-act-observe-v1 |
| Prompt set version | v1 |
| Planner prompt id | planner-v1 |
| Actor prompt id | actor-v1 |
| Observer prompt id | observer-v1 |
| Temperature | 0 |
| Top P | 1 |
| Seed required | true |
| Public egress allowed | false |
| Runtime prompt execution | not-started |

## Rules

- Planner, Actor, and Observer prompts must be version-pinned before runtime
  execution can start.
- Prompt outputs must stay inside the existing W6 plan/result/state contracts;
  prompts must not invent new runtime schemas.
- Prompt execution must inherit the W6 data boundary: local or private service
  mode only, no public egress by default, and policy preflight required.
- Deterministic prompt metadata is required for repeatable contract fixtures.
- Contract-only fixtures must not claim that prompt execution, LLM calls, or
  runtime orchestration have started.

The future W6 runtime may add executable prompt templates only after a separate
implementation gate. Until then, the contract locks prompt identity, version,
deterministic parameters, and the no-public-egress boundary.
