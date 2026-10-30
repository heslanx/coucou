#if !APPSTORE
import AppKit
import SwiftUI

/// Coucou Flow → Dictionary: the words Coucou must always spell right, and the replacements.
struct HubDictionaryPage: View {
    @ObservedObject private var store = FlowStore.shared
    @ObservedObject private var flow = FlowDictation.shared   // Koncluí: an empty dictionary leads to turning dictation on
    @State private var newWord = ""
    @State private var from = ""
    @State private var to = ""
    /// Koncluí: what a click on "Adicionar" found missing. The button stays enabled and says so under the field (UX.md 1.1).
    @State private var missing: KoncluiMissing?

    var body: some View {
        HubPageScaffold(title: String(localized: "hub.page.dictionary"),
                        subtitle: String(localized: "hub.dictionary-sub")) {
            HubCard {
                HStack(alignment: .top, spacing: 8) {
                    HubField(placeholder: String(localized: "hub.word-placeholder"), text: $newWord, onSubmit: addWord,
                             hint: missing == .word ? String(localized: "konclui.hint.word") : nil)
                    Button(String(localized: "konclui.hub.add-word"), action: addWord)
                        .buttonStyle(HubButtonStyle(primary: true))
                }
                if store.words.isEmpty {
                    HubEmptyState(text: String(localized: "hub.words-empty"), state: .idle, color: "#A78BFA")
                    if flow.koncluiState != .ready { KoncluiDictationNextStep(centered: true) }   // Koncluí: A3-39
                } else {
                    HubWrap(spacing: 8) {
                        ForEach(store.words, id: \.self) { word in
                            HubChip(text: word) { store.removeWordWithUndo(word) }   // Koncluí: Undo (UX.md 1.5)
                        }
                    }
                }
            }

            HubLabel(String(localized: "hub.replacements"))
            HubCard {
                Text("hub.replacements-sub")
                    .font(.system(size: 13))
                    .foregroundColor(HubTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: 8) {
                    HubField(placeholder: String(localized: "hub.heard-placeholder"), text: $from, onSubmit: addReplacement,
                             hint: missing == .heard ? String(localized: "konclui.hint.heard") : nil)
                    Image(systemName: "arrow.right")
                        .foregroundColor(HubTheme.muted)
                        .frame(height: 34)
                    HubField(placeholder: String(localized: "hub.written-placeholder"), text: $to, onSubmit: addReplacement,
                             hint: missing == .written ? String(localized: "konclui.hint.written") : nil)
                    Button(String(localized: "konclui.hub.add-replacement"), action: addReplacement)
                        .buttonStyle(HubButtonStyle(primary: true))
                }
                ForEach(store.replacements) { replacement in
                    HubDivider()
                    HStack(spacing: 12) {
                        Text(replacement.from)
                            .font(.system(size: 13))
                            .foregroundColor(HubTheme.secondary)
                            .frame(width: 200, alignment: .leading)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11))
                            .foregroundColor(HubTheme.muted)
                        Text(replacement.to)
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        HubIconButton(symbol: "trash", help: String(localized: "hub.delete")) {
                            store.removeReplacementWithUndo(replacement)   // Koncluí: Undo
                        }
                    }
                }
            }
        }
        .koncluiUndoBar()
        // Koncluí: the line under a field goes away as soon as the person starts to fix it.
        .onChange(of: newWord) { _, _ in if missing == .word { missing = nil } }
        .onChange(of: from) { _, _ in if missing == .heard { missing = nil } }
        .onChange(of: to) { _, _ in if missing == .written { missing = nil } }
    }

    private func addWord() {
        guard !newWord.trimmingCharacters(in: .whitespaces).isEmpty else { missing = .word; return }
        missing = nil
        store.addWord(newWord)
        newWord = ""
    }

    private func addReplacement() {
        if from.trimmingCharacters(in: .whitespaces).isEmpty { missing = .heard; return }
        if to.trimmingCharacters(in: .whitespaces).isEmpty { missing = .written; return }
        missing = nil
        store.addReplacement(from: from, to: to)
        from = ""
        to = ""
    }
}

/// Koncluí: the field a blocked "Adicionar" or "Salvar" is waiting for.
private enum KoncluiMissing { case word, heard, written, trigger, text }

/// A word of the dictionary, with its × to remove it.
private struct HubChip: View {
    let text: String
    let remove: () -> Void
    @State private var hover = false
    @Environment(\.colorSchemeContrast) private var contrast   // Koncluí

    var body: some View {
        HStack(spacing: 6) {
            Text(text).font(.system(size: 13))
            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(hover ? HubTheme.text : HubTheme.muted)
            }
            .buttonStyle(.plain)
            .koncluiPointer()   // Koncluí
            .accessibilityLabel(String(localized: "hub.delete"))
        }
        .padding(.leading, 11)
        .padding(.trailing, 9)
        .frame(height: 30)
        .background(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous).fill(HubTheme.field))
        .overlay(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous).strokeBorder(KoncluiTheme.controlStroke(contrast)))
        .onHover { hover = $0 }
    }
}

// MARK: - Snippets

/// Coucou Flow → Snippets: say the trigger, Coucou pastes the whole text.
struct HubSnippetsPage: View {
    @ObservedObject private var store = FlowStore.shared
    @ObservedObject private var flow = FlowDictation.shared   // Koncluí: an empty list leads to turning dictation on
    @State private var trigger = ""
    @State private var text = ""
    @State private var editing: UUID?
    @State private var missing: KoncluiMissing?   // Koncluí: see the Dictionary

    var body: some View {
        HubPageScaffold(title: String(localized: "hub.page.snippets"),
                        subtitle: String(localized: "hub.snippets-sub")) {
            HubCard {
                Text(editing == nil ? String(localized: "hub.snippet-new") : String(localized: "hub.snippet-edit"))
                    .font(.system(size: 14, weight: .bold))
                // Koncluí: both fields keep a label above once typing starts (a placeholder vanishes), and a blocked Add says why.
                HubField(placeholder: String(localized: "hub.trigger-placeholder"), text: $trigger,
                         label: String(localized: "hub.you-say"),
                         hint: missing == .trigger ? String(localized: "konclui.hint.trigger") : nil)
                VStack(alignment: .leading, spacing: 6) {
                    Text("konclui.snippets.pastes").koncluiType(.label).foregroundColor(KoncluiTheme.textTertiary)
                    TextEditor(text: $text)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(height: 90)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(HubTheme.field))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.white.opacity(0.16)))
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("hub.snippet-text-placeholder")
                                    .font(.system(size: 13))
                                    .foregroundColor(HubTheme.muted)
                                    .padding(.horizontal, 13)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                    if missing == .text { KoncluiHint(text: String(localized: "konclui.hint.snippet-text")) }
                }
                HStack(spacing: 8) {
                    Button(editing == nil ? String(localized: "konclui.hub.add-snippet") : String(localized: "hub.save"), action: save)
                        .buttonStyle(HubButtonStyle(primary: true))
                    if editing != nil {
                        Button(String(localized: "hub.cancel")) { reset() }
                            .buttonStyle(HubButtonStyle())
                    }
                }
            }
            if store.snippets.isEmpty {
                HubEmptyState(text: String(localized: "hub.snippets-empty"), color: "#F7B32B")
                if flow.koncluiState != .ready { KoncluiDictationNextStep(centered: true) }   // Koncluí: A3-39
            }
            ForEach(store.snippets) { snippet in
                HubCard {
                    HStack(spacing: 8) {
                        Text("hub.you-say")
                            .font(.system(size: 12))
                            .foregroundColor(HubTheme.secondary)
                        Text(String(format: String(localized: "konclui.hub.trigger-quoted %@"), snippet.trigger))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "#FDBA74"))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 6).fill(HubTheme.accent.opacity(0.14)))
                        Spacer()
                        HubIconButton(symbol: "pencil", help: String(localized: "hub.edit")) {
                            editing = snippet.id
                            trigger = snippet.trigger
                            text = snippet.text
                        }
                        HubIconButton(symbol: "trash", help: String(localized: "hub.delete")) {
                            store.removeSnippetWithUndo(snippet)   // Koncluí: Undo
                            if editing == snippet.id { reset() }
                        }
                    }
                    Text(snippet.text)
                        .font(.system(size: 13))
                        .lineSpacing(2)
                        .foregroundColor(KoncluiTheme.textBody)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .koncluiUndoBar()   // Koncluí
        .onChange(of: trigger) { _, _ in if missing == .trigger { missing = nil } }
        .onChange(of: text) { _, _ in if missing == .text { missing = nil } }
    }

    private func save() {
        let t = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { missing = .trigger; return }   // Koncluí: the button is enabled; a click says what is missing
        guard !body.isEmpty else { missing = .text; return }
        missing = nil
        if let editing, let index = store.snippets.firstIndex(where: { $0.id == editing }) {
            store.snippets[index].trigger = t
            store.snippets[index].text = body
        } else {
            store.snippets.append(FlowSnippet(trigger: t, text: body))
        }
        reset()
    }

    private func reset() {
        editing = nil
        trigger = ""
        text = ""
    }
}

// MARK: - Styles

/// Coucou Flow → Styles: Claude's clean-up, and how the words are written in each app.
struct HubStylesPage: View {
    @ObservedObject var router: HubRouter
    @ObservedObject private var store = FlowStore.shared
    // Koncluí: which apps this Mac has, asked once per visit (KoncluiInstalledApps).
    @StateObject private var installed = KoncluiInstalledApps()

    var body: some View {
        HubPageScaffold(title: String(localized: "hub.page.styles"),
                        subtitle: String(localized: "hub.styles-sub")) {
            HubCard {
                HubRow(title: String(localized: "hub.cleanup"), detail: String(localized: "hub.cleanup-detail")) {
                    Toggle("", isOn: $store.cleanupEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(!FlowCleanup.hasKey && !store.cleanupEnabled)
                }
                if !FlowCleanup.hasKey {
                    HStack(spacing: 10) {
                        Image(systemName: "key")
                            .foregroundColor(HubTheme.accent)
                        Text("hub.cleanup-key")
                            .font(.system(size: 12.5))
                            .foregroundColor(KoncluiTheme.textBody)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button(String(localized: "hub.open-settings")) {
                            NotificationCenter.default.post(name: .openFullSettings, object: "chat")
                        }
                        .buttonStyle(HubButtonStyle())
                    }
                }
                HubDivider()
                // Koncluí: with the clean-up off a style changes nothing, so the row is disabled and says so where the style is.
                HubRow(title: String(localized: "hub.style-default"),
                       detail: store.cleanupEnabled ? store.defaultStyle.detail : String(localized: "konclui.hub.styles-off")) {
                    KoncluiStylePicker(selection: $store.defaultStyle)
                        .disabled(!store.cleanupEnabled)
                }
            }

            HStack {
                HubLabel(String(localized: "hub.style-apps"))
                Spacer()
                Menu {
                    ForEach(addableApps, id: \.bundleID) { app in
                        Button(app.name) {
                            store.appStyles.append(FlowAppStyle(bundleID: app.bundleID, name: app.name, style: store.defaultStyle))
                        }
                    }
                    if addableApps.isEmpty { Text("hub.style-no-app") }
                } label: {
                    Label(String(localized: "hub.style-add"), systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)   // Koncluí: the "+" already says it opens; the text then ends on the card's edge
                .fixedSize()
                .disabled(!store.cleanupEnabled)
            }
            if !store.cleanupEnabled { stylesOff }
            HubCard {
                ForEach(Array(visibleApps.enumerated()), id: \.element.id) { index, app in
                    if index > 0 { HubDivider() }
                    HStack(spacing: 12) {
                        HubAppIcon(bundleID: app.bundleID)
                        Text(installed.name(app.bundleID, fallback: app.name)).font(.system(size: 13.5, weight: .medium))
                        Spacer()
                        KoncluiStylePicker(selection: Binding(
                            get: { store.appStyles.first(where: { $0.id == app.id })?.style ?? .natural },
                            set: { value in
                                if let i = store.appStyles.firstIndex(where: { $0.id == app.id }) { store.appStyles[i].style = value }
                            }))
                        HubIconButton(symbol: "xmark", help: String(localized: "hub.delete")) {
                            store.removeAppStyleWithUndo(app)   // Koncluí: Undo
                        }
                    }
                }
            }
            // Koncluí: dimmed means disabled, and it is (the list above says why); it was dimmed but fully live.
            .disabled(!store.cleanupEnabled)
            .opacity(store.cleanupEnabled ? 1 : 0.55)

            // Koncluí: what each style does is in the picker's popover, next to the choice; only the privacy line stays here.
            Text("hub.cleanup-privacy")
                .font(.system(size: 12))
                .foregroundColor(HubTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .koncluiUndoBar()
    }

    /// Koncluí: why the lists below do nothing, and the way out, in the same click when the key is there (UX.md 1.1).
    private var stylesOff: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle").foregroundColor(KoncluiTheme.textSecondary).accessibilityHidden(true)
            Text("konclui.hub.styles-off")
                .koncluiType(.detail)
                .foregroundColor(KoncluiTheme.textBody)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if FlowCleanup.hasKey {
                Button(String(localized: "konclui.hub.styles-turn-on")) { store.cleanupEnabled = true }
                    .buttonStyle(HubButtonStyle())
            }
        }
    }

    /// Koncluí: the apps this Mac has (A1-39); what the person added always shows.
    private var visibleApps: [FlowAppStyle] {
        KoncluiStyleApps.visible(store.appStyles, id: \.bundleID, defaults: KoncluiFlowStyles.defaultIDs,
                                 installed: installed.isInstalled)
    }

    /// Running apps with windows that have no style of their own yet.
    private var addableApps: [(bundleID: String, name: String)] {
        let taken = Set(store.appStyles.map(\.bundleID))
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (bundleID: String, name: String)? in
                guard let id = app.bundleIdentifier, let name = app.localizedName,
                      id != Bundle.main.bundleIdentifier, !taken.contains(id), seen.insert(id).inserted else { return nil }
                return (id, name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

/// The icon of an app, from its bundle identifier.
struct HubAppIcon: View {
    let bundleID: String

    var body: some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
            } else {
                RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.08))
            }
        }
        .frame(width: 22, height: 22)
    }
}

#endif
