#if !APPSTORE
import AppKit
import SwiftUI

/// Coucou Flow → Dictation: hello, today's dictations and the numbers.
struct HubHomePage: View {
    @ObservedObject var router: HubRouter
    @ObservedObject private var store = FlowStore.shared
    @ObservedObject private var flow = FlowDictation.shared
    @State private var query = ""
    @Environment(\.colorSchemeContrast) private var contrast   // Koncluí

    private var greeting: String {
        if let name = resolveUserFirstName() { return String(format: String(localized: "hub.hello %@"), name) }
        return String(localized: "hub.hello")
    }

    // Koncluí: while dictation is off or cannot paste yet, the band's one primary is the setup (the setup card and its
    // second primary are gone) and the subtitle says how to turn it on, never "hold the key" while nothing listens (A1-14).
    // Recording a call is the primary only when dictation works; the Notetaker promo below leads there in the meantime.
    private var bandSubtitle: String {
        switch flow.koncluiState {
        case .off:         return String(localized: "konclui.home.hint-off")
        case .needsAccess: return String(localized: "hub.setup-access-title")
        case .ready:       return String(format: String(localized: "hub.hint %@"), flow.key.label)
        }
    }

    var body: some View {
        HubPageScaffold(title: greeting, subtitle: bandSubtitle) {
            if flow.koncluiState != .ready {
                KoncluiDictationNextStep(prominent: true)
            } else {
                Button {
                    router.page = .notes
                    if KoncluiNoteSpeech.engine != .needsDownload, !NoteTaker.shared.isRecording { Task { await NoteTaker.shared.start() } }   // Koncluí: Apple's speech records
                } label: {
                    HStack(spacing: 7) {
                        Circle().fill(.foreground).frame(width: 9, height: 9)
                        Text("hub.record-call")
                    }
                }
                .buttonStyle(HubButtonStyle(primary: true))
            }
        } content: {
            KoncluiConnectAgentsHome(router: router)   // Koncluí: agents found on this Mac but not connected
            HStack(alignment: .top, spacing: 20) {
                history
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                VStack(spacing: 14) {
                    HubTotalsCard()
                    HubNotesPromo(router: router)
                }
                .frame(width: 270)
            }
        }
        .onAppear { flow.recheckTrust() }   // Koncluí: was the setup card's job
        .koncluiUndoBar()
    }

    // MARK: History

    private var filtered: [FlowEntry] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let all = q.isEmpty ? store.history : store.history.filter { $0.text.localizedCaseInsensitiveContains(q) }
        return Array(all.prefix(400))
    }

    /// The entries by day, newest day first, keeping their order.
    private var groups: [HubDayGroup] {
        var out: [HubDayGroup] = []
        for entry in filtered {
            let key = FlowText.dayKey(entry.date)
            if let last = out.indices.last, out[last].id == key {
                out[last].entries.append(entry)
            } else {
                out.append(HubDayGroup(id: key, date: entry.date, entries: [entry]))
            }
        }
        return out
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HubLabel(String(localized: "hub.history"))
                Spacer()
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(HubTheme.muted)
                    TextField(String(localized: "hub.search"), text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .frame(width: 170)
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous).fill(HubTheme.card))
                .overlay(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous).strokeBorder(KoncluiTheme.controlStroke(contrast)))
            }
            if store.history.isEmpty {
                HubCard {
                    // Koncluí: the hold-a-key sentence is in the band; the empty history says only why it is empty.
                    HubEmptyState(text: emptyHistory)
                }
            } else if groups.isEmpty {
                Text("hub.search-empty")
                    .font(.system(size: 13))
                    .foregroundColor(HubTheme.secondary)
            }
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Self.dayTitle(group.date))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(HubTheme.secondary)
                        VStack(spacing: 0) {
                            ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
                                if index > 0 { HubDivider() }
                                HubEntryRow(entry: entry)
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(HubTheme.card))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(HubTheme.line))
                    }
                }
            }
        }
    }

    /// Why the history is empty: dictation is off (nothing was recorded), the history is not kept, or nothing was said yet.
    private var emptyHistory: String {
        if flow.koncluiState == .off { return String(localized: "konclui.home.empty-off") }
        return store.keepDays == 0 ? String(localized: "hub.history-off") : String(localized: "konclui.home.empty")
    }

    static func dayTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return String(localized: "hub.today") }
        if calendar.isDateInYesterday(date) { return String(localized: "hub.yesterday") }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

private struct HubDayGroup: Identifiable {
    let id: String
    let date: Date
    var entries: [FlowEntry]
}

/// One dictation of the history.
private struct HubEntryRow: View {
    let entry: FlowEntry
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text(entry.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundColor(HubTheme.muted)
                if let app = entry.app, !app.isEmpty {
                    Text(app)
                        .font(.system(size: 11))
                        .foregroundColor(KoncluiTheme.textBody)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.06)))
                }
            }
            .frame(width: 70, alignment: .leading)
            Text(entry.text)
                .font(.system(size: 14))
                .lineSpacing(3)
                .foregroundColor(HubTheme.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4) {
                HubIconButton(symbol: copied ? "checkmark" : "doc.on.doc", help: String(localized: "hub.copy")) {
                    NSPasteboard.copyText(entry.text)
                    copied = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.2))
                        copied = false
                    }
                }
                HubIconButton(symbol: "trash", help: String(localized: "hub.delete")) {
                    FlowStore.shared.deleteWithUndo(entry)   // Koncluí: Undo (UX.md 1.5)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
    }
}

/// Total words, speed and days in a row. Koncluí: each number opens the records behind it (KoncluiStatDoor).
private struct HubTotalsCard: View {
    @ObservedObject private var store = FlowStore.shared

    var body: some View {
        let speed = KoncluiStats.speed(words: store.totalWords, seconds: store.totalSeconds)
        HubCard(padding: 20) {
            big(.words, FlowText.shortCount(store.totalWords), String(localized: "hub.total-words"))
            big(.speed, speed.map { "\($0)" }, String(localized: "hub.wpm"))
            big(.streak, "\(store.streak)", String(localized: "hub.streak"))
            HubDivider()
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock")
                    .font(.system(size: 12, weight: .bold))
                    .accessibilityHidden(true)
                Text("konclui.home.local-only")
                    .font(.system(size: 13, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(KoncluiTheme.textBody)
        }
    }

    /// A number with its label; `value` nil reads "unavailable" (UX.md 2.1) and its sheet says when it appears.
    private func big(_ kind: KoncluiStatKind, _ value: String?, _ label: String) -> some View {
        let shown = value ?? String(localized: "konclui.stat.unavailable")
        return KoncluiStatDoor(kind: kind, value: shown, label: label, period: String(localized: "hub.period.all"), since: nil) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(shown)
                    .koncluiType(value == nil ? .title : .metric)
                    .foregroundColor(value == nil ? KoncluiTheme.textSecondary : KoncluiTheme.textPrimary)
                Text(label)
                    .koncluiType(.body)
                    .foregroundColor(HubTheme.secondary)
            }
            .padding(.vertical, 4)
            .padding(.trailing, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HubNotesPromo: View {
    @ObservedObject var router: HubRouter
    @StateObject private var light = HubHeroLight()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("hub.notes-promo-title")
                .font(.system(size: 15, weight: .bold))
            Text("hub.notes-promo")
                .font(.system(size: 13))
                .lineSpacing(2)
                .foregroundColor(KoncluiTheme.textBody)
                .fixedSize(horizontal: false, vertical: true)
            Button { router.page = .notes } label: {
                Text("hub.notes-promo-open")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(HubTheme.accent)
            }
            .buttonStyle(.plain)
            .koncluiPointer()   // Koncluí
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HubHeroBackdrop(color: HubTheme.accent, light: light, cornerRadius: 14).allowsHitTesting(false))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(HubTheme.accent.opacity(0.2)))
        .onContinuousHover { phase in
            switch phase {
            case .active(let point): light.target = point
            case .ended:             light.target = nil
            }
        }
    }
}
#endif
