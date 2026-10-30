#if !APPSTORE
import AppKit
import SwiftUI
import UserNotifications

// Koncluí: the Lembretes page of the window, in the place of the owner's RemindersSettingsSection (left as it is; the App
// Store build still shows it). The page is the list, like Agentes: one calm row per reminder (its icon, its name, when it
// rings, its status), the whole row a door to the editor (KoncluiReminderEditor.swift), and one primary, "Novo lembrete",
// that opens the same editor empty. Below, how an agent creates reminders through the MCP, behind a disclosure.
//
// Every change offers Undo (UX.md 1.5) through the page's floating bar (KoncluiSettingsPage, `koncluiUndoBar`). A draft
// survives Cancel (UX.md 1.3). The reminders, their storage and their alerts stay the owner's (ReminderManager).

struct KoncluiRemindersPage: View {
    @ObservedObject private var manager = ReminderManager.shared
    @State private var editor: Sheet?
    @ObservedObject private var drafts = KoncluiReminderDrafts.shared
    @State private var restored = false
    @State private var notificationsOff = false
    @State private var mcpOpen = false
    @State private var detailsOpen = false
    @State private var copied: Copy?
    @Environment(\.colorSchemeContrast) private var contrast

    private enum Sheet: Identifiable {
        case new, edit(UUID)
        var id: String {
            switch self {
            case .new: return "new"
            case .edit(let id): return id.uuidString
            }
        }
    }

    private enum Copy { case command, json }

    private var reminders: [Reminder] { KoncluiReminderRules.ordered(manager.reminders + KoncluiRemindersDebug.samples) }

    var body: some View {
        VStack(alignment: .leading, spacing: KoncluiSpace.sectionGap) {
            if !manager.storageReady {
                KoncluiHint(text: manager.statusMessage)
            } else if reminders.isEmpty {
                empty
            } else {
                list
            }
            if notificationsOff { notificationsLine }
            mcp
        }
        .sheet(item: $editor) { sheet in editorView(sheet) }
        .task { await readNotifications() }
        .onAppear {
            guard !KoncluiRemindersDebug.opened else { return }
            KoncluiRemindersDebug.opened = true
            switch KoncluiRemindersDebug.editor {
            case "new"?: open(.new)
            case "edit"?: if let first = reminders.first { open(.edit(first.id)) }
            default: break
            }
        }
    }

    // MARK: - The list

    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            KoncluiReminderIcon(symbol: "bell.fill", imageData: nil, active: true, size: 36)
            Text("konclui.reminders.empty.title")
                .koncluiType(.title)
                .foregroundColor(KoncluiTheme.textPrimary)
            Text("konclui.reminders.empty.body")
                .koncluiType(.body)
                .foregroundColor(KoncluiTheme.textBody)
                .fixedSize(horizontal: false, vertical: true)
            newButton
        }
        .padding(KoncluiSpace.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KoncluiReminderCard(hovering: false))
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: KoncluiSpace.rowGap) {
            HStack {
                Text("konclui.reminders.list").koncluiType(.label).foregroundColor(KoncluiTheme.textTertiary)
                Spacer()
                newButton
            }
            ForEach(reminders) { reminder in
                KoncluiReminderRow(reminder: reminder) { open(.edit(reminder.id)) }
            }
        }
    }

    private var newButton: some View {
        Button { open(.new) } label: {
            Label("konclui.reminders.new", systemImage: "plus")
        }
        .buttonStyle(.koncluiPrimary)
        .disabled(!manager.storageReady)
    }

    // MARK: - Notifications

    private var notificationsLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            KoncluiHint(text: String(localized: "konclui.reminders.notifications.off"))
            Spacer(minLength: 8)
            Button("konclui.reminders.notifications.open") {
                let id = Bundle.main.bundleIdentifier ?? ""
                if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.koncluiSecondary)
            .controlSize(.small)
        }
    }

    private func readNotifications() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsOff = settings.authorizationStatus == .denied
    }

    // MARK: - MCP

    private var mcp: some View {
        DisclosureGroup(isExpanded: $mcpOpen) {
            VStack(alignment: .leading, spacing: 10) {
                Text("konclui.reminders.mcp.body")
                    .koncluiType(.body)
                    .foregroundColor(KoncluiTheme.textBody)
                    .fixedSize(horizontal: false, vertical: true)
                Text("konclui.reminders.mcp.local")
                    .koncluiType(.detail)
                    .foregroundColor(KoncluiTheme.secondary(contrast))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    copyButton(.command, title: "konclui.reminders.mcp.copy-command", text: KoncluiRemindersMCP.command)
                    copyButton(.json, title: "konclui.reminders.mcp.copy-json", text: KoncluiRemindersMCP.json)
                }
                Text("konclui.reminders.mcp.how")
                    .koncluiType(.detail)
                    .foregroundColor(KoncluiTheme.secondary(contrast))
                    .fixedSize(horizontal: false, vertical: true)
                DisclosureGroup(isExpanded: $detailsOpen) {
                    Text(verbatim: KoncluiRemindersMCP.command + "\n\n" + KoncluiRemindersMCP.json)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(KoncluiTheme.textBody)
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: KoncluiRadius.control).fill(KoncluiTheme.field))
                        .padding(.top, 6)
                } label: {
                    Text("konclui.hooks.details").koncluiType(.detail).foregroundColor(KoncluiTheme.textBody)
                }
            }
            .padding(.top, 10)
        } label: {
            Text("konclui.reminders.mcp.title").koncluiType(.bodyStrong).foregroundColor(KoncluiTheme.textPrimary)
        }
    }

    private func copyButton(_ kind: Copy, title: LocalizedStringKey, text: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = kind
            Task {
                try? await Task.sleep(for: .seconds(2))
                if copied == kind { copied = nil }
            }
        } label: {
            if copied == kind {
                Label("konclui.reminders.mcp.copied", systemImage: "checkmark")
            } else {
                Label(title, systemImage: "doc.on.doc")
            }
        }
        .buttonStyle(.koncluiSecondary)
        .controlSize(.small)
    }

    // MARK: - The editor

    private func open(_ sheet: Sheet) {
        switch sheet {
        case .new:
            restored = drafts.new != nil
            if drafts.new == nil { drafts.new = Self.blank() }
        case .edit(let id):
            guard let reminder = reminders.first(where: { $0.id == id }) else { return }
            restored = drafts.edits[id] != nil
            if drafts.edits[id] == nil { drafts.edits[id] = KoncluiReminderDraft(reminder) }
        }
        editor = sheet
    }

    private static func blank() -> KoncluiReminderDraft {
        KoncluiReminderDraft.blank(now: Date(), doneTitle: String(localized: "konclui.reminders.button.done"))
    }

    @ViewBuilder private func editorView(_ sheet: Sheet) -> some View {
        switch sheet {
        case .new:
            KoncluiReminderEditor(existing: nil, draft: newBinding, restored: restored,
                                  cancel: { closeNew(saved: false) }, save: create, delete: nil,
                                  startOver: { drafts.new = Self.blank(); restored = false })
        case .edit(let id):
            if let reminder = reminders.first(where: { $0.id == id }) {
                KoncluiReminderEditor(existing: reminder, draft: editBinding(id, reminder), restored: restored,
                                      cancel: { closeEdit(reminder, saved: false) },
                                      save: { update(reminder) },
                                      delete: { delete(reminder) },
                                      startOver: { drafts.edits[id] = KoncluiReminderDraft(reminder); restored = false })
            }
        }
    }

    private var newBinding: Binding<KoncluiReminderDraft> {
        // Never a fresh blank here: a value that changes on every read redraws the editor forever.
        Binding(get: { drafts.new ?? drafts.placeholder }, set: { drafts.new = $0 })
    }

    private func editBinding(_ id: UUID, _ reminder: Reminder) -> Binding<KoncluiReminderDraft> {
        Binding(get: { drafts.edits[id] ?? KoncluiReminderDraft(reminder) }, set: { drafts.edits[id] = $0 })
    }

    /// Closing without saving keeps a draft only when something was typed or chosen.
    private func closeNew(saved: Bool) {
        if saved { drafts.new = nil }
        else if let draft = drafts.new, draft.sameChoices(as: Self.blank()) { drafts.new = nil }
        editor = nil
    }

    private func closeEdit(_ reminder: Reminder, saved: Bool) {
        if saved || drafts.edits[reminder.id] == KoncluiReminderDraft(reminder) { drafts.edits[reminder.id] = nil }
        editor = nil
    }

    // MARK: - Saving, with Undo

    private func create() -> String? {
        guard let draft = drafts.new else { return nil }
        let due = KoncluiReminderRules.firstDue(draft.dueAt, repeats: draft.repeats, now: Date()) ?? draft.dueAt
        do {
            let reminder = try manager.create(draft.ownerDraft(dueAt: due))
            closeNew(saved: true)
            KoncluiUndoCenter.shared.offer(String(localized: "konclui.reminders.undo.created \(KoncluiReminderWords.when(due))")) {
                ReminderManager.shared.delete(id: reminder.id)
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func update(_ previous: Reminder) -> String? {
        guard let draft = drafts.edits[previous.id] else { return nil }
        let due = draft.isActive ? (KoncluiReminderRules.firstDue(draft.dueAt, repeats: draft.repeats, now: Date()) ?? draft.dueAt)
                                 : draft.dueAt
        do {
            var updated = try draft.ownerDraft(dueAt: due).validated(id: previous.id)
            updated.isActive = draft.isActive
            // A snooze holds only while nothing about the time changed.
            let sameTime = due == previous.dueAt && draft.repeats == previous.repeats && previous.isActive && draft.isActive
            updated.snoozedUntil = sameTime ? previous.snoozedUntil : nil
            try manager.update(updated)
            closeEdit(previous, saved: true)
            let words = !draft.isActive && previous.isActive ? "konclui.reminders.undo.stopped" : "konclui.reminders.undo.saved"
            KoncluiUndoCenter.shared.offer(String(localized: String.LocalizationValue(words))) {
                try? ReminderManager.shared.update(previous)
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func delete(_ reminder: Reminder) {
        drafts.edits[reminder.id] = nil
        editor = nil
        manager.delete(id: reminder.id)
        KoncluiUndoCenter.shared.offer(String(localized: "konclui.reminders.undo.deleted \(reminder.title)")) {
            Self.restore(reminder)
        }
    }

    /// Undo of a delete: the same reminder again (a new id). A stopped one comes back stopped, its time moved ahead so it
    /// does not ring on the way.
    private static func restore(_ reminder: Reminder) {
        let manager = ReminderManager.shared
        let draft = KoncluiReminderDraft(reminder)
        let ahead = Date().addingTimeInterval(86_400)
        let due = reminder.isActive
            ? (KoncluiReminderRules.firstDue(reminder.nextFireDate, repeats: reminder.repeats, now: Date()) ?? reminder.nextFireDate)
            : max(reminder.dueAt, ahead)
        guard let back = try? manager.create(draft.ownerDraft(dueAt: due)) else { return }
        if !reminder.isActive { manager.stop(id: back.id) }
    }
}

// MARK: - Drafts

/// The editor's drafts, outside the page: they survive Cancel, a click outside, moving to another page and closing the
/// window (UX.md 1.3), until the app quits.
@MainActor
final class KoncluiReminderDrafts: ObservableObject {
    static let shared = KoncluiReminderDrafts()
    @Published var new: KoncluiReminderDraft?
    @Published var edits: [UUID: KoncluiReminderDraft] = [:]
    /// What the new-reminder binding reads before `new` is set: one value, so reading it twice gives the same thing.
    let placeholder = KoncluiReminderDraft.blank(now: Date(), doneTitle: String(localized: "konclui.reminders.button.done"))
}

// MARK: - A row

private struct KoncluiReminderRow: View {
    let reminder: Reminder
    let open: () -> Void
    @State private var hovering = false

    private var status: KoncluiReminderRules.Status { KoncluiReminderRules.status(reminder) }

    private var tone: KoncluiStatus.Tone {
        switch status {
        case .active:  return .ok
        case .snoozed: return .attention
        case .stopped: return .off
        }
    }

    private var detail: String {
        var parts: [String] = []
        // A snoozed one says its time in its status.
        if status == .active { parts.append(KoncluiReminderWords.when(reminder.nextFireDate)) }
        parts.append(String(localized: String.LocalizationValue(KoncluiReminderRules.repeatKey(reminder.repeats))))
        parts.append(String(localized: reminder.presentation == .card ? "konclui.reminders.display.card" : "konclui.reminders.display.full"))
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                KoncluiReminderIcon(symbol: reminder.symbol, imageData: reminder.imageData, active: reminder.isActive)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: reminder.title)
                        .koncluiType(.bodyStrong)
                        .foregroundColor(reminder.isActive ? KoncluiTheme.textPrimary : KoncluiTheme.textSecondary)
                        .lineLimit(1)
                    Text(verbatim: detail)
                        .koncluiType(.detail)
                        .foregroundColor(KoncluiTheme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                KoncluiStatus(tone: tone, text: KoncluiReminderWords.status(status), door: true)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(minHeight: 52)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KoncluiReminderCard(hovering: hovering))
            .contentShape(RoundedRectangle(cornerRadius: KoncluiRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .onHover { hovering = $0 }
        .accessibilityLabel(Text(verbatim: reminder.title))
        .accessibilityValue(Text(verbatim: KoncluiReminderWords.status(status) + ", " + detail))
        .accessibilityHint(Text("konclui.reminders.row.hint"))
    }
}

/// The card behind a row, as Agentes draws its rows.
private struct KoncluiReminderCard: View {
    let hovering: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        RoundedRectangle(cornerRadius: KoncluiRadius.card, style: .continuous)
            .fill(KoncluiTheme.card)
            .overlay(RoundedRectangle(cornerRadius: KoncluiRadius.card, style: .continuous).fill(Color.white.opacity(hovering ? 0.04 : 0)))
            .overlay(RoundedRectangle(cornerRadius: KoncluiRadius.card, style: .continuous).strokeBorder(KoncluiTheme.hairline(contrast)))
    }
}

// MARK: - MCP

/// What an agent's MCP configuration needs to reach the reminders: the bridge script HookServer installs next to the hooks.
enum KoncluiRemindersMCP {
    static let server = "konclui-reminders"
    static var script: String { HookServer.supportDir.appendingPathComponent("coucou-mcp.py").path }

    static var command: String {
        "claude mcp add --scope user \(server) -- /usr/bin/python3 -I \"\(script)\""
    }

    static var json: String {
        let config: [String: Any] = ["mcpServers": [server: ["command": "/usr/bin/python3", "args": ["-I", script]]]]
        guard let data = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }
}

// MARK: - Screenshots (DEBUG builds only)

/// `-konclui.debug.reminderEditor new` opens the editor on a new reminder when the page shows; `edit` on the first row.
/// `-konclui.debug.reminderSamples YES` adds three sample rows that are never saved (saving one fails: it is not stored).
enum KoncluiRemindersDebug {
    /// The flag opens the editor once, not each time the page appears.
    @MainActor static var opened = false

    static var editor: String? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "konclui.debug.reminderEditor")
        #else
        nil
        #endif
    }

    static let samples: [Reminder] = {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "konclui.debug.reminderSamples") else { return [] }
        let now = Date()
        func sample(_ title: String, _ minutes: Double, _ repeats: ReminderRepeat, _ symbol: String,
                    _ presentation: ReminderPresentation = .card, active: Bool = true, snoozed: Bool = false) -> Reminder {
            var draft = KoncluiReminderDraft.blank(now: now, doneTitle: String(localized: "konclui.reminders.button.done"))
            draft.title = title
            draft.repeats = repeats
            draft.symbol = symbol
            draft.presentation = presentation
            var reminder = draft.reminder(dueAt: now.addingTimeInterval(minutes * 60))
            reminder.isActive = active
            if snoozed { reminder.snoozedUntil = now.addingTimeInterval(300) }
            return reminder
        }
        return [sample("Beber água", 25, .daily, "drop.fill"),
                sample("Revisar o PR do notch", 3, .none, "checklist", snoozed: true),
                sample("Daily com o time", 60 * 20, .weekdays, "phone.fill", .fullScreen),
                sample("Alongar", -90, .none, "figure.walk", active: false)]
        #else
        return []
        #endif
    }()
}
#endif
