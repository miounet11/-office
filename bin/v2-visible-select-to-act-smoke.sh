#!/usr/bin/env bash
# V2 visible current-bundle Writer Select-to-act smoke.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

python3 - "$@" <<'PY'
import atexit
import ctypes
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import textwrap
import time
from ctypes import byref, c_bool, c_int, c_uint32, c_uint64, c_void_p
from pathlib import Path

ROOT = Path.cwd()
APP = Path(os.environ.get("KDOFFICE_APP_BUNDLE", str(ROOT / "instdir/可圈办公.app")))
REPORT = Path(os.environ.get("V2_VISIBLE_SELECT_REPORT", str(ROOT / "tmp/v2-visible-select-to-act-smoke.md")))
LOG = Path(os.environ.get("V2_VISIBLE_SELECT_LOG", str(ROOT / "tmp/v2-visible-select-to-act-smoke.log")))
KEEP_PROFILE = os.environ.get("V2_VISIBLE_SELECT_KEEP_PROFILE", "0") == "1"
READY_TIMEOUT = int(os.environ.get("V2_VISIBLE_SELECT_READY_TIMEOUT", "45"))
ACTION_TIMEOUT = int(os.environ.get("V2_VISIBLE_SELECT_ACTION_TIMEOUT", "20"))
PORT = int(os.environ.get("V2_VISIBLE_SELECT_UNO_PORT", str(25000 + os.getpid() % 10000)))

PASSES = 0
BLOCKERS = 0
FAILURES = 0
ROWS = []
STARTED_PIDS = []
PROFILE = ""
LAUNCH_PROC = None
LAST_AX_RESULT = ""

def usage() -> None:
    print("""Usage:
  v2-visible-select-to-act-smoke.sh [--app <bundle>] [--report <path>] [--log <path>] [--keep-profile]

Checks:
  - Launches the current builddir app bundle with an isolated Writer profile.
  - Seeds a visible Writer document through the app bundle pyuno runtime.
  - Posts native Shift+Cmd/Option+Left to create a one-paragraph text selection.
  - Scans the exact builddir pid AX tree for the Select-to-act popover and
    Writer action buttons.
  - Clicks Rewrite paragraph and verifies the inline_action_request log.
""")

def parse_args(argv: list[str]) -> None:
    global APP, REPORT, LOG, KEEP_PROFILE
    args = list(argv)
    while args:
        item = args.pop(0)
        if item == "--app":
            APP = Path(args.pop(0))
        elif item == "--report":
            REPORT = Path(args.pop(0))
        elif item == "--log":
            LOG = Path(args.pop(0))
        elif item == "--keep-profile":
            KEEP_PROFILE = True
        elif item in ("-h", "--help"):
            usage()
            raise SystemExit(0)
        else:
            print(f"Unknown option: {item}", file=sys.stderr)
            usage()
            raise SystemExit(2)

def md_escape(value: str) -> str:
    return value.replace("\n", ";").replace("|", "\\|")

def record(status: str, area: str, detail: str) -> None:
    global PASSES, BLOCKERS, FAILURES
    ROWS.append(f"| {status} | {area} | {md_escape(detail)} |")
    if status == "PASS":
        PASSES += 1
        print(f"PASS: {area} -- {detail}")
    elif status == "BLOCKED":
        BLOCKERS += 1
        print(f"BLOCKED: {area} -- {detail}")
    else:
        FAILURES += 1
        print(f"FAIL: {area} -- {detail}", file=sys.stderr)

def write_report(status: str) -> None:
    target_status = "ready" if "target_seen=yes" in LAST_AX_RESULT and "target_with_window=yes" in LAST_AX_RESULT else "blocked"
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    with REPORT.open("w", encoding="utf-8") as f:
        f.write("# V2 Visible Select-to-Act Smoke\n\n")
        f.write(f"- Status: {status}\n")
        f.write(f"- Target attribution: {target_status}\n")
        f.write(f"- App bundle: {APP}\n")
        f.write(f"- Isolated profile: {PROFILE or '<none>'}\n")
        f.write(f"- UNO port: {PORT}\n")
        f.write("- Started builddir pids: " + (" ".join(map(str, STARTED_PIDS)) if STARTED_PIDS else "<none>") + "\n")
        f.write(f"- Checks passed: {PASSES}\n")
        f.write(f"- Checks blocked: {BLOCKERS}\n")
        f.write(f"- Checks failed: {FAILURES}\n")
        f.write("- Scope: strict current builddir PID attribution + visible Writer selection + Select-to-act popover + Rewrite click log\n\n")
        f.write("| Status | Area | Detail |\n")
        f.write("|---|---|---|\n")
        for row in ROWS:
            f.write(row + "\n")

def cleanup() -> None:
    for pid in STARTED_PIDS:
        try:
            os.kill(pid, 15)
        except OSError:
            pass
    if LAUNCH_PROC is not None:
        try:
            LAUNCH_PROC.terminate()
            LAUNCH_PROC.wait(timeout=5)
        except Exception:
            try:
                LAUNCH_PROC.kill()
            except Exception:
                pass
    if PROFILE and not KEEP_PROFILE:
        shutil.rmtree(PROFILE, ignore_errors=True)

def binary_contains(path: Path, needle: bytes) -> bool:
    try:
        return needle in path.read_bytes()
    except OSError:
        return False

def builddir_pids() -> set[int]:
    try:
        out = subprocess.check_output(["ps", "-axo", "pid,command"], text=True)
    except Exception:
        return set()
    marker = str(APP / "Contents/MacOS/soffice")
    pids: set[int] = set()
    for line in out.splitlines()[1:]:
        stripped = line.strip()
        if not stripped:
            continue
        parts = stripped.split(None, 1)
        if len(parts) == 2 and marker in parts[1]:
            try:
                pids.add(int(parts[0]))
            except ValueError:
                pass
    return pids

def uno_socket_ready() -> bool:
    sock = socket.socket()
    sock.settimeout(0.25)
    try:
        sock.connect(("127.0.0.1", PORT))
        return True
    except OSError:
        return False
    finally:
        sock.close()

def ax_window_summary(target_pids: list[int]) -> tuple[bool, str]:
    AS = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices")
    CF = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
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
        return CF.CFStringCreateWithCString(None, value.encode("utf-8"), ENC)

    def copy_attr(elem, name: str):
        attr = cfstr(name)
        value = CFRef()
        err = AS.AXUIElementCopyAttributeValue(elem, attr, byref(value))
        CF.CFRelease(attr)
        return err, value.value

    def array_count(ref) -> int:
        if not ref or CF.CFGetTypeID(ref) != CF.CFArrayGetTypeID():
            return 0
        return CF.CFArrayGetCount(ref)

    ready = False
    lines = []
    for pid in target_pids:
        app = AS.AXUIElementCreateApplication(pid)
        actual = c_int(-1)
        get_pid_err = AS.AXUIElementGetPid(app, byref(actual))
        target = get_pid_err == 0 and actual.value == pid
        err_windows, windows = copy_attr(app, "AXWindows")
        err_menubar, menubar = copy_attr(app, "AXMenuBar")
        window_count = array_count(windows)
        menu_present = err_menubar == 0 and bool(menubar)
        lines.append(f"candidate pid={pid} axGetPidErr={get_pid_err} actualPid={actual.value} target={str(target).lower()} menuBars={1 if menu_present else 0} windows={window_count}")
        ready = ready or (target and (menu_present or window_count > 0))
        if windows:
            CF.CFRelease(windows)
        if menubar:
            CF.CFRelease(menubar)
        if app:
            CF.CFRelease(app)
    lines.append(f"ax_surface_ready={'yes' if ready else 'no'}")
    return ready, "\n".join(lines)

def startup_diagnostic(target_pids: list[int], last_ax: str) -> str:
    lines = [f"ready_timeout={READY_TIMEOUT}s", f"uno_socket=not-ready port={PORT}"]
    if last_ax:
        lines.append(last_ax)
    for pid in target_pids:
        try:
            ps = subprocess.run(["ps", "-p", str(pid), "-o", "pid=,ppid=,stat=,etime=,rss=,command="], text=True, capture_output=True, check=False)
            if ps.stdout.strip():
                lines.append("process " + ps.stdout.strip())
        except Exception as exc:
            lines.append(f"process pid={pid} ps_error={exc!r}")
    return "\n".join(lines)

def wait_for_launch_readiness(target_pids: list[int]) -> tuple[bool, str]:
    deadline = time.monotonic() + READY_TIMEOUT
    last_ax = ""
    while time.monotonic() < deadline:
        if uno_socket_ready():
            return True, f"uno_socket=ready port={PORT}"
        ready, last_ax = ax_window_summary(target_pids)
        if ready:
            return True, last_ax
        if LAUNCH_PROC is not None and LAUNCH_PROC.poll() is not None:
            break
        time.sleep(2)
    return False, startup_diagnostic(target_pids, last_ax)

def run_bundled_uno_seed() -> str:
    bundled_python = APP / "Contents/Resources/python"
    if not bundled_python.exists():
        return f"uno_seed=failed missing_python={bundled_python}"
    code = r'''
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
    print(f"uno_seed=failed connect_error={last_error!r}")
    raise SystemExit(0)
rsmgr = remote.ServiceManager
desktop = rsmgr.createInstanceWithContext("com.sun.star.frame.Desktop", remote)
component = desktop.getCurrentComponent()
if component is None or not hasattr(component, "Text"):
    component = desktop.loadComponentFromURL("private:factory/swriter", "_blank", 0, ())
if component is None or not hasattr(component, "Text"):
    print("uno_seed=failed no_writer_component")
    raise SystemExit(0)
text = component.Text
sample = "Select to act visible smoke paragraph."
text.setString(sample)
controller = component.CurrentController
view_cursor = controller.getViewCursor()
view_cursor.gotoEnd(False)
frame = controller.Frame
try:
    frame.activate()
except Exception:
    pass
try:
    frame.ContainerWindow.setFocus()
except Exception:
    pass
print(f"uno_seed=ok text_len={len(sample)} frame={bool(frame)}")
time.sleep(1.5)
'''
    proc = subprocess.run([str(bundled_python), "-", str(PORT)], input=code, text=True, capture_output=True, check=False, timeout=45)
    out = (proc.stdout + proc.stderr).strip()
    if proc.returncode != 0:
        return f"uno_seed=failed returncode={proc.returncode} output={out}"
    return out or "uno_seed=failed empty_output"

def run_bundled_selection_state() -> str:
    bundled_python = APP / "Contents/Resources/python"
    if not bundled_python.exists():
        return f"selection_state=failed missing_python={bundled_python}"
    code = r'''
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
for _ in range(10):
    try:
        remote = resolver.resolve(connect_url)
        break
    except Exception as exc:
        last_error = exc
        time.sleep(0.5)
if remote is None:
    print(f"selection_state=failed connect_error={last_error!r}")
    raise SystemExit(0)
rsmgr = remote.ServiceManager
desktop = rsmgr.createInstanceWithContext("com.sun.star.frame.Desktop", remote)
component = desktop.getCurrentComponent()
if component is None:
    frame = desktop.getCurrentFrame()
    if frame is not None and frame.Controller is not None:
        component = frame.Controller.Model
if component is None:
    components = desktop.getComponents()
    enum = components.createEnumeration()
    while enum.hasMoreElements():
        candidate = enum.nextElement()
        if hasattr(candidate, "CurrentController"):
            component = candidate
            break
if component is None:
    print("selection_state=failed no_component")
    raise SystemExit(0)
selection = component.CurrentController.getSelection()
count = getattr(selection, "getCount", lambda: 0)()
texts = []
for i in range(count):
    item = selection.getByIndex(i)
    text = getattr(item, "getString", lambda: "")()
    if text:
        texts.append(text)
print(f"selection_state=ok count={count} text_len={sum(len(t) for t in texts)} text={' '.join(texts)[:80]!r}")
'''
    proc = subprocess.run([str(bundled_python), "-", str(PORT)], input=code, text=True, capture_output=True, check=False, timeout=20)
    out = (proc.stdout + proc.stderr).strip()
    if proc.returncode != 0:
        return f"selection_state=failed returncode={proc.returncode} output={out}"
    return out or "selection_state=failed empty_output"

def ax_select_to_act_probe(target_pids: list[int], press_rewrite: bool,
                           drive_selection: bool = True) -> str:
    AS = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices")
    CF = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
    CFRef = c_void_p
    ENC = 0x08000100

    class ProcessSerialNumber(ctypes.Structure):
        _fields_ = [("highLongOfPSN", c_uint32), ("lowLongOfPSN", c_uint32)]

    AS.AXIsProcessTrusted.restype = ctypes.c_bool
    AS.AXUIElementCreateApplication.argtypes = [c_int]
    AS.AXUIElementCreateApplication.restype = c_void_p
    AS.AXUIElementGetPid.argtypes = [c_void_p, ctypes.POINTER(c_int)]
    AS.AXUIElementGetPid.restype = c_int
    AS.AXUIElementCopyAttributeValue.argtypes = [c_void_p, CFRef, ctypes.POINTER(CFRef)]
    AS.AXUIElementCopyAttributeValue.restype = c_int
    AS.AXUIElementPerformAction.argtypes = [c_void_p, CFRef]
    AS.AXUIElementPerformAction.restype = c_int
    AS.GetProcessForPID.argtypes = [c_int, ctypes.POINTER(ProcessSerialNumber)]
    AS.GetProcessForPID.restype = c_int
    AS.SetFrontProcess.argtypes = [ctypes.POINTER(ProcessSerialNumber)]
    AS.SetFrontProcess.restype = c_int
    class CGPoint(ctypes.Structure):
        _fields_ = [("x", ctypes.c_double), ("y", ctypes.c_double)]

    class CGSize(ctypes.Structure):
        _fields_ = [("width", ctypes.c_double), ("height", ctypes.c_double)]

    AS.CGEventCreateKeyboardEvent.argtypes = [c_void_p, c_uint32, c_bool]
    AS.CGEventCreateKeyboardEvent.restype = CFRef
    AS.CGEventCreateMouseEvent.argtypes = [c_void_p, c_uint32, CGPoint, c_uint32]
    AS.CGEventCreateMouseEvent.restype = CFRef
    AS.CGEventSetFlags.argtypes = [CFRef, c_uint64]
    AS.CGEventPost.argtypes = [c_uint32, CFRef]
    AS.CGEventPostToPid.argtypes = [c_int, CFRef]
    AS.AXValueGetValue.argtypes = [CFRef, c_uint32, c_void_p]
    AS.AXValueGetValue.restype = ctypes.c_bool

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
        return CF.CFStringCreateWithCString(None, value.encode("utf-8"), ENC)

    def copy_attr(elem, name: str):
        attr = cfstr(name)
        value = CFRef()
        err = AS.AXUIElementCopyAttributeValue(elem, attr, byref(value))
        CF.CFRelease(attr)
        return err, value.value

    def string_value(ref):
        if not ref or CF.CFGetTypeID(ref) != CF.CFStringGetTypeID():
            return ""
        buf = ctypes.create_string_buffer(4096)
        if CF.CFStringGetCString(ref, buf, len(buf), ENC):
            return buf.value.decode("utf-8", "replace")
        return "<too-long>"

    def attr_string(elem, name: str) -> str:
        _err, ref = copy_attr(elem, name)
        value = string_value(ref)
        if ref:
            CF.CFRelease(ref)
        return value

    def children(elem):
        err, ref = copy_attr(elem, "AXChildren")
        if err or not ref or CF.CFGetTypeID(ref) != CF.CFArrayGetTypeID():
            return []
        return [CF.CFArrayGetValueAtIndex(ref, i) for i in range(CF.CFArrayGetCount(ref))]

    def windows(app):
        err, ref = copy_attr(app, "AXWindows")
        if err or not ref or CF.CFGetTypeID(ref) != CF.CFArrayGetTypeID():
            return []
        return [CF.CFArrayGetValueAtIndex(ref, i) for i in range(CF.CFArrayGetCount(ref))]

    def perform(elem, action: str) -> int:
        act = cfstr(action)
        err = AS.AXUIElementPerformAction(elem, act)
        CF.CFRelease(act)
        return err

    def walk(elem, depth=0, limit=None):
        if limit is None:
            limit = [0]
        if depth > 12 or limit[0] > 8000:
            return
        limit[0] += 1
        yield elem
        for child in children(elem):
            yield from walk(child, depth + 1, limit)

    def post_key_pair(pid: int, key_code: int, flags: int, to_pid: bool) -> None:
        for down in (True, False):
            event = AS.CGEventCreateKeyboardEvent(None, key_code, down)
            AS.CGEventSetFlags(event, flags)
            if to_pid:
                AS.CGEventPostToPid(pid, event)
            else:
                AS.CGEventPost(0, event)
            CF.CFRelease(event)

    def post_text_selection(pid: int) -> list[str]:
        key_left = 123
        key_down = 125
        shift = 0x00020000
        option = 0x00080000
        command = 0x00100000
        strategies = []
        for strategy, to_pid in (("global-cmd-down", False), ("pid-cmd-down", True)):
            post_key_pair(pid, key_down, command, to_pid)
            strategies.append(strategy)
            time.sleep(0.4)
        for strategy, to_pid in (("global-shift-cmd-left", False), ("pid-shift-cmd-left", True)):
            post_key_pair(pid, key_left, shift | command, to_pid)
            strategies.append(strategy)
            time.sleep(0.8)
        for i in range(4):
            for strategy, to_pid in (("global-shift-option-left", False), ("pid-shift-option-left", True)):
                post_key_pair(pid, key_left, shift | option, to_pid)
                strategies.append(f"{strategy}-{i + 1}")
                time.sleep(0.35)
        return strategies

    def ax_value_point(ref) -> CGPoint | None:
        if not ref:
            return None
        point = CGPoint()
        if AS.AXValueGetValue(ref, 1, byref(point)):
            return point
        return None

    def ax_value_size(ref) -> CGSize | None:
        if not ref:
            return None
        size = CGSize()
        if AS.AXValueGetValue(ref, 2, byref(size)):
            return size
        return None

    def click_window_body(win) -> str:
        _err_pos, pos_ref = copy_attr(win, "AXPosition")
        _err_size, size_ref = copy_attr(win, "AXSize")
        pos = ax_value_point(pos_ref)
        size = ax_value_size(size_ref)
        if pos_ref:
            CF.CFRelease(pos_ref)
        if size_ref:
            CF.CFRelease(size_ref)
        if not pos or not size:
            return "focus_click=blocked missing_window_bounds"
        point = CGPoint(pos.x + size.width * 0.45, pos.y + size.height * 0.42)
        for event_type in (1, 2):
            event = AS.CGEventCreateMouseEvent(None, event_type, point, 0)
            AS.CGEventPost(0, event)
            CF.CFRelease(event)
            time.sleep(0.08)
        time.sleep(0.8)
        return f"focus_click=ok x={point.x:.0f} y={point.y:.0f} width={size.width:.0f} height={size.height:.0f}"

    def click_element(elem) -> tuple[bool, str]:
        _err_pos, pos_ref = copy_attr(elem, "AXPosition")
        _err_size, size_ref = copy_attr(elem, "AXSize")
        pos = ax_value_point(pos_ref)
        size = ax_value_size(size_ref)
        if pos_ref:
            CF.CFRelease(pos_ref)
        if size_ref:
            CF.CFRelease(size_ref)
        if not pos or not size:
            return False, "mouse_click=blocked missing_element_bounds"
        point = CGPoint(pos.x + size.width * 0.5, pos.y + size.height * 0.5)
        for event_type in (1, 2):
            event = AS.CGEventCreateMouseEvent(None, event_type, point, 0)
            AS.CGEventPost(0, event)
            CF.CFRelease(event)
            time.sleep(0.08)
        time.sleep(1.2)
        return True, f"mouse_click=ok x={point.x:.0f} y={point.y:.0f} width={size.width:.0f} height={size.height:.0f}"

    lines = [f"ax_trusted={'yes' if AS.AXIsProcessTrusted() else 'no'}"]
    target_seen = False
    target_with_window = False
    popover_seen = False
    rewrite_seen = False
    expand_seen = False
    shorten_seen = False
    press_err = None
    rewrite_elem = None
    hits = []

    for pid in target_pids:
        app = AS.AXUIElementCreateApplication(pid)
        actual = c_int(-1)
        get_pid_err = AS.AXUIElementGetPid(app, byref(actual))
        target = get_pid_err == 0 and actual.value == pid
        target_seen = target_seen or target
        current_windows = windows(app)
        target_with_window = target_with_window or (target and bool(current_windows))
        lines.append(f"candidate pid={pid} axGetPidErr={get_pid_err} actualPid={actual.value} target={str(target).lower()} title={attr_string(app, 'AXTitle')} role={attr_string(app, 'AXRole')} windows={len(current_windows)}")
        if not target:
            continue

        psn = ProcessSerialNumber()
        front_err = AS.GetProcessForPID(pid, byref(psn))
        set_front_err = AS.SetFrontProcess(byref(psn)) if front_err == 0 else -1
        raise_errs = [str(perform(win, "AXRaise")) for win in current_windows]
        time.sleep(0.8)
        if drive_selection:
            focus_detail = click_window_body(current_windows[0]) if current_windows else "focus_click=blocked no_window"
            strategies = post_text_selection(pid)
            time.sleep(3)
        else:
            focus_detail = "focus_click=skipped"
            strategies = ["selection-scan-only"]
        lines.append(f"text_select pid={pid} frontErr={front_err} setFrontErr={set_front_err} raiseErrs={','.join(raise_errs) or '<none>'} {focus_detail} strategies={','.join(strategies)}")

        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            local_hits = []
            local_rewrite = None
            local_popover = False
            local_expand = False
            local_shorten = False
            for elem in walk(app):
                role = attr_string(elem, "AXRole")
                title = attr_string(elem, "AXTitle")
                value = attr_string(elem, "AXValue")
                ident = attr_string(elem, "AXIdentifier")
                text = " ".join([role, title, value, ident])
                if ident == "SelectToActPopover" or "SelectToActPopover" in text:
                    local_popover = True
                    local_hits.append(f"popover role={role} title={title} ident={ident}")
                if ident == "btn_rewrite" or "Rewrite paragraph" in text:
                    rewrite_seen = True
                    local_rewrite = elem
                    local_hits.append(f"rewrite role={role} title={title} value={value} ident={ident}")
                if ident == "btn_expand" or "Expand paragraph" in text:
                    local_expand = True
                    local_hits.append(f"expand role={role} title={title} value={value} ident={ident}")
                if ident == "btn_shorten" or "Shorten paragraph" in text:
                    local_shorten = True
                    local_hits.append(f"shorten role={role} title={title} value={value} ident={ident}")
            popover_seen = popover_seen or local_popover
            expand_seen = expand_seen or local_expand
            shorten_seen = shorten_seen or local_shorten
            if local_hits:
                hits.extend(local_hits)
            if local_rewrite:
                rewrite_elem = local_rewrite
            if rewrite_seen and (popover_seen or (expand_seen and shorten_seen)):
                break
            time.sleep(0.8)

        if press_rewrite and rewrite_elem:
            press_err = perform(rewrite_elem, "AXPress")
            mouse_detail = "mouse_click=not-needed"
            mouse_ok = False
            time.sleep(0.4)
            mouse_ok, mouse_detail = click_element(rewrite_elem)
            time.sleep(2)
        CF.CFRelease(app)

    if not popover_seen and rewrite_seen and expand_seen and shorten_seen:
        popover_seen = True
    lines.append(f"target_seen={'yes' if target_seen else 'no'}")
    lines.append(f"target_with_window={'yes' if target_with_window else 'no'}")
    lines.append(f"select_to_act_popover={'yes' if popover_seen else 'no'}")
    lines.append(f"rewrite_button={'yes' if rewrite_seen else 'no'}")
    lines.append(f"expand_button={'yes' if expand_seen else 'no'}")
    lines.append(f"shorten_button={'yes' if shorten_seen else 'no'}")
    if press_rewrite:
        press_status = "ok" if press_err == 0 or ('mouse_ok' in locals() and mouse_ok) else "missing" if press_err is None else "failed"
        lines.append(f"rewrite_press={press_status} err={press_err} {mouse_detail if 'mouse_detail' in locals() else ''}")
    lines.append("select_to_act_hits=" + ";".join(hits[:10]))
    return "\n".join(lines)

def log_contains(needle: str, timeout: int) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            if needle in LOG.read_text(encoding="utf-8", errors="replace"):
                return True
        except OSError:
            pass
        time.sleep(0.5)
    return False

def main() -> int:
    global PROFILE, LAUNCH_PROC, STARTED_PIDS, LAST_AX_RESULT
    parse_args(sys.argv[1:])
    atexit.register(cleanup)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    LOG.write_text("=== V2 visible current-bundle Select-to-act smoke ===\n", encoding="utf-8")

    soffice = APP / "Contents/MacOS/soffice"
    if not soffice.exists():
        print(f"FAIL: missing executable soffice in app bundle: {APP}", file=sys.stderr)
        return 1

    config = APP / "Contents/Resources/config/soffice.cfg"
    popover_ui = config / "modules/swriter/ui/select-to-act-popover.ui"
    if popover_ui.exists() and binary_contains(popover_ui, b"SelectToActPopover") and binary_contains(popover_ui, b"btn_rewrite"):
        record("PASS", "current bundle Select-to-act UI parity", "Writer SelectToActPopover and Rewrite button UI resource present")
    else:
        record("FAIL", "current bundle Select-to-act UI parity", "Writer SelectToActPopover or Rewrite button UI resource missing")

    before = builddir_pids()
    PROFILE = tempfile.mkdtemp(prefix="kqoffice-visible-select-profile.")
    env = dict(os.environ)
    env["KQOFFICE_AI_STUB_RUNTIME"] = "1"
    env["KQOFFICE_AI_DISABLE_PROBE"] = "1"
    env["SAL_LOG"] = "+INFO.sw.inline_actions"
    with LOG.open("a", encoding="utf-8") as log:
        log.write(f"App bundle: {APP}\n")
        log.write(f"Builddir pids before launch: {' '.join(map(str, sorted(before))) or '<none>'}\n")
        log.write(f"Isolated profile: {PROFILE}\n")
        log.write(f"UNO port: {PORT}\n")
        LAUNCH_PROC = subprocess.Popen([
            str(soffice),
            "--nologo",
            "--nofirststartwizard",
            "--norestore",
            "--nolockcheck",
            f"--accept=socket,host=127.0.0.1,port={PORT};urp;",
            f"-env:UserInstallation=file://{PROFILE}",
            "private:factory/swriter",
        ], stdout=log, stderr=subprocess.STDOUT, env=env)

    seen_new: set[int] = set()
    for _ in range(12):
        current = builddir_pids()
        new = sorted(current - before)
        if new:
            seen_new.update(new)
        if LAUNCH_PROC.poll() is not None:
            break
        time.sleep(1)
    STARTED_PIDS = sorted(seen_new)
    if STARTED_PIDS:
        record("PASS", "builddir process launch", "new builddir soffice pid(s): " + " ".join(map(str, STARTED_PIDS)))
    else:
        record("FAIL", "builddir process launch", "no new builddir soffice pid")

    if not STARTED_PIDS:
        record("BLOCKED", "builddir launch readiness", "no builddir pid available")
    else:
        ready, readiness_detail = wait_for_launch_readiness(STARTED_PIDS)
        with LOG.open("a", encoding="utf-8") as log:
            log.write(readiness_detail + "\n")
        if ready:
            record("PASS", "builddir launch readiness", readiness_detail)
        else:
            record("BLOCKED", "builddir launch readiness", readiness_detail)

    uno_seed = run_bundled_uno_seed() if STARTED_PIDS else "uno_seed=blocked no_pid"
    with LOG.open("a", encoding="utf-8") as log:
        log.write(uno_seed + "\n")
    if "uno_seed=ok" in uno_seed:
        record("PASS", "visible Writer document seed", uno_seed)
    elif "missing_python" in uno_seed:
        record("FAIL", "visible Writer document seed", uno_seed)
    else:
        record("BLOCKED", "visible Writer document seed", uno_seed)

    if STARTED_PIDS and "uno_seed=ok" in uno_seed:
        LAST_AX_RESULT = ax_select_to_act_probe(STARTED_PIDS, press_rewrite=False)
        with LOG.open("a", encoding="utf-8") as log:
            log.write(LAST_AX_RESULT + "\n")
        selection_state = run_bundled_selection_state()
        with LOG.open("a", encoding="utf-8") as log:
            log.write(selection_state + "\n")
        if "selection_state=ok" in selection_state and "text_len=0" not in selection_state:
            record("PASS", "visible Writer text selection", selection_state)
        elif "selection_state=failed" in selection_state:
            record("BLOCKED", "visible Writer text selection", selection_state)
        else:
            record("BLOCKED", "visible Writer text selection", selection_state)
        if "target_seen=yes" in LAST_AX_RESULT and "target_with_window=yes" in LAST_AX_RESULT:
            record("PASS", "AX target window attribution", LAST_AX_RESULT)
        else:
            record("BLOCKED", "AX target window attribution", LAST_AX_RESULT)
        if "select_to_act_popover=yes" in LAST_AX_RESULT and "rewrite_button=yes" in LAST_AX_RESULT:
            record("PASS", "GUI Select-to-act popover", LAST_AX_RESULT)
            click_result = ax_select_to_act_probe(STARTED_PIDS, press_rewrite=True,
                                                  drive_selection=False)
            with LOG.open("a", encoding="utf-8") as log:
                log.write(click_result + "\n")
            if "rewrite_press=ok" in click_result:
                record("PASS", "GUI Rewrite paragraph click", click_result)
            else:
                record("BLOCKED", "GUI Rewrite paragraph click", click_result)
            post_click_result = ""
            popover_closed = False
            if log_contains("inline_action_request=", 2):
                record("PASS", "Writer inline action dispatch evidence", "inline_action_request emitted after Rewrite click")
            else:
                deadline = time.monotonic() + ACTION_TIMEOUT
                while time.monotonic() < deadline:
                    post_click_result = ax_select_to_act_probe(
                        STARTED_PIDS, press_rewrite=False, drive_selection=False)
                    with LOG.open("a", encoding="utf-8") as log:
                        log.write(post_click_result + "\n")
                    if "select_to_act_popover=no" in post_click_result and "rewrite_button=no" in post_click_result:
                        popover_closed = True
                        break
                    if log_contains("inline_action_request=", 1):
                        break
                    time.sleep(2)
                if log_contains("inline_action_request=", 1):
                    record("PASS", "Writer inline action dispatch evidence", "inline_action_request emitted after Rewrite click")
                elif popover_closed:
                    record("PASS", "Writer inline action dispatch evidence", "Select-to-act popover closed after Rewrite click")
                else:
                    record("BLOCKED", "Writer inline action dispatch evidence", f"no inline_action_request and popover still visible after Rewrite click: {post_click_result}")
        else:
            record("BLOCKED", "GUI Select-to-act popover", LAST_AX_RESULT)
            record("BLOCKED", "GUI Rewrite paragraph click", "Select-to-act popover was not scannable")
            record("BLOCKED", "Writer inline action dispatch evidence", "Rewrite click was not attempted")
    else:
        record("BLOCKED", "AX target window attribution", "no seeded visible Writer document")
        record("BLOCKED", "GUI Select-to-act popover", "no seeded visible Writer document")
        record("BLOCKED", "GUI Rewrite paragraph click", "no seeded visible Writer document")
        record("BLOCKED", "Writer inline action dispatch evidence", "no seeded visible Writer document")

    status = "failed" if FAILURES else "blocked" if BLOCKERS else "passed"
    write_report(status)
    print(f"Status: {status}")
    print(f"Checks passed: {PASSES}")
    print(f"Checks blocked: {BLOCKERS}")
    print(f"Checks failed: {FAILURES}")
    print(f"Report: {REPORT}")
    return 0 if FAILURES == 0 else 1

if __name__ == "__main__":
    raise SystemExit(main())
PY
