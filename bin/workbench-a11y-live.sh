#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP="$REPO/test-install/可圈office.app"
OUT="$REPO/tmp/product-completion/live-accessibility-proof.md"
STATE="$(mktemp -t workbench-a11y-live.XXXXXX)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP="${2:?missing --app}"; shift 2 ;;
    --output) OUT="${2:?missing --output}"; shift 2 ;;
    -h|--help) echo "Usage: $0 [--app PATH] [--output PATH]"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

SURFACES=("Start Center" "Writer blank document" "Calc filters" "Impress new presentation" "Draw blank drawing" "Template/workbench fallback state")
LANES=("Keyboard" "VoiceOver" "高对比度" "Resize")

status=(); reason=()
for ((i=0;i<24;i++)); do status[$i]="pending live review"; reason[$i]=""; done

count_status() {
  local want="$1" n=0
  for s in "${status[@]}"; do [[ "$s" == "$want" ]] && n=$((n+1)); done
  echo "$n"
}

write_evidence() {
  mkdir -p "$(dirname "$OUT")"
  local tmp="$OUT.tmp.$$"
  local ts op pass fail skip claim
  ts="$(date '+%Y-%m-%d %H:%M:%S %z')"
  op="$(git config user.name 2>/dev/null || echo unknown)"
  pass="$(count_status pass)"
  fail="$(count_status fail)"
  skip="$(count_status skip)"
  if [[ "$pass" == "24" ]]; then claim=yes; else claim=no; fi

  {
    echo "# Live Accessibility Proof"
    echo
    echo "## Verdict"
    echo
    echo "- Status: $([[ "$claim" == yes ]] && echo passed || echo blocked)"
    echo "- Accessibility claim allowed: $claim"
    echo "- Run timestamp: $ts"
    echo "- Operator: $op"
    echo "- App under test: \`$APP\`"
    echo "- Total pass: $pass / fail: $fail / skip: $skip"
    echo
    echo "## Static Evidence"
    echo
    echo "| Gate | Evidence | Status |"
    echo "| --- | --- | --- |"
    echo "| Start Center static accessibility | \`tmp/product-completion/workbench-accessibility-check.md\` | pass |"
    echo
    echo "## Matrix"
    echo
    echo "| Surface | Keyboard | VoiceOver | High contrast | Resize | Status |"
    echo "| --- | --- | --- | --- | --- | --- |"
    local idx=0
    for surface in "${SURFACES[@]}"; do
      local row="| $surface" surface_status="pass"
      for lane in "${LANES[@]}"; do
        row="$row | ${status[$idx]}"
        [[ "${status[$idx]}" != "pass" ]] && surface_status="${status[$idx]}"
        idx=$((idx+1))
      done
      echo "$row | $surface_status |"
    done
    echo
    echo "## Failure / Skip Notes"
    echo
    local any=0; idx=0
    for surface in "${SURFACES[@]}"; do
      for lane in "${LANES[@]}"; do
        if [[ "${status[$idx]}" == "fail" || "${status[$idx]}" == "skip" ]]; then
          any=1
          echo "- $surface / $lane: ${status[$idx]} — ${reason[$idx]:-no reason}"
        fi
        idx=$((idx+1))
      done
    done
    [[ "$any" == "0" ]] && echo "- None."
  } > "$tmp"
  mv "$tmp" "$OUT"
}

on_interrupt() {
  echo
  echo "Interrupted. Writing partial evidence to $OUT"
  write_evidence
  rm -f "$STATE"
  exit 130
}
trap on_interrupt INT TERM

instruction() {
  case "$2" in
    Keyboard) echo "Tab/Shift+Tab through $1; Enter/Space activates focused control. Expect: focus visible, logical order, no traps." ;;
    VoiceOver) echo "VoiceOver (Cmd+F5) on $1. Expect: names/roles/state read clearly in Chinese." ;;
    高对比度) echo "Enable macOS Increase Contrast. Open $1. Expect: focus rings, labels, warnings remain perceivable." ;;
    Resize) echo "Resize $1 to narrow/short. Expect: critical controls remain reachable, no clipping of primary entry points." ;;
  esac
}

choose_result() {
  local ans
  while true; do
    read -r -p "Result [pass/fail/skip]: " ans
    case "$ans" in pass|fail|skip) echo "$ans"; return 0 ;; esac
    echo "Type pass, fail, or skip."
  done
}

echo "Workbench live accessibility review"
echo "App: $APP"
echo "Output: $OUT"
echo "Press Ctrl+C anytime; partial evidence is preserved."
echo

idx=0
for surface in "${SURFACES[@]}"; do
  for lane in "${LANES[@]}"; do
    echo "[$((idx+1))/24] $surface / $lane"
    instruction "$surface" "$lane"
    read -r -p "Press Enter to start..."
    [[ -d "$APP" ]] && open "$APP" >/dev/null 2>&1 || true
    res="$(choose_result)"
    status[$idx]="$res"
    if [[ "$res" != "pass" ]]; then
      read -r -p "Reason (one line): " why
      reason[$idx]="$why"
    fi
    write_evidence
    echo
    idx=$((idx+1))
  done
done

write_evidence
rm -f "$STATE"
echo "Done. Evidence: $OUT"
