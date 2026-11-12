import Foundation
import Combine

// Koncluí: what the Mac has of Koncluí's integrations, for the notch pages. The installers' own checks read and parse the
// agents' files (~/.codex/hooks.json, ~/.gemini/settings.json…); called from a view's body or a @State initializer they ran
// on the main thread at every redraw. Here they run once, off the main thread, when a page appears and after an action,
// and the views read the last answer from memory (docs/konclui/ENGINEERING.md: side effects at the edges).

@MainActor
final class KoncluiHookStatus: ObservableObject {
    static let shared = KoncluiHookStatus()

    /// The last answer; empty until the first read finishes (`loaded`).
    @Published private(set) var snapshot = KoncluiHookSnapshot()
    /// False until the first read ends: the rows say they are checking, never a guess.
    @Published private(set) var loaded = false

    private var reading: Task<Void, Never>?
    private var again = false

    private init() {}

    /// Reads the Mac again in the background. A call that arrives while a read is running asks for one more after it.
    func refresh() {
        guard reading == nil else { again = true; return }
        reading = Task { [weak self] in
            let fresh = await Task.detached(priority: .userInitiated) { Self.read() }.value
            guard let self else { return }
            if fresh != self.snapshot { self.snapshot = fresh }
            self.loaded = true
            self.reading = nil
            if self.again { self.again = false; self.refresh() }
        }
    }

    /// The reads themselves. Not isolated to the main actor: every one of them is a file read.
    nonisolated static func read() -> KoncluiHookSnapshot {
        var snap = KoncluiHookSnapshot()
        var on = Set<KoncluiHookTarget>()
        #if !APPSTORE
        if HookServer.claudeHooksInstalled() { on.insert(.claudeCode) }
        if KlaudeHooks.installed() { on.insert(.klaude) }
        if HookServer.geminiHooksInstalled() { on.insert(.gemini) }
        if HookServer.agyHooksInstalled() { on.insert(.antigravity) }
        if HookServer.codexHooksInstalled() { on.insert(.codex) }
        if HookServer.copilotHooksInstalled() { on.insert(.copilot) }
        if HookServer.museHooksInstalled() { on.insert(.muse) }
        if HookServer.openCodePluginInstalled() { on.insert(.opencode) }
        if HookServer.ampPluginInstalled() { on.insert(.amp) }
        if HookServer.hermesPluginInstalled() { on.insert(.hermes) }
        if HookServer.statusLineInstalled() { on.insert(.statusLine) }
        snap.claudeOutdated = on.contains(.claudeCode) && HookServer.hooksNeedUpdate()
        snap.klaudeExists = KlaudeHooks.exists()
        #else
        if HookServer.claudeHooksInstalled() { on.insert(.claudeCode) }
        #endif
        snap.installed = on
        snap.tools = KoncluiRecognition.liveTools(maxAge: 0)
        return snap
    }
}
