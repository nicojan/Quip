import SwiftUI

/// Compact 2-up / 5-up segmented control. Replaces InaGif's full-width
/// "Toggle Layout" button.
struct LayoutToggle: View {
    @Binding var isCompact: Bool

    var body: some View {
        Picker("Layout", selection: $isCompact) {
            Image(systemName: "square.grid.2x2").tag(false)
            Image(systemName: "square.grid.3x3").tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .help(isCompact ? "Wide (5 per row)" : "Narrow (2 per row)")
    }
}
