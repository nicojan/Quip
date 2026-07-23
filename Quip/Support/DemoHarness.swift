#if DEBUG
import AppKit
import SwiftUI
import SDWebImage

/// Debug-only demo harness for recording feature clips. Launched by setting the
/// `QUIP_DEMO=1` environment variable (see `AppDelegate`). Instead of the
/// menu-bar popover it opens a normal, focusable window hosting the *real*
/// `MenuContentView`, fed by bundled GIFs through an isolated `UserDefaults`
/// suite — so it never touches the real library, needs no API key, and makes no
/// network calls. All of this is compiled out of Release builds by `#if DEBUG`.
@MainActor
enum DemoHarness {
    /// Isolated defaults suite. Everything the demo reads or writes — favorites,
    /// collections, recents, layout, the (fake) API key — lives here, never in the
    /// app's real standard defaults. Wiped on each launch for a clean stage.
    static let suiteName = "com.nicojan.Quip.demo"
    static let suite: UserDefaults = {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }()

    /// Retained so the window isn't torn down after `launch` returns.
    private static var window: NSWindow?

    static func launch() {
        // Accessory (not regular): all interaction is programmatic (the director
        // drives state directly), so the window never needs focus — and this keeps
        // it from stealing focus or switching Spaces on whoever's at the machine.
        NSApp.setActivationPolicy(.accessory)

        TempClips.prepare()          // copy writes a temp .gif; give it a home
        GifImageCache.configure()

        // The bundled filenames are stable but their content can change (refreshed
        // from Giphy), so drop any stale disk-cached image keyed by those file URLs.
        // Synchronous (unlike GifImageCache.clear) so it finishes before views load.
        SDImageCache.shared.clearMemory()
        try? FileManager.default.removeItem(atPath: SDImageCache.shared.diskCachePath)

        let assetsDir = ProcessInfo.processInfo.environment["QUIP_DEMO_ASSETS"]
            .map { URL(fileURLWithPath: $0) }
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Demo/assets")

        let source = DemoGifSource(assetsDir: assetsDir)
        let library = GifLibrary(defaults: suite)
        DemoData.seed(into: library, from: source.all)

        // Initial layout preset, set before the view builds so @AppStorage reads it
        // (a runtime change to the suite doesn't reliably propagate; the layout clip
        // is recorded as separate native-size takes instead — see record-layout.sh).
        let initialMode = LayoutMode(
            rawValue: ProcessInfo.processInfo.environment["QUIP_DEMO_LAYOUT"] ?? ""
        ) ?? .tall

        // The API key now lives in the Keychain-backed Credentials store; seed an
        // in-memory one so the demo runs with a non-empty key (search enabled) and
        // never touches the real Keychain.
        let credentials = Credentials(store: InMemorySecretStore([Credentials.account: "demo-key"]))

        // Prefs the real app keeps in @AppStorage, seeded in the isolated suite.
        suite.set(initialMode.rawValue, forKey: "layoutMode")
        suite.set(GiphyClient.defaultRating, forKey: "giphyRating")
        suite.set(false, forKey: "useStickers")

        let vm = SearchViewModel(backend: source, recentSearchDefaults: suite)
        vm.recentSearches = ["celebrate", "thumbs up", "party", "wow"]
        vm.trending = source.all       // fill trending up front so there's no empty flash

        let metrics = LayoutMetrics(launchScreenHeight: 900)   // fixed ⇒ stable `tall` height
        let dragContext = DragContext()

        let cursor = DemoCursor()
        let content = MenuContentView(openSettings: {}, closePopover: {}, viewModel: vm)
            .environment(library)
            .environment(metrics)
            .environment(dragContext)
            .environment(credentials)
            .defaultAppStorage(suite)

        let contentSize = NSSize(width: initialMode.width,
                                 height: initialMode.height(forScreenHeight: 900))
        let root = ZStack(alignment: .topLeading) {
            content
            DemoCursorOverlay(cursor: cursor)
                .frame(width: contentSize.width, height: contentSize.height)
        }

        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Quip"
        // Chrome-less so a recorded clip matches the real menu-bar popover (just the
        // dark content), while a titled window still takes key focus for typing.
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isMovableByWindowBackground = true
        window.setContentSize(
            NSSize(width: initialMode.width,
                   height: initialMode.height(forScreenHeight: 900))
        )
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        // Click-through, so it can never intercept the user's clicks or be
        // accidentally interacted with while recording (capture is by window id).
        window.ignoresMouseEvents = true

        // Pin to the highest-scale (Retina) display so capture is always @2x, not
        // whatever screen happened to be "main" — and to a stable top-left spot.
        let screen = NSScreen.screens.max(by: { $0.backingScaleFactor < $1.backingScaleFactor })
            ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            window.setFrameOrigin(NSPoint(x: visible.minX + 80,
                                          y: visible.maxY - window.frame.height - 40))
        } else {
            window.center()
        }

        // Order front without activating (don't pull focus or switch Spaces).
        window.orderFrontRegardless()
        self.window = window

        // Print the CoreGraphics window id so the recorder can capture this exact
        // window (`screencapture -l<id>`) regardless of Space, occlusion, or focus.
        print("DEMO_WINDOW_ID=\(window.windowNumber)")
        fflush(stdout)

        // If a scene was requested, run the scripted storyboard (see DemoDirector).
        DemoDirector.begin(
            scene: ProcessInfo.processInfo.environment["QUIP_DEMO_SCENE"],
            vm: vm, library: library, window: window, suite: suite, cursor: cursor
        )
    }
}

/// The synthetic pointer drawn over the demo content. The director moves it and
/// fires click ripples; the overlay renders it. Position is in the content's
/// coordinate space (top-left origin), matching the `tall` layout the scenes use.
@MainActor
@Observable
final class DemoCursor {
    var position: CGPoint = CGPoint(x: 220, y: 700)   // starts just below view, glides in
    var visible = false
    /// Bumped once per click; the overlay watches it to fire a ripple.
    var clickCount = 0
}

/// Draws the synthetic cursor — a soft, semi-transparent disc in the style of
/// Apple's accessibility pointer — and its click ripple, on top of the demo
/// content. The disc is centred on `position` (its centre is the hotspot), so
/// waypoints point straight at their targets with no offset.
struct DemoCursorOverlay: View {
    let cursor: DemoCursor
    @State private var rippleScale: CGFloat = 0.4
    @State private var rippleOpacity: Double = 0
    @State private var pressScale: CGFloat = 1

    /// The content is pushed down by the (hidden) title-bar safe area, but this
    /// overlay isn't — so waypoints (measured against the content) render this much
    /// too low without correcting for it.
    private let yCorrection: CGFloat = -30

    var body: some View {
        ZStack {
            // Expanding ring on click.
            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: 2)
                .frame(width: 40, height: 40)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)
            // The translucent disc.
            Circle()
                .fill(Color.white.opacity(0.35))
                .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 1.5))
                .frame(width: 34, height: 34)
                .scaleEffect(pressScale)
                .shadow(color: .black.opacity(0.35), radius: 3)
        }
        .position(x: cursor.position.x, y: cursor.position.y + yCorrection)
        .opacity(cursor.visible ? 1 : 0)
        .animation(.easeInOut(duration: 0.55), value: cursor.position)
        .animation(.easeInOut(duration: 0.3), value: cursor.visible)
        .allowsHitTesting(false)
        .onChange(of: cursor.clickCount) { _, _ in
            pressScale = 0.7
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pressScale = 1 }
            rippleScale = 0.4; rippleOpacity = 0.9
            withAnimation(.easeOut(duration: 0.5)) { rippleScale = 1.7; rippleOpacity = 0 }
        }
    }
}

/// Calibrated tap targets in the `tall` layout's content coordinates (440-pt wide,
/// top-left origin). Everything is deterministic (fixed size + same seed each run),
/// so fixed points land correctly; re-measure if the seed or layout changes.
enum Waypoint {
    static let searchField = CGPoint(x: 200, y: 95)
    static let addCollection = CGPoint(x: 415, y: 193)

    /// Collection chips, left to right after "All". Indices follow `library.collections`.
    static let chipAll = CGPoint(x: 30, y: 193)
    static let chipX: [CGFloat] = [95, 163, 243, 320]   // 1st..4th collection chip
    static func chip(_ index: Int) -> CGPoint {
        CGPoint(x: chipX[min(index, chipX.count - 1)], y: 193)
    }

    /// Grid cell centre. `home` uses the favourites/library grid origin; results use
    /// the higher origin present while a search is active.
    private static let colX: [CGFloat] = [80, 207, 336]
    static func homeCell(_ row: Int, _ col: Int) -> CGPoint {
        CGPoint(x: colX[col], y: 300 + CGFloat(row) * 100)
    }
    static func resultCell(_ row: Int, _ col: Int) -> CGPoint {
        CGPoint(x: colX[col], y: 205 + CGFloat(row) * 100)
    }
    /// The favourite star sits at a cell's top-right corner.
    static func star(of center: CGPoint) -> CGPoint {
        CGPoint(x: center.x + 50, y: center.y - 30)
    }
}

/// Drives a scripted storyboard for one feature ("scene") by mutating the same
/// public view-model / library state a user's taps would — and moving a synthetic
/// cursor with click ripples — so the *real* views animate. Recording is external
/// (`screencapture -v -l<windowid>`); the director only decides what happens and
/// when. Selected by `QUIP_DEMO_SCENE`; it waits for the recorder's go-file
/// (`QUIP_DEMO_GO`) so the take never starts mid-setup.
@MainActor
enum DemoDirector {
    private static var vm: SearchViewModel!
    private static var library: GifLibrary!
    private static weak var window: NSWindow?
    private static var suite: UserDefaults!
    private static var cursor: DemoCursor!

    /// Rough wall-clock length of each scene, so the recorder knows how long to
    /// roll. Printed as `SCENE_DURATION=` at start. Includes the cursor moves.
    private static let durations: [String: Int] = [
        "search": 10, "favorites": 12, "collections": 15, "overview": 9,
    ]

    static func begin(scene: String?, vm: SearchViewModel, library: GifLibrary,
                      window: NSWindow, suite: UserDefaults, cursor: DemoCursor) {
        self.vm = vm; self.library = library; self.window = window
        self.suite = suite; self.cursor = cursor
        guard let scene, !scene.isEmpty else { return }   // no scene ⇒ leave window static

        print("SCENE_DURATION=\(durations[scene] ?? 10)")
        fflush(stdout)

        let goPath = ProcessInfo.processInfo.environment["QUIP_DEMO_GO"]
        Task { @MainActor in
            await waitForGo(path: goPath)
            await run(scene: scene)
            print("SCENE_DONE"); fflush(stdout)
        }
    }

    /// Blocks until the recorder creates the go-file (race-free start), or a short
    /// fallback delay if none was supplied.
    private static func waitForGo(path: String?) async {
        guard let path else { await pause(1000); return }
        for _ in 0..<600 where !FileManager.default.fileExists(atPath: path) {
            await pause(100)
        }
    }

    private static func run(scene: String) async {
        switch scene {
        case "search":      await searchScene()
        case "favorites":   await favoritesScene()
        case "collections": await collectionsScene()
        default:            await overviewScene()
        }
    }

    // MARK: Scenes

    /// Click into the field, type a query, watch suggestions + results populate,
    /// then click a result to copy it (the "Copied!" overlay flashes).
    private static func searchScene() async {
        await pause(500)
        await click(Waypoint.searchField)
        await type("celebrate")
        await pause(2200)                     // results load + settle
        await click(Waypoint.resultCell(0, 0))
        if let first = vm.results.first {
            vm.copy(first, into: library)     // real copy path: overlay + recents
        }
        await pause(2200)
    }

    /// Build favorites from scratch: search, click the star on a few visible cells,
    /// then return home to see them collected in the Favorites strip.
    private static func favoritesScene() async {
        library.clearFavorites()              // start from the empty state
        await pause(500)
        await click(Waypoint.searchField)
        await type("dance")
        await pause(1900)
        let cells = [Waypoint.resultCell(0, 0), Waypoint.resultCell(0, 1),
                     Waypoint.resultCell(0, 2), Waypoint.resultCell(1, 0)]
        for (i, gif) in vm.results.prefix(4).enumerated() {
            await click(Waypoint.star(of: cells[i]))
            library.toggleFavorite(gif)
            await pause(500)
        }
        await pause(900)
        vm.query = ""                         // back to home
        await pause(2400)                     // Favorites strip is now populated
    }

    /// Filter favorites through each collection chip, then create a new collection
    /// and file a GIF into it.
    private static func collectionsScene() async {
        await pause(700)
        for (index, collection) in library.collections.enumerated() {
            await click(Waypoint.chip(index))
            select(collection.id)
            await pause(1300)
        }
        await click(Waypoint.chipAll)
        select(nil)
        await pause(900)
        await click(Waypoint.addCollection)   // "+" to create
        if let wins = library.createCollection(named: "Wins", emoji: "🏆") {
            await pause(1200)
            if let gif = library.favorites.first {
                await click(Waypoint.homeCell(0, 0))   // point at the GIF being filed
                library.setMembership(gif, inCollection: wins.id, member: true)
            }
            await pause(800)
            await click(Waypoint.chip(0))     // new collection lands first — filter to it
            select(wins.id)
            await pause(1800)
        }
    }

    /// Hero clip: hold on the populated home, filter one collection, return to All.
    private static func overviewScene() async {
        await pause(1600)
        if let first = library.collections.first {
            await click(Waypoint.chip(0))
            select(first.id)
            await pause(1900)
        }
        await click(Waypoint.chipAll)
        select(nil)
        await pause(2000)
    }

    // MARK: Helpers

    private static func pause(_ ms: Int) async { try? await Task.sleep(for: .milliseconds(ms)) }

    /// Types into the search field one character at a time (drives the real
    /// live-search via SearchBar's onChange).
    private static func type(_ text: String, perCharMs: Int = 95) async {
        for ch in text {
            vm.query.append(ch)
            await pause(perCharMs)
        }
    }

    /// Glides the synthetic cursor to a point and waits for the move to finish.
    private static func move(to point: CGPoint, settleMs: Int = 650) async {
        cursor.visible = true
        cursor.position = point
        await pause(settleMs)
    }

    /// Glides to a point, then fires a click ripple and pauses briefly.
    private static func click(_ point: CGPoint) async {
        await move(to: point)
        cursor.clickCount += 1
        await pause(400)
    }

    /// Selects a collection chip (nil = "All"). Driven through a DEBUG-only
    /// notification the LibraryView listens for, since the selection is its
    /// private view state.
    private static func select(_ collectionID: String?) {
        NotificationCenter.default.post(name: .quipDemoSelectCollection, object: collectionID)
    }
}

extension Notification.Name {
    /// DEBUG demo: asks LibraryView to select a collection chip (object = id String,
    /// or nil for "All").
    static let quipDemoSelectCollection = Notification.Name("quipDemoSelectCollection")
}

/// Offline `GifBackend` for the demo: serves the bundled GIF files as both search
/// and trending results, with a small delay so loading states still show.
struct DemoGifSource: GifBackend {
    /// Every demo GIF, in a fixed order (drives trending and search results).
    let all: [Gif]
    private let bytesByID: [String: Data]

    /// (file id, display title), ordered so neighbouring cells look distinct.
    static let catalog: [(id: String, title: String)] = [
        ("celebrate", "Celebrate"), ("mind-blown", "Mind Blown"), ("thumbs-up", "Thumbs Up"),
        ("dance", "Dance"), ("wow", "Wow"), ("clapping", "Clapping"),
        ("party", "Party"), ("laughing", "Laughing"), ("high-five", "High Five"),
        ("love", "Love"), ("facepalm", "Facepalm"), ("yes", "Yes"),
    ]

    init(assetsDir: URL) {
        var gifs: [Gif] = []
        var bytes: [String: Data] = [:]
        for entry in Self.catalog {
            let fileURL = assetsDir.appendingPathComponent("\(entry.id).gif")
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
            let urlString = fileURL.absoluteString
            gifs.append(Gif(id: entry.id, gifURL: urlString, previewURL: urlString, title: entry.title))
            bytes[entry.id] = try? Data(contentsOf: fileURL)
        }
        self.all = gifs
        self.bytesByID = bytes
    }

    func search(_ query: String, apiKey: String,
                content: GiphyClient.Content, rating: String) async throws -> [Gif] {
        try? await Task.sleep(for: .milliseconds(450))   // let the spinner breathe
        return all
    }

    func trending(apiKey: String, content: GiphyClient.Content,
                  rating: String) async throws -> [Gif] {
        all
    }

    func autocomplete(_ query: String, apiKey: String) async throws -> [String] {
        try? await Task.sleep(for: .milliseconds(150))
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return [] }
        return ["\(term) reaction", "\(term) meme", "\(term) funny", "\(term) gif"]
    }

    func fetchData(for gif: Gif) async throws -> Data {
        guard let data = bytesByID[gif.id] else { throw GiphyClient.GiphyError.badResponse }
        return data
    }
}

/// Seeds a `GifLibrary` with a believable starting state: some favorites, a few
/// recently-copied, and three emoji collections.
enum DemoData {
    @MainActor
    static func seed(into library: GifLibrary, from all: [Gif]) {
        guard !all.isEmpty else { return }

        // Favorite the first 8 (toggle inserts at front, so reverse to keep order).
        for gif in all.prefix(8).reversed() { library.toggleFavorite(gif) }

        // A short recently-copied strip.
        for gif in all[3..<8].reversed() { library.addRecent(gif) }

        // Emoji collections (setMembership auto-favorites any not already saved).
        if let reactions = library.createCollection(named: "Reactions", emoji: "😂") {
            for gif in all.prefix(4) { library.setMembership(gif, inCollection: reactions.id, member: true) }
        }
        if let party = library.createCollection(named: "Party", emoji: "🎉") {
            for gif in all[2..<6] { library.setMembership(gif, inCollection: party.id, member: true) }
        }
        if let work = library.createCollection(named: "Work", emoji: "💼") {
            for gif in all[5..<8] { library.setMembership(gif, inCollection: work.id, member: true) }
        }
    }
}
#endif
