#if !APPSTORE
import SwiftUI

// Koncluí: the two lines the Flow pages show about Claude (unit U7, the interface side of KoncluiClaudeLive.swift). One says what
// to connect when no source can answer a feature and gets the person to the key in one click (UX.md 1.1, "Resolve"); the
// other keeps the last failure of a feature under the switch it belongs to until a call succeeds (UX.md 3, "A fallback is
// told once"). Both observe the live object, so they redraw when klaude is found a moment after launch.

/// "Prompt mode and translation need Claude. Connect your subscription or save an Anthropic key in Chat." and the button to
/// Chat, only while nothing can answer the feature.
struct KoncluiClaudeConnectLine: View {
    let feature: KoncluiClaudeAccess.Feature
    @ObservedObject private var claude = KoncluiClaudeLive.shared

    var body: some View {
        if claude.source(for: feature) == .none {
            HStack(spacing: 10) {
                Image(systemName: "key").foregroundColor(KoncluiTheme.textSecondary).accessibilityHidden(true)
                Text(verbatim: claude.connectLine(for: feature))
                    .koncluiType(.detail)
                    .foregroundColor(KoncluiTheme.textBody)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button(String(localized: "hub.open-settings")) { KoncluiClaudeLive.openChatForKey() }
                    .buttonStyle(HubButtonStyle())
            }
            .accessibilityElement(children: .contain)
        }
    }
}

/// The last call of a feature that failed: what happened, what it means, what to do, and the way to Chat when the person
/// must fix the connection.
struct KoncluiClaudeFailureLine: View {
    let feature: KoncluiClaudeAccess.Feature
    @ObservedObject private var claude = KoncluiClaudeLive.shared

    var body: some View {
        if let report = claude.lastFailure(feature) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(KoncluiTheme.attention)
                    .padding(.top, 1)
                    .accessibilityHidden(true)
                Text(verbatim: report.message)
                    .koncluiType(.detail)
                    .foregroundColor(KoncluiTheme.textBody)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if report.failure.needsChat {
                    Button(String(localized: "hub.open-settings")) { KoncluiClaudeLive.openChatForKey() }
                        .buttonStyle(HubButtonStyle())
                }
            }
            .accessibilityElement(children: .contain)
        }
    }
}

extension KoncluiClaudeLive {
    /// Chat shows the Anthropic key block only once a key is saved or the block was added, so the click that sends the
    /// person there adds it first: they land on the field, not on a page without one (A1-03, A3-10).
    static func openChatForKey() {
        KoncluiAddedModel.shared.add(.chat, ChatProvider.anthropic.rawValue)
        NotificationCenter.default.post(name: .openFullSettings, object: "chat")
    }
}
#endif
