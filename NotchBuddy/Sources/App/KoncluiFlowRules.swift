import Foundation

// Koncluí: the small decisions the Flow pages make (Ditado, Estatísticas, Dicionário, Trechos, Estilos, Ajustes do ditado), free
// of SwiftUI and AppKit so scripts/konclui/test-flow-pages.sh can check them with swiftc and FlowText.swift alone: which state
// dictation is in, when the "remove and add again" advice is true, the numbers behind a statistic, which apps the Estilos list
// shows, and how Undo puts an item back.

// MARK: - Dictation

/// What a Flow page says and offers depends on this, not on two booleans read in six places.
enum KoncluiDictationState: Equatable, Sendable {
    case off
    case needsAccess
    case ready

    static func resolve(enabled: Bool, trusted: Bool) -> KoncluiDictationState {
        guard enabled else { return .off }
        return trusted ? .ready : .needsAccess
    }
}

enum KoncluiAccessibilityAdvice {
    /// "Remove Koncluí from the list and add it again" only helps when macOS had trusted this app and no longer does (a new
    /// ad hoc build changes its signature). Someone who never granted the permission needs the plain steps, nothing else.
    static func suggestsRemoveAndAdd(wasTrusted: Bool, trusted: Bool) -> Bool {
        wasTrusted && !trusted
    }
}

// MARK: - Statistics

/// One day of `FlowStats.days`: the records behind every number of the Statistics page and the Ditado totals.
struct KoncluiDayRecord: Equatable, Sendable {
    let key: String
    let words: Int
    let seconds: Double
    let dictations: Int

    var isEmpty: Bool { words == 0 && dictations == 0 && seconds == 0 }
}

enum KoncluiStatKind: Equatable, Sendable {
    case words, dictations, speed, saved, streak
}

enum KoncluiStats {
    /// Words per minute while speaking, or nil when there is nothing to compute it from: the page then says "unavailable"
    /// (docs/konclui/UX.md 2.1), never a computed 0.
    static func speed(words: Int, seconds: Double) -> Int? {
        guard words > 0, seconds >= 1 else { return nil }
        return FlowText.wordsPerMinute(words: words, seconds: seconds)
    }

    /// The days a number is made of, newest first. A streak lists the days that make it; every other number lists the days
    /// of its period that have a dictation. Empty when the number is 0: the sheet then says why.
    static func records(for kind: KoncluiStatKind, days: [KoncluiDayRecord], since: String?, today: Date,
                        calendar: Calendar = .current) -> [KoncluiDayRecord] {
        if kind == .streak { return streakDays(days, today: today, calendar: calendar) }
        return days
            .filter { !$0.isEmpty && (since == nil || $0.key >= since!) }
            .sorted { $0.key > $1.key }
    }

    /// The same days `FlowText.streak` counts (words > 0, ending today or yesterday), with their numbers.
    private static func streakDays(_ days: [KoncluiDayRecord], today: Date, calendar: Calendar) -> [KoncluiDayRecord] {
        let byKey = Dictionary(days.filter { $0.words > 0 }.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        var day = calendar.startOfDay(for: today)
        if byKey[FlowText.dayKey(day, calendar: calendar)] == nil {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return [] }
            day = yesterday
        }
        var out: [KoncluiDayRecord] = []
        while let record = byKey[FlowText.dayKey(day, calendar: calendar)] {
            out.append(record)
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return out
    }

    /// "2026-10-14" back to a date, to write it in the person's own format.
    static func date(fromKey key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

// MARK: - Estilos: which apps the list shows

enum KoncluiStyleApps {
    /// Koncluí's own default rows show only when this Mac has the app; what the person added always shows.
    static func visible<Item>(_ items: [Item], id: (Item) -> String, defaults: Set<String>,
                              installed: (String) -> Bool) -> [Item] {
        items.filter { !defaults.contains(id($0)) || installed(id($0)) }
    }

    /// Apps to add to a list that already exists (Orca, Warp, Ghostty: places people dictate prompts), once each: an app the
    /// person removed is not added again. `offered` keeps what was already settled; an app that is not installed yet is
    /// looked at again next time.
    static func seed(candidates: [String], present: Set<String>, offered: Set<String>,
                     installed: (String) -> Bool) -> (add: [String], offered: Set<String>) {
        var add: [String] = []
        var settled = offered
        for id in candidates where !settled.contains(id) {
            if present.contains(id) {
                settled.insert(id)
            } else if installed(id) {
                add.append(id)
                settled.insert(id)
            }
        }
        return (add, settled)
    }
}

// MARK: - Undo

enum KoncluiUndoList {
    /// `item` back where it was (clamped to the list), unless the same one was added again in the meantime.
    static func putBack<Item>(_ item: Item, at index: Int, in list: [Item], isSame: (Item, Item) -> Bool) -> [Item] {
        guard !list.contains(where: { isSame($0, item) }) else { return list }
        var out = list
        out.insert(item, at: min(max(index, 0), out.count))
        return out
    }
}
