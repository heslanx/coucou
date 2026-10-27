import Foundation

enum ReminderPresentation: String, Codable, CaseIterable, Identifiable {
    case card
    case fullScreen

    var id: String { rawValue }
}

enum ReminderRepeat: String, Codable, CaseIterable, Identifiable {
    case none
    case daily
    case weekdays
    case weekly

    var id: String { rawValue }
}

enum ReminderButtonAction: String, Codable, CaseIterable, Identifiable {
    case openURL
    case snooze
    case complete
    case dismiss
    case stop

    var id: String { rawValue }
}

struct ReminderButton: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var action: ReminderButtonAction
    var url: String?

    var httpsURL: URL? {
        guard let url,
              let components = URLComponents(string: url),
              components.scheme?.lowercased() == "https",
              url.count <= 2_048,
              components.host != nil,
              components.user == nil,
              components.password == nil else { return nil }
        return components.url
    }
}

struct Reminder: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var message: String
    var dueAt: Date
    var presentation: ReminderPresentation
    var width: Double
    var height: Double
    var positionX: Double
    var positionY: Double
    var screenIndex: Int = 0
    var snoozeMinutes: Int?
    var repeats: ReminderRepeat
    var buttons: [ReminderButton]
    var symbol: String?
    var imageData: Data?
    var isActive: Bool
    var snoozedUntil: Date?

    var nextFireDate: Date {
        snoozedUntil ?? dueAt
    }

    func nextOccurrence(after date: Date, snoozeMinutes: Int? = nil,
                        calendar: Calendar = .current) -> Date? {
        if let snoozeMinutes, snoozeMinutes > 0 {
            return date.addingTimeInterval(TimeInterval(snoozeMinutes * 60))
        }
        return ReminderSchedule.nextOccurrence(for: self, after: date, calendar: calendar)
    }
}

struct ReminderDraft {
    var title: String
    var message: String
    var dueAt: Date
    var presentation: ReminderPresentation
    var width: Double
    var height: Double
    var positionX: Double
    var positionY: Double
    var screenIndex: Int = 0
    var snoozeMinutes: Int?
    var repeats: ReminderRepeat
    var buttons: [ReminderButton]
    var symbol: String?
    var imageData: Data?

    func validated(id: UUID = UUID()) throws -> Reminder {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, trimmedTitle.count <= 120 else {
            throw ReminderValidationError.invalidTitle
        }
        guard message.count <= 2_000 else {
            throw ReminderValidationError.messageTooLong
        }
        guard (260...900).contains(width), (180...720).contains(height),
              (0...1).contains(positionX), (0...1).contains(positionY),
              (0...15).contains(screenIndex) else {
            throw ReminderValidationError.invalidLayout
        }
        guard snoozeMinutes.map({ (1...1_440).contains($0) }) ?? true else {
            throw ReminderValidationError.invalidSnooze
        }
        guard buttons.count <= 3 else {
            throw ReminderValidationError.tooManyButtons
        }
        guard buttons.allSatisfy({ button in
            let title = button.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, title.count <= 32 else { return false }
            switch button.action {
            case .openURL:
                return button.httpsURL != nil
            case .snooze:
                return snoozeMinutes != nil && button.url == nil
            case .complete, .dismiss, .stop:
                return button.url == nil
            }
        }) else {
            throw ReminderValidationError.invalidButton
        }
        guard (symbol?.count ?? 0) <= 64,
              (imageData?.count ?? 0) <= 2_000_000 else {
            throw ReminderValidationError.imageTooLarge
        }
        if let imageData, !imageData.isEmpty, !imageData.starts(with: [0x89, 0x50, 0x4E, 0x47])
            && !imageData.starts(with: [0xFF, 0xD8, 0xFF]) {
            throw ReminderValidationError.invalidImage
        }

        return Reminder(
            id: id,
            title: trimmedTitle,
            message: message,
            dueAt: dueAt,
            presentation: presentation,
            width: width,
            height: height,
            positionX: positionX,
            positionY: positionY,
            screenIndex: screenIndex,
            snoozeMinutes: snoozeMinutes,
            repeats: repeats,
            buttons: buttons,
            symbol: symbol,
            imageData: imageData,
            isActive: true,
            snoozedUntil: nil
        )
    }
}

enum ReminderValidationError: Error, Equatable, LocalizedError {
    case invalidTitle
    case messageTooLong
    case invalidLayout
    case invalidSnooze
    case tooManyButtons
    case invalidButton
    case invalidImage
    case imageTooLarge

    var errorDescription: String? {
        switch self {
        case .invalidTitle: "A reminder title must contain 1–120 characters."
        case .messageTooLong: "A reminder message must contain at most 2,000 characters."
        case .invalidLayout: "The reminder size or position is outside the supported range."
        case .invalidSnooze: "Snooze must be between 1 and 1,440 minutes."
        case .tooManyButtons: "A reminder can have at most three buttons."
        case .invalidButton: "A reminder button has an invalid title or action."
        case .invalidImage: "The reminder image must be a PNG or JPEG image."
        case .imageTooLarge: "The reminder image exceeds the 2 MB limit."
        }
    }
}
