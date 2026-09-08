#!/bin/bash
# Reports what Quip costs while nobody is looking at it.
#
# Two regressions this catches, both invisible in a short session and both
# shipped once (fixed in 1.1.16):
#   - every loaded thumbnail keeps a CVDisplayLink running behind the closed
#     popover, decoding frames on the main thread
#   - the image caches grow without a ceiling, so days of use reach 900 MB
#
# Usage: open Quip, browse a few searches so thumbnails load, close the
# popover, then run this. Takes about 10 seconds.

set -u
PID=$(pgrep -f "Quip.app/Contents/MacOS/Quip" | head -1)
if [ -z "$PID" ]; then
  echo "Quip is not running."
  exit 1
fi

TMP=$(mktemp -t quip-idle.XXXXXX)
trap 'rm -f "$TMP"' EXIT
if ! sample "$PID" 5 -f "$TMP" >/dev/null 2>&1 || [ ! -s "$TMP" ]; then
  echo "ERROR: sample produced nothing for pid $PID. Nothing was measured."
  exit 2
fi

LINKS=$(command grep -ac 'CVDisplayLink$' "$TMP")
if ! [ "$LINKS" -eq "$LINKS" ] 2>/dev/null; then
  echo "ERROR: could not count display links. Nothing was measured."
  exit 2
fi
FOOT=$(footprint -p "$PID" 2>/dev/null | command grep -a "phys_footprint:" | awk '{print $2, $3}')
PEAK=$(footprint -p "$PID" 2>/dev/null | command grep -a "phys_footprint_peak:" | awk '{print $2, $3}')
RASTER=$(footprint -p "$PID" 2>/dev/null | command grep -a "CG raster data" | awk '{print $1, $2}')
UPTIME=$(ps -o etime= -p "$PID" | tr -d ' ')

echo "Quip pid $PID, up $UPTIME"
echo "  (0 links only means something if you browsed first: a Quip that never"
echo "   loaded a thumbnail has nothing to animate and passes for free.)"
echo "  display links   $LINKS      (want 0 with the popover closed; 1.1.15 shipped 36)"
echo "  footprint       $FOOT"
echo "  peak footprint  $PEAK   (1.1.15 reached 938 MB over two days)"
echo "  CG raster       $RASTER"
echo
if [ "$LINKS" -gt 0 ]; then
  echo "FAIL: $LINKS display links are still running with the popover shut."
  echo "      Check that PopoverVisibility.isOpen reaches GifThumbnail."
  exit 1
fi
echo "Display links are stopped. Read the footprint yourself: it should sit"
echo "near the 128 MB cache ceiling plus the app's own overhead, and it should"
echo "fall when you close the popover, not only stop climbing."
