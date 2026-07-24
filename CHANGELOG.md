# Changelog

All notable changes to Quip are documented here. The format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.1.14] - 2026-07-24

### Added

- The first time you open Quip, it opens on its own and points at its spot in the
  menu bar, so you can see where it lives and what to do next instead of hunting
  for a new icon.

### Changed

- Before you add an API key, Quip now shows a link that takes you straight to
  where you get a free one, and it reminds you which key to pick, since the wrong
  type looks fine but never works. It also shows the shortcut for summoning Quip,
  so you learn how to call it up again.

## [1.1.13] - 2026-07-23

### Added

- Drag a GIF straight onto a collection chip to save and file it in one motion,
  whether it came from search, trending, or your favorites. Drop it on "All" to
  just save it. Drop it on "+" to start a new collection from the GIF you're
  dragging.

### Changed

- The collection chips now sit in a strip above the grid, so they stay in reach
  no matter how far you've scrolled down into your GIFs. At the top, they spread
  across as many rows as it takes. Nothing hides off the edge. Scroll down and
  they shrink to a single row that slides sideways; pick up a GIF and the strip
  opens back up to give you room to drop.

## [1.1.12] - 2026-07-22

### Changed

- The collection chips are bigger and easier to read. A collection you've set to
  show only its emoji now appears as the bare emoji, sized up, rather than tucked
  inside a pill.
- Point at a collection chip and it lifts with an accent glow and grows a little,
  so you can tell which one you're about to pick.
- The Favorites and Recently copied rows no longer sit inside a boxed panel. The
  GIFs line up with everything else in the window.
- The copy icon that shows when you point at a GIF now has a dark outline, so it
  stays clear on bright GIFs.

### Fixed

- The scroll bars in the Favorites and Recently copied rows are gone, so no part
  of the window shows one now. A half-shown GIF at the end of a row tells you it
  scrolls sideways for more.

## [1.1.11] - 2026-07-22

### Added

- A Clear button on the recent-searches row, so you can wipe your search history
  the same way you clear recently copied GIFs.

### Changed

- Your Giphy API key now lives in the macOS Keychain instead of the app's plain
  preferences. Your existing key moves over on first launch, so you don't need to
  re-enter it.
- ⌥-click now copies a GIF's giphy.com link, which shows a preview when you paste
  it into apps that unfurl links.
- The star on a GIF you haven't saved is easier to see against bright GIFs.

### Fixed

- Changing the content rating, or switching between GIFs and stickers, now
  updates an on-screen search even when it had failed or found nothing.
- Trending no longer briefly shows the old kind of result after you switch
  between GIFs and stickers.
- Dragging a collection chip to reorder it now drops it where you aimed, in both
  directions.

## [1.1.10] - 2026-07-21

### Changed

- The collection chips now wrap onto a second and third row when they don't all
  fit, instead of scrolling sideways. The All chip and the sort and plus buttons
  stay on the top row.
- The vertical scroll bar is gone. Scroll with your trackpad or wheel, and a
  half-shown row at the bottom shows there's more below.

## [1.1.9] - 2026-07-20

### Added

- Give a collection an emoji. When you create or edit one, pick an emoji from
  the system picker to represent it, and you can hide the name so the chip shows
  only the emoji.
- Drag a collection's chip to reorder it.
- Sort your collections A to Z with the button in the collection row.

### Changed

- Favorites and Recently copied now scroll sideways. Each sits in its own box
  that grows to a few rows, then scrolls, so a long list no longer pushes
  Trending down the popover.
- The collection row now stays pinned at the top while you scroll your favorites.
- Every layout size is now the same height. Only the width and the number of
  columns per row change.
- The favorite star is now a filled yellow star, and a GIF you're dragging stays
  see-through so it doesn't cover the chips you drop it on.

### Fixed

- The popover's arrow no longer detaches from the menu-bar icon when you change
  the layout size while it's open.

## [1.1.8] - 2026-07-19

### Added

- A taller layout. The size toggle has a third setting that fills about 80% of
  your screen's height, three GIFs to a row, so there's more to browse without
  scrolling.
- Check for updates from the menu-bar menu. Right-click the Quip icon and check
  for a new version without opening Settings.

### Fixed

- Dragging a GIF onto a collection now files it. In 1.1.7 the drop looked like it
  worked but the GIF was never added.

## [1.1.7] - 2026-07-19

### Changed

- Drag a GIF onto a collection's chip to file it there. Grab one from your
  favorites, recents, or trending, drop it on a chip, and it's filed; if you
  hadn't saved it yet, that happens too. Right-click still works. It's also how
  you take a GIF back out of a collection.

## [1.1.6] - 2026-07-19

### Added

- Collections. Group your favorite GIFs into named buckets like "Reactions" or
  "Work". A row of chips above your favorites narrows them to one bucket at a
  time, and you can add a bucket with the plus button. Right-click any GIF to
  file it into a collection; if you hadn't saved it yet, that saves it too. One
  GIF can live in several. Rename or delete a collection by right-clicking its
  chip.

## [1.1.5] - 2026-07-18

### Added

- Quip returns to its home view (recent searches and trending) when you open it
  after a couple of minutes away, instead of showing your last search. Reopen
  sooner and your results are still there.

### Changed

- Results stay on screen while a new search loads, instead of blanking to a spinner.
- The Giphy API key field is now hidden by default, with a button to reveal it.
- VoiceOver can now copy a GIF and read the toolbar controls.

### Fixed

- A GIF that fails to download no longer shows a "Copied!" mark. Quip tells you
  the copy didn't work, so you don't paste a broken file.
- Switching stickers or the content rating now updates the results already on screen.
- A search with no matches shows a plain "No GIFs found" message instead of
  looking like an error.
- "Start at login" now reflects whether it took effect, and points you to System
  Settings when macOS needs to approve it.
- A GIF that can't load shows a placeholder instead of spinning forever.
- Tapping a suggestion or a recent search now runs a single search.
- Clearer messages when Giphy turns down your key or is busy.

## [1.1.4] - 2026-07-14

### Fixed

- The scroll indicator no longer appears over GIFs at the right edge of the grid.

### Changed

- The image cache now stops at 256 MB. When it fills, Quip drops the GIFs you
  used least recently, and you can still check its size or clear it from Settings.

## [1.1.3] - 2026-07-14

### Fixed

- Wide GIFs could spill past their column and cover the favorite star on the
  next GIF. Each GIF now stays inside its own tile.

## [1.1.2] - 2026-07-14

### Fixed

- Quip now displays correctly when macOS is set to Light appearance. The popover
  kept its dark background but let text and controls follow the system theme, so
  in Light mode they turned dark-on-dark and were unreadable.

### Changed

- Update reminders are gentler. When Quip finds an update in the background it
  now marks the menu-bar icon with a small dot — with an "Install Update…" entry
  in the right-click menu — instead of interrupting you with a window. Checking
  from Settings still shows the update right away.

## [1.1.1] - 2026-07-13

### Fixed

- A failed copy no longer replaces the whole window with an error; it shows a
  brief "Couldn't copy" mark on the GIF instead.
- Trending GIFs now appear after you add your key, and refresh when you change
  the stickers or rating setting, instead of loading only once.
- The search field focuses every time you open Quip.
- Filtering favorites can no longer strand them when the list shrinks.
- Favorites and recents survive an app update even if their data format changes.
- Queries with a "+" (like "c++") now search correctly.

## [1.1.0] - 2026-07-13

### Added

- **Right-click the menu-bar icon** for Settings and Quit.
- **Global hotkey** to open Quip from anywhere (default ⌘⇧G). Change it or clear
  it to turn it off in Settings.
- **Trending** GIFs fill the empty state, and **autocomplete** suggests terms as
  you type.
- **Stickers** (transparent) as an alternative to GIFs, and a **content rating**
  filter (G/PG/PG-13/R), both in Settings.
- **Drag a GIF out** of the grid into any app; **⌥-click** copies the link
  instead of the file.
- **Filter your favorites** once the list grows.
- **Image cache** size and a clear button in Settings.
- Author credit in the footer, and a larger preview on hover.

### Changed

- The menu-bar popover is now AppKit-backed (`NSStatusItem` + `NSPopover`) so the
  global hotkey can open it. The search field focuses on every open, and Esc
  closes the popover.
- Small accent text uses a lighter violet for readable contrast on the dark
  background.

## [1.0.0] - 2026-07-13

### Added

- First release. Search GIFs from the menu bar and copy any result to the
  clipboard with one click.
- Bring your own free Giphy API key, entered in Settings. Quip bundles no key.
- Favorites: star a GIF to keep it one click away.
- Recently copied: Quip remembers the GIFs you used.
- Recent searches: click a past search to run it again.
- Narrow (2 per row) and wide (5 per row) layouts.
- Start at login.
- In-app updates via Sparkle.
