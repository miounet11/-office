# V3-W6: Agent Multistep Spec

Status: **agent-step-plan + dependency-policy + plan-validation-policy + approval-policy + resume-policy + shadow-doc-policy + prompt-library + agent-step-result-state self-tests active** (2026-06-11: schema/fixture contracts live; runtime implementation not started)
Goal id: 待启动 (`.agent/goals/v3-w6-agent-multistep/` 尚未创建)
Predecessor: V2 ApplyPlan envelope + V2-W5 Async Cowork + V3-W1/W3/W4

---

## 1. Goal

把"一次问答"升级为"多步任务"，全程可观测可回滚。
**非目标**：不做完全自主 agent；不做云端任务托管；不放弃人审批。

成功画像：
- 用户输入"按这十份合同生成季度风险报告" → agent 拆 7 步 → 每步 evidence
  → 单步可暂停 / 回滚 → 完成时整体审批
- 任意一步失败 → 主文档 unchanged → evidence 标记 fault → 用户可选恢复或终止
- ApplyPlan token lock（7/5/4）严格保留；agent 输出仍走 V2 patch 管线

---

## 2. 关键决策

| 决策点 | 选项 | 当前默认 | 理由 |
|---|---|---|---|
| Agent 范式 | ReAct / Plan-Act-Observe / 自研 | **Plan-Act-Observe** | 每步可观测；与 V1.5 preview-approve-apply 同体例 |
| 步骤上限 | 5 / 10 / 无限 | **默认 10，上限 25**（用户可调） | 防止 runaway |
| Sandbox | 主文档 / 影子文档 / 两阶段 | **影子文档（per-step branch）** | 单步失败不污染主文档 |
| ShadowDoc 兼容 | 新 DocShell / 复用 SwDocShell / 未定 | **SwDocShell-compatible ShadowDoc** | 兼容 V2-W3 `SwDocShell` ApplyPlan 路径；不在契约阶段新增 DocShell 类型 |
| 步骤间通信 | 共享内存 / 显式输出 / 文件 | **显式输出（结构化）** | 可观测；便于 evidence |
| 中止机制 | 软中止 / 硬中止 / 双 | **软中止 + 硬中止** | 软：当前步完成；硬：立即丢弃当前步 |
| 失败恢复 | 不重试 / 重试一次 / 用户选 | **用户选** | 不静默重试；evidence 完整 |
| 长任务调度 | 进 V2-W5 cowork / 自研 | **复用 V2-W5** | 不新造异步基础设施 |
| 步骤依赖图 | 线性 / DAG / 任意图 | **forward-only DAG** | 允许 fan-in/fan-out，但 plan 仍按 index 拓扑排序；runtime 并行调度未启动 |
| Plan schema 失败 | 静默重试 / 自动简化 / fail-closed | **fail-closed-user-visible** | 执行前失败、用户可见、保留 invalid-plan evidence；不静默重试 |
| Prompt policy | 未锁定 / best-effort / deterministic | **deterministic prompt policy** | Planner/Actor/Observer prompt id 与参数固定；禁止默认 public egress；runtime prompt execution 未启动 |

---

## 3. Plan-Act-Observe 循环

```
User Goal
   │
   ▼
[Plan] LLM 输出 step list (JSON)
   │
   ▼
[Act] 执行 step[i]
   ├─ 调用 V3-W2 connector (取数据)
   ├─ 调用 V3-W3 knowledge index (召回)
   ├─ 调用 V2-W1 provider (LLM 推理)
   ├─ 输出 ApplyPlan (token lock 7/5/4)
   └─ 写入 shadow doc
   │
   ▼
[Observe] 验证 step[i] 输出
   ├─ schema lock (V2 ApplyPlan envelope)
   ├─ evidence 完整性
   ├─ policy 引擎 (W4 pre-flight)
   └─ 用户可选审批 (per-step approve)
   │
   ▼
[ Decide ] 继续 / 重试 / 中止
   │
   ▼
... (循环到完成或中止)
   │
   ▼
[Merge] shadow doc → main doc (整体 approve 后)
```

---

## 4. 文件层

### 待创建（**需授权**）

```
ai/source/agent/AgentRuntime.cxx               # 主调度
ai/source/agent/Planner.cxx                    # Plan 阶段
ai/source/agent/Actor.cxx                      # Act 阶段
ai/source/agent/Observer.cxx                   # Observe 阶段
ai/source/agent/ShadowDoc.cxx                  # 影子文档
ai/source/agent/StepStore.cxx                  # 步骤持久化
sw/source/uibase/app/sw-agent-bridge.cxx       # Writer 集成
sc/source/ui/app/sc-agent-bridge.cxx           # Calc 集成
sd/source/ui/app/sd-agent-bridge.cxx           # Impress 集成
```

### Schema（**进 V3 schema 锁**）

```
docs/schemas/agent-step-plan.schema.json       # Plan 输出（active contract）
docs/schemas/agent-step-result.schema.json     # 单步结果（active contract）
docs/schemas/agent-task-state.schema.json      # 任务整体状态（active contract）
```

### 待创建（纯 docs）

```
docs/product/v3/w6-agent-multistep-spec.md     # 本文档
docs/product/v3/w6-dependency-policy.md        # Step dependency DAG policy
docs/product/v3/w6-plan-validation-policy.md   # Invalid Planner output policy
docs/product/v3/w6-approval-policy.md          # Approval UX policy
docs/product/v3/w6-resume-policy.md            # Cross-session resume policy
docs/product/v3/w6-shadow-doc-policy.md        # ShadowDoc / SwDocShell compatibility policy
docs/product/v3/w6-prompt-library.md           # Plan/Act/Observe prompt policy
docs/product/v3/w6-shadow-doc-design.md        # 影子文档机制
docs/product/v3/w6-failure-modes.md            # 失败场景与恢复
```

---

## 5. Step Plan Schema 草稿

```json
{
  "$id": "https://kqoffice.example.com/schemas/agent-step-plan.schema.json",
  "type": "object",
  "required": ["taskId", "goal", "steps"],
  "properties": {
    "taskId":   { "type": "string", "format": "uuid" },
    "goal":     { "type": "string", "maxLength": 1024 },
    "createdAt":{ "type": "string", "format": "date-time" },
    "steps": {
      "type": "array",
      "minItems": 1,
      "maxItems": 25,
      "items": {
        "type": "object",
        "required": ["index", "kind", "description"],
        "properties": {
          "index":       { "type": "integer", "minimum": 0 },
          "kind":        { "enum": ["fetch", "query", "transform", "patch", "review"] },
          "description": { "type": "string", "maxLength": 512 },
          "dependencies":{ "type": "array", "items": { "type": "integer" } },
          "expectedOutput": { "type": "string" }
        }
      }
    }
  }
}
```

---

## 6. 与 V2 / V3-W1/W3/W4 衔接

| 资产 | 在 W6 中的角色 |
|---|---|
| V2 ApplyPlan envelope | Patch step 输出严格符合 envelope；token lock (7/5/4) 强制 |
| V2-W3 applyDiagnosticsPlan | Patch 落主文档走该 wiring（merge 阶段） |
| V2-W4 Select-to-Act | Per-step 审批 UI 复用 |
| V2-W5 Async Cowork | 长任务跑在该框架内 |
| V3-W1 Chat | Agent 启动入口（用户在 chat 输入"长任务"语义触发） |
| V3-W3 Knowledge Index | Query step 走 W3 API |
| V3-W4 Policy + Audit | 每个 step 都过 policy + 写 audit log |

**Schema 塌缩防护**：

- `agent-step-plan` ≠ V2 `apply-plan`（前者是任务编排；后者是单 patch）
- `agent-step-result` 引用 `evidence-record-id` 但不复用字段
- `agent-task-state` 是任务级状态机，不与 V2 任何 schema 重叠

---

## 7. 验证

### 单测（待写）

```
CppunitTest_ai_agent_planner_output_schema
CppunitTest_ai_agent_actor_step_execution
CppunitTest_ai_agent_observer_failure_isolation
CppunitTest_ai_agent_shadow_doc_isolation
CppunitTest_ai_agent_token_lock_preservation
CppunitTest_ai_agent_resume_after_pause
CppunitTest_ai_agent_rollback_full
```

### Fixture（agent-step-plan active）

- `docs/qa/fixtures/v3/agent-step-plan/valid/writer-quarterly-risk-report.json`
- `docs/qa/fixtures/v3/agent-step-plan/valid/calc-clean-sales-data.json`
- `docs/qa/fixtures/v3/agent-step-plan/valid/impress-outline-to-slides.json`
- `docs/qa/fixtures/v3/agent-step-plan/invalid/overflow-maxsteps.json`（>25 steps 拒绝）
- `docs/qa/fixtures/v3/agent-step-plan/invalid/patch-bypasses-apply-plan-runtime.json`
- `docs/qa/fixtures/v3/agent-step-plan/invalid/missing-shadow-doc-isolation.json`
- `docs/qa/fixtures/v3/agent-step-plan/invalid/forward-dependency-dag.json`
- `docs/qa/fixtures/v3/agent-step-plan/invalid/invalid-plan-silent-retry.json`
- `docs/qa/fixtures/v3/agent-step-plan/invalid/implicit-per-step-approval.json`
- `docs/qa/fixtures/v3/agent-step-plan/invalid/stale-checkpoint-auto-resume.json`
- `docs/qa/fixtures/v3/agent-step-plan/invalid/shadow-doc-new-docshell-runtime.json`
- `docs/qa/fixtures/v3/agent-step-plan/invalid/prompt-policy-public-egress-runtime.json`

### Fixture（agent-step-result-state active）

- `docs/qa/fixtures/v3/agent-step-result-state/valid/writer-patch-completed-running.json`
- `docs/qa/fixtures/v3/agent-step-result-state/valid/calc-review-awaiting.json`
- `docs/qa/fixtures/v3/agent-step-result-state/valid/impress-step-failed-recovery.json`
- `docs/qa/fixtures/v3/agent-step-result-state/valid/writer-hard-cancelled.json`
- `docs/qa/fixtures/v3/agent-step-result-state/invalid/patch-without-apply-runtime-validation.json`
- `docs/qa/fixtures/v3/agent-step-result-state/invalid/failed-step-mutates-main-doc.json`
- `docs/qa/fixtures/v3/agent-step-result-state/invalid/task-state-bypasses-cowork.json`

### Contract self-test（active）

`tests/v3-agent-step-plan-test.sh` is the W6 agent-step-plan self-test. It validates `docs/schemas/agent-step-plan.schema.json`, `docs/product/v3/w6-dependency-policy.md`, `docs/product/v3/w6-plan-validation-policy.md`, `docs/product/v3/w6-approval-policy.md`, `docs/product/v3/w6-resume-policy.md`, `docs/product/v3/w6-shadow-doc-policy.md`, `docs/product/v3/w6-prompt-library.md`, Writer/Calc/Impress fixture coverage, `maxSteps <= 25`, forward-only DAG dependencies, fan-in/fan-out coverage, fail-closed invalid Planner output semantics, whole-task approval default with explicit per-step opt-in, evidence-complete checkpoint resume semantics, SwDocShell-compatible ShadowDoc semantics, deterministic prompt policy, `shadow-doc` isolation, per-step policy/audit requirements, and V2 token-lock preservation (`ParagraphAction=7`, `CellAction=5`, `SlideElementAction=4`). It reports `Checks: 13` and is wired into `bin/v3-eval-sweep.sh --self-test`.

`tests/v3-agent-step-result-state-test.sh` is the W6 agent-step-result-state self-test. It validates `docs/schemas/agent-step-result.schema.json` and `docs/schemas/agent-task-state.schema.json`, completed/failed/cancelled result coverage, running/awaiting-review/failed/cancelled task-state coverage, `usesV2AsyncCowork`, `mainDocumentUnchanged`, approval-before-merge semantics, and `requiresApplyPlanRuntimeValidation`. It reports `Checks: 8` and is wired into `bin/v3-eval-sweep.sh --self-test`.

### Token lock 强制

H8 增量检查：每个 patch step 输出**必须**通过 V2 token lock 单测
（不允许 agent 绕开 ParagraphAction=7 / CellAction=5 / SlideElementAction=4）。

### 回归

- V1.5 27/27 ✅
- V2 H1-H7 ✅
- V3 H8 ✅
- W6 落地不引入 V2 token lock 退化（H6 baseline=39 不变）

---

## 8. Open Questions / Blockers

- ~~Q1：影子文档机制如何与 V2-W3 SwDocShell 兼容（是否需要新 docshell 类型）~~ **决议（W6 Q1）**：ShadowDoc 必须保持 `SwDocShell-compatible`，兼容 V2-W3 `SwDocShell` ApplyPlan 路径；契约阶段禁止新增 DocShell 类型、禁止审批前修改主文档、禁止声称 ShadowDoc runtime 已启动，详见 `docs/product/v3/w6-shadow-doc-policy.md`。
- ~~Q2：Plan 阶段 LLM 输出不符合 schema 时如何处理（重试 / 报错 / 简化）~~ **决议（W6 Q2）**：Planner output 必须在执行前通过 `agent-step-plan.schema.json`；invalid plan 走 `fail-closed-user-visible`，阻止执行、要求 invalid-plan evidence，禁止 silent retry / auto simplification，允许未来用户显式 retry；runtime Planner 仍 `not-started`，详见 `docs/product/v3/w6-plan-validation-policy.md`。
- ~~Q3：单步审批 vs 整体审批 UX（每步弹窗会很烦）~~ **决议（W6 Q3）**：默认 `whole-task` approval；`per-step` 仅允许来自 `explicit-user-choice`，禁止 implicit per-step prompts；每个有效计划仍必须有 review step 和 `user-approval` evidence；runtime approval UI 仍 `not-started`，详见 `docs/product/v3/w6-approval-policy.md`。
- ~~Q4：步骤依赖图是否允许 DAG（当前 schema 暗示线性）~~ **决议（W6 Q4）**：允许 forward-only DAG；每个 dependency 必须指向更早 step index，允许 fan-in/fan-out，禁止 cycle / future dependency / contract-only runtime parallelism；`dependencyPolicy.runtimeSchedulerImplementation=not-started`，详见 `docs/product/v3/w6-dependency-policy.md`。
- ~~Q5：长任务跨 session（用户关 app 再开）如何恢复~~ **决议（W6 Q5）**：允许 cross-session resume，但只能从 `evidence-complete-checkpoint` 恢复；必须用户确认、document hash 匹配、shadow snapshot 和 audit replay 输入齐全；禁止 auto resume，stale checkpoint 走 `fail-closed-user-visible`；runtime resume 仍 `not-started`，详见 `docs/product/v3/w6-resume-policy.md`。

---

## 9. 时间线（保守估算）

- Q3 2028 (4w)：Planner + Actor + Observer 骨架（无影子文档）
- Q3 2028 (4w)：Shadow doc + 单步隔离 + token lock 强制
- Q3 2028 (4w)：失败恢复 + 中止机制 + V2-W5 异步集成
- Q3-Q4 2028 (4w)：Per-step UI + 审批链路
- Q4 2028 (2w)：H8/H9 增量验证

总计：12–18 周。
