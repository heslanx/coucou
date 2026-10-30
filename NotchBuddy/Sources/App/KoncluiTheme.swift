#if !APPSTORE
import AppKit
import SwiftUI

// Koncluí: one design system for the hub window (docs/konclui/UX.md, "Visual system"). The numbers are KoncluiThemeCore.swift
// (tested); this file turns them into colours, type roles and the controls the window shares. FlowHub.swift injects the
// styles once at its root (`koncluiTheme()`), so a merge that brings upstream's SettingsView back keeps the look: the notch
// pages' GroupBoxes, Toggles and buttons follow without being rewritten. The standalone Settings window and popovers are
// other windows: they do not get the hub styles unless they ask (`koncluiTheme()` on the popover's content).

// MARK: - Tokens

enum KoncluiTheme {
    static let canvas = Color(hex: KoncluiPalette.canvas)
    static let panel = Color(hex: KoncluiPalette.panel)
    static let card = Color(hex: KoncluiPalette.card)
    static let field = Color(hex: KoncluiPalette.field)
    static let control = Color(hex: KoncluiPalette.control)

    static let textPrimary = Color(hex: KoncluiPalette.textPrimary)
    static let textBody = Color(hex: KoncluiPalette.textBody)
    static let textSecondary = Color(hex: KoncluiPalette.textSecondary)
    static let textTertiary = Color(hex: KoncluiPalette.textTertiary)

    static let accent = Color(hex: KoncluiPalette.accent)
    static let onAccent = Color(hex: KoncluiPalette.onAccent)
    static let selection = Color(hex: KoncluiPalette.selection)

    static let ok = Color(hex: KoncluiPalette.ok)
    static let attention = Color(hex: KoncluiPalette.attention)
    static let error = Color(hex: KoncluiPalette.error)

    /// Lines between and around surfaces; stronger with Increase Contrast.
    static func hairline(_ contrast: ColorSchemeContrast) -> Color {
        Color.white.opacity(contrast == .increased ? KoncluiIncreasedContrast.hairlineIncreased : KoncluiIncreasedContrast.hairline)
    }

    /// The edge of a field, a secondary button, a key cap.
    static func controlStroke(_ contrast: ColorSchemeContrast) -> Color {
        Color.white.opacity(contrast == .increased ? KoncluiIncreasedContrast.controlStrokeIncreased : KoncluiIncreasedContrast.controlStroke)
    }

    /// Supporting text: with Increase Contrast it takes the body role.
    static func secondary(_ contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? textBody : textSecondary
    }
}

/// The seven type roles. The smallest size is 11 pt.
enum KoncluiType {
    case display, title, body, bodyStrong, detail, label, metric

    var font: Font {
        switch self {
        case .display:    return .system(size: 30, weight: .bold)
        case .title:      return .system(size: 15, weight: .semibold)
        case .body:       return .system(size: 13.5)
        case .bodyStrong: return .system(size: 13.5, weight: .medium)
        case .detail:     return .system(size: 12)
        case .label:      return .system(size: 11, weight: .bold)
        case .metric:     return .system(size: 30, weight: .bold).monospacedDigit()
        }
    }

    var tracking: CGFloat {
        switch self {
        case .display, .metric: return -0.6
        case .label:            return 1.2
        default:                return 0
        }
    }
}

extension View {
    /// A type role: its font, its tracking, and capitals for the label role.
    func koncluiType(_ role: KoncluiType) -> some View {
        font(role.font).tracking(role.tracking).textCase(role == .label ? .uppercase : nil)
    }

    /// The hub window's controls for this content: the styles FlowHubView injects at its root, and a popover's content
    /// calls it too (a popover is its own window, the environment does not reach it).
    func koncluiTheme() -> some View {
        environment(\.koncluiHub, true)
            .groupBoxStyle(KoncluiGroupBoxStyle())
            .toggleStyle(KoncluiToggleStyle())
    }

    /// A selected segment keeps white text at 5.2:1 (the accent would be 2.3:1). Hub only.
    func koncluiSegmented() -> some View { modifier(KoncluiSegmentedModifier()) }

    /// `header` pinned over this content (a ScrollView somewhere inside): the content scrolls under it and meets it through
    /// a soft edge, not a hard cut. The window's only glass: the bar is translucent over a material (the header draws
    /// itself that way when `koncluiGlassHeader` is set); Reduce Transparency makes it solid. On macOS 26 the system's
    /// scroll edge effect does the softening; before it, a short fade under the bar does.
    func koncluiPinnedHeader<Header: View>(@ViewBuilder _ header: @escaping () -> Header) -> some View {
        modifier(KoncluiPinnedHeaderModifier(header: header))
    }
}

struct KoncluiPinnedHeaderModifier<Header: View>: ViewModifier {
    let header: () -> Header
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .safeAreaBar(edge: .top, spacing: 0) { bar }
                .scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
                .safeAreaInset(edge: .top, spacing: 0) { bar.overlay(alignment: .bottom) { fade } }
        }
    }

    private var bar: some View {
        header().background { if reduceTransparency { KoncluiTheme.panel } }
    }

    private var fade: some View {
        LinearGradient(colors: [KoncluiTheme.panel, KoncluiTheme.panel.opacity(0)], startPoint: .top, endPoint: .bottom)
            .frame(height: KoncluiSpace.headerFade)
            .offset(y: KoncluiSpace.headerFade)
            .allowsHitTesting(false)
    }
}

// MARK: - Environment

private struct KoncluiHubKey: EnvironmentKey { static let defaultValue = false }
private struct KoncluiNestedKey: EnvironmentKey { static let defaultValue = false }
private struct KoncluiMotionKey: EnvironmentKey { static let defaultValue = KoncluiMotionRate.live }
private struct KoncluiGlassKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// Whether this content is in the hub window (or in a popover that asked for its styles). Outside it, the
    /// `.koncluiPrimary` / `.koncluiSecondary` styles draw upstream's `.borderedProminent` / `.bordered`.
    var koncluiHub: Bool {
        get { self[KoncluiHubKey.self] }
        set { self[KoncluiHubKey.self] = newValue }
    }
    /// A GroupBox inside a card draws flat.
    var koncluiNested: Bool {
        get { self[KoncluiNestedKey.self] }
        set { self[KoncluiNestedKey.self] = newValue }
    }
    /// How often the window's canvases draw (FlowHubView sets it from the window's state and Reduce Motion).
    var koncluiMotion: KoncluiMotionRate {
        get { self[KoncluiMotionKey.self] }
        set { self[KoncluiMotionKey.self] = newValue }
    }
    /// The page header is pinned over scrolling content: its band is translucent over a material.
    var koncluiGlassHeader: Bool {
        get { self[KoncluiGlassKey.self] }
        set { self[KoncluiGlassKey.self] = newValue }
    }
}

// MARK: - Buttons

/// The look of a hub button: the region's one primary (ink on the accent), or neutral. A disabled one drops to the card
/// colour with a secondary text, so it never looks like an enabled primary; the reason belongs beside it (UX.md 1.1).
struct KoncluiButtonLook: View {
    enum Kind { case primary, secondary }

    let configuration: ButtonStyleConfiguration
    var kind: Kind
    var height: CGFloat = 34
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorSchemeContrast) private var contrast

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous) }
    private var destructive: Bool { configuration.role == .destructive }

    var body: some View {
        configuration.label
            .font(.system(size: 13, weight: kind == .primary ? .bold : .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 14)
            .frame(height: height)
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(stroke))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(shape)
            .koncluiPointer(isEnabled)
    }

    private var fill: Color {
        guard isEnabled else { return KoncluiTheme.card }
        return kind == .primary && !destructive ? KoncluiTheme.accent : KoncluiTheme.control
    }

    private var foreground: Color {
        guard isEnabled else { return kind == .primary ? KoncluiTheme.textSecondary : KoncluiTheme.textTertiary }
        if destructive { return KoncluiTheme.error }
        return kind == .primary ? KoncluiTheme.onAccent : KoncluiTheme.textPrimary
    }

    private var stroke: Color {
        if !isEnabled { return KoncluiTheme.hairline(contrast) }
        return kind == .primary && !destructive ? Color.clear : KoncluiTheme.controlStroke(contrast)
    }
}

struct KoncluiHubButtonStyle: ButtonStyle {
    var kind: KoncluiButtonLook.Kind
    var height: CGFloat = 34

    func makeBody(configuration: Configuration) -> some View {
        KoncluiButtonLook(configuration: configuration, kind: kind, height: height)
    }
}

/// `.buttonStyle(.koncluiPrimary)` and `.buttonStyle(.koncluiSecondary)`: what rebrand.py writes in place of upstream's
/// `.borderedProminent` and `.bordered`. In the hub they are the hub's buttons, sized by the control size; anywhere else
/// (the standalone Settings window) they are upstream's own style, untouched.
struct KoncluiButtonStyle: PrimitiveButtonStyle {
    var kind: KoncluiButtonLook.Kind
    @Environment(\.koncluiHub) private var inHub
    @Environment(\.controlSize) private var controlSize

    private var height: CGFloat {
        switch controlSize {
        case .mini:  return 20
        case .small: return 24
        case .large: return 34
        case .extraLarge: return 40
        default:     return 28
        }
    }

    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if inHub {
            Button(configuration).buttonStyle(KoncluiHubButtonStyle(kind: kind, height: height))
        } else if kind == .primary {
            Button(configuration).buttonStyle(.borderedProminent)
        } else {
            Button(configuration).buttonStyle(.bordered)
        }
    }
}

extension PrimitiveButtonStyle where Self == KoncluiButtonStyle {
    static var koncluiPrimary: KoncluiButtonStyle { KoncluiButtonStyle(kind: .primary) }
    static var koncluiSecondary: KoncluiButtonStyle { KoncluiButtonStyle(kind: .secondary) }
}

struct KoncluiSegmentedModifier: ViewModifier {
    @Environment(\.koncluiHub) private var inHub

    @ViewBuilder func body(content: Content) -> some View {
        if inHub { content.tint(KoncluiTheme.selection) } else { content }
    }
}

// MARK: - Cards

/// A GroupBox in the hub: its title above in the label role, the content on a full-width card. Upstream's own `.padding(6)`
/// inside the box makes the card's content sit 18 pt from its edge, like a HubCard. A box inside a card is flat.
struct KoncluiGroupBoxStyle: GroupBoxStyle {
    @Environment(\.koncluiNested) private var nested
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: KoncluiSpace.labelGap) {
            configuration.label
                .koncluiType(.label)
                .foregroundColor(nested ? KoncluiTheme.secondary(contrast) : KoncluiTheme.textTertiary)
            if nested {
                configuration.content
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                configuration.content
                    .environment(\.koncluiNested, true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: KoncluiRadius.card, style: .continuous).fill(KoncluiTheme.card))
                    .overlay(RoundedRectangle(cornerRadius: KoncluiRadius.card, style: .continuous)
                        .strokeBorder(KoncluiTheme.hairline(contrast)))
            }
        }
    }
}

// MARK: - Toggles

/// A labelled toggle is a row: the label on the left, the switch on the right, as in System Settings, so every on/off
/// sits in one column on every page. A toggle whose label is hidden is a selection in a list (Active pills, Shortcuts):
/// it stays a checkbox, drawn with a box you can see when it is off (3:1 against the card).
struct KoncluiToggleStyle: ToggleStyle {
    @Environment(\.labelsVisibility) private var labels

    func makeBody(configuration: Configuration) -> some View {
        if labels == .hidden {
            KoncluiCheckbox(configuration: configuration)
        } else {
            HStack(spacing: 12) {
                configuration.label
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { configuration.isOn.toggle() }
                    .koncluiPointer()
                    .accessibilityHidden(true)
                // The switch carries the label for VoiceOver (hidden on screen: the text is drawn beside it).
                Toggle(isOn: configuration.$isOn) { configuration.label }
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }
}

private struct KoncluiCheckbox: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button { configuration.isOn.toggle() } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .fill(configuration.isOn ? KoncluiTheme.accent : Color.white.opacity(0.04))
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .strokeBorder(configuration.isOn ? Color.clear : Color.white.opacity(KoncluiIncreasedContrast.checkboxStroke), lineWidth: 1.5)
                if configuration.isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9.5, weight: .heavy))
                        .foregroundColor(KoncluiTheme.onAccent)
                }
            }
            .frame(width: 16, height: 16)
            .opacity(isEnabled ? 1 : 0.6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .koncluiPointer(isEnabled)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }.toggleStyle(.checkbox)
        }
    }
}

// MARK: - Status, key caps, fields

/// One way to say how something is: a dot, a sentence, and a chevron when clicking opens its popover. Never the accent.
struct KoncluiStatus: View {
    enum Tone { case ok, attention, off, error }

    let tone: Tone
    let text: String
    /// The status opens something (a popover): it shows a chevron. The caller makes it a button.
    var door = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 6) {
            if tone == .error {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(color)
            } else {
                Circle().fill(color).frame(width: 8, height: 8)
            }
            Text(text)
                .koncluiType(.detail)
                .foregroundColor(tone == .off ? KoncluiTheme.secondary(contrast) : KoncluiTheme.textBody)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if door {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(KoncluiTheme.textTertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch tone {
        case .ok:        return KoncluiTheme.ok
        case .attention: return KoncluiTheme.attention
        case .off:       return KoncluiTheme.textSecondary
        case .error:     return KoncluiTheme.error
        }
    }
}

/// A key drawn like a keycap: one look for Settings and Shortcuts.
struct KoncluiKeyCap: View {
    let text: String
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
            .foregroundColor(KoncluiTheme.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous).fill(Color.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous)
                .strokeBorder(KoncluiTheme.hairline(contrast)))
    }
}

/// A text field of the window: an edge you can see, an accent ring while it has focus, a label above that stays when
/// typing starts, and an optional line below that says what is missing (UX.md 1.1: "Resolve" in the same click).
struct KoncluiField: View {
    var label: String? = nil
    let placeholder: String
    @Binding var text: String
    var hint: String? = nil
    var onSubmit: () -> Void = {}
    @FocusState private var focused: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                Text(label).koncluiType(.label).foregroundColor(KoncluiTheme.textTertiary)
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($focused)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous).fill(KoncluiTheme.field))
                .overlay(RoundedRectangle(cornerRadius: KoncluiRadius.control, style: .continuous)
                    .strokeBorder(focused ? KoncluiTheme.accent : KoncluiTheme.controlStroke(contrast), lineWidth: focused ? 2 : 1))
                .onSubmit(onSubmit)
            if let hint { KoncluiHint(text: hint) }
        }
        // The line under the field says what to do; focus goes back to the field so the person can do it.
        .onChange(of: hint) { _, new in if new != nil { focused = true } }
    }
}

/// "Escreva a palavra primeiro.": what a blocked action needs, where the person is looking.
struct KoncluiHint: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(KoncluiTheme.attention)
            Text(text)
                .koncluiType(.detail)
                .foregroundColor(KoncluiTheme.textBody)
        }
        .accessibilityElement(children: .combine)
    }
}
#endif
