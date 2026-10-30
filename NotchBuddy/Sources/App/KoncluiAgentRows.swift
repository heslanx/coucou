import Foundation

// Koncluí: Settings → Agents shows every agent as one calm row with an options popover (docs/konclui/UX.md, 1.2), and the
// "Hooks not installed" hint of Active pills is a door to the same install. What a row says, which agent pills have a
// door, and the names of the DEBUG screenshot flags live here, free of SwiftUI, so scripts/konclui/test-agent-rows.sh
// can check them. The views are KoncluiAgentRow.swift.

enum KoncluiAgentRows {

    /// What an agent needs from Koncluí to reach the notch.
    enum Kind: Sendable, Equatable {
        /// Hooks in the agent's settings file.
        case hooks
        /// A plugin file in the agent's plugin folder.
        case plugin
        /// A switch in Koncluí (no file of the agent is written).
        case toggle
    }

    /// How a status reads: done, still to do, or needing a look.
    enum Tone: Sendable, Equatable { case ready, todo, attention }

    struct Status: Equatable, Sendable {
        /// Catalog key of the words. "Hooks not installed" and "Plugin not installed" are the keys Active pills already used.
        let key: String
        let tone: Tone
    }

    /// The row's status in words. `outdated` is a hook Koncluí wrote that needs updating; `needsPermission` is a switch that
    /// is on but macOS has not allowed what it needs (Claude Desktop chats read the Stop button through Accessibility).
    static func status(_ kind: Kind, installed: Bool, outdated: Bool = false, needsPermission: Bool = false) -> Status {
        switch kind {
        case .hooks:
            if installed { return outdated ? Status(key: "konclui.agents.hooks.outdated", tone: .attention)
                                           : Status(key: "konclui.agents.hooks.installed", tone: .ready) }
            return Status(key: "Hooks not installed", tone: .todo)
        case .plugin:
            return installed ? Status(key: "konclui.agents.plugin.installed", tone: .ready)
                             : Status(key: "Plugin not installed", tone: .todo)
        case .toggle:
            if installed { return needsPermission ? Status(key: "konclui.agents.needs-permission", tone: .attention)
                                                  : Status(key: "konclui.agents.on", tone: .ready) }
            return Status(key: "konclui.agents.off", tone: .todo)
        }
    }

    /// What a row says until the first read of the Mac ends (KoncluiHookStatus): never a guess about what is installed.
    static let checking = Status(key: "konclui.agents.checking", tone: .todo)

    /// The row as VoiceOver says it after a change: the name, then the state in words.
    static func spoken(name: String, status: String) -> String { "\(name), \(status)" }

    // MARK: Doors on Active pills

    /// An agent pill whose "not installed" hint opens the install in a popover.
    struct Door: Equatable, Sendable {
        let block: KoncluiRecognition.AgentBlock
        let kind: Kind
    }

    /// Only the pills that had an install hint before; Hermes and Claude Code never had one.
    static func door(forPill id: String) -> Door? {
        switch id {
        case "agent_gemini":      return Door(block: .gemini, kind: .hooks)
        case "agent_antigravity": return Door(block: .antigravity, kind: .hooks)
        case "agent_codex":       return Door(block: .codex, kind: .hooks)
        case "agent_copilot":     return Door(block: .copilot, kind: .hooks)
        case "agent_muse":        return Door(block: .muse, kind: .hooks)
        case "agent_opencode":    return Door(block: .opencode, kind: .plugin)
        case "agent_amp":         return Door(block: .amp, kind: .plugin)
        default:                  return nil
        }
    }

    // MARK: Colour dot

    /// The pill whose colour the agent's dot uses (the user's own colour included); nil when the agent has no pill of its own.
    static func pill(for block: KoncluiRecognition.AgentBlock) -> String? {
        switch block {
        case .claudeCode, .plan: return nil
        case .claudeDesktop:     return "agent_claude-desktop"
        case .gemini:            return "agent_gemini"
        case .antigravity:       return "agent_antigravity"
        case .codex:             return "agent_codex"
        case .copilot:           return "agent_copilot"
        case .muse:              return "agent_muse"
        case .opencode:          return "agent_opencode"
        case .amp:               return "agent_amp"
        case .hermes:            return "agent_hermes"
        }
    }

    /// Claude's orange for Claude Code and klaude (which runs it), neutral grey for the plan gauges.
    static func fallbackColor(for block: KoncluiRecognition.AgentBlock) -> String {
        block == .plan ? "#8E939C" : "#D97757"
    }

    // MARK: DEBUG screenshots

    /// `-konclui.debug.agentPopover codex` opens that row's popover; `codex:preview` also builds the install preview in it
    /// and `codex:remove` the removal preview (they read the agent's file, never write). The id is an `AgentBlock` raw
    /// value, `klaude` or `orca`.
    struct DebugTarget: Equatable, Sendable {
        let id: String
        let preview: Bool
        var removal = false
    }

    static func debugTarget(_ raw: String?) -> DebugTarget? {
        guard let raw, !raw.isEmpty else { return nil }
        let parts = raw.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        guard let id = parts.first, !id.isEmpty else { return nil }
        let suffix = parts.count > 1 ? parts[1] : ""
        return DebugTarget(id: id, preview: suffix == "preview", removal: suffix == "remove")
    }
}
