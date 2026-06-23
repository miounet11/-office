# 可圈office V3 Master Plan: Claude for 可圈office

Date: 2026-05-12
Status: **Draft** (规划正文已与用户对齐 / spec 骨架同步交付 / H8-H12 contract gates active / W1 in-app-chat fixture + context autocomplete + Markdown rendering + chat history + streaming state + AI workspace UI + content opener + formatting review + content review + artifact navigator + review queue + evidence inspector + interaction chrome + content preview matrix + workspace action bar + workspace filter/search + workspace context handoff + workspace review state sync + workspace activity timeline + workspace session snapshot + workspace attention routing + workspace native style + workspace content registry + workspace source provenance + chat clipboard materialization self-test active / W2 manifest trust-chain + read-only/writeback + auth-flow + token-refresh guards active / W3 knowledge-index chunk/query/result self-tests active + model acquisition + vector-store + watcher scalability + extraction + storage policies locked / W4 audit-log-entry + policy-tenant self-tests active / W5 eval fixture schema lock + reference baseline lock + LLM-judge reproducibility lock + report/archive-policy self-test active / W6 agent-step-plan + dependency-policy + plan-validation-policy + approval-policy + resume-policy + shadow-doc-policy + prompt-library + agent-step-result-state self-tests active / W7 companion-contract self-test active / W8 sync-message self-test active / W9 onboarding-flow + starter-pack + edition-policy + i18n-locale + manual-docs + distribution-update + error-recovery-ux + release-ga-checklist self-tests active / 尚未启动实施)
Predecessor: V2 实施中 (`docs/product/v2-master-plan.md`，W1–W2 Day-1 已落 / W3 Day-1b 待授权)
Reference benchmark: <https://claude.com/claude-for-microsoft-365>

> 本文档是 V3 规划的入口 (entry pointer)。各 wave 详细 spec 在
> `docs/product/v3/w[1-9]-*-spec.md`；与 V2 的 hand-off 表见 §7；
> 验证策略与新增 harness (H8/H9/H10/H11/H12) 在 §8。
> 当前开发执行 TODO: `docs/product/v3/v3-upgrade-development-todolist-2026-06-13.md`。

---

## 1. North Star

V1.5 把 可圈office 视觉提升到 WPS 级别；V2 把 AI 从"贴皮聊天"做进了文档对象模型；
**V3 的目标是把整个 可圈office 升级为「Claude for 可圈office」——
一个嵌在桌面办公套件里的本地优先企业级 AI 工作台**，
对标 2027–2028 年的 Claude for Microsoft 365 / Copilot Pages / WPS AI 企业版，
但把 V1/V2 的差异化定位继续推到底：

| 维度 | 海外/国内主流做法 (2027F) | 可圈office V3 立场 |
|---|---|---|
| 推理位置 | 默认云端，本地是降级 | **本地优先 (Ollama / llama.cpp / MLX)**；云端是显式订阅项 |
| 数据出域 | 静默走 RAG，向量库托管 | **不静默上传**；任何外发需用户显式同意 + evidence 链 |
| 知识检索 | 平台托管的向量库 | **本地索引为主**，企业自建私有向量库为辅 |
| 输出形态 | Markdown + 整段重写 | **段落 / 单元格 / 幻灯片对象** patch (沿用 V2 ApplyPlan) |
| 任务编排 | 云端 agent 黑盒 | **多步 agent 全程 evidence + 逐步可中止 + 全局可回滚** |
| 协作 | 实时云协作 | **本地文件优先**；移动端 companion 仅审批不编辑 |
| 信任模型 | 输出即生效 | **预览 → 审批 → 应用 → evidence**（V2 管线在 V3 全保留）|
| 计费 | 按 token / 席位 | **本地 0 成本默认**；企业版按租户审计能力计价 |
| 云服务出处 | 厂商托管 | **全部自部署本地**（OAuth proxy / push / sync / embedding / audit sink / 崩溃上报 / 自更新 见 W8）|

V3 完成时，用户应当感受到：

- 在 Writer/Calc/Impress 内**直接 Cmd+Shift+K** 唤起 In-App Chat：
  "把这份 PRD 改成 OKR 格式，引用上次评审纪要" → AI 跨文档检索 + 结构化 patch
- **Connector 抽屉** 一键挂上飞书/企微/Notion/SharePoint，文档级权限严格
- **Knowledge Index** 自动维护本地+企业语料，随文件改写实时更新
- 企业管理员能在**一个面板**里看到：哪个用户、跑了哪个 prompt、消耗多少 token、
  动了哪些文档、哪步审批、是否泄露数据 → 直接出审计报告
- **Agent multistep** 跑长任务（比如"按这十份合同生成季度风险报告"），
  全程可暂停、回放、回滚，单步失败不污染主文档
- 整个体验**跟 Claude.ai 一样自然**，但**所有数据默认在本地**

---

## 2. V3 Wave 拓扑

```
                              V3 Master Plan
                                    │
                       ┌────────────┴────────────┐
                       │                         │
                W8 Local-Cloud-Stack (底座)  W9 Market-Readiness (收口)
                (6-10w, 全本地云服务)        (8-12w, GA 闭环)
                       │                         ▲
               ┌───────┴────────────┐            │
               │                    │            │
        W1 In-App Chat       W2 Connector Layer  │  W4 Tenant + Policy
        (12-16w)             (10-14w)            │  + Audit (8-12w)
               │                    │            │       │
               └────────┬───────────┘            │       │
                        │                        │       │
              W3 Knowledge Index ────────────────┼──► (W4 提供租户隔离)
              (10-14w)                           │
                        │                        │
               ┌────────┴────────┐               │
               │                 │               │
         W5 Eval Harness   W6 Agent Multistep    │
         (持续 6-10w)      (12-18w, 依赖 W1+W3+W4)│
                                 │               │
                                 │               │
                          W7 Companion ──────────┘
                          (8-12w, 移动端审批 + 通知)
```

依赖关系：

- **W8 是底座的底座**：所有 W2/W4/W7 需要的"云能力"（OAuth callback / audit sink / push gateway / 自更新）由 W8 自部署提供；W8 必须先于 W2/W4/W7 GA
- **W1 + W2 是底座**：In-App Chat 需要 connector 取上下文；二者并行启动
- **W3 在 W1 之后**：Knowledge Index 复用 W1 的 chat orchestration 做查询编排
- **W4 早期穿插**：Tenant+Policy+Audit 必须在任何"出域"行为前落地，否则 §1 不静默上传破功
- **W5 全程伴随**：Eval Harness 是 W1–W4 的回归 + ROI 度量基础
- **W6 在 W1+W3+W4 都达成 v1 后**：Agent multistep 调度它们的能力做长任务
- **W7 最后**：Companion 仅做审批 + 通知，不做编辑
- **W9 是 GA 收口层**：onboarding / starter pack / 性能基线 / i18n / freemium / 分发包装 全部在此收口；闭环到 GA 不留 PENDING

---

## 3. Wave 概要

### W1: In-App Chat（12–16 周）

**目标**：在每个 office app 内嵌 Chat sidebar，对话即上下文，输出即 patch。

**关键决策**：
- 复用 **V2 W1 Provider Runtime**（不重做 LLM 抽象）
- 复用 **V2 W2 Cmd+K** 三态调度（slot fuzzy / LLM intent / chat fallback）
- Sidebar 容器走 sfx2 sidebar 扩展（与 V2 W4 Diff 视图同框架）
- 默认快捷键：**Cmd+Shift+K**（避让 V2 W2 已占的 Cmd+K = palette；同步避让
  `Accelerators.xcu:93` 已绑的 `.uno:HyperlinkDialog`）
- 输出走 **V2 W3 Writer Apply Runtime / W4 Select-to-Act**，patch 粒度不变
- 上下文来源：当前文档 / 选中区 / W2 Connector 拉的远端 / W3 Knowledge Index

**Contract self-test**：`tests/v3-in-app-chat-test.sh` locks the W1 in-app-chat fixture self-test at 28 checks without adding a W1 schema: `Cmd+Shift+K` → CommandPalette `command-palette-chat-fallback` → `sfx2-sidebar`, `directAcceleratorRegistration=false`, Writer/Calc/Impress surfaces, connector-context fixture, scoped context autocomplete (`chat-input-only`, `delegate-existing-controls`, no global Office autocomplete hijack, W2-manifest-gated connector suggestions, no raw context preview, and parser runtime not started), native Markdown subset rendering (`paragraph`, `heading`, `list`, `code-fence`, `table`; no WebView/raw HTML/remote images), per-doc-local chat history (`local-sqlite-sidecar`, `document-id-hash`, no cloud sync/global index/cross-document restore/raw transcript fixture storage), V2 chunk streaming states (`idle`, `requesting`, `streaming`, `awaiting-approval`, `applied`, `failed`, `cancelled`; main document unchanged while streaming), AI workspace UI (`ai-workspace-sidebar`, `conversation-plus-progress`, visible task progress, content review, formatting review, DiffReview reuse, before/after preview, and openers for document / selection / connector-result / knowledge-index-result / evidence-record / task-step), content opener route policy (`routePolicy.task-step=diff-review`, evidence-linked read-only previews, no main document mutation, fail-closed visible failures), formatting review policy (`reviewMode=before-after-layout-diff`, paragraph/character/table/cell/slide layout scope, evidence-linked DiffReview, human approval, no raw/preview fixture content), content review policy (`reviewMode=evidence-linked-content-diff`, selection/document-section/connector-result/knowledge-index-result/evidence-record/task-step scope, evidence-linked DiffReview, human approval, no raw/suggestion fixture content), artifact navigator policy (`managedTypes=[document,selection,connector-result,knowledge-index-result,evidence-record,task-step]`, evidence badges, content opener integration, read-only details, no raw artifact fixture content, and runtime not started), review queue policy (`itemTypes=[content-review,formatting-review,task-step]`, queued/open/approved/rejected/applied/failed states, state/type/surface filters, DiffReview opening, explicit human approval for bulk actions, no raw review fixture content, and runtime not started), evidence inspector policy (`sourceTypes=[evidence-record,connector-result,knowledge-index-result,task-step,review-item]`, citation links, audit trail, content opener integration, redacted raw payloads, hash-only references, no raw evidence/citation fixture content, and runtime not started), interaction chrome policy (`layout=sidebar-workbench`, `navigation=segmented-tabs`, `panels=[chat,tasks,artifacts,reviews,evidence]`, persistent composer, visible rails, keyboard traversal, Escape focus return, no focus trap, compact native controls, no modal-only chat, and runtime not started), content preview matrix policy (`contentTypes=[document,selection,connector-result,knowledge-index-result,evidence-record,task-step,review-item]`, metadata/read-only/diff/evidence modes, evidence badges, source metadata, content opener integration, redaction, hash-only references, no raw/preview fixture payloads, and runtime not started), workspace action bar policy (`commands=[open-preview,open-diff-review,approve-selected,reject-selected,copy-reference,export-evidence,filter,sort,retry,cancel]`, visible keyboard-accessible native action surface, contentOpeners/DiffReview reuse, evidence links, explicit human approval, no auto-apply, no hidden/mouse-only actions, and runtime not started), workspace filter/search policy (`surfaces=[tasks,artifacts,reviews,evidence,previews]`, metadata-only scoped search, contentOpeners reuse, evidence links, no raw indexing, and runtime not started), workspace context handoff policy (visible breadcrumb/back/focus return, preserved task/evidence/hash/preview/review metadata, contentOpeners/DiffReview reuse, no raw handoff payloads, no auto-apply, and runtime not started), workspace review state sync policy (`stateSources=[review-queue,diff-review,preview-matrix,evidence-inspector,task-progress,action-bar]`, queued/open/approved/rejected/applied/failed states, evidence links, visible state, explicit human approval, no auto-apply, and runtime not started), workspace activity timeline policy (`events=[chat-requested,task-started,artifact-created,content-opened,review-opened,review-state-changed,evidence-linked,action-invoked,failure-reported]`, chronological append-only metadata, visible timestamp/actor/open target, contentOpeners/DiffReview/evidence inspector reuse, no raw/transcript fixture content, and runtime not started), workspace session snapshot policy (`restores=[active-task-id,open-artifact-id,open-review-id,active-evidence-id,preview-mode,review-state,activity-cursor,failure-state]`, current workspace/current document scope, visible resume summary, explicit resume, timestamp/document binding, contentOpeners/DiffReview/evidence inspector/activity timeline reuse, no raw/preview/transcript fixture content, no cross-document restore/cloud sync, and runtime not started), workspace attention routing policy (`triggers=[approval-required,review-ready,task-failed,evidence-missing,resume-available]`, visible badge/row/event/banner surfaces, routes to task/review/DiffReview/evidence/timeline/session targets, visible reason/timestamp/open target, keyboard access, no cloud push, no auto-open, no auto-apply, and runtime not started), V2 Provider reuse, V2 ApplyPlan token-lock reuse, V2 evidence-record reuse, human approval, no cloud history, and `runtimeImplementation=not-started`.

**文件层**：`docs/product/v3/w1-in-app-chat-spec.md`, `docs/product/v3/w1-keyboard-shortcut-survey.md`, `docs/product/v3/w1-sidebar-uiwireframe.md`, `docs/product/v3/w1-context-syntax-policy.md`, `docs/product/v3/w1-context-autocomplete-policy.md`, `docs/product/v3/w1-markdown-rendering-policy.md`, `docs/product/v3/w1-chat-history-policy.md`, `docs/product/v3/w1-streaming-state-policy.md`, `docs/product/v3/w1-ai-workspace-ui-policy.md`, `docs/product/v3/w1-content-opener-policy.md`, `docs/product/v3/w1-formatting-review-policy.md`, `docs/product/v3/w1-content-review-policy.md`, `docs/product/v3/w1-artifact-navigator-policy.md`, `docs/product/v3/w1-review-queue-policy.md`, `docs/product/v3/w1-evidence-inspector-policy.md`, `docs/product/v3/w1-interaction-chrome-policy.md`, `docs/product/v3/w1-content-preview-matrix-policy.md`, `docs/product/v3/w1-workspace-action-bar-policy.md`, `docs/product/v3/w1-workspace-filter-search-policy.md`, `docs/product/v3/w1-workspace-context-handoff-policy.md`, `docs/product/v3/w1-workspace-review-state-sync-policy.md`, `docs/product/v3/w1-workspace-activity-timeline-policy.md`, `docs/product/v3/w1-workspace-session-snapshot-policy.md`, `docs/product/v3/w1-workspace-attention-routing-policy.md`, `docs/product/v3/w1-workspace-native-style-policy.md`, `docs/product/v3/w1-workspace-content-registry-policy.md`

---

### W2: Connector Layer（10–14 周）

**目标**：标准化"AI 取外部数据"通道。一份 manifest，一次审批，全程 evidence。

**关键决策**：
- 新 schema：`docs/schemas/connector-manifest.schema.json`（V3 引入，**不进 V2 schema 锁**；H8 已锁 schema/fixture contract）
- 内置 connector：本地文件夹 / 飞书 / 企业微信 / Notion / SharePoint / Confluence
- 每个 connector 必须提供：auth flow / scope 声明 / rate limit / evidence emitter
- 每个 manifest 必须提供 trust envelope：source / publisher / sha256 / review state / install scope / signature posture
- 每个 manifest 必须提供 read-only operations envelope：V3 v0 禁止 writeback、write scopes、`data-write` evidence 和 runtime write implementation
- 每个 manifest 必须提供 auth flow envelope：OAuth2 系统浏览器 + 127.0.0.1 loopback；禁止 embedded WebView 和 runtime auth implementation
- 每个 manifest 必须提供 auth refresh envelope：OAuth2 用户显式 reauth、API key 手动轮换，禁止后台刷新和 refresh token 持久化
- **任何 connector 调用产生 evidence-record**（沿用 V2 schema），不创新
- UI 入口：sidebar 抽屉 + Cmd+Shift+K palette 子命令 `@connector`

**新增 harness**：H8 connector contract（active，16 checks；manifest 字段锁 + trust-chain guard + read-only/writeback guard + auth-flow guard + token-refresh guard + scope/service-mode/evidence/fixture roster 一致性）

**文件层**：`docs/product/v3/w2-connector-layer-spec.md`, `docs/product/v3/w2-manifest-trust-policy.md`, `docs/product/v3/w2-connector-operations-policy.md`, `docs/product/v3/w2-auth-flow-policy.md`, `docs/product/v3/w2-token-refresh-policy.md`

---

### W3: Knowledge Index（10–14 周）

**目标**：把"上下文召回"从 ad-hoc grep 升级为可索引、可更新、可审计的知识库。

**关键决策**：
- **本地索引默认**（SQLite + FTS5；lancedb-local 仅 opt-in，macOS arm64 仍 pending-runtime-spike）
- 文件改写触发**增量更新**（文件系统 watcher + 语义分块；>10k 文件工作区用 bounded watcher + polling fallback，禁止 per-file fd watch）
- 企业版可挂载远端只读向量库（走 W2 connector）
- **BGE-m3 不默认打包、不静默下载**；hybrid/vector 需用户显式确认，缺模型或向量后端未验证时回退 SQLite FTS5
- **PPTX 文本抽取走 LibreOffice import filter + Impress document model**；禁止 standalone PPT parser，保留 slide element refs
- **索引存储放 application data directory 的 per-workspace sidecar**；禁止放入用户文档目录或随文档同步，路径身份用 workspace hash
- **不向云上传原文**；只在用户显式同意时上传 embedding（且 embedding 模型本地）
- 检索 API 暴露给 W1 Chat / W6 Agent

**文件层**：`docs/product/v3/w3-knowledge-index-spec.md`, `docs/product/v3/w3-model-acquisition-policy.md`, `docs/product/v3/w3-vector-store-policy.md`, `docs/product/v3/w3-watcher-scalability-policy.md`, `docs/product/v3/w3-extraction-policy.md`, `docs/product/v3/w3-storage-policy.md`

---

### W4: Tenant + Policy + Audit（8–12 周）

**目标**：从单机用户扩展到企业租户，所有 AI 行为可审计可治理。

**关键决策**：
- 三层模型：**Tenant**（租户）/ **Workspace**（命名空间）/ **User**（实际用户）
- Policy 引擎：基于 evidence-record 的 deny/allow 规则
  （例：`tenant=acme && connector=public-internet → deny`）
- Audit log：append-only，**与 V2 evidence-record 同链不同表**（避免 schema 塌缩）
- 管理面板：独立 Web UI（local-only / 企业自部署），**不是 office app 内部**
- 离线模式（默认）：所有 policy 内嵌 binary，无网络依赖

**文件层**：`docs/product/v3/w4-tenant-policy-audit-spec.md`

---

### W5: Eval Harness（持续 6–10 周）

**目标**：建立可重放、可度量、可对外发布的 AI 质量基线。

**关键决策**：
- 沿用 V2 H1-H10 sweep，新增 **H8: connector contract**、**H9: eval baseline seed**、**H10: local-cloud no-egress contract**、**H11: perf baseline target contract**、**H12: crash-recovery target contract**（均已 active）
- 两类 eval：
  - **Capability eval**：固定 fixture → 期望 patch → diff 分数
  - **Regression eval**：V1.5 27/27 + V2 H1-H10 必须 100% 不退化
- 输出脚本：`bin/v3-eval-sweep.sh`（对齐 `bin/v2-harness-sweep.sh`）
- 报告：JSON + Markdown，挂在 `docs/product/v3/eval-reports/`；`docs/schemas/eval-report.schema.json` + `docs/product/v3/w5-report-archive-policy.md` + `tests/v3-eval-report-self-test.sh` lock the report-field and archive-policy contract
- Fixture schema/reference/judge-policy lock：`docs/schemas/eval-capability-fixture.schema.json`、`docs/schemas/eval-expected-patch.schema.json`、`docs/schemas/eval-regression-fixture.schema.json` are enforced by H9 at 9 checks, including invalid guards, the `v2-ga-acceptance` reference baseline, and opt-in deterministic LLM-judge policy before runtime scoring starts

**文件层**：`docs/product/v3/w5-eval-harness-spec.md`

---

### W6: Agent Multistep（12–18 周）

**目标**：把"一次问答"升级为"多步任务"，全程可观测可回滚。

**关键决策**：
- Plan-Act-Observe 循环，每步**独立** evidence + 独立 undo entry
- 复用 V2 ApplyPlan envelope；token lock（W4 ParagraphAction 7-token / CellAction 5-token / SlideElementAction 4-token）**严格保留**
- `agent-step-result` + `agent-task-state` contract locks per-step lifecycle, V2 async cowork scheduling, shadow-doc isolation, and approval-before-merge semantics
- `shadowDocPolicy` locks ShadowDoc compatibility to the V2-W3 SwDocShell ApplyPlan path, forbids a new DocShell type, and forbids main-document mutation before approval
- `promptPolicy` locks Planner/Actor/Observer prompt ids and deterministic parameters while keeping public egress and prompt runtime disabled by default
- 任务级中止：用户可在任意 step 暂停；恢复或回滚
- 失败隔离：单步失败 → 主文档 unchanged → evidence 标记 fault
- 长任务跑在 W2 Async Cowork 框架内（V2 W5 已有）

**文件层**：`docs/product/v3/w6-agent-multistep-spec.md`

---

### W7: Companion（8–12 周）

**目标**：移动端只做审批与通知，不做编辑（沿用 V2 W5 立场）。

**关键决策**：
- iOS / Android 原生 app 或 PWA（待 W7 spike 决定）
- 功能严格限定：任务列表 / diff 审批 / evidence 浏览 / push 通知
- **不做**：文档编辑 / AI 直接调用 / 离线编辑同步
- 通信：与桌面 app 同 LAN（默认）/ 企业网关（W4 租户模式）
- `companion-pairing-token` + `companion-diff-summary` + `companion-approval-request` contract locks short token pairing, read-only diff summaries, online biometric approval, and explicit cloud-push opt-in

**文件层**：`docs/product/v3/w7-companion-spec.md`

---

## 4. 时间线（保守估算）

| 阶段 | 月份范围 | 内容 |
|---|---|---|
| Q3 2027 | W1 v0 + W2 v0 | In-App Chat 壳 + Connector manifest 标准 + 本地文件 connector |
| Q4 2027 | W1 v1 + W2 v1 + W3 v0 | Chat 接 V2 patch 管线 + 飞书/Notion connector + 本地 FTS index |
| Q1 2028 | W3 v1 + W4 v0 | 向量索引 + 增量更新 + Tenant 模型骨架 |
| Q2 2028 | W4 v1 + W5 H9 | Policy + Audit GA + Eval baseline 第一版 |
| Q3 2028 | W6 v0 | Agent multistep 三步任务（PRD→OKR→Slide）|
| Q3-Q4 2028 | W6 v1 + W7 | Agent GA + Companion GA |

每个 wave 完成时刷新 V3 Beta-hard gate（保留 V1.5 27/27 + V2 H1-H10 不退化）。

---

## 5. 风险登记

| 风险 | 等级 | 缓解 |
|---|---|---|
| Connector 数量爆炸（每个 SaaS 一个 manifest） | 高 | W2 manifest schema + trust envelope 锁；社区贡献走 PR review + security review + signed manifest hash |
| OAuth embedded WebView 凭据捕获面 | 高 | W2 auth flow envelope 锁定系统浏览器 + 127.0.0.1 loopback；H8 拒绝 embedded WebView、非 loopback OAuth callback 和 runtime auth implementation |
| 外部 SaaS 写回污染数据 | 高 | W2 operations envelope 锁定 read-only；H8 拒绝 writeback、write scopes、`data-write` evidence 和 runtime write implementation |
| OAuth token 静默刷新 / refresh token 泄露 | 高 | W2 auth refresh envelope 锁定 OAuth2 reauth-on-expiry、API key manual-rotate；H8 拒绝后台刷新、refresh token 存储和 runtime refresh implementation |
| 本地向量库性能（百万级 chunk） | 高 | W3 spike 阶段验证 lancedb / qdrant local；分级降级 |
| 企业租户合规（GDPR / 等保 2.0） | 高 | W4 audit log 默认开 + 不可关闭；evidence 不可篡改 |
| Agent 多步失败污染主文档 | 高 | W6 强制 sandbox（每步在分支文档跑 → 通过后合并） |
| V2 ↔ V3 schema 互相塌缩 | 中 | 4-tier locking 沿用；任何新 schema 进锁前过 H8 |
| 本地 LLM 不够用（agent 多步需要更强模型） | 中 | W6 默认 Qwen-2.5-14B / Llama-3.1-70B；M2 Max 起步 |
| Companion 安全（移动端凭据泄露） | 中 | W7 仅 LAN + 短期 token + 审批二次确认 |
| 与 V2 实施竞争资源 | 中 | V3 实施起点 = V2 GA 后；spec 可并行 |
| 上游 LibreOffice 越走越远 | 中 | 每 wave 末做 rebase 评估；UNO service 优先 |

---

## 6. Non-Goals (V3 不做)

- ❌ 自建 LLM 模型（继续用现成）
- ❌ 实时云协作（飞书 / Google Docs 式）
- ❌ 移动端文档编辑（W7 仅审批）
- ❌ AI 全自动决策（始终人审批；agent 也不行）
- ❌ Browser-based 完整版（保留桌面优先；管理面板除外）
- ❌ 公网 SaaS 托管（企业自部署 only）
- ❌ AI 内容市场 / Plugin Store（不进 V3）
- ❌ 多租户在桌面端跑（桌面端 = 单租户；多租户 = 服务端）

---

## 7. V2 衔接

V3 不重做 V2 已交付的契约/管线。下表说明每个 V3 wave 复用了哪个 V2 成果：

| V3 Wave | 复用的 V2 资产 | 复用形式 |
|---|---|---|
| W1 In-App Chat | V2-W1 Provider Runtime | 直接调 `com.sun.star.ai.XProvider` (namespace 锁) |
| W1 In-App Chat | V2-W2 Cmd+K Palette | Sidebar 调度复用三态（slot / LLM intent / chat fallback） |
| W1 In-App Chat | V2-W3 Writer Apply | 输出 patch 进 `SwDocShell::applyDiagnosticsPlan` |
| W1 In-App Chat | V2-W4 Select-to-Act | 段落/单元格/幻灯片对象级别 patch UX 不变 |
| W2 Connector | V2 evidence-record schema | Connector 调用产生标准 evidence；不引入新 evidence schema |
| W3 Knowledge Index | V2-W3 Document Snapshot | Index 增量基于 snapshot diff |
| W4 Tenant+Policy | V2 service-mode policy | offline/private/cloud 三档继续；Tenant 是上层包装 |
| W5 Eval Harness | V2 H1-H10 | 全保留；V3 H8/H9/H10/H11/H12 与 W1/W3/W4/W5/W6/W7/W8/W9 meta self-tests（含 W1 in-app-chat/context autocomplete/Markdown rendering/chat history/streaming state/AI workspace UI/content opener route policy/formatting review policy/content review policy/artifact navigator policy/review queue policy/evidence inspector policy/interaction chrome policy/content preview matrix policy/workspace action bar policy/workspace filter/search policy/workspace context handoff policy/workspace review state sync policy/workspace activity timeline policy/workspace session snapshot policy/workspace attention routing policy/workspace native style policy/workspace content registry policy 与 W9 i18n-locale/manual-docs/distribution-update/error-recovery-ux/release-ga-checklist）已 active，并挂在同一 sweep 脚本 |
| W6 Agent Multistep | V2 ApplyPlan envelope | Token lock（7/5/4）严格保留；Action enum 不扩展 |
| W6 Agent Multistep | V2-W5 Async Cowork | 长任务跑在 V2-W5 异步框架内 |
| W7 Companion | V2-W5 移动审批立场 | 完整继承"仅审批不编辑"约束 |

**塌缩防护**（4-tier locking 沿用 V2 post-L83 架构）：

- `evidence-record` ≠ `provider-evidence` ≠ V3 audit-log（同链不同表）
- `apply-plan` ≠ `apply-plan-runtime` ≠ V3 agent-step-plan
- `connector-manifest` (V3 新增) 不与 `kqoffice-plugin` 互通
- `companion-diff-summary` ≠ V2 ApplyPlan；`companion-approval-request` ≠ V3 audit-log-entry
- Namespace：V2 锁 `com.sun.star.ai.XProvider` / `com.kqoffice.ai.Provider`；
  V3 新增 `com.kqoffice.ai.Connector` / `com.kqoffice.ai.KnowledgeIndex`

---

## 8. 验证策略

每个 V3 wave 必须满足：

1. **设计阶段**：spec 文档审阅 + schema/IDL 草稿 + 与 V2 衔接表
2. **实施阶段**：
   - 单测（CppunitTest_*）+ 契约 fixture（V1.5 18 + V2 增量 + V3 增量）
   - **GUI smoke**（Cmd+Shift+K → chat → patch → undo 链路）
   - V2 H1-H10 回归 100% 绿
3. **集成阶段**：V3 Beta-hard gate（待 W5 spec 阶段定义具体 9 项）
4. **体验阶段**：操作员实测 + 截图 + 录屏 + 用户反馈记录

### 新增 harness

| Harness | 范围 | 触发 |
|---|---|---|
| **H8: connector contract** | manifest 字段 / trust-chain / read-only operations / auth flow / token refresh / scope 声明 / service-mode / evidence emitter / fixture roster 一致性 | 每次 connector 改动 + 每日 sweep |
| **H9: eval baseline seed** | Capability fixture shape / expected patch refs / V2 token-lock counts / Regression eval (V1.5 + V2 不退化) | 每次 V3 eval fixture 改动 + 每周自动跑 |
| **H10: local-cloud no-egress** | LocalCloud endpoint/service config / loopback-private LAN defaults / explicit cloud opt-in evidence | 每次 W8 config/schema/fixture 改动 + 每日 sweep |
| **H11: perf baseline target** | 首启 / 首 token / 召回 P0 target contract + 三平台目标 fixture | 每次 W9 perf target/schema/fixture 改动 + 每日 sweep |
| **H12: crash-recovery target** | 自动保存 30s / RecoveryDialog 30s / diff=0 / evidence 链 + 三平台恢复目标 fixture | 每次 W9 recovery target/schema/fixture 改动 + 每日 sweep |

V2 baseline follows the current V2 sweep (H1-H10). V3 H8 baseline is 16 checks in contract-only mode; it locks connector manifest trust-chain semantics, read-only operations semantics, auth-flow semantics, token-refresh semantics, and auto-locks `Connectors.xcu` once the runtime registration file lands. V3 H9 seed baseline is 9 checks and locks the first capability/regression fixture contract, eval fixture schemas, `v2-ga-acceptance` reference baseline, and opt-in deterministic LLM-judge policy before runtime scoring exists. V3 H10 baseline is 10 checks and locks the LocalCloud no-egress config contract before the gated W8 runtime exists. V3 H11 baseline is 8 checks and locks the W9 P0 perf targets before runtime measurement exists. V3 H12 baseline is 9 checks and locks the W9 crash-recovery target contract before runtime SIGKILL/restart samples exist. The W1 in-app-chat fixture self-test, W3 knowledge-index chunk/query/result, W4 audit-log-entry + policy-tenant, W5 report-field, W6 agent-step-plan/result-state, W7 companion-contract, W8 sync-message, W9 onboarding-flow, W9 starter-pack, W9 edition-policy, W9 i18n-locale, W9 manual-docs, W9 distribution-update, W9 error-recovery-ux, and W9 release-ga-checklist self-tests are meta-gates, not H13; they lock W1 sidebar chat fixtures plus scoped context autocomplete, native Markdown subset rendering, per-doc-local history, V2 chunk streaming states, AI workspace UI review/progress/opening semantics, content opener route policy, formatting review policy, content review policy, artifact navigator policy, review queue policy, evidence inspector policy, interaction chrome policy, content preview matrix policy, workspace action bar policy, workspace filter/search policy, workspace context handoff policy, workspace review state sync policy, workspace activity timeline policy, workspace session snapshot policy, and workspace attention routing policy, workspace native style policy, workspace content registry policy, workspace source provenance policy, and chat clipboard materialization policy at 28 checks without adding a new schema, knowledge index chunks at 12 checks with explicit model acquisition/FTS fallback, vector-store default/fallback policy, watcher scalability policy, extraction policy, and storage policy, query/results at 8 checks, audit entries at 7 checks, policy/tenant envelopes at 8 checks, report fields plus archive policy at 10 checks, the W6 Plan-Act-Observe plan schema plus forward-only DAG dependency policy, fail-closed invalid Planner output policy, whole-task approval default with explicit per-step opt-in, evidence-complete checkpoint resume policy, SwDocShell-compatible ShadowDoc policy, and deterministic prompt policy at 13 checks, the W6 result/state lifecycle contract at 8 checks, the W7 pairing/diff/approval contract at 9 checks, the W8 sync-server message envelope at 8 checks, the W9 five-step first-run flow at 8 checks, the W9 30-template starter pack manifest at 8 checks, the W9 freemium/audit-lock edition policy at 8 checks, the W9 locale/output-language policy at 8 checks, the W9 embedded/online manual docs manifest at 8 checks, the W9 distribution/update policy at 8 checks, the W9 recoverable error UX policy at 8 checks, and the W9 GA checklist policy at 8 checks.

---

## 9. 度量与决策门

每个 wave 启动前需回答：

- **ROI**：相比 V2 用户增益是否清晰？是否对得起新增 8-18 周工作量？
- **安全**：失败时文档/索引是否 unchanged？evidence 是否完整？
- **兼容**：是否与 V1.5 27/27 + V2 H1-H10 冲突？
- **上游**：是否引入与 LibreOffice 主线无法共存的改动？
- **企业**：W4 落地前不引入任何"出域"行为；落地后所有出域走 audit log

如任一答案不通过，wave 标 `Blocked`，回 spec 阶段重审（与 V2 同治）。

V3 增加一项 V2 没有的门：

- **数据出域门**：任何 wave 引入新的"数据可能出本地"路径，必须先过 W4 audit
  + W2 evidence + 用户显式同意三层（缺一不可）

---

## 10. 文档索引

### 设计 / 规格 (planning surface)

| 文档 | 范围 |
|---|---|
| **本文 (v3-master-plan.md)** | 总体架构 / 时间线 / 与 V2 衔接 / 验证策略 |
| `v3/w1-in-app-chat-spec.md` | In-App Chat sidebar + Cmd+Shift+K + V2 复用细节 |
| `v3/w1-keyboard-shortcut-survey.md` | W1 CommandPalette chat fallback route + direct accelerator guard |
| `v3/w1-sidebar-uiwireframe.md` | W1 sfx2 sidebar layout/state contract |
| `v3/w1-context-syntax-policy.md` | W1 explicit context mention grammar + privacy guards |
| `v3/w1-context-autocomplete-policy.md` | W1 scoped @ mention autocomplete + Office autocomplete no-conflict guards |
| `v3/w1-markdown-rendering-policy.md` | W1 native Markdown subset + WebView/raw HTML/remote image guards |
| `v3/w1-chat-history-policy.md` | W1 per-doc local history + no global/cloud/cross-doc/raw-transcript guards |
| `v3/w1-streaming-state-policy.md` | W1 V2 chunk streaming states + no early mutation/partial persistence guards |
| `v3/w1-ai-workspace-ui-policy.md` | W1 AI workspace UI review/progress/opening semantics + modal-only chat guard |
| `v3/w1-content-opener-policy.md` | W1 content opener route policy + evidence-linked read-only preview guards |
| `v3/w1-formatting-review-policy.md` | W1 formatting review policy + before/after layout diff guards |
| `v3/w1-content-review-policy.md` | W1 content review policy + evidence-linked content diff guards |
| `v3/w1-artifact-navigator-policy.md` | W1 artifact/content navigator policy + read-only evidence-linked artifact management guards |
| `v3/w1-review-queue-policy.md` | W1 review queue policy + explicit-approval review item management guards |
| `v3/w1-evidence-inspector-policy.md` | W1 evidence/citation inspector policy + redacted hash-only source inspection guards |
| `v3/w1-interaction-chrome-policy.md` | W1 interaction chrome policy + compact native workbench navigation guards |
| `v3/w1-content-preview-matrix-policy.md` | W1 content preview matrix policy + multi-content read-only preview guards |
| `v3/w1-workspace-action-bar-policy.md` | W1 workspace action bar policy + visible keyboard-accessible command guards |
| `v3/w1-workspace-filter-search-policy.md` | W1 workspace filter/search policy + metadata-only scoped search guards |
| `v3/w1-workspace-context-handoff-policy.md` | W1 workspace context handoff policy + visible cross-surface handoff guards |
| `v3/w1-workspace-review-state-sync-policy.md` | W1 workspace review state sync policy + visible cross-surface review-state guards |
| `v3/w1-workspace-activity-timeline-policy.md` | W1 workspace activity timeline policy + visible append-only audit trail guards |
| `v3/w1-workspace-session-snapshot-policy.md` | W1 workspace session snapshot policy + visible resume state guards |
| `v3/w1-workspace-attention-routing-policy.md` | W1 workspace attention routing policy + visible attention target guards |
| `v3/w1-workspace-native-style-policy.md` | W1 workspace native style policy + compact native workbench layout guards |
| `v3/w2-connector-layer-spec.md` | Connector manifest schema + 内置 connector |
| `v3/w2-manifest-trust-policy.md` | Connector manifest 来源信任链 contract |
| `v3/w2-connector-operations-policy.md` | Connector read-only/writeback contract |
| `v3/w2-auth-flow-policy.md` | Connector auth flow contract |
| `v3/w2-token-refresh-policy.md` | Connector token refresh contract |
| `v3/w3-knowledge-index-spec.md` | 本地索引 + 增量更新 + 检索 API |
| `v3/w3-model-acquisition-policy.md` | BGE-m3 显式下载 + SQLite FTS5 fallback contract |
| `v3/w4-tenant-policy-audit-spec.md` | Tenant 模型 + Policy 引擎 + Audit log |
| `v3/w5-eval-harness-spec.md` | H8 + H9 + H10 + 评估流程 |
| `v3/w6-agent-multistep-spec.md` | Plan-Act-Observe + sandbox + dependency policy + token lock |
| `v3/w6-dependency-policy.md` | W6 forward-only DAG dependency contract |
| `v3/w6-plan-validation-policy.md` | W6 invalid Planner output fail-closed contract |
| `v3/w6-approval-policy.md` | W6 approval UX contract |
| `v3/w6-resume-policy.md` | W6 cross-session resume contract |
| `v3/w6-shadow-doc-policy.md` | W6 ShadowDoc / SwDocShell compatibility contract |
| `v3/w6-prompt-library.md` | W6 Plan-Act-Observe prompt contract |
| `v3/w7-companion-spec.md` | Companion 范围约束 + 通信协议 |
| `v3/w8-local-cloud-spec.md` | 全本地云栈（OAuth proxy / push / sync / audit sink / 自更新 / 崩溃上报） |
| `v3/w9-market-readiness-spec.md` | GA 收口（onboarding / starter pack / 性能基线 / i18n / freemium / 分发） |

### Schema / 契约 (contract surface, V3 新增)

| 文件 | 范围 |
|---|---|
| `docs/schemas/connector-manifest.schema.json` | V3-W2 manifest（draft，不进 V2 schema 锁；H8 active） |
| `docs/schemas/localcloud-config.schema.json` | V3-W8 LocalCloud config（draft，不进 V2 schema 锁；H10 active） |
| `docs/schemas/sync-message.schema.json` | V3-W8 sync-server message envelope（draft，不进 V2 schema 锁；sync-message self-test active） |
| `docs/schemas/onboarding-flow.schema.json` | V3-W9 first-run onboarding envelope（draft，不进 V2 schema 锁；onboarding-flow self-test active） |
| `docs/schemas/starter-pack-manifest.schema.json` | V3-W9 30-template starter pack manifest（draft，不进 V2 schema 锁；starter-pack self-test active） |
| `docs/schemas/edition-policy.schema.json` | V3-W9 freemium + audit-lock edition policy（draft，不进 V2 schema 锁；edition-policy self-test active） |
| `docs/schemas/i18n-locale-policy.schema.json` | V3-W9 locale + AI output-language policy（draft，不进 V2 schema 锁；i18n-locale self-test active） |
| `docs/schemas/manual-docs-manifest.schema.json` | V3-W9 embedded + online mirror manual docs manifest（draft，不进 V2 schema 锁；manual-docs self-test active） |
| `docs/schemas/distribution-update.schema.json` | V3-W9 distribution + update policy（draft，不进 V2 schema 锁；distribution-update self-test active） |
| `docs/schemas/error-recovery-ux.schema.json` | V3-W9 recoverable error UX policy（draft，不进 V2 schema 锁；error-recovery-ux self-test active） |
| `docs/schemas/release-ga-checklist.schema.json` | V3-W9 release GA checklist（draft，不进 V2 schema 锁；release-ga-checklist self-test active） |
| `docs/schemas/perf-baseline-targets.schema.json` | V3-W9 perf baseline target（draft，不进 V2 schema 锁；H11 active） |
| `docs/schemas/eval-report.schema.json` | V3-W5 eval report JSON envelope（draft；report-field self-test active） |
| `docs/schemas/agent-step-plan.schema.json` | V3-W6 Plan-Act-Observe plan envelope（draft；agent-step-plan self-test active） |
| `docs/schemas/agent-step-result.schema.json` | V3-W6 single-step result envelope（draft；agent-step-result-state self-test active） |
| `docs/schemas/agent-task-state.schema.json` | V3-W6 task lifecycle state envelope（draft；agent-step-result-state self-test active） |
| `docs/schemas/companion-pairing-token.schema.json` | V3-W7 pairing token envelope（draft；companion-contract self-test active） |
| `docs/schemas/companion-diff-summary.schema.json` | V3-W7 mobile diff summary envelope（draft；companion-contract self-test active） |
| `docs/schemas/companion-approval-request.schema.json` | V3-W7 online approval request envelope（draft；companion-contract self-test active） |
| `docs/schemas/audit-log-entry.schema.json` | V3-W4 audit log append-only envelope（draft；audit-log-entry self-test active） |
| `docs/schemas/policy-rule.schema.json` | V3-W4 policy rule envelope（draft；policy-tenant self-test active） |
| `docs/schemas/tenant-context.schema.json` | V3-W4 tenant context envelope（draft；policy-tenant self-test active） |
| `docs/schemas/knowledge-index-chunk.schema.json` | V3-W3 retrieval chunk envelope（draft；modelAcquisitionPolicy + vectorStorePolicy + watcherPolicy + extractionPolicy + storagePolicy；knowledge-index-chunk self-test active） |
| `docs/schemas/knowledge-index-query.schema.json` | V3-W3 query envelope（draft；knowledge-index-query-result self-test active） |
| `docs/schemas/knowledge-index-result.schema.json` | V3-W3 result envelope（draft；knowledge-index-query-result self-test active） |

### 工具 / 脚本 (tooling surface, V3 新增)

| 文件 | 范围 |
|---|---|
| `bin/v3-eval-sweep.sh` | V2 H1-H10 + V3 H8/H9/H10/H11/H12 active（对齐 v2-harness-sweep.sh） |
| `tests/v3-connector-manifest-contract-test.sh` | V3 H8 connector manifest contract（16 checks） |
| `tests/v3-eval-baseline-test.sh` | V3 H9 eval baseline seed contract（9 checks） |
| `tests/v3-local-cloud-no-egress-test.sh` | V3 H10 LocalCloud no-egress config contract（10 checks） |
| `tests/v3-perf-baseline-test.sh` | V3 H11 perf-baseline target contract（8 checks） |
| `tests/v3-crash-recovery-test.sh` | V3 H12 crash-recovery target contract（9 checks） |
| `tests/v3-in-app-chat-test.sh` | V3 W1 in-app-chat fixture + context autocomplete + Markdown rendering + chat history + streaming state + AI workspace UI + content opener route policy + formatting review policy + content review policy + artifact navigator policy + review queue policy + evidence inspector policy + interaction chrome policy + content preview matrix policy + workspace action bar policy + workspace filter/search policy + workspace context handoff policy + workspace review state sync policy + workspace activity timeline policy + workspace session snapshot policy + workspace attention routing policy + workspace native style policy + workspace content registry policy + workspace source provenance policy + chat clipboard materialization policy self-test（28 checks；not H13；CommandPalette fallback；no new schema） |
| `tests/v3-knowledge-index-chunk-test.sh` | V3 W3 knowledge-index-chunk self-test（12 checks；not H13；model acquisition + vector-store + watcher scalability + extraction + storage policy locks） |
| `tests/v3-knowledge-index-query-result-test.sh` | V3 W3 knowledge-index-query-result self-test（8 checks；not H13） |
| `tests/v3-audit-log-entry-test.sh` | V3 W4 audit-log-entry self-test（7 checks；not H13） |
| `tests/v3-policy-tenant-test.sh` | V3 W4 policy-tenant self-test（8 checks；not H13） |
| `tests/v3-eval-report-self-test.sh` | V3 W5 report-field/archive-policy self-test（10 checks；not H13） |
| `tests/v3-agent-step-plan-test.sh` | V3 W6 agent-step-plan self-test（13 checks；not H13） |
| `tests/v3-agent-step-result-state-test.sh` | V3 W6 agent-step-result-state self-test（8 checks；not H13） |
| `tests/v3-companion-contract-test.sh` | V3 W7 companion-contract self-test（9 checks；not H13） |
| `tests/v3-sync-message-test.sh` | V3 W8 sync-message self-test（8 checks；not H13） |
| `tests/v3-onboarding-flow-test.sh` | V3 W9 onboarding-flow self-test（8 checks；not H13） |
| `tests/v3-starter-pack-test.sh` | V3 W9 starter-pack self-test（8 checks；not H13） |
| `tests/v3-edition-policy-test.sh` | V3 W9 edition-policy self-test（8 checks；not H13） |
| `tests/v3-i18n-locale-test.sh` | V3 W9 i18n-locale self-test（8 checks；not H13） |
| `tests/v3-manual-docs-test.sh` | V3 W9 manual-docs self-test（8 checks；not H13） |
| `tests/v3-distribution-update-test.sh` | V3 W9 distribution-update self-test（8 checks；not H13） |
| `tests/v3-error-recovery-ux-test.sh` | V3 W9 error-recovery-ux self-test（8 checks；not H13） |
| `tests/v3-release-ga-checklist-test.sh` | V3 W9 release-ga-checklist self-test（8 checks；not H13） |

### 实施 / 进度 (execution surface)

V3 实施时各 wave 单独立项 (`.agent/goals/v3-w<N>-<topic>/`)，本文档不再重复细节。
当前 V3 仅 spec 阶段，未启动 implementation；V2 仍是当前主线
(`.agent/goals/2026-05-08-v2-ai-native/`)。

---

## 附录 A：V3 启动前置（待用户确认）

启动 V3 实施需要先做完以下 V2 收尾：

1. V2 W3 Day-1b：`SwDocShell::applyDiagnosticsPlan` wiring（**当前最高优先级**）
2. V2 H4/H5/H7 partial → full
3. V2 Beta-hard gate 8/9 → 9/9
4. V2 W4 Select-to-Act spec 落地
5. V2 W5 Async Cowork v0

V3 spec 阶段（**本文档 + 9 份 wave spec 骨架**）可与 V2 实施并行。
但 V3 实施阶段（动 sw/source/、cui/source/、officecfg/）必须等 V2 GA。

V3 实施阶段额外启动门：

6. **W8 Local-Cloud-Stack** docker-compose 必须先在内部环境跑通 H10 (no-egress) 才允许启动 W2/W4/W7 实施
7. **W9 Market-Readiness** 必须在 W1-W7 全部 v1 验收后启动，且 H11 (perf-baseline) + H12 (crash-recovery) 必须全绿才允许标 GA
