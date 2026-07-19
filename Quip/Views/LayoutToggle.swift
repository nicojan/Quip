import SwiftUI

/// Compact 2-up / 5-up segmented control. Replaces InaGif's full-width
/// "Toggle Layout" button.
struct LayoutToggle: View {
    @Binding var isCompact: Bool

    var body: some View {
        Picker("Layout", selection: $isCompact) {
            Image(systemName: "square.grid.2x2")
                .accessibilityLabel("Narrow, 2 per row")
                .tag(false)
            Image(systemName: "square.grid.3x3")
                .accessibilityLabel("Wide, 5 per row")
                .tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .accessibilityLabel("Layout")
        .help(isCompact ? "Wide (5 per row)" : "Narrow (2 per row)")
    }
}
