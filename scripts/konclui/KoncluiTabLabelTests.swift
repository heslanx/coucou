import AppKit

// scripts/konclui/test-tab-label.sh: every name a notch tab can show fits in KoncluiTabLabel.maxCharacters.
@main
struct KoncluiTabLabelTests {
    static func main() {
        var failures = 0
        func check(_ ok: Bool, _ what: String) {
            if !ok { failures += 1; print("FAIL \(what)") }
        }

        // The catalog's names, and the names ClaudeHost gives the VS Code / terminal pill.
        let names = PillCatalog.all.map(\.name) + ["VS Code", "Claude Code"]
        for name in names {
            let label = KoncluiTabLabel.short(name)
            check(label.count <= KoncluiTabLabel.maxCharacters, "\"\(name)\" shows \"\(label)\" (\(label.count) characters)")
            // Characters are a proxy: the tab's real limit is its width. "Claude Code" (63.9 pt) is the widest name known to fit.
            let width = (label as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 10, weight: .semibold)]).width
            check(width <= 64, "\"\(label)\" is \(width) pt wide, more than the 64 pt a tab gives its name")
            if name.count <= KoncluiTabLabel.maxCharacters { check(label == name, "\"\(name)\" fits but became \"\(label)\"") }
        }

        // The owner's short form.
        check(KoncluiTabLabel.short("Claude Desktop") == "Claude Desk", "Claude Desktop -> Claude Desk")
        // Every hand-picked short form fits, and only long names have one.
        for (name, form) in KoncluiTabLabel.shortForms {
            check(form.count <= KoncluiTabLabel.maxCharacters, "short form \"\(form)\" is too long")
            check(name.count > KoncluiTabLabel.maxCharacters, "\"\(name)\" fits already and needs no short form")
        }
        // A name the catalog does not know loses whole words, never half of one.
        check(KoncluiTabLabel.short("My Custom Agent Tool") == "My Custom", "unknown long name keeps whole words")
        check(KoncluiTabLabel.short("Supercalifragilistic") == "Supercalifr", "one long word is cut at the limit")
        check(KoncluiTabLabel.short("") == "", "empty stays empty")

        print(failures == 0 ? "PASS tab labels (\(names.count) names)" : "\(failures) failure(s)")
        exit(failures == 0 ? 0 : 1)
    }
}
