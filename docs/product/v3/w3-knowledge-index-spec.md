# V3-W3: Knowledge Index Spec

Status: **knowledge-index chunk/query/result self-tests active** (2026-06-11: schema/fixture contracts live; model acquisition, vector-store, watcher scalability, extraction, and storage policies locked; runtime implementation not started)
Goal id: 待启动 (`.agent/goals/v3-w3-knowledge-index/` 尚未创建)
Predecessor: V2-W3 Document Snapshot + V3-W1 Chat + V3-W2 Connector

---

## 1. Goal

把"上下文召回"从 ad-hoc grep 升级为可索引、可更新、可审计的知识库。

成功画像：
- 用户写文档时 → 后台增量索引 → Chat 内 `@kb 之前关于 X 的讨论` 直接召回
- 企业用户挂私有向量库 → 走 W2 connector → 同 API 召回
- 索引**默认在本地**，永不向云上传原文；embedding 模型也本地

---

## 2. 关键决策

| 决策点 | 选项 | 当前默认 | 理由 |
|---|---|---|---|
| 后端 | SQLite FTS5 / lancedb / qdrant local / chromadb | **SQLite FTS5 默认 + lancedb-local opt-in** | FTS5 零依赖；lancedb 在 macOS arm64 先保持 pending-runtime-spike |
| 索引粒度 | 文档级 / 段落级 / 句子级 | **段落级 + 句子级 fallback** | 平衡召回质量与索引大小 |
| 触发更新 | 实时 / 文件保存时 / 后台 watcher | **后台 watcher（debounce 5s）+ bounded fallback** | 不阻塞编辑；>10k 文件工作区禁止 per-file fd watch，走 bounded watcher + polling fallback |
| Embedding 模型 | OpenAI / 本地 BGE / 本地 jina | **本地 BGE-m3** | 不出域；多语支持好 |
| 向量维度 | 384 / 768 / 1024 | **1024（BGE-m3）** | 与模型匹配；存储成本可接受 |
| 模型获取 | 安装包内带 / 首次启动静默下载 / 用户确认下载 | **不默认打包；hybrid/vector 需用户显式确认下载；缺模型回退 SQLite FTS5** | BGE-m3 体积大；避免隐式网络和安装包膨胀 |
| PPT/PPTX 文本抽取 | LibreOffice import + document model / standalone PPT parser | **LibreOffice import filter + Impress document model；禁止 standalone PPT parser** | 与用户看到的导入结果一致，保留 slide element refs，避免双路径解析漂移 |
| 索引文件位置 | 用户文档目录 / 应用数据目录 / 远端缓存 | **application data directory + per-workspace sidecar** | 避免污染文档目录和被文档同步工具带出域；workspace-hash 避免原始路径泄露 |
| 索引共享 | per-doc / per-workspace / 全局 | **per-workspace** | 跨文档召回是核心价值；隔离粒度合理 |
| 检索 API 形态 | 同步 / 异步 / 流式 | **同步（topK<=10 时）+ 异步（>10）** | UX 简单 |

---

## 3. 文件层

### 待创建（**需授权**）

```
ai/source/knowledge/IndexManager.cxx          # 索引调度
ai/source/knowledge/FtsBackend.cxx             # SQLite FTS5
ai/source/knowledge/VectorBackend.cxx          # lancedb (opt-in)
ai/source/knowledge/Chunker.cxx                # 段落级分块
ai/source/knowledge/EmbeddingPipeline.cxx      # BGE-m3 调用
ai/source/knowledge/Watcher.cxx                # 文件系统 watcher
officecfg/registry/data/org/openoffice/Office/KnowledgeIndex.xcu  # 配置
```

### Schema（新增，**进 V3 schema 锁**）

```
docs/schemas/knowledge-index-chunk.schema.json   # chunk 结构（active contract）
docs/schemas/knowledge-index-query.schema.json   # 查询请求（active contract）
docs/schemas/knowledge-index-result.schema.json  # 召回结果（active contract）
```

### 待创建（纯 docs）

```
docs/product/v3/w3-knowledge-index-spec.md    # 本文档
docs/product/v3/w3-vector-backend-survey.md   # 后端选型理由
docs/product/v3/w3-embedding-model-survey.md  # 模型选型理由
docs/product/v3/w3-model-acquisition-policy.md # BGE-m3 获取/回退策略（active contract）
docs/product/v3/w3-vector-store-policy.md # vector-store policy；lancedb opt-in / sqlite fallback 策略（active contract）
docs/product/v3/w3-watcher-scalability-policy.md # watcher scalability policy；>10k 文件 / fd 上限策略（active contract）
docs/product/v3/w3-extraction-policy.md # PPTX extraction policy；LibreOffice import + Impress document model（active contract）
docs/product/v3/w3-storage-policy.md # index storage policy；app data per-workspace sidecar（active contract）
```

---

## 4. 与 V2 / V3-W1/W2 衔接

| 资产 | 在 W3 中的角色 |
|---|---|
| V2 document-snapshot schema | Index 增量基于 snapshot diff |
| V3-W1 Chat | `@kb` 语法走 W3 query API |
| V3-W2 Connector | 远端向量库挂载走 W2；本地默认不需要 |
| V2 service-mode | offline 模式：仅本地 FTS + 本地 embedding；private/cloud 模式：可挂远端 |

**Schema 塌缩防护**：

- `knowledge-index-chunk` ≠ `document-snapshot`（snapshot 是文档全状态；chunk 是检索单元）
- `knowledge-index-result` ≠ V2 任何 schema（独立锁）

---

## 5. 检索 API 草稿

```idl
module com { module kqoffice { module ai {

interface XKnowledgeIndex {
    // 同步检索（topK <= 10）
    sequence<KnowledgeChunk> query([in] string queryText, [in] short topK);

    // 异步检索（topK > 10 或 includeMetadata=true）
    string queryAsync([in] string queryText, [in] QueryOptions options);

    // 增量更新（外部触发）
    void reindex([in] string filePath);

    // 索引统计
    IndexStats getStats();
};

}; }; };
```

Namespace 锁：`com.kqoffice.ai.KnowledgeIndex`（V3 新增；不与 V2 namespace 冲突）。

---

## 6. 验证

### 单测（待写）

```
CppunitTest_ai_knowledge_chunker
CppunitTest_ai_knowledge_fts_backend
CppunitTest_ai_knowledge_vector_backend
CppunitTest_ai_knowledge_watcher_debounce
CppunitTest_ai_knowledge_embedding_pipeline
CppunitTest_ai_knowledge_query_api
```

### Fixture（knowledge-index-chunk active）

- `docs/qa/fixtures/v3/knowledge-index-chunk/valid/writer-paragraph-fts.json`
- `docs/qa/fixtures/v3/knowledge-index-chunk/valid/calc-sentence-fallback-fts.json`
- `docs/qa/fixtures/v3/knowledge-index-chunk/valid/connector-hybrid-private.json`
- `docs/qa/fixtures/v3/knowledge-index-chunk/valid/impress-pptx-slide-fts.json`
- `docs/qa/fixtures/v3/knowledge-index-chunk/invalid/stores-document-content.json`
- `docs/qa/fixtures/v3/knowledge-index-chunk/invalid/public-egress-cloud.json`
- `docs/qa/fixtures/v3/knowledge-index-chunk/invalid/embedding-dimension-drift.json`
- `docs/qa/fixtures/v3/knowledge-index-chunk/invalid/model-acquisition-silent-download.json`
- `docs/qa/fixtures/v3/knowledge-index-chunk/invalid/vector-store-lancedb-default-runtime.json`
- `docs/qa/fixtures/v3/knowledge-index-chunk/invalid/watcher-per-file-fd-runtime.json`
- `docs/qa/fixtures/v3/knowledge-index-chunk/invalid/ppt-standalone-parser-runtime.json`
- `docs/qa/fixtures/v3/knowledge-index-chunk/invalid/storage-user-documents-sync-runtime.json`

### Contract self-test（active）

`tests/v3-knowledge-index-chunk-test.sh` is the W3 knowledge-index-chunk self-test. It validates `docs/schemas/knowledge-index-chunk.schema.json`, `docs/product/v3/w3-model-acquisition-policy.md`, `docs/product/v3/w3-vector-store-policy.md`, `docs/product/v3/w3-watcher-scalability-policy.md`, `docs/product/v3/w3-extraction-policy.md`, `docs/product/v3/w3-storage-policy.md`, the 4 valid / 8 invalid fixture roster, paragraph + sentence-fallback granularity, document + connector sources, Writer/Calc/Impress/connector extraction families, `per-workspace` scope, local-only `BGE-m3` 1024-dimension hybrid retrieval, `modelAcquisitionPolicy`, `vectorStorePolicy`, `watcherPolicy`, `extractionPolicy`, `storagePolicy`, explicit user confirmation before model download, SQLite FTS5 fallback when BGE-m3 or lancedb-local is missing/unproven, `sqlite-fts5` as the default backend, lancedb-local opt-in with macOS arm64 `pending-runtime-spike`, 5s watcher debounce, bounded watcher + polling fallback for workspaces above 10k files, PPTX extraction through the LibreOffice import filter and Impress document model, standalone PPT parser forbidden, app-data-directory per-workspace index sidecar storage, no user-document sync, `storesDocumentContent=false`, no raw document content fields, no public egress, and V2 document-snapshot separation. It reports `Checks: 12` and is wired into `bin/v3-eval-sweep.sh --self-test`.

`tests/v3-knowledge-index-query-result-test.sh` is the W3 knowledge-index-query-result self-test. It validates `docs/schemas/knowledge-index-query.schema.json`, `docs/schemas/knowledge-index-result.schema.json`, paired fixtures under `docs/qa/fixtures/v3/knowledge-index-query-result/`, `topK<=10`, query/result linkage, workspace parity, `storesQueryText=false`, hash-only result snippets via `snippetHash`, no raw query/snippet/document content fields, no public egress, and local FTS/hybrid retrieval. It reports `Checks: 8` and is wired into `bin/v3-eval-sweep.sh --self-test`.

### 性能基线（待定）

- 索引 1k 文档 / 平均 5 段/文档 → < 30s
- 查询 topK=10 → < 200ms（FTS）/ < 500ms（FTS+vector rerank）

### 回归

- V1.5 27/27 ✅
- V2 H1-H7 ✅
- offline 模式不引入网络调用（H8 同检测）

---

## 7. Open Questions / Blockers

- ~~Q1：BGE-m3 模型 ~2GB，下载策略？（首次启动下载 / 安装包内带）~~ **决议（W3 Q1）**：BGE-m3 不默认打包、不静默下载；hybrid/vector 检索必须先经用户显式确认下载；离线、未下载或拒绝下载时回退 SQLite FTS5；默认无 public egress；runtime downloader / embedding pipeline 仍为 `not-started`。
- ~~Q2：lancedb 在 macOS arm64 是否稳定？需要 spike~~ **决议（W3 Q2）**：`sqlite-fts5` 保持默认后端；`lancedb-local` 只允许 opt-in hybrid/vector chunk，macOS arm64 状态为 `pending-runtime-spike`，升默认前必须有平台 smoke；缺失/未验证时回退 SQLite FTS5；runtime vector-store implementation 仍为 `not-started`，详见 `docs/product/v3/w3-vector-store-policy.md`。
- ~~Q3：watcher 在大型仓库（>10k 文件）是否会爆 fd / inode？~~ **决议（W3 Q3）**：后台 watcher 保持 5s debounce，但禁止 per-file descriptor watch；>10k 文件工作区必须使用 bounded watcher + polling fallback，fd 上限锁为 256，overflow 必须 `fail-closed-user-visible`，runtime watcher implementation 仍为 `not-started`，详见 `docs/product/v3/w3-watcher-scalability-policy.md`。
- ~~Q4：用户改 PPT 文件，如何提取文本（走 V2 oox 还是单独路径）？~~ **决议（W3 Q4）**：PPT/PPTX 文本抽取走 LibreOffice import filter 后的 Impress document model，`standalonePptParserAllowed=false`，PPTX fixture 必须保留 slide element refs；runtime extraction implementation 仍为 `not-started`，详见 `docs/product/v3/w3-extraction-policy.md`。
- ~~Q5：索引文件位置（用户文档目录 vs 应用数据目录）~~ **决议（W3 Q5）**：索引文件放 application data directory 下的 per-workspace sidecar，路径身份用 `workspace-hash`，不得与用户文档同目录、不得跟随用户文档同步、不得存原文；runtime storage implementation 仍为 `not-started`，详见 `docs/product/v3/w3-storage-policy.md`。

---

## 8. 时间线（保守估算）

- Q4 2027 (4w)：FTS5 backend + Chunker + 静态索引（无 watcher）
- Q1 2028 (4w)：Watcher + 增量更新 + 检索 API
- Q1 2028 (3w)：Embedding pipeline + lancedb opt-in
- Q1 2028 (3w)：与 W1 Chat 集成 + `@kb` 语法

总计：10–14 周。
