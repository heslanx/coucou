import Foundation

// Koncluí: the small decisions the notch pages (Geral, Abas ativas, Agentes) make, free of SwiftUI so
// scripts/konclui/test-page-rules.sh can check them: which control is the primary one for an agent's state, when the tab
// limit blocks a switch and what it offers, where the demo goes, when the "connect your agents" card shows, and whether
// Orca's approvals reach the notch.

// MARK: - An agent's install popover

enum KoncluiHookActions {
    enum Primary: Equatable, Sendable {
        /// Not installed: the one thing to do.
        case install
        /// Installed by an older Koncluí: the hooks must be rewritten.
        case update
    }

    /// The popover's controls for a state. The primary is the only filled button; "Uninstall" is the quiet one and only
    /// exists once there is something to take back (docs/konclui/UX.md, 2.8: one primary action per region).
    struct Controls: Equatable, Sendable {
        let primary: Primary?
        let canUninstall: Bool
    }

    static func controls(installed: Bool, outdated: Bool) -> Controls {
        guard installed else { return Controls(primary: .install, canUninstall: false) }
        return Controls(primary: outdated ? .update : nil, canUninstall: true)
    }
}

// MARK: - The four-tab limit

enum KoncluiTabLimit {
    static let maximum = 4

    /// A switch is blocked when four tabs are on, it is off, and it is not the main tab (which never counts).
    static func blocks(activeCount: Int, isOn: Bool, isMain: Bool) -> Bool {
        activeCount >= maximum && !isOn && !isMain
    }

    /// The tabs a person can turn off to free a place: the active ones except the main tab, in the order they are listed.
    static func releasable(active: Set<String>, main: String, order: [String]) -> [String] {
        order.filter { active.contains($0) && $0 != main }
    }
}

// MARK: - Geral

enum KoncluiGeneralPage {
    /// The demo is a first-run tool: first while nothing is connected, at the end once an agent is.
    static func demoComesLast(anyAgentConnected: Bool) -> Bool { anyAgentConnected }

    /// The "Connect your agents" card lists agents that were found and are not connected; none, no card.
    static func showsConnectCard(waiting: [KoncluiHookTarget]) -> Bool { !waiting.isEmpty }

    /// The agents named in the card's sentence, at most `limit`, then "and N more" is not worth a string: the rest are one click away.
    static func namesInCard(_ waiting: [KoncluiHookTarget], limit: Int = 4) -> [String] {
        Array(waiting.prefix(limit)).map(\.name)
    }

    /// "Remove Koncluí's integrations" only exists when Koncluí wrote something.
    static func offersRemoval(_ snapshot: KoncluiHookSnapshot) -> Bool { !snapshot.removable.isEmpty }
}

// MARK: - Orca

/// Whether a permission request or a question from an Orca terminal shows in the notch. Other terminals (Warp, iTerm…)
/// keep their own switch, off by default, because every session there would wait on the notch. Orca is where the
/// owner runs many agents at once: the notch is the one place that sees them all, so it ships on, with a switch.
enum KoncluiOrcaCards {
    static let key = "konclui.orcaCards"

    /// On unless the person turned it off.
    static func enabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) as? Bool ?? true
    }

    /// The decision HookServer takes for a session that runs in a terminal.
    static func showsInNotch(isOrca: Bool, otherTerminalsOn: Bool, defaults: UserDefaults = .standard) -> Bool {
        otherTerminalsOn || (isOrca && enabled(defaults))
    }
}

// MARK: - DEBUG screenshots

/// Launch arguments that draw a state a Mac does not have, for screenshots. They only change what is drawn: nothing is written,
/// nothing is installed. In a release build every answer is nil.
///   -konclui.debug.connected NO|YES            Geral as on a Mac with nothing connected (NO) or with an agent connected (YES)
///   -konclui.debug.connectCard claudeCode,codex   the "Connect your agents" card with these agents waiting
///   -konclui.debug.tabLimit agent_codex        Active pills as if four tabs were on, with that row's popover open
///   -konclui.debug.removeIntegrations YES      Geral's removal popover, with every preview built (a read)
enum KoncluiPageDebug {
    static var connected: Bool? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "konclui.debug.connected").map { $0.uppercased().hasPrefix("Y") }
        #else
        nil
        #endif
    }

    static var waiting: [KoncluiHookTarget]? {
        #if DEBUG
        targets(UserDefaults.standard.string(forKey: "konclui.debug.connectCard"))
        #else
        nil
        #endif
    }

    static var limitPill: String? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "konclui.debug.tabLimit").flatMap { $0.isEmpty ? nil : $0 }
        #else
        nil
        #endif
    }

    /// `claudeCode,codex` into targets; nil when the value is missing or names nothing known.
    static func targets(_ raw: String?) -> [KoncluiHookTarget]? {
        guard let raw, !raw.isEmpty else { return nil }
        let found = raw.split(separator: ",").compactMap { KoncluiHookTarget(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
        return found.isEmpty ? nil : found
    }
}
