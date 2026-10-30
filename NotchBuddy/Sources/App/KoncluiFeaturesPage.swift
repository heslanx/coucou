#if !APPSTORE
import SwiftUI

/// Koncluí: the Features screen ("Recursos" in Portuguese): a switch for every feature that has a flag, grouped
/// as pills, pages and Settings blocks. Hidden until the user unlocks it (⌥-click the wordmark in the window's
/// sidebar, or `defaults write com.konclui.mac konclui.features.unlocked -bool YES`).
struct KoncluiFeaturesPage: View {
    @ObservedObject private var model = KoncluiFeatureModel.shared

    var body: some View {
        HubPageScaffold(title: String(localized: "konclui.features.title"),
                        subtitle: String(localized: "konclui.features.subtitle")) {
            ForEach(KoncluiFeature.Kind.allCases, id: \.self) { kind in
                GroupBox(kind.title) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(kind.note)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        rows(KoncluiFeatureRegistry.features(in: kind))
                    }
                    .padding(6)
                }
            }
            Button(String(localized: "konclui.features.restore")) { model.restoreDefaults() }
                .buttonStyle(.koncluiSecondary)
        }
    }

    /// The features of a group, with a heading each time the section changes (a pill's category).
    @ViewBuilder private func rows(_ features: [KoncluiFeature]) -> some View {
        ForEach(features) { feature in
            if let section = feature.section, features.first(where: { $0.section == section })?.id == feature.id {
                Divider()
                Text(section)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            row(feature)
        }
    }

    private func row(_ feature: KoncluiFeature) -> some View {
        HStack(spacing: 8) {
            Text(feature.title)
                .font(.system(size: 12))
            Spacer()
            if feature.isRequired {
                Text(String(localized: "konclui.features.required"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else if feature.shipsOff {
                Text(String(localized: "konclui.features.off-by-default"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Toggle("", isOn: Binding(
                get: { KoncluiFeatures.isOn(feature.id) },
                set: { model.set(feature.id, $0) }
            ))
            .toggleStyle(.switch)   // Koncluí: an on/off setting, not a list selection: a switch, like the other settings
            .labelsHidden()
            .disabled(feature.isRequired)
        }
    }
}

/// The Features item of the window's sidebar, shown once the screen is unlocked. Same look as the pages' items.
struct KoncluiFeaturesSidebarItem: View {
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "flag")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selected ? KoncluiTheme.accent : KoncluiTheme.textBody)
                    .frame(width: 20)
                Text(String(localized: "konclui.features.title"))
                    .font(.system(size: 14, weight: selected ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .foregroundColor(selected ? HubTheme.text : KoncluiTheme.textBody)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 9)
                .fill(selected ? KoncluiTheme.accent.opacity(0.12) : Color.white.opacity(hover ? 0.06 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .koncluiPointer()
    }
}
#endif
