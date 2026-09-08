import Observation

/// Whether the menu-bar popover is on screen, so GIF cells can stop animating
/// while it's closed.
///
/// The popover's hosting controller is built once at launch and never torn down
/// (see `AppDelegate`), so closing the popover leaves every cell in the tree
/// alive with its display link still firing at the screen refresh rate — 36 GIFs
/// decoding and redrawing on the main thread behind a window nobody can see.
///
/// SDWebImage's own visibility check doesn't catch this. It tests `view.window`,
/// which stays set when a popover window is merely ordered out, and it only
/// re-runs when the view moves between windows — which never happens here.
@MainActor
@Observable
final class PopoverVisibility {
    static let shared = PopoverVisibility()

    /// Set by `AppDelegate` on every show and on every close path (Esc,
    /// click-away, the hotkey, or opening Settings).
    var isOpen: Bool

    /// `AppDelegate` uses `shared`; the demo harness makes its own already-open
    /// instance, since it renders the content in a plain window with no popover.
    init(isOpen: Bool = false) {
        self.isOpen = isOpen
    }
}
