# V3-W7: Companion Spec

Status: **companion-contract self-test active** (2026-06-10: schema/fixture contract live; runtime implementation not started)
Goal id: 待启动 (`.agent/goals/v3-w7-companion/` 尚未创建)
Predecessor: V2-W5 移动审批立场（"仅审批不编辑"）+ V3-W4 Tenant + V3-W6 Agent

---

## 1. Goal

移动端只做审批与通知，不做编辑（沿用 V2 W5 立场）。
**非目标**：移动端文档编辑；离线编辑同步；AI 直接调用。

成功画像：
- 桌面起 agent 长任务 → 用户出门 → 手机收 push → app 内看 diff → 一键审批 / 拒绝
- 拒绝后桌面 app 自动 rollback；同步 evidence
- 移动端**不存任何文档原文**（只缓存 diff 摘要 + evidence）

---

## 2. 关键决策

| 决策点 | 选项 | 当前默认 | 理由 |
|---|---|---|---|
| 平台 | 原生 iOS+Android / PWA / 单一 | **PWA + 原生 fallback**（spike 决议）| PWA 起步快；原生为长期 |
| 通信协议 | LAN gRPC / HTTPS / 自研 | **LAN gRPC（默认）+ HTTPS（企业网关）** | LAN 零配置；网关为企业 |
| 凭据存储 | 长 token / 短 token / 设备绑定 | **短 token（24h）+ 设备绑定** | 安全；丢手机不致命 |
| 数据缓存 | 全文档 / diff 摘要 / 不缓存 | **diff 摘要 + evidence id**（不缓全文）| 移动端不存文档原文 |
| 审批二次确认 | 单击 / 双击 / 生物识别 | **生物识别（Touch/Face ID）** | 防误触 |
| 通知机制 | APNs+FCM / 本地 push / 邮件 | **本地 LAN push gateway（默认，W8 提供 TCP 17801 + mDNS）+ APNs+FCM（opt-in）** | 默认零外发；公网推送仅企业 opt-in；见 W8 §3 |
| 离线行为 | 完全禁用 / 缓存查看 / 部分操作 | **缓存查看 + 不可审批** | 审批必须在线 |

---

## 3. 范围严格约束

W7 **绝对不做**的功能：

- ❌ 文档编辑（任何形式）
- ❌ 直接调用 AI / Provider
- ❌ 离线编辑同步
- ❌ 文件管理（上传 / 下载原文）
- ❌ 跨设备协同编辑

W7 **只做**的功能：

- ✅ 任务列表（来自 V3-W6 agent task state）
- ✅ Diff 审批（基于桌面发来的 ApplyPlan 摘要）
- ✅ Evidence 浏览
- ✅ Push 通知（任务完成 / 失败 / 等审批）
- ✅ 一键 approve / reject / rollback

---

## 4. 文件层

### 待创建（独立项目，**不进 office app monorepo**）

```
companion-app/                                  # 全新独立目录
companion-app/pwa/                              # PWA 实现
companion-app/pwa/src/...
companion-app/pwa/manifest.webmanifest
companion-app/native-ios/                       # 后期原生（spike 后）
companion-app/native-android/                   # 后期原生
companion-app/README.md
```

### 桌面侧 bridge（**需授权**）

```
ai/source/companion/CompanionBridge.cxx        # 桌面 ↔ 移动通信
ai/source/companion/PairingFlow.cxx            # 设备配对
ai/source/companion/PushDispatcher.cxx         # 推送
officecfg/registry/data/org/openoffice/Office/Companion.xcu  # 配置
```

### Schema（V3 增量，**进 V3 schema 锁**）

```
docs/schemas/companion-pairing-token.schema.json    # pairing token（active contract）
docs/schemas/companion-diff-summary.schema.json      # mobile read-only diff summary（active contract）
docs/schemas/companion-approval-request.schema.json  # online approval request（active contract）
```

### 待创建（纯 docs）

```
docs/product/v3/w7-companion-spec.md            # 本文档
docs/product/v3/w7-platform-survey.md           # PWA vs 原生选型
docs/product/v3/w7-security-model.md            # 凭据 / token / 设备绑定
docs/product/v3/w7-ux-wireframe.md              # 线框图
```

---

## 5. 配对流程草稿

```
桌面 app 启动配对：
  1. 桌面生成 pairing token (短期，10 min TTL)
  2. 桌面显示 QR (token + LAN endpoint + tenant id)
  3. 移动 app 扫 QR
  4. 移动发起 mTLS 握手 (LAN gRPC)
  5. 桌面验证 token + 用户 PIN 二次确认
  6. 配对成功 → 桌面下发 24h device session token
  7. 移动持久化 device id + session token (Keychain / Keystore)
```

后续每 24h 自动续 token；用户可在桌面侧吊销设备。

---

## 6. 与 V2 / V3 其它 Wave 衔接

| 资产 | 在 W7 中的角色 |
|---|---|
| V2-W5 Async Cowork | 长任务通过该框架触发 W7 push |
| V2 evidence-record | Evidence 浏览页只展示**桌面已生成**的 record；W7 不生产 evidence |
| V2 ApplyPlan envelope | Diff 摘要由桌面侧把 envelope 转成"人类可读 summary"再发；移动端不解析 envelope |
| V3-W4 Tenant + Audit | 每次审批写 audit log（actor.role=user, channel=companion） |
| V3-W6 Agent | Per-step 审批可路由到 W7（用户配置） |

**塌缩防护**：

- `companion-diff-summary` ≠ V2 ApplyPlan（移动端只看摘要不看原始 envelope）
- `companion-approval-request` ≠ V3 audit-log-entry（请求 vs 决策记录）

---

## 7. 验证

### 桌面侧单测（待写）

```
CppunitTest_ai_companion_pairing_token_ttl
CppunitTest_ai_companion_diff_summary_redaction
CppunitTest_ai_companion_session_revoke
CppunitTest_ai_companion_approval_evidence_link
```

### PWA / 原生测试（独立 CI）

- E2E：扫码配对 → 接 push → 审批 → 桌面确认 patch 落地
- 安全：丢失设备模拟（吊销 token 流程）
- 离线：断网时仅可查看缓存，不能审批

### Fixture（companion-contract active）

- `docs/qa/fixtures/v3/companion/valid/lan-pairing-token.json`
- `docs/qa/fixtures/v3/companion/valid/enterprise-pairing-token.json`
- `docs/qa/fixtures/v3/companion/valid/writer-paragraph-diff-summary.json`
- `docs/qa/fixtures/v3/companion/valid/calc-cell-diff-summary.json`
- `docs/qa/fixtures/v3/companion/valid/impress-slide-diff-summary.json`
- `docs/qa/fixtures/v3/companion/valid/lan-approval-request.json`
- `docs/qa/fixtures/v3/companion/valid/enterprise-approval-request.json`
- `docs/qa/fixtures/v3/companion/invalid/pairing-token-ttl-too-long.json`
- `docs/qa/fixtures/v3/companion/invalid/diff-summary-stores-document-content.json`
- `docs/qa/fixtures/v3/companion/invalid/approval-allows-offline.json`
- `docs/qa/fixtures/v3/companion/invalid/approval-public-egress-without-opt-in.json`

### Contract self-test（active）

`tests/v3-companion-contract-test.sh` is the W7 companion-contract self-test. It validates `docs/schemas/companion-pairing-token.schema.json`, `docs/schemas/companion-diff-summary.schema.json`, and `docs/schemas/companion-approval-request.schema.json`, covering 10-minute pairing tokens, 24h session token intent, device binding, LAN gRPC / enterprise HTTPS pairing modes, Writer/Calc/Impress diff summaries, V2 action-kind parity, no mobile ApplyPlan parsing, `storesDocumentContent=false`, `biometricRequired`, `cloudPushOptIn` for public push, and `allowApprovalOffline=false`. It reports `Checks: 9` and is wired into `bin/v3-eval-sweep.sh --self-test`.

### 回归

- V1.5 27/27 ✅
- V2 H1-H7 ✅
- V3 H8/H9 ✅
- 引入 W7 不破坏桌面端任何 wave（移动端是 read-only consumer）

---

## 8. Open Questions / Blockers

- Q1：PWA 在 iOS Safari 的限制（push 支持度有限）
- Q2：LAN gRPC 在企业 NAT / 防火墙穿透
- Q3：生物识别在企业管控的设备上是否可用
- Q4：是否需要做 Watch app（Apple Watch / Wear OS）
- Q5：评审：是否引入"任务委托"的语义（A 用户启动任务，B 用户审批）—— 默认不做（仅同账号同设备域）

---

## 9. 时间线（保守估算）

- Q3 2028 (3w)：CompanionBridge + 配对流程 + 短 token
- Q4 2028 (3w)：PWA v0（任务列表 + diff 浏览，不含审批）
- Q4 2028 (3w)：审批链路 + push 通知 + 生物识别
- Q4 2028 (3w)：吊销 / 离线 / 安全审计

总计：8–12 周。
