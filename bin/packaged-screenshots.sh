#!/usr/bin/env bash
# Capture packaged-app screenshots for R5 evidence.
# Usage: bin/packaged-screenshots.sh [APP_BUNDLE_PATH]
# Default app: test-install/可圈office.app

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$REPO/test-install/可圈office.app}"
SOFFICE="$APP/Contents/MacOS/soffice"
BUNDLE_ID="com.kdoffice.app"
OUT="$REPO/tmp/product-completion/screenshots"
WAIT="${PACKAGED_SHOT_WAIT:-14}"

[[ -x "$SOFFICE" ]] || { echo "soffice not found: $SOFFICE" >&2; exit 1; }
mkdir -p "$OUT"

capture() {
  local name="$1" flag="$2"
  local profile out log
  profile=$(mktemp -d -t kqoffice-shot.XXXXXX)
  out="$OUT/$name.png"
  log="$OUT/$name.log"
  rm -f "$out"

  "$SOFFICE" "$flag" --norestore --nofirststartwizard \
    "-env:UserInstallation=file://$profile" >"$log" 2>&1 &
  local pid=$!

  sleep "$WAIT"

  if ! kill -0 "$pid" 2>/dev/null; then
    echo "FAIL $name: soffice exited within ${WAIT}s (see $log)" >&2
    return 1
  fi

  osascript -e "tell application id \"$BUNDLE_ID\" to activate" >/dev/null 2>&1 || true
  sleep 1
  screencapture -x -o "$out"

  kill -TERM "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  rm -rf "$profile"

  [[ -s "$out" ]] || { echo "FAIL $name: empty PNG" >&2; return 1; }
  echo "OK $name -> $out"
}

cases=(
  "startcenter:--nodefault"
  "writer:--writer"
  "calc:--calc"
  "impress:--impress"
  "draw:--draw"
)

manifest="$OUT/manifest.md"
{
  echo "# Packaged-app screenshots"
  echo
  echo "Generated: $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "App: \`$APP\`"
  echo "Wait: ${WAIT}s"
  echo
  echo "| Surface | File | Status |"
  echo "| --- | --- | --- |"
} > "$manifest"

rc=0
for c in "${cases[@]}"; do
  name="${c%%:*}" flag="${c#*:}"
  if capture "$name" "$flag"; then
    size=$(stat -f%z "$OUT/$name.png" 2>/dev/null || echo 0)
    echo "| $name | \`screenshots/$name.png\` | pass (${size} bytes) |" >> "$manifest"
  else
    echo "| $name | — | fail (see \`screenshots/$name.log\`) |" >> "$manifest"
    rc=1
  fi
done

echo
echo "Manifest: $manifest"
exit $rc
