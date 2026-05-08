# 可圈office V2 Master Plan: AI-Native Office

Date: 2026-05-08
Status: Planning (V2 implementation not started)
Predecessor: V1.5 完成 (`docs/product/v1.5-completion-milestone.md`)
Goal artifact: `.agent/goals/2026-05-08-v2-ai-native/`

## 1. North Star

V1 让 可圈office 成为**可信中文办公套件**；V1.5 把视觉提升到接近 WPS。
**V2 的目标是把 AI 从"贴皮聊天框"升级为"嵌入文档对象模型的一等公民"**——
对标 2026 年 Word Copilot / WPS AI / Notion AI / Cursor，但保留我们的差异化定位：

| 维度 | 主流国产/海外做法 | 可圈office V2 立场 |
|---|---|---|
| AI 推理位置 | 默认云端 | **本地优先** (Ollama / llama.cpp / MLX)，云为可选 |
| 文档上传 | 静默上传全文做 RAG | **不静默上传**；任何外发数据需用户显式同意 + evidence 记录 |
| 协作模式 | 实时云协作 | **本地文件优先**；移动端 companion 仅做"审批"不做"编辑" |
| AI 输出粒度 | 整段重写 | **段落 / 单元格 / 幻灯片对象**结构化 patch (基于 ApplyPlan schema) |
| 撤销机制 | 用户自己 Cmd+Z | **AI 操作 = 事务**，逐项可撤销 + 全局回滚 |
| 信任模型 | 输出即生效 | **预览 → 审批 → 应用 → evidence 记录**四步管线 |

V2 完成时，用户应当感受到：

- 选中段落 / 单元格 / 对象 → 浮出 AI 动作气泡（"改写"/"扩写"/"翻译"/"清理格式"）
- Cmd+K 输入"把这个表的 A 列改成日期格式" → 直接执行（不打开对话框）
- 委托"根据我的会议纪要做一个 PPT 初稿" → 异步跑 → 完成时通知，返回 diff 让我审批
- 整个过程不需要登录账号、不需要联网、不向第三方泄露文档内容

## 2. V2 Wave 拓扑

```
                 G1: Master Plan
                       │
         ┌─────────────┼─────────────┐
         │             │             │
       W1 Provider     W2 Cmd+K      W3 Writer Apply
       Runtime         Palette       Runtime
       (2-4w)          (2-3w)        (4-6w)
         │             │                 │
         └─────────────┼─────────────────┘
                       │
                  W4 Select-to-Act
                  + Diff 审批视图
                  (6-8w)
                       │
                  W5 Async Cowork
                  (持续 8-16w)
```

依赖关系：

- **W1 是基座**：所有 LLM 调用走 provider runtime；其它 wave 不能绕开
- **W2 与 W3 可并行**：W2 v0 不接 LLM（纯模糊匹配），W3 复用 W1
- **W4 必须在 W3 之后**：Select-to-Act 浮窗调用 Writer Apply Runtime
- **W5 跨 wave 集成**：调度 W3 + W4 提供的 apply / preview 能力做长时任务

## 3. Wave 概要

### W1: Provider Runtime（2-4 周）

**目标**：所有 LLM 调用走统一管线。本地 Ollama 默认 provider。

**关键决策**：
- 不内置 provider 实现，通过 UNO service `com.kdoffice.AI.Provider` 接入
- `provider-request.schema.json` 已存在，复用
- Service Mode 三档：`offline`（默认，仅本地）/ `private`（企业自部署）/ `cloud`（用户显式启用）
- 每次请求记 evidence（耗时 / token / 状态码 / 来源 IP / 用户审批 hash）

**文件层**：`docs/product/v2/w1-provider-runtime-spec.md`

### W2: Cmd+K 命令调色板（2-3 周）

**目标**：自然语言入口替代菜单导航。

**两阶段**：
- v0：自然语言 → SfxDispatcher slot fuzzy match（不接 LLM，毫秒级响应）
- v1：v0 不命中时降级到 LLM 解析（走 W1 provider）

**示例**：
- "插入图片" → `.uno:InsertGraphic`
- "把这一段加粗" → `.uno:Bold` (with selection)
- "插入题注" → `.uno:InsertCaption`

**文件层**：`docs/product/v2/w2-cmd-palette-spec.md`

### W3: Writer Apply Runtime（4-6 周）

**目标**：把 V1 已有的 `IntelligentWriterAnalyzer` (preview-only) 升级为 apply。

**关键改动**：
- 新增 `SwDocShell::applyDiagnosticsPlan(const ApplyPlan&)`
- 段落级回滚（每个 patch 独立 undo entry）
- evidence 记录前后状态 hash

**复用**：
- `docs/architecture/engine-capability-writer-apply-guardrail-m3-04.md`
- `docs/schemas/apply-plan.schema.json`

**文件层**：`docs/product/v2/w3-writer-apply-runtime-spec.md`

### W4: Select-to-Act 浮窗 + Diff 审批视图（6-8 周）

**目标**：选中即操作，预览即审批，应用即可撤销。

**三模块**：
- **浮窗**：vcl 上下文菜单挂载 + 按 surface 注册动作（Writer 段落 / Calc 单元格 / Impress 对象）
- **Diff 视图**：sfx2 sidebar 容器扩展，复用 IntelligentWriterAnalyzer 数据结构
- **审批管线**：accept / reject / undo / 一键全撤销

**文件层**：`docs/product/v2/w4-select-to-act-spec.md`

### W5: 异步任务管理器（持续 8-16 周）

**目标**：Cowork 风格委托工作流。

**前期场景**：
- "把这周的会议纪要整理成周报" → 异步执行 → 通知
- "根据这份大纲做一个商务路演 PPT" → 长任务 → diff 审批
- "审阅这份合同找出风险点" → 报告 + 标注

**移动端 Companion**：仅做任务发起 + 审批，不做编辑（避免假装移动端 office）

**文件层**：`docs/product/v2/w5-async-cowork-spec.md`

## 4. 时间线（保守估算）

| 阶段 | 月份范围 | 内容 |
|---|---|---|
| Q3 2026 | W1 + W2 v0 | Provider Runtime 壳；Cmd+K 模糊匹配 |
| Q4 2026 | W2 v1 + W3 | Cmd+K LLM 增强；Writer Apply Runtime |
| Q1 2027 | W4 | Select-to-Act 三粒度 + Diff 视图 |
| Q2 2027 | W5 起步 | 异步任务 v1：周报场景 |
| Q3-Q4 2027 | W5 深化 | PPT 生成 / 合同审阅 / 移动端 Companion |

每个 wave 完成时刷新 Beta-hard gate（保留 V1.5 既有 8/9 不退化）。

## 5. 风险登记

| 风险 | 等级 | 缓解 |
|---|---|---|
| 本地 LLM 性能不足（M1 Mac 跑 7B 模型卡顿） | 高 | W1 内置 model size guidance；推荐 Qwen-2.5-3B / Phi-3.5 |
| ApplyPlan schema 不够覆盖 Calc 单元格批量改 | 中 | W3 设计阶段 spike 验证；必要时扩展 schema |
| VCL 上下文菜单基础设施不支持挂载 AI 动作 | 中 | W4 spec 阶段做技术 spike；备选方案：sfx2 sidebar 动作栏 |
| Cowork 异步任务 user 不信任（怕"AI 自己改了什么不知道"） | 高 | W5 默认所有 apply 必须 diff 审批；evidence 默认开 |
| 与上游 LibreOffice 越走越远 | 中 | 每个 wave 末尾做 rebase 评估；优先复用 UNO service 而非 fork |
| 隐私合规（本地 LLM 但企业部署可能要求审计） | 中 | W1 service-mode policy 内置审计 hook |

## 6. Non-Goals (V2 不做)

- ❌ 自建 LLM 模型（用现成 Ollama / 云 API）
- ❌ 实时云协作（飞书 / 腾讯文档式）
- ❌ 移动端文档编辑（仅 Companion 审批）
- ❌ AI 全自动决策（始终人审批）
- ❌ Browser-based version（保留桌面优先）
- ❌ 改 VCL 渲染层做 hover/动效（V1.5 同样约束）

## 7. V1.5 衔接

V1.5 已交付的 V2 基础设施：

- `docs/architecture/intelligent-office-contracts.md`
- `docs/architecture/engine-capability-platform-architecture.md`
- `docs/architecture/engine-capability-writer-apply-guardrail-m3-04.md`
- `docs/schemas/{apply-plan,capability-registry-entry,document-snapshot,evidence-record,intelligent-diagnostic,kqoffice-plugin,presentation-outline,preview-action,provider-request}.schema.json`
- `sw/inc/IntelligentWriterAnalyzer.hxx` + `sw/source/core/doc/IntelligentWriterAnalyzer.cxx` (preview-only)
- `bin/plugin-manifest-validator.sh`
- 18 contract fixtures pass

V2 不重新设计契约，**只把契约落地为运行时**。

## 8. 验证策略

每个 wave 必须满足：

1. 设计阶段：spec 文档审阅通过
2. 实施阶段：单测（CppunitTest_*）+ 契约 fixture（保留 18 fixture）+ GUI smoke
3. 集成阶段：v2-beta-gates 8/9 不退化
4. 体验阶段：操作员实测 + 截图证据 + 录屏

## 9. 度量与决策门

每个 wave 启动前需回答：

- ROI：相比 V1.5 用户增益是否清晰？
- 安全：失败时文档是否 unchanged？evidence 是否完整？
- 兼容：与 V1.5 既有 27/27 兼容性测试是否冲突？
- 上游：是否引入与 LibreOffice 主线无法共存的改动？

如任一答案不通过，wave 标 `Blocked`，回 spec 阶段重审。

## 10. 文档索引

| 文档 | 范围 |
|---|---|
| **本文 (v2-master-plan.md)** | 总体架构 / 时间线 / 风险 |
| `v2/w1-provider-runtime-spec.md` | Provider runtime + service mode |
| `v2/w2-cmd-palette-spec.md` | Cmd+K 命令调色板 |
| `v2/w3-writer-apply-runtime-spec.md` | Writer apply runtime |
| `v2/w4-select-to-act-spec.md` | Select-to-Act 浮窗 + Diff 视图 |
| `v2/w5-async-cowork-spec.md` | 异步任务管理器 |

V2 实施时各 wave 单独立项 (`.agent/goals/v2-w<N>-<topic>/`)，本文档不再重复细节。
