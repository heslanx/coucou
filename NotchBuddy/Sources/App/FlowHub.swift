#if !APPSTORE
import AppKit
import Carbon
import SwiftUI

/// The pages of the Coucou window: Flow (the dictation, the Notetaker) and the notch's settings.
enum HubPage: String, CaseIterable, Identifiable {
    case dictation, notes, insights, dictionary, snippets, styles, settings
    case general, pills, agents, chat, integrations, reminders, voice, shortcuts   // Koncluí: .reminders (A1-13)

    var id: String { rawValue }

    // Koncluí: a page whose feature flag is off is not listed (KoncluiFeatureRegistry.swift).
    static var flowPages: [HubPage] {
        [.dictation, .notes, .insights, .dictionary, .snippets, .styles, .settings].filter { KoncluiFeatures.isOn($0.featureId) }
    }
    static var notchPages: [HubPage] {
        [.general, .pills, .agents, .chat, .integrations, .reminders, .voice, .shortcuts].filter { KoncluiFeatures.isOn($0.featureId) }
    }

    /// The section of Settings this page shows, for the notch's pages.
    var settingsSection: String? {
        switch self {
        case .general:      return "general"
        case .pills:        return "activepills"
        case .agents:       return "agents"
        case .chat:         return "chat"
        case .integrations: return "integrations"
        case .reminders:    return "reminders"   // Koncluí
        case .voice:        return "voice"
        case .shortcuts:    return "shortcuts"
        default:            return nil
        }
    }

    /// The page showing a section of Settings ("chat", "voice"…).
    static func forSettings(_ section: String) -> HubPage {
        notchPages.first { $0.settingsSection == section } ?? .general
    }

    var title: String {
        switch self {
        case .general:      return String(localized: "General")
        case .pills:        return String(localized: "Active pills")
        case .agents:       return String(localized: "Agents")
        case .chat:         return String(localized: "Chat")
        case .integrations: return String(localized: "Integrations")
        case .reminders:    return String(localized: "Reminders")   // Koncluí
        case .voice:        return String(localized: "Voice")
        case .shortcuts:    return String(localized: "Shortcuts")
        case .dictation:  return String(localized: "hub.page.dictation")
        case .notes:      return String(localized: "hub.page.notes")
        case .insights:   return String(localized: "hub.page.insights")
        case .dictionary: return String(localized: "hub.page.dictionary")
        case .snippets:   return String(localized: "hub.page.snippets")
        case .styles:     return String(localized: "hub.page.styles")
        case .settings:   return String(localized: "hub.page.settings")
        }
    }

    var symbol: String {
        switch self {
        case .dictation:  return "mic"
        case .notes:      return "record.circle"
        case .insights:   return "chart.bar"
        case .dictionary: return "book.closed"
        case .snippets:   return "bolt"
        case .styles:     return "textformat"
        case .settings:   return "slider.horizontal.3"
        case .general:      return "gearshape"
        case .pills:        return "square.grid.2x2"
        case .agents:       return "terminal"
        case .chat:         return "bubble.left.and.bubble.right"
        case .integrations: return "puzzlepiece.extension"
        case .reminders:    return "bell.badge"   // Koncluí
        case .voice:        return "waveform"
        case .shortcuts:    return "keyboard"
        }
    }
}

/// The colors of the Coucou Flow window: the island's dark, with Coucou's orange.
/// Koncluí: the design system's navy family with mint (KoncluiPalette, docs/konclui/UX.md 11.1); the window itself is
/// KoncluiBrandBackdrop, the Painel Gestor's sidebar gradient.
enum HubTheme {
    /// OLED black: the window and the sidebar.
    static let window = KoncluiTheme.canvas
    static let sidebar = Color.clear   // Koncluí: the window's gradient shows through
    /// The big card on the right, where the pages are.
    static let panel = KoncluiTheme.panel
    static let card = KoncluiTheme.card
    static let field = KoncluiTheme.field
    static let line = Color.white.opacity(0.07)
    static let text = KoncluiTheme.textPrimary
    static let body = KoncluiTheme.textBody
    static let secondary = KoncluiTheme.textSecondary
    static let muted = KoncluiTheme.textTertiary   // Koncluí: was #6B7079, 3.5:1 on a card; 4.5:1 now
    static let accent = KoncluiTheme.accent
    static let onAccent = KoncluiTheme.onAccent
    static let green = KoncluiTheme.ok
    static let red = KoncluiTheme.error
    /// One color per person in a call: you first, then the others.
    static let speakers: [Color] = ["#3B9EFF", "#34D399", "#A78BFA", "#F7B32B", "#F472B6", "#22D3EE"].map { Color(hex: $0) }

    static func speaker(_ index: Int) -> Color { speakers[max(0, index) % speakers.count] }
}

private struct HubPageKey: EnvironmentKey {
    static let defaultValue: HubPage = .dictation
}

extension EnvironmentValues {
    /// The page shown, for the colour and the Mochis of its top band.
    var hubPage: HubPage {
        get { self[HubPageKey.self] }
        set { self[HubPageKey.self] = newValue }
    }
}

extension HubPage {
    /// The line under the title of the notch's pages.
    static func notchSubtitle(_ page: HubPage) -> String? {
        switch page {
        case .general:      return String(localized: "hub.notch.general")
        case .pills:        return String(localized: "hub.notch.pills")
        case .agents:       return String(localized: "hub.notch.agents")
        case .chat:         return String(localized: "hub.notch.chat")
        case .integrations: return String(localized: "hub.notch.integrations")
        case .reminders:    return String(localized: "hub.notch.reminders")   // Koncluí
        case .voice:        return String(localized: "hub.notch.voice")
        case .shortcuts:    return String(localized: "hub.notch.shortcuts")
        default:            return nil
        }
    }
}

@MainActor
final class HubRouter: ObservableObject {
    @Published var page: HubPage = HubPage.resolved(.dictation) {
        // Koncluí: any pick leaves the Features screen; a page whose flag is off falls back to the first one that is on.
        didSet {
            showFeatures = false
            let shown = HubPage.resolved(page)
            if shown != page { page = shown }
        }
    }
    /// Koncluí: the hidden Features screen (KoncluiFeaturesPage) is shown instead of `page`.
    @Published var showFeatures = false

    init() {
        #if DEBUG
        // Koncluí: `-konclui.debug.page <HubPage rawValue>` opens the window on that page, for screenshots.
        if let raw = UserDefaults.standard.string(forKey: "konclui.debug.page"), let debugPage = HubPage(rawValue: raw) {
            page = HubPage.resolved(debugPage)
        }
        #endif
    }
}

/// Opens the Coucou Flow window: the history of the dictations, the Notetaker, the numbers, the
/// dictionary, the snippets, the styles and the settings of the dictation.
@MainActor
final class FlowHubController {
    static let shared = FlowHubController()
    let router = HubRouter()
    let windowState = HubWindowState()
    private var window: NSWindow?

    static let showInDockKey = "coucouShowInDock"
    static let openAtLaunchKey = "coucouOpenAtLaunch"

    /// Coucou in the Dock, like a regular app (on by default in the GitHub build).
    static var showInDock: Bool {
        get { UserDefaults.standard.object(forKey: showInDockKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: showInDockKey)
            NSApp.setActivationPolicy(newValue ? .regular : .accessory)
            if newValue { NSApp.activate(ignoringOtherApps: true) }
        }
    }

    /// The window opens when Coucou is opened by hand (never at login).
    static var openAtLaunch: Bool {
        get { UserDefaults.standard.object(forKey: openAtLaunchKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: openAtLaunchKey) }
    }

    /// Whether macOS opened Coucou at login, rather than you from the Finder, the Dock or Spotlight.
    static func launchedAtLogin() -> Bool {
        if let event = NSAppleEventManager.shared().currentAppleEvent,
           event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue == OSType(keyAELaunchedAsLogInItem) {
            return true
        }
        // A login item started by launchd may come without that flag: the first minutes after
        // the Mac starts count as a login.
        return ProcessInfo.processInfo.systemUptime < 180
    }

    func show(_ page: HubPage? = nil) {
        if let page { router.page = page }
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
                           styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                           backing: .buffered, defer: false)
        win.title = "Koncluí"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.appearance = NSAppearance(named: .darkAqua)
        win.backgroundColor = .black
        win.contentView = NSHostingView(rootView: FlowHubView(router: router, windowState: windowState))
        windowState.watch(win)
        win.contentMinSize = NSSize(width: 940, height: 600)
        win.isReleasedWhenClosed = false
        win.setFrameAutosaveName("CoucouFlowWindow")
        if !win.setFrameUsingName("CoucouFlowWindow") { win.center() }
        window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct FlowHubView: View {
    @ObservedObject var router: HubRouter
    @ObservedObject var windowState: HubWindowState
    // Koncluí: the window draws again when a flag changes, and shows the Features screen once unlocked.
    @ObservedObject private var features = KoncluiFeatureModel.shared
    @AppStorage(KoncluiFeatures.unlockedKey) private var featuresUnlocked = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion   // Koncluí

    var body: some View {
        HStack(spacing: 0) {
            HubSidebar(router: router)
            // The pages sit in one big card, like Wispr Flow's window.
            page
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(HubTheme.panel)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(0.07)))
                .padding(.top, 10)
                .padding(.bottom, 10)
                .padding(.trailing, 10)
        }
        .background(KoncluiBrandBackdrop())   // Koncluí: the Painel Gestor's sidebar gradient, under the sidebar and around the panel
        .foregroundColor(HubTheme.text)
        .preferredColorScheme(.dark)
        .tint(HubTheme.accent)
        .disclosureGroupStyle(KoncluiDisclosureStyle())   // Koncluí: a disclosure opens from its whole label.
        .koncluiTheme()   // Koncluí: GroupBox, Toggle and `.koncluiPrimary` buttons take the hub's look (KoncluiTheme.swift).
        .environment(\.hubVisible, windowState.visible)
        .environment(\.koncluiMotion, KoncluiMotion.rate(visible: windowState.visible, key: windowState.key, reduceMotion: reduceMotion))   // Koncluí
        .environment(\.hubPage, router.showFeatures ? .settings : router.page)
        .onChange(of: featuresUnlocked) { _, unlocked in if !unlocked { router.showFeatures = false } }
    }

    @ViewBuilder private var page: some View {
        // Koncluí: the hidden Features screen takes the page's place.
        if router.showFeatures && featuresUnlocked {
            KoncluiFeaturesPage()
        } else {
            hubPage
        }
    }

    @ViewBuilder private var hubPage: some View {
        switch router.page {
        case .dictation:  HubHomePage(router: router)
        case .notes:      HubNotesPage()
        case .insights:   HubInsightsPage()
        case .dictionary: HubDictionaryPage()
        case .snippets:   HubSnippetsPage()
        case .styles:     HubStylesPage(router: router)
        case .settings:   HubSettingsPage()
        default:
            if let section = router.page.settingsSection {
                // Koncluí: the compact header is pinned over SettingsView's own scroll as a bar (KoncluiSettingsPage.swift).
                KoncluiSettingsPage(page: router.page, section: section)
            }
        }
    }
}

// MARK: - Sidebar

private struct HubSidebar: View {
    @ObservedObject var router: HubRouter
    @ObservedObject private var flow = FlowDictation.shared
    // Koncluí: the sidebar lists only the pages that are on; ⌥-click the wordmark unlocks the Features screen.
    @ObservedObject private var features = KoncluiFeatureModel.shared
    @AppStorage(KoncluiFeatures.unlockedKey) private var featuresUnlocked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 10) {
                // The scene draws Mochi a little below its middle (room for his
                // hops and hats): lifted so his body lines up with the name.
                HubLiveMochi(size: 28)
                    .offset(y: -4)
                Image("KoncluiLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 16)
                    .accessibilityLabel(Text(verbatim: "Koncluí"))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Koncluí: ⌥-click toggles the hidden Features screen.
                        guard NSEvent.modifierFlags.contains(.option) else { return }
                        featuresUnlocked.toggle()
                        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                    }
            }
            .padding(.horizontal, 8)
            // Halfway between the window's buttons and "FLOW".
            .padding(.top, 25)
            .padding(.bottom, 31)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    HubSidebarHeader(text: String(localized: "konclui.hub.section.flow"))
                    ForEach(HubPage.flowPages) { page in
                        HubSidebarItem(page: page, selected: router.page == page && !router.showFeatures) { router.page = page }
                    }
                    HubSidebarHeader(text: String(localized: "hub.section.notch"))
                        .padding(.top, 14)
                    ForEach(HubPage.notchPages) { page in
                        HubSidebarItem(page: page, selected: router.page == page && !router.showFeatures) { router.page = page }
                    }
                    if featuresUnlocked {
                        KoncluiFeaturesSidebarItem(selected: router.showFeatures) { router.showFeatures = true }
                            .padding(.top, 14)
                    }
                }
            }
            .scrollIndicators(.never)
            status
                .padding(.top, 8)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
        .frame(width: 228)
        .frame(maxHeight: .infinity)
        .background(HubTheme.sidebar)
        // Koncluí: remember that macOS once trusted Koncluí for Accessibility (KoncluiAccessibilityMemory), A3-24.
        .onAppear { KoncluiAccessibilityMemory.note(trusted: flow.trusted) }
        .onChange(of: flow.trusted) { _, now in KoncluiAccessibilityMemory.note(trusted: now) }
    }

    // Koncluí: the status is a door with a popover (KoncluiDictationDoor.swift), not a label that only jumped to Ajustes.
    @ViewBuilder private var status: some View {
        KoncluiDictationStatus(router: router)
    }
}

/// "FLOW", "NOTCH": the small capitals above a group of pages.
private struct HubSidebarHeader: View {
    let text: String

    var body: some View {
        Text(text.uppercased(with: .current))
            .koncluiType(.label)   // Koncluí: 11 pt minimum
            .foregroundColor(HubTheme.muted)
            .padding(.horizontal, 10)
            .padding(.bottom, 4)
    }
}

private struct HubSidebarItem: View {
    let page: HubPage
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: page.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selected ? KoncluiTheme.accent : KoncluiTheme.textBody)   // Koncluí: the platform's mint icon
                    .frame(width: 20)
                Text(page.title)
                    .font(.system(size: 14, weight: selected ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .foregroundColor(selected ? HubTheme.text : KoncluiTheme.textBody)
            .padding(.horizontal, 10)
            .frame(height: 32)
            // Koncluí: the selected page as on the platform's sidebar, a mint wash (rgba(83, 255, 200, 0.12))
            .background(RoundedRectangle(cornerRadius: 9)
                .fill(selected ? KoncluiTheme.accent.opacity(0.12) : Color.white.opacity(hover ? 0.06 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .koncluiPointer()   // Koncluí
    }
}

// MARK: - Shared pieces

/// Mochi as a small logo: the white body and its two eyes.
struct HubMochi: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.33, style: .continuous)
                .fill(LinearGradient(colors: [.white, Color(hex: "#C9CBD1")], startPoint: .top, endPoint: .bottom))
            HStack(spacing: size * 0.2) {
                Capsule().fill(Color(hex: "#1A1412")).frame(width: size * 0.11, height: size * 0.22)
                Capsule().fill(Color(hex: "#1A1412")).frame(width: size * 0.11, height: size * 0.22)
            }
        }
        .frame(width: size, height: size * 0.72)
    }
}

/// A page: its title, an optional line under it, and the content, scrolling.
struct HubPageScaffold<Trailing: View, Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    @Environment(\.hubPage) private var page

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KoncluiSpace.sectionGap) {
                HubHero(page: page, title: title, subtitle: subtitle, trailing: trailing)
                content()
            }
            .padding(.horizontal, KoncluiSpace.gutter)
            .padding(.top, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: 1100, alignment: .leading)
        }
        .scrollIndicators(.automatic)
    }
}

extension HubPageScaffold where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = { EmptyView() }
        self.content = content
    }
}

/// A dark rounded card.
struct HubCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content
    @Environment(\.colorSchemeContrast) private var contrast   // Koncluí

    var body: some View {
        VStack(alignment: .leading, spacing: KoncluiSpace.rowGap) { content() }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: KoncluiRadius.card, style: .continuous).fill(HubTheme.card))
            .overlay(RoundedRectangle(cornerRadius: KoncluiRadius.card, style: .continuous).strokeBorder(KoncluiTheme.hairline(contrast)))
    }
}

/// "AUJOURD'HUI": the small capitals above a list.
struct HubLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    @Environment(\.colorSchemeContrast) private var contrast   // Koncluí

    var body: some View {
        Text(text.uppercased(with: .current))
            .koncluiType(.label)   // Koncluí: the label role, the same as a GroupBox title on the notch pages
            .foregroundColor(contrast == .increased ? KoncluiTheme.textSecondary : HubTheme.muted)
    }
}

/// A row of a settings card: the label on the left, the control on the right.
struct HubRow<Control: View>: View {
    let title: String
    var detail: String? = nil
    @ViewBuilder var control: () -> Control
    @Environment(\.colorSchemeContrast) private var contrast   // Koncluí

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).koncluiType(.bodyStrong)
                if let detail {
                    Text(detail)
                        .koncluiType(.detail)
                        .foregroundColor(KoncluiTheme.secondary(contrast))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            control()
        }
        .padding(.vertical, 2)
    }
}

struct HubDivider: View {
    @Environment(\.colorSchemeContrast) private var contrast   // Koncluí
    var body: some View { Rectangle().fill(KoncluiTheme.hairline(contrast)).frame(height: 1) }
}

/// Orange (primary) or dark (secondary) button.
struct HubButtonStyle: ButtonStyle {
    var primary = false

    func makeBody(configuration: Configuration) -> some View {
        // Koncluí: one look for every hub button, with a disabled state that never reads as an enabled primary.
        KoncluiButtonLook(configuration: configuration, kind: primary ? .primary : .secondary)
    }
}

/// A small square icon button (copy, delete).
struct HubIconButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(hover ? HubTheme.text : KoncluiTheme.textSecondary)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous).fill(Color.white.opacity(hover ? 0.1 : 0.05)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .koncluiPointer()   // Koncluí
        .help(help)
        .accessibilityLabel(help)
        .onHover { hover = $0 }
    }
}

/// A text field drawn like the rest of the window.
struct HubField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: () -> Void = {}
    /// Koncluí: a label above (it stays while typing) and a line below that says what is missing.
    var label: String? = nil
    var hint: String? = nil

    var body: some View {
        KoncluiField(label: label, placeholder: placeholder, text: $text, hint: hint, onSubmit: onSubmit)   // Koncluí
    }
}

/// Lays its children out in rows, wrapping to the next row when one is full (the dictionary's words).
struct HubWrap: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

extension NSPasteboard {
    /// Copies plain text, as the copy buttons of the window do.
    @MainActor static func copyText(_ text: String) {
        general.clearContents()
        general.setString(text, forType: .string)
    }
}
#endif
