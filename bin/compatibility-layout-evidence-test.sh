#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_under_test="$repo_root/bin/compatibility-layout-evidence.sh"

tmp_root="$(mktemp -d)"
cleanup() {
    rm -rf "$tmp_root"
}
trap cleanup EXIT

fake_repo="$tmp_root/repo"
mkdir -p "$fake_repo/bin" "$fake_repo/tmp"
cp "$script_under_test" "$fake_repo/bin/compatibility-layout-evidence.sh"
chmod +x "$fake_repo/bin/compatibility-layout-evidence.sh"

missing_run_report="$fake_repo/tmp/layout-missing-run.md"
if "$fake_repo/bin/compatibility-layout-evidence.sh" \
    --run-dir "$fake_repo/tmp/compatibility-runs/missing" \
    --report "$missing_run_report" \
    > "$tmp_root/missing-run-stdout.log" 2> "$tmp_root/missing-run-stderr.log"; then
    printf 'Expected layout evidence to fail when the run directory is missing\n' >&2
    exit 1
fi

for expected in \
    '# Compatibility Layout Evidence Seed' \
    'Status: **fail**' \
    'missing-run-directory' \
    'tmp/compatibility-runs/missing' \
    'Run the compatibility roundtrip gate first'
do
    if ! grep -F -q -- "$expected" "$missing_run_report"; then
        printf 'Expected missing-run report to include %s\n' "$expected" >&2
        exit 1
    fi
done

missing_samples_run="$fake_repo/tmp/compatibility-runs/no-samples"
mkdir -p "$missing_samples_run"
missing_samples_report="$fake_repo/tmp/layout-missing-samples.md"
if "$fake_repo/bin/compatibility-layout-evidence.sh" \
    --run-dir "$missing_samples_run" \
    --report "$missing_samples_report" \
    > "$tmp_root/missing-samples-stdout.log" 2> "$tmp_root/missing-samples-stderr.log"; then
    printf 'Expected layout evidence to fail when samples.tsv is missing\n' >&2
    exit 1
fi

for expected in \
    'Status: **fail**' \
    'missing-samples-file' \
    'tmp/compatibility-runs/no-samples/samples.tsv'
do
    if ! grep -F -q -- "$expected" "$missing_samples_report"; then
        printf 'Expected missing-samples report to include %s\n' "$expected" >&2
        exit 1
    fi
done

missing_artifact_run="$fake_repo/tmp/compatibility-runs/missing-artifacts"
mkdir -p "$missing_artifact_run"
cat > "$missing_artifact_run/samples.tsv" <<'TSV'
docx	sw/qa/extras/ooxmlexport/data/sample.docx	文档样张
xlsx	sc/qa/unit/data/xlsx/sample.xlsx	表格样张
pptx	sd/qa/unit/data/pptx/sample.pptx	演示样张
TSV
cat > "$missing_artifact_run/results.tsv" <<'TSV'
docx	passed
xlsx	passed
pptx	passed
TSV
missing_artifact_report="$fake_repo/tmp/layout-missing-artifacts.md"
if "$fake_repo/bin/compatibility-layout-evidence.sh" \
    --run-dir "$missing_artifact_run" \
    --report "$missing_artifact_report" \
    > "$tmp_root/missing-artifacts-stdout.log" 2> "$tmp_root/missing-artifacts-stderr.log"; then
    printf 'Expected layout evidence to fail when selected lane artifacts are missing\n' >&2
    exit 1
fi

for expected in \
    'Status: **fail**' \
    'missing-lane-artifacts' \
    'docx' \
    'xlsx' \
    'pptx' \
    'Run `bin/compatibility-roundtrip.sh --manifest docs/compatibility/smoke-manifest.tsv --run-name v2-smoke-fidelity-manifest-final`'
do
    if ! grep -F -q -- "$expected" "$missing_artifact_report"; then
        printf 'Expected missing-artifacts report to include %s\n' "$expected" >&2
        exit 1
    fi
done

printf 'compatibility-layout-evidence failure-report tests passed\n'
