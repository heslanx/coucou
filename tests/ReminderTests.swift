import Foundation

@main
struct ReminderTests {
    static func main() throws {
        try validatesReminderContentAndActions()
        try rejectsUnsafeLinks()
        try exposesOnlyCredentialFreeHTTPSLinks()
        try rejectsSnoozeButtonsWhenSnoozeIsDisabled()
        try calculatesRecurringDates()
        try advancesAfterMissedOccurrences()
        try preservesOptionalSnoozeAndImage()
        try preservesUnreadableReminderFiles()
        try storesReminderFilesWithOwnerOnlyPermissions()
        print("Reminder tests passed")
    }

    private static func validatesReminderContentAndActions() throws {
        let reminder = try ReminderDraft(
            title: "Review the release",
            message: "Check the changelog before publishing.",
            dueAt: Date(timeIntervalSince1970: 1_800_000_000),
            presentation: .card,
            width: 480,
            height: 320,
            positionX: 0.5,
            positionY: 0.5,
            snoozeMinutes: 5,
            repeats: .none,
            buttons: [ReminderButton(title: "Open draft", action: .openURL, url: "https://example.com/draft")],
            symbol: "bell",
            imageData: nil
        ).validated()

        try expect(reminder.title == "Review the release", "preserves reminder title")
        try expect(reminder.buttons.first?.action == .openURL, "preserves button action")
        try expect(reminder.presentation == .card, "preserves selected presentation")
    }

    private static func rejectsUnsafeLinks() throws {
        let draft = ReminderDraft(
            title: "Unsafe link",
            message: "",
            dueAt: Date(timeIntervalSince1970: 1_800_000_000),
            presentation: .card,
            width: 480,
            height: 320,
            positionX: 0.5,
            positionY: 0.5,
            snoozeMinutes: nil,
            repeats: .none,
            buttons: [ReminderButton(title: "Open file", action: .openURL, url: "file:///etc/passwd")],
            symbol: nil,
            imageData: nil
        )

        try expectThrows("file URLs are rejected") { _ = try draft.validated() }
    }

    private static func exposesOnlyCredentialFreeHTTPSLinks() throws {
        let safe = ReminderButton(title: "Open", action: .openURL, url: "https://example.com/task")
        let credentialed = ReminderButton(title: "Open", action: .openURL, url: "https://user:secret@example.com/task")
        let insecure = ReminderButton(title: "Open", action: .openURL, url: "http://example.com/task")

        try expect(safe.httpsURL?.host == "example.com", "allows credential-free HTTPS links")
        try expect(credentialed.httpsURL == nil, "rejects URLs with embedded credentials")
        try expect(insecure.httpsURL == nil, "rejects non-HTTPS URLs")
    }

    private static func rejectsSnoozeButtonsWhenSnoozeIsDisabled() throws {
        let draft = ReminderDraft(
            title: "Snooze disabled",
            message: "",
            dueAt: Date(timeIntervalSince1970: 1_800_000_000),
            presentation: .card,
            width: 480,
            height: 320,
            positionX: 0.5,
            positionY: 0.5,
            snoozeMinutes: nil,
            repeats: .none,
            buttons: [ReminderButton(title: "Snooze", action: .snooze, url: nil)],
            symbol: nil,
            imageData: nil
        )
        try expectThrows("snooze action requires snooze to be enabled") { _ = try draft.validated() }
    }

    private static func calculatesRecurringDates() throws {
        let daily = try ReminderDraft(
            title: "Take a break",
            message: "",
            dueAt: Date(timeIntervalSince1970: 1_800_000_000),
            presentation: .card,
            width: 480,
            height: 320,
            positionX: 0.5,
            positionY: 0.5,
            snoozeMinutes: 5,
            repeats: .daily,
            buttons: [],
            symbol: nil,
            imageData: nil
        ).validated()

        let due = Date(timeIntervalSince1970: 1_800_000_000)
        try expect(daily.nextOccurrence(after: due) == due.addingTimeInterval(86_400), "daily reminder repeats after one day")
        try expect(daily.nextOccurrence(after: due, snoozeMinutes: 10) == due.addingTimeInterval(600), "snooze overrides recurrence")
    }

    private static func advancesAfterMissedOccurrences() throws {
        let due = Date(timeIntervalSince1970: 1_800_000_000)
        let weekdayReminder = try ReminderDraft(
            title: "Weekday reminder",
            message: "",
            dueAt: due,
            presentation: .card,
            width: 480,
            height: 320,
            positionX: 0.5,
            positionY: 0.5,
            snoozeMinutes: nil,
            repeats: .weekdays,
            buttons: [],
            symbol: nil,
            imageData: nil
        ).validated()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let afterManyMissedDates = due.addingTimeInterval(15 * 86_400)
        guard let next = weekdayReminder.nextOccurrence(after: afterManyMissedDates, calendar: calendar) else {
            throw TestFailure(message: "weekday reminder should advance after missed dates")
        }
        try expect(next > afterManyMissedDates, "weekday schedule advances beyond the supplied date")
        try expect(!calendar.isDateInWeekend(next), "weekday schedule never lands on a weekend")
    }

    private static func preservesOptionalSnoozeAndImage() throws {
        let image = Data([0x89, 0x50, 0x4E, 0x47])
        let reminder = try ReminderDraft(
            title: "Look at this",
            message: "",
            dueAt: Date(timeIntervalSince1970: 1_800_000_000),
            presentation: .fullScreen,
            width: 600,
            height: 400,
            positionX: 0.5,
            positionY: 0.5,
            snoozeMinutes: nil,
            repeats: .none,
            buttons: [ReminderButton(title: "Done", action: .complete, url: nil)],
            symbol: "photo",
            imageData: image
        ).validated()

        try expect(reminder.snoozeMinutes == nil, "omits snooze when disabled")
        try expect(reminder.imageData == image, "preserves inline image data")
        try expect(reminder.presentation == .fullScreen, "preserves full-screen presentation")
    }

    private static func preservesUnreadableReminderFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("coucou-reminder-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("reminders.json")
        let unreadableData = Data("not-json".utf8)
        try unreadableData.write(to: url)
        let store = ReminderFileStore(url: url)

        do {
            _ = try store.load()
            throw TestFailure(message: "corrupt reminders file should be rejected")
        } catch is DecodingError {
        }

        let preservedData = try Data(contentsOf: url)
        try expect(preservedData == unreadableData, "loading a corrupt reminders file leaves it untouched")

        let missingStore = ReminderFileStore(url: directory.appendingPathComponent("missing.json"))
        let missingReminders = try missingStore.load()
        try expect(missingReminders.isEmpty, "missing reminders file starts as an empty list")
    }

    private static func storesReminderFilesWithOwnerOnlyPermissions() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("coucou-reminder-permissions-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("reminders.json")

        try ReminderFileStore(url: url).save([])
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let directoryAttributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        let fileMode = (fileAttributes[.posixPermissions] as? NSNumber)?.intValue
        let directoryMode = (directoryAttributes[.posixPermissions] as? NSNumber)?.intValue
        try expect(fileMode == 0o600, "reminder file is private to its owner")
        try expect(directoryMode == 0o700, "reminder directory is private to its owner")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw TestFailure(message: message) }
    }

    private static func expectThrows(_ message: String, _ body: () throws -> Void) throws {
        do {
            try body()
            throw TestFailure(message: message)
        } catch is ReminderValidationError {
            return
        }
    }
}

struct TestFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}
