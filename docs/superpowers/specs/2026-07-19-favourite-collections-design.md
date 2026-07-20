# Favourite Collections — design

_2026-07-19_

## Goal

Let a user group their favourited GIFs into named, self-curated buckets
("Reactions", "Work", "Celebration") and filter the favourites grid to one
bucket at a time. A GIF can belong to more than one bucket (tags, not folders).

Constraint that shapes every choice: Quip is a menu-bar quick-picker in a narrow
popover (320px / 2 columns standard, 640px / 5 columns compact). Organization
must not slow down the glance-and-grab path or steal vertical space.

## Interaction

**No modals — decided by the popover.** The popover is `.transient` and the app
is `LSUIElement` with a deliberately anti-modal design (its gentle-update system
exists to avoid stolen-focus modals). A SwiftUI `.alert` / `.confirmationDialog`
would steal key focus and dismiss the transient popover. So every collection
action is **inline**, no modal anywhere. The split is: **home manages buckets,
cells file into them.**

**Chip row (home).** A horizontally-scrollable pill row sits above the favourites
grid: `All · Reactions · Work · … · +`. It shows whenever there is at least one
favourite (so the `+` create path is always reachable once you have something to
organize; a user with no favourites sees today's UI unchanged). Tapping a chip
filters the grid to that collection; `All` shows every favourite. Selection is
view-local `@State`: it persists across a quick reopen (matching how the app
keeps your last search) and falls back to `All` whenever the selected collection
no longer exists — so no explicit reset wiring is needed.

**Filing (any cell).** Right-click any GIF cell → **Add to Collection ▸**
submenu: a checklist of the existing collections (checkmark = member, click
toggles). The menu is on the shared `GifThumbnail`, so it works on search and
trending cells too — filing a non-favourite auto-favourites it first. With no
collections yet, the submenu shows a disabled "No collections yet" hint pointing
to the chip row. This is the VoiceOver-reachable filing path (VO can open a
context menu), so no per-collection accessibility actions are stamped on each
cell (that would explode combinatorially).

**Managing (chip row, inline).**
- **Create** — tap `+`; an inline `TextField` appears in the row. Return creates
  (trimmed, blank ignored); Escape / empty cancels.
- **Rename** — right-click a chip → **Rename**; that chip becomes an inline
  `TextField` in place. Return commits; Escape cancels.
- **Delete** — right-click a chip → **Delete** (destructive). Immediate: a
  deliberate two-step right-click→Delete, and the GIFs stay favourited (only the
  bucket is discarded), so no confirmation modal is warranted.

## Data model

`Collection` is a value type stored in `GifLibrary` alongside `favorites` /
`recents`, persisted to `UserDefaults` as JSON with the same tolerant
per-element decode.

```
struct Collection: Identifiable, Codable, Hashable, Sendable {
    let id: String        // UUID string
    var name: String
    var gifIDs: [String]  // membership; deduped on insert, order irrelevant
}
```

Collections reference favourite GIF **ids** only — `favorites` remains the one
source of truth for GIF objects. The grid for a selected collection is always
derived as `favorites` filtered by membership, which preserves favourites order
and drops orphaned ids for free.

### `GifLibrary` API (new)

- `createCollection(named:) -> Collection` — trims the name, ignores blank,
  inserts at front, enforces a count ceiling.
- `renameCollection(_:to:)` — trims, ignores blank.
- `deleteCollection(_:)`
- `setMembership(_ gif:in:member:)` / `isMember(_:of:)` — toggle a gif in/out;
  adding auto-favourites the gif if it isn't already.
- On `toggleFavorite` removal (un-favouriting): cascade-remove that id from every
  collection.
- `collectionsLimit = 50` (mirrors the existing `favoritesLimit` guard).

## Edge cases

- Un-favouriting a GIF pulls its id from all collections.
- Deleting the currently-selected collection drops the chip selection back to
  `All` (view reacts to the collection disappearing).
- Orphaned ids (member but no longer favourited) never render — the grid is
  derived from `favorites ∩ gifIDs`.
- Long collection names truncate with a max chip width.
- Additive persistence: a new `favoriteCollections` key; existing users'
  favourites and recents are untouched, no migration.

## Testing (model layer, TDD)

`GifLibraryTests` gains: create (and blank-name rejection), rename, delete,
toggle membership, membership auto-favourites, the un-favourite cascade,
persistence round-trip, tolerant decode of a bad collection record, and the
count limit. Matches the project's existing model-test style (isolated
`UserDefaults` suite per test). SwiftUI views follow the repo convention of no
view unit tests; they are verified by build + manual run.

## Out of scope (YAGNI)

Drag-to-reorder collections, nested collections, per-collection colours/icons,
sharing/exporting collections, and a dedicated management screen. The chip row
plus context menu covers create/rename/delete/file without any of these.
