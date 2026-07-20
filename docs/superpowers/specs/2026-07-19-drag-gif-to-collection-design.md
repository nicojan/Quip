# Drag a GIF onto a collection chip to file it

**Status:** shipped. Chip drop target + discoverability in 1.1.7; the actual
filing was broken by the pasteboard-payload assumption and fixed via `DragContext`
in 1.1.8 (see "Why it doesn't break drag-to-insert").
**Scope:** single-GIF drag-to-file. Batch/multi-select is a separate future spec.

## Problem

Filing a favorite GIF into a collection is right-click → **Add to Collection** →
submenu → pick one. Users report it as undiscoverable, slow, and indirect — a
menu feels wrong for "put this thing in that bucket." Direct manipulation
(drag the GIF onto the collection) is the obvious mental model.

## The interaction

Drag any GIF thumbnail (favorites, recents, or trending — anywhere the library
view is showing) onto a collection chip in the row above the favorites grid.
Release to file it into that collection. If the GIF wasn't a favorite yet, it is
auto-favorited first, identical to the right-click path.

- Drag only ever means **add**. Right-click stays the only way to *remove* from a
  collection and the only place membership checkmarks show.
- The **All** chip is not a drop target (it's not a bucket; "favorite without
  filing" is what the star already does). Only named-collection chips light up.
- Dropping on the **+** does nothing in v1.

## Why it doesn't break drag-to-insert

Every GIF cell already has `.onDrag` that vends the downloadable `.gif` **file**
— the "drag to insert into Messages/Finder/Slack" path (`QuipDragProvider.make`).
We must not disturb it. That file representation stays exactly as it was.

The cell's `NSItemProvider` also advertises a private type
`com.nicojan.Quip.gif-ref` (`.ownProcess` visibility). Its only job is
**acceptance gating**: a collection chip's `.onDrop(of: [.gifRef])` fires only for
drags carrying that type, so external GIF drags (which don't) are never treated as
filing. External apps still see only the `.gif` file.

**How the dragged GIF actually reaches the drop — the part that bit us.** The
original design loaded the `Gif` back from a second JSON representation on the
provider at drop time. That does **not** work: on macOS the drop handler receives
an `NSItemProvider` **stripped of its representations** (empty
`registeredTypeIdentifiers`) for an in-process, own-process custom type. The drop
fires, `isTargeted` toggles, but there is no payload to read. A unit test using a
provider built in the same call passed, which hid this — the real drag session
reconstructs the provider.

So the GIF is carried in a shared `DragContext` (`@MainActor @Observable`) instead
of on the pasteboard: the cell sets `dragContext.gif` when its drag starts, and the
chip reads it on drop. The `gif-ref` acceptance type still gates this to Quip's own
drags, so `DragContext` is only ever read for a drag we started — no stale/foreign
payload risk.

## Data flow

Chip drop handler reads `dragContext.gif` and calls the existing
`GifLibrary.setMembership(gif, inCollection: id, member: true)`, which already:
auto-favorites if needed, appends the id (deduped/idempotent), and persists. No
new library logic.

`CollectionChipsRow` holds `@Environment(GifLibrary.self)` and
`@Environment(DragContext.self)`, so it files directly — no new closure threaded
through `CollectionFiling`.

## Discoverability & feedback

Discovery can't depend only on someone guessing they can drag. Three cheap,
always-there or in-the-moment cues:

1. **Drag-over highlight** — while a GIF is dragged, each named chip highlights as
   the pointer enters it (SwiftUI `isTargeted`). This is the moment users learn
   chips are buckets.
2. **Drop confirmation** — a brief pulse on the chip on a successful drop, since
   dropping onto a *non-selected* collection otherwise shows no visible change.
3. **Persistent hints** — the cell tooltip mentions dragging onto a collection,
   and the empty-collection hint names both paths. (All user-facing copy passes
   the humanizer + Orwell gate per `CLAUDE.md`.)

## Boundaries / accepted limitations (v1)

- **Library view only.** Chips render in the home/library view. During an active
  *search*, chips aren't shown, so right-click stays the filing path there.
  Intentional.
- **Chip reachability.** The chips row sits at the top of favorites and can scroll
  off-screen when viewing Trending far below; SwiftUI doesn't auto-scroll during a
  drag. Accepted for v1. Future mitigation: make the selected-collection grid area
  a drop target too.
- **No batch.** Deferred; the drop mechanism extends to multi-select later without
  rework.

## Testing

- **Unit** (`GifLibraryTests` patterns): payload round-trip — encode `Gif` →
  decode → `setMembership(member: true)` auto-favorites and files; re-drop is
  idempotent (no duplicate membership). The gesture itself is manual QA (SwiftUI
  drag/drop isn't unit-testable).
- **Manual QA:**
  1. Drag a favorite onto a collection chip → chip highlights, drops, GIF appears
     when that collection is selected.
  2. Drag a *Trending* GIF onto a chip → auto-favorited + filed.
  3. Drag a GIF onto **Messages/Finder** → still inserts the file (no regression).
  4. Drag over the **All** chip and **+** → no highlight, no drop.
  5. Re-drop an already-filed GIF → no duplicate.

## Files

- `Quip/Support/QuipDragType.swift` — the private `UTType` used to gate chip
  drops (app-private identifier, not declared in Info.plist — see the file).
- `Quip/Support/QuipDragProvider.swift` — builds the cell's drag provider (the
  `.gif` file for drag-to-insert + the `gif-ref` acceptance type).
- `Quip/Support/DragContext.swift` — shared `@Observable` carrying the dragged
  GIF (the pasteboard can't; see above).
- `Quip/Views/GifThumbnail.swift` — sets `dragContext.gif` on drag start; tooltip.
- `Quip/Views/CollectionChipsRow.swift` — chip drop target, highlight, flash.
- `Quip/Views/LibraryView.swift` — empty-collection hint copy.
- `QuipTests/` — `GifLibrary.setMembership` filing/idempotency + drag-payload tests.
