# V3-W9: Market-Readiness Spec

Status: **Perf/recovery/onboarding/starter-pack/edition/i18n/manual/distribution/error-recovery/release-GA contracts active** (2026-06-10: H11/H12 target schema/fixture harnesses plus W9 onboarding-flow, starter-pack, edition-policy, i18n-locale, manual-docs, distribution-update, error-recovery-ux, and release-ga-checklist self-tests live; runtime implementation not started)
Goal id: 待启动 (`.agent/goals/v3-w9-market-readiness/` 尚未创建)
Predecessor: V3-W1..W8 全部 v1 完成
Constraint: **铁律 5 — 开发绝对闭环，必须落到 GA，不留 PENDING**

---

## 1. Goal

把 V3 从"功能完整"推到"真正能上市"——
**用户能拿到、能装上、5 分钟内能用上、用得下去、出问题能恢复、能升级、能买单**。

成功画像：
- 任意陌生用户从下载到第一次成功生成 patch < 5 分钟
- App Store / 官网下载页 / 自建分发渠道任一可用
- 个人版免费可装；企业版按"启用 audit"区分
- 首启 < 2s / 首 token < 800ms / 召回 < 200ms 三条性能基线全绿
- 出现崩溃 → 重启后 30s 内恢复未保存内容
- 一年内可平滑升级到下一版本，无需重新配置

**非目标**：
- ❌ 不做付费墙做"假本地"（个人版必须真本地全功能）
- ❌ 不做"企业试用"绕过 audit（audit 是企业版核心卖点）
- ❌ 不做模糊的"AI 加成"营销（必须能演示具体场景）

---

## 2. 关键决策

| 维度 | 选项 | **当前默认** | 验收方式 | 理由 |
|---|---|---|---|---|
| Onboarding 流程 | 0 步 / 3 步 / 5 步 / 10 步 | **5 步** | 新用户首启录屏 ≤ 5min 完成 | 0 步用户迷失；10 步流失高 |
| Edition 区分 | 功能 lock / 用量 lock / audit lock | **audit lock** | 个人版无 audit / 企业版必须 audit | 个人版真本地真免费；企业按治理能力计价 |
| 模板库 | 不做 / starter pack / 全量 | **starter pack（30 模板）** | 覆盖 10 业务场景 × 3 文档型 | 启动门槛；不内卷 WPS 模板库 |
| 性能基线 (P0) | — | **首启<2s / 首token<800ms / 召回<200ms** | H11 perf-baseline harness | 低于此线用户感知"卡" |
| i18n 策略 | UI 中文 / UI 多语 / AI 输出多语 | **UI 跟系统 + AI 输出跟 UI locale** | zh-CN / en-US / ja-JP / zh-TW 首发 | AI 输出语言不能和 UI 错位 |
| 崩溃恢复 | 不做 / 自动保存 / 自动保存+回放 | **自动保存（30s）+ 重启回放** | H12 crash-recovery harness | 办公软件最低线 |
| 自更新 | 不做 / 强制 / 提示 | **提示 + 一键 + W8 self-host server** | 个人版用户机器 / 企业版 LAN | 不强推；不依赖云 |
| 用户手册 | 不做 / PDF / 在线 / 内嵌 | **内嵌 + 在线镜像** | 内嵌 = ?-key 弹出 | 不依赖外链 |
| 错误恢复 UX | 红 toast / 模态 / inline 引导 | **inline 引导 + evidence 可点开** | 任何错误都给"下一步" | 不让用户卡死 |
| 崩溃上报 | sentry.io / 本地 / 不报 | **本地 file-only**（默认）/ **sentry-self-hosted**（可选）| W8 §2 已定 | 默认不出公网 |
| 商业模式 | 订阅 / 永久 / freemium | **freemium（个人免 / 企业 audit 按席位）**| — | 个人传播 + 企业付费 |
| 分发渠道 | App Store / DMG / pkg / docker | **DMG（macOS）+ MSI（Win）+ AppImage（Linux）+ docker（W8）**| 三平台首发 | 覆盖主流办公场景 |

---

## 3. 文件层

### 待创建（**需授权 — 一次性 W9 启动门**）

```
docs/manual/                                # 用户手册（内嵌 + 在线源）
├── index.md                                # 入口
├── quickstart.md                           # 5 分钟上手
├── ai-features.md                          # V3 AI 能力总览
├── connectors.md                           # W2 connector 配置
├── tenant-admin.md                         # W4 企业管理员
├── companion.md                            # W7 移动端
├── localcloud.md                           # W8 自部署
├── troubleshooting.md                      # 常见问题
└── i18n/                                   # 多语言版本

templates/v3-starter-pack/                  # W9 §2 模板库
├── writer/                                 # 10 模板：会议纪要 / OKR / PRD / 周报 / 合同模板...
├── calc/                                   # 10 模板：预算 / 销售看板 / 项目甘特...
└── impress/                                # 10 模板：路演 / 述职 / 项目复盘...

ai/source/onboarding/                       # 5 步 onboarding flow
├── OnboardingController.cxx
├── steps/Step1_Welcome.cxx                 # 介绍三铁律
├── steps/Step2_LocalModel.cxx              # 选 Ollama / 跳过
├── steps/Step3_Connector.cxx               # 可选挂 1 个 connector
├── steps/Step4_Privacy.cxx                 # 三铁律确认（不静默上传）
└── steps/Step5_Demo.cxx                    # 跑一次 sample patch

ai/source/recovery/                         # 崩溃恢复
├── AutoSave.cxx                            # 30s tick
└── RecoveryDialog.cxx                      # 重启回放

tests/v3-perf-baseline-test.sh              # H11 target contract（active）
tests/v3-crash-recovery-test.sh             # H12 target contract（active）
docs/schemas/onboarding-flow.schema.json    # W9 first-run 5-step flow（onboarding-flow self-test active）
docs/qa/fixtures/v3/onboarding-flow/        # valid/invalid first-run flow fixtures
tests/v3-onboarding-flow-test.sh            # W9 onboarding-flow self-test（active）
docs/schemas/starter-pack-manifest.schema.json # W9 30-template starter pack manifest（starter-pack self-test active）
docs/qa/fixtures/v3/starter-pack/           # valid/invalid starter pack manifest fixtures
tests/v3-starter-pack-test.sh               # W9 starter-pack self-test（active）
docs/schemas/edition-policy.schema.json     # W9 freemium + audit-lock policy（edition-policy self-test active）
docs/qa/fixtures/v3/edition-policy/         # valid/invalid edition policy fixtures
tests/v3-edition-policy-test.sh             # W9 edition-policy self-test（active）
docs/schemas/i18n-locale-policy.schema.json # W9 locale + AI output language policy（i18n-locale self-test active）
docs/qa/fixtures/v3/i18n-locale/            # valid/invalid locale policy fixtures
tests/v3-i18n-locale-test.sh                # W9 i18n-locale self-test（active）
docs/schemas/manual-docs-manifest.schema.json # W9 embedded + online mirror manual policy（manual-docs self-test active）
docs/qa/fixtures/v3/manual-docs/            # valid/invalid manual docs manifest fixtures
tests/v3-manual-docs-test.sh                # W9 manual-docs self-test（active）
docs/schemas/distribution-update.schema.json # W9 distribution + update policy（distribution-update self-test active）
docs/qa/fixtures/v3/distribution-update/    # valid/invalid distribution/update fixtures
tests/v3-distribution-update-test.sh        # W9 distribution-update self-test（active）
docs/schemas/error-recovery-ux.schema.json  # W9 recoverable error UX policy（error-recovery-ux self-test active）
docs/qa/fixtures/v3/error-recovery-ux/      # valid/invalid recoverable error UX fixtures
tests/v3-error-recovery-ux-test.sh          # W9 error-recovery-ux self-test（active）
docs/schemas/release-ga-checklist.schema.json # W9 GA blocking checklist（release-ga-checklist self-test active）
docs/qa/fixtures/v3/release-ga-checklist/   # valid/invalid release GA checklist fixtures
tests/v3-release-ga-checklist-test.sh       # W9 release-ga-checklist self-test（active）
bin/v3-perf-baseline.sh                     # H11 runtime samples（待 W9 implementation）
bin/v3-crash-recovery-test.sh               # H12 runtime SIGKILL samples（待 W9 implementation）
```

### 受保护路径不动

- 不动 `kqoffice/source/`、`cui/source/dialogs/commandpalette/`、
  `sw/source/uibase/app/docsh*.cxx`、`officecfg/`、`i18npool/`
  （W9 实施期前需用户授权门）
- Onboarding 复用 V1.5 splash 流程；不另起窗口体系

---

## 4. Harness（H11 / H12 新增）

### H11 perf-baseline
- 当前已 active 的 target-contract layer：`tests/v3-perf-baseline-test.sh` 验证三平台 fixture、首启 2000ms / 首 token 800ms / 召回 200ms、`ollama-local` + `llama3.2:3b`、10k 文档 top-5 local index、以及 GA 阻塞证据字段；baseline = 8 checks
- 冷启动到主窗口可交互：< 2s（macOS arm64 baseline）
- Cmd+Shift+K → 第一个 token：< 800ms（本地 Ollama llama3.2:3b）
- Knowledge index 召回 top-5：< 200ms（10k 文档库）
- 三条任一 FAIL → W9 GA 阻塞

### H12 crash-recovery
- 当前已 active 的 target-contract layer：`tests/v3-crash-recovery-test.sh` 验证三平台 fixture、Writer/Calc/Impress unsaved edit 场景、SIGKILL 触发语义、local-file-only autosave、30s RecoveryDialog、一键恢复、diff=0、零数据丢失和 GA 阻塞 evidence；baseline = 9 checks
- 模拟桌面 app SIGKILL（编辑中、未保存）
- 重启 → 30s 内 RecoveryDialog 弹出 → 一键恢复 → diff = 0
- FAIL 条件：丢字符 / 丢段落 / evidence 链断

集成：`bin/v3-eval-sweep.sh --v3-only` 已运行 H11/H12 target contracts；runtime sample harness waits for the W9 implementation gate.

### W9 onboarding-flow self-test
- 当前已 active 的 contract layer：`tests/v3-onboarding-flow-test.sh` 验证 `docs/schemas/onboarding-flow.schema.json`、3 个 valid fixture、4 个 invalid fixture、5 steps 固定顺序、`maxMinutes=5`、download-to-patch 预算、`noSilentUpload=true`、local-first、显式 cloud opt-in、可跳过本地模型、connector 可选且最多 1 个、demo-patch 必须成功/可 undo/有 evidence；baseline = `Checks: 8`
- 启动桌面 app + OnboardingController（待 W9 implementation）
- 从下载/首次启动到 sample patch 成功 ≤ 5 分钟
- 三平台录屏 + evidence 链完整；失败即 W9 GA 阻塞

集成：`bin/v3-eval-sweep.sh --self-test` 已运行 W9 onboarding-flow self-test；runtime onboarding proof waits for the W9 implementation gate.

### W9 starter-pack self-test
- 当前已 active 的 contract layer：`tests/v3-starter-pack-test.sh` 验证 `docs/schemas/starter-pack-manifest.schema.json`、1 个完整 valid manifest、4 个 invalid guards、`starter-pack-manifest` evidence、30 templates、10 business scenarios、Writer/Calc/Impress 各 10 个、每个模板绑定 surface 对应 action kind、sample patch 必须成功/可 undo/有 evidence、模板包内嵌默认、不要求网络、W8 self-host compatible；baseline = `Checks: 8`
- 创建真实 `templates/v3-starter-pack/` 资产（待 W9 implementation）
- 每个模板 ≥ 1 次成功 patch，三平台安装后可见可用
- 任一模板缺失、surface 计数漂移、patch smoke 失败或需要公网 → W9 GA 阻塞

集成：`bin/v3-eval-sweep.sh --self-test` 已运行 W9 starter-pack self-test；runtime template assets and installer wiring wait for the W9 implementation gate.

### W9 edition-policy self-test
- 当前已 active 的 contract layer：`tests/v3-edition-policy-test.sh` 验证 `docs/schemas/edition-policy.schema.json`、1 个 valid policy、4 个 invalid guards、`edition-policy` evidence、freemium、个人免费 ¥0、个人专业 ¥39/月、企业 ¥199/席位/月、企业自部署 ¥9999 起、audit lock、个人版全功能本地、限制只放在规模 + audit、不允许功能阉割、不允许企业 trial 绕过 audit、不要求公网；baseline = `Checks: 8`
- Edition 切换 UI、entitlement runtime、billing/export（待 W9 implementation）
- 三平台 edition 切换跑通；个人版真本地真免费，企业版 audit 必开
- 任一版本功能阉割、企业 audit 可绕过、默认公网依赖或价格/规模基线漂移 → W9 GA 阻塞

集成：`bin/v3-eval-sweep.sh --self-test` 已运行 W9 edition-policy self-test；runtime edition switching waits for the W9 implementation gate.

### W9 i18n-locale self-test
- 当前已 active 的 contract layer：`tests/v3-i18n-locale-test.sh` 验证 `docs/schemas/i18n-locale-policy.schema.json`、4 个 valid locale fixture、4 个 invalid guards、`i18n-locale-policy` evidence、首发 `zh-CN / en-US / ja-JP / zh-TW`、UI 跟 OS locale、AI 输出默认跟 UI locale、显式 `/lang` override、不静默切换、不静默持久化、用户手册 zh-CN/en-US 基线、runtime implementation 仍 gated；baseline = `Checks: 8`
- Locale runtime、chat `/lang` parser、AI output language propagation、evidence writer（待 W9 implementation）
- 任一 locale 首发缺失、AI 输出语言与 UI 错位、静默切换/持久化、缺少 evidence 或绕过 i18npool → W9 GA 阻塞

集成：`bin/v3-eval-sweep.sh --self-test` 已运行 W9 i18n-locale self-test；runtime locale plumbing waits for the W9 implementation gate.

### W9 manual-docs self-test
- 当前已 active 的 contract layer：`tests/v3-manual-docs-test.sh` 验证 `docs/schemas/manual-docs-manifest.schema.json`、1 个 valid manual manifest、4 个 invalid guards、`manual-docs-manifest` evidence、embedded + online mirror、`?` help key、Help menu entry、offline readable、zh-CN / en-US 必备手册基线、zh-CN / en-US / ja-JP / zh-TW launch locale roster、8 个手册主题（index/quickstart/ai-features/connectors/tenant-admin/companion/localcloud/troubleshooting）、不要求公网、W8 self-host/release bundle 更新路径、runtime implementation 仍 gated；baseline = `Checks: 8`
- 创建真实 `docs/manual/` 内容、Help viewer wiring、online mirror sync（待 W9 implementation）
- 任一必备主题缺失、zh-CN/en-US 手册缺失、嵌入 Help 入口缺失、需要公网才能阅读或缺少 evidence → W9 GA 阻塞

集成：`bin/v3-eval-sweep.sh --self-test` 已运行 W9 manual-docs self-test；runtime manual content and Help UI waits for the W9 implementation gate.

### W9 distribution-update self-test
- 当前已 active 的 contract layer：`tests/v3-distribution-update-test.sh` 验证 `docs/schemas/distribution-update.schema.json`、1 个 valid distribution/update manifest、4 个 invalid guards、`distribution-update-policy` evidence、DMG / MSI / AppImage / docker 四渠道首发、artifact signing/checksum/notarization、download-to-first-patch ≤ 5min、installer smoke required、prompt + one-click update、可延后、不强制更新、W8 self-host update server、LAN 支持、不要求公网、rollback proof、runtime implementation 仍 gated；baseline = `Checks: 8`
- 真实 installer packaging、自更新 server/client、rollback proof、三平台下载到首 patch（待 W9 implementation）
- 任一首发渠道缺失、强制更新、需要公网、缺少 rollback/evidence 或下载到首 patch 超 5 分钟 → W9 GA 阻塞

集成：`bin/v3-eval-sweep.sh --self-test` 已运行 W9 distribution-update self-test；runtime packaging and update plumbing wait for the W9 implementation gate.

### W9 error-recovery-ux self-test
- 当前已 active 的 contract layer：`tests/v3-error-recovery-ux-test.sh` 验证 `docs/schemas/error-recovery-ux.schema.json`、1 个 valid recoverable error UX manifest、4 个 invalid guards、`error-recovery-ux` evidence、provider timeout / connector auth expired / policy denied / patch apply failed 四类错误、Writer/Calc/Impress/Companion surface 覆盖、inline guidance、至少两个 next steps、openable evidence、diagnostics export、主文档 apply 前不变、可 retry/rollback、runtime implementation 仍 gated；baseline = `Checks: 8`
- 真实 inline guidance UI、evidence viewer、diagnostics export、retry/rollback recovery action wiring（待 W9 implementation）
- 任一错误只有 toast、无下一步、evidence 不可点开、diagnostics 不可导出、主文档在用户确认前被改动或缺少人类可读 cause → W9 GA 阻塞

集成：`bin/v3-eval-sweep.sh --self-test` 已运行 W9 error-recovery-ux self-test；runtime recovery UX waits for the W9 implementation gate.

### W9 release-ga-checklist self-test
- 当前已 active 的 contract layer：`tests/v3-release-ga-checklist-test.sh` 验证 `docs/schemas/release-ga-checklist.schema.json`、1 个 valid GA checklist manifest、4 个 invalid guards、`release-ga-checklist` evidence、V2 regression、H8/H9/H10/H11/H12、W9 onboarding/starter-pack/edition/i18n/manual/distribution/error-recovery gates、source archive、Windows toast、release policy decisions、human approval、signoff evidence、`canShip=false`、runtime implementation 仍 gated；baseline = `Checks: 8`
- 真实 release signoff、artifact publication、source archive final commit split、Windows toast proof、D5/D8/B3 release-policy decisions（待 V2 GA / W9 implementation / user authorization）
- 任一 GA gate 缺失、自动批准发布、缺少 human approval、`canShip=true`、runtime 已启动但未授权、或缺少 release signoff evidence → W9 GA 阻塞

集成：`bin/v3-eval-sweep.sh --self-test` 已运行 W9 release-ga-checklist self-test；runtime release execution waits for V2 GA and the W9 implementation gate.

---

## 5. 业务化（Edition 切换实现细节）

| Edition | 价格 | Audit | Connector 上限 | Knowledge Index 上限 | Agent 并发 |
|---|---|---|---|---|---|
| 个人免费 | ¥0 | ❌ | 5 | 10k 文档 | 1 |
| 个人专业 | ¥39/月 | ❌ | 20 | 50k 文档 | 3 |
| 企业 | ¥199/席位/月 | ✅ | 不限 | 不限 | 不限 |
| 企业 (自部署 W8) | 一次性 ¥9999 起 + ¥99/席位 | ✅ | 不限 | 不限 | 不限 |

**关键约束**：
- 个人版**真本地真免费**，不阉割 AI 能力
- 限制只放在"规模 + audit"，不放在"功能"
- 企业自部署 = W8 docker-compose 一键起

---

## 6. i18n / AI 输出语言

- UI 语言跟随 OS locale（i18npool 现有机制不动）
- AI 输出语言**默认跟 UI locale**：
  - UI = zh-CN → 输出中文
  - UI = en-US → 输出英文
  - UI = ja-JP → 输出日文
- 用户可在 chat 内 inline override：`/lang en` 强制英文
- 三铁律：不静默切换；切换需显式指令；输出语言写入 evidence

首发覆盖：zh-CN / en-US / ja-JP / zh-TW（4 语）。

---

## 7. 启动门 / 退出门

**启动门（用户授权 1 次）**：
- 创建 `docs/manual/`、`templates/v3-starter-pack/`、`ai/source/onboarding/`、`ai/source/recovery/`
- W1–W8 已 v1 完成（W9 不能跨过任何前序）

**退出门（GA 前必须全绿）**：
- H11 / H12 三平台全绿
- 5 步 onboarding 路径在三平台跑通
- 30 模板可装可用（每个模板 ≥ 1 次成功 patch）
- 用户手册 zh-CN / en-US 双语完成
- W8 docker-compose 在干净 macOS / Linux / Windows 各起一次
- Edition 切换在三平台跑通
- App Store / DMG / MSI / AppImage 任一渠道下载到首启 patch < 5min（端到端）
- 崩溃恢复在 100 次随机 SIGKILL 下成功率 > 99%

---

## 8. Open Questions

- Q1: 30 模板从 0 起还是 fork LibreOffice 模板库改？（默认 fork + 重设计）
- Q2: 个人专业版是否做？（当前默认做，可在 GA 前砍）
- Q3: 自更新 differential patch 算法（bsdiff / Courgette / 自研）？（默认 bsdiff，足够小）
- Q4: 模板库分发是内嵌还是首启拉？（默认内嵌 starter pack；后续模板按需拉）
- Q5: 崩溃上报 sentry-self-hosted 是 W8 §2 范围还是 W9 范围？（默认 W8，W9 只配 UI 开关）

---

## 9. 与 V3 master 关系

W9 在 master plan §2 拓扑图中作为**收口层**，依赖 W1–W8 全部 v1：
- 没 W1 → 无核心场景可演示
- 没 W2 → connector 卖点空
- 没 W3 → 召回基线无意义
- 没 W4 → 企业版无差异化
- 没 W5 → 性能基线无 harness
- 没 W6 → 长任务卖点空
- 没 W7 → 移动端审批卖点空
- 没 W8 → "全本地"卖点空 / 自更新无 self-host server

W9 退出门 = V3 GA。
