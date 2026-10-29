import Foundation

// Koncluí's feature flags (CoucouKit/KoncluiFeatures.swift, PillCatalog.available) and what Settings recognizes on a
// Mac (App/KoncluiRecognition.swift). Pure: the flags live in a throwaway UserDefaults suite and the Mac is a fake.

@main
enum KoncluiFeaturesTests {

    static var failures = 0

    static func check(_ label: String, _ got: Bool) {
        if got { print("  ✓ \(label)") }
        else   { print("  ✗ \(label)"); failures += 1 }
    }

    static let hiddenByDefault = [
        "integration_crypto", "integration_calcom", "integration_stripe", "integration_github",
        "integration_vercel", "integration_n8n", "integration_resend", "integration_notion", "integration_portfolio",
    ]

    static func ids(_ pills: [PillDefinition]) -> [String] { pills.map(\.id) }

    /// A Mac with exactly these paths, these folders on $PATH and these children in folders.
    static func mac(_ paths: [String], path: [String] = [], children: [String: [String]] = [:]) -> KoncluiProbe {
        let home = "/Users/test"
        let present = Set(paths.map { $0.hasPrefix("~/") ? home + $0.dropFirst(1) : $0 })
        return KoncluiProbe(home: home, path: path, exists: { present.contains($0) },
                            children: { children[$0] ?? [] })
    }

    static func main() {
        let suite = "konclui-features-tests-\(ProcessInfo.processInfo.processIdentifier)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        KoncluiFeatures.store = defaults
        defer { defaults.removePersistentDomain(forName: suite) }

        print("Default flags — what PillCatalog.available offers")
        let shipped = ids(PillCatalog.available)
        print("  available: \(shipped.joined(separator: " "))")
        check("the hidden pills are not offered", hiddenByDefault.allSatisfy { !shipped.contains($0) })
        check("shippedOff is exactly the hidden ones", KoncluiFeatures.shippedOff == Set(hiddenByDefault))
        let others = PillCatalog.all.map(\.id).filter { !hiddenByDefault.contains($0) }
        check("every other pill is offered, in catalog order", shipped == others)
        check("Orca is offered", shipped.contains("agent_orca"))
        check("the main pill is offered", shipped.contains("integration_claude"))
        check("nothing was written to the preferences", defaults.dictionaryRepresentation().keys.allSatisfy { !$0.hasPrefix("konclui.feature.") })

        print("Orca — the pill K11 routes Orca terminals to")
        let orca = PillCatalog.definition(for: "agent_orca")
        check("named Orca", orca?.name == "Orca")
        check("in Where you code (workspace)", orca?.category == .workspace)
        check("a session agent", orca?.source == .agent)
        let sameColour = PillCatalog.all.filter { $0.id != "agent_orca" && $0.defaultColor.uppercased() == orca?.defaultColor.uppercased() }
        check("its colour belongs to no other pill", sameColour.isEmpty)
        check("sessions of its card say Orca", orca?.sessionSubtitle == "Orca")

        print("Override round trip — konclui.feature.<id>")
        check("GitHub ships off", !KoncluiFeatures.isOn("integration_github"))
        KoncluiFeatures.set("integration_github", true)
        check("the choice is stored as konclui.feature.integration_github",
              defaults.object(forKey: "konclui.feature.integration_github") as? Bool == true)
        check("GitHub is back in PillCatalog.available", ids(PillCatalog.available).contains("integration_github"))
        check("the other hidden pills stay hidden",
              hiddenByDefault.filter { $0 != "integration_github" }.allSatisfy { !ids(PillCatalog.available).contains($0) })
        KoncluiFeatures.set("integration_github", false)
        check("off again: gone from available", !ids(PillCatalog.available).contains("integration_github"))
        KoncluiFeatures.set("agent_cursor", false)
        check("a pill that ships on can be turned off", !ids(PillCatalog.available).contains("agent_cursor"))
        KoncluiFeatures.reset("agent_cursor")
        check("reset gives back the shipped value", ids(PillCatalog.available).contains("agent_cursor"))
        defaults.set(true, forKey: "konclui.feature.integration_stripe")
        check("a value written from outside (defaults write) counts", ids(PillCatalog.available).contains("integration_stripe"))
        defaults.set("yes", forKey: "konclui.feature.integration_vercel")
        check("a value that is not a Bool is ignored", !KoncluiFeatures.isOn("integration_vercel"))
        check("an unknown feature is on", KoncluiFeatures.isOn("something_nobody_declared"))
        KoncluiFeatures.resetAll()
        check("resetAll: back to the hidden ones", hiddenByDefault.allSatisfy { !KoncluiFeatures.isOn($0) })
        check("resetAll leaves no override", defaults.dictionaryRepresentation().keys.allSatisfy { !$0.hasPrefix("konclui.feature.") })

        print("Required — the main workspace pill")
        KoncluiFeatures.set("integration_claude", false)
        check("cannot be turned off", KoncluiFeatures.isOn("integration_claude"))
        check("and nothing is stored for it", defaults.object(forKey: "konclui.feature.integration_claude") == nil)

        print("Changes are announced")
        var posts = 0
        let token = NotificationCenter.default.addObserver(forName: KoncluiFeatures.didChange, object: nil, queue: nil) { _ in posts += 1 }
        KoncluiFeatures.set("integration_n8n", true)
        KoncluiFeatures.reset("integration_n8n")
        KoncluiFeatures.resetAll()
        NotificationCenter.default.removeObserver(token)
        check("set, reset and resetAll each post didChange", posts == 3)

        print("Unlock — the hidden Features screen")
        check("locked by default", !KoncluiFeatures.isUnlocked)
        KoncluiFeatures.isUnlocked = true
        check("stored as konclui.features.unlocked", defaults.bool(forKey: "konclui.features.unlocked"))
        KoncluiFeatures.set("integration_n8n", true)
        KoncluiFeatures.resetAll()
        check("resetAll does not lock it again", KoncluiFeatures.isUnlocked)
        KoncluiFeatures.isUnlocked = false
        check("locks again", !KoncluiFeatures.isUnlocked)

        print("Tools on a Mac — detection")
        check("an empty Mac has none", KoncluiRecognition.detectedTools(mac([])).isEmpty)
        check("a CLI in ~/.local/bin", KoncluiRecognition.detect(.claudeCode, mac(["~/.local/bin/claude"])))
        check("a CLI in Homebrew's folder", KoncluiRecognition.detect(.codex, mac(["/opt/homebrew/bin/codex"])))
        check("a CLI on $PATH", KoncluiRecognition.detect(.gemini, mac(["/custom/bin/gemini"], path: ["/custom/bin"])))
        check("a CLI under nvm",
              KoncluiRecognition.detect(.opencode, mac(["~/.nvm/versions/node/v22.1.0/bin/opencode"],
                                                       children: ["/Users/test/.nvm/versions/node": ["v22.1.0"]])))
        check("an app in /Applications", KoncluiRecognition.detect(.cursor, mac(["/Applications/Cursor.app"])))
        check("an app in ~/Applications", KoncluiRecognition.detect(.orca, mac(["~/Applications/Orca.app"])))
        check("the Claude desktop app", KoncluiRecognition.detect(.claudeDesktop, mac(["/Applications/Claude.app"])))
        check("a leftover config folder is not the tool", !KoncluiRecognition.detect(.codex, mac(["~/.codex"])))
        check("Orca's folder alone is not Orca", !KoncluiRecognition.detect(.orca, mac(["~/.orca"])))
        check("~/.gemini alone is neither Gemini CLI nor Antigravity",
              KoncluiRecognition.detectedTools(mac(["~/.gemini", "~/.gemini/config/hooks.json"])).isEmpty)
        check("Gemini CLI's leftover settings are not Gemini CLI",
              KoncluiRecognition.detectedTools(mac(["~/.gemini/settings.json", "~/.gemini/oauth_creds.json",
                                                    "~/.gemini/antigravity", "~/.copilot", "~/.hermes"])).isEmpty)
        check("a CLI that is somewhere unusual is not found", !KoncluiRecognition.detect(.amp, mac(["/somewhere/else/amp"])))
        check("a CLI is not another tool", KoncluiRecognition.detectedTools(mac(["~/.local/bin/hermes"])) == [.hermes])
        check("several at once",
              KoncluiRecognition.detectedTools(mac(["~/.local/bin/claude", "/Applications/Orca.app", "/usr/local/bin/amp"])) == [.claudeCode, .orca, .amp])

        print("Pills and integrations — recognized")
        func rec(_ id: String, _ s: KoncluiRecognition.Signals) -> Bool { KoncluiRecognition.pillRecognized(id, s) }
        let none = KoncluiRecognition.Signals()
        check("nothing recognized on a bare Mac", PillCatalog.all.allSatisfy { !rec($0.id, none) })
        check("a pill that is on", rec("agent_amp", .init(on: ["agent_amp"])))
        check("the main pill", rec("integration_claude", .init(on: ["integration_claude"])))
        check("a tool on this Mac", rec("agent_cursor", .init(tools: [.cursor])))
        check("Orca installed", rec("agent_orca", .init(tools: [.orca])))
        check("another tool does not count", !rec("agent_cursor", .init(tools: [.orca])))
        check("a service with its key", rec("integration_github", .init(keys: ["github-token"])))
        check("a key of another service does not count", !rec("integration_github", .init(keys: ["stripe-api-key"])))
        check("n8n by its URL alone", rec("integration_n8n", .init(keys: ["n8n-url"])))
        check("WhatsApp by its gateway", rec("integration_whatsapp", .init(keys: ["whatsapp-url"])))
        check("Portfolio by any exchange key", rec("integration_portfolio", .init(keys: ["portfolio-kraken-key"])))
        check("an AI provider that is ready", rec("ai_anthropic", .init(chatReady: ["anthropic"])))
        check("a local server that is connected", rec("ai_ollama", .init(chatReady: ["ollama"])))
        check("a ready provider is not another provider", !rec("ai_openai", .init(chatReady: ["anthropic"])))
        check("Spotify installed", rec("integration_spotify", .init(spotifyInstalled: true)))
        check("Apple Music and Mail count only when on",
              !rec("integration_music", .init(tools: Set(KoncluiTool.allCases))) && rec("integration_music", .init(on: ["integration_music"]))
              && !rec("integration_mail", none) && rec("integration_mail", .init(on: ["integration_mail"])))
        check("Crypto (no key, no app) counts only when on",
              !rec("integration_crypto", .init(keys: Set(KoncluiRecognition.allKeys))) && rec("integration_crypto", .init(on: ["integration_crypto"])))
        check("every pill the rules name is in the catalog",
              Set(KoncluiRecognition.toolForPill.keys).union(KoncluiRecognition.keysForPill.keys).isSubset(of: Set(PillCatalog.all.map(\.id))))

        print("Agents — recognized")
        typealias Block = KoncluiRecognition.AgentBlock
        check("nothing on a bare Mac", Block.allCases.allSatisfy { !KoncluiRecognition.agentRecognized($0, tools: [], active: []) })
        check("its tool is on this Mac", KoncluiRecognition.agentRecognized(.gemini, tools: [.gemini], active: []))
        check("its hooks are installed", KoncluiRecognition.agentRecognized(.amp, tools: [], active: [.amp]))
        check("another agent's tool does not count", !KoncluiRecognition.agentRecognized(.gemini, tools: [.codex], active: []))
        check("the plan gauges follow Claude Code or Codex",
              KoncluiRecognition.agentRecognized(.plan, tools: [.claudeCode], active: [])
              && KoncluiRecognition.agentRecognized(.plan, tools: [.codex], active: [])
              && !KoncluiRecognition.agentRecognized(.plan, tools: [.gemini], active: []))
        check("the plan gauges when one is on", KoncluiRecognition.agentRecognized(.plan, tools: [], active: [.plan]))
        check("every block with a tool names one a Mac can have", Block.allCases.compactMap(\.tool).allSatisfy { KoncluiTool.allCases.contains($0) })

        print("Added — what Add… keeps")
        check("entries read <screen>:<id>", KoncluiAdded.entry(.agents, "gemini") == "agents:gemini")
        check("a screen's entry is not another's", KoncluiAdded.entry(.pills, "x") != KoncluiAdded.entry(.chat, "x"))
        check("nothing added at first", KoncluiAdded.load(defaults).isEmpty)
        KoncluiAdded.save([KoncluiAdded.entry(.chat, "google"), KoncluiAdded.entry(.pills, "agent_amp")], defaults)
        check("saved entries come back", KoncluiAdded.load(defaults) == ["chat:google", "pills:agent_amp"])

        if failures == 0 { print("PASS") } else { print("FAIL: \(failures)"); exit(1) }
    }
}
