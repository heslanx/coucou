import Foundation

// MARK: - KoncluiHook
// Koncluí runs next to an installed Coucou (KONCLUI.md, "Functional ties"). Both apps write hook
// entries that run a script named nb-hook into the same agent settings (Gemini, Codex, Muse,
// Copilot, the Claude Code status line), so an entry is Koncluí's only when its command runs the
// nb-hook of Koncluí's own folder: ~/Library/Application Support/Konclui/nb-hook (GitHub build) or
// ~/.claude/konclui/nb-hook (App Store build). Coucou's entries (…/NotchBuddy/nb-hook,
// ~/.claude/coucou/nb-hook) are never read as Koncluí's, so installing or removing Koncluí's
// hooks leaves them as they are. scripts/konclui/rebrand.py routes HookServer's tests here.

enum KoncluiHook {
    /// The folder and script every Koncluí hook command names, compared ignoring case.
    static let marker = "konclui/nb-hook"

    /// True when `command` runs Koncluí's nb-hook.
    static func owns(_ command: String?) -> Bool {
        command?.range(of: marker, options: .caseInsensitive) != nil
    }
}
