#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_path="${1:-$repo_root/tmp/world-class-quality-baseline.md}"

usage() {
    cat <<'EOF'
Usage:
  quality-baseline.sh [output-file]

Generates a repeatable baseline report for the current 可圈office tree.
If no output file is provided, the report is written to:
  tmp/world-class-quality-baseline.md
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

branch_name="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'unknown')"
head_commit="$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
status_count="$(git -C "$repo_root" status --short 2>/dev/null | wc -l | tr -d ' ')"
source_status_count="$(
    git -C "$repo_root" status --short -- \
        . \
        ':(exclude)workdir/**' \
        ':(exclude)instdir/**' \
        ':(exclude)test-install/**' \
        ':(exclude)tmp/**' \
        ':(exclude)autom4te.cache/**' \
        ':(exclude)config.log' \
        ':(exclude)config.status' \
        ':(exclude)config_host.mk' \
        ':(exclude)config_host/**' \
        ':(exclude)autogen.lastrun' \
        ':(exclude)autogen.lastrun.bak' \
        2>/dev/null | wc -l | tr -d ' '
)"
created_at="$(date '+%Y-%m-%d %H:%M:%S %z')"

mkdir -p "$(dirname "$output_path")"

file_state() {
    local rel="$1"
    if [[ -e "$repo_root/$rel" ]]; then
        printf 'present'
    else
        printf 'missing'
    fi
}

cat > "$output_path" <<EOF
# 可圈office Quality Baseline

Generated at: $created_at
Branch: $branch_name
HEAD: $head_commit
Working tree entries: $status_count
Source-focused entries: $source_status_count
Repo root: $repo_root

## Roadmap source

- AUTORESEARCH_EXECUTION_TODOLIST.md
- AUTORESEARCH_WORLD_CLASS_QUALITY_ROADMAP.md

## Repo entry-point inventory

- Makefile: $(file_state "Makefile")
- test/Makefile: $(file_state "test/Makefile")
- uitest/Makefile: $(file_state "uitest/Makefile")
- bin/odfvalidator.sh: $(file_state "bin/odfvalidator.sh")
- bin/officeotron.sh: $(file_state "bin/officeotron.sh")
- bin/verapdf.sh: $(file_state "bin/verapdf.sh")
- bin/source-hygiene-report.sh: $(file_state "bin/source-hygiene-report.sh")
- bin/intelligent-office-readiness.sh: $(file_state "bin/intelligent-office-readiness.sh")
- bin/intelligent-contract-fixtures.sh: $(file_state "bin/intelligent-contract-fixtures.sh")
- bin/compatibility-lab.sh: $(file_state "bin/compatibility-lab.sh")
- bin/compatibility-roundtrip.sh: $(file_state "bin/compatibility-roundtrip.sh")
- docs/compatibility/smoke-manifest.tsv: $(file_state "docs/compatibility/smoke-manifest.tsv")
- AUTORESEARCH_EXECUTION_TODOLIST.md: $(file_state "AUTORESEARCH_EXECUTION_TODOLIST.md")
- AUTORESEARCH_INTELLIGENT_OFFICE_ARCHITECTURE.md: $(file_state "AUTORESEARCH_INTELLIGENT_OFFICE_ARCHITECTURE.md")
- AUTORESEARCH_OFFICE_ROUNDS.md: $(file_state "AUTORESEARCH_OFFICE_ROUNDS.md")
- AUTORESEARCH_PRODUCT_REFACTOR_AUDIT.md: $(file_state "AUTORESEARCH_PRODUCT_REFACTOR_AUDIT.md")

## Standard command budget

- make build
- make check
- make unitcheck
- make slowcheck
- make subsequentcheck
- make uicheck
- make screenshot
- make test-install
- make debugrun
- bin/odfvalidator.sh <file>
- bin/officeotron.sh <file>
- bin/verapdf.sh <file>
- bin/source-hygiene-report.sh tmp/source-hygiene-report.md
- bin/source-hygiene-report.sh --strict tmp/source-hygiene-report.md
- bin/intelligent-office-readiness.sh tmp/intelligent-office-readiness.md
- bin/intelligent-contract-fixtures.sh tmp/intelligent-contract-fixtures.md
- bin/compatibility-roundtrip.sh --manifest docs/compatibility/smoke-manifest.tsv --run-name <name>

## Workflow Verification Pack v1

### Writer
1. 工作周报
2. 会议纪要
3. 简历创建
4. 正式通知 / 公文式通知
5. DOCX 协作修订

### Calc
6. 部门预算表
7. 销售跟踪表
8. 项目排期 / 进度跟踪
9. 复杂 XLSX 兼容

### Impress
10. 工作汇报 PPT
11. 教学课件 PPT
12. 根据提纲生成演示提纲
13. PPTX 兼容演示文稿

### Cross-suite
14. 任务式首页进入
15. 统一命令心智

## Round checklist

1. Pick one bottleneck.
2. Name one primary metric.
3. Name explicit guardrails.
4. Declare the fixed verification budget.
5. Record which workflows this round targets.
6. Keep or reject the round based on evidence.

## Current focus lanes

- compatibility
- stability
- interaction logic
- reliability

## Next-round template

- Round name:
- Bottleneck:
- Primary metric:
- Guardrails:
- Commands to run:
- Workflows covered:
- Result:
- Next bottleneck:
EOF

printf 'Wrote baseline report to %s\n' "$output_path"
