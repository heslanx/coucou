import SwiftUI

// Koncluí: klaude runs Claude Code with its own config (~/.klaude), so it gets Koncluí's hooks too and
// its sessions reach the notch; sessions in Orca terminals go to the Orca pill (agent_orca) and a click
// opens that terminal. Owned by unit K11. Settings → Agents (unit K9) shows this section, as a row with an options
// popover like every agent (KoncluiAgentRow.swift, unit K16).

// MARK: - KlaudeHooks

/// klaude (~/.local/bin/klaude) starts Claude Code with CLAUDE_CONFIG_DIR=~/.klaude, so Claude Code reads
/// ~/.klaude/settings.json and never ~/.claude/settings.json: its hooks are installed there, by the same
/// code that installs them in ~/.claude (HookServer.previewClaudeHooks(at:)).
enum KlaudeHooks {
    static func settingsURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home.appendingPathComponent(".klaude/settings.json")
    }

    /// klaude is on this Mac: its launcher or its config folder is there.
    static func exists(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: home.appendingPathComponent(".local/bin/klaude").path)
            || fm.fileExists(atPath: home.appendingPathComponent(".klaude").path)
    }

    /// True when ~/.klaude/settings.json routes Claude Code's SessionStart to Koncluí's nb-hook.
    static func installed(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        guard let data = try? Data(contentsOf: settingsURL(home: home)),
              let settings = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let hooks = settings["hooks"] as? [String: Any],
              let groups = hooks["SessionStart"] as? [[String: Any]] else { return false }
        return groups.contains { group in
            (group["hooks"] as? [[String: Any]])?.contains { KoncluiHook.owns($0["command"] as? String) } ?? false
        }
    }
}

