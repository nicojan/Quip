import SwiftUI

/// The inline create/edit panel for a collection ("tag"). Shown below the chips —
/// never a modal, since the transient popover would dismiss under one. Collects a
/// name, an optional emoji, and a "show name" flag, then hands them back through
/// `onCommit`. The owner decides what a commit means (create a new tag, or save an
/// edit) and, for a drag-onto-＋ create, files the pending GIF into the result.
struct CollectionChipEditor: View {
    /// Drives the primary button label only (Create vs Save).
    let creating: Bool
    let onCommit: (_ name: String, _ emoji: String, _ showsName: Bool) -> Void
    let onCancel: () -> Void

    @State private var draftName: String
    @State private var draftEmoji: String       // "" means no emoji
    @State private var draftShowsName: Bool
    @FocusState private var nameFocused: Bool

    init(
        creating: Bool,
        name: String = "",
        emoji: String = "",
        showsName: Bool = true,
        onCommit: @escaping (String, String, Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.creating = creating
        self.onCommit = onCommit
        self.onCancel = onCancel
        _draftName = State(initialValue: name)
        _draftEmoji = State(initialValue: emoji)
        _draftShowsName = State(initialValue: showsName)
    }

    private var isDraftValid: Bool {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let emoji = draftEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && (draftShowsName || !emoji.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Collection name", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .frame(maxWidth: 180)
                    .focused($nameFocused)
                    .onSubmit { commit() }
                    .onExitCommand(perform: onCancel)
                EmojiField(selection: $draftEmoji)
                Spacer(minLength: 0)
            }

            Toggle("Show name on chip", isOn: $draftShowsName)
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .font(.caption)

            if !draftShowsName && draftEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Pick an emoji so the collection isn't blank.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .font(.caption)
                Button(creating ? "Create" : "Save", action: commit)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(Theme.accent)
                    .disabled(!isDraftValid)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: Theme.corner)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.corner).strokeBorder(Theme.cardStroke)
                )
        )
        // Toggle false → true across a runloop tick: assigning true when it's already
        // true is a no-op, so a second create/edit wouldn't focus. Same fix the
        // search field uses (MenuContentView.focusSearchSoon).
        .onAppear {
            nameFocused = false
            DispatchQueue.main.async { nameFocused = true }
        }
        // Restore the popover's transient auto-close once the editor goes away — it's
        // suspended while the emoji picker is open (see EmojiField).
        .onDisappear {
            NotificationCenter.default.post(name: .quipResumePopoverAutoClose, object: nil)
        }
    }

    private func commit() {
        guard isDraftValid else { return }
        onCommit(
            draftName,
            draftEmoji.trimmingCharacters(in: .whitespacesAndNewlines),
            draftShowsName
        )
    }
}
