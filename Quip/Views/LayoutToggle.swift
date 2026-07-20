import SwiftUI

/// Three-way layout picker: narrow (2-up), tall (3-up, full-height), wide (5-up).
struct LayoutToggle: View {
    @Binding var mode: LayoutMode

    var body: some View {
        Picker("Layout", selection: $mode) {
            Image(systemName: "square.grid.2x2")
                .accessibilityLabel("Narrow, 2 per row")
                .tag(LayoutMode.narrow)
            Image(systemName: "square.grid.3x3")
                .accessibilityLabel("Tall, 3 per row")
                .tag(LayoutMode.tall)
            Image(systemName: "square.grid.4x3.fill")
                .accessibilityLabel("Wide, 5 per row")
                .tag(LayoutMode.wide)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .accessibilityLabel("Layout")
        .help(helpText)
    }

    private var helpText: String {
        switch mode {
        case .narrow: "Narrow (2 per row)"
        case .tall: "Tall (3 per row, full height)"
        case .wide: "Wide (5 per row)"
        }
    }
}
