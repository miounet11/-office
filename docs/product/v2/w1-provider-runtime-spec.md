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
