import Foundation

// scripts/konclui/test-reminder-rules.sh
@main
struct KoncluiReminderRulesTests {
    static func main() {
        var failures = 0
        func check(_ ok: Bool, _ what: String) {
            if !ok { failures += 1; print("FAIL \(what)") }
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
        }
        // Friday 30 October 2026, 14:00.
        let now = date(2026, 10, 30, 14)

        // Sizes: three presets; a full-screen alert only has a width; anything else is an agent's own.
        check(KoncluiReminderSize.matching(width: 480, height: 320, fullScreen: false) == .medium, "480x320 is medium")
        check(KoncluiReminderSize.matching(width: 640, height: 999, fullScreen: true) == .large, "full screen ignores the height")
        check(KoncluiReminderSize.matching(width: 500, height: 320, fullScreen: false) == nil, "500 pt is custom")
        for size in KoncluiReminderSize.allCases {
            let p = size.points
            check((260...900).contains(p.width) && (180...720).contains(p.height), "\(size) fits the owner's validation")
        }

        // Places: the owner's 0…1 from the left and from the top.
        check(KoncluiReminderPlace.topLeading.position == (0, 0), "top left is 0,0")
        check(KoncluiReminderPlace.top.position == (0.5, 0), "top centre is 0.5,0")
        check(KoncluiReminderPlace.center.position == (0.5, 0.5), "centre is 0.5,0.5")
        check(KoncluiReminderPlace.bottomTrailing.position == (1, 1), "bottom right is 1,1")
        check(KoncluiReminderPlace.matching(x: 1, y: 0.5) == .trailing, "1,0.5 is middle right")
        check(KoncluiReminderPlace.matching(x: 0.3, y: 0.5) == nil, "0.3,0.5 is custom")
        let snapped = KoncluiReminderPlace.snapped(x: 0.96, y: 0.03)
        check(snapped == (1, 0), "a card let go near the top right lands there (\(snapped))")
        let free = KoncluiReminderPlace.snapped(x: 0.3, y: 0.7)
        check(free == (0.3, 0.7), "a card let go far from a place stays (\(free))")
        check(KoncluiReminderPlace.snapped(x: -0.4, y: 1.3) == (0, 1), "a drag past the edge stays on the screen")

        // The first time it rings.
        let later = date(2026, 10, 30, 18)
        check(KoncluiReminderRules.firstDue(later, repeats: .none, now: now) == later, "a time ahead rings then")
        check(KoncluiReminderRules.firstDue(date(2026, 10, 30, 9), repeats: .none, now: now) == nil, "a one-time reminder in the past is refused")
        check(KoncluiReminderRules.firstDue(date(2026, 10, 30, 9), repeats: .daily, now: now, calendar: calendar) == date(2026, 10, 31, 9),
              "every day at 9 made at 14:00 rings tomorrow at 9, not now")
        check(KoncluiReminderRules.firstDue(date(2026, 10, 31, 9), repeats: .weekdays, now: now, calendar: calendar) == date(2026, 11, 2, 9),
              "weekdays never start on a Saturday")
        check(KoncluiReminderRules.firstDue(date(2026, 10, 30, 9), repeats: .weekdays, now: now, calendar: calendar) == date(2026, 11, 2, 9),
              "weekdays at 9 made on Friday afternoon ring on Monday")
        check(KoncluiReminderRules.firstDue(date(2026, 10, 29, 9), repeats: .weekly, now: now, calendar: calendar) == date(2026, 11, 5, 9),
              "weekly from yesterday rings next week")
        check(KoncluiReminderRules.following(later, repeats: .none, calendar: calendar) == nil, "a one-time reminder has no next turn")
        check(KoncluiReminderRules.following(later, repeats: .daily, calendar: calendar) == date(2026, 10, 31, 18), "daily: the next turn is tomorrow")

        // Words of a day.
        check(KoncluiReminderRules.day(of: later, now: now, calendar: calendar) == .today, "today")
        check(KoncluiReminderRules.day(of: date(2026, 10, 31, 8), now: now, calendar: calendar) == .tomorrow, "tomorrow")
        check(KoncluiReminderRules.day(of: date(2026, 11, 4, 8), now: now, calendar: calendar) == .thisWeek, "Wednesday is this week")
        check(KoncluiReminderRules.day(of: date(2026, 11, 9, 8), now: now, calendar: calendar) == .later, "ten days ahead is a date")
        let quick = KoncluiReminderRules.quickTimes(now: date(2026, 10, 30, 14, 7).addingTimeInterval(31), calendar: calendar)
        check(quick.tenMinutes == date(2026, 10, 30, 14, 17), "in 10 min is a whole minute")
        check(quick.hour == date(2026, 10, 30, 15, 7), "in 1 h")
        check(quick.tomorrowMorning == date(2026, 10, 31, 9), "tomorrow at 9:00")

        // The draft: what blocks a save, the first thing only.
        var draft = KoncluiReminderDraft.blank(now: now, doneTitle: "Concluído")
        check(draft.issue(now: now) == .title, "a reminder needs a name")
        draft.title = "  Beber água  "
        check(draft.issue(now: now) == nil, "a named blank draft saves (\(String(describing: draft.issue(now: now))))")
        check(draft.place == .top && draft.size == .medium && draft.snoozeOn, "a new reminder: medium, under the notch, snooze on")
        draft.buttons.append(ReminderButton(title: " ", action: .complete, url: nil))
        check(draft.issue(now: now) == .buttonTitle, "every button needs a name")
        draft.buttons[1] = ReminderButton(title: "Abrir", action: .openURL, url: "http://example.com")
        check(draft.issue(now: now) == .link, "a link must be https")
        draft.buttons[1].url = "https://example.com/pr"
        check(draft.issue(now: now) == nil, "an https link saves")
        draft.dueAt = date(2026, 10, 30, 9)
        check(draft.issue(now: now) == .past, "a one-time reminder in the past is refused")
        check(draft.issue(now: nil) == nil, "a test shows it whatever its time")
        draft.isActive = false
        check(draft.issue(now: now) == nil, "a stopped reminder keeps its old time")
        draft.isActive = true
        draft.repeats = .daily
        check(draft.issue(now: now) == nil, "a repeating reminder in the past rings at its next turn")

        // To the owner's model and back.
        draft.snoozeOn = false
        draft.buttons[0].url = "https://stale.example"
        let owner = draft.ownerDraft(dueAt: later)
        check(owner.snoozeMinutes == nil, "snooze off is no snooze")
        check(owner.buttons[0].url == nil, "a button that is not a link keeps no link")
        check(owner.buttons.allSatisfy { $0.title == $0.title.trimmingCharacters(in: .whitespaces) }, "button titles are trimmed")
        draft.imageData = Data([0x89, 0x50, 0x4E, 0x47, 0, 0])
        check(draft.ownerDraft(dueAt: later).symbol == nil, "an image replaces the symbol")
        draft.imageData = nil
        do {
            let reminder = try draft.ownerDraft(dueAt: later).validated()
            check(reminder.title == "Beber água", "the title is trimmed by the owner's validation")
            let back = KoncluiReminderDraft(reminder)
            check(back.sameChoices(as: { var d = draft; d.title = "Beber água"; d.buttons[0].url = nil; return d }()),
                  "a reminder opens in the editor as it was saved")
        } catch {
            check(false, "the owner's validation refused the draft: \(error)")
        }
        check(KoncluiReminderDraft.blank(now: now).sameChoices(as: .blank(now: later)), "two blank drafts are the same, whatever the time")
        check(!draft.sameChoices(as: .blank(now: now)), "a named draft is not blank")
        // An agent's own values survive the editor.
        var agent = draft.reminder(dueAt: later)
        agent.width = 512; agent.positionX = 0.3; agent.snoozeMinutes = 7
        let opened = KoncluiReminderDraft(agent)
        check(opened.size == nil && opened.place == nil && opened.snoozeMinutes == 7, "an agent's size, place and snooze stay")

        // Rows: order and status.
        var a = draft.reminder(dueAt: date(2026, 10, 30, 20)); a.title = "a"
        var b = draft.reminder(dueAt: date(2026, 10, 30, 16)); b.title = "b"
        var c = draft.reminder(dueAt: date(2026, 10, 30, 10)); c.title = "c"; c.isActive = false
        var d = draft.reminder(dueAt: date(2026, 10, 30, 17)); d.title = "d"; d.snoozedUntil = date(2026, 10, 30, 15)
        check(KoncluiReminderRules.ordered([a, b, c, d]).map(\.title) == ["d", "b", "a", "c"], "next to ring first, stopped last")
        check(KoncluiReminderRules.status(c) == .stopped, "stopped")
        check(KoncluiReminderRules.status(d) == .snoozed(until: date(2026, 10, 30, 15)), "snoozed")
        check(KoncluiReminderRules.status(a) == .active, "active")

        // Every key the rules name exists in the 14 languages.
        let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "NotchBuddy/Resources/Localizable.xcstrings"
        if let data = FileManager.default.contents(atPath: path),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let strings = json["strings"] as? [String: Any] {
            var keys = KoncluiReminderSize.allCases.map(\.key) + KoncluiReminderPlace.allCases.map(\.key)
            keys += ReminderRepeat.allCases.map(KoncluiReminderRules.repeatKey)
            keys += ReminderButtonAction.allCases.map(KoncluiReminderRules.actionKey)
            keys += ReminderButtonAction.allCases.map(KoncluiReminderRules.defaultTitleKey)
            keys += [KoncluiReminderRules.Status.active, .snoozed(until: now), .stopped].map(\.key)
            keys += [KoncluiReminderDraft.Issue.title, .past, .link, .buttonTitle].map(\.key)
            keys.append("Snooze · %lld min")
            for key in Set(keys) {
                let languages = ((strings[key] as? [String: Any])?["localizations"] as? [String: Any])?.count ?? 0
                check(languages == 14, "\"\(key)\" has \(languages) of 14 languages")
            }
        } else {
            check(false, "could not read the catalog at \(path)")
        }

        print(failures == 0 ? "PASS reminder rules" : "\(failures) failure(s)")
        exit(failures == 0 ? 0 : 1)
    }
}
