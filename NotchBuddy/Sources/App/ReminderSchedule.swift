import Foundation

enum ReminderSchedule {
    static func nextOccurrence(for reminder: Reminder, after date: Date,
                               calendar: Calendar = .current) -> Date? {
        guard reminder.repeats != .none else { return nil }
        var candidate = reminder.dueAt
        while candidate <= date {
            switch reminder.repeats {
            case .none:
                return nil
            case .daily:
                guard let next = calendar.date(byAdding: .day, value: 1, to: candidate), next > candidate else { return nil }
                candidate = next
            case .weekdays:
                guard let next = nextWeekday(after: candidate, calendar: calendar) else { return nil }
                candidate = next
            case .weekly:
                guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: candidate), next > candidate else { return nil }
                candidate = next
            }
        }
        return candidate
    }

    static func nextWeekday(after date: Date, calendar: Calendar = .current) -> Date? {
        guard var candidate = calendar.date(byAdding: .day, value: 1, to: date), candidate > date else { return nil }
        while calendar.isDateInWeekend(candidate) {
            guard let next = calendar.date(byAdding: .day, value: 1, to: candidate), next > candidate else { return nil }
            candidate = next
        }
        return candidate
    }
}
