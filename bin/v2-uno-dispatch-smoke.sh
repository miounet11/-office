#!/usr/bin/env bash
# V2 UNO dispatch smoke for installed 可圈办公.app.
#
# Starts the real app bundle with an isolated profile and a UNO accept socket,
# connects with the bundled LibreOfficePython/pyuno runtime, opens a hidden
# Writer document frame, and proves V2 user-entry commands resolve at runtime.
# It dispatches only non-modal commands; Cowork is query-only because the real
# command opens a modal dialog.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mkdir -p tmp

app="${KDOFFICE_APP_BUNDLE:-$repo_root/instdir/可圈办公.app}"
report="${V2_UNO_DISPATCH_REPORT:-tmp/v2-uno-dispatch-smoke.md}"
log="${V2_UNO_DISPATCH_LOG:-tmp/v2-uno-dispatch-smoke.log}"
keep_profile="${V2_UNO_DISPATCH_KEEP_PROFILE:-0}"
profile=""
soffice_pid=""
port=""

usage() {
    cat <<'EOF'
Usage:
  v2-uno-dispatch-smoke.sh [--app <bundle>] [--report <path>] [--log <path>] [--keep-profile]

Checks:
  - Launches the installed app bundle with a UNO accept socket and isolated user profile.
  - Connects via the bundled LibreOfficePython/pyuno runtime.
  - Opens a hidden Writer document to obtain a live frame.
  - queryDispatch succeeds for CommandPalette, CoworkTaskManager,
    SidebarDeck.PropertyDeck, and SidebarDeck.DiffReviewDeck.
  - DispatchHelper executes the non-modal PropertyDeck and CommandPalette commands.

This is not a visible GUI click-through; it is a live app-session UNO dispatch smoke.
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

soffice="$app/Contents/MacOS/soffice"
python="$app/Contents/Resources/python"
if [[ ! -x "$soffice" ]]; then
    echo "FAIL: missing executable soffice in app bundle: $app" >&2
    exit 1
fi
if [[ ! -x "$python" ]]; then
    echo "FAIL: missing bundled LibreOfficePython launcher: $python" >&2
    exit 1
fi

cleanup() {
    if [[ -n "${soffice_pid:-}" ]]; then
        kill "$soffice_pid" 2>/dev/null || true
        wait "$soffice_pid" 2>/dev/null || true
    fi
    if [[ "$keep_profile" != "1" && -n "${profile:-}" ]]; then
        rm -rf "$profile"
    fi
}
trap cleanup EXIT

profile="$(mktemp -d /tmp/kqoffice-uno-dispatch-profile.XXXXXX)"
port="${V2_UNO_DISPATCH_PORT:-$((22000 + RANDOM % 10000))}"

echo "=== V2 UNO dispatch smoke ==="
echo "App bundle: $app"
echo "Profile: $profile"
echo "Port: $port"

KQOFFICE_AI_STUB_RUNTIME=1 \
KQOFFICE_AI_DISABLE_PROBE=1 \
"$soffice" \
    --headless \
    --nologo \
    --nodefault \
    --nofirststartwizard \
    --norestore \
    --nolockcheck \
    "--accept=socket,host=127.0.0.1,port=$port;urp;" \
    "-env:UserInstallation=file://$profile" \
    >"$log" 2>&1 &
soffice_pid=$!

"$python" - "$port" "$app" "$profile" "$report" <<'PY'
import sys
import time
import traceback

import uno
from com.sun.star.beans import PropertyValue

port, app, profile, report = sys.argv[1:5]
query_commands = [
    ".uno:CommandPalette",
    ".uno:CoworkTaskManager",
    ".uno:SidebarDeck.PropertyDeck",
    ".uno:SidebarDeck.DiffReviewDeck",
]
dispatch_commands = [
    ".uno:SidebarDeck.PropertyDeck",
    ".uno:CommandPalette",
]
rows = []

def record(status, area, detail):
    rows.append((status, area, detail))
    print(f"{status}: {area} -- {detail}")

ctx = uno.getComponentContext()
smgr = ctx.ServiceManager
resolver = smgr.createInstanceWithContext(
    "com.sun.star.bridge.UnoUrlResolver", ctx)
connect_url = (
    f"uno:socket,host=127.0.0.1,port={port};urp;StarOffice.ComponentContext"
)

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
    raise RuntimeError(f"UNO connection failed: {last_error!r}")
record("PASS", "uno connection", connect_url)

rsmgr = remote.ServiceManager
desktop = rsmgr.createInstanceWithContext("com.sun.star.frame.Desktop", remote)
hidden = PropertyValue()
hidden.Name = "Hidden"
hidden.Value = True
model = None
try:
    model = desktop.loadComponentFromURL(
        "private:factory/swriter", "_blank", 0, (hidden,))
    if model is None:
        raise RuntimeError("loadComponentFromURL returned None")
    record("PASS", "writer model", "private:factory/swriter hidden document loaded")

    frame = model.CurrentController.Frame
    provider = frame
    transformer = rsmgr.createInstanceWithContext(
        "com.sun.star.util.URLTransformer", remote)
    helper = rsmgr.createInstanceWithContext(
        "com.sun.star.frame.DispatchHelper", remote)

    def parse_uno_url(command):
        url = uno.createUnoStruct("com.sun.star.util.URL")
        url.Complete = command
        _, parsed = transformer.parseStrict(url)
        return parsed

    for command in query_commands:
        dispatch = provider.queryDispatch(parse_uno_url(command), "_self", 0)
        if dispatch:
            record("PASS", "queryDispatch", f"{command} resolved on live Writer frame")
        else:
            record("FAIL", "queryDispatch", f"{command} did not resolve")

    for command in dispatch_commands:
        try:
            result = helper.executeDispatch(frame, command, "_self", 0, ())
            record("PASS", "executeDispatch",
                   f"{command} executed; result state={getattr(result, 'State', '<none>')}")
        except Exception as exc:
            record("FAIL", "executeDispatch", f"{command} raised {exc!r}")
finally:
    if model is not None:
        try:
            model.close(True)
            record("PASS", "writer model", "hidden document closed")
        except Exception as exc:
            record("FAIL", "writer model", f"close failed: {exc!r}")
    try:
        desktop.terminate()
        record("PASS", "app session", "desktop terminate requested")
    except Exception as exc:
        record("FAIL", "app session", f"terminate failed: {exc!r}")

failed = sum(1 for status, _, _ in rows if status != "PASS")
with open(report, "w", encoding="utf-8") as f:
    f.write("# V2 UNO Dispatch Smoke\n\n")
    f.write(f"- Status: {'passed' if failed == 0 else 'failed'}\n")
    f.write(f"- App bundle: {app}\n")
    f.write(f"- Isolated profile: {profile}\n")
    f.write(f"- Port: {port}\n")
    f.write(f"- Checks passed: {len(rows) - failed}\n")
    f.write(f"- Checks failed: {failed}\n")
    f.write("- Scope: live app-bundle UNO bridge + Writer frame query/dispatch\n\n")
    f.write("| Status | Area | Detail |\n")
    f.write("|---|---|---|\n")
    for status, area, detail in rows:
        safe_detail = str(detail).replace("|", "\\|")
        f.write(f"| {status} | {area} | {safe_detail} |\n")

if failed:
    print(f"Status: failed ({failed} checks failed)")
    sys.exit(1)
print(f"Status: passed")
print(f"Checks: {len(rows)}")
print(f"Report: {report}")
PY

if [[ "$keep_profile" == "1" ]]; then
    echo "Profile kept: $profile"
fi
