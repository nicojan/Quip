import SwiftUI
import AppKit

/// A button for choosing one emoji to represent a tag. Empty, it's a
/// Messages-style circular smiley; once picked, the button *becomes* the chosen
/// emoji. Tapping it opens the **native macOS emoji picker** (Character Viewer),
/// so the full system emoji set and its search come for free.
///
/// The picker inserts into whatever text control is first responder, so a tiny
/// invisible capture field rides behind the button purely to receive that
/// insertion — the user never sees or types into it.
///
/// The app lives in a *transient* NSPopover, which would dismiss the moment a
/// separate panel opens; focusing the capture field posts
/// `.quipSuspendPopoverAutoClose` so AppDelegate holds the popover open until the
/// tag editor closes.
struct EmojiField: View {
    @Binding var selection: String   // the chosen emoji; "" means none selected

    /// Bumped on each tap to ask the capture field to grab focus and open the
    /// picker (a plain value change the representable can observe).
    @State private var focusRequest = 0

    init(selection: Binding<String>) {
        _selection = selection
    }

    private var hasEmoji: Bool {
        !selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 6) {
            Button { focusRequest += 1 } label: {
                ZStack {
                    if hasEmoji {
                        Text(selection).font(.system(size: 16))
                    } else {
                        Circle().fill(Color.white.opacity(0.12))
                        Image(systemName: "face.smiling")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .frame(width: 26, height: 26)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Pick an emoji")
            .accessibilityLabel(hasEmoji ? "Collection emoji: \(selection)" : "Pick a collection emoji")
            .background(
                EmojiCaptureField(selection: $selection, focusRequest: focusRequest)
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
            )

            if hasEmoji {
                Button { selection = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove emoji")
                .accessibilityLabel("Remove emoji")
            }
        }
    }
}

/// A 1×1, invisible `NSTextField` that grabs focus and opens the system emoji
/// picker on request, then hands whatever it captures back as a single emoji.
private struct EmojiCaptureField: NSViewRepresentable {
    @Binding var selection: String
    var focusRequest: Int

    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.isBezeled = false
        field.isBordered = false
        field.drawsBackground = false
        field.backgroundColor = .clear
        field.textColor = .clear          // never shows text or a visible caret
        field.font = .systemFont(ofSize: 1)
        field.focusRingType = .none
        field.stringValue = selection
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != selection { nsView.stringValue = selection }
        guard context.coordinator.lastFocusRequest != focusRequest, focusRequest > 0 else { return }
        context.coordinator.lastFocusRequest = focusRequest
        // Defer so the button's own click settles before we take first responder.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .quipSuspendPopoverAutoClose, object: nil)
            nsView.window?.makeFirstResponder(nsView)
            NSApp.orderFrontCharacterPalette(nil)
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var selection: String
        var lastFocusRequest = 0

        init(selection: Binding<String>) { _selection = selection }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            // Keep only the last emoji the picker inserted.
            if let emoji = field.stringValue.reversed().first(where: { $0.isEmojiGlyph }) {
                selection = String(emoji)
            }
            field.stringValue = ""
            // Drop focus so no field editor lingers behind the button.
            field.window?.makeFirstResponder(nil)
        }
    }
}

private extension Character {
    /// True for a real emoji glyph. Excludes the ASCII digits/`#`/`*` that Unicode
    /// also flags as `isEmoji`, so a stray keystroke never fills the well.
    var isEmojiGlyph: Bool {
        unicodeScalars.contains { scalar in
            scalar.properties.isEmojiPresentation
                || (scalar.properties.isEmoji && scalar.value >= 0x1F000)
        }
    }
}
