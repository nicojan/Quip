import XCTest
import AppKit
@testable import Quip

@MainActor
private final class FakePopover: MorphablePopover {
    var contentSize = NSSize(width: 320, height: 700)
    var isShown = true
    var animates = true
}

@MainActor
private final class FakeTicker: MorphTicker {
    var onFrame: ((CFTimeInterval, CFTimeInterval) -> Void)?
    var stopped = false
    func stop() { stopped = true }
}

@MainActor
final class PopoverMorpherTests: XCTestCase {
    private let narrow = NSSize(width: 320, height: 700)
    private let tall = NSSize(width: 440, height: 700)
    private let wide = NSSize(width: 640, height: 700)
    private var popover: FakePopover!
    private var tickers: [FakeTicker] = []
    private var morpher: PopoverMorpher!

    override func setUp() async throws {
        popover = FakePopover()
        tickers = []
        morpher = PopoverMorpher(popover: popover) { [unowned self] onFrame in
            let ticker = FakeTicker()
            ticker.onFrame = onFrame
            tickers.append(ticker)
            return ticker
        }
    }

    /// Drives the live ticker one 60 Hz frame at a time from `t`.
    private func frames(_ count: Int, from t: CFTimeInterval) {
        for n in 0..<count {
            let frame = t + Double(n) / 60
            tickers.last?.onFrame?(frame, frame + 1.0 / 60)
        }
    }

    func testMorphsThroughTheSizesInBetweenAndEndsExactly() {
        morpher.resize(to: wide, animated: true)
        XCTAssertEqual(tickers.count, 1)
        XCTAssertFalse(popover.animates, "NSPopover's own animation must be off during a morph")

        frames(6, from: 100)   // 0.1 s in
        XCTAssertGreaterThan(popover.contentSize.width, narrow.width)
        XCTAssertLessThan(popover.contentSize.width, wide.width)
        XCTAssertEqual(popover.contentSize.height, 700)

        frames(20, from: 100.1)
        XCTAssertEqual(popover.contentSize, wide)
        XCTAssertTrue(tickers[0].stopped, "the frame clock stops when the morph ends")
        XCTAssertTrue(popover.animates)
        XCTAssertFalse(morpher.isMorphing)
    }

    /// The first frame can come late (the layout change that starts the morph is
    /// heavy); the curve starts there instead of jumping ahead.
    func testClockStartsOnTheFirstFrame() {
        morpher.resize(to: wide, animated: true)
        frames(1, from: 500)
        let firstStep = popover.contentSize.width - narrow.width
        XCTAssertLessThan(firstStep, (wide.width - narrow.width) * 0.15)
    }

    /// Nothing may tick behind a closed popover (the 1.1.16 regression class).
    func testNeverStartsAClockWhileClosed() {
        popover.isShown = false
        morpher.resize(to: wide, animated: true)
        XCTAssertTrue(tickers.isEmpty)
        XCTAssertEqual(popover.contentSize, wide)
    }

    func testClosingMidMorphStopsTheClockOnTheFinalSize() {
        morpher.resize(to: wide, animated: true)
        frames(3, from: 0)
        morpher.finish()   // what popoverWillClose / popoverDidClose call
        XCTAssertTrue(tickers[0].stopped)
        XCTAssertEqual(popover.contentSize, wide)
        XCTAssertTrue(popover.animates)
        XCTAssertFalse(morpher.isMorphing)
    }

    /// A second change mid-morph carries on from where the window is, on the same
    /// clock, rather than jumping to the old target first.
    func testRetargetsFromTheCurrentSize() {
        morpher.resize(to: wide, animated: true)
        frames(6, from: 0)
        let midway = popover.contentSize.width
        morpher.resize(to: tall, animated: true)
        XCTAssertEqual(tickers.count, 1)
        frames(1, from: 1)
        XCTAssertLessThanOrEqual(abs(popover.contentSize.width - midway), (wide.width - narrow.width) * 0.15)
        frames(30, from: 1.1)
        XCTAssertEqual(popover.contentSize, tall)
    }

    /// The same target arriving twice (the change is announced more than once)
    /// must not restart the curve.
    func testIgnoresTheTargetAlreadyInFlight() {
        morpher.resize(to: wide, animated: true)
        frames(6, from: 0)
        let before = popover.contentSize.width
        morpher.resize(to: wide, animated: true)
        frames(1, from: 0.1)
        XCTAssertGreaterThanOrEqual(popover.contentSize.width, before)
    }

    /// Reduce Motion, or a resize before the popover shows: set at once, and an
    /// unanimated change mid-morph never flashes the old target first.
    func testUnanimatedResizeIsImmediateAndCancelsAMorph() {
        morpher.resize(to: wide, animated: true)
        frames(3, from: 0)
        var seen: [NSSize] = []
        let probe = popover!
        morpher.resize(to: narrow, animated: false)
        seen.append(probe.contentSize)
        XCTAssertEqual(seen, [narrow])
        XCTAssertTrue(tickers[0].stopped)
        XCTAssertTrue(popover.animates)
    }

    func testFallsBackToAnInstantChangeWithNoClock() {
        let morpher = PopoverMorpher(popover: popover) { _ in nil }
        morpher.resize(to: wide, animated: true)
        XCTAssertEqual(popover.contentSize, wide)
        XCTAssertTrue(popover.animates)
        XCTAssertFalse(morpher.isMorphing)
    }
}
