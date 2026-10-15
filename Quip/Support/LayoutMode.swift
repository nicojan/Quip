import CoreGraphics
import Observation

/// The popover's three size presets. Persisted in `UserDefaults` as the raw
/// string under `layoutMode` (migrated from the old `isCompactLayout` bool — see
/// `AppDelegate.migrateLayoutPreference`).
enum LayoutMode: String, CaseIterable, Identifiable, Sendable {
    case narrow   // 2 per row, fixed height
    case tall     // 3 per row, 80% of the launching display's height
    case wide     // 5 per row, 80% of the launching display's height

    var id: String { rawValue }

    var columns: Int {
        switch self {
        case .narrow: 2
        case .tall: 3
        case .wide: 5
        }
    }

    var width: CGFloat {
        switch self {
        case .narrow: 320
        case .tall: 440
        case .wide: 640
        }
    }

    /// Popover height. Every layout fills 80% of the display it opens on, so all
    /// three are the same (tallest) height — only the width and column count
    /// change between them. `screenHeight` is the *usable* height
    /// (`NSScreen.visibleFrame`, menu bar and Dock excluded), because the popover
    /// opens downward from the menu bar and would clip — not scroll — anything
    /// taller than that.
    func height(forScreenHeight screenHeight: CGFloat) -> CGFloat {
        (screenHeight * 0.8).rounded()
    }

    /// Width of one cell in the horizontal Favorites / Recently-copied strips. At
    /// each preset's own width, half of the next cell shows past the last full
    /// one, an obvious "peep" that the strip scrolls sideways: 1.5 cells for
    /// narrow, 2.5 for tall, 4.5 for wide. Between presets it changes in a straight
    /// line, so while the popover morphs from one size to another the strip
    /// follows the window's live width with no jump. `contentWidth` is the strip's
    /// own width: the popover's minus its 12-pt padding on each side.
    static func stripCellWidth(contentWidth: CGFloat) -> CGFloat {
        let anchors = allCases.map { ($0.width - 24, $0.presetStripCellWidth) }.sorted { $0.0 < $1.0 }
        guard let first = anchors.first, let last = anchors.last else { return 0 }
        if contentWidth <= first.0 { return first.1 }
        if contentWidth >= last.0 { return last.1 }
        let upper = anchors.firstIndex { $0.0 >= contentWidth } ?? anchors.count - 1
        let (x0, y0) = anchors[upper - 1], (x1, y1) = anchors[upper]
        return y0 + (y1 - y0) * (contentWidth - x0) / (x1 - x0)
    }

    private var presetStripCellWidth: CGFloat {
        let cols = CGFloat(columns)
        return ((width - 24 - 8 * cols) / (cols - 0.5)).rounded(.down)
    }

    /// Maps the pre-1.1.8 two-state `isCompactLayout` bool. Note the flag's name is
    /// misleading: `true` was the dense 5-up **wide** layout (640pt), `false` the
    /// 2-up **narrow** one (320pt). Kept as a pure function so the mapping is tested
    /// (see `LayoutModeTests`) and can't be "corrected" the wrong way.
    init(legacyIsCompact: Bool) {
        self = legacyIsCompact ? .wide : .narrow
    }
}

/// Carries the height of the display the popover is about to open on, so the
/// `tall` layout can size itself to 80% of it. Updated by `AppDelegate` just
/// before each show and read by `MenuContentView`.
@MainActor
@Observable
final class LayoutMetrics {
    var launchScreenHeight: CGFloat

    init(launchScreenHeight: CGFloat) {
        self.launchScreenHeight = launchScreenHeight
    }
}
