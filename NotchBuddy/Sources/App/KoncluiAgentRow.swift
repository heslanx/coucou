import SwiftUI
import AppKit

// Koncluí: the views of Settings → Agents as one calm row each (docs/konclui/UX.md, 1.2 "Door" and the compact row +
// popover pattern of the WhatsApp block). The whole row is the target: a click or the keyboard opens a subtle popover
// that holds the agent's existing install component unchanged (path, Install, Uninstall, the preview, Confirm and write).
// SettingsView wraps each block's content in KoncluiAgentRow in place of its GroupBox; the words, doors and DEBUG flags are
// KoncluiAgentRows.swift (pure, tested).

// MARK: - The row

struct KoncluiAgentRow<Content: View>: View {
    let id: String
    let name: String
    let colorHex: String
    let status: KoncluiAgentRows.Status
    /// What the last action said (a result or an error): it shows at the bottom of the popover, where the person is looking.
    let note: String
    private let openBinding: Binding<Bool>?
    private let content: () -> Content

    @State private var ownOpen: Bool

    /// `isOpen` is the caller's when the same view must know about the popover (SettingsView hides its bottom message
    /// meanwhile); without it the row keeps its own.
    init(id: String, name: String, colorHex: String, status: KoncluiAgentRows.Status, note: String = "",
         isOpen: Binding<Bool>? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.status = status
        self.note = note
        self.openBinding = isOpen
        self.content = content
        _ownOpen = State(initialValue: KoncluiAgentsDebug.opens(id))
    }

    private var open: Binding<Bool> { openBinding ?? $ownOpen }
    private var words: String { String(localized: String.LocalizationValue(status.key)) }

    var body: some View {
        Button {
            open.wrappedValue.toggle()
        } label: {
            HStack(spacing: 10) {
                Circle().fill(Color(hex: colorHex)).frame(width: 10, height: 10).accessibilityHidden(true)
                Text(verbatim: name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                HStack(spacing: 8) {
                    KoncluiAgentStatusLabel(words: words, tone: status.tone, size: 12.5)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
                // The popover points at the status, at the row's trailing end, not at the middle of a wide row.
                .popover(isPresented: open, arrowEdge: .bottom) { popover }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KoncluiAgentCard())
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityValue(Text(verbatim: words))
        .accessibilityHint(Text("konclui.agents.row.hint"))
        .onChange(of: status) { _, new in
            // The install just finished or was undone: say it, as the row's words changed under the person's hands.
            let line = KoncluiAgentRows.spoken(name: name, status: String(localized: String.LocalizationValue(new.key)))
            AccessibilityNotification.Announcement(line).post()
        }
        // A row that leaves the page (the agent is no longer recognized) must not leave a popover waiting to reopen.
        .onDisappear { open.wrappedValue = false }
    }

    private var popover: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: colorHex)).frame(width: 10, height: 10).accessibilityHidden(true)
                Text(verbatim: name)
                    .font(.system(size: 13, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                KoncluiAgentStatusLabel(words: words, tone: status.tone, size: 12)
            }
            Divider()
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
            if !note.isEmpty { KoncluiAgentNote(text: note) }
        }
        .padding(14)
        .frame(width: 400, alignment: .leading)
        #if !APPSTORE
        .koncluiTheme()   // a popover is its own window: the hub's buttons do not reach it
        #endif
    }
}

// MARK: - Door on Active pills

/// What "Hooks not installed" opens on Active pills: the same controls as Settings → Agents (the state, the one primary it
/// needs, the review of what changes), driven by the Agents page's own state (SettingsView passes it in), so a preview
/// started here shows there too, and nothing is written before the person confirms.
struct KoncluiHookDoorPopover: View {
    let name: String
    let colorHex: String
    let target: KoncluiHookTarget
    let kind: KoncluiAgentRows.Kind
    let installed: Bool
    let showDiff: Bool
    let pending: String
    let pendingInstall: Bool
    let note: String
    let preview: (_ install: Bool) -> Void
    let confirm: () -> Void
    let cancel: () -> Void

    var body: some View {
        let status = KoncluiAgentRows.status(kind, installed: installed)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: colorHex)).frame(width: 10, height: 10).accessibilityHidden(true)
                Text(verbatim: name)
                    .font(.system(size: 13, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                KoncluiAgentStatusLabel(words: String(localized: String.LocalizationValue(status.key)), tone: status.tone, size: 12)
            }
            #if !APPSTORE
            KoncluiHookControls(target: target, name: name, installed: installed, showDiff: showDiff, pending: pending,
                                pendingInstall: pendingInstall, preview: preview, confirm: confirm, cancel: cancel)
            #endif
            if !note.isEmpty { KoncluiAgentNote(text: note) }
        }
        .padding(14)
        .frame(width: 400, alignment: .leading)
        #if !APPSTORE
        .koncluiTheme()   // a popover is its own window: the hub's buttons do not reach it
        #endif
    }
}

// MARK: - Small views

/// The status as a symbol and words: colour is never the only signal (UX.md, 6).
private struct KoncluiAgentStatusLabel: View {
    let words: String
    let tone: KoncluiAgentRows.Tone
    let size: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: size - 1.5))
                .foregroundColor(color)
                .accessibilityHidden(true)
            Text(verbatim: words)
                .font(.system(size: size))
                .foregroundColor(tone == .attention ? color : .secondary)
                .lineLimit(1)
        }
    }

    private var symbol: String {
        switch tone {
        case .ready:     return "checkmark.circle.fill"
        case .todo:      return "circle.dashed"
        case .attention: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch tone {
        case .ready:     return Color(hex: "#22C55E")
        case .todo:      return .secondary
        case .attention: return Color(hex: "#F5B83D")
        }
    }
}

/// The result or error of the last action, under the component inside the popover.
private struct KoncluiAgentNote: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 11))
            .foregroundColor(text.hasPrefix("❌") ? Color(hex: "#F4505E") : .secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: text) { _, new in AccessibilityNotification.Announcement(new).post() }
    }
}

/// The calm card of a row, the same fill and edge as the WhatsApp line.
private struct KoncluiAgentCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.primary.opacity(0.045))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
    }
}

extension KoncluiAgentRows {
    /// The colour of an agent's dot: its pill's (the user's own included), else Claude's orange or the neutral grey.
    @MainActor
    static func colorHex(for block: KoncluiRecognition.AgentBlock, custom: [String: String] = PillColors.stored) -> String {
        guard let id = pill(for: block), let def = PillCatalog.definition(for: id) else { return fallbackColor(for: block) }
        return PillColors.color(for: id, catalogColor: def.defaultColor, in: custom)
    }
}

// MARK: - Screenshots (DEBUG builds only)

/// `-konclui.debug.agentPopover <agent id>` (an `AgentBlock` raw value such as `codex`, or `klaude`) opens that row's popover
/// on Settings → Agents, and shows the row even on a Mac without the agent; add `:preview` (`codex:preview`) to build the
/// install preview in it as well, or `:remove` for the removal preview. Opening and previewing only read: no hook file is ever written by the flag. On Active pills
/// the same id opens the door popover of that agent's "not installed" hint. In a release build every answer is nil or false.
enum KoncluiAgentsDebug {
    static var target: KoncluiAgentRows.DebugTarget? {
        #if DEBUG
        KoncluiAgentRows.debugTarget(UserDefaults.standard.string(forKey: "konclui.debug.agentPopover"))
        #else
        nil
        #endif
    }

    static func opens(_ id: String) -> Bool { target?.id == id }

    /// The pill whose door the flag opens, when the agent has one.
    static var doorPill: String? {
        guard let id = target?.id, let block = KoncluiRecognition.AgentBlock(rawValue: id),
              let pill = KoncluiAgentRows.pill(for: block), KoncluiAgentRows.door(forPill: pill) != nil else { return nil }
        return pill
    }

    static var previews: Bool { target?.preview ?? false }

    static var removes: Bool { target?.removal ?? false }
}
