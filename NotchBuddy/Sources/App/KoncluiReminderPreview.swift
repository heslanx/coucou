#if !APPSTORE
import AppKit
import SwiftUI

// Koncluí: the live preview of the reminder editor (KoncluiReminderEditor.swift), like the WhatsApp block's notch preview:
// the chosen screen in small (its menu bar, its notch, the time the reminder rings in the clock) and the reminder playing on
// it as it will: it arrives, its first button is pressed, it leaves, and again. A card can be dragged to where it should
// appear; let go near a corner, an edge or the centre, it lands there (KoncluiReminderPlace.snapped).
//
// The card is drawn at a readable scale, not the screen's: on a 1728 pt screen a 480 pt card is a quarter of the width,
// and so it stays here, but its words keep a size that can be read (the real alert's fonts do not grow with the card
// either). The layout repeats KoncluiReminderAlertView ("Despertador com a Koru": the Koru on top, the time, the primary
// the whole width, the snooze lengths); keep them in step when that view changes.
//
// Cost: the loop is one task, alive only while the editor is on screen and Reduce Motion is off; editing a field puts the
// card back on the screen and holds it. Reduce Motion: the card stays, no spring, no press.

/// The screen a reminder rings on, as the preview needs it.
struct KoncluiReminderScreen: Equatable {
    var width: Double
    var height: Double
    var menuBar: Double
    var notch: Bool

    @MainActor static func at(_ index: Int) -> KoncluiReminderScreen {
        let screens = NSScreen.screens
        guard let screen = screens.isEmpty ? nil : screens[min(max(0, index), screens.count - 1)] else {
            return KoncluiReminderScreen(width: 1728, height: 1117, menuBar: 37, notch: true)
        }
        return KoncluiReminderScreen(width: screen.frame.width, height: screen.frame.height,
                                     menuBar: max(24, screen.frame.maxY - screen.visibleFrame.maxY),
                                     notch: screen.safeAreaInsets.top > 0)
    }
}

struct KoncluiReminderPreview: View {
    @Binding var draft: KoncluiReminderDraft
    let screen: KoncluiReminderScreen
    var width: CGFloat = 380

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = Phase.shown
    @State private var restarts = 0
    @State private var onScreen = false
    @State private var dragStart: (x: Double, y: Double)?
    /// The card's own height, measured: it follows what it says, like the alert.
    @State private var cardHeight: CGFloat = 120

    private enum Phase { case waiting, shown, pressed, gone }

    /// How much larger than the screen's own scale the card is drawn, so its words read.
    private static let legibility: CGFloat = 1.7
    private static let inset: CGFloat = 5

    private var scale: CGFloat { width / screen.width }
    private var height: CGFloat { min(270, width * screen.height / screen.width) }
    private var menuBar: CGFloat { max(8, screen.menuBar * scale) }
    private var fullScreen: Bool { draft.presentation == .fullScreen }
    private var animates: Bool { onScreen && !reduceMotion && dragStart == nil }

    var body: some View {
        ZStack(alignment: .topLeading) {
            wallpaper
            menuBarStrip
            if phase != .waiting && phase != .gone {
                if fullScreen { fullScreenAlert.transition(.opacity) } else { card }
            } else if let outcome {
                outcomeToast(outcome)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.14)))
        .coordinateSpace(name: Self.space)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("konclui.reminders.preview.label"))
        .accessibilityValue(Text(verbatim: draft.title))
        .onAppear { onScreen = true }
        .onDisappear { onScreen = false }
        .onChange(of: draft) { _, _ in
            // What was just edited shows at once, and stays long enough to be seen.
            if phase != .shown { withAnimation(.easeOut(duration: 0.15)) { phase = .shown } }
            restarts += 1
        }
        .task(id: LoopID(animates: animates, restarts: restarts)) { await play() }
    }

    private static let space = "koncluiReminderScreen"

    private struct LoopID: Equatable {
        var animates: Bool
        var restarts: Int
    }

    // MARK: - The loop

    private func play() async {
        guard animates else {
            phase = .shown
            return
        }
        while !Task.isCancelled {
            if phase != .shown { set(.shown, .spring(response: 0.42, dampingFraction: 0.78)) }
            guard await pause(2.6) else { return }
            set(.pressed, .easeOut(duration: 0.12))
            guard await pause(0.32) else { return }
            set(.gone, .easeIn(duration: 0.22))
            guard await pause(1.3) else { return }
            set(.waiting, .easeOut(duration: 0.2))
            guard await pause(0.4) else { return }
        }
    }

    private func set(_ next: Phase, _ animation: Animation?) {
        withAnimation(animation) { phase = next }
    }

    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled
    }

    // MARK: - The screen

    private var wallpaper: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#1B2440"), Color(hex: "#2B1F3F"), Color(hex: "#3A2433")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color(hex: "#FB923C").opacity(0.18), .clear], center: .bottomTrailing,
                           startRadius: 0, endRadius: width * 0.7)
            // Two windows of the desktop, so the card reads as floating over work.
            RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.06))
                .frame(width: width * 0.46, height: height * 0.52)
                .position(x: width * 0.3, y: height * 0.52)
            RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.045))
                .frame(width: width * 0.38, height: height * 0.42)
                .position(x: width * 0.7, y: height * 0.62)
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }

    private var menuBarStrip: some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.1))
            HStack(spacing: 4) {
                Image(systemName: "apple.logo").font(.system(size: max(5, menuBar * 0.55)))
                Spacer()
                Text(verbatim: draft.dueAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                    .font(.system(size: max(5.5, menuBar * 0.6), weight: .medium).monospacedDigit())
            }
            .foregroundColor(.white.opacity(0.85))
            .padding(.horizontal, 6)
            if screen.notch {
                UnevenRoundedRectangle(bottomLeadingRadius: menuBar * 0.45, bottomTrailingRadius: menuBar * 0.45)
                    .fill(Color.black)
                    .frame(width: 185 * scale, height: menuBar)
            }
        }
        .frame(width: width, height: menuBar)
        .allowsHitTesting(false)
    }

    // MARK: - After the press

    /// The alert's buttons as KoncluiReminderAlert orders them; the loop presses the first (the primary).
    private var alertButtons: [ReminderButton] { KoncluiReminderAlertRules.ordered(draft.buttons, message: draft.message) }

    /// What the primary does, said on the screen while the reminder is away: its next turn, done, or stopped.
    private var outcome: String? {
        let action = alertButtons.first?.action ?? .dismiss
        if action == .stop { return String(localized: "konclui.reminders.preview.stopped") }
        if action == .snooze { return String(localized: "konclui.reminders.preview.back \(draft.snoozeMinutes)") }
        if let next = KoncluiReminderRules.following(draft.dueAt, repeats: draft.repeats) {
            return String(localized: "konclui.reminders.preview.then \(KoncluiReminderWords.when(next))")
        }
        return String(localized: "konclui.reminders.preview.finished")
    }

    private func outcomeToast(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 9).frame(height: 20)
            .background(Capsule().fill(Color.black.opacity(0.55)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.14)))
            .frame(width: width)
            .offset(y: menuBar + 10)
            .transition(.opacity)
            .allowsHitTesting(false)
    }

    // MARK: - The card

    /// The card is as tall as what it says, as the alert is; its width is the size chosen.
    private var cardSize: CGSize {
        CGSize(width: min(width - 2 * Self.inset, draft.width * scale * Self.legibility),
               height: min(height - menuBar - 2 * Self.inset, cardHeight + Self.perch))
    }

    /// The room the card's top-left corner can move in.
    private var room: CGSize {
        CGSize(width: max(0, width - 2 * Self.inset - cardSize.width),
               height: max(0, height - menuBar - 2 * Self.inset - cardSize.height))
    }

    private static let perch: CGFloat = 14

    private var card: some View {
        alertColumn(big: false)
            .padding(.horizontal, 8).padding(.top, 15).padding(.bottom, 7)
            .frame(width: cardSize.width)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(KoncluiTheme.panel)
                .overlay { KoncluiGrain().clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous)) })
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
            .overlay(alignment: .top) { koru(26).offset(y: -Self.perch) }
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardHeight = $0 }
            .scaleEffect(phase == .pressed ? 0.985 : 1)
            .offset(x: Self.inset + draft.positionX * room.width,
                    y: menuBar + Self.inset + Self.perch + draft.positionY * room.height)
            .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
            .gesture(drag)
            .pointerStyle(dragStart == nil ? .grabIdle : .grabActive)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
            .onChanged { value in
                let start = dragStart ?? (draft.positionX, draft.positionY)
                if dragStart == nil { dragStart = start }
                if room.width > 0 { draft.positionX = min(1, max(0, start.x + value.translation.width / room.width)) }
                if room.height > 0 { draft.positionY = min(1, max(0, start.y + value.translation.height / room.height)) }
            }
            .onEnded { _ in
                let landed = KoncluiReminderPlace.snapped(x: draft.positionX, y: draft.positionY)
                withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                    draft.positionX = landed.x
                    draft.positionY = landed.y
                }
                dragStart = nil
            }
    }

    /// As the alert: the blurred desktop over the whole screen, the Koru, then the same column, larger.
    private var fullScreenAlert: some View {
        ZStack {
            wallpaper.blur(radius: 7)
            Color.black.opacity(0.5)
            VStack(spacing: 0) {
                koru(40)
                alertColumn(big: true).padding(.top, 4)
            }
            .frame(width: min(width - 40, 230))
            .scaleEffect(phase == .pressed ? 0.99 : 1)
        }
        .frame(width: width, height: height)
        .clipped()
        .allowsHitTesting(false)
    }

    private func koru(_ size: CGFloat) -> some View {
        MochiStill(showBadge: false)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    /// KoncluiReminderAlertView's column, at the preview's sizes.
    private func alertColumn(big: Bool) -> some View {
        VStack(spacing: 0) {
            Text(verbatim: draft.dueAt.formatted(date: .omitted, time: .shortened))
                .font(.system(size: big ? 36 : 25, weight: .ultraLight).monospacedDigit())
                .foregroundColor(.white)
                .lineLimit(1)
            (Text("konclui.reminders.alert.now").foregroundColor(KoncluiTheme.accent).bold()
             + Text(verbatim: " · " + String(localized: String.LocalizationValue(KoncluiReminderRules.repeatKey(draft.repeats))))
                .foregroundColor(.white.opacity(0.55)))
                .font(.system(size: big ? 7.5 : 6.5, weight: .medium))
                .padding(.top, 2)
            Text(verbatim: draft.title.isEmpty ? String(localized: "konclui.reminders.title.placeholder") : draft.title)
                .font(.system(size: big ? 12.5 : 10, weight: .semibold))
                .foregroundColor(.white.opacity(draft.title.isEmpty ? 0.45 : 0.95))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, big ? 7 : 5)
            if !draft.message.isEmpty {
                Text(verbatim: draft.message)
                    .font(.system(size: big ? 8.5 : 7.5))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
            VStack(spacing: 3) {
                ForEach(Array(previewButtons.enumerated()), id: \.offset) { index, title in
                    let primary = index == 0
                    let pressed = primary && phase == .pressed
                    Text(verbatim: title)
                        .font(.system(size: big ? 8 : 7, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundColor(primary ? KoncluiTheme.onAccent : .white.opacity(0.9))
                        .frame(maxWidth: .infinity, minHeight: big ? 17 : 15)
                        .background(Capsule().fill(primary ? KoncluiTheme.accent.opacity(pressed ? 0.75 : 1) : Color.white.opacity(0.1)))
                        .scaleEffect(pressed ? 0.95 : 1)
                }
            }
            .padding(.top, big ? 9 : 7)
            if draft.snoozeOn {
                HStack(spacing: 2.5) {
                    ForEach(KoncluiReminderAlertRules.snoozeChips(own: draft.snoozeMinutes).shown, id: \.self) { minutes in
                        chip(KoncluiReminderAlertView.duration(Double(minutes * 60)), big: big)
                    }
                    chip("⋯", big: big)
                }
                .padding(.top, big ? 6 : 5)
            }
        }
    }

    /// The buttons' words as the alert shows them: the primary first, a meeting link as "Entrar na reunião".
    private var previewButtons: [String] {
        let buttons = alertButtons
        guard !buttons.isEmpty else { return [String(localized: "konclui.reminders.action.dismiss")] }
        return buttons.map { button in
            if button.action == .openURL && KoncluiReminderAlertRules.isMeeting(button.httpsURL) {
                return String(localized: "konclui.reminders.alert.join")
            }
            let title = button.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? "…" : title
        }
    }

    private func chip(_ title: String, big: Bool) -> some View {
        Text(verbatim: title)
            .font(.system(size: big ? 6.5 : 6, weight: .semibold))
            .foregroundColor(.white.opacity(0.75))
            .padding(.horizontal, 4)
            .frame(height: big ? 11 : 10)
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.2)))
    }
}
#endif
