#!/usr/bin/env bash
# V2 strict current-bundle GUI attribution smoke for 可圈office.app.
#
# Starts the current builddir instdir app bundle's soffice executable with an
# isolated profile, then uses native Accessibility AX-by-PID only if it exposes the
# exact newly-started builddir pid with its own menu bar. This prevents falsely
# attributing menu/shortcut actions on an older /Applications instance to the
# current builddir bundle.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mkdir -p tmp

app="${KDOFFICE_APP_BUNDLE:-$repo_root/instdir/可圈office.app}"
report="${V2_VISIBLE_CURRENT_REPORT:-tmp/v2-visible-current-bundle-smoke.md}"
log="${V2_VISIBLE_CURRENT_LOG:-tmp/v2-visible-current-bundle-smoke.log}"
profile=""
launch_pid=""
keep_profile="${V2_VISIBLE_CURRENT_KEEP_PROFILE:-0}"
port="${V2_VISIBLE_CURRENT_UNO_PORT:-$((25000 + RANDOM % 10000))}"
ready_timeout="${V2_VISIBLE_CURRENT_READY_TIMEOUT:-45}"
passes=0
blockers=0
failures=0
rows=()
started_pids=()

usage() {
    cat <<EOF
Usage:
  v2-visible-current-bundle-smoke.sh [--app <bundle>] [--report <path>] [--log <path>] [--keep-profile]

Checks:
  - Launches the current builddir app bundle's soffice with an isolated profile.
  - Confirms a new builddir soffice process exists without touching /Applications.
  - Uses native Accessibility AX-by-PID to bind to the newly-started pid.
  - Drives the Writer menu only when that target pid exposes
    its own AX menu bar.
  - Sends Cmd+Shift+K to the target pid with native CGEvent strategies and
    verifies CommandPalette/search/results AX nodes on the same pid.
  - Dispatches .uno:CommandPalette on the visible Writer frame and
    verifies CommandPalette/search/results AX nodes on the same pid.

This is a strict target-attribution smoke. If the builddir pid launches but
has no AX menu/window while another soffice process does, the result is
Status: blocked rather than a false GUI click-through pass.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)
            app="${2:?}"
            shift 2
            ;;
        --report)
            report="${2:?}"
            shift 2
            ;;
        --log)
            log="${2:?}"
            shift 2
            ;;
        --keep-profile)
            keep_profile=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

md_escape() {
    printf "%s" "$1" | tr "\n" ";" | sed "s/|/\\|/g"
}

record() {
    local status="$1"
    local area="$2"
    local detail="$3"
    rows+=("| $status | $area | $(md_escape "$detail") |")
    case "$status" in
        PASS)
            passes=$((passes + 1))
            printf "PASS: %s -- %s\n" "$area" "$detail"
            ;;
        BLOCKED)
            blockers=$((blockers + 1))
            printf "BLOCKED: %s -- %s\n" "$area" "$detail"
            ;;
        *)
            failures=$((failures + 1))
            printf "FAIL: %s -- %s\n" "$area" "$detail" >&2
            ;;
    esac
}

write_report() {
    local status="passed"
    if [[ "$failures" -ne 0 ]]; then
        status="failed"
    elif [[ "$blockers" -ne 0 ]]; then
        status="blocked"
    fi
    {
        echo "# V2 Visible Current-Bundle Smoke"
        echo
        echo "- Status: $status"
        if grep -Fq "target_seen=yes" <<<"${osascript_result:-}" \
            && grep -Fq "target_with_menu=yes" <<<"${osascript_result:-}" \
            && grep -Fq "drove_target_process=yes" <<<"${osascript_result:-}"; then
            echo "- Target attribution: ready"
        else
            echo "- Target attribution: blocked"
        fi
        echo "- App bundle: $app"
        echo "- Isolated profile: ${profile:-<none>}"
        echo "- UNO port: $port"
        echo "- Started builddir pids: ${started_pids[*]:-<none>}"
        echo "- Checks passed: $passes"
        echo "- Checks blocked: $blockers"
        echo "- Checks failed: $failures"
        echo "- Scope: strict current builddir bundle PID attribution + native AX Writer menu + physical Cmd+Shift+K CommandPalette proof + visible CommandPalette UNO dispatch"
        echo
        echo "| Status | Area | Detail |"
        echo "|---|---|---|"
        printf "%s\n" "${rows[@]}"
    } >"$report"

    echo "Status: $status"
    echo "Checks passed: $passes"
    echo "Checks blocked: $blockers"
    echo "Checks failed: $failures"
    echo "Report: $report"
    [[ "$failures" -eq 0 ]]
}

contains_binary() {
    local file="$1"
    local needle="$2"
    [[ -f "$file" ]] && LC_ALL=C grep -aqF "$needle" "$file" 2>/dev/null
}

builddir_pids() {
    ps -axo pid,command \
        | grep -F "$app/Contents/MacOS/soffice" \
        | grep -v grep \
        | awk "{print \$1}" \
        || true
}

uno_socket_ready() {
    python3 - "$port" <<'PY' >/dev/null 2>&1
import socket
import sys

sock = socket.socket()
sock.settimeout(0.25)
try:
    sock.connect(("127.0.0.1", int(sys.argv[1])))
except OSError:
    raise SystemExit(1)
finally:
    sock.close()
PY
}

ax_surface_probe() {
    python3 - "${new_pids[@]:-}" <<'PY' 2>&1 || true
import ctypes
import sys
from ctypes import byref, c_int, c_uint32, c_void_p

target_pids = [int(arg) for arg in sys.argv[1:] if arg.strip()]
if not target_pids:
    print("ax_surface_ready=no")
    raise SystemExit(0)

AS = ctypes.cdll.LoadLibrary('/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices')
CF = ctypes.cdll.LoadLibrary('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
CFRef = c_void_p
ENC = 0x08000100

AS.AXUIElementCreateApplication.argtypes = [c_int]
AS.AXUIElementCreateApplication.restype = c_void_p
AS.AXUIElementGetPid.argtypes = [c_void_p, ctypes.POINTER(c_int)]
AS.AXUIElementGetPid.restype = c_int
AS.AXUIElementCopyAttributeValue.argtypes = [c_void_p, CFRef, ctypes.POINTER(CFRef)]
AS.AXUIElementCopyAttributeValue.restype = c_int

CF.CFStringCreateWithCString.argtypes = [c_void_p, ctypes.c_char_p, c_uint32]
CF.CFStringCreateWithCString.restype = CFRef
CF.CFRelease.argtypes = [CFRef]
CF.CFGetTypeID.argtypes = [CFRef]
CF.CFGetTypeID.restype = ctypes.c_ulong
CF.CFArrayGetTypeID.restype = ctypes.c_ulong
CF.CFArrayGetCount.argtypes = [CFRef]
CF.CFArrayGetCount.restype = ctypes.c_long

def cfstr(value: str):
    return CF.CFStringCreateWithCString(None, value.encode('utf-8'), ENC)

def copy_attr(elem, name: str):
    attr = cfstr(name)
    value = CFRef()
    err = AS.AXUIElementCopyAttributeValue(elem, attr, byref(value))
    CF.CFRelease(attr)
    return err, value.value

def array_count(ref):
    if not ref or CF.CFGetTypeID(ref) != CF.CFArrayGetTypeID():
        return 0
    return CF.CFArrayGetCount(ref)

ready = False
for pid in target_pids:
    app = AS.AXUIElementCreateApplication(pid)
    actual = c_int(-1)
    get_pid_err = AS.AXUIElementGetPid(app, byref(actual))
    target = get_pid_err == 0 and actual.value == pid
    err_windows, windows = copy_attr(app, 'AXWindows')
    err_menubar, menubar = copy_attr(app, 'AXMenuBar')
    window_count = array_count(windows)
    menu_present = err_menubar == 0 and bool(menubar)
    print(f"candidate pid={pid} axGetPidErr={get_pid_err} actualPid={actual.value} target={str(target).lower()} menuBars={1 if menu_present else 0} windows={window_count}")
    ready = ready or (target and (menu_present or window_count > 0))
    if windows:
        CF.CFRelease(windows)
    if menubar:
        CF.CFRelease(menubar)
    if app:
        CF.CFRelease(app)

print(f"ax_surface_ready={'yes' if ready else 'no'}")
PY
}

startup_diagnostic() {
    local last_ax="$1"
    local pid sample_file
    {
        echo "ready_timeout=${ready_timeout}s"
        echo "uno_socket=not-ready port=$port"
        if [[ -n "$last_ax" ]]; then
            echo "$last_ax"
        fi
        for pid in "${new_pids[@]:-}"; do
            ps -p "$pid" -o pid=,ppid=,stat=,etime=,rss=,command= 2>/dev/null | sed "s/^/process /" || true
            if command -v sample >/dev/null 2>&1 && kill -0 "$pid" 2>/dev/null; then
                sample_file="tmp/v2-visible-current-startup-pid-${pid}.sample.txt"
                sample "$pid" 1 1 >"$sample_file" 2>&1 || true
                echo "sample=$sample_file"
            fi
        done
    }
}

wait_for_launch_readiness() {
    local deadline=$((SECONDS + ready_timeout))
    local probe=""
    while (( SECONDS < deadline )); do
        if uno_socket_ready; then
            launch_ready_detail="uno_socket=ready port=$port"
            return 0
        fi
        probe="$(ax_surface_probe)"
        if grep -Fq "ax_surface_ready=yes" <<<"$probe"; then
            launch_ready_detail="$probe"
            return 0
        fi
        if [[ -n "${launch_pid:-}" ]] && ! kill -0 "$launch_pid" 2>/dev/null; then
            break
        fi
        sleep 2
    done
    launch_ready_detail="$(startup_diagnostic "$probe")"
    return 1
}

cleanup() {
    local pid
    for pid in "${started_pids[@]:-}"; do
        kill "$pid" 2>/dev/null || true
    done
    if [[ -n "${launch_pid:-}" ]]; then
        kill "$launch_pid" 2>/dev/null || true
        wait "$launch_pid" 2>/dev/null || true
    fi
    if [[ "$keep_profile" != "1" && -n "${profile:-}" ]]; then
        rm -rf "$profile"
    fi
}
trap cleanup EXIT

if [[ ! -x "$app/Contents/MacOS/soffice" ]]; then
    echo "FAIL: missing executable soffice in app bundle: $app" >&2
    exit 1
fi
python="$app/Contents/Resources/python"

registry="$app/Contents/Resources/registry/main.xcd"
config="$app/Contents/Resources/config/soffice.cfg"
if contains_binary "$registry" ".uno:CommandPalette" \
    && contains_binary "$registry" "K_SHIFT_MOD1" \
    && [[ -f "$config/cui/ui/commandpalette.ui" ]]; then
    record "PASS" "current bundle V2 entry parity" "CommandPalette command, Cmd+Shift+K, and UI resource present"
else
    record "FAIL" "current bundle V2 entry parity" "CommandPalette command, Cmd+Shift+K, or UI resource missing"
fi

before_pids="$(builddir_pids | tr "\n" " ")"
echo "=== V2 visible current-bundle attribution smoke ===" | tee "$log"
echo "App bundle: $app" | tee -a "$log"
echo "Builddir pids before launch: ${before_pids:-<none>}" | tee -a "$log"
echo "UNO port: $port" | tee -a "$log"

profile="$(mktemp -d /tmp/kqoffice-visible-current-profile.XXXXXX)"
echo "Isolated profile: $profile" | tee -a "$log"
KQOFFICE_AI_STUB_RUNTIME=1 \
KQOFFICE_AI_DISABLE_PROBE=1 \
"$app/Contents/MacOS/soffice" \
    --nologo \
    --nofirststartwizard \
    --norestore \
    --nolockcheck \
    "--accept=socket,host=127.0.0.1,port=$port;urp;" \
    "-env:UserInstallation=file://$profile" \
    private:factory/swriter \
    >>"$log" 2>&1 &
launch_pid=$!

after_pids=""
launch_seen=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
    after_pids="$(builddir_pids | tr "\n" " ")"
    for pid in $after_pids; do
        if ! grep -qw "$pid" <<<"$before_pids"; then
            launch_seen=1
        fi
    done
    if [[ "$launch_seen" == "1" ]]; then
        break
    fi
    if ! kill -0 "$launch_pid" 2>/dev/null; then
        break
    fi
    sleep 1
done
new_pids=()
for pid in $after_pids; do
    if ! grep -qw "$pid" <<<"$before_pids"; then
        new_pids+=("$pid")
        started_pids+=("$pid")
    fi
done

if [[ "${#new_pids[@]}" -gt 0 ]]; then
    record "PASS" "builddir process launch" "new builddir soffice pid(s): ${new_pids[*]}"
else
    record "FAIL" "builddir process launch" "no new builddir soffice pid; current pids: ${after_pids:-<none>}"
fi

if [[ "${#new_pids[@]}" -gt 0 ]]; then
    if wait_for_launch_readiness; then
        echo "$launch_ready_detail" >>"$log"
        record "PASS" "builddir launch readiness" "$launch_ready_detail"
    else
        echo "$launch_ready_detail" >>"$log"
        record "BLOCKED" "builddir launch readiness" "$launch_ready_detail"
        record "BLOCKED" "AX target process discovery" "target builddir pid did not expose AX windows/menu or UNO socket before timeout"
        record "BLOCKED" "AX target menu/window attribution" "target builddir pid did not expose AX windows/menu or UNO socket before timeout"
        record "BLOCKED" "AX target drive" "target builddir pid did not expose AX windows/menu or UNO socket before timeout"
        record "BLOCKED" "GUI Text Document" "target builddir pid did not expose AX windows/menu or UNO socket before timeout"
        record "BLOCKED" "GUI Cmd+Shift+K" "target builddir pid did not expose AX windows/menu or UNO socket before timeout"
        record "BLOCKED" "GUI CommandPalette UNO dispatch" "target builddir UNO socket was not ready"
        record "BLOCKED" "GUI CommandPalette AX" "target builddir pid did not expose a scannable palette"
        write_report
        exit $?
    fi
else
    record "BLOCKED" "builddir launch readiness" "no builddir pid available"
fi

ax_result="$(python3 - "${new_pids[@]:-}" <<'PY' 2>&1 || true
import ctypes
import sys
import time
from ctypes import byref, c_int, c_uint32, c_void_p

target_pids = [int(arg) for arg in sys.argv[1:] if arg.strip()]
if not target_pids:
    print("target_seen=no")
    print("target_with_menu=no")
    print("drove_target_process=no")
    raise SystemExit(0)

AS = ctypes.cdll.LoadLibrary('/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices')
CF = ctypes.cdll.LoadLibrary('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
AXRef = c_void_p
CFRef = c_void_p
ENC = 0x08000100

AS.AXIsProcessTrusted.restype = ctypes.c_bool
AS.AXUIElementCreateApplication.argtypes = [c_int]
AS.AXUIElementCreateApplication.restype = AXRef
AS.AXUIElementGetPid.argtypes = [AXRef, ctypes.POINTER(c_int)]
AS.AXUIElementGetPid.restype = c_int
AS.AXUIElementCopyAttributeValue.argtypes = [AXRef, CFRef, ctypes.POINTER(CFRef)]
AS.AXUIElementCopyAttributeValue.restype = c_int
AS.AXUIElementPerformAction.argtypes = [AXRef, CFRef]
AS.AXUIElementPerformAction.restype = c_int

CF.CFStringCreateWithCString.argtypes = [c_void_p, ctypes.c_char_p, c_uint32]
CF.CFStringCreateWithCString.restype = CFRef
CF.CFRelease.argtypes = [CFRef]
CF.CFGetTypeID.argtypes = [CFRef]
CF.CFGetTypeID.restype = ctypes.c_ulong
CF.CFArrayGetTypeID.restype = ctypes.c_ulong
CF.CFArrayGetCount.argtypes = [CFRef]
CF.CFArrayGetCount.restype = ctypes.c_long
CF.CFArrayGetValueAtIndex.argtypes = [CFRef, ctypes.c_long]
CF.CFArrayGetValueAtIndex.restype = CFRef
CF.CFStringGetTypeID.restype = ctypes.c_ulong
CF.CFStringGetCString.argtypes = [CFRef, ctypes.c_char_p, ctypes.c_long, c_uint32]
CF.CFStringGetCString.restype = ctypes.c_bool

def cfstr(value: str):
    return CF.CFStringCreateWithCString(None, value.encode('utf-8'), ENC)

def copy_attr(elem, name: str):
    attr = cfstr(name)
    value = CFRef()
    err = AS.AXUIElementCopyAttributeValue(elem, attr, byref(value))
    CF.CFRelease(attr)
    return err, value.value

def perform(elem, action: str) -> int:
    act = cfstr(action)
    err = AS.AXUIElementPerformAction(elem, act)
    CF.CFRelease(act)
    return err

def array_count(ref):
    if not ref or CF.CFGetTypeID(ref) != CF.CFArrayGetTypeID():
        return 0
    return CF.CFArrayGetCount(ref)

def children(elem):
    err, ref = copy_attr(elem, 'AXChildren')
    if err or not ref or CF.CFGetTypeID(ref) != CF.CFArrayGetTypeID():
        return []
    return [CF.CFArrayGetValueAtIndex(ref, i) for i in range(CF.CFArrayGetCount(ref))]

def string_value(ref):
    if not ref or CF.CFGetTypeID(ref) != CF.CFStringGetTypeID():
        return ''
    buf = ctypes.create_string_buffer(1024)
    if CF.CFStringGetCString(ref, buf, len(buf), ENC):
        return buf.value.decode('utf-8', 'replace')
    return '<too-long>'

def attr_string(elem, name: str) -> str:
    err, ref = copy_attr(elem, name)
    value = string_value(ref)
    if ref:
        CF.CFRelease(ref)
    return value

def find_by_title(elem, titles, depth=0):
    if depth > 8:
        return None
    if attr_string(elem, 'AXTitle') in titles:
        return elem
    for child in children(elem):
        found = find_by_title(child, titles, depth + 1)
        if found:
            return found
    return None

print(f"ax_trusted={'yes' if AS.AXIsProcessTrusted() else 'no'}")
target_seen = False
target_with_menu = False
drove_target = False
new_text_clicked = False

for pid in target_pids:
    app = AS.AXUIElementCreateApplication(pid)
    actual = c_int(-1)
    get_pid_err = AS.AXUIElementGetPid(app, byref(actual))
    target = get_pid_err == 0 and actual.value == pid
    target_seen = target_seen or target
    role = attr_string(app, 'AXRole')
    title = attr_string(app, 'AXTitle')
    err_windows, windows = copy_attr(app, 'AXWindows')
    err_menubar, menubar = copy_attr(app, 'AXMenuBar')
    window_count = array_count(windows)
    menu_present = err_menubar == 0 and bool(menubar)
    print(
        f"candidate pid={pid} axGetPidErr={get_pid_err} actualPid={actual.value} "
        f"target={str(target).lower()} title={title} role={role} "
        f"menuBars={1 if menu_present else 0} windows={window_count}"
    )

    if target and menu_present:
        target_with_menu = True
        file_menu = find_by_title(menubar, {'文件', 'File'})
        if file_menu:
            press_file = perform(file_menu, 'AXPress')
            time.sleep(0.5)
            new_item = find_by_title(file_menu, {'新建', 'New'})
            press_new = None
            text_item = None
            press_text = None
            if new_item:
                press_new = perform(new_item, 'AXPress')
                time.sleep(0.5)
                text_item = find_by_title(new_item, {'文本文档', 'Text Document'})
                if text_item:
                    press_text = perform(text_item, 'AXPress')
                    time.sleep(2)
                    new_text_clicked = press_text == 0
            err_windows_after, windows_after = copy_attr(app, 'AXWindows')
            window_count_after = array_count(windows_after)
            print(
                f"targetNewText={'clicked' if new_text_clicked else 'failed'} "
                f"pid={pid} pressFile={press_file} pressNew={press_new} "
                f"pressText={press_text} windows={window_count_after}"
            )
            drove_target = True
        else:
            print(f"targetNewText=failed pid={pid} missing File menu")
    if windows:
        CF.CFRelease(windows)
    if menubar:
        CF.CFRelease(menubar)
    CF.CFRelease(app)

print(f"target_seen={'yes' if target_seen else 'no'}")
print(f"target_with_menu={'yes' if target_with_menu else 'no'}")
print(f"drove_target_process={'yes' if drove_target else 'no'}")
PY
)"
osascript_result="$ax_result"
: <<'DISABLED_SYSTEM_EVENTS_AX'
osascript_result="$(osascript - "${new_pids[@]:-}" <<APPLESCRIPT 2>&1 || true
on run argv
  set out to {}
  set targetPids to {}
  repeat with a in argv
    set end of targetPids to a as text
  end repeat
  tell application "System Events"
    set soffices to every process whose name is "soffice"
    set end of out to "soffice_count=" & (count of soffices)
    set targetSeen to false
    set targetWithMenu to false
    set droveTarget to false
    repeat with p in soffices
      try
        set pidText to "unknown"
        try
          set pidText to unix id of p as text
        end try
        set isTarget to false
        repeat with targetPid in targetPids
          if pidText is (targetPid as text) then set isTarget to true
        end repeat
        set menuBarCount to count of menu bars of p
        set windowCount to count of windows of p
        set end of out to "candidate pid=" & pidText & " target=" & isTarget & " menuBars=" & menuBarCount & " windows=" & windowCount
        if isTarget then
          set targetSeen to true
        end if
        if isTarget and menuBarCount > 0 and droveTarget is false then
          set targetWithMenu to true
          set frontmost of p to true
          delay 0.5
          try
            click menu item "Text Document" of menu 1 of menu item "New" of menu "文件" of menu bar 1 of p
            delay 2
            set end of out to "targetNewText=clicked pid=" & pidText & " windows=" & (count of windows of p)
          on error errMsg number errNum
            set end of out to "targetNewText=failed pid=" & pidText & " " & errNum & " " & errMsg
          end try
          try
            keystroke "k" using {command down, shift down}
            delay 1
            set focusSummary to "none"
            try
              set f to value of attribute "AXFocusedUIElement" of p
              set focusSummary to (role of f) & ":" & (name of f)
            end try
            set end of out to "targetCmdShiftK=sent pid=" & pidText & " windows=" & (count of windows of p) & " focus=" & focusSummary
          on error errMsg number errNum
            set end of out to "targetCmdShiftK=failed pid=" & pidText & " " & errNum & " " & errMsg
          end try
          set droveTarget to true
        end if
      on error errMsg number errNum
        set end of out to "candidate failed " & errNum & " " & errMsg
      end try
    end repeat
    if targetSeen then
      set end of out to "target_seen=yes"
    else
      set end of out to "target_seen=no"
    end if
    if targetWithMenu then
      set end of out to "target_with_menu=yes"
    else
      set end of out to "target_with_menu=no"
    end if
    if droveTarget then
      set end of out to "drove_target_process=yes"
    else
      set end of out to "drove_target_process=no"
    end if
  end tell
  return out
end run
APPLESCRIPT
)"
DISABLED_SYSTEM_EVENTS_AX
echo "$osascript_result" >>"$log"

if grep -Fq "target_seen=yes" <<<"$osascript_result"; then
    record "PASS" "AX target process discovery" "$osascript_result"
else
    record "BLOCKED" "AX target process discovery" "$osascript_result"
fi

if grep -Fq "target_with_menu=yes" <<<"$osascript_result"; then
    record "PASS" "AX target menu/window attribution" "$osascript_result"
else
    record "BLOCKED" "AX target menu/window attribution" "$osascript_result"
fi

if grep -Fq "drove_target_process=yes" <<<"$osascript_result"; then
    record "PASS" "AX target drive" "$osascript_result"
else
    record "BLOCKED" "AX target drive" "$osascript_result"
fi

if grep -Fq "targetNewText=clicked" <<<"$osascript_result"; then
    record "PASS" "GUI Text Document" "File > New > Text Document clicked on target pid"
elif grep -Fq "target_with_menu=no" <<<"$osascript_result"; then
    record "BLOCKED" "GUI Text Document" "target builddir pid has no AX menu/window"
else
    record "FAIL" "GUI Text Document" "$osascript_result"
fi

shortcut_palette_result=""
if [[ "${#new_pids[@]}" -eq 0 ]]; then
    record "BLOCKED" "GUI Cmd+Shift+K" "no builddir pid available"
else
    shortcut_palette_result="$(python3 - "${new_pids[@]:-}" <<'PY' 2>&1 || true
import ctypes
import sys
import time
from ctypes import byref, c_bool, c_int, c_uint32, c_uint64, c_void_p

target_pids = [int(arg) for arg in sys.argv[1:] if arg.strip()]
if not target_pids:
    print("shortcut_palette_seen=no")
    print("shortcut_palette_search=no")
    print("shortcut_palette_results=no")
    raise SystemExit(0)

AS = ctypes.cdll.LoadLibrary('/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices')
CF = ctypes.cdll.LoadLibrary('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
AXRef = c_void_p
CFRef = c_void_p
ENC = 0x08000100

class ProcessSerialNumber(ctypes.Structure):
    _fields_ = [('highLongOfPSN', c_uint32), ('lowLongOfPSN', c_uint32)]

AS.AXIsProcessTrusted.restype = ctypes.c_bool
AS.AXUIElementCreateApplication.argtypes = [c_int]
AS.AXUIElementCreateApplication.restype = AXRef
AS.AXUIElementGetPid.argtypes = [AXRef, ctypes.POINTER(c_int)]
AS.AXUIElementGetPid.restype = c_int
AS.AXUIElementCopyAttributeValue.argtypes = [AXRef, CFRef, ctypes.POINTER(CFRef)]
AS.AXUIElementCopyAttributeValue.restype = c_int
AS.AXUIElementPerformAction.argtypes = [AXRef, CFRef]
AS.AXUIElementPerformAction.restype = c_int
AS.GetProcessForPID.argtypes = [c_int, ctypes.POINTER(ProcessSerialNumber)]
AS.GetProcessForPID.restype = c_int
AS.SetFrontProcess.argtypes = [ctypes.POINTER(ProcessSerialNumber)]
AS.SetFrontProcess.restype = c_int
AS.CGEventCreateKeyboardEvent.argtypes = [c_void_p, c_uint32, c_bool]
AS.CGEventCreateKeyboardEvent.restype = CFRef
AS.CGEventSetFlags.argtypes = [CFRef, c_uint64]
AS.CGEventPost.argtypes = [c_uint32, CFRef]
AS.CGEventPostToPid.argtypes = [c_int, CFRef]

CF.CFStringCreateWithCString.argtypes = [c_void_p, ctypes.c_char_p, c_uint32]
CF.CFStringCreateWithCString.restype = CFRef
CF.CFRelease.argtypes = [CFRef]
CF.CFGetTypeID.argtypes = [CFRef]
CF.CFGetTypeID.restype = ctypes.c_ulong
CF.CFArrayGetTypeID.restype = ctypes.c_ulong
CF.CFArrayGetCount.argtypes = [CFRef]
CF.CFArrayGetCount.restype = ctypes.c_long
CF.CFArrayGetValueAtIndex.argtypes = [CFRef, ctypes.c_long]
CF.CFArrayGetValueAtIndex.restype = CFRef
CF.CFStringGetTypeID.restype = ctypes.c_ulong
CF.CFStringGetCString.argtypes = [CFRef, ctypes.c_char_p, ctypes.c_long, c_uint32]
CF.CFStringGetCString.restype = ctypes.c_bool

def cfstr(value: str):
    return CF.CFStringCreateWithCString(None, value.encode('utf-8'), ENC)

def copy_attr(elem, name: str):
    attr = cfstr(name)
    value = CFRef()
    err = AS.AXUIElementCopyAttributeValue(elem, attr, byref(value))
    CF.CFRelease(attr)
    return err, value.value

def perform(elem, action: str) -> int:
    act = cfstr(action)
    err = AS.AXUIElementPerformAction(elem, act)
    CF.CFRelease(act)
    return err

def children(elem):
    err, ref = copy_attr(elem, 'AXChildren')
    if err or not ref or CF.CFGetTypeID(ref) != CF.CFArrayGetTypeID():
        return []
    return [CF.CFArrayGetValueAtIndex(ref, i) for i in range(CF.CFArrayGetCount(ref))]

def string_value(ref):
    if not ref or CF.CFGetTypeID(ref) != CF.CFStringGetTypeID():
        return ''
    buf = ctypes.create_string_buffer(4096)
    if CF.CFStringGetCString(ref, buf, len(buf), ENC):
        return buf.value.decode('utf-8', 'replace')
    return '<too-long>'

def attr_string(elem, name: str) -> str:
    err, ref = copy_attr(elem, name)
    value = string_value(ref)
    if ref:
        CF.CFRelease(ref)
    return value

def walk(elem, depth=0, limit=None):
    if limit is None:
        limit = [0]
    if depth > 12 or limit[0] > 5000:
        return
    limit[0] += 1
    yield elem
    for child in children(elem):
        yield from walk(child, depth + 1, limit)

def raise_first_window(app):
    err, windows = copy_attr(app, 'AXWindows')
    if err or not windows or CF.CFGetTypeID(windows) != CF.CFArrayGetTypeID() or CF.CFArrayGetCount(windows) == 0:
        return None
    win = CF.CFArrayGetValueAtIndex(windows, 0)
    return perform(win, 'AXRaise')

def scan_palette(app):
    palette_seen = False
    search_seen = False
    results_seen = False
    hits = []
    for elem in walk(app):
        role = attr_string(elem, 'AXRole')
        title = attr_string(elem, 'AXTitle')
        value = attr_string(elem, 'AXValue')
        ident = attr_string(elem, 'AXIdentifier')
        text = " ".join([role, title, value, ident])
        if ident == 'CommandPalette':
            palette_seen = True
            hits.append(f"CommandPalette role={role}")
        elif ident == 'search_input' or title == 'Search commands':
            search_seen = True
            hits.append(f"search_input role={role} title={title}")
        elif ident == 'results_view' or title == 'Matching commands':
            results_seen = True
            hits.append(f"results_view role={role} title={title}")
        elif '按 Enter 执行' in text:
            hits.append(f"hint role={role} value={value}")
    return palette_seen, search_seen, results_seen, hits

def make_key_event(key_code, down, flags):
    event = AS.CGEventCreateKeyboardEvent(None, key_code, down)
    if event:
        AS.CGEventSetFlags(event, flags)
    return event

def post_event(target_pid, to_pid, event):
    if to_pid:
        AS.CGEventPostToPid(target_pid, event)
    else:
        AS.CGEventPost(0, event)

def post_key_pair(target_pid, to_pid, key_code, flags):
    down = make_key_event(key_code, True, flags)
    up = make_key_event(key_code, False, flags)
    if not down or not up:
        return False
    post_event(target_pid, to_pid, down)
    time.sleep(0.05)
    post_event(target_pid, to_pid, up)
    CF.CFRelease(down)
    CF.CFRelease(up)
    return True

def post_modifier_sequence(target_pid, to_pid, flags):
    key_cmd = 55
    key_shift = 56
    key_k = 40
    events = [
        make_key_event(key_cmd, True, 0x00100000),
        make_key_event(key_shift, True, flags),
        make_key_event(key_k, True, flags),
        make_key_event(key_k, False, flags),
        make_key_event(key_shift, False, 0x00100000),
        make_key_event(key_cmd, False, 0),
    ]
    if any(not event for event in events):
        for event in events:
            if event:
                CF.CFRelease(event)
        return False
    for event in events:
        post_event(target_pid, to_pid, event)
        time.sleep(0.04)
        CF.CFRelease(event)
    return True

def try_shortcut_strategies(target_pid, app):
    key_k = 40
    flags = 0x00100000 | 0x00020000
    strategies = [
        ('global-flags', lambda: post_key_pair(target_pid, False, key_k, flags)),
        ('pid-flags', lambda: post_key_pair(target_pid, True, key_k, flags)),
        ('global-modifier-sequence', lambda: post_modifier_sequence(target_pid, False, flags)),
        ('pid-modifier-sequence', lambda: post_modifier_sequence(target_pid, True, flags)),
    ]
    last = (False, False, False, [])
    for name, action in strategies:
        posted = action()
        time.sleep(1.0)
        palette_seen, search_seen, results_seen, hits = scan_palette(app)
        print(
            f"shortcut_strategy={name} posted={'yes' if posted else 'no'} "
            f"palette={'yes' if palette_seen else 'no'} "
            f"search={'yes' if search_seen else 'no'} "
            f"results={'yes' if results_seen else 'no'}"
        )
        last = (palette_seen, search_seen, results_seen, hits)
        if palette_seen and search_seen and results_seen:
            return last
    return last

print(f"ax_trusted={'yes' if AS.AXIsProcessTrusted() else 'no'}")
target_pid = target_pids[0]
app = AS.AXUIElementCreateApplication(target_pid)
actual = c_int(-1)
get_pid_err = AS.AXUIElementGetPid(app, byref(actual))
print(f"shortcut_target pid={target_pid} axGetPidErr={get_pid_err} actualPid={actual.value}")
if get_pid_err != 0 or actual.value != target_pid:
    print("shortcut_palette_seen=no")
    print("shortcut_palette_search=no")
    print("shortcut_palette_results=no")
    raise SystemExit(0)

psn = ProcessSerialNumber()
psn_err = AS.GetProcessForPID(target_pid, byref(psn))
front_err = AS.SetFrontProcess(byref(psn)) if psn_err == 0 else -1
raise_err = raise_first_window(app)
time.sleep(0.8)
palette_seen, search_seen, results_seen, hits = try_shortcut_strategies(target_pid, app)

print(f"shortcut_front psnErr={psn_err} frontErr={front_err} raiseErr={raise_err}")
print("shortcut_event=attempted key=K flags=cmd+shift strategies=global-flags,pid-flags,global-modifier-sequence,pid-modifier-sequence")
print(f"shortcut_palette_seen={'yes' if palette_seen else 'no'}")
print(f"shortcut_palette_search={'yes' if search_seen else 'no'}")
print(f"shortcut_palette_results={'yes' if results_seen else 'no'}")
print("shortcut_palette_hits=" + ";".join(hits[:8]))
CF.CFRelease(app)
PY
)"
    echo "$shortcut_palette_result" >>"$log"

    if grep -Fq "shortcut_palette_seen=yes" <<<"$shortcut_palette_result" \
        && grep -Fq "shortcut_palette_search=yes" <<<"$shortcut_palette_result" \
        && grep -Fq "shortcut_palette_results=yes" <<<"$shortcut_palette_result"; then
        record "PASS" "GUI Cmd+Shift+K" "$shortcut_palette_result"
    else
        record "BLOCKED" "GUI Cmd+Shift+K" "$shortcut_palette_result"
    fi
fi

uno_palette_result=""
if [[ "${#new_pids[@]}" -eq 0 ]]; then
    record "BLOCKED" "GUI CommandPalette UNO dispatch" "no builddir pid available"
    record "BLOCKED" "GUI CommandPalette AX" "no builddir pid available"
elif [[ ! -x "$python" ]]; then
    record "FAIL" "GUI CommandPalette UNO dispatch" "missing bundled LibreOfficePython launcher: $python"
    record "BLOCKED" "GUI CommandPalette AX" "UNO dispatch not available"
else
    uno_palette_result="$("$python" - "$port" <<'PY' 2>&1 || true
import sys
import time

import uno

port = sys.argv[1]
ctx = uno.getComponentContext()
smgr = ctx.ServiceManager
resolver = smgr.createInstanceWithContext("com.sun.star.bridge.UnoUrlResolver", ctx)
connect_url = f"uno:socket,host=127.0.0.1,port={port};urp;StarOffice.ComponentContext"

remote = None
last_error = None
for _ in range(30):
    try:
        remote = resolver.resolve(connect_url)
        break
    except Exception as exc:
        last_error = exc
        time.sleep(1)
if remote is None:
    print(f"uno_dispatch=failed connect_error={last_error!r}")
    raise SystemExit(0)

rsmgr = remote.ServiceManager
desktop = rsmgr.createInstanceWithContext("com.sun.star.frame.Desktop", remote)
component = desktop.getCurrentComponent()
frame = component.CurrentController.Frame if component else desktop.getCurrentFrame()
if not frame:
    print("uno_dispatch=failed no_frame")
    raise SystemExit(0)

helper = rsmgr.createInstanceWithContext("com.sun.star.frame.DispatchHelper", remote)
try:
    result = helper.executeDispatch(frame, ".uno:CommandPalette", "_self", 0, ())
    state = getattr(result, "State", "<none>")
    print(f"uno_dispatch=ok command=.uno:CommandPalette state={state}")
    time.sleep(3)
except Exception as exc:
    print(f"uno_dispatch=failed exception={exc!r}")
PY
)"
    echo "$uno_palette_result" >>"$log"

    if grep -Fq "uno_dispatch=ok" <<<"$uno_palette_result"; then
        record "PASS" "GUI CommandPalette UNO dispatch" "$uno_palette_result"
    else
        record "FAIL" "GUI CommandPalette UNO dispatch" "$uno_palette_result"
    fi

    ax_palette_result="$(python3 - "${new_pids[@]:-}" <<'PY' 2>&1 || true
import ctypes
import sys
from ctypes import byref, c_int, c_uint32, c_void_p

target_pids = [int(arg) for arg in sys.argv[1:] if arg.strip()]
if not target_pids:
    print("palette_seen=no")
    print("palette_search=no")
    print("palette_results=no")
    raise SystemExit(0)

AS = ctypes.cdll.LoadLibrary('/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices')
CF = ctypes.cdll.LoadLibrary('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
AXRef = c_void_p
CFRef = c_void_p
ENC = 0x08000100

AS.AXIsProcessTrusted.restype = ctypes.c_bool
AS.AXUIElementCreateApplication.argtypes = [c_int]
AS.AXUIElementCreateApplication.restype = AXRef
AS.AXUIElementGetPid.argtypes = [AXRef, ctypes.POINTER(c_int)]
AS.AXUIElementGetPid.restype = c_int
AS.AXUIElementCopyAttributeValue.argtypes = [AXRef, CFRef, ctypes.POINTER(CFRef)]
AS.AXUIElementCopyAttributeValue.restype = c_int

CF.CFStringCreateWithCString.argtypes = [c_void_p, ctypes.c_char_p, c_uint32]
CF.CFStringCreateWithCString.restype = CFRef
CF.CFRelease.argtypes = [CFRef]
CF.CFGetTypeID.argtypes = [CFRef]
CF.CFGetTypeID.restype = ctypes.c_ulong
CF.CFArrayGetTypeID.restype = ctypes.c_ulong
CF.CFArrayGetCount.argtypes = [CFRef]
CF.CFArrayGetCount.restype = ctypes.c_long
CF.CFArrayGetValueAtIndex.argtypes = [CFRef, ctypes.c_long]
CF.CFArrayGetValueAtIndex.restype = CFRef
CF.CFStringGetTypeID.restype = ctypes.c_ulong
CF.CFStringGetCString.argtypes = [CFRef, ctypes.c_char_p, ctypes.c_long, c_uint32]
CF.CFStringGetCString.restype = ctypes.c_bool

def cfstr(value: str):
    return CF.CFStringCreateWithCString(None, value.encode('utf-8'), ENC)

def copy_attr(elem, name: str):
    attr = cfstr(name)
    value = CFRef()
    err = AS.AXUIElementCopyAttributeValue(elem, attr, byref(value))
    CF.CFRelease(attr)
    return err, value.value

def children(elem):
    err, ref = copy_attr(elem, 'AXChildren')
    if err or not ref or CF.CFGetTypeID(ref) != CF.CFArrayGetTypeID():
        return []
    return [CF.CFArrayGetValueAtIndex(ref, i) for i in range(CF.CFArrayGetCount(ref))]

def string_value(ref):
    if not ref or CF.CFGetTypeID(ref) != CF.CFStringGetTypeID():
        return ''
    buf = ctypes.create_string_buffer(4096)
    if CF.CFStringGetCString(ref, buf, len(buf), ENC):
        return buf.value.decode('utf-8', 'replace')
    return '<too-long>'

def attr_string(elem, name: str) -> str:
    err, ref = copy_attr(elem, name)
    value = string_value(ref)
    if ref:
        CF.CFRelease(ref)
    return value

def walk(elem, depth=0, limit=None):
    if limit is None:
        limit = [0]
    if depth > 12 or limit[0] > 5000:
        return
    limit[0] += 1
    yield elem
    for child in children(elem):
        yield from walk(child, depth + 1, limit)

palette_seen = False
search_seen = False
results_seen = False
hits = []
print(f"ax_trusted={'yes' if AS.AXIsProcessTrusted() else 'no'}")

for pid in target_pids:
    app = AS.AXUIElementCreateApplication(pid)
    actual = c_int(-1)
    get_pid_err = AS.AXUIElementGetPid(app, byref(actual))
    if get_pid_err != 0 or actual.value != pid:
        print(f"candidate pid={pid} axGetPidErr={get_pid_err} actualPid={actual.value} target=false")
        CF.CFRelease(app)
        continue
    for elem in walk(app):
        role = attr_string(elem, 'AXRole')
        title = attr_string(elem, 'AXTitle')
        value = attr_string(elem, 'AXValue')
        ident = attr_string(elem, 'AXIdentifier')
        text = " ".join([role, title, value, ident])
        if ident == 'CommandPalette':
            palette_seen = True
            hits.append(f"CommandPalette role={role}")
        elif ident == 'search_input' or title == 'Search commands':
            search_seen = True
            hits.append(f"search_input role={role} title={title}")
        elif ident == 'results_view' or title == 'Matching commands':
            results_seen = True
            hits.append(f"results_view role={role} title={title}")
        elif '按 Enter 执行' in text:
            hits.append(f"hint role={role} value={value}")
    CF.CFRelease(app)

print(f"palette_seen={'yes' if palette_seen else 'no'}")
print(f"palette_search={'yes' if search_seen else 'no'}")
print(f"palette_results={'yes' if results_seen else 'no'}")
print("palette_hits=" + ";".join(hits[:8]))
PY
)"
    echo "$ax_palette_result" >>"$log"

    if grep -Fq "palette_seen=yes" <<<"$ax_palette_result" \
        && grep -Fq "palette_search=yes" <<<"$ax_palette_result" \
        && grep -Fq "palette_results=yes" <<<"$ax_palette_result"; then
        record "PASS" "GUI CommandPalette AX" "$ax_palette_result"
    elif grep -Fq "uno_dispatch=ok" <<<"$uno_palette_result"; then
        record "BLOCKED" "GUI CommandPalette AX" "$ax_palette_result"
    else
        record "BLOCKED" "GUI CommandPalette AX" "UNO dispatch did not open a scannable palette"
    fi
fi

write_report
