# Service Mode Policy

Generated: 2026-04-28

## Purpose

This policy blocks plugin runtime loading, AI provider integration, and service-backed document automation until 可圈office has explicit offline, local, private, and cloud behavior boundaries.

Core editing must remain fully usable when every service, plugin, connector, AI provider, and network feature is disabled.

## Service Modes

| Mode | Meaning | Allowed Before Runtime Loader | Network | Document Context |
| --- | --- | --- | --- | --- |
| `offline` | Built-in or packaged capability with no network access. | Yes, through schema/manifest validation only. | None. | Local document inspection only. |
| `local` | User-controlled localhost or LAN service. | Policy/design only until loader exists. | Loopback or explicit local endpoint. | Only selected document ranges after user action. |
| `private` | Organization-controlled private endpoint. | No runtime before admin policy, consent, and audit logging. | Explicit enterprise endpoint. | Scoped payload with visible context summary. |
| `cloud` | Public hosted provider. | No runtime before explicit user consent, privacy review, and failure isolation. | Public provider endpoint. | Minimum selected context only; never silent whole-document upload. |

## Non-Negotiable Product Rules

- Offline editing, save, export, print preview, templates, and compatibility workflows must work without login or service configuration.
- Service failure must not mutate document content, styles, selection, undo stack, or modified state.
- Generated output enters as preview, diagnostic, or editable insertion; never as silent replacement.
- External calls require explicit user action and a Chinese-facing context summary before sending.
- Any capability that can transmit document content must declare network mode, module scope, privacy behavior, and failure behavior in the manifest.
- A disable-all-plugins mode must leave core Writer, Calc, Impress, Start Center, and compatibility operations usable.
- Runtime plugin loading stays blocked until signing, allowlist, update, and quarantine policy exists.

## Capability Matrix

| Capability | Offline | Local | Private | Cloud |
| --- | --- | --- | --- | --- |
| Static diagnostics | Allowed. | Allowed if local endpoint is optional. | Allowed only with policy. | Defer. |
| One-click formatting | Preview-only until undo grouping exists. | Same. | Same plus audit. | Defer. |
| Translation | Built-in/offline dictionary only. | Optional local engine after consent. | Enterprise endpoint after policy. | Defer until privacy review. |
| AI writing | Defer unless fully local and preview-only. | Preview-only with explicit selected context. | Preview-only with admin policy. | Defer until cloud consent model exists. |
| PPT generation | Deterministic local builder only. | Local planner may propose outline, builder stays deterministic. | Private planner later. | Defer. |
| Connectors | Local files/templates only. | Local connectors only. | Enterprise allowlist. | Defer. |

## Manifest Requirements

The current `docs/schemas/kqoffice-plugin.schema.json` already requires:

- `network`
- `privacy.requires_user_consent`
- `privacy.context_scope_zh`
- `failure_behavior.document_mutation_on_failure`
- `failure_behavior.output_mode`
- `failure_behavior.message_zh`

Until this policy is implemented in runtime code, `bin/plugin-manifest-validator.sh --policy local-offline` must continue rejecting `private` and `cloud` manifests. It must explain that rejection in product-facing terms: private/cloud modes are blocked until signing, explicit consent, service-mode enforcement, allowlist/update/quarantine policy, auditability, and failure isolation are in place. It should also continue requiring Chinese-facing failure messages and KQOffice-owned command scope.

## Enforcement Gates

The policy is enforced only by wrapper gates in this phase; it is not runtime/provider readiness.

- `bin/plugin-manifest-validator.sh --self-test --report tmp/plugin-manifest-validator.md` must include negative self-tests for both `private` and `cloud` network modes.
- The P0 wrapper must report this validator as service-policy enforcement and keep it `alpha-hard`, preserving the local/offline command behavior.
- The beta wrapper must run the validator self-test as `beta-hard`; service-policy enforcement must pass even while unrelated beta blockers remain.
- Dashboard wording must show service-policy enforcement in automated workflow coverage and beta readiness without claiming plugin loader, provider, network, signing, consent, audit, quarantine, or failure-isolation runtime support.
- Generated reports may record the enforcement state, but no provider calls, runtime loading, network behavior, document transmission, or UI command integration is allowed in this gate slice.

## Runtime Loader Prerequisites

Before any runtime loader is added, the product needs:

- Signed or locally trusted plugin package identity.
- Admin/user allowlist and disable-all switch.
- Quarantine for invalid, unsigned, or crashed plugins.
- Per-plugin network-mode enforcement.
- Per-command preview and undo behavior.
- Persistent audit record for private/cloud calls without storing sensitive document content.
- Recovery path if a plugin crashes during an operation.
- Tests proving provider failure leaves document state unchanged.

## P2-04 Acceptance

P2-04 is accepted when:

- This policy is linked from the active todolist and dashboard.
- Plugin validator remains local/offline by default.
- Private/cloud runtime is explicitly blocked until signing, consent, policy, and failure-isolation gates exist.
- No provider code or runtime plugin loader is introduced in the same round.

## Next Implementation Order

1. Keep manifest validation local/offline.
2. Add service-mode policy checks to any future plugin runtime design.
3. Build diagnostic preview UI before apply actions.
4. Build undo-grouped local apply actions before service-backed generation.
5. Only then design local/private/cloud provider adapters.
