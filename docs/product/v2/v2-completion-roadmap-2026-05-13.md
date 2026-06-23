# V2 AI-native — Completion Roadmap (刷新于 2026-06-04, ledger=L125)

> 这份文件是 **后续开发的导航图**，不是新规范。
> Authoritative 文档仍是：
> - `docs/product/v2/lane-status.md`（当前状态镜像）
> - `.agent/goals/2026-05-08-v2-ai-native/ledger.jsonl`（append-only 时间线）
> - `docs/v2-coordinator-handoff-2026-05-10.md`（wait-state snapshot）
> - 各 Wave spec：`docs/product/v2/w[1-5]-*-spec.md`
>
> 本文档 = 一句话告诉下次会话 "从哪里捡起来"。
> 同步策略：每次完成一个 Wave 阶段或解除一个 D-gate，回来更新对应小节状态。

## 0. 现状总评（complete-vs-skeleton）

| Wave | Contract / schema | 纯逻辑 / cppunit | 真实 UI / 文档写入 | 整体阶段 |
|---|---|---|---|---|
| W1 Provider Runtime  | A 完成 | A 完成（54 cases） | offline ✅ / runtime JSON stub ✅ / private ✗ / cloud ✗ | **A- 本地路径待 Ollama 全量烟测** |
| W2 Cmd+K Palette     | A 完成 | A 完成（38 cases） | dispatcher ✅ / popover ✅ / Cmd+Shift+K ✅ / manual app smoke 待验 | **B+ 产品路径已落，缺手动烟测** |
| W3 Writer Apply      | A 完成（H7 full） | A 完成（sw_apply_engine OK(35)） | ApplyEngine 7/7 ✅ / doc-backed apply ✅ / svp UITest skips 待根因 | **A- 核心已通，GUI 证据待补** |
| W4 Select-to-act     | A 完成（H5 full） | A 完成（sw/sc/sd OK(9/6/5)） | popovers ✅ / provider loop ✅ / DiffReview ✅ / UITest/manual smoke 待验 | **B+ 产品 loop 已通，缺完整 GUI 验收** |
| W5 Async Cowork      | A 完成（H4 full） | A 完成（10 cases） | CoworkDialog ✅ / menu hook ✅ / scheduler/notifications ✗ | **B UI 壳已落，任务执行闭环待做** |

**整体评价**：V2 已从协议层推进到产品 loop：Provider→ApplyPlan→Writer/Calc/Impress→DiffReview/Cowork 的主要本地路径已有源码和 cppunit 证据。
当前缺口从“能不能写进文档对象模型”转为“能不能干净归档、GUI 全证据、真实 Ollama 路径、release policy”。

7 个 V2 contract harness 全绿（H1-H7，最近一次 sweep 7/7 passed at L125）。
V1.5 27/27 strict roundtrip 不变。
ai-native counted core cppunit = 92；side suites：sw_apply_engine OK(35)、sw/sc/sd inline OK(9/6/5)、cowork OK(10)。

## 1. Wave 收尾路线（优先级从高到低）

> **L125 override**：下面 1.1-1.5 保留 L107 前后的历史路线，很多 D-gate 已在 L108-L125 落地。当前真实优先级：
>
> 1. `/Users/lu/kdoffice-src` 按 W1/W2/W3/W4/W5/build-infra 分组归档，禁止 `git add .`。
> 2. builddir `/Users/lu/可点office` 的状态文档、scripts、fixtures 分组归档，并保持 `bash bin/v2-harness-sweep.sh --with-fixtures` 绿。
> 3. GUI 证据：root-cause Writer load / TYPE/select under svp；手动 bundle smoke 覆盖 Cmd+Shift+K、select-to-act、DiffReview、Cowork menu。
> 4. 真实 provider：Ollama full 7-patch path。
> 5. release policy：`downstream-branding/`、LaunchConstraint team identifier、B3 push strategy。

按 "解锁后做" 的顺序排，每个 Wave 都列出：可逆 (coord 自己能做) vs gated (需用户授权)。

### 1.1 W3 Writer Apply Runtime — **第一优先级**

为什么第一：W3 把 ApplyPlan 真正打到 SwDoc，是 W1/W2/W4/W5 都要复用的核心 wiring；
合约层已 full-enforce，欠的是 source/link 闭环。

| ID | 类别 | 内容 | 验证 |
|---|---|---|---|
| W3.A | 可逆 | 不动 SRCDIR，先重跑 `make CppunitTest_sw_apply_engine` 在 PKG_CONFIG wrapper 下捕全量 link 错误清单（含 UndoApplyPatch.hxx 缺哪些 subclass / SwDocShell 不可见的 include 链） | 输出落 `tmp/w3-apply-link-survey.log` |
| W3.B | gated（D1） | 授权后修 `sw/source/uibase/inline-actions/SwUndoApplyPatch*.hxx` 缺失 subclass（aggregator + 7 patch kind） | `make CppunitTest_sw_apply_engine` 通过 |
| W3.C | gated（D1） | 授权后接 `SwDocShell::applyDiagnosticsPlan` wiring（spec §"5 new + 3 modify"） | UITest_sw 或 cppunit doc-backed apply pass |
| W3.D | 可逆 | 把 W3 14-case 验证结果回写 `lane-status` W3 行 + STATUS 新章节 + 加 ledger | `bash bin/v2-harness-sweep.sh` 仍 7/7 |

完成判据：
- `make PKG_CONFIG=/tmp/kqoffice-pkgconf-utf8 CppunitTest_sw_apply_engine` exit 0
- `SwDocShell::applyDiagnosticsPlan` 真实路径有至少 1 个 doc-backed cppunit
- H7 仍 full-enforce
- ai-native cppunit claimed total 84 → 84+14（或重新统计）

### 1.2 W4 Select-to-act — **第二优先级**

为什么第二：W4 schema/H5/token lock 已 full；C++ 已落 3 个 surface；阻塞点是 link symbol 缺失。

| ID | 类别 | 内容 | 验证 |
|---|---|---|---|
| W4.A | 可逆 | Wrapper 下重跑 `CppunitTest_sc_inline_actions` / `CppunitTest_sw_inline_actions` / `CppunitTest_sd_inline_actions`，截全量 link 错误；按 surface 分类 missing symbol | `tmp/w4-link-survey.log` |
| W4.B | ✅ L107 | 修 `sc::inline_actions::{toToken,fromToken}` undefined（`SC_DLLPUBLIC` + `sc/inc` cppunit include） | `CppunitTest_sc_inline_actions` = `OK(3)` |
| W4.C | gated（W4 source/link / D1） | 修 Writer compile（SwDocShell unknown / UndoApplyPatch.hxx missing — 与 W3.B 共享 fix） | `CppunitTest_sw_inline_actions` 通过 |
| W4.C2 | ✅ L107 | 修 sd 同类 source-link（`SD_DLLPUBLIC` + `sd/inc` cppunit include） | `CppunitTest_sd_inline_actions` = `OK(3)` |
| W4.D | gated（W4 scope） | 接 VCL popover：`SelectToActPopover` / `CellRangePopover` / `SlideElementPopover` 真实弹出 + selection 监听 | `UITest_sw_select_to_act` |
| W4.E | gated（W4 scope） | `svx/source/sidebar/diff-review/` 接 ApplyPlan accept/reject 走 W3 wiring | UITest |

完成判据：
- 3 个 inline-actions cppunit binary 全部 `[build CUT]` exit 0
- 至少 Writer 1 个 surface 有 UITest 验证 popover → diff review → applyDiagnosticsPlan 端到端
- H5 仍 full-enforce
- W4 行从 "B2 wrapper cleared / source-link" → "shipping"

### 1.3 W2 Cmd+K Command Palette — **第三优先级**

为什么第三：纯逻辑全过，sfx2/cui/officecfg 是 4 个授权小步，每步都很短。

| ID | 类别 | 内容 | 验证 |
|---|---|---|---|
| W2.A | 可逆 | Sweep 当前 4 个 commandpalette cppunit binary 在 wrapper 下能否构建 | `tmp/w2-cppunit-survey.log` |
| W2.B | gated（D3a） | sfx2 dispatcher core（4 files, spec §2） | `sfx2.build` 通过 + `appserv.cxx` ShowPalette 替换 |
| W2.C | gated（D3b） | cui loader + popover wiring（4 files） | `cui.build` 通过 |
| W2.D | gated（D3c, B1） | `Accelerators.xcu` Cmd+K → `.uno:CommandPalette`，B1 冲突先决：HyperlinkDialog 改 `MOD1_SHIFT+K` 或 CommandPalette 用别的键 | UITest 触发 |
| W2.E | gated（D3d） | 5 case dispatcher cppunit（ai-native cppunit 84 → 89） | `CppunitTest_cui_dispatcher` |
| W2.F | gated（D9） | SRCDIR officecfg `GenericCommands.xcu` 11-line en-US label commit | 单独 commit / smallest D3 sub-step |
| W2.G | 可逆 | i18n pinyin 整合（D1c）排进 backlog，不阻塞 D3 | — |

完成判据：
- Cmd+K 在 Writer / Calc / Impress 内部均能弹出 palette
- Enter 触发 sfx dispatch slot
- ai-native cppunit total 84 → 89
- accelerator 不与 HyperlinkDialog 冲突

### 1.4 W5 Async Cowork — **第四优先级**

为什么第四：Day-0 skeleton 已通过；下一阶段是 worker / UI / cancellation，属于新工作量。

| ID | 类别 | 内容 | 验证 |
|---|---|---|---|
| W5.A | 可逆 | 现状 cowork cppunit pass 已确认。把 W5 行从 "skeleton landed" 改成 "skeleton verified" 并加 STATUS 增量章节 | sweep 7/7 |
| W5.B | gated（W5 scope, 续期） | worker queue / scheduling（offline 模式可不开 thread，但要有 await/cancel 接口） | `CppunitTest_kqoffice_cowork` 扩展 |
| W5.C | gated（W5 UI） | Diff Review 浮窗 + Task list panel；与 W4.E 复用 `svx/source/sidebar/diff-review/` | UITest |
| W5.D | gated（W5 integration） | 把真实 ApplyPlan 接 W3.C 的 `applyDiagnosticsPlan`，cancel/refine/applied 状态机端到端 | UITest |

完成判据：
- 4 种 TaskKind 至少 1 种走通 pending → running → awaiting-review → applied
- TaskStateMachine + TaskStore 有持久化测试
- 用户可在 UI 看到 task list + diff review

### 1.5 W1 Provider Runtime — **第五优先级（巩固 + 扩展）**

为什么第五：offline+evidence+ollama 已合格，private/cloud 是新增工作量；
建议先把 listCapabilities + durationMs 这两个 "诚实化" 收掉，再开 private/cloud。

| ID | 类别 | 内容 | 验证 |
|---|---|---|---|
| W1.A | 可逆 | `Provider::listCapabilities()` 改成实际反射 ServiceModePolicy allowlist | 新增 cppunit |
| W1.B | 可逆 | `Provider::call` 实际测量 `durationMs`（osl_getSystemTime 前后） | cppunit 测 ≥ 0 / 上限 < timeout |
| W1.C | gated（D1d 续） | private / cloud TLS：先做 cloud Anthropic-shape adapter；offline 仍是默认 | 新 cppunit |
| W1.D | 可逆 | spec docs 增加 "支持的 capability + 触发回路" 表 | H6 自动收 |

完成判据：
- evidence 字段 `duration_ms` 不再恒 0
- listCapabilities 非空
- 至少一个 cloud adapter（不强制 TLS 实现，先 stub probe）
- spec ↔ schema ↔ C++ 仍多层互锁

## 2. 横切 Tracks（不属于 W1-W5）

### 2.1 B-class blockers

| 编号 | 状态 | 后续 |
|---|---|---|
| B1 Cmd+K 冲突 | open，gated D3c | D3 推进时一并决 |
| B2 harfbuzz Meson UTF-8 | **wrapper 解除** `/tmp/kqoffice-pkgconf-utf8` | 不再算 active blocker；记得 wrapper 是 make-level，不进 git |
| B3 push 受限 | 500MB pack + 无 SSH | 单独沟通 host / Git LFS / shallow push |

### 2.2 Locking System（已经很硬，维持即可）

4 层锁不要回退：
- Tier 1 schema↔C++（H1/H4/H5/H7）— 严禁回 partial
- Tier 2 schema↔manual（H6） — 新 schema.md 自动入册
- Tier 3 lane-status↔artifacts（H2 9/10/11）
- Tier 4 self-consistency（H2 12/13/14/15/16）

每加一个 spec / schema / fixture / harness：
1. 加 spec
2. 加 schema + fixture
3. 加 harness 锁 spec↔schema↔C++
4. 加 reader manual + H6 自动锁
5. lane-status 镜像
6. ledger 一行
7. sweep 7/7 (现 7) 必须仍绿

### 2.3 验证管道（不要绕过）

```
bash bin/v2-harness-sweep.sh                      # H1→H7
bash bin/v2-harness-sweep.sh --with-fixtures      # 36/0 fixture assert
bash tests/v2-plan-baseline-test.sh               # H2 47 checks
make PKG_CONFIG=/tmp/kqoffice-pkgconf-utf8 \
     CppunitTest_<target>                         # 本地 cppunit
```

合并前：
- 7 个 harness 全绿
- 任何变 schema 的 PR 必须同时改 spec + schema + fixture + manual + lane-status，否则 H2/H6 会拒。

## 3. 授权 Gates 速查

只列还未授权的：

| Gate | 内容 | 阻挡 |
|---|---|---|
| D1 | `sw/source/uibase/app/docsh*.cxx` + `sw/source/core/{doc,undo}/` 新文件 + `sw/CppunitTest_sw_apply_engine.mk` + `sw/Module_sw.mk` register（L102 survey 发现 build-system 入口未注册） | W3 真实 wiring |
| D1d | `kqoffice/source/ai/provider/{Provider.cxx,ServiceModePolicy.{hxx,cxx}}` + `kqoffice/qa/cppunit/test_provider.cxx`（W1.A listCapabilities reflection + W1.B osl_getSystemTime duration；~30 行 C++ + 3 cppunit 案例；84→87） | W1 honesty pair |
| D3a | sfx2 dispatcher 4 file（spec §2） | Cmd+K 后端 |
| D3b | cui loader/popover 4 file | Cmd+K 前端 |
| D3c | `Accelerators.xcu` Cmd+K（B1 冲突需同决） | Cmd+K 触发键 |
| D3d | dispatcher cppunit 3 file | Cmd+K 测试 |
| D5 | `downstream-branding/` 来源 | 安装包 branding |
| D6 | worker owned-paths re-scope | 协作 lane（不阻塞主线） |
| D8 | LaunchConstraint.plist team-identifier | 签名 |
| D9 | `GenericCommands.xcu` `.uno:CommandPalette` 11-line en-US 提交 | 最小 D3 子步 |
| W4 source/link | sd `S{D}_DLLPUBLIC` 2 行 + sc `S{C}_DLLPUBLIC` 2 行；sw 与 D1 共享 | W4 cppunit |
| W4 scope | popover + diff-review SRCDIR 路径 | W4 UI |
| W5 scope | worker queue / UI / cancellation | W5 端到端 |
| W1 cloud | cloud adapter + TLS | private/cloud mode |

## 4. 下一会话标准开场

1. `cat docs/product/v2/lane-status.md | tail -n 60`
2. `tail -1 .agent/goals/2026-05-08-v2-ai-native/ledger.jsonl`
3. `bash bin/v2-harness-sweep.sh` — 仍要 7/7 green，否则停下排查
4. `cat docs/product/v2/v2-todo.md` — 抓最上面 unchecked 任务
5. 选可逆 (W3.A / W4.A / W2.A / W5.A / W1.A/B/D / 文档收口) 之一开始
6. 任何 D-gate / W4 source/link / W5 scope / W1 cloud — 要授权前停下

## 5. 风险与陷阱

- 不要在 BUILDDIR 根名带非 ASCII 的环境跑外部 Meson/autotools 项目而不带 wrapper
- 不要 `git add .` —— 永远显式路径
- 不要为绕过 link 错误而 `--no-verify` / 删 cppunit case
- 不要把 `.git.bak-20260510-pre-c/` 加进 git
- 不要在 W3/W4/W5 还没真实 doc-backed 之前对外宣称 "AI 接入完成"
- ApplyPlan 真的写文档之前，所有 Provider 输出仍走 evidence 审计，不能裸接 SwDoc

## 6. 文档生命周期

| 文档 | 维护节奏 | 触发条件 |
|---|---|---|
| lane-status.md | 每 ledger 行 | step_closed |
| ledger.jsonl | append-only | 每 reversible commit |
| handoff doc | ~4 commit | enumeration / D-gate 状态变化 |
| STATUS-2026-05-NN.md | ~5 commit | 阶段性增量 §N 章节 |
| reader manual | schema 改时 | 同 PR |
| **本文件 (roadmap)** | 每个 Wave 阶段交付 / D-gate 解锁后更新 | 不要每次提交都改 |
| **v2-todo.md** | 每完成一项打勾 + 加新发现 | 必要时滚 |

---

最后一次基线（L105 2026-05-13）：H1=26 / H2=47 / H3=26 / H4 full / H5 full / H6=39 / H7 full。
ai-native cppunit OK(84) claimed === OK(84) workdir-verified（L102：所有 4 个 cui_commandpalette_* 在 wrapper 下产出 workdir log；W5 cowork 10 已 wrapper 通过 L101）。
ledger=105。V1.5 27/27 不变。

新增可逆资产（L102-L105）：
- `tmp/w3-apply-link-survey.log` / `tmp/w4-link-survey.log` / `tmp/w2-cppunit-survey.log`
- `tmp/w1-listcap-survey.md` / `tmp/w1-duration-survey.md`
- W1 spec §"Capability ↔ ServiceMode 矩阵"（L103）
- W2 spec §"Backlog § (L102 入册): Pinyin Transliteration 集成草案 (W2.G)"（L103）
- W4 spec §"Popover Invocation Contract"（L103）
- W5 spec §"Worker Queue Scheduling Contract"（L103）
- STATUS §25 覆盖 L102-L103 survey + spec quad
