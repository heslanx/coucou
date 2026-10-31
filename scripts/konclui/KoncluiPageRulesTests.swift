import Foundation

// scripts/konclui/test-page-rules.sh: the rules of the notch pages (App/KoncluiPageRules.swift, KoncluiHookTargets.swift,
// KoncluiHooksDiff.swift) and the places in the sources that carry them.
@main
enum KoncluiPageRulesTests {
    static var failures = 0

    static func check(_ label: String, _ ok: Bool) {
        if ok { print("  ✓ \(label)") } else { print("  ✗ \(label)"); failures += 1 }
    }

    static func read(_ path: String) -> String {
        (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
    }

    typealias Target = KoncluiHookTarget

    static func main() {
        popoverControls()
        tabLimit()
        generalPage()
        orcaCards()
        targets()
        diffs()
        sources()
        catalog()
        if failures == 0 { print("PASS") } else { print("FAIL: \(failures)"); exit(1) }
    }

    // MARK: An agent's popover

    static func popoverControls() {
        print("Popover — one primary, and only the one the state needs")
        let missing = KoncluiHookActions.controls(installed: false, outdated: false)
        check("not installed: Install is the primary and there is nothing to uninstall", missing.primary == .install && !missing.canUninstall)
        let fine = KoncluiHookActions.controls(installed: true, outdated: false)
        check("installed: no primary, Uninstall is the quiet action", fine.primary == nil && fine.canUninstall)
        let old = KoncluiHookActions.controls(installed: true, outdated: true)
        check("outdated: Update is the primary, Uninstall stays quiet", old.primary == .update && old.canUninstall)
        let phantom = KoncluiHookActions.controls(installed: false, outdated: true)
        check("outdated hooks that are not installed are just not installed", phantom == missing)
    }

    // MARK: The four-tab limit

    static func tabLimit() {
        print("Tab limit — a blocked switch says why and offers a way out")
        check("the limit is 4", KoncluiTabLimit.maximum == 4)
        check("four on, this one off: blocked", KoncluiTabLimit.blocks(activeCount: 4, isOn: false, isMain: false))
        check("three on: not blocked", !KoncluiTabLimit.blocks(activeCount: 3, isOn: false, isMain: false))
        check("a tab that is on can always be turned off", !KoncluiTabLimit.blocks(activeCount: 4, isOn: true, isMain: false))
        check("the main tab is never blocked", !KoncluiTabLimit.blocks(activeCount: 4, isOn: false, isMain: true))
        let order = ["integration_claude", "agent_codex", "agent_gemini", "agent_amp", "ai_ollama"]
        let released = KoncluiTabLimit.releasable(active: ["agent_codex", "agent_amp", "ai_ollama", "agent_gemini", "integration_claude"],
                                                  main: "integration_claude", order: order)
        check("the tabs to turn off exclude the main one, in list order", released == ["agent_codex", "agent_gemini", "agent_amp", "ai_ollama"])
        check("a tab that is not on is not offered", !KoncluiTabLimit.releasable(active: ["agent_codex"], main: "x", order: order).contains("agent_amp"))
    }

    // MARK: Geral

    static func generalPage() {
        print("Geral — the demo steps back, the card appears, the removal waits for something to remove")
        check("nothing connected: the demo stays first", !KoncluiGeneralPage.demoComesLast(anyAgentConnected: false))
        check("an agent connected: the demo goes last", KoncluiGeneralPage.demoComesLast(anyAgentConnected: true))
        check("no card without waiting agents", !KoncluiGeneralPage.showsConnectCard(waiting: []))
        check("a card for waiting agents", KoncluiGeneralPage.showsConnectCard(waiting: [.codex]))
        let many: [Target] = [.klaude, .claudeCode, .codex, .gemini, .antigravity, .copilot]
        check("the card names four agents at most", KoncluiGeneralPage.namesInCard(many) == ["klaude", "Claude Code", "Codex", "Gemini CLI"])
        check("fewer than four are all named", KoncluiGeneralPage.namesInCard([.codex]) == ["Codex"])

        var mac = KoncluiHookSnapshot()
        check("a bare Mac offers no removal", !KoncluiGeneralPage.offersRemoval(mac))
        mac.installed = [.codex, .statusLine]
        check("a Mac with Koncluí's files offers it", KoncluiGeneralPage.offersRemoval(mac))
        check("the status line alone is not an agent", mac.connected == [.codex] && mac.removable.contains(.statusLine))

        var found = KoncluiHookSnapshot()
        found.tools = [.claudeCode, .codex, .orca, .gemini]
        found.klaudeExists = true
        check("agents found and not connected, in the order of the pages", found.waiting == [.klaude, .claudeCode, .codex, .gemini])
        found.installed = [.claudeCode, .klaude]
        check("a connected agent leaves the card", found.waiting == [.codex, .gemini])
        check("Orca is an app, not hooks: it never waits", !found.waiting.contains { $0.name == "Orca" })
        check("a tool that is not on the Mac does not wait", !found.waiting.contains(.amp))
        found.installed = [.claudeCode, .klaude, .codex, .gemini]
        check("everything connected: no card", !KoncluiGeneralPage.showsConnectCard(waiting: found.waiting))
        check("connected is set up", found.anyConnected)
        check("klaude not on the Mac is not waiting", KoncluiHookSnapshot().waiting.isEmpty)
    }

    // MARK: Orca

    static func orcaCards() {
        print("Orca — approvals in the notch ship on for Orca only")
        let suite = "konclui-page-rules-\(ProcessInfo.processInfo.processIdentifier)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        check("on by default", KoncluiOrcaCards.enabled(defaults))
        check("an Orca session shows in the notch by default", KoncluiOrcaCards.showsInNotch(isOrca: true, otherTerminalsOn: false, defaults: defaults))
        check("another terminal does not, by default", !KoncluiOrcaCards.showsInNotch(isOrca: false, otherTerminalsOn: false, defaults: defaults))
        check("the other terminals' own switch still works", KoncluiOrcaCards.showsInNotch(isOrca: false, otherTerminalsOn: true, defaults: defaults))
        defaults.set(false, forKey: KoncluiOrcaCards.key)
        check("turned off, Orca asks in its own terminal", !KoncluiOrcaCards.showsInNotch(isOrca: true, otherTerminalsOn: false, defaults: defaults))
        check("turned off, the other terminals' switch still decides for Orca too", KoncluiOrcaCards.showsInNotch(isOrca: true, otherTerminalsOn: true, defaults: defaults))
        check("the key is Koncluí's own, not the shipped terminal key", KoncluiOrcaCards.key == "konclui.orcaCards")
    }

    // MARK: The files

    static func targets() {
        print("Files — what Koncluí writes, where")
        check("eleven targets: ten agents and the status line", Target.allCases.count == 11 && Target.agents.count == 10)
        check("every path is shown in the home folder's short form", Target.allCases.allSatisfy { $0.shownPath.hasPrefix("~/") })
        let home = URL(fileURLWithPath: "/Users/test")
        check("a path resolves under the home folder", Target.codex.url(home: home).path == "/Users/test/.codex/hooks.json")
        check("klaude has its own config folder", Target.klaude.url(home: home).path == "/Users/test/.klaude/settings.json")
        check("the status line is Claude Code's settings file", Target.statusLine.shownPath == Target.claudeCode.shownPath)
        check("plugins are OpenCode, Amp and Hermes", Set(Target.allCases.filter(\.isPlugin)) == [.opencode, .amp, .hermes])
        check("a block maps to its target", Target(block: .codex) == .codex && Target(block: .claudeCode) == .claudeCode)
        check("Claude Desktop and the plan gauges write no hooks", Target(block: .claudeDesktop) == nil && Target(block: .plan) == nil)
        check("every agent block with hooks has a target", KoncluiRecognition.AgentBlock.allCases.filter { Target(block: $0) != nil }.count == 9)
        check("klaude needs no tool, the status line follows Claude Code", Target.klaude.tool == nil && Target.statusLine.tool == .claudeCode)
        check("no duplicate path between agents (the status line shares Claude Code's)",
              Set(Target.agents.map(\.shownPath)).count == Target.agents.count)
    }

    // MARK: What an install or a removal changes

    static let userHook = #"""
    {
      "hooks": {
        "Stop": [
          { "hooks": [ { "command": "/usr/local/bin/mine --stop", "type": "command" } ] }
        ]
      },
      "theme": "dark"
    }
    """#

    static func koncluiEntry(_ timeout: Int) -> String {
        #"{ "hooks": [ { "command": "\"/Users/x/Library/Application Support/Konclui/nb-hook\"", "timeout": \#(timeout), "type": "command" } ] }"#
    }

    static func settings(stop: [String], theme: Bool = true) -> String {
        let groups = stop.joined(separator: ", ")
        return #"{ "hooks": { "Stop": [ \#(groups) ] }\#(theme ? #", "theme": "dark""# : "") }"#
    }

    static func diffs() {
        print("Diff — only the lines Koncluí adds or removes")
        let mine = #"{ "hooks": [ { "command": "/usr/local/bin/mine --stop", "type": "command" } ] }"#
        let before = settings(stop: [mine])
        let after = settings(stop: [mine, koncluiEntry(10)])
        let install = KoncluiHooksDiff.compute(original: before, pending: after)
        check("installing adds one Koncluí entry", install.summary == .adds(entries: 1))
        check("nothing of the person's is removed", install.removed.isEmpty)
        check("the added lines include the command", install.added.contains { $0.contains("nb-hook") })
        check("only a few lines are added, not the file", install.added.count > 0 && install.added.count < 12)
        check("the person's own hook stays and is counted", install.othersKept == 1)
        check("the whole file is kept for the disclosure", install.whole.contains("mine --stop") && install.whole.contains("nb-hook"))

        let uninstall = KoncluiHooksDiff.compute(original: after, pending: before)
        check("removing takes one Koncluí entry away", uninstall.summary == .removes(entries: 1))
        check("nothing is added by a removal", uninstall.added.isEmpty)

        let reformatted = KoncluiHooksDiff.compute(original: #"{"theme":"dark","hooks":{"Stop":[{"hooks":[{"type":"command","command":"/usr/local/bin/mine --stop"}]}]}}"#,
                                                    pending: after)
        check("a file formatted another way does not read as changed in every line", reformatted.summary == .adds(entries: 1) && reformatted.removed.isEmpty)

        let oldEntry = settings(stop: [mine, koncluiEntry(10)])
        let newEntry = settings(stop: [mine, koncluiEntry(120)])
        let update = KoncluiHooksDiff.compute(original: oldEntry, pending: newEntry)
        check("a changed Koncluí entry is an update", update.summary == .updates(entries: 1))

        let same = KoncluiHooksDiff.compute(original: after, pending: after)
        check("the same file changes nothing", same.summary == .nothing && same.added.isEmpty && same.removed.isEmpty)

        let created = KoncluiHooksDiff.compute(original: nil, pending: after)
        check("a file that is not there is created", created.summary == .creates && !created.added.isEmpty)
        let empty = KoncluiHooksDiff.compute(original: "", pending: after)
        check("an empty file is created too", empty.summary == .creates)

        let plugin = KoncluiHooksDiff.compute(original: "// old\nconst a = 1\n", pending: "// new\nconst a = 1\nconst b = 2\n")
        check("a plugin that changes is an update of the file", plugin.summary == .updatesFile && plugin.added.count == 2 && plugin.removed.count == 1)

        let deletion = KoncluiHooksDiff.compute(original: "line one\nline two\n", pending: "(will delete /Users/x/.copilot/hooks/konclui.json)")
        check("a removal the installer answers with its marker is a deletion", deletion.summary == .deletes && deletion.removed.count == 2)

        let copilotBefore = #"{ "hooks": { "Stop": [ { "bash": "/Users/x/Konclui/nb-hook --agent copilot", "type": "command" } ] } }"#
        let copilot = KoncluiHooksDiff.compute(original: nil, pending: copilotBefore)
        check("Copilot's own file counts its bash entries", copilot.added.filter(KoncluiHooksDiff.isKoncluiCommand).count == 1)

        check("a command line of another tool is not Koncluí's", !KoncluiHooksDiff.isKoncluiCommand(#"      "command": "/usr/local/bin/mine --stop","#))
        check("Koncluí's command line is found whatever the case", KoncluiHooksDiff.isKoncluiCommand(#"      "command": "/Users/x/Library/Application Support/Konclui/nb-hook","#))
        check("lines drop the trailing newline", KoncluiHooksDiff.lines("a\nb\n") == ["a", "b"])
    }

    // MARK: Sources

    static func sources() {
        print("Sources — the places that carry the rules")
        let settings = read("NotchBuddy/Sources/App/SettingsView.swift")
        let hooksOk = ["claudeHooksInstalled", "geminiHooksInstalled", "agyHooksInstalled", "codexHooksInstalled", "copilotHooksInstalled",
                       "museHooksInstalled", "openCodePluginInstalled", "ampPluginInstalled", "hermesPluginInstalled", "hooksNeedUpdate"]
        check("SettingsView reads no agent's file (KoncluiHookStatus does, off the main thread)",
              hooksOk.allSatisfy { !settings.contains("HookServer.\($0)(") })
        check("the pill rows read the last answer", settings.contains("koncluiHooks.snapshot") && settings.contains("hooksKnown"))
        check("the tab limit rule is used by the row", settings.contains("KoncluiTabLimit.blocks("))
        check("the updater sits behind its flag", settings.contains("UpdateSettingsSection()\n            .settingsAnchor(\"general.update\")\n            .koncluiShown(KoncluiFeatures.isOn(\"block_updates\"))"))
        check("the open/close hotkey box is not in the hub window", settings.contains(".koncluiShown(embeddedSection == nil)"))
        check("the demo steps back once an agent is connected", settings.contains("KoncluiGeneralPage.demoComesLast(anyAgentConnected"))
        check("the connect card and the removal are on Geral", settings.contains("KoncluiConnectAgentsCard(") && settings.contains("KoncluiRemoveIntegrations("))
        check("klaude's row is Koncluí's new one", settings.contains("KoncluiKlaudeHooksSection()") && !settings.contains(" KlaudeHooksSection()"))
        check("Orca has a row", settings.contains("KoncluiOrcaRow()"))
        check("Claude Code's removal is previewed like its install", settings.contains("previewClaudeHooks(install: false)"))
        check("every agent popover is the shared controls",
              ["koncluiHookControls(.gemini,", "koncluiHookControls(.antigravity,", "koncluiHookControls(.codex,", "koncluiHookControls(.copilot,",
               "koncluiHookControls(.muse,", "koncluiHookControls(.opencode,", "koncluiHookControls(.amp,", "koncluiHookControls(.hermes,",
               "koncluiHookControls(.claudeCode,"].allSatisfy(settings.contains))
        check("no agent popover keeps its own Install button", !settings.contains("triggerCodexPreview(install: true) }\n"))
        check("the Add… menu is at the page's outer edge on all four lists",
              settings.components(separatedBy: "Add…\" sits at the page's outer edge").count == 3)

        let flowHub = read("NotchBuddy/Sources/App/FlowHub.swift")
        check("Reminders is a page of the window", flowHub.contains("integrations, reminders, voice, shortcuts") && flowHub.contains("case .reminders:    return \"reminders\""))
        let registry = read("NotchBuddy/Sources/App/KoncluiFeatureRegistry.swift")
        check("the page keeps the reminders flag", registry.contains("self == .reminders ? \"block_reminders\""))
        check("the updater is a block with a flag", registry.contains("\"block_updates\""))
        check("the updater flag ships off", KoncluiFeatures.shippedOff.contains("block_updates") && !KoncluiFeatures.shippedDefault("block_updates"))
        let status = read("NotchBuddy/Sources/App/KoncluiHookStatus.swift")
        check("the reads run off the main thread", status.contains("Task.detached") && status.contains("nonisolated static func read()"))
        let controls = read("NotchBuddy/Sources/App/KoncluiHookControls.swift")
        check("the diff is computed off the main thread", controls.contains("Task.detached") && controls.contains("KoncluiHooksDiff.compute"))
        check("the whole file is behind a disclosure", controls.contains("konclui.hooks.diff.whole") && controls.contains("DisclosureGroup"))
        check("the path is a detail, not a status", controls.contains("KoncluiHookDetails(target: target)") && !controls.contains("nb-hook :"))
    }

    // MARK: Strings

    static func catalog() {
        print("Catalog — every new key, in the 14 languages, with the same arguments")
        let languages = ["ar", "bn", "de", "en", "es", "fr", "hi", "id", "pt-BR", "ru", "th", "tr", "zh-Hans", "zh-Hant"]
        let strings = ((try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: "NotchBuddy/Resources/Localizable.xcstrings")))) as? [String: Any])?["strings"] as? [String: [String: Any]] ?? [:]
        func value(_ key: String, _ lang: String) -> String {
            ((strings[key]?["localizations"] as? [String: [String: [String: String]]])?[lang]?["stringUnit"]?["value"]) ?? ""
        }
        let keys = [
            "konclui.hooks.ok", "konclui.hooks.outdated", "konclui.hooks.diff.adds", "konclui.hooks.diff.removes", "konclui.hooks.diff.updates",
            "konclui.hooks.diff.updates-file", "konclui.hooks.diff.creates", "konclui.hooks.diff.deletes", "konclui.hooks.diff.nothing",
            "konclui.hooks.diff.others", "konclui.hooks.diff.whole", "konclui.hooks.diff.reading", "konclui.hooks.write", "konclui.hooks.remove",
            "konclui.hooks.details", "konclui.hooks.reveal", "konclui.hooks.copy-path", "konclui.hooks.copied", "konclui.agents.checking",
            "konclui.terminals.toggle", "konclui.terminals.about", "konclui.orca.about", "konclui.orca.toggle", "konclui.orca.needs-hooks",
            "konclui.pills.limit", "konclui.pills.limit.about", "konclui.pills.limit.hint", "konclui.pills.turn-off", "konclui.pills.turn-off.named",
            "konclui.connect.title", "konclui.connect.body", "konclui.connect.action", "konclui.remove.title", "konclui.remove.about",
            "konclui.remove.open", "konclui.remove.heading", "konclui.remove.confirm", "konclui.remove.note", "konclui.remove.done",
            "konclui.remove.close", "konclui.remove.item.nothing", "konclui.remove.item.removed", "konclui.remove.item.failed",
            "konclui.features.block.updates", "hub.notch.reminders",
        ]
        for key in keys {
            let there = Set((strings[key]?["localizations"] as? [String: Any] ?? [:]).keys) == Set(languages)
            check(key, there)
        }
        func arguments(_ text: String) -> [String] {
            var out: [String] = []
            let scanner = text as NSString
            let regex = try! NSRegularExpression(pattern: #"%(?:\d+\$)?(?:ll)?[@d]"#)
            for m in regex.matches(in: text, range: NSRange(location: 0, length: scanner.length)) { out.append(scanner.substring(with: m.range)) }
            return out.sorted()
        }
        check("every language keeps the English arguments",
              keys.allSatisfy { key in languages.allSatisfy { arguments(value(key, $0)) == arguments(value(key, "en")) } })
        check("no dash in a new string (UX.md, microcopy)",
              keys.allSatisfy { key in languages.allSatisfy { !value(key, $0).contains("—") && !value(key, $0).contains("–") } })
        check("the summary sentences number their arguments, so word order can differ",
              ["konclui.hooks.diff.adds", "konclui.hooks.diff.removes", "konclui.hooks.diff.updates"].allSatisfy { key in
                  languages.allSatisfy { value(key, $0).contains("%1$lld") && value(key, $0).contains("%2$@") }
              })
    }
}
