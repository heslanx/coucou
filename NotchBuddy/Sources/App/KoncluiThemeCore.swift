import Foundation

// Koncluí: the numbers of the hub window's visual system, without SwiftUI so `scripts/konclui/test-theme.sh` can check them
// with swiftc alone (contrast pairs, one gutter, which bands stay alive, when the Koru stands still). KoncluiTheme.swift
// turns them into colours, fonts and controls. Rules: docs/konclui/UX.md, "Visual system".

/// Every colour of the hub window as a hex string: the dark family of Koncluí's design system (konclui-platform,
/// `packages/ui/src/styles/globals.css` and the Painel Gestor's sidebar in `apps/web/src/index.css`), so the Mac app and the
/// web read as one product. Navy surfaces, mint as the one accent. The greys that drifted fold into the four text roles.
enum KoncluiPalette {
    // The brand: the Painel Gestor's sidebar gradient (navy, ink, deep teal, at -160°) with the mint glow on top. It is the
    // window behind the sidebar and around the pages' panel (KoncluiBrandBackdrop).
    static let brandNavy = "#0D184F"
    static let brandInk = "#080924"
    static let brandDeep = "#123234"
    // Surfaces
    static let canvas = brandInk        // the window where it is one colour (the gradient's middle)
    static let panel = "#03051A"        // the big card the pages sit in (the platform's dark background)
    static let card = "#0E2236"
    static let field = "#182C41"
    static let control = "#1F3349"      // secondary buttons
    static let sunken = "#020112"       // the pages' top bands, deeper than the panel (the platform's surface-sunken)
    // Text
    static let textPrimary = "#F0F5FB"
    static let textBody = "#B4BDCC"
    static let textSecondary = "#98A3B3"
    static let textTertiary = "#909BAC" // the quietest text that still reads: 4.5:1 on every surface, fields and buttons included
    // Accent: the region's one primary, links, focus
    static let accent = "#53FFC8"       // mint
    static let onAccent = "#070A1D"     // ink on the accent: 15:1 (white on it is 1.1:1)
    static let selection = "#0B7A66"    // only where macOS draws white on the tint (a selected segment): 5.3:1
    // Status: the platform's; never the accent, and always with a word or a symbol (ok is close to mint by design)
    static let ok = "#3DD9B0"
    static let attention = "#E8B04A"
    static let error = "#F07B73"

    /// Text roles on surfaces that must read at 4.5:1 (UX.md 6), and what they are for.
    static let textPairs: [(text: String, surface: String)] = [
        (textPrimary, panel), (textPrimary, card), (textPrimary, field), (textPrimary, control),
        (textBody, panel), (textBody, card), (textBody, field),
        (textSecondary, panel), (textSecondary, card), (textSecondary, field), (textSecondary, control),
        (textTertiary, canvas), (textTertiary, panel), (textTertiary, card), (textTertiary, field), (textTertiary, control),
        (accent, panel), (accent, card), (ok, card), (attention, card), (error, card), (error, field),
        (onAccent, accent), ("#FFFFFF", selection), (textPrimary, sunken), (textBody, sunken), (textSecondary, sunken),
        // The sidebar sits on the gradient: its text reads from the navy top to the teal foot.
        (textPrimary, brandNavy), (textPrimary, brandDeep), (textBody, brandNavy), (textBody, brandDeep),
        (textTertiary, brandNavy), (textTertiary, brandDeep), (accent, brandNavy), (accent, brandDeep),
    ]
}

/// WCAG 2 contrast, so a token that stops passing fails a test instead of a person's eyes.
enum KoncluiContrast {
    static func channels(_ hex: String) -> (r: Double, g: Double, b: Double) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(digits, radix: 16) ?? 0
        return (Double((value >> 16) & 0xFF), Double((value >> 8) & 0xFF), Double(value & 0xFF))
    }

    static func luminance(_ hex: String) -> Double {
        func linear(_ c: Double) -> Double { let s = c / 255; return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4) }
        let c = channels(hex)
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }

    static func ratio(_ a: String, _ b: String) -> Double {
        let (hi, lo) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
        return (hi + 0.05) / (lo + 0.05)
    }

    /// The colour a translucent foreground has once drawn over a surface, as hex.
    static func composite(_ foreground: String, alpha: Double, over surface: String) -> String {
        let f = channels(foreground), s = channels(surface)
        func mix(_ x: Double, _ y: Double) -> Int { Int((alpha * x + (1 - alpha) * y).rounded()) }
        return String(format: "#%02X%02X%02X", mix(f.r, s.r), mix(f.g, s.g), mix(f.b, s.b))
    }
}

/// The measures of the hub window. One gutter for every page edge and column.
enum KoncluiSpace {
    /// The page's left and right edge, and the leading edge of every column under a header card.
    static let gutter: Double = 28
    static let cardPadding: Double = 18
    static let sectionGap: Double = 22
    static let rowGap: Double = 12
    static let labelGap: Double = 8
    /// The Notetaker's list column and what it keeps free on its inner (divider) side.
    static let notesColumn: Double = 280
    static let notesColumnInner: Double = 14
    /// The pinned page header of the settings pages (the compact band) and the fade under it where there is no scroll edge effect.
    static let compactBand: Double = 116
    static let headerFade: Double = 12
}

enum KoncluiRadius {
    static let panel: Double = 20
    static let band: Double = 18
    static let card: Double = 14
    /// Buttons, fields, menus. A chip is a Capsule.
    static let control: Double = 9
}

/// How often a canvas of the window draws: at the display's rate, at 30 frames a second while the window is not the front
/// one, or once. Reduce Motion always means once (docs/konclui/UX.md, 6).
enum KoncluiMotionRate: Equatable {
    case live, eco, still

    /// The `minimumInterval` of a TimelineView(.animation): nil is the display's own rate.
    var minimumInterval: Double? { self == .eco ? 1.0 / 30 : nil }
    var paused: Bool { self == .still }
}

enum KoncluiMotion {
    static func rate(visible: Bool, key: Bool, reduceMotion: Bool) -> KoncluiMotionRate {
        if !visible || reduceMotion { return .still }
        return key ? .live : .eco
    }

    /// Every page's band drifts: particles in the page's colour rising, a glow breathing in its corner, the light under the
    /// pointer. One band is on screen at a time, so it is one canvas; it stands still where the rate does (Reduce Motion, a
    /// hidden window) and draws at 30 Hz while the window is not the front one. The glow cards inside pages stay still.
    static func bandIsLive(rate: KoncluiMotionRate) -> Bool { rate != .still }
}

/// What Increase Contrast changes: the hairlines, the second text role and the strokes of cards.
enum KoncluiIncreasedContrast {
    static let hairline: Double = 0.07
    static let hairlineIncreased: Double = 0.2
    static let controlStroke: Double = 0.16
    static let controlStrokeIncreased: Double = 0.4
    /// The off state of a checkbox: 3:1 against the card (WCAG 1.4.11).
    static let checkboxStroke: Double = 0.36
}
