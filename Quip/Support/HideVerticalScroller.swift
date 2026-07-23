import SwiftUI
import AppKit

extension View {
    /// Permanently removes a `ScrollView`'s scrollers on both axes, even when the
    /// system is set to always show scroll bars — a case both SwiftUI's
    /// `.scrollIndicators(.hidden)` and the `showsIndicators: false` initializer
    /// ignore. Trackpad and wheel scrolling still work; the half-shown next row (or
    /// the peeking next cell in a horizontal strip) is the only cue that there's
    /// more.
    ///
    /// Apply it to the scroll *content* (not the `ScrollView` itself), so the probe
    /// lands inside the document view and can reach the backing `NSScrollView`.
    func hideScrollers() -> some View {
        background(ScrollerHider().frame(width: 0, height: 0).allowsHitTesting(false))
    }
}

/// A zero-size probe that finds its enclosing `NSScrollView` and turns both
/// scrollers off. Reapplies on every update, since SwiftUI can rebuild the
/// scroll view and restore them.
private struct ScrollerHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        hideScrollers(from: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        hideScrollers(from: nsView)
    }

    /// Turn off both scrollers, retrying on a short schedule. On first layout the
    /// backing `NSScrollView` may not be in the hierarchy yet, so a single async
    /// pass can miss it — and in a static host (no re-render) `updateNSView` never
    /// fires again. The staggered retries make the hide land whatever the timing.
    private func hideScrollers(from view: NSView) {
        for delay in [0.0, 0.05, 0.2, 0.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard let scrollView = view.enclosingScrollView else { return }
                // Overlay style so the (now hidden) scroller reserves no gutter —
                // otherwise a horizontal strip leaves an empty band where the bar
                // would sit, pushing its rows off-centre.
                scrollView.scrollerStyle = .overlay
                scrollView.hasVerticalScroller = false
                scrollView.hasHorizontalScroller = false
            }
        }
    }
}
