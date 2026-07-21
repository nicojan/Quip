#!/bin/bash
# Records the three layout presets (narrow / tall / wide) as native-size takes and
# crossfades them into one clip. Done separately from record-scene.sh because
# `screencapture -v -l` locks to the window's initial size and can't follow a live
# resize — so each preset is captured at its true size, then composited.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/dd-demo/Build/Products/Debug/Quip.app/Contents/MacOS/Quip"
ASSETS="$ROOT/Demo/assets"
OUT="$ROOT/Demo/clips"; mkdir -p "$OUT"
TMP="$(mktemp -d)"
HOLD=3            # seconds held on each preset
X=0.5            # crossfade duration

PROC="build/dd-demo/Build/Products/Debug/Quip.app"

rec_once() {
  local mode="$1" min_w="$2"
  pkill -f "$PROC" 2>/dev/null
  for _ in $(seq 1 25); do pgrep -f "$PROC" >/dev/null || break; sleep 0.2; done
  sleep 0.3
  QUIP_DEMO=1 QUIP_DEMO_LAYOUT="$mode" QUIP_DEMO_ASSETS="$ASSETS" "$APP" >"$TMP/$mode.log" 2>&1 &
  local pid=$! wid=""
  for _ in $(seq 1 100); do
    wid=$(grep -o 'DEMO_WINDOW_ID=[0-9]*' "$TMP/$mode.log" 2>/dev/null | head -1 | cut -d= -f2)
    [ -n "$wid" ] && break; sleep 0.1
  done
  [ -z "$wid" ] && { kill "$pid" 2>/dev/null; return 1; }
  sleep 1.6        # let the GIFs load in
  screencapture -o -l"$wid" -v -V "$HOLD" -x "$TMP/$mode.raw.mov"
  kill "$pid" 2>/dev/null
  local w
  w=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=nk=1:nw=1 "$TMP/$mode.raw.mov" 2>/dev/null)
  if [ ! -s "$TMP/$mode.raw.mov" ] || [ -z "$w" ] || [ "$w" -lt "$min_w" ]; then
    echo "  $mode take invalid (width=${w:-none}); retrying"; return 1
  fi
  ffmpeg -y -loglevel error -i "$TMP/$mode.raw.mov" \
    -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2,fps=30" -an \
    -c:v libx264 -pix_fmt yuv420p "$TMP/$mode.mp4"
  echo "$mode: $(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$TMP/$mode.mp4")"
}

rec() {
  # min widths guard against a half-res (1x display) or empty capture per preset.
  local mode="$1" min_w
  case "$mode" in narrow) min_w=560 ;; tall) min_w=800 ;; wide) min_w=1100 ;; *) min_w=560 ;; esac
  for _ in 1 2 3 4 5; do rec_once "$mode" "$min_w" && return 0; done
  echo "failed to record $mode"; return 1
}

rec narrow && rec tall && rec wide || { echo "recording failed"; exit 1; }

# Common canvas = the widest (wide) preset; center the smaller ones on it.
CANVAS=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$TMP/wide.mp4")
W="${CANVAS%,*}"; H="${CANVAS#*,}"
pad() {
  ffmpeg -y -loglevel error -i "$TMP/$1.mp4" \
    -vf "pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=0x0B0F1A,setsar=1,fps=30" \
    -c:v libx264 -pix_fmt yuv420p "$TMP/${1}_p.mp4"
}
pad narrow; pad tall; pad wide

# Crossfade narrow -> tall -> wide. Offsets: first at HOLD-X, second at 2*HOLD-2*X.
OFF1=$(python3 -c "print($HOLD-$X)")
OFF2=$(python3 -c "print(2*$HOLD-2*$X)")
ffmpeg -y -loglevel error \
  -i "$TMP/narrow_p.mp4" -i "$TMP/tall_p.mp4" -i "$TMP/wide_p.mp4" \
  -filter_complex "[0][1]xfade=transition=fade:duration=${X}:offset=${OFF1}[a];[a][2]xfade=transition=fade:duration=${X}:offset=${OFF2}[v]" \
  -map "[v]" -c:v libx264 -pix_fmt yuv420p -movflags +faststart "$OUT/layout.mp4"

rm -rf "$TMP"
echo "wrote $OUT/layout.mp4 ($(du -h "$OUT/layout.mp4" | cut -f1))"
