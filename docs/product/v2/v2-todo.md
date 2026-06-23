# V2 AI-native — TODO Backlog (刷新于 2026-06-11, ledger=L242)

> 配套 `v2-completion-roadmap-2026-05-13.md`。
> 完成一项就把 `[ ]` 改成 `[x]` 并在末尾标 `→ Lxx`。
> 产品源码 gated 项已在 L108-L176 大批落地；后续重点是 Windows toast/manual、归档提交和 release policy。

## 立即可逆（coord 自己能跑，不需要授权）

### 探针 / 现状捕获

- [x] **W3.A** wrapper 下重跑 `make PKG_CONFIG=/tmp/kqoffice-pkgconf-utf8 CppunitTest_sw_apply_engine`，把全量 link 错误存到 `tmp/w3-apply-link-survey.log` → L102（target 未注册，需要 D1 sub-step 加 sw/CppunitTest_sw_apply_engine.mk + Module_sw.mk）
- [x] **W4.A** wrapper 下逐一跑 3 个 surface cppunit（`CppunitTest_sw_inline_actions` / `CppunitTest_sc_inline_actions` / `CppunitTest_sd_inline_actions`），输出 `tmp/w4-link-survey.log`，按 surface 分类 missing symbol → L102（sw=compile fail D1 共享；sc/sd=link fail SC_DLLPUBLIC/SD_DLLPUBLIC 缺失）
- [x] **W2.A** wrapper 下跑 4 个 commandpalette cppunit（index / fuzzy / recent / controller），输出 `tmp/w2-cppunit-survey.log`，确认 controller 是否仍因外部 dep 卡住 → L102（4/4 [build CUT]，OK(8)+OK(8)+OK(10)+OK(7) = OK(77)→OK(84) workdir 闭合）
- [x] **W1.A 调研** grep `Provider::listCapabilities` 调用方与 ServiceModePolicy allowlist，写 `tmp/w1-listcap-survey.md` → L103
- [x] **W1.B 调研** 找 `Provider::call` 时间测量插入点（`osl_getSystemTime` 前后），写 `tmp/w1-duration-survey.md` → L103
- [x] **Product-entry static smoke** 增强 `bin/v2-w4-smoke*.sh`：默认 `PARALLELISM=2`，Error 137 资源杀自动串行重试；`v2-w4-smoke-installdir.sh` 验证 app bundle 中 provider / CommandPalette / Cowork / Select-to-act / DiffReview 入口和 UI 资源 → L126
- [x] **H8 product-entry gate** 新增 `tests/v2-product-entry-smoke-test.sh` 并接入 `bin/v2-harness-sweep.sh`，把 L126 静态入口 smoke 固化为 H8=14 → L127
- [x] **H8 CI/artifact guard**：H8 在 CI 下不再误触发 `make test-install`；需 macOS 或 `KDOFFICE_APP_BUNDLE` 预构建 bundle → L129
- [x] **App launch smoke**：真实 `可圈office.app/Contents/MacOS/soffice --headless --terminate_after_init` 在隔离 profile + AI runtime env 下启动退出 0，且先跑 H8 静态 bundle 入口检查 → L147
- [x] **Writer document smoke**：真实 app bundle 在隔离 profile 下将 UTF-8 文本文档经 Writer filter 转为 ODT，并解包验证正文内容；artifact=`tmp/v2-writer-document-output.odt` → L148
- [x] **Suite document smoke**：真实 app bundle 覆盖 Writer txt→ODT、Calc CSV→ODS、Impress ODP→PDF、Impress PPTX→ODP，并验证四个稳定 artifact → L149
- [x] **User-entry chain smoke**：安装包内 CommandPalette/Cowork 命令、Cmd+Shift+K/T 快捷键、Cowork 菜单、DiffReviewDeck、V2 UI 控件和 SRCDIR SFX/registry anchors 形成闭环；report=`tmp/v2-user-entry-smoke.md` → L150
- [x] **Live UNO dispatch smoke**：真实 app-bundle 进程 + UNO socket + bundled pyuno 打开 hidden Writer frame，queryDispatch 解析 CommandPalette/Cowork/PropertyDeck/DiffReviewDeck，并执行非 modal PropertyDeck + CommandPalette；report=`tmp/v2-uno-dispatch-smoke.md` → L151
- [x] **Suite-surface UNO dispatch smoke**：真实 app-bundle 进程 + UNO socket + bundled pyuno 分别打开 hidden Writer/Calc/Impress frame，逐 surface queryDispatch 解析 CommandPalette/Cowork/PropertyDeck/DiffReviewDeck，并执行非 modal PropertyDeck + CommandPalette；report=`tmp/v2-suite-dispatch-smoke.md` → L152
- [x] **GUI readiness/install-route parity smoke**：osascript/System Events/AX 可用，记录 visible LaunchServices route 到 `/Applications/可圈office.app`，并证明该可见包缺 V2 entry parity 而 builddir `instdir` 包具备；report=`tmp/v2-gui-readiness-smoke.md` → L153
- [x] **Visible current-bundle launch/resource smoke**：用 `open -n` 启动当前 builddir `instdir/可圈office.app` 的独立实例，证明当前包 V2 entry parity 与 builddir `soffice` 进程启动；L154 未绑定同名进程 GUI 归因的菜单/快捷键 claim 已由 L155 修正；report=`tmp/v2-visible-current-bundle-smoke.md` → L154
- [x] **Strict current-bundle PID-attribution gate**：`bin/v2-visible-current-bundle-smoke.sh` 传入新启动的 builddir pid，只在 System Events/AX 暴露精确目标 pid 且该 pid 有 menu bar 时才驱动 Writer menu + Cmd+Shift+K；当前 report=`tmp/v2-visible-current-bundle-smoke.md` 为 `Status: blocked`，2 passed / 5 blocked / 0 failed → L155
- [x] **Direct-launch PID-attribution stabilization**：`bin/v2-visible-current-bundle-smoke.sh` 改为直接启动当前 builddir `Contents/MacOS/soffice`，使用 isolated `UserInstallation` profile 并等待新 builddir pid，避免 `open -n` / bundle-id 路由到既有 `/Applications` 实例；当前仍为 `Status: blocked`，2 passed / 5 blocked / 0 failed → L156
- [x] **Native AX-by-PID current-bundle menu click-through**：`bin/v2-visible-current-bundle-smoke.sh` 改用 `AXUIElementCreateApplication(pid)` 精确绑定当前 builddir pid，验证 menu/window attribution，并通过 AXPress 点击 File > New > Text Document；当前 `Status: blocked`，6 passed / 1 blocked / 0 failed，仅 Cmd+Shift+K shortcut injection 仍 open → L157
- [x] **Visible CommandPalette UNO/AX current-bundle proof**：`bin/v2-visible-current-bundle-smoke.sh` 在同一个 visible Writer frame 上通过 UNO dispatch 打开 `.uno:CommandPalette`，并在同一 builddir pid 的 AX tree 中验证 CommandPalette/search/results 节点；当前 `Status: blocked`，`Target attribution: ready`，8 passed / 1 blocked / 0 failed，仅物理 Cmd+Shift+K shortcut injection 仍 open → L158
- [x] **Physical Cmd+Shift+K visible CommandPalette proof**：Writer-family module `K_SHIFT_MOD1` en-US override 从 `.uno:SmallCaps` 改为 `.uno:CommandPalette`，重建 `officecfg.build postprocess.build` 后，当前 builddir visible smoke 通过 native CGEvent 发送 Cmd+Shift+K 并在同一 pid 验证 CommandPalette/search/results AX 节点；当前 `Status: passed`，`Target attribution: ready`，9 passed / 0 blocked / 0 failed → L159
- [x] **Physical Cmd+Shift+T visible Cowork dialog proof**：`bin/v2-visible-cowork-smoke.sh` 直接启动当前 builddir app、native AX-by-PID 精确绑定同一 pid，通过 native CGEvent 发送 Cmd+Shift+T，并验证 `异步任务`、`btn_new_task`、`btn_accept_task`、`task_list_view` AX 节点；当前 `Status: passed`，`Target attribution: ready`，5 passed / 0 blocked / 0 failed → L160
- [x] **恢复 current-builddir AX window/menu 归因**：L162 复验恢复通过；`V2_APP_LAUNCH_TIMEOUT=15 bash bin/v2-app-launch-smoke.sh` 为 `Status: passed`（3 passed / 0 blocked / 0 failed），`V2_VISIBLE_CURRENT_READY_TIMEOUT=30 bash bin/v2-visible-current-bundle-smoke.sh` 为 `Status: passed`（10 passed / 0 blocked / 0 failed，`Target attribution: ready`），`V2_VISIBLE_COWORK_READY_TIMEOUT=35 bash bin/v2-visible-cowork-smoke.sh` 为 `Status: passed`（6 passed / 0 blocked / 0 failed，`Target attribution: ready`）→ L162
- [x] **Visible Writer Select-to-act click-through**：普通 Writer 文本选区通知已接入 `OnWriterSelectionChanged`，`bin/v2-visible-select-to-act-smoke.sh` 证明当前 builddir pid、真实 Writer 文本选区、`SelectToActPopover`/Rewrite/Expand/Shorten AX 节点、Rewrite 点击和点击后 dispatch 证据；当前 `Status: passed`（9 passed / 0 blocked / 0 failed）→ L163
- [x] **Visible DiffReview Accept/Reject click-through**：`bin/v2-visible-diff-review-smoke.sh` 在精确 current-builddir pid 上证明 Writer Rewrite 应用、`DiffReviewPanel`/`btn_accept`/`btn_reject`、Accept undo 回原文、Reject 移除 patch row 与按钮失效；当前 `Status: passed`（16 passed / 0 blocked / 0 failed）→ L164
- [x] **Visible DiffReview real Ollama provider click-through**：`V2_VISIBLE_DIFF_REVIEW_REAL_PROVIDER=1 bin/v2-visible-diff-review-smoke.sh` 在精确 current-builddir pid 上证明 Rewrite 点击走真实 Ollama provider（`provider=ollama: qwen3:0.6b`, `status=ok`, `capability=rewrite`），并继续打开 DiffReview、应用改文、Accept undo、Reject 清 row；当前 `Status: passed`（18 passed / 0 blocked / 0 failed）→ L169
- [x] **Writer Select-to-act UITest zero-skip**：`UITest_sw_select_to_act` 的 UNO factory 与 `writer_edit` reachability smoke 均改走 `load_empty_file("writer")` 并真实运行；targeted UITest `Tests skipped: 0`，全量 UITest `Ran 3 tests` / `OK` / `skipped=0`，Start Center creation-path root cause 后续由 L174 关闭 → L170-L171
- [x] **Calc/Impress Select-to-act UITest factory-window coverage**：新增并注册 `UITest_sc_select_to_act` / `UITest_sd_select_to_act`，均通过 `load_empty_file()` 验证文档类型和主编辑窗口控件；两套 target 均 `Ran 3 tests` / `OK` / `skipped=0` → L172
- [x] **Calc/Impress visible Select-to-act click-through**：新增 `bin/v2-visible-suite-select-to-act-smoke.sh`，精确 current-builddir pid 绑定，证明 Calc `CellRangePopover` / Impress `SlideElementPopover`、动作按钮、真实鼠标点击和点击后 popover 关闭；当前 `Status: passed`（16 passed / 0 blocked / 0 failed）→ L173
- [x] **Start Center Writer creation-path svp root cause**：`vcl` UITest completion idle 从 `LOWEST` 提升到 `DEFAULT`，`UITest_demo_ui` Start Center repro 通过，`UITest_sw_select_to_act` 新增 Start Center Writer smoke 并通过 `Ran 4 tests` / `OK` / `skipped=0` → L174
- [x] **H10 source archive boundary refresh / path lists**：L174 后 dirty SRCDIR 增至 175 paths，H10 一度暴露 8 unknown；`bin/v2-source-archive-boundary.sh` 已补 W4 分类并在 L176 输出 `tmp/v2-source-archive-batches/*.paths`，当前 H10 为 175 dirty / 0 unknown / 9 split-needed / 23 checks → L175-L176
- [x] **Visible Cowork task-loop click-through**：`bin/v2-visible-cowork-smoke.sh` 在精确 current-builddir pid 上证明 `btn_new_task` → `awaiting-review` → 可见 DiffReview → `btn_accept_task` → `applied`，并锁定新任务选中保持和 VCL 主线程 UI 投递；当前 `Status: passed`（12 passed / 0 blocked / 0 failed）→ L165
- [x] **Visible Cowork pending/running state rows**：`bin/v2-visible-cowork-smoke.sh` 在隔离 TaskStore 中预置 pending/running envelope，通过精确 current-builddir pid AX 证明 `[pending]`/`[running]` 可见，再移除预置项后保持真实 new-task→applied 闭环；当前 `Status: passed`（14 passed / 0 blocked / 0 failed）→ L166
- [x] **Visible Cowork live nonblocking transition**：`bin/v2-visible-cowork-smoke.sh` 在真实点击 `btn_new_task` 后证明同一个 live task 从 `pending` → `running` → `awaiting-review` → 可见 DiffReview → `btn_accept_task` → `applied`，并由 H9 锁定 `CoworkUiTaskBridgeJob` 非阻塞 API；当前 `Status: passed`（16 passed / 0 blocked / 0 failed）→ L167
- [x] **Visible Cowork macOS native notification proof**：`bin/v2-visible-cowork-smoke.sh` 在精确 current-builddir pid 上证明 New Task 完成后实际调用 macOS `NSUserNotification` backend（`macos-nsusernotification` submitted），native payload dispatch 成功，并由 CoworkDialog click sink 打开 stored review；当前 `Status: passed`（19 passed / 0 blocked / 0 failed）→ L168

### 文档收口

- [x] **W5.A** lane-status W5 行从 "Day-0 C++ skeleton landed" 改成 "skeleton verified (cowork cppunit pass)" → L102
- [x] **STATUS** 在 `docs/product/v2/STATUS-2026-05-11.md` 新增 §25 章节覆盖 L96-L101 全部增量（已部分写过 §24 上午增量 I，整合 / 续）→ L102（§25 已覆盖 L102 全部 survey，§24 已覆盖 L99-L101）
- [x] **roadmap 同步** 每解锁一个 D-gate 回来更新 `v2-completion-roadmap-2026-05-13.md` §3 表 → L103（D1 增 build-system note；D1d 入册；W4 source/link granularity；§0 / §"最后一次基线" / 标题统一刷到 L103）
- [x] **CLAUDE-NOTES** 加 line 引用本 roadmap + todo（已在 task #5 处理）→ L103（同时把 handoff 引用从 L101 刷到 L103）
- [x] **handoff** 当 ledger 推进到 L105+ 时刷新 `docs/v2-coordinator-handoff-2026-05-10.md` ledger row count + Open D-gate 表 → L103（提前刷到 L103；title + State at handoff + W4 source/link + D1 都已更新，新增 D1d 行）

### 文档清理 / 漂移修

- [x] 检查 STATUS-2026-05-10.md 中过时 "5 个 V2 contract harness" 字样，确认是否要超 supersede 标记（现在是 7 个）→ L103（STATUS-2026-05-10 无此字样；STATUS-2026-05-11 line 22 是时间戳前段落，已加 "post-L62 升至 7 个" 注释保留原文）

> **协议（不是 task，不打 [x]）**：以下两条是每次 reversible 增量都必须满足的运行约束，已由 CLAUDE-NOTES + H2 自动 enforce：
> - sweep 验证：每条可逆动作做完即 `bash bin/v2-harness-sweep.sh` 必须 H1-H10 green（CLAUDE-NOTES "One-shot sweep" 段；H2 50 checks 同时验各 harness 形态）
> - STATUS / lane-status 任何 H_N 数字基线改动需 3-site 镜像（CLAUDE-NOTES canonical / handoff / sweep header）— 由 H2 check 13 自动锁，人不需要手 grep
>
> ↑ 从原 todo line 28/29 上移为协议；保留在 v2-todo 视图里只作可见性，不再算待办。

### V3 contract-only follow-up

- [x] **V3 H8/H9/H10/H11/H12 contract gates + W1/W2/W3/W4/W5/W6/W7/W8/W9 meta self-tests**：connector manifest H8、W2 manifest trust-chain policy、W2 read-only/writeback policy、W2 token-refresh policy、W2 auth-flow policy、eval baseline seed H9 + eval fixture schema lock + reference baseline lock + LLM-judge reproducibility lock、LocalCloud no-egress config H10、perf-baseline target H11、crash-recovery target H12 均已接入 `bin/v3-eval-sweep.sh --v3-only`；W1 in-app-chat fixtures + entry-route/context syntax/context autocomplete/Markdown rendering/chat history/streaming state design + AI workspace UI review/progress/opening policy + content opener route policy + formatting review policy + content review policy + artifact navigator policy + review queue policy + evidence inspector policy + interaction chrome policy + content preview matrix policy + workspace action bar policy + workspace filter/search policy + workspace context handoff policy + workspace review state sync policy + workspace activity timeline policy + workspace session snapshot policy + workspace attention routing policy + workspace native style policy、W3 knowledge-index chunk/query/result schema/fixtures + model-acquisition policy lock + vector-store backend policy lock + watcher scalability policy lock + extraction policy lock + storage policy lock、W4 audit-log-entry + policy-tenant schema/fixtures、W5 eval fixture schemas + eval-report schema/template/sample/report archive-policy lock、W6 agent-step-plan schema/fixtures/dependency-policy/plan-validation-policy/approval-policy/resume-policy/shadow-doc-policy/prompt-policy locks、W6 agent-step-result/task-state schema/fixtures、W7 companion pairing/diff/approval schema/fixtures、W8 sync-message schema/fixtures、W9 onboarding-flow schema/fixtures、W9 starter-pack manifest fixtures、W9 edition-policy fixtures、W9 i18n-locale fixtures、W9 manual-docs fixtures、W9 distribution-update fixtures、W9 error-recovery-ux fixtures 与 W9 release-ga-checklist fixtures 已接入 `bin/v3-eval-sweep.sh --self-test`；后续 W1 chat runtime / W1 workspace UI runtime opener / W1 content opener runtime / W1 formatting review runtime / W1 content review runtime / W1 artifact navigator runtime / W1 review queue runtime / W1 evidence inspector runtime / W1 interaction chrome runtime / W1 content preview matrix runtime / W1 workspace action bar runtime / W1 workspace filter/search runtime / W1 workspace context handoff runtime / W1 workspace review state sync runtime / W1 workspace activity timeline runtime / W1 workspace session snapshot runtime / W1 workspace attention routing runtime / W1 workspace native style runtime / W1 workspace content registry runtime / W2 connector runtime/auth-flow runtime/writeback runtime/token-refresh runtime / W3 runtime/downloader/embedding/vector-store/watcher/extraction/storage runtime / W4 runtime / runtime scoring / W6 runtime/scheduler parallelism/Planner retry UI/ShadowDoc runtime/prompt runtime / W7 companion runtime/app / W8 sync-server runtime / W9 onboarding runtime/starter pack/edition/i18n/manual/distribution-update/error-recovery-ux / release signoff/artifact publication / H11 live samples / H12 SIGKILL samples 仍待实施门 → L177-L242

## W1 Provider 巩固

- [x] **W1.A** 实现 `Provider::listCapabilities()`：返回 ServiceModePolicy 当前 allowlist → L108
- [x] **W1.A** 加 cppunit `testListCapabilitiesMatchesPolicy` → L108
- [x] **W1.B** 在 `Provider::call` 头尾插 `osl_getSystemTime`，写 `rsp.durationMs` → L108
- [x] **W1.B** 加 cppunit durationMs bounded 覆盖 → L108/L123（provider OK(54)；L169 后 provider OK(55) 含 Ollama JSON-mode request lock）
- [x] **W1.D** spec 新章 "Capability ↔ ServiceMode 矩阵"，H6 自动入册 → L103
- [x] **W1.cloud (gated)** spec docs/product/v2/w1-provider-spec.md 增 "cloud adapter token-lock" 表，先冻结 schema，不写代码 → L104（168 行 backlog 落 w1-provider-runtime-spec.md，Anthropic-first + 3-OS keychain + 3 新 evidence 字段冻结）
- [x] **W1.Ollama full path** 跑真实 Ollama 7-patch path：Writer provider prompt 已硬化为 W3 runtime JSON contract，`bin/v2-ollama-real-path-smoke.sh` 在本机 `qwen3:0.6b` 下验证 7 patch kind runtime JSON → L146；visible app real-provider click-through → L169

## W2 Cmd+K Palette

可逆：
- [x] **W2.A** 4 个 cppunit 当前在 wrapper 下能否成功 build，写 survey → L102（4/4 [build CUT]，全部 OK）
- [x] **W2.G** spec backlog "i18npool pinyin transliteration" 写 design 草稿（不入 SRCDIR）→ L103

D3a 已落：
- [x] sfx2 dispatcher core（4 files; spec §2）→ L108-L110
- [x] `appserv.cxx` SID_COMMAND_PALETTE → ShowPalette → L108
- [x] cppunit dispatcher binary → L110

D3b 已落：
- [x] cui loader + popover wiring（4 files）→ L109-L110

D3c + B1 已落：
- [x] B1 决议：option B — Cmd+Shift+K 面板，Cmd+K 保留 HyperlinkDialog → L109
- [x] `Accelerators.xcu` Global `K_SHIFT_MOD1` → `.uno:CommandPalette` → L109

D3d 已落：
- [x] `CommandPaletteDispatcherTest.cxx`（5 cases，cppunit total 84 → 89）→ L110

D9 已验证（仍需源码归档提交）：
- [x] commit SRCDIR `officecfg/.../GenericCommands.xcu` 11-line en-US label → L106（已存在 `.uno:CommandPalette` 单节点，Label/Tooltip/Properties 11 行；XML parse OK；diff --check OK；未 git commit）

## W3 Writer Apply Runtime

可逆：
- [x] **W3.A** survey link errors（见上）→ L102
- [ ] **W3.D** validator 边界 fixture 补充：`apply-plan-runtime.writer-runtime.json` 已落且计入 H2 40-fixture baseline。加 calc-runtime / slide-runtime placeholder = 改 H2 期望 40→42 + reader manual + schema validity 三方同步。**不在 design 阶段主动加**（无明确产品需求）；留待 W4 Calc/Impress popover 实装时按需扩 fixture，或确认 sweep 跑 calc/impress runtime fixture 是否能加价值再决

D1 已落：
- [x] 修复 `UndoApplyPatch.hxx` 缺失 subclass（aggregator + 7 patch kinds）→ L108/L112
- [x] `SwDocShell::applyDiagnosticsPlan` 真实 wiring（→ ApplyEngine）→ L112
- [x] doc-backed cppunit / live-doc apply evidence → L122（sw_uwriter OK(73)）/ L123（OK(74)）
- [x] 其余 6 patch kinds 真实现 + H7 shipping 口径 → L116-L120（sw_apply_engine OK(35)）
- [x] root-cause Writer Start Center creation path under svp → L174
- [x] 手动 bundle smoke 自动化：STUB_RUNTIME Rewrite → DiffReview → applied document → Accept undo / Reject removal → L164

## W4 Select-to-act

可逆：
- [x] **W4.A** survey 3 surface link errors → L102（sw compile/D1；sc/sd link/DLLPUBLIC）
- [x] spec 增章节 "popover invocation contract"（不写代码，只锁接口）→ L103

待 W4 source/link 授权：
- [x] 修 `sc::inline_actions::{toToken,fromToken}` 未定义 → L107（补 `SC_DLLPUBLIC` + cppunit include `sc/inc`，`CppunitTest_sc_inline_actions` OK(3)）
- [x] 修 sd 同类问题 → L107（补 `SD_DLLPUBLIC` + cppunit include `sd/inc`，`CppunitTest_sd_inline_actions` OK(3)）
- [x] 修 sw 同类问题（随 D1 include/undo 修复）→ L108
- [x] 3 个 inline-actions cppunit 均能 `[build CUT]` / workdir pass → L118-L120（sw OK(9), sc OK(6), sd OK(5)）

待 W4 scope 授权：
- [x] Writer VCL popover：`WriterSelectToActPopover` + `.ui` + `ShowSelectToActPopover` stub → L112
- [x] 选区 hook + Calc/Impress popover + Diff deck → L113-L117
- [x] selection 监听 + 按钮触发 ApplyPlan/provider dispatch → L117-L119
- [x] `svx/source/sidebar/diff-review/` 接 W3 wiring，做 accept/reject UI → L116-L119
- [x] current-bundle visible DiffReview accept/reject 闭环 → L164（16/0/0）
- [x] UITest `UITest_sw_select_to_act` Writer factory document-window zero-skip：UNO factory + `writer_edit` reachability both unskipped and passing through `load_empty_file("writer")` → L170-L171
- [x] UITest `UITest_sc_select_to_act` / `UITest_sd_select_to_act` factory document-window coverage：Calc `grid_window` + Impress `impress_win` both registered and passing with 3 tests / 0 skipped → L172
- [x] Calc/Impress visible popover click-through polish：`bin/v2-visible-suite-select-to-act-smoke.sh` proves exact-pid `CellRangePopover` / `SlideElementPopover` action clicks and popover-close product response at 16/0/0 → L173
- [x] Start Center Writer creation-path svp root cause → L174
- [x] app-bundle static smoke：CommandPalette、Cmd+Shift+K、Select-to-act popovers、DiffReviewDeck、CoworkDialog、Cmd+Shift+T 均随 `instdir/可圈office.app` 安装 → L126

## W5 Async Cowork

可逆：
- [x] **W5.A** lane-status / STATUS 同步 cowork cppunit pass → L102
- [x] spec backlog "worker queue scheduling contract"（入 W5 spec 新章）→ L103

待 W5 scope 授权续：
- [x] worker queue 实现（offline 单线程也行，但要有 cancel/await/refine API）→ L128（TaskQueue pure-logic lifecycle）
- [x] task list panel UI：CoworkDialog + cowork-dialog.ui + TaskStore → L121
- [x] Help menu / Cmd+Shift+T CoworkTaskManager hook → L122-L123
- [x] 端到端 cppunit：pending → running → awaiting-review → applied → L128；H9 lifecycle evidence contract 补齐 reason 证据 → L130；TaskScheduler success/failure/restart-recovery lifecycle → L131；TaskRunner worker-thread/in-process notification lifecycle → L132；TaskReviewBridge notification click-to-review core → L133；TaskReviewBridge stored-task review-open handler → L134；AutoOpenReviewNotificationSink notification auto-open bridge → L135；CoworkUiBridge dialog-run bridge → L136；review accept → applied core → L137；CoworkDialog visible DiffReview + accept UI → L138；OS-notification gateway payload/click core → L139；Cowork UI OS-notification sink seam → L140；native backend/fallback + macOS submitter → L141；native click payload → stored review open handler → L142；macOS delegate/click-sink dispatch → CoworkDialog stored review open → L143；Windows Shell_NotifyIcon backend/click dispatch → L144；CoworkUiTaskBridgeJob 非阻塞 pending/running/complete transition → L167；native notification evidence log/smoke click gate → L168（kqoffice_cowork OK(45)）
- [x] worker thread / notification primitive：真实 OSL worker thread + in-process notification sink，锁 `worker-started` / `task-running` / `awaiting-review-notification` / `task-failed-notification` / `worker-idle` / `worker-empty` → L132
- [x] 平台无关通知点击 core：awaiting-review notification → open-review-request（monthDir/taskId/resultPlanId/evidenceId）→ L133；open-review-request → stored awaiting-review task → diff-review-opened → L134；TaskRunner awaiting-review notification → AutoOpenReviewNotificationSink → stored-task diff-review-opened → L135；CoworkDialog new-task → TaskRunner → visible DiffReview + stored-task diff-review-opened → L136/L138；opened review accept → applied → L137/L138；OS notification request payload + click token → stored review open → L139；Cowork UI runner emits OS notification request through sink seam → L140；native backend/fallback + macOS NSUserNotification submitter → L141；native click metadata → `openReviewFromNativeOsNotificationClick` → stored review open → L142；macOS delegate/click-sink dispatch → CoworkDialog stored review open → L143；Windows Shell_NotifyIcon balloon click → native click sink dispatch → L144
- [x] macOS 系统 delegate/callback 绑定证明：NSUserNotification activation → click-sink dispatch → `openReviewFromNativeOsNotificationClick` → CoworkDialog DiffReview/sidebar → L143；current-builddir 产品 smoke 证明 `macos-nsusernotification` submit + native payload dispatch + stored review open → L168
- [x] Windows 原生通知 backend：Shell_NotifyIcon notification-area balloon + WNT `shell32` build wiring + click dispatch source proof → L144（Windows host compile/manual toast smoke 仍归完整 GUI/worker E2E）
- [ ] 端到端 UITest：用户可看到 task list + 接受/拒绝
- [x] current-bundle visible Cowork 闭环：`btn_new_task` → awaiting-review → DiffReview → `btn_accept_task` → applied → L165（12/0/0）
- [x] current-bundle visible Cowork 状态行：`[pending]` / `[running]` 在真实 Cowork 列表可见，且不干扰 new-task→applied 闭环 → L166（14/0/0；不代表实时过渡）
- [x] current-bundle visible Cowork 真实非阻塞过渡：真实点击 `btn_new_task` 后同一个 live task 先可见 `pending`，再可见 `running`，随后进入 awaiting-review/DiffReview/accept/applied 闭环 → L167（16/0/0）
- [x] current-bundle visible Cowork macOS native notification：真实 New Task 完成后记录 `native-os-notification-submit` / `native-os-notification-click-dispatch` / `native-os-notification-review-open` 三条产品证据，且均指向同一个 live task → L168（19/0/0）

## 横切 Tracks

### B-class

- [x] B2 harfbuzz Meson UTF-8 — wrapper 解除（L101）
- [x] B1 Cmd+K accelerator 冲突 — option B：Cmd+Shift+K 打开 CommandPalette，Cmd+K 保留 HyperlinkDialog → L109
- [ ] B3 push 受限 — 等用户决 host / LFS / shallow

### CI / Locking

- [x] 检查 `.github/workflows/v2-contract-harnesses.yml` 是否还需要把 wrapper 注入 macOS 那一栏的 cppunit step → L104（CI 用 ubuntu-latest，非 ASCII BUILDDIR 路径问题不存在，wrapper 无需注入；同时修了 H4/H5/H7 step 标签 `partial-enforce` → `full-enforce since L96/97/98`，H2 + V1.5 step 名 36 fixtures → 40 fixtures，floor 36 保留为安全裕度）
- [x] 新增 H8 product-entry smoke harness（installed app-bundle entrypoints）→ L127
- [x] 评估是否新增 H9（worker / UI integration harness）— H8 已覆盖静态产品入口，TaskQueue pure-logic 已落；H9 应锁 GUI/worker lifecycle → L128
- [x] 新增 H9 worker/UI lifecycle evidence gate：覆盖 TaskQueue reason evidence、TaskScheduler success/failure/restart-recovery、TaskRunner real thread/in-process notification events、TaskReviewBridge open-review-request + stored-task diff-review-opened core + review accept → applied core、AutoOpenReviewNotificationSink notification→diff-review-opened bridge、CoworkUiBridge dialog-run bridge、CoworkDialog visible DiffReview open sink + selected-task accept UI + OS-notification gateway payload/click core + Cowork UI OS-notification sink seam + native OS notification backend/fallback + macOS NSUserNotification submitter + native click payload → stored review open handler + macOS delegate/click-sink dispatch into CoworkDialog stored review open + Windows Shell_NotifyIcon backend/click dispatch + TaskStore-backed list surface + non-modal DiffReview controller + VCL 主线程投递 + task-id 选中保持 + CoworkUiTaskBridgeJob 非阻塞 transition + native notification evidence log/smoke click gate、`kqoffice_cowork OK(45)` 和 H9=278 → L130/L168
- [x] 新增 H10 source archive boundary gate：`/Users/lu/kdoffice-src` dirty paths 分类到 W1/W2/W3/W4/W5/build-infra/submodule，unknown=0，report=`tmp/v2-source-archive-boundary.md` → L145；L175 刷新当前边界到 175 dirty / 0 unknown / 9 split-needed；L176 输出 `tmp/v2-source-archive-batches/*.paths` 并把 H10 提到 23 checks
- [ ] 完整 GUI/worker E2E：已完成 awaiting-review→DiffReview→applied 真实 app click-through、pending/running 列表可见性、真实非阻塞 pending→running 过渡，以及 macOS current-builddir native notification submit/dispatch/stored-review proof；仍需 Windows host compile/manual toast proof；H9 不替代这一项
- [x] 评估是否新增 tier-4 check 17（max-L-anchor in docs ↔ ledger row count）— 现在是手工漂移源 → L105（已存在 H2 check 17 L-anchor cadence ≤ 3，验过；L104 sentinel refresh handoff/notes/status 全到 L104，gap=0；维护协议落 STATUS §26.7）

### 其它

- [ ] 决定 D5 `downstream-branding/` 来源（commit / submodule / skip）
- [ ] D8 LaunchConstraint.plist team-identifier 决议
- [ ] D6 worker owned-paths re-scope（不阻塞主线，但影响 parallel lane 可用性）
- [ ] `/Users/lu/kdoffice-src` 按 W1/W2/W3/W4/W5/build-infra 分组归档提交（H10 当前边界：175 dirty / 0 unknown / 9 split-needed；显式路径清单在 `tmp/v2-source-archive-batches/`；仍禁止 `git add .`）
- [x] 手动 product smoke：DiffReview、Cowork 任务循环（L126-L163 已完成 bundle 入口、app launch/init、文档处理、UNO dispatch、current-builddir AX 归因、CommandPalette/Cowork 入口和 Writer Select-to-act；L164 完成 DiffReview Accept/Reject 16/0/0；L165 完成 Cowork new-task→awaiting-review→DiffReview→accept-task→applied 12/0/0；L167 完成 live pending→running→awaiting-review→DiffReview→accept-task→applied 16/0/0；L168 完成 macOS native notification submit/dispatch/stored-review proof 19/0/0；L169 完成 visible real Ollama provider click-through 18/0/0）→ L169

## 历史 - 已完成里程碑（不再动）

- [x] L1-L40 V1.5 milestone + V2 W1/W2/W3 Day-0/Day-1 schema + 27/27 strict roundtrip
- [x] L41 W5 async-task schema + fixtures + H4 partial
- [x] L46 W4 inline-action-request schema + 4 fixtures + H5 partial
- [x] L62 CI 4/7 → 7/7 harness 调用
- [x] L83 H2 check 16 ledger ts ISO+UTC monotonicity
- [x] L96 W5 H4 full-enforce + cowork Day-0 skeleton
- [x] L97 W4 H5 full-enforce + 3 surface skeleton
- [x] L98 W3 H7 full-enforce + ApplyPlanValidator subclass aggregator
- [x] L100 W2 Day-1b spec 整合 + D3a/b/c/d 拆分
- [x] L101 B2 wrapper reclassification + W5 cowork cppunit pass
- [x] L102 reversible survey triangle (W3.A target unregistered / W4.A 3-surface fix scope / W2.A 4×[build CUT] OK(33) — OK(77)→OK(84) workdir closed)
- [x] L103 reversible spec backlog quad (W1.D capability matrix / W2.G pinyin design draft / W4 popover invocation contract / W5 worker queue scheduling contract)
- [x] L104 CI workflow label drift fix (3× partial→full + 36→40 fixtures) + W1.cloud token-lock backlog (W1.cloud schema freeze, 168 lines)

---

更新协议：每完成一项 [ ] 改 [x] 并加 `→ Lxx`；新发现追加到对应小节末尾。
要保持本文件 < 300 行，过 300 行就拆 milestone 章节。
