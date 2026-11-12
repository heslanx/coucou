import Foundation

// MARK: - OrcaTerminals
// Koncluí: sessions that run in Orca's terminals share the Orca pill (agent_orca). The hook relay
// sends the terminal's handle and worktree id (ORCA_TERMINAL_HANDLE, ORCA_WORKTREE_ID, nothing else
// from Orca); this remembers them per session, so a click on the pill brings that session's own
// terminal forward (ClaudeHost.switchOrcaTerminal). Pure, no AppKit.

/// Where a session runs inside Orca.
struct OrcaTerminal: Equatable, Sendable {
    var handle: String
    var worktree: String
}

/// The Orca terminal of each live session, and which session the Orca pill opens.
///
/// HookServer writes it on the main actor and the click handlers read it from wherever they
/// run, so every access takes the lock.
final class OrcaTerminals: @unchecked Sendable {
    static let shared = OrcaTerminals()

    /// A session unheard of for this long is dropped, as in PillSessionRegistry.
    static let maxSilence: TimeInterval = 12 * 3600
    /// Upper bound on remembered sessions: a SessionEnd that never arrives must not grow this forever.
    static let maxSessions = 64

    private struct Entry {
        var terminal: OrcaTerminal
        var lastSeen: Date
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private var focusSession: String?
    /// The session each card shows now (Coucou 0.5.8's board: a pill shows one session, others pop out as cards).
    private var taskSessions: [String: String] = [:]

    init() {}

    /// Remembers the terminal an event came from. A payload without a handle (an agent that
    /// does not run in an Orca terminal, or an older relay) leaves what is known untouched.
    func note(session: String, handle: String?, worktree: String?, now: Date = Date()) {
        guard let handle, !handle.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        entries[session] = Entry(terminal: OrcaTerminal(handle: handle, worktree: worktree ?? ""), lastSeen: now)
        prune(now: now)
    }

    /// The session ended: its terminal is no longer the one to open.
    func forget(session: String) {
        lock.lock(); defer { lock.unlock() }
        entries.removeValue(forKey: session)
        if focusSession == session { focusSession = nil }
    }

    /// The session whose terminal the Orca pill opens: the one that owns the pill's card.
    func focus(session: String?) {
        lock.lock(); defer { lock.unlock() }
        focusSession = session
    }

    /// The board put this session on this card (the pill's own, or a popped-out one).
    func shown(task: String, session: String) {
        lock.lock(); defer { lock.unlock() }
        taskSessions[task] = session
        if taskSessions.count > Self.maxSessions * 2 { taskSessions = [task: session] }
    }

    /// The terminal of the session a card shows, if it runs in Orca.
    func terminal(task: String) -> OrcaTerminal? {
        lock.lock(); defer { lock.unlock() }
        return taskSessions[task].flatMap { entries[$0]?.terminal }
    }

    /// The terminal of one session.
    func terminal(session: String) -> OrcaTerminal? {
        lock.lock(); defer { lock.unlock() }
        return entries[session]?.terminal
    }

    /// The terminal the Orca pill opens, nil when its session did not report one.
    var focusTerminal: OrcaTerminal? {
        lock.lock(); defer { lock.unlock() }
        return focusSession.flatMap { entries[$0]?.terminal }
    }

    private func prune(now: Date) {
        entries = entries.filter { now.timeIntervalSince($0.value.lastSeen) < Self.maxSilence }
        guard entries.count > Self.maxSessions else { return }
        let oldest = entries.sorted { $0.value.lastSeen < $1.value.lastSeen }
            .prefix(entries.count - Self.maxSessions)
        for (key, _) in oldest { entries.removeValue(forKey: key) }
    }
}
