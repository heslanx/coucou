import Foundation

// scripts/konclui/test-flow-pages.sh: the rules of the Flow pages (App/KoncluiFlowRules.swift, with FlowText.swift), and the places
// in the sources that carry them: every removal offers Undo, no page promises a key while dictation is off, a disabled list says
// why, the strings exist in 14 languages.
@main
enum KoncluiFlowPagesTests {
    static var failures = 0

    static func check(_ label: String, _ ok: Bool) {
        if ok { print("  ✓ \(label)") } else { print("  ✗ \(label)"); failures += 1 }
    }

    static func read(_ path: String) -> String {
        (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
    }

    static let sources = "NotchBuddy/Sources/App/"

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    static func date(_ key: String) -> Date { KoncluiStats.date(fromKey: key, calendar: calendar)! }

    static func day(_ key: String, words: Int, seconds: Double = 60, dictations: Int = 1) -> KoncluiDayRecord {
        KoncluiDayRecord(key: key, words: words, seconds: seconds, dictations: dictations)
    }

    static func main() {
        dictationState()
        accessibilityAdvice()
        speed()
        records()
        streak()
        styleApps()
        undoList()
        pageSources()
        catalog()
        if failures == 0 { print("PASS") } else { print("FAIL: \(failures)"); exit(1) }
    }

    static func dictationState() {
        print("Dictation — off, needs the permission, ready")
        check("off whatever the permission", KoncluiDictationState.resolve(enabled: false, trusted: true) == .off
              && KoncluiDictationState.resolve(enabled: false, trusted: false) == .off)
        check("on without the permission", KoncluiDictationState.resolve(enabled: true, trusted: false) == .needsAccess)
        check("on with the permission", KoncluiDictationState.resolve(enabled: true, trusted: true) == .ready)
    }

    static func accessibilityAdvice() {
        print("Accessibility — remove and add again only helps when macOS once trusted this app")
        check("never trusted: plain steps only", !KoncluiAccessibilityAdvice.suggestsRemoveAndAdd(wasTrusted: false, trusted: false))
        check("trusted before, not now: remove and add again", KoncluiAccessibilityAdvice.suggestsRemoveAndAdd(wasTrusted: true, trusted: false))
        check("trusted now: no advice", !KoncluiAccessibilityAdvice.suggestsRemoveAndAdd(wasTrusted: true, trusted: true))
    }

    static func speed() {
        print("Speed — unavailable, never a computed 0")
        check("no words: unavailable", KoncluiStats.speed(words: 0, seconds: 120) == nil)
        check("no speaking time: unavailable", KoncluiStats.speed(words: 50, seconds: 0) == nil)
        check("under a second of speech: unavailable", KoncluiStats.speed(words: 3, seconds: 0.5) == nil)
        check("120 words in 60 s is 120 per minute", KoncluiStats.speed(words: 120, seconds: 60) == 120)
    }

    static func records() {
        print("Records — the days behind a number, zero included")
        let days = [day("2026-10-14", words: 100, seconds: 50, dictations: 2), day("2026-10-02", words: 40), day("2026-09-01", words: 70),
                    KoncluiDayRecord(key: "2026-10-10", words: 0, seconds: 0, dictations: 0)]
        let month = KoncluiStats.records(for: .words, days: days, since: "2026-09-15", today: date("2026-10-14"), calendar: calendar)
        check("the period's days, newest first", month.map(\.key) == ["2026-10-14", "2026-10-02"])
        check("an empty day is not a record", !month.contains { $0.key == "2026-10-10" })
        check("the words of the records add up to the number", month.reduce(0) { $0 + $1.words } == 140)
        let all = KoncluiStats.records(for: .dictations, days: days, since: nil, today: date("2026-10-14"), calendar: calendar)
        check("all time lists every day with a dictation", all.map(\.key) == ["2026-10-14", "2026-10-02", "2026-09-01"])
        check("the dictations of the records add up", all.reduce(0) { $0 + $1.dictations } == 4)
        let none = KoncluiStats.records(for: .words, days: [], since: nil, today: date("2026-10-14"), calendar: calendar)
        check("nothing dictated: no records (the sheet says why)", none.isEmpty)
        let outside = KoncluiStats.records(for: .speed, days: [day("2026-01-01", words: 10)], since: "2026-10-01", today: date("2026-10-14"), calendar: calendar)
        check("a period with no day in it: no records", outside.isEmpty)
        check("a day key reads back as that day", KoncluiStats.date(fromKey: "2026-10-14", calendar: calendar).map { calendar.component(.day, from: $0) } == 14)
        check("a bad key reads as nil", KoncluiStats.date(fromKey: "nope", calendar: calendar) == nil)
    }

    static func streak() {
        print("Streak — the same days FlowText counts")
        let today = date("2026-10-14")
        let days = [day("2026-10-14", words: 5), day("2026-10-13", words: 5), day("2026-10-12", words: 5), day("2026-10-10", words: 5)]
        let counted = KoncluiStats.records(for: .streak, days: days, since: nil, today: today, calendar: calendar)
        check("three days in a row, ending today", counted.map(\.key) == ["2026-10-14", "2026-10-13", "2026-10-12"])
        check("it matches FlowText.streak", counted.count == FlowText.streak(days: Set(days.map(\.key)), today: today, calendar: calendar))
        let late = KoncluiStats.records(for: .streak, days: days, since: nil, today: date("2026-10-15"), calendar: calendar)
        check("no dictation yet today: the streak ends yesterday", late.count == 3 && late.first?.key == "2026-10-14")
        let broken = KoncluiStats.records(for: .streak, days: days, since: nil, today: date("2026-10-17"), calendar: calendar)
        check("two days without: no streak, no records", broken.isEmpty)
        let empty = KoncluiStats.records(for: .streak, days: [], since: nil, today: today, calendar: calendar)
        check("no days at all: no streak", empty.isEmpty)
        let ignored = KoncluiStats.records(for: .streak, days: [day("2026-10-14", words: 0, seconds: 3, dictations: 1)], since: nil, today: today, calendar: calendar)
        check("a day with no words does not make a streak (as FlowText)", ignored.isEmpty)
    }

    static func styleApps() {
        print("Estilos — the apps this Mac has")
        let installed: Set<String> = ["com.apple.mail", "com.stablyai.orca", "com.custom.added"]
        let defaults: Set<String> = ["com.apple.mail", "net.whatsapp.WhatsApp", "com.stablyai.orca"]
        let stored = ["com.apple.mail", "net.whatsapp.WhatsApp", "com.stablyai.orca", "com.custom.added", "com.custom.gone"]
        let shown = KoncluiStyleApps.visible(stored, id: { $0 }, defaults: defaults, installed: { installed.contains($0) })
        check("a default row shows only when the app is here", shown == ["com.apple.mail", "com.stablyai.orca", "com.custom.added", "com.custom.gone"])
        check("what the person added shows even when the app is gone", shown.contains("com.custom.gone"))

        let first = KoncluiStyleApps.seed(candidates: ["com.stablyai.orca", "dev.warp.Warp-Stable"], present: ["com.apple.mail"], offered: [],
                                          installed: { installed.contains($0) })
        check("an installed app is added once", first.add == ["com.stablyai.orca"])
        check("an app that is not installed is looked at again next time", !first.offered.contains("dev.warp.Warp-Stable"))
        let again = KoncluiStyleApps.seed(candidates: ["com.stablyai.orca"], present: [], offered: first.offered, installed: { installed.contains($0) })
        check("an app the person removed is not added again", again.add.isEmpty)
        let existing = KoncluiStyleApps.seed(candidates: ["com.stablyai.orca"], present: ["com.stablyai.orca"], offered: [], installed: { _ in true })
        check("an app already in the list is not added twice, and counts as offered", existing.add.isEmpty && existing.offered.contains("com.stablyai.orca"))
    }

    static func undoList() {
        print("Undo — an item goes back where it was")
        check("back at its index", KoncluiUndoList.putBack("b", at: 1, in: ["a", "c"], isSame: ==) == ["a", "b", "c"])
        check("an index past the end is clamped", KoncluiUndoList.putBack("z", at: 9, in: ["a"], isSame: ==) == ["a", "z"])
        check("a negative index is clamped", KoncluiUndoList.putBack("z", at: -2, in: ["a"], isSame: ==) == ["z", "a"])
        check("added again meanwhile: not duplicated", KoncluiUndoList.putBack("A", at: 0, in: ["a"], isSame: { $0.lowercased() == $1.lowercased() }) == ["a"])
    }

    // MARK: Where the rules live in the sources

    static func pageSources() {
        print("Sources — the Flow pages carry the rules")
        let words = read(sources + "FlowHubWords.swift"), home = read(sources + "FlowHubHome.swift"), settings = read(sources + "FlowHubSettings.swift")
        let insights = read(sources + "FlowHubInsights.swift"), store = read(sources + "FlowStore.swift"), whatsapp = read(sources + "KoncluiWhatsAppSection.swift")
        func has(_ text: String, _ needle: String) -> Bool { text.contains(needle) }

        check("no word is removed without Undo", !has(words, "store.words.removeAll") && has(words, "removeWordWithUndo"))
        check("no replacement is removed without Undo", !has(words, "store.replacements.removeAll") && has(words, "removeReplacementWithUndo"))
        check("no snippet is removed without Undo", !has(words, "store.snippets.removeAll") && has(words, "removeSnippetWithUndo"))
        check("no app style is removed without Undo", !has(words, "store.appStyles.removeAll") && has(words, "removeAppStyleWithUndo"))
        check("a dictation is deleted with Undo", !has(home, "FlowStore.shared.delete(entry)") && has(home, "deleteWithUndo"))
        check("the history is cleared with Undo", !has(settings, "store.clearHistory()") && has(settings, "clearHistoryWithUndo"))
        check("everything is cleared with Undo", !has(settings, "store.clearEverything()") && has(settings, "clearEverythingWithUndo"))
        for (name, text) in [("Dictionary and Snippets and Estilos", words), ("Ditado", home), ("Ajustes do ditado", settings), ("Estatísticas", insights)] {
            check("\(name) show the Undo bar", has(text, ".koncluiUndoBar()"))
        }
        check("the WhatsApp block uses the shared Undo bar", has(whatsapp, "KoncluiUndoBar(") && !has(whatsapp, "private struct UndoNotice"))

        check("Ditado never promises a key while dictation is off", !has(home, "hub.setup %@") && has(home, "konclui.home.hint-off"))
        check("an empty history says dictation is off first", has(home, "konclui.home.empty-off"))
        check("no \"unlimited and free\" in the totals", !has(home, "hub.unlimited"))
        check("words per minute reads unavailable without data", has(home, "KoncluiStats.speed") && has(insights, "KoncluiStats.speed"))
        check("the totals and the stat cards open their records", has(home, "KoncluiStatDoor(") && has(insights, "KoncluiStatDoor("))
        check("an empty chart says why and leads to the next step", has(insights, "chartEmpty") && has(insights, "KoncluiDictationNextStep"))
        check("the empty Dictionary and Snippets lead to turning dictation on", words.components(separatedBy: "KoncluiDictationNextStep").count == 3)

        check("the per-app list is disabled, not only dimmed, and says why", has(words, ".disabled(!store.cleanupEnabled)") && has(words, "stylesOff"))
        check("the styles are explained next to the choice", has(words, "KoncluiStylePicker") && !has(words, "ForEach(FlowStyle.allCases)"))
        check("the list shows the apps this Mac has", has(words, "KoncluiStyleApps.visible") && has(store, "seedInstalledAppStyles()"))

        check("the Accessibility card shows only for the state that needs it", has(settings, "flow.koncluiState == .needsAccess") && !has(settings, "hub.settings.permission"))
        check("remove and add again follows the memory of a past permission", has(settings, "suggestsRemoveAndAdd"))
        check("the dictation keys link to Atalhos", has(settings, "show(.shortcuts)"))
        check("the sample data never reaches the files", has(store, "guard !loading, !readOnly"))
    }

    // MARK: Strings

    static func catalog() {
        print("Catalog — every new key, in the 14 languages, with the same arguments")
        let languages = ["ar", "bn", "de", "en", "es", "fr", "hi", "id", "pt-BR", "ru", "th", "tr", "zh-Hans", "zh-Hant"]
        let strings = ((try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: "NotchBuddy/Resources/Localizable.xcstrings")))) as? [String: Any])?["strings"] as? [String: [String: Any]] ?? [:]
        func value(_ key: String, _ lang: String) -> String {
            ((strings[key]?["localizations"] as? [String: [String: [String: String]]])?[lang]?["stringUnit"]?["value"]) ?? ""
        }
        // Every konclui.* key the Flow files and the new views name.
        let files = ["FlowHubWords", "FlowHubHome", "FlowHubInsights", "FlowHubSettings", "FlowStore", "KoncluiUndo", "KoncluiFlowUndo", "KoncluiFlowStyles",
                     "KoncluiFlowState", "KoncluiStatDoor", "KoncluiDictationShortcuts", "KoncluiDictationDoor"].map { read(sources + $0 + ".swift") }.joined(separator: "\n")
        let regex = try! NSRegularExpression(pattern: #"["\(]((?:konclui)\.[a-z0-9.\-]+(?: %@)?)""#)
        let ns = files as NSString
        var keys = Set<String>()
        for m in regex.matches(in: files, range: NSRange(location: 0, length: ns.length)) {
            let key = ns.substring(with: m.range(at: 1))
            if !key.hasPrefix("konclui.debug.") { keys.insert(key) }   // launch arguments, not strings
        }
        check("the sources name at least 30 keys", keys.count >= 30)
        for key in keys.sorted() {
            check(key, Set((strings[key]?["localizations"] as? [String: Any] ?? [:]).keys) == Set(languages))
        }
        func arguments(_ text: String) -> [String] {
            var out: [String] = []
            let scanner = text as NSString
            let regex = try! NSRegularExpression(pattern: #"%(?:\d+\$)?(?:ll)?[@d]"#)
            for m in regex.matches(in: text, range: NSRange(location: 0, length: scanner.length)) { out.append(scanner.substring(with: m.range)) }
            return out.sorted()
        }
        check("every language keeps the English arguments",
              keys.allSatisfy { key in languages.allSatisfy { arguments(value(key, $0)) == arguments(value(key, "en")) } })
        check("no dash in a Flow string (UX.md, microcopy)",
              keys.allSatisfy { key in languages.allSatisfy { !value(key, $0).contains("—") && !value(key, $0).contains("–") } })
        check("Undo is the same word the WhatsApp block uses",
              languages.allSatisfy { value("konclui.undo", $0) == value("konclui.whatsapp.undo", $0) })
    }
}
