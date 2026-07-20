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

---

## Status: shipped in 1.1.6

Shipped 2026-07-19 in Quip 1.1.6 (build 9), tag `v1.1.6`, commits `3d3393c`
(feature) + `a3cebae` (appcast). 37/37 tests pass. A `qa-reviewer` pass ran
before release; its Medium and two correctness Lows are fixed (see below).

### Code map

- `Quip/Models/GifCollection.swift` — the value type (`id`, `name`, `gifIDs`),
  tolerant decode.
- `Quip/Services/GifLibrary.swift` — the store: `collections`, create / rename /
  delete / `setMembership` / `isMember` / `gifs(inCollection:)`, the
  un-favourite + cap-eviction cascades, generic `load`/`save`.
- `Quip/Views/CollectionChipsRow.swift` — the chip row (home): `All` + chips +
  `+`, inline create/rename, chip context menu (rename/delete). Owns selection
  via a `@Binding`.
- `Quip/Views/CollectionFiling.swift` — the closure bundle a cell needs to file
  itself.
- `Quip/Views/GifThumbnail.swift` — `collectionMenu` (right-click → Add to
  Collection).
- `Quip/Views/LibraryView.swift` — hosts the chip row, `favoritesInScope`
  filtering, empty-collection hint, `selectedCollectionID` state.
- `Quip/Views/MenuContentView.swift` — builds `filing`, passes it to both grids.
- `QuipTests/GifLibraryTests.swift` — the model-layer matrix.

### Build / test / run

```sh
xcodegen generate                                   # after any project.yml or new-file change
xcodebuild test -project Quip.xcodeproj -scheme Quip -destination 'platform=macOS'
xcodebuild build -project Quip.xcodeproj -scheme Quip -configuration Debug -destination 'platform=macOS'
```

Filter test noise (runtime logs contain "error:") by grepping for
`\.swift:[0-9]+:[0-9]+: error:` and `Executed [0-9]+ tests`.

### Already fixed (don't redo)

- Inline field focus uses the false→true runloop toggle, so a second
  create/rename focuses (was a no-op).
- A half-typed create/rename is cancelled on popover reopen (`.quipPopoverShown`).
- Cap-eviction (past 500 favourites) cascades ids out of collections, not just
  the explicit un-favourite path.

## Fine-tuning backlog (next session)

UX-level calls to revisit with a human in the loop; none are bugs.

1. **Creating a bucket hides your favourites.** After `+` → name, the new
   (empty) collection is auto-selected, so the grid shows "Nothing in this
   collection yet." Brief "where did my favourites go?" risk. Options: don't
   auto-select on create; select but keep All's grid visible with an inline
   note; or leave as-is (the hint guides). Current: auto-select.
2. **Selection persistence vs. idle reset.** Chip selection persists across a
   quick reopen and only falls back to All when the collection is deleted — it
   does *not* reset on the app's idle "return to home." Decide whether the chip
   should also reset after idle (consistency) or persist (fewer taps). Current:
   persists.
3. **Filing discoverability.** Filing is right-click-only, with no visible cue
   that the menu exists and no indicator on a cell of which collections a GIF is
   in. Consider a hover affordance and/or a small membership badge.
4. **Create from a search-result cell.** Cells can only file into *existing*
   collections; you can't spin up a new bucket straight from a search result
   (creation lives on the home chip row). Weigh an in-cell create against keeping
   it modal-free.
5. **Empty-submenu hint.** With zero collections the cell submenu shows a
   disabled "No collections yet." Could point more actively at the `+`.
6. **Chip overflow / off-screen inline field** (QA Low, deferred). With enough
   collections to overflow 320px, an inline create/rename field can open scrolled
   out of view. Self-resolves in practice (the triggering control is on-screen);
   a `ScrollViewReader` auto-scroll would harden it.
7. **Silent create-at-cap** (QA Low, accepted). At 50 collections, create
   no-ops with no message. Add a hint if wanted.
8. **Visual polish.** Selected-chip contrast, the 120pt truncation width, chip
   spacing, and whether to show a per-chip count.
