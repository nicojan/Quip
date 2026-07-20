#!/bin/bash
# Records one demo scene to an MP4 by driving the DEBUG demo harness and capturing
# its window by CoreGraphics window id (works regardless of Space / occlusion /
# focus, using the calling shell's Screen Recording permission).
#
# `screencapture -v` occasionally yields an empty or mis-sized file, so each take
# is validated (non-empty, full width) and retried a few times.
#
# Usage: Demo/record-scene.sh <scene> [outdir]
#   scene: search | favorites | collections | overview
set -uo pipefail

SCENE="${1:?usage: record-scene.sh <scene> [outdir]}"
OUTDIR="${2:-Demo/clips}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/dd-demo/Build/Products/Debug/Quip.app/Contents/MacOS/Quip"
ASSETS="$ROOT/Demo/assets"
PROC="build/dd-demo/Build/Products/Debug/Quip.app"
mkdir -p "$OUTDIR"

kill_app() {
  pkill -f "$PROC" 2>/dev/null
  for _ in $(seq 1 25); do pgrep -f "$PROC" >/dev/null || break; sleep 0.2; done
}

attempt() {
  local TMP LOG GO REC WID DUR APP_PID SC_PID W
  TMP="$(mktemp -d)"; LOG="$TMP/demo.log"; GO="$TMP/go"; REC="$TMP/rec.mov"
  kill_app; sleep 0.3

  QUIP_DEMO=1 QUIP_DEMO_SCENE="$SCENE" QUIP_DEMO_GO="$GO" QUIP_DEMO_ASSETS="$ASSETS" "$APP" >"$LOG" 2>&1 &
  APP_PID=$!
  WID=""; DUR=""
  for _ in $(seq 1 100); do
    WID=$(grep -o 'DEMO_WINDOW_ID=[0-9]*' "$LOG" 2>/dev/null | head -1 | cut -d= -f2)
    DUR=$(grep -o 'SCENE_DURATION=[0-9]*' "$LOG" 2>/dev/null | head -1 | cut -d= -f2)
    [ -n "$WID" ] && [ -n "$DUR" ] && break
    sleep 0.1
  done
  if [ -z "$WID" ]; then kill "$APP_PID" 2>/dev/null; rm -rf "$TMP"; return 1; fi

  screencapture -o -l"$WID" -v -V "$((DUR + 2))" -x "$REC" &
  SC_PID=$!
  sleep 1.0            # let the recording go live before the scene starts
  touch "$GO"          # release the director
  wait "$SC_PID"
  kill "$APP_PID" 2>/dev/null

  W=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nk=1:nw=1 "$REC" 2>/dev/null)
  if [ ! -s "$REC" ] || [ -z "$W" ] || [ "$W" -lt 600 ]; then
    echo "  take invalid (width=${W:-none}); retrying"
    rm -rf "$TMP"; return 1
  fi

  ffmpeg -y -loglevel error -i "$REC" \
    -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2,fps=30" \
    -c:v libx264 -pix_fmt yuv420p -movflags +faststart "$OUTDIR/$SCENE.mp4"
  rm -rf "$TMP"
  return 0
}

for try in 1 2 3 4 5; do
  echo "scene=$SCENE attempt $try"
  if attempt; then
    echo "wrote $OUTDIR/$SCENE.mp4 ($(du -h "$OUTDIR/$SCENE.mp4" | cut -f1))"
    exit 0
  fi
done
echo "ERROR: $SCENE failed after retries"
exit 1
