# Clavue Next Upgrade Handoff

Date: 2026-04-29
Owner: Clavue
Controller/reviewer: Codex
Product: 可圈office
Status: further upgrade required before beta

## Current Verdict

可圈office is not beta-ready yet. The current control plane is stronger than before, but the latest beta gate still blocks release-quality claims.

Latest reference report:

- `tmp/v2-beta-gates/clavue-beta-json-sidecar-check-2.md`
- `tmp/v2-beta-gates/clavue-beta-json-sidecar-check-2.json`

Current beta gate status:

| Gate | Status | Meaning |
| --- | --- | --- |
| compatibility-manifest-audit | pass | Smoke manifest is structurally usable. |
| workbench-accessibility-static | pass | Static Workbench accessibility checks pass. |
| gui-smoke-timing-startcenter | pass | Start Center process survival/timing currently passes. |
| compatibility-layout-evidence | pass | Layout-proxy evidence exists, but it is not pixel fidelity. |
| service-policy-enforcement | pass | Plugin manifest self-test passes; runtime readiness is still not proven. |
| validator-readiness-strict | fail | Officeotron and veraPDF assets are missing. |
| compatibility-roundtrip | fail | Strict validator-backed roundtrip is blocked by validator readiness. |
| source-hygiene-strict | fail | Working tree contains source, config, generated, install, and release artifacts. |
| workbench-live-accessibility | fail | Manual live accessibility review is still missing. |

Do not claim beta readiness while any failed beta-hard gate remains.

## Upgrade Priority

The next upgrade should remove blockers in this order:

1. Validator readiness and strict compatibility.
2. Source hygiene classification and release decision packet.
3. Workbench live accessibility evidence.
4. Final beta gate rerun and JSON/Markdown evidence review.

Do not start new product features, AI features, UI redesign, import/export engine changes, or service/plugin runtime work until these blockers are controlled.

## Clavue Assignment: M2-10 Validator Readiness Upgrade

### Objective

Make `validator-readiness-strict` actionable and, if trusted assets can be obtained, move it toward pass without faking validator readiness.

### Owned Write Scope

Clavue may edit only:

- `docs/compatibility/validator-assets-release-packet.md`
- `bin/validator-readiness.sh`
- `bin/officeotron.sh`
- `bin/verapdf.sh`
- `tmp/validator-readiness*.md`
- `tmp/v2-beta-gates/clavue-m2-10-*`

Clavue may place validator assets only in:

- `/Users/lu/kdoffice-src/external/tarballs`

### Non-Goals

- Do not edit import/export engines.
- Do not edit Workbench UI or UITest files.
- Do not edit `sw/`, `sc/`, `sd/`, `oox/`, `filter/`, or `xmloff/`.
- Do not use arbitrary mirror, blog, forum, or unauthenticated binary downloads.
- Do not rename required assets unless every wrapper, readiness script, and release packet is updated together.

### Required Evidence

For each validator asset:

- Source URL.
- Download method.
- Filename.
- File size.
- SHA-256.
- Upstream checksum or explicit statement that no upstream checksum was available.
- License / redistribution note.
- Wrapper smoke command and result.

Current missing assets:

- `officeotron-0.8.8.jar`
- `verapdf-cli-1.29.0.jar`

Current ready asset:

- `odfvalidator-0.13.0-jar-with-dependencies.jar`

### Verification Commands

Run:

```sh
bin/validator-readiness.sh tmp/validator-readiness.md
bin/validator-readiness.sh --strict tmp/validator-readiness-strict.md
bin/v2-beta-gates.sh clavue-m2-10-validator-readiness
```

Expected result:

- If assets remain unavailable from trusted sources, `validator-readiness-strict` must continue to fail honestly.
- If all assets are present, trusted, and wrapper-smoked, strict validator readiness may pass.
- The beta gate may still fail on source hygiene and live accessibility.

### Stop Rules

Stop and report `Blocked` before:

- Using untrusted validator binaries.
- Modifying product source to bypass validator checks.
- Marking missing validators as pass.
- Editing compatibility engines without a separate packet.
- Deleting generated outputs or resetting the working tree.

## Clavue Assignment: M2-11 Source Hygiene Upgrade

Start only after M2-10 returns.

### Objective

Turn `source-hygiene-strict` from a broad dirty-tree failure into an actionable release decision list.

### Owned Write Scope

Clavue may edit only:

- `docs/product/source-hygiene-release-packet.md`
- `tmp/source-hygiene-report*.md`
- Optional: `docs/product/clavue-next-upgrade-handoff.md` status section

### Required Evidence

Classify entries into:

- Intentional source/control files to keep.
- Generated/local outputs to preserve as evidence.
- Config/autoconf artifacts requiring operator decision.
- Install/test/release artifacts requiring operator decision.
- Untracked files requiring explicit human staging/cleanup decision.

Do not delete, reset, clean, or stage files.

### Verification Commands

Run:

```sh
bin/source-hygiene-report.sh tmp/source-hygiene-report.md
bin/source-hygiene-report.sh --strict tmp/source-hygiene-report-strict.md
```

Expected result:

- Strict mode may still fail.
- The improvement is an explicit release decision list, not forced cleanliness.

## Clavue Assignment: M2-12 Live Accessibility Upgrade

Start only after M2-10 and M2-11 return, unless a manual macOS accessibility operator is immediately available.

### Objective

Close or reduce the `workbench-live-accessibility` blocker with real live evidence.

### Required Live Checks

Record evidence for:

- Tab traversal.
- Shift+Tab traversal.
- Enter activation.
- Space activation.
- VoiceOver Chinese labels, grouping, order, and intent.
- High/increased contrast visibility.
- Narrow and short resize reachability.
- Missing-template fallback warning and focus movement.

### Owned Write Scope

Clavue may edit only:

- `docs/accessibility/workbench-live-accessibility-review.md`
- `docs/accessibility/workbench-accessibility-evidence-m2-06.md`
- `tmp/workbench-accessibility*.md`

### Stop Rules

Stop and report `Blocked` if:

- No live macOS GUI/VoiceOver operator is available.
- Evidence is only static or UITest-based.
- Keyboard activation cannot be observed directly.
- Any failure is found that requires product source edits; that needs a separate implementation packet.

## Final Regression Gate

After M2-10, M2-11, and M2-12:

```sh
bin/v2-beta-gates.sh clavue-final-beta-readiness
```

Required final output:

- Markdown report path.
- JSON report path.
- Failed blocker list.
- Claim decision: `beta-ready` or `not-beta-ready`.

Beta readiness can only be claimed if:

- `validator-readiness-strict` passes.
- `compatibility-roundtrip` passes with strict validators.
- `source-hygiene-strict` passes or has an approved release exception.
- `workbench-live-accessibility` has live evidence and is accepted by Codex review.

## Return Format For Each Clavue Round

Clavue must return:

- Verdict: `Keep`, `Revise`, or `Blocked`.
- Changed files.
- Commands run and exact results.
- Evidence report paths.
- Remaining blockers.
- Stop-rule concerns.

No commit, tag, push, cleanup, or broad feature work is allowed in these packets.
