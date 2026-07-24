import SwiftUI
import UniformTypeIdentifiers

/// The collection ("tag") drawer that sits above the scrolling GIF grid, so any
/// GIF — a search result, trending, a favourite — can be dragged onto a chip to
/// favourite and file it in one motion.
///
/// Two states, driven by whether a GIF drag is in flight (`DragContext.isDragging`):
/// - **Collapsed** (idle, home only): one sideways-scrolling row of compact pills,
///   still tappable to filter favourites.
/// - **Expanded** (a drag is in flight, or the create/edit editor is open): the
///   pills wrap to full height with roomier drop targets under a "Drop into a
///   collection" prompt. In search the drawer is absent until a drag, then slides in.
///
/// Drop targets: a collection chip files + auto-favourites (via `GifLibrary`); the
/// `All` chip favourites without filing; `＋` opens the editor with the GIF pending
/// and files it into the collection you create. Each drop reports through `onFiled`
/// so the host can show a brief confirmation — the only "it worked" cue in search,
/// where nothing else on screen changes.
struct FilingDrawer: View {
    enum Role { case home, search }

    @Environment(GifLibrary.self) private var library
    @Environment(DragContext.self) private var dragContext
    @Binding var selectedID: String?
    let role: Role
    /// Reports a successful drop so the host can confirm it. The argument is the
    /// destination's name ("Favorites" for the `All` chip, else the collection's).
    let onFiled: (String) -> Void
    /// Home only: true while the favourites section is scrolled into view. When true
    /// the idle pills wrap to full rows (nothing hidden); once favourites scrolls off,
    /// they collapse to the compact sideways-scrolling row to save height.
    var favoritesInView = true

    // Inline editor state (create or edit).
    @State private var creating = false
    @State private var editingID: String?
    /// A GIF dropped onto `＋`, waiting to be filed into the collection the editor
    /// creates. Captured before the drag clears, so the commit can still read it.
    @State private var pendingGif: Gif?

    /// The chip a drag is currently over (filing highlight or reorder target).
    @State private var activeTargetID: String?
    /// The chip being dragged to reorder; nil when no reorder drag is in flight.
    @State private var draggingID: String?
    /// The chip to pulse briefly after a successful drop — the "it worked" cue for a
    /// chip that stays on screen (the toast covers the search case). The generation
    /// token lets only the latest pulse's timer clear it, so two quick drops on the
    /// same chip don't cut the second pulse short.
    @State private var flashID: String?
    @State private var flashGeneration = 0
    /// The chip under the pointer, for the accent hover glow.
    @State private var hoveredID: String?

    private let allID = "__all__"
    private let addID = "__add__"
    private let chipHeight: CGFloat = 30

    private var isEditing: Bool { creating || editingID != nil }
    /// Expanded whenever a GIF is being dragged, or the editor is open (the editor
    /// must stay up after a ＋-drop even though that drop ended the drag).
    private var expanded: Bool { dragContext.isDragging || isEditing }
    /// Whether a collapsed (non-flow) pill strip should show. Home: once there are
    /// favourites to organize. Search: always — a search result can only be dragged
    /// onto a pill that's already on screen (a strip revealed mid-drag doesn't render
    /// reliably during the drag), so the pills stay visible as a ready drop target.
    private var collapsedVisible: Bool {
        switch role {
        case .home: return !library.favorites.isEmpty
        case .search: return true
        }
    }
    private var showSort: Bool { library.collections.count >= 2 }

    /// Selection only means something in home, where it scopes the favourites grid.
    /// In search the pills are drop-only, so nothing reads as selected and a tap does
    /// nothing.
    private func isSelected(_ id: String?) -> Bool {
        role == .home && selectedID == id
    }

    /// Wrap the pills to full rows while a drag/editor is up, or (in home) while the
    /// favourites section is in view — otherwise use the compact sideways-scrolling row.
    private var useFlowLayout: Bool {
        expanded || (collapsedVisible && role == .home && favoritesInView)
    }

    var body: some View {
        content
            .animation(.easeOut(duration: 0.18), value: expanded)
            .animation(.easeOut(duration: 0.18), value: favoritesInView)
            // A half-typed create/edit — and a stale reorder drag — shouldn't survive
            // a close/reopen.
            .onReceive(NotificationCenter.default.publisher(for: .quipPopoverShown)) { _ in
                cancelEditing()
                draggingID = nil
            }
    }

    @ViewBuilder private var content: some View {
        if useFlowLayout {
            flowPanel
                .transition(
                    role == .search
                        ? .move(edge: .top).combined(with: .opacity)
                        : .opacity
                )
        } else if collapsedVisible {
            compactRow
                .transition(.opacity)
        }
    }

    // MARK: Layouts

    /// Home, idle and scrolled past favourites: All on the left, chips scrolling
    /// sideways in the middle, sort and ＋ pinned on the right. Tappable to filter; a
    /// drag (or scrolling back to favourites) switches to `flowPanel`.
    private var compactRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                allChip
                if !library.collections.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(library.collections) { collectionChip($0) }
                        }
                        .padding(.vertical, 6)   // room for the hover magnify
                        .padding(.horizontal, 2)
                        .hideScrollers()
                    }
                    .scrollIndicators(.hidden)
                }
                Spacer(minLength: 6)
                if showSort { sortButton }
                addButton
            }
            .padding(.horizontal, 8)
            drawerDivider
        }
    }

    /// Pills wrapped to full rows — nothing hidden. Used while a drag/editor is up and
    /// (in home) while favourites are in view. The "Drop into a collection" prompt
    /// shows only during a drag; the sort button only when not dragging (it's not a
    /// drop target); the editor, when open, sits below.
    private var flowPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if dragContext.isDragging {
                Text("Drop into a collection")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            }
            FlowLayout(spacing: 12, lineSpacing: 10) {
                allChip
                ForEach(library.collections) { collectionChip($0) }
                if showSort && !dragContext.isDragging { sortButton }
                addButton
            }
            .padding(.vertical, 6)   // room for the hover magnify + glow
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            if isEditing {
                CollectionChipEditor(
                    creating: creating,
                    name: editingCollection?.name ?? "",
                    emoji: editingCollection?.emoji ?? "",
                    showsName: editingCollection?.showsName ?? true,
                    onCommit: commit,
                    onCancel: cancelEditor
                )
                .padding(.horizontal, 8)
            }
            drawerDivider
        }
    }

    private var drawerDivider: some View {
        Rectangle()
            .fill(Theme.cardStroke)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    // MARK: Chips

    private var allChip: some View {
        let selected = isSelected(nil)
        let isFiling = activeTargetID == allID && dragContext.gif != nil
        return Button { if role == .home { selectedID = nil } } label: {
            Text("All").lineLimit(1).fixedSize()
        }
        .buttonStyle(.plain)
        .font(.footnote.weight(.medium))
        .padding(.horizontal, 12)
        .frame(height: chipHeight)
        .background(selected ? Theme.accent : Color.white.opacity(0.12), in: Capsule())
        .foregroundStyle(selected ? Color.white : Color.primary)
        .overlay(fileHighlight(active: isFiling || flashID == allID))
        .scaleEffect(isFiling ? 1.15 : 1)
        .hoverGlow(hoveredID == allID)
        .onHover { setHover(allID, $0) }
        .animation(.easeOut(duration: 0.12), value: activeTargetID)
        .animation(.easeOut(duration: 0.15), value: flashID)
        .onDrop(of: [QuipDragType.gifRef], isTargeted: targetBinding(allID)) { _ in
            favouriteOnly()
        }
        .help("Drag a GIF here to save it")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func collectionChip(_ collection: GifCollection) -> some View {
        let id = collection.id
        let isFiling = activeTargetID == id && dragContext.gif != nil
        // A GIF filing drag is never a reorder, so don't paint the reorder border
        // during one — guards against a stale `draggingID` from a reorder that ended
        // without landing on a chip.
        let isReorderTarget = activeTargetID == id && draggingID != nil
            && draggingID != id && dragContext.gif == nil
        return chipButton(collection)
            .overlay(fileHighlight(active: isFiling || flashID == id))
            .overlay(
                Capsule()
                    .strokeBorder(Theme.accentText, lineWidth: 2)
                    .opacity(isReorderTarget ? 1 : 0)
                    .allowsHitTesting(false)
            )
            .scaleEffect(isFiling ? 1.15 : 1)
            .hoverGlow(hoveredID == id)
            .onHover { setHover(id, $0) }
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
                // A GIF drag carries `dragContext.gif`; a reorder never does — so its
                // presence tells the two drop kinds apart.
                if dragContext.gif != nil { return fileIntoCollection(id) }
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
        let emojiOnly = hasEmoji && !showName
        let selected = isSelected(collection.id)
        return Button { if role == .home { selectedID = collection.id } } label: {
            HStack(spacing: 4) {
                if hasEmoji {
                    Text(collection.emoji ?? "")
                        .font(emojiOnly ? .title2 : .footnote.weight(.medium))
                        .opacity(emojiOnly && role == .home && selectedID != nil && !selected ? 0.5 : 1)
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
        let isFiling = activeTargetID == addID && dragContext.gif != nil
        return Button(action: beginCreate) {
            Image(systemName: "plus")
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 10)
                .frame(height: chipHeight)
                .background(Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isEditing)
        .overlay(fileHighlight(active: isFiling))
        .scaleEffect(isFiling ? 1.15 : 1)
        .animation(.easeOut(duration: 0.12), value: activeTargetID)
        .onDrop(of: [QuipDragType.gifRef], isTargeted: targetBinding(addID)) { _ in
            beginCreateFromDrag()
        }
        .help("New collection, or drag a GIF here to start one")
        .accessibilityLabel("New collection")
    }

    /// The accent capsule shown while a GIF hovers a drop target, and pulsed briefly
    /// after a drop lands.
    private func fileHighlight(active: Bool) -> some View {
        Capsule()
            .fill(Theme.accent.opacity(0.35))
            .overlay(Capsule().strokeBorder(Theme.accent, lineWidth: 2.5))
            .opacity(active ? 1 : 0)
            .allowsHitTesting(false)
    }

    // MARK: Hover / target tracking

    /// Records which chip the pointer is over, clearing the slot only when this chip
    /// owns it — so a stray exit after another chip's enter can't wipe the new one.
    private func setHover(_ id: String, _ hovering: Bool) {
        if hovering { hoveredID = id }
        else if hoveredID == id { hoveredID = nil }
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

    // MARK: Drops

    /// Files the dragged GIF into a collection (auto-favouriting it), then confirms.
    @MainActor private func fileIntoCollection(_ id: String) -> Bool {
        guard let gif = dragContext.gif,
              let name = library.collections.first(where: { $0.id == id })?.name else { return false }
        library.setMembership(gif, inCollection: id, member: true)
        dragContext.gif = nil
        flash(id)
        onFiled(name)
        return true
    }

    /// Favourites the dragged GIF without filing it — the "just save it" drop on `All`.
    @MainActor private func favouriteOnly() -> Bool {
        guard let gif = dragContext.gif else { return false }
        if !library.isFavorite(gif) { library.toggleFavorite(gif) }
        dragContext.gif = nil
        flash(allID)
        onFiled("Favorites")
        return true
    }

    /// A GIF dropped on `＋`: favourite it now so it's never lost, hold it, and open
    /// the create editor. It's filed into the collection on Create — but it's already
    /// saved, so cancelling (or hitting the collection cap) can't drop it.
    @MainActor private func beginCreateFromDrag() -> Bool {
        guard !isEditing, let gif = dragContext.gif else { return false }
        if !library.isFavorite(gif) { library.toggleFavorite(gif) }
        pendingGif = gif
        dragContext.gif = nil
        editingID = nil
        creating = true
        return true
    }

    /// Pulses a chip's highlight briefly to confirm a drop landed.
    @MainActor private func flash(_ id: String) {
        flashID = id
        flashGeneration += 1
        let generation = flashGeneration
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            if flashGeneration == generation { flashID = nil }
        }
    }

    // MARK: Reorder

    private func collectionProvider(_ id: String) -> NSItemProvider {
        let provider = NSItemProvider()
        // The id rides as an own-process payload only to advertise the type; the
        // moving chip is read from `draggingID` (own-process data is stripped on drop).
        provider.registerDataRepresentation(
            forTypeIdentifier: QuipDragType.collectionRef.identifier, visibility: .ownProcess
        ) { completion in
            completion(Data(id.utf8), nil)
            return nil
        }
        return provider
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

    // MARK: Create / edit / delete

    private var editingCollection: GifCollection? {
        guard let editingID else { return nil }
        return library.collections.first { $0.id == editingID }
    }

    private func beginCreate() {
        editingID = nil
        pendingGif = nil
        creating = true
    }

    private func beginEdit(_ collection: GifCollection) {
        creating = false
        pendingGif = nil
        editingID = collection.id
    }

    private func commit(name: String, emoji: String, showsName: Bool) {
        if creating {
            if let created = library.createCollection(named: name, emoji: emoji, showsName: showsName) {
                selectedID = created.id
                // A GIF dropped on ＋ waits here to be filed into the new collection.
                if let gif = pendingGif {
                    library.setMembership(gif, inCollection: created.id, member: true)
                    onFiled(created.name)
                }
            } else if pendingGif != nil {
                // Create failed (name invalid, or the 50-collection cap). The GIF is
                // already favourited (beginCreateFromDrag), so nothing is lost — just
                // confirm the save it did get.
                onFiled("Favorites")
            }
        } else if let id = editingID {
            library.updateCollection(id, name: name, emoji: emoji, showsName: showsName)
        }
        cancelEditing()
    }

    private func delete(_ collection: GifCollection) {
        if selectedID == collection.id { selectedID = nil }
        if editingID == collection.id { cancelEditing() }
        library.deleteCollection(collection.id)
    }

    /// The editor's Cancel button. If a GIF was pending from a ＋-drop it's already
    /// favourited, so confirm that save before closing — otherwise the GIF would seem
    /// to vanish (nothing changes on screen in search).
    private func cancelEditor() {
        if pendingGif != nil { onFiled("Favorites") }
        cancelEditing()
    }

    private func cancelEditing() {
        creating = false
        editingID = nil
        pendingGif = nil
    }
}

private extension View {
    /// Dock-style hover cue for a chip: a gentle magnify plus a clear accent halo.
    /// Two stacked shadows make the glow read on the dark surface — a tight bright
    /// core and a wider soft bloom — and the chip is lifted above its neighbours so
    /// their capsules don't clip the halo. Everything collapses to nothing when the
    /// chip isn't hovered.
    func hoverGlow(_ active: Bool) -> some View {
        scaleEffect(active ? 1.1 : 1)
            .shadow(color: Theme.accent.opacity(active ? 1 : 0), radius: active ? 4 : 0)
            .shadow(color: Theme.accent.opacity(active ? 0.6 : 0), radius: active ? 7 : 0)
            .zIndex(active ? 1 : 0)
            .animation(.easeOut(duration: 0.16), value: active)
    }
}
