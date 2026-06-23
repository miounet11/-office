# V3-W2: Connector Layer Spec

Status: **Contract gate active** (2026-06-10: H8 schema/fixture/trust-chain/read-only/auth-flow/token-refresh harness live; runtime implementation not started)
Goal id: 待启动 (`.agent/goals/v3-w2-connector-layer/` 尚未创建)
Predecessor: V2 evidence-record schema + V2-W1 Provider Runtime

---

## 1. Goal

标准化"AI 取外部数据"通道。一份 manifest，一次审批，全程 evidence。

成功画像：
- 用户在 Chat 输入 `@notion 拉昨天的会议纪要` → 弹 connector 授权对话框 →
  确认后拉取 → 内容作为 prompt 上下文 → 输出 patch
- 管理员可在 W4 audit 面板看到：哪个 connector / 哪个 scope / 拉了什么 / 谁审批
- 一个 connector 写错或越权 → manifest schema 锁 + H8 harness 拦截

---

## 2. 关键决策

| 决策点 | 选项 | 当前默认 | 理由 |
|---|---|---|---|
| Manifest 格式 | JSON Schema / Protobuf / TOML | **JSON Schema** | 与 V2 schema 体例一致；Apple 配置工具友好 |
| Schema 文件位置 | `docs/schemas/` / 单独目录 | **`docs/schemas/connector-manifest.schema.json`** | 与 V2 schema 同目录但**不进 V2 schema 锁** |
| 内置 connector 集合 | 全集 / 最小集 / 用户自配 | **最小集 + 用户自配** | 飞书/企微/Notion/SharePoint/Confluence/Local FS |
| Auth flow | OAuth / API Key / Both | **Both** | OAuth 优先；不支持 OAuth 的允许 API Key（如自建 Confluence）|
| Token refresh | 后台刷新 / 用户触发 / 不适用 | **用户触发 reauth / 手动轮换** | OAuth2 过期后显式重新授权；API key 手动轮换；禁止后台刷新和 refresh token 持久化 |
| OAuth callback | 厂商 redirect / 本地回环 | **`http://127.0.0.1:<random>/cb`（W8 OAuth proxy 提供）** | 不依赖云回调；零外发；见 W8 §3 |
| OAuth surface | 内嵌 WebView / 系统浏览器 | **系统浏览器 + loopback** | 禁止 embedded WebView credential-capture 面；auth runtime 仍未启动 |
| Rate limit | 框架强制 / connector 自管 | **框架强制 + manifest 声明** | 防止滥用 SaaS quota |
| Evidence emitter | 强制 / 可选 | **强制** | 所有调用必须 emit evidence-record，否则 H8 拦截 |
| 数据缓存 | 永久 / TTL / 不缓 | **TTL（默认 5min）** | 平衡性能与新鲜度；TTL 进 manifest |
| Manifest trust chain | 无 / PR-only / 显式 trust envelope | **显式 trust envelope + H8 guard** | 社区/企业 connector 必须声明来源、publisher、hash、review state、install scope 与签名要求 |
| Connector operations | read-only / read-write | **read-only only** | V3 v0 只允许取上下文；外部 SaaS 写回需要单独产品/租户/审批/evidence 合约 |

---

## 3. Manifest Schema Contract

Canonical schema lives at `docs/schemas/connector-manifest.schema.json`.
It is still V3-only and **does not enter the V2 schema lock**, but it is now
covered by `tests/v3-connector-manifest-contract-test.sh` (H8, 16 checks).

H8 locks:
- required top-level fields: `id`, `version`, `displayName`, `trust`, `operations`, `auth`, `serviceModes`, `scopes`, `rateLimit`, `evidence`
- `additionalProperties:false` on the envelope and nested trust/operations/auth/auth-flow/refresh-policy/scope/rate-limit/evidence objects
- trust envelope: `source`, `publisher`, `manifestSha256`, `reviewState`, `installScope`, `signatureRequired`, `allowUnsigned`
- trust source enum: `builtin`, `community`, `enterprise-admin`; review states: `repo-reviewed`, `security-reviewed`, `tenant-approved`; install scopes: `builtin`, `user`, `tenant`
- `manifestSha256` must be `sha256:` plus 64 lowercase hex chars; `allowUnsigned=false`; all manifests must require signatures
- built-ins must be `source=builtin`, `publisher=kqoffice`, `reviewState=repo-reviewed`, `installScope=builtin`
- community user installs must be `security-reviewed`; tenant installs must be `tenant-approved`
- operations envelope: `mode=read-only`, `allowedActions=["read"]`, `writeback=false`, `writeScopesAllowed=false`, `runtimeWriteImplementation=not-started`
- writeback guards: no `write:*` connector scopes, no provider `:write` auth scopes, and no `evidence.category=data-write` for V3 v0 manifests
- auth enum: `oauth2`, `api-key`, `none`
- token storage enum: `keychain`, `memory`, `none`
- auth flow envelope: OAuth2 uses `system-browser-loopback` + `loopback-127.0.0.1`; API key uses `manual-secret-entry` + `manual-entry`; auth `none` uses `not-applicable` + `none`; `embeddedWebView=false`, `runtimeAuthImplementation=not-started`
- refresh policy envelope: OAuth2 uses `reauth-on-expiry`; API key uses `manual-rotate`; auth `none` uses `not-applicable`; `backgroundRefresh=false`, `storesRefreshToken=false`, `runtimeRefreshImplementation=not-started`
- service modes: `private`, `cloud` only; offline mode disables connectors
- data class enum: `public`, `internal`, `confidential`, `secret`
- evidence categories: `data-fetch`, `data-write`, `auth`, `metadata`（schema reserves `data-write`; H8 forbids it for V3 v0 read-only connector manifests）

---

## 4. 内置 Connector 清单

| ID | DisplayName | Auth | DataClass 上限 | 备注 |
|---|---|---|---|---|
| `local-fs` | 本地文件夹 | none | confidential | 用户选 root；不支持 ~/.ssh 等敏感目录 |
| `feishu-docs` | 飞书云文档 | oauth2 | internal | 个人/企业用户 OAuth |
| `wechat-work-docs` | 企微文档 | oauth2 | internal | 同上 |
| `notion` | Notion | oauth2 | internal | workspace 级授权 |
| `sharepoint` | SharePoint | oauth2 | confidential | 仅企业版；走 W4 租户 |
| `confluence` | Confluence | api-key + oauth2 | confidential | 自建实例支持 API Key |
| `slack` | Slack | oauth2 | internal | 仅 channel read |

**Non-built-in（用户自配）**：通过 manifest 安装；社区贡献走 PR review + security review + signed manifest hash，tenant 级安装还需要 tenant approval。

---

## 5. 文件层

### 已创建（contract / fixture，可逆）

```
docs/schemas/connector-manifest.schema.json
docs/qa/fixtures/v3/connector/valid/*.json    # 7 built-in connector manifests
docs/qa/fixtures/v3/connector/invalid/*.json  # 17 guard fixtures
docs/product/v3/w2-manifest-trust-policy.md   # trust-chain policy, contract-only
docs/product/v3/w2-connector-operations-policy.md # read-only/writeback policy, contract-only
docs/product/v3/w2-auth-flow-policy.md        # auth flow policy, contract-only
docs/product/v3/w2-token-refresh-policy.md    # auth refresh policy, contract-only
tests/v3-connector-manifest-contract-test.sh  # H8 contract harness
bin/v3-eval-sweep.sh                          # runs H8 in --v3-only mode
```

### 待创建（**需授权**）

```
ai/source/connector/ConnectorManager.cxx      # 注册中心
ai/source/connector/ConnectorRegistry.cxx     # manifest 加载
ai/source/connector/builtin/LocalFsConnector.cxx
ai/source/connector/builtin/NotionConnector.cxx  # ...等内置
ai/source/connector/AuthFlow.cxx              # OAuth / API Key flow
officecfg/registry/data/org/openoffice/Office/Connectors.xcu  # 内置 connector 注册
```

### 待创建（纯 docs，可逆）

```
docs/product/v3/w2-connector-survey.md        # 各 SaaS API 调研
docs/product/v3/w2-auth-flow-design.md        # OAuth / token storage 设计
```

### Fixture（V3 增量）

```
docs/qa/fixtures/v3/connector/valid/{local-fs,feishu-docs,wechat-work-docs,notion,sharepoint,confluence,slack}.json
docs/qa/fixtures/v3/connector/invalid/{evidence-disabled,offline-service-mode,cloud-confidential-without-policy,missing-manifest-hash,tenant-scope-without-approval,unsigned-community-manifest,unreviewed-community-manifest,data-write-evidence,runtime-write-implementation-started,embedded-webview-auth-flow,oauth-non-loopback-callback,runtime-auth-implementation-started,background-refresh-enabled,refresh-token-stored,runtime-refresh-implementation-started,write-scope-declared,writeback-enabled}.json
```

---

## 6. 与 V2 衔接

| V2 资产 | 在 W2 中的角色 |
|---|---|
| V2 evidence-record schema | Connector 调用产生标准 evidence；**不引入新 evidence schema** |
| V2 service-mode (offline/private/cloud) | Connector 调用 = "private" 或 "cloud"；offline 模式禁用所有 connector |
| V2 plugin manifest | Connector manifest 借鉴体例但**独立 schema**（防塌缩） |
| V2 W1 Provider Runtime | Connector 拉的内容作为 prompt context；不改 Provider IDL |

**塌缩防护**：

- `connector-manifest.schema.json` ≠ `kqoffice-plugin.schema.json`
- Connector evidence ≠ Provider evidence（同 schema 但 category 不同）

---

## 7. 验证

### 新增 Harness：H8 connector contract

H8 sweep is active via `tests/v3-connector-manifest-contract-test.sh` and
`bin/v3-eval-sweep.sh --v3-only`.

H8 sweep 检查：
1. 所有 manifest 文件符合 schema
2. `scopes[].dataClass` 与 service-mode 兼容
   （offline 模式下 connector 必须禁用；cloud + confidential/secret 需要 tenant policy）
3. `evidence.emit == true`（强制）
4. trust-chain 语义一致：内置 connector 只能是 `kqoffice` built-in；community/enterprise manifests 不能 unsigned，必须有 hash 与 review state；tenant scope 必须 tenant-approved
5. read-only/writeback 语义一致：operations 必须 read-only；禁止 write scopes、writeback、runtime write implementation、`data-write` evidence
6. auth-flow 语义一致：OAuth2 必须 system browser + 127.0.0.1 loopback；API key 必须 manual secret entry；禁止 embedded WebView 和 runtime auth implementation
7. token-refresh 语义一致：OAuth2 必须 `reauth-on-expiry`，API key 必须 `manual-rotate`，auth none 必须 `not-applicable`；禁止后台刷新、refresh token 存储和 runtime refresh implementation
8. 内置 connector fixture roster 与 §4 清单一致
9. 内置 connector 在 `Connectors.xcu` 中注册一致（文件落地后自动升级检查；当前为 contract-only）

### 单测（待写）

```
CppunitTest_ai_connector_manifest_validation
CppunitTest_ai_connector_localfs_fetch
CppunitTest_ai_connector_oauth_flow
CppunitTest_ai_connector_evidence_emit
```

### Fixture（已写）

- valid connector manifest × 7（每个内置 connector）
- invalid connector manifest × 17（evidence disabled / offline service-mode / cloud confidential without tenant policy / missing manifest hash / tenant scope without tenant approval / unsigned community manifest / unreviewed community manifest / data-write evidence / runtime write implementation started / embedded WebView auth flow / OAuth non-loopback callback / runtime auth implementation started / background refresh enabled / refresh token stored / runtime refresh implementation started / write scope declared / writeback enabled）
- connector fetch evidence fixture remains future runtime work

### 回归

- V1.5 27/27 ✅
- V2 H1-H10 ✅
- V3 H8 ✅（contract-only; registration check deferred until `Connectors.xcu` exists）
- 不能引入新的"必须联网"路径（offline 模式 V2 全保留）

---

## 8. Open Questions / Blockers

- ~~Q1：飞书/企微 OAuth 流程是否需要内嵌 WebView？（W7 同问题）~~ **决议：V3 v0 禁止 embedded WebView；OAuth2 connector 必须声明 `auth.flow.strategy=system-browser-loopback`、`callback=loopback-127.0.0.1`、`runtimeAuthImplementation=not-started`；API key 用 `manual-secret-entry`；详见 `docs/product/v3/w2-auth-flow-policy.md`**
- ~~Q2：API Key 存哪里？macOS Keychain / Windows DPAPI / Linux libsecret？~~ **决议：三平台原生 secure store（Keychain / DPAPI / libsecret），由 W8 secret-broker 统一封装**
- ~~Q3：Token 刷新策略（后台 / 用户触发）~~ **决议：V3 v0 manifest 必须声明 `auth.refreshPolicy`；OAuth2 只允许 `reauth-on-expiry`，API key 只允许 `manual-rotate`，auth none 为 `not-applicable`；禁止后台刷新、refresh token 存储和 runtime refresh implementation；详见 `docs/product/v3/w2-token-refresh-policy.md`**
- ~~Q4：Manifest 来源信任链（社区贡献如何防止恶意 connector）~~ **决议：manifest 必须包含 H8 锁定的 trust envelope；community=user scope 需 security-reviewed，tenant scope 需 tenant-approved，所有 manifest 禁止 unsigned 并固定 sha256；详见 `docs/product/v3/w2-manifest-trust-policy.md`**
- ~~Q5：是否允许 connector 写回（如 Notion 写新页面）？~~ **决议：V3 v0 connector manifest 必须声明 read-only operations envelope；禁止 writeback、write scopes、`data-write` evidence 和 runtime write implementation；详见 `docs/product/v3/w2-connector-operations-policy.md`**

---

## 9. 时间线（保守估算）

- Q3 2027 (4w)：schema + ConnectorManager + local-fs connector
- Q4 2027 (4w)：OAuth flow + Notion connector + evidence wiring
- Q4 2027 (3w)：飞书/企微/Confluence connector
- Q1 2028 (3w)：H8 harness + manifest 安装流程

总计：10–14 周。
