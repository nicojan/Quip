# Demo clip harness

Records short screen clips of Quip's features for the README and landing page.
Everything here is for making demos — none of it ships. The app code it relies on
is behind `#if DEBUG`, so a Release build excludes it.

## How it works

`QUIP_DEMO=1` makes the app open a demo window instead of the menu-bar popover
(see `Quip/Support/DemoHarness.swift`). The window hosts the real `MenuContentView`,
but:

- GIFs come from local files in `assets/`, served by an offline `DemoGifSource` —
  no Giphy key, no network.
- Favorites, collections, and recents are seeded into a throwaway `UserDefaults`
  suite, so your real library is never touched.
- A scripted `DemoDirector` runs one feature "scene" (search, favorites,
  collections, overview) by driving the same state a click would, and moves a
  synthetic cursor with click ripples on top.

The window is non-activating and click-through, so it can't steal focus or be
disturbed while recording. Capture is by CoreGraphics window id
(`screencapture -v -l<id>`), which works no matter which Space or display is in
front.

## Recording

```sh
# one scene → Demo/clips/<scene>.mp4
Demo/record-scene.sh search
Demo/record-scene.sh favorites
Demo/record-scene.sh collections
Demo/record-scene.sh overview

# the three layout sizes, crossfaded into one clip
Demo/record-layout.sh
```

`screencapture -v` sometimes returns an empty or half-size file, so each take is
checked and retried up to five times. Layout is recorded as three separate
takes (narrow / tall / wide) because `screencapture -v -l` locks to the window's
starting size and can't follow a live resize.

Both scripts build the Debug app into `build/dd-demo` first. Grant Screen
Recording permission to whatever runs them (Terminal, etc.) once.

## Portfolio clips

`Demo/record-portfolio.py take <clip>` records one of three portfolio clips (`1-collections`, `2-copy`, `3-sizes`) with the Cap CLI and exports a readme (1920x1200, white), website (2560x1600, warm grey) and social (1080x1080 square) version, matching the Chorus clips. It then scans every frame for anything touching the edge or a missing popover, and writes contact sheets and numbered stills. Takes land in `clips/portfolio/<date>/<clip>/t<n>/`; the picked ones go in `clips/FINAL/` with a `REVIEW.md`. It never uploads.

What it relies on in the harness:

- **The stage** (`QUIP_DEMO_STAGE=1`, `QUIP_DEMO_BG=RRGGBB`): a borderless 1280x800-pt window with the popover pinned 50 pt from the top and centred. The window never changes size, so Cap, locked to it by window id, films the popover resizing inside it. Each clip is two takes of the same scene, one per background.
- **Anchors** (`demoAnchor` in `Support/DemoAnchors.swift`): chips, cells, the search field and the size toggle report their frames, so the scenes aim at them at any size instead of at hand-measured points.
- **A real library** (`QUIP_DEMO_LIBRARY`): a JSON snapshot of your favourites, recents, collections and recent searches, exported from the real defaults, with a local copy of each GIF, in `assets/library/`. It loads into the demo suite; the real defaults are only ever read, once, to make the snapshot.
- **Saved searches**: `Demo/fetch-search.sh shocked celebrate` saves real Giphy results for the words the scenes type, in `assets/search/<word>/`. It reads your key from the Keychain (macOS asks) and never prints it.

The harness keeps its own image cache and copies to a private pasteboard, so a take touches neither the installed Quip's cache nor your clipboard.

Known trap: hovering the first "shocked" result (`bGPTxLislwm3u`) sends the window into an AppKit layout loop that crashes it, every time. The collections scene drags the second result instead (`QUIP_DEMO_INDEX`). Not yet checked in the real app.

## The size-morph clip (cut-out)

`Demo/record-morph.sh [outdir]` records the size toggle going two, three, five and back to two per row, with the popover resizing live, as a loop on a transparent background. It writes a ProRes 4444 master with alpha (30 fps, 2x), the same frames as PNGs, an H.264 preview on grey and a contact sheet with a frame every 150 ms, to `~/Movies/quip-sizes-morph-<date>/` by default. It then checks every frame: the popover's top edge stays put, and nothing outside the popover has any alpha.

What it relies on:

- **A clear stage** (`QUIP_DEMO_BG=clear`): the stage window is transparent and drops the popover's shadow. The stage moves the popover's width frame by frame on the same curve as the real popover (`DemoStageWidth`), so the content lays out live at each width, as it does in the app.
- **The `p-morph` scene**: the cursor fades in near the toggle, clicks through the three sizes with about a second on each, and fades out with the last click. It prints `SCENE_START` and `SCENE_END` on the host clock, and the recorder prints the time of its first frame on the same clock, so the loop is cut to the frame.
- **`Demo/tools/record-window.swift`**: records one window with ScreenCaptureKit, alpha included. Cap and `screencapture -v` both flatten it.
- **An optimised build** in `build/dd-demo-opt`: Debug (so the harness is in it) with release optimisation, so the morph runs as smoothly as in the shipped app. It is signed ad hoc with the hardened runtime off, so the ad-hoc Sparkle framework loads. It is for recording only.

`QUIP_DEMO_POPOVER=1` shows the content in a real NSPopover hung under a stand-in menu-bar icon at the top of the Retina screen, resized by the real `PopoverMorpher`. Use it to check the morph itself. `QUIP_DEMO_REDUCE_MOTION=1` takes the Reduce Motion path without changing the system setting.

## Sample GIFs

`assets/` holds real Giphy GIFs, fetched with the key stored in your Quip
settings. To refresh or change the set:

```sh
KEY=$(defaults read com.nicojan.Quip giphyApiKey)
# then fetch fixed_width GIFs by search term into Demo/assets/<name>.gif
```

The file names in `assets/` map to titles in `DemoGifSource.catalog` — keep them
in sync if you rename or add clips.

## Not in git

`assets/` (third-party Giphy content) and `clips/` (large generated MP4s) are
git-ignored. The GIFs are Giphy's, so don't commit or redistribute them without
sorting out licensing; the clips are regenerable from the scripts above.
