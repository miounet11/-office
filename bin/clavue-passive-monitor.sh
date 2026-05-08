#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src_root="${KDOFFICE_SRC:-$repo_root/libreoffice-core}"
output_path="${1:-$repo_root/tmp/clavue-passive-monitor.md}"

usage() {
    cat <<'EOF'
Usage:
  clavue-passive-monitor.sh [output-file]

Writes a non-interrupting Clavue/build/test process snapshot. This tool only
observes process state; it does not signal, stop, or inject into Clavue.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

mkdir -p "$(dirname "$output_path")"

python3 - "$repo_root" "$src_root" "$output_path" <<'PY'
from pathlib import Path
from datetime import datetime
import subprocess
import sys

repo_root = Path(sys.argv[1])
src_root = Path(sys.argv[2]).resolve()
output_path = Path(sys.argv[3])

raw = subprocess.run(
    ["ps", "-ax", "-o", "pid=,ppid=,stat=,%cpu=,%mem=,etime=,command="],
    check=True,
    text=True,
    stdout=subprocess.PIPE,
).stdout.splitlines()

all_rows = []
office_pids = set()
pid_to_row = {}
for line in raw:
    if "clavue-passive-monitor" in line:
        continue
    parts = line.split(None, 6)
    if len(parts) < 7:
        continue
    pid, ppid, stat, cpu, mem, elapsed, command = parts
    row = (pid, ppid, stat, cpu, mem, elapsed, command)
    all_rows.append(row)
    pid_to_row[pid] = row
    if "ps -ax" in command or command.startswith("rg "):
        continue
    if str(src_root) in command or "UITest_workbench_smoke" in command:
        office_pids.add(pid)

changed = True
while changed:
    changed = False
    for pid in list(office_pids):
        row = pid_to_row.get(pid)
        if row is None:
            continue
        ppid = row[1]
        parent = pid_to_row.get(ppid)
        if parent is None or ppid in office_pids or ppid == "1":
            continue
        parent_command = parent[-1]
        if (
            "clavue" in parent_command
            or "gmake" in parent_command
            or "Makefile.gbuild" in parent_command
            or "source /Users/lu/.clavue/" in parent_command
        ):
            office_pids.add(ppid)
            changed = True

office_rows = [row for row in all_rows if row[0] in office_pids]
clavue_rows = [row for row in office_rows if "clavue" in row[-1]]

lines = [
    "# Clavue Passive Monitor",
    "",
    f"Generated at: {datetime.now().astimezone().strftime('%Y-%m-%d %H:%M:%S %z')}",
    f"Repo root: `{repo_root}`",
    f"Source root: `{src_root}`",
    "",
    "This is a passive coordination snapshot. It does not interrupt Clavue, send signals, or mutate source files.",
    "",
    "## Summary",
    "",
    f"- Office-related Clavue processes: {len(clavue_rows)}",
    f"- Office build/test/process descendants: {len(office_rows)}",
    "",
    "## Active Processes",
    "",
    "| PID | PPID | STAT | CPU | MEM | ELAPSED | Command |",
    "| ---: | ---: | --- | ---: | ---: | --- | --- |",
]

if office_rows:
    for pid, ppid, stat, cpu, mem, elapsed, command in office_rows:
        safe_command = command.replace("|", "\\|")
        lines.append(f"| {pid} | {ppid} | `{stat}` | {cpu} | {mem} | `{elapsed}` | `{safe_command}` |")
else:
    lines.append("|  |  |  |  |  |  | No matching Clavue or office build/test processes found. |")

lines.extend([
    "",
    "## Coordination Guidance",
    "",
    "- If a Clavue-owned build or UI test is active, avoid launching competing GUI smoke runs against the same install tree.",
    "- If Clavue is editing Writer analyzer, Workbench UI, or Impress builder files, keep Codex work in wrapper/report/documentation surfaces until a handoff is recorded.",
    "- Use this report as evidence for coordination only; it is not a correctness or test-pass signal.",
])

output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"Wrote Clavue passive monitor report to {output_path}")
PY
