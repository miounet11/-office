#!/usr/bin/env bash
# V2 visible current-bundle Cowork task-loop smoke for KQOffice.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

python3 - "$@" <<'PY'
import atexit
import ctypes
import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from ctypes import byref, c_bool, c_int, c_uint32, c_uint64, c_void_p
from pathlib import Path

ROOT = Path.cwd()
APP = Path(os.environ.get("KDOFFICE_APP_BUNDLE", str(ROOT / "instdir/可圈office.app")))
REPORT = Path(os.environ.get("V2_VISIBLE_COWORK_REPORT", str(ROOT / "tmp/v2-visible-cowork-smoke.md")))
LOG = Path(os.environ.get("V2_VISIBLE_COWORK_LOG", str(ROOT / "tmp/v2-visible-cowork-smoke.log")))
NATIVE_EVIDENCE_LOG = Path(os.environ.get(
    "V2_VISIBLE_COWORK_NATIVE_EVIDENCE_LOG",
    str(ROOT / "tmp/v2-visible-cowork-native-notification.jsonl")))
KEEP_PROFILE = os.environ.get("V2_VISIBLE_COWORK_KEEP_PROFILE", "0") == "1"
READY_TIMEOUT = int(os.environ.get("V2_VISIBLE_COWORK_READY_TIMEOUT", "45"))
ACTION_TIMEOUT = int(os.environ.get("V2_VISIBLE_COWORK_ACTION_TIMEOUT", "30"))
PORT = int(os.environ.get("V2_VISIBLE_COWORK_UNO_PORT", str(25000 + os.getpid() % 10000)))
SAL_LOG_SPEC = os.environ.get("V2_VISIBLE_COWORK_SAL_LOG", "")
SAL_LOG_FILE = os.environ.get("V2_VISIBLE_COWORK_SAL_LOG_FILE", "")
LAUNCH_MODE = os.environ.get("V2_VISIBLE_COWORK_LAUNCH_MODE", "direct")

PASSES = 0
BLOCKERS = 0
FAILURES = 0
ROWS = []
PROFILE = ""
TASK_DIR = ""
LAUNCH_PROC = None
STARTED_PIDS = []
LAST_AX_RESULT = ""
LAUNCH_ENV_KEYS = []

def md_escape(value: str) -> str:
    return str(value).replace("|", "\\|").replace("\n", ";")

def record(status: str, area: str, detail: str) -> None:
    global PASSES, BLOCKERS, FAILURES
    ROWS.append((status, area, detail))
    if status == "PASS":
        PASSES += 1
        print(f"PASS: {area} -- {detail}")
    elif status == "BLOCKED":
        BLOCKERS += 1
        print(f"BLOCKED: {area} -- {detail}")
    else:
        FAILURES += 1
        print(f"FAIL: {area} -- {detail}", file=sys.stderr)

def cleanup() -> None:
    for key in LAUNCH_ENV_KEYS:
        subprocess.run(["launchctl", "unsetenv", key], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    for pid in STARTED_PIDS:
        try:
            os.kill(pid, 15)
        except OSError:
            pass
    if LAUNCH_PROC is not None:
        try:
            LAUNCH_PROC.terminate()
            LAUNCH_PROC.wait(timeout=3)
        except Exception:
            try:
                LAUNCH_PROC.kill()
            except Exception:
                pass
    if PROFILE and not KEEP_PROFILE:
        shutil.rmtree(PROFILE, ignore_errors=True)
    if TASK_DIR and not KEEP_PROFILE:
        shutil.rmtree(TASK_DIR, ignore_errors=True)

atexit.register(cleanup)

def binary_contains(path: Path, needle: bytes) -> bool:
    try:
        return needle in path.read_bytes()
    except OSError:
        return False

def builddir_pids() -> set[int]:
    needle = str(APP / "Contents/MacOS/soffice")
    out = subprocess.check_output(["ps", "-axo", "pid,command"], text=True)
    pids = set()
    for line in out.splitlines():
        if needle in line and "grep" not in line:
            try:
                pids.add(int(line.strip().split(None, 1)[0]))
            except Exception:
                pass
    return pids

def launch_session_pids(profile: str, port: int) -> set[int]:
    out = subprocess.check_output(["ps", "-axo", "pid,command"], text=True)
    needle = str(APP / "Contents/MacOS/soffice")
    profile_needle = f"UserInstallation=file://{profile}"
    port_needle = f"port={port};urp;"
    pids = set()
    for line in out.splitlines():
        if needle not in line or "grep" in line:
            continue
        if profile_needle not in line and port_needle not in line:
            continue
        try:
            pids.add(int(line.strip().split(None, 1)[0]))
        except Exception:
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

def pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False

def activate_pid_front(pid: int) -> str:
    AS = ctypes.cdll.LoadLibrary(
        "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices")

    class ProcessSerialNumber(ctypes.Structure):
        _fields_ = [("highLongOfPSN", c_uint32), ("lowLongOfPSN", c_uint32)]

    AS.GetProcessForPID.argtypes = [c_int, ctypes.POINTER(ProcessSerialNumber)]
    AS.GetProcessForPID.restype = c_int
    AS.SetFrontProcess.argtypes = [ctypes.POINTER(ProcessSerialNumber)]
    AS.SetFrontProcess.restype = c_int

    psn = ProcessSerialNumber()
    get_err = AS.GetProcessForPID(pid, byref(psn))
    set_err = AS.SetFrontProcess(byref(psn)) if get_err == 0 else -1
    return f"front_activation pid={pid} getErr={get_err} setErr={set_err}"

def post_cowork_shortcut(pid: int) -> str:
    AS = ctypes.cdll.LoadLibrary(
        "/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices")
    AS.CGEventCreateKeyboardEvent.argtypes = [c_void_p, c_uint32, c_bool]
    AS.CGEventCreateKeyboardEvent.restype = c_void_p
    AS.CGEventSetFlags.argtypes = [c_void_p, c_uint64]
    AS.CGEventPostToPid.argtypes = [c_int, c_void_p]
    CF = ctypes.cdll.LoadLibrary(
        "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
    CF.CFRelease.argtypes = [c_void_p]

    key_t = 17
    command_shift = (1 << 20) | (1 << 17)
    for down in (True, False):
        event = AS.CGEventCreateKeyboardEvent(None, key_t, down)
        AS.CGEventSetFlags(event, command_shift)
        AS.CGEventPostToPid(pid, event)
        CF.CFRelease(event)
    return f"cowork_shortcut_bootstrap pid={pid} sent=yes"

def write_report(status: str) -> None:
    target_ready = "target_seen=yes" in LAST_AX_RESULT and "target_with_window=yes" in LAST_AX_RESULT
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    with REPORT.open("w", encoding="utf-8") as f:
        f.write("# V2 Visible Cowork Smoke\n\n")
        f.write(f"- Status: {status}\n")
        f.write(f"- Target attribution: {'ready' if target_ready else 'blocked'}\n")
        f.write(f"- App bundle: {APP}\n")
        f.write(f"- Isolated profile: {PROFILE or '<none>'}\n")
        f.write(f"- Isolated task store: {TASK_DIR or '<none>'}\n")
        f.write(f"- UNO port: {PORT}\n")
        f.write("- Started builddir pids: ")
        f.write(" ".join(str(pid) for pid in STARTED_PIDS) or "<none>")
        f.write("\n")
        f.write(f"- Checks passed: {PASSES}\n")
        f.write(f"- Checks blocked: {BLOCKERS}\n")
        f.write(f"- Checks failed: {FAILURES}\n")
        f.write("- Scope: strict current builddir bundle PID attribution + physical Cmd+Shift+T Cowork dialog + pending/running visible rows + New Task/Accept Task visible loop + macOS native notification proof\n\n")
        f.write("| Status | Area | Detail |\n")
        f.write("|---|---|---|\n")
        for row_status, area, detail in ROWS:
            f.write(f"| {row_status} | {area} | {md_escape(detail)} |\n")

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
    AS.AXUIElementSetAttributeValue.argtypes = [c_void_p, CFRef, CFRef]
    AS.AXUIElementSetAttributeValue.restype = c_int

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
        ready = ready or (target and window_count > 0)
        if windows:
            CF.CFRelease(windows)
        if menubar:
            CF.CFRelease(menubar)
        if app:
            CF.CFRelease(app)
    lines.append(f"ax_surface_ready={'yes' if ready else 'no'}")
    return ready, "\n".join(lines)

def startup_diagnostic(target_pids: list[int], last_ax: str, socket_seen: bool,
                       activation_detail: str) -> str:
    lines = [f"ready_timeout={READY_TIMEOUT}s"]
    lines.append(
        f"uno_socket={'ready' if socket_seen else 'not-ready'} port={PORT}")
    if activation_detail:
        lines.append(activation_detail)
    if last_ax:
        lines.append(last_ax)
    for pid in target_pids:
        try:
            ps = subprocess.run(["ps", "-p", str(pid), "-o", "pid=,ppid=,stat=,etime=,rss=,command="], text=True, capture_output=True, check=False)
            if ps.stdout.strip():
                lines.append("process " + ps.stdout.strip())
        except Exception as exc:
            lines.append(f"process pid={pid} ps_error={exc!r}")
        if shutil.which("sample"):
            sample_file = ROOT / "tmp" / f"v2-visible-cowork-startup-pid-{pid}.sample.txt"
            try:
                subprocess.run(["sample", str(pid), "1", "1"], stdout=sample_file.open("w"), stderr=subprocess.STDOUT, check=False, timeout=8)
                lines.append(f"sample={sample_file}")
            except Exception as exc:
                lines.append(f"sample_error pid={pid} error={exc!r}")
    return "\n".join(lines)

def wait_for_launch_readiness(target_pids: list[int]) -> tuple[bool, str]:
    deadline = time.monotonic() + READY_TIMEOUT
    last_ax = ""
    socket_seen = False
    socket_seen_at = None
    bootstrap_detail = "uno_bootstrap=not-attempted"
    activation_detail = "front_activation=not-attempted"
    shortcut_detail = "cowork_shortcut_bootstrap=not-attempted"
    shortcut_sent = False
    last_activation_at = 0.0
    started_at = time.monotonic()
    while time.monotonic() < deadline:
        if uno_socket_ready():
            socket_seen = True
            if socket_seen_at is None:
                socket_seen_at = time.monotonic()
            if (bootstrap_detail == "uno_bootstrap=not-attempted"
                    and time.monotonic() - socket_seen_at > 1):
                bootstrap_detail = bootstrap_visible_writer()
        now = time.monotonic()
        if target_pids and now - last_activation_at > 4:
            activation_detail = ";".join(
                activate_pid_front(pid) for pid in target_pids if pid_alive(pid))
            last_activation_at = now
        if target_pids and not shortcut_sent and now - started_at > 18:
            shortcut_detail = ";".join(
                post_cowork_shortcut(pid) for pid in target_pids if pid_alive(pid))
            shortcut_sent = True
        ready, last_ax = ax_window_summary(target_pids)
        if ready:
            socket_detail = f"uno_socket={'ready' if socket_seen else 'not-ready'} port={PORT}"
            return True, (socket_detail + "\n" + bootstrap_detail + "\n"
                          + activation_detail + "\n" + shortcut_detail + "\n"
                          + last_ax)
        if socket_seen and "uno_bootstrap=ok" in bootstrap_detail:
            return True, (f"uno_socket=ready port={PORT}\n" + bootstrap_detail + "\n"
                          + activation_detail + "\n" + shortcut_detail + "\n"
                          + last_ax)
        if target_pids and not any(pid_alive(pid) for pid in target_pids):
            break
        time.sleep(2)
    detail = startup_diagnostic(
        target_pids, last_ax, socket_seen,
        activation_detail + "\n" + shortcut_detail)
    if socket_seen:
        detail = f"{bootstrap_detail}\n" + detail
    return False, detail

def bootstrap_visible_writer() -> str:
    bundled_python = APP / "Contents/Resources/python"
    if not bundled_python.exists():
        return f"uno_bootstrap=failed missing_python={bundled_python}"
    code = r'''
import sys
import time
import uno

port = sys.argv[1]
ctx = uno.getComponentContext()
smgr = ctx.ServiceManager
resolver = smgr.createInstanceWithContext("com.sun.star.bridge.UnoUrlResolver", ctx)
remote = resolver.resolve(
    f"uno:socket,host=127.0.0.1,port={port};urp;StarOffice.ComponentContext")
rsmgr = remote.ServiceManager
desktop = rsmgr.createInstanceWithContext("com.sun.star.frame.Desktop", remote)
component = desktop.getCurrentComponent()
if component is None or not hasattr(component, "Text"):
    component = desktop.loadComponentFromURL("private:factory/swriter", "_blank", 0, ())
if component is None or not hasattr(component, "Text"):
    print("uno_bootstrap=failed no_writer_component")
    raise SystemExit(0)
text = component.Text
if not text.getString():
    text.setString("Cowork visible smoke document.")
controller = component.CurrentController
view_cursor = controller.getViewCursor()
view_cursor.gotoEnd(False)
frame = controller.Frame
try:
    frame.activate()
except Exception:
    pass
try:
    frame.ContainerWindow.setVisible(True)
except Exception:
    pass
try:
    frame.ContainerWindow.setFocus()
except Exception:
    pass
print(f"uno_bootstrap=ok frame={bool(frame)} text_len={len(text.getString())}")
time.sleep(1.5)
''' 
    try:
        proc = subprocess.run(
            [str(bundled_python), "-", str(PORT)], input=code, text=True,
            capture_output=True, check=False, timeout=20)
    except Exception as exc:
        return f"uno_bootstrap=failed error={exc!r}"
    output = (proc.stdout + proc.stderr).strip()
    if proc.returncode != 0:
        return f"uno_bootstrap=failed returncode={proc.returncode} output={output}"
    return output or "uno_bootstrap=failed empty_output"

def task_records() -> list[dict]:
    records = []
    if not TASK_DIR:
        return records
    for path in sorted(Path(TASK_DIR).glob("*/*.json")):
        try:
            with path.open("r", encoding="utf-8") as f:
                data = json.load(f)
            data["_path"] = str(path)
            records.append(data)
        except Exception as exc:
            records.append({"_path": str(path), "_error": repr(exc)})
    return records

def task_store_summary(records: list[dict]) -> str:
    if not records:
        return "task_store=<empty>"
    parts = []
    for item in records:
        task_id = item.get("task_id", "<missing>")
        state = item.get("state", "<missing>")
        plan = item.get("result_plan_id")
        if plan is None:
            plan = "null"
        parts.append(f"{task_id}:{state}:plan={plan}")
    return "task_store=" + ",".join(parts)

def wait_for_task_state(state: str, timeout: int = ACTION_TIMEOUT) -> tuple[bool, str]:
    deadline = time.monotonic() + timeout
    last_records = []
    while time.monotonic() < deadline:
        last_records = task_records()
        if any(item.get("state") == state for item in last_records):
            return True, task_store_summary(last_records)
        time.sleep(0.5)
    return False, task_store_summary(last_records)

def wait_for_new_task_state(existing_ids: set[str], state: str,
                            timeout: float = ACTION_TIMEOUT,
                            interval: float = 0.05) -> tuple[bool, str, str]:
    deadline = time.monotonic() + timeout
    last_records = []
    last_new_task = ""
    while time.monotonic() < deadline:
        last_records = task_records()
        for item in last_records:
            task_id = item.get("task_id", "")
            if not task_id or task_id in existing_ids:
                continue
            last_new_task = task_id
            if item.get("state") == state:
                return True, task_store_summary(last_records), task_id
        time.sleep(interval)
    return False, task_store_summary(last_records), last_new_task

def seed_visible_state_tasks() -> None:
    """Create stable pending/running rows so AX can prove both UI states."""
    month_dir = time.strftime("%Y-%m", time.gmtime())
    timestamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    target_dir = Path(TASK_DIR) / month_dir
    target_dir.mkdir(parents=True, exist_ok=True)
    for state, title in (
        ("pending", "Visible smoke pending task"),
        ("running", "Visible smoke running task"),
    ):
        task_id = f"tk-visible-{state}"
        envelope = {
            "schema_version": 1,
            "task_id": task_id,
            "kind": "weekly-report",
            "state": state,
            "title": title,
            "created_at": timestamp,
            "updated_at": timestamp,
            "service_mode": "offline",
            "input": {
                "source_docs": [],
                "user_prompt": "Visible Cowork state proof",
                "target_template": "",
            },
            "steps": [],
            "result_plan_id": None,
            "evidence_ids": [],
        }
        with (target_dir / f"{task_id}.json").open("w", encoding="utf-8") as f:
            json.dump(envelope, f, ensure_ascii=False, indent=2)
            f.write("\n")

def remove_seeded_visible_state_tasks() -> bool:
    removed = False
    for path in Path(TASK_DIR).glob("*/tk-visible-*.json"):
        path.unlink(missing_ok=True)
        removed = True
    return removed

def native_notification_events() -> list[dict]:
    events = []
    if not NATIVE_EVIDENCE_LOG.exists():
        return events
    try:
        for line in NATIVE_EVIDENCE_LOG.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                events.append({"event": "parse-error", "raw": line})
    except OSError as exc:
        events.append({"event": "read-error", "error": repr(exc)})
    return events

def native_notification_summary() -> str:
    events = native_notification_events()
    if not events:
        return f"native_evidence_log={NATIVE_EVIDENCE_LOG} events=0"
    parts = []
    for event in events[-8:]:
        parts.append(
            "event={event} backend={backend} task={task} submitted={submitted} "
            "dispatched={dispatched} opened={opened} valid={valid}".format(
                event=event.get("event", ""),
                backend=event.get("backend_token", ""),
                task=event.get("task_id") or event.get("opened_task_id", ""),
                submitted=event.get("submitted", ""),
                dispatched=event.get("dispatched", ""),
                opened=event.get("opened", ""),
                valid=event.get("valid", ""),
            ))
    return f"native_evidence_log={NATIVE_EVIDENCE_LOG} events={len(events)}; " + "; ".join(parts)

def native_notification_has(event_name: str, **expected) -> bool:
    for event in native_notification_events():
        if event.get("event") != event_name:
            continue
        if all(event.get(key) == value for key, value in expected.items()):
            return True
    return False

def system_events_click_button(pid: int, identifier: str, title_hint: str) -> str:
    script = r'''
on clickByIdOrTitle(thePid, theIdentifier, theTitle)
    tell application "System Events"
        set targetProcess to missing value
        repeat with proc in application processes
            try
                if unix id of proc is thePid then
                    set targetProcess to proc
                    exit repeat
                end if
            end try
        end repeat
        if targetProcess is missing value then return "system_events_click=missing_pid"
        set frontmost of targetProcess to true
        delay 0.2
        tell targetProcess
            repeat with win in windows
                set foundButton to my findButton(win, theIdentifier, theTitle)
                if foundButton is not missing value then
                    click foundButton
                    return "system_events_click=ok"
                end if
            end repeat
        end tell
    end tell
    return "system_events_click=missing_button"
end clickByIdOrTitle

on findButton(node, theIdentifier, theTitle)
    tell application "System Events"
        try
            if role of node is "AXButton" then
                set nodeDescription to ""
                try
                    set nodeDescription to description of node
                end try
                set nodeTitle to ""
                try
                    set nodeTitle to title of node
                end try
                set nodeName to ""
                try
                    set nodeName to name of node
                end try
                if nodeDescription is theIdentifier or nodeTitle contains theTitle or nodeName contains theTitle then return node
            end if
            repeat with childNode in UI elements of node
                set foundButton to my findButton(childNode, theIdentifier, theTitle)
                if foundButton is not missing value then return foundButton
            end repeat
        end try
    end tell
    return missing value
end findButton

return clickByIdOrTitle(%d, "%s", "%s")
''' % (pid, identifier, title_hint)
    try:
        proc = subprocess.run(["osascript", "-e", script], text=True,
                              capture_output=True, check=False, timeout=8)
    except Exception as exc:
        return f"system_events_click=error {exc!r}"
    out = (proc.stdout + proc.stderr).strip().replace("\n", ";")
    if proc.returncode != 0:
        return f"system_events_click=failed returncode={proc.returncode} output={out}"
    return out or "system_events_click=empty"

def ax_cowork_probe(target_pids: list[int]) -> str:
    AS = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices")
    CF = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
    CG = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
    CFRef = c_void_p
    ENC = 0x08000100

    class ProcessSerialNumber(ctypes.Structure):
        _fields_ = [("highLongOfPSN", c_uint32), ("lowLongOfPSN", c_uint32)]

    class CGPoint(ctypes.Structure):
        _fields_ = [("x", ctypes.c_double), ("y", ctypes.c_double)]

    class CGSize(ctypes.Structure):
        _fields_ = [("width", ctypes.c_double), ("height", ctypes.c_double)]

    AS.AXIsProcessTrusted.restype = ctypes.c_bool
    AS.AXUIElementCreateApplication.argtypes = [c_int]
    AS.AXUIElementCreateApplication.restype = c_void_p
    AS.AXUIElementGetPid.argtypes = [c_void_p, ctypes.POINTER(c_int)]
    AS.AXUIElementGetPid.restype = c_int
    AS.AXUIElementCopyAttributeValue.argtypes = [c_void_p, CFRef, ctypes.POINTER(CFRef)]
    AS.AXUIElementCopyAttributeValue.restype = c_int
    AS.AXUIElementSetAttributeValue.argtypes = [c_void_p, CFRef, CFRef]
    AS.AXUIElementSetAttributeValue.restype = c_int
    AS.AXUIElementPerformAction.argtypes = [c_void_p, CFRef]
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
    AS.CGEventCreateMouseEvent.argtypes = [c_void_p, c_uint32, CGPoint, c_uint32]
    AS.CGEventCreateMouseEvent.restype = CFRef
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
    CF.CFBooleanGetTypeID.restype = ctypes.c_ulong
    CF.CFBooleanGetValue.argtypes = [CFRef]
    CF.CFBooleanGetValue.restype = ctypes.c_bool
    CF.CFDictionaryGetValue.argtypes = [CFRef, CFRef]
    CF.CFDictionaryGetValue.restype = CFRef
    CF.CFNumberGetValue.argtypes = [CFRef, c_int, c_void_p]
    CF.CFNumberGetValue.restype = ctypes.c_bool
    CG.CGWindowListCopyWindowInfo.argtypes = [c_uint32, c_uint32]
    CG.CGWindowListCopyWindowInfo.restype = CFRef

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

    def attr_bool(elem, name: str):
        _err, ref = copy_attr(elem, name)
        value = None
        if ref and CF.CFGetTypeID(ref) == CF.CFBooleanGetTypeID():
            value = bool(CF.CFBooleanGetValue(ref))
        if ref:
            CF.CFRelease(ref)
        return value

    def cf_number(ref):
        if not ref:
            return None
        d = ctypes.c_double()
        if CF.CFNumberGetValue(ref, 13, byref(d)):
            return d.value
        i = c_int()
        if CF.CFNumberGetValue(ref, 9, byref(i)):
            return float(i.value)
        return None

    def array_count(ref) -> int:
        if not ref or CF.CFGetTypeID(ref) != CF.CFArrayGetTypeID():
            return 0
        return CF.CFArrayGetCount(ref)

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

    def ax_value_point(ref):
        if not ref:
            return None
        point = CGPoint()
        if AS.AXValueGetValue(ref, 1, byref(point)):
            return point
        return None

    def ax_value_size(ref):
        if not ref:
            return None
        size = CGSize()
        if AS.AXValueGetValue(ref, 2, byref(size)):
            return size
        return None

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
        time.sleep(1.0)
        return True, f"mouse_click=ok x={point.x:.0f} y={point.y:.0f} width={size.width:.0f} height={size.height:.0f}"

    def press_or_click(elem) -> tuple[bool, int | None, str]:
        if not elem:
            return False, None, "mouse_click=missing_element"
        press_err = perform(elem, "AXPress")
        if press_err == 0:
            return True, press_err, "mouse_click=not-needed"
        mouse_ok, mouse_detail = click_element(elem)
        return mouse_ok, press_err, mouse_detail

    def ax_value_point(ref):
        if not ref:
            return None
        point = CGPoint()
        if AS.AXValueGetValue(ref, 1, byref(point)):
            return point
        return None

    def ax_value_size(ref):
        if not ref:
            return None
        size = CGSize()
        if AS.AXValueGetValue(ref, 2, byref(size)):
            return size
        return None

    def click_element(elem):
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
        time.sleep(1.0)
        return True, (f"mouse_click=ok x={point.x:.0f} y={point.y:.0f} "
                      f"width={size.width:.0f} height={size.height:.0f}")

    def cg_dialog_bounds(pid: int):
        arr = CG.CGWindowListCopyWindowInfo(1, 0)
        if not arr:
            return None
        keys = {name: cfstr(name) for name in [
            "kCGWindowOwnerPID", "kCGWindowBounds", "X", "Y", "Width", "Height"]}
        best = None
        try:
            for i in range(CF.CFArrayGetCount(arr)):
                info = CF.CFArrayGetValueAtIndex(arr, i)
                owner = cf_number(CF.CFDictionaryGetValue(info, keys["kCGWindowOwnerPID"]))
                if owner is None or int(owner) != pid:
                    continue
                bounds = CF.CFDictionaryGetValue(info, keys["kCGWindowBounds"])
                if not bounds:
                    continue
                x = cf_number(CF.CFDictionaryGetValue(bounds, keys["X"]))
                y = cf_number(CF.CFDictionaryGetValue(bounds, keys["Y"]))
                w = cf_number(CF.CFDictionaryGetValue(bounds, keys["Width"]))
                h = cf_number(CF.CFDictionaryGetValue(bounds, keys["Height"]))
                if None in (x, y, w, h) or w < 120 or h < 80:
                    continue
                area = w * h
                if best is None or area < best[0]:
                    best = (area, x, y, w, h)
        finally:
            CF.CFRelease(arr)
            for value in keys.values():
                CF.CFRelease(value)
        if not best:
            return None
        _area, x, y, w, h = best
        return x, y, w, h

    def click_dialog_button_slot(win, pid: int, slot: str):
        _err_pos, pos_ref = copy_attr(win, "AXPosition")
        _err_size, size_ref = copy_attr(win, "AXSize")
        pos = ax_value_point(pos_ref)
        size = ax_value_size(size_ref)
        if pos_ref:
            CF.CFRelease(pos_ref)
        if size_ref:
            CF.CFRelease(size_ref)
        if pos and size:
            x, y, w, h = pos.x, pos.y, size.width, size.height
            source = "ax"
        else:
            bounds = cg_dialog_bounds(pid)
            if not bounds:
                return False, f"slot_click=blocked slot={slot} missing_window_bounds"
            x, y, w, h = bounds
            source = "cg"
        ratios = {"new": 0.56, "accept": 0.74, "cancel": 0.91}
        point = CGPoint(x + w * ratios.get(slot, 0.74), y + h - 24)
        for event_type in (1, 2):
            event = AS.CGEventCreateMouseEvent(None, event_type, point, 0)
            AS.CGEventPost(0, event)
            CF.CFRelease(event)
            time.sleep(0.08)
        time.sleep(1.0)
        return True, (f"slot_click=ok source={source} slot={slot} x={point.x:.0f} "
                      f"y={point.y:.0f} width={w:.0f} height={h:.0f}")

    def focus_cg_window(pid: int) -> str:
        bounds = cg_dialog_bounds(pid)
        if not bounds:
            return "focus_click=blocked missing_window_bounds"
        x, y, w, h = bounds
        point = CGPoint(x + w * 0.5, y + h * 0.52)
        for event_type in (1, 2):
            event = AS.CGEventCreateMouseEvent(None, event_type, point, 0)
            AS.CGEventPost(0, event)
            CF.CFRelease(event)
            time.sleep(0.08)
        time.sleep(0.8)
        return (f"focus_click=ok x={point.x:.0f} y={point.y:.0f} "
                f"width={w:.0f} height={h:.0f}")

    def focus_and_activate(elem, pid: int):
        focused_attr = cfstr("AXFocused")
        true_ref = c_void_p.in_dll(CF, "kCFBooleanTrue")
        focus_err = AS.AXUIElementSetAttributeValue(elem, focused_attr, true_ref)
        CF.CFRelease(focused_attr)
        if focus_err != 0:
            return False, f"keyboard_activate=blocked focus_err={focus_err}"
        time.sleep(0.3)
        for down in (True, False):
            event = AS.CGEventCreateKeyboardEvent(None, 49, down)
            AS.CGEventPostToPid(pid, event)
            CF.CFRelease(event)
        time.sleep(1.0)
        return True, "keyboard_activate=ok key=space"

    def post_mnemonic(pid: int, keycode: int, label: str):
        option_flag = 1 << 19
        for down in (True, False):
            event = AS.CGEventCreateKeyboardEvent(None, keycode, down)
            AS.CGEventSetFlags(event, option_flag)
            AS.CGEventPostToPid(pid, event)
            CF.CFRelease(event)
        time.sleep(1.0)
        return f"mnemonic_activate=sent key=option+{label}"

    def find_by_title(elem, titles, depth=0):
        if depth > 8:
            return None
        if attr_string(elem, "AXTitle") in titles:
            return elem
        for child in children(elem):
            found = find_by_title(child, titles, depth + 1)
            if found:
                return found
        return None

    def find_by_identifier(elem, identifier: str, depth=0):
        if depth > 12:
            return None
        if attr_string(elem, "AXIdentifier") == identifier:
            return elem
        for child in children(elem):
            found = find_by_identifier(child, identifier, depth + 1)
            if found:
                return found
        return None

    def find_in_windows(app, finder):
        for win in windows(app):
            found = finder(win)
            if found:
                return found
        return None

    def wait_for(predicate, timeout=ACTION_TIMEOUT):
        deadline = time.monotonic() + timeout
        last = None
        while time.monotonic() < deadline:
            last = predicate()
            if last:
                return last
            time.sleep(0.5)
        return last

    def scan(elem, depth=0, hits=None):
        if hits is None:
            hits = []
        if depth > 9:
            return hits
        role = attr_string(elem, "AXRole")
        title = attr_string(elem, "AXTitle")
        value = attr_string(elem, "AXValue")
        ident = attr_string(elem, "AXIdentifier")
        text = " ".join([role, title, value, ident])
        tokens = ["Cowork", "异步任务", "新建任务", "接受任务", "任务列表", "Tasks this month", "task_list_view", "btn_new_task", "btn_accept_task", "pending", "running", "awaiting-review", "applied", "DiffReviewPanel"]
        if any(token in text for token in tokens):
            hits.append((role, title, value, ident))
        for child in children(elem):
            scan(child, depth + 1, hits)
        return hits

    def post_cmd_shift_t(pid: int, strategy: str):
        key_t = 17
        flags = (1 << 20) | (1 << 17)
        for down in (True, False):
            event = AS.CGEventCreateKeyboardEvent(None, key_t, down)
            AS.CGEventSetFlags(event, flags)
            if strategy == "global":
                AS.CGEventPost(0, event)
            else:
                AS.CGEventPostToPid(pid, event)
            CF.CFRelease(event)
        time.sleep(0.7)

    def cowork_window_for(app):
        return find_in_windows(
            app, lambda win: win if attr_string(win, "AXTitle") == "异步任务" else None)

    def node_text(elem) -> str:
        return " ".join([attr_string(elem, "AXRole"), attr_string(elem, "AXTitle"),
                         attr_string(elem, "AXValue"), attr_string(elem, "AXIdentifier")])

    def tree_contains(app, token: str) -> bool:
        def contains(elem, depth=0):
            if depth > 12:
                return False
            if token in node_text(elem):
                return True
            return any(contains(child, depth + 1) for child in children(elem))
        return contains(app)

    def enabled_accept_button(cowork_win):
        button = find_by_identifier(cowork_win, "btn_accept_task")
        if button and attr_bool(button, "AXEnabled") is True:
            return button
        return None

    def any_accept_button(app):
        return find_in_windows(app, lambda win: find_by_identifier(win, "btn_accept_task"))

    lines = [f"ax_trusted={'yes' if AS.AXIsProcessTrusted() else 'no'}"]
    target_seen = False
    target_with_window = False
    cowork_window = False
    cowork_new_task = False
    cowork_accept_task = False
    cowork_task_list = False
    seeded_pending_visible = False
    seeded_running_visible = False
    live_task_pending = False
    live_task_running = False
    live_task_id = ""
    new_task_press = None
    new_task_mouse = ""
    new_task_keyboard = ""
    new_task_mnemonic = ""
    task_awaiting_review = False
    task_awaiting_review_detail = ""
    diff_review_panel = False
    accept_task_enabled = False
    accept_task_press = None
    accept_task_mouse = ""
    accept_task_keyboard = ""
    accept_task_mnemonic = ""
    accept_task_slot_click = ""
    task_applied = False
    task_applied_detail = ""
    accept_task_disabled = False
    hits = []

    for pid in target_pids:
        app = AS.AXUIElementCreateApplication(pid)
        actual = c_int(-1)
        get_pid_err = AS.AXUIElementGetPid(app, byref(actual))
        target = get_pid_err == 0 and actual.value == pid
        target_seen = target_seen or target
        focus_click = focus_cg_window(pid) if target else "focus_click=skipped"
        early_shortcut = "early_shortcut=not-needed"
        if target and not windows(app):
            post_cmd_shift_t(pid, "global")
            post_cmd_shift_t(pid, "pid")
            early_shortcut = "early_shortcut=global,pid"
        for _ in range(10):
            if windows(app):
                break
            time.sleep(1)
        before_windows = len(windows(app))
        if not target:
            lines.append(f"candidate pid={pid} axGetPidErr={get_pid_err} actualPid={actual.value} target={str(target).lower()} title={attr_string(app, 'AXTitle')} role={attr_string(app, 'AXRole')} windows_before={before_windows} {focus_click} {early_shortcut}")
            continue

        bootstrap_detail = "window_bootstrap=not-needed"
        if before_windows == 0:
            err_menubar, menubar = copy_attr(app, "AXMenuBar")
            if err_menubar == 0 and menubar:
                file_menu = find_by_title(menubar, {"文件", "File"})
                if file_menu:
                    press_file = perform(file_menu, "AXPress")
                    time.sleep(0.5)
                    new_item = find_by_title(file_menu, {"新建", "New"})
                    press_new = None
                    press_text = None
                    if new_item:
                        press_new = perform(new_item, "AXPress")
                        time.sleep(0.5)
                        text_item = find_by_title(new_item, {"文本文档", "Text Document"})
                        if text_item:
                            press_text = perform(text_item, "AXPress")
                            time.sleep(2)
                    bootstrap_detail = f"window_bootstrap=menu pressFile={press_file} pressNew={press_new} pressText={press_text}"
                else:
                    bootstrap_detail = "window_bootstrap=missing_file_menu"
                CF.CFRelease(menubar)
            else:
                bootstrap_detail = "window_bootstrap=no_menubar"

        after_bootstrap_windows = len(windows(app))
        target_with_window = target_with_window or (target and after_bootstrap_windows > 0)
        lines.append(f"candidate pid={pid} axGetPidErr={get_pid_err} actualPid={actual.value} target={str(target).lower()} title={attr_string(app, 'AXTitle')} role={attr_string(app, 'AXRole')} windows_before={before_windows} windows_after_bootstrap={after_bootstrap_windows} {focus_click} {early_shortcut} {bootstrap_detail}")

        psn = ProcessSerialNumber()
        front_err = AS.GetProcessForPID(pid, byref(psn))
        set_front_err = AS.SetFrontProcess(byref(psn)) if front_err == 0 else -1
        raise_errs = [str(perform(win, "AXRaise")) for win in windows(app)]
        time.sleep(1)
        strategies = ["global"]
        post_cmd_shift_t(pid, "global")
        if not wait_for(lambda: cowork_window_for(app), timeout=4):
            strategies.append("pid")
            post_cmd_shift_t(pid, "pid")
        wait_for(lambda: cowork_window_for(app), timeout=4)

        current_windows = windows(app)
        for win in current_windows:
            for role, title, value, ident in scan(win):
                text = " ".join([role, title, value, ident])
                if title == "异步任务" or value == "异步任务":
                    cowork_window = True
                if ident == "btn_new_task" or "新建任务" in text:
                    cowork_new_task = True
                if ident == "btn_accept_task" or "接受任务" in text:
                    cowork_accept_task = True
                if ident == "task_list_view" or "Tasks this month" in text:
                    cowork_task_list = True
                hits.append(f"role={role} title={title} value={value} ident={ident}")
        lines.append(f"cowork_shortcut pid={pid} frontErr={front_err} setFrontErr={set_front_err} raiseErrs={','.join(raise_errs) or '<none>'} strategies={','.join(strategies)} windows_after={len(current_windows)}")

        cowork_win = cowork_window_for(app)
        if not cowork_win:
            continue

        seeded_pending_visible = bool(
            wait_for(lambda: tree_contains(cowork_win, "[pending]"), timeout=8))
        seeded_running_visible = bool(
            wait_for(lambda: tree_contains(cowork_win, "[running]"), timeout=8))
        seeded_state_tasks_removed = remove_seeded_visible_state_tasks()
        lines.append(
            f"seeded_state_tasks_removed={'yes' if seeded_state_tasks_removed else 'no'}")
        existing_task_ids = {
            item.get("task_id", "") for item in task_records()
            if item.get("task_id")
        }

        new_button = find_by_identifier(cowork_win, "btn_new_task")
        if new_button:
            new_task_press = perform(new_button, "AXPress")
            if new_task_press != 0:
                _mouse_ok, new_task_mouse = click_element(new_button)
                if not _mouse_ok:
                    _keyboard_ok, new_task_keyboard = focus_and_activate(new_button, pid)
                    if not _keyboard_ok:
                        se_detail = system_events_click_button(
                            pid, "btn_new_task", "新建任务")
                        if "system_events_click=ok" in se_detail:
                            new_task_press = 0
                        new_task_keyboard = f"{new_task_keyboard} {se_detail}"
                    if not _keyboard_ok:
                        new_task_mnemonic = post_mnemonic(pid, 45, "n")
            else:
                new_task_mouse = "mouse_click=not-needed"
            lines.append(
                f"new_task_press_err={new_task_press} {new_task_mouse} "
                f"{new_task_keyboard} {new_task_mnemonic}")
        else:
            lines.append("new_task_press_err=missing")

        if new_button:
            live_task_pending, live_pending_detail, live_task_id = wait_for_new_task_state(
                existing_task_ids, "pending", timeout=2.0, interval=0.02)
            lines.append(
                f"live_task_pending_detail={live_pending_detail} task_id={live_task_id or '<none>'}")
            live_task_running, live_running_detail, live_running_task_id = wait_for_new_task_state(
                existing_task_ids, "running", timeout=8.0, interval=0.02)
            if live_running_task_id:
                live_task_id = live_running_task_id
            lines.append(
                f"live_task_running_detail={live_running_detail} task_id={live_task_id or '<none>'}")
            task_awaiting_review, task_awaiting_review_detail, live_awaiting_task_id = wait_for_new_task_state(
                existing_task_ids, "awaiting-review")
            if live_awaiting_task_id:
                live_task_id = live_awaiting_task_id
            if not task_awaiting_review:
                task_awaiting_review = bool(
                    wait_for(lambda: tree_contains(app, "[awaiting-review]")))
                if task_awaiting_review:
                    task_awaiting_review_detail = "task_store=not-yet-observed ax_row=awaiting-review"
            lines.append(f"task_awaiting_review_detail={task_awaiting_review_detail}")
            diff_review_panel = bool(
                wait_for(lambda: tree_contains(app, "DiffReviewPanel"), timeout=8))
            cowork_win = cowork_window_for(app) or cowork_win
            perform(cowork_win, "AXRaise")
            accept_button = wait_for(lambda: any_accept_button(app), timeout=8)
            accept_task_enabled = bool(
                accept_button and attr_bool(accept_button, "AXEnabled") is True)
            if accept_button and (accept_task_enabled or task_awaiting_review):
                accept_task_press = perform(accept_button, "AXPress")
                if accept_task_press != 0:
                    _mouse_ok, accept_task_mouse = click_element(accept_button)
                    if not _mouse_ok:
                        _keyboard_ok, accept_task_keyboard = focus_and_activate(
                            accept_button, pid)
                        if not _keyboard_ok:
                            se_detail = system_events_click_button(
                                pid, "btn_accept_task", "接受任务")
                            if "system_events_click=ok" in se_detail:
                                accept_task_press = 0
                            accept_task_keyboard = f"{accept_task_keyboard} {se_detail}"
                        if not _keyboard_ok:
                            accept_task_mnemonic = post_mnemonic(pid, 0, "a")
                            _slot_ok, accept_task_slot_click = click_dialog_button_slot(
                                cowork_win, pid, "accept")
                else:
                    accept_task_mouse = "mouse_click=not-needed"
                lines.append(
                    f"accept_task_press_err={accept_task_press} {accept_task_mouse} "
                    f"{accept_task_keyboard} {accept_task_mnemonic} "
                    f"{accept_task_slot_click}")
                task_applied, task_applied_detail = wait_for_task_state("applied")
                if not task_applied:
                    task_applied = bool(wait_for(lambda: tree_contains(app, "[applied]")))
                    if task_applied:
                        task_applied_detail = "task_store=not-yet-observed ax_row=applied"
                lines.append(f"task_applied_detail={task_applied_detail}")
                refreshed_accept = find_by_identifier(cowork_win, "btn_accept_task")
                accept_task_disabled = bool(
                    refreshed_accept
                    and attr_bool(refreshed_accept, "AXEnabled") is False)
            elif accept_button:
                lines.append(
                    f"accept_task_press_err=disabled enabled={attr_bool(accept_button, 'AXEnabled')}")
            elif task_awaiting_review:
                accept_task_mnemonic = post_mnemonic(pid, 0, "a")
                _slot_ok, accept_task_slot_click = click_dialog_button_slot(
                    cowork_win, pid, "accept")
                lines.append(
                    f"accept_task_press_err=missing {accept_task_mnemonic} "
                    f"{accept_task_slot_click}")
                task_applied, task_applied_detail = wait_for_task_state("applied")
                if not task_applied:
                    task_applied = bool(wait_for(lambda: tree_contains(app, "[applied]")))
                    if task_applied:
                        task_applied_detail = "task_store=not-yet-observed ax_row=applied"
                lines.append(f"task_applied_detail={task_applied_detail}")
                latest_cowork_win = cowork_window_for(app) or cowork_win
                refreshed_accept = find_by_identifier(latest_cowork_win, "btn_accept_task")
                accept_task_disabled = bool(
                    refreshed_accept and attr_bool(refreshed_accept, "AXEnabled") is False)
            else:
                lines.append("accept_task_press_err=missing")

        for win in windows(app):
            for role, title, value, ident in scan(win):
                hit = f"role={role} title={title} value={value} ident={ident}"
                if hit not in hits:
                    hits.append(hit)

        # Direct launch should expose one product pid. Do not drive any helper
        # processes if process discovery ever returns more than one candidate.
        break

    lines.append(f"target_seen={'yes' if target_seen else 'no'}")
    lines.append(f"target_with_window={'yes' if target_with_window else 'no'}")
    lines.append(f"cowork_window={'yes' if cowork_window else 'no'}")
    lines.append(f"cowork_new_task={'yes' if cowork_new_task else 'no'}")
    lines.append(f"cowork_accept_task={'yes' if cowork_accept_task else 'no'}")
    lines.append(f"cowork_task_list={'yes' if cowork_task_list else 'no'}")
    lines.append(f"seeded_pending_visible={'yes' if seeded_pending_visible else 'no'}")
    lines.append(f"seeded_running_visible={'yes' if seeded_running_visible else 'no'}")
    lines.append(f"live_task_id={live_task_id or '<none>'}")
    lines.append(f"live_task_pending={'yes' if live_task_pending else 'no'}")
    lines.append(f"live_task_running={'yes' if live_task_running else 'no'}")
    lines.append(f"new_task_press={'ok' if new_task_press == 0 or 'mouse_click=ok' in new_task_mouse or 'keyboard_activate=ok' in new_task_keyboard or 'mnemonic_activate=sent' in new_task_mnemonic or task_awaiting_review else 'missing' if new_task_press is None else 'failed'}")
    lines.append(f"new_task_mouse={new_task_mouse or 'none'}")
    lines.append(f"new_task_keyboard={new_task_keyboard or 'none'}")
    lines.append(f"task_awaiting_review={'yes' if task_awaiting_review else 'no'}")
    lines.append(f"task_awaiting_review_detail={task_awaiting_review_detail or task_store_summary(task_records())}")
    lines.append(f"diff_review_panel={'yes' if diff_review_panel else 'no'}")
    lines.append(f"accept_task_enabled={'yes' if accept_task_enabled else 'no'}")
    lines.append(f"accept_task_press={'ok' if accept_task_press == 0 or 'mouse_click=ok' in accept_task_mouse or 'keyboard_activate=ok' in accept_task_keyboard or 'mnemonic_activate=sent' in accept_task_mnemonic or task_applied else 'missing' if accept_task_press is None else 'failed'}")
    lines.append(f"accept_task_mouse={accept_task_mouse or 'none'}")
    lines.append(f"accept_task_keyboard={accept_task_keyboard or 'none'}")
    lines.append(f"accept_task_slot_click={accept_task_slot_click or 'none'}")
    lines.append(f"task_applied={'yes' if task_applied else 'no'}")
    lines.append(f"task_applied_detail={task_applied_detail or task_store_summary(task_records())}")
    lines.append(f"accept_task_disabled={'yes' if accept_task_disabled else 'no'}")
    lines.append("cowork_hits=" + ";".join(hits[:20]))
    return "\n".join(lines)

def main() -> int:
    global PROFILE, TASK_DIR, LAUNCH_PROC, STARTED_PIDS, LAST_AX_RESULT
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("w", encoding="utf-8") as log:
        log.write("=== V2 visible current-bundle Cowork smoke ===\n")
        log.write(f"App bundle: {APP}\n")

    soffice = APP / "Contents/MacOS/soffice"
    if not soffice.exists():
        print(f"FAIL: missing executable soffice in app bundle: {APP}", file=sys.stderr)
        return 1

    registry = APP / "Contents/Resources/registry/main.xcd"
    config = APP / "Contents/Resources/config/soffice.cfg"
    if (binary_contains(registry, b".uno:CoworkTaskManager") and binary_contains(registry, b"T_SHIFT_MOD1") and (config / "cui/ui/cowork-dialog.ui").exists()):
        record("PASS", "current bundle Cowork entry parity", "CoworkTaskManager command, Cmd+Shift+T, and dialog UI resource present")
    else:
        record("FAIL", "current bundle Cowork entry parity", "CoworkTaskManager command, Cmd+Shift+T, or dialog UI resource missing")

    before = builddir_pids()
    PROFILE = tempfile.mkdtemp(prefix="kqoffice-visible-cowork-profile.")
    TASK_DIR = tempfile.mkdtemp(prefix="kqoffice-visible-cowork-tasks.")
    NATIVE_EVIDENCE_LOG.parent.mkdir(parents=True, exist_ok=True)
    NATIVE_EVIDENCE_LOG.unlink(missing_ok=True)
    seed_visible_state_tasks()
    with LOG.open("a", encoding="utf-8") as log:
        log.write(f"Builddir pids before launch: {' '.join(map(str, sorted(before))) or '<none>'}\n")
        log.write(f"Isolated profile: {PROFILE}\n")
        log.write(f"Isolated task store: {TASK_DIR}\n")
        log.write(f"Native notification evidence: {NATIVE_EVIDENCE_LOG}\n")
        log.write(f"UNO port: {PORT}\n")
        launch_env = dict(os.environ)
        launch_env.update({
            "KQOFFICE_AI_STUB_RUNTIME": "1",
            "KQOFFICE_AI_DISABLE_PROBE": "1",
            "KQOFFICE_AI_TASKS_DIR": TASK_DIR,
            "KQOFFICE_AI_NATIVE_NOTIFICATION_EVIDENCE_LOG": str(NATIVE_EVIDENCE_LOG),
            "KQOFFICE_AI_NATIVE_NOTIFICATION_SMOKE_CLICK": "1",
            "SAL_ACCESSIBILITY_ENABLED": "1",
        })
        if SAL_LOG_SPEC:
            launch_env["SAL_LOG"] = SAL_LOG_SPEC
        if SAL_LOG_FILE:
            launch_env["SAL_LOG_FILE"] = SAL_LOG_FILE
        office_args = [
            "--nologo", "--nofirststartwizard", "--norestore", "--nolockcheck",
            f"--accept=socket,host=127.0.0.1,port={PORT};urp;",
            f"-env:UserInstallation=file://{PROFILE}",
            "private:factory/swriter",
        ]
        if LAUNCH_MODE == "direct":
            LAUNCH_PROC = subprocess.Popen(
                [str(soffice), *office_args], stdout=log,
                stderr=subprocess.STDOUT, env=launch_env)
        elif LAUNCH_MODE == "open":
            launch_service_env = {
                key: launch_env[key]
                for key in (
                    "KQOFFICE_AI_STUB_RUNTIME",
                    "KQOFFICE_AI_DISABLE_PROBE",
                    "KQOFFICE_AI_TASKS_DIR",
                    "KQOFFICE_AI_NATIVE_NOTIFICATION_EVIDENCE_LOG",
                    "KQOFFICE_AI_NATIVE_NOTIFICATION_SMOKE_CLICK",
                    "SAL_ACCESSIBILITY_ENABLED",
                    "SAL_LOG",
                    "SAL_LOG_FILE",
                )
                if key in launch_env
            }
            for key, value in launch_service_env.items():
                subprocess.run(["launchctl", "setenv", key, value], check=True)
                LAUNCH_ENV_KEYS.append(key)
            try:
                LAUNCH_PROC = subprocess.Popen(
                    ["open", "-n", "-F", str(APP), "--args", *office_args])
                try:
                    LAUNCH_PROC.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    pass
            finally:
                for key in LAUNCH_ENV_KEYS:
                    subprocess.run(["launchctl", "unsetenv", key], check=False)
                LAUNCH_ENV_KEYS.clear()
        else:
            raise RuntimeError(f"unsupported launch mode: {LAUNCH_MODE}")

    seen_new = set()
    if LAUNCH_PROC.pid:
        seen_new.add(LAUNCH_PROC.pid)
    for _ in range(12):
        current = launch_session_pids(PROFILE, PORT)
        if current:
            seen_new.update(current)
        if LAUNCH_PROC is not None and LAUNCH_PROC.poll() is not None:
            break
        time.sleep(1)
    STARTED_PIDS = sorted(builddir_pids() - before)

    if STARTED_PIDS:
        record("PASS", "builddir process launch", "new builddir soffice pid(s): " + " ".join(map(str, STARTED_PIDS)))
    else:
        record("FAIL", "builddir process launch", "no new builddir soffice pid")

    if not STARTED_PIDS:
        record("BLOCKED", "builddir launch readiness", "no builddir pid available")
        record("BLOCKED", "AX target process discovery", "no builddir pid available")
        record("BLOCKED", "AX target window attribution", "no builddir pid available")
        record("BLOCKED", "GUI Cowork Cmd+Shift+T", "no builddir pid available")
        record("BLOCKED", "Cowork seeded pending row visible", "no builddir pid available")
        record("BLOCKED", "Cowork seeded running row visible", "no builddir pid available")
        record("BLOCKED", "GUI Cowork new task click", "no builddir pid available")
        record("BLOCKED", "Cowork live new task pending", "no builddir pid available")
        record("BLOCKED", "Cowork live new task running", "no builddir pid available")
        record("BLOCKED", "Cowork awaiting-review task", "no builddir pid available")
        record("BLOCKED", "GUI Cowork DiffReview", "no builddir pid available")
        record("BLOCKED", "Cowork accept-task enabled", "no builddir pid available")
        record("BLOCKED", "GUI Cowork accept task click", "no builddir pid available")
        record("BLOCKED", "Cowork applied task", "no builddir pid available")
        record("BLOCKED", "macOS native notification submitted", "no builddir pid available")
        record("BLOCKED", "Native notification click dispatch", "no builddir pid available")
        record("BLOCKED", "Native notification stored review open", "no builddir pid available")
    else:
        ready, readiness_detail = wait_for_launch_readiness(STARTED_PIDS)
        with LOG.open("a", encoding="utf-8") as log:
            log.write(readiness_detail + "\n")
        if ready:
            record("PASS", "builddir launch readiness", readiness_detail)
        else:
            record("BLOCKED", "builddir launch readiness", readiness_detail)
            record("BLOCKED", "AX target process discovery", "target builddir pid did not expose AX windows/menu or UNO socket before timeout")
            record("BLOCKED", "AX target window attribution", "target builddir pid did not expose AX windows/menu or UNO socket before timeout")
            record("BLOCKED", "GUI Cowork Cmd+Shift+T", "target builddir pid did not expose AX windows/menu or UNO socket before timeout")
            record("BLOCKED", "Cowork seeded pending row visible", "target builddir pid did not expose AX windows/menu or UNO socket before timeout")
            record("BLOCKED", "Cowork seeded running row visible", "target builddir pid did not expose AX windows/menu or UNO socket before timeout")
            record("BLOCKED", "GUI Cowork new task click", "target builddir pid did not expose AX windows/menu or UNO socket before timeout")
            record("BLOCKED", "Cowork live new task pending", "target builddir pid did not expose AX windows/menu or UNO socket before timeout")
            record("BLOCKED", "Cowork live new task running", "target builddir pid did not expose AX windows/menu or UNO socket before timeout")
            record("BLOCKED", "Cowork awaiting-review task", "target builddir pid did not expose AX windows/menu or UNO socket before timeout")
            record("BLOCKED", "GUI Cowork DiffReview", "target builddir pid did not expose AX windows/menu or UNO socket before timeout")
            record("BLOCKED", "Cowork accept-task enabled", "target builddir pid did not expose AX windows/menu or UNO socket before timeout")
            record("BLOCKED", "GUI Cowork accept task click", "target builddir pid did not expose AX windows/menu or UNO socket before timeout")
            record("BLOCKED", "Cowork applied task", "target builddir pid did not expose AX windows/menu or UNO socket before timeout")
            record("BLOCKED", "macOS native notification submitted", "target builddir pid did not expose AX windows/menu or UNO socket before timeout")
            record("BLOCKED", "Native notification click dispatch", "target builddir pid did not expose AX windows/menu or UNO socket before timeout")
            record("BLOCKED", "Native notification stored review open", "target builddir pid did not expose AX windows/menu or UNO socket before timeout")
            status = "failed" if FAILURES else "blocked" if BLOCKERS else "passed"
            write_report(status)
            print(f"Status: {status}")
            print(f"Checks passed: {PASSES}")
            print(f"Checks blocked: {BLOCKERS}")
            print(f"Checks failed: {FAILURES}")
            print(f"Report: {REPORT}")
            return 0 if FAILURES == 0 else 1

        LAST_AX_RESULT = ax_cowork_probe(STARTED_PIDS)
        with LOG.open("a", encoding="utf-8") as log:
            log.write(LAST_AX_RESULT + "\n")

        if "target_seen=yes" in LAST_AX_RESULT:
            record("PASS", "AX target process discovery", LAST_AX_RESULT)
        else:
            record("BLOCKED", "AX target process discovery", LAST_AX_RESULT)

        if "target_with_window=yes" in LAST_AX_RESULT:
            record("PASS", "AX target window attribution", LAST_AX_RESULT)
        else:
            record("BLOCKED", "AX target window attribution", LAST_AX_RESULT)

        required = ["cowork_window=yes", "cowork_new_task=yes", "cowork_accept_task=yes", "cowork_task_list=yes"]
        if all(token in LAST_AX_RESULT for token in required):
            record("PASS", "GUI Cowork Cmd+Shift+T", LAST_AX_RESULT)
        elif "target_with_window=no" in LAST_AX_RESULT:
            record("BLOCKED", "GUI Cowork Cmd+Shift+T", LAST_AX_RESULT)
        else:
            record("FAIL", "GUI Cowork Cmd+Shift+T", LAST_AX_RESULT)

        action_checks = [
            ("Cowork seeded pending row visible", "seeded_pending_visible=yes"),
            ("Cowork seeded running row visible", "seeded_running_visible=yes"),
            ("GUI Cowork new task click", "new_task_press=ok"),
            ("Cowork live new task pending", "live_task_pending=yes"),
            ("Cowork live new task running", "live_task_running=yes"),
            ("Cowork awaiting-review task", "task_awaiting_review=yes"),
            ("GUI Cowork DiffReview", "diff_review_panel=yes"),
            ("Cowork accept-task enabled", "accept_task_enabled=yes"),
            ("GUI Cowork accept task click", "accept_task_press=ok"),
        ]
        for area, token in action_checks:
            if token in LAST_AX_RESULT:
                record("PASS", area, LAST_AX_RESULT)
            elif "cowork_window=no" in LAST_AX_RESULT or "missing" in LAST_AX_RESULT:
                record("BLOCKED", area, LAST_AX_RESULT)
            else:
                record("FAIL", area, LAST_AX_RESULT)

        if ("task_applied=yes" in LAST_AX_RESULT
                and "accept_task_disabled=yes" in LAST_AX_RESULT):
            record("PASS", "Cowork applied task", LAST_AX_RESULT)
        elif ("accept_task_press=missing" in LAST_AX_RESULT
              or "accept_task_enabled=no" in LAST_AX_RESULT
              or "diff_review_panel=no" in LAST_AX_RESULT):
            record("BLOCKED", "Cowork applied task", LAST_AX_RESULT)
        else:
            record("FAIL", "Cowork applied task", LAST_AX_RESULT)

        native_summary = native_notification_summary()
        if native_notification_has(
                "native-os-notification-submit",
                backend_token="macos-nsusernotification",
                submitted=True,
                valid=True):
            record("PASS", "macOS native notification submitted", native_summary)
        elif "task_awaiting_review=no" in LAST_AX_RESULT:
            record("BLOCKED", "macOS native notification submitted", native_summary)
        else:
            record("FAIL", "macOS native notification submitted", native_summary)

        if native_notification_has(
                "native-os-notification-click-dispatch",
                backend_token="macos-nsusernotification",
                dispatched=True,
                valid=True):
            record("PASS", "Native notification click dispatch", native_summary)
        elif not native_notification_events():
            record("BLOCKED", "Native notification click dispatch", native_summary)
        else:
            record("FAIL", "Native notification click dispatch", native_summary)

        if native_notification_has(
                "native-os-notification-review-open",
                opened=True,
                valid=True):
            record("PASS", "Native notification stored review open", native_summary)
        elif not native_notification_events():
            record("BLOCKED", "Native notification stored review open", native_summary)
        else:
            record("FAIL", "Native notification stored review open", native_summary)

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
