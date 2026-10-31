import AppKit

extension TerminalTarget {
    /// Brings the session's terminal to the front: the app the session runs in first,
    /// then the first running known terminal. Returns false if none is running.
    @discardableResult
    static func activate(sessionBundleId: String?, task: String? = nil) -> Bool {
        let apps = NSWorkspace.shared.runningApplications
        let running = Set(apps.compactMap(\.bundleIdentifier))
        guard let id = pick(sessionBundleId: sessionBundleId, running: running),
              let app = apps.first(where: { $0.bundleIdentifier == id }) else { return false }
        // Koncluí: Orca holds many terminals, so it also opens the one the clicked card's session runs in.
        if id == ClaudeHost.orcaBundleId {
            let terminal = task.flatMap { OrcaTerminals.shared.terminal(task: $0) } ?? OrcaTerminals.shared.focusTerminal
            ClaudeHost.switchOrcaTerminal(handle: terminal?.handle)
        }
        return app.activate(options: .activateIgnoringOtherApps)
    }
}
