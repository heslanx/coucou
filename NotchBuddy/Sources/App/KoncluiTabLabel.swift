import Foundation

// Koncluí: the name a tab (aba) of the notch shows. A tab gives its name about 64 pt of 10 pt semibold text beside the
// mini Koru, so a longer name was cut with an ellipsis ("Claude Deskt…"). A name of more than `maxCharacters` gets a short
// form chosen by hand; scripts/konclui/test-tab-label.sh checks that every catalog name fits (docs/konclui/UX.md, "Names").
// Foundation only, so the test compiles it with swiftc alone.
enum KoncluiTabLabel {
    static let maxCharacters = 11

    /// Short forms chosen by hand (owner, 2026-10-30: "Claude Desk").
    static let shortForms: [String: String] = [
        "Claude Desktop": "Claude Desk",
    ]

    static func short(_ name: String) -> String {
        if let form = shortForms[name] { return form }
        guard name.count > maxCharacters else { return name }
        // A name the catalog does not know (an agent that named itself): drop whole words from the end while it is too
        // long, so the tab never shows half a word.
        var words = name.split(separator: " ").map(String.init)
        while words.count > 1, words.joined(separator: " ").count > maxCharacters { words.removeLast() }
        let kept = words.joined(separator: " ")
        return kept.count <= maxCharacters ? kept : String(kept.prefix(maxCharacters))
    }
}
