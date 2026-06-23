# V3-W4: Tenant + Policy + Audit Spec

Status: **audit-log-entry + policy-tenant self-tests active** (2026-06-10: schema/fixture contracts live; runtime implementation not started)
Goal id: 待启动 (`.agent/goals/v3-w4-tenant-policy-audit/` 尚未创建)
Predecessor: V2 evidence-record schema + V2 service-mode policy

---

## 1. Goal

从单机用户扩展到企业租户，所有 AI 行为可审计可治理。
**非目标**：不做多租户在桌面端跑（桌面 = 单租户；多租户 = 服务端）。

成功画像：
- 企业管理员一个面板看到：哪个用户 / 哪个 prompt / 哪步审批 / 是否泄露
- 一条 policy `tenant=acme && connector=public-internet → deny` 直接生效
- Audit log append-only，不可篡改；满足等保 2.0 + GDPR 要求

---

## 2. 关键决策

| 决策点 | 选项 | 当前默认 | 理由 |
|---|---|---|---|
| Tenant 模型 | 单层 / 三层 / 树状 | **三层（Tenant/Workspace/User）** | 与 SaaS 主流模型对齐；够用不过度 |
| Policy 引擎 | 规则文件 / OPA / 自研 DSL | **规则文件 (YAML) + 简单 DSL** | OPA 太重；YAML 可读性高 |
| Policy 评估时机 | 调用前 / 调用后 / 双向 | **调用前（pre-flight）+ 调用后（post-evidence）** | 双向覆盖 |
| Audit log 存储 | SQLite / Append-only file / 远端 | **本地 append-only file + W8 本地 sink server**（TCP 17803, 自部署）| 不可篡改；远端 sink 降为企业 opt-in（非云）；见 W8 §3 |
| Audit log 与 evidence 关系 | 同表 / 不同表同链 | **不同表同链**（防 schema 塌缩）| 每条 audit-log 引用 evidence-record id |
| 管理面板 | office app 内 / 独立 Web UI | **独立 Web UI（local-only / 自部署）** | 与桌面 app 解耦；管理员视角独立 |
| 离线 policy | 内嵌 / 远端拉 / 混合 | **内嵌 binary** | 离线可用；远端 override 仅企业版 |

---

## 3. 文件层

### 待创建（**需授权**）

```
ai/source/policy/PolicyEngine.cxx              # 评估器
ai/source/policy/RuleParser.cxx                 # YAML → AST
ai/source/audit/AuditLog.cxx                    # append-only 写入
ai/source/audit/AuditSink.cxx                   # 远端 sink（opt-in）
ai/source/tenant/TenantContext.cxx              # 当前租户上下文
officecfg/registry/data/org/openoffice/Office/Tenant.xcu       # 默认租户
officecfg/registry/data/org/openoffice/Office/PolicyRules.xcu  # 内嵌 policy
```

### Schema（**进 V3 schema 锁**）

```
docs/schemas/audit-log-entry.schema.json       # active contract
docs/schemas/policy-rule.schema.json          # active contract
docs/schemas/tenant-context.schema.json       # active contract
```

### 管理面板（独立项目）

```
admin-panel/                                    # 全新目录，独立构建
admin-panel/package.json
admin-panel/src/...
admin-panel/README.md
```

> 管理面板使用什么前端栈待定（候选：Vue + Vite / SvelteKit / 纯 HTMX）；
> **不进 office app monorepo 的主构建**。

### 待创建（纯 docs）

```
docs/product/v3/w4-tenant-policy-audit-spec.md  # 本文档
docs/product/v3/w4-policy-dsl-design.md         # DSL 设计稿
docs/product/v3/w4-compliance-mapping.md        # 等保 2.0 / GDPR 映射
```

---

## 4. Policy DSL 草稿

```yaml
# 例 1：禁用所有 cloud 连接器（offline 模式默认）
- id: deny-cloud-connectors-in-offline
  when:
    serviceMode: offline
    actor.role: any
    target.type: connector
    target.attributes.dataClass: [confidential, secret]
  effect: deny
  reason: "offline mode disallows confidential/secret data egress"

# 例 2：仅允许指定 tenant 用 GPT-4
- id: gpt4-tenant-allowlist
  when:
    actor.tenant: [acme, beta-corp]
    target.type: provider
    target.attributes.modelFamily: gpt-4
  effect: allow

# 例 3：所有 chat 调用必须 evidence
- id: require-evidence-for-chat
  when:
    target.type: chat
  effect: require-evidence
```

---

## 5. Audit Log Entry Schema 草稿

```json
{
  "$id": "https://kqoffice.example.com/schemas/audit-log-entry.schema.json",
  "type": "object",
  "required": ["id", "timestamp", "tenant", "actor", "action", "evidenceId"],
  "properties": {
    "id":          { "type": "string", "format": "uuid" },
    "timestamp":   { "type": "string", "format": "date-time" },
    "tenant":      { "type": "string" },
    "workspace":   { "type": "string" },
    "actor": {
      "type": "object",
      "required": ["id", "role"],
      "properties": {
        "id":   { "type": "string" },
        "role": { "enum": ["user", "admin", "service"] }
      }
    },
    "action": {
      "type": "object",
      "required": ["type", "target"],
      "properties": {
        "type":   { "enum": ["chat", "patch-apply", "connector-fetch", "kb-query", "agent-step"] },
        "target": { "type": "string" }
      }
    },
    "evidenceId":  { "type": "string", "format": "uuid" },
    "policyDecision": { "enum": ["allow", "deny", "require-approval"] },
    "approvalChain": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["approverId", "decision", "timestamp"]
      }
    }
  }
}
```

**注意**：`audit-log-entry` 引用 `evidenceId`，但**不复用 evidence schema 字段**
（防止两 schema 塌缩为一）。

Active contract extension: `docs/schemas/audit-log-entry.schema.json` now requires `evidenceId` to match `ev-[0-9a-f]{16}`, carries append-only `chain.previousHash` / `chain.entryHash` fields, and requires `redaction.storesDocumentContent=false`. `tests/v3-audit-log-entry-test.sh` is the W4 audit-log-entry self-test; it reports `Checks: 7` and is wired into `bin/v3-eval-sweep.sh --self-test`.

Policy/tenant contract extension: `docs/schemas/policy-rule.schema.json` and `docs/schemas/tenant-context.schema.json` now lock W4's tenant isolation and policy DSL envelope before runtime implementation. `tests/v3-policy-tenant-test.sh` is the W4 policy-tenant self-test. It validates the paired fixtures under `docs/qa/fixtures/v3/policy-tenant/`, effect/enforcement semantics, `tenantIsolation=true`, local-only admin panel, audit `sinkPort=17803`, append-only hash-chain requirement, evidence/audit requirements, and schema-collapse boundaries. It reports `Checks: 8` and is wired into `bin/v3-eval-sweep.sh --self-test`.

---

## 6. 与 V2 衔接

| V2 资产 | 在 W4 中的角色 |
|---|---|
| V2 evidence-record | 每条 audit-log 必有 evidenceId 引用；schema 不变 |
| V2 service-mode | service-mode 是 policy 的一个 attribute（不是替代） |
| V2 H1-H7 | W4 落地不破坏任何 H1-H7（H8 增量验证 audit/policy） |

**塌缩防护**：

- `audit-log-entry` ≠ `evidence-record`（多对一引用）
- `policy-rule` ≠ V2 任何 schema
- `tenant-context` ≠ V2 任何 schema

---

## 7. 验证

### 单测（待写）

```
CppunitTest_ai_policy_rule_parser
CppunitTest_ai_policy_engine_eval_allow
CppunitTest_ai_policy_engine_eval_deny
CppunitTest_ai_policy_engine_eval_require_approval
CppunitTest_ai_audit_append_only_invariant
CppunitTest_ai_audit_evidence_link
CppunitTest_ai_tenant_context_isolation
```

### Fixture（audit-log-entry + policy-tenant active）

- `docs/qa/fixtures/v3/policy-tenant/valid/offline-deny-cloud-connector.json`
- `docs/qa/fixtures/v3/policy-tenant/valid/tenant-private-provider-allow.json`
- `docs/qa/fixtures/v3/policy-tenant/valid/secret-agent-step-require-approval.json`
- `docs/qa/fixtures/v3/policy-tenant/valid/chat-require-evidence-post.json`
- `docs/qa/fixtures/v3/policy-tenant/invalid/tenant-allows-public-egress.json`
- `docs/qa/fixtures/v3/policy-tenant/invalid/policy-effect-enforcement-drift.json`
- `docs/qa/fixtures/v3/policy-tenant/invalid/collapsed-evidence-fields.json`
- `docs/qa/fixtures/v3/audit-log-entry/valid/chat-private-allow.json`
- `docs/qa/fixtures/v3/audit-log-entry/valid/patch-apply-require-approval.json`
- `docs/qa/fixtures/v3/audit-log-entry/valid/connector-fetch-deny.json`
- `docs/qa/fixtures/v3/audit-log-entry/invalid/missing-evidence-id.json`
- `docs/qa/fixtures/v3/audit-log-entry/invalid/stores-document-content.json`
- `docs/qa/fixtures/v3/audit-log-entry/invalid/collapsed-evidence-record-fields.json`

### 合规对照

| 要求 | 实现 |
|---|---|
| 等保 2.0 三级 - 审计日志完整性 | append-only file + hash chain |
| GDPR Art. 17 - Right to erasure | 用户级 evidence + audit 删除 API（不影响其它 tenant） |
| GDPR Art. 30 - Records of processing | audit log 即满足 |
| ISO 27001 - 访问控制 | policy engine + tenant 三层模型 |

### 回归

- V1.5 27/27 ✅
- V2 H1-H7 ✅
- 引入 W4 后 V2 evidence-record 调用路径不变（向后兼容）

---

## 8. Open Questions / Blockers

- Q1：管理面板是否要做（V3 v0 是否可以先用 CLI）？
- Q2：Policy DSL 是否需要 lambda / regex（当前 attribute 匹配可能不够）
- Q3：Audit log 文件大小如何控制（rotation / archive）
- Q4：远端 sink 协议（syslog / OTLP / 自定义 HTTP）
- Q5：Tenant 在桌面端的初始化流程（首次启动 / 配置文件 / 远端 provision）

---

## 9. 时间线（保守估算）

- Q4 2027 (3w)：tenant context + policy schema + 内嵌默认 policy
- Q1 2028 (3w)：policy engine + audit append-only + evidence link
- Q1 2028 (3w)：管理面板 v0（read-only 视图）
- Q2 2028 (3w)：远端 sink + GDPR 删除 API + H8 校验

总计：8–12 周。
