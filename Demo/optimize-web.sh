#!/bin/bash
# Re-encodes the demo clips in Demo/clips/ into small, web-friendly assets for the
# landing page: an H.264 MP4 per clip, plus a poster JPG.
#
# The originals are retina screen recordings (~3-5MB each). These are downscaled,
# stripped of audio, and encoded for autoplay-muted-loop playback. H.264 covers
# every browser on macOS (the audience), so there's no WebM/VP9 twin to ship.
#
# Usage: Demo/optimize-web.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Demo/clips"
OUT="$ROOT/docs/assets/clips"
mkdir -p "$OUT"

FPS=24
# Cap width so a clip never exceeds this; smaller sources are left as-is.
maxw() { case "$1" in layout) echo 960 ;; *) echo 720 ;; esac; }

for src in "$SRC"/*.mp4; do
  name="$(basename "$src" .mp4)"
  W="$(maxw "$name")"
  # Downscale only if wider than the cap; keep even dimensions.
  vf="scale='min($W,iw)':-2:flags=lanczos,fps=$FPS"

  echo "== $name =="

  ffmpeg -y -loglevel error -i "$src" \
    -vf "$vf" -an \
    -c:v libx264 -profile:v high -crf 33 -preset slow \
    -pix_fmt yuv420p -movflags +faststart \
    "$OUT/$name.mp4"

  # Poster: a frame ~40% through, same scale, for the <video poster> attribute.
  dur="$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$src" 2>/dev/null)"
  ts="$(python3 -c "print(max(0.1, ${dur:-1} * 0.4))")"
  ffmpeg -y -loglevel error -ss "$ts" -i "$src" \
    -vf "scale='min($W,iw)':-2:flags=lanczos" -frames:v 1 -q:v 4 \
    "$OUT/$name.jpg"

  printf "   mp4 %s  poster %s\n" \
    "$(du -h "$OUT/$name.mp4" | cut -f1)" \
    "$(du -h "$OUT/$name.jpg" | cut -f1)"
done

echo "done -> $OUT"
