# V2 W5 Spec: 异步任务管理器（Cowork 风格委托）

Date: 2026-05-08
Wave: W5（V2 末波，持续）
Depends on: W1 (provider), W3 (Writer apply), W4 (Diff 审批)
Master plan: `../v2-master-plan.md`

## Scope

把 V2 从"实时工具"升级为"任务委托平台"——用户可以**发起一个长时任务**
（"做一份本周周报"），后台异步跑，完成时通知，返回 diff 让审批。
对标 Claude Cowork。

## In Scope

1. 任务队列（Task Queue）+ scheduler
2. 4 个前期场景模板：周报 / PPT 提纲生成 / 合同审阅 / 数据整理
3. 任务状态机（pending / running / awaiting-review / applied / cancelled）
4. 通知中心（macOS UNUserNotification / Windows toast）
5. 移动端 Companion（仅审批，不编辑；iOS/Android）
6. 跨设备 hand-off（桌面发起 → 手机审批）

## Out of Scope

- 不实现实时云协作（保留"本地优先"招牌）
- 不实现移动端编辑文档
- 不实现"自动应用，无需审批"模式（V2 永远要审批）
- 不实现复杂工作流编排（如循环 / 条件分支）

## Architecture

```
Desktop App                      Companion App (iOS/Android)
┌──────────────────────┐         ┌──────────────────────┐
│ Task Manager UI      │         │ Pending Reviews      │
│ ──────────────────── │  push   │ ──────────────────── │
│ ▶ 周报 (running 67%) │ ◄────── │ ☐ 周报 (60min ago)   │
│ ✓ 合同审阅 (done)    │         │ ▶ [审批] [拒绝]      │
│                      │         │                      │
│ [新建任务]            │         └──────────────────────┘
└──────────┬───────────┘                  ▲
           │                              │ approve
           │ task-spec                    │ via notification
           ▼                              │
   ┌────────────────────┐                 │
   │ Task Scheduler     │                 │
   │ (offline daemon)   │                 │
   │ ────────────────── │                 │
   │ 1. plan steps      │ ApplyPlan       │
   │ 2. call W1 N times ├────────────────►│
   │ 3. assemble plan   │                 │
   │ 4. mark await      │                 │
   └────────────────────┘                 │
                                          │
   ┌────────────────────┐                 │
   │ W4 Diff Review     │◄────────────────┘
   │ Sidebar / Mobile   │  user approves
   └─────────┬──────────┘
             │ run W3 apply
             ▼
        document updated
```

## File Map

### Desktop Task Manager

| 路径 | 类型 | 内容 |
|---|---|---|
| `kqoffice/source/cowork/TaskManager.cxx` | new | 队列 + scheduler |
| `kqoffice/source/cowork/TaskScenarios.cxx` | new | 4 个场景 |
| `kqoffice/source/cowork/Notification.cxx` | new | macOS/Windows 通知 |
| `kqoffice/source/cowork/CompanionSync.cxx` | new | 移动端同步 |
| `cui/source/dialogs/cowork/CoworkDialog.cxx` | new | "新建任务" 对话框 |
| `cui/uiconfig/ui/cowork-dialog.ui` | new | UI |
| `officecfg/registry/data/org/openoffice/Office/Cowork.xcu` | new | 配置（开关、扫描间隔等）|
| `kqoffice/qa/python/test_cowork.py` | new | 集成测试 |

### Companion App（独立项目）

W5 v1 Companion **不在本仓库实施**——单独 React Native / Flutter 项目，连接桌面端通过：

- 局域网 mDNS discovery
- 端到端加密 channel（如 Tailscale-style WireGuard 或 自建 mTLS）
- 拒绝公网连接（保留 offline-first 立场）

V2 范围内只做 desktop side 的 sync API。

## Task Schema

```json
{
  "task_id": "tk-20260508-001",
  "scenario": "weekly-report",
  "title": "本周周报",
  "status": "running",
  "created_at": "2026-05-08T14:00:00",
  "input": {
    "source_docs": [
      "file:///path/to/meeting1.odt",
      "file:///path/to/meeting2.odt"
    ],
    "user_prompt": "整理这两份会议纪要为周报，含决策、待办、风险。",
    "target_template": "Work_Report_CN.ott"
  },
  "steps": [
    {"step_id": "s1", "title": "提取决策", "status": "completed", "evidence": "ev-..."},
    {"step_id": "s2", "title": "提取待办", "status": "completed", "evidence": "ev-..."},
    {"step_id": "s3", "title": "组装周报", "status": "running"}
  ],
  "result_plan_id": null,
  "evidence_ids": ["ev-...", "ev-..."]
}
```

## 4 个前期场景

### 场景 1: 周报生成

**输入**：
- 1-N 份 Writer 文档（会议纪要 / 邮件 / 备忘）
- 用户 prompt（可选）
- 目标模板（默认 `Work_Report_CN.ott`）

**步骤**：
1. 扫描每份 source doc 提取 paragraph + 标记
2. 调 W1 capability="extract-decisions" 拿决策列表
3. 调 W1 capability="extract-todos" 拿待办列表
4. 调 W1 capability="assemble-report" 组装周报
5. 输出 ApplyPlan（创建新文档 + 填充段落）

**输出**：新 Writer 文档 in `~/Documents/可圈office/周报/<date>.odt`

### 场景 2: PPT 提纲 → PPT

**输入**：
- 1 份 Writer 文档（提纲）或 user prompt
- 目标模板（默认 `Business_Pitch_CN.otp`）

**步骤**：
1. 解析提纲为 PresentationOutline schema (V1.5 已有)
2. 调 W1 capability="outline-to-slides" 生成幻灯片结构
3. 输出 ApplyPlan（创建新 Impress 文档 + 填充幻灯片）

**输出**：新 Impress 文档

### 场景 3: 合同审阅

**输入**：
- 1 份 Writer 合同
- 用户角色（甲方 / 乙方）
- 用户关注点（可选 prompt，如"重点看违约条款"）

**步骤**：
1. 段落级扫描（W3 已有）拿到所有段落
2. 调 W1 capability="contract-risk" 逐段评估
3. 生成 ApplyPlan with 批注 patch（不改正文，加 annotation）
4. 加摘要文档

**输出**：原合同加 N 条批注 + 一份"风险摘要" Writer 文档

### 场景 4: 数据整理

**输入**：
- 1 份 Calc 表（脏数据）
- 用户 prompt（"把日期格式统一，去重，按部门排序"）

**步骤**：
1. 扫描列识别类型（W1 capability="detect-column-types"）
2. 生成清理 ApplyPlan（每列一个 patch）
3. 用户审批 → 应用

**输出**：原 Calc 表（已清理）

## 状态机

```
                ┌─────────────────────────────┐
                ▼                             │
  pending ─► running ─► awaiting-review ──┴── applied
              │           │                       
              ▼           ▼                       
           failed      cancelled                  
```

每次状态转换写 evidence。

## 通知

- macOS：UNUserNotification 推送 "周报任务完成，等待审批"
- Windows：Toast notification
- Linux：libnotify
- Companion App：APNs / FCM

通知点击 → 唤起 desktop app + 打开 Diff 审批 sidebar with relevant plan_id

## Companion 同步协议

发现：mDNS service `_kqoffice-cowork._tcp.local`

通信：每分钟轮询（companion → desktop）：

```http
GET /api/v1/tasks/awaiting-review HTTP/1.1
X-Pairing-Token: <secret>
```

返回：

```json
{
  "tasks": [
    {
      "task_id": "tk-20260508-001",
      "title": "本周周报",
      "scenario": "weekly-report",
      "summary": "提取了 12 个决策、8 个待办，组装为周报",
      "patch_count": 45,
      "preview_text": "本周完成了 ...",
      "approve_url": "/api/v1/tasks/tk-.../approve",
      "reject_url": "/api/v1/tasks/tk-.../reject"
    }
  ]
}
```

approve → desktop 拉起 W3 apply 流程。

## Cron 定时任务

支持"每周一上午 9 点自动跑周报任务"：

```json
{
  "schedule": "0 9 * * 1",
  "scenario": "weekly-report",
  "input": {
    "source_dir": "~/Documents/可圈office/会议纪要/",
    "since": "last-week",
    "target_dir": "~/Documents/可圈office/周报/"
  }
}
```

到点自动跑 → 完成时推通知（不直接应用，等用户审批）。

## evidence

完整的 task evidence chain：

```
TaskEvidence (W5)
  ├── StepEvidence × N (每步一条 ProviderRequest evidence from W1)
  ├── ApplyEvidence × M (每个 ApplyPlan 应用记录 from W3)
  └── ReviewEvidence × M (每次用户审批决策)
```

可在"任务历史"里查看每步耗时、token 用量、用户决策。

## 安全

- 默认所有 task 走 service mode `offline`（W1 同样默认）
- 切到 `cloud` 模式需用户对**每个 task** 单独确认
- Cron 任务**必须**走当前 service mode（不能为定时任务私自启用 cloud）
- Companion App 配对时需 desktop 显示 6 位 PIN，user 在 mobile 输入
- 配对后建立的 token 仅在该 LAN 有效；切 WiFi 失效

## Test Strategy

1. **Unit**：TaskManager 状态机；scheduler；4 个 scenario 单测
2. **Integration**：跑端到端 weekly-report 场景（mock provider response）
3. **End-to-End**：
   - 真 Ollama + 2 份 sample 会议纪要 → 跑周报 → 验证输出文档结构正确
4. **Companion**：mock companion client + 同步协议 contract test

## ROI Estimate

- 实施：8-16 周（4 scenarios × 2-4 周/each + companion 4 周）
- 用户感知：最高（"AI 帮我做完了"vs"AI 帮我建议"）
- 风险：高（长时任务调试难；user trust 是产品挑战）

## Stop Conditions

1. Ollama 在 7B 模型下做 4 步 chain 总耗时 > 5 分钟 → 改用更小模型 / 减步骤
2. Companion App pairing 协议在企业 LAN 下 mDNS 不可达 → 加手动 IP 配置
3. Cron 任务在用户睡觉时跑导致电量耗尽 → 限制只在插电时跑
4. 用户拒绝 task review > 80% → 说明 prompt 设计有问题，回 spec

## Day-0 Entry-Point Plan (skeleton)

> **Status**: planned. Mirrors the W1/W2/W4 Day-0 layout: minimum files
> to land the linkable surface so subsequent sub-steps can fan out
> without colliding. No real backend, no scheduler, no companion sync.

### Token lock (source-of-truth for Day-0 headers + schema)

These are the exact ASCII kebab-case tokens W5 Day-0 will hard-code into
the C++ enums, the JSON Schema enum lists, and the harness drift-lock
asserts. Locked here so spec wording, header tokens, and schema enum
strings can never disagree silently. `TaskState` mirrors the spec's
existing state-machine diagram at §"状态机" (six states; `awaiting-review`
is the standard term, **not** `needs-review`).

**`enum class TaskKind` — 4 tokens (one per scenario at §"4 个前期场景"):**

| Token | Scenario | Output target |
|---|---|---|
| `weekly-report`        | 场景 1 周报生成      | new Writer doc under `~/Documents/可圈office/周报/<date>.odt` |
| `outline-to-slides`    | 场景 2 PPT 提纲 → PPT | new Impress doc |
| `contract-review`      | 场景 3 合同审阅       | original Writer + N annotations + risk-summary Writer |
| `data-cleanup`         | 场景 4 数据整理       | same Calc workbook (cleaned in place) |

**`enum class TaskState` — 6 tokens (matches §"状态机" diagram exactly):**

| Token | Meaning | Valid next states |
|---|---|---|
| `pending`          | task accepted, queued                | `running`, `cancelled` |
| `running`          | provider/applier loop active         | `awaiting-review`, `failed`, `cancelled` |
| `awaiting-review`  | apply-plan ready, user not yet acted | `running` (refine) , `applied`, `cancelled` |
| `applied`          | apply-plan accepted + applied via W3 | terminal |
| `failed`           | provider error / apply error / abort | terminal |
| `cancelled`        | user-cancelled at any non-terminal   | terminal |

**Naming rules (locked):**
- Lowercase ASCII, kebab-case, no underscores.
- Past-participle for terminals (`applied`, `cancelled`, `failed`),
  present-participle / gerund for in-flight (`running`,
  `awaiting-review`, `pending`).
- TaskKind tokens never collide with W1 capability tokens; the
  capability tokens (`extract-decisions`, `extract-todos`,
  `assemble-report`, `outline-to-slides`, `contract-risk`,
  `detect-column-types`) are *function-level* and may be called by
  multiple TaskKinds. `outline-to-slides` is the one overlap and is
  intentional — the TaskKind directly maps to the single capability.
- Schema enum order matches the table order above; harness asserts
  exact-position match to lock against silent re-ordering.

### What lands in Day-0

1. **Task envelope contract (header-only)** — `kqoffice/source/ai/cowork/`
   - `AsyncTask.hxx`: `TaskKind` enum (`weekly-report |
     outline-to-slides | contract-review | data-cleanup`), `TaskState`
     enum (`pending | running | awaiting-review | applied | failed |
     cancelled`), `AsyncTaskEnvelope` struct (id / kind / state /
     created_at / payload_hash / evidence_id).
   - `TaskStateMachine.hxx`: header-only valid-transition table per the
     6×N matrix above; `bool TaskStateMachine::canTransition(from, to)`
     is the single point of truth used by both the C++ store and the
     drift-lock harness.
2. **Task store skeleton** — `kqoffice/source/ai/cowork/TaskStore.{hxx,cxx}`
   - JSON-on-disk persistence under
     `${UserInstallation}/ai-tasks/YYYY-MM/<task_id>.json`,
     mirrors EvidenceRecorder layout. Day-0 ships file write + read +
     list-by-state; no migration logic.
3. **Schema** — `docs/schemas/async-task.schema.json` (new):
   17-key envelope locked by JSON Schema 2020-12. Adds two fixtures
   (`async-task.valid.json` / `async-task.invalid.json`) so
   `tests/v2-plan-baseline-test.sh` baseline grows from 26/11 → 28/12.
4. **Pure-logic cppunit** — `kqoffice/qa/cppunit/test_cowork.cxx` (new
   file in existing `CppunitTest_kqoffice_provider` binary or a new
   `CppunitTest_kqoffice_cowork` per fdo#47246 hygiene): cases for
   state-machine transition validity, store round-trip, schema-vs-C++
   enum drift lock (mirrors `tests/v2-provider-evidence-schema-test.sh`).
5. **Drift lock harness** — extend
   `tests/v2-provider-evidence-schema-test.sh` (or a new
   `tests/v2-async-task-schema-test.sh`) to assert
   `TaskKind` / `TaskState` enum subset ⊆ schema, *and* schema enum
   order = table order above (catches silent re-ordering).

### Out of scope for Day-0

- Cron scheduler / wake-from-sleep / power-aware run.
- Companion App pairing (mDNS, manual IP fallback).
- Notification surface (sfx2 toast / system notification).
- Apply path: `applied` state requires W3 Day-1b; until then Day-0
  rejects `applied` transitions and leaves the task at `awaiting-review`
  (the single canonical pre-apply state per §"状态机").

### Verification gate for Day-0

- `make kqoffice.build` clean.
- `make CppunitTest_kqoffice_cowork` (or extended provider binary) green.
- `tests/v2-plan-baseline-test.sh` baseline updated: 28 fixtures across
  12 schemas, status passed, checks unchanged at 21.
- `tests/v2-provider-evidence-schema-test.sh` still passes (W1 schema
  contract untouched).
- V1.5 27/27 strict roundtrip baseline untouched.

### Authorization required before Day-0 starts

W5 lands inside `kqoffice/` (already on the V2 allow-list under
`kqoffice/source/ai/provider/` precedent) plus `docs/schemas/`. The
new `kqoffice/source/ai/cowork/` subdirectory is a sibling of an
authorized path; explicit confirmation that the V2 allow-list extends
to `kqoffice/source/ai/cowork/**` and `kqoffice/qa/cppunit/test_cowork*`
is needed before Day-0 begins. Schema + harness paths are
documentation-tier and don't need new authorization.

## Schema reader's manual

The W5 async-task envelope schema body lives at
`docs/schemas/async-task.schema.json`. A human-derivation guide
explaining *why* each property exists, the `TaskKind` 4-token /
`TaskState` 6-token enum rationale (note: state token is
`awaiting-review`, **not** `needs-review`), and the
failed-vs-cancelled distinction (failure_reason populated vs absent;
evidence_ids non-empty vs empty) lives at
`docs/schemas/async-task.schema.md`. Read the manual before
hand-deriving `kqoffice/source/ai/cowork/AsyncTask.hxx` or
implementing the cancel button on `TaskStore` — it captures the
state-machine intent that isn't recoverable from the schema body
alone.

Token-lock anchor: this spec's §"Token lock" subsection (above) is
the single source of truth the schema enums mirror. Drift is caught
by `tests/v2-async-task-schema-test.sh` (H4 partial-enforce;
auto-promotes to full-enforce when `AsyncTask.hxx` lands in SRCDIR).

## Dependencies

- W1：所有 LLM 调用
- W3：所有 apply 走 Writer Apply Runtime
- W4：审批 UI 复用 Diff sidebar
- 现有：`docs/schemas/{apply-plan,evidence-record,intelligent-diagnostic}.schema.json`

## Acceptance Criteria

W5 v1（仅周报场景 + 桌面）：

- [ ] "新建任务"对话框可见
- [ ] 选 "周报" + 2 份 sample doc → 触发任务
- [ ] 任务状态 pending → running → awaiting-review
- [ ] 完成时 macOS 通知出现
- [ ] 点击通知 → 桌面 Diff sidebar 弹出 with plan
- [ ] 用户接受 → W3 apply → 新 Writer 文档生成
- [ ] evidence 文件链路完整
- [ ] 拒绝任务后文档不动

W5 v2（4 scenarios + companion）单独立项。

## V2 收官

W5 v1 完成时，可圈office V2 完整理念已交付。
后续 V2.x 持续完善 W5 + 其它 scenario。
V3 路线由那时再制定。
