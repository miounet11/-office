# V2 W3 Spec: Writer Apply Runtime

Date: 2026-05-08
Wave: W3
Depends on: W1 (provider runtime)
Master plan: `../v2-master-plan.md`

## Scope

V1.5 已就位的 `IntelligentWriterAnalyzer`（preview-only contract）升级为
**apply runtime**——能基于 ApplyPlan schema 把 AI 给出的诊断/改进建议
**真实写回 Writer 文档**，且每个 patch 独立可撤销，全程留 evidence。

## In Scope

1. `SwDocShell::applyDiagnosticsPlan(const ApplyPlan&) → ApplyResult`
2. 段落级 patch 应用（增 / 删 / 替换 / 格式化）
3. 每个 patch 独立 SwUndoAction（标准 Cmd+Z 可逐项撤销）
4. evidence 记录：前后 hash + 影响段落 ID + 时间戳
5. 失败隔离：任一 patch fail → 整个 Plan rollback
6. preview→apply 闭环：从 V1.5 preview 数据无缝衔接

## Out of Scope

- 不实现 Calc / Impress 版本（W3.5 / W4 范畴）
- 不实现 AI 推理（W1 已做）
- 不实现 UI 浮窗（W4 范畴）
- 不实现 cross-document apply（仅当前 SwDocShell）

## 复用既有契约

| 契约 | 路径 | 用途 |
|---|---|---|
| ApplyPlan | `docs/schemas/apply-plan.schema.json` | 输入格式 |
| IntelligentDiagnostic | `docs/schemas/intelligent-diagnostic.schema.json` | 来源 |
| EvidenceRecord | `docs/schemas/evidence-record.schema.json` | 输出审计 |
| DocumentSnapshot | `docs/schemas/document-snapshot.schema.json` | 前后状态 hash |
| Writer Apply Guardrail | `docs/architecture/engine-capability-writer-apply-guardrail-m3-04.md` | 设计约束 |

## File Map

| 路径 | 类型 | 内容 |
|---|---|---|
| `sw/inc/IntelligentWriterApplyEngine.hxx` | new | apply 引擎接口 |
| `sw/source/core/doc/IntelligentWriterApplyEngine.cxx` | new | 实现 |
| `sw/source/core/undo/UndoApplyPatch.cxx` | new | 单 patch undo |
| `sw/source/core/undo/UndoApplyPatch.hxx` | new | header |
| `sw/inc/IntelligentWriterAnalyzer.hxx` | modify | 加 `runApply(plan)` 方法 |
| `sw/source/core/doc/IntelligentWriterAnalyzer.cxx` | modify | preview→apply 桥接 |
| `sw/inc/docsh.hxx` | modify | 加 `applyDiagnosticsPlan()` |
| `sw/source/uibase/app/docsh.cxx` | modify | 实现 |
| `sw/qa/core/test_apply_engine.cxx` | new | 单测 |
| `sw/Library_sw.mk` | modify | gbuild |
| `docs/schemas/fixtures/apply-plan.valid.writer-runtime.json` | new | runtime fixture |

## ApplyPlan 输入示例

```json
{
  "schema_version": "1.0",
  "plan_id": "ap-20260508-001",
  "source_diagnostic_id": "diag-20260508-007",
  "doc_snapshot_hash": "sha256:abc...",
  "patches": [
    {
      "patch_id": "p1",
      "kind": "paragraph-replace",
      "target": {"paragraph_id": "swpara-42", "text_hash": "sha256:..."},
      "before": "本段表述太啰嗦，重复说了好几遍。",
      "after": "本段表述简洁，无重复。",
      "rationale": "去除冗余",
      "severity": "minor"
    },
    {
      "patch_id": "p2",
      "kind": "paragraph-format",
      "target": {"paragraph_id": "swpara-43"},
      "format_changes": {"style": "Heading 2"},
      "rationale": "层级结构",
      "severity": "minor"
    }
  ],
  "preview_only": false
}
```

## Apply Pipeline

```
SwDocShell::applyDiagnosticsPlan(plan)
  │
  ├── 1. validate(plan): schema OK + doc_snapshot_hash matches current doc
  │       └─ fail → return ApplyResult{status="stale-snapshot"}
  │
  ├── 2. SfxUndoManager::EnterListAction("Apply AI Plan ap-20260508-001")
  │
  ├── 3. for each patch in plan.patches:
  │       ├── try patch.apply() → SwUndoAction (registered)
  │       ├── on fail: SfxUndoManager::Undo()  // rollback all so far
  │       │            LeaveListAction()
  │       │            return ApplyResult{status="patch-failed", failed_patch=patch_id}
  │       └── continue
  │
  ├── 4. SfxUndoManager::LeaveListAction()  // 整个 Plan 现在是单个 undo entry
  │
  ├── 5. EvidenceRecorder.write(plan_id, before_hash, after_hash, patches[])
  │
  └── 6. return ApplyResult{
            status: "ok",
            applied_count: N,
            evidence_id: "ev-...",
            after_snapshot: hash
          }
```

## Patch Kinds（v1）

| kind | 描述 | 实现 |
|---|---|---|
| `paragraph-replace` | 整段文字替换 | `SwTextNode::SetText()` + Undo |
| `paragraph-insert-after` | 在段落后插新段 | `SwDoc::AppendTextNode()` |
| `paragraph-delete` | 删除段落 | `SwDoc::DelFullPara()` |
| `paragraph-format` | 改段落样式（标题/正文） | `SwDoc::SetTxtFmtColl()` |
| `paragraph-reformat` | 改段落属性（缩进/间距） | `SwParaFormatProperty` set |
| `text-range-replace` | 段落内 range 替换 | `SwPaM` + `SwDoc::ReplaceRange()` |
| `text-format` | 段落内 range 格式（粗/斜/下划线） | `SwDoc::SetFormat()` |

W3 不实现：
- table-cell 操作（W3.5）
- inline 对象（图/图表/批注）（W3.5）
- 跨段落 range（W3.5）

## Undo Strategy

每个 patch 包一个 `SwUndoApplyPatch` (extends `SwUndo`)：

- 持有 patch_id + 影响段落的 SwNodeIndex + before/after snapshot
- `Undo()`：恢复 before 状态（SwTextNode::SetText 或 reset format attr）
- `Redo()`：重新应用 after

整个 Plan 包在一个 `EnterListAction("Apply AI Plan {plan_id}")` 里 — 标准 Cmd+Z 撤一个 entry 撤掉整个 Plan；用户也可在 Edit → Undo Stack 中看到逐 patch 项。

## Failure Modes

| 情况 | 行为 |
|---|---|
| Plan schema invalid | 立即 reject，return `validation-failed` |
| `doc_snapshot_hash` 不匹配（用户期间改了文档） | reject，return `stale-snapshot`；caller 需重新生成 plan |
| 第 K 个 patch 应用 fail（如目标段落已被删） | rollback 前 K-1 个，return `patch-failed`，evidence 记 K 个 patch 状态 |
| Undo manager 异常 | 整 Plan 视为 fail；引擎 throw RuntimeException（caller 知道文档可能不一致） |

## Idempotency

每个 patch 应用前 check `target.text_hash` (paragraph 当前内容 hash)：

- 与 `before` hash 一致 → 应用
- 与 `after` hash 一致 → skip（已应用过，幂等）
- 都不一致 → fail（外部修改）

## Evidence 内容

```json
{
  "evidence_id": "ev-w3-...",
  "plan_id": "ap-...",
  "timestamp": "...",
  "doc_uri": "file:///path/to/doc.odt",
  "before_snapshot": "sha256:...",
  "after_snapshot": "sha256:...",
  "applied_patches": [
    {"patch_id": "p1", "status": "ok", "before_hash": "...", "after_hash": "..."},
    {"patch_id": "p2", "status": "skipped-idempotent"}
  ],
  "rolled_back": false,
  "user_decision": "auto-apply"  // or "user-approved"
}
```

## Test Strategy

1. **Unit (`CppunitTest_sw_apply_engine`)**：
   - 单 paragraph-replace 应用 + undo + redo
   - 多 patch sequential apply
   - mid-failure rollback
   - stale-snapshot detect
   - idempotent skip
2. **Contract (`docs/schemas/fixtures/apply-plan.valid.writer-runtime.json`)**：
   - 加入 `bin/intelligent-contract-fixtures.sh` 自检
3. **Integration**：
   - 走 W1 provider → 拿 LLM 生成的 ApplyPlan → 应用 → 验证 doc 状态
4. **Regression**：
   - 27/27 兼容性 roundtrip 不退化
   - V1.5 IntelligentWriterAnalyzer preview-only 测试不退化

## Performance Budget

- Plan validation：< 50ms
- Single patch apply：< 100ms（中等段落）
- Plan with 10 patches：< 1s 总
- Undo：< 200ms

## ROI Estimate

- 实施：4-6 周（包括 undo 集成 + evidence + 测试）
- 用户感知：从"AI 给建议但要手抄"→"AI 一键应用"
- 风险：高（动文档；undo 错误会丢用户内容）

## Stop Conditions

1. SwUndoAction subclass 与 SwTextNode 替换流不兼容 → 改用 `SwDoc::ReplaceText` API
2. paragraph_id 在 LO 内不稳定（增删段落后 ID 变化） → 改用 SwNodeIndex + text_hash
3. EvidenceRecorder 阻塞主线程 → 改为 async queue（与 W1 一致）

## Schema reader's manual

The W3 runtime ApplyPlan envelope schema body lives at
`docs/schemas/apply-plan-runtime.schema.json`. A 9-section
human-derivation guide explaining *why* each envelope key exists,
*why* `patches[]` items are intentionally schema-open (per-kind
payload validation deferred to each `SwUndoApplyPatch` impl + C++
`ApplyPlanValidator` 14-token enum), and what's locked vs deferred
(cross-patch ordering, total-change size cap, per-patch evidence
back-pointer) lives at `docs/schemas/apply-plan-runtime.schema.md`.
Read the manual before hand-writing a new `SwUndoApplyPatch`
subclass or a diagnostic-pass Plan generator — it captures the
envelope/per-kind layering rationale that isn't recoverable from
the schema body alone.

Token-lock anchor: this spec's §"Patch Kinds（v1）" table (above)
is the single source of truth the schema's 7-token `kind` enum
mirrors, and the C++ ApplyPlanValidator's 14-token
`ValidationCode` enum branches against. Drift is caught by H2
(`tests/v2-plan-baseline-test.sh`) at fixture-validation level
plus the H1 schema↔C++ runtime-token subset check.

## Dependencies

- W1：provider runtime 必须就位（ApplyPlan 来源）
- 现有：`IntelligentWriterAnalyzer` preview 数据结构（V1.5）
- 现有：`apply-plan.schema.json` (V1.5)

## Acceptance Criteria

- [ ] `CppunitTest_sw_apply_engine` pass（≥ 12 case）
- [ ] Apply → Undo → Redo 三轮文档 hash 一致
- [ ] 10-patch Plan 应用 < 1s
- [ ] mid-failure rollback 后文档与 before 一致
- [ ] evidence 文件按 schema 写出
- [ ] 27/27 兼容性测试不退化
- [ ] V1.5 IntelligentWriterAnalyzer test 仍 pass
