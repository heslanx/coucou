#if !APPSTORE
import SwiftUI
import AppKit

// Koncluí: "Remove Koncluí's integrations" (Geral). Deleting Koncluí leaves hooks in ~/.claude, ~/.klaude, ~/.codex… that point
// to a script that is no longer there, and every agent session then prints a hook error. This takes them back in one place:
// it previews what changes in every file Koncluí wrote (the same preview the installers show), writes nothing until the
// person confirms, and says what happened to each file afterwards. It goes through the installers' own removal steps
// (HookServer.preview…(install: false) and its write or remove), so a file is touched the way it is when removed from
// Settings → Agents: only Koncluí's entries, a dated backup, refused if the file changed since the preview.

// MARK: - The removal steps

@MainActor
enum KoncluiRemovalSteps {
    /// What removing the target would do, without writing: the text the installer shows.
    static func preview(_ target: KoncluiHookTarget) throws -> String {
        let hooks = HookServer.shared
        switch target {
        case .claudeCode:  return try hooks.previewClaudeHooks(install: false)
        case .klaude:      return try hooks.previewClaudeHooks(at: KlaudeHooks.settingsURL(), install: false)
        case .gemini:      return try hooks.previewGeminiHooks(install: false)
        case .antigravity: return try hooks.previewAgyHooks(install: false)
        case .codex:       return try hooks.previewCodexHooks(install: false)
        case .copilot:     return try hooks.previewCopilotHooks(install: false)
        case .muse:        return try hooks.previewMuseHooks(install: false)
        case .opencode:    return try hooks.previewOpenCodePlugin(install: false)
        case .amp:         return try hooks.previewAmpPlugin(install: false)
        case .hermes:      return try hooks.previewHermesPlugin(install: false)
        case .statusLine:  return try hooks.previewStatusLine(install: false)
        }
    }

    /// Writes the removal the last `preview` computed for the target.
    static func write(_ target: KoncluiHookTarget) throws {
        let hooks = HookServer.shared
        switch target {
        case .claudeCode:  try hooks.writeClaudeHooks()
        case .klaude:      try hooks.writeClaudeHooks(at: KlaudeHooks.settingsURL())
        case .gemini:      try hooks.writeGeminiHooks()
        case .antigravity: try hooks.writeAgyHooks()
        case .codex:       try hooks.writeCodexHooks()
        case .copilot:     try hooks.writeCopilotHooks()
        case .muse:        try hooks.writeMuseHooks()
        case .opencode:    try hooks.removeOpenCodePlugin()
        case .amp:         try hooks.removeAmpPlugin()
        case .hermes:      try hooks.removeHermesPlugin()
        case .statusLine:  try hooks.writeStatusLine()
        }
    }

    /// The status line's preview is a before and after of its one key, not the file: its words are made here.
    static func statusLineDiff(_ shown: String) -> KoncluiHooksDiff {
        KoncluiHooksDiff(summary: .removes(entries: 1), added: [], removed: KoncluiHooksDiff.lines(shown), othersKept: 0, whole: shown)
    }
}

// MARK: - The model

@MainActor
final class KoncluiRemoval: ObservableObject {
    enum Phase { case idle, reading, review, removing, finished }

    enum Outcome: Equatable {
        case pending
        case nothingToRemove
        case removed
        case failed(String)
    }

    struct Item: Identifiable {
        let target: KoncluiHookTarget
        var diff: KoncluiHooksDiff?
        var outcome: Outcome = .pending
        var id: KoncluiHookTarget { target }
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var items: [Item] = []

    /// Reads every file and previews its removal. Nothing is written.
    func load(_ targets: [KoncluiHookTarget]) {
        phase = .reading
        items = targets.map { Item(target: $0) }
        for index in items.indices {
            let target = items[index].target
            do {
                let shown = try KoncluiRemovalSteps.preview(target)
                items[index].diff = target == .statusLine
                    ? KoncluiRemovalSteps.statusLineDiff(shown)
                    : KoncluiHooksDiff.compute(original: try? String(contentsOf: target.url(), encoding: .utf8), pending: shown)
            } catch let e as NSError where e.domain == "CoucouNoop" {
                items[index].outcome = .nothingToRemove
            } catch {
                items[index].outcome = .failed(error.localizedDescription)
            }
        }
        phase = .review
    }

    /// What the confirmation button will remove: the files that can be.
    var removable: [KoncluiHookTarget] { items.filter { $0.outcome == .pending }.map(\.target) }

    /// Removes each file's Koncluí part. A file shared by two targets (Claude Code's hooks and its status line) is read
    /// again before each write, so the second write expects what the first one left.
    func removeAll() {
        phase = .removing
        for index in items.indices where items[index].outcome == .pending {
            let target = items[index].target
            do {
                _ = try KoncluiRemovalSteps.preview(target)
                try KoncluiRemovalSteps.write(target)
                items[index].outcome = .removed
            } catch let e as NSError where e.domain == "CoucouNoop" {
                items[index].outcome = .nothingToRemove
            } catch {
                items[index].outcome = .failed(error.localizedDescription)
            }
        }
        phase = .finished
    }

    func reset() {
        phase = .idle
        items = []
    }
}

// MARK: - The row and its popover

struct KoncluiRemoveIntegrations: View {
    let snapshot: KoncluiHookSnapshot
    let done: () -> Void

    @StateObject private var removal = KoncluiRemoval()
    @State private var open = false

    var body: some View {
        GroupBox(String(localized: "konclui.remove.title")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: String(localized: "konclui.remove.about"), Int64(snapshot.removable.count)))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(String(localized: "konclui.remove.open")) { open = true }
                    .buttonStyle(.koncluiSecondary)
                    .popover(isPresented: $open, arrowEdge: .bottom) { popover }
            }
            .padding(6)
        }
        .onChange(of: open) { _, on in
            if on { removal.load(snapshot.removable) } else if removal.phase == .finished { done() ; removal.reset() } else { removal.reset() }
        }
        .onAppear {
            #if DEBUG
            // `-konclui.debug.removeIntegrations YES` opens the popover with every preview built (it reads, never writes).
            if UserDefaults.standard.bool(forKey: "konclui.debug.removeIntegrations") { open = true }
            #endif
        }
    }

    private var popover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("konclui.remove.heading")
                .font(.system(size: 13, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            switch removal.phase {
            case .idle, .reading:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("konclui.hooks.diff.reading").font(.system(size: 11.5)).foregroundColor(.secondary)
                }
            case .review, .removing, .finished:
                list
                footer
            }
        }
        .padding(14)
        .frame(width: 430, alignment: .leading)
        .koncluiTheme()   // a popover is its own window: the hub's buttons do not reach it
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(removal.items) { item in KoncluiRemovalRow(item: item) }
            }
        }
        // About one row per file, up to 300 pt, then it scrolls (a ScrollView has no height of its own inside a popover).
        .frame(height: min(300, CGFloat(removal.items.count) * 56 + 4))
    }

    @ViewBuilder private var footer: some View {
        switch removal.phase {
        case .finished:
            Text("konclui.remove.done").font(.system(size: 11.5)).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(String(localized: "konclui.remove.close")) { open = false }
                .buttonStyle(.koncluiPrimary)
        case .removing:
            ProgressView().controlSize(.small)
        default:
            Text("konclui.remove.note").font(.system(size: 11)).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button(String(format: String(localized: "konclui.remove.confirm"), Int64(removal.removable.count))) { removal.removeAll() }
                    .buttonStyle(.koncluiPrimary)
                    .disabled(removal.removable.isEmpty)
                Button(String(localized: "Cancel")) { open = false }
                    .buttonStyle(.koncluiSecondary)
            }
        }
    }
}

/// One file: its name and path, then what happens to it (before) or what happened (after).
private struct KoncluiRemovalRow: View {
    let item: KoncluiRemoval.Item

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(verbatim: item.target == .statusLine ? String(localized: "plan.title") : item.target.name)
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 8)
                outcome
            }
            Text(verbatim: item.target.shownPath)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(.secondary)
            if case .failed(let message) = item.outcome {
                Text(verbatim: message).font(.system(size: 11)).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if item.outcome == .pending, let diff = item.diff { changes(diff) }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var outcome: some View {
        switch item.outcome {
        case .pending:         EmptyView()
        case .nothingToRemove: Text("konclui.remove.item.nothing").font(.system(size: 11)).foregroundColor(.secondary)
        case .removed:         Label(String(localized: "konclui.remove.item.removed"), systemImage: "checkmark.circle.fill")
                                   .font(.system(size: 11)).foregroundColor(Color(hex: "#34D399"))
        case .failed:          Label(String(localized: "konclui.remove.item.failed"), systemImage: "exclamationmark.triangle.fill")
                                   .font(.system(size: 11)).foregroundColor(Color(hex: "#F5B83D"))
        }
    }

    @ViewBuilder private func changes(_ diff: KoncluiHooksDiff) -> some View {
        switch diff.summary {
        case .deletes:
            Text(String(format: String(localized: "konclui.hooks.diff.deletes"), item.target.shownPath))
                .font(.system(size: 11)).foregroundColor(.secondary)
        default:
            DisclosureGroup {
                KoncluiChangedLines(added: diff.added, removed: diff.removed)
            } label: {
                Text(verbatim: summary(diff)).font(.system(size: 11.5))
            }
            .disclosureGroupStyle(KoncluiDisclosureStyle())
        }
    }

    private func summary(_ diff: KoncluiHooksDiff) -> String {
        switch diff.summary {
        case .removes(let n): return String(format: String(localized: "konclui.hooks.diff.removes"), Int64(n), item.target.shownPath)
        default:              return String(format: String(localized: "konclui.hooks.diff.updates-file"), item.target.shownPath)
        }
    }
}
#endif
