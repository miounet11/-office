# Executive Operating Model

Generated: 2026-04-28

## Role Split

Codex is the product-control owner. Codex sets the target, acceptance gate, evidence standard, owner boundary, and stop/go decision.

Clavue is the source-product implementer and technical reviewer. Clavue should execute bounded implementation work, validate it locally, and hand off exact evidence for Codex review.

This split is intentional: Clavue should not be repeatedly interrupted for planning churn, and Codex should not drift into source edits that collide with a Clavue-owned implementation round.

## Current Operating State

- M2-01 through M2-05 are complete.
- M2-06 is evidence-complete for alpha: Workbench static/source/UITest evidence exists, while live assistive-tech checks remain beta blockers.
- M2-07 is accepted as an internal/test-only seed after Clavue added the speaker-notes unsupported diagnostic assertion and `CppunitTest_sd_misc_tests` passed.
- M2-08 alpha P0 wrapper is green after M2-03 and M2-05.
- Codex reviewed Clavue's `sd/` builder patch read-only and recorded the final decision in `docs/product/m2-07-presentation-outline-builder-review.md`.
- Beta blockers remain: validator assets, live accessibility review, representative compatibility matrix, strict source hygiene, service-policy enforcement, and runtime plugin policy.

## Boss-Level Rules

1. One owner per file family per round.
2. Codex owns the product gate; Clavue owns the implementation patch while assigned.
3. A round is not complete because code exists; it is complete only when the evidence report names command, result, changed source surfaces, generated outputs, and known limitations.
4. Do not promote advisory evidence into release claims.
5. Do not start a new feature if the prior owner has not produced a handoff.
6. Do not interrupt a running Clavue build/test unless it is destructive or clearly stuck.
7. Codex can inject session context only as a directive or stop condition, not as constant steering noise.

## Decision Gates

Use these decisions at every handoff:

| Decision | Meaning | Required Evidence |
| --- | --- | --- |
| Keep | Patch advances a target workflow and preserves guardrails. | Targeted test pass plus source-surface list. |
| Revise | Direction is correct, but acceptance is incomplete. | Exact missing assertion or failing behavior. |
| Stop | Patch expands scope, weakens trust, or collides with another owner. | File-family conflict, failing gate, or product-rule violation. |
| Defer | Work is useful but not next bottleneck. | Higher-priority blocker named with owner. |

## Current Product Logic

The product is not an AI toy. It is a China-first office productivity suite where AI and plugins only matter after core trust is proven.

Execution priority:

1. Open/edit/save/reopen/export trust.
2. DOCX/XLSX/PPTX compatibility evidence.
3. Fast and understandable first-use flow.
4. Workbench scenario usefulness and accessibility.
5. Preview-only intelligence with no document mutation.
6. Deterministic PPT builder from normalized model.
7. Service/plugin runtime only after local/offline safety policy.

## Active Clavue Directive

Clavue may continue only in these bounded lanes:

- Wait for a new round packet before expanding `sd/`, Workbench UI, Writer analyzer, provider, plugin runtime, import/export, or PPTX export scope.
- If assigned accessibility beta work, produce live evidence for Tab/Shift+Tab traversal, Enter/Space activation, VoiceOver, high contrast, resize, and missing-template fallback.
- If assigned presentation-builder follow-up, keep it internal/test-only unless Codex explicitly approves UI/provider/export scope.
- Preserve legacy `.uno:SendOutlineToStarImpress`.

## Codex Duties

Codex should:

- Monitor Clavue passively with `bin/clavue-passive-monitor.sh tmp/clavue-passive-monitor.md`.
- Review Clavue handoffs read-only before approving.
- Keep `AUTORESEARCH_EXECUTION_TODOLIST.md`, `AUTORESEARCH_AGENT_COORDINATION_PLAN.md`, review docs, and dashboard output current.
- Keep `bin/v2-p0-gates.sh <round-name>` green after control-plane changes.
- Keep service-mode policy enforced as a blocker before any runtime plugin/provider implementation.

Codex should not:

- Edit `sd/` presentation-builder follow-ups without a new accepted round packet.
- Edit Writer analyzer files unless explicitly assigned a review-fix round.
- Start another long office test while Clavue has an active office build/test.
- Treat generated output as source.

## Next Stop/Go Review

Codex reviewed and accepted Clavue's M2-07 patch against:

- Internal/test-only boundary.
- No legacy Writer-to-Impress mutation.
- Slide count and title/body assertions.
- Deterministic validation diagnostics.
- Speaker notes explicitly reported as unsupported if not implemented.
- No UI/export/provider scope creep.

Current result: keep. M2-07 is accepted as an internal/test-only seed. M2-06 is accepted as alpha evidence with retained live accessibility beta blockers. The next bottleneck is beta hardening, not more M2 feature expansion.
