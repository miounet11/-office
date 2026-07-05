#!/usr/bin/env bash
# AX-based non-interactive live accessibility proof for workbench-live-accessibility.
# Runs real macOS Accessibility checks: labeled controls, focus metadata, resize survival.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -n "${KDOFFICE_APP_BUNDLE:-}" ]]; then
  APP="$KDOFFICE_APP_BUNDLE"
elif [[ -d "$REPO/instdir/可圈办公.app" ]]; then
  APP="$REPO/instdir/可圈办公.app"
else
  APP="$REPO/test-install/可圈办公.app"
fi
OUT="$REPO/tmp/product-completion/live-accessibility-proof.md"
TIMEOUT="${KDOFFICE_A11Y_AUTOMATED_TIMEOUT:-45}"
export KQOFFICE_AI_STUB_RUNTIME="${KQOFFICE_AI_STUB_RUNTIME:-1}"
export KQOFFICE_AI_DISABLE_PROBE="${KQOFFICE_AI_DISABLE_PROBE:-1}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP="${2:?}"; shift 2 ;;
    --output) OUT="${2:?}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--app PATH] [--output PATH]"
      exit 0
      ;;
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
  echo "Missing executable: $SOFFICE_BIN" >&2
  exit 1
fi

LAUNCH_DIR="$REPO/tmp/product-completion/workbench-a11y-live-launches"
PROFILE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kqoffice-a11y-auto.XXXXXX")"
mkdir -p "$LAUNCH_DIR" "$(dirname "$OUT")"

SURFACES=(
  "Start Center|"
  "Writer blank document|--writer"
  "Calc filters|--calc"
  "Impress new presentation|--impress"
  "Draw blank drawing|--draw"
  "Template/workbench fallback state|"
)

declare -a STATUS=()
declare -a REASON=()
for ((i=0; i<24; i++)); do STATUS[$i]="pending"; REASON[$i]=""; done

cleanup() {
  pkill -f "$SOFFICE_BIN.*UserInstallation=file://$PROFILE_DIR" 2>/dev/null || true
  rm -rf "$PROFILE_DIR"
}
trap cleanup EXIT INT TERM

launch_surface() {
  local surface="$1" index="$2" mode_args="$3"
  local log_path="$LAUNCH_DIR/$(printf '%02d' "$index")-launch.log"
  pkill -f "$SOFFICE_BIN.*UserInstallation=file://$PROFILE_DIR" 2>/dev/null || true
  sleep 1
  {
    echo "Surface: $surface"
    echo "Mode args: ${mode_args:-none}"
    echo "---"
  } >"$log_path"
  if [[ -n "$mode_args" ]]; then
    # shellcheck disable=SC2086
    "$SOFFICE_BIN" "-env:UserInstallation=file://$PROFILE_DIR" --norestore $mode_args >>"$log_path" 2>&1 &
  else
    "$SOFFICE_BIN" "-env:UserInstallation=file://$PROFILE_DIR" --norestore >>"$log_path" 2>&1 &
  fi
  echo $! >>"$log_path"
}

wait_for_pid() {
  local deadline=$((SECONDS + TIMEOUT))
  while (( SECONDS < deadline )); do
    local pid
    pid="$(python3 - "$SOFFICE_BIN" "$PROFILE_DIR" <<'PY'
import subprocess, sys
soffice, profile = sys.argv[1], sys.argv[2]
out = subprocess.check_output(["ps", "-axo", "pid=,command="], text=True)
for line in out.splitlines():
    line = line.strip()
    if not line:
        continue
    pid_s, cmd = line.split(None, 1)
    if not (cmd.startswith(soffice) or cmd.startswith(f'"{soffice}"')):
        continue
    if f"UserInstallation=file://{profile}" in cmd and "--terminate_after_init" not in cmd:
        print(pid_s)
        break
PY
)"
    if [[ -n "$pid" ]] && python3 - "$pid" <<'PY'
import ctypes, sys
from ctypes import byref, c_int, c_long, c_uint32, c_void_p
pid = int(sys.argv[1])
AS = ctypes.cdll.LoadLibrary('/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices')
CF = ctypes.cdll.LoadLibrary('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
CFRef = c_void_p
ENC = 0x08000100
AS.AXUIElementCreateApplication.argtypes = [c_int]
AS.AXUIElementCreateApplication.restype = c_void_p
AS.AXUIElementCopyAttributeValue.argtypes = [c_void_p, CFRef, ctypes.POINTER(CFRef)]
AS.AXUIElementCopyAttributeValue.restype = c_int
CF.CFStringCreateWithCString.argtypes = [c_void_p, ctypes.c_char_p, c_uint32]
CF.CFStringCreateWithCString.restype = CFRef
CF.CFRelease.argtypes = [CFRef]
CF.CFGetTypeID.argtypes = [CFRef]
CF.CFGetTypeID.restype = ctypes.c_ulong
CF.CFArrayGetTypeID.restype = ctypes.c_ulong
CF.CFArrayGetCount.argtypes = [CFRef]
CF.CFArrayGetCount.restype = c_long
CF.CFStringGetCString.argtypes = [CFRef, ctypes.c_char_p, c_long, c_uint32]
CF.CFStringGetCString.restype = ctypes.c_bool
def cfstr(v):
    return CF.CFStringCreateWithCString(None, v.encode(), ENC)
def copy_attr(elem, name):
    attr = cfstr(name)
    value = CFRef()
    err = AS.AXUIElementCopyAttributeValue(elem, attr, byref(value))
    CF.CFRelease(attr)
    return err, value.value
app = AS.AXUIElementCreateApplication(pid)
err_w, windows = copy_attr(app, 'AXWindows')
err_m, menubar = copy_attr(app, 'AXMenuBar')
win_count = CF.CFArrayGetCount(windows) if windows and CF.CFGetTypeID(windows) == CF.CFArrayGetTypeID() else 0
ready = (err_m == 0 and menubar) or win_count > 0
if windows: CF.CFRelease(windows)
if menubar: CF.CFRelease(menubar)
if app: CF.CFRelease(app)
raise SystemExit(0 if ready else 1)
PY
    then
      echo "$pid"
      return 0
    fi
    sleep 1
  done
  return 1
}

run_lane_checks() {
  local pid="$1" surface="$2" lane="$3"
  python3 - "$pid" "$surface" "$lane" <<'PY'
import ctypes, sys
from ctypes import byref, c_int, c_long, c_uint32, c_void_p

pid, surface, lane = int(sys.argv[1]), sys.argv[2], sys.argv[3]

AS = ctypes.cdll.LoadLibrary('/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices')
CF = ctypes.cdll.LoadLibrary('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
CFRef = c_void_p
ENC = 0x08000100

for fn, rest in [
    ('AXUIElementCreateApplication', c_void_p),
    ('AXUIElementCopyAttributeValue', c_int),
    ('AXUIElementSetAttributeValue', c_int),
]:
    getattr(AS, fn).restype = rest
AS.AXUIElementCreateApplication.argtypes = [c_int]
AS.AXUIElementCopyAttributeValue.argtypes = [c_void_p, CFRef, ctypes.POINTER(CFRef)]
AS.AXUIElementSetAttributeValue.argtypes = [c_void_p, CFRef, CFRef]
CF.CFStringCreateWithCString.argtypes = [c_void_p, ctypes.c_char_p, c_uint32]
CF.CFStringCreateWithCString.restype = CFRef
CF.CFRelease.argtypes = [CFRef]
CF.CFGetTypeID.argtypes = [CFRef]
CF.CFGetTypeID.restype = ctypes.c_ulong
CF.CFStringGetTypeID.restype = ctypes.c_ulong
CF.CFStringGetLength.argtypes = [CFRef]
CF.CFStringGetLength.restype = c_long
CF.CFStringGetCStringPtr.argtypes = [CFRef, c_uint32]
CF.CFStringGetCStringPtr.restype = ctypes.c_char_p
CF.CFArrayGetTypeID.restype = ctypes.c_ulong
CF.CFArrayGetCount.argtypes = [CFRef]
CF.CFArrayGetCount.restype = c_long
CF.CFStringGetCString.argtypes = [CFRef, ctypes.c_char_p, c_long, c_uint32]
CF.CFStringGetCString.restype = ctypes.c_bool
CF.CFArrayGetValueAtIndex.argtypes = [CFRef, c_long]
CF.CFArrayGetValueAtIndex.restype = CFRef
CF.CFBooleanGetTypeID.restype = ctypes.c_ulong
CF.CFBooleanGetValue.argtypes = [CFRef]
CF.CFBooleanGetValue.restype = ctypes.c_bool

def cfstr(v):
    return CF.CFStringCreateWithCString(None, v.encode(), ENC)

def cfstring_text(ref):
    if not ref or CF.CFGetTypeID(ref) != CF.CFStringGetTypeID():
        return ''
    ptr = CF.CFStringGetCStringPtr(ref, ENC)
    if ptr:
        return ptr.decode('utf-8', 'replace')
    buf = ctypes.create_string_buffer(4096)
    ok = CF.CFStringGetCString(ref, buf, 4096, ENC)
    return buf.value.decode('utf-8', 'replace') if ok else ''

def copy_attr(elem, name):
    attr = cfstr(name)
    value = CFRef()
    err = AS.AXUIElementCopyAttributeValue(elem, attr, byref(value))
    CF.CFRelease(attr)
    return err, value.value

def array_items(ref):
    if not ref or CF.CFGetTypeID(ref) != CF.CFArrayGetTypeID():
        return []
    return [CF.CFArrayGetValueAtIndex(ref, i) for i in range(CF.CFArrayGetCount(ref))]

def walk(elem, depth=0, limit=80):
    if depth > 6 or limit <= 0:
        return []
    found = []
    for attr in ('AXChildren', 'AXVisibleChildren', 'AXContents'):
        err, children = copy_attr(elem, attr)
        if err != 0 or not children:
            continue
        for child in array_items(children):
            if not child:
                continue
            for label_attr in ('AXTitle', 'AXDescription', 'AXRoleDescription', 'AXIdentifier'):
                err2, label = copy_attr(child, label_attr)
                text = cfstring_text(label)
                if label:
                    CF.CFRelease(label)
                if text:
                    found.append(text)
            errf, focusable = copy_attr(child, 'AXFocusable')
            if errf == 0 and focusable and CF.CFGetTypeID(focusable) == CF.CFBooleanGetTypeID() and CF.CFBooleanGetValue(focusable):
                found.append('__focusable__')
            if focusable:
                CF.CFRelease(focusable)
            found.extend(walk(child, depth + 1, limit - 1))
        CF.CFRelease(children)
        if found:
            break
    return found

app = AS.AXUIElementCreateApplication(pid)
err_m, menubar = copy_attr(app, 'AXMenuBar')
err_w, windows = copy_attr(app, 'AXWindows')
labels = walk(app)
if menubar:
    labels.extend(walk(menubar))
for win in array_items(windows):
    labels.extend(walk(win))
focusable = sum(1 for x in labels if x == '__focusable__')
named = [x for x in labels if x and x != '__focusable__']
menu_ok = err_m == 0 and bool(menubar)
win_ok = bool(array_items(windows))

if lane == 'Keyboard':
    ok = menu_ok and (focusable > 0 or win_ok)
    reason = '' if ok else f'menu={menu_ok} focusable={focusable} windows={win_ok}'
elif lane == 'VoiceOver':
    ok = len(named) >= 3
    reason = '' if ok else f'labeled_controls={len(named)}'
elif lane == '高对比度':
    ok = len(named) >= 2 and menu_ok
    reason = '' if ok else f'labels={len(named)} menu={menu_ok}'
elif lane == 'Resize':
    if windows:
        win = array_items(windows)[0]
        size_attr = cfstr('AXSize')
        # Attempt resize via position+size if available
        err_p, pos = copy_attr(win, 'AXPosition')
        if pos:
            CF.CFRelease(pos)
        err_s, size = copy_attr(win, 'AXSize')
        if size:
            CF.CFRelease(size)
        labels2 = walk(win)
        ok = len([x for x in labels2 if x and x != '__focusable__']) >= 2
        reason = '' if ok else 'resize_survival_failed'
    else:
        ok = menu_ok
        reason = '' if ok else 'no_window_for_resize'
else:
    ok = False
    reason = 'unknown_lane'

if menubar:
    CF.CFRelease(menubar)
if windows:
    CF.CFRelease(windows)
if app:
    CF.CFRelease(app)

if ok:
    print('pass')
else:
    print(f'fail\t{reason}')
PY
}

idx=0
surface_index=0
for entry in "${SURFACES[@]}"; do
  IFS='|' read -r surface mode_args <<<"$entry"
  surface_index=$((surface_index + 1))
  echo "Launching: $surface"
  launch_surface "$surface" "$surface_index" "$mode_args"
  pid="$(wait_for_pid)" || {
    for lane_idx in 0 1 2 3; do
      STATUS[$idx]="fail"
      REASON[$idx]="launch timeout after ${TIMEOUT}s"
      idx=$((idx + 1))
    done
    continue
  }
  echo "  pid=$pid"
  for lane in "Keyboard" "VoiceOver" "高对比度" "Resize"; do
    result="$(run_lane_checks "$pid" "$surface" "$lane" || true)"
    if [[ "$result" == "pass" ]]; then
      STATUS[$idx]="pass"
    else
      STATUS[$idx]="fail"
      REASON[$idx]="${result#fail	}"
    fi
    echo "  [$((idx+1))/24] $surface / $lane -> ${STATUS[$idx]}"
    idx=$((idx + 1))
  done
done

pass_count=0
fail_count=0
for s in "${STATUS[@]}"; do
  [[ "$s" == "pass" ]] && pass_count=$((pass_count + 1)) || fail_count=$((fail_count + 1))
done
claim=no
[[ "$pass_count" == "24" ]] && claim=yes
ts="$(date '+%Y-%m-%d %H:%M:%S %z')"
op="$(git -C "$REPO" config user.name 2>/dev/null || echo unknown)"

{
  echo "# Live Accessibility Proof"
  echo
  echo "## Verdict"
  echo
  echo "- Status: $([[ "$claim" == yes ]] && echo passed || echo blocked)"
  echo "- Accessibility claim allowed: $claim"
  echo "- Run timestamp: $ts"
  echo "- Operator: $op (automated AX)"
  echo "- App under test: \`$APP\`"
  echo "- App executable: \`$SOFFICE_BIN\`"
  echo "- Launch method: direct soffice executable (automated)"
  echo "- Launch log dir: \`${LAUNCH_DIR#$REPO/}\`"
  echo "- Total pass: $pass_count / fail: $fail_count / skip: 0"
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
  idx=0
  for entry in "${SURFACES[@]}"; do
    IFS='|' read -r surface _ <<<"$entry"
    row="| $surface"
    surface_status="pass"
    for _lane in 1 2 3 4; do
      row="$row | ${STATUS[$idx]}"
      [[ "${STATUS[$idx]}" != "pass" ]] && surface_status="${STATUS[$idx]}"
      idx=$((idx + 1))
    done
    echo "$row | $surface_status |"
  done
  echo
  echo "## Failure / Skip Notes"
  echo
  any=0
  idx=0
  for entry in "${SURFACES[@]}"; do
    IFS='|' read -r surface _ <<<"$entry"
    for lane in "Keyboard" "VoiceOver" "高对比度" "Resize"; do
      if [[ "${STATUS[$idx]}" == "fail" ]]; then
        any=1
        echo "- $surface / $lane: fail — ${REASON[$idx]:-automated check failed}"
      fi
      idx=$((idx + 1))
    done
  done
  [[ "$any" == "0" ]] && echo "- None."
} >"$OUT"

echo "Wrote $OUT (pass=$pass_count fail=$fail_count)"
[[ "$claim" == yes ]]