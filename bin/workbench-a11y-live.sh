#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP="$REPO/test-install/可圈办公.app"
OUT="$REPO/tmp/product-completion/live-accessibility-proof.md"
STATE="$(mktemp -t workbench-a11y-live.XXXXXX)"
RESUME=0
CHECKLIST_OUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP="${2:?missing --app}"; shift 2 ;;
    --output) OUT="${2:?missing --output}"; shift 2 ;;
    --checklist) CHECKLIST_OUT="${2:?missing --checklist}"; shift 2 ;;
    --resume) RESUME=1; shift ;;
    -h|--help) echo "Usage: $0 [--app PATH] [--output PATH] [--checklist PATH] [--resume]"; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ ! -d "$APP" ]]; then
  echo "Missing app bundle: $APP" >&2
  exit 1
fi
APP="$(cd -P "$APP" && pwd)"
SOFFICE_BIN="$APP/Contents/MacOS/soffice"
if [[ ! -x "$SOFFICE_BIN" ]]; then
  echo "Missing app executable: $SOFFICE_BIN" >&2
  exit 1
fi
LAUNCH_DIR="$REPO/tmp/product-completion/workbench-a11y-live-launches"
PROFILE_DIR="${KDOFFICE_A11Y_PROFILE_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/kqoffice-a11y-live.XXXXXX")}"
mkdir -p "$LAUNCH_DIR" "$PROFILE_DIR"

SURFACES=("Start Center" "Writer blank document" "Calc filters" "Impress new presentation" "Draw blank drawing" "Template/workbench fallback state")
LANES=("Keyboard" "VoiceOver" "高对比度" "Resize")

status=(); reason=()
for ((i=0;i<24;i++)); do status[$i]="pending live review"; reason[$i]=""; done

load_existing_evidence() {
  [[ -f "$OUT" ]] || return 0
  python3 - "$OUT" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
valid = {"pass", "fail", "skip", "pending live review"}
in_notes = False
for raw in path.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if line.startswith("## Failure / Skip Notes"):
        in_notes = True
        continue
    if in_notes:
        if not line.startswith("-"):
            continue
        if line == "- None.":
            continue
        prefix, sep, note = line[2:].partition(": ")
        if not sep:
            continue
        surface, sep, lane = prefix.partition(" / ")
        status, sep, reason = note.partition(" — ")
        if sep and status in {"fail", "skip"}:
            print(f"reason\t{surface}\t{lane}\t{status}\t{reason}")
        continue
    if not line.startswith("|") or line.startswith("| ---") or line.startswith("| Surface "):
        continue
    cells = [cell.strip() for cell in line.strip("|").split("|")]
    if len(cells) != 6:
        continue
    surface, keyboard, voiceover, contrast, resize, _surface_status = cells
    for lane, status in zip(["Keyboard", "VoiceOver", "高对比度", "Resize"], [keyboard, voiceover, contrast, resize]):
        if status in valid:
            print(f"status\t{surface}\t{lane}\t{status}")
PY
}

apply_existing_evidence() {
  local kind surface lane value note idx=0 loaded=0
  while IFS=$'\t' read -r kind surface lane value note; do
    idx=0
    for existing_surface in "${SURFACES[@]}"; do
      for existing_lane in "${LANES[@]}"; do
        if [[ "$existing_surface" == "$surface" && "$existing_lane" == "$lane" ]]; then
          if [[ "$kind" == "status" && "$value" =~ ^(pass|fail|skip)$ ]]; then
            status[$idx]="$value"
            loaded=$((loaded + 1))
          elif [[ "$kind" == "reason" && ( "$value" == "fail" || "$value" == "skip" ) ]]; then
            reason[$idx]="$note"
          fi
        fi
        idx=$((idx+1))
      done
    done
  done < <(load_existing_evidence)
  if [[ "$loaded" -gt 0 ]]; then
    echo "Resumed $loaded completed live accessibility checks from $OUT"
  fi
}

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
    echo "- App executable: \`$SOFFICE_BIN\`"
    echo "- Launch method: direct soffice executable"
    echo "- Launch log dir: \`${LAUNCH_DIR#$REPO/}\`"
    echo "- User profile dir: \`$PROFILE_DIR\`"
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

write_checklist() {
  local checklist_path="$1"
  mkdir -p "$(dirname "$checklist_path")"
  {
    echo "# Live Accessibility Manual Review Checklist"
    echo
    echo "- App under test: \`$APP\`"
    echo "- App executable: \`$SOFFICE_BIN\`"
    echo "- Proof output: \`$OUT\`"
    echo "- Status: support-only"
    echo "- Accessibility claim allowed: no"
    echo "- Manual proof required: yes"
    echo
    echo "## Checks"
    echo
    echo "| # | Surface | Lane | Instruction |"
    echo "| --- | --- | --- | --- |"
    local idx=0
    local surface lane detail
    for surface in "${SURFACES[@]}"; do
      for lane in "${LANES[@]}"; do
        idx=$((idx+1))
        detail="$(instruction "$surface" "$lane")"
        detail="${detail//|/\\|}"
        echo "| $idx | $surface | $lane | $detail |"
      done
    done
    echo
    echo "## Stop Rule"
    echo
    echo "- This checklist is not beta evidence. Only a completed proof with 24 pass results can satisfy workbench-live-accessibility."
  } > "$checklist_path"
}

choose_result() {
  local ans
  while true; do
    read -r -p "Result [pass/fail/skip]: " ans
    case "$ans" in pass|fail|skip) echo "$ans"; return 0 ;; esac
    echo "Type pass, fail, or skip."
  done
}

launch_args_for_surface() {
  case "$1" in
    "Writer blank document") printf '%s\0' --writer ;;
    "Calc filters") printf '%s\0' --calc ;;
    "Impress new presentation") printf '%s\0' --impress ;;
    "Draw blank drawing") printf '%s\0' --draw ;;
  esac
}

launch_app_for_review() {
  local surface="$1" index="$2"
  local log_path="$LAUNCH_DIR/$(printf '%02d' "$index")-launch.log"
  local -a mode_args=()
  local arg
  while IFS= read -r -d '' arg; do
    mode_args+=("$arg")
  done < <(launch_args_for_surface "$surface")

  {
    printf 'App: %s\n' "$APP"
    printf 'Executable: %s\n' "$SOFFICE_BIN"
    printf 'Surface: %s\n' "$surface"
    printf 'Mode args:'
    if [[ "${#mode_args[@]}" -gt 0 ]]; then
      printf ' %q' "${mode_args[@]}"
    else
      printf ' none'
    fi
    printf '\n--- process output ---\n'
  } > "$log_path"

  if [[ "${#mode_args[@]}" -gt 0 ]]; then
    "$SOFFICE_BIN" "-env:UserInstallation=file://$PROFILE_DIR" --norestore "${mode_args[@]}" >> "$log_path" 2>&1 &
  else
    "$SOFFICE_BIN" "-env:UserInstallation=file://$PROFILE_DIR" --norestore >> "$log_path" 2>&1 &
  fi
}

echo "Workbench live accessibility review"
echo "App: $APP"
echo "Executable: $SOFFICE_BIN"
echo "Output: $OUT"
if [[ -n "$CHECKLIST_OUT" ]]; then
  write_checklist "$CHECKLIST_OUT"
  echo "Checklist: $CHECKLIST_OUT"
  echo "Manual proof still required: $OUT"
  rm -f "$STATE"
  exit 0
fi
if [[ "$RESUME" == "1" ]]; then
  apply_existing_evidence
fi
echo "Press Ctrl+C anytime; partial evidence is preserved."
echo

idx=0
for surface in "${SURFACES[@]}"; do
  for lane in "${LANES[@]}"; do
    echo "[$((idx+1))/24] $surface / $lane"
    if [[ "${status[$idx]}" == "pass" || "${status[$idx]}" == "fail" || "${status[$idx]}" == "skip" ]]; then
      echo "Already recorded: ${status[$idx]}; skipping. Use a new output file to retest this item."
      idx=$((idx+1))
      continue
    fi
    instruction "$surface" "$lane"
    read -r -p "Press Enter to start..."
    launch_app_for_review "$surface" "$((idx+1))"
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
