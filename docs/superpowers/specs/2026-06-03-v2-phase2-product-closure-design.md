---
title: 可圈office V2 — Phase 2 Product Closure
date: 2026-06-03
status: v0 (draft — 待用户批准后开始实施)
author: Grok (coordination) / ledger through L125
predecessor: V2 W1–W5 contract + spine (L96–L125)
---

# V2 Phase 2 — 产品闭环设计 v0

## 1. 项目定位

### 范围（Phase 2 要做）

把 V2 从 **「合约全绿 + Writer 主路径可编译」** 推进到 **「用户可重复完成的 AI 办公闭环」**：

1. **Golden path（Writer）**：选中文本 → 气泡 Rewrite → Provider（stub 或 Ollama）→ ApplyPlan 写回 → Diff 审阅 → 接受/拒绝 → Undo 可预期。
2. **Cmd+Shift+K** 命令面板与 **Cmd+Shift+T** Cowork 入口在 Writer/Calc/Impress 可发现、可触发。
3. **三应用最小 Select-to-act**：Writer 全链；Calc 公式格 / Impress 文本框各 1 条「建议→应用」短链。
4. **W1 诚实化**：`listCapabilities` 反射策略；`durationMs` 实测写入 evidence。
5. **文档真相源**：`lane-status` / `handoff` / `v2-todo` / `STATUS` / `roadmap` 与 L125 实态对齐（消除「W2 未通 / instdir 空」等过期叙述）。
6. **门禁固化**：`bin/v2-harness-sweep.sh` 7/7 + 核心 cppunit 矩阵 + `UITest_sw_select_to_act`（office-connect smoke）进 CI 或 release checklist。

### 不做的事（Phase 2 明确排除）

- V3 Connector / Knowledge Index / In-App Chat 全屏（见 `docs/product/v3-master-plan.md`）。
- Cloud provider TLS / Anthropic adapter **实现**（W1.cloud 仅 schema 冻结，L104）。
- `UITest_demo_ui` 全套件在 headless `svp` 下救绿（上游 stock，非 V2 门禁）。
- headless 下 Writer `create_doc_in_start_center` / `loadComponentFromURL(swriter)` 根因 **不阻塞** Phase 2 交付（用 native 手测 + skipped UITest 代替）。
- `git push`、签名证书注入、downstream-branding 仓库结构 **决策**（D5/D8/B3）— 仅列 checklist，不替用户选。

### 成功标准（可验证）

| # | 命令 / 动作 | 期望 |
|---|-------------|------|
| S1 | `bash bin/v2-harness-sweep.sh` | 7/7 passed |
| S2 | `make CppunitTest_{sw_apply_engine,sw_inline_actions,sc_inline_actions,sd_inline_actions,kqoffice_provider,cui_dispatcher}` + `PKG_CONFIG=/tmp/kqoffice-pkgconf-utf8` | 全部 exit 0 |
| S3 | `bash bin/v2-uitest-sw-select-to-act.sh` | `OK (skipped=2)`，`make_exit=0` |
| S4 | 本机 `instdir/可圈office.app` + `KQOFFICE_AI_STUB_RUNTIME=1` + `KQOFFICE_AI_DISABLE_PROBE=1` | Golden path 录屏或 checklist 全勾 |
| S5 | 本机 Ollama `@127.0.0.1:11434` + 无 stub | Rewrite 返回 `apply-plan-runtime` 且 7-patch 中 ≥1 种写回成功 |
| S6 | `lane-status.md` ledger 行数 = `wc -l ledger.jsonl`；roadmap §0 表与 cppunit 计数一致 | H2 check 9/17 无漂移 |

---

## 2. 现状证据（2026-06-03，以 ledger + 本机构建为准）

### 2.1 已落地（L108–L125，代码在 `kdoffice-src`）

| 能力 | 证据 |
|------|------|
| W2 命令面板 | `CommandPaletteDispatcher`、⌘⇧K → `.uno:CommandPalette`；`CppunitTest_cui_dispatcher` 等 |
| W3 Writer Apply | 7 patch kinds、`ParseApplyPlanRuntimeJson`、`SwDocShell::applyDiagnosticsPlan`；`CppunitTest_sw_apply_engine`；`sw_uwriter` doc E2E |
| W4 Select-to-act | Writer popover + `InlineActionProviderDispatch`；sc/sd/sw inline cppunit OK(6/5/9)；UITest 下 `LO_RUNNING_UI_TEST` 禁用 popover |
| W1 stub runtime | `KQOFFICE_AI_STUB_RUNTIME` + `DISABLE_PROBE` → `RuntimePlanStub`；provider OK(54) |
| W5 Cowork | `CoworkDialog`、⌘⇧T、Help 菜单（sw/sc/sd/si） |
| 构建 | 非 ASCII BUILDDIR：`PKG_CONFIG=/tmp/kqoffice-pkgconf-utf8`；solenv CLICOLOR 修复（L124） |
| UITest 门禁 | `UITest_sw_select_to_act`：`test_office_connect_smoke` ~0.01s；Writer UI/UNO **skip**（svp 挂起） |

### 2.2 文档滞后（必须 Phase 2 收口）

- `v2-completion-roadmap-2026-05-13.md` §0 仍写 W2「popover ✗」、W3「link ✗」— 与 L112/L120 矛盾。
- `STATUS-2026-05-11.md` §2 写 `instdir` 近乎空 — 本机已可 `make build` + `test-install`。
- `v2-todo.md` 多项 `[ ]` 实际已完成（D3、W3.B/C 等）。
- `handoff` 仍列 D1/D3 为 open — 多数已在 L108–L110 关闭。

### 2.3 已知环境限制

- headless `SAL_USE_VCLPLUGIN=svp`：Writer 打开/输入 UITest **挂 CPU**（含 stock `demo_ui`）。
- 自动化勿用：`pkill` + `rm -rf workdir/UITest/*` + `make UITest_*`（易 SIGTERM 15、~7min build ALL）。
- `main` ahead origin 63+；B3 push 未决。

### 2.4 四维评估（Phase 2 起点）

| 维度 | 评级 | 事实 |
|------|------|------|
| 功能完整性 | **B** | 合约+编译+Writer 主链 cppunit 闭合；用户可触达 UI 闭环 **未** 验收；Calc/Impress 写回浅 |
| UX | **C+** | 气泡/面板/快捷键已接线；Diff 审阅 deck、Cowork 真异步、错误 toast 一致性未验 |
| 性能 | **B-** | Provider 有界读/超时；选区 hook 在 UITest 已关；未见 Ollama 大文档压测 |
| 代码质量 | **B+** | 7 harness + 89+ cppunit；文档/门禁脚本漂移；UITest 分层（smoke vs skip）已建立 |

**总评**：V2 处于 **「工程闭环 > 产品闭环」**；Phase 2 目标是 **产品闭环 + 文档真相源**，而非新 schema。

---

## 3. 三方案对比（Phase 2 范围选择）

| 方案 | 描述 | 改动量 / 工期 | 得到什么 | 得不到什么 |
|------|------|----------------|----------|------------|
| **A 保守** | 仅 Golden path 手测 + 文档/sync + W1.A/B 诚实化 | ~400 行文档+C++，**3–5 天** | 可演示 Writer AI _rewrite_；release notes 可信 | Calc/Impress 写回、Diff UI、W5 真队列 |
| **B 标准（推荐）** | A + Ollama 实链 + `svx` Diff 审阅 + Calc/Impress 各 1 条 apply 短链 + smoke 脚本 | ~1200–1800 行 SRCDIR，**10–14 天** | **可对外说 W2–W4 Writer 可用**；三应用均有 AI 触点 | W5 完整调度、headless UITest Writer 全开、V3 |
| **C 激进** | B + W5 worker 状态机 UI + headless 根因 + sc/sd UITest + H8 harness 草案 | ~3500+ 行，**3–4 周** | 接近「V2 功能完整」；为 V3 铺路 | 风险：并行改 sw/svx/kqoffice 回归面大；D5/D8 仍阻塞安装包 |

**推荐 B**：与 L125「Next: manual STUB_RUNTIME + Ollama 7-patch」一致；不先啃 headless UITest 无底洞。

---

## 4. 设计 — Phase 2 工作分解（标准方案 B）

### 4.1 架构（不变，只补 UI 层）

```
选区/单元格/形状
  → InlineActionRequest (JSON)
  → com.sun.star.ai.Provider::call
  → apply-plan-runtime (JSON)
  → SwDocShell::applyDiagnosticsPlan / sc·sd 等价入口
  → svx DiffReview（accept/reject，LIFO per patch）
  → Undo 栈
```

Cowork（W5）Phase 2 仅要求：**同一 Provider + Apply 管线**，TaskStore 列表展示 stub 任务，不要求真后台线程池。

### 4.2 里程碑（建议 ledger L126–L135）

| 里程碑 | ID | 交付 | 验证 |
|--------|-----|------|------|
| M0 | P2.0 | 文档真相源刷新（lane-status/handoff/roadmap/todo/STATUS §28） | H2 全绿；check 9 gap=0 |
| M1 | P2.1 | `bin/v2-manual-golden-path.sh` + checklist（STUB_RUNTIME） | S4 |
| M2 | P2.2 | Ollama live：`bin/v2-w4-writer-apply-smoke.sh` 扩展 7-patch | S5 |
| M3 | P2.3 | `svx/source/sidebar/diff-review/` 接 Writer accept/reject | 手测 Diff 按钮 |
| M4 | P2.4 | Calc `formula_suggest` → apply；Impress `translate_selection` 写回 | sc/sd cppunit +1 case each |
| M5 | P2.5 | W1 `listCapabilities` + `durationMs` | provider 84→87 cases |
| M6 | P2.6 | Cowork panel：pending→applied 单路径（offline 同步即可） | cowork cppunit + 手测 |
| M7 | P2.7 | Release checklist（D5/D8/B3 占位） | 文档 only |

### 4.3 数据流 — Golden path（Writer）

1. `DrawSelChanged` → `OnWriterSelectionChanged`（非 UITest）→ `ShowSelectToActPopover`。
2. `btn_rewrite` → `InlineActionProviderDispatch` → Provider。
3. 返回 JSON → `TryParseApplyPlanRuntimeJson` → `applyDiagnosticsPlan`。
4. DiffReview 显示 patches；用户 Accept → `AcceptDiffPatch` LIFO；Reject → 回滚对应 undo。

**错误处理**：Provider 失败 → toast（已有 `applyPlanValidationMessage` 路径）；解析失败 → 不写文档；UITest 不弹 popover。

### 4.4 测试矩阵（Phase 2 结束态）

| 层 | 目标 |
|----|------|
| Schema | 保持 H1–H7，40 fixtures |
| Cppunit | sw_apply_engine, sw/sc/sd inline, kqoffice_provider, cui_dispatcher, kqoffice_cowork |
| UITest | `sw_select_to_act` office-connect only；Writer 全 UI 标 `@unittest.skip('native manual')` |
| 手测 | `bin/v2-manual-golden-path.sh` 必跑项 |
| 可选 | Ollama smoke 仅 CI nightly 或本机 |

### 4.5 风险与缓解

| 风险 | 缓解 |
|------|------|
| headless Writer 挂起 | 不纳入 Phase 2 exit；native 手测为准 |
| mergedlo 链接遗漏 | 新符号先进 `Library_merged.mk` / `kqoffice_ai` |
| 文档再次漂移 | 每 milestone 只改 STATUS §28 + ledger，禁止手改 H2 计数 |
| 并行 Composer 任务 SIGTERM | 禁止 pkill+rm 模板；用 `v2-uitest-sw-select-to-act.sh` |

---

## 5. 落盘清单（标准方案 B）

### 新建（BUILDDIR）

- `bin/v2-manual-golden-path.sh` — STUB_RUNTIME 启动 + 步骤 echo
- `docs/product/v2/PHASE2-CHECKLIST.md` — 手测勾选表（可选，用户若不要 md 则只保留 bin 脚本注释）

### 修改（SRCDIR `kdoffice-src`）

- `svx/source/sidebar/diff-review/*` — W3 accept/reject 接线
- `sc/source/ui/inline-actions/*` — formula apply 写回
- `sd/source/ui/inline-actions/*` — impress text apply
- `kqoffice/source/ai/provider/Provider.cxx` — W1.A/B
- `kqoffice/qa/cppunit/test_provider.cxx` — +3 cases

### 修改（BUILDDIR 文档）

- `docs/product/v2/lane-status.md` — roll-up 表、W2–W5 行、ledger 125+
- `docs/v2-coordinator-handoff-2026-05-10.md` — 关闭已解决的 D1/D3
- `docs/product/v2/v2-todo.md` — `[x]` 与 L126+ 引用
- `docs/product/v2/v2-completion-roadmap-2026-05-13.md` — §0 表刷新
- `docs/product/v2/STATUS-2026-05-11.md` — §28 Phase 2 增量（或新 STATUS-2026-06-03.md）

### 不改

- V3 specs、`UITest_demo_ui`、cloud adapter 实现、i18npool pinyin（W2.G backlog）

---

## 6. 下一轮选项（批准后执行入口）

| 选项 | 含义 | 第一批命令 |
|------|------|------------|
| **a** | 保守：只做 M0+M1+文档 | `bash bin/v2-manual-golden-path.sh` 草案 + lane-status 刷新 |
| **b** | **标准（推荐）**：按 M0→M6 顺序 | M0 文档 → M1 手测脚本 → M2 Ollama → M3 Diff → … |
| **c** | 激进：b + W5 worker + headless 调查 | 另开 `tmp/headless-writer-stall.md` 调查日志 |

---

## 7. 自检

- [x] 无占位符 TODO
- [x] 范围/不做什么/成功标准明确
- [x] 依据 ledger L125、done.log、`make_exit=0` 实测
- [x] 验证命令可执行
- [x] 三方案含具体工期/行数估计
- [x] 落盘清单与里程碑清晰
- [ ] **用户批准** — 未批准前不实施 SRCDIR 改动

---

## 附录：10 行 workspace 快照

1. **位置**：BUILDDIR `/Users/lu/可点office`，SRCDIR `/Users/lu/kdoffice-src`
2. **目标**：V2 AI-native 五车道产品闭环
3. **约束**：非 ASCII 路径需 pkgconf wrapper；mergedlo 链接；不 silent push
4. **合约**：H1–H7 全绿；ledger **L125**
5. **Cppunit**：apply_engine / inline×3 / provider / dispatcher 已绿
6. **UITest**：`sw_select_to_act` OK(skipped=2)；勿 pkill+rm+make
7. **缺口**：手测 Golden、Ollama 7-patch、Diff UI、Calc/Impress 写回、文档漂移
8. **阻塞**：D5 branding、D8 签名、B3 push — 用户决
9. **V3**：draft，Phase 2 不启动
10. **建议下一步**：批准 **方案 B** → 执行 M0+M1