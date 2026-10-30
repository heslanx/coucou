#if !APPSTORE
import SwiftUI

// Koncluí: klaude's row of Settings → Agents. klaude runs Claude Code with its own config (~/.klaude), so its hooks are
// written the way Claude Code's are (HookServer.previewClaudeHooks(at:)). Like every agent it is one row with an options
// popover that holds KoncluiHookControls: the state, the one primary it needs, the review before anything is written.
// KlaudeHooks (the file checks) stays in KoncluiAgentHooks.swift.

struct KoncluiKlaudeHooksSection: View {
    @ObservedObject private var hooks = KoncluiHookStatus.shared
    @State private var installed = KoncluiHookStatus.shared.snapshot.isInstalled(.klaude)
    @State private var showDiff = false
    @State private var pendingJSON = ""
    @State private var pendingInstall = true
    @State private var statusMessage = ""
    @State private var open = KoncluiAgentsDebug.opens("klaude")

    var body: some View {
        if (hooks.loaded && hooks.snapshot.klaudeExists) || KoncluiAgentsDebug.opens("klaude") {
            // Opening starts from a clean message: the row's note is about what was done in this popover.
            KoncluiAgentRow(id: "klaude", name: "klaude", colorHex: KoncluiAgentRows.colorHex(for: .claudeCode),
                            status: hooks.loaded ? KoncluiAgentRows.status(.hooks, installed: installed) : KoncluiAgentRows.checking,
                            note: statusMessage,
                            isOpen: Binding(get: { open }, set: { on in if on { statusMessage = "" }; open = on })) {
                KoncluiHookControls(target: .klaude, name: "klaude", installed: installed, showDiff: showDiff,
                                    pending: pendingJSON, pendingInstall: pendingInstall,
                                    preview: { preview(install: $0) }, confirm: { confirm() },
                                    cancel: { showDiff = false; pendingJSON = "" })
                    .padding(6)
            }
            .onAppear {
                // DEBUG only: `-konclui.debug.agentPopover klaude:preview` (or `klaude:remove`)
                if KoncluiAgentsDebug.opens("klaude") && (KoncluiAgentsDebug.previews || KoncluiAgentsDebug.removes) {
                    preview(install: !KoncluiAgentsDebug.removes)
                }
            }
            .onChange(of: hooks.snapshot) { _, snap in installed = snap.isInstalled(.klaude) }
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
            installed = pendingInstall
            statusMessage = pendingInstall
                ? String(localized: "status.klaude-hooks-installed")
                : String(localized: "status.klaude-hooks-removed")
            hooks.refresh()
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }
}
#endif
