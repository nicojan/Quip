#!/bin/bash
# Records the size-morph clip as a cut-out: the popover on a transparent stage,
# toggled two → three → five → two per row, cut to one exact loop.
#
# Outputs (in <outdir>, default ~/Movies/quip-sizes-morph-<date>):
#   quip-sizes-morph-master-prores4444.mov   ProRes 4444 with alpha, 30 fps, 2x
#   png-alpha/                               the same frames as PNGs with alpha
#   quip-sizes-morph-preview-grey.mp4        H.264 on grey, for a quick look
#   contact-sheet-150ms.png                  a frame every 150 ms, on grey
#
# Capture is ScreenCaptureKit (Demo/tools/record-window.swift): neither Cap nor
# `screencapture -v` keeps a window's alpha. The harness is built with release
# optimisation so the morph runs at the speed it does in the shipped app.
#
# Usage: Demo/record-morph.sh [outdir]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$HOME/Movies/quip-sizes-morph-$(date +%F)}"
BUILD="$ROOT/build/dd-demo-opt"
APP="$BUILD/Build/Products/Debug/Quip.app/Contents/MacOS/Quip"
PROC="build/dd-demo-opt/Build/Products/Debug/Quip.app"
TAKE="$(mktemp -d)"
REC="$TAKE/record-window"

xcodebuild build -scheme Quip -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$BUILD" SWIFT_OPTIMIZATION_LEVEL=-O GCC_OPTIMIZATION_LEVEL=s \
  CODE_SIGN_IDENTITY=- ENABLE_HARDENED_RUNTIME=NO -quiet
swiftc -O -parse-as-library "$ROOT/Demo/tools/record-window.swift" -o "$REC"

pkill -f "$PROC" 2>/dev/null || true
sleep 0.6
QUIP_DEMO=1 QUIP_DEMO_STAGE=1 QUIP_DEMO_BG=clear QUIP_DEMO_SCENE=p-morph QUIP_DEMO_LAYOUT=narrow \
  QUIP_DEMO_GO="$TAKE/go" QUIP_DEMO_ASSETS="$ROOT/Demo/assets" QUIP_DEMO_LIBRARY="$ROOT/Demo/assets/library" \
  "$APP" > "$TAKE/demo.log" 2>&1 &
APP_PID=$!
WID=""
for _ in $(seq 1 100); do
  WID=$(grep -ao 'DEMO_WINDOW_ID=[0-9]*' "$TAKE/demo.log" | head -1 | cut -d= -f2 || true)
  [ -n "$WID" ] && break
  sleep 0.1
done
[ -n "$WID" ] || { echo "the demo window never appeared"; exit 1; }
sleep 2.5                                  # every GIF loads before the camera rolls
"$REC" "$WID" 9 "$TAKE/take.mov" > "$TAKE/rec.log" &
REC_PID=$!
sleep 1.0
touch "$TAKE/go"
wait "$REC_PID"
kill "$APP_PID" 2>/dev/null || true

# The scene prints SCENE_START / SCENE_END on the same host clock the recorder
# stamps its first frame with, so the loop is cut to the frame.
read -r SS DUR < <(python3 - "$TAKE" <<'EOF'
import re, sys
t = open(sys.argv[1] + "/rec.log").read() + open(sys.argv[1] + "/demo.log").read()
g = lambda k: float(re.search(k + r"=([0-9.]+)", t).group(1))
print(round(g("SCENE_START") - g("FIRST_FRAME_HOST"), 4), round(g("SCENE_END") - g("SCENE_START"), 4))
EOF
)

# The stage is 1280x800 pt; the crop keeps the widest popover (640 pt) with a
# 20-pt transparent margin all round.
mkdir -p "$OUT/png-alpha"
MASTER="$OUT/quip-sizes-morph-master-prores4444.mov"
ffmpeg -loglevel error -y -i "$TAKE/take.mov" -ss "$SS" -t "$DUR" \
  -vf "fps=30,crop=1360:1480:600:60" -c:v prores_ks -profile:v 4444 -pix_fmt yuva444p10le -an "$MASTER"
ffmpeg -loglevel error -y -i "$MASTER" -pix_fmt rgba "$OUT/png-alpha/quip-sizes-morph-%04d.png"
ffmpeg -loglevel error -y -f lavfi -i color=c=0x808080:s=1360x1480:r=30 -i "$MASTER" \
  -filter_complex "[0][1]overlay=shortest=1,format=yuv420p" \
  -c:v libx264 -crf 16 -preset slow -movflags +faststart -an "$OUT/quip-sizes-morph-preview-grey.mp4"
ffmpeg -loglevel error -y -i "$MASTER" -filter_complex \
  "color=c=0x808080:s=1360x1480[bg];[bg][0]overlay=shortest=1,fps=1/0.15,scale=340:-2,tile=9x4:padding=4:color=white" \
  -frames:v 1 "$OUT/contact-sheet-150ms.png"

# Every frame: the popover's top edge stays on one row, and nothing but the
# popover has any alpha (no cursor or ripple past its edge, no gaps inside it).
python3 - "$OUT/png-alpha" <<'EOF'
import glob, sys
from PIL import Image
bad = []
for p in sorted(glob.glob(sys.argv[1] + "/*.png")):
    a = Image.open(p).getchannel("A")
    bb = a.getbbox()
    inner = a.crop((bb[0] + 30, bb[1] + 30, bb[2] - 30, bb[3] - 30)) if bb else None
    if not bb or bb[1] != 40 or bb[3] != 1440 or (inner and inner.getextrema()[0] < 250):
        bad.append(p.rsplit("/", 1)[1])
n = len(glob.glob(sys.argv[1] + "/*.png"))
print(f"checked {n} frames: " + ("all clean" if not bad else f"PROBLEMS in {bad[:5]}"))
sys.exit(1 if bad else 0)
EOF
echo "wrote $OUT ($DUR s)"
