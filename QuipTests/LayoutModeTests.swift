import XCTest
@testable import Quip

final class LayoutModeTests: XCTestCase {
    func testColumnsPerMode() {
        XCTAssertEqual(LayoutMode.narrow.columns, 2)
        XCTAssertEqual(LayoutMode.tall.columns, 3)
        XCTAssertEqual(LayoutMode.wide.columns, 5)
    }

    func testFixedHeightsIgnoreScreen() {
        XCTAssertEqual(LayoutMode.narrow.height(forScreenHeight: 1440), 600)
        XCTAssertEqual(LayoutMode.wide.height(forScreenHeight: 1440), 470)
    }

    func testTallHeightIs80PercentOfScreen() {
        XCTAssertEqual(LayoutMode.tall.height(forScreenHeight: 1000), 800)
        XCTAssertEqual(LayoutMode.tall.height(forScreenHeight: 1440), 1152)
    }

    func testRawValueRoundTripForPersistence() {
        for mode in LayoutMode.allCases {
            XCTAssertEqual(LayoutMode(rawValue: mode.rawValue), mode)
        }
    }

    /// Locks the legacy migration direction. The old `isCompactLayout` flag is
    /// misleadingly named: `true` was the 5-up WIDE layout, `false` the 2-up narrow
    /// one. Guards against a plausible-looking but wrong "fix" that inverts it.
    func testLegacyIsCompactMapping() {
        XCTAssertEqual(LayoutMode(legacyIsCompact: true), .wide)
        XCTAssertEqual(LayoutMode(legacyIsCompact: false), .narrow)
        // Width sanity: old true was 640 (wide), old false was 320 (narrow).
        XCTAssertEqual(LayoutMode(legacyIsCompact: true).width, 640)
        XCTAssertEqual(LayoutMode(legacyIsCompact: false).width, 320)
    }
}
