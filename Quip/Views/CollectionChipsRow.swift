import SwiftUI
import UniformTypeIdentifiers

/// The collection ("tag") row above the favourites grid: an `All` chip, a
/// divider, one chip per tag, a sort button, and a `+` to create one. Create and
/// edit use an inline editor panel below the row — never a modal, since the
/// transient popover would dismiss under one. Chips can be dragged to reorder,
/// and a GIF cell can be dropped onto a chip to file it. Each tag carries an
/// optional emoji and a "show name" flag (see `GifCollection`).
struct CollectionChipsRow: View {
    @Environment(GifLibrary.self) private var library
    @Environment(DragContext.self) private var dragContext
    @Binding var selectedID: String?

    // Inline editor state.
    @State private var creating = false
    @State private var editingID: String?
    @State private var draftName = ""
    @State private var draftEmoji = ""          // "" means no emoji
    @State private var draftShowsName = true
    @FocusState private var nameFocused: Bool

    /// The chip a drag is currently over (filing highlight or reorder target).
    @State private var activeTargetID: String?
    /// The chip being dragged to reorder; nil when no reorder drag is in flight.
    @State private var draggingID: String?
    /// The chip to pulse briefly after a successful GIF drop — the "it worked" cue,
    /// needed because filing into a non-selected tag changes nothing on screen.
    @State private var flashID: String?
    /// The category chip under the pointer, for the accent hover glow. Tracked here
    /// (not per-chip) because the chips are built by helper funcs, not their own
    /// views. `allID` stands in for the "All" chip, which has no collection id.
    @State private var hoveredID: String?
    private let allID = "__all__"

    /// One height for every chip — labelled pills, the "All" pill, and the
    /// sort/add buttons — so they line up with the taller emoji-only chips.
    private let chipHeight: CGFloat = 30

    private var isEditing: Bool { creating || editingID != nil }

    /// Records which chip the pointer is over, clearing the slot only when this chip
    /// owns it — so a stray exit after another chip's enter can't wipe the new one.
    private func setHover(_ id: String, _ hovering: Bool) {
        if hovering { hoveredID = id }
        else if hoveredID == id { hoveredID = nil }
    }

    private var isDraftValid: Bool {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        let emoji = draftEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && (draftShowsName || !emoji.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            chipRow
            if isEditing { editor }
        }
        // A half-typed create/edit — and a stale reorder drag — shouldn't survive a
        // close/reopen.
        .onReceive(NotificationCenter.default.publisher(for: .quipPopoverShown)) { _ in
            cancelEditing()
            draggingID = nil
        }
    }

    private var chipRow: some View {
        // Top row: the All chip on the left, sort and add on the right. The tag
        // chips wrap onto their own line(s) below, spilling to a second and third
        // row once they fill the width — no sideways scrolling.
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                chip("All", selected: selectedID == nil) { selectedID = nil }
                Spacer(minLength: 6)
                if library.collections.count >= 2 { sortButton }
                addButton
            }

            if !library.collections.isEmpty {
                FlowLayout(spacing: 12, lineSpacing: 10) {
                    ForEach(library.collections) { collection in
                        collectionChip(collection)
                    }
                }
                .padding(.vertical, 6)   // room for the hover magnify + glow
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // Inset the whole chip group so a hovered edge chip's magnify and glow have
        // room before the enclosing scroll view clips them.
        .padding(.horizontal, 8)
    }

    // MARK: Chips

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .fixedSize()   // hug the label ("All") — don't stretch to fill the row
        }
        .buttonStyle(.plain)
        .font(.footnote.weight(.medium))
        .padding(.horizontal, 12)
        .frame(height: chipHeight)
        .background(selected ? Theme.accent : Color.white.opacity(0.12), in: Capsule())
        .foregroundStyle(selected ? Color.white : Color.primary)
        .hoverEffect(hoveredID == allID)
        .onHover { hovering in setHover(allID, hovering) }
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func collectionChip(_ collection: GifCollection) -> some View {
        let id = collection.id
        let isFiling = activeTargetID == id && dragContext.gif != nil
        let isReorderTarget = activeTargetID == id && draggingID != nil && draggingID != id
        return chipButton(collection)
            .overlay(
                Capsule()
                    .fill(Theme.accent.opacity(0.35))
                    .overlay(Capsule().strokeBorder(Theme.accent, lineWidth: 2.5))
                    .opacity(isFiling || flashID == id ? 1 : 0)
                    .allowsHitTesting(false)
            )
            .overlay(
                Capsule()
                    .strokeBorder(Theme.accentText, lineWidth: 2)
                    .opacity(isReorderTarget ? 1 : 0)
                    .allowsHitTesting(false)
            )
            .scaleEffect(isFiling ? 1.15 : 1)
            .hoverEffect(hoveredID == id)
            .onHover { hovering in setHover(id, hovering) }
            .animation(.easeOut(duration: 0.12), value: activeTargetID)
            .animation(.easeOut(duration: 0.15), value: flashID)
            .onDrag {
                // Starting a reorder: mark this chip as the one moving and make sure
                // no stale GIF-filing payload is mistaken for it (see the drop below).
                dragContext.gif = nil
                draggingID = id
                return collectionProvider(id)
            }
            .onDrop(
                of: [QuipDragType.collectionRef, QuipDragType.gifRef],
                isTargeted: targetBinding(id)
            ) { _ in
                // A GIF drag always carries `dragContext.gif`; a reorder never does —
                // so the presence of that payload disambiguates the two drop kinds.
                if dragContext.gif != nil { return handleDrop(into: id) }
                return performReorder(onto: id)
            }
            .contextMenu {
                Button("Edit") { beginEdit(collection) }
                Button("Delete", role: .destructive) { delete(collection) }
            }
    }

    private func chipButton(_ collection: GifCollection) -> some View {
        let hasEmoji = !(collection.emoji?.isEmpty ?? true)
        // Guarantee a non-empty chip even for an odd record: fall back to the name
        // when there's no emoji, whatever `showsName` says.
        let showName = collection.showsName || !hasEmoji
        // No label to carry a pill — the emoji stands alone as an icon.
        let emojiOnly = hasEmoji && !showName
        let selected = selectedID == collection.id
        return Button { selectedID = collection.id } label: {
            HStack(spacing: 4) {
                if hasEmoji {
                    // With no name beside it the emoji is the whole chip, so let it
                    // grow past the label text size instead of sitting tiny.
                    Text(collection.emoji ?? "")
                        .font(emojiOnly ? .title2 : .footnote.weight(.medium))
                        // No pill to mark it selected, so dim the inactive ones — but
                        // only once a collection is active. Under "All" nothing is
                        // singled out, so every emoji shows at full strength.
                        .opacity(emojiOnly && selectedID != nil && !selected ? 0.5 : 1)
                }
                if showName {
                    Text(collection.name)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 130)
                }
            }
        }
        .buttonStyle(.plain)
        .font(.footnote.weight(.medium))
        .padding(.horizontal, emojiOnly ? 5 : 12)
        .frame(height: chipHeight)
        .background {
            // A bare emoji wears no pill; only a labelled chip gets the capsule.
            if !emojiOnly {
                Capsule().fill(selected ? Theme.accent : Color.white.opacity(0.12))
            }
        }
        .foregroundStyle(selected ? Color.white : Color.primary)
        .accessibilityLabel(collection.name)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var sortButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                library.sortCollectionsAlphabetically()
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 10)
                .frame(height: chipHeight)
                .background(Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .help("Sort collections A→Z")
        .accessibilityLabel("Sort collections alphabetically")
    }

    private var addButton: some View {
        Button(action: beginCreate) {
            Image(systemName: "plus")
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 10)
                .frame(height: chipHeight)
                .background(Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isEditing)
        .help("New collection")
        .accessibilityLabel("New collection")
    }

    // MARK: Editor

    private var editor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                TextField("Collection name", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .frame(maxWidth: 180)
                    .focused($nameFocused)
                    .onSubmit { if isDraftValid { commit() } }
                    .onExitCommand(perform: cancelEditing)
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
                Button("Cancel", action: cancelEditing)
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
        // Toggle false → true across a runloop tick: assigning true when it's
        // already true is a no-op, so a second create/edit wouldn't focus. Same fix
        // the search field uses (MenuContentView.focusSearchSoon).
        .onAppear {
            nameFocused = false
            DispatchQueue.main.async { nameFocused = true }
        }
        // Restore the popover's transient auto-close once the editor goes away —
        // it's suspended while the emoji picker is open (see EmojiField).
        .onDisappear {
            NotificationCenter.default.post(name: .quipResumePopoverAutoClose, object: nil)
        }
    }

    // MARK: Reorder drag

    private func collectionProvider(_ id: String) -> NSItemProvider {
        let provider = NSItemProvider()
        // The id rides as an own-process payload only to advertise the type; the
        // actual moving chip is read from `draggingID` (own-process data is stripped
        // on drop — see DragContext).
        provider.registerDataRepresentation(
            forTypeIdentifier: QuipDragType.collectionRef.identifier, visibility: .ownProcess
        ) { completion in
            completion(Data(id.utf8), nil)
            return nil
        }
        return provider
    }

    /// Per-chip `isTargeted` binding: writing records which chip a drag is over, so
    /// only one highlights at a time. The `false` write only clears the slot when
    /// this chip owns it — otherwise a stray `exit(A)` after `enter(B)` wipes B.
    private func targetBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { activeTargetID == id },
            set: { isOver in
                if isOver { activeTargetID = id }
                else if activeTargetID == id { activeTargetID = nil }
            }
        )
    }

    @MainActor private func performReorder(onto targetID: String) -> Bool {
        defer { draggingID = nil; activeTargetID = nil }
        guard let dragging = draggingID, dragging != targetID,
              library.collections.contains(where: { $0.id == targetID }) else {
            return false
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            library.moveCollection(dragging, adjacentTo: targetID)
        }
        return true
    }

    // MARK: GIF filing drop

    /// Files the currently-dragged GIF into a tag. The GIF comes from `DragContext`
    /// (the drop provider arrives empty — see `DragContext`), and the `gifRef`
    /// acceptance type already gated this to Quip's own drags. Filing a
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

    // MARK: Create / edit / delete

    private func beginCreate() {
        editingID = nil
        draftName = ""
        draftEmoji = ""
        draftShowsName = true
        creating = true
    }

    private func beginEdit(_ collection: GifCollection) {
        creating = false
        draftName = collection.name
        draftEmoji = collection.emoji ?? ""
        draftShowsName = collection.showsName
        editingID = collection.id
    }

    private func commit() {
        guard isDraftValid else { return }
        let emoji = draftEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        if creating {
            if let created = library.createCollection(
                named: draftName, emoji: emoji, showsName: draftShowsName
            ) {
                selectedID = created.id
            }
        } else if let id = editingID {
            library.updateCollection(id, name: draftName, emoji: emoji, showsName: draftShowsName)
        }
        cancelEditing()
    }

    private func delete(_ collection: GifCollection) {
        if selectedID == collection.id { selectedID = nil }
        if editingID == collection.id { cancelEditing() }
        library.deleteCollection(collection.id)
    }

    private func cancelEditing() {
        creating = false
        editingID = nil
        draftName = ""
        draftEmoji = ""
        draftShowsName = true
    }
}

private extension View {
    /// Dock-style hover cue for a category chip: a gentle magnify plus a clear
    /// accent halo. Two stacked shadows make the glow read on the dark surface — a
    /// tight bright core and a wider soft bloom — and the chip is lifted above its
    /// neighbours so their capsules don't clip the halo. Everything collapses to
    /// nothing when the chip isn't hovered.
    func hoverEffect(_ active: Bool) -> some View {
        scaleEffect(active ? 1.1 : 1)
            .shadow(color: Theme.accent.opacity(active ? 1 : 0), radius: active ? 4 : 0)
            .shadow(color: Theme.accent.opacity(active ? 0.6 : 0), radius: active ? 7 : 0)
            .zIndex(active ? 1 : 0)
            .animation(.easeOut(duration: 0.16), value: active)
    }
}
