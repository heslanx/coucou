import Foundation

// Koncluí runs next to Coucou: its hook test (KoncluiHook.owns) and HookServer's
// removeNbHookEntries, taken from the source by test-hooks.sh, never claim Coucou's entries.

@main
enum KoncluiHookTests {
    static var failures = 0
    static func check(_ name: String, _ ok: Bool) {
        print("  \(ok ? "✓" : "✗") \(name)")
        if !ok { failures += 1 }
    }

    static let koncluiGemini = #"/bin/sh "/Users/me/Library/Application Support/Konclui/nb-hook" --agent gemini SessionStart"#
    static let koncluiAppStore = "/Users/me/.claude/konclui/nb-hook --agent codex Stop"
    static let koncluiStatusLine = #""/Users/me/Library/Application Support/Konclui/nb-hook" --statusline"#
    static let coucouGemini = #"/bin/sh "/Users/me/Library/Application Support/NotchBuddy/nb-hook" --agent gemini SessionStart"#
    static let coucouAppStore = "/Users/me/.claude/coucou/nb-hook --agent codex Stop"

    static func commands(_ groups: [[String: Any]]) -> [String] {
        groups.flatMap { g -> [String] in
            if let c = g["command"] as? String { return [c] }
            return (g["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String }
        }
    }

    static func main() {
        print("Which hook commands are Koncluí's")
        check("GitHub build", KoncluiHook.owns(koncluiGemini))
        check("App Store build", KoncluiHook.owns(koncluiAppStore))
        check("status line", KoncluiHook.owns(koncluiStatusLine))
        check("not Coucou's GitHub build", !KoncluiHook.owns(coucouGemini))
        check("not Coucou's App Store build", !KoncluiHook.owns(coucouAppStore))
        check("not another tool", !KoncluiHook.owns("/usr/local/bin/other-tool"))
        check("not a missing command", !KoncluiHook.owns(nil))

        print("\nInstalling or removing Koncluí's entries keeps Coucou's")
        let groups: [[String: Any]] = [
            ["matcher": "", "hooks": [["type": "command", "command": coucouGemini],
                                      ["type": "command", "command": koncluiGemini]]],
            ["command": koncluiAppStore],
            ["command": coucouAppStore],
            ["hooks": [["type": "command", "command": koncluiGemini]]],
            ["hooks": [["type": "command", "command": "/usr/local/bin/other-tool"]]],
        ]
        let cleaned = removeNbHookEntries(from: groups)
        let left = commands(cleaned)
        check("Koncluí's entries removed", !left.contains(where: KoncluiHook.owns))
        check("Coucou's entries kept", left.filter { $0 == coucouGemini || $0 == coucouAppStore }.count == 2)
        check("other tools kept", left.contains("/usr/local/bin/other-tool"))
        check("groups left empty dropped, others kept", cleaned.count == 3)
        let reinstalled = cleaned + [["hooks": [["type": "command", "command": koncluiGemini]]]]
        let twice = removeNbHookEntries(from: reinstalled) + [["hooks": [["type": "command", "command": koncluiGemini]]]]
        check("reinstalling keeps one Koncluí entry", commands(twice).filter(KoncluiHook.owns).count == 1)

        if failures > 0 { print("\n\(failures) failure(s)"); exit(1) }
        print("\nKoncluí hooks: all checks passed")
    }
}
