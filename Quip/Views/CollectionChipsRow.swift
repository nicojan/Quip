import SwiftUI
import UniformTypeIdentifiers

/// The collection row above the favourites grid: an `All` chip, one chip per
/// collection, and a `+` to create one. Create and rename use inline text fields
/// — never a modal, since the transient popover would dismiss under one. This row
/// manages buckets; GIFs are filed into them by the cell context menu or by
/// dragging a GIF cell onto a chip (see the drop handling below).
struct CollectionChipsRow: View {
    @Environment(GifLibrary.self) private var library
    @Environment(DragContext.self) private var dragContext
    @Binding var selectedID: String?

    @State private var creating = false
    @State private var editingID: String?
    @State private var draftName = ""
    @FocusState private var fieldFocused: Bool

    /// The chip a dragged GIF is currently hovering (drop-target highlight).
    @State private var dropTargetID: String?
    /// The chip to pulse briefly after a successful drop (the "it worked" cue,
    /// needed because dropping onto a non-selected collection changes nothing on screen).
    @State private var flashID: String?

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
                        .overlay(
                            Capsule()
                                .fill(Theme.accent.opacity(0.35))
                                .overlay(Capsule().strokeBorder(Theme.accent, lineWidth: 2.5))
                                .opacity(dropTargetID == collection.id || flashID == collection.id ? 1 : 0)
                                .allowsHitTesting(false)
                        )
                        .scaleEffect(dropTargetID == collection.id ? 1.15 : 1)
                        .animation(.easeOut(duration: 0.12), value: dropTargetID)
                        .animation(.easeOut(duration: 0.15), value: flashID)
                        .onDrop(
                            of: [QuipDragType.gifRef],
                            isTargeted: dropTargetBinding(collection.id)
                        ) { _ in
                            handleDrop(into: collection.id)
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

    // MARK: Drop filing

    /// Per-chip `isTargeted` binding: reading tells the chip whether a drag is over
    /// it; writing records which chip that is, so only one highlights at a time.
    /// The `false` write only clears the slot when this chip owns it — otherwise a
    /// stray `exit(A)` arriving after `enter(B)` would wipe B's highlight.
    private func dropTargetBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { dropTargetID == id },
            set: { isOver in
                if isOver { dropTargetID = id }
                else if dropTargetID == id { dropTargetID = nil }
            }
        )
    }

    /// Files the currently-dragged GIF into a collection. The GIF comes from
    /// `DragContext` (the drop provider arrives empty — see `DragContext`), and the
    /// `gifRef` acceptance type already gated this to Quip's own drags. Filing a
    /// not-yet-favourited GIF auto-favourites it on the way in.
    @MainActor private func handleDrop(into id: String) -> Bool {
        guard let gif = dragContext.gif else { return false }
        library.setMembership(gif, inCollection: id, member: true)
        dragContext.gif = nil
        flash(id)
        return true
    }

    /// Pulses a chip's border briefly to confirm a drop landed.
    @MainActor private func flash(_ id: String) {
        flashID = id
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            if flashID == id { flashID = nil }
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
