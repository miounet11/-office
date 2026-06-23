# V3-W2 Manifest Trust Policy

Status: **Contract-only** (2026-06-10: H8 trust-chain guard active; runtime implementation not started)
Owner wave: V3-W2 Connector Layer
Harness: `tests/v3-connector-manifest-contract-test.sh` (H8)

---

## 1. Goal

Prevent malicious or ambiguous connector manifests from entering the V3 connector
layer before any runtime registry, installer, or `officecfg` integration exists.

The policy answers W2 Q4: community connector contributions are allowed only when
their manifest identity, review path, installation scope, and signature posture
are explicit and testable.

---

## 2. Trust Envelope

Every connector manifest must include:

```json
{
  "trust": {
    "source": "builtin",
    "publisher": "kqoffice",
    "manifestSha256": "sha256:<64 lowercase hex chars>",
    "reviewState": "repo-reviewed",
    "installScope": "builtin",
    "signatureRequired": true,
    "allowUnsigned": false
  }
}
```

H8 locks this object with `additionalProperties:false`.

Field contract:

| Field | Allowed values | Contract |
|---|---|---|
| `source` | `builtin`, `community`, `enterprise-admin` | Declares who supplied the manifest |
| `publisher` | lowercase slug, 3-64 chars | Stable publisher identity used by install/audit UI |
| `manifestSha256` | `sha256:` + 64 lowercase hex chars | Pins the reviewed manifest bytes |
| `reviewState` | `repo-reviewed`, `security-reviewed`, `tenant-approved` | Highest completed review gate |
| `installScope` | `builtin`, `user`, `tenant` | Maximum scope the manifest may be installed into |
| `signatureRequired` | boolean | Must be `true` for every installable manifest |
| `allowUnsigned` | `false` | Unsigned manifests are forbidden |

---

## 3. Semantic Rules

- Built-in manifests must use `source=builtin`, `publisher=kqoffice`,
  `reviewState=repo-reviewed`, and `installScope=builtin`.
- Community manifests installed by a user must use `reviewState=security-reviewed`
  and `installScope=user`.
- Tenant-wide installs must use `reviewState=tenant-approved`.
- Enterprise-admin manifests must install only at tenant scope and must be
  tenant-approved.
- All manifests must require a signature and must keep `allowUnsigned=false`.
- All manifests must pin `manifestSha256` before the runtime registry is allowed
  to load them.

---

## 4. Guard Fixtures

The H8 invalid roster includes trust-chain guards for:

- unsigned community manifest
- missing manifest hash
- unreviewed community manifest
- tenant-scope manifest without tenant approval

These guards are intentionally contract-only. They do not authorize manifest
installation UI, signature verification runtime, registry loading, marketplace
submission, or `Connectors.xcu` registration.

---

## 5. Runtime Boundary

Future runtime work must keep these boundaries:

- The manifest loader rejects unsigned manifests before network/auth setup.
- Signature verification happens before OAuth/API key prompts.
- Tenant installs require tenant policy evidence before connector activation.
- Audit records cite connector id, publisher, manifest hash, review state, and
  install scope.
- Built-in connector registration remains locked by H8 once `Connectors.xcu`
  exists.
