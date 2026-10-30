import Foundation

// scripts/konclui/test-key-name.sh: no key shows as a speck, and ⌃⌥] and ⌃⌥[ (Next and Previous tab) read differently.
@main
struct KoncluiKeyNameTests {
    static func main() {
        var failures = 0
        func check(_ ok: Bool, _ what: String) {
            if !ok { failures += 1; print("FAIL \(what)") }
        }
        let words: (String) -> String = { "<\($0)>" }

        check(KoncluiKeyName.label(30, word: words) == "]", "key 30 is ]")
        check(KoncluiKeyName.label(33, word: words) == "[", "key 33 is [")
        check(KoncluiKeyName.label(43, word: words) == "<comma>", "the comma is a word")
        check(KoncluiKeyName.label(47, word: words) == "<period>", "the period is a word")
        check(KoncluiKeyName.label(49, word: words) == "<space>", "the space bar is a word")
        check(KoncluiKeyName.label(0, word: words) == "A", "key 0 is A")
        check(KoncluiKeyName.label(29, word: words) == "0", "key 29 is 0")

        // Every ANSI key code the keyboard can send up to 126 has a name that is not the old "·" placeholder.
        var seen: [String: UInt16] = [:]
        for code in UInt16(0)...126 {
            let name = KoncluiKeyName.label(code, word: words)
            check(name != "·" && !name.isEmpty, "key \(code) shows nothing useful")
            if let other = seen[name], !name.hasPrefix("#") { check(false, "keys \(other) and \(code) both read \"\(name)\"") }
            seen[name] = code
        }

        if failures == 0 { print("KoncluiKeyName: all checks passed") }
        exit(failures == 0 ? 0 : 1)
    }
}
