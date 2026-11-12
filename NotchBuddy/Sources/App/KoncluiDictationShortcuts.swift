#if !APPSTORE
import SwiftUI

// Koncluí: the keys of dictation (hold, hands-free, paste again, cancel) are set in Ajustes do ditado, and listed here, read-only,
// where people look for keys (docs/konclui/UX.md 2.6: recognition rather than recall). One place changes them, the other
// links to it. The Shortcuts page shows this group after its own (KONCLUI.md, "Koncluí hooks in upstream files").
struct KoncluiDictationShortcuts: View {
    @ObservedObject private var flow = FlowDictation.shared

    var body: some View {
        GroupBox(String(localized: "hub.page.dictation")) {
            VStack(alignment: .leading, spacing: 10) {
                row("hub.settings.hold", flow.key.label)
                row("hub.settings.handsfree", "\(flow.key.symbol) \(flow.key.symbol)")
                row("hub.settings.paste-again", "⌃⌘V")
                row("hub.settings.cancel", String(localized: "hub.key-esc"))
                HStack {
                    Spacer()
                    Button(String(localized: "konclui.status.open-settings")) { FlowHubController.shared.show(.settings) }
                        .buttonStyle(.koncluiSecondary)
                        .controlSize(.small)
                }
            }
            .padding(6)
        }
    }

    private func row(_ title: LocalizedStringKey, _ key: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 8)
            KoncluiKeyCap(text: key)
        }
    }
}
#endif
