# 可圈office World-Class Quality Roadmap

This document turns the `autoresearch` loop into a product-quality operating model for 可圈office.

The core rule is simple:

1. choose one real bottleneck
2. make one bounded change
3. verify it under a fixed budget
4. keep or reject it based on measurable outcome
5. queue the next round from observed gaps, not opinion

For an office suite, this loop must optimize product quality, not only model loss or visual polish.

## Product objective

Build 可圈office into a world-class office suite that leads on:

- compatibility
- stability
- interaction logic
- reliability

The suite should feel premium and calm, but the deeper goal is trust: users must be able to open, edit, save, export, print, review, and recover important documents with confidence.

## Why the autoresearch loop fits this repo

`karpathy/autoresearch` is valuable here because it enforces a repeatable loop with a fixed evaluation budget and a clear accept/reject decision.

Applied to 可圈office, that means:

- do not ship vague improvement rounds
- do not mix many unrelated product bets in one pass
- do not accept changes on aesthetics alone
- do not treat one successful manual check as sufficient proof

Each round must improve one visible workflow or one measurable quality lane.

## Quality lanes

### 1. Compatibility

Primary concern: users exchange files with Microsoft Office and WPS users every day.

North-star metrics:

- DOCX round-trip damage rate
- XLSX formula/chart fidelity score
- PPTX layout/theme fidelity score
- comment and tracked-change parity score
- PDF export correctness rate

Guardrails:

- no new import crashes
- no new severe layout regressions in golden files
- no new export blockers on common formats

### 2. Stability

Primary concern: the app should be hard to crash in normal work.

North-star metrics:

- crash-free editing session rate
- repeated open/save/export pass rate
- long-session stability pass rate
- startup success rate

Guardrails:

- no new startup regressions
- no new crash signatures in top workflows
- no new resource leak spikes in repeated loops

### 3. Interaction logic

Primary concern: users should complete common tasks quickly without learning upstream LibreOffice structure first.

North-star metrics:

- time to first useful task completion
- clicks from launch to common-task start
- cross-module command consistency score
- first-run task-entry success rate

Guardrails:

- no increase in confusion on core task entry
- no new fragmentation across Writer/Calc/Impress command models
- no regression in discoverability for common actions

### 4. Reliability

Primary concern: the suite must produce trustworthy results, not only stay open.

North-star metrics:

- undo/redo trust pass rate
- autosave/recovery success rate
- print and PDF output consistency score
- save/reopen correctness rate

Guardrails:

- no new data-loss scenarios
- no new recovery regressions
- no new output corruption in high-value documents

## Round discipline

Every round must follow this sequence:

1. pick one bottleneck
2. define one primary metric and explicit guardrails
3. change the smallest real source surface that can move the result
4. run the same verification budget every time
5. keep the round only if the workflow measurably improves
6. log what changed, what did not, and what should be next

## Fixed verification budget

Each round should use a fixed budget drawn from the repo's real entry points:

- `make build`
- `make check`
- `make unitcheck`
- `make slowcheck`
- `make subsequentcheck`
- `make uicheck`
- `make screenshot`
- `make test-install`
- `make debugrun`
- `bin/odfvalidator.sh`
- `bin/officeotron.sh`
- `bin/verapdf.sh`

Not every round must run every command, but each round must declare its exact budget in advance.

## Workflow Verification Pack v1

These workflows define the first durable product-quality baseline.

### Writer workflows

1. 工作周报
2. 会议纪要
3. 简历创建
4. 正式通知 / 公文式通知
5. DOCX 协作修订

### Calc workflows

6. 部门预算表
7. 销售跟踪表
8. 项目排期 / 进度跟踪
9. 复杂 XLSX 兼容

### Impress workflows

10. 工作汇报 PPT
11. 教学课件 PPT
12. 根据提纲生成 PPT 初稿
13. PPTX 兼容演示文稿

### Cross-suite workflows

14. 任务式首页进入
15. 统一命令心智

Every future round should state which workflows it improves, validates, or leaves unchanged.

## Repo-mapped execution lanes

### Lane A — Product shell and task entry

Primary files:

- `sfx2/source/dialog/backingwindow.cxx`
- `sfx2/uiconfig/ui/startcenter.ui`
- `cui/source/dialogs/welcomedlg.cxx`

Goal:

- make home/task entry scenario-first instead of module-first

### Lane B — Unified command model

Primary files:

- `officecfg/registry/data/org/openoffice/Office/UI/ToolbarMode.xcu`
- `officecfg/registry/data/org/openoffice/Office/UI/*.xcu`
- `sw/uiconfig/swriter/ui/notebookbar*.ui`
- `sc/uiconfig/scalc/ui/notebookbar*.ui`
- `sd/uiconfig/simpress/ui/notebookbar*.ui`

Goal:

- make Writer, Calc, and Impress feel like one suite

### Lane C — Compatibility lab

Primary files:

- `oox`
- `filter`
- `xmloff`
- app-specific import/export paths in `sw`, `sc`, `sd`

Goal:

- build a permanent regression gate around real Office interchange

### Lane D — Reliability and output trust

Primary files:

- save/export/recovery paths in `sfx2`, `sw`, `sc`, `sd`, `vcl`
- validation entry points under `bin/`

Goal:

- make save, export, recovery, print, and PDF results trustworthy

## Phase roadmap

### Phase 0 — Baseline and instrumentation

Deliverables:

- one source-of-truth roadmap
- one repeatable baseline script
- one generated quality baseline report
- one stable workflow pack for round review

Acceptance:

- the team can start every round from the same baseline instead of memory

### Phase 1 — P0 product wins

Priority:

1. home/workbench
2. unified command model
3. compatibility lab
4. PPT draft workflow

Acceptance:

- first-run task entry is clearer
- cross-module command discovery is more consistent
- Office interchange regressions are visible sooner

### Phase 2 — Product leadership

Priority:

1. scenario/template engine
2. China defaults system
3. surface pruning
4. AI office workflows built on top of stable core flows

Acceptance:

- common Chinese office tasks start faster and require less relearning

### Phase 3 — Strategic moat

Priority:

1. service layer
2. enterprise/private deployment mode
3. cross-device continuity

Acceptance:

- the suite becomes a broader product system instead of only a desktop build

## Release gates

A round is accepted only if all of the following are true:

- the targeted workflow improves or the targeted defect class shrinks
- guardrails remain green
- the change is reproducible from the checked-in source
- the result is recorded in a round log or baseline report

## Immediate execution cut

The first execution cut is not another visual redesign round.

It is:

1. create this roadmap
2. add a baseline quality scaffold in the repo
3. generate a baseline report from the current tree
4. use that report as the mandatory starting point for every next round

## Current first implementation target

The first code artifacts for this roadmap are `bin/quality-baseline.sh`, `bin/compatibility-lab.sh`, and `bin/compatibility-roundtrip.sh`.

Their jobs are to:

- capture the repo state for a round
- surface the main quality entry points already available here
- print the Workflow Verification Pack v1
- inventory real compatibility samples from the source tree
- execute a small real round-trip run against a chosen format lane or smoke pack
- record validator outcomes and failure summaries in the run report
- standardize what must be reviewed before a new optimization round is accepted

That gives 可圈office a real quality loop entry point instead of relying on ad hoc review.
