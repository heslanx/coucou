#if !APPSTORE
import SwiftUI

// Koncluí: what the Notetaker screen says about its speech. Recording never waits for a download, so the screen shows
// the engine in use ("Transcrição do Mac, neste aparelho") as one calm row under Record, and Parakeet as the optional
// upgrade in its popover, with its size and what it adds. UX.md: four states, one primary action (Record), a blocked
// control says why, a row that opens a popover.

/// Under the Record button of the Notetaker: the engine in use, or why Record is blocked.
struct KoncluiNoteSpeechRow: View {
    @ObservedObject private var speech = KoncluiNoteSpeech.shared
    @ObservedObject private var parakeet = Parakeet.shared
    @ObservedObject private var taker = NoteTaker.shared
    @State private var open = false

    var body: some View {
        switch KoncluiNoteSpeech.engine {
        case .apple:
            engineRow
        case .needsDownload:
            // Record is off (an Intel Mac or macOS before 26): the reason stays beside it, as the setup card
            // does on the empty screen.
            if !taker.notes.isEmpty && !taker.isRecording {
                Text("notes.error.models")
                    .font(.system(size: 12))
                    .foregroundColor(HubTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .parakeet:
            EmptyView()
        }
    }

    private var engineRow: some View {
        Button {
            open.toggle()
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: failed ? "exclamationmark.triangle.fill" : "waveform")
                    .font(.system(size: 12))
                    .foregroundColor(failed ? HubTheme.accent : HubTheme.secondary)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text("konclui.notes.speech.title")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(HubTheme.text)
                    if let status {
                        Text(status)
                            .font(.system(size: 11.5))
                            .foregroundColor(failed ? HubTheme.accent : HubTheme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(HubTheme.muted)
                    .padding(.top, 4)
            }
            .multilineTextAlignment(.leading)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(HubTheme.card))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .popover(isPresented: $open, arrowEdge: .bottom) { KoncluiNoteSpeechPopover() }
        .accessibilityHint(Text("konclui.notes.speech.row-hint"))
        .task { speech.refresh() }
    }

    private var failed: Bool {
        if case .failed = speech.readiness { return true }
        return false
    }

    /// One line under the title when something needs saying.
    private var status: String? {
        switch speech.readiness {
        case .missing:
            return String(localized: "konclui.notes.speech.first-time")
        case .installing(let fraction):
            return String(localized: "konclui.notes.speech.installing") + " " + fraction.formatted(.percent.precision(.fractionLength(0)))
        case .failed(let message):
            return message
        case .unknown, .ready, .unsupported:
            return nil
        }
    }
}

/// The row's popover: what the Mac's transcription does, and Parakeet as the optional upgrade.
private struct KoncluiNoteSpeechPopover: View {
    @ObservedObject private var speech = KoncluiNoteSpeech.shared
    @ObservedObject private var parakeet = Parakeet.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(HubTheme.green)
                Text("konclui.notes.speech.title")
                    .font(.system(size: 14, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
            }
            Text("konclui.notes.speech.detail")
                .font(.system(size: 13))
                .foregroundColor(KoncluiTheme.textBody)
                .fixedSize(horizontal: false, vertical: true)
            KoncluiNoteSpeechProgress()
            if parakeet.state != .unsupported {
                HubDivider()
                HubLabel(String(localized: "konclui.notes.speech.upgrade-label"))
                Text("konclui.notes.speech.upgrade-detail")
                    .font(.system(size: 13))
                    .foregroundColor(KoncluiTheme.textBody)
                    .fixedSize(horizontal: false, vertical: true)
                Text("konclui.notes.speech.one-voice")
                    .font(.system(size: 12))
                    .foregroundColor(HubTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                upgrade
            }
        }
        .padding(16)
        .frame(width: 340, alignment: .leading)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var upgrade: some View {
        switch parakeet.state {
        case .missing:
            Button(String(localized: "konclui.notes.speech.download")) { parakeet.download() }
                .buttonStyle(HubButtonStyle())
                .pointerStyle(.link)
        case .downloading(let fraction):
            HStack(spacing: 8) {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .accessibilityLabel(Text("konclui.notes.speech.download-progress"))
                Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                    .font(.system(size: 12))
                    .foregroundColor(HubTheme.secondary)
                    .monospacedDigit()
            }
        case .failed(let message):
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(HubTheme.accent)
                .fixedSize(horizontal: false, vertical: true)
            Button(String(localized: "hub.engine.retry")) { parakeet.download() }
                .buttonStyle(HubButtonStyle())
                .pointerStyle(.link)
        case .ready, .unsupported:
            EmptyView()
        }
    }
}

/// The Mac's language files being installed, or the install that failed: under the live call and in the popover.
struct KoncluiNoteSpeechProgress: View {
    @ObservedObject private var speech = KoncluiNoteSpeech.shared

    var body: some View {
        switch KoncluiNoteSpeech.engine == .apple ? speech.readiness : .ready {
        case .installing(let fraction):
            VStack(alignment: .leading, spacing: 6) {
                Text("konclui.notes.speech.installing")
                    .font(.system(size: 12))
                    .foregroundColor(HubTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 320)
                    .accessibilityLabel(Text("konclui.notes.speech.installing"))
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(HubTheme.accent)
                    .fixedSize(horizontal: false, vertical: true)
                Button(String(localized: "konclui.notes.speech.retry")) { speech.prepare() }
                    .buttonStyle(HubButtonStyle())
                    .pointerStyle(.link)
            }
        case .unknown, .ready, .missing, .unsupported:
            EmptyView()
        }
    }
}
#endif
