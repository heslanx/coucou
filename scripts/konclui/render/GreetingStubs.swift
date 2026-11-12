// Stand-ins for the app pieces GreetingCanvasView.swift uses, so the renderer can draw the real greeting.
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    var notchWidth: CGFloat = 185
    var notchHeight: CGFloat = 32
}

extension SoundEngine {
    func fadeOut(_ name: String, duration: Double) {}
}

extension Notification.Name {
    static let greetComplete = Notification.Name("notchBuddy.greetComplete")
    static let greetingHover = Notification.Name("notchBuddy.greetingHover")
    static let greetingInterrupt = Notification.Name("notchBuddy.greetingInterrupt")
}
