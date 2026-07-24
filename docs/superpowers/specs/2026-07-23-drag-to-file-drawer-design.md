# Drag-to-file favourites drawer — design

**Date:** 2026-07-23
**Status:** Implemented (pending live verification + release copy pass)

## Goal

Drag any GIF — a search result, a trending GIF, a favourite, a recently-copied one
— onto a collection pill to favourite and file it in one motion, with the pills
reachable from anywhere in the scroll (they used to scroll away under Trending, and
were absent entirely during search).

## Interaction

A `FilingDrawer` sits above the scrolling grid in both the library (home) and search
views, with two states driven by whether a GIF drag is in flight
(`DragContext.isDragging`):

- **Collapsed** (home, idle): one sideways-scrolling row of compact pills
  (`All` + collection chips), still tappable to filter favourites, with the sort and
  `＋` buttons pinned at the right. A divider marks the drawer's edge.
- **Expanded** (a GIF drag is in flight, or the editor is open): the pills wrap to
  full height with roomier drop targets under a "Drop into a collection" prompt.
- **Search, idle:** the drawer is absent; it slides in when a drag starts and slides
  out when it ends.

## Drop targets

- **Collection chip** → files the GIF and auto-favourites it (existing
  `GifLibrary.setMembership`).
- **`All`** → favourites the GIF without filing it ("just save it").
- **`＋`** → favourites the GIF immediately (so it's never lost), then opens the
  create editor with the GIF pending; on Create it's filed into the new collection.

Each successful drop reports through an `onFiled(name)` callback, which shows a
transient "Added to …" toast — the only "it worked" cue in search, where the grid
doesn't change when a GIF is filed.

## Drag-end detection

The drawer expands on drag start and must collapse when the drag ends. Rather than
rewrite the GIF cell as an AppKit `NSDraggingSource` (which would put the app's core
click-to-copy interaction at risk), the drag state (`DragContext.gif`) is cleared
three ways:

1. The chip / `All` / `＋` drop handlers clear it when a drop lands.
2. A full-content **drop-catcher** behind the grid clears it on a drop over empty
   space (returns `false` so the drop reads as "not filed").
3. The existing `.quipPopoverClosed` handler clears it — a drag *out* to another app
   closes the transient popover, which self-heals the state.

The one uncovered case — cancelling a drag with Esc over empty space — leaves the
drawer expanded until the next drag, which re-collapses it. Rare, cosmetic, and
self-healing; accepted for v1.

## Architecture

- `FilingDrawer.swift` (new) — the drawer: both layouts, chip rendering, drop
  handlers, reorder, flash, and hosting the editor.
- `CollectionChipEditor.swift` (new) — the inline create/edit panel, extracted from
  the old `CollectionChipsRow`.
- `MenuContentView.swift` — hosts one `FilingDrawer` above the content, owns
  `selectedCollectionID` (so the one drawer drives both grids), the toast, and the
  drop-catcher. Drawer + content are paired in a zero-spacing stack so an empty
  drawer adds no gap.
- `LibraryView.swift` — pills removed from the Favorites header (they moved to the
  drawer); takes `selectedCollectionID` as a binding, keeps the title + filter field.
- `DragContext.swift` — added a computed `isDragging`.
- `CollectionChipsRow.swift` — retired (absorbed into the above).

## Out of scope (v1)

Proximity-based expand, reorder-while-filing, multi-GIF/batch drag, and detecting
Esc-cancel over empty space.

## Tests

`CollectionDropTests` covers the library-level effects of each drop path:
file + favourite (regression), `All` favourite-only, `All` on an already-favourite
no-op, `＋` create-and-file, and the collection-cap case (GIF stays favourited, not
lost). The drag/drop gesture itself remains manual QA — SwiftUI drag isn't
unit-testable.
