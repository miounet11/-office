# Live Accessibility Review Runbook

为 `bin/workbench-a11y-live.sh` 提供操作员手册。脚本只产 evidence，**不能替代人工验证**。

## 启动前准备

- App: `test-install/可圈office.app` 已可启动（GUI smoke 通过）。
- 关闭其它窗口避免 VoiceOver/键盘焦点干扰。
- 命令：

  ```bash
  bin/workbench-a11y-live.sh
  ```

- 中途按 Ctrl+C 会写出 partial evidence，下次重跑从头开始（不支持 resume，每次是完整一轮）。

## VoiceOver

- 开关：`Cmd+F5`，或系统设置 → 辅助功能 → VoiceOver。
- 检查每控件读出：名称 / 角色（按钮/列表/输入框）/ 状态（选中/禁用）/ 中文清晰。
- 焦点跑到系统弹窗时，先恢复到 可圈office 再继续记结果。

## 高对比度

- 系统设置 → 辅助功能 → 显示 → Increase Contrast 勾选；视情况启用 Invert Colors。
- 检查焦点环、按钮边界、警告色、禁用态可辨。
- 测后恢复设置再进下一项。

## Resize

- 拖窗口到极窄（≤ 600px）+ 极矮（≤ 400px）。
- 允许装饰性内容裁切；**不允许**主要入口、focus target、说明文字不可达。

## Missing-Template Fallback

- 关闭 可圈office。
- 临时移走 `test-install/可圈office.app/Contents/Resources/template/` 下任一 `.ott`（记原位置）。
- 重开 Start Center，看是否给出可读的 fallback（不是空白/崩溃）。
- 测完恢复模板。

## 24 项 = 6 surface × 4 lane

| Surface | 对应 evidence 模板项 |
|---|---|
| Start Center | 第 1-4 |
| Writer blank document | 第 5-8 |
| Calc filters | 第 9-12 |
| Impress new presentation | 第 13-16 |
| Draw blank drawing | 第 17-20 |
| Template/workbench fallback state | 第 21-24 |

## abort 条件

- App 崩溃 / 无法启动 / 无法获焦 → fail + 停止（不要继续余下项目）。
- VoiceOver 完全无法读主窗口 → fail。
- 高对比度下主要文字/按钮不可辨 → fail。
- Resize 后主要入口不可达且无替代路径 → fail。

跑完后 `tmp/product-completion/live-accessibility-proof.md` 自动更新；Verdict 中 `Accessibility claim allowed: yes` 仅当 24/24 全 pass 才生效。
