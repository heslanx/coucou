import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RemindersSettingsSection: View {
    @StateObject private var manager = ReminderManager.shared
    @State private var title = ""
    @State private var message = ""
    @State private var dueAt = Date().addingTimeInterval(600)
    @State private var presentation: ReminderPresentation = .card
    @State private var repeats: ReminderRepeat = .none
    @State private var width = 480.0
    @State private var height = 320.0
    @State private var positionX = 0.5
    @State private var positionY = 0.5
    @State private var screenIndex = 0
    @State private var editingReminderID: UUID?
    @State private var reminderPendingDeletion: Reminder?
    @State private var snoozeEnabled = true
    @State private var snoozeMinutes = 5
    @State private var symbol = "bell.fill"
    @State private var imageData: Data?
    @State private var buttons = [ReminderButton(title: "Done", action: .complete, url: nil)]
    @State private var copiedConfig = false

    private var screens: [NSScreen] { NSScreen.screens }
    private var hasSnoozeActionButton: Bool { buttons.contains { $0.action == .snooze } }
    private var mcpScriptPath: String {
        NSHomeDirectory() + "/Library/Application Support/NotchBuddy/coucou-mcp.py"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Create a reminder and choose how Coucou should interrupt you.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            createForm
            remindersList
            #if !APPSTORE
            mcpInstructions
            #endif

            if !manager.statusMessage.isEmpty {
                Text(manager.statusMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var createForm: some View {
        GroupBox(editingReminderID == nil ? "New reminder" : "Edit reminder") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Title", text: $title)
                TextField("Message (optional)", text: $message, axis: .vertical)
                    .lineLimit(2...5)
                DatePicker("Show at", selection: $dueAt)
                Picker("Repeat", selection: $repeats) {
                    Text("Only once").tag(ReminderRepeat.none)
                    Text("Every day").tag(ReminderRepeat.daily)
                    Text("Weekdays").tag(ReminderRepeat.weekdays)
                    Text("Every week").tag(ReminderRepeat.weekly)
                }
                Picker("Display", selection: $presentation) {
                    Text("Floating card").tag(ReminderPresentation.card)
                    Text("Full-screen alert").tag(ReminderPresentation.fullScreen)
                }
                Picker("Screen", selection: $screenIndex) {
                    ForEach(Array(screens.enumerated()), id: \.offset) { index, screen in
                        Text(screen.localizedName).tag(index)
                    }
                }
                if presentation == .card {
                    dimensionSlider("Width", value: $width, range: 260...900)
                    dimensionSlider("Height", value: $height, range: 180...720)
                    dimensionSlider("Horizontal position", value: $positionX, range: 0...1)
                    dimensionSlider("Vertical position from top", value: $positionY, range: 0...1)
                } else {
                    dimensionSlider("Alert content width", value: $width, range: 260...900)
                }

                Toggle("Offer snooze", isOn: $snoozeEnabled)
                    .disabled(hasSnoozeActionButton)
                if hasSnoozeActionButton {
                    Text("Remove custom Snooze buttons before disabling snooze.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                if snoozeEnabled {
                    Stepper("Snooze for \(snoozeMinutes) minutes", value: $snoozeMinutes, in: 1...1_440)
                }

                HStack(spacing: 8) {
                    TextField("SF Symbol (optional)", text: $symbol)
                    Button(imageData == nil ? "Choose image…" : "Change image…", action: chooseImage)
                    if imageData != nil {
                        Button("Remove image", systemImage: "xmark.circle") { imageData = nil }
                            .labelStyle(.iconOnly)
                    }
                }

                Divider()
                HStack {
                    Text("Buttons")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Button("Add button", systemImage: "plus") {
                        guard buttons.count < 3 else { return }
                        buttons.append(ReminderButton(title: "Done", action: .complete, url: nil))
                    }
                    .disabled(buttons.count >= 3)
                }
                ForEach($buttons) { button in
                    buttonEditor(button)
                }

                HStack {
                    Button(editingReminderID == nil ? "Create reminder" : "Save changes",
                           systemImage: editingReminderID == nil ? "bell.badge.fill" : "checkmark",
                           action: saveReminder)
                        .buttonStyle(.borderedProminent)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if editingReminderID != nil {
                        Button("Cancel", action: resetForm)
                    }
                }
            }
            .padding(8)
        }
        .disabled(!manager.storageReady)
    }

    private var remindersList: some View {
        GroupBox("Reminders on this Mac") {
            if !manager.storageReady {
                Text("Saved reminders could not be loaded. Changes are disabled to protect the existing file.")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            } else if manager.reminders.isEmpty {
                Text("No reminders yet. Create one above or connect a local MCP client below.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            } else {
                VStack(spacing: 0) {
                    ForEach(manager.reminders) { reminder in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: reminder.symbol ?? "bell.fill")
                                .foregroundStyle(reminder.isActive ? .orange : .secondary)
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(reminder.title)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(reminderStatus(reminder))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if reminder.isActive {
                                Button("Show now", systemImage: "bell") {
                                    manager.present(id: reminder.id)
                                }
                                .labelStyle(.iconOnly)
                                .help("Show this reminder now")
                                Button("Edit", systemImage: "pencil") { edit(reminder) }
                                    .labelStyle(.iconOnly)
                                    .help("Edit this reminder")
                                Button("Stop", systemImage: "stop.fill") {
                                    manager.stop(id: reminder.id)
                                }
                                .labelStyle(.iconOnly)
                                .help("Stop future occurrences")
                            } else {
                                Button("Delete", systemImage: "trash") {
                                    reminderPendingDeletion = reminder
                                }
                                .labelStyle(.iconOnly)
                                .help("Delete this reminder")
                            }
                        }
                        .padding(.vertical, 9)
                        if reminder.id != manager.reminders.last?.id { Divider() }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .confirmationDialog("Delete reminder?",
                            isPresented: Binding(
                                get: { reminderPendingDeletion != nil },
                                set: { if !$0 { reminderPendingDeletion = nil } }
                            ),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let reminderPendingDeletion {
                    manager.delete(id: reminderPendingDeletion.id)
                }
                reminderPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { reminderPendingDeletion = nil }
        } message: {
            Text(reminderPendingDeletion?.title ?? "")
        }
    }

    private var mcpInstructions: some View {
        GroupBox("Connect a local MCP client") {
            VStack(alignment: .leading, spacing: 9) {
                Text("Coucou keeps reminders on this Mac. The MCP bridge uses a private local socket; it does not edit other apps’ settings or send calendar data.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Add this server to your MCP client configuration, then restart that client:")
                    .font(.system(size: 12))
                Text(mcpConfiguration)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                Button(copiedConfig ? "Copied" : "Copy MCP configuration", systemImage: copiedConfig ? "checkmark" : "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(mcpConfiguration, forType: .string)
                    copiedConfig = true
                }
            }
            .padding(8)
        }
    }

    private var mcpConfiguration: String {
        let config: [String: Any] = ["mcpServers": ["coucou-reminders": [
            "command": "/usr/bin/python3",
            "args": ["-I", mcpScriptPath]
        ]]]
        guard let data = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    private func buttonEditor(_ button: Binding<ReminderButton>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                TextField("Button title", text: button.title)
                Picker("Button action", selection: Binding(
                    get: { button.wrappedValue.action },
                    set: { action in
                        button.wrappedValue.action = action
                        if action != .openURL { button.wrappedValue.url = nil }
                    }
                )) {
                    Text("Open link").tag(ReminderButtonAction.openURL)
                    Text("Snooze").tag(ReminderButtonAction.snooze)
                    Text("Complete").tag(ReminderButtonAction.complete)
                    Text("Dismiss").tag(ReminderButtonAction.dismiss)
                    Text("Stop reminder").tag(ReminderButtonAction.stop)
                }
                .frame(width: 180)
                Button("Remove button", systemImage: "minus.circle") {
                    buttons.removeAll { $0.id == button.wrappedValue.id }
                }
                .labelStyle(.iconOnly)
            }
            if button.wrappedValue.action == .openURL {
                TextField("HTTPS link", text: Binding(
                    get: { button.wrappedValue.url ?? "" },
                    set: { button.wrappedValue.url = $0 }
                ))
            }
        }
    }

    private func dimensionSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .frame(width: 150, alignment: .leading)
            Slider(value: value, in: range)
            Text(range.upperBound <= 1 ? "\(Int(value.wrappedValue * 100))%" : "\(Int(value.wrappedValue)) pt")
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 60, alignment: .trailing)
        }
    }

    private func saveReminder() {
        do {
            let draft = ReminderDraft(title: title, message: message, dueAt: dueAt,
                                      presentation: presentation, width: width, height: height,
                                      positionX: positionX, positionY: positionY, screenIndex: screenIndex,
                                      snoozeMinutes: snoozeEnabled ? snoozeMinutes : nil,
                                      repeats: repeats, buttons: buttons,
                                      symbol: symbol.isEmpty ? nil : symbol,
                                      imageData: imageData)
            if let editingReminderID {
                let updated = try draft.validated(id: editingReminderID)
                try manager.update(updated)
            } else {
                try manager.create(draft)
            }
            resetForm()
        } catch {
            manager.report(error.localizedDescription)
        }
    }

    private func edit(_ reminder: Reminder) {
        editingReminderID = reminder.id
        title = reminder.title
        message = reminder.message
        dueAt = reminder.dueAt
        presentation = reminder.presentation
        repeats = reminder.repeats
        width = reminder.width
        height = reminder.height
        positionX = reminder.positionX
        positionY = reminder.positionY
        screenIndex = reminder.screenIndex
        snoozeMinutes = reminder.snoozeMinutes ?? 5
        snoozeEnabled = reminder.snoozeMinutes != nil
        symbol = reminder.symbol ?? ""
        imageData = reminder.imageData
        buttons = reminder.buttons
    }

    private func resetForm() {
        editingReminderID = nil
        title = ""
        message = ""
        dueAt = Date().addingTimeInterval(600)
        presentation = .card
        repeats = .none
        width = 480
        height = 320
        positionX = 0.5
        positionY = 0.5
        screenIndex = 0
        snoozeEnabled = true
        snoozeMinutes = 5
        symbol = "bell.fill"
        imageData = nil
        buttons = [ReminderButton(title: "Done", action: .complete, url: nil)]
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.allowsOtherFileTypes = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            guard data.count <= 2_000_000 else {
                manager.report("Choose an image smaller than 2 MB.")
                return
            }
            guard NSImage(data: data) != nil else {
                manager.report("That image could not be decoded. Choose a valid PNG or JPEG.")
                return
            }
            imageData = data
        } catch {
            manager.report("Image could not be opened: \(error.localizedDescription)")
        }
    }

    private func reminderStatus(_ reminder: Reminder) -> String {
        guard reminder.isActive else { return "Stopped" }
        let date = reminder.snoozedUntil ?? reminder.dueAt
        let schedule = date.formatted(date: .abbreviated, time: .shortened)
        let repeatName = reminder.repeats == .none ? "Once" : reminder.repeats.rawValue.capitalized
        let display = reminder.presentation == .fullScreen ? "Full screen" : "Floating card"
        return "\(schedule) · \(repeatName) · \(display)"
    }
}
