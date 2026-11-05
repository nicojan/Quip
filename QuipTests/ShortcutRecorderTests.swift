import AppKit
import XCTest
import KeyboardShortcuts
@testable import Quip

/// The Settings recorder must capture a pressed shortcut and save it.
///
/// On macOS 26/27, KeyboardShortcuts 2.x held its key monitor weakly, so the
/// monitor was freed as soon as the autorelease pool drained after the field took
/// focus, and showing the clear button ended the recording the moment it began.
/// The field then looked focused but typed the keys as text, and pressing Delete
/// in it wiped the saved shortcut. Fixed upstream in 3.1.0 (issue #241).
///
/// A test host can't become the active app, so its window is never key and
/// AppKit skips the editing restart that caused the bug; this test can't fail on
/// 2.4.0. It guards the rest: focus, capture and save, end to end.
@MainActor
final class ShortcutRecorderTests: XCTestCase {
    private let shortcutName = KeyboardShortcuts.Name("quipTestRecorder")

    override func tearDown() {
        KeyboardShortcuts.setShortcut(nil, for: shortcutName)
        super.tearDown()
    }

    /// Replacing a shortcut that's already set: the case that failed. With a
    /// shortcut present, focusing the field showed the clear button, and on
    /// macOS 26+ that ended the editing session (and the key monitor) at once.
    func testRecorderReplacesExistingShortcut() throws {
        KeyboardShortcuts.setShortcut(.init(.g, modifiers: [.command, .shift]), for: shortcutName)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 80),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let recorder = KeyboardShortcuts.RecorderCocoa(for: shortcutName)
        window.contentView?.addSubview(recorder)
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }

        // Focus the field inside its own pool, as one turn of the event loop
        // would, so anything the recorder only holds weakly is freed here.
        autoreleasepool {
            _ = window.makeFirstResponder(recorder)
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))

        // ⌘⌥K
        let keyDown = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [.command, .option],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber, context: nil,
            characters: "˚", charactersIgnoringModifiers: "k",
            isARepeat: false, keyCode: 40))
        NSApp.postEvent(keyDown, atStart: false)
        // Dequeue through NSApp so local event monitors see the event.
        while let event = NSApp.nextEvent(matching: .any,
                                          until: Date().addingTimeInterval(0.2),
                                          inMode: .default, dequeue: true) {
            NSApp.sendEvent(event)
        }

        XCTAssertEqual(KeyboardShortcuts.getShortcut(for: shortcutName),
                       KeyboardShortcuts.Shortcut(.k, modifiers: [.command, .option]))
    }
}
