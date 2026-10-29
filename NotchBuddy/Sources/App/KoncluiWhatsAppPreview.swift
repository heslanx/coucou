#if !APPSTORE
import SwiftUI

// Koncluí: the live notch preview above the WhatsApp block in Settings. It draws the island's WhatsApp card the way the
// notch does, with sample conversations (KoncluiWAPreview) instead of real ones: no network, no real message, and
// nothing on it can be clicked (a right click on a row would otherwise offer "Ignore this chat" on a sample).
//
// The rows are the notch's own `WhatsAppRow`; the header and the status layout repeat WhatsAppCardView's (that view
// reads the live controller, so it cannot take samples). Keep them in step when upstream changes the card.

struct KoncluiWhatsAppPreview: View {
    let content: KoncluiWAPreviewContent
    @Binding var simulateFocus: Bool

    /// The island's expanded size and where its card and its character sit (IslandConst.viewLayouts[.overview]).
    private static let island = CGSize(width: 640, height: 160)
    private static let scale: CGFloat = 0.72
    private static let accent = Color(hex: whatsAppAccent)

    private var samples: [KoncluiWASample]? {
        if case .samples(let samples) = content { return samples }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "#2A3050"), Color(hex: "#171A2A"), Color(hex: "#10121C")],
                                         startPoint: .top, endPoint: .bottom))
                RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.08))
                notch
                    .frame(width: Self.island.width, height: Self.island.height)
                    .scaleEffect(Self.scale, anchor: .top)
                    .frame(width: Self.island.width * Self.scale, height: Self.island.height * Self.scale, alignment: .top)
                    .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("konclui.whatsapp.preview.label"))
                    .accessibilityValue(Text(verbatim: summary))
            }
            .frame(height: Self.island.height * Self.scale + 14)

            if let samples {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("konclui.whatsapp.preview.caption")
                        // The rule behind what is faded, in words (UX.md, habit 10): nothing depends on hovering.
                        if let muted = samples.first(where: \.muted) {
                            Text(String(format: String(localized: "konclui.whatsapp.preview.cause.muted %@"), muted.conversation.name))
                        }
                    }
                    .font(.system(size: 10.5))
                    .foregroundColor(Color(hex: "#8E939C"))
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Toggle(isOn: $simulateFocus) {
                        Label("konclui.whatsapp.preview.focus-chip", systemImage: "moon.fill")
                            .font(.system(size: 11))
                    }
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .pointerStyle(.link)
                }
                .padding(.horizontal, 2)
            }
        }
    }

    /// What the preview says in words, for VoiceOver.
    private var summary: String {
        switch content {
        case .samples(let samples):
            let muted = String(localized: "konclui.whatsapp.preview.muted")
            return samples.map { $0.muted ? "\($0.conversation.name) (\(muted))" : $0.conversation.name }.joined(separator: ", ")
        case .status(let link):
            return WhatsAppStatus.label(link.real)
        }
    }

    // MARK: - The notch

    private var notch: some View {
        ZStack(alignment: .topLeading) {
            UnevenRoundedRectangle(bottomLeadingRadius: IslandConst.expandedCorner,
                                   bottomTrailingRadius: IslandConst.expandedCorner)
                .fill(Color.black)
            card
                .frame(width: Self.island.width - 20, height: 98, alignment: .topLeading)
                .offset(x: 10, y: 42)
            KoncluiPreviewKoru()
                .frame(width: 58 / 0.6, height: 58 / 0.6)
                .position(x: 68, y: 101)
        }
        .foregroundColor(Color(hex: "#F5F6F8"))
    }

    @ViewBuilder private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch content {
            case .samples(let samples):
                header(unread: KoncluiWAPreview.unread(samples))
                if samples.contains(where: \.quiet) { focusNote }
                list(samples)
            case .status(let link):
                header(unread: 0)
                status(link)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 4)
    }

    private func header(unread: Int) -> some View {
        HStack(spacing: 6) {
            Circle().fill(Self.accent).frame(width: 7, height: 7)
            Text(verbatim: "WhatsApp")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#F5F6F8"))
            if unread > 0 {
                Text(String(format: String(localized: "%lld unread"), Int64(unread)))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Self.accent)
                    .monospacedDigit()
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Self.accent.opacity(0.14))
                    .clipShape(Capsule())
            }
            Spacer(minLength: 2)
        }
        .padding(.top, 6)
        .padding(.leading, 108)
        .padding(.trailing, 36)
    }

    private var focusNote: some View {
        HStack(spacing: 5) {
            Image(systemName: "moon.fill").font(.system(size: 9))
            Text("konclui.whatsapp.preview.focus-note").font(.system(size: 10))
        }
        .foregroundColor(Color(hex: "#F5B83D"))
        .padding(.top, 5)
        .padding(.leading, 108)
    }

    private func list(_ samples: [KoncluiWASample]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(samples) { sample in
                ZStack(alignment: .trailing) {
                    WhatsAppRow(conversation: sample.conversation)
                        .opacity(sample.muted ? 0.4 : 1)
                    if sample.muted {
                        Text("konclui.whatsapp.preview.muted")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: "#8E939C"))
                            .padding(.horizontal, 4)
                            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color(hex: "#3A3D44")))
                            .background(Color.black)
                            .padding(.trailing, 6)
                    }
                }
            }
        }
        .padding(.top, 5)
        .padding(.leading, 108)
        .padding(.trailing, 12)
    }

    private func status(_ link: KoncluiWALink) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle().fill(WhatsAppStatus.dot(link.real)).frame(width: 5, height: 5)
                Text(WhatsAppStatus.label(link.real))
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#6B7079"))
                    .lineLimit(1).truncationMode(.tail)
            }
            Text("Settings…")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#8E939C"))
        }
        .padding(.top, 8)
        .padding(.leading, 108)
    }
}

/// The notch's character in the WhatsApp pill's green, drawn once and still (no timeline: nothing runs while the
/// Settings window sits open).
private struct KoncluiPreviewKoru: View {
    @StateObject private var engine: BotEngine = {
        let koru = BotEngine()
        koru.bodyColor = cgColorFromHex(whatsAppAccent)
        for _ in 0..<12 { MochiFrameClock.advance(koru) }
        return koru
    }()

    var body: some View {
        Canvas { context, size in
            engine.draw(context: context, size: size)
        }
    }
}

extension KoncluiWALink {
    init(_ link: WhatsAppController.Link) {
        switch link {
        case .off:               self = .off
        case .connecting:        self = .connecting
        case .needsQR:           self = .needsQR
        case .connected:         self = .connected
        case .unreachable:       self = .unreachable
        case .unauthorized:      self = .unauthorized
        case .failed(let why):   self = .failed(why)
        }
    }

    var real: WhatsAppController.Link {
        switch self {
        case .off:               return .off
        case .connecting:        return .connecting
        case .needsQR:           return .needsQR
        case .connected:         return .connected
        case .unreachable:       return .unreachable
        case .unauthorized:      return .unauthorized
        case .failed(let why):   return .failed(why)
        }
    }
}
#endif
