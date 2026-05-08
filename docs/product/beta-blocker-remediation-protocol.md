# M2-08 Beta Blocker Remediation Protocol

This protocol tracks the current M2-08 beta gate blockers. It does not claim beta readiness.

## Current blocker list

1. `compatibility-roundtrip` fails under strict validators.
2. `validator-readiness-strict` is missing Officeotron and veraPDF validator assets/evidence.
3. `gui-smoke-timing-startcenter` fails start center survival/abort diagnostics.
4. `source-hygiene-strict` reports dirty/generated tree blockers.
5. `workbench-live-accessibility` remains a manual beta-hard blocker.

Passing static workbench accessibility, compatibility manifest audit, layout evidence, and service-policy enforcement remain useful evidence, but they do not clear the blockers above.

## Owner lanes

- **Validator lane**: acquire approved Officeotron and veraPDF assets, record provenance and checksums, smoke the wrappers, then rerun strict validator readiness and strict compatibility roundtrip.
- **GUI survival lane**: use `bin/gui-smoke-timing.sh` reports to capture pid, exit status/classification, and bounded soffice log tail before changing launch/runtime behavior.
- **Source hygiene lane**: classify dirty files into source review, generated/local cleanup, config/autoconf, install/test/release, and human-decision buckets. Do not delete or reset unrelated generated outputs as a shortcut.
- **Live accessibility lane**: complete live Tab/Shift+Tab, Enter/Space, VoiceOver, high-contrast, resize, and missing-template fallback review.
- **Gate controller lane**: rerun `bin/v2-beta-gates.sh` after each lane produces evidence and preserve the generated report/log paths.

## Evidence required

- `tmp/validator-readiness-strict.md` with all required validators present, versioned, checksummed, and wrapper-smoked.
- Strict compatibility roundtrip report/logs under `tmp/compatibility-roundtrip/` showing validator-backed pass evidence.
- `tmp/gui-smoke-timing/<run-name>/report.md` with process id, exit status, exit classification, elapsed timing, and a bounded soffice log tail.
- `tmp/source-hygiene-report-strict.md` plus release-packet decisions for remaining dirty/generated files.
- A live accessibility evidence packet covering keyboard traversal, activation, VoiceOver, high contrast, resize behavior, and missing-template fallback.
- A final `tmp/v2-beta-gates/<run-name>.md` report with every beta-hard blocker passing.

## Stop rules

Stop and escalate before claiming readiness if any of these are true:

- Officeotron or veraPDF assets are unavailable, unverified, or not wrapper-smoked.
- Live accessibility evidence is missing or only static checks have passed.
- GUI smoke exits before the wait window and the report lacks actionable process/log evidence.
- Source hygiene requires deleting, resetting, or reverting unrelated local/generated outputs.
- Any remediation would require editing core LibreOffice source outside the owned M2-08 scope.
- Any beta-hard gate still fails, even if the failure is expected during alpha iteration.
