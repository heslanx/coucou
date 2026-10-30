#if !APPSTORE
import SwiftUI

// Koncluí: first run. The core job (seeing and answering Claude Code, Codex and Orca from the notch) needs the agents' hooks,
// and nothing told a person that their agents were found and not connected. This is one calm card that names what was
// found and has one primary that opens Agents; it is gone once everything found is connected (the rules are
// KoncluiGeneralPage in KoncluiPageRules.swift).

struct KoncluiConnectAgentsCard: View {
    let waiting: [KoncluiHookTarget]
    let openAgents: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("konclui.connect.title")
                    .font(.system(size: 13, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: sentence)
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(String(localized: "konclui.connect.action"), action: openAgents)
                .buttonStyle(.koncluiPrimary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
        .accessibilityElement(children: .contain)
    }

    /// "Found on this Mac: Claude Code, Codex and klaude…": the names, at most four.
    private var sentence: String {
        let names = KoncluiGeneralPage.namesInCard(waiting)
        let more = waiting.count > names.count ? "\u{2026}" : ""
        return String(format: String(localized: "konclui.connect.body"), names.joined(separator: ", ") + more)
    }
}

/// The same card on the Dictation home: it reads the Mac itself and opens the Agents page of the router it is given.
struct KoncluiConnectAgentsHome: View {
    @ObservedObject var router: HubRouter
    @ObservedObject private var hooks = KoncluiHookStatus.shared

    var body: some View {
        let waiting = KoncluiPageDebug.waiting ?? hooks.snapshot.waiting
        KoncluiConnectAgentsCard(waiting: waiting, openAgents: { router.page = HubPage.forSettings("agents") })
            .koncluiShown((hooks.loaded || KoncluiPageDebug.waiting != nil) && KoncluiGeneralPage.showsConnectCard(waiting: waiting))
            .onAppear { hooks.refresh() }
    }
}
#endif
