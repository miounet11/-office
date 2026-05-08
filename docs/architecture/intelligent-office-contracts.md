# Intelligent Office Contracts

These contracts define the first safe implementation boundary for one-click formatting, diagnostics, and plugin-mounted AI/translation features. They are intentionally conservative: core editing must work when every intelligent feature is disabled.

## Diagnostic Contract

Every analyzer returns issues with the same shape:

- `id`: stable issue identifier, for example `writer.mixed-fonts`.
- `module`: `writer`, `calc`, `impress`, or `shared`.
- `severity`: `tip`, `suggestion`, `warning`, or `blocking`.
- `title_zh`: short Chinese issue title.
- `message_zh`: user-facing Chinese explanation.
- `location`: page, slide, sheet, paragraph, cell range, or object path.
- `actions`: zero or more previewable fixes.
- `evidence`: optional source such as round-trip log, validator log, or analyzer rule.

Chinese severity vocabulary:

| Severity | UI Text | Meaning |
| --- | --- | --- |
| `tip` | 提示 | Low-risk improvement or explanation. |
| `suggestion` | 建议 | Quality improvement the user may accept. |
| `warning` | 警告 | Likely formatting, compatibility, or export risk. |
| `blocking` | 阻塞 | Must be resolved before a trusted export/release workflow. |

## Formatting Action Contract

One-click formatting is not a blind rewrite. Each action must declare:

- affected range or object
- before/after summary in Chinese
- whether it is safe to apply automatically
- undo grouping identifier
- fallback if the apply step fails

Initial Writer analyzer rules:

- inconsistent heading hierarchy
- direct formatting mixed with styles
- mixed CJK/body fonts
- abnormal paragraph spacing
- broken list numbering
- table width or border inconsistency

## Plugin Manifest Contract

Plugin capabilities are declared in `kqoffice-plugin.json` before runtime registration. Required fields:

- `id`
- `name_zh`
- `version`
- `capabilities`
- `modules`
- `network`
- `privacy`
- `entrypoints`
- `failure_behavior`

Allowed network modes:

- `offline`: no network access
- `local`: local endpoint only
- `private`: enterprise/private endpoint
- `cloud`: public cloud provider

Required failure behavior:

- provider failure does not modify the document
- generated output appears as preview or editable insertion
- external calls require explicit user action
- sensitive document context is scoped and visible before sending

## Non-Goals For The Current Lane

- Do not touch `oox/`, `filter/`, `xmloff/`, or app-specific import/export filter internals without a concrete failing sample.
- Do not add cloud AI as a hard dependency.
- Do not add a generic chatbot that is disconnected from document context.
- Do not auto-apply destructive formatting changes without preview and undo.
