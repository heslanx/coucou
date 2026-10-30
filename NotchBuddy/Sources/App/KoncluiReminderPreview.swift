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
// either). The layout repeats ReminderWindowController's ReminderAlertView (symbol or image, title, message, the snooze
// button first, Escape line); keep them in step when that view changes.
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

    /// The button the loop presses: the first of the person's own, else "Adiar" (the snooze button comes first on the alert).
    private var pressedID: Int? { draft.buttons.isEmpty ? (draft.snoozeOn ? -1 : nil) : 0 }

    /// What that press does, said on the screen while the reminder is away: back in 5 minutes, its next turn, or done.
    private var outcome: String? {
        guard let pressedID else { return nil }
        guard pressedID >= 0 else { return String(localized: "konclui.reminders.preview.back \(draft.snoozeMinutes)") }
        let action = draft.buttons[pressedID].action
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

    private var cardSize: CGSize {
        let k = scale * Self.legibility
        return CGSize(width: min(width - 2 * Self.inset, draft.width * k),
                      height: min(height - menuBar - 2 * Self.inset, draft.height * k))
    }

    /// The room the card's top-left corner can move in.
    private var room: CGSize {
        CGSize(width: max(0, width - 2 * Self.inset - cardSize.width),
               height: max(0, height - menuBar - 2 * Self.inset - cardSize.height))
    }

    private var card: some View {
        let size = cardSize
        return alertBody(compact: true)
            .frame(width: size.width, height: size.height, alignment: .top)
            .background(material(radius: 9))
            .scaleEffect(phase == .pressed ? 0.985 : 1)
            .offset(x: Self.inset + draft.positionX * room.width,
                    y: menuBar + Self.inset + draft.positionY * room.height)
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

    private var fullScreenAlert: some View {
        let k = scale * Self.legibility
        // As the alert: the card covers the screen (32 pt from its edges), the words keep a column in its middle.
        let edge = max(5, 32 * scale)
        return ZStack {
            Color.black.opacity(0.88)
            alertBody(compact: false)
                .frame(width: min(width - 2 * edge - 16, draft.width * k), alignment: .top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(material(radius: 10))
                .padding(edge)
                .scaleEffect(phase == .pressed ? 0.99 : 1)
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }

    private func material(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color(hex: "#2A2B30").opacity(0.94))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.white.opacity(0.14)))
            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
    }

    /// ReminderAlertView's content, at the preview's sizes.
    private func alertBody(compact: Bool) -> some View {
        VStack(spacing: compact ? 4 : 6) {
            if let data = draft.imageData, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFit()
                    .frame(maxHeight: cardSize.height * 0.3)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else if let symbol = draft.symbol, !symbol.isEmpty {
                Image(systemName: symbol)
                    .font(.system(size: compact ? 14 : 18, weight: .medium))
                    .foregroundColor(.orange)
            }
            Text(verbatim: draft.title.isEmpty ? String(localized: "konclui.reminders.title.placeholder") : draft.title)
                .font(.system(size: compact ? 10.5 : 13, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(draft.title.isEmpty ? 0.45 : 0.95))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            if !draft.message.isEmpty {
                Text(verbatim: draft.message)
                    .font(.system(size: compact ? 8 : 9.5))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(compact ? 2 : 4)
            }
            buttons(compact: compact)
            Text("Press Escape to close this alert.")
                .font(.system(size: 6))
                .foregroundColor(.white.opacity(0.4))
                .lineLimit(1)
        }
        .padding(compact ? 8 : 12)
    }

    private struct Shown: Identifiable {
        let id: Int
        let title: String
        let tinted: Bool
    }

    private var shownButtons: [Shown] {
        var list: [Shown] = []
        if draft.snoozeOn {
            list.append(Shown(id: -1, title: String(localized: "Snooze · \(draft.snoozeMinutes) min"), tinted: false))
        }
        for (index, button) in draft.buttons.enumerated() {
            let title = button.title.trimmingCharacters(in: .whitespacesAndNewlines)
            list.append(Shown(id: index, title: title.isEmpty ? "…" : title, tinted: button.action == .complete))
        }
        return list
    }

    @ViewBuilder private func buttons(compact: Bool) -> some View {
        let list = shownButtons
        if !list.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 52 : 60), spacing: 3)], spacing: 3) {
                ForEach(list) { item in
                    let pressed = phase == .pressed && item.id == pressedID
                    Text(verbatim: item.title)
                        .font(.system(size: compact ? 7.5 : 8.5, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundColor(item.tinted ? .orange : .white.opacity(0.85))
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity, minHeight: compact ? 13 : 16)
                        .background(RoundedRectangle(cornerRadius: 3.5)
                            .fill(pressed ? Color.orange.opacity(0.45)
                                  : (item.tinted ? Color.orange.opacity(0.18) : Color.white.opacity(0.12))))
                        .scaleEffect(pressed ? 0.94 : 1)
                }
            }
        }
    }
}
#endif
