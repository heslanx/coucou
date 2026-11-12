import Foundation

// Koncluí: what this Mac has. Settings → Active pills, Agents, Chat and Integrations list only what was recognized
// (installed, configured, signed in or turned on); an "Add…" button reveals the rest. This file is the pure part:
// the detection of the tools on disk, the signals the screens gather, and the rules that turn them into
// "recognized". No UI, no AppState, no Keychain: the screens pass in what they read, the tests pass in fakes.

// MARK: - Tools found on disk

/// A tool Koncluí can recognize without being told: its CLI, its app or its config folder is on this Mac.
enum KoncluiTool: String, CaseIterable, Sendable {
    case claudeCode, claudeDesktop, cursor, orca
    case gemini, antigravity, codex, copilot, muse, opencode, amp, hermes

    /// Executable names, looked for on $PATH and in the usual install folders.
    var binaries: [String] {
        switch self {
        case .claudeCode:    return ["claude"]
        case .claudeDesktop: return []
        case .cursor:        return ["cursor"]
        case .orca:          return []
        case .gemini:        return ["gemini"]
        case .antigravity:   return ["agy", "antigravity"]
        case .codex:         return ["codex"]
        case .copilot:       return ["copilot"]
        case .muse:          return ["muse"]
        case .opencode:      return ["opencode"]
        case .amp:           return ["amp"]
        case .hermes:        return ["hermes"]
        }
    }

    /// App bundle names, looked for in /Applications and ~/Applications.
    var apps: [String] {
        switch self {
        case .claudeDesktop: return ["Claude.app"]
        case .cursor:        return ["Cursor.app"]
        case .orca:          return ["Orca.app"]
        case .antigravity:   return ["Antigravity.app"]
        case .codex:         return ["Codex.app"]
        default:             return []
        }
    }

    /// Config files or folders the tool leaves in the home folder (paths relative to it). Not a sign the tool is
    /// installed (see `detect`); kept to tell a leftover from a tool that was never there.
    var configPaths: [String] {
        switch self {
        case .claudeCode:  return [".claude"]
        case .cursor:      return [".cursor"]
        case .orca:        return [".orca"]
        // ~/.gemini also holds Antigravity's hooks, so Gemini CLI is told by its own files.
        case .gemini:      return [".gemini/settings.json", ".gemini/oauth_creds.json"]
        case .antigravity: return [".gemini/antigravity", ".antigravity"]
        case .codex:       return [".codex"]
        case .copilot:     return [".copilot"]
        case .muse:        return [".config/muse"]
        case .opencode:    return [".config/opencode", ".opencode"]
        case .amp:         return [".config/amp", ".amp"]
        case .hermes:      return [".hermes"]
        case .claudeDesktop: return []
        }
    }
}

/// What the detection reads from the Mac. `live` is the real one; the tests pass a fake.
struct KoncluiProbe {
    var home: String
    /// The $PATH folders. A GUI app inherits a short PATH, so the usual install folders are added on top.
    var path: [String]
    var exists: (String) -> Bool
    /// The names inside a folder, for the version managers (nvm keeps one `bin` per Node version).
    var children: (String) -> [String]

    static var live: KoncluiProbe {
        let fm = FileManager.default
        return KoncluiProbe(
            home: NSHomeDirectory(),
            path: (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init),
            exists: { fm.fileExists(atPath: $0) },
            children: { (try? fm.contentsOfDirectory(atPath: $0)) ?? [] })
    }
}

enum KoncluiRecognition {

    /// Where a CLI usually lands, besides $PATH.
    static func binaryFolders(_ p: KoncluiProbe) -> [String] {
        var folders = p.path + [
            "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin",
            "\(p.home)/.local/bin", "\(p.home)/.npm-global/bin", "\(p.home)/.bun/bin", "\(p.home)/.cargo/bin",
            "\(p.home)/.volta/bin", "\(p.home)/.claude/local", "\(p.home)/.amp/bin", "\(p.home)/.opencode/bin",
            "\(p.home)/go/bin", "\(p.home)/Library/pnpm",
        ]
        let nvm = "\(p.home)/.nvm/versions/node"
        folders += p.children(nvm).map { "\(nvm)/\($0)/bin" }
        return folders
    }

    static func hasBinary(_ names: [String], _ p: KoncluiProbe) -> Bool {
        let folders = binaryFolders(p)
        return names.contains { name in folders.contains { p.exists("\($0)/\(name)") } }
    }

    static func hasApp(_ names: [String], _ p: KoncluiProbe) -> Bool {
        names.contains { name in ["/Applications", "\(p.home)/Applications"].contains { p.exists("\($0)/\(name)") } }
    }

    /// Whether this Mac has the tool: its CLI or its app. A config folder alone does not count: it outlives an
    /// uninstall (~/.gemini, ~/.copilot, ~/.hermes… stay behind), so it would list agents the Mac no longer has.
    static func detect(_ tool: KoncluiTool, _ p: KoncluiProbe) -> Bool {
        hasBinary(tool.binaries, p) || hasApp(tool.apps, p)
    }

    static func detectedTools(_ p: KoncluiProbe) -> Set<KoncluiTool> {
        Set(KoncluiTool.allCases.filter { detect($0, p) })
    }

    // The settings screens are rebuilt often and the folders do not change by the second: one scan serves them all.
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cache: (at: Date, tools: Set<KoncluiTool>)?

    /// The tools on this Mac, scanned at most every `maxAge` seconds.
    static func liveTools(maxAge: TimeInterval = 10) -> Set<KoncluiTool> {
        cacheLock.lock(); defer { cacheLock.unlock() }
        if let cache, Date().timeIntervalSince(cache.at) < maxAge { return cache.tools }
        let tools = detectedTools(.live)
        cache = (Date(), tools)
        return tools
    }

    // MARK: Pills and integrations

    /// What the screens know about this Mac and the user's setup, gathered by the view.
    struct Signals {
        /// The main pill and the active pills.
        var on: Set<String> = []
        /// Tools found on disk, plus agents whose hooks are installed.
        var tools: Set<KoncluiTool> = []
        /// Keychain names that hold a value.
        var keys: Set<String> = []
        /// Chat providers usable now: a saved key, a connected server, or a sign-in.
        var chatReady: Set<String> = []
        var spotifyInstalled = false
    }

    /// The tool behind each workspace and agent pill.
    static let toolForPill: [String: KoncluiTool] = [
        "agent_cursor": .cursor, "agent_orca": .orca, "agent_antigravity": .antigravity, "agent_codex": .codex,
        "agent_gemini": .gemini, "agent_copilot": .copilot, "agent_muse": .muse, "agent_opencode": .opencode,
        "agent_amp": .amp, "agent_hermes": .hermes, "agent_claude-desktop": .claudeDesktop,
    ]

    /// The Keychain names that configure each service (any one of them counts).
    static let keysForPill: [String: [String]] = [
        "integration_resend": ["resend-api-key"],
        "integration_n8n": ["n8n-api-key", "n8n-url"],
        "integration_vercel": ["vercel-token"],
        "integration_github": ["github-token"],
        "integration_notion": ["notion-api-key"],
        "integration_calcom": ["calcom-api-key"],
        "integration_stripe": ["stripe-api-key"],
        "integration_whatsapp": ["whatsapp-url", "whatsapp-api-key"],
        "integration_portfolio": [
            "portfolio-binance-key", "portfolio-okx-key", "portfolio-bybit-key",
            "portfolio-kraken-key", "portfolio-coinbase-key",
        ],
    ]

    /// Every Keychain name the rules above read: the screen asks the cache for these.
    static let allKeys: [String] = keysForPill.values.flatMap { $0 }.sorted()

    /// Whether a pill (or the integration block of the same id) was recognized: turned on, found on this Mac,
    /// configured, or usable. Built-in apps (Music, Mail) and keyless services (Crypto) carry no signal, so
    /// they count only when turned on.
    static func pillRecognized(_ id: String, _ s: Signals) -> Bool {
        if s.on.contains(id) { return true }
        if let tool = toolForPill[id] { return s.tools.contains(tool) }
        if id == "integration_spotify" { return s.spotifyInstalled }
        if let provider = ChatProvider(pillID: id) { return s.chatReady.contains(provider.rawValue) }
        if let keys = keysForPill[id] { return keys.contains { s.keys.contains($0) } }
        return false
    }

    // MARK: Agents

    /// The blocks of Settings → Agents.
    enum AgentBlock: String, CaseIterable, Sendable {
        case claudeCode, claudeDesktop, gemini, antigravity, codex, copilot, muse, opencode, amp, hermes
        /// The Claude and Codex plan gauges.
        case plan

        /// What the "Add…" menu calls it.
        var title: String {
            switch self {
            case .claudeCode:    return "Claude Code"
            case .claudeDesktop: return "Claude Desktop"
            case .gemini:        return "Gemini CLI"
            case .antigravity:   return "Antigravity"
            case .codex:         return "Codex"
            case .copilot:       return "Copilot CLI"
            case .muse:          return "Muse Code"
            case .opencode:      return "OpenCode"
            case .amp:           return "Amp"
            case .hermes:        return "Hermes"
            case .plan:          return String(localized: "plan.title")
            }
        }

        var tool: KoncluiTool? {
            switch self {
            case .claudeCode:    return .claudeCode
            case .claudeDesktop: return .claudeDesktop
            case .gemini:        return .gemini
            case .antigravity:   return .antigravity
            case .codex:         return .codex
            case .copilot:       return .copilot
            case .muse:          return .muse
            case .opencode:      return .opencode
            case .amp:           return .amp
            case .hermes:        return .hermes
            case .plan:          return nil
            }
        }
    }

    /// An agent's block shows when its tool is on this Mac, or its hooks are already installed (`active`).
    static func agentRecognized(_ block: AgentBlock, tools: Set<KoncluiTool>, active: Set<AgentBlock>) -> Bool {
        if active.contains(block) { return true }
        if block == .plan { return tools.contains(.claudeCode) || tools.contains(.codex) }
        return block.tool.map(tools.contains) ?? false
    }
}

// MARK: - What the user added

/// "Add…" reveals a row the screen did not list. The choice is kept, as `<screen>:<id>` entries.
enum KoncluiAdded {
    enum Screen: String { case pills, agents, chat, integrations }

    static let defaultsKey = "konclui.added"

    static func entry(_ screen: Screen, _ id: String) -> String { "\(screen.rawValue):\(id)" }

    static func load(_ defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: defaultsKey) ?? [])
    }

    static func save(_ entries: Set<String>, _ defaults: UserDefaults = .standard) {
        defaults.set(entries.sorted(), forKey: defaultsKey)
    }
}
