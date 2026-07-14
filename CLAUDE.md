# Quip — Project Instructions

## User-facing copy must read as human-written

Every word a user can see must meet **both** standards below before it ships. This
covers the changelog (`CHANGELOG.md`), Sparkle release notes and appcast
descriptions, the README, in-app strings and error messages, and marketing text.
Quip ships direct-download only (Developer ID-signed, notarized), not on the Mac
App Store.

1. **mcp-humanizer rules.** Draft the copy, run `humanizer_check_text` on it,
   resolve every finding, and re-run until `prohibitions_clear` is true — then
   self-attest the manual-review items. Reading the rules alone leaves about half
   the violations in place; the check→fix loop is what carries it.

2. **Orwell's six rules** (*Politics and the English Language*):
   - Never use a metaphor, simile, or figure of speech you are used to seeing in print.
   - Never use a long word where a short one will do.
   - If it is possible to cut a word out, cut it out.
   - Never use the passive where you can use the active.
   - Never use a foreign phrase, a scientific word, or a jargon word if an everyday
     English equivalent exists.
   - Break any of these rules sooner than say anything outright barbarous.

Apply this at commit time and at update/release time — do not commit or cut a
release with user-facing copy that hasn't passed both.
