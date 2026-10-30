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

// MARK: - KlaudeHooksSection

/// The klaude row of Settings → Agents, built like the Codex one: where the hooks go, Install and
/// Uninstall each previewing the file, and nothing written until the user confirms.
struct KlaudeHooksSection: View {
    #if !APPSTORE
    @State private var hooksInstalled = KlaudeHooks.installed()
    @State private var showDiff = false
    @State private var pendingJSON = ""
    @State private var pendingInstall = true
    @State private var statusMessage = ""
    @State private var open = KoncluiAgentsDebug.opens("klaude")

    var body: some View {
        if KlaudeHooks.exists() || KoncluiAgentsDebug.opens("klaude") {
            // Opening starts from a clean message: the row's note is about what was done in this popover.
            KoncluiAgentRow(id: "klaude", name: "klaude", colorHex: KoncluiAgentRows.colorHex(for: .claudeCode),
                            status: KoncluiAgentRows.status(.hooks, installed: hooksInstalled), note: statusMessage,
                            isOpen: Binding(get: { open }, set: { on in if on { statusMessage = "" }; open = on })) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(hooksInstalled
                         ? String(localized: "hooks.klaude.installed")
                         : "~/.klaude/settings.json")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                    HStack(spacing: 10) {
                        Button(String(localized: "hooks.install")) { preview(install: true) }
                            .buttonStyle(.borderedProminent)
                        Button(String(localized: "hooks.uninstall")) { preview(install: false) }
                            .buttonStyle(.bordered)
                    }
                    if showDiff {
                        ScrollView {
                            Text(pendingJSON)
                                .font(.system(size: 10, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 140)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                        HStack {
                            Button(String(localized: "hooks.confirm-write")) { confirm() }
                                .buttonStyle(.borderedProminent)
                            Button(String(localized: "Cancel")) { showDiff = false; pendingJSON = "" }
                                .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(6)
            }
            .onAppear {
                if KoncluiAgentsDebug.opens("klaude") && KoncluiAgentsDebug.previews { preview(install: true) }   // DEBUG only
            }
        }
    }

    private func preview(install: Bool) {
        do {
            pendingInstall = install
            pendingJSON = try HookServer.shared.previewClaudeHooks(at: KlaudeHooks.settingsURL(), install: install)
            showDiff = true
            statusMessage = String(localized: "hooks.review-json")
        } catch let e as NSError where e.domain == "CoucouNoop" {
            statusMessage = e.localizedDescription
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func confirm() {
        do {
            try HookServer.shared.writeClaudeHooks(at: KlaudeHooks.settingsURL())
            showDiff = false
            pendingJSON = ""
            hooksInstalled = pendingInstall
            statusMessage = pendingInstall
                ? String(localized: "status.klaude-hooks-installed")
                : String(localized: "status.klaude-hooks-removed")
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }
    #else
    var body: some View { EmptyView() }
    #endif
}
