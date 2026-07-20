import SwiftUI

/// The collection row above the favourites grid: an `All` chip, one chip per
/// collection, and a `+` to create one. Create and rename use inline text fields
/// — never a modal, since the transient popover would dismiss under one. This
/// row manages buckets; filing GIFs into them lives on the cell context menu.
struct CollectionChipsRow: View {
    @Environment(GifLibrary.self) private var library
    @Binding var selectedID: String?

    @State private var creating = false
    @State private var editingID: String?
    @State private var draftName = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip("All", selected: selectedID == nil) { selectedID = nil }

                ForEach(library.collections) { collection in
                    if editingID == collection.id {
                        nameField(commit: { commitRename(collection.id) }, cancel: cancelEditing)
                    } else {
                        chip(collection.name, selected: selectedID == collection.id) {
                            selectedID = collection.id
                        }
                        .contextMenu {
                            Button("Rename") { beginRename(collection) }
                            Button("Delete", role: .destructive) { delete(collection) }
                        }
                    }
                }

                if creating {
                    nameField(commit: commitCreate, cancel: cancelEditing)
                } else {
                    Button(action: beginCreate) {
                        Image(systemName: "plus")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("New collection")
                    .accessibilityLabel("New collection")
                }
            }
            .padding(.horizontal, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // A half-typed create/rename shouldn't survive a close/reopen.
        .onReceive(NotificationCenter.default.publisher(for: .quipPopoverShown)) { _ in
            cancelEditing()
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 120)
        }
        .buttonStyle(.plain)
        .font(.caption)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(selected ? Theme.accent : Color.white.opacity(0.08), in: Capsule())
        .foregroundStyle(selected ? Color.white : Color.primary)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func nameField(commit: @escaping () -> Void, cancel: @escaping () -> Void) -> some View {
        TextField("Name", text: $draftName)
            .textFieldStyle(.plain)
            .font(.caption)
            .frame(width: 110)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.12), in: Capsule())
            .focused($fieldFocused)
            .onSubmit(commit)
            .onExitCommand(perform: cancel)
            // Toggle false → true across a runloop tick: assigning true when it's
            // already true is a no-op, so a second create/rename wouldn't focus.
            // Same fix the search field uses (MenuContentView.focusSearchSoon).
            .onAppear {
                fieldFocused = false
                DispatchQueue.main.async { fieldFocused = true }
            }
    }

    // MARK: Create

    private func beginCreate() {
        editingID = nil
        draftName = ""
        creating = true
    }

    private func commitCreate() {
        if let created = library.createCollection(named: draftName) { selectedID = created.id }
        cancelEditing()
    }

    // MARK: Rename

    private func beginRename(_ collection: GifCollection) {
        creating = false
        draftName = collection.name
        editingID = collection.id
    }

    private func commitRename(_ id: String) {
        library.renameCollection(id, to: draftName)
        cancelEditing()
    }

    // MARK: Delete

    private func delete(_ collection: GifCollection) {
        if selectedID == collection.id { selectedID = nil }
        library.deleteCollection(collection.id)
    }

    private func cancelEditing() {
        creating = false
        editingID = nil
        draftName = ""
    }
}
