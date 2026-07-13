# Changelog

All notable changes to Quip are documented here. The format loosely follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
