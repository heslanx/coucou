import Foundation

// scripts/konclui/test-agent-rows.sh: Settings → Agents as rows with a popover, and the doors on Active pills
// (App/KoncluiAgentRows.swift). The words a row says for each state, how VoiceOver reads it, which agents show (the rules
// of KoncluiRecognition, unchanged), which agent pills open an install from their hint, and that no agent is left as a
// GroupBox. Pure: the sources are read as text, nothing runs.
@main
enum KoncluiAgentRowsTests {
    static var failures = 0

    static func check(_ label: String, _ ok: Bool) {
        if ok { print("  ✓ \(label)") } else { print("  ✗ \(label)"); failures += 1 }
    }

    static func read(_ path: String) -> String {
        (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
    }

    typealias Rows = KoncluiAgentRows
    typealias Block = KoncluiRecognition.AgentBlock

    static func main() {
        print("Status words — (kind, installed, outdated, needs permission)")
        func words(_ s: Rows.Status) -> String { "\(s.key) | \(s.tone)" }
        check("hooks installed", words(Rows.status(.hooks, installed: true)) == "konclui.agents.hooks.installed | ready")
        check("hooks not installed (the key Active pills used)", words(Rows.status(.hooks, installed: false)) == "Hooks not installed | todo")
        check("hooks installed but outdated needs a look", words(Rows.status(.hooks, installed: true, outdated: true)) == "konclui.agents.hooks.outdated | attention")
        check("outdated hooks that are not installed are just not installed",
              Rows.status(.hooks, installed: false, outdated: true) == Rows.status(.hooks, installed: false))
        check("plugin installed", words(Rows.status(.plugin, installed: true)) == "konclui.agents.plugin.installed | ready")
        check("plugin not installed (the key Active pills used)", words(Rows.status(.plugin, installed: false)) == "Plugin not installed | todo")
        check("a plugin is never outdated or in need of permission",
              Rows.status(.plugin, installed: true, outdated: true, needsPermission: true) == Rows.status(.plugin, installed: true))
        check("a switch that is on", words(Rows.status(.toggle, installed: true)) == "konclui.agents.on | ready")
        check("a switch that is off", words(Rows.status(.toggle, installed: false)) == "konclui.agents.off | todo")
        check("a switch that is on without its permission", words(Rows.status(.toggle, installed: true, needsPermission: true)) == "konclui.agents.needs-permission | attention")
        check("a switch that is off needs no permission", Rows.status(.toggle, installed: false, needsPermission: true) == Rows.status(.toggle, installed: false))
        check("a hooks row never says 'on' or 'plugin'",
              [true, false].allSatisfy { !Rows.status(.hooks, installed: $0).key.contains(".on") && !Rows.status(.hooks, installed: $0).key.contains("plugin") })
        let tones: [Rows.Tone] = [true, false].flatMap { installed in
            [Rows.Kind.hooks, .plugin, .toggle].map { Rows.status($0, installed: installed).tone }
        }
        check("done is ready and not done is todo, in every kind", tones == [.ready, .ready, .ready, .todo, .todo, .todo])

        print("Catalog — every key a row can say, in Koncluí's 16 languages (Coucou's own keys may have more)")
        let catalogPath = "NotchBuddy/Resources/Localizable.xcstrings"
        let catalog = (try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: catalogPath)))) as? [String: Any]
        let strings = catalog?["strings"] as? [String: [String: Any]] ?? [:]
        let languages = ["ar", "bn", "de", "en", "es", "fr", "hi", "id", "ja", "ko", "pt-BR", "ru", "th", "tr", "zh-Hans", "zh-Hant"]
        func languagesOf(_ key: String) -> Set<String> {
            Set((strings[key]?["localizations"] as? [String: Any] ?? [:]).keys)
        }
        let keys = Set([true, false].flatMap { installed in
            [Rows.Kind.hooks, .plugin, .toggle].flatMap { kind in
                [Rows.status(kind, installed: installed), Rows.status(kind, installed: installed, outdated: true, needsPermission: true)].map(\.key)
            }
        }).union(["konclui.agents.row.hint", "konclui.agents.door.hooks %@", "konclui.agents.door.plugin %@", "konclui.agents.door.hint %@",
                  Rows.checking.key])
        for key in keys.sorted() {
            check("\(key)", languagesOf(key).isSuperset(of: languages))
        }
        let dashed = keys.filter { key in
            (strings[key]?["localizations"] as? [String: [String: [String: String]]] ?? [:]).values
                .contains { ($0["stringUnit"]?["value"] ?? "").contains("—") || ($0["stringUnit"]?["value"] ?? "").contains("–") }
        }
        check("no dash in a row's words (UX.md, microcopy)", dashed.isEmpty)
        check("the door strings keep their one %@",
              ["konclui.agents.door.hooks %@", "konclui.agents.door.plugin %@", "konclui.agents.door.hint %@"].allSatisfy { key in
                  languages.allSatisfy { lang in
                      let value = ((strings[key]?["localizations"] as? [String: [String: [String: String]]])?[lang]?["stringUnit"]?["value"]) ?? ""
                      return value.components(separatedBy: "%@").count == 2
                  }
              })

        print("VoiceOver — the name, then the state")
        check("after a change", Rows.spoken(name: "Codex", status: "Hooks instalados") == "Codex, Hooks instalados")
        check("a name with a space", Rows.spoken(name: "Gemini CLI", status: "Hooks not installed") == "Gemini CLI, Hooks not installed")

        print("Which agents show — the rules are KoncluiRecognition's, unchanged")
        func shown(_ block: Block, tools: Set<KoncluiTool> = [], active: Set<Block> = []) -> Bool {
            KoncluiRecognition.agentRecognized(block, tools: tools, active: active)
        }
        check("no agent on a bare Mac", Block.allCases.allSatisfy { !shown($0) })
        check("Codex when its tool is on the Mac", shown(.codex, tools: [.codex]))
        check("Codex when its hooks are installed, tool or not", shown(.codex, active: [.codex]))
        check("another tool does not show Codex", !shown(.codex, tools: [.gemini]))
        check("the plan gauges follow Claude Code or Codex", shown(.plan, tools: [.claudeCode]) && shown(.plan, tools: [.codex]) && !shown(.plan, tools: [.amp]))
        check("every block has a row of its own below", Block.allCases.count == 11)

        print("Doors — the 'not installed' hints of Active pills")
        let doors = PillCatalog.all.compactMap { pill in Rows.door(forPill: pill.id).map { (pill.id, $0) } }
        check("seven pills open an install", doors.count == 7)
        check("Gemini, Antigravity, Codex, Copilot and Muse install hooks",
              doors.filter { $0.1.kind == .hooks }.map(\.0) == ["agent_antigravity", "agent_codex", "agent_gemini", "agent_copilot", "agent_muse"])
        check("OpenCode and Amp install plugins", doors.filter { $0.1.kind == .plugin }.map(\.0) == ["agent_opencode", "agent_amp"])
        check("each door's pill is the pill of its block", doors.allSatisfy { Rows.pill(for: $0.1.block) == $0.0 })
        check("Hermes, Claude Desktop, Orca, Cursor and the main pill have none",
              ["agent_hermes", "agent_claude-desktop", "agent_orca", "agent_cursor", "integration_claude"].allSatisfy { Rows.door(forPill: $0) == nil })
        let settings = read("NotchBuddy/Sources/App/SettingsView.swift")
        check("each door still has its hint line in SettingsView.pillRow, with the words the row uses",
              doors.allSatisfy { id, door in
                  let key = Rows.status(door.kind, installed: false).key
                  return settings.contains("def.id == \"\(id)\"") && settings.contains("{ return String(localized: \"\(key)\") }")
              })

        print("Colour dot")
        let pills = Set(PillCatalog.all.map(\.id))
        check("a block's pill is in the catalog", Block.allCases.compactMap { Rows.pill(for: $0) }.allSatisfy(pills.contains))
        check("Claude Code and the plan gauges have no pill of their own", Rows.pill(for: .claudeCode) == nil && Rows.pill(for: .plan) == nil)
        check("Claude's orange for Claude Code, grey for the plan", Rows.fallbackColor(for: .claudeCode) == "#D97757" && Rows.fallbackColor(for: .plan) == "#8E939C")

        print("DEBUG flag")
        check("an agent id", Rows.debugTarget("codex") == .init(id: "codex", preview: false))
        check("with the preview", Rows.debugTarget("codex:preview") == .init(id: "codex", preview: true))
        check("any other suffix is no preview", Rows.debugTarget("codex:write") == .init(id: "codex", preview: false))
        check("with the removal preview", Rows.debugTarget("codex:remove") == .init(id: "codex", preview: false, removal: true))
        check("a row says it is checking until the first read ends", Rows.checking.key == "konclui.agents.checking" && Rows.checking.tone == .todo)
        check("nothing, or an empty value, is no target", Rows.debugTarget(nil) == nil && Rows.debugTarget("") == nil && Rows.debugTarget(":preview") == nil)
        let view = read("NotchBuddy/Sources/App/KoncluiAgentRow.swift")
        check("the flag is read in DEBUG builds only", view.contains("#if DEBUG\n        KoncluiAgentRows.debugTarget"))

        print("No block is left as a GroupBox (a merge from upstream brings them back)")
        let hooks = read("NotchBuddy/Sources/App/KoncluiKlaudeRow.swift")
        let desktop = read("NotchBuddy/Sources/App/ClaudeDesktopChatWatcher.swift")
        for block in Block.allCases where block != .claudeDesktop {
            check("\(block.rawValue) is a row in SettingsView", settings.contains("koncluiAgentRow(.\(block.rawValue),"))
        }
        check("Claude Desktop chats are a row", desktop.contains("KoncluiAgentRow(id: \"claudeDesktop\""))
        check("klaude is a row", hooks.contains("KoncluiAgentRow(id: \"klaude\""))
        let oldTitles = ["hooks.claude-code.title", "hooks.gemini.title", "hooks.antigravity.title", "hooks.codex.title", "hooks.copilot.title",
                         "hooks.muse.title", "plugin.opencode.title", "plugin.amp.title", "plugin.hermes.title", "plan.title",
                         "hooks.klaude.title", "claude-desktop.chat.title"]
        check("none of their GroupBox titles is left",
              oldTitles.allSatisfy { !(settings + hooks + desktop).contains("GroupBox(String(localized: \"\($0)\"))") })

        if failures == 0 { print("PASS") } else { print("FAIL: \(failures)"); exit(1) }
    }
}
