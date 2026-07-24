# Quip — Retroactive Usability Notes

_Reconstructed 2026-07-23, updated 2026-07-24, covering releases 1.0.0 through 1.1.14._

## 1. First run and the empty popover

**Finding 1.1 — The empty window gave a new user nothing to do.** _(Friction, 1.1.0)_
On first open, before anyone had searched, the popover was blank except for the
search field. People opened Quip, saw nothing, and weren't sure it was working or
what to type. The fix filled the empty state with **trending GIFs** so there was
always something to look at and grab, and added **autocomplete** so a half-typed
word suggested where to go. The empty state stopped being empty.

**Finding 1.2 — People couldn't find Settings or Quit.** _(Friction, 1.1.0)_
Quip runs as a menu-bar-only app with no Dock icon and no menu bar of its own, so
the usual places to look for Settings and Quit weren't there. People had no way
to change the API key or close the app once the popover was open. Adding a
**right-click menu on the menu-bar icon** (Settings, Quit) put those controls
where macOS users already right-click for them.

**Finding 1.3 — Reaching the app meant aiming for a small icon.** _(Friction, 1.1.0)_
The only way to open Quip was clicking its menu-bar icon — a small target, and one
you have to look up to find while your attention is in the app you're typing in. A
**configurable global hotkey** (default ⌘⇧G) let people summon it without leaving
the keyboard. It can be changed or cleared for anyone who doesn't want it.

**Finding 1.4 — A new user saw no sign the app had started.** _(Friction, 1.1.14)_
Quip has no Dock icon and opens no window when it launches, so after installing and
opening it the only thing that appeared was a small menu-bar icon a new user might
not notice. People couldn't tell the app had started, or where to click. Quip now
opens its popover once, on the first launch only, anchored to its menu-bar icon, so
the first thing a new user sees points straight at where the app lives. This is a
deliberate one-time exception to the anti-modal stance (see 7.1): the app opens
itself once to introduce itself, then never again.

**Finding 1.5 — Getting the API key was a retype-it-yourself chore, and the shortcut stayed hidden.** _(Friction, 1.1.14)_
Before a key is entered, the popover tells you Quip needs a free Giphy API key. But
it printed the address as plain text you had to retype into a browser. And Giphy's
dashboard offers two kinds of key — an SDK key that looks right but never works with
Quip, and the API key you actually need — with nothing on screen to steer you to the
right one. It also never named the shortcut that summons Quip. The screen now links
straight to the Giphy dashboard, says in as many words to choose the API option and
not the SDK, and shows your own summon shortcut so you learn how to call the app
back up.

## 2. The copy moment — did it work?

Copying to the clipboard is invisible. Nothing on screen changes, so people had no
way to know their click landed. This was the app's most-repeated moment, and it
took several passes to make it trustworthy.

**Finding 2.1 — A successful copy gave no feedback.** _(Friction, 1.0.0)_
People clicked a GIF and nothing visibly happened, so they clicked again, or
weren't sure whether to switch apps and paste. A **"Copied!" overlay** on the
thumbnail confirmed the click worked.

**Finding 2.2 — A failed copy still said "Copied!".** _(Blocker, 1.1.5)_
Worse than no feedback: when a GIF failed to download, the overlay still claimed
success. People switched to their chat app, pasted, and got nothing or a broken
file — and blamed themselves or the other app, not Quip. This is the kind of bug
that quietly destroys trust. The fix tied the mark to the actual result, so a
failed copy says the copy didn't work.

**Finding 2.3 — One failed copy blanked the whole window.** _(Blocker, 1.1.1)_
When a copy failed, the entire popover was replaced with a full-window error.
A single hiccup wiped out the grid the person was browsing and made a small
problem look like a crash. The fix scoped the failure down to a brief
**"Couldn't copy" mark on that one GIF**, leaving everything else in place.

**Finding 2.4 — The copy icon vanished on bright GIFs.** _(Polish, 1.1.12)_
The hover copy icon was light, so on a bright or busy thumbnail it disappeared into
the image and people couldn't tell copy was even an option there. A **dark outline**
made it hold up against any background.

## 3. The favourite star: reachable and visible

The star sits in the corner of each thumbnail. A run of problems in a row all
came down to the same thing — something was covering the star or hiding it, so
people couldn't favourite what they wanted.

**Finding 3.1 — Wide GIFs covered the star next door.** _(Blocker, 1.1.3)_
A GIF wider than its column spilled past its tile and sat on top of the favourite
star of the GIF beside it. People went to star a GIF and the click landed on the
neighbour's image instead. Clipping each GIF to its own tile fixed it.

**Finding 3.2 — The scroll bar sat on top of the right-edge GIFs.** _(Friction, 1.1.3–1.1.4)_
The grid's scroll indicator overlapped the GIFs in the rightmost column, covering
their stars during and after scrolling. This took three tries to get right —
reserve a lane for the scroller, widen the lane to clear its active width, then
hide the indicator entirely — a sign of how stubbornly a system scrollbar fights
for the same pixels the content wants.

**Finding 3.3 — The unsaved star was hard to see on busy thumbnails.** _(Polish, 1.1.11)_
The outline of an unfavourited star was faint, and against a bright or detailed
GIF people couldn't tell whether a GIF was already saved or find where to click to
save it. A clearer outline made the star readable on any background.

## 4. Reading the window

**Finding 4.1 — Light-mode users saw dark text on a dark panel.** _(Blocker, 1.1.2)_
The popover kept its dark background in every appearance, but its text and controls
followed the system theme. For anyone running macOS in Light mode, that meant dark
text on a dark panel — effectively unreadable. A whole cohort of users couldn't
use the app until this was fixed to render correctly in Light appearance.

**Finding 4.2 — Small accent text was too faint to read.** _(Polish, 1.1.0)_
Small accent text used a violet that didn't have enough contrast against the dark
background. A lighter violet (#A78BFA) brought it up to a readable level.

## 5. Searching: feedback, staleness, and focus

**Finding 5.1 — Every new search blanked the screen to a spinner.** _(Friction, 1.1.5)_
Typing a new search cleared the current results and showed a spinner, so the window
flickered empty between searches and people lost the results they were still
looking at. Keeping the old results on screen while the next set loads made search
feel continuous instead of stop-start.

**Finding 5.2 — No matches looked like a broken app.** _(Friction, 1.1.5)_
A search that found nothing showed something that read like an error, so people
thought Quip had failed rather than understanding their term had no GIFs. A plain
**"No GIFs found"** told them what actually happened.

**Finding 5.3 — Changing stickers or rating seemed to do nothing.** _(Friction, 1.1.1, 1.1.5, 1.1.11)_
When someone switched between GIFs and stickers, or changed the content rating,
the results already on screen didn't update — so the setting looked broken or
ignored. This was fixed more than once as new cases surfaced: results now refresh
when these change, even for a search that had failed or found nothing, and
Trending no longer flashes the old kind of result before switching.

**Finding 5.4 — The search field wasn't ready to type in.** _(Friction, 1.1.0–1.1.1)_
Opening Quip didn't put the cursor in the search field, so people had to click it
first before typing — an extra step on the single most common action. The field
now focuses every time the popover opens.

**Finding 5.5 — Tapping a suggestion searched twice.** _(Polish, 1.1.5)_
Choosing an autocomplete suggestion or a recent search sometimes fired two
searches, wasting a request and occasionally flickering the results. Each now runs
a single search.

**Finding 5.6 — A "+" in the query broke the search.** _(Blocker, 1.1.1)_
Searching for something with a plus in it — "c++" being the obvious case — failed,
because the "+" wasn't escaped in the request. Anyone searching for a programming
term hit a dead end. Now those queries search correctly.

## 6. Getting back to a clean slate

**Finding 6.1 — Reopening showed a stale search from hours ago.** _(Friction, 1.1.5)_
Quip kept your last search on screen indefinitely, so opening it the next morning
dropped you back into yesterday's results instead of a fresh start. But clearing it
on every open would punish the common case of reopening a moment later to grab one
more GIF. The resolution reads the gap: reopen within a couple of minutes and your
results are still there; come back after longer and Quip returns to its home view
(recent searches and trending).

## 7. Updates that don't interrupt

**Finding 7.1 — Update prompts stole focus and interrupted.** _(Friction, 1.1.2)_
When Quip found an update in the background, it interrupted with a window that
stole focus — jarring for a quick-picker you summon mid-task and dismiss in
seconds. This shaped a lasting design stance: the app is deliberately anti-modal.
A found update now just marks the menu-bar icon with a small dot and offers
**"Install Update…"** in the right-click menu; checking manually from Settings
still shows it right away.

## 8. Collections: filing a GIF

Collections (named buckets for favourites) arrived in 1.1.6 and then went through
the most sustained round of refinement in the app's history. The filing gesture —
how you put a GIF into a bucket — was reworked repeatedly.

**Finding 8.1 — Filing through a right-click submenu felt wrong.** _(Friction, 1.1.6 → 1.1.7)_
The first filing path was right-click → **Add to Collection** → submenu → pick one.
People found it undiscoverable and slow, and a menu is the wrong mental model for
"put this thing in that bucket." Direct manipulation — **drag the GIF onto the
collection chip** — matched what people expected and became the primary path
(1.1.7). Right-click stayed for removing a GIF and for showing membership.

**Finding 8.2 — The drag looked like it worked but filed nothing.** _(Blocker, 1.1.7 → 1.1.8)_
This is the sharpest trust failure in the app's history. In 1.1.7 you could drag a
GIF onto a chip, the chip lit up, you released, and it looked filed — but the GIF
was never added. People believed they had organized their favourites and hadn't.
A silent no-op on a direct-manipulation gesture is worse than an error, because
nothing tells you to try again. The cause was a wrong assumption about how macOS
carries a custom drag payload; the fix (1.1.8) routed the dragged GIF through a
shared `DragContext` so the drop actually files it.

**Finding 8.3 — The dragged GIF hid the chip you were aiming at.** _(Friction, 1.1.9)_
While dragging, the GIF's drag image was opaque and covered the very chips you were
trying to drop onto — you couldn't see your target. Making the dragged image
**see-through** let people see the chips underneath and aim.

**Finding 8.4 — Filing while searching was impossible.** _(Blocker, 1.1.13)_
The chips lived above the favourites grid, so they scrolled away under Trending on
the home view and weren't present at all during a search. But the moment you most
want to file a GIF is the moment you've just found it — mid-search. People had to
find it, favourite it, stop, scroll back, and only then file. The fix moved the
chips into a **filing drawer** that stays in reach anywhere in the scroll and
slides into the search view when you start dragging, so you can drop a fresh search
result straight into a bucket. Because the search grid doesn't change when a GIF is
filed, a transient **"Added to…" toast** became the only cue that it worked —
closing the same feedback gap as Finding 2.1, one layer up.

## 9. Collections: finding and reading the chips

**Finding 9.1 — Chips scrolled sideways and hid off the edge.** _(Friction, 1.1.10)_
When there were more collections than fit across, the chip row scrolled sideways.
Collections past the right edge were invisible, and people didn't know they had
them or how to reach them. The row now **wraps onto more rows** so every collection
is visible at once; the All chip, sort, and add buttons stay put on the top row.

**Finding 9.2 — Chips were too small to read and hard to aim at.** _(Polish, 1.1.12)_
The chips were cramped, which made them hard to read and small drop targets to aim a
drag at. They were made bigger and clearer; a collection set to show only its emoji
now appears as a **bare, sized-up emoji** instead of a tiny glyph in a pill.

**Finding 9.3 — You couldn't tell which chip you were about to hit.** _(Polish, 1.1.12)_
Nothing distinguished the chip under the pointer, so during a drag it was unclear
which bucket you'd drop into. Pointing at a chip now makes it **lift, glow, and grow
slightly**, confirming the target before you release.

**Finding 9.4 — Boxed panels walled the library off from the grid.** _(Polish, 1.1.9 → 1.1.12)_
Favorites and Recently copied were first put in their own boxes so a long list
wouldn't push Trending down the popover (1.1.9). But the boxes read as walled-off
panels that broke the alignment of the window. Removing the boxes (1.1.12) let the
GIFs **line up with everything else**, so the window reads as one surface.

**Finding 9.5 — The vertical scroll bar covered content and looked heavy.** _(Polish, 1.1.10, 1.1.12)_
Vertical scroll bars sat over the GIFs and made a light window feel cluttered.
They were removed, and discoverability was handled another way: a **half-shown row
at the bottom edge** signals there's more below, and a half-shown GIF at the end of
a sideways row signals it scrolls for more. The affordance replaced the scrollbar
rather than just hiding it.

**Finding 9.6 — Reorder dropped the chip in the wrong place.** _(Friction, 1.1.11)_
Dragging a chip to reorder it landed in the wrong slot — an off-by-one that got
worse in one drag direction. People couldn't arrange their collections
predictably. The drop now lands where you aimed, in both directions.

## 10. Layout sizes and the detaching arrow

**Finding 10.1 — Only two sizes, neither roomy enough to browse.** _(Friction, 1.0.0 → 1.1.8)_
Quip shipped with narrow (2 per row) and wide (5 per row) only. Neither gave much
vertical room, so browsing meant a lot of scrolling. A third **tall layout** fills
about 80% of screen height, three to a row, for browsing without scrolling.

**Finding 10.2 — Changing size while open detached the popover's arrow.** _(Polish, 1.1.9)_
Changing the layout size while the popover was open left its pointer arrow detached
from the menu-bar icon — the window looked unmoored. Every layout size was also made
the **same height** (only width and columns change), and the arrow now stays put.

## 11. Sharing and the API key

**Finding 11.1 — Pasted links didn't show a preview.** _(Friction, 1.1.0 → 1.1.11)_
⌥-click copies a link instead of the file, but the link it copied didn't unfurl into
a preview when pasted into chat apps — so the recipient saw a bare URL. It now copies
the **giphy.com link**, which apps that unfurl links show as a preview.

**Finding 11.2 — The API key sat in a plain, always-visible field.** _(Friction, 1.1.5 → 1.1.11)_
The Giphy API key was shown in a plain text field, in the open where anyone
glancing at the screen could read it, and stored in the app's plain preferences.
It's now **hidden by default with a reveal button** (1.1.5) and stored in the macOS
**Keychain** (1.1.11), with existing keys moved over automatically so no one has to
re-enter theirs.

## 12. Small but sharp

**Finding 12.1 — Filtering favourites could strand them.** _(Friction, 1.1.1)_
When the favourites list shrank while a filter was active, favourites could be
stranded out of view — present but unreachable. The filter now handles a shrinking
list without losing them.

**Finding 12.2 — A GIF that couldn't load spun forever.** _(Friction, 1.1.5)_
A GIF that failed to load kept spinning with no end state, so people waited on
something that would never arrive. It now shows a **placeholder** instead.

**Finding 12.3 — Recent searches couldn't be cleared.** _(Polish, 1.1.11)_
Recently copied GIFs could be cleared but recent searches couldn't, an inconsistency
people noticed. A **Clear button** on the recent-searches row matched the two.

## Patterns worth carrying forward

A few themes recur across the findings and are worth stating plainly, because they
predict where the next problems will come from:

1. **Invisible actions need visible confirmation.** Copy and file both change
   nothing on screen, and both needed an explicit cue — and a cue that tells the
   truth when the action fails (2.1, 2.2, 8.2, 8.4). Any new invisible action will
   need the same.
2. **A silent no-op is worse than an error.** The drag that looked filed but wasn't
   (8.2) did more damage than an honest failure would have. Fail loudly.
3. **Direct manipulation beats menus for "put this there."** The move from
   right-click submenu to drag-onto-chip (8.1) was the single biggest usability win
   in Collections.
4. **The chrome must not fight the content.** Scroll bars covering stars and GIFs
   (3.2, 9.5) took repeated fixes; the lasting answer was to remove the chrome and
   replace it with a content-based affordance (a half-shown row).
5. **Put the tool where the moment is.** Filing belongs next to the search result
   you just found, not on a separate screen you have to navigate back to (8.4).
6. **Don't interrupt a quick-picker.** The anti-modal stance (7.1) flows from what
   Quip is — a thing you summon for two seconds and dismiss.
