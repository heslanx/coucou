import SwiftUI
import ServiceManagement
import AppKit

struct SettingsView: View {
    @ObservedObject private var state = AppState.shared
    @ObservedObject private var demoEngine = DemoEngine.shared
    @State private var apiKey: String = KeychainStore.shared.get("anthropic-api-key") ?? ""

    // Claude model — dynamic list fetched from the API, static fallback if unavailable
    private static let fallbackModels: [(id: String, label: String)] = [
        ("claude-sonnet-4-6",         "Claude Sonnet 4.6"),
        ("claude-sonnet-5-5",         "Claude Sonnet 5.5"),
        ("claude-opus-5-5",           "Claude Opus 5.5"),
        ("claude-haiku-4-5-20251001", "Claude Haiku 4.5"),
    ]
    private static let customModelTag = "__custom__"
    @State private var fetchedModels: [(id: String, label: String)] = []
    @State private var modelChoice: String = {
        let m = AppState.shared.claudeModel
        return SettingsView.fallbackModels.contains { $0.id == m } ? m : SettingsView.customModelTag
    }()
    @State private var customModel: String = {
        let m = AppState.shared.claudeModel
        return SettingsView.fallbackModels.contains { $0.id == m } ? "" : m
    }()
    private var displayModels: [(id: String, label: String)] {
        fetchedModels.isEmpty ? Self.fallbackModels : fetchedModels
    }
    @State private var launchAtStartup: Bool = (SMAppService.mainApp.status == .enabled)
    @State private var statusMessage: String = ""
    @State private var showDiff: Bool = false
    @State private var pendingHookJSON: String = ""
    // Koncluí: what Koncluí wrote in the agents' files comes from KoncluiHookStatus (read off the main thread), not from the files
    // at every redraw; these start from its last answer and follow it (`koncluiApplyHooks`).
    @State private var hookNeedsUpdate: Bool = KoncluiHookStatus.shared.snapshot.claudeOutdated
    @State private var claudeHooksInstalled: Bool = KoncluiHookStatus.shared.snapshot.isInstalled(.claudeCode)
    @State private var claudePendingInstall: Bool = true

    #if !APPSTORE
    @State private var showStatusLineDiff: Bool = false
    @State private var pendingStatusLineJSON: String = ""
    @State private var statusLinePendingInstall: Bool = true
    @State private var planTogglePending: Bool = false

    @State private var geminiHooksInstalled: Bool = KoncluiHookStatus.shared.snapshot.isInstalled(.gemini)
    @State private var showGeminiDiff: Bool = false
    @State private var pendingGeminiJSON: String = ""
    @State private var geminiPendingInstall: Bool = true

    @State private var agyHooksInstalled: Bool = KoncluiHookStatus.shared.snapshot.isInstalled(.antigravity)
    @State private var showAgyDiff: Bool = false
    @State private var pendingAgyJSON: String = ""
    @State private var agyPendingInstall: Bool = true

    @State private var codexHooksInstalled: Bool = KoncluiHookStatus.shared.snapshot.isInstalled(.codex)
    @State private var showCodexDiff: Bool = false
    @State private var pendingCodexJSON: String = ""
    @State private var codexPendingInstall: Bool = true

    @State private var copilotHooksInstalled: Bool = KoncluiHookStatus.shared.snapshot.isInstalled(.copilot)
    @State private var showCopilotDiff: Bool = false
    @State private var pendingCopilotJSON: String = ""
    @State private var copilotPendingInstall: Bool = true

    @State private var museHooksInstalled: Bool = KoncluiHookStatus.shared.snapshot.isInstalled(.muse)
    @State private var showMuseDiff: Bool = false
    @State private var pendingMuseJSON: String = ""
    @State private var musePendingInstall: Bool = true

    @State private var openCodePluginInstalled: Bool = KoncluiHookStatus.shared.snapshot.isInstalled(.opencode)
    @State private var showOpenCodeDiff: Bool = false
    @State private var pendingOpenCodeContent: String = ""
    @State private var openCodePendingInstall: Bool = true

    @State private var ampPluginInstalled: Bool = KoncluiHookStatus.shared.snapshot.isInstalled(.amp)
    @State private var showAmpDiff: Bool = false
    @State private var pendingAmpContent: String = ""
    @State private var ampPendingInstall: Bool = true

    @State private var hermesPluginInstalled: Bool = KoncluiHookStatus.shared.snapshot.isInstalled(.hermes)
    @State private var showHermesPluginDiff: Bool = false
    @State private var pendingHermesPluginContent: String = ""
    @State private var hermesPluginPendingInstall: Bool = true

    @State private var showHermesConfigDiff: Bool = false
    @State private var pendingHermesConfigContent: String = ""
    @AppStorage("hermesApprovalsEnabled") private var hermesApprovalsEnabled: Bool = false
    @State private var hermesSupportsApprovals: Bool = false
    #endif

    // Multi-provider chat keys
    @State private var googleKey: String   = KeychainStore.shared.get("google-api-key") ?? ""
    @State private var openAIKey: String   = KeychainStore.shared.get("openai-api-key") ?? ""
    @State private var deepseekKey: String = KeychainStore.shared.get("deepseek-api-key") ?? ""
    @State private var qwenKey: String     = KeychainStore.shared.get("qwen-api-key") ?? ""
    @State private var moonshotKey: String = KeychainStore.shared.get("moonshot-api-key") ?? ""
    @State private var ollamaURL:    String = AppState.shared.ollamaServerURL
    @State private var lmstudioURL:  String = AppState.shared.lmstudioServerURL
    @State private var connectingOllama:    Bool = false
    @State private var connectingLMStudio:  Bool = false

    // Integration keys
    @State private var resendKey: String    = KeychainStore.shared.get("resend-api-key")  ?? ""
    @State private var resendFrom: String   = KeychainStore.shared.get("resend-from")     ?? ""
    @State private var n8nUrl: String       = KeychainStore.shared.get("n8n-url")         ?? ""
    @State private var n8nKey: String       = KeychainStore.shared.get("n8n-api-key")     ?? ""
    @State private var vercelToken: String  = KeychainStore.shared.get("vercel-token")    ?? ""
    @State private var githubToken: String  = KeychainStore.shared.get("github-token")    ?? ""
    @State private var stripeKey: String    = KeychainStore.shared.get("stripe-api-key")  ?? ""
    @State private var calcomKey: String    = KeychainStore.shared.get("calcom-api-key")  ?? ""
    @State private var notionKey: String    = KeychainStore.shared.get("notion-api-key")  ?? ""
    @AppStorage(CryptoSettings.exchangeKey)     private var cryptoExchange = CryptoExchange.coinbase.rawValue
    @AppStorage(CryptoSettings.currencyKey)     private var cryptoCurrency = "EUR"
    @AppStorage(CryptoSettings.coinsKey)        private var cryptoCoins = CryptoSettings.defaultCoins
    @AppStorage(CryptoSettings.alertKey)        private var cryptoAlert = false
    @AppStorage(CryptoSettings.alertPercentKey) private var cryptoAlertPercent = 5.0

    // Hotkey
    @State private var hotkeyFlags: UInt    = AppState.shared.hotkeyFlags
    @State private var hotkeyCode: UInt16   = AppState.shared.hotkeyCode

    // Vercel project filter
    @State private var vercelProjects: [String] = []
    @State private var loadingVercel: Bool = false

    // n8n workflow filter
    @State private var n8nWorkflows: [String] = []
    @State private var loadingN8n: Bool = false

    // Bindings in minutes for the absence field
    private var absenceMinutes: Binding<Double> {
        Binding(
            get: { state.absenceInterval / 60 },
            set: { state.absenceInterval = max(1, $0) * 60 }
        )
    }

    // Connected screens for the Display picker, refreshed when screens change
    @State private var connectedScreens: [(uuid: String, name: String)] = []

    // Sidebar selection persisted across sessions
    @AppStorage("settingsSection") private var selectedSection: String = "general"
    /// Shown inside the Coucou Flow window (GitHub build): one section, without this window's
    /// sidebar, as the window has its own.
    private var embeddedSection: String? = nil
    private var section: String {
        let chosen = embeddedSection ?? selectedSection
        // Koncluí: a section whose feature is off falls back to General.
        if let id = KoncluiFeatureRegistry.sectionFeatureId(chosen), !KoncluiFeatures.isOn(id) { return "general" }
        return chosen
    }
    // Active pills: the pill whose colour palette is open, if any
    @State private var colorPalettePill: String? = nil
    // Koncluí: Active pills, Agents, Chat and Integrations list what was recognized on this Mac, and what was added
    // with "Add…" (KoncluiRecognition.swift); a flag that is off hides a block (KoncluiFeatureRegistry.swift).
    @ObservedObject private var koncluiFeatures = KoncluiFeatureModel.shared
    @ObservedObject private var koncluiAdded = KoncluiAddedModel.shared
    @ObservedObject private var chatAccess = ChatAccess.shared
    @ObservedObject private var koncluiHooks = KoncluiHookStatus.shared
    @State private var koncluiTools: Set<KoncluiTool> = KoncluiHookStatus.shared.loaded
        ? KoncluiHookStatus.shared.snapshot.tools : KoncluiRecognition.liveTools()
    // Koncluí: the tab whose "4 tabs is the limit" popover is open (Active pills).
    @State private var koncluiLimitPill: String? = KoncluiPageDebug.limitPill
    // Koncluí: the agent whose options popover is open (Agents) and the pill whose "not installed" door is open (Active pills).
    @State private var koncluiOpenAgent: String? = KoncluiAgentsDebug.target?.id
    @State private var koncluiDoorPill: String? = KoncluiAgentsDebug.doorPill
    #if PHONE_LINK
    @AppStorage("iPhoneSyncEnabled") private var iPhoneSyncEnabled = false
    @AppStorage("iPhoneLiveActivityEnabled") private var iPhoneLiveActivityEnabled = false
    @AppStorage("iPhoneInstructionsEnabled") private var iPhoneInstructionsEnabled = false
    #endif
    @AppStorage(ClaudeHost.terminalCardsKey) private var terminalCardsEnabled = false
    @State private var customSoundCount = SoundEngine.shared.customized.count

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            if embeddedSection == nil {
            // Sidebar — 200 pt, sidebar visual effect background
            ZStack(alignment: .topLeading) {
                SidebarBackground()
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack(alignment: .center, spacing: 10) {
                        Image(nsImage: NSApplication.shared.applicationIconImage)
                            .resizable()
                            .frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Koncluí")
                                .font(.system(size: 13, weight: .semibold))
                            Text(appVersion)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 10)
                    Divider()
                    List(selection: Binding(
                        get: { Optional(selectedSection) },
                        set: { if let v = $0 { selectedSection = v; statusMessage = "" } }
                    )) {
                        // Koncluí: each row shows only while its feature is on.
                        SettingsSidebarRow(title: "General",      icon: "gearshape.fill",                    color: "#8E939C").tag("general")
                            .koncluiShown(KoncluiFeatures.isOn("page_general"))
                        SettingsSidebarRow(title: "Active pills", icon: "square.grid.2x2.fill",              color: "#F5A524").tag("activepills")
                            .koncluiShown(KoncluiFeatures.isOn("page_pills"))
                        SettingsSidebarRow(title: "Agents",       icon: "terminal.fill",                     color: "#3B9EFF").tag("agents")
                            .koncluiShown(KoncluiFeatures.isOn("page_agents"))
                        SettingsSidebarRow(title: "Chat",         icon: "bubble.left.and.bubble.right.fill", color: "#E07950").tag("chat")
                            .koncluiShown(KoncluiFeatures.isOn("page_chat"))
                        SettingsSidebarRow(title: "Integrations", icon: "puzzlepiece.extension.fill",        color: "#7C5CFF").tag("integrations")
                            .koncluiShown(KoncluiFeatures.isOn("page_integrations"))
                        SettingsSidebarRow(title: "Reminders",    icon: "bell.badge.fill",                   color: "#F59E0B").tag("reminders")
                            .koncluiShown(KoncluiFeatures.isOn("block_reminders"))
                        #if !APPSTORE
                        SettingsSidebarRow(title: "Voice",        icon: "mic.fill",                          color: "#F97316").tag("voice")
                            .koncluiShown(KoncluiFeatures.isOn("page_voice"))
                        #endif
                        SettingsSidebarRow(title: "Shortcuts",    icon: "keyboard.fill",                     color: "#6366F1").tag("shortcuts")
                            .koncluiShown(KoncluiFeatures.isOn("page_shortcuts"))
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(width: 200)

            Divider()
            }

            // Detail panel
            VStack(alignment: .leading, spacing: 0) {
                if embeddedSection == nil {
                    Text(sectionTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 12)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        sectionContent
                    }
                    .padding(.horizontal, embeddedSection == nil ? 20 : 28)
                    .padding(.top, embeddedSection == nil ? 0 : 20)
                    .padding(.bottom, 16)
                    .frame(maxWidth: embeddedSection == nil ? .infinity : 1100, alignment: .leading)
                }
                if !statusMessage.isEmpty && !koncluiPopoverOpen {   // Koncluí: an open popover shows the message itself
                    Divider()
                    Text(statusMessage)
                        .font(.system(size: 12))
                        .foregroundColor(statusMessage.hasPrefix("❌") ? .red : .secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                }
            }
        }
        .onChange(of: koncluiHooks.snapshot) { _, snap in koncluiApplyHooks(snap) }
        .onChange(of: koncluiInstalledFlags) { _, _ in koncluiHooks.refresh() }
        .onAppear {
            #if !APPSTORE
            state.refreshPlanRelayState()
            #endif
            // Koncluí: look again at what this Mac has (off the main thread; `onChange` below applies the answer), and at the sign-ins.
            koncluiHooks.refresh()
            koncluiDebugPreview()   // Koncluí: DEBUG only, `-konclui.debug.agentPopover <id>:preview`
            Task { await chatAccess.refresh() }
            guard fetchedModels.isEmpty,
                  let key = KeychainStore.shared.get("anthropic-api-key"), !key.isEmpty else { return }
            Task {
                let models = await ClaudeService.fetchModels(apiKey: key)
                guard !models.isEmpty else { return }
                await MainActor.run {
                    fetchedModels = models
                    let m = state.claudeModel
                    if models.contains(where: { $0.id == m }) {
                        modelChoice = m
                        customModel = ""
                    } else if modelChoice != Self.customModelTag {
                        modelChoice = Self.customModelTag
                        customModel = m
                    }
                }
            }
        }
    }

    // MARK: - Section routing

    private var sectionTitle: String {
        switch section {
        case "general":      return String(localized: "General")
        case "activepills":  return String(localized: "Active pills")
        case "agents":       return String(localized: "Agents")
        case "chat":         return String(localized: "Chat")
        case "integrations": return String(localized: "Integrations")
        case "reminders":    return String(localized: "Reminders")
        case "voice":        return String(localized: "Voice")
        case "shortcuts":    return String(localized: "Shortcuts")
        default:             return String(localized: "General")
        }
    }

    @ViewBuilder private var sectionContent: some View {
        switch section {
        case "activepills":  activePillsSection
        case "agents":       agentsSection
        case "chat":         chatSection
        case "integrations": integrationsSection
        case "reminders":    RemindersSettingsSection()
        #if !APPSTORE
        case "voice":        voiceSection
        #endif
        case "shortcuts":    ShortcutsSettingsView()
        default:             generalSection
        }
    }

    // MARK: - General section

    @ViewBuilder private var generalSection: some View {
        // Koncluí: agents found on this Mac and not connected yet: one calm card, first (KoncluiConnectAgentsCard.swift).
        #if !APPSTORE
        KoncluiConnectAgentsCard(waiting: koncluiWaitingAgents, openAgents: koncluiOpenAgentsPage)
            .koncluiShown((koncluiHooks.loaded || KoncluiPageDebug.waiting != nil) && KoncluiGeneralPage.showsConnectCard(waiting: koncluiWaitingAgents))
        #endif
        // Koncluí: the demo is a first-run tool: first while nothing is connected, at the end (as a quiet button) after.
        demoBox(quiet: false)
            .koncluiShown(koncluiHooks.loaded && !KoncluiGeneralPage.demoComesLast(anyAgentConnected: koncluiAnyAgentConnected))

        GroupBox("Sound") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Enable sounds", isOn: $state.soundEnabled)
                HStack(spacing: 8) {
                    Text("Volume")
                        .frame(width: 56, alignment: .leading)
                    Slider(value: $state.soundVolume, in: 0...0.2)
                        .disabled(!state.soundEnabled)
                    Text("\(Int(state.soundVolume / 0.2 * 100)) %")
                        .frame(width: 36, alignment: .trailing)
                        .monospacedDigit()
                }
                HStack(spacing: 8) {
                    Button("Open sounds folder") { SoundEngine.shared.revealCustomFolder() }
                    Button("Reload sounds") {
                        SoundEngine.shared.reload()
                        customSoundCount = SoundEngine.shared.customized.count
                        SoundEngine.shared.play("pop")
                    }
                    if customSoundCount > 0 {
                        Text(String(format: String(localized: "%lld custom"), Int64(customSoundCount)))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(!state.soundEnabled)
                Text("Drop a file named like one of Koru's sounds (finish.wav, approval.mp3, greet.m4a…) in the sounds folder to replace it, then Reload.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(6)
        }

        GroupBox("Behavior") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Open on hover", isOn: $state.openOnHover)
                    .help("Hovering the island opens it; it folds again shortly after the pointer leaves. Click inside to keep it open.")
                Toggle(String(localized: "alerts.all-pills"), isOn: $state.alertsFromAllPills)
                    .help(String(localized: "alerts.all-pills.help"))
                HStack(spacing: 8) {
                    Text("Close after")
                    TextField("60", value: $state.autoCloseInterval, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 64)
                    Text("s inactive")
                }
                HStack(spacing: 8) {
                    Text("Hide after")
                    TextField("3", value: absenceMinutes, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 48)
                    Text("min without movement")
                }
            }
            .padding(6)
        }

        GroupBox("Display") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Show Koru on", selection: $state.islandDisplay) {
                    Text("Screen with the notch").tag(IslandDisplayChoice.notch)
                    Text("Main screen (menu bar)").tag(IslandDisplayChoice.menuBar)
                    Text("Follow the mouse").tag(IslandDisplayChoice.followMouse)
                    Divider()
                    ForEach(connectedScreens, id: \.uuid) { screen in
                        Text(screen.name).tag(IslandDisplayChoice.display(uuid: screen.uuid))
                    }
                    if case .display(let uuid) = state.islandDisplay,
                       !connectedScreens.contains(where: { $0.uuid == uuid }) {
                        Text("Saved screen (not connected)").tag(state.islandDisplay)
                    }
                }
                .frame(maxWidth: 360)
                Text("On a screen without a notch, Koru sits in a small bar at the top. Follow the mouse moves it to your cursor's screen while it is closed.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(6)
            .onAppear { refreshConnectedScreens() }
            .onReceive(NotificationCenter.default.publisher(
                for: NSApplication.didChangeScreenParametersNotification)) { _ in
                refreshConnectedScreens()
            }
        }

        GroupBox(String(localized: "vitals.title")) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(String(localized: "vitals.toggle"), isOn: Binding(
                    get: { MachineVitals.shared.enabled },
                    set: { MachineVitals.shared.enabled = $0 }))
                Text("vitals.about")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(6)
        }
        .koncluiShown(KoncluiFeatures.isOn("block_vitals"))

        GroupBox("Hotkey") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Show island with shortcut", isOn: $state.hotkeyEnabled)
                    .onChange(of: state.hotkeyEnabled) { _, _ in
                        HotKeyCenter.shared.reregister(.toggleIsland)
                    }
                if state.hotkeyEnabled {
                    HStack(spacing: 8) {
                        Text("Shortcut")
                            .frame(width: 70, alignment: .leading)
                        ShortcutRecorderButton(flags: $hotkeyFlags, code: $hotkeyCode)
                            .onChange(of: hotkeyFlags) { _, v in
                                state.hotkeyFlags = v
                                HotKeyCenter.shared.reregister(.toggleIsland)
                            }
                            .onChange(of: hotkeyCode) { _, v in
                                state.hotkeyCode = v
                                HotKeyCenter.shared.reregister(.toggleIsland)
                            }
                        Text("presses this → island opens")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(6)
        }
        .koncluiShown(embeddedSection == nil)   // Koncluí: in the hub window the Shortcuts page owns this switch (one switch, one place)

        GroupBox("Startup") {
            Toggle("Launch at Mac startup", isOn: $launchAtStartup)
                .onChange(of: launchAtStartup) { _, on in toggleStartup(on) }
                .padding(6)
        }

        #if !APPSTORE
        UpdateSettingsSection()
            .koncluiShown(KoncluiFeatures.isOn("block_updates"))   // Koncluí: ships off, the updater cannot install Koncluí yet (KONCLUI.md)
        #endif

        GroupBox(String(localized: "Weekly recap")) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(String(localized: "Keep a history of my coding sessions"), isOn: $state.recapEnabled)
                Text(String(localized: "Stored locally on your Mac. Nothing leaves your Mac. Retained for 12 weeks."))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle(String(localized: "Hide project names in shared images"), isOn: $state.recapHideProjects)
                    .disabled(!state.recapEnabled)
                Button(String(localized: "Clear history")) { RecapStore.shared.clearHistory() }
            }
            .padding(6)
        }
        .koncluiShown(KoncluiFeatures.isOn("block_recap"))

        GroupBox(String(localized: "Language")) {
            VStack(alignment: .leading, spacing: 10) {
                Picker("", selection: $state.appLanguage) {
                    Text(String(localized: "System")).tag("")
                    Text("English").tag("en")
                    Text("简体中文").tag("zh-Hans")
                    Text("繁體中文").tag("zh-Hant")
                    Text("हिन्दी").tag("hi")
                    Text("Español").tag("es")
                    Text("العربية").tag("ar")
                    Text("Français").tag("fr")
                    Text("বাংলা").tag("bn")
                    Text("Português (Brasil)").tag("pt-BR")
                    Text("Русский").tag("ru")
                    Text("Bahasa Indonesia").tag("id")
                    Text("Deutsch").tag("de")
                    Text("Türkçe").tag("tr")
                    Text("ไทย").tag("th")
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .onChange(of: state.appLanguage) { _, code in
                    if code.isEmpty {
                        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                    } else {
                        UserDefaults.standard.set([code], forKey: "AppleLanguages")
                    }
                    UserDefaults.standard.synchronize()
                }
                HStack(spacing: 8) {
                    Button(String(localized: "Restart Koncluí")) {
                        let appPath = Bundle.main.bundleURL.path
                        let pid = ProcessInfo.processInfo.processIdentifier
                        let task = Process()
                        task.executableURL = URL(fileURLWithPath: "/bin/sh")
                        task.arguments = ["-c", "while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; open \"$1\"", "--", appPath]
                        try? task.run()
                        NSApp.terminate(nil)
                    }
                    .buttonStyle(.koncluiSecondary)
                    Text(String(localized: "Applies on next launch"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(6)
        }

        #if PHONE_LINK
        GroupBox("iPhone") {
            VStack(alignment: .leading, spacing: 6) {
                Toggle(String(localized: "iphone.sync.toggle"), isOn: $iPhoneSyncEnabled)
                    .onChange(of: iPhoneSyncEnabled) { _, on in CloudProbe.shared.setEnabled(on) }
                Text(String(localized: "iphone.sync.description"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle(String(localized: "iphone.live-activity.toggle"), isOn: $iPhoneLiveActivityEnabled)
                    .disabled(!iPhoneSyncEnabled)
                    .onChange(of: iPhoneLiveActivityEnabled) { _, on in LiveActivityRelay.shared.setEnabled(on) }
                Text(String(localized: "iphone.live-activity.description"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                #if !APPSTORE
                Toggle(String(localized: "iphone.instruction.toggle"), isOn: $iPhoneInstructionsEnabled)
                    .disabled(!iPhoneSyncEnabled)
                    .onChange(of: iPhoneInstructionsEnabled) { _, on in InstructionRunner.shared.setEnabled(on) }
                Text(String(localized: "iphone.instruction.description"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                #endif
            }
            .padding(6)
        }
        .koncluiShown(KoncluiFeatures.isOn("block_iphone"))
        #endif

        // Koncluí: an agent is connected already: the demo steps back to a quiet button here, and the way out of every
        // integration Koncluí wrote is one click away (previewed and confirmed, KoncluiRemoveIntegrations.swift).
        demoBox(quiet: true)
            .koncluiShown(koncluiHooks.loaded && KoncluiGeneralPage.demoComesLast(anyAgentConnected: koncluiAnyAgentConnected))
        #if !APPSTORE
        KoncluiRemoveIntegrations(snapshot: koncluiHooks.snapshot, done: { koncluiHooks.refresh() })
            .koncluiShown(koncluiHooks.loaded && KoncluiGeneralPage.offersRemoval(koncluiHooks.snapshot))
        #endif
    }

    /// The demo: an orange primary while nothing is connected, a plain button once an agent is.
    @ViewBuilder
    private func demoBox(quiet: Bool) -> some View {
        GroupBox(String(localized: "demo.groupbox.title")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "demo.description"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                let toggleDemo = {
                    if demoEngine.isActive { DemoEngine.shared.stop() } else { DemoEngine.shared.start() }
                }
                let title = demoEngine.isActive ? String(localized: "demo.stop") : String(localized: "demo.start")
                if quiet {
                    Button(title, action: toggleDemo)
                        .buttonStyle(.koncluiSecondary)
                } else {
                    Button(title, action: toggleDemo)
                        .buttonStyle(.koncluiPrimary)
                }
            }
            .padding(6)
        }
    }

    private func refreshConnectedScreens() {
        connectedScreens = NSScreen.screens.compactMap { screen in
            guard let uuid = IslandWindowController.displayUUID(screen) else { return nil }
            return (uuid, screen.localizedName)
        }
    }

    // MARK: - Active pills section

    @ViewBuilder private var activePillsSection: some View {
        let signals = koncluiSignals   // Koncluí: only the pills this Mac has, turned on or added are listed
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("Choose the tools you use. Koncluí only shows what you declare here.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Text(String(format: String(localized: "settings.slots-used %lld"), Int64(state.activeIntegrations.count)))
                    .font(.system(size: 11))
                    .foregroundColor(state.activeIntegrations.count >= 4 ? .orange : .secondary)

                Picker(String(localized: "settings.main-pill"), selection: $state.mainPillId) {
                    ForEach(PillCatalog.available.filter { $0.category == .workspace && !$0.comingSoon }, id: \.id) { def in
                        Text(def.name).tag(def.id)
                    }
                }
                .onChange(of: state.mainPillId) { _, newId in
                    state.setMainPill(newId)
                }

                ForEach(PillCategory.allCases, id: \.self) { cat in
                    let catPills = PillCatalog.available.filter { $0.category == cat && koncluiPillShown($0, signals) }
                    if !catPills.isEmpty {
                        Divider()
                        Text(cat.title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        ForEach(catPills, id: \.id) { def in
                            pillRow(def)
                        }
                    }
                }

            }
            .padding(6)
        }
        // Koncluí: "Add…" sits at the page's outer edge on every list (Active pills, Agents, Chat, Integrations).
        KoncluiAddMenu(
            items: PillCatalog.available.filter { !koncluiPillShown($0, signals) }
                .map { .init(id: $0.id, title: $0.name, section: $0.category.title) },
            onPick: { koncluiAdded.add(.pills, $0) })
    }

    // MARK: - Agents section

    @ViewBuilder private var agentsSection: some View {
        // Koncluí: klaude's hooks (unit K11); then only the agents this Mac has, hooked up or added.
        #if !APPSTORE
        KoncluiKlaudeHooksSection()
        #endif

        koncluiAgentRow(.claudeCode, .hooks, installed: claudeHooksInstalled, outdated: hookNeedsUpdate) {   // Koncluí: row + popover
            VStack(alignment: .leading, spacing: 10) {
                #if APPSTORE
                if hookNeedsUpdate {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(String(localized: "hooks.outdated"))
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                    Button(String(localized: "hooks.update")) { installHooksAppStore() }
                }
                Text("~/.claude/konclui/nb-hook")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                HStack(spacing: 10) {
                    Button(String(localized: "hooks.install")) { installHooksAppStore() }
                        .buttonStyle(.koncluiPrimary)
                    Button(String(localized: "hooks.uninstall")) { uninstallHooksAppStore() }
                        .buttonStyle(.koncluiSecondary)
                }
                #else
                // Koncluí: the state, the one primary it needs and the review of what changes (KoncluiHookControls.swift).
                koncluiHookControls(.claudeCode, installed: claudeHooksInstalled, outdated: hookNeedsUpdate, show: showDiff,
                                    pending: pendingHookJSON, pendingInstall: claudePendingInstall,
                                    preview: { $0 ? installHooks() : uninstallHooks() }, confirm: { confirmInstall() },
                                    cancel: { showDiff = false; pendingHookJSON = "" })
                #endif
                Divider()
                Toggle(String(localized: "konclui.terminals.toggle"), isOn: $terminalCardsEnabled)
                Text("konclui.terminals.about")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(6)
        }
        .koncluiShown(koncluiAgentShown(.claudeCode))

        #if !APPSTORE
        // Koncluí: Orca's sessions come through Claude Code's hooks; this row decides if their approvals wait on the notch.
        KoncluiOrcaRow()
            .koncluiShown(koncluiTools.contains(.orca) || KoncluiAgentsDebug.opens("orca"))

        ClaudeDesktopChatSettingsSection()
            .koncluiShown(koncluiAgentShown(.claudeDesktop))

        koncluiAgentRow(.gemini, .hooks, installed: geminiHooksInstalled) {   // Koncluí: row + popover
            koncluiHookControls(.gemini, installed: geminiHooksInstalled, show: showGeminiDiff, pending: pendingGeminiJSON, pendingInstall: geminiPendingInstall,
                                preview: { triggerGeminiPreview(install: $0) }, confirm: { confirmGeminiOp() },
                                cancel: { showGeminiDiff = false; pendingGeminiJSON = "" })
        }
        .koncluiShown(koncluiAgentShown(.gemini))

        koncluiAgentRow(.antigravity, .hooks, installed: agyHooksInstalled) {   // Koncluí: row + popover
            koncluiHookControls(.antigravity, installed: agyHooksInstalled, show: showAgyDiff, pending: pendingAgyJSON, pendingInstall: agyPendingInstall,
                                preview: { triggerAgyPreview(install: $0) }, confirm: { confirmAgyOp() },
                                cancel: { showAgyDiff = false; pendingAgyJSON = "" })
        }
        .koncluiShown(koncluiAgentShown(.antigravity))

        koncluiAgentRow(.codex, .hooks, installed: codexHooksInstalled) {   // Koncluí: row + popover
            koncluiHookControls(.codex, installed: codexHooksInstalled, show: showCodexDiff, pending: pendingCodexJSON, pendingInstall: codexPendingInstall,
                                preview: { triggerCodexPreview(install: $0) }, confirm: { confirmCodexOp() },
                                cancel: { showCodexDiff = false; pendingCodexJSON = "" })
        }
        .koncluiShown(koncluiAgentShown(.codex))

        koncluiAgentRow(.copilot, .hooks, installed: copilotHooksInstalled) {   // Koncluí: row + popover
            koncluiHookControls(.copilot, installed: copilotHooksInstalled, show: showCopilotDiff, pending: pendingCopilotJSON, pendingInstall: copilotPendingInstall,
                                preview: { triggerCopilotPreview(install: $0) }, confirm: { confirmCopilotOp() },
                                cancel: { showCopilotDiff = false; pendingCopilotJSON = "" })
        }
        .koncluiShown(koncluiAgentShown(.copilot))

        koncluiAgentRow(.muse, .hooks, installed: museHooksInstalled) {   // Koncluí: row + popover
            koncluiHookControls(.muse, installed: museHooksInstalled, show: showMuseDiff, pending: pendingMuseJSON, pendingInstall: musePendingInstall,
                                preview: { triggerMusePreview(install: $0) }, confirm: { confirmMuseOp() },
                                cancel: { showMuseDiff = false; pendingMuseJSON = "" })
        }
        .koncluiShown(koncluiAgentShown(.muse))

        koncluiAgentRow(.opencode, .plugin, installed: openCodePluginInstalled) {   // Koncluí: row + popover
            koncluiHookControls(.opencode, installed: openCodePluginInstalled, show: showOpenCodeDiff, pending: pendingOpenCodeContent, pendingInstall: openCodePendingInstall,
                                preview: { triggerOpenCodePreview(install: $0) }, confirm: { confirmOpenCodeOp() },
                                cancel: { showOpenCodeDiff = false; pendingOpenCodeContent = "" })
        }
        .koncluiShown(koncluiAgentShown(.opencode))

        koncluiAgentRow(.amp, .plugin, installed: ampPluginInstalled) {   // Koncluí: row + popover
            koncluiHookControls(.amp, installed: ampPluginInstalled, show: showAmpDiff, pending: pendingAmpContent, pendingInstall: ampPendingInstall,
                                preview: { triggerAmpPreview(install: $0) }, confirm: { confirmAmpOp() },
                                cancel: { showAmpDiff = false; pendingAmpContent = "" })
        }
        .koncluiShown(koncluiAgentShown(.amp))

        koncluiAgentRow(.hermes, .plugin, installed: hermesPluginInstalled) {   // Koncluí: row + popover
            VStack(alignment: .leading, spacing: 10) {
                koncluiHookControls(.hermes, installed: hermesPluginInstalled, show: showHermesPluginDiff,
                                    pending: pendingHermesPluginContent, pendingInstall: hermesPluginPendingInstall,
                                    preview: { triggerHermesPluginPreview(install: $0) }, confirm: { confirmHermesPluginOp() },
                                    cancel: { showHermesPluginDiff = false; pendingHermesPluginContent = "" })

                if hermesPluginInstalled {
                    Divider()
                    Toggle(String(localized: "plugin.hermes.approvals"), isOn: $hermesApprovalsEnabled)
                        .onChange(of: hermesApprovalsEnabled) { _, _ in triggerHermesConfigPreview() }
                        .disabled(!hermesSupportsApprovals)
                    if !hermesSupportsApprovals {
                        Text("Requires a newer version of Hermes — run: hermes update")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(hermesApprovalsEnabled
                             ? String(localized: "plugin.hermes.approvals.enabled")
                             : String(localized: "plugin.hermes.approvals.disabled"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if showHermesConfigDiff {
                        ScrollView {
                            Text(pendingHermesConfigContent)
                                .font(.system(size: 10, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 120)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                        HStack {
                            Button(String(localized: "hooks.confirm-write")) { confirmHermesConfigOp() }
                                .buttonStyle(.koncluiPrimary)
                            Button(String(localized: "Cancel")) { showHermesConfigDiff = false; pendingHermesConfigContent = "" }
                                .buttonStyle(.koncluiSecondary)
                        }
                    }
                }
            }
            .padding(6)
        }
        #if !APPSTORE
        .task(id: hermesPluginInstalled) {
            guard hermesPluginInstalled else { hermesSupportsApprovals = false; return }
            let result = await Task.detached(priority: .background) {
                HookServer.hermesSupportsApprovalTransport()
            }.value
            await MainActor.run { hermesSupportsApprovals = result }
        }
        #endif
        .koncluiShown(koncluiAgentShown(.hermes))

        koncluiAgentRow(.plan, .toggle, installed: state.showPlanInNotch || state.showCodexPlanInNotch) {   // Koncluí: row + popover
            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "plan.description"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle(String(localized: "plan.show-in-notch"), isOn: Binding(
                    get: { state.showPlanInNotch || planTogglePending },
                    set: { on in
                        if on {
                            if state.planRelayInstalled {
                                state.showPlanInNotch = true
                            } else {
                                planTogglePending = true
                                installStatusLine()
                            }
                        } else {
                            state.showPlanInNotch = false
                            planTogglePending = false
                        }
                    }
                ))
                HStack(spacing: 10) {
                    if state.planRelayInstalled {
                        Text(String(localized: "plan.relay.installed"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Button(String(localized: "plan.relay.uninstall")) { uninstallStatusLine() }
                            .buttonStyle(.koncluiSecondary)
                    } else {
                        Text(String(localized: "plan.relay.not-installed"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Button(String(localized: "plan.relay.install")) { installStatusLine() }
                            .buttonStyle(.koncluiPrimary)
                    }
                }
                if showStatusLineDiff {
                    ScrollView {
                        Text(pendingStatusLineJSON)
                            .font(.system(size: 10, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 100)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    HStack {
                        Button(String(localized: "hooks.confirm-write")) { confirmStatusLine() }
                            .buttonStyle(.koncluiPrimary)
                        Button(String(localized: "Cancel")) {
                            showStatusLineDiff = false
                            pendingStatusLineJSON = ""
                            planTogglePending = false
                        }
                        .buttonStyle(.koncluiSecondary)
                    }
                }
                Divider()
                Text("Shows your Codex plan usage (weekly limit and free resets left) in the notch header. Koncluí asks the Codex CLI (codex app-server) when the pill shows; nothing is installed. Codex must be signed in with ChatGPT.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle("Show Codex plan in the notch", isOn: Binding(
                    get: { state.showCodexPlanInNotch },
                    set: { state.showCodexPlanInNotch = $0 }
                ))
            }
            .padding(6)
        }
        .koncluiShown(koncluiAgentShown(.plan))
        #endif

        KoncluiAddMenu(
            items: koncluiAgentBlocks.filter { !koncluiAgentShown($0) }.map { .init(id: $0.rawValue, title: $0.title) },
            onPick: { koncluiAdded.add(.agents, $0) })
    }

    // MARK: - Chat section

    @ViewBuilder private var chatSection: some View {
        // Koncluí: the chat through what this Mac is signed in to (unit K10); then only the key-based and local
        // providers that have a key or a server, or were added.
        KoncluiChatSubscriptionsSection()

        GroupBox(String(localized: "chat.anthropic-api.title")) {
            VStack(alignment: .leading, spacing: 8) {
                SecureField(String(localized: "chat.api-key.claude"), text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                Button(String(localized: "Save")) {
                    KeychainStore.shared.set("anthropic-api-key", value: apiKey)
                    statusMessage = String(localized: "status.key-saved")
                }
                .buttonStyle(.koncluiPrimary)

                Divider().padding(.vertical, 2)

                Picker(String(localized: "chat.model"), selection: $modelChoice) {
                    ForEach(displayModels, id: \.id) { preset in
                        Text(preset.label).tag(preset.id)
                    }
                    Text(String(localized: "chat.model.custom")).tag(Self.customModelTag)
                }
                .onChange(of: modelChoice) { _, choice in
                    if choice != Self.customModelTag {
                        state.claudeModel = choice
                    } else {
                        applyCustomModel(customModel)
                    }
                }

                if modelChoice == Self.customModelTag {
                    TextField(String(localized: "chat.model.custom-id"), text: $customModel)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: customModel) { _, value in applyCustomModel(value) }
                }

                Text(String(localized: "chat.model.description"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(6)
        }
        .koncluiShown(koncluiChatShown(.anthropic))

        GroupBox(String(localized: "chat.other-providers.title")) {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "chat.other-providers.description"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                if koncluiChatShown(.google) {
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: "#4285F4")).frame(width: 8, height: 8)
                        Text(String(localized: "chat.google-ai")).font(.system(size: 12, weight: .semibold))
                    }
                    SecureField(String(localized: "chat.api-key.google"), text: $googleKey)
                        .textFieldStyle(.roundedBorder)
                    Button(String(localized: "Save")) {
                        KeychainStore.shared.set("google-api-key", value: googleKey)
                        statusMessage = String(localized: "status.google-key-saved")
                    }
                    .buttonStyle(.koncluiPrimary)
                    Divider().koncluiShown(koncluiChatShownAfter(.google))
                }

                if koncluiChatShown(.openai) {
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: "#10A37F")).frame(width: 8, height: 8)
                        Text(String(localized: "chat.openai")).font(.system(size: 12, weight: .semibold))
                    }
                    SecureField(String(localized: "chat.api-key.openai"), text: $openAIKey)
                        .textFieldStyle(.roundedBorder)
                    Button(String(localized: "Save")) {
                        KeychainStore.shared.set("openai-api-key", value: openAIKey)
                        statusMessage = String(localized: "status.openai-key-saved")
                    }
                    .buttonStyle(.koncluiPrimary)
                    Divider().koncluiShown(koncluiChatShownAfter(.openai))
                }

                if koncluiChatShown(.deepseek) {
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: "#5B8FF9")).frame(width: 8, height: 8)
                        Text("DeepSeek").font(.system(size: 12, weight: .semibold))
                    }
                    SecureField("API key", text: $deepseekKey)
                        .textFieldStyle(.roundedBorder)
                    Button(String(localized: "Save")) {
                        KeychainStore.shared.set("deepseek-api-key", value: deepseekKey)
                        statusMessage = String(localized: "status.deepseek-key-saved")
                    }
                    .buttonStyle(.koncluiPrimary)
                    Divider().koncluiShown(koncluiChatShownAfter(.deepseek))
                }

                if koncluiChatShown(.qwen) {
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: "#FF6A00")).frame(width: 8, height: 8)
                        Text("Qwen (Alibaba)").font(.system(size: 12, weight: .semibold))
                    }
                    SecureField("API key", text: $qwenKey)
                        .textFieldStyle(.roundedBorder)
                    Button(String(localized: "Save")) {
                        KeychainStore.shared.set("qwen-api-key", value: qwenKey)
                        statusMessage = String(localized: "status.qwen-key-saved")
                    }
                    .buttonStyle(.koncluiPrimary)
                    Divider().koncluiShown(koncluiChatShownAfter(.qwen))
                }

                if koncluiChatShown(.moonshot) {
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: "#7C5CFC")).frame(width: 8, height: 8)
                        Text("Moonshot (Kimi)").font(.system(size: 12, weight: .semibold))
                    }
                    SecureField("API key", text: $moonshotKey)
                        .textFieldStyle(.roundedBorder)
                    Button(String(localized: "Save")) {
                        KeychainStore.shared.set("moonshot-api-key", value: moonshotKey)
                        statusMessage = String(localized: "status.moonshot-key-saved")
                    }
                    .buttonStyle(.koncluiPrimary)
                }
            }
            .padding(.vertical, 4)
        }
        .koncluiShown(Self.koncluiKeyProviders.contains(where: koncluiChatShown))

        GroupBox(String(localized: "chat.local.title")) {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "chat.local.description"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                if koncluiChatShown(.ollama) {
                    // ── Ollama ──────────────────────────────────────────────────────
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: "#FACC15")).frame(width: 8, height: 8)
                        Text("Ollama").font(.system(size: 12, weight: .semibold))
                        if !state.ollamaServerURL.isEmpty {
                            Text(String(localized: "Connected"))
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#22C55E"))
                        }
                    }
                    if state.ollamaServerURL.isEmpty {
                        TextField("http://127.0.0.1:11434", text: $ollamaURL)
                            .textFieldStyle(.roundedBorder)
                        Button(connectingOllama ? String(localized: "chat.connecting") : String(localized: "chat.connect")) {
                            Task { await connectLocal(provider: .ollama) }
                        }
                        .buttonStyle(.koncluiPrimary)
                        .disabled(connectingOllama)
                    } else {
                        Text(state.ollamaServerURL)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                        Button(String(localized: "chat.disconnect")) {
                            state.ollamaServerURL = ""
                            ollamaURL = ""
                            state.fetchedProviderModels[.ollama] = nil
                            state.providerModelFetchError[.ollama] = nil
                            if state.chatProvider == .ollama { state.chatProvider = .anthropic }
                            statusMessage = String(localized: "status.local.ollama-disconnected")
                        }
                        .buttonStyle(.koncluiSecondary)
                    }
                    Divider().koncluiShown(koncluiChatShown(.lmstudio))
                }

                if koncluiChatShown(.lmstudio) {
                    // ── LM Studio ───────────────────────────────────────────────────
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: "#A3E635")).frame(width: 8, height: 8)
                        Text("LM Studio").font(.system(size: 12, weight: .semibold))
                        if !state.lmstudioServerURL.isEmpty {
                            Text(String(localized: "Connected"))
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#22C55E"))
                        }
                    }
                    if state.lmstudioServerURL.isEmpty {
                        TextField("http://127.0.0.1:1234", text: $lmstudioURL)
                            .textFieldStyle(.roundedBorder)
                        Button(connectingLMStudio ? String(localized: "chat.connecting") : String(localized: "chat.connect")) {
                            Task { await connectLocal(provider: .lmstudio) }
                        }
                        .buttonStyle(.koncluiPrimary)
                        .disabled(connectingLMStudio)
                    } else {
                        Text(state.lmstudioServerURL)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                        Button(String(localized: "chat.disconnect")) {
                            state.lmstudioServerURL = ""
                            lmstudioURL = ""
                            state.fetchedProviderModels[.lmstudio] = nil
                            state.providerModelFetchError[.lmstudio] = nil
                            if state.chatProvider == .lmstudio { state.chatProvider = .anthropic }
                            statusMessage = String(localized: "status.local.lmstudio-disconnected")
                        }
                        .buttonStyle(.koncluiSecondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .koncluiShown(koncluiChatShown(.ollama) || koncluiChatShown(.lmstudio))

        KoncluiAddMenu(
            items: Self.koncluiAddableChatProviders.filter { !koncluiChatShown($0) }
                .map { .init(id: $0.rawValue, title: $0 == .anthropic ? "Anthropic API" : $0.displayName) },
            onPick: { koncluiAdded.add(.chat, $0) })
    }

    // MARK: - Integrations section

    @ViewBuilder private var integrationsSection: some View {
        let signals = koncluiSignals   // Koncluí: only the services that are configured, turned on or added show
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {

                // Resend
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "#22C55E")).frame(width: 8, height: 8)
                        Text("Resend").font(.system(size: 12, weight: .semibold))
                    }
                    SecureField("API key  (re_…)", text: $resendKey)
                        .textFieldStyle(.roundedBorder)
                    TextField("From address  (you@yourdomain.com)", text: $resendFrom)
                        .textFieldStyle(.roundedBorder)
                }
                .koncluiShown(koncluiIntegrationShown("integration_resend", signals))

                // n8n
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "#F29B38")).frame(width: 8, height: 8)
                        Text("n8n").font(.system(size: 12, weight: .semibold))
                    }
                    TextField("Instance URL  (https://…)", text: $n8nUrl)
                        .textFieldStyle(.roundedBorder)
                    SecureField("API key", text: $n8nKey)
                        .textFieldStyle(.roundedBorder)
                    IntegrationFilterRow(
                        label: String(localized: "integrations.workflows"),
                        items: n8nWorkflows,
                        filter: $state.n8nWorkflowFilter,
                        loading: loadingN8n,
                        onLoad: loadN8nWorkflows
                    )
                }
                .koncluiShown(koncluiIntegrationShown("integration_n8n", signals))

                // Vercel
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "#7C5CFF")).frame(width: 8, height: 8)
                        Text("Vercel").font(.system(size: 12, weight: .semibold))
                    }
                    SecureField("Token", text: $vercelToken)
                        .textFieldStyle(.roundedBorder)
                    IntegrationFilterRow(
                        label: String(localized: "integrations.projects"),
                        items: vercelProjects,
                        filter: $state.vercelProjectFilter,
                        loading: loadingVercel,
                        onLoad: loadVercelProjects
                    )
                }
                .koncluiShown(koncluiIntegrationShown("integration_vercel", signals))

                // GitHub
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "#F4505E")).frame(width: 8, height: 8)
                        Text("GitHub").font(.system(size: 12, weight: .semibold))
                    }
                    SecureField("Personal Access Token", text: $githubToken)
                        .textFieldStyle(.roundedBorder)
                    Text(String(localized: "integrations.github.token-hint"))
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#8E939C"))
                }
                .koncluiShown(koncluiIntegrationShown("integration_github", signals))

                // Stripe
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "#0570DE")).frame(width: 8, height: 8)
                        Text("Stripe").font(.system(size: 12, weight: .semibold))
                    }
                    SecureField("Secret key  (sk_live_… or sk_test_…)", text: $stripeKey)
                        .textFieldStyle(.roundedBorder)
                }
                .koncluiShown(koncluiIntegrationShown("integration_stripe", signals))

                // Cal.com
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "#C9956A")).frame(width: 8, height: 8)
                        Text("Cal.com").font(.system(size: 12, weight: .semibold))
                    }
                    SecureField("API key  (cal_live_…)", text: $calcomKey)
                        .textFieldStyle(.roundedBorder)
                }
                .koncluiShown(koncluiIntegrationShown("integration_calcom", signals))

                // Notion
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "#E8E8E8")).frame(width: 8, height: 8)
                        Text("Notion").font(.system(size: 12, weight: .semibold))
                    }
                    SecureField("Integration token  (secret_…)", text: $notionKey)
                        .textFieldStyle(.roundedBorder)
                }
                .koncluiShown(koncluiIntegrationShown("integration_notion", signals))

                // Crypto: public prices, no key. Changes apply at once.
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "#F7931A")).frame(width: 8, height: 8)
                        Text(verbatim: "Crypto").font(.system(size: 12, weight: .semibold))
                    }
                    Picker(String(localized: "crypto.exchange"), selection: $cryptoExchange) {
                        ForEach(CryptoExchange.allCases, id: \.rawValue) { ex in
                            Text(verbatim: ex.name).tag(ex.rawValue)
                        }
                    }
                    .pickerStyle(.segmented).koncluiSegmented()
                    Picker(String(localized: "crypto.currency"), selection: $cryptoCurrency) {
                        Text(verbatim: "EUR €").tag("EUR")
                        Text(verbatim: "USD $").tag("USD")
                    }
                    .pickerStyle(.segmented).koncluiSegmented()
                    TextField(String(localized: "crypto.coins-placeholder"), text: $cryptoCoins)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { CryptoController.shared.settingsChanged() }
                    HStack(spacing: 8) {
                        Toggle(String(format: String(localized: "crypto.alert %lld"), Int64(cryptoAlertPercent)),
                               isOn: $cryptoAlert)
                        if cryptoAlert {
                            Stepper("", value: $cryptoAlertPercent, in: 1...50, step: 1)
                                .labelsHidden()
                        }
                    }
                    Text(String(localized: "crypto.hint"))
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#8E939C"))
                }
                .onChange(of: cryptoExchange) { _, _ in CryptoController.shared.settingsChanged() }
                .onChange(of: cryptoCurrency) { _, _ in CryptoController.shared.settingsChanged() }
                .koncluiShown(koncluiIntegrationShown("integration_crypto", signals))

                // Portfolio: exchange accounts + wallets.
                PortfolioSettingsSection()
                    .padding(.top, 4)
                    .koncluiShown(koncluiIntegrationShown("integration_portfolio", signals))

                #if !APPSTORE
                // WhatsApp through a local gateway: its own fields, saved by its own button.
                // Koncluí: one line with an options popover and a live notch preview (KoncluiWhatsAppSection.swift).
                KoncluiWhatsAppSection()
                    .padding(.top, 4)
                    .koncluiShown(koncluiIntegrationShown("integration_whatsapp", signals) || KoncluiWhatsAppDebug.forcesBlock)
                #endif

                Button(String(localized: "integrations.save")) {
                    saveIntegrations()
                    CryptoController.shared.settingsChanged()
                }
                    .buttonStyle(.koncluiPrimary)
                    .koncluiShown(Self.koncluiKeyServices.contains { koncluiIntegrationShown($0, signals) })

            }
            .padding(6)
        }
        // Koncluí: "Add…" sits at the page's outer edge on every list (Active pills, Agents, Chat, Integrations).
        KoncluiAddMenu(
            items: Self.koncluiServices.filter { KoncluiFeatures.isOn($0) && !koncluiIntegrationShown($0, signals) }
                .compactMap { id in PillCatalog.definition(for: id).map { .init(id: id, title: $0.name) } },
            onPick: { koncluiAdded.add(.integrations, $0) })
    }

    // MARK: - Voice section

    #if !APPSTORE
    @State private var voicePermissionsGranted: Bool = false
    @ObservedObject private var voiceEngine = VoiceEngine.shared
    @AppStorage("voiceLanguage")       private var voiceLanguage: String = "en"
    @AppStorage("voiceListenLanguage") private var listenLanguage: String = "auto"
    @AppStorage("voiceTTSEngine")      private var ttsEngine: String = "system"
    @AppStorage("voiceElevenGender")   private var elevenGender: String = "female"
    @AppStorage("voicePitchFemale")    private var pitchFemale: Double = VoiceSettings.defaultPitchFemale
    @AppStorage("voicePitchMale")      private var pitchMale: Double = VoiceSettings.defaultPitchMale
    @State private var webKeySaved: Bool = !(KeychainStore.shared.get("anthropic-api-key") ?? "").isEmpty
    @State private var elevenKeyDraft: String = ""
    @State private var elevenKeySaved: Bool = KeychainStore.shared.get(ElevenLabsTTS.keyName) != nil

    private func speakVoiceSample() {
        let en = voiceLanguage != "fr"
        VoiceSpeaker.shared.speak(en ? "Hi, I'm Koncluí. Say OK Koru whenever you need me."
                                     : "Salut, c'est Koncluí. Dis OK Koru quand tu as besoin de moi.",
                                  locale: Locale(identifier: en ? "en-US" : "fr-FR"))
    }

    @ViewBuilder private var voiceSection: some View {
        // Flow dictation: hold a key anywhere, speak, the words are pasted where you type.
        FlowSettingsBox()

        // Claude is Coucou's brain: no model, language or feature switches any more,
        // only the wake word, the Anthropic key it needs, and Coucou's voice.
        GroupBox(String(localized: "«\u{202F}OK Koru\u{202F}» — voice wake word")) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(String(localized: "Enable voice command"), isOn: $voiceEngine.isEnabled)
                    .disabled(!voicePermissionsGranted && !voiceEngine.isEnabled)

                // Koncluí: no API key needed. Why the box is greyed out, who understands you, and the Claude opt-in.
                KoncluiVoiceBrainSection(permissionsGranted: voicePermissionsGranted, voiceOn: voiceEngine.isEnabled)

                if voiceEngine.recognizerUnavailable {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("No speech recognition model available on this device. Install one in System Settings \u{2192} Keyboard \u{2192} Dictation.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let err = voiceEngine.audioError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("\(String(localized: "Microphone unavailable")): \(err)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !voicePermissionsGranted {
                    Button(String(localized: "Request permissions")) {
                        Task {
                            let ok = await VoiceSettings.requestPermissions()
                            voicePermissionsGranted = ok
                        }
                    }
                    .buttonStyle(.koncluiPrimary)
                }
            }
            .padding(6)
        }
        .onAppear {
            voicePermissionsGranted = VoiceSettings.micStatus == .granted
                && VoiceSettings.speechStatus == .granted
        }

        GroupBox(String(localized: "Language")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text(String(localized: "voice.listen-language"))
                        .frame(width: 130, alignment: .leading)
                    Picker(String(localized: "voice.listen-language"), selection: $listenLanguage) {
                        Text(String(localized: "voice.lang-auto")).tag("auto")
                        Text(verbatim: "Français").tag("fr")
                        Text(verbatim: "English").tag("en")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented).koncluiSegmented()
                    .frame(maxWidth: 260)
                }
                HStack(spacing: 10) {
                    Text(String(localized: "voice.language"))
                        .frame(width: 130, alignment: .leading)
                    Picker(String(localized: "voice.language"), selection: $voiceLanguage) {
                        Text(verbatim: "Français").tag("fr")
                        Text(verbatim: "English").tag("en")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented).koncluiSegmented()
                    .frame(maxWidth: 180)
                    .onChange(of: voiceLanguage) { _, _ in
                        // Chosen by hand: Coucou no longer offers to switch.
                        VoiceSettings.languageOfferDone = true
                        ElevenLabsTTS.shared.reset()
                    }
                }
            }
            .padding(6)
        }

        GroupBox(String(localized: "voice.tts-engine")) {
            VStack(alignment: .leading, spacing: 10) {
                Picker(String(localized: "voice.tts-engine"), selection: $ttsEngine) {
                    Text(String(localized: "voice.tts-system")).tag("system")
                    Text(verbatim: "ElevenLabs").tag("elevenlabs")
                }
                .labelsHidden()   // the box is already titled "Voice"
                .frame(maxWidth: 260)

                if ttsEngine == "elevenlabs" {
                    HStack(spacing: 6) {
                        SecureField(elevenKeySaved ? String(localized: "voice.tts-key-saved")
                                                   : String(localized: "voice.tts-key"),
                                    text: $elevenKeyDraft)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 220)
                        Button(String(localized: "Save")) {
                            let k = elevenKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            if k.isEmpty { KeychainStore.shared.remove(ElevenLabsTTS.keyName) }
                            else { KeychainStore.shared.set(ElevenLabsTTS.keyName, value: k) }
                            elevenKeyDraft = ""
                            elevenKeySaved = !k.isEmpty
                            ElevenLabsTTS.shared.reset()
                        }
                    }
                }

                Picker(String(localized: "voice.tts-gender"), selection: $elevenGender) {
                    Text(String(localized: "voice.tts-female")).tag("female")
                    Text(String(localized: "voice.tts-male")).tag("male")
                }
                .pickerStyle(.segmented).koncluiSegmented()
                .frame(maxWidth: 220)
                .onChange(of: elevenGender) { _, _ in ElevenLabsTTS.shared.reset() }

                if ttsEngine == "system" {
                    HStack(spacing: 8) {
                        Text(String(localized: "voice.tts-pitch"))
                        Slider(value: elevenGender == "male" ? $pitchMale : $pitchFemale,
                               in: 0.8...1.6, step: 0.05,
                               onEditingChanged: { editing in
                                   // Released: hear the new pitch right away.
                                   if !editing { speakVoiceSample() }
                               })
                        .frame(maxWidth: 180)
                    }
                    let current = VoiceSpeaker.macVoiceName(for: Locale(identifier: voiceLanguage == "fr" ? "fr-FR" : "en-US"),
                                                            gender: elevenGender)
                    Text(String(format: String(localized: "voice.mac-voice-current %@"), current))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(String(localized: "voice.mac-voices-help"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(String(localized: "voice.mac-voices-open")) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }

                Button(String(localized: "voice.tts-test")) { speakVoiceSample() }
            }
            .padding(6)
        }
    }

    #if !APPSTORE
    private func localModelStatusLabel(_ status: LocalModelStatus) -> String {
        switch status {
        case .available:            return String(localized: "voice.model-available")
        case .notMacOS26:           return String(localized: "voice.model-not-macos26")
        case .appleIntelligenceOff: return String(localized: "voice.model-ai-off")
        }
    }
    #endif

    // MARK: - Transcript history debug view (in-memory, cleared on close)

    private struct VoiceTranscriptHistoryView: View {
        @ObservedObject private var history = VoiceTranscriptHistory.shared

        var body: some View {
            if !history.entries.isEmpty {
                GroupBox(String(localized: "voice.history-title")) {
                    VStack(alignment: .leading, spacing: 8) {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(history.entries) { entry in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(verbatim: entry.transcript)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundColor(.primary)
                                        Text(verbatim: "→ \(entry.intent)  [\(entry.origin.rawValue)]")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 2)
                                    Divider()
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .frame(maxHeight: 200)

                        HStack {
                            Button(String(localized: "Copy")) {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(history.plainText, forType: .string)
                            }
                            Button(String(localized: "Clear")) {
                                history.clear()
                            }
                            .foregroundColor(.red)
                        }
                        .padding(.top, 4)
                    }
                    .padding(6)
                }
            }
        }
    }

    private var micStatusIcon:  String { VoiceSettings.micStatus    == .granted ? "checkmark.circle.fill" : "xmark.circle.fill" }
    private var micStatusColor: Color  { VoiceSettings.micStatus    == .granted ? .green : .red }
    private var micStatusLabel: String {
        switch VoiceSettings.micStatus {
        case .granted:      return String(localized: "Granted")
        case .denied:       return String(localized: "Denied")
        case .undetermined: return String(localized: "Not requested")
        }
    }
    private var speechStatusIcon:  String { VoiceSettings.speechStatus == .granted ? "checkmark.circle.fill" : "xmark.circle.fill" }
    private var speechStatusColor: Color  { VoiceSettings.speechStatus == .granted ? .green : .red }
    private var speechStatusLabel: String {
        switch VoiceSettings.speechStatus {
        case .granted:      return String(localized: "Granted")
        case .denied:       return String(localized: "Denied")
        case .undetermined: return String(localized: "Not requested")
        }
    }
    #endif

    // MARK: - Actions

    private func applyCustomModel(_ value: String) {
        let id = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !id.isEmpty { state.claudeModel = id }
    }

    private func toggleStartup(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else  { try SMAppService.mainApp.unregister() }
        } catch {
            statusMessage = "❌ Startup: \(error.localizedDescription)"
            launchAtStartup = !on
        }
    }

    // MARK: - App Store: hooks via NSOpenPanel + security-scoped bookmark

    #if APPSTORE
    private func pickClaudeFolder(prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.message = "Select your .claude folder (press ⇧⌘. to show hidden files)"
        panel.prompt = prompt
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        let realHomePath = getpwuid(getuid()).flatMap { String(cString: $0.pointee.pw_dir, encoding: .utf8) }
            ?? "/Users/\(NSUserName())"
        panel.directoryURL = URL(fileURLWithPath: realHomePath)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard url.lastPathComponent == ".claude" else {
            statusMessage = String(localized: "status.select-claude-folder")
            return nil
        }
        return url
    }

    private func installHooksAppStore() {
        guard let claudeURL = pickClaudeFolder(prompt: "Select") else { return }
        let alert = NSAlert()
        alert.messageText = String(localized: "alert.hooks.title")
        alert.informativeText = String(localized: "alert.hooks.body")
        alert.addButton(withTitle: String(localized: "alert.hooks.button-install"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.alertStyle = .informational
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try HookServer.shared.installAndWriteClaudeHooksAppStore(claudeURL: claudeURL)
            hookNeedsUpdate = false
            claudeHooksInstalled = true
            statusMessage = String(localized: "status.hooks-installed-claude")
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func uninstallHooksAppStore() {
        guard let claudeURL = pickClaudeFolder(prompt: "Select") else { return }
        do {
            try HookServer.shared.uninstallClaudeHooksAppStore(claudeURL: claudeURL)
            claudeHooksInstalled = false
            statusMessage = String(localized: "status.hooks-removed")
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }
    #endif

    private func connectLocal(provider: ChatProvider) async {
        let rawURL = provider == .ollama ? ollamaURL : lmstudioURL
        let candidate = rawURL.isEmpty
            ? (provider == .ollama ? "http://127.0.0.1:11434" : "http://127.0.0.1:1234")
            : rawURL
        let normalised = LocalChat.normaliseURL(candidate)
        guard normalised.hasPrefix("http://") || normalised.hasPrefix("https://") else {
            statusMessage = String(localized: "status.local.url-invalid")
            return
        }
        if provider == .ollama { connectingOllama = true } else { connectingLMStudio = true }
        statusMessage = ""
        let result = await LocalChat.fetchModelsResult(baseURL: normalised)
        if provider == .ollama { connectingOllama = false } else { connectingLMStudio = false }
        let name = provider == .ollama ? "Ollama" : "LM Studio"
        switch result {
        case .success(let models) where models.isEmpty:
            statusMessage = String(format: String(localized: "status.local.no-models %@"), name)
        case .success(let models):
            if provider == .ollama {
                state.ollamaServerURL = normalised
                ollamaURL = normalised
                state.fetchedProviderModels[.ollama] = nil
                state.providerModelFetchError[.ollama] = nil
            } else {
                state.lmstudioServerURL = normalised
                lmstudioURL = normalised
                state.fetchedProviderModels[.lmstudio] = nil
                state.providerModelFetchError[.lmstudio] = nil
            }
            statusMessage = String(localized: "status.local.connected \(models.count)")
        case .failure:
            statusMessage = String(format: String(localized: "status.local.unreachable %1$@ %2$@"), name, normalised)
        }
    }

    private func installHooks() {
        do {
            pendingHookJSON = try HookServer.shared.previewClaudeHooks()
            claudePendingInstall = true
            showDiff = true
            statusMessage = String(localized: "hooks.review-json")
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func confirmInstall() {
        do {
            try HookServer.shared.writeClaudeHooks()
            showDiff = false
            statusMessage = claudePendingInstall ? String(localized: "status.hooks-installed-settings")
                                                 : String(localized: "status.hooks-removed")
            pendingHookJSON = ""
            claudeHooksInstalled = claudePendingInstall
            if claudePendingInstall { hookNeedsUpdate = false }
        } catch {
            statusMessage = "❌ Write error: \(error.localizedDescription)"
        }
    }

    // Koncluí: removing the hooks is previewed and confirmed like installing them (CLAUDE.md: never write
    // ~/.claude/settings.json without showing what changes); it used to write at once.
    private func uninstallHooks() {
        do {
            pendingHookJSON = try HookServer.shared.previewClaudeHooks(install: false)
            claudePendingInstall = false
            showDiff = true
            statusMessage = String(localized: "hooks.review-json")
        } catch let e as NSError where e.domain == "CoucouNoop" {
            statusMessage = e.localizedDescription
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    #if !APPSTORE
    private func triggerGeminiPreview(install: Bool) {
        do {
            geminiPendingInstall = install
            pendingGeminiJSON = try HookServer.shared.previewGeminiHooks(install: install)
            showGeminiDiff = true
            statusMessage = String(localized: "hooks.review-json")
        } catch let e as NSError where e.domain == "CoucouNoop" {
            statusMessage = e.localizedDescription
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func confirmGeminiOp() {
        do {
            try HookServer.shared.writeGeminiHooks()
            showGeminiDiff = false
            pendingGeminiJSON = ""
            geminiHooksInstalled = geminiPendingInstall
            statusMessage = geminiPendingInstall
                ? String(localized: "status.gemini-hooks-installed")
                : String(localized: "status.gemini-hooks-removed")
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func triggerAgyPreview(install: Bool) {
        do {
            agyPendingInstall = install
            pendingAgyJSON = try HookServer.shared.previewAgyHooks(install: install)
            showAgyDiff = true
            statusMessage = String(localized: "hooks.review-json")
        } catch let e as NSError where e.domain == "CoucouNoop" {
            statusMessage = e.localizedDescription
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func confirmAgyOp() {
        do {
            try HookServer.shared.writeAgyHooks()
            showAgyDiff = false
            pendingAgyJSON = ""
            agyHooksInstalled = agyPendingInstall
            statusMessage = agyPendingInstall
                ? String(localized: "status.agy-hooks-installed")
                : String(localized: "status.agy-hooks-removed")
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func triggerCodexPreview(install: Bool) {
        do {
            codexPendingInstall = install
            pendingCodexJSON = try HookServer.shared.previewCodexHooks(install: install)
            showCodexDiff = true
            statusMessage = String(localized: "hooks.review-json")
        } catch let e as NSError where e.domain == "CoucouNoop" {
            statusMessage = e.localizedDescription
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func confirmCodexOp() {
        do {
            try HookServer.shared.writeCodexHooks()
            showCodexDiff = false
            pendingCodexJSON = ""
            codexHooksInstalled = codexPendingInstall
            statusMessage = codexPendingInstall
                ? String(localized: "status.codex-hooks-installed")
                : String(localized: "status.codex-hooks-removed")
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func triggerCopilotPreview(install: Bool) {
        do {
            copilotPendingInstall = install
            pendingCopilotJSON = try HookServer.shared.previewCopilotHooks(install: install)
            showCopilotDiff = true
            statusMessage = String(localized: "hooks.review-json")
        } catch let e as NSError where e.domain == "CoucouNoop" {
            statusMessage = e.localizedDescription
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func confirmCopilotOp() {
        do {
            try HookServer.shared.writeCopilotHooks()
            showCopilotDiff = false
            pendingCopilotJSON = ""
            copilotHooksInstalled = copilotPendingInstall
            statusMessage = copilotPendingInstall
                ? String(localized: "status.copilot-hooks-installed")
                : String(localized: "status.copilot-hooks-removed")
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func triggerMusePreview(install: Bool) {
        do {
            musePendingInstall = install
            pendingMuseJSON = try HookServer.shared.previewMuseHooks(install: install)
            showMuseDiff = true
            statusMessage = String(localized: "hooks.review-json")
        } catch let e as NSError where e.domain == "CoucouNoop" {
            statusMessage = e.localizedDescription
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func confirmMuseOp() {
        do {
            try HookServer.shared.writeMuseHooks()
            showMuseDiff = false
            pendingMuseJSON = ""
            museHooksInstalled = musePendingInstall
            statusMessage = musePendingInstall
                ? String(localized: "status.muse-hooks-installed")
                : String(localized: "status.muse-hooks-removed")
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func triggerOpenCodePreview(install: Bool) {
        do {
            openCodePendingInstall = install
            pendingOpenCodeContent = try HookServer.shared.previewOpenCodePlugin(install: install)
            showOpenCodeDiff = true
            statusMessage = String(localized: "plugin.review-content")
        } catch let e as NSError where e.domain == "CoucouNoop" {
            statusMessage = e.localizedDescription
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func confirmOpenCodeOp() {
        do {
            if openCodePendingInstall {
                try HookServer.shared.writeOpenCodePlugin()
            } else {
                try HookServer.shared.removeOpenCodePlugin()
            }
            showOpenCodeDiff = false
            pendingOpenCodeContent = ""
            openCodePluginInstalled = openCodePendingInstall
            statusMessage = openCodePendingInstall
                ? String(localized: "status.opencode-plugin-installed")
                : String(localized: "status.opencode-plugin-removed")
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func triggerAmpPreview(install: Bool) {
        do {
            ampPendingInstall = install
            pendingAmpContent = try HookServer.shared.previewAmpPlugin(install: install)
            showAmpDiff = true
            statusMessage = String(localized: "plugin.review-content")
        } catch let e as NSError where e.domain == "CoucouNoop" {
            statusMessage = e.localizedDescription
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func confirmAmpOp() {
        do {
            if ampPendingInstall {
                try HookServer.shared.writeAmpPlugin()
            } else {
                try HookServer.shared.removeAmpPlugin()
            }
            showAmpDiff = false
            pendingAmpContent = ""
            ampPluginInstalled = ampPendingInstall
            statusMessage = ampPendingInstall
                ? String(localized: "status.amp-plugin-installed")
                : String(localized: "status.amp-plugin-removed")
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func triggerHermesPluginPreview(install: Bool) {
        do {
            hermesPluginPendingInstall = install
            pendingHermesPluginContent = try HookServer.shared.previewHermesPlugin(install: install)
            showHermesPluginDiff = true
            statusMessage = String(localized: "plugin.review-content")
        } catch let e as NSError where e.domain == "CoucouNoop" {
            statusMessage = e.localizedDescription
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func confirmHermesPluginOp() {
        do {
            if hermesPluginPendingInstall {
                try HookServer.shared.writeHermesPlugin()
            } else {
                try HookServer.shared.removeHermesPlugin()
            }
            showHermesPluginDiff = false
            pendingHermesPluginContent = ""
            hermesPluginInstalled = hermesPluginPendingInstall
            statusMessage = hermesPluginPendingInstall
                ? String(localized: "status.hermes-plugin-installed")
                : String(localized: "status.hermes-plugin-removed")
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func triggerHermesConfigPreview() {
        do {
            pendingHermesConfigContent = try HookServer.shared.previewHermesConfig(
                enableApprovals: hermesApprovalsEnabled,
                supportsTransport: hermesSupportsApprovals)
            showHermesConfigDiff = true
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func confirmHermesConfigOp() {
        do {
            try HookServer.shared.writeHermesConfig()
            showHermesConfigDiff = false
            pendingHermesConfigContent = ""
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func installStatusLine() {
        do {
            pendingStatusLineJSON = try HookServer.shared.previewStatusLine(install: true)
            showStatusLineDiff = true
            statusLinePendingInstall = true
            statusMessage = String(localized: "hooks.review-json")
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func uninstallStatusLine() {
        do {
            pendingStatusLineJSON = try HookServer.shared.previewStatusLine(install: false)
            showStatusLineDiff = true
            statusLinePendingInstall = false
            statusMessage = String(localized: "hooks.review-json")
        } catch {
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }

    private func confirmStatusLine() {
        do {
            try HookServer.shared.writeStatusLine()
            showStatusLineDiff = false
            pendingStatusLineJSON = ""
            state.refreshPlanRelayState()
            if planTogglePending {
                state.showPlanInNotch = true
                planTogglePending = false
            }
            if !statusLinePendingInstall {
                state.showPlanInNotch = false
            }
            statusMessage = statusLinePendingInstall
                ? String(localized: "status.statusline-installed")
                : String(localized: "status.statusline-removed")
        } catch {
            planTogglePending = false
            statusMessage = "❌ \(error.localizedDescription)"
        }
    }
    #endif

    private func saveIntegrations() {
        saveKey("resend-api-key",  value: resendKey)
        saveKey("resend-from",     value: resendFrom)
        saveKey("n8n-url",         value: n8nUrl)
        saveKey("n8n-api-key",     value: n8nKey)
        saveKey("vercel-token",    value: vercelToken)

        // Detect GitHub token changes before writing
        let prevGithubToken = KeychainStore.shared.get("github-token")
        saveKey("github-token", value: githubToken)
        let nextGithubToken = KeychainStore.shared.get("github-token")
        if nextGithubToken != prevGithubToken {
            AppState.shared.githubPulse = nil
            AppState.shared.githubActivity = nil
            if nextGithubToken == nil { AppState.shared.githubStats = nil }
            if nextGithubToken != nil {
                GithubPoller.shared.triggerPulseNow()
                GithubPoller.shared.refreshActivityIfStale()
            }
        }

        saveKey("stripe-api-key",  value: stripeKey)
        saveKey("calcom-api-key",  value: calcomKey)
        saveKey("notion-api-key",  value: notionKey)
        statusMessage = String(localized: "status.integrations-saved")
    }

    private func saveKey(_ key: String, value: String) {
        if value.isEmpty {
            KeychainStore.shared.remove(key)
        } else {
            KeychainStore.shared.set(key, value: value)
        }
    }

    // MARK: - Vercel project list

    private func loadVercelProjects() {
        guard let token = KeychainStore.shared.get("vercel-token") else {
            statusMessage = "❌ Save Vercel token first."
            return
        }
        loadingVercel = true
        guard let url = URL(string: "https://api.vercel.com/v9/projects?limit=100") else { return }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { data, response, _ in
            let names: [String]
            if let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let projects = json["projects"] as? [[String: Any]] {
                names = projects.compactMap { $0["name"] as? String }.sorted()
            } else {
                names = []
            }
            DispatchQueue.main.async {
                self.vercelProjects = names
                self.loadingVercel = false
                if names.isEmpty { self.statusMessage = "❌ No Vercel projects found." }
            }
        }.resume()
    }

    // MARK: - n8n workflow list

    private func loadN8nWorkflows() {
        guard let apiKey  = KeychainStore.shared.get("n8n-api-key"),
              let rawBase = KeychainStore.shared.get("n8n-url") else {
            statusMessage = "❌ Save n8n URL and API key first."
            return
        }
        loadingN8n = true
        let base = rawBase.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urls = ["\(base)/api/v1/workflows?limit=100", "\(base)/rest/workflows?limit=100"]
        fetchN8nWorkflows(urls: urls, apiKey: apiKey, idx: 0)
    }

    private func fetchN8nWorkflows(urls: [String], apiKey: String, idx: Int) {
        guard idx < urls.count, let url = URL(string: urls[idx]) else {
            DispatchQueue.main.async { self.loadingN8n = false; self.statusMessage = "❌ No n8n workflows found." }
            return
        }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue(apiKey, forHTTPHeaderField: "X-N8N-API-KEY")
        URLSession.shared.dataTask(with: req) { data, response, _ in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let data, code == 200 else {
                self.fetchN8nWorkflows(urls: urls, apiKey: apiKey, idx: idx + 1)
                return
            }
            let items: [[String: Any]]
            if let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
               let arr = obj["data"] as? [[String: Any]] { items = arr }
            else if let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] { items = arr }
            else { items = [] }
            let names = items.compactMap { $0["name"] as? String }.sorted()
            DispatchQueue.main.async {
                self.n8nWorkflows = names
                self.loadingN8n = false
                if names.isEmpty { self.statusMessage = "❌ No n8n workflows found." }
            }
        }.resume()
    }

    @ViewBuilder
    private func pillRow(_ def: PillDefinition) -> some View {
        let isMain = def.id == state.mainPillId
        let isOn   = state.activeIntegrations.contains(def.id)
        let atMax  = KoncluiTabLimit.blocks(activeCount: state.activeIntegrations.count, isOn: isOn, isMain: isMain)   // Koncluí
            || (KoncluiPageDebug.limitPill != nil && !isOn && !isMain)   // DEBUG screenshots only
        // Koncluí: the installed state comes from KoncluiHookStatus (read off the main thread), not from the files at every redraw.
        let hooks = koncluiHooks.snapshot, hooksKnown = koncluiHooks.loaded
        let hint: String? = {
            if isMain { return nil }
            if def.comingSoon { return String(localized: "Coming soon") }
            #if !APPSTORE
            if def.id == "agent_gemini"        && hooksKnown && !hooks.isInstalled(.gemini)      { return String(localized: "Hooks not installed") }
            if def.id == "agent_antigravity"   && hooksKnown && !hooks.isInstalled(.antigravity) { return String(localized: "Hooks not installed") }
            if def.id == "agent_codex"         && hooksKnown && !hooks.isInstalled(.codex)       { return String(localized: "Hooks not installed") }
            if def.id == "agent_copilot"       && hooksKnown && !hooks.isInstalled(.copilot)     { return String(localized: "Hooks not installed") }
            if def.id == "agent_muse"          && hooksKnown && !hooks.isInstalled(.muse)        { return String(localized: "Hooks not installed") }
            if def.id == "agent_opencode"      && hooksKnown && !hooks.isInstalled(.opencode)    { return String(localized: "Plugin not installed") }
            if def.id == "agent_amp"           && hooksKnown && !hooks.isInstalled(.amp)         { return String(localized: "Plugin not installed") }
            if def.id == SpotifyController.pillId && !SpotifyController.shared.isInstalled { return String(localized: "Not installed") }
            #endif
            if def.category == .ai {
                if let provider = ChatProvider(pillID: def.id), provider.isLocal {
                    let url = provider == .ollama ? state.ollamaServerURL : state.lmstudioServerURL
                    if url.isEmpty { return String(localized: "Not connected") }
                } else {
                    let keyId = def.id == "ai_anthropic" ? "anthropic-api-key"
                               : def.id == "ai_google"    ? "google-api-key" : "openai-api-key"
                    if KeychainStore.shared.get(keyId) == nil { return String(localized: "Key not configured") }
                }
            }
            return nil
        }()
        HStack(spacing: 8) {
            // The dot is the row's colour control; a click opens the palette. Koncluí: it is drawn as a door (KoncluiPillRowParts.swift).
            koncluiColorDot(def)
            .popover(isPresented: Binding(
                get: { colorPalettePill == def.id },
                set: { open in if !open && colorPalettePill == def.id { colorPalettePill = nil } }
            ), arrowEdge: .bottom) {
                PillColorPalette(
                    current: def.color,
                    isCustom: state.pillColors[def.id] != nil,
                    pick: { hex in
                        state.setPillColor(def.id, hex)
                        colorPalettePill = nil
                    }
                )
            }
            Text(def.name)
                .font(.system(size: 12))
                .foregroundColor(atMax ? .secondary : .primary)
            Spacer()
            if isMain {
                Text("Main")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                if atMax {
                    koncluiLimitDoor(def)   // Koncluí: the switch is blocked, and the row says why and how to free a place
                } else if let h = hint {
                    koncluiHint(h, for: def)   // Koncluí: "Hooks not installed" is a door to the install (KoncluiAgentRow.swift)
                }
                Toggle("", isOn: Binding(
                    get: { isOn },
                    set: { _ in state.toggleIntegration(def.id) }
                ))
                .labelsHidden()
                .disabled(atMax)
            }
        }
    }
}

// MARK: - Pill colour palette (Active pills, opened from a row's dot)

private struct PillColorPalette: View {
    /// The colour the pill is painted with now.
    let current: String
    /// The user picked it: "Default" is offered, to go back to the catalog's.
    let isCustom: Bool
    /// nil = back to the catalog's colour.
    let pick: (String?) -> Void

    var body: some View {
        let now = PillColors.normalized(current)
        HStack(spacing: 7) {
            ForEach(PillColors.palette, id: \.self) { hex in
                Button {
                    pick(hex)
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.primary, lineWidth: 1.5)
                                .padding(-3)
                                .opacity(hex == now ? 1 : 0)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(hex))
            }
            if isCustom {
                Button(String(localized: "Default")) {
                    pick(nil)
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Sidebar background (NSVisualEffectView .sidebar)

struct SidebarBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .sidebar
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Sidebar row (System Settings style icon)

struct SettingsSidebarRow: View {
    let title: String
    let icon: String
    let color: String

    var body: some View {
        Label {
            Text(LocalizedStringKey(title))
        } icon: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color(hex: color)))
        }
    }
}

// MARK: - Integration filter row (reusable for Vercel / n8n)

struct IntegrationFilterRow: View {
    let label: String
    let items: [String]
    @Binding var filter: Set<String>
    let loading: Bool
    let onLoad: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                if loading {
                    ProgressView().scaleEffect(0.6)
                } else {
                    Button(items.isEmpty ? "Load list" : "Refresh") { onLoad() }
                        .buttonStyle(.koncluiSecondary)
                        .controlSize(.mini)
                }
                if !filter.isEmpty {
                    Button("Clear") { filter = [] }
                        .buttonStyle(.koncluiSecondary)
                        .controlSize(.mini)
                        .foregroundColor(.secondary)
                }
            }
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(items, id: \.self) { item in
                        Toggle(item, isOn: Binding(
                            get: { filter.isEmpty || filter.contains(item) },
                            set: { on in
                                if on { filter.insert(item) }
                                else  {
                                    if filter.isEmpty { filter = Set(items).subtracting([item]) }
                                    else { filter.remove(item) }
                                    if filter.count == items.count { filter = [] }
                                }
                            }
                        ))
                        .font(.system(size: 11))
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(.leading, 4)
                if !filter.isEmpty {
                    Text(String(format: String(localized: "Watching %lld of %lld"), Int64(filter.count), Int64(items.count)))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Shortcut recorder button

struct ShortcutRecorderButton: View {
    @Binding var flags: UInt
    @Binding var code: UInt16
    @State private var isRecording = false

    var body: some View {
        Button {
            guard !isRecording else { return }
            isRecording = true
            var token: Any?
            token = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                let mods = event.modifierFlags.intersection([.command, .control, .option, .shift])
                guard !mods.isEmpty else { return event }
                DispatchQueue.main.async {
                    self.flags = mods.rawValue
                    self.code = event.keyCode
                    self.isRecording = false
                    if let t = token { NSEvent.removeMonitor(t) }
                }
                return nil
            }
        } label: {
            Text(isRecording ? String(localized: "konclui.key.press") : shortcutLabel)
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(isRecording ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var shortcutLabel: String {
        let f = NSEvent.ModifierFlags(rawValue: flags)
        var s = ""
        if f.contains(.control) { s += "⌃" }
        if f.contains(.option)  { s += "⌥" }
        if f.contains(.shift)   { s += "⇧" }
        if f.contains(.command) { s += "⌘" }
        s += keyChar(code)
        return s.isEmpty ? String(localized: "None") : s
    }

    private func keyChar(_ c: UInt16) -> String {
        let map: [UInt16: String] = [
            0:"A", 1:"S", 2:"D", 3:"F", 4:"H", 5:"G", 6:"Z", 7:"X", 8:"C", 9:"V",
            11:"B", 12:"Q", 13:"W", 14:"E", 15:"R", 16:"Y", 17:"T", 31:"O", 32:"U",
            34:"I", 37:"L", 38:"J", 40:"K", 45:"N", 46:"M", 49:"Space", 50:"`", 27:"-"
        ]
        return map[c] ?? KoncluiKeyName.label(c)
    }
}

extension SettingsView {
    /// One section of Settings, for the Coucou Flow window.
    init(embeddedSection: String) {
        self.init()
        self.embeddedSection = embeddedSection
    }
}

// MARK: - Koncluí: recognized-only lists

/// Active pills, Agents, Chat and Integrations list what this Mac has (installed, configured, signed in or turned
/// on) and what the user added with "Add…". The rules are KoncluiRecognition.swift; this is what the screens feed them.
extension SettingsView {
    /// The key-based chat providers listed in "Other providers", in their order.
    static let koncluiKeyProviders: [ChatProvider] = [.google, .openai, .deepseek, .qwen, .moonshot]
    /// Every chat provider with a block of its own here (the subscriptions are KoncluiChatSubscriptionsSection's).
    static let koncluiAddableChatProviders: [ChatProvider] = [.anthropic] + koncluiKeyProviders + [.ollama, .lmstudio]
    /// The services with a block in Integrations.
    static var koncluiServices: [String] {
        var ids = ["integration_resend", "integration_n8n", "integration_vercel", "integration_github", "integration_stripe",
                   "integration_calcom", "integration_notion", "integration_crypto", "integration_portfolio"]
        #if !APPSTORE
        ids.append("integration_whatsapp")
        #endif
        return ids
    }
    /// The ones the "Save" button of Integrations writes.
    static let koncluiKeyServices = ["integration_resend", "integration_n8n", "integration_vercel", "integration_github",
                                     "integration_stripe", "integration_calcom", "integration_notion"]

    // MARK: Pills and integrations

    private var koncluiSignals: KoncluiRecognition.Signals {
        var tools = koncluiTools
        for block in koncluiActiveAgents { if let tool = block.tool { tools.insert(tool) } }
        var keys: Set<String> = []
        for name in KoncluiRecognition.allKeys where !(KeychainStore.shared.get(name) ?? "").isEmpty { keys.insert(name) }
        var chatReady: Set<String> = []
        for provider in ChatProvider.allCases where koncluiChatConfigured(provider) || chatAccess.status(provider).isReady {
            chatReady.insert(provider.rawValue)
        }
        var signals = KoncluiRecognition.Signals(on: state.activeIntegrations.union([state.mainPillId]),
                                                 tools: tools, keys: keys, chatReady: chatReady)
        #if !APPSTORE
        signals.spotifyInstalled = SpotifyController.shared.isInstalled
        #endif
        return signals
    }

    private func koncluiPillShown(_ def: PillDefinition, _ signals: KoncluiRecognition.Signals) -> Bool {
        KoncluiRecognition.pillRecognized(def.id, signals) || koncluiAdded.contains(.pills, def.id)
    }

    private func koncluiIntegrationShown(_ id: String, _ signals: KoncluiRecognition.Signals) -> Bool {
        guard KoncluiFeatures.isOn(id) else { return false }
        return KoncluiRecognition.pillRecognized(id, signals) || koncluiAdded.contains(.integrations, id)
    }

    // MARK: Agents

    /// The agents whose hooks, plugin or switch are already on: their blocks show whatever the detection says.
    private var koncluiActiveAgents: Set<KoncluiRecognition.AgentBlock> {
        #if APPSTORE
        return [.claudeCode]   // the sandbox cannot look for the CLI: the one block there is always listed
        #else
        var on: Set<KoncluiRecognition.AgentBlock> = []
        if geminiHooksInstalled { on.insert(.gemini) }
        if agyHooksInstalled { on.insert(.antigravity) }
        if codexHooksInstalled { on.insert(.codex) }
        if copilotHooksInstalled { on.insert(.copilot) }
        if museHooksInstalled { on.insert(.muse) }
        if openCodePluginInstalled { on.insert(.opencode) }
        if ampPluginInstalled { on.insert(.amp) }
        if hermesPluginInstalled { on.insert(.hermes) }
        if ClaudeDesktopChatWatcher.enabled { on.insert(.claudeDesktop) }
        if state.planRelayInstalled || state.showPlanInNotch || state.showCodexPlanInNotch { on.insert(.plan) }
        return on
        #endif
    }

    private var koncluiAgentBlocks: [KoncluiRecognition.AgentBlock] {
        #if APPSTORE
        return [.claudeCode]
        #else
        return KoncluiRecognition.AgentBlock.allCases
        #endif
    }

    private func koncluiAgentShown(_ block: KoncluiRecognition.AgentBlock) -> Bool {
        KoncluiRecognition.agentRecognized(block, tools: koncluiTools, active: koncluiActiveAgents)
            || koncluiAdded.contains(.agents, block.rawValue)
            || KoncluiAgentsDebug.opens(block.rawValue)   // DEBUG screenshots only
    }

    // MARK: Agent rows and doors (KoncluiAgentRow.swift, KoncluiAgentRows.swift)

    /// One agent in Settings → Agents: a calm row with its status in words; the block's own component is the popover.
    private func koncluiAgentRow<Content: View>(_ block: KoncluiRecognition.AgentBlock, _ kind: KoncluiAgentRows.Kind,
                                                installed: Bool, outdated: Bool = false,
                                                @ViewBuilder content: @escaping () -> Content) -> some View {
        KoncluiAgentRow(id: block.rawValue, name: block.title,
                        colorHex: KoncluiAgentRows.colorHex(for: block, custom: state.pillColors),
                        status: koncluiHooks.loaded || kind == .toggle ? KoncluiAgentRows.status(kind, installed: installed, outdated: outdated)
                                                                        : KoncluiAgentRows.checking,
                        note: statusMessage, isOpen: koncluiPopoverBinding(block.rawValue, open: $koncluiOpenAgent),
                        content: content)
    }

    /// Opening a popover starts from a clean message, so the one it shows is about what was done in it.
    private func koncluiPopoverBinding(_ id: String, open: Binding<String?>) -> Binding<Bool> {
        Binding(get: { open.wrappedValue == id },
                set: { on in
                    if on {
                        statusMessage = ""
                        open.wrappedValue = id
                    } else if open.wrappedValue == id {
                        open.wrappedValue = nil
                    }
                })
    }

    /// While a popover is open the message shows inside it; the window's bottom line would repeat it.
    private var koncluiPopoverOpen: Bool { koncluiOpenAgent != nil || koncluiDoorPill != nil }

    /// The colour dot of an Active pills row.
    @ViewBuilder
    private func koncluiColorDot(_ def: PillDefinition) -> some View {
        #if !APPSTORE
        KoncluiColorDot(hex: def.color, tabName: def.name) { colorPalettePill = def.id }
        #else
        Button { colorPalettePill = def.id } label: {
            Circle().fill(Color(hex: def.color)).frame(width: 10, height: 10)
        }
        .buttonStyle(.plain)
        .help(String(localized: "Color"))
        .accessibilityLabel(Text(def.name + " · " + String(localized: "Color")))
        #endif
    }

    /// Four tabs are on: what the blocked switch of `def` offers instead of a silent grey.
    @ViewBuilder
    private func koncluiLimitDoor(_ def: PillDefinition) -> some View {
        #if !APPSTORE
        let order = PillCatalog.available.map(\.id)
        let tabs: [KoncluiTabLimitDoor.Tab] = KoncluiTabLimit
            .releasable(active: state.activeIntegrations, main: state.mainPillId, order: order)
            .compactMap { id in PillCatalog.definition(for: id).map { .init(id: id, name: $0.name, colorHex: $0.color) } }
        KoncluiTabLimitDoor(
            name: def.name, tabs: tabs,
            isOpen: Binding(get: { koncluiLimitPill == def.id },
                            set: { on in if on { koncluiLimitPill = def.id } else if koncluiLimitPill == def.id { koncluiLimitPill = nil } }),
            turnOff: { state.toggleIntegration($0) })
        #else
        Text(String(format: String(localized: "settings.slots-used %lld"), Int64(state.activeIntegrations.count)))
            .font(.system(size: 11)).foregroundColor(.secondary)
        #endif
    }

    /// The hint on an Active pills row: plain text, or for an agent whose hooks or plugin are missing, a door to the install.
    @ViewBuilder
    private func koncluiHint(_ text: String, for def: PillDefinition) -> some View {
        #if !APPSTORE
        if let door = KoncluiAgentRows.door(forPill: def.id) {
            koncluiDoor(text, def, door)
        } else {
            Text(text).font(.system(size: 11)).foregroundColor(.secondary)
        }
        #else
        Text(text).font(.system(size: 11)).foregroundColor(.secondary)
        #endif
    }

    #if !APPSTORE
    private func koncluiDoor(_ text: String, _ def: PillDefinition, _ door: KoncluiAgentRows.Door) -> some View {
        let open = koncluiPopoverBinding(def.id, open: $koncluiDoorPill)
        return Button {
            open.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Text(verbatim: text)
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold)).accessibilityHidden(true)
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .popover(isPresented: open, arrowEdge: .bottom) { koncluiDoorPopover(def, door) }
        .accessibilityLabel(Text(verbatim: KoncluiAgentRows.spoken(name: def.name, status: text)))
        .accessibilityHint(Text(verbatim: String(format: String(localized: "konclui.agents.door.hint %@"), def.name)))
        // Installed from the popover: the hint is gone, and the popover must not wait to reopen if it comes back.
        .onDisappear { open.wrappedValue = false }
    }

    private func koncluiDoorPopover(_ def: PillDefinition, _ door: KoncluiAgentRows.Door) -> some View {
        let wiring = koncluiHookWiring(door.block)
        return KoncluiHookDoorPopover(
            name: def.name,
            colorHex: PillColors.color(for: def.id, catalogColor: def.defaultColor, in: state.pillColors),
            target: KoncluiHookTarget(block: door.block) ?? .codex, kind: door.kind,
            installed: wiring?.installed ?? false, showDiff: wiring?.showDiff ?? false, pending: wiring?.pending ?? "",
            pendingInstall: wiring?.pendingInstall ?? true, note: statusMessage,
            preview: { wiring?.start($0) }, confirm: { wiring?.confirm() }, cancel: { wiring?.cancel() })
    }

    /// An agent's own install state and steps, so the door runs the very preview and confirmation of the Agents page.
    private struct KoncluiHookWiring {
        var installed: Bool
        var showDiff: Bool
        var pending: String
        var pendingInstall: Bool
        var start: (_ install: Bool) -> Void
        var confirm: () -> Void
        var cancel: () -> Void
    }

    private func koncluiHookWiring(_ block: KoncluiRecognition.AgentBlock) -> KoncluiHookWiring? {
        switch block {
        case .gemini:
            return KoncluiHookWiring(installed: geminiHooksInstalled, showDiff: showGeminiDiff, pending: pendingGeminiJSON, pendingInstall: geminiPendingInstall,
                                     start: { triggerGeminiPreview(install: $0) }, confirm: { confirmGeminiOp() },
                                     cancel: { showGeminiDiff = false; pendingGeminiJSON = "" })
        case .antigravity:
            return KoncluiHookWiring(installed: agyHooksInstalled, showDiff: showAgyDiff, pending: pendingAgyJSON, pendingInstall: agyPendingInstall,
                                     start: { triggerAgyPreview(install: $0) }, confirm: { confirmAgyOp() },
                                     cancel: { showAgyDiff = false; pendingAgyJSON = "" })
        case .codex:
            return KoncluiHookWiring(installed: codexHooksInstalled, showDiff: showCodexDiff, pending: pendingCodexJSON, pendingInstall: codexPendingInstall,
                                     start: { triggerCodexPreview(install: $0) }, confirm: { confirmCodexOp() },
                                     cancel: { showCodexDiff = false; pendingCodexJSON = "" })
        case .copilot:
            return KoncluiHookWiring(installed: copilotHooksInstalled, showDiff: showCopilotDiff, pending: pendingCopilotJSON, pendingInstall: copilotPendingInstall,
                                     start: { triggerCopilotPreview(install: $0) }, confirm: { confirmCopilotOp() },
                                     cancel: { showCopilotDiff = false; pendingCopilotJSON = "" })
        case .muse:
            return KoncluiHookWiring(installed: museHooksInstalled, showDiff: showMuseDiff, pending: pendingMuseJSON, pendingInstall: musePendingInstall,
                                     start: { triggerMusePreview(install: $0) }, confirm: { confirmMuseOp() },
                                     cancel: { showMuseDiff = false; pendingMuseJSON = "" })
        case .opencode:
            return KoncluiHookWiring(installed: openCodePluginInstalled, showDiff: showOpenCodeDiff, pending: pendingOpenCodeContent, pendingInstall: openCodePendingInstall,
                                     start: { triggerOpenCodePreview(install: $0) }, confirm: { confirmOpenCodeOp() },
                                     cancel: { showOpenCodeDiff = false; pendingOpenCodeContent = "" })
        case .amp:
            return KoncluiHookWiring(installed: ampPluginInstalled, showDiff: showAmpDiff, pending: pendingAmpContent, pendingInstall: ampPendingInstall,
                                     start: { triggerAmpPreview(install: $0) }, confirm: { confirmAmpOp() },
                                     cancel: { showAmpDiff = false; pendingAmpContent = "" })
        case .hermes:
            return KoncluiHookWiring(installed: hermesPluginInstalled, showDiff: showHermesPluginDiff, pending: pendingHermesPluginContent, pendingInstall: hermesPluginPendingInstall,
                                     start: { triggerHermesPluginPreview(install: $0) }, confirm: { confirmHermesPluginOp() },
                                     cancel: { showHermesPluginDiff = false; pendingHermesPluginContent = "" })
        case .claudeCode, .claudeDesktop, .plan:
            return nil
        }
    }
    #endif

    /// DEBUG screenshots: `-konclui.debug.agentPopover <id>:preview` (or `:remove`) builds that agent's install (or removal)
    /// preview (a read; nothing is written).
    private func koncluiDebugPreview() {
        #if DEBUG
        guard let target = KoncluiAgentsDebug.target, target.preview || target.removal else { return }
        if target.id == KoncluiRecognition.AgentBlock.claudeCode.rawValue {
            if target.removal { uninstallHooks() } else { installHooks() }
            return
        }
        #if !APPSTORE
        if let block = KoncluiRecognition.AgentBlock(rawValue: target.id) { koncluiHookWiring(block)?.start(!target.removal) }
        #endif
        #endif
    }

    // MARK: What Koncluí wrote (KoncluiHookStatus.swift)

    /// The agent's popover content: the state, the one primary it needs, the review before anything is written.
    @ViewBuilder
    private func koncluiHookControls(_ target: KoncluiHookTarget, installed: Bool, outdated: Bool = false, show: Bool,
                                     pending: String, pendingInstall: Bool, preview: @escaping (Bool) -> Void,
                                     confirm: @escaping () -> Void, cancel: @escaping () -> Void) -> some View {
        #if !APPSTORE
        KoncluiHookControls(target: target, name: target.name, installed: installed, outdated: outdated, showDiff: show,
                            pending: pending, pendingInstall: pendingInstall, preview: preview, confirm: confirm, cancel: cancel)
        #endif
    }

    /// The last read of the Mac, copied into the installed flags the install and removal steps keep up to date.
    private func koncluiApplyHooks(_ snap: KoncluiHookSnapshot) {
        hookNeedsUpdate = snap.claudeOutdated
        claudeHooksInstalled = snap.isInstalled(.claudeCode)
        koncluiTools = snap.tools
        #if !APPSTORE
        geminiHooksInstalled = snap.isInstalled(.gemini)
        agyHooksInstalled = snap.isInstalled(.antigravity)
        codexHooksInstalled = snap.isInstalled(.codex)
        copilotHooksInstalled = snap.isInstalled(.copilot)
        museHooksInstalled = snap.isInstalled(.muse)
        openCodePluginInstalled = snap.isInstalled(.opencode)
        ampPluginInstalled = snap.isInstalled(.amp)
        hermesPluginInstalled = snap.isInstalled(.hermes)
        #endif
    }

    /// Any install or removal flips one of these: the snapshot (Active pills' hints, Geral's card) reads the Mac again.
    private var koncluiInstalledFlags: [Bool] {
        #if APPSTORE
        [claudeHooksInstalled]
        #else
        [claudeHooksInstalled, geminiHooksInstalled, agyHooksInstalled, codexHooksInstalled, copilotHooksInstalled,
         museHooksInstalled, openCodePluginInstalled, ampPluginInstalled, hermesPluginInstalled]
        #endif
    }

    /// Agents found on this Mac and not connected yet (a DEBUG launch argument can name some, for screenshots).
    private var koncluiWaitingAgents: [KoncluiHookTarget] { KoncluiPageDebug.waiting ?? koncluiHooks.snapshot.waiting }

    private var koncluiAnyAgentConnected: Bool { KoncluiPageDebug.connected ?? koncluiHooks.snapshot.anyConnected }

    /// "Connect agents" on Geral: the Agents page, in the hub window or in the standalone Settings.
    private func koncluiOpenAgentsPage() {
        #if !APPSTORE
        if embeddedSection != nil {
            FlowHubController.shared.router.page = HubPage.forSettings("agents")
            return
        }
        #endif
        selectedSection = "agents"
    }

    // MARK: Chat

    /// A key is saved (key-based providers) or a server is connected (local ones).
    private func koncluiChatConfigured(_ provider: ChatProvider) -> Bool {
        if provider == .ollama { return !state.ollamaServerURL.isEmpty }
        if provider == .lmstudio { return !state.lmstudioServerURL.isEmpty }
        return !provider.keychainKey.isEmpty && !(KeychainStore.shared.get(provider.keychainKey) ?? "").isEmpty
    }

    /// A provider's block shows when it is configured, when a local server answers, or when it was added.
    private func koncluiChatShown(_ provider: ChatProvider) -> Bool {
        koncluiChatConfigured(provider)
            || (provider.isLocal && chatAccess.status(provider).isReady)
            || koncluiAdded.contains(.chat, provider.rawValue)
    }

    /// Whether a key-based provider listed after `provider` shows: the divider under `provider` is only for it.
    private func koncluiChatShownAfter(_ provider: ChatProvider) -> Bool {
        guard let i = Self.koncluiKeyProviders.firstIndex(of: provider) else { return false }
        return Self.koncluiKeyProviders[(i + 1)...].contains(where: koncluiChatShown)
    }
}
