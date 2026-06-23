---
title: W2 Day-1b — CommandPalette sfx2 dispatcher + corpus loader + Cmd+K accel
date: 2026-05-12
wave: V2 W2
slice: Day-1b
status: design-approved
author: clavue (brainstorming skill)
---

# W2 Day-1b 设计规格

## 0. 背景与边界

- **V2 W2** 总目标：Cmd+K 命令面板（面向 Writer/Calc/Draw/Impress/Base/Math 全栈）。
- **Day-0（已落）**：controller / fuzzy / .ui / sfx.sdi slot / sfxsids.hrc / appslots.sdi / appserv.cxx placeholder handler。
- **Day-1b（本规格）**：将 appserv placeholder 换为真实 dispatcher，加 Cmd+K 全局 accel，从 SfxSlotPool 动态建 corpus。
- **Day-1c（下轮）**：Start Center fallback、拼音检索、frequency 持久化、multi-monitor 修正。

### Day-0 锁（不动）
- `CommandPaletteController` header API：`setCorpus / queryToResults / corpus / shouldDispatch` — 签名冻结。
- `cui/source/inc/commandpalette/CommandPalette.hxx`（73 行）不动。
- `cui/uiconfig/ui/commandpalette.ui` widget id（CommandPalette / search_input / results_view / hint_label / results_store）不动。
- `SID_COMMAND_PALETTE` slot 号已定（`include/sfx2/sfxsids.hrc:305` → `SID_SFX_START + 1753`），不重排。
- `sfx2/sdi/sfx.sdi:5936` 的 `SfxVoidItem CommandPalette SID_COMMAND_PALETTE` block 不动。
- `sfx2/sdi/appslots.sdi:238` 的 `SID_COMMAND_PALETTE` 不动。

---

## 1. 架构总览

分层：**A slim** 方案（appserv slot + loader only，不抽 sfx2 基类）。

```
AccelCmd+K
   ↓ (Accelerators.xcu)
SfxDispatcher::Execute(.uno:CommandPalette, ASYNCHRON)
   ↓
SfxApplication::MiscExec_Impl → case SID_COMMAND_PALETTE
   ↓
CommandPaletteDispatcher::ShowPalette(SfxViewFrame::Current())
   ↓
  ├─ CommandPaletteLoader::buildCorpusFromSlotPool() → CommandPaletteController::setCorpus
  ├─ new CommandPalette popover (持有 dispatcher ref)
  └─ popover.show()
      ↓ user 选中 item
      ↓ CommandPaletteController::shouldDispatch(item) == true
      ↓
CommandPaletteDispatcher::dispatchUrl(url)
   ↓ 递归保护：if (url == ".uno:CommandPalette") return;
   ↓ frequency[url]++（进程内 static std::map，main thread only）
   ↓
SfxDispatcher::Execute(url, ASYNCHRON)
```

**宿主**：`SfxViewFrame::Current()`（当前 view）。Start Center 无 view，Day-1b 不支持，推 Day-1c。

---

## 2. 文件清单

| # | 路径 | 状态 | 用途 |
|---|------|------|------|
| 1 | `sfx2/inc/dispatch/CommandPaletteDispatcher.hxx` | **新增** | dispatcher 类声明（ShowPalette / dispatchUrl / recordFrequency） |
| 2 | `sfx2/source/dispatch/CommandPaletteDispatcher.cxx` | **新增** | dispatcher 实现 + static frequency map + 递归保护 |
| 3 | `sfx2/source/appl/appserv.cxx` | **改** | L1321-1331 placeholder MessageDialog → 调 `CommandPaletteDispatcher::ShowPalette` |
| 4 | `sfx2/Library_sfx.mk` | **改** | 加 `sfx2/source/dispatch/CommandPaletteDispatcher` |
| 5 | `cui/source/dialogs/commandpalette/CommandPaletteLoader.hxx` | **新增** | corpus 从 SfxSlotPool dump 的 static helper |
| 6 | `cui/source/dialogs/commandpalette/CommandPaletteLoader.cxx` | **新增** | 实现：遍历 SfxSlotPool → 过滤可见 slot → 产 `std::vector<CommandItem>` |
| 7 | `cui/source/dialogs/commandpalette/CommandPalette.cxx` | **改** | ShowPalette 调 Loader 拿 corpus + 选中后调 dispatcher |
| 8 | `cui/Library_cui.mk` | **改** | 加 CommandPaletteLoader |
| 9 | `officecfg/registry/data/org/openoffice/Office/Accelerators.xcu` | **改** | 加 `command:*` + `keyboard:mod1 K` → `.uno:CommandPalette`（全局，非 module 专属） |
| 10 | `cui/qa/unit/CommandPaletteDispatcherTest.cxx` | **新增** | 5 cases cppunit |
| 11 | `cui/CppunitTest_cui_dispatcher.mk` | **新增** | 新 harness makefile |
| 12 | `cui/Module_cui.mk` | **改** | 注册 `CppunitTest_cui_dispatcher` 入 check_targets |

**不动**（Day-0 已落）：sfx.sdi / sfxsids.hrc / appslots.sdi / CommandPalette.hxx / commandpalette.ui / CommandPaletteController.cxx。

---

## 3. 数据流（关键路径）

### 3.1 Cmd+K → popover

```cpp
// sfx2/source/appl/appserv.cxx (改后)
case SID_COMMAND_PALETTE:
{
    if (SfxViewFrame* pFrame = SfxViewFrame::Current())
        sfx2::CommandPaletteDispatcher::Get().ShowPalette(*pFrame);
    // else: Start Center，Day-1c 处理
    break;
}
```

### 3.2 dispatcher 核心

```cpp
// sfx2/inc/dispatch/CommandPaletteDispatcher.hxx
namespace sfx2 {
class SFX2_DLLPUBLIC CommandPaletteDispatcher {
public:
    static CommandPaletteDispatcher& Get();        // 进程单例
    void ShowPalette(SfxViewFrame& rFrame);
    void dispatchUrl(SfxViewFrame& rFrame, OUString const& url);
    sal_uInt32 frequency(OUString const& url) const;
private:
    CommandPaletteDispatcher() = default;
    std::map<OUString, sal_uInt32> m_frequency;    // main thread only, no lock
    std::unique_ptr<CommandPalette> m_pActivePopover;
};
}

// sfx2/source/dispatch/CommandPaletteDispatcher.cxx
void CommandPaletteDispatcher::dispatchUrl(SfxViewFrame& rFrame, OUString const& url)
{
    if (url == u".uno:CommandPalette")
        return;                                    // 递归保护
    ++m_frequency[url];
    rFrame.GetDispatcher()->Execute(
        SfxSlotPool::GetSlotFromUnoName(url)->GetSlotId(),
        SfxCallMode::ASYNCHRON);
}
```

### 3.3 corpus loader

```cpp
// cui/source/dialogs/commandpalette/CommandPaletteLoader.cxx
std::vector<CommandItem> CommandPaletteLoader::buildCorpus(SfxViewFrame& rFrame)
{
    std::vector<CommandItem> out;
    SfxSlotPool& rPool = SfxSlotPool::GetSlotPool(&rFrame);
    for (sal_uInt16 nGroup = 0; nGroup < rPool.GetGroupCount(); ++nGroup) {
        for (const SfxSlot* p = rPool.FirstSlot(); p; p = rPool.NextSlot()) {
            if (!p->GetUnoName().startsWith(".uno:"))  // skip internal
                continue;
            out.push_back({ p->GetUnoName(), p->GetCommand(), /*label lookup*/... });
        }
    }
    return out;
}
```

每次 popover open 重新 load（Day-1b 不缓存）。

### 3.4 选中 → dispatch

```cpp
// cui/source/dialogs/commandpalette/CommandPalette.cxx (改)
IMPL_LINK(CommandPalette, RowActivated, weld::TreeView&, rTV, bool)
{
    auto item = m_aController.corpus()[rTV.get_selected_index()];
    if (m_aController.shouldDispatch(item)) {
        Hide();
        sfx2::CommandPaletteDispatcher::Get().dispatchUrl(m_rFrame, item.url);
    }
    return true;
}
```

---

## 4. 错误处理

| 场景 | 策略 |
|------|------|
| `SfxViewFrame::Current() == nullptr`（Start Center） | appserv no-op，Day-1c 接 |
| corpus load 异常（SlotPool 访问失败） | `buildCorpus` 返回空 vector，popover 显示 hint "无可用命令" |
| 递归 `.uno:CommandPalette` 自调 | dispatcher `dispatchUrl` 开头 early-return |
| 无效 url（slot 查不到） | `GetSlotFromUnoName` nullptr → `dispatchUrl` log warning 后 return，不 crash |
| popover 重复 open | `m_pActivePopover` 已非空 → 先 Hide → 再 Show |
| frequency map 线程竞争 | **不加锁**：假设 main thread only（V2 Day-1b 约定），Day-1c 若需跨线程再加 |

---

## 5. 测试策略

### 5.1 新增 harness

`cui/qa/unit/CommandPaletteDispatcherTest.cxx` — 5 cases：

| case | 验证 |
|------|------|
| `testLoadCorpusNonEmpty` | `CommandPaletteLoader::buildCorpus(frame).size() > 100` |
| `testLoadCorpusContainsSave` | corpus 含 `.uno:Save` |
| `testFrequencyIncrement` | `dispatchUrl(".uno:Save")` 调 3 次 → `frequency(".uno:Save") == 3` |
| `testShowPaletteNoCrash` | `ShowPalette(frame)` + `Hide` 不抛 |
| `testDispatchLookupRecursion` | `dispatchUrl(".uno:CommandPalette")` 直接 return，frequency 不变 |

### 5.2 Fixture

`test::BootstrapFixture` 派生 → `SfxApplication::GetOrCreate()` + loadFromFile `private:factory/swriter` 拿真实 `SfxViewFrame`。`testDispatchLookupRecursion` 不真走 Execute，走 early-return。

### 5.3 与 Day-0 测试关系

| 文件 | 层 | Day-1b |
|------|----|---------|
| `CommandPaletteControllerTest.cxx` | controller 纯数据层 | 不动 |
| `CommandPaletteFuzzyTest.cxx` | fuzzy 算法层 | 不动 |
| `CommandIndexTest.cxx` | index/recent | 不动 |
| `CommandPaletteDispatcherTest.cxx` **新** | sfx2 集成层 | 本轮 |

四者互不重叠。

### 5.4 sweep 7 → 8 harness

`docs/product/v2/lane-status.md` W2 行 `harness_count`：7 → 8。ledger 新行 `V2-W2Day1bSpec`/`V2-W2Day1bLand` 记 `sweep_harnesses: 8`。

CI 7-sweep 增：`CppunitTest_cui_dispatcher`。

### 5.5 本机 verify 边界

BUILDDIR `/Users/lu/可点office` 非 ASCII（B2 持续 blocker），`make CppunitTest_*` 本机跑不动 — 走 CI。

本机可做：
- `make sfx2.build` — 验 dispatcher 编译过
- `make cui.build` — 验 loader + popover 编译过
- `grep -n SID_COMMAND_PALETTE include/sfx2/sfxsids.hrc` — 确认 slot id 未被改

---

## 6. 验收清单

- [ ] 8 files 编译过（sfx2.build + cui.build）
- [ ] CI 8-harness sweep 全绿（含新 `cui_dispatcher`）
- [ ] `cui_dispatcher` 5/5 cases 绿
- [ ] V1.5 27/27 strict 不退
- [ ] V2 H1-H7 + Day-0 controller/fuzzy 不退
- [ ] `docs/product/v2/lane-status.md` W2 行 `harness_count` 7 → 8
- [ ] `.agent/goals/2026-05-08-v2-ai-native/ledger.jsonl` 新行 `V2-W2Day1bLand` 含 `sweep_harnesses: 8`
- [ ] `docs/product/v2/STATUS-2026-05-11.md` §23 或新 §24 记 Day-1b land
- [ ] 人工：Cmd+K 在 Writer/Calc/Draw 各开一次，选 `.uno:Save` 能走

---

## 7. 锁定条件 / Out of scope

- **不做**：Start Center fallback、拼音检索、frequency 持久化 (xcu/registrymodifications)、multi-monitor 修正、label i18n 完善 → 全部 Day-1c。
- **不破**：controller/fuzzy/.ui/sdi/sfxsids Day-0 锁，V1.5 27/27，V2 H1-H7。
- **路径前缀**：所有 modify 文件走 SRCDIR `/Users/lu/kdoffice-src/...`，BUILDDIR 只落 spec/docs。
