# V3 Eval Report Template

Status: TEMPLATE

## Scope

| Field | Value |
|---|---|
| Mode | `v3-contract-sweep` / `nightly` / `release-candidate` |
| Wave | `all` or one V3 wave id |
| Contract-only | `true` until runtime scoring starts |
| Runtime implementation | `not-started` / `partial` / `active` |

## Baseline

| Baseline | Required value |
|---|---|
| V1.5 strict roundtrip | `27/27` |
| V2 regression sweep | `H1-H10` |
| V3 contract sweep | `H8/H9/H10/H11/H12` |
| V3 contract checks | `52` |

## Harness Results

| Harness | Command | Status | Checks | Required artifacts |
|---|---|---:|---:|---|
| H8 connector manifest | `bash tests/v3-connector-manifest-contract-test.sh` | TBD | 16 | `docs/schemas/connector-manifest.schema.json`, `docs/qa/fixtures/v3/connector/` |
| H9 eval baseline seed | `bash tests/v3-eval-baseline-test.sh` | TBD | 9 | `docs/schemas/eval-capability-fixture.schema.json`, `docs/schemas/eval-expected-patch.schema.json`, `docs/schemas/eval-regression-fixture.schema.json`, `docs/qa/fixtures/v3/eval/` |
| H10 LocalCloud no-egress | `bash tests/v3-local-cloud-no-egress-test.sh` | TBD | 10 | `docs/schemas/localcloud-config.schema.json`, `docs/qa/fixtures/v3/localcloud/` |
| H11 perf baseline target | `bash tests/v3-perf-baseline-test.sh` | TBD | 8 | `docs/schemas/perf-baseline-targets.schema.json`, `docs/qa/fixtures/v3/perf/` |
| H12 crash recovery target | `bash tests/v3-crash-recovery-test.sh` | TBD | 9 | `docs/schemas/crash-recovery-targets.schema.json`, `docs/qa/fixtures/v3/recovery/` |

## Gate Decisions

| Gate | Required value |
|---|---|
| Blocks release on failure | `true` |
| Requires V2 regression green | `true` |
| Allows public egress | `false` |
| Requires runtime samples before GA | `true` |
| Publishable externally | `false` for contract-only reports |

## Artifacts

- JSON report: `docs/product/v3/eval-reports/<report-id>.json`
- Markdown report: `docs/product/v3/eval-reports/<report-id>.md`
- Schema: `docs/schemas/eval-report.schema.json`
- Fixture roots: `docs/qa/fixtures/v3/connector/`, `docs/qa/fixtures/v3/eval/`, `docs/qa/fixtures/v3/localcloud/`, `docs/qa/fixtures/v3/perf/`, `docs/qa/fixtures/v3/recovery/`

## Archive Policy

| Field | Required value |
|---|---|
| Policy doc | `docs/product/v3/w5-report-archive-policy.md` |
| Per-release directory | `docs/product/v3/eval-reports/<release>/` |
| Git-tracked reports | `json`, `markdown` |
| Heavy artifacts in git | `false` |
| Large artifact policy | `release-artifact-or-lfs` |
| Requires LFS decision for large artifacts | `true` |
| Max git report bytes | `262144` |
| Runtime archive automation | `not-started` |

## Reproduction

```bash
bash bin/v3-eval-sweep.sh --v3-only
bash bin/v3-eval-sweep.sh --self-test
```

## Runtime Notes

Contract-only reports are not GA evidence until H11 live perf samples and H12 SIGKILL/restart samples are attached.
