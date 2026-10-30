import AppKit
import Foundation

// Koncluí: "Testar" on the Lembretes page shows the reminder being edited now, exactly as it will ring (the owner's own
// window, ReminderWindowController), without saving it. Its buttons and Escape go through `ReminderManager.perform` like a
// real one's; the hook at the top of `perform` hands a test's to `close`, which changes nothing: it opens a link (so the
// link is tested too) and closes the test. Kept outside `#if !APPSTORE` because the hook is in a file both builds compile.
@MainActor
enum KoncluiReminderTrial {
    private static var running: Set<UUID> = []

    static func show(_ reminder: Reminder) {
        running.insert(reminder.id)
        ReminderWindowController.shared.show(reminder)
    }

    /// True when `id` is a test, which this call closed; false lets the manager handle a real reminder.
    static func close(_ id: UUID, action: ReminderButtonAction, button: ReminderButton?) -> Bool {
        guard running.remove(id) != nil else { return false }
        if action == .openURL, let url = button?.httpsURL { NSWorkspace.shared.open(url) }
        ReminderWindowController.shared.dismiss(id: id)
        return true
    }
}
