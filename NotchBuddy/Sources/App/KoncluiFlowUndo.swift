#if !APPSTORE
import Foundation

// Koncluí: every removal on the Flow pages offers Undo (docs/konclui/UX.md 1.5). The page calls one of these instead of
// removing the item itself; the notice shows in `KoncluiUndoCenter`. What was removed stays in memory for ten seconds and
// goes with the notice.

extension FlowStore {
    func removeWordWithUndo(_ word: String) {
        guard let index = words.firstIndex(of: word) else { return }
        words.remove(at: index)
        KoncluiUndoCenter.shared.offer(String(localized: "konclui.undo.word")) { [self] in
            words = KoncluiUndoList.putBack(word, at: index, in: words) { $0.caseInsensitiveCompare($1) == .orderedSame }
        }
    }

    func removeReplacementWithUndo(_ replacement: FlowReplacement) {
        guard let index = replacements.firstIndex(where: { $0.id == replacement.id }) else { return }
        replacements.remove(at: index)
        KoncluiUndoCenter.shared.offer(String(localized: "konclui.undo.replacement")) { [self] in
            replacements = KoncluiUndoList.putBack(replacement, at: index, in: replacements) {
                $0.id == $1.id || $0.from.caseInsensitiveCompare($1.from) == .orderedSame
            }
        }
    }

    func removeSnippetWithUndo(_ snippet: FlowSnippet) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        snippets.remove(at: index)
        KoncluiUndoCenter.shared.offer(String(localized: "konclui.undo.snippet")) { [self] in
            snippets = KoncluiUndoList.putBack(snippet, at: index, in: snippets) { $0.id == $1.id }
        }
    }

    func removeAppStyleWithUndo(_ style: FlowAppStyle) {
        guard let index = appStyles.firstIndex(where: { $0.bundleID == style.bundleID }) else { return }
        appStyles.remove(at: index)
        KoncluiUndoCenter.shared.offer(String(localized: "konclui.undo.app-style")) { [self] in
            appStyles = KoncluiUndoList.putBack(style, at: index, in: appStyles) { $0.bundleID == $1.bundleID }
        }
    }

    func deleteWithUndo(_ entry: FlowEntry) {
        guard history.contains(where: { $0.id == entry.id }) else { return }
        delete(entry)
        KoncluiUndoCenter.shared.offer(String(localized: "konclui.undo.dictation")) { [self] in restoreHistory([entry]) }
    }

    /// "Erase the history": the numbers stay, so only the entries come back.
    func clearHistoryWithUndo() {
        let erased = history
        clearHistory()
        guard !erased.isEmpty else { return }
        KoncluiUndoCenter.shared.offer(String(localized: "konclui.undo.history")) { [self] in restoreHistory(erased) }
    }

    /// "Erase everything": the entries and the numbers come back together.
    func clearEverythingWithUndo() {
        let erasedHistory = history
        let erasedStats = stats
        clearEverything()
        guard !erasedHistory.isEmpty || !erasedStats.days.isEmpty else { return }
        KoncluiUndoCenter.shared.offer(String(localized: "konclui.undo.everything")) { [self] in
            restoreHistory(erasedHistory)
            restoreStats(erasedStats)
        }
    }
}

/// "Reset all to defaults" on the Shortcuts page, with Undo: Undo puts every key and switch back as it was.
enum KoncluiShortcutsUndo {
    @MainActor static func resetAll(then refresh: @escaping () -> Void) {
        let before = ShortcutAction.allCases.map { (action: $0, spec: ShortcutLogic.hotKey(for: $0), enabled: ShortcutLogic.isEnabled($0)) }
        for action in ShortcutAction.allCases {
            ShortcutLogic.resetToDefault(action)
            HotKeyCenter.shared.reregister(action)
        }
        refresh()
        KoncluiUndoCenter.shared.offer(String(localized: "konclui.undo.shortcuts")) {
            for saved in before {
                ShortcutLogic.save(saved.spec, for: saved.action)
                ShortcutLogic.setEnabled(saved.enabled, for: saved.action)
                HotKeyCenter.shared.reregister(saved.action)
            }
            refresh()
        }
    }
}
#endif
