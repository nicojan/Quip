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

/// What `PopoverMorpher` needs from a popover. NSPopover has it all; tests use
/// a stand-in.
@MainActor
protocol MorphablePopover: AnyObject {
    var contentSize: NSSize { get set }
    var isShown: Bool { get }
    var animates: Bool { get set }
}

extension NSPopover: MorphablePopover {}

/// A running frame clock for one morph, stopped when the morph ends.
@MainActor
protocol MorphTicker: AnyObject {
    func stop()
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
/// The frame clock runs only during a morph and is stopped when it ends or the
/// popover closes, so nothing ticks behind a closed popover.
@MainActor
final class PopoverMorpher {
    /// Starts a frame clock that calls back with each frame's start and the time
    /// it reaches the screen; nil when there's nothing to tick on.
    typealias StartTicker = (@escaping @MainActor (_ frame: CFTimeInterval, _ onScreen: CFTimeInterval) -> Void) -> MorphTicker?

    private let popover: MorphablePopover
    private let startTicker: StartTicker
    private var ticker: MorphTicker?
    private var start = CGSize.zero
    private var target = CGSize.zero
    /// Set on the morph's first frame, not at the click: the layout change that
    /// starts a morph can hold up that frame, and a clock started earlier would
    /// open with a jump instead of the curve's first step.
    private var startTime: CFTimeInterval?

    var isMorphing: Bool { ticker != nil }

    init(popover: MorphablePopover, startTicker: @escaping StartTicker) {
        self.popover = popover
        self.startTicker = startTicker
    }

    /// The real thing: a display link on the popover's content view.
    convenience init(popover: NSPopover) {
        self.init(popover: popover) { [weak popover] onFrame in
            guard let view = popover?.contentViewController?.view else { return nil }
            return DisplayLinkTicker(view: view, onFrame: onFrame)
        }
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
        guard animated, popover.isShown else {
            stop()
            popover.contentSize = size
            return
        }
        // Already heading there: let the morph run on rather than restart it.
        if isMorphing ? target == size : popover.contentSize == size { return }
        // A change mid-morph starts the next one from wherever the window is now.
        if ticker == nil {
            ticker = startTicker { [weak self] frame, onScreen in self?.step(frame: frame, onScreen: onScreen) }
            guard ticker != nil else {
                popover.contentSize = size
                return
            }
        }
        start = popover.contentSize
        target = size
        startTime = nil
        popover.animates = false
    }

    /// Ends a morph in flight on its final size. Safe to call when idle.
    func finish() {
        guard isMorphing else { return }
        stop()
        popover.contentSize = target
    }

    private func stop() {
        ticker?.stop()
        ticker = nil
        popover.animates = true
    }

    private func step(frame: CFTimeInterval, onScreen: CFTimeInterval) {
        let startTime = self.startTime ?? frame
        self.startTime = startTime
        // Aim at the moment this frame reaches the screen, as SwiftUI does for the
        // content, so the two halves stay in step.
        let elapsed = onScreen - startTime
        if SizeMorph.isFinished(elapsed: elapsed) {
            finish()
        } else {
            popover.contentSize = SizeMorph.size(from: start, to: target, elapsed: elapsed)
        }
    }
}

/// A display link on a view, for the length of one morph.
@MainActor
private final class DisplayLinkTicker: NSObject, MorphTicker {
    private var link: CADisplayLink?
    private let onFrame: @MainActor (CFTimeInterval, CFTimeInterval) -> Void

    init(view: NSView, onFrame: @escaping @MainActor (CFTimeInterval, CFTimeInterval) -> Void) {
        self.onFrame = onFrame
        super.init()
        link = view.displayLink(target: self, selector: #selector(tick(_:)))
        link?.add(to: .main, forMode: .common)
    }

    @objc private func tick(_ link: CADisplayLink) {
        onFrame(link.timestamp, link.targetTimestamp)
    }

    func stop() {
        link?.invalidate()
        link = nil
    }
}
