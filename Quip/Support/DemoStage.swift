#if DEBUG
import AppKit
import SwiftUI
import SDWebImageSwiftUI

/// Debug-only pieces for the portfolio takes: a fixed-size stage the popover hangs
/// in, a stand-in for a drag image, a loader that copies a snapshot of a real
/// library into the demo suite, and the three portfolio scenes. See Demo/README.md.

/// The GIF the director is "dragging". The stage draws it under the cursor the way
/// the real drag preview looks (small and see-through).
@MainActor
@Observable
final class DemoGhost {
    var gif: Gif?
}

/// Rings drawn over the stage to point at something in a still (stage coordinates).
@MainActor
@Observable
final class DemoCallouts {
    static let shared = DemoCallouts()
    var rects: [CGRect] = []
}

/// A fixed-size window body with the popover pinned to its top edge and centred.
/// The window never changes size, so a recorder locked to it still films the popover
/// growing and shrinking inside it — which a capture of the popover window itself
/// can't follow.
struct DemoStage<Content: View>: View {
    static var size: NSSize { NSSize(width: 1280, height: 800) }

    let background: Color
    let topInset: CGFloat
    let cursor: DemoCursor
    let ghost: DemoGhost
    let callouts: DemoCallouts
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .top) {
            background
            content
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
                // The shadow is drawn by a plain shape behind the popover, not by the
                // popover itself, so SwiftUI doesn't shadow every GIF layer inside it.
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.surface)
                        // Kept inside the 50-pt margin below the popover, so it fades out
                        // before the frame's edge instead of being cut off by it.
                        .shadow(color: .black.opacity(0.22), radius: 22, y: 8)
                )
                .padding(.top, topInset)
            DemoGhostOverlay(cursor: cursor, ghost: ghost)
            ForEach(Array(callouts.rects.enumerated()), id: \.offset) { _, rect in
                // The pink of Quip's icon gradient: it stands off the dark popover
                // and the GIFs without borrowing a colour the app uses for state.
                RoundedRectangle(cornerRadius: Theme.thumbCorner + 4, style: .continuous)
                    .strokeBorder(Color(demoHex: "DB2777"), lineWidth: 3)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
            }
            DemoCursorOverlay(cursor: cursor, yCorrection: 0)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .ignoresSafeArea()
    }
}

/// Draws the dragged GIF under the cursor, matching `GifThumbnail.dragPreview`.
struct DemoGhostOverlay: View {
    let cursor: DemoCursor
    let ghost: DemoGhost

    var body: some View {
        ZStack {
            if let gif = ghost.gif, let url = URL(string: gif.gifURL) {
                Color.clear
                    .frame(width: 110, height: 74)
                    .overlay { AnimatedImage(url: url).resizable().scaledToFill() }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.thumbCorner))
                    .opacity(0.3)
                    .position(cursor.position)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: cursor.moveDuration), value: cursor.position)
        .animation(.easeOut(duration: 0.15), value: ghost.gif?.id)
        .allowsHitTesting(false)
    }
}

/// Copies a snapshot of a real library into the demo suite. The snapshot is JSON
/// exported from the real defaults (never read live), and each GIF is pointed at a
/// local copy, `<dir>/<id>.gif`; a GIF with no local copy is left out.
enum DemoLibraryImport {
    static let favoritesKey = "favoriteGifs"
    static let recentsKey = "recentGifs"
    static let collectionsKey = "favoriteCollections"
    static let searchesKey = "recentSearches"

    static func load(from dir: URL, into suite: UserDefaults) {
        for key in [favoritesKey, recentsKey] {
            if let data = localized(dir.appendingPathComponent("\(key).json"), gifsIn: dir) {
                suite.set(data, forKey: key)
            }
        }
        if let data = try? Data(contentsOf: dir.appendingPathComponent("\(collectionsKey).json")) {
            suite.set(data, forKey: collectionsKey)
        }
        if let data = try? Data(contentsOf: dir.appendingPathComponent("\(searchesKey).json")),
           let terms = try? JSONDecoder().decode([String].self, from: data) {
            suite.set(terms, forKey: searchesKey)
        }
    }

    /// The GIF records in `file`, re-pointed at their local copies. Works on the raw
    /// JSON so any field this code doesn't know about passes through untouched.
    private static func localized(_ file: URL, gifsIn dir: URL) -> Data? {
        guard let data = try? Data(contentsOf: file),
              let records = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return nil }
        let local: [[String: Any]] = records.compactMap { record in
            guard let id = record["id"] as? String else { return nil }
            let gif = dir.appendingPathComponent("\(id).gif")
            guard FileManager.default.fileExists(atPath: gif.path) else { return nil }
            return record.merging(["gifURL": gif.absoluteString,
                                   "previewURL": gif.absoluteString]) { _, new in new }
        }
        return try? JSONSerialization.data(withJSONObject: local)
    }
}

/// Shows the demo content in a real NSPopover hung under a stand-in for the
/// menu-bar icon at the top centre of the Retina display (the real icon may be
/// hidden by a menu-bar manager), wired to `PopoverMorpher` exactly as AppDelegate
/// wires it. For checking the morph in a real popover window.
@MainActor
enum DemoPopover {
    private static var popover: NSPopover?
    private static var morpher: PopoverMorpher?

    /// Returns the stand-in icon's window, which anchors the popover.
    static func show<Content: View>(_ content: Content, size: NSSize, screenHeight: CGFloat) -> NSWindow {
        let screen = NSScreen.screens.max(by: { $0.backingScaleFactor < $1.backingScaleFactor }) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 875)
        let anchor = NSWindow(contentRect: NSRect(x: visible.midX - 11, y: visible.maxY - 22, width: 22, height: 22),
                              styleMask: .borderless, backing: .buffered, defer: false)
        anchor.isOpaque = false
        anchor.backgroundColor = .clear
        anchor.ignoresMouseEvents = true
        anchor.level = .statusBar
        anchor.isReleasedWhenClosed = false
        anchor.orderFrontRegardless()

        let popover = NSPopover()
        popover.behavior = .applicationDefined
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentSize = size
        popover.contentViewController = PopoverMorpher.host(content)
        popover.show(relativeTo: anchor.contentView!.bounds, of: anchor.contentView!, preferredEdge: .minY)
        let morpher = PopoverMorpher(popover: popover)
        NotificationCenter.default.addObserver(forName: .quipLayoutModeChanged, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                let mode = LayoutMode(rawValue: DemoHarness.suite.string(forKey: "layoutMode") ?? "") ?? .narrow
                morpher.resize(to: NSSize(width: mode.width, height: mode.height(forScreenHeight: screenHeight)),
                               animated: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
            }
        }
        self.popover = popover
        self.morpher = morpher
        if let window = popover.contentViewController?.view.window {
            print("DEMO_POPOVER_WINDOW_ID=\(window.windowNumber)")
            print("DEMO_POPOVER_FRAME=\(NSStringFromRect(window.frame))")
            print("DEMO_SCREEN_FRAME=\(NSStringFromRect(screen?.frame ?? .zero))")
        }
        print("DEMO_WINDOW_ID=\(anchor.windowNumber)")
        fflush(stdout)
        return anchor
    }
}

// MARK: - Portfolio scenes

extension DemoDirector {
    /// Centre of a view registered with `demoAnchor`, in stage coordinates.
    static func anchor(_ key: String) -> CGPoint? {
        DemoAnchors.shared.frame(key).map { CGPoint(x: $0.midX, y: $0.midY) }
    }

    /// Marks one GIF as under the pointer (shows its copy hint), or none.
    static func hover(_ gifID: String?) {
        NotificationCenter.default.post(name: .quipDemoHover, object: gifID)
    }

    /// The collection a scene works with, by name (`QUIP_DEMO_COLLECTION`), falling
    /// back to the first one.
    static var featuredCollection: GifCollection? {
        let name = ProcessInfo.processInfo.environment["QUIP_DEMO_COLLECTION"] ?? ""
        return library.collections.first { $0.name == name } ?? library.collections.first
    }

    /// Collections: the payoff first (a tap narrows favourites to one group), then
    /// how a GIF gets there (dragged from search onto the chip, saved and filed in
    /// one drop), then the group again with the new GIF in it.
    static func portfolioCollectionsScene() async {
        guard let group = featuredCollection else { return }
        let query = ProcessInfo.processInfo.environment["QUIP_DEMO_QUERY"] ?? group.name
        await pause(900)

        if let chip = anchor("chip:\(group.id)") {
            await click(chip)
            select(group.id)
        }
        await pause(1500)

        // The field already has focus (it takes it whenever Quip opens), so the
        // typing starts straight away.
        await type(query, perCharMs: 75)
        await pause(1200)

        // A result that isn't in the group yet, so the drop visibly adds one: the
        // QUIP_DEMO_INDEX-th such result (default the second — hovering the first
        // "shocked" result, bGPTxLislwm3u, sends the harness window into an AppKit
        // layout loop that crashes it; not yet checked in the real app).
        let candidates = vm.results.filter { !group.gifIDs.contains($0.id) }
        let wanted = Int(ProcessInfo.processInfo.environment["QUIP_DEMO_INDEX"] ?? "") ?? 1
        guard !candidates.isEmpty else { return }
        let gif = candidates[min(wanted, candidates.count - 1)]
        guard let cell = anchor("result:\(gif.id)") else { return }
        await move(to: cell)
        hover(gif.id)
        await pause(350)

        // Pick it up: the drawer opens to every chip with its drop prompt.
        cursor.pressed = true
        dragContext.gif = gif
        ghost.gif = gif
        hover(nil)
        await pause(450)

        if let chip = anchor("chip:\(group.id)") {
            await move(to: chip, settleMs: 900, duration: 0.9)
            NotificationCenter.default.post(name: .quipDemoDragTarget, object: group.id)
            await pause(350)
        }
        cursor.pressed = false
        ghost.gif = nil
        NotificationCenter.default.post(name: .quipDemoDrop, object: group.id)
        await pause(1500)   // the chip flashes and "Added to …" shows

        // Back home: the group, still selected, now leads with the new GIF.
        // Press the field's clear button (the ⓧ at its trailing edge).
        if let field = DemoAnchors.shared.frame("search") {
            await click(CGPoint(x: field.maxX - 17, y: field.midY))
        }
        vm.query = ""
        await pause(300)
        cursor.visible = false
        await pause(1800)
    }

    /// Copy: search, point at a result to show the copy hint, click, "Copied!".
    static func portfolioCopyScene() async {
        let query = ProcessInfo.processInfo.environment["QUIP_DEMO_QUERY"] ?? "celebrate"
        await pause(1200)
        await type(query, perCharMs: 75)   // the field has focus whenever Quip opens
        await pause(1400)

        let wanted = Int(ProcessInfo.processInfo.environment["QUIP_DEMO_INDEX"] ?? "") ?? 1
        let index = min(wanted, max(0, vm.results.count - 1))
        guard vm.results.indices.contains(index) else { return }
        let gif = vm.results[index]
        guard let cell = anchor("result:\(gif.id)") else { return }
        await move(to: cell)
        hover(gif.id)
        await pause(900)
        await click(cell)
        vm.copy(gif, into: library)   // the real copy path, onto the demo pasteboard
        await pause(2100)
        cursor.visible = false
        hover(nil)
        await pause(1300)
    }

    /// Still: no motion, for a screenshot. With QUIP_DEMO_CALLOUTS=scroll it rings
    /// the two cues that replaced the scroll bars: the half-shown GIF at the end of
    /// the first favourites row (more to the side) and the cut-off row at the
    /// bottom of the scroll area (more below).
    static func portfolioStillScene() async {
        await pause(2500)   // everything loads and settles
        if ProcessInfo.processInfo.environment["QUIP_DEMO_CALLOUTS"] == "scroll",
           let footer = DemoAnchors.shared.frame("footer"),
           let field = DemoAnchors.shared.frame("search") {
            let frames = DemoAnchors.shared.frames
            let right = field.maxX             // the search field spans the content width
            let bottom = footer.minY - 10      // where the scroll area stops
            let pad: CGFloat = 4
            // First favourites row: the cell that runs past the right edge.
            let favs = frames.filter { $0.key.hasPrefix("fav:") }.map(\.value)
            let firstRow = favs.map(\.minY).min()
            if let cut = favs.filter({ $0.minY == firstRow && $0.maxX > right + 1 })
                .min(by: { $0.minX < $1.minX }) {
                DemoCallouts.shared.rects.append(
                    CGRect(x: cut.minX - pad, y: cut.minY - pad,
                           width: right - cut.minX + 2 * pad, height: cut.height + 2 * pad))
            }
            // The row the bottom of the scroll area slices through.
            let sliced = frames.filter { $0.value.minY < bottom && $0.value.maxY > bottom + 1 }
                .map(\.value).filter { $0.minX < right }
            if let minX = sliced.map(\.minX).min(), let minY = sliced.map(\.minY).min() {
                let maxX = min(right, sliced.map(\.maxX).max() ?? right)
                DemoCallouts.shared.rects.append(
                    CGRect(x: minX - pad, y: minY - pad,
                           width: maxX - minX + 2 * pad, height: bottom - minY + 2 * pad))
            }
        }
        await pause(800)
        print("STILL_READY"); fflush(stdout)
        await pause(60_000)   // hold until the recorder quits the app
    }

    /// Sizes: two, three and five GIFs per row, all the same height, switched live
    /// with the toggle, ending where it started so the clip loops.
    static func portfolioLayoutScene() async {
        await pause(1300)
        for mode in [LayoutMode.tall, .wide, .narrow] {
            guard let toggle = DemoAnchors.shared.frame("layout") else { return }
            let segment = toggle.width / 3
            let index = CGFloat([LayoutMode.narrow, .tall, .wide].firstIndex(of: mode) ?? 0)
            await click(CGPoint(x: toggle.minX + segment * (index + 0.5), y: toggle.midY))
            NotificationCenter.default.post(name: .quipDemoSetLayout, object: mode.rawValue)
            // The narrow popover shrinks out from under the pointer, which would be
            // left floating on the backdrop, so it fades out with that last click.
            if mode == .narrow { cursor.visible = false }
            await pause(mode == .narrow ? 2000 : 2300)
        }
    }
}
#endif
