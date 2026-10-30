#if !APPSTORE
import SwiftUI
import AppKit
import CoreImage.CIFilterBuiltins

// Koncluí: Settings → Integrations → WhatsApp, as version 8 of design/konclui/whatsapp ("one line, with an options
// popover") plus version 7's live notch preview on top. It replaces WhatsAppSettingsSection (WhatsAppViews.swift, left as
// upstream has it) and keeps every option of it:
//   - connected, the block is one calm line (status, number, gateway) with an "Options" popover for the daily options;
//   - not set up, installing, waiting for the QR scan and a failed install expand in place as a card, and collapse back to
//     the line once connected; a stopped gateway adds its panel under the line;
//   - the unofficial-integration warning shows before the install, then lives behind the "Experimental" tag.
// Which shape shows is KoncluiWABlock.stage (KoncluiWhatsAppModel.swift, tested); the preview is KoncluiWhatsAppPreview.swift.
// The rules of docs/konclui/UX.md apply: the number and the ignored chats are doors, every click that changes data can be
// undone, a control that cannot act says why beside it, and the clickable views show the pointing hand.

struct KoncluiWhatsAppSection: View {
    @ObservedObject private var wa = WhatsAppController.shared
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var installer = WhatsAppGOWAInstaller.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // What WhatsAppSettingsSection kept.
    @State private var enabled = WhatsAppSettings.enabled
    @State private var gateway = WhatsAppSettings.gateway
    @State private var url = KeychainStore.shared.get(WhatsAppSettings.urlKey) ?? ""
    @State private var credential = KeychainStore.shared.get(WhatsAppSettings.credentialKey) ?? ""
    @State private var port = String(WhatsAppSettings.port)
    @State private var respectFocus = WhatsAppSettings.respectFocus
    @State private var markReadOnOpen = WhatsAppSettings.markReadOnOpen
    @State private var autoStart = WhatsAppGOWAProcess.autoStart
    @State private var gowaPath = WhatsAppGOWAProcess.binaryPath
    @State private var testResult: String?
    @State private var testing = false
    @State private var ignoreEntry = ""
    /// The gateway and address as saved: the stage follows these, not the fields being edited under Advanced.
    @State private var savedGateway = WhatsAppSettings.gateway
    @State private var savedAddress = KeychainStore.shared.get(WhatsAppSettings.urlKey) ?? ""

    // The block's own.
    @State private var optionsOpen = KoncluiWhatsAppDebug.popover != nil
    @State private var showIgnored = KoncluiWhatsAppDebug.popover == .ignored
    @State private var showAdvanced = KoncluiWhatsAppDebug.popover == .advanced
    @State private var showPrivacy = false
    @State private var showWarning = false
    @State private var simulateFocus = false
    @State private var ignoreMessage: String?
    @FocusState private var ignoreFocused: Bool
    @State private var undoNotice: UndoNotice?
    /// Screenshots only (KoncluiWhatsAppDebug): the options and ignored chats of a simulated block never reach the settings.
    @State private var simulatedMute = true
    @State private var simulatedIgnored = KoncluiWhatsAppDebug.sampleIgnored

    private static let amber = Color(hex: "#F5B83D")
    private static let red = Color(hex: "#F4505E")
    private static let muted = Color(hex: "#8E939C")
    private static let ink = Color(hex: "#F5F6F8")
    private static let body = Color(hex: "#C7CBD2")

    /// What "Undo" does for the last change, for ten seconds (UX.md, 1.5).
    private struct UndoNotice: Identifiable {
        let id = UUID()
        let text: String
        let undo: @MainActor () -> Void
    }

    // MARK: - What the block is in

    private var simulated: Bool { KoncluiWhatsAppDebug.override != nil }

    private var inputs: KoncluiWAInputs {
        if let override = KoncluiWhatsAppDebug.override { return override.inputs }
        return KoncluiWAInputs(
            enabled: enabled,
            hasRoom: appState.activeIntegrations.contains(WhatsAppController.pillId),
            gateway: savedGateway,
            installed: WhatsAppGOWAInstaller.isInstalled,
            addressSet: !savedAddress.isEmpty,
            install: KoncluiWAInstallPhase(installer.step),
            link: KoncluiWALink(wa.link))
    }

    private var me: String? { KoncluiWhatsAppDebug.override?.me ?? wa.me }
    private var installedVersion: String? { KoncluiWhatsAppDebug.override?.gatewayVersion ?? WhatsAppGOWAInstaller.installedVersion }

    var body: some View {
        let inputs = self.inputs
        let stage = KoncluiWABlock.stage(inputs)
        let link: KoncluiWALink = inputs.enabled && inputs.hasRoom ? inputs.link : .off
        let options = KoncluiWAPreviewOptions(muteGroups: muteGroups.wrappedValue, respectFocus: respectFocus,
                                              focusOn: simulateFocus, markReadOnOpen: markReadOnOpen)
        VStack(alignment: .leading, spacing: 10) {
            KoncluiWhatsAppPreview(link: link, options: options, copy: sampleCopy, simulateFocus: $simulateFocus)

            if stage.isSetup { setupCard(stage, inputs) } else { line(stage, inputs) }

            if case .problem(let problem) = stage { problemPanel(problem) }
            if stage == .connected, let note = webhookProblem { notice(note, color: Self.amber) }
            if inputs.enabled && !inputs.hasRoom {
                notice(String(localized: "whatsapp.no-slot"), color: Self.red)
            }
            if let undoNotice, !optionsOpen { undoBar(undoNotice) }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: stage)
        .onChange(of: stage) { old, new in
            // Leaving the install shows the warning behind its tag; an update from the popover shows its steps in the card.
            if old == .install { showWarning = false }
            if case .installing = new { optionsOpen = false }
            AccessibilityNotification.Announcement(spokenStatus(new)).post()
        }
        .onChange(of: installer.step) { _, step in
            // Installed by Koncluí: the fields follow what it set.
            if case .done = step {
                gateway = .gowa
                url = ""
                autoStart = true
                gowaPath = WhatsAppGOWAProcess.binaryPath
                savedGateway = .gowa
                savedAddress = ""
            }
        }
        .onChange(of: gateway) { old, new in
            // Still on the other gateway's default address: follow the switch.
            if url.isEmpty || url == old.defaultURL { url = new.defaultURL }
        }
        .onChange(of: ignoreEntry) { _, _ in ignoreMessage = nil }
        .task(id: undoNotice?.id) {
            guard let id = undoNotice?.id else { return }
            try? await Task.sleep(for: .seconds(10))
            if undoNotice?.id == id { undoNotice = nil }
        }
    }

    // MARK: - The line

    private func line(_ stage: KoncluiWAStage, _ inputs: KoncluiWAInputs) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // The number never truncates (UX.md, 8): when the row is tight, "Connected as" goes first, then the
            // switch's label. Other stages keep one row whose status text may be cut (its tooltip has it whole).
            if stage == .connected {
                ViewThatFits(in: .horizontal) {
                    lineRow(stage, prefix: true, switchLabel: true)
                    lineRow(stage, prefix: false, switchLabel: true)
                    lineRow(stage, prefix: false, switchLabel: false)
                }
            } else {
                lineRow(stage, prefix: true, switchLabel: true)
            }
            if showWarning { warning.padding([.horizontal, .bottom], 12) }
        }
        .background(cardBackground)
        // The whole row opens the options (UX.md, 1.2); the Options button is the keyboard's way in.
        .contentShape(Rectangle())
        .onTapGesture { optionsOpen = true }
        .pointerStyle(.link)
    }

    private func lineRow(_ stage: KoncluiWAStage, prefix: Bool, switchLabel: Bool) -> some View {
        HStack(spacing: 10) {
            WhatsAppMark()
            Text(verbatim: "WhatsApp").font(.system(size: 14, weight: .semibold)).fixedSize()
            experimentalTag
            statusText(stage, prefix: prefix)
            Spacer(minLength: 8)
            optionsButton
            if switchLabel {
                Text("konclui.whatsapp.show-in-notch")
                    .font(.system(size: 12))
                    .foregroundColor(Self.muted)
                    .lineLimit(1).fixedSize()
                    .accessibilityHidden(true)
            }
            Toggle("whatsapp.enable", isOn: enabledBinding)
                .toggleStyle(.switch)
                .labelsHidden()
                .help(Text("whatsapp.enable"))
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(minHeight: 50)
    }

    private var experimentalTag: some View {
        Button {
            showWarning.toggle()
        } label: {
            HStack(spacing: 4) {
                Text("konclui.whatsapp.experimental")
                Image(systemName: "info.circle").font(.system(size: 9))
            }
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundColor(Self.amber)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Self.amber.opacity(0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(Self.amber.opacity(0.38)))
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .fixedSize()
        .help(Text("whatsapp.warning"))
        .accessibilityLabel(Text("konclui.whatsapp.experimental"))
        .accessibilityHint(Text("whatsapp.warning"))
    }

    /// The dot and what the line says: the number and the gateway when connected, the status otherwise.
    private func statusText(_ stage: KoncluiWAStage, prefix: Bool) -> some View {
        HStack(spacing: 7) {
            Circle().fill(color(stage.dot)).frame(width: 8, height: 8).accessibilityHidden(true)
            switch stage {
            case .connected:
                if let me {
                    if prefix { Text("konclui.whatsapp.connected-as").foregroundColor(Self.body).lineLimit(1).fixedSize() }
                    KoncluiWhatsAppDoor(jid: me, display: KoncluiPhone.format(me), ignored: false,
                                        simulated: simulated, onStopIgnoring: nil)
                        .lineLimit(1).fixedSize()
                } else {
                    Text(WhatsAppStatus.label(.connected)).foregroundColor(Self.body)
                }
            case .connecting:  Text(WhatsAppStatus.label(.connecting)).foregroundColor(Self.body)
            case .off:         Text("konclui.whatsapp.state.off").foregroundColor(Self.body)
            case .noRoom:      Text("konclui.whatsapp.state.no-room").foregroundColor(Self.body)
            case .problem(let problem):
                Text(problemTitle(problem)).foregroundColor(Self.body)
            default:           EmptyView()
            }
        }
        .font(.system(size: 12.5))
        .lineLimit(1).truncationMode(.tail)
        .help(Text(verbatim: spokenStatus(stage)))
    }

    /// The status in one sentence: for the tooltip of a cut-off line and for VoiceOver when the stage changes.
    private func spokenStatus(_ stage: KoncluiWAStage) -> String {
        switch stage {
        case .connected:     return me.map { connectedPrefix + " " + KoncluiPhone.format($0) } ?? WhatsAppStatus.label(.connected)
        case .connecting:    return WhatsAppStatus.label(.connecting)
        case .off:           return String(localized: "konclui.whatsapp.state.off")
        case .noRoom:        return String(localized: "konclui.whatsapp.state.no-room")
        case .problem(let p): return problemTitle(p)
        default:             return setupStatus(stage)
        }
    }

    private var connectedPrefix: String { String(localized: "konclui.whatsapp.connected-as") }

    private func problemTitle(_ problem: KoncluiWAProblem) -> String {
        switch problem {
        case .stopped:        return WhatsAppStatus.label(.unreachable)
        case .unauthorized:   return WhatsAppStatus.label(.unauthorized)
        case .other(let why): return why
        }
    }

    // MARK: - Options popover

    private var optionsButton: some View {
        Button {
            optionsOpen.toggle()
        } label: {
            HStack(spacing: 4) {
                Text("konclui.whatsapp.options")
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .fixedSize()
        .popover(isPresented: $optionsOpen, arrowEdge: .bottom) { optionsPopover }
        .accessibilityHint(Text("konclui.whatsapp.options.hint"))
    }

    private var optionsPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("konclui.whatsapp.notifications")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundColor(Color(hex: "#A4A9B2"))
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 9) {
                Toggle("whatsapp.mute-groups", isOn: muteGroups)
                Toggle("whatsapp.respect-focus", isOn: $respectFocus)
                    .onChange(of: respectFocus) { _, on in
                        guard !simulated else { return }
                        WhatsAppSettings.respectFocus = on
                        if on { wa.askFocus() }
                    }
                if respectFocus && wa.focusReadable == false {
                    hintKey("whatsapp.focus-unavailable").padding(.leading, 20)
                }
                Toggle("whatsapp.mark-read-on-open", isOn: $markReadOnOpen)
                    .onChange(of: markReadOnOpen) { _, on in
                        guard !simulated else { return }
                        WhatsAppSettings.markReadOnOpen = on
                    }
                hintKey("whatsapp.mark-read.hint").padding(.leading, 20)
            }

            Divider()
            ignoredChats

            Divider()
            gatewayRow

            VStack(alignment: .leading, spacing: 6) {
                privacyLine
                advanced
            }

            if let undoNotice { undoBar(undoNotice) }
        }
        .padding(14)
        .frame(width: 372, alignment: .leading)
    }

    // MARK: - Setup card

    private func setupCard(_ stage: KoncluiWAStage, _ inputs: KoncluiWAInputs) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                WhatsAppMark()
                Text(verbatim: "WhatsApp").font(.system(size: 14, weight: .semibold))
                if stage != .install { experimentalTag }
                Spacer(minLength: 8)
                HStack(spacing: 7) {
                    Circle().fill(color(stage.dot)).frame(width: 8, height: 8).accessibilityHidden(true)
                    Text(setupStatus(stage)).foregroundColor(Self.body)
                }
                .font(.system(size: 12.5))
                .lineLimit(1)
                .accessibilityElement(children: .combine)
            }
            if stage == .install || showWarning { warning.padding(.top, 10) }

            Divider().padding(.vertical, 12)
            setupBody(stage)

            Divider().padding(.vertical, 12)
            VStack(alignment: .leading, spacing: 6) {
                privacyLine
                advanced
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private func setupStatus(_ stage: KoncluiWAStage) -> String {
        switch stage {
        case .install:       return String(localized: "konclui.whatsapp.state.not-set-up")
        case .installing:    return String(localized: "konclui.whatsapp.state.installing")
        case .installFailed: return String(localized: "konclui.whatsapp.state.install-failed")
        default:             return String(localized: "konclui.whatsapp.state.waiting-qr")
        }
    }

    @ViewBuilder private func setupBody(_ stage: KoncluiWAStage) -> some View {
        switch stage {
        case .install:
            installCall(failure: nil)
        case .installFailed(let why):
            installCall(failure: why)
        case .installing(let step):
            installSteps(step)
        default:
            qrPanel
        }
    }

    /// One click: Koncluí downloads the gateway, checks it and starts it, and turns the integration on. No Terminal.
    /// A failure says what happened (the installer's own sentence), what it means and what to press.
    private func installCall(failure: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let failure {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: "exclamationmark.triangle").font(.system(size: 11)).padding(.top, 1)
                        Text(verbatim: failure).fixedSize(horizontal: false, vertical: true)
                    }
                    Text("konclui.whatsapp.install-failed.impact")
                        .foregroundColor(Color(hex: "#C9A0A5"))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 18)
                }
                .font(.system(size: 11.5))
                .foregroundColor(Color(hex: "#FF8E98"))
                .accessibilityElement(children: .combine)
            }
            hintKey("konclui.whatsapp.install.plain")
            Button {
                install()
            } label: {
                if failure == nil {
                    Label("whatsapp.install", systemImage: "arrow.down.circle.fill")
                } else {
                    Label("konclui.whatsapp.install-again", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func installSteps(_ current: Int) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(0..<KoncluiWABlock.installSteps, id: \.self) { step in
                HStack(spacing: 9) {
                    Group {
                        if step < current {
                            Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(Color(hex: "#22C55E"))
                        } else if step == current {
                            ProgressView().controlSize(.small).scaleEffect(0.7)
                        } else {
                            Circle().strokeBorder(Color(hex: "#6B7079"), lineWidth: 1.5).frame(width: 8, height: 8)
                        }
                    }
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)
                    Text(verbatim: installLabel(step))
                        .font(.system(size: 12.5))
                        .foregroundColor(step == current ? Self.ink : Self.muted)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: installLabel(step)))
                .accessibilityValue(Text(stepState(step, current: current)))
            }
            hint(String(format: String(localized: "konclui.whatsapp.install.step %lld"), Int64(min(current + 1, KoncluiWABlock.installSteps))))
                .padding(.top, 3)
        }
    }

    private func stepState(_ step: Int, current: Int) -> LocalizedStringKey {
        step < current ? "konclui.whatsapp.step.done" : (step == current ? "konclui.whatsapp.step.now" : "konclui.whatsapp.step.todo")
    }

    private func installLabel(_ step: Int) -> String {
        switch step {
        case 0: return String(localized: "konclui.whatsapp.install.checking")
        case 1:
            if case .downloading(let mb) = inputs.install {
                return String(format: String(localized: "whatsapp.install.downloading %lld"), Int64(mb))
            }
            return String(localized: "konclui.whatsapp.install.downloading")
        case 2: return String(localized: "whatsapp.install.verifying")
        default: return String(localized: "whatsapp.install.installing")
        }
    }

    /// The QR to scan; it shows only while WhatsApp waits for the scan.
    private var qrPanel: some View {
        HStack(alignment: .top, spacing: 16) {
            Group {
                if let image = qrImage {
                    Image(nsImage: image)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 168, height: 168)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .accessibilityLabel(Text("konclui.whatsapp.qr.label"))
                } else {
                    ProgressView().controlSize(.small).frame(width: 168, height: 168)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("konclui.whatsapp.qr.title").font(.system(size: 13, weight: .semibold))
                hintKey("whatsapp.qr.hint")
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).scaleEffect(0.7)
                    Text("konclui.whatsapp.qr.waiting").font(.system(size: 12)).foregroundColor(Self.amber)
                }
                .padding(.top, 4)
            }
        }
    }

    private var qrImage: NSImage? {
        if let data = KoncluiWhatsAppDebug.override != nil ? KoncluiWhatsAppDebug.sampleQR : wa.qrPNG {
            return NSImage(data: data)
        }
        return nil
    }

    // MARK: - Problem panel

    /// What happened is the line above; this says what it means and what to press.
    private func problemPanel(_ problem: KoncluiWAProblem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(Self.red).frame(width: 8, height: 8).padding(.top, 5).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(problemDetail(problem))
                    .font(.system(size: 11.5))
                    .foregroundColor(Color(hex: "#C9A0A5"))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button {
                        retry()
                    } label: {
                        Label("konclui.whatsapp.reconnect", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    Button("konclui.whatsapp.open-advanced") {
                        showAdvanced = true
                        optionsOpen = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Self.red.opacity(0.3)))
        .accessibilityElement(children: .contain)
    }

    private func problemDetail(_ problem: KoncluiWAProblem) -> String {
        switch problem {
        case .stopped:
            // Koncluí restarts a gateway it was told to start; with one of the user's own there is nothing to restart.
            return WhatsAppSettings.gateway == .gowa && WhatsAppGOWAProcess.autoStart
                ? String(localized: "konclui.whatsapp.problem.stopped.auto")
                : String(localized: "konclui.whatsapp.problem.stopped.manual")
        case .unauthorized:
            return String(localized: "konclui.whatsapp.problem.unauthorized.detail")
        case .other:
            return String(localized: "konclui.whatsapp.problem.other.detail")
        }
    }

    // MARK: - Pieces shared by the popover and the card

    private var warning: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 11)).padding(.top, 1).accessibilityHidden(true)
            Text("whatsapp.warning").fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 11.5))
        .foregroundColor(Color(hex: "#F2C15C"))
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Self.amber.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Self.amber.opacity(0.22)))
        .accessibilityElement(children: .combine)
    }

    private var privacyLine: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "lock").font(.system(size: 10)).padding(.top, 2).accessibilityHidden(true)
                Text("konclui.whatsapp.privacy.short")
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(showPrivacy ? LocalizedStringKey("konclui.whatsapp.hide") : LocalizedStringKey("konclui.whatsapp.details")) {
                    showPrivacy.toggle()
                }
                .buttonStyle(.link)
                .pointerStyle(.link)
            }
            .font(.system(size: 11.5))
            .foregroundColor(Self.muted)
            if showPrivacy { hintKey("whatsapp.privacy").padding(.leading, 17) }
        }
    }

    /// The gateway Koncluí installed (or one the user picked), with its update; its live/polling line.
    @ViewBuilder private var gatewayRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            if savedGateway == .gowa && (WhatsAppGOWAInstaller.isInstalled || simulated) {
                HStack(spacing: 8) {
                    Text(verbatim: installedVersion.map { String(format: String(localized: "konclui.whatsapp.gateway-ready %@"), $0) }
                         ?? String(localized: "konclui.whatsapp.gateway-own"))
                        .font(.system(size: 11.5))
                        .foregroundColor(Self.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button("konclui.whatsapp.update-gateway") { install(turnOn: false) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                if case .failed(let why) = installer.step {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: why)
                        Text("konclui.whatsapp.update-failed.impact").foregroundColor(Color(hex: "#C9A0A5"))
                    }
                    .font(.system(size: 10))
                    .foregroundColor(Self.red)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            if inputs.link == .connected { hint(webhookLine) }
        }
    }

    private var ignoredChats: some View {
        DisclosureGroup(isExpanded: $showIgnored) {
            VStack(alignment: .leading, spacing: 6) {
                if ignored.isEmpty {
                    Text("konclui.whatsapp.ignored.empty").font(.system(size: 11.5)).foregroundColor(Self.muted)
                }
                ForEach(ignored) { chat in
                    HStack(spacing: 6) {
                        KoncluiWhatsAppDoor(jid: chat.id, display: chat.name, ignored: true, simulated: simulated,
                                            onStopIgnoring: { stopIgnoring(chat) })
                            .font(.system(size: 11))
                        Spacer()
                        Button("konclui.whatsapp.unignore") { stopIgnoring(chat) }
                            .buttonStyle(.borderless)
                            .font(.system(size: 11))
                            .accessibilityLabel(Text(verbatim: "\(String(localized: "konclui.whatsapp.unignore")) \(chat.name)"))
                    }
                }
                HStack(spacing: 6) {
                    TextField(String(localized: "whatsapp.ignore-placeholder"), text: $ignoreEntry)
                        .textFieldStyle(.roundedBorder)
                        .focused($ignoreFocused)
                        .onSubmit(addIgnored)
                    Button("whatsapp.ignore-chat", action: addIgnored)
                }
                if let ignoreMessage { problemNote(ignoreMessage) }
            }
            .padding(.top, 6)
        } label: {
            HStack(spacing: 6) {
                Text("whatsapp.ignored").font(.system(size: 11, weight: .medium))
                Text(verbatim: "\(ignored.count)").font(.system(size: 11)).foregroundColor(Self.muted).monospacedDigit()
            }
        }
        .disclosureGroupStyle(KoncluiDisclosureStyle())   // the popover is its own window: the hub's style does not reach it
    }

    /// Your own gateway (OpenWA, another address, a password, the port): folded away.
    private var advanced: some View {
        DisclosureGroup(isExpanded: $showAdvanced) {
            VStack(alignment: .leading, spacing: 6) {
                Picker("whatsapp.gateway", selection: $gateway) {
                    ForEach(WAGatewayKind.allCases, id: \.self) { kind in
                        Text(verbatim: kind.name).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                TextField(gateway.defaultURL, text: $url)
                    .textFieldStyle(.roundedBorder)
                if KoncluiWAAdvanced.addressProblem(url) { problemNote(String(localized: "konclui.whatsapp.url.invalid")) }
                SecureField(gateway == .gowa ? String(localized: "whatsapp.credential.gowa")
                                             : String(localized: "whatsapp.credential.openwa"),
                            text: $credential)
                    .textFieldStyle(.roundedBorder)
                if gateway == .gowa { autoStartRow }
                HStack(spacing: 6) {
                    Text("whatsapp.port").font(.system(size: 11))
                    TextField(String(WhatsAppSettings.defaultPort), text: $port)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Spacer()
                }
                if KoncluiWAAdvanced.portProblem(port) { problemNote(String(localized: "konclui.whatsapp.port.invalid")) }

                HStack(spacing: 8) {
                    // One primary action per region: in the setup card that is Install, so Save is plain there.
                    Button("whatsapp.save") { save() }
                        .buttonStyle(.borderedProminent)
                        .tint(optionsOpen ? nil : .gray)
                    Button {
                        testConnection()
                    } label: {
                        // While it runs, the button says so: no silent disabled control.
                        Text(testing ? LocalizedStringKey("konclui.whatsapp.testing") : LocalizedStringKey("whatsapp.test"))
                    }
                    .buttonStyle(.bordered)
                    .disabled(testing)
                    if testing { ProgressView().controlSize(.small) }
                }
                if let testResult {
                    Text(verbatim: testResult)
                        .font(.system(size: 10))
                        .foregroundColor(Self.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 4)
        } label: {
            Text("whatsapp.advanced").font(.system(size: 11, weight: .medium))
        }
        .disclosureGroupStyle(KoncluiDisclosureStyle())
    }

    /// Koncluí starts the gateway itself (GitHub build: the App Store build is sandboxed and never compiles this).
    @ViewBuilder private var autoStartRow: some View {
        Toggle("whatsapp.autostart", isOn: $autoStart)
            .onChange(of: autoStart) { _, on in
                guard !simulated else { return }
                WhatsAppGOWAProcess.autoStart = on
                wa.settingsChanged()
            }
        if autoStart {
            HStack(spacing: 6) {
                TextField(String(localized: "whatsapp.autostart.path"), text: $gowaPath)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { savePath() }
                Button("whatsapp.choose") { chooseBinary() }
            }
            hintKey("whatsapp.autostart.hint")
        }
    }

    // MARK: - Small views

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.045))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
    }

    /// A hint from the catalog. Named apart from `hint(_:)` so a string literal never lands on the verbatim one.
    private func hintKey(_ key: LocalizedStringKey) -> some View {
        Text(key).font(.system(size: 10)).foregroundColor(Self.muted).fixedSize(horizontal: false, vertical: true)
    }

    private func hint(_ text: String) -> some View {
        Text(verbatim: text).font(.system(size: 10)).foregroundColor(Self.muted).fixedSize(horizontal: false, vertical: true)
    }

    private func notice(_ text: String, color: Color) -> some View {
        Text(verbatim: text)
            .font(.system(size: 10))
            .foregroundColor(color)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 2)
    }

    /// Why a field cannot be used as typed, right under it, with a warning symbol so colour is not the only signal.
    private func problemNote(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: "exclamationmark.triangle").font(.system(size: 9)).padding(.top, 1)
            Text(verbatim: text).fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 10))
        .foregroundColor(Self.amber)
        .accessibilityElement(children: .combine)
    }

    private func undoBar(_ notice: UndoNotice) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.uturn.backward.circle").font(.system(size: 12)).accessibilityHidden(true)
            Text(verbatim: notice.text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button("konclui.whatsapp.undo") {
                notice.undo()
                undoNotice = nil
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .font(.system(size: 11))
        .foregroundColor(Self.body)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
    }

    private func color(_ dot: KoncluiWADot) -> Color {
        switch dot {
        case .green: return Color(hex: "#22C55E")
        case .amber: return Self.amber
        case .red:   return Self.red
        case .gray:  return Color(hex: "#8E939C")
        }
    }

    // MARK: - Settings behind the controls (what WhatsAppSettingsSection did)

    private var enabledBinding: Binding<Bool> {
        Binding(get: { enabled }, set: { setEnabled($0) })
    }

    private var muteGroups: Binding<Bool> {
        simulated ? $simulatedMute
                  : Binding(get: { wa.filters.muteGroups }, set: { wa.filters.muteGroups = $0 })
    }

    /// Switching off stops the gateway and forgets the messages held in memory, so it offers Undo.
    private func setEnabled(_ on: Bool, undoable: Bool = true) {
        enabled = on
        if !simulated { wa.setEnabled(on) }
        if !on && undoable {
            offerUndo(String(localized: "konclui.whatsapp.undo.off")) { setEnabled(true, undoable: false) }
        }
    }

    /// "Install WhatsApp" and "Install again" also turn the integration on; "Update gateway" (in the popover) only downloads the latest.
    private func install(turnOn: Bool = true) {
        guard !simulated else { return }
        if turnOn && !enabled { setEnabled(true) }
        installer.install()
    }

    /// What the Advanced section's save runs after writing: the controller starts over.
    private func retry() {
        guard !simulated else { return }
        wa.settingsChanged()
    }

    private func offerUndo(_ text: String, _ undo: @escaping @MainActor () -> Void) {
        undoNotice = UndoNotice(text: text, undo: undo)
        AccessibilityNotification.Announcement(text).post()
    }

    private var ignored: [KoncluiWhatsAppIgnoredChat] {
        if simulated { return simulatedIgnored }
        return wa.filters.ignored.sorted().map {
            KoncluiWhatsAppIgnoredChat(id: $0, name: wa.inbox.conversations[$0]?.name ?? WAJID.displayNumber($0))
        }
    }

    private func setIgnored(_ chat: String, name: String, _ on: Bool) {
        if simulated {
            simulatedIgnored.removeAll { $0.id == chat }
            if on { simulatedIgnored.append(KoncluiWhatsAppIgnoredChat(id: chat, name: name)) }
        } else if on {
            wa.ignore(chat)
        } else {
            wa.unignore(WAJID.normalized(chat))
        }
    }

    private func stopIgnoring(_ chat: KoncluiWhatsAppIgnoredChat) {
        setIgnored(chat.id, name: chat.name, false)
        offerUndo(String(format: String(localized: "konclui.whatsapp.undo.unignored %@"), chat.name)) {
            setIgnored(chat.id, name: chat.name, true)
        }
    }

    private func addIgnored() {
        switch KoncluiWAIgnore.parse(ignoreEntry) {
        case .empty:
            ignoreMessage = String(localized: "konclui.whatsapp.ignore.empty")
            ignoreFocused = true
        case .invalid:
            ignoreMessage = String(localized: "konclui.whatsapp.ignore.invalid")
            ignoreFocused = true
        case .chat(let chat):
            let name = ignoreEntry.trimmingCharacters(in: .whitespaces)
            setIgnored(chat, name: name, true)
            ignoreEntry = ""
            offerUndo(String(format: String(localized: "konclui.whatsapp.undo.ignored %@"), name)) {
                setIgnored(chat, name: name, false)
            }
        }
    }

    private func chooseBinary() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        gowaPath = url.path
        savePath()
    }

    private func savePath() {
        guard !simulated else { return }
        WhatsAppGOWAProcess.binaryPath = gowaPath.trimmingCharacters(in: .whitespaces)
        wa.settingsChanged()
    }

    /// What Advanced holds as saved, to put back with Undo.
    private struct Saved {
        var gateway: WAGatewayKind
        var url: String
        var credential: String
        var port: Int
        var autoStart: Bool
        var binaryPath: String

        @MainActor static func current() -> Saved {
            Saved(gateway: WhatsAppSettings.gateway,
                  url: KeychainStore.shared.get(WhatsAppSettings.urlKey) ?? "",
                  credential: KeychainStore.shared.get(WhatsAppSettings.credentialKey) ?? "",
                  port: WhatsAppSettings.port,
                  autoStart: WhatsAppGOWAProcess.autoStart,
                  binaryPath: WhatsAppGOWAProcess.binaryPath)
        }
    }

    /// An address that cannot work is not saved (the note under the field says why); a bad port keeps the previous one.
    private func save(undoable: Bool = true) {
        guard !simulated, !KoncluiWAAdvanced.addressProblem(url) else { return }
        let before = Saved.current()
        let trimmedURL = url.trimmingCharacters(in: .whitespaces)
        if trimmedURL.isEmpty { KeychainStore.shared.remove(WhatsAppSettings.urlKey) }
        else { KeychainStore.shared.set(WhatsAppSettings.urlKey, value: trimmedURL) }
        let trimmedCredential = credential.trimmingCharacters(in: .whitespaces)
        if trimmedCredential.isEmpty { KeychainStore.shared.remove(WhatsAppSettings.credentialKey) }
        else { KeychainStore.shared.set(WhatsAppSettings.credentialKey, value: trimmedCredential) }
        WhatsAppSettings.gateway = gateway
        WhatsAppGOWAProcess.binaryPath = gowaPath.trimmingCharacters(in: .whitespaces)
        if !KoncluiWAAdvanced.portProblem(port), let p = Int(port) { WhatsAppSettings.port = p }
        port = String(WhatsAppSettings.port)
        savedGateway = gateway
        savedAddress = trimmedURL
        wa.settingsChanged()
        if undoable {
            offerUndo(String(localized: "konclui.whatsapp.undo.saved")) { restore(before) }
        }
    }

    private func restore(_ saved: Saved) {
        gateway = saved.gateway
        url = saved.url
        credential = saved.credential
        port = String(saved.port)
        autoStart = saved.autoStart
        gowaPath = saved.binaryPath
        WhatsAppGOWAProcess.autoStart = saved.autoStart
        save(undoable: false)
    }

    private func testConnection() {
        guard !simulated, !KoncluiWAAdvanced.addressProblem(url) else { return }
        save(undoable: false)
        testing = true
        Task {
            testResult = await wa.testConnection()
            testing = false
        }
    }

    /// The webhook's state in a sentence (the notch gets messages at once, or the app asks every 20 s).
    private var webhookLine: String {
        switch wa.webhook {
        case .registered:        return String(localized: "whatsapp.webhook.live")
        case .portBusy:          return String(format: String(localized: "whatsapp.webhook.port-busy %lld"), Int64(WhatsAppSettings.port))
        case .refused(let why):  return String(format: String(localized: "whatsapp.webhook.refused %@"), why)
        case .off, .listening:   return String(localized: "whatsapp.webhook.polling")
        }
    }

    /// A webhook that did not come up is a problem worth seeing without opening the popover.
    private var webhookProblem: String? {
        switch wa.webhook {
        case .portBusy, .refused: return webhookLine
        default:                  return nil
        }
    }

    private var sampleCopy: KoncluiWASampleCopy {
        KoncluiWASampleCopy(
            directName: String(localized: "konclui.whatsapp.sample.direct.name"),
            directText: String(localized: "konclui.whatsapp.sample.direct.text"),
            mentionName: String(localized: "konclui.whatsapp.sample.mention.name"),
            mentionSender: String(localized: "konclui.whatsapp.sample.mention.sender"),
            mentionText: String(localized: "konclui.whatsapp.sample.mention.text"),
            groupName: String(localized: "konclui.whatsapp.sample.group.name"),
            groupSender: String(localized: "konclui.whatsapp.sample.group.sender"),
            groupText: String(localized: "konclui.whatsapp.sample.group.text"))
    }
}

// MARK: - Door

/// A number or a chat as a door (UX.md, 1.2): a click opens a small popover with its likely actions, the most likely first.
/// Opening the chat only shows it in WhatsApp; nothing is sent.
struct KoncluiWhatsAppDoor: View {
    let jid: String
    let display: String
    let ignored: Bool
    let simulated: Bool
    let onStopIgnoring: (() -> Void)?

    @State private var open = false
    @State private var message: String?

    var body: some View {
        Button {
            open.toggle()
        } label: {
            Text(verbatim: display).underline(open, color: .secondary)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .popover(isPresented: $open, arrowEdge: .bottom) { actions }
        .accessibilityLabel(Text(verbatim: display))
        .accessibilityHint(Text("konclui.whatsapp.number.hint"))
        .onChange(of: open) { _, _ in message = nil }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: display)
                .font(.system(size: 12, weight: .semibold))
                .padding(.bottom, 4)
            ForEach(KoncluiWADoor.actions(for: jid, ignored: ignored), id: \.self) { action in
                Button { perform(action) } label: {
                    Label(title(action), systemImage: symbol(action)).frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .pointerStyle(.link)
                .padding(.vertical, 3)
            }
            if let message {
                Text(verbatim: message)
                    .font(.system(size: 10.5))
                    .foregroundColor(Color(hex: "#F5B83D"))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(width: 232, alignment: .leading)
    }

    private func title(_ action: KoncluiWADoor.Action) -> LocalizedStringKey {
        switch action {
        case .openChat:     return "konclui.whatsapp.number.open"
        case .copyNumber:   return "konclui.whatsapp.number.copy"
        case .copyChatId:   return "konclui.whatsapp.id.copy"
        case .stopIgnoring: return "konclui.whatsapp.unignore"
        }
    }

    private func symbol(_ action: KoncluiWADoor.Action) -> String {
        switch action {
        case .openChat:                   return "bubble.left"
        case .copyNumber, .copyChatId:    return "doc.on.doc"
        case .stopIgnoring:               return "bell"
        }
    }

    private func perform(_ action: KoncluiWADoor.Action) {
        switch action {
        case .openChat:
            // The sample number of a simulated block must never open a real chat.
            guard !simulated, let url = KoncluiWADoor.chatURL(jid) else { open = false; return }
            guard NSWorkspace.shared.urlForApplication(toOpen: url) != nil else {
                message = String(localized: "konclui.whatsapp.number.unavailable")
                return
            }
            NSWorkspace.shared.open(url)
            open = false
        case .copyNumber, .copyChatId:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(KoncluiWADoor.copyText(jid), forType: .string)
            message = String(localized: "konclui.whatsapp.copied")
            AccessibilityNotification.Announcement(String(localized: "konclui.whatsapp.copied")).post()
        case .stopIgnoring:
            open = false
            onStopIgnoring?()
        }
    }
}

// MARK: - Install phase

extension KoncluiWAInstallPhase {
    init(_ step: WhatsAppGOWAInstaller.Step) {
        switch step {
        case .idle:                  self = .idle
        case .checking:              self = .checking
        case .downloading(let mb):   self = .downloading(megabytes: mb)
        case .verifying:             self = .verifying
        case .installing:            self = .installing
        case .done:                  self = .done
        case .failed(let why):       self = .failed(why)
        }
    }
}

/// WhatsApp's green mark: a speech bubble on a rounded square.
private struct WhatsAppMark: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(Color(hex: whatsAppAccent))
            .frame(width: 24, height: 24)
            .overlay(Image(systemName: "bubble.left.fill").font(.system(size: 12, weight: .semibold)).foregroundColor(.white))
            .accessibilityHidden(true)
    }
}

struct KoncluiWhatsAppIgnoredChat: Identifiable {
    let id: String
    let name: String
}

// MARK: - Screenshots (DEBUG builds only)

/// `-konclui.debug.whatsappState <state>` draws the block in a state it is not in, so a page can be captured without a
/// gateway: fresh, installing, qr, connected, stopped, unauthorized, failed, connecting, off, noroom. The block reads its
/// state from here and nothing else: no setting, no Keychain item and no gateway is touched, and its buttons do nothing
/// but change what the screen shows. `-konclui.debug.whatsappPopover <options|ignored|advanced>` opens the Options popover.
/// In a release build `override` is always nil.
enum KoncluiWhatsAppDebug {
    struct Override {
        var inputs: KoncluiWAInputs
        var me: String?
        var gatewayVersion: String?
    }

    enum Popover: String { case options, ignored, advanced }

    static var override: Override? {
        #if DEBUG
        guard let name = UserDefaults.standard.string(forKey: "konclui.debug.whatsappState") else { return nil }
        var i = KoncluiWAInputs(enabled: true, hasRoom: true, gateway: .gowa, installed: true, addressSet: false,
                                install: .idle, link: .connected)
        switch name {
        case "fresh":        i.enabled = false; i.installed = false; i.link = .off
        case "installing":   i.install = .downloading(megabytes: 15); i.link = .off
        case "qr":           i.link = .needsQR
        case "stopped":      i.link = .unreachable
        case "unauthorized": i.link = .unauthorized
        case "failed":       i.installed = false; i.link = .off
                             i.install = .failed(String(localized: "whatsapp.install.download-failed"))
        case "connecting":   i.link = .connecting
        case "off":          i.enabled = false; i.link = .off
        case "noroom":       i.hasRoom = false; i.link = .off
        default:             break   // connected
        }
        return Override(inputs: i, me: "5511912345678:12@s.whatsapp.net", gatewayVersion: "9.7.0")
        #else
        return nil
        #endif
    }

    static var popover: Popover? {
        #if DEBUG
        UserDefaults.standard.string(forKey: "konclui.debug.whatsappPopover").map { Popover(rawValue: $0) ?? .options }
        #else
        nil
        #endif
    }

    /// The block shows even on a Mac that never set WhatsApp up.
    static var forcesBlock: Bool { override != nil }

    static var sampleIgnored: [KoncluiWhatsAppIgnoredChat] {
        #if DEBUG
        override == nil ? [] : [KoncluiWhatsAppIgnoredChat(id: "5521977771234@s.whatsapp.net", name: "+55 21 97777-1234"),
                                KoncluiWhatsAppIgnoredChat(id: "120363000000000009@g.us", name: "Promo Store X")]
        #else
        []
        #endif
    }

    /// A QR code that encodes nothing real.
    static var sampleQR: Data? {
        #if DEBUG
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data("konclui-debug-sample".utf8)
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else { return nil }
        let rep = NSBitmapImageRep(ciImage: output)
        return rep.representation(using: .png, properties: [:])
        #else
        return nil
        #endif
    }
}
#endif
