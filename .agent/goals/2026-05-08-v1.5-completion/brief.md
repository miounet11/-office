# Goal Brief: V1.5 收官 + 长治建设

## User Intent

按用户指令"继续 用你认为最好的方案 持续开发下去 直至全部结束"，把 V1.5 视觉重设计阶段的剩余工作收尾，并把会话中临时修补的工程债转为长期可用的代码改动。最终目标：让 可圈office 在 zh-CN UI 上可重复 build、视觉提升落地、所有改动 commit 入仓。

## Success Criteria

1. Workbench Start Center 任务卡片实现（cxx + ui）— 11 个中文场景按钮可点击触发
2. L10N pipeline 长治：修 `gb_Configuration_add_localized_data` 让 registry_zh-CN.list 自动生成（不再手补）
3. ASCII workdir watchdog 永久化：写成 `bin/build-zh-cn.sh` 包装脚本（自动跑 watchdog + build）
4. 所有改动 commit：autogen.lastrun / Configuration.mk / VCL.xcu / Common.xcu / Sidebar.xcu / smoke-manifest.tsv / 新增 bin/* / docs/* / .agent/* 入仓
5. 重新 build + screenshot 验证最终视觉效果

## Constraints / Non-Goals

- 不动 VCL 渲染层（按钮造型 / hover / 动效 — VCL 改动 ROI 太低）
- 不引入新外部依赖
- 不改变 Beta-hard gate 的 9 项判定逻辑
- 不破坏现有 27/27 兼容性 roundtrip
- 不动 Beta blocker（live a11y 仍是人工任务）

## Recommended Execution Strategy

按 G1 → G6 依序，每完成一个 goal 验证 + 写 ledger event。中途如发现某 goal 必须 cxx debug + 测试时长超出预算，标 `blocked` 并记原因。

最大时间敏感项是 build（每次 ~3-5 分钟增量）。pipeline 修复 + cxx 改动需要 1-2 次 build verify。

总预估：5 个 build cycle + 1 commit。
