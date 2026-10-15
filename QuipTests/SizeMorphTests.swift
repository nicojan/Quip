import XCTest
import SwiftUI
@testable import Quip

final class SizeMorphTests: XCTestCase {
    private let narrow = CGSize(width: 320, height: 700)
    private let wide = CGSize(width: 640, height: 700)

    /// Short enough never to feel slow, long enough to read as one window resizing.
    func testDurationIsInTheBrief() {
        XCTAssertGreaterThanOrEqual(SizeMorph.duration, 0.25)
        XCTAssertLessThanOrEqual(SizeMorph.duration, 0.35)
    }

    func testStartsAndEndsOnTheExactSizes() {
        XCTAssertEqual(SizeMorph.size(from: narrow, to: wide, elapsed: 0), narrow)
        XCTAssertEqual(SizeMorph.size(from: narrow, to: wide, elapsed: SizeMorph.duration), wide)
    }

    /// A late or early display-link tick must not overshoot either end.
    func testClampsOutsideTheMorph() {
        XCTAssertEqual(SizeMorph.size(from: narrow, to: wide, elapsed: -0.1), narrow)
        XCTAssertEqual(SizeMorph.size(from: narrow, to: wide, elapsed: 5), wide)
        XCTAssertTrue(SizeMorph.isFinished(elapsed: SizeMorph.duration))
        XCTAssertFalse(SizeMorph.isFinished(elapsed: SizeMorph.duration / 2))
    }

    /// The height and top edge stay put: only the width moves.
    func testHeightNeverChanges() {
        for step in 0...30 {
            let elapsed = SizeMorph.duration * Double(step) / 30
            XCTAssertEqual(SizeMorph.size(from: narrow, to: wide, elapsed: elapsed).height, 700)
        }
    }

    /// No bounce: every frame is between the two sizes and moves one way only,
    /// growing and shrinking alike.
    func testMovesOneWayWithNoBounce() {
        for (from, to) in [(narrow, wide), (wide, narrow)] {
            var previous = from.width
            for step in 0...60 {
                let width = SizeMorph.size(from: from, to: to, elapsed: SizeMorph.duration * Double(step) / 60).width
                XCTAssertGreaterThanOrEqual(width, min(from.width, to.width))
                XCTAssertLessThanOrEqual(width, max(from.width, to.width))
                if to.width > from.width {
                    XCTAssertGreaterThanOrEqual(width, previous)
                } else {
                    XCTAssertLessThanOrEqual(width, previous)
                }
                previous = width
            }
        }
    }

    /// Ease-out: more than half the distance is covered in the first half.
    func testEasesOut() {
        let half = SizeMorph.size(from: narrow, to: wide, elapsed: SizeMorph.duration / 2).width
        XCTAssertGreaterThan(half, (narrow.width + wide.width) / 2)
    }

    /// Reduce Motion keeps the old instant change: no animation at all.
    func testReduceMotionHasNoAnimation() {
        XCTAssertNil(SizeMorph.animation(reduceMotion: true))
        XCTAssertNotNil(SizeMorph.animation(reduceMotion: false))
    }
}
