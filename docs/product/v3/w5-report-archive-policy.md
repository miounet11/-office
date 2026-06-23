# V3 W5 Report Archive Policy

Status: **contract-only / archival automation not started** (2026-06-10)

This policy resolves W5 Q4 for per-release eval reports. It does not start
report generation, release publishing, git LFS migration, or CI archival
automation.

## Storage Policy

| Artifact | Storage | Rule |
|---|---|---|
| JSON report | git | Keep under `docs/product/v3/eval-reports/<release>/report.json` |
| Markdown report | git | Keep under `docs/product/v3/eval-reports/<release>/report.md` |
| Report schema | git | Keep as `docs/schemas/eval-report.schema.json` |
| Small fixture metadata | git | Keep under `docs/qa/fixtures/v3/**` |
| Screenshots / recordings | release-artifact | Do not commit by default |
| Raw runtime samples | release-artifact | Do not commit by default |
| Large binary attachments | lfs-decision-required | Must not enter git before an explicit LFS/release-artifact decision |

## Required Archive Metadata

- `archivePolicy.perReleaseDirectory` is `docs/product/v3/eval-reports/<release>/`.
- `archivePolicy.gitTrackedReports` contains `json` and `markdown`.
- `archivePolicy.heavyArtifactsInGit` is `false`.
- `archivePolicy.largeArtifactPolicy` is `release-artifact-or-lfs`.
- `archivePolicy.requiresLfsDecisionForLargeArtifacts` is `true`.
- `archivePolicy.maxGitReportBytes` is `262144`.
- `archivePolicy.runtimeArchiveAutomation` is `not-started`.

Contract-only reports remain non-publishable until runtime scoring, H11 live
perf samples, H12 SIGKILL/restart samples, and the release approval path are
explicitly implemented.
