import Foundation

/// How a virtual key code reads on a shortcut's keycap. Upstream's tables stop at letters, digits and a few symbols and show
/// "·" for every other key, so ⌃⌥] and ⌃⌥[ both read "⌃⌥·" (UX.md 1.1: an answer, not a speck). The comma and the period, which
/// look alike at 11 pt, are words; the other punctuation is the glyph printed on the key. Pure: the words come in as a closure.
enum KoncluiKeyName {
    /// The word for a key id ("comma", "period", "space"), in the person's language.
    static func localizedWord(_ id: String) -> String {
        String(localized: String.LocalizationValue("konclui.key." + id))
    }

    /// What goes after the modifier symbols for `code` (ANSI key positions).
    static func label(_ code: UInt16, word: (String) -> String = localizedWord) -> String {
        if let glyph = glyphs[code] { return glyph }
        switch code {
        case 43: return word("comma")
        case 47: return word("period")
        case 49: return word("space")
        default: return "#\(code)"
        }
    }

    private static let glyphs: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E",
        15: "R", 16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
        24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 41: ";", 42: "\\", 44: "/", 50: "`",
        36: "↩", 48: "⇥", 51: "⌫", 53: "⎋", 117: "⌦", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
        103: "F11", 111: "F12",
    ]
}
