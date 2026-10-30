import AppKit
import SwiftUI

@MainActor
final class ReminderWindowController {
    static let shared = ReminderWindowController()

    private var panels: [UUID: ReminderPanel] = [:]
    private var panelOrder: [UUID] = []

    private init() {}

    func show(_ reminder: Reminder) {
        if let panel = panels[reminder.id] {
            panel.orderFrontRegardless()
            return
        }
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let screen = screens[min(reminder.screenIndex, screens.count - 1)]
        let fullScreen = reminder.presentation == .fullScreen
        let frame = fullScreen ? screen.frame : cardFrame(for: reminder, on: screen)
        let panel = ReminderPanel(contentRect: frame,
                                  styleMask: [.borderless, .nonactivatingPanel],
                                  backing: .buffered, defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = !fullScreen
        panel.level = fullScreen ? .screenSaver : .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.reminderID = reminder.id
        panel.screenIndex = reminder.screenIndex
        // Koncluí: the alert is "Despertador com a Koru" (KoncluiReminderAlert.swift); the App Store build keeps this one.
        panel.contentView = KoncluiReminderAlert.hostingView(for: reminder) ?? NSHostingView(rootView: ReminderAlertView(reminder: reminder))
        panels[reminder.id] = panel
        panelOrder.append(reminder.id)
        panel.orderFrontRegardless()
        panel.makeKey()
        NSApp.activate(ignoringOtherApps: true)
        arrangeOverlappingCards(on: screen, screenIndex: reminder.screenIndex)
    }

    func dismiss(id: UUID) {
        guard let panel = panels.removeValue(forKey: id) else { return }
        panelOrder.removeAll { $0 == id }
        panel.close()
        if let next = panelOrder.last, let nextPanel = panels[next] {
            nextPanel.makeKey()
        }
    }

    private func cardFrame(for reminder: Reminder, on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let size = NSSize(width: min(reminder.width, visible.width - 32),
                          height: min(KoncluiReminderAlert.cardHeight(for: reminder), visible.height - 32))   // Koncluí: as tall as it says
        let x = visible.minX + reminder.positionX * max(0, visible.width - size.width)
        let y = visible.minY + (1 - reminder.positionY) * max(0, visible.height - size.height)
        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }

    private func arrangeOverlappingCards(on screen: NSScreen, screenIndex: Int) {
        var stackIndex = 0
        for id in panelOrder {
            guard let panel = panels[id], panel.screenIndex == screenIndex,
                  panel.level != .screenSaver else { continue }
            if stackIndex > 0 {
                var frame = panel.frame
                let offset = CGFloat(stackIndex) * 28
                frame.origin.x = min(frame.origin.x + offset, screen.visibleFrame.maxX - frame.width)
                frame.origin.y = max(frame.origin.y - offset, screen.visibleFrame.minY)
                panel.setFrame(frame, display: true)
            }
            stackIndex += 1
        }
    }
}

private final class ReminderPanel: NSPanel {
    var reminderID: UUID?
    var screenIndex = 0

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        guard let reminderID else { return }
        ReminderManager.shared.dismiss(id: reminderID)
    }
}

private struct ReminderAlertView: View {
    let reminder: Reminder

    private var isFullScreen: Bool { reminder.presentation == .fullScreen }
    private var maximumWidth: CGFloat { isFullScreen ? CGFloat(reminder.width) : .infinity }
    private var maximumHeight: CGFloat { isFullScreen ? .infinity : CGFloat(reminder.height) }

    private func reminderActionButton(_ button: ReminderButton) -> some View {
        let action = button.action
        let reminderID = reminder.id
        return Button(button.title) {
            ReminderManager.shared.perform(action, for: reminderID, button: button)
            if action != .snooze {
                ReminderWindowController.shared.dismiss(id: reminderID)
            }
        }
        .buttonStyle(.bordered)
        .tint(action == .complete ? .orange : nil)
    }

    var body: some View {
        ZStack {
            if isFullScreen {
                Color.black.opacity(0.88).ignoresSafeArea()
            }
            ScrollView {
                VStack(spacing: 18) {
                    if let imageData = reminder.imageData, let image = NSImage(data: imageData) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: CGFloat(reminder.height) * 0.38)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else if let symbol = reminder.symbol, !symbol.isEmpty {
                        Image(systemName: symbol)
                            .font(.system(size: 42, weight: .medium))
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                    }

                    VStack(spacing: 8) {
                        Text(reminder.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        if !reminder.message.isEmpty {
                            Text(reminder.message)
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if reminder.snoozeMinutes != nil || !reminder.buttons.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                            if let minutes = reminder.snoozeMinutes {
                                Button(String(format: String(localized: "Snooze · %lld min"), Int64(minutes))) {
                                    ReminderManager.shared.perform(.snooze, for: reminder.id)
                                }
                                .buttonStyle(.bordered)
                            }
                            ForEach(reminder.buttons) { button in
                                reminderActionButton(button)
                            }
                        }
                    }

                    Text("Press Escape to close this alert.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(isFullScreen ? 36 : 24)
                .frame(maxWidth: maximumWidth)
            }
            .scrollIndicators(.hidden)
            // Koncluí: a full-screen alert covers the width too; its words keep their column (the width above).
            .frame(maxWidth: .infinity, maxHeight: max(120, maximumHeight - 48))
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 24, y: 12)
            .padding(isFullScreen ? 32 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isFullScreen ? Color.clear : Color.clear)
        .accessibilityElement(children: .contain)
    }
}
