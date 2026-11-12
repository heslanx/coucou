import AppKit
import SwiftUI

// Koncluí: the reminder's alert, "Despertador com a Koru" (design/konclui/reminders/reminder-alerts-10.html, option 11, the
// owner's pick). The Koru perches on top; the time is the headline, with how far it is ("agora", "em 1 min 54 s", "há 3
// min"); one primary button the whole width (a meeting link first, as "Entrar na reunião", else "Concluir"); the snooze
// lengths offered on the spot. Full screen is the same column, larger, over the blurred desktop; it covers the whole
// screen. Keys: ⏎ is the primary, esc closes (ReminderPanel's cancelOperation).
//
// The window stays the owner's (ReminderWindowController): two hooks there take this view and its height. Every button
// goes through `ReminderManager.perform` / `snooze(id:minutes:)` as the owner's alert did, so a test run (KoncluiReminderTrial)
// changes nothing. The App Store build keeps the owner's ReminderAlertView.
@MainActor
enum KoncluiReminderAlert {
    /// The alert's view, or nil where the owner's stays (App Store build).
    static func hostingView(for reminder: Reminder) -> NSView? {
        #if APPSTORE
        return nil
        #else
        let host = NSHostingView(rootView: KoncluiReminderAlertView(reminder: reminder)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top))
        // The window keeps the frame ReminderWindowController gives it (`cardHeight`); left on, the hosting view would grow
        // it to its own ideal size, measured without the card's width.
        host.sizingOptions = []
        return host
        #endif
    }

    /// A card is as tall as what it says, at the width chosen in the editor; `reminder.height` is no longer used.
    static func cardHeight(for reminder: Reminder) -> Double {
        #if APPSTORE
        return reminder.height
        #else
        let host = NSHostingView(rootView: KoncluiReminderAlertView(reminder: reminder).frame(width: reminder.width))
        return Double(host.fittingSize.height)
        #endif
    }
}

#if !APPSTORE

struct KoncluiReminderAlertView: View {
    let reminder: Reminder

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var shown = false

    private var full: Bool { reminder.presentation == .fullScreen }
    private var trial: Bool { KoncluiReminderTrial.isRunning(reminder.id) }
    /// The room above the card for the Koru's drawing; she stands `rise` points above its edge.
    private static let perch: CGFloat = 52
    private static let rise: CGFloat = 34

    var body: some View {
        Group {
            if full { fullScreen } else { card }
        }
        .environment(\.koncluiMotion, reduceMotion ? .still : .live)
        .environment(\.colorScheme, .dark)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8)) { shown = true }
        }
    }

    // MARK: - Card

    private var card: some View {
        column(big: false)
            .padding(.horizontal, 22).padding(.top, 46).padding(.bottom, 18)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(KoncluiTheme.panel)
                .overlay { KoncluiGrain().clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous)) })
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
            .overlay(alignment: .top) { koru(size: 52).offset(y: -Self.rise) }
            .overlay(alignment: .topLeading) { if trial { trialTag.padding(14) } }
            .padding(.top, Self.perch)
            .scaleEffect(shown ? 1 : 0.96, anchor: .top)
            .opacity(shown ? 1 : 0)
    }

    // MARK: - Full screen

    private var fullScreen: some View {
        ZStack {
            if reduceTransparency {
                KoncluiTheme.panel
            } else {
                KoncluiBehindWindowBlur()
                Color.black.opacity(0.5)
            }
            VStack(spacing: 0) {
                koru(size: 84)
                column(big: true).padding(.top, 18)
            }
            .frame(maxWidth: 720)
            .padding(40)
            .scaleEffect(shown ? 1 : 0.98)
            .offset(y: shown ? 0 : 14)
            if trial { trialTag.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) }
        }
        .opacity(shown ? 1 : 0)
        .ignoresSafeArea()
    }

    // MARK: - The column

    private func column(big: Bool) -> some View {
        VStack(spacing: 0) {
            Text(verbatim: reminder.nextFireDate.formatted(date: .omitted, time: .shortened))
                .font(.system(size: big ? 150 : 60, weight: .ultraLight).monospacedDigit())
                .tracking(big ? -5 : -2)
                .foregroundStyle(KoncluiTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            whenLine(big: big).padding(.top, big ? 12 : 6)
            Text(verbatim: reminder.title)
                .font(.system(size: big ? 44 : 19, weight: .semibold))
                .foregroundStyle(KoncluiTheme.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, big ? 30 : 14)
            if !reminder.message.isEmpty {
                Text(verbatim: reminder.message)
                    .font(.system(size: big ? 20 : 13.5))
                    .foregroundStyle(KoncluiTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(big ? 8 : 5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, big ? 10 : 4)
            }
            if let image = reminder.imageData.flatMap(NSImage.init(data:)) {
                Image(nsImage: image).resizable().scaledToFit()
                    .frame(maxHeight: big ? 220 : 110)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top, 12)
            }
            actions(big: big).padding(.top, big ? 44 : 18)
            if reminder.snoozeMinutes != nil { snoozeRow(big: big).padding(.top, big ? 30 : 14) }
            keysHint(big: big).padding(.top, big ? 26 : 12)
        }
    }

    private func whenLine(big: Bool) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let repeats = String(localized: String.LocalizationValue(KoncluiReminderRules.repeatKey(reminder.repeats)))
            let words: Text = {
                switch KoncluiReminderAlertRules.when(reminder.nextFireDate, now: context.date) {
                case .now: return Text("konclui.reminders.alert.now").foregroundColor(KoncluiTheme.accent).bold()
                case .ahead(let seconds):
                    return Text("konclui.reminders.alert.in \(Self.duration(seconds))").foregroundColor(KoncluiTheme.accent).bold()
                case .late(let seconds):
                    return Text("konclui.reminders.alert.ago \(Self.duration(seconds))").foregroundColor(KoncluiTheme.attention).bold()
                }
            }()
            (words + Text(verbatim: " · " + repeats).foregroundColor(KoncluiTheme.textSecondary))
                .font(.system(size: big ? 20 : 12.5, weight: .medium).monospacedDigit())
        }
    }

    // MARK: - Buttons

    private struct Action: Identifiable {
        let id: String
        let title: String
        let button: ReminderButton?
        let action: ReminderButtonAction
        var meeting = false
    }

    /// The primary first, then the reminder's other buttons (KoncluiReminderAlertRules.ordered).
    private var actionList: [Action] {
        let buttons = KoncluiReminderAlertRules.ordered(reminder.buttons, message: reminder.message)
        guard !buttons.isEmpty else {
            return [Action(id: "close", title: String(localized: "konclui.reminders.action.dismiss"), button: nil, action: .dismiss)]
        }
        return buttons.map { button in
            let meeting = button.action == .openURL && KoncluiReminderAlertRules.isMeeting(button.httpsURL)
            return Action(id: button.id.uuidString, title: meeting ? String(localized: "konclui.reminders.alert.join") : button.title,
                          button: button, action: button.action, meeting: meeting)
        }
    }

    private func actions(big: Bool) -> some View {
        let list = actionList
        return VStack(spacing: big ? 12 : 8) {
            ForEach(Array(list.enumerated()), id: \.element.id) { index, item in
                let primary = index == 0
                let button = Button { run(item) } label: {
                    HStack(spacing: 8) {
                        if item.meeting { Image(systemName: "video.fill") }
                        Text(verbatim: item.title).lineLimit(1)
                    }
                    .font(.system(size: big ? 19 : 15, weight: .semibold))
                    .foregroundStyle(primary ? KoncluiTheme.onAccent : KoncluiTheme.textPrimary)
                    .frame(maxWidth: big ? 420 : .infinity)
                    .frame(height: big ? 58 : 46)
                    .background(Capsule().fill(primary ? KoncluiTheme.accent : Color.white.opacity(0.1)))
                    .contentShape(Capsule())
                }
                .buttonStyle(KoncluiAlertPress())
                .pointerStyle(.link)
                if primary { button.keyboardShortcut(.defaultAction) } else { button }
            }
        }
    }

    private func run(_ item: Action) {
        let manager = ReminderManager.shared
        manager.perform(item.action, for: reminder.id, button: item.button)
        if item.action != .snooze { ReminderWindowController.shared.dismiss(id: reminder.id) }
    }

    private func snoozeRow(big: Bool) -> some View {
        let chips = KoncluiReminderAlertRules.snoozeChips(own: reminder.snoozeMinutes ?? 5)
        return VStack(spacing: big ? 12 : 7) {
            Text("konclui.reminders.action.snooze")
                .font(.system(size: big ? 13 : 11, weight: .bold))
                .tracking(big ? 1.6 : 1.2)
                .textCase(.uppercase)
                .foregroundStyle(KoncluiTheme.textTertiary)
            HStack(spacing: big ? 10 : 6) {
                ForEach(chips.shown, id: \.self) { minutes in
                    Button { snooze(minutes) } label: { chip(Self.duration(Double(minutes * 60)), big: big) }
                        .buttonStyle(KoncluiAlertPress())
                        .pointerStyle(.link)
                }
                Menu {
                    ForEach(chips.more, id: \.self) { minutes in
                        Button(Self.duration(Double(minutes * 60))) { snooze(minutes) }
                    }
                } label: {
                    chip("⋯", big: big, round: true)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel(Text("konclui.reminders.alert.more"))
            }
        }
    }

    private func chip(_ title: String, big: Bool, round: Bool = false) -> some View {
        Text(verbatim: title)
            .font(.system(size: big ? 16 : 12.5, weight: .semibold))
            .foregroundStyle(KoncluiTheme.textBody)
            .padding(.horizontal, round ? 0 : (big ? 18 : 12))
            .frame(minWidth: round ? (big ? 44 : 30) : (big ? 110 : 60))
            .frame(height: big ? 44 : 30)
            .background(Capsule().fill(Color.white.opacity(0.06)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(big ? 0.22 : 0.12)))
            .contentShape(Capsule())
    }

    private func snooze(_ minutes: Int) {
        if KoncluiReminderTrial.close(reminder.id, action: .snooze, button: nil) { return }
        do {
            try ReminderManager.shared.snooze(id: reminder.id, minutes: minutes)
        } catch {
            ReminderManager.shared.report(error.localizedDescription)
        }
    }

    // MARK: - Pieces

    private func koru(size: CGFloat) -> some View {
        HubLiveMochi(color: "#F5F6F8", size: size)
            .frame(width: size * 1.5, height: size * 1.1)
            .scaleEffect(shown ? 1 : 0.7, anchor: .bottom)
            .accessibilityHidden(true)
    }

    private func keysHint(big: Bool) -> some View {
        let primaryIsMeeting = actionList.first?.meeting == true
        return HStack(spacing: 6) {
            keycap("esc", big: big)
            Text("konclui.reminders.alert.esc")
            Text(verbatim: "·")
            keycap("⏎", big: big)
            Text(primaryIsMeeting ? "konclui.reminders.alert.return-join" : "konclui.reminders.alert.return")
        }
        .font(.system(size: big ? 14 : 11))
        .foregroundStyle(KoncluiTheme.textTertiary)
    }

    private func keycap(_ key: String, big: Bool) -> some View {
        Text(verbatim: key)
            .font(.system(size: big ? 12 : 10, weight: .semibold))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(KoncluiTheme.textTertiary.opacity(0.7)))
    }

    private var trialTag: some View {
        Text("konclui.reminders.alert.trial")
            .koncluiType(.label)
            .foregroundStyle(KoncluiTheme.onAccent)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(KoncluiTheme.attention))
    }

    /// "1 min 54 s", "5 min", "1 h": the system's own short units, in the person's language.
    static func duration(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .short
        formatter.allowedUnits = seconds >= 3_600 ? [.hour, .minute] : (seconds >= 60 ? [.minute, .second] : [.second])
        formatter.maximumUnitCount = 2
        return formatter.string(from: seconds) ?? ""
    }
}

/// The press of the alert's buttons: they sink a little under the pointer, at once (UX.md 1.4).
private struct KoncluiAlertPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// The desktop behind a full-screen alert, blurred (the system's material, behind the window).
private struct KoncluiBehindWindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
#endif
