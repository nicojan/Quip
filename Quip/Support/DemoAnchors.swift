import SwiftUI

/// Where the demo harness's on-screen targets are, so a scripted cursor can find a
/// chip, a cell or a control at any layout size instead of relying on hand-measured
/// points. Frames are in window coordinates (SwiftUI `.global`, top-left origin).
/// Only the DEBUG demo harness turns it on; everywhere else `demoAnchor` is inert.
@MainActor
final class DemoAnchors {
    static let shared = DemoAnchors()
    /// Set by `DemoHarness` before any view builds. Off in every normal run.
    var isEnabled = false
    private(set) var frames: [String: CGRect] = [:]

    func set(_ key: String, _ frame: CGRect) {
        guard isEnabled else { return }
        frames[key] = frame
    }

    func frame(_ key: String) -> CGRect? { frames[key] }
}

extension View {
    /// Reports this view's frame to `DemoAnchors` under `key` (DEBUG demo only).
    @ViewBuilder
    func demoAnchor(_ key: String) -> some View {
        #if DEBUG
        background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { DemoAnchors.shared.set(key, geo.frame(in: .global)) }
                    .onChange(of: geo.frame(in: .global)) { _, frame in
                        DemoAnchors.shared.set(key, frame)
                    }
                // No removal on disappear: the drawer swaps its compact row for its
                // wrapped panel, and the old chip's disappear lands after the new
                // one's appear, which would wipe the live frame.
            }
        )
        #else
        self
        #endif
    }
}
