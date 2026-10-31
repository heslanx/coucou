#if !APPSTORE
import AppKit
import SwiftUI

/// Coucou Flow → Settings: the key, the permission, the recognition and the history.
struct HubSettingsPage: View {
    @ObservedObject private var flow = FlowDictation.shared
    @ObservedObject private var store = FlowStore.shared
    @AppStorage("dictationLanguage") private var language = MacDictation.automatic
    @State private var confirmClear = false
    @State private var showInDock = FlowHubController.showInDock
    @State private var openAtLaunch = FlowHubController.openAtLaunch
    // Koncluí: the Claude source is found a moment after launch; the page redraws when it is (KoncluiClaudeLive.swift).
    @ObservedObject private var claude = KoncluiClaudeLive.shared

    var body: some View {
        HubPageScaffold(title: String(localized: "hub.page.settings"), subtitle: String(localized: "konclui.settings.sub")) {   // Koncluí: a band with one word had no subtitle
            HubLabel(String(localized: "hub.settings.keys"))
                .settingsHeading("flow.keys")
            HubCard {
                // Koncluí: the permission shows only while dictation is on and macOS does not trust Koncluí yet, first, with its
                // button (A2-19). It was a card of its own that also showed while dictation was off.
                if flow.koncluiState == .needsAccess {
                    accessibilityRow
                    HubDivider()
                }
                HubRow(title: String(localized: "flow.enable")) {
                    Toggle("", isOn: $flow.isEnabled).toggleStyle(.switch).labelsHidden()
                }
                HubDivider()
                HubRow(title: String(localized: "hub.settings.hold"),
                       detail: flow.key == .fn ? String(localized: "flow.fn-help") : nil) {
                    Picker("", selection: $flow.key) {
                        ForEach(FlowKey.allCases) { Text(verbatim: $0.label).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                HubDivider()
                HubRow(title: String(localized: "flow.edge")) {
                    Picker("", selection: $flow.pillEdge) {
                        ForEach(FlowPillEdge.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .koncluiSegmented()   // Koncluí
                    .labelsHidden()
                    .fixedSize()
                }
                HubDivider()
                HubRow(title: String(localized: "hub.settings.handsfree"),
                       detail: String(localized: "hub.settings.handsfree-detail")) {
                    HubKeyCap(text: "\(flow.key.symbol) \(flow.key.symbol)")
                }
                HubDivider()
                HubRow(title: String(localized: "hub.settings.paste-again"),
                       detail: String(localized: "hub.settings.paste-again-detail")) {
                    HubKeyCap(text: "⌃⌘V")
                }
                HubDivider()
                HubRow(title: String(localized: "hub.settings.cancel")) {
                    HubKeyCap(text: String(localized: "hub.key-esc"))
                }
                // Koncluí: the dictation keys are listed in Atalhos too (KoncluiDictationShortcuts); this links the two (A1-38).
                HubDivider()
                Button { FlowHubController.shared.show(.shortcuts) } label: {
                    Text("konclui.settings.all-shortcuts")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(HubTheme.accent)
                }
                .buttonStyle(.plain)
                .koncluiPointer()
            }
                .settingsAnchor("flow.keys", cornerRadius: 14)

            HubLabel(String(localized: "flow.ai.title"))
                .settingsHeading("flow.ai")
            HubCard {
                HubRow(title: String(localized: "flow.prompt-mode"), detail: String(localized: "flow.prompt-mode-detail")) {
                    Toggle("", isOn: $store.promptMode)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(!FlowCleanup.hasKey && !store.promptMode)
                }
                KoncluiClaudeFailureLine(feature: .prompt)   // Koncluí: the last prompt that fell back (A3-27)
                HubDivider()
                HubRow(title: String(localized: "flow.translate"),
                       detail: FlowLanguages.language(store.translateTo).map {
                           String(format: String(localized: "flow.translate-on %@"), $0.name)
                       } ?? String(localized: "flow.translate-detail")) {
                    Picker("", selection: $store.translateTo) {
                        Text("flow.translate-off").tag("")
                        Divider()
                        ForEach(FlowLanguages.sorted) { Text(verbatim: $0.name).tag($0.code) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .disabled(!FlowCleanup.hasKey && store.translateTo.isEmpty)
                }
                KoncluiClaudeFailureLine(feature: .translation)   // Koncluí: A3-27
                // Koncluí: what to connect, with the key one click away; and where the words go for the source that answers now
                KoncluiClaudeConnectLine(feature: .prompt)
                if let privacy = claude.privacyLine(for: .prompt) {
                    Text(verbatim: privacy)
                        .font(.system(size: 12))
                        .foregroundColor(HubTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
                .settingsAnchor("flow.ai", cornerRadius: 14)

            HubLabel(String(localized: "hub.settings.recognition"))
                .settingsHeading("flow.recognition")
            HubCard {
                HubRecognitionSettings(language: $language)
            }
                .settingsAnchor("flow.recognition", cornerRadius: 14)

            HubLabel(String(localized: "hub.page.notes"))
                .settingsHeading("flow.summary")
            HubCard {
                HubSummaryEnginePicker()
                // Koncluí: where a transcript goes with the Claude engine (subscription or key), and the last call that failed
                Text(verbatim: claude.notesDetail)
                    .font(.system(size: 12))
                    .foregroundColor(HubTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                KoncluiClaudeFailureLine(feature: .summary)
                KoncluiClaudeFailureLine(feature: .correction)
                HubDivider()
                Text("notes.legal")
                    .font(.system(size: 12))
                    .foregroundColor(HubTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
                .settingsAnchor("flow.summary", cornerRadius: 14)

            HubLabel(String(localized: "hub.settings.app"))
                .settingsHeading("flow.app")
            HubCard {
                HubRow(title: String(localized: "hub.settings.dock"), detail: String(localized: "hub.settings.dock-detail")) {
                    Toggle("", isOn: Binding(get: { showInDock }, set: { showInDock = $0; FlowHubController.showInDock = $0 }))
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                HubDivider()
                HubRow(title: String(localized: "hub.settings.open-at-launch")) {
                    Toggle("", isOn: Binding(get: { openAtLaunch }, set: { openAtLaunch = $0; FlowHubController.openAtLaunch = $0 }))
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
                .settingsAnchor("flow.app", cornerRadius: 14)

            HubLabel(String(localized: "hub.settings.privacy"))
                .settingsHeading("flow.privacy")
            HubCard {
                HubRow(title: String(localized: "hub.settings.keep")) {
                    Picker("", selection: $store.keepDays) {
                        Text("hub.keep.none").tag(0)
                        Text("hub.keep.week").tag(7)
                        Text("hub.keep.month").tag(30)
                        Text("hub.keep.year").tag(365)
                        Text("hub.keep.forever").tag(-1)
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                HubDivider()
                HStack(spacing: 8) {
                    Button(String(localized: "hub.settings.clear-history")) { store.clearHistoryWithUndo() }   // Koncluí: Undo
                        .buttonStyle(HubButtonStyle())
                    Button(String(localized: "hub.settings.clear-all")) { confirmClear = true }
                        .buttonStyle(HubButtonStyle())
                }
                Text("hub.settings.privacy-text")
                    .font(.system(size: 12))
                    .foregroundColor(HubTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
                .settingsAnchor("flow.privacy", cornerRadius: 14)
        }
        .onAppear { flow.recheckTrust() }
        .koncluiUndoBar()
        .alert(String(localized: "hub.settings.clear-all-confirm"), isPresented: $confirmClear) {
            Button(String(localized: "hub.settings.clear-all"), role: .destructive) { store.clearEverythingWithUndo() }
            Button(String(localized: "hub.cancel"), role: .cancel) {}
        }
    }

    /// Koncluí: what is missing, what to do, and the advice to remove and add Koncluí again only when macOS once trusted it (A3-24).
    private var accessibilityRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(KoncluiTheme.attention)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("hub.setup-access-title").koncluiType(.bodyStrong)
                    Text("konclui.flow.accessibility")
                        .koncluiType(.detail)
                        .foregroundColor(KoncluiTheme.textBody)
                        .fixedSize(horizontal: false, vertical: true)
                    if KoncluiAccessibilityMemory.suggestsRemoveAndAdd(for: flow) {
                        Text("konclui.flow.accessibility-stale")
                            .koncluiType(.detail)
                            .foregroundColor(KoncluiTheme.textBody)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Button(String(localized: "flow.accessibility-open")) { flow.openAccessibilitySettings() }
                .buttonStyle(HubButtonStyle(primary: true))
        }
    }
}

/// A key drawn like a keycap.
struct HubKeyCap: View {
    let text: String

    var body: some View {
        KoncluiKeyCap(text: text)   // Koncluí: one key cap for Ajustes and Atalhos
    }
}

/// How the voice becomes text: Parakeet on the Mac (once downloaded) or the Mac's recognizer.
struct HubRecognitionSettings: View {
    @Binding var language: String
    @ObservedObject private var store = FlowStore.shared
    @ObservedObject private var parakeet = Parakeet.shared

    var body: some View {
        HubEngineRow(selected: store.engine == .parakeet,
                     title: String(localized: "hub.engine.parakeet"),
                     detail: String(localized: "hub.engine.parakeet-detail")) {
            store.engine = .parakeet
        } trailing: {
            parakeetStatus
        }
        HubDivider()
        HubEngineRow(selected: store.engine == .apple,
                     title: String(localized: "hub.settings.engine-apple"),
                     detail: String(localized: "hub.settings.engine-apple-detail")) {
            store.engine = .apple
        } trailing: {
            EmptyView()
        }
        if store.engine == .apple {
            HubDivider()
            HubRow(title: String(localized: "Dictation language")) {
                Picker("", selection: $language) {
                    Text("Automatic").tag(MacDictation.automatic)
                    ForEach(MacDictation.allLanguages, id: \.self) { id in
                        Text(MacDictation.name(of: id)).tag(id)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
        } else if !parakeet.isReady {
            Text("hub.engine.fallback")
                .font(.system(size: 12))
                .foregroundColor(HubTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var parakeetStatus: some View {
        switch parakeet.state {
        case .unsupported:
            Text("hub.engine.unsupported")
                .font(.system(size: 12))
                .foregroundColor(HubTheme.secondary)
        case .missing:
            Button(String(localized: "hub.engine.download")) { parakeet.download() }
                .buttonStyle(HubButtonStyle(primary: true))
        case .downloading(let fraction):
            HStack(spacing: 8) {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .frame(width: 110)
                Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                    .font(.system(size: 12))
                    .foregroundColor(HubTheme.secondary)
                    .monospacedDigit()
            }
        case .ready:
            Menu {
                Button(String(localized: "hub.engine.remove"), role: .destructive) { parakeet.remove() }
            } label: {
                // Koncluí: a menu tints its label with the accent; the status draws its own dot and chevron.
                KoncluiStatus(tone: .ok, text: String(localized: "hub.engine.installed"), door: true)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        case .failed:
            Button(String(localized: "hub.engine.retry")) { parakeet.download() }
                .buttonStyle(HubButtonStyle())
        }
    }
}

/// A recognizer to choose: a round mark, its name and what it does, and its status on the right.
private struct HubEngineRow<Trailing: View>: View {
    let selected: Bool
    let title: String
    let detail: String
    let choose: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Button(action: choose) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().strokeBorder(selected ? HubTheme.accent : Color.white.opacity(KoncluiIncreasedContrast.checkboxStroke),   // Koncluí: 3:1 when off
                                              lineWidth: selected ? 5 : 1.5)
                    }
                    .frame(width: 17, height: 17)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.system(size: 13.5, weight: .semibold))
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundColor(HubTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .koncluiPointer()   // Koncluí
            trailing()
        }
    }
}
#endif
