import SwiftUI

// Koncluí: the registry of the feature flags (the store is CoucouKit/KoncluiFeatures.swift), what a flag does to
// the running app, and the small view helpers the Settings screens use. The Features screen is
// KoncluiFeaturesPage.swift; what each recognized-only screen lists is KoncluiRecognition.swift.

/// One feature a flag controls.
struct KoncluiFeature: Identifiable {
    enum Kind: String, CaseIterable {
        case pills, pages, blocks

        var title: String {
            switch self {
            case .pills:  return String(localized: "konclui.features.group.pills")
            case .pages:  return String(localized: "konclui.features.group.pages")
            case .blocks: return String(localized: "konclui.features.group.blocks")
            }
        }

        var note: String {
            switch self {
            case .pills:  return String(localized: "konclui.features.note.pills")
            case .pages:  return String(localized: "konclui.features.note.pages")
            case .blocks: return String(localized: "konclui.features.note.blocks")
            }
        }
    }

    let id: String
    let kind: Kind
    let title: String
    /// What the Features screen lists it under (a pill's category).
    var section: String? = nil

    var isRequired: Bool { KoncluiFeatures.required.contains(id) }
    var shipsOff: Bool { !KoncluiFeatures.shippedDefault(id) }
}

/// Every feature that has a flag. Deleting a feature for good is deleting its code and, for a Settings block,
/// its line here (a pill's entry follows its PillCatalog line, a page's its HubPage case): KONCLUI.md, "Feature flags".
enum KoncluiFeatureRegistry {
    /// Settings blocks that are features of their own. Integrations services, Voice and the Notetaker are not here:
    /// a service follows its pill's flag, Voice and the Notetaker are pages.
    static var blocks: [(id: String, title: String)] {
        [
            ("block_iphone",    "iPhone"),
            ("block_recap",     String(localized: "Weekly recap")),
            ("block_vitals",    String(localized: "vitals.title")),
            // Reminders is a page of the window now (HubPage.reminders, flag `block_reminders`): it is listed under Pages.
            ("block_updates",   String(localized: "konclui.features.block.updates")),
        ]
    }

    static var features: [KoncluiFeature] {
        #if APPSTORE
        let pills = PillCatalog.all.filter { !$0.githubOnly }
        #else
        let pills = PillCatalog.all
        #endif
        var list = pills.map {
            KoncluiFeature(id: $0.id, kind: .pills, title: $0.name, section: $0.category.title)
        }
        #if !APPSTORE
        list += HubPage.allCases.map { KoncluiFeature(id: $0.featureId, kind: .pages, title: $0.title) }
        #endif
        list += blocks.map { KoncluiFeature(id: $0.id, kind: .blocks, title: $0.title) }
        return list
    }

    static func features(in kind: KoncluiFeature.Kind) -> [KoncluiFeature] {
        features.filter { $0.kind == kind }
    }

    /// The feature behind each section of Settings (the standalone window's sidebar and the window's pages).
    static func sectionFeatureId(_ section: String) -> String? {
        switch section {
        case "general":      return "page_general"
        case "activepills":  return "page_pills"
        case "agents":       return "page_agents"
        case "chat":         return "page_chat"
        case "integrations": return "page_integrations"
        case "reminders":    return "block_reminders"
        case "voice":        return "page_voice"
        case "shortcuts":    return "page_shortcuts"
        default:             return nil
        }
    }
}

#if !APPSTORE
/// What the settings search may offer: only what the window can show. A page or block whose flag is off has no
/// result, and neither has the open/close hotkey, which the hub shows on Atalhos only (SettingsView, `embeddedSection`).
enum KoncluiSettingsSearch {
    static func isShown(_ id: String, page: HubPage) -> Bool {
        guard KoncluiFeatures.isOn(page.featureId) else { return false }
        switch id {
        case "general.hotkey": return false
        case "general.update": return KoncluiFeatures.isOn("block_updates")
        case "general.recap":  return KoncluiFeatures.isOn("block_recap")
        case "general.vitals": return KoncluiFeatures.isOn("block_vitals")
        case "general.iphone": return KoncluiFeatures.isOn("block_iphone")
        default:               return true
        }
    }

    /// An entry's words without the services whose pill is off (Integrations lists them by name).
    static func terms(_ entry: SettingsSearchEntry) -> [String] {
        let off = Set(PillCatalog.all.filter { !KoncluiFeatures.isOn($0.id) }.map(\.name))
        return entry.terms.filter { !off.contains($0) }
    }
}
#endif

#if !APPSTORE
extension HubPage {
    /// The id of this page's flag. Reminders keeps the flag it had as a block of the standalone Settings window.
    var featureId: String { self == .reminders ? "block_reminders" : "page_" + rawValue }

    /// The page itself when its feature is on, else the first page that is on.
    static func resolved(_ page: HubPage) -> HubPage {
        if KoncluiFeatures.isOn(page.featureId) { return page }
        return (flowPages + notchPages).first ?? .general
    }
}
#endif

/// What a change of a flag does to the running app, and the object the views watch to draw again.
@MainActor
final class KoncluiFeatureModel: ObservableObject {
    static let shared = KoncluiFeatureModel()

    /// Bumped after every change, so a view that reads a flag draws again.
    @Published private(set) var revision = 0
    private var observer: NSObjectProtocol?

    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: KoncluiFeatures.didChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.apply() }
        }
    }

    func set(_ id: String, _ on: Bool) { KoncluiFeatures.set(id, on) }

    func restoreDefaults() { KoncluiFeatures.resetAll() }

    private func apply() {
        dropPillsThatAreOff()
        #if !APPSTORE
        // The window may be on a page that just went off: the router falls back to the first one that is on,
        // without leaving the Features screen if that is where the user is.
        let router = FlowHubController.shared.router
        let onFeatures = router.showFeatures
        router.page = router.page
        router.showFeatures = onFeatures
        #endif
        revision += 1
    }

    /// A pill whose flag is off leaves the active pills and the notch. Turning it on again brings nothing back:
    /// the user adds it again.
    private func dropPillsThatAreOff() {
        let state = AppState.shared
        let off = Set(PillCatalog.all.map(\.id).filter { !KoncluiFeatures.isOn($0) })
        if !state.activeIntegrations.isDisjoint(with: off) { state.activeIntegrations.subtract(off) }
        if state.tasks.contains(where: { off.contains($0.id) }) {
            state.tasks.removeAll { off.contains($0.id) }
            if let focus = state.focusId, off.contains(focus) { state.focusId = state.mainPillId }
            state.syncMode()
            state.syncView()
        }
        // Also corrects the main pill if its flag went off.
        state.loadIntegrationTasks()
    }
}

extension View {
    /// Koncluí: draws the view only when `condition` holds. One line after a Settings block hides it without
    /// touching the block's own code.
    @ViewBuilder func koncluiShown(_ condition: Bool) -> some View {
        if condition { self }
    }
}

// MARK: - "Add…"

/// What the user added to the recognized-only screens, kept across launches (`KoncluiAdded` has the format).
@MainActor
final class KoncluiAddedModel: ObservableObject {
    static let shared = KoncluiAddedModel()

    @Published private(set) var entries: Set<String> = KoncluiAdded.load()

    func contains(_ screen: KoncluiAdded.Screen, _ id: String) -> Bool {
        entries.contains(KoncluiAdded.entry(screen, id))
    }

    func add(_ screen: KoncluiAdded.Screen, _ id: String) {
        entries.insert(KoncluiAdded.entry(screen, id))
        KoncluiAdded.save(entries)
    }
}

/// The "Add…" button at the end of a recognized-only list: a menu of what the list does not show yet.
struct KoncluiAddMenu: View {
    struct Item: Identifiable {
        let id: String
        let title: String
        /// A heading in the menu (a pill's category).
        var section: String? = nil
    }

    let items: [Item]
    let onPick: (String) -> Void

    private var groups: [(title: String?, items: [Item])] {
        var out: [(title: String?, items: [Item])] = []
        for item in items {
            if let i = out.firstIndex(where: { $0.title == item.section }) {
                out[i].items.append(item)
            } else {
                out.append((item.section, [item]))
            }
        }
        return out
    }

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "konclui.add.hint"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Menu(String(localized: "konclui.add")) {
                    ForEach(groups.indices, id: \.self) { i in
                        if let title = groups[i].title {
                            Section(title) { buttons(groups[i].items) }
                        } else {
                            buttons(groups[i].items)
                        }
                    }
                }
                .fixedSize()
            }
        }
    }

    @ViewBuilder private func buttons(_ items: [Item]) -> some View {
        ForEach(items) { item in
            Button(item.title) { onPick(item.id) }
        }
    }
}
