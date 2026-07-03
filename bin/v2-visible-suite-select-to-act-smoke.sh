#!/usr/bin/env bash
# V2 visible current-bundle Calc/Impress Select-to-act smoke.
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
import time
from ctypes import byref, c_bool, c_int, c_uint32, c_uint64, c_void_p
from pathlib import Path

ROOT = Path.cwd()
APP = Path(os.environ.get("KDOFFICE_APP_BUNDLE", str(ROOT / "instdir/可圈办公.app")))
REPORT = Path(os.environ.get(
    "V2_VISIBLE_SUITE_SELECT_REPORT",
    str(ROOT / "tmp/v2-visible-suite-select-to-act-smoke.md")))
LOG = Path(os.environ.get(
    "V2_VISIBLE_SUITE_SELECT_LOG",
    str(ROOT / "tmp/v2-visible-suite-select-to-act-smoke.log")))
KEEP_PROFILE = os.environ.get("V2_VISIBLE_SUITE_SELECT_KEEP_PROFILE", "0") == "1"
READY_TIMEOUT = int(os.environ.get("V2_VISIBLE_SUITE_SELECT_READY_TIMEOUT", "45"))
ACTION_TIMEOUT = int(os.environ.get("V2_VISIBLE_SUITE_SELECT_ACTION_TIMEOUT", "20"))
BASE_PORT = int(os.environ.get("V2_VISIBLE_SUITE_SELECT_UNO_PORT",
                               str(27000 + os.getpid() % 5000)))

SURFACES = [
    {
        "name": "Calc",
        "factory": "private:factory/scalc",
        "service": "com.sun.star.sheet.SpreadsheetDocument",
        "ui": "Contents/Resources/config/soffice.cfg/modules/scalc/ui/cell-range-popover.ui",
        "ui_needles": [b"CellRangePopover", b"btn_explain_data", b"btn_suggest_chart"],
        "sal": "+INFO.sc.inline_actions",
        "category": "sc.inline_actions",
        "popover_id": "CellRangePopover",
        "button_ids": ["btn_explain_data", "btn_suggest_chart", "btn_generate_formula"],
        "button_names": ["Explain data in selection", "Suggest chart for selection"],
        "click_id": "btn_explain_data",
        "click_name": "Explain data in selection",
        "scope": "visible Calc range selection + CellRangePopover + Explain data click",
    },
    {
        "name": "Impress",
        "factory": "private:factory/simpress",
        "service": "com.sun.star.presentation.PresentationDocument",
        "ui": "Contents/Resources/config/soffice.cfg/modules/simpress/ui/slide-element-popover.ui",
        "ui_needles": [b"SlideElementPopover", b"btn_rewrite_text", b"btn_translate_text"],
        "sal": "+INFO.sd.inline_actions",
        "category": "sd.inline_actions",
        "popover_id": "SlideElementPopover",
        "button_ids": ["btn_rewrite_text", "btn_translate_text", "btn_relayout"],
        "button_names": ["Rewrite text in selection", "Translate text in selection"],
        "click_id": "btn_rewrite_text",
        "click_name": "Rewrite text in selection",
        "scope": "visible Impress text shape selection + SlideElementPopover + Rewrite text click",
    },
]

PASSES = 0
BLOCKERS = 0
FAILURES = 0
ROWS = []
ACTIVE_PROCS = []
ACTIVE_PIDS = []
PROFILES = []
LAST_AX_RESULT = ""


def usage() -> None:
    print("""Usage:
  v2-visible-suite-select-to-act-smoke.sh [--app <bundle>] [--report <path>] [--log <path>] [--keep-profile]

Checks:
  - Launches the current builddir app bundle with isolated Calc and Impress profiles.
  - Seeds visible Calc and Impress documents through bundled pyuno.
  - Creates a real Calc cell-range selection and a real Impress text-shape selection.
  - Scans the exact builddir pid AX tree for the Calc/Impress Select-to-act popovers.
  - Clicks a surface action button and requires product response evidence:
    inline_action_request SAL_LOG when available, or popover closure after click.
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
    summary = md_escape(detail)
    if len(summary) > 220:
        summary = summary[:220] + "..."
    if status == "PASS":
        PASSES += 1
        print(f"PASS: {area} -- {summary}", flush=True)
    elif status == "BLOCKED":
        BLOCKERS += 1
        print(f"BLOCKED: {area} -- {summary}", flush=True)
    else:
        FAILURES += 1
        print(f"FAIL: {area} -- {summary}", file=sys.stderr, flush=True)


def write_report(status: str) -> None:
    target_status = "ready" if "target_seen=yes" in LAST_AX_RESULT and "target_with_window=yes" in LAST_AX_RESULT else "blocked"
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    with REPORT.open("w", encoding="utf-8") as f:
        f.write("# V2 Visible Suite Select-to-Act Smoke\n\n")
        f.write(f"- Status: {status}\n")
        f.write(f"- Target attribution: {target_status}\n")
        f.write(f"- App bundle: {APP}\n")
        f.write(f"- UNO base port: {BASE_PORT}\n")
        f.write("- Isolated profiles: " + (" ".join(PROFILES) if PROFILES else "<none>") + "\n")
        f.write(f"- Checks passed: {PASSES}\n")
        f.write(f"- Checks blocked: {BLOCKERS}\n")
        f.write(f"- Checks failed: {FAILURES}\n")
        f.write("- Scope: strict current builddir PID attribution + visible Calc/Impress selection + popover + action click-through evidence\n\n")
        f.write("| Status | Area | Detail |\n")
        f.write("|---|---|---|\n")
        for row in ROWS:
            f.write(row + "\n")


def cleanup() -> None:
    for pid in ACTIVE_PIDS:
        try:
            os.kill(pid, 15)
        except OSError:
            pass
    for proc in ACTIVE_PROCS:
        try:
            proc.terminate()
            proc.wait(timeout=5)
        except Exception:
            try:
                proc.kill()
            except Exception:
                pass
    for pid in ACTIVE_PIDS:
        try:
            os.kill(pid, 9)
        except OSError:
            pass
    if not KEEP_PROFILE:
        for profile in PROFILES:
            shutil.rmtree(profile, ignore_errors=True)


def binary_contains(path: Path, needles: list[bytes]) -> bool:
    try:
        data = path.read_bytes()
    except OSError:
        return False
    return all(needle in data for needle in needles)


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


def uno_socket_ready(port: int) -> bool:
    sock = socket.socket()
    sock.settimeout(0.25)
    try:
        sock.connect(("127.0.0.1", port))
        return True
    except OSError:
        return False
    finally:
        sock.close()


def wait_for_uno(port: int, proc: subprocess.Popen) -> bool:
    deadline = time.monotonic() + READY_TIMEOUT
    while time.monotonic() < deadline:
        if uno_socket_ready(port):
            return True
        if proc.poll() is not None:
            return False
        time.sleep(0.5)
    return False


def launch_surface(surface: dict, port: int) -> tuple[subprocess.Popen, list[int], str]:
    before = builddir_pids()
    profile = tempfile.mkdtemp(prefix=f"kqoffice-visible-{surface['name'].lower()}-select.")
    PROFILES.append(profile)
    env = dict(os.environ)
    env["KQOFFICE_AI_STUB_RUNTIME"] = "1"
    env["KQOFFICE_AI_DISABLE_PROBE"] = "1"
    env["SAL_LOG"] = surface["sal"]
    with LOG.open("a", encoding="utf-8") as log:
        log.write(f"\n=== {surface['name']} launch ===\n")
        log.write(f"Profile: {profile}\n")
        log.write(f"UNO port: {port}\n")
        proc = subprocess.Popen([
            str(APP / "Contents/MacOS/soffice"),
            "--nologo",
            "--nofirststartwizard",
            "--norestore",
            "--nolockcheck",
            f"--accept=socket,host=127.0.0.1,port={port};urp;",
            f"-env:UserInstallation=file://{profile}",
            surface["factory"],
        ], stdout=log, stderr=subprocess.STDOUT, env=env)
    ACTIVE_PROCS.append(proc)
    seen: set[int] = set()
    for _ in range(24):
        current = builddir_pids()
        new = sorted(current - before)
        if new:
            seen.update(new)
            break
        if proc.poll() is not None:
            break
        time.sleep(0.5)
    pids = sorted(seen)
    ACTIVE_PIDS.extend(pids)
    return proc, pids, profile


def run_bundled_seed(surface: dict, port: int) -> str:
    bundled_python = APP / "Contents/Resources/python"
    if not bundled_python.exists():
        return f"seed=failed missing_python={bundled_python}"
    if surface["name"] == "Calc":
        code = r'''
import sys
import time
import uno

port = sys.argv[1]
ctx = uno.getComponentContext()
smgr = ctx.ServiceManager
resolver = smgr.createInstanceWithContext("com.sun.star.bridge.UnoUrlResolver", ctx)
remote = None
last_error = None
for _ in range(30):
    try:
        remote = resolver.resolve(f"uno:socket,host=127.0.0.1,port={port};urp;StarOffice.ComponentContext")
        break
    except Exception as exc:
        last_error = exc
        time.sleep(0.5)
if remote is None:
    print(f"seed=failed connect_error={last_error!r}")
    raise SystemExit(0)
rsmgr = remote.ServiceManager
desktop = rsmgr.createInstanceWithContext("com.sun.star.frame.Desktop", remote)
doc = desktop.getCurrentComponent()
if doc is None or not doc.supportsService("com.sun.star.sheet.SpreadsheetDocument"):
    doc = desktop.loadComponentFromURL("private:factory/scalc", "_blank", 0, ())
sheet = doc.Sheets.getByIndex(0)
for row, values in enumerate((("North", "10"), ("South", "20"))):
    for col, value in enumerate(values):
        sheet.getCellByPosition(col, row).String = value
rng = sheet.getCellRangeByName("A1:B2")
doc.CurrentController.select(rng)
try:
    doc.CurrentController.Frame.activate()
    doc.CurrentController.Frame.ContainerWindow.setFocus()
except Exception:
    pass
print("seed=ok surface=Calc selected=A1:B2")
time.sleep(2.0)
'''
    else:
        code = r'''
import sys
import time
import uno

port = sys.argv[1]
ctx = uno.getComponentContext()
smgr = ctx.ServiceManager
resolver = smgr.createInstanceWithContext("com.sun.star.bridge.UnoUrlResolver", ctx)
remote = None
last_error = None
for _ in range(40):
    try:
        remote = resolver.resolve(f"uno:socket,host=127.0.0.1,port={port};urp;StarOffice.ComponentContext")
        break
    except Exception as exc:
        last_error = exc
        time.sleep(0.5)
if remote is None:
    print(f"seed=failed connect_error={last_error!r}")
    raise SystemExit(0)
rsmgr = remote.ServiceManager
desktop = rsmgr.createInstanceWithContext("com.sun.star.frame.Desktop", remote)
doc = desktop.getCurrentComponent()
if doc is None or not doc.supportsService("com.sun.star.presentation.PresentationDocument"):
    doc = desktop.loadComponentFromURL("private:factory/simpress", "_blank", 0, ())
for _ in range(20):
    if doc.getDrawPages().getCount() > 0:
        break
    time.sleep(0.5)
page = doc.getDrawPages().getByIndex(0)
shape = doc.createInstance("com.sun.star.drawing.TextShape")
pos = uno.createUnoStruct("com.sun.star.awt.Point")
pos.X = 3000
pos.Y = 2500
size = uno.createUnoStruct("com.sun.star.awt.Size")
size.Width = 9000
size.Height = 2500
shape.Position = pos
shape.Size = size
shape.String = "Impress visible select smoke"
page.add(shape)
try:
    doc.CurrentController.setCurrentPage(page)
except Exception:
    pass
doc.CurrentController.select(shape)
try:
    doc.CurrentController.Frame.activate()
    doc.CurrentController.Frame.ContainerWindow.setFocus()
except Exception:
    pass
print("seed=ok surface=Impress selected=textshape")
time.sleep(2.0)
'''
    proc = subprocess.run([str(bundled_python), "-", str(port)], input=code, text=True,
                          capture_output=True, check=False, timeout=60)
    out = (proc.stdout + proc.stderr).strip()
    if proc.returncode != 0:
        return f"seed=failed returncode={proc.returncode} output={out}"
    return out or "seed=failed empty_output"


def wait_log_contains(offset: int, category: str, timeout: int) -> str:
    deadline = time.monotonic() + timeout
    last = ""
    while time.monotonic() < deadline:
        try:
            text = LOG.read_text(encoding="utf-8", errors="replace")[offset:]
        except OSError:
            text = ""
        last = "\n".join(text.splitlines()[-20:])
        if "inline_action_request=" in text and category in text:
            return "inline_action_request=seen category=" + category
        if "inline_action_request=" in text:
            return "inline_action_request=seen category=unmatched"
        time.sleep(0.5)
    return "inline_action_request=missing tail=" + last


def ax_probe_and_click(surface: dict, target_pids: list[int]) -> str:
    AS = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices")
    CF = ctypes.cdll.LoadLibrary("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
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
    AS.AXUIElementPerformAction.argtypes = [c_void_p, CFRef]
    AS.AXUIElementPerformAction.restype = c_int
    AS.GetProcessForPID.argtypes = [c_int, ctypes.POINTER(ProcessSerialNumber)]
    AS.GetProcessForPID.restype = c_int
    AS.SetFrontProcess.argtypes = [ctypes.POINTER(ProcessSerialNumber)]
    AS.SetFrontProcess.restype = c_int
    AS.CGEventCreateMouseEvent.argtypes = [c_void_p, c_uint32, CGPoint, c_uint32]
    AS.CGEventCreateMouseEvent.restype = CFRef
    AS.CGEventPost.argtypes = [c_uint32, CFRef]
    AS.AXValueGetValue.argtypes = [CFRef, c_uint32, c_void_p]
    AS.AXValueGetValue.restype = c_bool

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
    CF.CFStringGetCString.restype = c_bool

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
        if depth > 13 or limit[0] > 14000:
            return
        limit[0] += 1
        yield elem
        for child in children(elem):
            yield from walk(child, depth + 1, limit)

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

    def popover_present(app) -> bool:
        for elem in walk(app):
            role = attr_string(elem, "AXRole")
            title = attr_string(elem, "AXTitle")
            value = attr_string(elem, "AXValue")
            ident = attr_string(elem, "AXIdentifier")
            text = " ".join([role, title, value, ident])
            if surface["popover_id"] in text or surface["click_id"] in text:
                return True
        return False

    lines = [f"surface={surface['name']}", f"ax_trusted={'yes' if AS.AXIsProcessTrusted() else 'no'}"]
    target_seen = False
    target_with_window = False
    popover_seen = False
    seen_buttons: set[str] = set()
    click_elem = None
    click_press_err = None
    mouse_detail = "mouse_click=not-needed"
    hits = []

    for pid in target_pids:
        app = AS.AXUIElementCreateApplication(pid)
        actual = c_int(-1)
        get_pid_err = AS.AXUIElementGetPid(app, byref(actual))
        target = get_pid_err == 0 and actual.value == pid
        target_seen = target_seen or target
        current_windows = windows(app)
        target_with_window = target_with_window or (target and bool(current_windows))
        lines.append(f"candidate pid={pid} axGetPidErr={get_pid_err} actualPid={actual.value} target={str(target).lower()} title={attr_string(app, 'AXTitle')} windows={len(current_windows)}")
        if not target:
            continue

        psn = ProcessSerialNumber()
        front_err = AS.GetProcessForPID(pid, byref(psn))
        set_front_err = AS.SetFrontProcess(byref(psn)) if front_err == 0 else -1
        raise_errs = [str(perform(win, "AXRaise")) for win in current_windows]
        lines.append(f"front pid={pid} frontErr={front_err} setFrontErr={set_front_err} raiseErrs={','.join(raise_errs) or '<none>'}")
        time.sleep(0.8)

        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            local_hits = []
            local_click = None
            for elem in walk(app):
                role = attr_string(elem, "AXRole")
                title = attr_string(elem, "AXTitle")
                value = attr_string(elem, "AXValue")
                ident = attr_string(elem, "AXIdentifier")
                text = " ".join([role, title, value, ident])
                if surface["popover_id"] in text:
                    popover_seen = True
                    local_hits.append(f"popover role={role} title={title} ident={ident}")
                for button_id in surface["button_ids"]:
                    if button_id in text:
                        seen_buttons.add(button_id)
                        local_hits.append(f"button role={role} title={title} ident={ident}")
                for button_name in surface["button_names"]:
                    if button_name in text:
                        local_hits.append(f"button-name role={role} title={title} ident={ident}")
                if surface["click_id"] in text or surface["click_name"] in text:
                    local_click = elem
            if local_hits:
                hits.extend(local_hits)
            if local_click:
                click_elem = local_click
            if popover_seen and click_elem and len(seen_buttons) >= 2:
                break
            time.sleep(0.8)

        if click_elem:
            offset = LOG.stat().st_size if LOG.exists() else 0
            mouse_ok, mouse_detail = click_element(click_elem)
            log_result = wait_log_contains(offset, surface["category"], 3)
            if "inline_action_request=seen" not in log_result:
                click_press_err = perform(click_elem, "AXPress")
                time.sleep(1.0)
                log_result = wait_log_contains(offset, surface["category"], ACTION_TIMEOUT)
                lines.append(f"axpress_fallback={'ok' if click_press_err == 0 else 'failed'} err={click_press_err}")
            lines.append(f"mouse_click={'ok' if mouse_ok else 'blocked'} {mouse_detail}")
            lines.append(log_result)
            closed = False
            if "inline_action_request=seen" not in log_result:
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    if not popover_present(app):
                        closed = True
                        break
                    time.sleep(0.5)
            lines.append(f"popover_closed_after_click={'yes' if closed else 'not-needed' if 'inline_action_request=seen' in log_result else 'no'}")
        if app:
            CF.CFRelease(app)

    lines.append(f"target_seen={'yes' if target_seen else 'no'}")
    lines.append(f"target_with_window={'yes' if target_with_window else 'no'}")
    lines.append(f"popover_seen={'yes' if popover_seen else 'no'}")
    lines.append("buttons_seen=" + ",".join(sorted(seen_buttons)))
    lines.append(f"click_button={'yes' if click_elem else 'no'} id={surface['click_id']}")
    if click_elem:
        status = "ok" if click_press_err == 0 else "not-needed" if "inline_action_request=seen" in "\n".join(lines) else "failed"
        lines.append(f"click_press={status} err={click_press_err} {mouse_detail}")
    lines.append("hits=" + ";".join(hits[:12]))
    return "\n".join(lines)


def run_surface(surface: dict, index: int) -> None:
    global LAST_AX_RESULT
    ui_path = APP / surface["ui"]
    if ui_path.exists() and binary_contains(ui_path, surface["ui_needles"]):
        record("PASS", f"{surface['name']} UI resource parity",
               f"{surface['popover_id']} resource and action buttons present")
    else:
        record("FAIL", f"{surface['name']} UI resource parity",
               f"missing resource or button ids at {ui_path}")

    port = BASE_PORT + index
    proc, pids, _profile = launch_surface(surface, port)
    if pids:
        record("PASS", f"{surface['name']} builddir process launch",
               "new builddir soffice pid(s): " + " ".join(map(str, pids)))
    else:
        record("FAIL", f"{surface['name']} builddir process launch",
               "no new builddir soffice pid")
        return

    if wait_for_uno(port, proc):
        record("PASS", f"{surface['name']} UNO readiness", f"uno_socket=ready port={port}")
    else:
        record("FAIL", f"{surface['name']} UNO readiness", f"uno_socket=not-ready port={port}")
        return

    seed = run_bundled_seed(surface, port)
    with LOG.open("a", encoding="utf-8") as log:
        log.write(seed + "\n")
    if "seed=ok" in seed:
        record("PASS", f"{surface['name']} visible selection seed", seed)
    else:
        record("FAIL", f"{surface['name']} visible selection seed", seed)
        return

    LAST_AX_RESULT = ax_probe_and_click(surface, pids)
    with LOG.open("a", encoding="utf-8") as log:
        log.write(LAST_AX_RESULT + "\n")

    if "target_seen=yes" in LAST_AX_RESULT and "target_with_window=yes" in LAST_AX_RESULT:
        record("PASS", f"{surface['name']} AX target attribution", LAST_AX_RESULT)
    else:
        record("FAIL", f"{surface['name']} AX target attribution", LAST_AX_RESULT)

    if "popover_seen=yes" in LAST_AX_RESULT and "click_button=yes" in LAST_AX_RESULT:
        record("PASS", f"{surface['name']} Select-to-act popover", LAST_AX_RESULT)
    else:
        record("FAIL", f"{surface['name']} Select-to-act popover", LAST_AX_RESULT)

    if ("mouse_click=ok" in LAST_AX_RESULT or "click_press=ok" in LAST_AX_RESULT
            or "click_press=not-needed" in LAST_AX_RESULT):
        record("PASS", f"{surface['name']} action button click", LAST_AX_RESULT)
    else:
        record("FAIL", f"{surface['name']} action button click", LAST_AX_RESULT)

    if ("inline_action_request=seen" in LAST_AX_RESULT
            or "popover_closed_after_click=yes" in LAST_AX_RESULT):
        record("PASS", f"{surface['name']} action dispatch evidence",
               LAST_AX_RESULT)
    else:
        record("FAIL", f"{surface['name']} action dispatch evidence",
               LAST_AX_RESULT)


def main() -> int:
    parse_args(sys.argv[1:])
    atexit.register(cleanup)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    LOG.write_text("=== V2 visible suite Select-to-act smoke ===\n", encoding="utf-8")

    soffice = APP / "Contents/MacOS/soffice"
    bundled_python = APP / "Contents/Resources/python"
    if not soffice.exists():
        print(f"FAIL: missing executable soffice in app bundle: {APP}", file=sys.stderr)
        return 1
    if not bundled_python.exists():
        print(f"FAIL: missing bundled python in app bundle: {APP}", file=sys.stderr)
        return 1

    for index, surface in enumerate(SURFACES):
        run_surface(surface, index)

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
