#!/bin/bash
# Watches for a popover close and reports whether the decoded GIF frames were
# actually handed back.
#
# This is the check that would have caught the 1.1.16 bug. That release set
# `clearBufferWhenStopped = true` in `onViewCreate`, where SDWebImageSwiftUI's
# `configureView` overwrites it after every load — so the flag was on for an
# instant at view creation and off before a single frame decoded. It freed
# nothing for a whole release, and no test noticed, because a unit test can only
# assert the value we asked for, not the value the view ends up with.
#
# The measurement is deliberately a BEFORE/AFTER inside one process. Absolute
# footprints are not reproducible between runs on this machine (the same build
# has measured 63-74 MB and 190-203 MB, cause unknown), so comparing two
# launches proves nothing. A delta within one process is immune to that.
#
# Usage: open Quip, browse a few searches so thumbnails load, then run this and
# close the popover when it says it is watching. Or run it first and browse.

set -u
POLL=8            # seconds between checks; `sample` is not cheap, so not faster
DEADLINE=600      # give up after 10 minutes of no close

PID=$(pgrep -f "Quip.app/Contents/MacOS/Quip" | head -1)
if [ -z "$PID" ]; then
  echo "Quip is not running."
  exit 1
fi

# `footprint` reports B, KB, MB or GB per line. Reading the number and ignoring
# the unit is how an earlier version of this reported a 7520 MB raster figure.
to_mb() {
  awk -v s="${1:-0 MB}" 'BEGIN{
    split(s, f, /[ \t]+/); n=f[1]+0; u=f[2];
    if (u=="B")       n=n/1048576;
    else if (u=="KB") n=n/1024;
    else if (u=="GB") n=n*1024;
    else if (u!="MB" && u!="") { printf "?%s", u; exit }
    printf "%.0f", n
  }'
}

links() {
  local t out
  t=$(mktemp -t qbr.XXXXXX)
  if sample "$PID" 1 -f "$t" >/dev/null 2>&1 && [ -s "$t" ]; then
    out=$(command grep -ac 'CVDisplayLink$' "$t")
  else
    out=""      # empty, not 0: a failed sample must never read as "closed"
  fi
  rm -f "$t"
  echo "$out"
}

# echoes "<footprint MB> <raster MB> <raster objects>"
snapshot() {
  local snap
  snap=$(footprint -p "$PID" 2>/dev/null)
  echo "$(to_mb "$(command grep -a 'phys_footprint:' <<<"$snap" | awk '{print $2, $3}')")" \
       "$(to_mb "$(command grep -a 'CG raster data'  <<<"$snap" | awk '{print $1, $2}')")" \
       "$(command grep -a 'CG raster data' <<<"$snap" | awk '{print $7}' | tr -d ' ')"
}

echo "Watching Quip pid $PID. Browse so thumbnails load, then close the popover."
echo "(Waiting for the display-link count to go from above zero to zero.)"

OPEN_SNAP=""
OPEN_LINKS=0
ELAPSED=0

while [ "$ELAPSED" -lt "$DEADLINE" ]; do
  L=$(links)
  if [ -z "$L" ]; then
    echo "ERROR: sample produced nothing for pid $PID. Nothing was measured."
    exit 2
  fi

  if [ "$L" -gt 0 ]; then
    # Popover is open with GIFs animating: keep the most recent open reading.
    OPEN_SNAP=$(snapshot)
    OPEN_LINKS=$L
  elif [ -n "$OPEN_SNAP" ]; then
    # Was open, now closed. Let the teardown finish before reading.
    sleep 5
    read -r c_foot c_rast c_obj <<<"$(snapshot)"
    read -r o_foot o_rast o_obj <<<"$OPEN_SNAP"

    echo
    echo "  popover open ($OPEN_LINKS display links)"
    echo "    footprint      ${o_foot} MB"
    echo "    CG raster      ${o_rast} MB in ${o_obj} objects"
    echo "  popover closed (0 display links)"
    echo "    footprint      ${c_foot} MB"
    echo "    CG raster      ${c_rast} MB in ${c_obj} objects"
    echo "    change         footprint $((c_foot - o_foot)) MB, raster $((c_rast - o_rast)) MB, objects $((c_obj - o_obj))"
    echo

    if [ "$o_obj" -lt 50 ]; then
      echo "INCONCLUSIVE: only $o_obj raster objects while open, so there was"
      echo "              nothing much to release. Browse more and re-run."
      exit 3
    fi
    # Measured with the fix in place: 1404 objects down to 48. Anything that
    # leaves most of them alive means the buffers are not being handed back.
    if [ "$c_obj" -gt $((o_obj / 2)) ]; then
      echo "FAIL: $c_obj of $o_obj raster objects survived the close."
      echo "      Check that GifThumbnail still applies .purgeable(true) as an"
      echo "      AnimatedImage modifier. Setting clearBufferWhenStopped on the"
      echo "      view inside .onViewCreate does nothing - configureView resets"
      echo "      it after every load. That was the 1.1.16 bug."
      exit 1
    fi
    echo "PASS: the decoded frames were released on close."
    exit 0
  fi

  sleep "$POLL"
  ELAPSED=$((ELAPSED + POLL))
done

if [ -z "$OPEN_SNAP" ]; then
  echo "TIMED OUT after ${DEADLINE}s without ever seeing an animating GIF."
  echo "Nothing was measured - open the popover and browse, then re-run."
else
  echo "TIMED OUT after ${DEADLINE}s. Saw the popover open but never close."
  echo "Nothing was measured."
fi
exit 2
