# V3-W5: Eval Harness Spec

Status: **H8 active / H9 seed + eval fixture schema lock + reference baseline lock + LLM-judge reproducibility lock active / H10 config active / H11 target active / H12 target active / W1 in-app-chat + context autocomplete + Markdown rendering + chat history + streaming state + AI workspace UI + content opener route policy + formatting review policy + content review policy + artifact navigator policy + review queue policy + evidence inspector policy + interaction chrome policy + content preview matrix policy + workspace action bar policy + workspace filter/search policy + workspace context handoff policy + workspace review state sync policy + workspace activity timeline policy + workspace session snapshot policy + workspace attention routing policy + workspace native style policy + workspace content registry policy + workspace source provenance policy + chat clipboard materialization policy self-test active / report + archive-policy self-test active / W6 result-state self-test active / W7 companion self-test active / W8 sync-message self-test active / W9 onboarding-flow + starter-pack + edition-policy + i18n-locale + manual-docs + distribution-update + error-recovery-ux + release-ga-checklist self-tests active** (2026-06-11)
Goal id: 待启动 (`.agent/goals/v3-w5-eval-harness/` 尚未创建)
Predecessor: V2 7-harness sweep (`bin/v2-harness-sweep.sh`)

---

## 1. Goal

建立可重放、可度量、可对外发布的 AI 质量基线。
**非目标**：不做大规模 benchmark 公榜；不做付费评测服务。

成功画像：
- 每次发版前自动跑 V2 H1-H10 + V3 H8/H9/H10/H11/H12 → 生成 Markdown + JSON 报告（schema/template self-test 已 active）
- V1.5 27/27 + V2 H1-H10 永远 100% 绿
- Capability eval 给出"该 wave 实际 patch 质量分"，对外可发布

---

## 2. 关键决策

| 决策点 | 选项 | 当前默认 | 理由 |
|---|---|---|---|
| Sweep 脚本 | 单文件 / 模块化 | **单文件 + 子命令** | 对齐 v2-harness-sweep.sh |
| Eval fixture 格式 | JSON / YAML / 自定义 | **JSON**（同 V2 fixture） | 一致性 |
| 评分函数 | exact match / fuzzy / LLM-judge | **三档：exact / fuzzy / LLM-judge（opt-in）** | LLM-judge 默认关；reproducibility |
| 报告输出 | console / Markdown / JSON / HTML | **Markdown + JSON**（HTML 远期） | 与 lane-status.md 体例一致 |
| 历史归档 | 不存 / per-version / 全部 | **per-version 归档** | 回溯能力 |
| CI 集成 | 必跑 / nightly / 手动 | **PR 必跑 H1-H10 + nightly 全 sweep** | 平衡速度与覆盖 |

---

## 3. Harness 矩阵（V3 完整）

| Harness | 范围 | Baseline | 频率 |
|---|---|---|---|
| H1 | V1.5 strict roundtrip | 27/27 | 每次 build |
| H2 | V2 contract fixture | 47 | 每次 build |
| H3 | V2 schema lock | 26 | 每次 build |
| H4 | V2 cppunit (W3 partial) | partial | 每次 build |
| H5 | V2 cppunit (W4 partial) | partial | 每次 build |
| H6 | V2 fixture sweep | 39 | 每次 build |
| H7 | V2 lane-status drift | partial | 每次 build |
| **H8** | **V3 connector contract** | 16 checks（contract-only；含 manifest trust-chain + read-only/writeback + auth-flow + token-refresh guards）| 每次 V3 connector/schema/trust-policy/operations-policy/auth-flow-policy/token-refresh-policy change |
| **H9** | **V3 eval baseline seed** | 9 checks（fixture contract + schema lock + reference baseline lock + LLM-judge reproducibility lock）| every V3 eval fixture/schema/reference/judge-policy change |
| **H10** | **V3 local-cloud no-egress** | 10 checks（config contract）| every V3 W8 config/schema change |
| **H11** | **V3 perf-baseline target** | 8 checks（target contract）| every V3 W9 perf target/schema change |
| **H12** | **V3 crash-recovery target** | 9 checks（target contract）| every V3 W9 recovery target/schema change |

V2 H1-H10 baseline **永不退化**；H8 baseline is active and can only be raised with matching fixture/harness/docs updates. H8 now also locks the W2 manifest trust envelope: source/publisher/sha256/review state/install scope/signature posture, unsigned-manifest rejection, built-in publisher semantics, community security review, and tenant approval semantics. H8 also locks the V3 v0 read-only operations envelope: `mode=read-only`, `allowedActions=["read"]`, no writeback, no write scopes, no `data-write` connector evidence, and `runtimeWriteImplementation=not-started`. H8 also locks the auth-flow envelope: OAuth2 `system-browser-loopback` with `loopback-127.0.0.1`, API key `manual-secret-entry`, auth none `not-applicable`, no embedded WebView, and `runtimeAuthImplementation=not-started`. H8 also locks the token-refresh envelope: OAuth2 `reauth-on-expiry`, API key `manual-rotate`, auth none `not-applicable`, no background refresh, no refresh-token storage, and `runtimeRefreshImplementation=not-started`. H9 seed baseline is active and locks the first capability/regression fixture shape before runtime scoring exists. H9 also locks three eval fixture schemas: capability fixtures, expected patch references, and V2 regression fixtures, with invalid schema guards for runtime-score drift, missing undo preservation, and V2 sweep downgrade. H9 also locks the LLM-judge reproducibility policy: judge use is opt-in, prompt metadata lives in `docs/product/v3/w5-judge-prompt-library.md`, deterministic parameters are `temperature=0`, `topP=1`, and `seedRequired=true`, default release gating is false, human review is required before external publication, and runtime judge implementation remains `not-started`. H10 config baseline is active and locks loopback/private-LAN defaults plus explicit cloud opt-in evidence before the gated W8 runtime exists. H11 target baseline is active and locks the P0 perf target contract before runtime samples exist. H12 target baseline is active and locks autosave/recovery targets before runtime SIGKILL samples exist.

W5 also has an active **report-field self-test**. It is not a new H-numbered runtime harness; it locks the Markdown/JSON report envelope and archive policy that H8-H12 results must publish. Current baseline: `tests/v3-eval-report-self-test.sh` reports `Checks: 10`.

---

## 4. 文件层

### 已创建（纯脚本，纯 docs，可逆）

```
bin/v3-eval-sweep.sh                          # 主入口
tests/v3-connector-manifest-contract-test.sh  # H8 connector contract
tests/v3-eval-baseline-test.sh                # H9 eval fixture seed contract
tests/v3-local-cloud-no-egress-test.sh        # H10 local-cloud config no-egress
tests/v3-perf-baseline-test.sh                # H11 perf target contract
tests/v3-crash-recovery-test.sh               # H12 crash-recovery target contract
tests/v3-in-app-chat-test.sh                  # W1 in-app-chat fixture self-test
tests/v3-knowledge-index-chunk-test.sh        # W3 knowledge-index-chunk self-test
tests/v3-knowledge-index-query-result-test.sh # W3 knowledge-index-query-result self-test
tests/v3-audit-log-entry-test.sh              # W4 audit-log-entry self-test
tests/v3-policy-tenant-test.sh                # W4 policy-tenant self-test
tests/v3-eval-report-self-test.sh             # W5 report-field self-test
tests/v3-agent-step-plan-test.sh              # W6 agent-step-plan self-test
tests/v3-agent-step-result-state-test.sh      # W6 agent-step-result-state self-test
tests/v3-companion-contract-test.sh           # W7 companion-contract self-test
tests/v3-sync-message-test.sh                 # W8 sync-message self-test
tests/v3-onboarding-flow-test.sh              # W9 onboarding-flow self-test
tests/v3-starter-pack-test.sh                 # W9 starter-pack self-test
tests/v3-edition-policy-test.sh               # W9 edition-policy self-test
tests/v3-i18n-locale-test.sh                  # W9 i18n-locale self-test
tests/v3-manual-docs-test.sh                  # W9 manual-docs self-test
tests/v3-distribution-update-test.sh          # W9 distribution-update self-test
tests/v3-error-recovery-ux-test.sh            # W9 error-recovery-ux self-test
tests/v3-release-ga-checklist-test.sh         # W9 release-ga-checklist self-test
docs/qa/fixtures/v3/connector/                # H8 connector manifests
docs/product/v3/w2-manifest-trust-policy.md   # W2 manifest trust-chain policy
docs/product/v3/w2-connector-operations-policy.md # W2 read-only/writeback policy
docs/product/v3/w2-auth-flow-policy.md        # W2 auth-flow policy
docs/product/v3/w2-token-refresh-policy.md    # W2 token-refresh policy
docs/product/v3/w3-model-acquisition-policy.md # W3 BGE-m3 explicit download + FTS fallback policy
docs/qa/fixtures/v3/eval/                     # H9 capability/regression seed fixtures
docs/qa/fixtures/v3/eval/invalid/             # H9 eval fixture schema invalid guards
docs/qa/fixtures/v3/localcloud/               # H10 LocalCloud default/LAN/opt-in fixtures
docs/qa/fixtures/v3/perf/                     # H11 perf target fixtures
docs/qa/fixtures/v3/recovery/                 # H12 crash-recovery target fixtures
docs/qa/fixtures/v3/in-app-chat/              # W1 in-app-chat fixtures
docs/product/v3/w1-workspace-content-registry-policy.md # W1 workspace content registry policy
docs/product/v3/w1-workspace-source-provenance-policy.md # W1 workspace source provenance policy
docs/product/v3/w1-chat-clipboard-materialization-policy.md # W1 chat clipboard materialization policy
docs/qa/fixtures/v3/knowledge-index-chunk/    # W3 knowledge-index-chunk fixtures (includes model acquisition + vector-store + watcher + extraction + storage guards)
docs/qa/fixtures/v3/knowledge-index-query-result/ # W3 query/result paired fixtures
docs/qa/fixtures/v3/audit-log-entry/          # W4 audit-log-entry fixtures
docs/qa/fixtures/v3/policy-tenant/            # W4 policy/tenant paired fixtures
docs/qa/fixtures/v3/agent-step-plan/          # W6 agent-step-plan fixtures
docs/qa/fixtures/v3/agent-step-result-state/  # W6 result/state paired fixtures
docs/qa/fixtures/v3/companion/                # W7 companion pairing/diff/approval fixtures
docs/qa/fixtures/v3/sync-message/             # W8 sync-message protocol fixtures
docs/qa/fixtures/v3/onboarding-flow/          # W9 first-run onboarding fixtures
docs/qa/fixtures/v3/starter-pack/             # W9 starter pack manifest fixtures
docs/qa/fixtures/v3/edition-policy/           # W9 edition/freemium policy fixtures
docs/qa/fixtures/v3/i18n-locale/              # W9 locale/output-language policy fixtures
docs/qa/fixtures/v3/manual-docs/              # W9 embedded/online manual docs fixtures
docs/qa/fixtures/v3/distribution-update/      # W9 distribution/update policy fixtures
docs/qa/fixtures/v3/error-recovery-ux/        # W9 recoverable error UX fixtures
docs/qa/fixtures/v3/release-ga-checklist/     # W9 release GA checklist fixtures
docs/schemas/localcloud-config.schema.json    # H10 LocalCloud config schema
docs/schemas/sync-message.schema.json         # W8 sync-server message schema
docs/schemas/onboarding-flow.schema.json      # W9 first-run onboarding flow schema
docs/schemas/starter-pack-manifest.schema.json # W9 starter pack manifest schema
docs/schemas/edition-policy.schema.json       # W9 freemium + audit-lock policy schema
docs/schemas/i18n-locale-policy.schema.json   # W9 locale + AI output language policy schema
docs/schemas/manual-docs-manifest.schema.json # W9 embedded + online mirror manual docs schema
docs/schemas/distribution-update.schema.json  # W9 distribution + update policy schema
docs/schemas/error-recovery-ux.schema.json    # W9 recoverable error UX schema
docs/schemas/release-ga-checklist.schema.json # W9 release GA checklist schema
docs/schemas/perf-baseline-targets.schema.json # H11 perf target schema
docs/schemas/crash-recovery-targets.schema.json # H12 recovery target schema
docs/schemas/knowledge-index-chunk.schema.json # W3 knowledge index chunk schema (includes modelAcquisitionPolicy + extractionPolicy + storagePolicy)
docs/schemas/knowledge-index-query.schema.json # W3 knowledge index query schema
docs/schemas/knowledge-index-result.schema.json # W3 knowledge index result schema
docs/schemas/audit-log-entry.schema.json      # W4 audit log entry schema
docs/schemas/policy-rule.schema.json          # W4 policy rule schema
docs/schemas/tenant-context.schema.json       # W4 tenant context schema
docs/schemas/eval-report.schema.json          # W5 Markdown/JSON report schema
docs/schemas/eval-capability-fixture.schema.json # W5/H9 capability eval fixture schema
docs/schemas/eval-expected-patch.schema.json  # W5/H9 expected patch reference schema
docs/schemas/eval-regression-fixture.schema.json # W5/H9 V2 regression fixture schema
docs/schemas/agent-step-plan.schema.json      # W6 Plan-Act-Observe plan schema
docs/schemas/agent-step-result.schema.json    # W6 single-step result schema
docs/schemas/agent-task-state.schema.json     # W6 task lifecycle state schema
docs/schemas/companion-pairing-token.schema.json # W7 pairing token schema
docs/schemas/companion-diff-summary.schema.json # W7 mobile diff summary schema
docs/schemas/companion-approval-request.schema.json # W7 online approval request schema
docs/product/v3/eval-reports/template.md      # W5 report template
docs/product/v3/eval-reports/v3-contract-self-test.json # W5 report sample
docs/product/v3/w5-report-archive-policy.md   # W5 per-release report archive policy
docs/product/v3/w5-judge-prompt-library.md    # W5 LLM-judge prompt/reproducibility contract
docs/product/v3/w6-dependency-policy.md       # W6 forward-only DAG dependency policy
docs/product/v3/w6-plan-validation-policy.md  # W6 invalid Planner output policy
docs/product/v3/w6-approval-policy.md         # W6 approval UX policy
docs/product/v3/w6-resume-policy.md           # W6 cross-session resume policy
docs/product/v3/w6-shadow-doc-policy.md       # W6 ShadowDoc / SwDocShell compatibility policy
docs/product/v3/w6-prompt-library.md          # W6 Plan-Act-Observe prompt policy
docs/product/v3/w1-keyboard-shortcut-survey.md # W1 CommandPalette chat fallback route
docs/product/v3/w1-sidebar-uiwireframe.md      # W1 sfx2 sidebar layout contract
docs/product/v3/w1-context-syntax-policy.md    # W1 explicit context mention grammar
docs/product/v3/w1-context-autocomplete-policy.md # W1 scoped @ mention autocomplete contract
docs/product/v3/w1-markdown-rendering-policy.md # W1 native Markdown subset contract
docs/product/v3/w1-chat-history-policy.md      # W1 per-doc local history contract
docs/product/v3/w1-streaming-state-policy.md   # W1 V2 chunk streaming state contract
docs/product/v3/w1-ai-workspace-ui-policy.md   # W1 AI workspace review/progress/opening UI contract
docs/product/v3/w1-content-opener-policy.md    # W1 content opener route policy contract
docs/product/v3/w1-formatting-review-policy.md # W1 formatting review policy contract
docs/product/v3/w1-content-review-policy.md    # W1 content review policy contract
docs/product/v3/w1-artifact-navigator-policy.md # W1 artifact/content navigator policy contract
docs/product/v3/w1-review-queue-policy.md      # W1 review queue policy contract
docs/product/v3/w1-evidence-inspector-policy.md  # W1 evidence/citation inspector policy contract
docs/product/v3/w1-interaction-chrome-policy.md    # W1 interaction chrome policy contract
docs/product/v3/w1-content-preview-matrix-policy.md # W1 content preview matrix policy contract
docs/product/v3/w1-workspace-action-bar-policy.md # W1 workspace action bar policy contract
docs/product/v3/w1-workspace-filter-search-policy.md # W1 workspace filter/search policy contract
docs/product/v3/w1-workspace-context-handoff-policy.md # W1 workspace context handoff policy contract
docs/product/v3/w1-workspace-review-state-sync-policy.md # W1 workspace review state sync policy contract
docs/product/v3/w1-workspace-activity-timeline-policy.md # W1 workspace activity timeline policy contract
docs/product/v3/w1-workspace-session-snapshot-policy.md # W1 workspace session snapshot policy contract
docs/product/v3/w1-workspace-attention-routing-policy.md # W1 workspace attention routing policy contract
docs/product/v3/w1-workspace-native-style-policy.md # W1 workspace native style policy contract
```

### 待创建（纯脚本，纯 docs，可逆）

```
bin/v3-eval-judge-llm.sh                      # LLM-judge（opt-in）
docs/product/v3/w5-eval-harness-spec.md       # 本文档
```

### Eval fixture 目录

```
docs/qa/fixtures/v3/eval/capability/          # capability eval
docs/qa/fixtures/v3/eval/regression/          # regression eval
docs/qa/fixtures/v3/eval/expected-patches/    # 期望输出
docs/qa/fixtures/v3/eval/invalid/             # schema guard fixtures
```

---

## 5. Eval Fixture 格式

Schema lock:
- Capability fixtures: `docs/schemas/eval-capability-fixture.schema.json`
- Expected patch references: `docs/schemas/eval-expected-patch.schema.json`
- Regression fixtures: `docs/schemas/eval-regression-fixture.schema.json`

These schemas are intentionally H9-local and do not enter the V2 schema roster. `tests/v3-eval-baseline-test.sh` validates all current valid fixtures against them and requires invalid schema guards to fail before any runtime scoring starts.

Reference baseline lock:
- `referenceBaseline.id=v2-ga-acceptance`
- `referenceBaseline.source=v2-ga`
- `referenceBaseline.versionPolicy=frozen-at-v2-ga`
- `referenceBaseline.frozenAtLedger=L211`
- `referenceBaseline.requiresV2RegressionGreen=true`
- `referenceBaseline.runtimeReferenceImplementation=not-started`

This resolves W5 Q2: capability eval references the V2 GA acceptance baseline, not W1 v0 runtime output. W1 v0 can become a measured candidate once runtime scoring starts, but it cannot become the frozen reference without a new H9 contract update.

LLM-judge reproducibility lock:
- `llmJudgePolicy.enabled=false`
- `llmJudgePolicy.promptLibrary=docs/product/v3/w5-judge-prompt-library.md`
- `llmJudgePolicy.promptId=judge-v3-capability-v1`
- `llmJudgePolicy.promptVersion=v1`
- `llmJudgePolicy.deterministicParameters.temperature=0`
- `llmJudgePolicy.deterministicParameters.topP=1`
- `llmJudgePolicy.deterministicParameters.seedRequired=true`
- `llmJudgePolicy.defaultReleaseGate=false`
- `llmJudgePolicy.requiresHumanReviewForPublish=true`
- `llmJudgePolicy.runtimeJudgeImplementation=not-started`

This resolves W5 Q1: LLM-judge may be used only as an opt-in future tie-breaker with deterministic prompt metadata and human-reviewed publication. It is not a default release gate, does not allow public egress, and does not start runtime model judging.

```json
{
  "id": "v3-eval-w1-rewrite-formal-001",
  "wave": "w1",
  "category": "capability",
  "llmJudgePolicy": {
    "enabled": false,
    "promptLibrary": "docs/product/v3/w5-judge-prompt-library.md",
    "promptId": "judge-v3-capability-v1",
    "promptVersion": "v1",
    "deterministicParameters": {
      "temperature": 0,
      "topP": 1,
      "seedRequired": true
    },
    "defaultReleaseGate": false,
    "requiresHumanReviewForPublish": true,
    "runtimeJudgeImplementation": "not-started"
  },
  "input": {
    "documentSnapshot": "...base64 or path...",
    "selection": {"start": 100, "end": 250},
    "userPrompt": "把第二段改成正式语气",
    "context": []
  },
  "expected": {
    "patchType": "ParagraphAction",
    "tokenCount": 7,
    "diffSimilarity": ">= 0.85"
  },
  "scoring": {
    "method": "fuzzy",
    "threshold": 0.85
  }
}
```

---

## 6. 与 V2 衔接

V3 eval harness **完全继承**并扩展 V2 sweep。`bin/v3-eval-sweep.sh` 第一步即调用
`bin/v2-harness-sweep.sh`，把 H1-H10 跑完再跑 V3 H8/H9/H10/H11/H12。任何破 V2 的改动**直接卡 V3 sweep**。

```bash
# v3-eval-sweep.sh 顶层逻辑（伪代码）
bin/v2-harness-sweep.sh || exit 1   # H1-H10 必须绿
tests/v3-connector-manifest-contract-test.sh  # H8
tests/v3-eval-baseline-test.sh                # H9
tests/v3-local-cloud-no-egress-test.sh        # H10
tests/v3-perf-baseline-test.sh                # H11
tests/v3-crash-recovery-test.sh               # H12
tests/v3-in-app-chat-test.sh                  # W1 in-app-chat fixture self-test
tests/v3-knowledge-index-chunk-test.sh        # W3 knowledge-index-chunk self-test
tests/v3-knowledge-index-query-result-test.sh # W3 knowledge-index-query-result self-test
tests/v3-audit-log-entry-test.sh              # W4 audit-log-entry self-test
tests/v3-policy-tenant-test.sh                # W4 policy-tenant self-test
tests/v3-eval-report-self-test.sh             # W5 report-field self-test
tests/v3-agent-step-plan-test.sh              # W6 agent-step-plan self-test
tests/v3-agent-step-result-state-test.sh      # W6 agent-step-result-state self-test
tests/v3-companion-contract-test.sh           # W7 companion-contract self-test
tests/v3-sync-message-test.sh                 # W8 sync-message self-test
tests/v3-onboarding-flow-test.sh              # W9 onboarding-flow self-test
tests/v3-starter-pack-test.sh                 # W9 starter-pack self-test
tests/v3-edition-policy-test.sh               # W9 edition-policy self-test
tests/v3-i18n-locale-test.sh                  # W9 i18n-locale self-test
tests/v3-manual-docs-test.sh                  # W9 manual-docs self-test
tests/v3-distribution-update-test.sh          # W9 distribution-update self-test
tests/v3-error-recovery-ux-test.sh            # W9 error-recovery-ux self-test
tests/v3-release-ga-checklist-test.sh         # W9 release-ga-checklist self-test
```

For contract-only V3 work, `bin/v3-eval-sweep.sh --v3-only` runs H8, H9, H10, H11, and H12 as active gates. `bin/v3-eval-sweep.sh --self-test` runs V3 meta self-tests: the W1 in-app-chat fixture self-test including context autocomplete, Markdown subset rendering, per-doc local history, streaming UI states, AI workspace UI review/progress/opening semantics, content opener route policy, formatting review policy, content review policy, artifact navigator policy, review queue policy, evidence inspector policy, interaction chrome policy, content preview matrix policy, workspace action bar policy, workspace filter/search policy, workspace context handoff policy, workspace review state sync policy, workspace activity timeline policy, workspace session snapshot policy, workspace attention routing policy, workspace native style policy, workspace content registry policy, workspace source provenance policy, and chat clipboard materialization policy, the W3 knowledge-index-chunk self-test, the W3 knowledge-index-query-result self-test, the W4 audit-log-entry self-test, the W4 policy-tenant self-test, the W5 report-field self-test, the W6 agent-step-plan self-test, the W6 agent-step-result-state self-test, the W7 companion-contract self-test, the W8 sync-message self-test, the W9 onboarding-flow self-test, the W9 starter-pack self-test, the W9 edition-policy self-test, the W9 i18n-locale self-test, the W9 manual-docs self-test, the W9 distribution-update self-test, the W9 error-recovery-ux self-test, and the W9 release-ga-checklist self-test.

Report archive policy:
- `archivePolicy.perReleaseDirectory=docs/product/v3/eval-reports/<release>/`
- `archivePolicy.gitTrackedReports=["json","markdown"]`
- `archivePolicy.heavyArtifactsInGit=false`
- `archivePolicy.largeArtifactPolicy=release-artifact-or-lfs`
- `archivePolicy.requiresLfsDecisionForLargeArtifacts=true`
- `archivePolicy.maxGitReportBytes=262144`
- `archivePolicy.runtimeArchiveAutomation=not-started`

This resolves W5 Q4: per-release JSON/Markdown reports are git-trackable, but heavy screenshots, recordings, and raw runtime samples stay out of git unless an explicit LFS/release-artifact decision is made. No archival automation starts in contract-only mode.

---

## 7. 验证

W5 自身的"元验证"：
- `bin/v3-eval-sweep.sh --v3-only` → H8/H9/H10/H11/H12 must pass
- `tests/v3-connector-manifest-contract-test.sh` → H8 must report `Checks: 16` with 7 valid connector manifests and 17 invalid trust/service/evidence/writeback/auth-flow/token-refresh guards
- `tests/v3-eval-baseline-test.sh` → H9 must report `Checks: 9`
- `tests/v3-local-cloud-no-egress-test.sh` → H10 must report `Checks: 10`
- `tests/v3-perf-baseline-test.sh` → H11 must report `Checks: 8`
- `tests/v3-crash-recovery-test.sh` → H12 must report `Checks: 9`
- `tests/v3-in-app-chat-test.sh` → W1 in-app-chat fixture + context autocomplete + Markdown rendering + chat history + streaming state + AI workspace UI + content opener route policy + formatting review policy + content review policy + artifact navigator policy + review queue policy + evidence inspector policy + interaction chrome policy + content preview matrix policy + workspace action bar policy + workspace filter/search policy + workspace context handoff policy + workspace review state sync policy + workspace activity timeline policy + workspace session snapshot policy + workspace attention routing policy + workspace native style policy + workspace content registry policy + workspace source provenance policy + chat clipboard materialization policy self-test must report `Checks: 28`
- `tests/v3-knowledge-index-chunk-test.sh` → W3 knowledge-index-chunk self-test must report `Checks: 12`
- `tests/v3-knowledge-index-query-result-test.sh` → W3 knowledge-index-query-result self-test must report `Checks: 8`
- `tests/v3-audit-log-entry-test.sh` → W4 audit-log-entry self-test must report `Checks: 7`
- `tests/v3-policy-tenant-test.sh` → W4 policy-tenant self-test must report `Checks: 8`
- `bin/v3-eval-sweep.sh --self-test` → W5 report-field self-test must report `Checks: 10`
- `tests/v3-agent-step-plan-test.sh` → W6 agent-step-plan self-test must report `Checks: 13`
- `tests/v3-agent-step-result-state-test.sh` → W6 agent-step-result-state self-test must report `Checks: 8`
- `tests/v3-companion-contract-test.sh` → W7 companion-contract self-test must report `Checks: 9`
- `tests/v3-sync-message-test.sh` → W8 sync-message self-test must report `Checks: 8`
- `tests/v3-onboarding-flow-test.sh` → W9 onboarding-flow self-test must report `Checks: 8`
- `tests/v3-starter-pack-test.sh` → W9 starter-pack self-test must report `Checks: 8`
- `tests/v3-edition-policy-test.sh` → W9 edition-policy self-test must report `Checks: 8`
- `tests/v3-i18n-locale-test.sh` → W9 i18n-locale self-test must report `Checks: 8`
- `tests/v3-manual-docs-test.sh` → W9 manual-docs self-test must report `Checks: 8`
- `tests/v3-distribution-update-test.sh` → W9 distribution-update self-test must report `Checks: 8`
- `tests/v3-error-recovery-ux-test.sh` → W9 error-recovery-ux self-test must report `Checks: 8`
- `tests/v3-release-ga-checklist-test.sh` → W9 release-ga-checklist self-test must report `Checks: 8`
- 报告 schema：`docs/schemas/eval-report.schema.json`
- 报告模板：`docs/product/v3/eval-reports/template.md`
- 报告样例：`docs/product/v3/eval-reports/v3-contract-self-test.json`

每个 wave 完成时运行 sweep 并归档报告：
- `docs/product/v3/eval-reports/v3-w1-v0.md`
- `docs/product/v3/eval-reports/v3-w1-v0.json`

---

## 8. Open Questions / Blockers

- ~~Q1：LLM-judge 是否引入 reproducibility 风险（同 prompt 不同输出）~~ **决议（W5 Q1）**：H9 capability fixtures must declare `llmJudgePolicy` with opt-in/default-off judging, prompt `judge-v3-capability-v1`, deterministic parameters `temperature=0`, `topP=1`, `seedRequired=true`, `defaultReleaseGate=false`, human review before publication, and `runtimeJudgeImplementation=not-started`; LLM-judge remains a future tie-breaker, not a default release gate.
- ~~Q2：Capability eval baseline 取哪个版本作为 reference（V2 GA 还是 W1 v0）~~ **决议（W5 Q2）**：H9 capability fixtures must declare `referenceBaseline.id=v2-ga-acceptance` with `source=v2-ga`, `versionPolicy=frozen-at-v2-ga`, `requiresV2RegressionGreen=true`, and `runtimeReferenceImplementation=not-started`; W1 v0 is a candidate output, not the frozen reference.
- ~~Q3：eval fixture 是否过 schema 锁（H8 或新 harness）~~ **决议**：H9 直接锁定 eval fixture schemas：`eval-capability-fixture.schema.json`、`eval-expected-patch.schema.json`、`eval-regression-fixture.schema.json`；不新增 H-number，不进入 V2 schema roster，invalid guards 覆盖 runtime-score drift、missing undo preservation、V2 sweep downgrade。
- ~~Q4：正式 per-release 报告归档是否进 git（可能导致 repo 膨胀；可能要 git LFS）~~ **决议（W5 Q4）**：per-release JSON/Markdown report files may be git-tracked under `docs/product/v3/eval-reports/<release>/`; heavy screenshots, recordings, raw samples, and large binary attachments must stay in release artifacts or await an explicit LFS decision; archive automation remains `not-started`.

---

## 9. 时间线（保守估算）

- Q4 2027 (2w)：v3-eval-sweep.sh 骨架 + H1-H10 forward
- Q1 2028 (2w)：H8 connector contract（与 W2 同步）
- Q1 2028 (3w)：H9 capability eval runtime scoring（fixture contract + schema/reference/judge-policy locks 已 active）
- Q1 2028 (1w)：H10 LocalCloud no-egress config contract（已 active；runtime socket proof waits for W8 implementation）
- Q1 2028 (1w)：W8 sync-message self-test（已 active；sync-server runtime waits for W8 implementation）
- Q1 2028 (1w)：H11 perf-baseline target contract（已 active；runtime samples wait for W9 implementation）
- Q1 2028 (1w)：H12 crash-recovery target contract（已 active；runtime SIGKILL samples wait for W9 implementation）
- Q1 2028 (1w)：W9 onboarding-flow self-test（已 active；runtime onboarding proof waits for W9 implementation）
- Q1 2028 (1w)：W9 starter-pack self-test（已 active；runtime template assets wait for W9 implementation）
- Q1 2028 (1w)：W9 edition-policy self-test（已 active；runtime edition switching waits for W9 implementation）
- Q1 2028 (1w)：W9 i18n-locale self-test（已 active；runtime locale plumbing waits for W9 implementation）
- Q1 2028 (1w)：W9 manual-docs self-test（已 active；runtime manual content and Help UI wait for W9 implementation）
- Q1 2028 (1w)：W9 distribution-update self-test（已 active；runtime packaging and update plumbing wait for W9 implementation）
- Q1 2028 (1w)：W9 error-recovery-ux self-test（已 active；runtime recovery UX waits for W9 implementation）
- Q1 2028 (1w)：W9 release-ga-checklist self-test（已 active；release execution waits for V2 GA / W9 implementation）
- Q2 2028 (3w)：LLM-judge opt-in + 正式报告归档（报告 schema/template self-test 已 active）

总计：6–10 周（持续，与其它 wave 并行）。
