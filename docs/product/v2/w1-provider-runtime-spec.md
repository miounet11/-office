# V2 W1 Spec: Provider Runtime

Date: 2026-05-08
Wave: W1 (V2 第 1 波次)
Master plan: `../v2-master-plan.md`

## Scope

为 V2 全部 AI 能力提供统一的 LLM 调用基座。**所有** AI 推理走这层；其它 wave (W2/W3/W4/W5) 不允许直接 import LLM SDK。

V1.5 已就位的契约 (`docs/schemas/provider-request.schema.json`) 是设计起点；W1 落地为 runtime。

## In Scope

1. UNO service `com.kdoffice.AI.Provider`（接口 + 默认 Ollama 实现）
2. Service Mode 三档策略实施（offline / private / cloud）
3. Request 生命周期（构造 → 审批 → 调用 → evidence → response）
4. Provider 注册表 + capability discovery
5. 失败隔离（timeout / 超额 / 拒绝服务时文档不动）
6. Sandbox：provider 不持有 document handle

## Out of Scope (Non-Goals)

- 不内置任何模型推理代码（用 Ollama HTTP API）
- 不实现 RAG / vector store（W3 之后再考虑）
- 不实现 streaming（v0 用 blocking call；streaming 留 v1）
- 不接入云 provider 默认（service mode `cloud` 需用户显式启用）

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Caller (W2 Cmd+K, W3 Writer Apply, W4 浮窗, W5 异步)  │
└─────────────┬───────────────────────────────────────┘
              │ ProviderRequest (schema)
              ▼
┌─────────────────────────────────────────────────────┐
│  com.kdoffice.AI.Provider (UNO service)              │
│  ┌─────────────────────────────────────────┐        │
│  │ ServiceModePolicy (offline/private/cloud)│        │
│  └─────────────────────────────────────────┘        │
│  ┌─────────────────────────────────────────┐        │
│  │ ProviderRegistry (Ollama / Custom HTTP) │        │
│  └─────────────────────────────────────────┘        │
│  ┌─────────────────────────────────────────┐        │
│  │ EvidenceRecorder (req/res/timing/hash)  │        │
│  └─────────────────────────────────────────┘        │
└─────────────┬───────────────────────────────────────┘
              │ HTTP (localhost:11434 default)
              ▼
       ┌──────────────┐
       │ Ollama / API │
       └──────────────┘
```

## File Map

| 路径 | 类型 | 内容 |
|---|---|---|
| `kqoffice/source/ai/provider/Provider.cxx` | new | UNO service implementation |
| `kqoffice/source/ai/provider/ProviderImpl.hxx` | new | Provider class declaration |
| `kqoffice/source/ai/provider/ServiceModePolicy.cxx` | new | Mode enforcement |
| `kqoffice/source/ai/provider/EvidenceRecorder.cxx` | new | Per-request evidence |
| `offapi/com/kdoffice/AI/XProvider.idl` | new | UNO interface |
| `offapi/com/kdoffice/AI/ProviderRequest.idl` | new | Request struct |
| `offapi/com/kdoffice/AI/ProviderResponse.idl` | new | Response struct |
| `kqoffice/Library_kqoffice_ai.mk` | new | gbuild library |
| `kqoffice/Module_kqoffice.mk` | new | module wiring |
| `RepositoryModule_host.mk` | modify | register kqoffice module |
| `officecfg/registry/data/org/openoffice/Office/AIProvider.xcu` | new | provider registry data |
| `officecfg/registry/schema/org/openoffice/Office/AIProvider.xcs` | new | schema |
| `kqoffice/qa/cppunit/test_provider.cxx` | new | unit tests |

## UNO Interface

```idl
module com { module kdoffice { module AI {

interface XProvider : com::sun::star::uno::XInterface
{
    /// Synchronous request; throws RuntimeException on policy denial.
    ProviderResponse call([in] ProviderRequest req)
        raises (com::sun::star::lang::IllegalArgumentException);

    /// List capabilities of currently active provider.
    sequence<string> listCapabilities();

    /// Current service mode: "offline" | "private" | "cloud".
    string getServiceMode();
};

}; }; };
```

## Service Mode Policy

| Mode | 默认 | 网络 | 数据出域 | 启用条件 |
|---|---|---|---|---|
| `offline` | ✅ | localhost only | 否 | 默认；用户无需配置 |
| `private` | ❌ | 用户配置 endpoint | 仅去配置的私有 endpoint | 企业管理员配置 + 用户确认 |
| `cloud` | ❌ | 任意 | 是（含 evidence） | 用户在 设置 → AI → 启用云模式 显式勾选 + 看到隐私提示 |

Mode 切换记 evidence。Cloud 模式下每次请求顶部弹"内容将发送到 cloud provider"小提示。

## Capability ↔ ServiceMode 矩阵 (L102 入册, source-of-truth = `ServiceModePolicy.cxx:20`)

> 本表是 spec ↔ C++ 实际 allowlist 的诚实对照表，加这一节是为了关掉 W1 历史的 capability claim drift（spec 写过 "rewrite | summarize | format-fix | ..." 模糊省略号，C++ 实际是 4 个明确 token）。
> H6 reader's manual 自动入册时按本表锁。改 allowlist 必须 3-site 同步：本表 / `ServiceModePolicy.cxx:20` `kOfflineCapabilities` / 新加 cppunit `testListCapabilitiesMatchesPolicy`（W1.A 已入 backlog）。

| Capability token | offline | private | cloud | 触发回路 / 用例 |
|---|---|---|---|---|
| `rewrite` | ✅ | 计划支持（gated D1d） | 计划支持（gated W1 cloud） | Writer 段落改写、邮件润色、Calc 单元格批注润色 |
| `summarize` | ✅ | 计划支持 | 计划支持 | Writer 长文摘要、Impress 大纲压缩 |
| `format-fix` | ✅ | 计划支持 | 计划支持 | 全局 fmt clean (Writer/Calc/Impress 同 token，apply 路径不同) |
| `intent-to-uno` | ✅ | 计划支持 | 计划支持 | Cmd+K 自然语言 → `.uno:` 命令分派；与 W2 controller 共享 |

总数：offline = **4** (`rewrite | summarize | format-fix | intent-to-uno`)。这是 `Provider::listCapabilities()` 在 offline 模式下应当返回的 sequence，但当前 C++ 还返回空（W1.A 待办，可逆 reflection patch）。

矩阵不变量（与 W1 invariant §29 相干）：
- offline 集合是 private 集合的子集，private 集合是 cloud 集合的子集（**包含序**）。
- 任何不在矩阵里的 capability token，`Provider::call` 必须 reject 并记 evidence `policy-denied`。
- 新加 capability：先加到本表 + `ServiceModePolicy.cxx:20`，再加 cppunit case；不允许 spec 落后于 C++。

矩阵扩展项（不入 offline，留待对应 wave 落地时再决）：
- `apply-paragraph` — W3 wiring，offline 走 ApplyPlanValidator 不需 provider，所以不入本表。
- `inline-action-cell-*` / `inline-action-slide-*` — W4 token，token 走 ProviderRequest.capability 还是走独立 dispatcher 是 D3a-d 范围内决议。
- `cowork-task-*` — W5 token，offline 走纯本地 worker，不一定要进矩阵。


## Request Lifecycle

```
1. Caller 构造 ProviderRequest (按 schema)
     ├── prompt: string
     ├── context: SelectedRange | DocumentSnapshot | None
     ├── capability: string ("rewrite" | "summarize" | "format-fix" | ...)
     └── timeout_ms: int (default 30000)

2. Provider.call()
   ├── ServiceModePolicy.check(req) → throw if 拒绝
   ├── EvidenceRecorder.start(req_hash)
   ├── ProviderRegistry.dispatch(req) → HTTP / IPC
   │     └── 失败 → return ProviderResponse{status=fail, doc=unchanged}
   ├── EvidenceRecorder.complete(req_hash, response, timing)
   └── return ProviderResponse

3. Caller 拿到 ProviderResponse
   ├── status: "ok" | "policy-denied" | "timeout" | "provider-error"
   ├── content: string
   ├── evidence_id: string (for traceability)
   └── apply_plan?: ApplyPlan (W3 集成时使用)
```

## Sandbox 不变量

1. Provider 不持有 `XComponent` / `XTextDocument` 等文档 handle
2. Provider 输入限于 `ProviderRequest`；输出限于 `ProviderResponse`
3. Provider 失败时 caller 文档**不动**（caller 责任）
4. Provider 不写文件系统（除 evidence 目录 `tmp/ai-evidence/<run-id>/`）
5. Provider 不修改 user profile

## Default Ollama Provider

启动时 probe `http://localhost:11434/api/tags`：
- 200 → 用 Ollama，列模型
- 拒绝连接 → 提示用户安装 Ollama / 切换 service mode

推荐模型（按设备性能）：
- M1/M2/M3 (8GB+)：`qwen2.5:3b` / `phi3.5:3.8b`
- M-series (16GB+)：`qwen2.5:7b` / `llama3.1:8b`
- M-series (32GB+)：`qwen2.5:14b`

## Evidence Schema 复用

`docs/schemas/evidence-record.schema.json` 已存在，W1 直接用：

```json
{
  "evidence_id": "ev-...",
  "timestamp": "2026-05-08T13:30:00+0800",
  "request_hash": "sha256:...",
  "service_mode": "offline",
  "provider": "ollama:qwen2.5:7b",
  "capability": "rewrite",
  "request_size_bytes": 1234,
  "response_size_bytes": 5678,
  "duration_ms": 2400,
  "status": "ok"
}
```

evidence 写到 `${UserInstallation}/ai-evidence/YYYY-MM/<evidence_id>.json`，每月轮转。

## Test Strategy

1. **Unit**：`CppunitTest_kqoffice_provider`
   - ServiceModePolicy 拒绝逻辑
   - EvidenceRecorder 写盘正确
   - Ollama probe（mock HTTP）
2. **Integration**：`PythonTest_kqoffice_provider`
   - 跑真 Ollama（需要 CI 装 Ollama 或 mock）
   - capability discovery 正确
3. **契约**：扩展现有 18 fixture，新增 ProviderRequest/Response fixture 至 24
4. **Smoke**：`bin/v2-w1-smoke.sh`：跑 capability="rewrite" + 评估输出非空

## Security Review

每次 request 通过下面 4 道闸：

1. ServiceMode 是否允许该 provider
2. capability 是否在 user/admin 白名单
3. context 大小是否超过 service mode 上限（offline 默认 ≤ 32KB；cloud 可配）
4. evidence_id 是否唯一（防 replay）

Cloud 模式额外：
5. 用户是否已在最近 24h 看过隐私提示

## ROI Estimate

- 实施时间：2-3 周（不含 evidence 仪表盘）
- 阻塞 wave：所有后续 wave 都依赖；不能跳过
- 运行时开销：每请求增加 ≤ 50ms（policy + evidence）
- 用户感知：默认 offline 模式无隐私改变；cloud 模式有显式提示

## Stop Conditions

W1 实施暂停的红线：

1. Ollama 在 macOS 上 default 不工作（需 user 手装）→ 需要 W1 v0 提示流（不是 spec 失败，是产品决策）
2. UNO service `com.kdoffice.*` namespace 与上游 LO 冲突 → 改 `com.libreoffice.*` 或 fork
3. ServiceMode 切换 dialog 不能在 Settings 中找到合适入口 → 需要 cui spec
4. evidence 写盘 IO 影响主线程响应 → 改异步队列

## Dependencies

- 无前置依赖（V1.5 的 contracts/schemas 已就位）
- 阻塞：W2 v1 (LLM 增强), W3, W4, W5 都需要 W1 完成

## Acceptance Criteria

W1 完成时验证：

- [ ] `gmake CppunitTest_kqoffice_provider` pass
- [ ] `gmake PythonTest_kqoffice_provider` pass（with mock Ollama）
- [ ] `bin/v2-w1-smoke.sh` 跑 5 个不同 capability 都返回非空 response
- [ ] Service mode 切换从 Settings → AI 可见
- [ ] evidence 文件按 `tmp/ai-evidence/2026-MM/<id>.json` 写出
- [ ] V1.5 27/27 兼容性测试不退化

## Backlog § (L103 入册): Cloud Adapter Token Lock (W1.cloud, design-only)

> 这一节是 **schema 冻结草案**，不是 cloud TLS 实装路径，不入 SRCDIR。
> 目的是在 W1 cloud（也叫 D1d cloud 续期）授权之前，把 cloud-side adapter
> 的 token / 鉴权 / endpoint 形态锁下来；放行后只做实装。
> 与 ServiceModePolicy `Cloud` 模式的 allowlist 同步在 §"Capability ↔
> ServiceMode 矩阵" 章节，已显式列出"private/cloud 计划支持"列。本 backlog 继续把
> cloud 这一边的 **认证与路由细节** 冻结。

### 1. 第一阶段目标

V2 cloud 只先做 **Anthropic-shape adapter**（HTTP/JSON, x-api-key
header），不做 OpenAI/Azure/Bedrock；多 vendor 是 V2.x 范围。Anthropic
是 first-class first 的原因：

- 协议简单（一个 endpoint，无 streaming required, JSON-only）
- 用户最常见的 cloud LLM 之一
- evidence 字段已经能直接装 Anthropic-shape 响应（`content` 单段）

### 2. Cloud adapter 接口（design-only）

```cpp
namespace kqoffice::ai
{
class SAL_DLLPUBLIC_EXPORT CloudAdapter
{
public:
    /// Vendor enumeration. V2 only Anthropic; rest reserved for V2.x.
    enum class Vendor
    {
        Anthropic,    // anthropic-2024-style /v1/messages
        // OpenAI,    // V2.x
        // Azure,     // V2.x
        // Bedrock,   // V2.x
    };

    struct Config
    {
        Vendor vendor;
        OUString endpoint;        // e.g. https://api.anthropic.com/v1/messages
        OUString apiKeyRef;       // KEY REFERENCE, not raw key — see §3
        OUString model;           // e.g. claude-3-5-sonnet-20241022
        sal_Int32 maxOutputTokens; // default 1024
        sal_Int32 timeoutMs;       // default 30000
    };

    explicit CloudAdapter(const Config& cfg);

    /// Probe: HEAD on endpoint or vendor-specific cheap GET.
    /// Returns "reachable" | "unauthenticated" | "unreachable" | "rate-limited".
    OUString probe();

    /// Generate. Returns content; empty string on any failure.
    /// Evidence-level reason captured in lastError().
    OUString generate(const OUString& prompt);

    /// Diagnostics for evidence record. Reset on each call.
    OUString lastError() const;

private:
    Config m_cfg;
    OUString m_lastError;
};
} // namespace kqoffice::ai
```

不变量：
- `apiKeyRef` 永远不是原始 key —— 是指向 OS keychain 的 reference
  (macOS keychain item name, Windows credman, GNOME secret-service)。Adapter
  内部即时取 key 用，调用后立即 zero 内存，**绝不写日志**。
- `Config` 字段值（不含 key）写 evidence；endpoint URL 算受控 PII，
  evidence 字段标 `private`。
- Probe 不会消耗 token；用 HEAD 或最小 token request 完成。

### 3. Key storage（设计层 token lock）

| OS | 存储 | reference 形态 |
|---|---|---|
| macOS | `Security.framework` keychain item | `keychain://kqoffice/ai-cloud/anthropic` |
| Windows | `wincred` credential manager | `wincred://kqoffice/ai-cloud/anthropic` |
| Linux | `libsecret` (GNOME) / `kwallet` (KDE) | `secret-service://kqoffice/ai-cloud/anthropic` |

Adapter 启动时用 reference 解析到 raw key；fail-fast on 失败（不 silently
fall back，避免没鉴权情况下发请求暴露 prompt）。

key reference 是 user setting，存 `kqoffice/registry/data/.../AICloud.xcu`
(待 D1d cloud 解锁后入册)。**不存 raw key 到 registry**，registry 只存
reference。

### 4. ServiceMode 切换 evidence

切换到 `cloud` 时必须 emit evidence with reason `mode-switch-to-cloud`，
包含：

- target vendor
- endpoint URL（不含 key）
- 用户是否在最近 24h 看过隐私提示（W1 spec §"Service Mode Policy" 已有要求）
- timestamp ISO 8601 + UTC

切换回 offline / private 同样 emit evidence，便于审计 "用户用云模式多久"。

### 5. 请求 lifecycle 增量（在 §"Request Lifecycle" 基础上）

```
ServiceModePolicy.check(req) → 通过
  └─ 若 mode==Cloud:
       ├─ 显式校验 capability ∈ cloud allowlist
       ├─ 显式校验用户 24h 隐私提示已 ack
       ├─ EvidenceRecorder.start(req_hash) 加 cloud-marker
       └─ CloudAdapter.generate(req.prompt)
            ├─ 取 keychain key（即时，不缓存到 m_cfg）
            ├─ HTTP POST endpoint
            ├─ 失败 → return ProviderResponse{status=provider-error}
            └─ 成功 → return ProviderResponse{status=ok, content, evidence_id}
```

### 6. Timeouts / 重试

- HTTP timeout = `Config.timeoutMs` （默认 30s）
- 不重试 4xx（鉴权 / 输入错）
- 5xx 可重试 1 次，间隔 1s；超过 = `provider-error`
- 429 rate-limited 立即返回 `rate-limited`（不 retry，让用户决定）

### 7. Provider response 字段映射（Anthropic 4 项）

| Anthropic field | ProviderResponse 映射 | 备注 |
|---|---|---|
| `content[0].text` | `content` | 仅取第一段；多段拼接是 V2.x |
| `usage.input_tokens` | evidence `request_tokens` (新字段) | 待 provider-evidence.schema 增列 |
| `usage.output_tokens` | evidence `response_tokens` (新字段) | 同上 |
| `stop_reason` | evidence `stop_reason` (新字段) | 同上 |

新增 evidence 字段 = schema 改动 = H1 / H6 必须同步：

- `docs/schemas/provider-evidence.schema.json` 加 3 字段
- reader's manual 加对应 fact-block
- C++ EvidenceRecord 加 3 个 sal_Int32 + 1 个 OUString
- H1 通过

这一同步必须与 cloud adapter 实装在同一个 PR 里完成，不允许 schema 先落 C++ 落后。

### 8. 不在本 backlog 内

- 实际 HTTP client（macOS NSURLSession / Linux libcurl / Windows WinHTTP；选型留 D1d cloud 时决）
- 多 vendor（OpenAI / Azure / Bedrock —— V2.x）
- streaming response（V2.x）
- function calling / tool use（V2.x）
- 计费 quota / budget enforcement（不在 V2 任何 wave 范围）

### 9. Gate

- **W1 cloud (D1d cloud)**：实际 SRCDIR 落 CloudAdapter.{hxx,cxx} + AICloud.xcu schema +
  evidence schema 3 字段补充 + cppunit。
- 落地顺序建议：W1.A/W1.B (D1d 第一阶段，offline-only honesty) 先放行
  并跑通 → 再开 D1d cloud；这样 evidence schema 改动是单方向只增加，
  不动现有 17-token status enum。

### 10. Schema 冻结要点（不动 C++）

- adapter Config 字段集冻结为 §2 的 7 项（vendor / endpoint / apiKeyRef / model /
  maxOutputTokens / timeoutMs + 未来 `extraHeaders` 选项给企业代理用）
- vendor enum 冻结为 Anthropic（V2 范围）
- key reference scheme 冻结为 §3 三种
- 新增 evidence 字段冻结为 §7 三项（request_tokens / response_tokens / stop_reason）

**这些 frozen list 不在 schema JSON 里实装直到 D1d cloud 放行**。本节
只是把"放行时该长这样"写死，避免到时候争论 vendor 顺序 / key store
选型 / 字段命名。
