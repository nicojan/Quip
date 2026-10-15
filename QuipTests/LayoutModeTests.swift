import XCTest
@testable import Quip

final class LayoutModeTests: XCTestCase {
    func testColumnsPerMode() {
        XCTAssertEqual(LayoutMode.narrow.columns, 2)
        XCTAssertEqual(LayoutMode.tall.columns, 3)
        XCTAssertEqual(LayoutMode.wide.columns, 5)
    }

    /// Every layout is the same (tallest) height: 80% of the usable screen.
    func testAllHeightsAre80PercentOfScreen() {
        for mode in LayoutMode.allCases {
            XCTAssertEqual(mode.height(forScreenHeight: 1000), 800)
            XCTAssertEqual(mode.height(forScreenHeight: 1440), 1152)
        }
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

final class StripCellWidthTests: XCTestCase {
    /// At each preset's own width, a strip shows the same cells as before:
    /// 1.5 for narrow, 2.5 for tall, 4.5 for wide (content = width minus 24 pt).
    func testMatchesEachPresetAtItsWidth() {
        XCTAssertEqual(LayoutMode.stripCellWidth(contentWidth: 296), 186)
        XCTAssertEqual(LayoutMode.stripCellWidth(contentWidth: 416), 156)
        XCTAssertEqual(LayoutMode.stripCellWidth(contentWidth: 616), 128)
    }

    /// Between presets it moves smoothly and one way, so a morph that passes
    /// through every width in between never jumps or wobbles.
    func testChangesSmoothlyBetweenPresets() {
        var previous = LayoutMode.stripCellWidth(contentWidth: 296)
        for width in stride(from: 297.0, through: 616.0, by: 1.0) {
            let cell = LayoutMode.stripCellWidth(contentWidth: width)
            XCTAssertLessThanOrEqual(cell, previous)
            XCTAssertLessThan(previous - cell, 1)
            previous = cell
        }
    }

    func testClampsOutsideThePresets() {
        XCTAssertEqual(LayoutMode.stripCellWidth(contentWidth: 100), 186)
        XCTAssertEqual(LayoutMode.stripCellWidth(contentWidth: 2000), 128)
    }
}
