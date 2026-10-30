import AppKit
import Foundation
import UserNotifications
import Combine

@MainActor
final class ReminderManager: ObservableObject {
    static let shared = ReminderManager()
    private static let notificationPrefix = "coucou.reminder."
    private static let fileName = "reminders.json"

    @Published private(set) var reminders: [Reminder] = []
    @Published private(set) var statusMessage = ""
    @Published private(set) var storageReady = true

    private var timer: Timer?
    private var presentedIDs: Set<UUID> = []
    private var notificationTask: Task<Void, Never>?
    private var notificationRefreshRequested = false

    private init() {}

    var activeReminders: [Reminder] {
        reminders.filter(\.isActive).sorted { $0.nextFireDate < $1.nextFireDate }
    }

    func report(_ message: String) {
        statusMessage = message
    }

    func start() {
        load()
        UNUserNotificationCenter.current().delegate = ReminderNotificationDelegate.shared
        guard storageReady else { return }
        scheduleNotifications()
        presentDueReminders()
        scheduleDueCheck()
    }

    @discardableResult
    func create(_ draft: ReminderDraft) throws -> Reminder {
        try requireStorageReady()
        let reminder = try draft.validated()
        reminders.append(reminder)
        guard persist() else {
            reminders.removeAll { $0.id == reminder.id }
            throw ReminderManagerError.persistenceFailed(statusMessage)
        }
        statusMessage = String(localized: "Reminder created.")
        Task { await requestNotificationPermissionIfNeeded() }
        scheduleNotifications()
        presentDueReminders()
        scheduleDueCheck()
        return reminder
    }

    func update(_ reminder: Reminder) throws {
        try requireStorageReady()
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else {
            throw ReminderManagerError.notFound
        }
        let previous = reminders[index]
        let wasPresented = presentedIDs.contains(reminder.id)
        let validated = try draft(for: reminder).validated(id: reminder.id)
        var updated = validated
        updated.isActive = reminder.isActive
        updated.snoozedUntil = reminder.snoozedUntil
        ReminderWindowController.shared.dismiss(id: reminder.id)
        reminders[index] = updated
        presentedIDs.remove(reminder.id)
        guard persist() else {
            restore(previous, at: index, wasPresented: wasPresented)
            throw ReminderManagerError.persistenceFailed(statusMessage)
        }
        statusMessage = String(localized: "Reminder updated.")
        scheduleNotifications()
        presentDueReminders()
        scheduleDueCheck()
    }

    func perform(_ action: ReminderButtonAction, for id: UUID, button: ReminderButton? = nil) {
        guard storageReady else { return }
        guard let index = reminders.firstIndex(where: { $0.id == id }), reminders[index].isActive else { return }
        let previous = reminders[index]
        let wasPresented = presentedIDs.contains(id)
        var reminder = previous

        switch action {
        case .openURL:
            guard let url = (button ?? reminder.buttons.first(where: { $0.action == .openURL }))?.httpsURL,
                  NSWorkspace.shared.open(url) else { return }
            finishOccurrence(at: index, complete: false)
        case .snooze:
            guard let minutes = reminder.snoozeMinutes else { return }
            reminder.snoozedUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
            reminders[index] = reminder
            presentedIDs.remove(id)
            ReminderWindowController.shared.dismiss(id: id)
            statusMessage = String(format: String(localized: "Reminder snoozed for %lld minutes."), Int64(minutes))
        case .complete:
            finishOccurrence(at: index, complete: true)
        case .dismiss:
            finishOccurrence(at: index, complete: false)
        case .stop:
            reminder.isActive = false
            reminder.snoozedUntil = nil
            reminders[index] = reminder
            presentedIDs.remove(id)
            ReminderWindowController.shared.dismiss(id: id)
            statusMessage = String(localized: "Reminder stopped.")
        }

        guard persist() else {
            restore(previous, at: index, wasPresented: wasPresented)
            scheduleDueCheck()
            return
        }
        scheduleNotifications()
        scheduleDueCheck()
    }

    func snooze(id: UUID, minutes: Int) throws {
        try requireStorageReady()
        guard (1...1_440).contains(minutes) else { throw ReminderManagerError.invalidSnooze }
        guard let index = reminders.firstIndex(where: { $0.id == id && $0.isActive }) else {
            throw ReminderManagerError.notFound
        }
        guard reminders[index].snoozeMinutes != nil else { throw ReminderManagerError.snoozeDisabled }
        let previous = reminders[index]
        let wasPresented = presentedIDs.contains(id)
        reminders[index].snoozedUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        presentedIDs.remove(id)
        ReminderWindowController.shared.dismiss(id: id)
        guard persist() else {
            restore(previous, at: index, wasPresented: wasPresented)
            throw ReminderManagerError.persistenceFailed(statusMessage)
        }
        scheduleNotifications()
        scheduleDueCheck()
        statusMessage = String(format: String(localized: "Reminder snoozed for %lld minutes."), Int64(minutes))
    }

    func dismiss(id: UUID) {
        perform(.dismiss, for: id)
    }

    func stop(id: UUID) {
        perform(.stop, for: id)
    }

    func delete(id: UUID) {
        guard storageReady,
              let index = reminders.firstIndex(where: { $0.id == id }) else { return }
        let reminder = reminders[index]
        let wasPresented = presentedIDs.contains(id)
        reminders.remove(at: index)
        presentedIDs.remove(id)
        ReminderWindowController.shared.dismiss(id: id)
        guard persist() else {
            restore(reminder, at: index, wasPresented: wasPresented)
            return
        }
        scheduleNotifications()
        scheduleDueCheck()
        let center = UNUserNotificationCenter.current()
        Task {
            let delivered = await center.deliveredNotifications()
            let prefix = Self.notificationPrefix + id.uuidString
            center.removeDeliveredNotifications(withIdentifiers: delivered.map(\.request.identifier).filter { $0.hasPrefix(prefix) })
        }
        statusMessage = String(localized: "Reminder deleted.")
    }

    func present(id: UUID) {
        guard storageReady,
              let reminder = reminders.first(where: { $0.id == id && $0.isActive }) else { return }
        presentedIDs.insert(id)
        ReminderWindowController.shared.show(reminder)
    }

    private func finishOccurrence(at index: Int, complete: Bool) {
        var reminder = reminders[index]
        reminder.snoozedUntil = nil
        if !complete, let next = reminder.nextOccurrence(after: Date()) {
            reminder.dueAt = next
            statusMessage = String(localized: "Reminder dismissed. The next one is scheduled.")
        } else {
            reminder.isActive = false
            statusMessage = String(localized: complete ? "Reminder completed." : "Reminder dismissed.")
        }
        reminders[index] = reminder
        presentedIDs.remove(reminder.id)
        ReminderWindowController.shared.dismiss(id: reminder.id)
        scheduleDueCheck()
    }

    private func presentDueReminders(now: Date = Date()) {
        guard storageReady else { return }
        for reminder in reminders where reminder.isActive && reminder.nextFireDate <= now {
            guard presentedIDs.insert(reminder.id).inserted else { continue }
            ReminderWindowController.shared.show(reminder)
            if reminder.snoozedUntil != nil,
               let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                reminders[index].snoozedUntil = nil
                if persist() {
                    scheduleNotifications()
                } else {
                    reminders[index] = reminder
                }
            }
        }
        scheduleDueCheck()
    }

    private func scheduleDueCheck() {
        timer?.invalidate()
        guard storageReady else { timer = nil; return }
        guard let next = activeReminders.first(where: { !presentedIDs.contains($0.id) }) else {
            timer = nil
            return
        }
        let delay = max(0.1, next.nextFireDate.timeIntervalSinceNow)
        let dueTimer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.timer = nil
                self?.presentDueReminders()
            }
        }
        timer = dueTimer
        RunLoop.main.add(dueTimer, forMode: .common)
    }

    private func draft(for reminder: Reminder) -> ReminderDraft {
        ReminderDraft(title: reminder.title, message: reminder.message, dueAt: reminder.dueAt,
                      presentation: reminder.presentation, width: reminder.width, height: reminder.height,
                      positionX: reminder.positionX, positionY: reminder.positionY,
                      screenIndex: reminder.screenIndex,
                      snoozeMinutes: reminder.snoozeMinutes, repeats: reminder.repeats,
                      buttons: reminder.buttons, symbol: reminder.symbol, imageData: reminder.imageData)
    }

    private var store: ReminderFileStore { ReminderFileStore(url: Self.storageURL) }

    private func load() {
        do {
            reminders = try store.load()
            storageReady = true
        } catch {
            reminders = []
            storageReady = false
            statusMessage = String(format: String(localized: "Saved reminders could not be read from %@: %@. Changes are disabled to protect the existing file."),
                                   Self.storageURL.path, error.localizedDescription)
        }
    }

    func requireStorageReady() throws {
        guard storageReady else { throw ReminderManagerError.storageUnavailable(statusMessage) }
    }

    @discardableResult
    private func persist() -> Bool {
        guard storageReady else { return false }
        do {
            try store.save(reminders)
            return true
        } catch {
            statusMessage = String(format: String(localized: "Reminder could not be saved: %@"), error.localizedDescription)
            return false
        }
    }

    private func restore(_ reminder: Reminder, at index: Int, wasPresented: Bool) {
        if let existingIndex = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[existingIndex] = reminder
        } else {
            reminders.insert(reminder, at: min(index, reminders.count))
        }
        if wasPresented { present(id: reminder.id) }
    }

    private static var storageURL: URL {
        HookServer.supportDir.appendingPathComponent(fileName)
    }

    private func requestNotificationPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            do {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                statusMessage = String(format: String(localized: "System notification permission failed: %@"), error.localizedDescription)
                return
            }
        }
        let updatedSettings = await center.notificationSettings()
        if updatedSettings.authorizationStatus == .authorized || updatedSettings.authorizationStatus == .provisional {
            scheduleNotifications()
        } else {
            statusMessage = String(localized: "macOS notifications are off. Reminders will appear only while Coucou is open.")
        }
    }

    private func scheduleNotifications() {
        notificationRefreshRequested = true
        guard notificationTask == nil else { return }
        notificationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while self.notificationRefreshRequested {
                self.notificationRefreshRequested = false
                await self.refreshNotifications()
            }
            self.notificationTask = nil
        }
    }

    private func refreshNotifications() async {
        guard storageReady else { return }
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending.map(\.identifier).filter { $0.hasPrefix(Self.notificationPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        for reminder in activeReminders {
            for request in notificationRequests(for: reminder) {
                do { try await center.add(request) }
                catch { statusMessage = String(format: String(localized: "System reminder could not be scheduled: %@"), error.localizedDescription) }
            }
        }
    }

    private func notificationRequests(for reminder: Reminder) -> [UNNotificationRequest] {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.message
        content.sound = .default
        content.userInfo = ["reminderID": reminder.id.uuidString]
        let prefix = Self.notificationPrefix + reminder.id.uuidString

        if let snoozedUntil = reminder.snoozedUntil {
            return [UNNotificationRequest(identifier: prefix + ".snooze",
                                          content: content,
                                          trigger: calendarTrigger(for: snoozedUntil))]
        }
        switch reminder.repeats {
        case .none:
            guard reminder.dueAt > Date() else { return [] }
            return [UNNotificationRequest(identifier: prefix + ".once",
                                          content: content,
                                          trigger: calendarTrigger(for: reminder.dueAt))]
        case .daily:
            var components = Calendar.current.dateComponents([.hour, .minute], from: reminder.dueAt)
            components.second = 0
            return [UNNotificationRequest(identifier: prefix + ".daily", content: content,
                                          trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))]
        case .weekdays:
            return (2...6).map { weekday in
                var components = Calendar.current.dateComponents([.hour, .minute], from: reminder.dueAt)
                components.weekday = weekday
                components.second = 0
                return UNNotificationRequest(identifier: prefix + ".weekday.\(weekday)", content: content,
                                             trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))
            }
        case .weekly:
            var components = Calendar.current.dateComponents([.weekday, .hour, .minute], from: reminder.dueAt)
            components.second = 0
            return [UNNotificationRequest(identifier: prefix + ".weekly", content: content,
                                          trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))]
        }
    }

    private func calendarTrigger(for date: Date) -> UNCalendarNotificationTrigger {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}

enum ReminderManagerError: Error, LocalizedError {
    case notFound
    case storageUnavailable(String)
    case invalidIdentifier
    case invalidAction
    case invalidConfiguration
    case missingFields
    case invalidSnooze
    case snoozeDisabled
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound: String(localized: "Reminder was not found.")
        case .storageUnavailable(let message): message
        case .invalidIdentifier: String(localized: "Reminder ID is invalid.")
        case .invalidAction: String(localized: "Reminder action is not supported.")
        case .invalidConfiguration: String(localized: "The reminder contains an unsupported display, repeat, button, or image value.")
        case .missingFields: String(localized: "A reminder needs a title and an ISO 8601 due date.")
        case .invalidSnooze: String(localized: "Snooze must be between 1 and 1,440 minutes.")
        case .snoozeDisabled: String(localized: "Snooze is disabled for this reminder.")
        case .persistenceFailed(let message): message
        }
    }
}

@MainActor
final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderNotificationDelegate()

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let rawID = response.notification.request.content.userInfo["reminderID"] as? String
        nonisolated(unsafe) let done = completionHandler
        Task { @MainActor in
            if let rawID, let id = UUID(uuidString: rawID) {
                ReminderManager.shared.present(id: id)
            }
            done()
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let rawID = notification.request.content.userInfo["reminderID"] as? String
        nonisolated(unsafe) let done = completionHandler
        Task { @MainActor in
            let manager = ReminderManager.shared
            guard manager.storageReady else {
                done([.banner, .sound])
                return
            }
            if let rawID, let id = UUID(uuidString: rawID) {
                manager.present(id: id)
            }
            done([])
        }
    }
}
