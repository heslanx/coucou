#if !APPSTORE
import SwiftUI

// Koncluí: two controls of Settings → Active pills that used to be silent. A blocked switch says why and offers the way out
// (docs/konclui/UX.md 1.1: explain, redirect, resolve), and the colour dot is a door, not a bare 10 pt circle.

/// What a tab row shows beside a switch that four tabs on keep from turning on: the reason, and a popover that frees a place.
struct KoncluiTabLimitDoor: View {
    struct Tab: Identifiable {
        let id: String
        let name: String
        let colorHex: String
    }

    /// The tab the person is trying to turn on.
    let name: String
    /// The tabs they can turn off to make room.
    let tabs: [Tab]
    @Binding var isOpen: Bool
    let turnOff: (String) -> Void

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: 4) {
                Text("konclui.pills.limit")
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold)).accessibilityHidden(true)
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) { popover }
        .accessibilityLabel(Text(verbatim: String(format: String(localized: "konclui.pills.limit.about"), name)))
        .accessibilityHint(Text("konclui.pills.limit.hint"))
    }

    private var popover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("konclui.pills.limit")
                .font(.system(size: 13, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: String(format: String(localized: "konclui.pills.limit.about"), name))
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 6) {
                ForEach(tabs) { tab in
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: tab.colorHex)).frame(width: 10, height: 10).accessibilityHidden(true)
                        Text(verbatim: tab.name).font(.system(size: 12))
                        Spacer(minLength: 8)
                        Button(String(localized: "konclui.pills.turn-off")) {
                            turnOff(tab.id)
                            isOpen = false
                        }
                        .buttonStyle(.koncluiSecondary)
                        .controlSize(.small)
                        .accessibilityLabel(Text(verbatim: String(format: String(localized: "konclui.pills.turn-off.named"), tab.name)))
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 320, alignment: .leading)
        .koncluiTheme()   // a popover is its own window: the hub's buttons do not reach it
    }
}

/// The dot that opens a tab's colour palette. A thin ring says it is a control, the hand and the tooltip say what for, and
/// VoiceOver reads "name, Color". A 22 pt target around the 10 pt dot.
struct KoncluiColorDot: View {
    let hex: String
    let tabName: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 10, height: 10)
                .overlay(Circle().strokeBorder(Color.primary.opacity(hovering ? 0.8 : 0.32), lineWidth: 1).padding(-3))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .onHover { hovering = $0 }
        .help(String(localized: "Color"))
        .accessibilityLabel(Text(tabName + " \u{00B7} " + String(localized: "Color")))
    }
}
#endif
