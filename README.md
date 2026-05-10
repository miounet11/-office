# 可圈office

可圈office 是面向中文办公场景定制的 office 套件，定位"**本地优先、文档级可信、无静默上传**"的 AI 办公软件。本仓库用于持续构建和验证 macOS 与 Windows 安装包。

## 项目愿景

把 AI 从"贴皮聊天框"升级为"嵌入文档对象模型的一等公民"，对标 2026 年 Word Copilot / WPS AI / Notion AI，同时保留差异化：

- **本地优先**：默认走 Ollama / llama.cpp / MLX，云端可选且需用户显式启用
- **不静默上传**：任何外发数据需用户显式同意 + evidence 记录
- **结构化 patch**：AI 输出落到段落 / 单元格 / 幻灯片对象级别，而非整段重写
- **AI 操作即事务**：预览 → 审批 → 应用 → evidence 记录四步管线，逐项可撤销

## 里程碑状态

| 阶段 | 状态 | 关键交付 |
| --- | --- | --- |
| V1 (MVP 可信中文办公套件) | 完成 | Writer/Calc/Impress/Draw 启动稳定；27/27 strict roundtrip；30k+ zh-CN msgid；中文场景模板 11/11 |
| V1.5 (视觉低悬果) | 完成 | 中文优先字体替换；SVG 图标主题；Sidebar 顺序重排；Workbench 任务卡片；Beta-Hard 8/9 通过 |
| V2 (AI 一等公民) | Spec 完成 · Day-1 实施中 | 5 wave spec 已落档于 `docs/product/v2/`；W1/W2/W3 Day-1 多步落地（77 cppunit 用例绿）；规划与进度见 [`docs/product/v2-master-plan.md`](docs/product/v2-master-plan.md) + [`docs/product/v2/lane-status.md`](docs/product/v2/lane-status.md) |

详细完成度与遗留问题：[`docs/product/v1.5-completion-milestone.md`](docs/product/v1.5-completion-milestone.md)

## V2 AI 路线图

| Wave | 范围 | 估算 | Spec |
| --- | --- | --- | --- |
| W1 | Provider Runtime（本地 Ollama 优先 + service mode 三档） | 2-4 周 | [`v2/w1-provider-runtime-spec.md`](docs/product/v2/w1-provider-runtime-spec.md) |
| W2 | Cmd+K 命令调色板（自然语言 → SfxDispatcher） | 2-3 周 | [`v2/w2-cmd-palette-spec.md`](docs/product/v2/w2-cmd-palette-spec.md) |
| W3 | Writer Apply Runtime（preview-only → apply + 段落级回滚） | 4-6 周 | [`v2/w3-writer-apply-runtime-spec.md`](docs/product/v2/w3-writer-apply-runtime-spec.md) |
| W4 | Select-to-Act 浮窗 + Diff 审批视图 | 6-8 周 | [`v2/w4-select-to-act-spec.md`](docs/product/v2/w4-select-to-act-spec.md) |
| W5 | 异步任务管理器（Cowork 风格委托） | 持续 8-16 周 | [`v2/w5-async-cowork-spec.md`](docs/product/v2/w5-async-cowork-spec.md) |

总览：[`docs/product/v2-master-plan.md`](docs/product/v2-master-plan.md)

## 下载安装包

安装包通过 GitHub Actions 手动生成：

1. 打开仓库的 **Actions** 页面。
2. 选择 **Build installers** workflow。
3. 点击 **Run workflow**。
4. 在 `target` 中选择：
   - `both`：同时生成 macOS 和 Windows 安装包
   - `macos`：只生成 macOS 安装包
   - `windows`：只生成 Windows 安装包
5. （可选）保持 `upload_logs: true`，构建失败时也会上传日志，便于排查。
6. 构建完成后，在 workflow run 的 **Artifacts** 中下载：
   - `kdoffice-macos-installers`：macOS 安装包（`.dmg` / `.pkg`，可能附带构建归档）
   - `kdoffice-windows-installers`：Windows 安装包（`.msi`，可能附带相关安装组件）
   - `kdoffice-macos-logs` / `kdoffice-windows-logs`：构建日志（当 `upload_logs=true` 时）

## 当前平台状态

| 平台 | GitHub 构建入口 | 产物 |
| --- | --- | --- |
| macOS | `Build installers` → `target: macos` | `.dmg` / `.pkg` |
| Windows | `Build installers` → `target: windows` | `.msi` |
| macOS + Windows | `Build installers` → `target: both` | 同时上传两组 artifacts |

当前 workflow 默认生成未签名安装包，适合内部测试和验证。正式发布前还需要接入 macOS Developer ID 与 Windows 代码签名证书。

## 本地开发说明

本仓库是 LibreOffice 风格的可圈office 构建树。常用命令见 [`clavue.md`](clavue.md) 与 [`AGENTS.md`](AGENTS.md)。AI / 智能办公契约与 schema 见 `docs/architecture/` 与 `docs/schemas/`。
