import Foundation
import Security

// scripts/konclui/test-final-wiring.sh (unit U7): what a key save says (App/KoncluiKeychainSave.swift), and the places in the
// sources where the last hand-offs are wired: the Claude lines on the Flow pages, Undo on the Atalhos reset, the weekly recap
// clear and the Notetaker's deleted line, the dictation keys in Atalhos, one key cap, the voice rows' label column. The
// sources are read as text; nothing runs.
@main
@MainActor
enum KoncluiFinalWiringTests {
    static var failures = 0

    static func check(_ label: String, _ ok: Bool) {
        if ok { print("  ✓ \(label)") } else { print("  ✗ \(label)"); failures += 1 }
    }

    static func read(_ path: String) -> String {
        (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
    }

    static let sources = "NotchBuddy/Sources/App/"

    static func has(_ text: String, _ needle: String) -> Bool { text.contains(needle) }

    static func main() {
        keychain()
        claudeLines()
        undo()
        keysAndVoice()
        agentFiles()
        catalog()
        print(failures == 0 ? "All checks passed" : "\(failures) check(s) failed")
        exit(failures == 0 ? 0 : 1)
    }

    // MARK: A3-28

    static func keychain() {
        print("Saving a key — the Keychain's answer")
        check("a stored key is stored", KoncluiKeychainSave.isStored(errSecSuccess))
        for status in [errSecInteractionNotAllowed, errSecAuthFailed, errSecParam, errSecDuplicateItem, errSecNotAvailable] {
            check("status \(status) is not stored", !KoncluiKeychainSave.isStored(status))
        }
        check("success keeps the screen's own sentence", KoncluiKeychainSave.message(errSecSuccess, saved: "Key saved.") == "Key saved.")
        let refused = KoncluiKeychainSave.message(errSecInteractionNotAllowed, saved: "Key saved.")
        check("a refusal never says the key was saved", !refused.contains("Key saved."))
        check("a refusal starts with the cross the status line paints red", refused.hasPrefix("❌ "))

        let service = read(sources + "ClaudeService.swift")
        check("Keychain.save answers the status of the add", has(service, "static func save(key: String, value: String) -> OSStatus") && has(service, "return SecItemAdd("))
        check("KeychainStore.set passes it on", has(service, "func set(_ key: String, value: String) -> OSStatus") && has(service, "return Keychain.save("))
        check("both stay callable without using the answer", service.components(separatedBy: "@discardableResult").count == 3)

        let settings = read(sources + "SettingsView.swift")
        let calls = settings.components(separatedBy: "\n").filter { $0.contains("KeychainStore.shared.set(") }
        check("SettingsView saves nine keys", calls.count == 8)
        check("none of them drops the answer", calls.allSatisfy { $0.contains("KoncluiKeychainSave.message(") || $0.contains("stored = ") || $0.contains("let stored = ") })
        check("the integrations say what the Keychain refused", has(settings, "koncluiKeychainRefused") && has(settings, "KoncluiKeychainSave.isStored(stored)"))
    }

    // MARK: A1-03, A3-10, A3-27

    static func claudeLines() {
        print("Claude on the Flow pages — one source, one line, one way to the key")
        let words = read(sources + "FlowHubWords.swift"), settings = read(sources + "FlowHubSettings.swift")
        let notes = read(sources + "FlowHubNotes.swift"), lines = read(sources + "KoncluiClaudeLines.swift"), live = read(sources + "KoncluiClaudeLive.swift")
        check("Estilos observes the live source", has(words, "@ObservedObject private var claude = KoncluiClaudeLive.shared"))
        check("Ajustes observes the live source", has(settings, "@ObservedObject private var claude = KoncluiClaudeLive.shared"))
        check("the Notetaker's engine picker observes it", has(notes, "@ObservedObject private var claude = KoncluiClaudeLive.shared"))
        check("the clean-up switch counts Apple Intelligence", has(words, "!FlowCleanup.canClean && !store.cleanupEnabled") && has(words, "if FlowCleanup.canClean {"))
        check("prompt mode and translation still need Claude", has(settings, "!FlowCleanup.hasKey && !store.promptMode") && has(settings, "!FlowCleanup.hasKey && store.translateTo.isEmpty"))
        check("no page keeps the key-only sentence", !has(words, "hub.cleanup-key") && !has(settings, "hub.cleanup-key"))
        check("no page keeps the key-only privacy text", !has(words, "\"hub.cleanup-privacy\"") && !has(settings, "\"flow.ai-privacy\"") && !has(settings, "\"notes.engine-detail\""))
        check("the privacy lines follow the source", has(words, "claude.privacyLine(for: .cleanup)") && has(settings, "claude.privacyLine(for: .prompt)"))
        check("the Notetaker sentence follows the source", has(settings, "claude.notesDetail"))
        check("the connect line shows only while nothing can answer", has(lines, "claude.source(for: feature) == .none"))
        check("the connect line names what to connect", has(lines, "claude.connectLine(for: feature)"))
        check("Estilos shows the connect line for clean-up", has(words, "KoncluiClaudeConnectLine(feature: .cleanup)"))
        check("Ajustes shows it for prompt mode and translation", has(settings, "KoncluiClaudeConnectLine(feature: .prompt)"))
        for feature in ["cleanup", "prompt", "translation", "summary", "correction"] {
            check("the last failure of \(feature) stays under its switch", has(words + settings, "KoncluiClaudeFailureLine(feature: .\(feature))"))
        }
        check("the key button adds the key block before it opens Chat", has(lines, "KoncluiAddedModel.shared.add(.chat, ChatProvider.anthropic.rawValue)"))
        check("the pill's button goes the same way", has(live, "Self.openChatForKey()"))
        check("no page posts the Chat jump by itself", !has(words, "object: \"chat\"") && !has(settings, "object: \"chat\""))
        check("a failure the person must fix offers Chat", has(lines, "report.failure.needsChat"))
    }

    // MARK: A1-10

    static func undo() {
        print("Undo — the last removals")
        let shortcuts = read(sources + "ShortcutsSettingsView.swift"), page = read(sources + "KoncluiSettingsPage.swift")
        let settings = read(sources + "SettingsView.swift"), recap = read(sources + "RecapStore.swift")
        let notes = read(sources + "FlowHubNotes.swift"), taker = read(sources + "NoteTaker.swift")
        check("the Atalhos reset offers Undo", has(shortcuts, "KoncluiShortcutsUndo.resetAll(then: reload)"))
        check("the notch pages carry the Undo bar", has(page, ".koncluiUndoBar()"))
        check("the weekly recap clear offers Undo", has(settings, "RecapStore.shared.snapshotForUndo()") && has(settings, "konclui.undo.recap"))
        check("the recap Undo keeps what was recorded since", has(recap, "saved.turns + data.turns") && has(recap, "saved.decisions + data.decisions"))
        check("the Notetaker deletes a line with Undo", has(notes, "taker.deleteLineWithUndo(") && !has(notes, "taker.deleteLine("))
        check("the Notetaker page carries the Undo bar", has(notes, ".koncluiUndoBar()"))
        check("the line goes back where it was", has(taker, "KoncluiUndoList.putBack(removed, at: index"))
    }

    // MARK: A1-38, A2-29, A1-49

    static func keysAndVoice() {
        print("Keys and voice rows")
        let shortcuts = read(sources + "ShortcutsSettingsView.swift"), settings = read(sources + "SettingsView.swift"), theme = read(sources + "KoncluiTheme.swift")
        check("Atalhos lists the dictation keys", has(shortcuts, "KoncluiDictationShortcuts()"))
        check("the island keys are key caps", has(shortcuts, "KoncluiKeyCap(text: pair.key)"))
        check("the recorder button is a key cap", has(settings, "KoncluiKeyCap(text: isRecording") && has(settings, "recording: isRecording"))
        check("a key cap can show it is recording", has(theme, "var recording = false"))
        check("the voice source has its label", has(settings, "konclui.voice.source"))
        check("the three voice rows share the Language box's label column", settings.components(separatedBy: "frame(width: 130, alignment: .leading)").count - 1 >= 5)
    }

    // MARK: Agent files

    static func agentFiles() {
        print("Agent files — the hub's look")
        for name in ["KoncluiAgentRow", "KoncluiHookControls", "KoncluiPillRowParts", "KoncluiKlaudeRow", "KoncluiOrcaRow"] {
            let text = read(sources + name + ".swift")
            check("\(name): no system grey", !has(text, ".foregroundColor(.secondary)") && !has(text, ".foregroundColor(.primary)"))
            check("\(name): no hard-coded status colour", !has(text, "Color(hex: \"#22C55E\")") && !has(text, "Color(hex: \"#F4505E\")")
                  && !has(text, "Color(hex: \"#FF453A\")") && !has(text, "Color(hex: \"#34D399\")") && !has(text, "Color(hex: \"#F5B83D\")"))
            check("\(name): no text under 11 pt", !has(text, "size: 10") && !has(text, "size: 9,"))
            check("\(name): no bordered style", !has(text, ".borderedProminent") && !has(text, ".buttonStyle(.bordered)"))
        }
        let row = read(sources + "KoncluiAgentRow.swift")
        check("a row says its state with KoncluiStatus", has(row, "KoncluiStatus(tone:") && !has(row, "KoncluiAgentStatusLabel"))
        check("a popover calls the hub's theme", has(row, ".koncluiTheme()") && has(read(sources + "KoncluiPillRowParts.swift"), ".koncluiTheme()"))
    }

    // MARK: Strings

    static func catalog() {
        print("Catalog — the new keys, in the 14 languages")
        let languages = ["ar", "bn", "de", "en", "es", "fr", "hi", "id", "pt-BR", "ru", "th", "tr", "zh-Hans", "zh-Hant"]
        let strings = ((try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: "NotchBuddy/Resources/Localizable.xcstrings")))) as? [String: Any])?["strings"] as? [String: [String: Any]] ?? [:]
        func value(_ key: String, _ lang: String) -> String {
            ((strings[key]?["localizations"] as? [String: [String: [String: String]]])?[lang]?["stringUnit"]?["value"]) ?? ""
        }
        let keys = ["konclui.undo.note-line", "konclui.voice.source", "konclui.keychain.save-failed", "konclui.voice.proxy-slow",
                    "konclui.claude.fail.notes.none", "konclui.claude.fail.notes.refused.key", "konclui.claude.fail.notes.refused.proxy",
                    "konclui.claude.fail.notes.limit", "konclui.claude.fail.notes.busy", "konclui.claude.fail.notes.offline",
                    "konclui.claude.fail.notes.slow", "konclui.claude.fail.notes.reply"]
        for key in keys {
            check(key, languages.allSatisfy { !value(key, $0).isEmpty })
        }
        let dashes = keys.flatMap { key in languages.map { (key, $0) } }.filter { value($0.0, $0.1).contains("—") || value($0.0, $0.1).contains("–") }
        check("no dash used as punctuation", dashes.isEmpty)
        check("the notes sentences never say dictation in English or Portuguese",
              keys.filter { $0.contains(".notes.") }.allSatisfy { !value($0, "en").lowercased().contains("dictation") && !value($0, "pt-BR").lowercased().contains("ditado") })
        // The accessibility sentence shown on Voz no longer carries the advice that Ajustes shows when it applies.
        check("flow.accessibility ends at the path", languages.allSatisfy { value("flow.accessibility", $0) == value("konclui.flow.accessibility", $0) })
    }
}
