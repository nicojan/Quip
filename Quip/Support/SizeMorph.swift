import AppKit
import SwiftUI

/// The timing for a layout-size change, shared by the two halves that have to
/// move together: SwiftUI animates the content (every GIF slides from its old
/// slot to its new one) and `PopoverMorpher` resizes the popover window around
/// it, frame by frame, on the same curve.
enum SizeMorph {
    static let duration: Double = 0.3
    /// Ease-out with no overshoot, so the window never bounces past its new size.
    static let curve: UnitCurve = .easeOut

    /// The content's half. Nil under Reduce Motion, which keeps the old instant
    /// change.
    static func animation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .timingCurve(curve, duration: duration)
    }

    /// The popover's size `elapsed` seconds into a morph, clamped to the two ends.
    static func size(from start: CGSize, to end: CGSize, elapsed: Double) -> CGSize {
        let t = min(max(elapsed / duration, 0), 1)
        let p = curve.value(at: t)
        return CGSize(width: start.width + (end.width - start.width) * p,
                      height: start.height + (end.height - start.height) * p)
    }

    static func isFinished(elapsed: Double) -> Bool { elapsed >= duration }
}

/// Resizes the popover along `SizeMorph`'s curve.
///
/// NSPopover can't do this itself. Its own resize animation runs about 90 ms on a
/// fixed curve and blocks the main thread while it runs, so the GIFs freeze and
/// the content jumps to its final width on the first frame. So for a size change
/// the popover's animation is switched off and `contentSize` is set on every
/// display frame instead (about 1 ms each). NSPopover re-anchors on each set, so
/// the arrow stays on the menu-bar icon and the top edge stays put.
///
/// The display link runs only during a morph and is invalidated when it ends or
/// the popover closes, so nothing ticks behind a closed popover.
@MainActor
final class PopoverMorpher: NSObject {
    private let popover: NSPopover
    private var link: CADisplayLink?
    private var start = CGSize.zero
    private var target = CGSize.zero
    private var startTime: CFTimeInterval = 0

    init(popover: NSPopover) {
        self.popover = popover
    }

    /// The popover's content controller, set up so the morph can work.
    static func host<Content: View>(_ content: Content) -> NSViewController {
        let hosting = NSHostingController(
            rootView: content
                // The window and the content morph on two clocks, so for a frame
                // they can differ by a few points. Painting the surface out to the
                // window edge keeps that gap invisible.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.surface)
        )
        // The popover's size comes only from `contentSize`. Left on, the hosting
        // controller would pin the window to the content's final size the moment a
        // layout change starts, and the morph could never pass through the sizes
        // in between.
        hosting.sizingOptions = []
        return hosting
    }

    /// Moves the popover to `size`: morphed when `animated` and the popover is on
    /// screen, otherwise set at once (which also ends any morph in flight).
    func resize(to size: NSSize, animated: Bool) {
        guard animated, popover.isShown, popover.contentSize != size,
              let view = popover.contentViewController?.view else {
            finish()
            popover.contentSize = size
            return
        }
        // A click mid-morph starts the next one from wherever the window is now.
        start = popover.contentSize
        target = size
        startTime = CACurrentMediaTime()
        popover.animates = false
        if link == nil {
            let link = view.displayLink(target: self, selector: #selector(step(_:)))
            link.add(to: .main, forMode: .common)
            self.link = link
        }
    }

    /// Ends a morph in flight on its final size. Safe to call when idle.
    func finish() {
        guard let link else { return }
        link.invalidate()
        self.link = nil
        popover.contentSize = target
        popover.animates = true
    }

    @objc private func step(_ link: CADisplayLink) {
        // Aim at the moment this frame reaches the screen, as SwiftUI does for the
        // content, so the two halves stay in step.
        let elapsed = link.targetTimestamp - startTime
        if SizeMorph.isFinished(elapsed: elapsed) {
            finish()
        } else {
            popover.contentSize = SizeMorph.size(from: start, to: target, elapsed: elapsed)
        }
    }
}
