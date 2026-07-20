# Drag a GIF onto a collection chip to file it

**Status:** approved for build (2026-07-19)
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
— the "drag to insert into Messages/Finder/Slack" path (`GifThumbnail.dragProvider`).
We must not disturb it.

The same `NSItemProvider` gets a **second** representation: the full `Gif`
encoded as JSON, registered under a private exported UTI
`com.nicojan.Quip.gif-ref` with **`.ownProcess` visibility**. Because the
payload is own-process only, it never leaves Quip — external apps see only the
`.gif` file, exactly as today. Collection chips are the only drop targets that
understand the private type. One drag, the destination decides what it means.

**The payload is the whole `Gif`, not just its id.** Auto-favoriting a GIF
dragged from Trending needs the full `Gif` object to insert into `favorites`; an
id alone can't reconstruct it. `Gif` is already `Codable`.

## Data flow

Chip drop handler decodes the `Gif` from the payload and calls the existing
`GifLibrary.setMembership(gif, inCollection: id, member: true)`, which already:
auto-favorites if needed, appends the id (deduped/idempotent), and persists. No
new library logic.

`CollectionChipsRow` already holds `@Environment(GifLibrary.self)`, so it files
directly — no new closure threaded through `CollectionFiling`.

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

- `Quip/Support/QuipDragType.swift` (new) — the exported `UTType` + payload
  encode/decode helpers.
- `Quip/Info.plist` — `UTExportedTypeDeclarations` for the private UTI.
- `Quip/Views/GifThumbnail.swift` — register the second representation; tooltip.
- `Quip/Views/CollectionChipsRow.swift` — chip drop target, highlight, flash.
- `Quip/Views/LibraryView.swift` — empty-collection hint copy.
- `QuipTests/` — payload round-trip + idempotency tests.
