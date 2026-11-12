#if !APPSTORE
import AppKit
import SwiftUI

// Koncluí: the Estilos page lists the apps this Mac has, under the name this Mac gives them, and adds the places where people
// dictate prompts (docs/konclui/UX.md 5, "only what this Mac has"). Upstream's defaults stay in `FlowStore.defaultAppStyles`;
// the rows are filtered when they are drawn, so nothing the person saved is deleted.

enum KoncluiFlowStyles {
    /// Terminals and the agent workspace where a prompt is dictated: written as said, so the clean-up never rewrites them.
    static let extras: [FlowAppStyle] = [
        FlowAppStyle(bundleID: "com.stablyai.orca", name: "Orca", style: .verbatim),
        FlowAppStyle(bundleID: "dev.warp.Warp-Stable", name: "Warp", style: .verbatim),
        FlowAppStyle(bundleID: "com.mitchellh.ghostty", name: "Ghostty", style: .verbatim),
    ]

    /// The rows Koncluí put in the list itself (upstream's and the extras), as opposed to the ones the person added.
    @MainActor static var defaultIDs: Set<String> {
        Set(FlowStore.defaultAppStyles.map(\.bundleID) + extras.map(\.bundleID))
    }

    private static let offeredKey = "konclui.flow.styleAppsOffered"

    static func isInstalled(_ bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    /// Adds the extras that are installed and were never offered. Called once when the store loads.
    @MainActor static func seed(_ styles: [FlowAppStyle]) -> [FlowAppStyle] {
        let offered = Set(UserDefaults.standard.stringArray(forKey: offeredKey) ?? [])
        let result = KoncluiStyleApps.seed(candidates: extras.map(\.bundleID), present: Set(styles.map(\.bundleID)),
                                           offered: offered, installed: isInstalled)
        if result.offered != offered { UserDefaults.standard.set(result.offered.sorted(), forKey: offeredKey) }
        return styles + extras.filter { result.add.contains($0.bundleID) }
    }
}

extension FlowStore {
    func seedInstalledAppStyles() {
        let seeded = KoncluiFlowStyles.seed(appStyles)
        if seeded.count != appStyles.count { appStyles = seeded }
    }
}

/// Which apps are on this Mac and what this Mac calls them, looked up once per page.
@MainActor
final class KoncluiInstalledApps: ObservableObject {
    private var urls: [String: URL?] = [:]

    private func url(_ bundleID: String) -> URL? {
        if let known = urls[bundleID] { return known }
        let found = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        urls[bundleID] = .some(found)
        return found
    }

    func isInstalled(_ bundleID: String) -> Bool { url(bundleID) != nil }

    /// "Mensagens" on a Portuguese Mac, not the stored "Messages"; the stored name when the app is not here.
    func name(_ bundleID: String, fallback: String) -> String {
        guard let url = url(bundleID), let bundle = Bundle(url: url) else { return fallback }
        for info in [bundle.localizedInfoDictionary, bundle.infoDictionary] {
            for key in ["CFBundleDisplayName", "CFBundleName"] {
                if let name = info?[key] as? String, !name.isEmpty { return name }
            }
        }
        return url.deletingPathExtension().lastPathComponent
    }
}

/// A style to choose: the name of the current one, and a popover whose rows each say what the style does (a menu cannot carry
/// a second line, and "Natural", "Caprichado" and "Do jeito que foi dito" do not explain themselves).
struct KoncluiStylePicker: View {
    @Binding var selection: FlowStyle
    @State private var open = false
    @State private var hover = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Button { open.toggle() } label: {
            HStack(spacing: 6) {
                Text(selection.label).font(.system(size: 13))
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .bold)).foregroundColor(KoncluiTheme.textTertiary)
            }
            .foregroundColor(isEnabled ? KoncluiTheme.textPrimary : KoncluiTheme.textTertiary)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous)
                .fill(isEnabled && hover ? Color.white.opacity(0.1) : KoncluiTheme.control))
            .overlay(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous).strokeBorder(KoncluiTheme.controlStroke(contrast)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .koncluiPointer(isEnabled)
        .accessibilityLabel(Text(selection.label))
        .accessibilityHint(Text(selection.detail))
        .popover(isPresented: $open, arrowEdge: .bottom) { choices }
    }

    private var choices: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(FlowStyle.allCases) { style in
                KoncluiStyleChoice(style: style, selected: style == selection) {
                    selection = style
                    open = false
                }
            }
        }
        .padding(8)
        .frame(width: 320)
        .koncluiTheme()
    }
}

private struct KoncluiStyleChoice: View {
    let style: FlowStyle
    let selected: Bool
    let choose: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: choose) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(KoncluiTheme.accent)
                    .frame(width: 14)
                    .opacity(selected ? 1 : 0)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(style.label).font(.system(size: 13, weight: .semibold)).foregroundColor(KoncluiTheme.textPrimary)
                    Text(style.detail)
                        .koncluiType(.detail)
                        .foregroundColor(KoncluiTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.white.opacity(hover ? 0.08 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .koncluiPointer()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
#endif
