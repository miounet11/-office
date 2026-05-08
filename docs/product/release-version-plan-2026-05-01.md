# New Version Release Plan

Date: 2026-05-01
Product: 可圈office
Current source base version: `26.8.0.0.alpha0+`
Current source branch: `/Users/lu/kdoffice-src` `master`
Current source commit observed: `75333b0de`
Release controller: Codex
Implementation/build owner: Clavue
Verdict: prepare an alpha preview candidate only; do not publish as beta/stable yet.

## 1. Release Positioning

The next version must be positioned as an internal or controlled alpha preview. It can be packaged for testing, screenshots, localization validation, and stakeholder review, but it must not be marketed as beta, stable, release-ready, or world-class.

Reason:

- Localization source/build evidence is strong through `L10N-37`, but packaged-app screenshot proof is not complete.
- `source-hygiene-strict` remains failed because the tree contains large dirty/generated/local artifacts and many intentional source changes that are not yet release-classified.
- `validator-readiness-strict` remains failed because Officeotron and veraPDF assets are missing, and ODF Validator reports `failed:extension-namespace` findings on generated intermediate ODF files.
- `workbench-live-accessibility` remains failed because live keyboard, VoiceOver, high-contrast, resize, and fallback evidence are incomplete.
- Compatibility evidence has useful smoke/layout records, but true representative Chinese visual comparison is still too narrow.
- Current macOS/Windows installer workflow creates unsigned artifacts; signing, notarization, and download validation are not closed.

Release label:

```text
可圈office 26.8 Alpha Preview 1
```

Recommended technical tag after the release branch is clean:

```text
kqoffice-v26.8.0-alpha.1
```

Recommended human-facing artifact naming:

```text
KQOffice-26.8.0-alpha.1-macos-unsigned.dmg
KQOffice-26.8.0-alpha.1-windows-unsigned.msi
```

This is naming guidance for planned release artifacts. Current macOS build output may still emit a source-version filename such as `可圈office_26.8.0.0.alpha0_MacOS_aarch64.dmg`; record that exact generated filename, hash, and unsigned status when it is the evidence artifact rather than renaming it silently. Do not imply a Windows artifact exists unless one is actually produced.

Do not create a tag from the current dirty tree. Tag only after source classification, build evidence, and release notes are complete.

## 2. Release Tracks

Use three explicit tracks so the team does not confuse packaging with readiness.

| Track | Purpose | Allowed audience | Required status |
| --- | --- | --- | --- |
| Alpha Preview | Internal testing, screenshots, Clavue/Codex verification, selected trusted users | Internal and controlled testers | Module builds and smoke evidence pass; blockers disclosed. |
| Beta Candidate | Wider testing with beta-quality claims | External beta users | All beta-hard gates pass. |
| Stable Release | Public download and promotion | Public users | Beta gates pass, packaging/signing/notarization pass, release artifacts are reproducible and verified. |

Current target: `Alpha Preview`.

Blocked targets: `Beta Candidate`, `Stable Release`.

## 3. Alpha Preview 1 Scope

Alpha Preview 1 should package the current product improvements while explicitly documenting known limits.

Include:

- Current 可圈office branding and application naming.
- Workbench/start-center improvements already implemented.
- Chinese templates and default-document improvements already implemented.
- Localization improvements through `L10N-37`.
- Calc filter localization through Standard Filter and Advanced Filter.
- Writer, Calc, Impress, Draw, SFX2, CUI localized surfaces already proven by checkers.
- Existing compatibility smoke/layout evidence.
- Existing plugin/service-mode policy gates.
- Existing Writer analyzer and Impress outline builder only as preview/internal capability evidence, not as promoted user-facing stable AI features.

Exclude from release claims:

- "All UI is Chinese."
- "Beta ready."
- "Stable/release ready."
- "Fully compatible with Word/WPS/Microsoft Office."
- "Fully accessible."
- "AI office assistant ready."
- "Signed/notarized production installer."

## 4. Release Branch And Version Policy

Recommended branch:

```text
release/kqoffice-26.8-alpha.1
```

Branch creation is blocked until Codex reviews source hygiene classification. The current dirty tree has too many unrelated categories to branch blindly.

Version policy:

- Keep upstream-compatible numeric base: `26.8.0.0`.
- Use product-facing label: `26.8 Alpha Preview 1`.
- Use Git tag: `kqoffice-v26.8.0-alpha.1`.
- Do not change `configure.ac` until the release operator confirms whether `26.8.0.0.alpha0+` should remain or become a downstream suffix.
- If changing `configure.ac`, use a suffix compatible with the LibreOffice version parser: no spaces or extra periods inside the free-form suffix.

Candidate acceptable source suffix examples:

```text
26.8.0.0.alpha1+
26.8.0.0.kqalpha1+
```

Avoid:

```text
26.8.0.0.alpha.preview.1
26.8.0.0 Alpha Preview 1
```

## 5. Clavue Release Preparation Packet

Clavue should not start with packaging. Clavue should first close or document the minimum release evidence.

### Packet R1: Source Classification

Goal: separate release source from generated/local artifacts.

Actions:

- Generate `tmp/source-hygiene-report.md`.
- Classify dirty files into source edits, branding/icons, templates, generated build output, config/autoconf, install/test artifacts, release artifacts, and human-decision items.
- Do not delete, reset, clean, or stage unrelated files.
- Produce `tmp/release-alpha1-source-classification.md`.

Required command:

```sh
bin/source-hygiene-report.sh tmp/source-hygiene-report.md
```

Stop if any file looks credential-like, externally supplied, user-authored, or unrelated to the release.

### Packet R2: Localization Gate Refresh

Goal: prove the release candidate includes localization evidence through the latest lane.

Actions:

- Run all existing `L10N` checkers through `L10N-37`.
- If Clavue adds any later `L10N` lane before packaging, include it only after its focused checker, accumulated sweep, XML parse, and relevant `gmake` module build pass.
- Produce `tmp/release-alpha1-localization-gates.md`.

Required command:

```sh
for f in /Users/lu/可点office/tmp/localization-sweep/check-l10n-*.py; do python3 "$f" || exit 1; done
```

### Packet R3: Build And Smoke Baseline

Goal: prove the candidate can build and launch before installer packaging.

Actions:

- Run relevant module builds after the latest localization/source packets.
- Run GUI timing smoke for Start Center.
- Record command outputs and warning/error/fatal counts.
- Produce `tmp/release-alpha1-build-smoke.md`.

Required commands:

```sh
gmake -C /Users/lu/kdoffice-src sc.build
gmake -C /Users/lu/kdoffice-src sw.build
gmake -C /Users/lu/kdoffice-src sfx2.build
/Users/lu/可点office/bin/gui-smoke-timing.sh --mode startcenter --wait 12 --timeout 20 --max-elapsed 20 --run-name release-alpha1-startcenter
```

### Packet R4: Packaged App Candidate

Goal: produce an unsigned alpha artifact for controlled testing.

Actions:

- Build `test-install`.
- If using GitHub Actions, run `.github/workflows/build-installers.yml` with `target=macos` or `target=both`.
- Collect artifact paths, hashes, size, build logs, and install/open smoke result.
- Produce `tmp/release-alpha1-artifacts.md`.

Local macOS command:

```sh
gmake -C /Users/lu/kdoffice-src test-install
```

GitHub Actions target already exists:

```text
.github/workflows/build-installers.yml
```

Current workflow status:

- macOS DMG: unsigned build path exists.
- Windows MSI: unsigned build path exists.
- Signing/notarization: not implemented in this release path.
- Artifact upload: workflow uploads installer artifacts and logs.

### Packet R5: Manual Screenshot And Known-Issues Evidence

Goal: make the alpha preview honest and useful.

Actions:

- Capture screenshots for Start Center, Writer, Calc, Impress, Draw, and selected localized dialogs.
- Capture Calc Standard Filter and Advanced Filter because they are latest proven high-value changes.
- Record remaining English and classify it.
- Produce `tmp/release-alpha1-screenshot-evidence.md`.

Required classification buckets:

- Technical term.
- Real font name.
- Identifier/internal.
- Fixture/test-only.
- Stock button deferred.
- Unresolved visible defect.

## 6. Codex Release Review Checklist

Codex should accept Alpha Preview 1 only if all of these are true:

- Release label says `Alpha Preview`, not beta/stable.
- Source classification exists and does not hide dirty-tree risk.
- Localization checks pass through the included lane number.
- Module build gates pass for touched modules.
- Start Center smoke runs and records evidence.
- Artifact report lists exact paths, hashes, and whether artifacts are signed.
- Screenshot evidence exists or every missing screenshot is explained.
- Known issues are included in release notes.
- No beta/stable/world-class marketing claim appears in the release notes.

Codex must reject the release if:

- Clavue asks to tag from the current unclassified dirty tree.
- Any beta-hard gate failure is omitted from release notes.
- The installer is described as signed/notarized without proof.
- Generated build output is treated as source.
- AI/provider/plugin runtime is promoted without policy/signing/consent gates.

## 7. Release Notes Draft

Title:

```text
可圈office 26.8 Alpha Preview 1
```

Summary:

```text
This is a controlled alpha preview for localization, packaging, and workflow validation. It includes recent Chinese-first UI improvements, 可圈office branding, templates/workbench progress, and Calc filter localization evidence through the current source lanes. It is not a beta or stable release.
```

Highlights:

- Improved Chinese UI coverage across high-frequency Writer, Calc, Impress/Draw, CUI, SFX2, and shared surfaces.
- Calc Standard Filter and Advanced Filter dialogs now have source/build localization evidence.
- 可圈office branding and desktop integration work continue.
- Workbench/start-center and Chinese template/default-document work are available for controlled testing.
- Compatibility smoke/layout evidence exists, but representative visual comparison is still expanding.

Known limitations:

- Not beta-ready.
- Not stable/release-ready.
- Some visible English remains in high-frequency UI.
- Packaged-app screenshot proof is incomplete.
- Accessibility live evidence is incomplete.
- Strict validator readiness is blocked by missing validator assets and current ODF Validator `failed:extension-namespace` findings on generated intermediate ODF files.
- Skipped validators and classified validator failures are alpha caveats, not compatibility quality passes.
- Strict source hygiene is blocked until dirty/generated/local artifacts are classified.
- Installers are unsigned unless a separate signing/notarization packet completes.
- AI/provider/plugin runtime should not be treated as production-ready.

## 8. Promotion Gates

### Alpha Preview 1 Exit

The alpha preview can be distributed to controlled testers after:

- Source classification report exists.
- Localization sweep passes through the included lane.
- Relevant module builds pass.
- `test-install` or GitHub Actions artifact build succeeds.
- Artifact hashes and known issues are recorded.

### Beta Candidate Entry

Beta candidate is blocked until:

- `validator-readiness-strict` passes, including required validator assets and resolution or approved release exception for ODF Validator `failed:extension-namespace` findings.
- `source-hygiene-strict` passes or every remaining item has an approved release exception.
- `workbench-live-accessibility` passes.
- Packaged-app screenshots prove claimed localization surfaces.
- Representative Chinese compatibility corpus has visual evidence.
- PDF export trust checks include Chinese fonts and layout evidence; direct input-PDF validation alone is not PDF export/roundtrip proof.

### Stable Release Entry

Stable release is blocked until:

- All beta gates pass.
- macOS signing and notarization are complete.
- Windows signing is complete if Windows is distributed.
- Download artifacts have hashes and install/open verification.
- Release notes match evidence.
- No unresolved high-severity localization, accessibility, compatibility, data-loss, or packaging issue remains.

## 9. Immediate Next Action

Clavue should keep the refreshed blocker packet attached to the Alpha Preview 1 handoff and avoid any branch, tag, beta, stable, public-release, signed/notarized, or full-compatibility claim until the listed blockers are closed or explicitly accepted by the release operator.

Codex should review the classification before allowing a release branch or tag.

No tag, public release, or stable claim should be created from the current state.
