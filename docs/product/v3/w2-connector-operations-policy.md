# V3-W2 Connector Operations Policy

Status: **Contract-only** (2026-06-10: H8 read-only/writeback guard active; runtime implementation not started)
Owner wave: V3-W2 Connector Layer
Harness: `tests/v3-connector-manifest-contract-test.sh` (H8)

---

## 1. Goal

Keep V3 v0 connectors read-only until there is a separate product decision,
tenant policy model, approval flow, evidence model, and runtime implementation
for connector writeback.

The policy answers W2 Q5: connectors may fetch context for prompts, but they may
not write back to SaaS systems such as Notion, Confluence, SharePoint, Slack, or
Feishu/WeCom during the V3 v0 contract phase.

---

## 2. Operations Envelope

Every connector manifest must include:

```json
{
  "operations": {
    "mode": "read-only",
    "allowedActions": ["read"],
    "writeback": false,
    "writeScopesAllowed": false,
    "runtimeWriteImplementation": "not-started"
  }
}
```

H8 locks this object with `additionalProperties:false`.

Field contract:

| Field | Contract |
|---|---|
| `mode` | Must be `read-only` |
| `allowedActions` | Must be exactly `["read"]` |
| `writeback` | Must be `false` |
| `writeScopesAllowed` | Must be `false` |
| `runtimeWriteImplementation` | Must be `not-started` |

---

## 3. Read-Only Guards

H8 rejects:

- `operations.mode=read-write`
- `operations.allowedActions` containing `write`
- `operations.writeback=true`
- `operations.writeScopesAllowed=true`
- `operations.runtimeWriteImplementation=started`
- provider auth scopes containing `:write`
- connector scopes named `write:*`
- `evidence.category=data-write`

The connector schema still reserves the `data-write` evidence category for a
future wave, but H8 forbids it for V3 v0 connector manifests.

---

## 4. Runtime Boundary

This policy does not authorize connector writeback implementation. Future work
that wants writeback must first add a new contract increment covering:

- user approval before every external write
- tenant policy and audit gates for write scopes
- evidence records that distinguish fetch, draft, and committed external writes
- rollback or compensating-action behavior for each connector
- explicit UI labeling that the action writes to an external system

Until that increment lands, all connector runtime work must treat manifests as
read-only context fetch contracts.
