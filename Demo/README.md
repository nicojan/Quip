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
