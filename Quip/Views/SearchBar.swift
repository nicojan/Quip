import SwiftUI

/// A single rounded search field with an inline magnifier and clear button.
/// Replaces InaGif's field-plus-separate-Search-button.
struct SearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search GIFs", text: $text)
                .textFieldStyle(.plain)
                .focused(isFocused)
                .onSubmit(onSubmit)
                .onChange(of: text) { _, _ in onChange() }

            if !text.isEmpty {
                Button {
                    text = ""
                    onChange()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: Theme.corner))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner)
                .stroke(isFocused.wrappedValue ? Theme.accent : Theme.cardStroke, lineWidth: 1)
        )
    }
}
