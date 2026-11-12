#if !APPSTORE
import AppKit
import SwiftUI

// Koncluí: the reminder editor, the screen "Novo lembrete" (or a row of the list) opens on the Lembretes page
// (KoncluiRemindersPage.swift). The live preview on the left, the few choices on the right, in the order a person thinks
// them: what, when, how it looks, which buttons. It replaces the owner's always-open form, whose sliders (width, height,
// two positions), SF Symbol name field and free snooze stepper became a few named choices (KoncluiReminderRules.swift);
// values an agent set through the MCP outside them are kept and shown as "Personalizado".
//
// A sheet rather than the agents' popover: a popover closes on any click outside it, choosing an image included, and this
// form is long enough that the preview must stay in sight while the buttons at its end are edited. The look is the
// popover's (a header with the reminder's icon and status, the hub's controls). Cancel keeps the draft (UX.md 1.3).

struct KoncluiReminderEditor: View {
    /// The reminder being edited; nil for a new one.
    let existing: Reminder?
    @Binding var draft: KoncluiReminderDraft
    /// The draft is one an earlier Cancel kept: say so, with the way back to a blank one.
    let restored: Bool
    let cancel: () -> Void
    /// Saves; returns what went wrong, in words, or nil.
    let save: () -> String?
    let delete: (() -> Void)?
    let startOver: () -> Void

    @State private var tried = false
    @State private var failure: String?
    @State private var imageProblem: String?
    @FocusState private var titleFocused: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    private var screens: [NSScreen] { NSScreen.screens }
    private var issue: KoncluiReminderDraft.Issue? { draft.issue(now: Date()) }
    private var shownIssue: KoncluiReminderDraft.Issue? { tried ? issue : nil }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(KoncluiTheme.hairline(contrast))
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    KoncluiReminderPreview(draft: $draft, screen: KoncluiReminderScreen.at(draft.screenIndex))
                    caption
                    testRow.padding(.top, 8)
                }
                .frame(width: 380)
                ScrollView {
                    form.padding(.trailing, 14)
                }
                .scrollIndicators(.automatic)
            }
            .padding(.horizontal, 22).padding(.top, 18)
            Divider().overlay(KoncluiTheme.hairline(contrast))
            footer
        }
        .frame(width: 800, height: 620)
        .background(KoncluiTheme.panel)
        .koncluiTheme()
        .disclosureGroupStyle(KoncluiDisclosureStyle())
        .onChange(of: draft) { _, _ in failure = nil }
    }

    // MARK: - Header and footer

    private var header: some View {
        HStack(spacing: 10) {
            symbolTile(size: 30)
            Text(existing == nil ? "konclui.reminders.new" : "konclui.reminders.edit")
                .koncluiType(.title)
                .foregroundColor(KoncluiTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let existing {
                if case .snoozed(let until) = KoncluiReminderRules.status(existing), draft.isActive {
                    KoncluiStatus(tone: .attention, text: KoncluiReminderWords.status(.snoozed(until: until)))
                }
                Toggle(isOn: $draft.isActive) {
                    Text(draft.isActive ? "konclui.reminders.status.active" : "konclui.reminders.status.stopped")
                        .koncluiType(.detail)
                        .foregroundColor(KoncluiTheme.textBody)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .help(Text("konclui.reminders.active.help"))
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            footerLine
            Spacer(minLength: 8)
            if let delete {
                Button(role: .destructive, action: delete) {
                    Text("konclui.reminders.delete").foregroundColor(KoncluiTheme.error)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .padding(.trailing, 6)
            }
            Button("Cancel", action: cancel)
                .buttonStyle(.koncluiSecondary)
                .keyboardShortcut(.cancelAction)
            Button(existing == nil ? "konclui.reminders.create" : "konclui.reminders.save") {
                tried = true
                guard issue == nil else { return }
                failure = save()
            }
            .buttonStyle(.koncluiPrimary)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
    }

    /// The one line beside the buttons: what blocks the save or what failed.
    @ViewBuilder private var footerLine: some View {
        if let shownIssue {
            KoncluiHint(text: String(localized: String.LocalizationValue(shownIssue.key)))
        } else if let message = failure ?? imageProblem {
            KoncluiHint(text: message)
        }
    }

    /// "Testar", under the preview it makes real: the reminder now, on its screen, as it will ring.
    private var testRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                test()
            } label: {
                Label("konclui.reminders.test", systemImage: "play.fill")
            }
            .buttonStyle(.koncluiSecondary)
            Text("konclui.reminders.test.hint")
                .koncluiType(.detail)
                .foregroundColor(KoncluiTheme.secondary(contrast))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func test() {
        // A test shows the reminder whatever its time; only what would make it unreadable blocks it.
        if let blocking = draft.issue(now: nil), blocking != .title {
            tried = true
            failure = String(localized: String.LocalizationValue(blocking.key))
            return
        }
        var trial = draft
        if trial.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            trial.title = String(localized: "konclui.reminders.title.placeholder")
        }
        KoncluiReminderTrial.show(trial.reminder())
    }

    // MARK: - The preview's caption

    private var caption: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: KoncluiReminderWords.summary(draft))
                .koncluiType(.detail)
                .foregroundColor(KoncluiTheme.textBody)
            if let next = KoncluiReminderRules.following(KoncluiReminderRules.firstDue(draft.dueAt, repeats: draft.repeats,
                                                                                      now: Date()) ?? draft.dueAt,
                                                         repeats: draft.repeats) {
                Text("konclui.reminders.preview.then \(KoncluiReminderWords.when(next))")
                    .koncluiType(.detail)
                    .foregroundColor(KoncluiTheme.secondary(contrast))
            }
            if draft.presentation == .card {
                Text("konclui.reminders.preview.drag")
                    .koncluiType(.detail)
                    .foregroundColor(KoncluiTheme.textTertiary)
            }
            Text("konclui.reminders.preview.closed")
                .koncluiType(.detail)
                .foregroundColor(KoncluiTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - The form

    private var form: some View {
        VStack(alignment: .leading, spacing: KoncluiSpace.sectionGap) {
            if restored {
                HStack(spacing: 6) {
                    Text("konclui.reminders.draft.restored").foregroundColor(KoncluiTheme.textBody)
                    Button("konclui.reminders.draft.discard", action: startOver)
                        .buttonStyle(.link)
                }
                .koncluiType(.detail)
            }
            section("konclui.reminders.section.what") {
                titleField
                messageField
            }
            section("konclui.reminders.section.when") { when }
            section("konclui.reminders.section.look") { look }
            section("konclui.reminders.section.buttons") { buttons }
        }
        .padding(.bottom, 8)
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).koncluiType(.label).foregroundColor(KoncluiTheme.textTertiary)
            content()
        }
    }

    /// KoncluiField's look, with focus the editor owns: the name is where typing starts (else the date takes it).
    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(String(localized: "konclui.reminders.title.placeholder"), text: $draft.title)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($titleFocused)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous).fill(KoncluiTheme.field))
                .overlay(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous)
                    .strokeBorder(titleFocused ? KoncluiTheme.accent : KoncluiTheme.controlStroke(contrast), lineWidth: titleFocused ? 2 : 1))
            if shownIssue == .title { KoncluiHint(text: String(localized: "konclui.reminders.issue.title")) }
        }
        .onAppear { titleFocused = true }
        .onChange(of: shownIssue) { _, new in if new == .title { titleFocused = true } }
    }

    private var messageField: some View {
        TextField(String(localized: "konclui.reminders.message.placeholder"), text: $draft.message, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .lineLimit(2...4)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous).fill(KoncluiTheme.field))
            .overlay(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous)
                .strokeBorder(KoncluiTheme.controlStroke(contrast)))
    }

    // MARK: When

    @ViewBuilder private var when: some View {
        let quick = KoncluiReminderRules.quickTimes(now: Date())
        HStack(spacing: 8) {
            DatePicker("", selection: $draft.dueAt)
                .labelsHidden()
                .datePickerStyle(.field)
            Spacer(minLength: 0)
        }
        HStack(spacing: 6) {
            chip("konclui.reminders.quick.10min", on: false) { draft.dueAt = quick.tenMinutes }
            chip("konclui.reminders.quick.1h", on: false) { draft.dueAt = quick.hour }
            chip("konclui.reminders.quick.tomorrow \(quick.tomorrowMorning.formatted(date: .omitted, time: .shortened))",
                 on: draft.dueAt == quick.tomorrowMorning) { draft.dueAt = quick.tomorrowMorning }
        }
        Picker("", selection: $draft.repeats) {
            ForEach(ReminderRepeat.allCases) { repeats in
                Text(LocalizedStringKey(KoncluiReminderRules.repeatKey(repeats))).tag(repeats)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .koncluiSegmented()
        if shownIssue == .past {
            KoncluiHint(text: String(localized: "konclui.reminders.issue.past"))
        }
    }

    private func chip(_ title: LocalizedStringKey, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .koncluiType(.detail)
                .foregroundColor(on ? KoncluiTheme.onAccent : KoncluiTheme.textBody)
                .padding(.horizontal, 10).frame(height: 24)
                .background(Capsule().fill(on ? KoncluiTheme.accent : Color.white.opacity(0.07)))
                .overlay(Capsule().strokeBorder(on ? Color.clear : KoncluiTheme.hairline(contrast)))
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
    }

    // MARK: How it looks

    @ViewBuilder private var look: some View {
        Picker("", selection: $draft.presentation) {
            Text("konclui.reminders.display.card").tag(ReminderPresentation.card)
            Text("konclui.reminders.display.full").tag(ReminderPresentation.fullScreen)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .koncluiSegmented()
        Text(draft.presentation == .card ? "konclui.reminders.display.card-hint" : "konclui.reminders.display.full-hint")
            .koncluiType(.detail)
            .foregroundColor(KoncluiTheme.secondary(contrast))
            .fixedSize(horizontal: false, vertical: true)

        if draft.presentation == .card {
            // Full screen covers the whole screen: a size means nothing there.
            row("konclui.reminders.size") {
                Picker("", selection: sizeBinding) {
                    ForEach(KoncluiReminderSize.allCases) { size in
                        Text(LocalizedStringKey(size.key)).tag(Optional(size))
                    }
                    if draft.size == nil {
                        Text("konclui.reminders.size.custom").tag(KoncluiReminderSize?.none)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .koncluiSegmented()
            }
            row("konclui.reminders.position") {
                Picker("", selection: placeBinding) {
                    ForEach(KoncluiReminderPlace.allCases) { place in
                        Text(LocalizedStringKey(place.key)).tag(Optional(place))
                    }
                    if draft.place == nil {
                        Text("konclui.reminders.position.custom").tag(KoncluiReminderPlace?.none)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
        }
        if screens.count > 1 {
            row("konclui.reminders.screen") {
                Picker("", selection: $draft.screenIndex) {
                    ForEach(Array(screens.enumerated()), id: \.offset) { index, screen in
                        Text(verbatim: screen.localizedName).tag(index)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
        }
        icons
    }

    private func row<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .koncluiType(.detail)
                .foregroundColor(KoncluiTheme.textBody)
                .frame(width: 70, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
    }

    private var sizeBinding: Binding<KoncluiReminderSize?> {
        Binding(get: { draft.size }, set: { size in
            guard let size else { return }
            draft.width = size.points.width
            draft.height = size.points.height
        })
    }

    private var placeBinding: Binding<KoncluiReminderPlace?> {
        Binding(get: { draft.place }, set: { place in
            guard let place else { return }
            draft.positionX = place.position.x
            draft.positionY = place.position.y
        })
    }

    @ViewBuilder private var icons: some View {
        let symbols = KoncluiReminderRules.symbols
            + (draft.symbol.map { KoncluiReminderRules.symbols.contains($0) ? [] : [$0] } ?? [])
        HStack(alignment: .top, spacing: 12) {
            Text("konclui.reminders.icon")
                .koncluiType(.detail)
                .foregroundColor(KoncluiTheme.textBody)
                .frame(width: 70, alignment: .leading)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 8) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 6), count: 6), alignment: .leading, spacing: 6) {
                    ForEach(symbols, id: \.self) { symbol in
                        let on = draft.imageData == nil && draft.symbol == symbol
                        Button {
                            draft.symbol = symbol
                            draft.imageData = nil
                        } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(on ? KoncluiTheme.onAccent : KoncluiTheme.textBody)
                                .frame(width: 26, height: 26)
                                .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(on ? KoncluiTheme.accent : Color.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        .accessibilityLabel(Text(verbatim: symbol))
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                HStack(spacing: 8) {
                    if let data = draft.imageData, let image = NSImage(data: data) {
                        Image(nsImage: image).resizable().scaledToFill()
                            .frame(width: 26, height: 26)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(KoncluiTheme.accent, lineWidth: 2))
                        Button("konclui.reminders.image.remove") {
                            draft.imageData = nil
                            if draft.symbol == nil { draft.symbol = KoncluiReminderRules.symbols[0] }
                        }
                        .buttonStyle(.koncluiSecondary)
                        .controlSize(.small)
                    }
                    Button("konclui.reminders.image.choose", action: chooseImage)
                        .buttonStyle(.koncluiSecondary)
                        .controlSize(.small)
                }
            }
        }
    }

    private func chooseImage() {
        imageProblem = nil
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsOtherFileTypes = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url), NSImage(data: data) != nil else {
            imageProblem = String(localized: "konclui.reminders.issue.image-read")
            return
        }
        guard data.count <= KoncluiReminderRules.maxImageBytes else {
            imageProblem = String(localized: "konclui.reminders.issue.image-size")
            return
        }
        draft.imageData = data
    }

    // MARK: Buttons

    @ViewBuilder private var buttons: some View {
        Toggle(isOn: $draft.snoozeOn) { Text("konclui.reminders.snooze").koncluiType(.body) }
            .disabled(draft.hasSnoozeButton)
        if draft.snoozeOn {
            row("konclui.reminders.snooze.length") {
                Picker("", selection: $draft.snoozeMinutes) {
                    ForEach(snoozeChoices, id: \.self) { minutes in
                        Text("konclui.reminders.snooze.minutes \(minutes)").tag(minutes)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
        }
        if draft.hasSnoozeButton {
            Text("konclui.reminders.snooze.locked")
                .koncluiType(.detail)
                .foregroundColor(KoncluiTheme.secondary(contrast))
        }
        ForEach($draft.buttons) { $button in
            buttonEditor($button)
        }
        if shownIssue == .buttonTitle || shownIssue == .link {
            KoncluiHint(text: String(localized: String.LocalizationValue(shownIssue?.key ?? "")))
        }
        if draft.buttons.count < KoncluiReminderRules.maxButtons {
            Button {
                draft.buttons.append(ReminderButton(title: String(localized: "konclui.reminders.button.done"), action: .complete, url: nil))
            } label: {
                Label("konclui.reminders.button.add", systemImage: "plus")
            }
            .buttonStyle(.koncluiSecondary)
            .controlSize(.small)
        }
    }

    private var snoozeChoices: [Int] {
        KoncluiReminderRules.snoozeChoices.contains(draft.snoozeMinutes)
            ? KoncluiReminderRules.snoozeChoices
            : (KoncluiReminderRules.snoozeChoices + [draft.snoozeMinutes]).sorted()
    }

    private func buttonEditor(_ button: Binding<ReminderButton>) -> some View {
        let actions = KoncluiReminderRules.buttonActions
            + (KoncluiReminderRules.buttonActions.contains(button.wrappedValue.action) ? [] : [button.wrappedValue.action])
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField(String(localized: "konclui.reminders.button.title"), text: button.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous).fill(KoncluiTheme.field))
                    .overlay(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous)
                        .strokeBorder(KoncluiTheme.controlStroke(contrast)))
                Picker("", selection: Binding(get: { button.wrappedValue.action }, set: { action in
                    let old = button.wrappedValue.action
                    // A title still the old action's default follows the new action.
                    if button.wrappedValue.title == String(localized: String.LocalizationValue(KoncluiReminderRules.defaultTitleKey(old))) {
                        button.wrappedValue.title = String(localized: String.LocalizationValue(KoncluiReminderRules.defaultTitleKey(action)))
                    }
                    button.wrappedValue.action = action
                    if action != .openURL { button.wrappedValue.url = nil }
                })) {
                    ForEach(actions) { action in
                        Text(LocalizedStringKey(KoncluiReminderRules.actionKey(action))).tag(action)
                    }
                }
                .labelsHidden()
                .frame(width: 130)
                Button {
                    draft.buttons.removeAll { $0.id == button.wrappedValue.id }
                } label: {
                    Image(systemName: "minus.circle").foregroundColor(KoncluiTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .pointerStyle(.link)
                .help(Text("konclui.reminders.button.remove"))
                .accessibilityLabel(Text("konclui.reminders.button.remove"))
            }
            if button.wrappedValue.action == .openURL {
                TextField(String(localized: "konclui.reminders.link.placeholder"), text: Binding(
                    get: { button.wrappedValue.url ?? "" }, set: { button.wrappedValue.url = $0 }))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous).fill(KoncluiTheme.field))
                    .overlay(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous)
                        .strokeBorder(KoncluiTheme.controlStroke(contrast)))
            }
        }
    }

    // MARK: - Pieces

    private func symbolTile(size: CGFloat) -> some View {
        KoncluiReminderIcon(symbol: draft.symbol, imageData: draft.imageData, active: draft.isActive, size: size)
    }
}

/// A reminder's icon in its tile: the list's rows and the editor's header.
struct KoncluiReminderIcon: View {
    let symbol: String?
    let imageData: Data?
    let active: Bool
    var size: CGFloat = 30

    var body: some View {
        Group {
            if let data = imageData, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: symbol ?? "bell.fill")
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundColor(active ? KoncluiTheme.accent : KoncluiTheme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(active ? KoncluiTheme.accent.opacity(0.16) : Color.white.opacity(0.06))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// The words of dates and summaries, shared by the list and the editor.
enum KoncluiReminderWords {
    static func when(_ date: Date, now: Date = Date()) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        switch KoncluiReminderRules.day(of: date, now: now) {
        case .today:    return String(localized: "konclui.reminders.day.today \(time)")
        case .tomorrow: return String(localized: "konclui.reminders.day.tomorrow \(time)")
        case .thisWeek: return date.formatted(.dateTime.weekday(.wide).hour().minute())
        case .later:    return date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        }
    }

    static func status(_ status: KoncluiReminderRules.Status) -> String {
        switch status {
        case .snoozed(let until):
            return String(localized: "konclui.reminders.status.snoozed \(until.formatted(date: .omitted, time: .shortened))")
        default:
            return String(localized: String.LocalizationValue(status.key))
        }
    }

    /// "Hoje, 17:30 · Todo dia · Adiar 5 min": the when, the repeat and the snooze of a draft or a reminder.
    static func summary(_ draft: KoncluiReminderDraft, now: Date = Date()) -> String {
        let due = draft.isActive ? (KoncluiReminderRules.firstDue(draft.dueAt, repeats: draft.repeats, now: now) ?? draft.dueAt)
                                 : draft.dueAt
        var parts = [when(due, now: now), String(localized: String.LocalizationValue(KoncluiReminderRules.repeatKey(draft.repeats)))]
        if draft.presentation == .fullScreen { parts.append(String(localized: "konclui.reminders.display.full")) }
        if draft.snoozeOn { parts.append(String(localized: "Snooze · \(draft.snoozeMinutes) min")) }
        return parts.joined(separator: " · ")
    }
}
#endif
