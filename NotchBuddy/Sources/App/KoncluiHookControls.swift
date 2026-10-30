#if !APPSTORE
import SwiftUI
import AppKit

// Koncluí: what an agent's popover holds (Settings → Agents, the "Hooks not installed" door of Active pills, klaude). One
// component for every agent, so the popovers cannot drift apart: the state in a sentence, the one primary that state needs
// (Install when nothing is installed, Update when outdated, none when it is fine), Uninstall as the quiet action once there
// is something to take back, and the review before anything is written: the lines Koncluí adds or removes, the whole file
// behind a disclosure (docs/konclui/UX.md 1.3 habit 5, 2.8; the rules are KoncluiPageRules.swift).
// The agent's own preview and write steps stay SettingsView's: this view only asks for them.

struct KoncluiHookControls: View {
    let target: KoncluiHookTarget
    let name: String
    let installed: Bool
    var outdated = false
    /// A preview is waiting for the person's confirmation.
    let showDiff: Bool
    /// What the installer will write if they confirm.
    let pending: String
    /// The preview is an install (or an update) and not a removal.
    let pendingInstall: Bool
    let preview: (_ install: Bool) -> Void
    let confirm: () -> Void
    let cancel: () -> Void

    @State private var diff: KoncluiHooksDiff?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showDiff { review } else { state }
            KoncluiHookDetails(target: target)
        }
        // The file is read here, off the main thread, to tell what changes from what stays: never in the body.
        .task(id: pending) { await computeDiff() }
    }

    // MARK: The state

    @ViewBuilder private var state: some View {
        let controls = KoncluiHookActions.controls(installed: installed, outdated: outdated)
        Text(verbatim: sentence)
            .koncluiType(.detail)
            .foregroundColor(KoncluiTheme.textBody)
            .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 10) {
            if let primary = controls.primary {
                Button(primaryTitle(primary)) { preview(true) }
                    .buttonStyle(.koncluiPrimary)
            }
            if controls.canUninstall {
                Button(String(localized: "hooks.uninstall")) { preview(false) }
                    .buttonStyle(.koncluiSecondary)
            }
        }
    }

    private var sentence: String {
        if installed {
            return outdated ? String(localized: "konclui.hooks.outdated")
                            : String(format: String(localized: "konclui.hooks.ok"), name)
        }
        let key = target.isPlugin ? "konclui.agents.door.plugin %@" : "konclui.agents.door.hooks %@"
        return String(format: String(localized: String.LocalizationValue(key)), name)
    }

    private func primaryTitle(_ primary: KoncluiHookActions.Primary) -> String {
        switch primary {
        case .install: return target.isPlugin ? String(localized: "plugin.install") : String(localized: "hooks.install")
        case .update:  return String(localized: "hooks.update")
        }
    }

    // MARK: The review

    @ViewBuilder private var review: some View {
        if let diff {
            Text(verbatim: summary(diff))
                .koncluiType(.bodyStrong)
                .foregroundColor(KoncluiTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if diff.othersKept > 0 {
                Text(String(format: String(localized: "konclui.hooks.diff.others"), Int64(diff.othersKept)))
                    .koncluiType(.detail)
                    .foregroundColor(KoncluiTheme.textSecondary)
            }
            KoncluiChangedLines(added: diff.added, removed: diff.removed)
            DisclosureGroup {
                ScrollView {
                    Text(verbatim: diff.whole)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(KoncluiTheme.textBody)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                }
                .frame(height: 140)
                .background(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous).fill(KoncluiTheme.field))
            } label: {
                Text("konclui.hooks.diff.whole").koncluiType(.detail).foregroundColor(KoncluiTheme.textBody)
            }
            .disclosureGroupStyle(KoncluiDisclosureStyle())
            reviewButtons
        } else {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("konclui.hooks.diff.reading").koncluiType(.detail).foregroundColor(KoncluiTheme.textSecondary)
            }
            Button(String(localized: "Cancel"), action: cancel).buttonStyle(.koncluiSecondary)
        }
    }

    private var reviewButtons: some View {
        HStack(spacing: 10) {
            Button(pendingInstall ? String(localized: "konclui.hooks.write") : String(localized: "konclui.hooks.remove"), action: confirm)
                .buttonStyle(.koncluiPrimary)
            Button(String(localized: "Cancel"), action: cancel)
                .buttonStyle(.koncluiSecondary)
        }
    }

    private func summary(_ diff: KoncluiHooksDiff) -> String {
        let path = target.shownPath
        switch diff.summary {
        case .adds(let n):    return String(format: String(localized: "konclui.hooks.diff.adds"), Int64(n), path)
        case .removes(let n): return String(format: String(localized: "konclui.hooks.diff.removes"), Int64(n), path)
        case .updates(let n): return String(format: String(localized: "konclui.hooks.diff.updates"), Int64(n), path)
        case .updatesFile:    return String(format: String(localized: "konclui.hooks.diff.updates-file"), path)
        case .creates:        return String(format: String(localized: "konclui.hooks.diff.creates"), path)
        case .deletes:        return String(format: String(localized: "konclui.hooks.diff.deletes"), path)
        case .nothing:        return String(format: String(localized: "konclui.hooks.diff.nothing"), path)
        }
    }

    private func computeDiff() async {
        guard showDiff, !pending.isEmpty else { diff = nil; return }
        let url = target.url()
        let text = pending
        diff = await Task.detached(priority: .userInitiated) {
            KoncluiHooksDiff.compute(original: try? String(contentsOf: url, encoding: .utf8), pending: text)
        }.value
    }
}

// MARK: - The lines that change

/// Only the lines Koncluí adds or removes: a glyph and a tint, so colour is never the only signal.
struct KoncluiChangedLines: View {
    let added: [String]
    let removed: [String]

    var body: some View {
        if added.isEmpty && removed.isEmpty {
            EmptyView()
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(removed.enumerated()), id: \.offset) { row("\u{2212}", $0.element, KoncluiTheme.error) }
                    ForEach(Array(added.enumerated()), id: \.offset) { row("+", $0.element, KoncluiTheme.ok) }
                }
            }
            // A ScrollView has no height of its own inside a popover: about one row per line, up to 150 pt, then it scrolls.
            .frame(height: min(150, CGFloat(added.count + removed.count) * 16.5 + 2))
            .background(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous).fill(KoncluiTheme.field))
            .clipShape(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous))
        }
    }

    private func row(_ glyph: String, _ line: String, _ tint: Color) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(verbatim: glyph).foregroundColor(tint).frame(width: 10)
            Text(verbatim: line).foregroundColor(KoncluiTheme.textPrimary)
            Spacer(minLength: 0)
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background(tint.opacity(0.12))
    }
}

// MARK: - Details: the file, as a door

/// The path is a detail, not a status (UX.md 2.2): a line inside the popover with the two things a path is for.
struct KoncluiHookDetails: View {
    let target: KoncluiHookTarget
    @State private var copied = false

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: target.shownPath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(KoncluiTheme.textBody)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Button(String(localized: "konclui.hooks.reveal")) { reveal() }
                    Button(copied ? String(localized: "konclui.hooks.copied") : String(localized: "konclui.hooks.copy-path")) { copy() }
                }
                .buttonStyle(.link)
                .koncluiType(.detail)
            }
            .padding(.top, 4)
        } label: {
            Text("konclui.hooks.details").koncluiType(.detail).foregroundColor(KoncluiTheme.textSecondary)
        }
        .disclosureGroupStyle(KoncluiDisclosureStyle())
    }

    /// The file in Finder, or the nearest folder that exists when the file is not there yet (a click always shows something).
    private func reveal() {
        var url = target.url()
        while !FileManager.default.fileExists(atPath: url.path), url.pathComponents.count > 2 {
            url = url.deletingLastPathComponent()
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(target.url().path, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            copied = false
        }
    }
}
#endif
