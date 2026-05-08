# V2 Master Goal Brief: AI 一等公民 (AI-Native Office)

## User Intent

V1 + V1.5 已完成（功能可信 + 中文化 + 视觉低悬果 + 8/9 beta gate pass）。
现在开启 **V2: AI 一等公民** 完整规划阶段——把"AI 助手"从"贴皮聊天框"升级为
"嵌入文档对象模型的一等公民"，对标 2026 年 Word Copilot / WPS AI / Notion AI / Cursor，
但保留 可圈office 的差异化定位：**离线优先 / 文档级可信 / 无静默上传**。

## Success Criteria

1. **完整 V2 master plan** 写入 `docs/product/v2-master-plan.md`，覆盖 5 个 wave + 时间线 + 风险
2. **5 个 wave spec** 各自有独立设计文档：
   - W1: Provider Runtime (本地 Ollama 优先)
   - W2: Cmd+K 命令调色板（自然语言入口）
   - W3: Writer Apply Runtime（智能分析器从 preview-only 升级）
   - W4: Select-to-Act 浮窗 + Diff 审批视图（结构化交互范式）
   - W5: 异步任务管理器（Cowork 风格委托工作流）
3. **每个 spec 含**：scope、文件层 file map、UNO/dispatch 接口、契约 schema 引用、
   测试策略、安全/隐私 policy、ROI 评估、依赖拓扑
4. **不写代码**：全部是规划与设计文档（V2 实施在后续 round）
5. **所有文档入仓 commit**（goal G6 一次性 commit）

## Constraints / Non-Goals

- 不实施任何 V2 代码（实施另立项）
- 不破坏 V1 + V1.5 既有 8/9 beta gate
- 不假装云协作（保留"本地优先"招牌）
- 不引入新的硬编码字体/颜色（与 V1.5 一致）
- 不破坏现有 contracts/schemas（在其上扩展，非 fork）
- 不写超过 4000 字的单 spec（保持可读性）

## Recommended Execution Strategy

按 G1 → G7 依序：先 master plan 立架，再 5 个 wave spec 并行起草（可派 4 路 subagent），
最后写 changelog + commit。

预估：1 master plan + 5 wave specs + 1 commit = ~7 个文档 ≈ 15-20K 字总量。
