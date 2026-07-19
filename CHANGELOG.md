# Changelog

All notable changes to Quip are documented here. The format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
