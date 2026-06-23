# V3-W8: Local-Cloud-Stack Spec

Status: **Config + sync-message contracts active** (2026-06-10: H10 schema/fixture harness and W8 sync-message self-test live; runtime implementation not started)
Goal id: 待启动 (`.agent/goals/v3-w8-local-cloud/` 尚未创建)
Predecessor: V3-W2 Connector / V3-W4 Tenant+Audit / V3-W7 Companion 中所有"云"路径
Constraint: **铁律 4 — 所有云服务必须本地自部署，禁止默认走厂商托管**

---

## 1. Goal

把 V3 中所有原本默认"云端"的依赖**全部替换为本地自部署服务**。
单机用户默认 0 配置即可起 stack；企业用户可换 LAN 内的同一份镜像。

成功画像：
- 用户首次启动桌面 app → 后台拉起 `localcloud-supervisor` → OAuth proxy /
  push gateway / sync server / audit sink 全部 listen 在 127.0.0.1
- `nettop -P -p <soffice pid>` 在任何 V3 默认路径下不应见到出公网的 socket
- 企业部署：把 `localcloud/` 一整套打成 docker-compose，部署到 LAN 任意机器；
  桌面 app 配置 `localcloud.endpoint=http://10.0.0.5:` 即接入

**非目标**：
- ❌ 不替代云推理（W1 推理仍走本地 Ollama；云 provider 是显式订阅项）
- ❌ 不做 P2P / 去中心化（仍是 client-server，只是 server 在用户/企业自己的机器）
- ❌ 不重写已成熟的本地组件（W3 BGE-m3 embedding 已是本地，不动）

---

## 2. 关键决策

| 子组件 | 原默认（云） | **W8 新默认（本地自部署）** | 端口策略 | 理由 |
|---|---|---|---|---|
| OAuth callback proxy | `https://oauth.kqoffice.example.com/cb` | **`http://127.0.0.1:<random>/cb`** | random ephemeral，每次 launch 新选 | 不依赖外网回调；Connector 全平台一致 |
| Push gateway | APNs + FCM (W7) | **本地 WebSocket gateway + mDNS 广播** | TCP 17801（可改）| LAN 内零配置；APNs/FCM 降为 opt-in |
| Sync server | 厂商托管 / 不存在 | **SQLite-backed sync server**（自部署）| TCP 17802 | 跨设备 evidence/diff 同步；单机时本地 socket |
| Embedding service | (W3 已本地) | **保留 BGE-m3 本地**（无变更）| in-process | 已是本地，列出仅为完整 |
| Audit sink | 远端 syslog (W4 §2) | **本地 syslog-style sink server**（自部署）| TCP 17803 | append-only file + 可选 LAN forward |
| 崩溃上报 | sentry.io (云) | **sentry-self-hosted**（可选）/ **file-only** 默认 | 无网络 | 默认 `~/Library/Logs/可圈office/crash/`；Sentry 是 opt-in |
| 自更新 | 厂商 CDN | **differential patch from self-host server** | HTTPS 17804 | 个人版 = 用户机器 / 企业版 = LAN 部署；签名校验保留 |
| 镜像仓库 | Docker Hub | **本地 docker-compose registry** | 无需常驻 | 一次性部署 |

**统一前缀**：所有本地端口走 `178xx`，便于 firewall 规则与运维识别。

---

## 3. 文件层

### 待创建（**需授权 — 一次性 W8 启动门**）

```
ai/source/localcloud/                       # C++ supervisor + IPC client
├── Supervisor.cxx                          # 拉起/监控 4 个本地服务
├── OAuthProxy.cxx                          # 127.0.0.1 OAuth callback handler
├── PushGateway.cxx                         # WebSocket gateway + mDNS
├── SyncServer.cxx                          # SQLite-backed sync
├── AuditSink.cxx                           # syslog-style sink
└── HealthCheck.cxx                         # 4 服务健康探测

localcloud/                                 # 独立子项目（go / rust 二选一）
├── docker-compose.yml                      # 企业部署一键起
├── oauth-proxy/                            # 单二进制 < 5MB
├── push-gateway/
├── sync-server/
├── audit-sink/
└── README.md                               # 自部署手册

officecfg/registry/data/org/openoffice/Office/LocalCloud.xcu  # 端口/endpoint 配置
```

### Schema（**进 V3 schema 锁**）

```
docs/schemas/localcloud-config.schema.json   # endpoint / port / token 配置（H10 active）
docs/schemas/sync-message.schema.json        # client ↔ sync-server 协议（sync-message self-test active）
```

**注意**：Supervisor 与 4 个本地服务的进程间协议**不进 V2 schema 锁**；
新建 `docs/schemas/v3/` 子目录隔离，避免与 V2 evidence-record / diagnostics-plan 塌缩。

### 已创建（contract / fixture，可逆）

```
docs/schemas/localcloud-config.schema.json
docs/qa/fixtures/v3/localcloud/valid/{default-loopback,enterprise-lan,cloud-opt-in}.json
docs/qa/fixtures/v3/localcloud/invalid/{default-public-endpoint,public-egress-without-opt-in}.json
tests/v3-local-cloud-no-egress-test.sh
docs/schemas/sync-message.schema.json
docs/qa/fixtures/v3/sync-message/valid/{local-evidence-upload,lan-diff-summary-download,companion-approval-upload,task-state-ack}.json
docs/qa/fixtures/v3/sync-message/invalid/{stores-document-content,public-egress-sync,missing-ack-required,raw-payload-sync}.json
tests/v3-sync-message-test.sh
```

---

## 4. 与 W2/W4/W7 的 hand-off

### W2 Connector
- §2 OAuth callback default 改为 `http://127.0.0.1:<random>/cb`
- §8 Q2 token storage 决议 = **macOS Keychain / Windows DPAPI / Linux libsecret**
- W2 不直接依赖 W8 服务进程；OAuth proxy 由 W8 supervisor 拉起，W2 调用 IPC client

### W4 Tenant+Audit
- §2 "Audit log 存储"行：远端 sink → **本地自部署 sink server**（W8 提供）
- 企业 LAN 部署时 sink server endpoint 写入 `Tenant.xcu`
- Audit log schema 不变；只换 transport

### W7 Companion
- §2 "通知机制"行：APNs+FCM (默认) → **本地 LAN push gateway (默认)** + APNs/FCM (opt-in)
- §2 "通信协议"行 LAN gRPC 保留；W8 push gateway 与 LAN gRPC 复用 mDNS 广播

### W3 Knowledge Index
- 无变更（embedding 已本地，BGE-m3）

### W6 Agent Multistep
- 长任务 evidence 通过 W8 sync-server 跨设备同步给 W7；不直接出公网

---

## 5. Harness（H10 新增）

H10 = **local-cloud-no-egress test**：
- 当前已 active 的 contract layer：验证 `localcloud-config.schema.json`、默认 loopback fixture、企业 LAN fixture、显式 cloud opt-in fixture，以及两个反例 fixture；baseline = 10 checks
- 启动桌面 app + W8 supervisor
- 跑 V3 W1/W2/W4/W7 默认 happy-path（chat / connector OAuth / audit / 移动审批）
- 监听整机 socket，**任何到非 127.0.0.1 / 非 LAN 私有段（10/8, 172.16/12, 192.168/16）的连接 → FAIL**
- 仅当用户显式启用 cloud opt-in（如挂云 provider）才允许出公网

集成进 V3 sweep：`bin/v3-eval-sweep.sh --v3-only` 已运行 H10 config contract；runtime socket proof waits for the W8 implementation gate.

W8 also has an active **sync-message self-test** for the client ↔ sync-server protocol. `tests/v3-sync-message-test.sh` validates `docs/schemas/sync-message.schema.json`, 4 valid fixtures, 4 invalid fixtures, local-socket/loopback and lan-grpc/private-lan coverage, `storesDocumentContent=false`, `containsRawPayload=false`, `ackRequired=true`, `publicEgress=false`, mTLS required, and the W8 sync port `17802`. Current baseline: `Checks: 8`. This remains contract-only until the W8 runtime implementation gate opens.

---

## 6. 性能基线（W9 §2 性能行的依赖项）

W8 服务必须满足：
- supervisor 冷启 < 800ms
- OAuth proxy 端口分配 + listen < 50ms
- Sync server 单条 evidence 写入 < 5ms
- Audit sink 写入 < 2ms（本地 file append-only）
- 4 服务总内存占用 < 80MB（idle）

不满足 → W9 §2 性能行 FAIL → 阻塞 W9 GA。

---

## 7. 启动门 / 退出门

**启动门（用户授权 1 次）**：
- 创建 `ai/source/localcloud/` 目录
- 创建 `localcloud/` 子项目目录
- 加 `LocalCloud.xcu`

**退出门（GA 前必须满足）**：
- H10 在 macOS / Linux / Windows 三平台全绿
- `nettop` 验证默认路径无公网出
- docker-compose 在 LAN 任意机器一键起
- §6 性能基线全绿
- W2/W4/W7 spec 已对齐 W8 默认（本文档 §4）

---

## 8. Open Questions

- Q1: localcloud 子项目语言选 Go 还是 Rust？（默认 Go：起步快、二进制小、生态好）
- Q2: docker-compose 是否绑 podman fallback？（默认是；macOS 用户偏好 podman）
- Q3: Sync server 在单机模式是 socket 还是 in-process？（默认 socket，便于企业部署一致）
- Q4: 端口冲突时 supervisor 是否自动让步？（默认是；让步顺序写入 `LocalCloud.xcu`）

---

## 9. 与 V3 master 关系

W8 在 master plan §2 拓扑图中作为**底座层**，与 W2/W4/W7 并列但更底；
W1/W3/W6 不直接依赖 W8（推理与索引仍是 in-process）；
W9 市场就绪以 W8 的"无公网出"作为可演示卖点之一。
