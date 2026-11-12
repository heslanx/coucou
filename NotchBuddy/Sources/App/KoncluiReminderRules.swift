import Foundation

// Koncluí: the rules of the Lembretes page (KoncluiRemindersPage.swift), without SwiftUI so
// `scripts/konclui/test-reminder-rules.sh` checks them with swiftc alone: the editor's draft and its round trip to the
// owner's `ReminderDraft`, the few sizes, places and snooze lengths the editor offers instead of free sliders, what blocks a
// save, the first time a new reminder rings, and the words of a row. The reminder itself stays the owner's model
// (ReminderModels.swift): a reminder an agent made through the MCP with values outside these choices keeps them, shown as
// "Personalizado".

enum KoncluiReminderSize: String, CaseIterable, Identifiable {
    case small, medium, large

    var id: String { rawValue }

    /// The card's size; for a full-screen alert only the width counts (the width of its content).
    var points: (width: Double, height: Double) {
        switch self {
        case .small:  return (340, 210)
        case .medium: return (480, 320)
        case .large:  return (640, 440)
        }
    }

    var key: String { "konclui.reminders.size.\(rawValue)" }

    /// The preset these values are, or nil for a size an agent chose.
    static func matching(width: Double, height: Double, fullScreen: Bool) -> KoncluiReminderSize? {
        allCases.first { $0.points.width == width && (fullScreen || $0.points.height == height) }
    }
}

/// The nine places of a card on the screen, as the owner's model stores them: 0…1 from the left and from the top.
enum KoncluiReminderPlace: String, CaseIterable, Identifiable {
    case topLeading, top, topTrailing, leading, center, trailing, bottomLeading, bottom, bottomTrailing

    var id: String { rawValue }

    var position: (x: Double, y: Double) {
        let index = Self.allCases.firstIndex(of: self) ?? 4
        return (Double(index % 3) / 2, Double(index / 3) / 2)
    }

    var key: String { "konclui.reminders.position.\(rawValue)" }

    static func matching(x: Double, y: Double) -> KoncluiReminderPlace? {
        allCases.first { abs($0.position.x - x) < 0.001 && abs($0.position.y - y) < 0.001 }
    }

    /// A card let go near a place lands on it; elsewhere it stays where it was dropped.
    static func snapped(x: Double, y: Double, within reach: Double = 0.07) -> (x: Double, y: Double) {
        func snap(_ value: Double) -> Double {
            let clamped = min(1, max(0, value))
            let nearest = (clamped * 2).rounded() / 2
            return abs(nearest - clamped) <= reach ? nearest : clamped
        }
        return (snap(x), snap(y))
    }
}

enum KoncluiReminderRules {
    /// The snooze lengths offered, in minutes. A reminder made with another length keeps it (it shows as an extra choice).
    static let snoozeChoices = [5, 10, 15, 30, 60]
    static let symbols = ["bell.fill", "drop.fill", "pills.fill", "cup.and.saucer.fill", "figure.walk", "phone.fill",
                          "calendar", "checklist", "star.fill", "moon.fill"]
    /// The actions a new button can take. "Adiar" has its own switch; "Fechar" does what "Concluir" does since a done
    /// repeating reminder comes back (ReminderManager, `perform`): a button an agent made with either keeps it.
    static let buttonActions: [ReminderButtonAction] = [.complete, .openURL, .stop]
    static let maxButtons = 3
    static let maxImageBytes = 2_000_000

    static func actionKey(_ action: ReminderButtonAction) -> String {
        switch action {
        case .complete: return "konclui.reminders.action.complete"
        case .openURL:  return "konclui.reminders.action.link"
        case .stop:     return "konclui.reminders.action.stop"
        case .snooze:   return "konclui.reminders.action.snooze"
        case .dismiss:  return "konclui.reminders.action.dismiss"
        }
    }

    /// The title a button gets when its action is picked and its title is still another action's default.
    static func defaultTitleKey(_ action: ReminderButtonAction) -> String {
        switch action {
        case .complete, .dismiss, .snooze: return "konclui.reminders.button.done"
        case .openURL:                     return "konclui.reminders.button.open"
        case .stop:                        return "konclui.reminders.button.stop"
        }
    }

    static func repeatKey(_ repeats: ReminderRepeat) -> String {
        switch repeats {
        case .none:     return "konclui.reminders.repeat.none"
        case .daily:    return "konclui.reminders.repeat.daily"
        case .weekdays: return "konclui.reminders.repeat.weekdays"
        case .weekly:   return "konclui.reminders.repeat.weekly"
        }
    }

    // MARK: When

    /// The first time a reminder saved now rings: the time chosen when it is still ahead; for a repeating one whose time
    /// passed, its next turn (a "Todo dia às 9:00" made at 14:00 rings tomorrow, not at once); nil for a one-time reminder
    /// in the past, which the editor refuses. "Dias úteis" never starts on a weekend.
    static func firstDue(_ date: Date, repeats: ReminderRepeat, now: Date, calendar: Calendar = .current) -> Date? {
        var due = date
        if repeats == .weekdays, calendar.isDateInWeekend(due) {
            guard let weekday = ReminderSchedule.nextWeekday(after: due, calendar: calendar) else { return nil }
            due = weekday
        }
        if due > now { return due }
        guard repeats != .none else { return nil }
        var probe = KoncluiReminderDraft.blank(now: now).reminder(dueAt: due)
        probe.repeats = repeats
        return ReminderSchedule.nextOccurrence(for: probe, after: now, calendar: calendar)
    }

    /// The turn after this one, for the preview's "Depois: …": nil for a one-time reminder.
    static func following(_ date: Date, repeats: ReminderRepeat, calendar: Calendar = .current) -> Date? {
        guard repeats != .none else { return nil }
        var probe = KoncluiReminderDraft.blank(now: date).reminder(dueAt: date)
        probe.repeats = repeats
        return ReminderSchedule.nextOccurrence(for: probe, after: date, calendar: calendar)
    }

    enum Day: Equatable { case today, tomorrow, thisWeek, later }

    /// Which words a date takes: "Hoje", "Amanhã", the weekday within six days, else the date.
    static func day(of date: Date, now: Date, calendar: Calendar = .current) -> Day {
        if calendar.isDate(date, inSameDayAs: now) { return .today }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return .tomorrow
        }
        let start = calendar.startOfDay(for: now)
        if date > start, let days = calendar.dateComponents([.day], from: start, to: date).day, days < 7 { return .thisWeek }
        return .later
    }

    /// The quick times under the date: in 10 minutes, in an hour, tomorrow at 9:00. Whole minutes.
    static func quickTimes(now: Date, calendar: Calendar = .current) -> (tenMinutes: Date, hour: Date, tomorrowMorning: Date) {
        let minute = calendar.dateInterval(of: .minute, for: now)?.start ?? now
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        return (minute.addingTimeInterval(600), minute.addingTimeInterval(3_600), morning)
    }

    // MARK: Rows

    enum Status: Equatable {
        case active, snoozed(until: Date), stopped

        var key: String {
            switch self {
            case .active:  return "konclui.reminders.status.active"
            case .snoozed: return "konclui.reminders.status.snoozed %@"
            case .stopped: return "konclui.reminders.status.stopped"
            }
        }
    }

    static func status(_ reminder: Reminder) -> Status {
        guard reminder.isActive else { return .stopped }
        if let until = reminder.snoozedUntil { return .snoozed(until: until) }
        return .active
    }

    /// Active ones first, the next to ring on top; stopped ones after, newest first.
    static func ordered(_ reminders: [Reminder]) -> [Reminder] {
        let active = reminders.filter(\.isActive).sorted { $0.nextFireDate < $1.nextFireDate }
        let stopped = reminders.filter { !$0.isActive }.sorted { $0.dueAt > $1.dueAt }
        return active + stopped
    }
}

// MARK: - The alert (KoncluiReminderAlert.swift)

/// What the alert shows besides the reminder's own words: its one primary button, the meeting it opens, the snooze
/// lengths offered, and how far the time is.
enum KoncluiReminderAlertRules {
    /// The hosts of a video call: a link to one of them is "Entrar na reunião".
    static let meetingHosts = ["meet.google.com", "zoom.us", "zoom.com", "teams.microsoft.com", "teams.live.com", "webex.com",
                               "whereby.com", "meet.jit.si", "facetime.apple.com", "around.co", "app.gather.town", "discord.gg"]

    static func isMeeting(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased(), url?.scheme?.lowercased() == "https" else { return false }
        return meetingHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    /// The first video-call link in a reminder's message (an agent often writes it there), https only.
    static func meetingLink(in message: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(message.startIndex..., in: message)
        return detector.matches(in: message, range: range).compactMap(\.url).first(where: isMeeting)
    }

    /// The button the alert makes primary (full width, ⏎): a meeting link first, else the first "Concluir", else the first
    /// button. Nil when there is none (the alert then offers "Fechar").
    static func primaryIndex(_ buttons: [ReminderButton]) -> Int? {
        if let meeting = buttons.firstIndex(where: { $0.action == .openURL && isMeeting($0.httpsURL) }) { return meeting }
        if let done = buttons.firstIndex(where: { $0.action == .complete }) { return done }
        return buttons.isEmpty ? nil : 0
    }

    /// The alert's buttons in order, the primary first: a meeting link found in the message becomes a button when no
    /// button opens one. Empty when the reminder has no button (the alert then offers "Fechar").
    static func ordered(_ buttons: [ReminderButton], message: String) -> [ReminderButton] {
        var all = buttons
        if !all.contains(where: { $0.action == .openURL && isMeeting($0.httpsURL) }), let link = meetingLink(in: message) {
            all.insert(ReminderButton(title: "", action: .openURL, url: link.absoluteString), at: 0)
        }
        guard let primary = primaryIndex(all) else { return [] }
        return [all[primary]] + all.indices.filter { $0 != primary }.map { all[$0] }
    }

    /// The snooze lengths on the alert, then behind "⋯". The reminder's own length is always one of the first.
    static func snoozeChips(own: Int) -> (shown: [Int], more: [Int]) {
        var shown = [1, 5, 10]
        if !shown.contains(own) { shown = (own < 5 ? [1, own, 10] : [1, 5, own]).sorted() }
        return (shown, [15, 30, 60, 120].filter { !shown.contains($0) })
    }

    enum When: Equatable { case now, ahead(TimeInterval), late(TimeInterval) }

    /// How the time compares with now: within a minute is "agora"; a test or an early show counts down; a reminder the
    /// Mac was asleep for says how late it is.
    static func when(_ due: Date, now: Date) -> When {
        let delta = due.timeIntervalSince(now)
        if delta >= 1 { return .ahead(delta.rounded(.up)) }
        if -delta < 60 { return .now }
        return .late(-delta)
    }

    /// What the alert's Koru and her alarm clock do (KoncluiReminderKoru.swift): before the time the clock ticks and she
    /// waits; at the time it rings and she jumps; past it, it keeps ringing and she sweats a little. Never a scolding
    /// (design/prototype/koru/docs/MOTION.md, PRODUCT-02).
    enum Cue: Equatable { case waiting, ringing, overdue }

    static func cue(_ when: When) -> Cue {
        switch when {
        case .ahead: return .waiting
        case .now: return .ringing
        case .late: return .overdue
        }
    }

    /// The moments the cue changes after `now`, for a view that redraws only then: just inside "agora" (`when`'s second),
    /// then just inside "late" (its minute).
    static func cueChanges(due: Date, after now: Date) -> [Date] {
        [due.addingTimeInterval(-0.5), due.addingTimeInterval(60.5)].filter { $0 > now }
    }
}

/// The alarm clock beside the alert's Koru, as numbers: where its hands point and how it rings. Angles are radians,
/// clockwise from 12.
enum KoncluiAlarmClockMotion {
    /// It rings in bursts with a rest between them, not as a constant buzz.
    static let burst: Double = 1.0
    static let period: Double = 2.4
    static let shakesPerSecond: Double = 11

    /// The hour and minute hands at a time of day; the clock shows the reminder's own time, as the headline does.
    static func hands(at date: Date, calendar: Calendar = .current) -> (hour: Double, minute: Double) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double((parts.hour ?? 0) % 12), minute = Double(parts.minute ?? 0)
        return (2 * .pi * (hour + minute / 60) / 12, 2 * .pi * minute / 60)
    }

    /// The second hand, a tick a second.
    static func secondHand(at date: Date, calendar: Calendar = .current) -> Double {
        2 * .pi * Double(calendar.component(.second, from: date)) / 60
    }

    /// How hard it rings, 0 to 1, `elapsed` seconds after it started: eased in and out over a burst, then still.
    static func strength(elapsed: Double) -> Double {
        guard elapsed >= 0 else { return 0 }
        let phase = elapsed.truncatingRemainder(dividingBy: period)
        return phase < burst ? sin(.pi * phase / burst) : 0
    }

    /// The shake, −1 to 1: how far it leans on its feet at `elapsed` seconds.
    static func swing(elapsed: Double) -> Double {
        strength(elapsed: elapsed) * sin(2 * .pi * shakesPerSecond * elapsed)
    }

    /// Which burst `elapsed` falls in (one sweat drop each while she is late).
    static func burstIndex(elapsed: Double) -> Int {
        elapsed < 0 ? -1 : Int(elapsed / period)
    }
}

// MARK: - The editor's draft

/// What the editor edits. It outlives the sheet (UX.md 1.3, "never lose work"): Cancel or a click outside keeps it, and the
/// next "Novo lembrete" (or the same reminder) opens on it.
struct KoncluiReminderDraft: Equatable {
    var title = ""
    var message = ""
    var dueAt: Date
    var repeats: ReminderRepeat = .none
    var presentation: ReminderPresentation = .card
    var width: Double
    var height: Double
    var positionX: Double
    var positionY: Double
    var screenIndex = 0
    var snoozeOn = true
    var snoozeMinutes = 5
    var symbol: String? = "bell.fill"
    var imageData: Data?
    var buttons: [ReminderButton]
    var isActive = true

    enum Issue: Equatable {
        case title, past, link, buttonTitle

        var key: String {
            switch self {
            case .title:       return "konclui.reminders.issue.title"
            case .past:        return "konclui.reminders.issue.past"
            case .link:        return "konclui.reminders.issue.link"
            case .buttonTitle: return "konclui.reminders.issue.button"
            }
        }
    }

    /// A new reminder: ten minutes from now, a medium card at the top centre, under the notch, with one "Concluído" button.
    static func blank(now: Date, doneTitle: String = "Done") -> KoncluiReminderDraft {
        let size = KoncluiReminderSize.medium.points
        let place = KoncluiReminderPlace.top.position
        return KoncluiReminderDraft(dueAt: KoncluiReminderRules.quickTimes(now: now).tenMinutes,
                                    width: size.width, height: size.height, positionX: place.x, positionY: place.y,
                                    buttons: [ReminderButton(title: doneTitle, action: .complete, url: nil)])
    }

    init(dueAt: Date, width: Double, height: Double, positionX: Double, positionY: Double, buttons: [ReminderButton]) {
        self.dueAt = dueAt
        self.width = width
        self.height = height
        self.positionX = positionX
        self.positionY = positionY
        self.buttons = buttons
    }

    init(_ reminder: Reminder) {
        title = reminder.title
        message = reminder.message
        dueAt = reminder.dueAt
        repeats = reminder.repeats
        presentation = reminder.presentation
        width = reminder.width
        height = reminder.height
        positionX = reminder.positionX
        positionY = reminder.positionY
        screenIndex = reminder.screenIndex
        snoozeOn = reminder.snoozeMinutes != nil
        snoozeMinutes = reminder.snoozeMinutes ?? 5
        symbol = reminder.symbol
        imageData = reminder.imageData
        buttons = reminder.buttons
        isActive = reminder.isActive
    }

    var size: KoncluiReminderSize? {
        KoncluiReminderSize.matching(width: width, height: height, fullScreen: presentation == .fullScreen)
    }

    var place: KoncluiReminderPlace? { KoncluiReminderPlace.matching(x: positionX, y: positionY) }

    var hasSnoozeButton: Bool { buttons.contains { $0.action == .snooze } }

    /// What blocks the save, the first one only (the line under the form says it). `now` nil skips the time check (a test
    /// shows the reminder now, whatever its time).
    func issue(now: Date?) -> Issue? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .title }
        if buttons.contains(where: { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { return .buttonTitle }
        if buttons.contains(where: { $0.action == .openURL && $0.httpsURL == nil }) { return .link }
        if let now, isActive, KoncluiReminderRules.firstDue(dueAt, repeats: repeats, now: now) == nil { return .past }
        return nil
    }

    /// The same reminder as `other`, the time and the buttons' ids aside (a blank draft's time moves with the clock): a
    /// draft that is still this when the editor closes is not kept.
    private static let noID = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()

    func sameChoices(as other: KoncluiReminderDraft) -> Bool {
        func plain(_ draft: KoncluiReminderDraft) -> KoncluiReminderDraft {
            var copy = draft
            copy.dueAt = .distantPast
            copy.buttons = draft.buttons.map { button in
                var same = button
                same.id = Self.noID
                return same
            }
            return copy
        }
        return plain(self) == plain(other)
    }

    /// The owner's draft for `ReminderManager.create`, ringing at `due`.
    func ownerDraft(dueAt due: Date) -> ReminderDraft {
        ReminderDraft(title: title, message: message, dueAt: due, presentation: presentation,
                      width: width, height: height, positionX: positionX, positionY: positionY, screenIndex: screenIndex,
                      snoozeMinutes: snoozeOn ? snoozeMinutes : nil, repeats: repeats,
                      buttons: buttons.map { button in
                          var clean = button
                          clean.title = button.title.trimmingCharacters(in: .whitespacesAndNewlines)
                          if button.action != .openURL { clean.url = nil }
                          return clean
                      },
                      symbol: imageData == nil ? symbol : nil, imageData: imageData)
    }

    /// A whole reminder with these values (the test run and the preview's next turn), not validated.
    func reminder(id: UUID = UUID(), dueAt due: Date? = nil) -> Reminder {
        let draft = ownerDraft(dueAt: due ?? dueAt)
        return Reminder(id: id, title: draft.title, message: draft.message, dueAt: draft.dueAt,
                        presentation: draft.presentation, width: draft.width, height: draft.height,
                        positionX: draft.positionX, positionY: draft.positionY, screenIndex: draft.screenIndex,
                        snoozeMinutes: draft.snoozeMinutes, repeats: draft.repeats, buttons: draft.buttons,
                        symbol: draft.symbol, imageData: draft.imageData, isActive: true, snoozedUntil: nil)
    }
}
