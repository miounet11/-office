# V3-W1: In-App Chat Spec

Status: **in-app-chat fixture self-test active / context autocomplete + Markdown rendering + chat history + streaming state + AI workspace UI + content opener route policy + formatting review policy + content review policy + artifact navigator policy + review queue policy + evidence inspector policy + interaction chrome policy + content preview matrix policy + workspace action bar policy + workspace filter/search policy + workspace context handoff policy + workspace review state sync policy + workspace activity timeline policy + workspace session snapshot policy + workspace attention routing policy + workspace native style policy + workspace content registry policy + workspace source provenance policy contracts active** (2026-06-11: fixture contract live; no new W1 schema; runtime implementation not started)
Goal id: 待启动 (`.agent/goals/v3-w1-in-app-chat/` 尚未创建)
Predecessor: V2-W1 Provider Runtime + V2-W2 Cmd+K + V2-W3 Writer Apply + V2-W4 Select-to-Act

Addendum: `docs/product/v3/w1-chat-clipboard-materialization-policy.md` is active in the same W1 fixture contract set. It locks Codex-style chat clipboard handling: large, rich, or structured pasted content becomes a local temporary content object, and the transcript/history store keeps only references.

---

## 1. Goal

在 Writer / Calc / Impress 内嵌 Chat sidebar，对话即上下文，输出即 patch。
**非目标**：不做独立 chat app；不做云端历史记录；不做账号体系。

成功画像：
- 用户在 Writer 打开任意文档 → `Cmd+Shift+K` → V2 CommandPalette → chat fallback → 弹 Chat sidebar
- 输入 "把第二段改成正式语气" → AI 调 V2 Provider → 输出 ApplyPlan patch
  → 走 V2 W3 apply 管线 → 用户审批 → 应用 + evidence 入链
- 用户输入 "@connector notion 拉昨天的会议纪要" → 走 V3-W2 → 拉数据 →
  作为 prompt 上下文 → 输出 patch
- 整个过程**默认离线**，所有 evidence 本地

---

## 2. 关键决策

| 决策点 | 选项 | 当前默认 | 理由 |
|---|---|---|---|
| 快捷键 | Cmd+K / Cmd+Shift+K / 自定义 | **Cmd+Shift+K** | 避让 V2-W2 已占 Cmd+K + `Accelerators.xcu:93` `.uno:HyperlinkDialog` |
| 入口路由 | direct accelerator / CommandPalette fallback / menu only | **CommandPalette chat fallback** | `Cmd+Shift+K` 先保留给 V2 CommandPalette，W1 不注册第二个直接 accelerator |
| Sidebar 容器 | sfx2 sidebar / 自建 vcl 浮窗 / WebView | **sfx2 sidebar 扩展** | 与 V2-W4 Diff 视图同框架，不引入新基础设施 |
| Chat 历史 | 本地 SQLite / 内存 / 不存 | **本地 SQLite (per-doc)** | 不上云；per-doc 避免跨文档泄露上下文 |
| Markdown 渲染 | 自渲染 / WebView / 第三方 | **自渲染（subset）** | 桌面 app 不引 WebView；只渲染 heading/list/code/table |
| 流式输出 | SSE / chunk / 一次性 | **chunk** | 复用 V2 Provider chunk 接口；不改 IDL |
| 多轮上下文 | 全文档上下文 / 选中区 / 显式 @ | **显式 @** | 默认只发 system prompt + user message；上下文 opt-in |

---

## 3. 文件层

### 待创建（**需授权**）

```
sfx2/source/sidebar/AIChatPanel.cxx           # 新 panel 注册
sfx2/source/sidebar/AIChatPanel.hxx
sfx2/uiconfig/sidebar/AIChatPanel.xml         # UI 描述
officecfg/registry/data/org/openoffice/Office/Sidebar.xcu  # 注册 panel
officecfg/registry/data/org/openoffice/Office/Accelerators.xcu  # 不新增 W1 直接绑定；仅在授权后接 CommandPalette fallback
sw/source/uibase/app/docsh-ai-chat.cxx        # Writer hook（非 docsh*.cxx 主文件）
sc/source/ui/app/scchat-bridge.cxx            # Calc hook
sd/source/ui/app/sdchat-bridge.cxx            # Impress hook
```

### 待创建（纯 docs，可逆）

```
docs/product/v3/w1-in-app-chat-spec.md        # 本文档
docs/product/v3/w1-keyboard-shortcut-survey.md  # Cmd+Shift+K 决议依据
docs/product/v3/w1-sidebar-uiwireframe.md      # 线框图
docs/qa/fixtures/v3/in-app-chat/              # W1 chat fixture contract（active）
tests/v3-in-app-chat-test.sh                  # W1 in-app-chat self-test（active）
docs/product/v3/w1-keyboard-shortcut-survey.md # CommandPalette chat fallback route（active）
docs/product/v3/w1-sidebar-uiwireframe.md      # sfx2 sidebar layout contract（active）
docs/product/v3/w1-context-syntax-policy.md    # explicit context mention grammar（active）
docs/product/v3/w1-context-autocomplete-policy.md # scoped @ mention autocomplete contract（active）
docs/product/v3/w1-markdown-rendering-policy.md # native Markdown subset contract（active）
docs/product/v3/w1-chat-history-policy.md      # per-doc local history contract（active）
docs/product/v3/w1-streaming-state-policy.md   # V2 chunk streaming state contract（active）
docs/product/v3/w1-ai-workspace-ui-policy.md   # AI workspace review/progress/opening UI contract（active）
docs/product/v3/w1-content-opener-policy.md    # content opener route policy（active）
docs/product/v3/w1-formatting-review-policy.md # formatting review policy（active）
docs/product/v3/w1-content-review-policy.md    # content review policy（active）
docs/product/v3/w1-artifact-navigator-policy.md # artifact/content navigator policy（active）
docs/product/v3/w1-review-queue-policy.md      # review queue policy（active）
docs/product/v3/w1-evidence-inspector-policy.md  # evidence/citation inspector policy（active）
docs/product/v3/w1-interaction-chrome-policy.md    # interaction chrome policy（active）
docs/product/v3/w1-content-preview-matrix-policy.md # content preview matrix policy（active）
docs/product/v3/w1-workspace-action-bar-policy.md # workspace action bar policy（active）
docs/product/v3/w1-workspace-filter-search-policy.md # workspace filter/search policy（active）
docs/product/v3/w1-workspace-context-handoff-policy.md # workspace context handoff policy（active）
docs/product/v3/w1-workspace-review-state-sync-policy.md # workspace review state sync policy（active）
docs/product/v3/w1-workspace-activity-timeline-policy.md # workspace activity timeline policy（active）
docs/product/v3/w1-workspace-session-snapshot-policy.md # workspace session snapshot policy（active）
docs/product/v3/w1-workspace-attention-routing-policy.md # workspace attention routing policy（active）
docs/product/v3/w1-workspace-native-style-policy.md # workspace native style policy（active）
docs/product/v3/w1-workspace-content-registry-policy.md # workspace content registry policy（active）
docs/product/v3/w1-workspace-source-provenance-policy.md # workspace source provenance policy（active）
docs/product/v3/w1-chat-clipboard-materialization-policy.md # chat clipboard materialization policy（active）
```

---

## 4. 与 V2 衔接

| V2 资产 | 在 W1 中的角色 |
|---|---|
| V2-W1 `XProvider` | Chat 输出走 `XProvider::generate(prompt, options)` |
| V2-W1 service-mode (offline/private/cloud) | Chat 默认 offline；切档同 V2 |
| V2-W2 Cmd+K palette | Chat 是 palette 的"chat fallback"档位（第三态）|
| V2-W2 三态调度 | 用户文本 → slot fuzzy → LLM intent → chat（同框架）|
| V2-W3 `applyDiagnosticsPlan` | Chat 输出 ApplyPlan 后走该 wiring |
| V2-W4 Select-to-Act | Chat 也支持"选中后右键 → 发到 chat" |
| V2 evidence-record | 每次 chat 调用产生 evidence；schema 不变 |
| V2 ApplyPlan token lock | Chat 输出严格符合 7/5/4 token 锁 |

**不引入新 schema**（W1 全程复用 V2）。

---

## 5. 验证

### 单测（待写）

```
CppunitTest_sfx2_aichat_panel_registration   # panel 注册
CppunitTest_sfx2_aichat_provider_dispatch    # chat → XProvider 调用
CppunitTest_sw_aichat_apply_pipeline         # chat → ApplyPlan → applyDiagnosticsPlan
CppunitTest_sc_aichat_apply_pipeline         # 同 Calc
CppunitTest_sd_aichat_apply_pipeline         # 同 Impress
```

### Fixture（in-app-chat active）

- `docs/qa/fixtures/v3/in-app-chat/valid/writer-rewrite-formal.json`
- `docs/qa/fixtures/v3/in-app-chat/valid/writer-doc-summary.json`
- `docs/qa/fixtures/v3/in-app-chat/valid/calc-format-date.json`
- `docs/qa/fixtures/v3/in-app-chat/valid/impress-summarize-bullets.json`
- `docs/qa/fixtures/v3/in-app-chat/valid/connector-context-readonly.json`（依赖 W2 manifest contract）
- `docs/qa/fixtures/v3/in-app-chat/invalid/cloud-history-enabled.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/bypasses-apply-plan-runtime.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/missing-human-approval.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/introduces-new-chat-schema.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/direct-accelerator-registration.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/implicit-full-doc-context.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/unknown-context-mention.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/connector-write-context.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/raw-html-rendering.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/webview-renderer.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/remote-image-rendering.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/global-history-leakage.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/cloud-history-sync.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/raw-transcript-history.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/missing-history-clear-control.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/streaming-mutates-document.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/partial-chunks-persisted.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/missing-terminal-evidence.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/unsupported-stream-state.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/global-autocomplete-hijack.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/unknown-connector-suggestion.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/raw-context-preview.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/autocomplete-runtime-parser-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/workspace-modal-chat-only.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/workspace-missing-task-progress.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/workspace-review-without-evidence.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/workspace-formatting-no-preview.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/workspace-openers-runtime-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/opener-route-policy-drift.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/opener-missing-evidence-link.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/opener-mutable-preview.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/opener-silent-failure.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/formatting-review-missing-envelope.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/formatting-review-no-diffreview.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/formatting-review-mutable-preview.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/formatting-review-runtime-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/content-review-missing-envelope.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/content-review-no-evidence.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/content-review-mutable-suggestion.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/content-review-runtime-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/artifact-navigator-missing-envelope.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/artifact-navigator-type-drift.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/artifact-navigator-mutable-details.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/artifact-navigator-runtime-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/review-queue-missing-envelope.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/review-queue-no-filter.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/review-queue-bulk-auto-apply.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/review-queue-runtime-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/evidence-inspector-missing-envelope.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/evidence-inspector-source-drift.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/evidence-inspector-raw-payload.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/evidence-inspector-runtime-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/interaction-chrome-missing-envelope.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/interaction-chrome-modal-only.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/interaction-chrome-no-keyboard.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/interaction-chrome-runtime-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/preview-matrix-missing-envelope.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/preview-matrix-type-drift.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/preview-matrix-raw-payload.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/preview-matrix-runtime-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/action-bar-missing-envelope.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/action-bar-command-drift.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/action-bar-hidden-mouse-only.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/action-bar-runtime-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/filter-search-missing-envelope.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/filter-search-scope-drift.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/filter-search-raw-index.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/filter-search-runtime-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/context-handoff-missing-envelope.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/context-handoff-target-drift.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/context-handoff-raw-payload.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/context-handoff-runtime-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/review-state-sync-missing-envelope.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/review-state-sync-target-drift.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/review-state-sync-auto-apply.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/review-state-sync-runtime-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/activity-timeline-missing-envelope.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/activity-timeline-event-drift.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/activity-timeline-raw-payload.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/activity-timeline-runtime-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/session-snapshot-missing-envelope.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/session-snapshot-scope-drift.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/session-snapshot-raw-payload.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/session-snapshot-runtime-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/attention-routing-missing-envelope.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/attention-routing-surface-drift.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/attention-routing-raw-payload.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/attention-routing-runtime-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/native-style-missing-envelope.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/native-style-density-drift.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/native-style-card-layout.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/native-style-runtime-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/content-registry-missing-envelope.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/content-registry-type-drift.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/content-registry-raw-payload.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/content-registry-runtime-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/source-provenance-missing-envelope.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/source-provenance-type-drift.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/source-provenance-raw-payload.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/source-provenance-runtime-started.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/clipboard-materialization-missing-envelope.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/clipboard-materialization-raw-transcript.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/clipboard-materialization-memory-only.json`
- `docs/qa/fixtures/v3/in-app-chat/invalid/clipboard-materialization-runtime-started.json`

### Contract self-test（active）

`tests/v3-in-app-chat-test.sh` is the W1 in-app-chat fixture self-test. It validates the 5 valid / 104 invalid fixture roster, Writer/Calc/Impress surface coverage, connector-context coverage, explicit context syntax, scoped context autocomplete, native Markdown subset rendering, per-doc-local chat history, V2 chunk streaming UI states, AI workspace UI semantics from `docs/product/v3/w1-ai-workspace-ui-policy.md`, content opener route policy from `docs/product/v3/w1-content-opener-policy.md`, formatting review policy from `docs/product/v3/w1-formatting-review-policy.md` (`reviewMode=before-after-layout-diff`, paragraph/character/table/cell/slide layout scope, DiffReview reuse, evidence link, human approval, no raw or preview content in fixtures, and `runtimeFormattingImplementation=not-started`), content review policy from `docs/product/v3/w1-content-review-policy.md` (`reviewMode=evidence-linked-content-diff`, selection/document-section/connector-result/knowledge-index-result/evidence-record/task-step scope, DiffReview reuse, evidence link, human approval, no raw or suggestion content in fixtures, and `runtimeContentReviewImplementation=not-started`), artifact navigator policy from `docs/product/v3/w1-artifact-navigator-policy.md` (`managedTypes=[document,selection,connector-result,knowledge-index-result,evidence-record,task-step]`, current-workspace/current-document scope, evidence badges, content opener integration, read-only details, no raw artifact content in fixtures, and `runtimeArtifactNavigatorImplementation=not-started`), review queue policy from `docs/product/v3/w1-review-queue-policy.md` (`itemTypes=[content-review,formatting-review,task-step]`, queued/open/approved/rejected/applied/failed states, state/type/surface filters, DiffReview opening, evidence links, explicit human approval for bulk actions, no raw review content in fixtures, and `runtimeReviewQueueImplementation=not-started`), evidence inspector policy from `docs/product/v3/w1-evidence-inspector-policy.md` (`sourceTypes=[evidence-record,connector-result,knowledge-index-result,task-step,review-item]`, citation links, audit trail, content opener integration, redacted raw payloads, hash-only references, no raw evidence/citation content in fixtures, and `runtimeEvidenceInspectorImplementation=not-started`), interaction chrome policy from `docs/product/v3/w1-interaction-chrome-policy.md` (`layout=sidebar-workbench`, `navigation=segmented-tabs`, `panels=[chat,tasks,artifacts,reviews,evidence]`, persistent composer, visible task/artifact/review/evidence rails, keyboard tab order, Escape focus return, no focus trap, compact native controls, no modal-only chat, and `runtimeInteractionChromeImplementation=not-started`), content preview matrix policy from `docs/product/v3/w1-content-preview-matrix-policy.md` (`contentTypes=[document,selection,connector-result,knowledge-index-result,evidence-record,task-step,review-item]`, document/main-window, selection/connector/knowledge/evidence sidebar previews, task-step/review-item DiffReview previews, metadata/read-only/diff/evidence modes, evidence badges, source metadata, redaction, hash-only references, no raw or preview fixture payloads, and `runtimePreviewMatrixImplementation=not-started`), workspace action bar policy from `docs/product/v3/w1-workspace-action-bar-policy.md` (`commands=[open-preview,open-diff-review,approve-selected,reject-selected,copy-reference,export-evidence,filter,sort,retry,cancel]`, task/review/artifact/evidence/preview targets, keyboard access, native controls, visible state, evidence links, contentOpeners/DiffReview reuse, explicit human approval for bulk apply, no auto-apply, no hidden or mouse-only actions, and `runtimeActionBarImplementation=not-started`), workspace filter/search policy from `docs/product/v3/w1-workspace-filter-search-policy.md` (`surfaces=[tasks,artifacts,reviews,evidence,previews]`, current workspace/current document scope, metadata-only/hash-only search fields, no raw indexing, content opener reuse, evidence links, and `runtimeFilterSearchImplementation=not-started`), workspace context handoff policy from `docs/product/v3/w1-workspace-context-handoff-policy.md` (`entrySurfaces=[filter-search-result,artifact-navigator-item,review-queue-item,evidence-inspector-link,preview-matrix-item,action-bar-command]`, visible breadcrumb/back/focus return, preserved task/evidence/hash/preview/review metadata, contentOpeners/DiffReview reuse, no raw handoff payloads, no auto-apply, and `runtimeContextHandoffImplementation=not-started`), workspace review state sync policy from `docs/product/v3/w1-workspace-review-state-sync-policy.md` (`stateSources=[review-queue,diff-review,preview-matrix,evidence-inspector,task-progress,action-bar]`, queued/open/approved/rejected/applied/failed states, open/approve/reject/apply/fail transitions, evidence links, visible state, DiffReview/contentOpeners reuse, explicit human approval for bulk apply, no auto-apply, and `runtimeReviewStateSyncImplementation=not-started`), workspace activity timeline policy from `docs/product/v3/w1-workspace-activity-timeline-policy.md` (`events=[chat-requested,task-started,artifact-created,content-opened,review-opened,review-state-changed,evidence-linked,action-invoked,failure-reported]`, chat/tasks/artifacts/reviews/evidence/previews/action-bar surfaces, chronological append-only metadata, visible timestamp/actor/open target, contentOpeners/DiffReview/evidence inspector reuse, no raw or transcript content in fixtures, and `runtimeActivityTimelineImplementation=not-started`), workspace session snapshot policy from `docs/product/v3/w1-workspace-session-snapshot-policy.md` (`restores=[active-task-id,open-artifact-id,open-review-id,active-evidence-id,preview-mode,review-state,activity-cursor,failure-state]`, current-workspace/current-document scope, resume summary, explicit resume, visible timestamp/document binding, contentOpeners/DiffReview/evidence inspector/activity timeline reuse, no raw/preview/transcript fixture content, and `runtimeSessionSnapshotImplementation=not-started`), workspace attention routing policy from `docs/product/v3/w1-workspace-attention-routing-policy.md` (`triggers=[approval-required,review-ready,task-failed,evidence-missing,resume-available]`, sidebar badge/tab badge/task row/review queue/activity event/resume banner surfaces, routes to task progress/review queue/DiffReview/evidence inspector/activity timeline/session snapshot, visible reason/timestamp/open target, keyboard access, native controls, no cloud push, no auto-open, and `runtimeAttentionRoutingImplementation=not-started`), workspace content registry policy from `docs/product/v3/w1-workspace-content-registry-policy.md` (`types=[document,selection,connector-result,knowledge-index-result,evidence-record,task-step,review-item,formatting-preview,content-suggestion]`, `requiredFields=[object-id,type,source-surface,state,evidence-id,hash-reference,open-target,preview-mode]`, metadata-only hash references, contentOpeners/previewMatrix/evidenceInspector/reviewQueue reuse, no raw/preview/transcript fixture payloads, no auto-open, no auto-apply, and `runtimeContentRegistryImplementation=not-started`), workspace source provenance policy from `docs/product/v3/w1-workspace-source-provenance-policy.md` and chat clipboard materialization policy from `docs/product/v3/w1-chat-clipboard-materialization-policy.md` (`sourceTypes=[document,selection,connector-result,knowledge-index-result,evidence-record,task-step,review-item,formatting-preview,content-suggestion]`, `requiredFields=[source-id,source-type,citation-id,evidence-id,hash-reference,source-surface,open-target,span-reference,review-id]`, maps AI claims/suggestions/formatting changes to openable evidence-backed sources, contentRegistry/contentOpeners/evidenceInspector/reviewQueue/DiffReview reuse, no raw/source/preview/transcript fixture payloads, no auto-open, no auto-apply, and `runtimeSourceProvenanceImplementation=not-started`), `Cmd+Shift+K` → CommandPalette `command-palette-chat-fallback` → `sfx2-sidebar` entry semantics, V2 Provider/ApplyPlan/evidence reuse, human approval before main-document mutation, no cloud history, no stored prompt content, and `runtimeImplementation=not-started`. It deliberately rejects any `docs/schemas/in-app-chat*.schema.json` file because W1 introduces no new schema.

### GUI smoke（待写）

- `bin/v3-w1-smoke.sh`：启动 app → Cmd+Shift+K → 输入固定 prompt → 检查 sidebar HTML 文本

### 回归

- V1.5 27/27 ✅
- V2 H1-H10 ✅
- V3 W1 in-app-chat fixture self-test ✅（27 checks; context autocomplete + Markdown subset + per-doc history + streaming state + AI workspace UI + content opener route policy + formatting review policy + content review policy + artifact navigator policy + review queue policy + evidence inspector policy + interaction chrome policy + content preview matrix policy + workspace action bar policy + workspace filter/search policy + workspace context handoff policy + workspace review state sync policy + workspace activity timeline policy + workspace session snapshot policy + workspace attention routing policy + workspace native style policy + workspace content registry policy + workspace source provenance policy contracts active; not H13）

---

## 6. Open Questions / Blockers

- ~~B1：Cmd+Shift+K 真的没有冲突？~~ **决议**：`docs/product/v3/w1-keyboard-shortcut-survey.md` 锁定 W1 只走 CommandPalette chat fallback，不注册直接 accelerator；runtime grep 仍待实施期复验。
- ~~Q1：sfx2 sidebar 是否支持流式更新？需要 spike~~ **决议**：`docs/product/v3/w1-streaming-state-policy.md` 锁定 V2 chunk → sidebar 状态机合同；实际 sfx2 增量渲染能力仍在 runtime gate 下实施期复验。
- ~~Q2：Markdown 自渲染范围（是否要支持表格、代码 syntax highlight）~~ **决议**：`docs/product/v3/w1-markdown-rendering-policy.md` 锁定 native-rich-text subset：paragraph / heading / list / code-fence / table；不引 WebView、raw HTML 或远程图片。
- ~~Q3：每文档独立 chat 历史 vs 全局历史，UX 路径未定~~ **决议**：`docs/product/v3/w1-chat-history-policy.md` 锁定 `per-doc-local` + `local-sqlite-sidecar` + `document-id-hash`；禁止云同步、全局索引、跨文档恢复和 fixture 原文 transcript 存储，并要求可见清除入口。
- ~~Q4：`@selection` / `@doc` / `@connector:notion` 语法是否冲突 office 现有补全~~ **决议**：`docs/product/v3/w1-context-autocomplete-policy.md` 锁定 @ suggestion 只在 chat input 内生效，`officeAutocompletePolicy=delegate-existing-controls`，禁止劫持全局 Office autocomplete；实际 mention popup/parser 仍在 runtime gate 下实施期复验。
- ~~Q5：AI 入口是否只是文件编辑聊天框，还是要承载审查、排版、打开更多内容类型和任务进度~~ **决议**：`docs/product/v3/w1-ai-workspace-ui-policy.md` 锁定 `ai-workspace-sidebar` + `conversation-plus-progress`，要求可见 task progress / step list / evidence links，支持 content review、formatting review、DiffReview、before-after-preview，以及 document / selection / connector-result / knowledge-index-result / evidence-record / task-step 打开面；实际 UI/runtime opener 仍在 runtime gate 下实施期复验。
- ~~Q6：document / selection / connector-result / knowledge-index-result / evidence-record / task-step 应该打开到哪里，失败是否可静默~~ **决议**：`docs/product/v3/w1-content-opener-policy.md` 锁定 document → main-document-window，selection / connector-result / knowledge-index-result / evidence-record → sidebar-preview，task-step → diff-review；所有 opener 必须 evidence-linked、read-only preview、fail-closed-user-visible，且不得在审批前修改主文档。
- ~~Q7：排版/格式审查是否只是文本建议，还是需要可审查的布局差异面~~ **决议**：`docs/product/v3/w1-formatting-review-policy.md` 锁定 `reviewMode=before-after-layout-diff`，覆盖 paragraph-style / character-style / table-layout / cell-format / slide-layout，复用 DiffReview，要求 evidence link、人审、主文档审批前不变，禁止 fixture 存原文或预览内容；实际 formatting runtime 仍在 runtime gate 下实施期复验。
- ~~Q8：内容审查是否只是聊天回复，还是要成为可审计的修改建议面~~ **决议**：`docs/product/v3/w1-content-review-policy.md` 锁定 `reviewMode=evidence-linked-content-diff`，覆盖 selection / document-section / connector-result / knowledge-index-result / evidence-record / task-step，复用 DiffReview，要求 evidence link、人审、主文档审批前不变，禁止 fixture 存原文或建议内容；实际 content review runtime 仍在 runtime gate 下实施期复验。
- ~~Q9：AI 参与产生的文档、选区、连接器结果、索引结果、evidence 和 task-step 是否只散落在聊天中~~ **决议**：`docs/product/v3/w1-artifact-navigator-policy.md` 锁定 visible artifact/content navigator，按 type/task 管理 document / selection / connector-result / knowledge-index-result / evidence-record / task-step，显示 evidence badge，打开动作复用 contentOpeners，详情只读，禁止 fixture 存 raw artifact content；实际 artifact navigator runtime 仍在 runtime gate 下实施期复验。
- ~~Q10：内容审查和排版审查是否只能逐个散落在聊天回复或 DiffReview 面板里~~ **决议**：`docs/product/v3/w1-review-queue-policy.md` 锁定 visible review queue，管理 content-review / formatting-review / task-step 待审项，支持 queued/open/approved/rejected/applied/failed 状态、state/type/surface 过滤、DiffReview 打开和 evidence link；批量 approve/reject 必须显式人审，禁止 batch auto-apply、raw review content fixture 和审批前主文档变更。
- ~~Q11：AI 生成/审查内容的来源、引用和审计轨迹是否只靠聊天上下文记忆~~ **决议**：`docs/product/v3/w1-evidence-inspector-policy.md` 锁定 evidence/citation inspector，覆盖 evidence-record / connector-result / knowledge-index-result / task-step / review-item 来源，显示 citation links 与 audit trail，打开动作复用 contentOpeners，要求 redactsRawPayload=true、hashOnlyReferences=true、requiresEvidenceLink=true，禁止 fixture 存原始 evidence/citation payload、绕过 opener 或审批前主文档变更。
- ~~Q12：AI workspace 是否可以只是聊天 modal，还是需要 Codex-like 原生工作台导航~~ **决议**：`docs/product/v3/w1-interaction-chrome-policy.md` 锁定 sidebar-workbench + segmented-tabs，面板为 chat / tasks / artifacts / reviews / evidence，保留 persistent composer、task/artifact/review/evidence rails、键盘 tab order、Escape focus return、focusTrap=false、compact-utility 密度和 native controls；禁止 modal-only chat、鼠标-only/focus trap、silent failure、raw UI/content fixture 和 runtime-started claim。
- ~~Q13：不同内容类型打开后是否只靠通用 opener，还是需要明确预览矩阵~~ **决议**：`docs/product/v3/w1-content-preview-matrix-policy.md` 锁定 document / selection / connector-result / knowledge-index-result / evidence-record / task-step / review-item 的 preview matrix，覆盖 metadata-summary / read-only-preview / diff-preview / evidence-summary，要求 evidence badge、source metadata、contentOpeners、readOnlyPreview、redactsRawPayload、hashOnlyReferences，禁止 raw/preview payload fixture、静默失败、绕过 opener、审批前主文档变更和 runtime-started claim。
- ~~Q14：Codex-like 工作台里的常用动作是否可以隐藏在聊天内容或鼠标悬停里~~ **决议**：`docs/product/v3/w1-workspace-action-bar-policy.md` 锁定 visible action bar，命令为 open-preview / open-diff-review / approve-selected / reject-selected / copy-reference / export-evidence / filter / sort / retry / cancel，目标覆盖 task-step / review-item / artifact / evidence-record / preview，要求键盘可达、native controls、visible state、evidence link、contentOpeners/DiffReview 复用、批量 apply 显式人审，禁止 auto-apply、hidden/mouse-only actions、静默失败、raw fixture content、审批前主文档变更和 runtime-started claim。
- ~~Q15：任务、artifact、review、evidence、preview 的筛选/搜索是否可以变成隐藏全文索引~~ **决议**：`docs/product/v3/w1-workspace-filter-search-policy.md` 锁定 visible filter/search，只覆盖 tasks / artifacts / reviews / evidence / previews，范围限 current-workspace/current-document，过滤维度为 state / type / surface / source / evidence-status，搜索字段限 id / type / state / source-metadata / evidence-id / hash-reference，要求 metadataOnly、hashOnlyReferences、redactsRawPayload、contentOpeners、evidence link，禁止 raw content indexing、cross-document/global index、静默失败和 runtime-started claim。
- ~~Q16：从搜索、artifact、review、evidence、preview 打开内容后，任务/证据/审查上下文是否会丢失~~ **决议**：`docs/product/v3/w1-workspace-context-handoff-policy.md` 锁定 visible context handoff，入口覆盖 filter-search result / artifact item / review queue item / evidence link / preview item / action-bar command，目标覆盖 preview / DiffReview / evidence inspector / review queue / task progress / composer，保留 active-task-id / source-surface / evidence-id / hash-reference / preview-mode / review-state，要求 breadcrumb、back navigation、focus return、contentOpeners、DiffReview、evidence link，禁止 raw handoff payload、auto-apply、main-document mutation、静默失败和 runtime-started claim。
- ~~Q17：同一条 AI 审查在 review queue、DiffReview、preview、evidence、task progress 和 action bar 里的状态是否可能漂移~~ **决议**：`docs/product/v3/w1-workspace-review-state-sync-policy.md` 锁定 visible review state sync，来源和目标覆盖 review-queue / diff-review / preview-matrix / evidence-inspector / task-progress / action-bar，状态为 queued / open / approved / rejected / applied / failed，事件为 open / approve / reject / apply / fail；要求 evidence link、visible state、DiffReview/contentOpeners 复用、人审和批量 apply 显式人审，禁止 raw payload、auto-apply、main-document mutation、静默失败和 runtime-started claim。
- ~~Q18：AI 工作台里的请求、任务、artifact、打开、审查、证据、动作和失败是否只散落在聊天文本里~~ **决议**：`docs/product/v3/w1-workspace-activity-timeline-policy.md` 锁定 visible activity timeline，事件覆盖 chat-requested / task-started / artifact-created / content-opened / review-opened / review-state-changed / evidence-linked / action-invoked / failure-reported，表面覆盖 chat / tasks / artifacts / reviews / evidence / previews / action-bar，要求 chronological append-only、visible timestamp、visible actor、open target、evidence link、contentOpeners、DiffReview、evidence inspector、metadata-only/hash-only/redaction，禁止 raw payload、preview/transcript fixture content、auto-apply、main-document mutation、静默失败和 runtime-started claim。
- ~~Q19：返回文档或工作台时任务、artifact、review、evidence、preview、review-state、activity cursor 和 failure state 是否可见恢复~~ **决议**：`docs/product/v3/w1-workspace-session-snapshot-policy.md` 锁定 visible session snapshot，范围限 current-workspace/current-document，恢复 active-task-id / open-artifact-id / open-review-id / active-evidence-id / preview-mode / review-state / activity-cursor / failure-state，覆盖 chat / tasks / artifacts / reviews / evidence / previews / activity-timeline，要求 resume summary、explicit resume、visible timestamp、visible document binding、contentOpeners、DiffReview、evidence inspector、activity timeline、metadata-only/hash-only/redaction，禁止 raw payload、preview/transcript fixture content、cross-document restore、cloud sync、auto-apply、main-document mutation、静默失败和 runtime-started claim。
- ~~Q20：需要审批、审查就绪、任务失败、证据缺失或可恢复会话是否会藏在聊天文本里~~ **决议**：`docs/product/v3/w1-workspace-attention-routing-policy.md` 锁定 visible attention routing，触发为 approval-required / review-ready / task-failed / evidence-missing / resume-available，表面为 sidebar-badge / tab-badge / task-row-highlight / review-queue-badge / activity-timeline-event / resume-banner，目标为 task-progress / review-queue / diff-review / evidence-inspector / activity-timeline / session-snapshot，要求 open target、visible reason、visible timestamp、keyboard access、native controls、ActionBar、activity timeline、session snapshot、evidence inspector、DiffReview、metadata-only/hash-only/redaction，禁止 raw payload、cloud push、auto-open、auto-apply、main-document mutation、系统通知 runtime 和 runtime-started claim。
- ~~Q21：AI 工作台样式是否可以退化成松散卡片流、营销页或大聊天弹窗~~ **决议**：`docs/product/v3/w1-workspace-native-style-policy.md` 锁定 native workbench style，layout=sidebar-workbench、density=compact-utility、surfaces=composer / panel-tabs / task-rail / artifact-rail / review-queue / evidence-inspector / preview-matrix / action-bar、navigation=segmented-tabs、usesNativeControls=true、stableDimensions=toolbar-buttons / tab-badges / task-rows / review-rows / evidence-rows / preview-tiles、textOverflowPolicy=wrap-or-ellipsize-no-overlap、keyboardAccessible=true、focusReturn=true；禁止 cardPileLayout、modalOnly、marketingHero、raw/preview/transcript fixture content、auto-apply、main-document mutation 和 runtime-started claim。
- ~~Q22：AI 审查、排版建议和内容建议是否可以只显示结论而没有可打开来源~~ **决议**：`docs/product/v3/w1-workspace-source-provenance-policy.md` 锁定 visible source provenance，sourceTypes 覆盖 document / selection / connector-result / knowledge-index-result / evidence-record / task-step / review-item / formatting-preview / content-suggestion，requiredFields 覆盖 source-id / source-type / citation-id / evidence-id / hash-reference / source-surface / open-target / span-reference / review-id；要求 AI claim、suggestion、formatting change 映射到 evidence-backed source，复用 contentRegistry、contentOpeners、evidenceInspector、reviewQueue 和 DiffReview，禁止 raw/source/preview/transcript fixture content、auto-open、auto-apply、main-document mutation 和 runtime-started claim。

---

## 7. 时间线（保守估算）

- Q3 2027 (8w)：sidebar 注册 + CommandPalette chat fallback route + 接 V2 Provider（无 Markdown 渲染）
- Q4 2027 (4w)：Markdown 渲染 + chat 历史持久化 + apply pipeline 接 V2-W3
- Q4 2027 (4w)：connector 上下文（`@connector` 语法，依赖 W2）

总计：12–16 周。
