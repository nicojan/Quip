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
