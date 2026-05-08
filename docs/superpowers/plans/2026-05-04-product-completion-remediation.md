# Product Completion Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the known gaps that currently keep 可圈office at controlled Alpha Preview status and move it toward an evidence-backed beta candidate.

**Architecture:** Treat product completion as release-gate remediation, not one broad feature patch. Each lane owns one blocker class, produces a machine-readable or human-reviewable evidence artifact under `tmp/`, and updates the release packet only after verification. Source changes are allowed only when a gate identifies a concrete defect with file/control/sample evidence.

**Tech Stack:** LibreOffice/gbuild tree, shell gate scripts under `bin/`, product docs under `docs/product/`, release evidence under `tmp/`, macOS app bundle checks, Java validator wrappers, and compatibility manifests under `docs/compatibility/`.

---

## Current Baseline

The product is not complete. Current evidence supports controlled Alpha Preview only.

Known blockers:

- Strict source hygiene is blocked by a very dirty tree with generated/install artifacts and unreviewed source-focused entries.
- Packaged-app screenshots are missing for Start Center, Writer, Calc, Impress, Draw, and selected dialogs.
- Live accessibility evidence is incomplete.
- Strict validator readiness fails because Officeotron and veraPDF assets are missing.
- Compatibility evidence is narrow conversion smoke, not representative Microsoft Office/WPS visual fidelity proof.
- PDF evidence is not sufficient for export, font, page-count, bookmark, or PDF/A claims.
- macOS signing/notarization and Windows signing are not complete.
- AI/provider/plugin/runtime features are not production-ready and must remain blocked from marketing claims.

Authoritative evidence files:

- `tmp/release-alpha1-packet-index.md`
- `tmp/release-alpha1-checklist-review.md`
- `tmp/release-alpha1-blocker-refresh.md`
- `tmp/release-alpha1-artifacts.md`
- `tmp/release-alpha1-screenshot-evidence.md`
- `tmp/source-hygiene-report-refresh.md`
- `tmp/validator-readiness-strict-refresh.md`

## File Map

- Modify: `docs/superpowers/plans/2026-05-04-product-completion-remediation.md`  
  Owns this executable remediation plan.
- Modify: `tmp/product-completion/source-hygiene-closeout.md`  
  Records reviewed source-focused files, generated/local cleanup decisions, and branch/tag eligibility.
- Modify: `tmp/product-completion/packaged-ui-proof.md`  
  Records screenshot coverage, remaining visible English, and manual UI defects.
- Modify: `tmp/product-completion/live-accessibility-proof.md`  
  Records keyboard, VoiceOver, high-contrast, resize, and fallback findings.
- Modify: `tmp/product-completion/validator-readiness-closeout.md`  
  Records strict validator asset provenance, checksums, wrapper smoke, and unresolved blockers.
- Modify: `tmp/product-completion/compatibility-proof.md`  
  Records DOCX/XLSX/PPTX/PDF corpus coverage, visual/layout proof, skipped validators, and regressions.
- Modify: `tmp/product-completion/signing-release-proof.md`  
  Records macOS/Windows signing, notarization, hashes, installer smoke, and download verification.
- Modify: `tmp/product-completion/beta-readiness-decision.md`  
  Final gate summary: alpha, beta candidate, or blocked.

Create the `tmp/product-completion/` directory before writing evidence.

## Task 1: Source Hygiene Closeout

**Files:**
- Create/modify: `tmp/product-completion/source-hygiene-closeout.md`
- Read: `tmp/source-hygiene-report-refresh.md`
- Read: `tmp/release-alpha1-source-classification.md`

- [ ] **Step 1: Refresh source hygiene report**

Run:

```bash
bin/source-hygiene-report.sh tmp/product-completion/source-hygiene-report.md
```

Expected:

```text
Status: advisory
```

- [ ] **Step 2: Classify source-focused entries**

Write `tmp/product-completion/source-hygiene-closeout.md` with this exact structure:

```markdown
# Source Hygiene Closeout

## Verdict

- Status: blocked
- Branch/tag eligible: no

## Reviewed Source-Focused Entries

| Path | Category | Decision | Reason |
| --- | --- | --- | --- |

## Generated/Local Entries

| Bucket | Decision | Cleanup command allowed? | Reason |
| --- | --- | --- | --- |

## Human-Decision Items

| Path | Required owner decision |
| --- | --- |

## Stop Conditions

- Do not delete or reset generated/install artifacts until source-focused entries are reviewed.
- Do not create release branch or tag while this file says `Branch/tag eligible: no`.
```

- [ ] **Step 3: Verify no release branch/tag claim exists**

Run:

```bash
rg -n "branch/tag eligible: yes|beta-ready|stable-ready|world-class" tmp/product-completion tmp/release-alpha1-*.md docs/product
```

Expected: no unqualified beta/stable/world-class claim. If matches are legitimate blocked/excluded claims, record them in the closeout.

## Task 2: Packaged UI Proof

**Files:**
- Create/modify: `tmp/product-completion/packaged-ui-proof.md`
- Read: `tmp/release-alpha1-screenshot-evidence.md`

- [ ] **Step 1: Confirm runnable app path**

Run:

```bash
test -x '/Users/lu/kdoffice-src/test-install/可圈office.app/Contents/MacOS/soffice'
```

Expected: exit code `0`. If missing, run the unsigned alpha test-install command recorded in `tmp/release-alpha1-artifacts.md`.

- [ ] **Step 2: Capture required surfaces**

Manual or automated screenshots must cover:

```text
Start Center
Writer blank document
Calc blank spreadsheet
Impress blank presentation
Draw blank drawing
Calc Standard Filter
Calc Advanced Filter
Selected localized shared dialogs
```

Store screenshots under:

```text
tmp/product-completion/screenshots/
```

- [ ] **Step 3: Record visible-English classification**

Write `tmp/product-completion/packaged-ui-proof.md` with this exact structure:

```markdown
# Packaged UI Proof

## Verdict

- Status: blocked
- Full Chinese UI claim allowed: no

## Screenshot Inventory

| Surface | Screenshot path | Status | Notes |
| --- | --- | --- | --- |

## Remaining Visible English

| Surface | Text | Category | Decision |
| --- | --- | --- | --- |

## Categories

- Technical term
- Real font name
- Identifier/internal
- Fixture/test-only
- Stock button deferred
- Unresolved visible defect

## Required Fix Packets

| Packet | Source file | Defect | Verification |
| --- | --- | --- | --- |
```

Only change `Status` to `pass` and `Full Chinese UI claim allowed: yes` after every unresolved visible defect is fixed or accepted with a documented reason.

## Task 3: Live Accessibility Proof

**Files:**
- Create/modify: `tmp/product-completion/live-accessibility-proof.md`
- Read: `docs/accessibility/workbench-accessibility-checklist.md`
- Read: `docs/accessibility/workbench-live-accessibility-review.md`

- [ ] **Step 1: Run static accessibility helper**

Run:

```bash
bin/workbench-accessibility-check.sh
```

Expected: pass or a concrete file/control failure.

- [ ] **Step 2: Perform live accessibility matrix**

Check these surfaces:

```text
Start Center
Writer blank document
Calc filters
Impress new presentation
Draw blank drawing
Template/workbench fallback state
```

For each surface, test:

```text
Tab
Shift+Tab
Enter
Space
VoiceOver label
High contrast/theme behavior
Resize/narrow window behavior
```

- [ ] **Step 3: Record accessibility defects**

Write `tmp/product-completion/live-accessibility-proof.md` with this exact structure:

```markdown
# Live Accessibility Proof

## Verdict

- Status: blocked
- Accessibility claim allowed: no

## Matrix

| Surface | Keyboard | VoiceOver | High contrast | Resize | Status |
| --- | --- | --- | --- | --- | --- |

## Defects

| Surface | File/control | Failure | Severity | Required fix packet |
| --- | --- | --- | --- | --- |

## Deferred Items

| Item | Reason | Owner decision |
| --- | --- | --- |
```

## Task 4: Strict Validator Readiness

**Files:**
- Create/modify: `tmp/product-completion/validator-readiness-closeout.md`
- Read: `tmp/validator-readiness-strict-refresh.md`
- Read: `docs/compatibility/validator-assets-release-packet.md`

- [ ] **Step 1: Run strict readiness**

Run:

```bash
bin/validator-readiness.sh --strict tmp/product-completion/validator-readiness-strict.md
```

Expected today: fail until exact Officeotron and veraPDF assets are present and trusted.

- [ ] **Step 2: Acquire only trusted assets**

Required filenames:

```text
officeotron-0.8.8.jar
verapdf-cli-1.29.0.jar
```

For each acquired asset, record:

```text
Source URL
Download method
Filename
File size
SHA-256
Upstream checksum status
License/redistribution note
Wrapper smoke command and result
```

- [ ] **Step 3: Record closeout**

Write `tmp/product-completion/validator-readiness-closeout.md` with this exact structure:

```markdown
# Validator Readiness Closeout

## Verdict

- Status: blocked
- Strict validator gate: fail

## Validators

| Validator | Asset | SHA-256 | Trust status | Wrapper smoke | Decision |
| --- | --- | --- | --- | --- | --- |

## Blockers

| Validator | Blocker | Next action |
| --- | --- | --- |

## Rule

Skipped validators and classified validator failures are not compatibility quality passes.
```

## Task 5: Compatibility And PDF Proof

**Files:**
- Create/modify: `tmp/product-completion/compatibility-proof.md`
- Modify only if needed: `docs/compatibility/smoke-manifest.tsv`
- Read: `docs/compatibility/corpus-expansion-plan.md`

- [ ] **Step 1: Run current smoke manifest**

Run:

```bash
bin/compatibility-roundtrip.sh --manifest docs/compatibility/smoke-manifest.tsv --run-name product-completion-baseline
```

Expected: conversion results recorded under `tmp/compatibility-runs/product-completion-baseline/`.

- [ ] **Step 2: Expand representative corpus**

Add samples only when license/provenance allows testing use. Required lanes:

```text
DOCX report with headings/tables/images/comments
DOCX tracked changes
XLSX formulas/charts/conditional formatting/filter/print area
PPTX theme/text boxes/grouped shapes/charts
PDF export from Chinese Writer document
PDF export from spreadsheet print area
PDF export from presentation
```

- [ ] **Step 3: Add visual/layout evidence**

For each representative sample, record:

```text
Input path
Output path
Screenshots or rendered PDF path
Page/slide/sheet count
Known fidelity issues
Validator status
Pass/fail decision
```

- [ ] **Step 4: Record compatibility proof**

Write `tmp/product-completion/compatibility-proof.md` with this exact structure:

```markdown
# Compatibility And PDF Proof

## Verdict

- Status: blocked
- Full Microsoft Office/WPS compatibility claim allowed: no
- PDF trust claim allowed: no

## Corpus

| Lane | Sample count | Visual evidence | Validator evidence | Status |
| --- | ---: | --- | --- | --- |

## Failures

| Sample | Failure | Severity | Source area | Required fix packet |
| --- | --- | --- | --- | --- |

## Skipped Validators

| Validator | Reason | Release impact |
| --- | --- | --- |
```

## Task 6: Signing, Notarization, And Installer Proof

**Files:**
- Create/modify: `tmp/product-completion/signing-release-proof.md`
- Read: `tmp/release-alpha1-artifacts.md`
- Read: `.github/workflows/build-installers.yml`

- [ ] **Step 1: Reproduce current macOS packaging split**

Run the configured path:

```bash
gmake -C /Users/lu/kdoffice-src test-install
```

Expected today: fails if signing identity is still unavailable.

Run the alpha unsigned override only for alpha evidence:

```bash
gmake -C /Users/lu/kdoffice-src MACOSX_CODESIGNING_IDENTITY= test-install
```

Expected: pass if build state remains healthy.

- [ ] **Step 2: Close signing path**

Do not change signing scripts until the root cause is confirmed. Required evidence:

```text
Configured signing identity
Keychain availability
codesign verification
spctl assessment
notarization submission result
stapler result
DMG/package hash
Install/open smoke result
```

- [ ] **Step 3: Record installer proof**

Write `tmp/product-completion/signing-release-proof.md` with this exact structure:

```markdown
# Signing And Installer Proof

## Verdict

- Status: blocked
- Signed macOS claim allowed: no
- Notarized macOS claim allowed: no
- Signed Windows claim allowed: no

## macOS

| Artifact | Signed | Notarized | SHA-256 | Install smoke | Decision |
| --- | --- | --- | --- | --- | --- |

## Windows

| Artifact | Signed | SHA-256 | Install smoke | Decision |
| --- | --- | --- | --- | --- |

## Blockers

| Platform | Blocker | Required fix |
| --- | --- | --- |
```

## Task 7: Beta Readiness Decision

**Files:**
- Create/modify: `tmp/product-completion/beta-readiness-decision.md`
- Read all `tmp/product-completion/*.md`

- [ ] **Step 1: Read every closeout file**

Run:

```bash
ls tmp/product-completion/*.md
```

Expected: closeout files exist for source hygiene, packaged UI, accessibility, validators, compatibility/PDF, and signing.

- [ ] **Step 2: Make the decision**

Write `tmp/product-completion/beta-readiness-decision.md` with this exact structure:

```markdown
# Beta Readiness Decision

## Decision

- Product status: Alpha Preview
- Beta candidate allowed: no
- Stable/public release allowed: no

## Gate Summary

| Gate | Status | Evidence file | Release impact |
| --- | --- | --- | --- |

## Claims Allowed

| Claim | Allowed? | Reason |
| --- | --- | --- |
| Controlled alpha preview | yes | Evidence packet exists with blockers disclosed. |
| Beta-ready | no | Blockers remain. |
| Stable/public release-ready | no | Blockers remain. |
| Full Chinese UI | no | Packaged proof and remaining defects not closed. |
| Full Microsoft Office/WPS compatibility | no | Representative visual/layout proof not closed. |
| Full accessibility | no | Live evidence not closed. |
| Signed/notarized installer | no | Signing proof not closed. |

## Next Fix Packet

| Priority | Packet | Owner | Stop condition |
| --- | --- | --- | --- |
```

Only change `Beta candidate allowed` to `yes` after every hard gate is `pass` and no excluded claim remains unsupported.

## Execution Order

1. Task 1: Source hygiene closeout.
2. Task 2: Packaged UI proof.
3. Task 3: Live accessibility proof.
4. Task 4: Strict validator readiness.
5. Task 5: Compatibility and PDF proof.
6. Task 6: Signing and installer proof.
7. Task 7: Beta readiness decision.

## First Recommended Fix Packet

Start with Task 1. It is the highest-leverage blocker because no branch, tag, public release, or cleanup decision is safe until the dirty tree is classified. It also avoids touching product behavior before evidence ownership is clear.

## Self-Review

- Spec coverage: The plan covers all known blocker groups from the current release packet.
- Placeholder scan: No `TBD`, `TODO`, or undefined future implementation placeholder is used.
- Type/path consistency: All evidence paths live under `tmp/product-completion/`; release evidence references match existing packet names.
