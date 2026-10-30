#if !APPSTORE
import SwiftUI

// Koncluí: the status at the bottom of the sidebar ("Ditado desligado", "Pronto · segure ⌥") is a door, not a label
// (docs/konclui/UX.md 1.2): a hover fill, the pointing hand, a chevron, and a small popover with what a person most likely
// wants next, the likeliest first. It replaces a button that only jumped to Ajustes whatever the state was.
struct KoncluiDictationStatus: View {
    @ObservedObject var router: HubRouter
    @ObservedObject private var flow = FlowDictation.shared
    @State private var open = false
    @State private var hover = false
    @Environment(\.colorSchemeContrast) private var contrast

    private var ready: Bool { flow.isEnabled && flow.trusted }

    private var words: String {
        ready ? String(format: String(localized: "hub.status-ready %@"), flow.key.label)
              : (flow.isEnabled ? String(localized: "hub.status-access") : String(localized: "hub.status-off"))
    }

    var body: some View {
        Button { open.toggle() } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(ready ? KoncluiTheme.ok : (flow.isEnabled ? KoncluiTheme.attention : KoncluiTheme.textSecondary))
                    .frame(width: 8, height: 8)
                Text(words)
                    .koncluiType(.detail)
                    .foregroundColor(KoncluiTheme.textBody)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(KoncluiTheme.textTertiary)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(KoncluiTheme.card))
            .overlay(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(hover ? 0.04 : 0)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(KoncluiTheme.hairline(contrast)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .koncluiPointer()
        .accessibilityValue(Text(words))
        .accessibilityHint(Text("konclui.status.hint"))
        .popover(isPresented: $open, arrowEdge: .top) { actions }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !flow.isEnabled {
                action("power", String(localized: "hub.setup-enable"), first: true) { flow.isEnabled = true }
            } else if !flow.trusted {
                action("lock.shield", String(localized: "flow.accessibility-open"), first: true) { flow.openAccessibilitySettings() }
            }
            action("slider.horizontal.3", String(localized: "konclui.status.open-settings"), first: ready) { router.page = .settings }
            if flow.isEnabled {
                action("power", String(localized: "konclui.status.turn-off"), first: false) { flow.isEnabled = false }
            }
        }
        .padding(8)
        .frame(minWidth: 220)
        .koncluiTheme()
    }

    private func action(_ symbol: String, _ title: String, first: Bool, run: @escaping () -> Void) -> some View {
        KoncluiPopoverAction(symbol: symbol, title: title, first: first) {
            open = false
            run()
        }
    }
}

/// One line of a door's popover: an icon, a verb, the whole row is the target. The likeliest one reads as a link.
struct KoncluiPopoverAction: View {
    let symbol: String
    let title: String
    var first = false
    let run: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: run) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 18)
                Text(title).font(.system(size: 13, weight: first ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .foregroundColor(first ? KoncluiTheme.accent : KoncluiTheme.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(hover ? 0.08 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .koncluiPointer()
    }
}
#endif
