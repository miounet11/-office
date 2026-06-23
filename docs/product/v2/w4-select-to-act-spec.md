# V2 W4 Spec: Select-to-Act 浮窗 + Diff 审批视图

Date: 2026-05-08
Wave: W4
Depends on: W1 (provider), W3 (Writer apply runtime)
Master plan: `../v2-master-plan.md`

## Scope

把 V1.5 + W1 + W3 凑成"**选中即操作 / 预览即审批 / 应用即可撤销**"完整体验。
对标 Word Copilot 浮动按钮、Notion AI inline、Cursor inline edit。

**两个核心组件**：

1. **Select-to-Act 浮窗**：选中段落 / 单元格 / 形状对象后，浮出 AI 动作气泡
2. **Diff 审批视图**：sidebar 中显示"AI 提议的 patch 列表"，逐项 accept/reject/undo

## In Scope

1. Writer 段落级浮窗（W4-A）
2. Calc 单元格 / range 浮窗（W4-B）
3. Impress 对象浮窗（W4-C）
4. Diff 审批 sidebar deck（W4-D）
5. 全局"撤销最后一次 AI 应用"快捷键（Cmd+Shift+Z）

## Out of Scope

- 不实现 Draw / Math 浮窗
- 不实现批量"对所有段落应用"功能（W5 范畴）
- 不实现协作模式下的 diff 合并（V2 不做云协作）

## File Map

### W4-A Writer 浮窗

| 路径 | 类型 | 内容 |
|---|---|---|
| `sw/source/uibase/inline-actions/SelectToActPopover.cxx` | new | 浮窗主体 |
| `sw/source/uibase/inline-actions/ParagraphActions.cxx` | new | 注册 7 个段落动作 |
| `sw/source/uibase/inline-actions/ParagraphActions.hxx` | new | header |
| `sw/uiconfig/swriter/ui/select-to-act-popover.ui` | new | UI |
| `sw/Library_sw.mk` | modify | gbuild |

### W4-B Calc 浮窗

| 路径 | 类型 | 内容 |
|---|---|---|
| `sc/source/ui/inline-actions/CellRangePopover.cxx` | new | 浮窗 |
| `sc/source/ui/inline-actions/CellActions.cxx` | new | 5 个单元格动作 |
| `sc/uiconfig/scalc/ui/cell-range-popover.ui` | new | UI |

### W4-C Impress 浮窗

| 路径 | 类型 | 内容 |
|---|---|---|
| `sd/source/ui/inline-actions/ObjectPopover.cxx` | new | 浮窗 |
| `sd/source/ui/inline-actions/ObjectActions.cxx` | new | 4 个对象动作 |
| `sd/uiconfig/simpress/ui/object-popover.ui` | new | UI |

### W4-D Diff 审批 Sidebar Deck

| 路径 | 类型 | 内容 |
|---|---|---|
| `svx/source/sidebar/diff-review/DiffReviewPanel.cxx` | new | sidebar panel |
| `svx/source/sidebar/diff-review/DiffEntry.cxx` | new | 单条 diff UI |
| `svx/uiconfig/ui/diff-review-panel.ui` | new | UI |
| `officecfg/registry/data/org/openoffice/Office/UI/Sidebar.xcu` | modify | 注册 DiffReviewDeck |

## Writer 浮窗动作（W4-A）

选中段落（>= 1 个完整段落）→ 触发显示，靠近选区右上角：

| 图标 | 动作 | 走 W1 capability | 输出 |
|---|---|---|---|
| ✏️ | 改写 (rewrite) | `rewrite` | ApplyPlan with paragraph-replace patch |
| 📝 | 扩写 (expand) | `expand` | paragraph-replace |
| ✂️ | 简写 (shorten) | `shorten` | paragraph-replace |
| 🌐 | 翻译为英文 | `translate-en` | paragraph-replace |
| 🧹 | 清理格式 | `format-clean` (本地，不走 LLM) | paragraph-format reset |
| 💬 | 解释 | `explain` | 仅显示弹窗，不改文档 |
| ⚙️ | 自定义提示 | `custom` | 用户输入 prompt |

每个动作触发：

```
1. 用户点动作 → 浮窗显示 "正在生成..."
2. 走 W1 provider.call({capability, prompt, context: selection})
3. provider 返回 ProviderResponse with apply_plan
4. 浮窗隐藏 → Diff 审批 sidebar 自动打开 → 显示 patch
5. 用户选择 accept / reject / refine
6. accept → 走 W3 applyDiagnosticsPlan → 文档更新
```

**关键不变量**：浮窗动作**永不直接改文档**，必须经过 Diff 审批。

## Calc 浮窗动作（W4-B）

选中 range（>= 1 cell）→ 浮窗显示：

| 图标 | 动作 | 输出 |
|---|---|---|
| 🔍 | 解释这些数据 | 弹窗（不改）|
| 📊 | 建议图表 | 插入 chart（要审批）|
| 🧮 | 生成公式 | 替换选中 cell（要审批）|
| 🧹 | 清理格式 | range format reset |
| 🔢 | 改为日期格式 / 货币 / 百分比 | format change |

## Impress 浮窗动作（W4-C）

选中对象（文本框 / 形状）→ 浮窗：

| 图标 | 动作 | 输出 |
|---|---|---|
| ✏️ | 改写文字 | 文本框内容替换 |
| 🎨 | 调整配色 | 形状颜色改 |
| 🔄 | 重新排版（保留内容）| 位置/大小调整 |
| 🌐 | 翻译 | 文本替换 |

## Diff 审批 Sidebar Deck（W4-D）

新 deck `DiffReviewDeck`：

```
┌─ Diff 审批 ──────────────────────────┐
│ AI 提议 5 项改动                       │
│ [全部接受] [全部拒绝]                  │
├──────────────────────────────────────┤
│ ✏️ 段落 42: 改写                       │
│   原文: "本段表述太啰嗦..."             │
│   建议: "本段表述简洁..."              │
│   [✓ 接受] [✗ 拒绝]                    │
├──────────────────────────────────────┤
│ 📝 段落 43: 改样式                     │
│   原: 正文                             │
│   建议: Heading 2                      │
│   [✓ 接受] [✗ 拒绝]                    │
├──────────────────────────────────────┤
│ ...                                   │
├──────────────────────────────────────┤
│ 已接受: 2  已拒绝: 1  待审: 2          │
│ [应用已接受 (2)] [全部撤销]            │
└──────────────────────────────────────┘
```

## Diff 数据流

```
ProviderResponse.apply_plan
    │
    ▼
DiffReviewPanel.populate(plan)
    │  生成 N 个 DiffEntry widget
    ▼
用户交互 (accept/reject/全部)
    │
    ▼
[应用已接受] 按钮 → W3.applyDiagnosticsPlan(filtered_plan)
    │
    ▼
ApplyResult → DiffReviewPanel.markApplied()
```

## 全局快捷键

- `Cmd+Shift+Z`：撤销最后一次 AI 应用（即整个 ApplyPlan，单 entry 标记为 "AI Apply: ap-..."）
- `Cmd+K`：W2 Cmd+K 浮窗（不冲突）
- 选中文本时按 `Option+E`：触发 Select-to-Act 浮窗（无鼠标用户）

## VCL 集成挑战与方案

LO VCL 默认无"上下文浮窗"基础设施。两条路径：

**A. 复用 GtkPopover (Linux/macOS gtk3 backend)**：
- 在 `vcl/unx/gtk3/gtkframe.cxx` 加 popover 创建 helper
- macOS 走 NSPopover (vcl/osx)
- Windows 走 ToolTip extended（缺 native popover）

**B. sfx2 Sidebar 临时 panel**：
- 选中时在 sidebar 顶部弹出"AI 动作"轻量 panel
- 跨平台一致性更好；牺牲"贴近选区"视觉

**spec 阶段决策**：W4 实施前做 1 周 spike，从 A/B 中选。当前倾向 **A**（macOS 优先，Windows 用 fallback B）。

## evidence

每次 select-to-act 完整流程记一条 evidence：

```json
{
  "evidence_id": "ev-w4-...",
  "trigger": "writer-paragraph-popover",
  "capability": "rewrite",
  "selection": {"paragraph_id": "swpara-42", "text_hash": "..."},
  "plan_id": "ap-...",
  "user_decisions": [
    {"patch_id": "p1", "decision": "accept"},
    {"patch_id": "p2", "decision": "reject"}
  ],
  "applied": true,
  "duration_ms": 5400
}
```

## Test Strategy

1. **Unit**：每个 popover class 的 layout & action register
2. **UITest**：
   - 选段落 → 浮窗出现 → 点改写 → diff sidebar 弹出 → 接受 → 文档变
   - 同样流程在 Calc / Impress
3. **Smoke (`bin/v2-w4-smoke.sh`)**：
   - 自动化跑 Writer 改写流程，断言文档前后 hash 不同
4. **Visual regression**：
   - 浮窗截图 vs baseline（容忍 ≤ 5px 偏差）

## ROI Estimate

- 实施：6-8 周（3 个 surface + 1 sidebar + spike）
- 用户感知：极高（这是 V2 最直观的"AI 一等公民"体验）
- 风险：中（VCL 浮窗基础设施 + 跨 surface 一致性）

## Stop Conditions

1. macOS NSPopover 与 LO 主窗口 z-order 冲突 → fallback 到 sfx2 sidebar
2. Sidebar deck 注册无法动态显示 / 隐藏 → 改为 always-on 但 collapsed
3. ApplyPlan 含的 patch 数 > 50 时 sidebar 卡 → 引入分页
4. Diff 视图无法处理 paragraph-format（无可视 diff） → 改为"前后样式名"展示

## Day-0 Entry-Point Plan (skeleton)

> **Status**: planned. This section enumerates the smallest set of files
> that must land first so subsequent W4 sub-steps can be parallelized
> safely. No production behavior; each file is either a header-only
> placeholder, an empty TU registered into its module's gbuild, or a
> contract-only fixture/test. Mirrors the W1/W2 Day-0 layout that
> shipped 2026-05-08.

### Action enum lock (source-of-truth for Day-0 headers)

These are the exact ASCII kebab-case tokens that W4 Day-0 will hard-code
into the action enums. Locked here in the spec so future drift between
spec wording, enum names, and `apply-plan-runtime.schema.json` capability
strings cannot happen silently. Any new action proposed in a later wave
must add a row to this table *and* the matching `XCapability` enum *and*
the schema enum in the same change.

**W4-A Writer (`enum class ParagraphAction` — 7 tokens, matches the spec
table at §"Writer 浮窗动作"):**

| Token | UI label (zh-CN) | UI label (en-US) | W1 capability | Goes through Diff? |
|---|---|---|---|---|
| `rewrite`        | 改写              | Rewrite              | `rewrite`        | yes |
| `expand`         | 扩写              | Expand               | `expand`         | yes |
| `shorten`        | 简写              | Shorten              | `shorten`        | yes |
| `translate-en`   | 翻译为英文         | Translate to English | `translate-en`   | yes |
| `format-clean`   | 清理格式           | Clean Formatting     | n/a (local)      | yes |
| `explain`        | 解释              | Explain              | `explain`        | **no** (popup-only) |
| `custom`         | 自定义提示         | Custom Prompt        | `custom`         | yes |

**W4-B Calc (`enum class CellAction` — 5 tokens, matches §"Calc 浮窗动作"):**

| Token | UI label (zh-CN) | UI label (en-US) | Goes through Diff? |
|---|---|---|---|
| `explain-data`     | 解释这些数据  | Explain Data           | **no** (popup-only) |
| `suggest-chart`    | 建议图表       | Suggest Chart           | yes |
| `generate-formula` | 生成公式       | Generate Formula        | yes |
| `format-clean`     | 清理格式       | Clean Formatting        | yes |
| `format-change`    | 改格式         | Change Format           | yes (date/currency/%) |

**W4-C Impress (`enum class SlideElementAction` — 4 tokens, matches §"Impress 浮窗动作"):**

| Token | UI label (zh-CN) | UI label (en-US) | Goes through Diff? |
|---|---|---|---|
| `rewrite-text`   | 改写文字   | Rewrite Text       | yes |
| `adjust-color`   | 调整配色   | Adjust Color       | yes |
| `relayout`       | 重新排版   | Relayout           | yes |
| `translate-text` | 翻译       | Translate Text     | yes |

**Naming rules (locked):**
- Lowercase ASCII, kebab-case, no underscores.
- No verbs/nouns mixing — pick the imperative form (`rewrite`,
  `suggest-chart`), not the participle (`rewriting`, `chart-suggestion`).
- Tokens that span multiple surfaces (`format-clean`) reuse the same
  string across enums — do not localize the token per surface.
- "Goes through Diff?" column maps directly to whether Day-1 wires the
  action through `Diff Review` sidebar; popup-only actions
  (`explain`, `explain-data`) never produce an `ApplyPlan`.

### What lands in Day-0

1. **W4-A Writer header skeleton** — `sw/source/uibase/inline-actions/`
   - `ParagraphActions.hxx` (new, header-only): action enum
     (`rewrite | expand | shorten | translate-en | format-clean |
     explain | custom`) + free-function signatures, no implementations.
   - `SelectToActPopover.hxx` (new, header-only): popover lifecycle
     interface (`open(rect, paragraph_id) / close() / dispatchSelected()`),
     no VCL dependency yet.
   - `SelectToActPopover.cxx` / `ParagraphActions.cxx` (new, empty TUs):
     compiled into `Library_sw` via `sw/Library_sw.mk` so the link
     surface is stable for Day-1 popover wiring.
2. **W4-B Calc header skeleton** — `sc/source/ui/inline-actions/`
   - `CellActions.hxx` (new, header-only): 5-action enum
     (`explain-data | suggest-chart | generate-formula | format-clean |
     format-change`) + free-function signatures.
   - `CellRangePopover.hxx` / `.cxx` (new, header + empty TU): same
     popover lifecycle shape as W4-A; empty TU compiled via
     `sc/Library_sc.mk`.
3. **W4-C Impress header skeleton** — `sd/source/ui/inline-actions/`
   - `SlideElementActions.hxx` + `SlideElementPopover.{hxx,cxx}`
     mirroring W4-A/B; 4-action enum (`rewrite-text | adjust-color |
     relayout | translate-text`).
4. **W4-D Diff sidebar skeleton** — `svx/source/sidebar/diff-review/`
   - `DiffReviewPanel.hxx` + empty `.cxx` registered as a sidebar deck
     factory entry only (`officecfg/.../Sidebar.xcu` deck node);
     accept/reject buttons wired to no-op handlers.
5. **Pure-logic cppunit (no VCL bring-up)** — one `CppunitTest_*` per
   surface with header-only action-enum stability tests
   (`testParagraphActionEnumStable`, `testCellActionEnumStable`,
   `testSlideElementActionEnumStable`) so the action set cannot drift
   silently before Day-1.

### Out of scope for Day-0

- Real popover rendering (VCL `weld::Popover` / NSPopover bring-up).
- Any provider call (`XProvider::call`); Day-0 popovers fire a
  `dispatchSelected()` signal only, like W2 Day-0.
- Diff sidebar actually showing patches; the deck registers but renders
  an empty placeholder.
- Cross-surface action consistency tests (deferred to Day-1d).

### Verification gate for Day-0

- `make sw.build sc.build sd.build svx.build` clean.
- `make CppunitTest_sw_inline_actions CppunitTest_sc_inline_actions
   CppunitTest_sd_inline_actions` green (3 binaries × ≥1 enum-stability
   case each → ≥3 new pure-logic cases).
- Sidebar deck visible as a registered (but empty) entry under
  `Sidebar.xcu`.
- V1.5 27/27 strict roundtrip baseline untouched.

### Authorization required before Day-0 starts

W4 spans `sw/`, `sc/`, `sd/`, `svx/`, `officecfg/`. None of those (except
`officecfg`) are on the current pre-authorized allow-list (`sfx2 sdi /
officecfg / cui commandpalette / sw docsh`), so Day-0 cannot begin
without an explicit scope grant for `sw/source/uibase/inline-actions/`,
`sc/source/ui/inline-actions/`, `sd/source/ui/inline-actions/`, and
`svx/source/sidebar/diff-review/`. The header-only nature of Day-0
keeps the blast radius small once authorized.

## Schema reader's manual

The W4 inline-action-request envelope schema body lives at
`docs/schemas/inline-action-request.schema.json`. A 10-section human
guide explaining *why* each property exists, *why* the
`oneOf`-on-`surface` shape rejects cross-surface drift at the schema
layer, and what's intentionally not locked (cross-field
`action=custom ⇒ user_prompt`, multi-target trigger, action chaining,
result correlation, telemetry) lives at
`docs/schemas/inline-action-request.schema.md`. Read the manual
before hand-deriving `sw/source/uibase/inline-actions/ParagraphActions.hxx`
or its Calc / Impress siblings — it captures intent that isn't
recoverable from the schema body alone.

Token-lock anchor: this spec's §"Action enum lock" subsection (above)
is the single source of truth the schema oneOf branches mirror.
Drift is caught by `tests/v2-inline-action-request-schema-test.sh`
(H5 partial-enforce; auto-promotes to full-enforce when all three
`*Actions.hxx` headers land in SRCDIR).

## Dependencies

- W1：所有动作走 provider runtime
- W3：accept 后的 apply 走 Writer Apply Runtime
- V1.5：IntelligentWriterAnalyzer 数据结构

## Acceptance Criteria

- [ ] Writer 段落选中 → 浮窗 0.3s 内显示
- [ ] 点"改写" → < 5s 出 diff（offline Ollama 7B 模型）
- [ ] Diff sidebar 列出 N 个 patch（accept/reject 独立）
- [ ] 应用后 Cmd+Z 一次撤销整个 Plan
- [ ] Cmd+Shift+Z 撤销最近 AI 应用
- [ ] Calc / Impress 浮窗同样 work
- [ ] UITest 全部 pass
- [ ] V1.5 8/9 beta gate 不退化

## Popover Invocation Contract (L102 入册, design-only)

> 这一章是 **接口冻结**，不是 GUI 实装路径，不入 SRCDIR。
> 目的是在 W4 scope 授权之前，把"selection → popover 触发 → action 选择 → ApplyPlan 提交"这一条核心链路的协议表达式锁下来；scope 放行后只做 VCL 层实现。
> 这一条契约同时被 W5 任务"awaiting-review"复用（W5 spec §"通知" + diff review 浮窗与本 popover 共享 entry surface）。

### 1. Invocation 三态

popover 三种触发态，任意一态都必须能 100% 复现到 H5 inline-action-request fixture：

| 触发态 | 入口 | 默认 capability（W1 矩阵） | 备注 |
|---|---|---|---|
| `manual` | 用户选区 + 鼠标右键 / Cmd+. | 不预选 | 用户手动主动；spec §"全局快捷键" |
| `auto-hover` | 选区稳定 ≥ 400ms 且超过 minLen 字符 | 不预选 | 默认 off，需 Settings → AI 开启 |
| `programmatic` | 上层调用 `SelectToActPopover::invoke(req)` | 由 caller 指定 | W5 cowork "awaiting-review" 走这条 |

三态在 `inline-action-request.schema.json` 里的差异 = `triggerSource` 枚举（schema v1 当前为 3 token：`manual | auto-hover | programmatic`，与本表对齐）。

### 2. 输入契约（caller → popover）

popover 接收的 request 必须能由 `inline-action-request.schema.json` (H5 full-enforce) 完整描述。即：

```
InlineActionRequest {
  surface          : "writer" | "calc" | "impress"       // 与 W4 三 surface 对齐
  triggerSource    : "manual" | "auto-hover" | "programmatic"
  selection        : ParagraphRef | CellRangeRef | SlideElementRef
                     // surface 决定子类型；3 套 ref schema 在 SRCDIR 已落
  candidateActions : [TokenString, …]
                     // 子集 of ParagraphAction(7) | CellAction(5) | SlideElementAction(4)
                     // 空数组 = popover 自决（按 surface 默认全集展示）
  evidenceCorrelationId? : string
                     // W5 cowork 任务回触发时必填，闭合 evidence 链
}
```

不变量：
- `surface` 与 `selection` 子类型必须一致；不一致 = caller 错误，popover 拒绝调用并返回 `policy-denied` evidence。
- `candidateActions` 元素必须在对应 surface 的 W4 token 集内（见 spec §"Writer/Calc/Impress 浮窗动作" 章节）。
- `evidenceCorrelationId` 如果填了，必须能在 evidence store 里 join 到一个未关闭的 cowork task；否则视同没填，popover 自启新 evidence 链。

### 3. 输出契约（popover → caller）

popover 返回（点击 action 或 ESC 关闭）：

```
PopoverOutcome {
  decision       : "applied" | "rejected" | "cancelled"
  chosenAction?  : TokenString   // decision=applied 时必填
  applyPlanRef?  : PlanIdString  // decision=applied 时必填，对应 H7 apply-plan-runtime
  evidenceId     : string        // 始终必填，包括 cancelled
}
```

不变量：
- `decision=cancelled`（ESC / 焦点丢） → 不触发 W3 ApplyPlan，不调 W1 provider，但仍记 evidence（用于审计 user-side abandonment 率）。
- `decision=rejected`（用户看了候选 + 显式叉掉） → 同 cancelled，但 evidence reason 字段标 `user-rejected`，与"无意取消"区分。
- `decision=applied` → caller 必须立即在 ≤ 100ms 内把 `applyPlanRef` 派给 W3 `SwDocShell::applyDiagnosticsPlan`（或对应 Calc/Impress entry），不允许中间用户再编辑文档。否则 plan 失效（`doc_snapshot_hash` 不一致），W3 会 reject。

### 4. 时序约束

```
T+0     : caller invoke(req)
T+50ms  : popover frame 必须可见（VCL render budget）
T+50ms..选 action : 用户停留任意时长（无超时）
T+选action+100ms : caller 必须 dispatch applyPlanRef → W3
T+5s    : 如果 5s 内 W3 没回 applied/failed，evidence 标 stale，UI 可降级到 progress indicator
```

`auto-hover` 模式额外：触发到 frame 可见之间允许 200ms 渲染 budget（比 manual 宽松，因为不需要响应用户操作）。

### 5. 与 W3 / W5 的耦合点

- **W3 wiring**：popover applied 路径 = `ApplyPlanValidator.validate(plan)` → `SwDocShell::applyDiagnosticsPlan(plan)`。当前 D1 阻 wiring，所以 popover 也只能 stub。W3 spec §"Apply Runtime" 的 7 patch kind 是 popover applied → W3 这一条 hop 的唯一 payload schema。
- **W5 wiring**：`programmatic` 触发态由 W5 cowork "awaiting-review" task 调用。popover 不知道 W5 的存在，只看到一个普通 InlineActionRequest with `evidenceCorrelationId` 已填。W5 不该往 popover 里偷塞 task-specific UI；如果 W5 需要展示任务上下文（"周报第 3 段，置信度 0.82"），由 caller 在 popover 外的容器里显示。

### 6. 不在本契约内（避免范围爆炸）

- VCL widget 实现层（gated W4 scope）
- popover 视觉规范（spacing / 配色 / animation） — 设计稿层面，不在 spec
- popover 多语言 strings — locale 层面，与 W1.G/W2.G 一起算
- popover 与系统级 menubar 焦点抢夺策略 — VCL 集成挑战 §"VCL 集成挑战与方案" 已记，本契约不重复

### 7. Gate

- W4 source/link：sc/sd `S{C,D}_DLLPUBLIC` 修复后才能跑通 popover 信号路径单元测试。
- W4 scope：popover VCL 实装、selection 监听、按钮触发 ApplyPlan 落地都在 W4 scope 范围内。
- D1：popover applied → W3 wiring 那一 hop 受 D1 阻。

本契约本身是 docs/product/v2 spec 增量，不带任何代码改动。落地顺序建议：W4 source/link 解开 → 跑通 popover 信号 cppunit → W4 scope 解开 → VCL 实装 → D1 解开 → 接 W3 → 端到端 UITest。
