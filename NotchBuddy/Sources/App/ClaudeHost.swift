import AppKit

// MARK: - ClaudeHost
//
// The app a Claude Code session runs in, from the hook payload's term_program /
// bundle_id. VS Code sessions keep the original "VS Code" pill; sessions from a
// terminal also route to integration_claude and the pill says "Claude Code".

struct ClaudeHost: Equatable {
    let bundleId: String
    let name: String

    /// UserDefaults key: show terminal sessions' questions and permission requests in the
    /// notch (they then wait for the notch). Off by default: the terminal asks itself.
    static let terminalCardsKey = "terminalCardsEnabled"
    static var terminalCardsEnabled: Bool { UserDefaults.standard.bool(forKey: terminalCardsKey) }

    /// Terminals (and agent apps like Conductor) accepted for Claude Code sessions.
    /// Keyed by bundle id; the second
    /// table maps TERM_PROGRAM for hooks that run without __CFBundleIdentifier.
    private static let terminals: [String: String] = [
        "dev.warp.Warp-Stable":       "Warp",
        "dev.warp.Warp-Preview":      "Warp",
        "com.apple.Terminal":         "Terminal",
        "com.googlecode.iterm2":      "iTerm",
        "com.mitchellh.ghostty":      "Ghostty",
        "net.kovidgoyal.kitty":       "kitty",
        "org.alacritty":              "Alacritty",
        "com.github.wez.wezterm":     "WezTerm",
        "co.zeit.hyper":              "Hyper",
        "dev.zed.Zed":                "Zed",
        "com.cmuxterm.app":           "cmux",    // sets TERM_PROGRAM=ghostty: the bundle id decides
        "com.stablyai.orca":          "Orca",
        "com.conductor.app":          "Conductor", // runs Claude Code with no TERM_PROGRAM
    ]
    private static let termPrograms: [String: String] = [
        "warpterminal":   "dev.warp.Warp-Stable",
        "apple_terminal": "com.apple.Terminal",
        "iterm.app":      "com.googlecode.iterm2",
        "ghostty":        "com.mitchellh.ghostty",
        "kitty":          "net.kovidgoyal.kitty",
        "alacritty":      "org.alacritty",
        "wezterm":        "com.github.wez.wezterm",
        "hyper":          "co.zeit.hyper",
        "zed":            "dev.zed.Zed",
        "orca":           "com.stablyai.orca",
    ]

    /// The terminal a session runs in, or nil when it isn't a known terminal.
    static func terminal(termProgram: String, bundleId: String) -> ClaudeHost? {
        if let name = terminals[bundleId] { return ClaudeHost(bundleId: bundleId, name: name) }
        if let id = termPrograms[termProgram.lowercased()], let name = terminals[id] {
            return ClaudeHost(bundleId: id, name: name)
        }
        return nil
    }

    // MARK: - Orca
    // Orca (stablyai) runs agents in its own terminals. Koncluí keeps those sessions on their own
    // pill and a click brings that exact terminal forward through Orca's CLI.

    static let orcaBundleId = "com.stablyai.orca"
    static let orcaPillId = "agent_orca"

    /// True for a session started in one of Orca's terminals: TERM_PROGRAM=Orca, or Orca's bundle id
    /// (a tmux inside Orca no longer says Orca in TERM_PROGRAM).
    static func isOrca(termProgram: String, bundleId: String) -> Bool {
        termProgram.lowercased() == "orca" || bundleId == orcaBundleId
    }

    /// The arguments of `orca terminal switch --terminal <handle>`, or nil when `handle` is not
    /// a plausible terminal handle (Orca issues `term_<uuid>`: letters, digits and `_-.:`, starting
    /// with a letter or digit so it can never pass for an option).
    static func orcaSwitchArguments(handle: String?) -> [String]? {
        guard let handle else { return nil }
        let bytes = Array(handle.utf8)
        func alphanumeric(_ b: UInt8) -> Bool {
            (0x30...0x39).contains(b) || (0x41...0x5A).contains(b) || (0x61...0x7A).contains(b)
        }
        guard (1...128).contains(bytes.count), alphanumeric(bytes[0]),
              bytes.allSatisfy({ alphanumeric($0) || [0x5F, 0x2D, 0x2E, 0x3A].contains($0) })
        else { return nil }
        return ["terminal", "switch", "--terminal", handle]
    }

    /// Orca's command-line tool inside the app bundle, or nil when Orca is not installed.
    static func orcaCLI() -> URL? {
        let fm = FileManager.default
        var apps: [URL] = []
        #if !APPSTORE
        if let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: orcaBundleId) { apps.append(installed) }
        #endif
        apps.append(URL(fileURLWithPath: "/Applications/Orca.app"))
        for app in apps {
            let cli = app.appendingPathComponent("Contents/Resources/bin/orca")
            if fm.isExecutableFile(atPath: cli.path) { return cli }
        }
        return nil
    }

    /// Asks Orca to bring terminal `handle` to the foreground: `orca terminal switch --terminal <handle>`,
    /// off the main thread and given a few seconds. Does nothing without a usable handle or CLI;
    /// the caller activates the app itself.
    static func switchOrcaTerminal(handle: String?, timeout: TimeInterval = 5) {
        #if !APPSTORE
        guard let arguments = orcaSwitchArguments(handle: handle), let cli = orcaCLI() else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = cli
            process.arguments = arguments
            // The CLI needs no Orca variables (and must never see a hook token): a bare environment.
            process.environment = ["HOME": NSHomeDirectory(), "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return }
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
            if process.isRunning { process.terminate() }
        }
        #endif
    }

    /// Activates Orca and, given the session's terminal handle, switches to that terminal.
    static func focusOrca(handle: String?) {
        activate(orcaBundleId)
        switchOrcaTerminal(handle: handle)
    }

    /// The app name for a task's host; nil host means VS Code (the original routing).
    static func name(for hostBundleId: String?) -> String {
        guard let id = hostBundleId, let name = terminals[id] else { return "VS Code" }
        return name
    }

    /// Pill label for integration_claude: "VS Code" for editor sessions, "Claude Code" otherwise.
    static func pillName(hostApp: String?) -> String {
        hostApp == nil ? "VS Code" : "Claude Code"
    }

    /// Brings the session's terminal forward (launching it if needed). false when not a terminal host.
    @discardableResult
    static func activate(_ hostBundleId: String?) -> Bool {
        guard let id = hostBundleId, terminals[id] != nil else { return false }
        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == id }) {
            running.activate()
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil)
        }
        return true
    }
}
