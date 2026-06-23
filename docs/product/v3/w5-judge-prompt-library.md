# V3 W5 Judge Prompt Library

Status: **contract-only / opt-in / runtime not started** (2026-06-10)

This file locks the prompt metadata for future V3 W5 LLM-judge scoring.
It does not start model judging, provider calls, release gating, or report
publication.

## Policy

- LLM judge is **opt-in** per future release report; H9 capability fixtures keep `llmJudgePolicy.enabled=false`.
- LLM judge is **not** a default release gate while V3 runtime scoring is not started.
- Deterministic parameters are locked as `temperature=0`, `topP=1`, and `seedRequired=true`.
- Any externally publishable LLM-judge result requires human review.
- Runtime judge implementation remains `not-started`.
- Public egress is not allowed by this contract.

## Prompt `judge-v3-capability-v1`

| Field | Value |
|---|---|
| Prompt id | `judge-v3-capability-v1` |
| Version | `v1` |
| Intended use | Capability eval tie-breaker only |
| Default release gate | `false` |
| Requires human review for publish | `true` |
| Runtime implementation | `not-started` |

### Deterministic Parameters

| Parameter | Value |
|---|---|
| `temperature` | `0` |
| `topP` | `1` |
| `seedRequired` | `true` |

### Prompt Template

```text
You are judging whether a proposed office-document patch satisfies the
fixture expectation. Use only the fixture metadata, expected patch
description, and diff summary provided by the harness. Do not infer hidden
document content. Return a JSON object with score, rationale, and blocking
issues. Score 1.0 means the expected user-visible change is satisfied and
undo/evidence requirements are preserved.
```

### Output Contract

```json
{
  "score": 0.0,
  "rationale": "short deterministic explanation",
  "blockingIssues": []
}
```

The output contract is documentation only until the LLM-judge runtime is
explicitly authorized.
