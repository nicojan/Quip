import XCTest
@testable import Quip

/// Covers the predicate the emoji well uses to decide what the system picker just
/// inserted (`EmojiField`). It regressed once by testing a code-point floor of
/// 0x1F000, which silently rejected every text-default emoji — the picker inserted
/// ❤️ and the well stayed empty.
final class EmojiGlyphTests: XCTestCase {
    private func first(_ string: String) -> Character {
        Character(string)
    }

    func testAcceptsTextDefaultEmoji() {
        // Emoji_Presentation = No, and all below U+1F000 — the ones the old floor cut.
        for string in ["❤️", "☺️", "✌️", "☀️", "✏️", "✂️", "☎️", "⚠️"] {
            XCTAssertTrue(first(string).isEmojiGlyph, "\(string) should be accepted")
        }
    }

    func testAcceptsEmojiPresentationGlyphs() {
        for string in ["🎉", "🐱", "⭐️", "⚡", "🇨🇦", "👩‍💻"] {
            XCTAssertTrue(first(string).isEmojiGlyph, "\(string) should be accepted")
        }
    }

    func testRejectsASCIIThatUnicodeAlsoFlagsAsEmoji() {
        // Digits, # and * carry Emoji = Yes; a stray keystroke must never fill the well.
        for string in ["0", "1", "9", "#", "*"] {
            XCTAssertFalse(first(string).isEmojiGlyph, "\(string) should be rejected")
        }
    }

    func testRejectsOrdinaryText() {
        for string in ["a", "Z", " ", "é", "—"] {
            XCTAssertFalse(first(string).isEmojiGlyph, "\(string) should be rejected")
        }
    }
}
