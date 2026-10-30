#if !APPSTORE
import SwiftUI

// Koncluí: a disclosure (accordion) opens and closes from its whole label row, not from the chevron alone as the macOS
// default does (docs/konclui/UX.md, "Hit targets"). Applied to the hub window's content in FlowHub.swift, so every
// DisclosureGroup there takes it, and directly to the ones inside popovers, which are separate windows.
struct KoncluiDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { configuration.isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                        .frame(width: 12)
                    configuration.label
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
            .accessibilityValue(Text(configuration.isExpanded ? "konclui.disclosure.expanded" : "konclui.disclosure.collapsed"))

            if configuration.isExpanded {
                configuration.content
                    .padding(.leading, 18)
            }
        }
    }
}
#endif
