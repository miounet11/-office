# V3 W6 ShadowDoc Policy

Status: **contract-only / shadow doc runtime not started** (2026-06-10)

This policy resolves W6 Q1 for ShadowDoc compatibility with the V2-W3
Writer apply path. It does not start AgentRuntime, Planner, Actor, Observer,
ShadowDoc, a new DocShell type, source integration, or product runtime
implementation.

## ShadowDoc Compatibility Contract

| Field | Required value |
|---|---|
| Shadow doc mode | per-step-compatible-branch |
| Writer compatibility target | v2-w3-swdocshell |
| Requires existing SwDocShell compatibility | true |
| Creates new DocShell type | false |
| Merge path | v2-apply-plan-runtime |
| Main document mutation before approval | false |
| Merge requires approval | true |
| Runtime shadow doc implementation | not-started |

## Rules

- A future Writer ShadowDoc must remain compatible with the V2-W3 SwDocShell
  ApplyPlan path rather than introducing a new DocShell type in contract-only
  mode.
- Patch steps may write only to a per-step compatible shadow branch until the
  plan reaches an approved merge point.
- The main document must not be mutated before approval.
- Merge back to the main document must go through the V2 ApplyPlan runtime path
  and keep the existing ParagraphAction/CellAction/SlideElementAction token
  locks.
- Contract-only fixtures must not claim an implemented ShadowDoc runtime.

The future W6 runtime may add ShadowDoc storage and merge plumbing only after a
separate implementation gate. Until then, this contract locks compatibility
with V2-W3 SwDocShell and prevents drift toward a new DocShell runtime or
direct main-document mutation.
