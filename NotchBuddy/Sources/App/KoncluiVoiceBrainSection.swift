#if !APPSTORE
import SwiftUI

// Koncluí: what sits under "Enable voice command" in Settings → Voice (unit K13). It answers three questions where
// the person looks for them: why the checkbox is greyed out, who understands "OK Koru" right now (and what that means
// for their privacy), and how to let Claude answer open questions. The routing itself is KoncluiVoiceBrain.swift.
struct KoncluiVoiceBrainSection: View {
    /// The page's own state: the microphone and speech recognition are allowed; the wake word is on.
    let permissionsGranted: Bool
    let voiceOn: Bool

    @ObservedObject private var live = KoncluiVoiceBrainLive.shared
    @State private var claudeOn = VoiceSettings.claudeBrainEnabled
    @State private var apiKeySaved = KoncluiVoiceBrainLive.shared.apiKeySaved
    @State private var appleIntelligence = KoncluiVoiceBrainLive.appleIntelligence()

    private var proxyReady: Bool { live.proxyReady }

    private var source: KoncluiVoiceBrain.ClaudeSource? {
        KoncluiVoiceBrain.claudeSource(proxyAvailable: proxyReady, apiKeySaved: apiKeySaved)
    }

    private var brain: KoncluiVoiceBrain.Brain {
        KoncluiVoiceBrain.brain(.init(appleIntelligence: appleIntelligence, claudeEnabled: claudeOn,
                                      proxyAvailable: proxyReady, apiKeySaved: apiKeySaved))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !permissionsGranted && !voiceOn { permissionNotice }
            brainLine
            claudeRow
        }
        .onAppear {
            claudeOn = VoiceSettings.claudeBrainEnabled
            apiKeySaved = live.apiKeySaved
            appleIntelligence = KoncluiVoiceBrainLive.appleIntelligence()
        }
        .task { await live.refreshProxy() }
    }

    // MARK: Why the checkbox is greyed out

    private var permissionNotice: some View {
        let blocked = VoiceSettings.micStatus == .denied || VoiceSettings.speechStatus == .denied
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lock").foregroundColor(.secondary).accessibilityHidden(true)
                Text(blocked ? String(localized: "konclui.voice.permission.denied")
                             : String(localized: "konclui.voice.permission.reason"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if blocked {
                Button(String(localized: "konclui.voice.permission.open-settings")) { openPrivacySettings() }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
            }
        }
    }

    /// The microphone first; speech recognition when the microphone is fine.
    private func openPrivacySettings() {
        let pane = VoiceSettings.micStatus == .denied ? "Privacy_Microphone" : "Privacy_SpeechRecognition"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Who understands you now

    private var brainLine: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: brainSymbol).foregroundColor(.secondary).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(brainTitle).font(.system(size: 12, weight: .semibold))
                ForEach(brainDetails, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var brainSymbol: String {
        switch brain {
        case .appleIntelligence: return "laptopcomputer"
        case .claude:            return "cloud"
        case .phrases:           return "text.bubble"
        }
    }

    private var brainTitle: String {
        switch brain {
        case .appleIntelligence: return String(localized: "konclui.voice.brain.apple")
        case .claude(.proxy):    return String(localized: "konclui.voice.brain.proxy")
        case .claude(.apiKey):   return String(localized: "konclui.voice.brain.key")
        case .phrases:           return String(localized: "konclui.voice.brain.phrases")
        }
    }

    /// The privacy consequence, and for phrases only, how to get a model.
    private var brainDetails: [String] {
        switch brain {
        case .appleIntelligence:
            return [String(localized: "konclui.voice.privacy.local")]
        case .claude(.proxy):
            return [String(localized: "konclui.voice.privacy.proxy")]
        case .claude(.apiKey):
            return [String(localized: "konclui.voice.privacy.key")]
        case .phrases:
            var lines = [String(localized: "konclui.voice.privacy.phrases")]
            switch appleIntelligence {
            case .off:         lines.append(String(localized: "konclui.voice.hint.ai-off"))
            case .unsupported: lines.append(String(localized: "konclui.voice.hint.ai-unsupported"))
            case .available:   break
            }
            return lines
        }
    }

    // MARK: Claude, only when the person asks

    private var claudeRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(String(localized: "konclui.voice.claude.toggle"), isOn: claudeBinding)
                // Without a way to reach Claude the switch has nothing to turn on: the line below says how to get one.
                .disabled(source == nil && !claudeOn)
            claudeCaption
            if claudeOn, let failure = live.lastFailure { failureNotice(failure) }
        }
    }

    private var claudeBinding: Binding<Bool> {
        Binding(get: { claudeOn }, set: { value in
            claudeOn = value
            VoiceSettings.claudeBrainEnabled = value
            // The thread lives in memory only: turning Claude off forgets it.
            if !value { ClaudeVoiceBrain.shared.reset() }
        })
    }

    @ViewBuilder private var claudeCaption: some View {
        if !live.proxyChecked {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(String(localized: "konclui.voice.checking")).font(.system(size: 11)).foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
        } else if let source {
            // What turning it on does, before it is on; once it is on the line above says it.
            if !claudeOn {
                Text(source == .proxy ? String(localized: "konclui.voice.claude.consent-proxy")
                                      : String(localized: "konclui.voice.claude.consent-key"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(String(localized: "konclui.voice.claude.missing"))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(String(localized: "konclui.voice.claude.open-chat")) {
                FlowHubController.shared.show(HubPage.forSettings("chat"))
            }
            .buttonStyle(.link)
            .font(.system(size: 11))
        }
    }

    private func failureNotice(_ failure: KoncluiVoiceBrainLive.Failure) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(KoncluiTheme.attention).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "konclui.voice.claude.failed"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = failure.detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
#endif
