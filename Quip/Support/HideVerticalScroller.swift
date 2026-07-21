import SwiftUI
import AppKit

extension View {
    /// Permanently removes a `ScrollView`'s vertical scroller, even when the system
    /// is set to always show scroll bars — a case SwiftUI's
    /// `.scrollIndicators(.hidden)` ignores. Trackpad and wheel scrolling still
    /// work; the half-shown next row is the only cue that there's more below.
    ///
    /// Apply it to the scroll *content* (not the `ScrollView` itself), so the probe
    /// lands inside the document view and can reach the backing `NSScrollView`.
    func hideVerticalScroller() -> some View {
        background(ScrollerHider().frame(width: 0, height: 0).allowsHitTesting(false))
    }
}

/// A zero-size probe that finds its enclosing `NSScrollView` and turns the
/// vertical scroller off. Reapplies on every update, since SwiftUI can rebuild the
/// scroll view and restore the scroller.
private struct ScrollerHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { hideScroller(from: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { hideScroller(from: nsView) }
    }

    private func hideScroller(from view: NSView) {
        guard let scrollView = view.enclosingScrollView else { return }
        scrollView.hasVerticalScroller = false
    }
}
