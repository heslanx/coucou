#if !APPSTORE
import AppKit
import SwiftUI

// Koncluí: Undo for a click that changes data (docs/konclui/UX.md 1.5): a notice that says what happened, a button that puts it
// back, ten seconds to use it, reachable with the keyboard. The WhatsApp block shows the bar inline; the Flow pages share one
// center, so the notice survives a move to another page of the window.

/// What "Undo" does for the last change.
struct KoncluiUndoNotice: Identifiable {
    let id = UUID()
    let text: String
    let undo: @MainActor () -> Void
}

struct KoncluiUndoBar: View {
    let notice: KoncluiUndoNotice
    /// On a page, over the content: opaque and a little larger. Inline in a card it keeps the quiet look.
    var floating = false
    /// Called after the undo ran, so the owner of the notice drops it.
    let finished: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.uturn.backward.circle").font(.system(size: 12)).accessibilityHidden(true)
            Text(verbatim: notice.text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button("konclui.undo") {
                notice.undo()
                finished()
            }
            .buttonStyle(.koncluiSecondary)
            .controlSize(.small)
        }
        .font(.system(size: floating ? 12 : 11))
        .foregroundColor(KoncluiTheme.textBody)
        .padding(.horizontal, floating ? 14 : 10).padding(.vertical, floating ? 10 : 7)
        .background(background)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var background: some View {
        if floating {
            RoundedRectangle(cornerRadius: KoncluiRadius.card, style: .continuous).fill(KoncluiTheme.control)
                .overlay(RoundedRectangle(cornerRadius: KoncluiRadius.card, style: .continuous).strokeBorder(Color.white.opacity(0.16)))
                .shadow(color: .black.opacity(0.4), radius: 10, y: 3)
        } else {
            RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.06))
        }
    }
}

/// The notice of the Flow pages: one at a time, the newest wins, gone after ten seconds.
@MainActor
final class KoncluiUndoCenter: ObservableObject {
    static let shared = KoncluiUndoCenter()
    private static let seconds = 10.0

    @Published private(set) var notice: KoncluiUndoNotice?
    private var expiry: Task<Void, Never>?

    func offer(_ text: String, undo: @escaping @MainActor () -> Void) {
        let offered = KoncluiUndoNotice(text: text, undo: undo)
        notice = offered
        AccessibilityNotification.Announcement(text).post()
        expiry?.cancel()
        expiry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.seconds))
            guard !Task.isCancelled, self?.notice?.id == offered.id else { return }
            self?.notice = nil
        }
    }

    func dismiss() {
        expiry?.cancel()
        notice = nil
    }
}

private struct KoncluiUndoBarModifier: ViewModifier {
    @ObservedObject private var center = KoncluiUndoCenter.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomLeading) {
                if let notice = center.notice {
                    KoncluiUndoBar(notice: notice, floating: true) { center.dismiss() }
                        .padding(.horizontal, KoncluiSpace.gutter)
                        .padding(.bottom, 16)
                        .frame(maxWidth: 1100, alignment: .leading)   // the page's own width, so the bar lines up with its cards
                        .transition(reduceMotion ? .identity : .move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: center.notice?.id)
    }
}

extension View {
    /// The Undo notice of the Flow pages, floating at the bottom of this page.
    func koncluiUndoBar() -> some View { modifier(KoncluiUndoBarModifier()) }
}
#endif
