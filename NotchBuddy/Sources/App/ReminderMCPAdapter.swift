import AppKit
import CoreFoundation
import Foundation

@MainActor
final class ReminderMCPAdapter {
    static let shared = ReminderMCPAdapter()

    private let manager = ReminderManager.shared

    private init() {}

    func handle(_ request: [String: Any]) -> [String: Any] {
        do {
            switch request["action"] as? String {
            case "create":
                let reminder = try manager.create(draft(from: request))
                return ["ok": true, "reminder": serialize(reminder)]
            case "list":
                try manager.requireStorageReady()
                return ["ok": true, "reminders": manager.reminders.map(serialize)]
            case "dismiss", "complete", "stop", "snooze":
                try manager.requireStorageReady()
                guard let rawID = request["id"] as? String, let id = UUID(uuidString: rawID) else {
                    throw ReminderManagerError.invalidIdentifier
                }
                guard manager.reminders.contains(where: { $0.id == id && $0.isActive }) else {
                    throw ReminderManagerError.notFound
                }
                switch request["action"] as? String {
                case "dismiss": manager.dismiss(id: id)
                case "complete": manager.perform(.complete, for: id)
                case "stop": manager.stop(id: id)
                default:
                    try manager.snooze(id: id, minutes: request["minutes"] as? Int ?? 0)
                }
                return ["ok": true, "reminder": manager.reminders.first(where: { $0.id == id }).map(serialize)
                    ?? ["id": rawID, "is_active": false]]
            default:
                throw ReminderManagerError.invalidAction
            }
        } catch {
            return ["ok": false, "error": error.localizedDescription]
        }
    }

    private func draft(from request: [String: Any]) throws -> ReminderDraft {
        guard let title = request["title"] as? String,
              let dueAtString = request["due_at"] as? String,
              let dueAt = Self.parseDate(dueAtString) else {
            throw ReminderManagerError.missingFields
        }
        guard let presentation = ReminderPresentation(rawValue: try string("presentation", in: request, default: "card")),
              let repeats = ReminderRepeat(rawValue: try string("repeats", in: request, default: "none")) else {
            throw ReminderManagerError.invalidConfiguration
        }

        let buttons: [ReminderButton]
        if let rawButtons = request["buttons"] {
            guard let rawButtons = rawButtons as? [[String: Any]] else {
                throw ReminderManagerError.invalidConfiguration
            }
            buttons = try rawButtons.map { item in
                guard let title = item["title"] as? String,
                      let action = ReminderButtonAction(rawValue: item["action"] as? String ?? "") else {
                    throw ReminderManagerError.invalidConfiguration
                }
                return ReminderButton(title: title, action: action, url: try optionalString("url", in: item))
            }
        } else {
            buttons = []
        }

        let imageData: Data?
        if let encodedImage = request["image_base64"] {
            guard let encodedImage = encodedImage as? String,
                  let decodedImage = Data(base64Encoded: encodedImage) else {
                throw ReminderValidationError.invalidImage
            }
            guard decodedImage.count <= 700_000 else { throw ReminderMCPAdapterError.imageTooLarge }
            guard NSImage(data: decodedImage) != nil else { throw ReminderValidationError.invalidImage }
            imageData = decodedImage
        } else {
            imageData = nil
        }

        return ReminderDraft(title: title,
                             message: try string("message", in: request, default: ""),
                             dueAt: dueAt,
                             presentation: presentation,
                             width: try double("width", in: request, default: 480),
                             height: try double("height", in: request, default: 320),
                             positionX: try double("position_x", in: request, default: 0.5),
                             positionY: try double("position_y", in: request, default: 0.5),
                             screenIndex: try integer("screen_index", in: request, default: 0),
                             snoozeMinutes: try optionalInteger("snooze_minutes", in: request),
                             repeats: repeats,
                             buttons: buttons,
                             symbol: try optionalString("symbol", in: request),
                             imageData: imageData)
    }

    private func string(_ key: String, in request: [String: Any], default fallback: String) throws -> String {
        guard request[key] != nil else { return fallback }
        guard let value = request[key] as? String else { throw ReminderManagerError.invalidConfiguration }
        return value
    }

    private func optionalString(_ key: String, in request: [String: Any]) throws -> String? {
        guard let rawValue = request[key] else { return nil }
        guard let value = rawValue as? String else { throw ReminderManagerError.invalidConfiguration }
        return value
    }

    private func double(_ key: String, in request: [String: Any], default fallback: Double) throws -> Double {
        guard request[key] != nil else { return fallback }
        let value = try number(key, in: request).doubleValue
        guard value.isFinite else { throw ReminderManagerError.invalidConfiguration }
        return value
    }

    private func integer(_ key: String, in request: [String: Any], default fallback: Int) throws -> Int {
        guard request[key] != nil else { return fallback }
        guard let value = Int(exactly: try number(key, in: request).doubleValue) else {
            throw ReminderManagerError.invalidConfiguration
        }
        return value
    }

    private func optionalInteger(_ key: String, in request: [String: Any]) throws -> Int? {
        guard request[key] != nil else { return nil }
        return try integer(key, in: request, default: 0)
    }

    private func number(_ key: String, in request: [String: Any]) throws -> NSNumber {
        guard let value = request[key] as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID() else {
            throw ReminderManagerError.invalidConfiguration
        }
        return value
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }

    private func serialize(_ reminder: Reminder) -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        return [
            "id": reminder.id.uuidString,
            "title": reminder.title,
            "message": reminder.message,
            "due_at": formatter.string(from: reminder.dueAt),
            "presentation": reminder.presentation.rawValue,
            "repeats": reminder.repeats.rawValue,
            "screen_index": reminder.screenIndex,
            "width": reminder.width,
            "height": reminder.height,
            "position_x": reminder.positionX,
            "position_y": reminder.positionY,
            "buttons": reminder.buttons.map { ["title": $0.title, "action": $0.action.rawValue, "url": $0.url ?? ""] },
            "snooze_minutes": reminder.snoozeMinutes as Any? ?? NSNull(),
            "is_active": reminder.isActive
        ]
    }
}
