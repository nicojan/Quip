# Quip v1.1 — "make it fast" plan

Adds the features from the feature discussion. Built in phases; each phase builds
and tests green before the next.

## Key architecture change

Switch the menu-bar surface from SwiftUI `MenuBarExtra` to an AppKit
`NSStatusItem` + `NSPopover` driven by an `AppDelegate`. Reason: you can't open a
`MenuBarExtra` programmatically, and the global hotkey must toggle the panel.
This was the documented fallback in `DESIGN.md`. The popover still hosts the same
SwiftUI `MenuContentView` via `NSHostingController`; `GifLibrary` becomes a shared
instance so the detached popover and the Settings scene share one store.

## Phases

**Phase 1 — foundation + global hotkey (configurable/disable-able)**
- Add the `KeyboardShortcuts` package (sindresorhus).
- `AppDelegate` owns the status item + popover; global shortcut toggles it.
- `KeyboardShortcuts.Recorder` in Settings lets the user change or clear (disable)
  the shortcut. Default `⌘⇧G`, set once so a user's later "disable" sticks.

**Phase 2 — keyboard-first interaction**
- Arrow-key navigation of the grid, Return to copy, Esc to close, focus search on
  open. Larger preview on hover.

**Phase 3 — content & discovery**
- Trending GIFs in the empty state. Search autocomplete (Giphy suggestions).
- Stickers toggle (transparent) and a rating filter (g/pg/pg-13) in Settings.

**Phase 4 — output & organization**
- Drag a GIF out of the grid into any app. ⌥-click copies the Giphy link; a
  right-click menu picks rendition/size. Search/filter within favorites.
- First-run onboarding for the API key.

## Scope note

Full **tags/collections** for favorites is deferred — it's a data-model + UI
feature larger than the rest. Phase 4 ships **search/filter within favorites**;
tags/collections can be its own later effort.
