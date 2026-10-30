import Foundation

// Koncluí: every file Koncluí writes so an agent reaches the notch, and what a Mac has of them. Free of SwiftUI and of
// HookServer, so scripts/konclui/test-page-rules.sh can check it: the views and KoncluiHookStatus feed it what they read.

/// One integration Koncluí writes in an agent's own files. The raw values are stable (they are never stored, but the DEBUG
/// flags and the tests name them).
enum KoncluiHookTarget: String, CaseIterable, Sendable {
    case claudeCode, klaude, gemini, antigravity, codex, copilot, muse, opencode, amp, hermes
    /// The plan gauge's status line, also written in Claude Code's settings.
    case statusLine

    /// The file as the person reads it, in the home folder's short form.
    var shownPath: String {
        switch self {
        case .claudeCode, .statusLine: return "~/.claude/settings.json"
        case .klaude:                  return "~/.klaude/settings.json"
        case .gemini:                  return "~/.gemini/settings.json"
        case .antigravity:             return "~/.gemini/config/hooks.json"
        case .codex:                   return "~/.codex/hooks.json"
        case .copilot:                 return "~/.copilot/hooks/konclui.json"
        case .muse:                    return "~/.config/muse/settings.json"
        case .opencode:                return "~/.config/opencode/plugins/konclui.js"
        case .amp:                     return "~/.config/amp/plugins/konclui.ts"
        case .hermes:                  return "~/.hermes/plugins/konclui/__init__.py"
        }
    }

    func url(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent(String(shownPath.dropFirst(2)))
    }

    /// A plugin is a file of Koncluí's own; the rest are entries inside a settings file that belongs to the agent.
    var isPlugin: Bool { self == .opencode || self == .amp || self == .hermes }

    /// The tool that has to be on this Mac for the target to matter.
    var tool: KoncluiTool? {
        switch self {
        case .claudeCode, .statusLine: return .claudeCode
        case .klaude:                  return nil
        case .gemini:                  return .gemini
        case .antigravity:             return .antigravity
        case .codex:                   return .codex
        case .copilot:                 return .copilot
        case .muse:                    return .muse
        case .opencode:                return .opencode
        case .amp:                     return .amp
        case .hermes:                  return .hermes
        }
    }

    /// The name the person knows it by.
    var name: String {
        switch self {
        case .claudeCode:  return "Claude Code"
        case .klaude:      return "klaude"
        case .gemini:      return "Gemini CLI"
        case .antigravity: return "Antigravity"
        case .codex:       return "Codex"
        case .copilot:     return "Copilot CLI"
        case .muse:        return "Muse Code"
        case .opencode:    return "OpenCode"
        case .amp:         return "Amp"
        case .hermes:      return "Hermes"
        case .statusLine:  return "Claude Code"
        }
    }

    /// The target behind a block of Settings → Agents, when the block installs something.
    init?(block: KoncluiRecognition.AgentBlock) {
        switch block {
        case .claudeCode:  self = .claudeCode
        case .gemini:      self = .gemini
        case .antigravity: self = .antigravity
        case .codex:       self = .codex
        case .copilot:     self = .copilot
        case .muse:        self = .muse
        case .opencode:    self = .opencode
        case .amp:         self = .amp
        case .hermes:      self = .hermes
        case .claudeDesktop, .plan: return nil
        }
    }

    /// The agents, in the order the notch's pages list them (klaude and Claude Code first: the main job).
    static let agents: [KoncluiHookTarget] = [.klaude, .claudeCode, .codex, .gemini, .antigravity, .copilot, .muse, .opencode, .amp, .hermes]
}

/// What a Mac has of Koncluí's integrations, read once off the main thread (KoncluiHookStatus) and passed to the views.
struct KoncluiHookSnapshot: Equatable, Sendable {
    var installed: Set<KoncluiHookTarget> = []
    /// Claude Code's hooks are there but older than what Koncluí writes now (the permission timeout, the question hook).
    var claudeOutdated = false
    /// klaude's launcher or config folder is on this Mac.
    var klaudeExists = false
    /// The agents and apps found on disk.
    var tools: Set<KoncluiTool> = []

    func isInstalled(_ target: KoncluiHookTarget) -> Bool { installed.contains(target) }

    /// The agents already connected to the notch (the status line is not an agent).
    var connected: [KoncluiHookTarget] { KoncluiHookTarget.agents.filter(installed.contains) }

    /// Whether the person has set up at least one agent: the demo is a first-run tool, so it steps back after this.
    var anyConnected: Bool { !connected.isEmpty }

    /// Agents found on this Mac that are not connected yet, in the order of `KoncluiHookTarget.agents`.
    var waiting: [KoncluiHookTarget] {
        KoncluiHookTarget.agents.filter { target in
            guard !installed.contains(target) else { return false }
            if target == .klaude { return klaudeExists }
            return target.tool.map(tools.contains) ?? false
        }
    }

    /// Everything Koncluí wrote that "remove everything" can take back.
    var removable: [KoncluiHookTarget] { KoncluiHookTarget.allCases.filter(installed.contains) }
}
