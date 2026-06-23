# V2 W2 Spec: Cmd+K 命令调色板

Date: 2026-05-08
Wave: W2
Depends on: W1 (provider runtime, 但 v0 不需要)
Master plan: `../v2-master-plan.md`

## Scope

为 可圈office 加一个**自然语言入口**——按 `Cmd+K` 弹出搜索框，输入"插入题注"或
"把这一段加粗" → 直接执行已有 UNO command。两阶段：

- **v0**：纯模糊匹配（命令字典 + 拼音 + fuzzy score），毫秒级响应，**不接 LLM**
- **v1**：v0 不命中时降级到 LLM 解析（走 W1 provider）

对标 Cursor / Linear / Raycast。差异：vs Cursor，可圈office 默认 offline。

## In Scope

1. 全局快捷键 `Cmd+K` (macOS) / `Ctrl+K` (Windows/Linux)
2. 浮窗 UI（GtkPopover 或 sfx2 dialog）
3. 命令索引：所有 UNO `.uno:*` slot ID + 中文名 + 拼音首字母
4. Fuzzy search engine（v0）
5. LLM intent parser（v1，走 W1）
6. 历史记录（最近 10 个）
7. Recent + suggested 优先排序

## Out of Scope

- 不实现 macro 录制 / playback
- 不实现 multi-step workflow（W5 的事）
- 不显示帮助文档（仅触发命令）

## File Map

| 路径 | 类型 | 内容 |
|---|---|---|
| `cui/source/dialogs/commandpalette/CommandPalette.cxx` | new | 浮窗主体 |
| `cui/source/dialogs/commandpalette/CommandIndex.cxx` | new | UNO slot 索引 |
| `cui/source/dialogs/commandpalette/FuzzyMatcher.cxx` | new | 模糊匹配（v0）|
| `cui/source/dialogs/commandpalette/IntentParser.cxx` | new | LLM intent 解析（v1）|
| `cui/source/inc/commandpalette/*.hxx` | new | headers |
| `cui/uiconfig/ui/commandpalette.ui` | new | popover UI |
| `sfx2/source/dispatch/CommandPaletteDispatcher.cxx` | new | 调用 SfxDispatcher |
| `officecfg/registry/data/org/openoffice/Office/UI/GenericCommands.xcu` | modify | 加 `.uno:CommandPalette` accelerator |
| `cui/Library_cui.mk` | modify | gbuild |
| `cui/qa/uitest/commandpalette/test_command_palette.py` | new | UI test |

## v0 设计：Fuzzy Match Engine

### 命令索引数据源

启动时构建：

```cpp
struct CommandEntry {
    OUString unoCommand;     // ".uno:Bold"
    OUString labelEn;        // "Bold"
    OUString labelZh;        // "粗体"
    OUString pinyinFirst;    // "ct" (粗体)
    OUString pinyinFull;     // "cuti"
    OUString contextHint;    // "Writer/Calc/Impress/All"
    int      frequency;      // 用于排序（动态更新）
};
```

数据来源：扫描 `officecfg/registry/data/org/openoffice/Office/UI/*Commands.xcu`，
拿出所有 `<node oor:name=".uno:*">`，提取 `Label` 多语言节点。

### Fuzzy Score 算法

```
score(query, entry) =
    + 100 if query == entry.labelZh / labelEn (exact)
    + 80 if query startsWith entry.pinyinFirst (拼音首字母)
    + 60 if entry.labelZh contains query
    + 40 if entry.labelEn contains query (case-insensitive)
    + entry.frequency / 10  (recency boost)
```

排序后取 top 8 显示。

### 示例

| 用户输入 | 匹配结果 |
|---|---|
| `ct` | 粗体（cuti首字母）/ 删除（shanchu首字母） |
| `插入图片` | `.uno:InsertGraphic` |
| `pdf` | `.uno:ExportToPDF` / 其它含 PDF 的命令 |
| `加粗` | `.uno:Bold` |
| `b` | `.uno:Bold` (B = Bold first letter) / 其它 b 开头 |

## v1 设计：LLM Intent Parser

v0 不命中（top score < 30）时，发 W1 provider request：

```json
{
  "capability": "intent-to-uno",
  "prompt": "用户输入: \"把这一段标题改成 H1\"\n\n候选命令清单（前 50 个 frequency 最高）:\n.uno:HeadingApplyStyle1 - 应用标题 1 样式\n.uno:HeadingApplyStyle2 - 应用标题 2 样式\n...",
  "context": null,
  "timeout_ms": 3000
}
```

provider 返回 JSON：

```json
{
  "uno_command": ".uno:HeadingApplyStyle1",
  "confidence": 0.85,
  "explanation": "用户想把当前段落改为 H1 标题样式"
}
```

如果 confidence < 0.6 → 显示 "未理解，请用更具体的词" 提示。

## UI 流程

```
1. 用户按 Cmd+K
2. 浮窗弹出（屏幕中上 1/3 位置；500x400px）
3. Focus 在 input field
4. 用户键入 → 实时 fuzzy 匹配 → 显示 top 8（每条：图标 + 中文 + 快捷键提示）
5. 用户 Enter → 执行 .uno: command
6. 如 fuzzy 不命中：
   a. 显示 "正在用 AI 解析..."
   b. 走 W1 provider (intent-to-uno)
   c. 命中 → 显示 1 个结果 + 解释
   d. 不命中 → 显示 "未理解" + 链接到帮助
7. 命中后：浮窗关闭 + 命令执行 + frequency++ 并写盘
```

## SfxDispatcher 集成

执行命令通过现有 `SfxDispatcher::Execute()`：

```cpp
void CommandPalette::executeCommand(const OUString& unoCommand) {
    SfxViewFrame* pViewFrame = SfxViewFrame::Current();
    if (!pViewFrame) return;
    SfxDispatcher* pDispatcher = pViewFrame->GetDispatcher();
    if (!pDispatcher) return;

    // 解析 .uno: 命令到 SfxSlot
    URL url;
    url.Complete = unoCommand;
    Reference<XDispatchProvider> xProvider(pViewFrame->GetFrame().GetFrameInterface(), UNO_QUERY);
    Reference<XDispatch> xDispatch = xProvider->queryDispatch(url, OUString(), 0);
    if (xDispatch.is()) {
        Sequence<PropertyValue> args;
        xDispatch->dispatch(url, args);
    }
}
```

## 拼音库

候选：

- 内置：解析时用 `i18npool` 已有 `Transliteration_pinyin`（LO 自带）
- 外部：libpinyin（Linux 常见，macOS 需 brew 装）

**决策**：用 LO 自带，避免新依赖。

## 历史与个性化

最近使用记录写到 `${UserInstallation}/cmdpalette/recent.json`：

```json
{
  "version": 1,
  "entries": [
    {"unoCommand": ".uno:Bold", "lastUsed": "2026-05-08T13:00:00", "useCount": 42},
    {"unoCommand": ".uno:InsertGraphic", "lastUsed": "2026-05-08T12:30:00", "useCount": 7}
  ]
}
```

- 浮窗刚打开（无输入时）显示 top 5 most recent
- frequency 用于 fuzzy score 加权

## 国际化

- UI 字符串走标准 `.po` 流（已 V1.5 接入 zh-CN）
- 命令索引 `labelZh` 直接从 `*Commands.xcu` 中 `xml:lang="zh-CN"` 节点拿
- 拼音生成器只处理 zh-CN labels

## Test Strategy

1. **Unit (`CppunitTest_cui_commandpalette`)**：
   - FuzzyMatcher 排序正确（10+ 用例）
   - CommandIndex 启动时正确扫描 *Commands.xcu
   - Pinyin 生成器准确率 > 95%（200 个常见命令）
2. **UITest (`UITest_commandpalette`)**：
   - Cmd+K 弹出浮窗
   - 输入"加粗"→ 选中段落 → Enter → 段落变粗体
   - Esc 关闭
3. **Smoke (`bin/v2-w2-smoke.sh`)**：
   - 启动 + Cmd+K + "粗体" + Enter + verify

## Security

- 浮窗仅触发已注册的 UNO command（不能任意 sh exec）
- LLM intent parser 输出受白名单约束（只能返回 `.uno:` 前缀的字符串，且必须在 CommandIndex 里）
- 历史记录不含用户输入文本（只存 unoCommand），避免泄漏

## ROI Estimate

- 实施：v0 1.5 周 + v1 1 周 = 2.5 周
- 用户感知：高（即刻可见，每次按键省时）
- 风险：低（不动文档，只调用现有命令）

## Stop Conditions

1. SfxDispatcher 不能在浮窗 thread 中调用 → 改为 main thread post message
2. 拼音生成对部分字符无效 → fallback 到 labelZh substring match
3. UNO command 因 selection state 不同行为不同 → spec 阶段补 selection precondition

## Acceptance Criteria

- [ ] `Cmd+K` 在 Writer/Calc/Impress/Draw 都能弹浮窗
- [ ] 输入"粗体" → 选中文本 → Enter → 文本变粗
- [ ] 输入"insert image" → 弹文件选择器（执行 `.uno:InsertGraphic`）
- [ ] v0 fuzzy 在 < 50ms 返回结果（500 个命令索引）
- [ ] v1 LLM 在 < 3s 返回（offline Ollama）
- [ ] 历史记录持久化
- [ ] UITest 通过
- [ ] V1.5 既有 8/9 beta gate 不退化

## Backlog § (L102 入册): Pinyin Transliteration 集成草案 (W2.G)

> 这一节是 **设计草稿**，不是已批准的实现路径，不入 SRCDIR。
> 目的是在 i18npool gated（D1c）放行之前，把 pinyin 集成所需的接口面、性能上限、回退策略冻结下来；放行后只做实现层面落地。

### 1. 现状

- `cui/source/inc/commandpalette/CommandIndex.hxx` 中 `Entry::pinyinFirst` / `pinyinFull` 字段 **当前由调用方手填**（spec §"v0 设计 §Fuzzy Match Engine"）。
- LO 自带 `i18npool` 提供 `css.i18n.Transliteration` 服务，其中存在 `pinyin` 风格变体 `TRANSLITERATION_pinyin_(numeric|toneless)`。
- W2 OK(33) cppunit 全部走 hand-filled fixture，没有对真实 zh-CN label → pinyin 的 transliteration 通道做端到端覆盖。

### 2. 目标接口（design-only）

```cpp
namespace cui::commandpalette
{
struct PinyinHints
{
    OUString full;   // "cuti"
    OUString first;  // "ct"
};

// 单点入口；offline 模式 100% 本地，不出域。
PinyinHints transliterateLabel(const OUString& zhLabel);
}
```

调用约定：
- 输入字符串可包含混合 ASCII / CJK / fullwidth / emoji；非 zh 部分按原样小写并保留。
- 返回 `full` 是按字逐个拼音用空格隔开的 join；`first` 是每个字拼音首字母的拼接（去声调）。
- 异常路径 fallback：transliteration 服务不可达 / 输入不可识别字符 → 返回 `{full="", first=""}`，调用方按 spec §"v0 Fuzzy Match Engine" 已有路径降级到 labelZh substring。

### 3. 调用回路

```
CommandIndex::buildFromCommands()
  └─ for each (unoCommand, labelZh) in xcu:
       ├─ entry.label    = labelZh
       ├─ entry.pinyin   = transliterateLabel(labelZh)
       └─ entry.unoSlot  = unoCommand
```

入口点必须在索引构建一次（启动 / locale change），不在每次 query 即时触发。Query 阶段只读已构建的 `entry.pinyinFirst/Full`（与 spec §"v0 设计" 已经一致）。

### 4. 性能上限

- 单次 transliteration ≤ 5ms（i18npool zh-CN 内置数据，不走 IO）
- 全索引重建（500 命令） ≤ 2.5s（启动可摊销）
- 索引内存 ≤ 250KB（500 entries × ~500 bytes 平均）

超上限时降级（按优先级）：
1. 关闭 `pinyinFull`，只填 `pinyinFirst`（首字母够 80% query 用例）
2. 关闭 pinyin 整路，回到 labelZh substring（spec §"v0 Fuzzy Match Engine" 既有路径）

### 5. 回退矩阵

| 场景 | 行为 |
|---|---|
| `i18npool` Transliteration 服务初始化失败 | 启动告警 + 回退 substring；不阻 W2 启动 |
| zh-CN 之外的 label（en-US / fr / etc.） | 跳过 transliterate；只填 latin lowercase 到 `pinyinFirst.full` |
| 单字无对应拼音（GB18030 ext B 等罕见字） | 该字位置填 `?`，整体不阻断 |
| 用户切 locale | 重建索引 + 重新 transliterate；不复用上次结果 |

### 6. Test Strategy（设计阶段，cppunit 落地待 D1c）

- 黄金集 200 个高频命令（cut/copy/paste/bold/italic/insert image/...）→ 准确率 ≥ 95%
- 边界 case：emoji label（不应崩）/ 全英文 label（仅 lowercase）/ 混合 label（"插入 image"）
- 性能：` benchmark::transliterateLabel(label) ≤ 5ms` 99-percentile
- 错误注入：模拟 `Transliteration::createInstance` 抛 → fallback 路径走通

### 7. 与 W1 capability 矩阵的关系

`intent-to-uno` capability（offline allowlist 第 4 项, W1 spec §"Capability ↔ ServiceMode 矩阵"）将与 W2 controller 共用 transliteration —— intent parser 输入纯中文 prompt 时，需要先生成 pinyin 让 fuzzy 兜底候选。这是 W1 / W2 共有约束，spec §"v1 设计：LLM Intent Parser" 已隐含但未明写。本 backlog 把这条耦合显式化。

### 8. 不在本 backlog 内（避免范围爆炸）

- 真实 i18npool 服务调用代码（gated D1c）
- `Transliteration_pinyin` 是否需要包装 wrapper service（设计上不需要，直接调）
- 多音字处理（默认取 i18npool 默认变体；多音字策略留 v2）

### 9. Gate

- D1c：实际触动 i18npool 时打开。本 backlog 只锁接口，不动代码。
- 落地顺序建议：在 D3a-d 全部解开、Cmd+K 端到端跑通后再开 D1c —— 因为 fuzzy + recent + 历史回路（已 OK(33) workdir-verified）已经能覆盖大部分 zh-CN query 用例（用 labelZh substring），pinyin 是上限优化不是必需路径。
