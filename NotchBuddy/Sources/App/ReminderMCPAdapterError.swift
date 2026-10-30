import Foundation

enum ReminderMCPAdapterError: Error, LocalizedError {
    case imageTooLarge

    var errorDescription: String? {
        switch self {
        case .imageTooLarge: String(localized: "MCP reminder images must be 700 KB or smaller.")
        }
    }
}
