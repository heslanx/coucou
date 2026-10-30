import Foundation

// scripts/konclui/test-theme.sh: the hub window's tokens pass the contrast the rules ask for, one gutter serves every
// page edge, the Notetaker's column starts on the header card's edge, and the motion rules hold.
@main
struct KoncluiThemeTests {
    static func main() {
        var failures = 0
        func check(_ ok: Bool, _ what: String) {
            if !ok { failures += 1; print("FAIL \(what)") }
        }

        // Text roles read at 4.5:1 on the surfaces they sit on (UX.md 6).
        for (text, surface) in KoncluiPalette.textPairs {
            let ratio = KoncluiContrast.ratio(text, surface)
            check(ratio >= 4.5, "\(text) on \(surface) is \(String(format: "%.2f", ratio)):1, under 4.5:1")
        }
        // The known failures stay failures, so the reason for each token is not forgotten.
        check(KoncluiContrast.ratio("#FFFFFF", KoncluiPalette.accent) < 3, "white on the accent is the 2.3:1 that ink replaces")
        check(KoncluiContrast.ratio("#6B7079", KoncluiPalette.card) < 4.5, "the old muted grey failed on a card")
        // Ink on the accent is the page's primary look: far above 4.5.
        check(KoncluiContrast.ratio(KoncluiPalette.onAccent, KoncluiPalette.accent) >= 8, "ink on the accent is at least 8:1")
        // Hierarchy holds through value, not only size: each role is darker than the one before it.
        let order = [KoncluiPalette.textPrimary, KoncluiPalette.textBody, KoncluiPalette.textSecondary, KoncluiPalette.textTertiary]
        for (a, b) in zip(order, order.dropFirst()) {
            check(KoncluiContrast.luminance(a) > KoncluiContrast.luminance(b), "\(a) is lighter than \(b)")
        }
        // A disabled primary (card fill, secondary text) still reads; the unchecked checkbox box is 3:1 (WCAG 1.4.11).
        check(KoncluiContrast.ratio(KoncluiPalette.textSecondary, KoncluiPalette.card) >= 4.5, "a disabled primary's text reads")
        for surface in [KoncluiPalette.card, KoncluiPalette.field, KoncluiPalette.panel] {
            let stroke = KoncluiContrast.composite("#FFFFFF", alpha: KoncluiIncreasedContrast.checkboxStroke, over: surface)
            check(KoncluiContrast.ratio(stroke, surface) >= 3, "the unchecked checkbox on \(surface) is under 3:1")
        }
        check(KoncluiIncreasedContrast.hairlineIncreased > KoncluiIncreasedContrast.hairline, "Increase Contrast strengthens the hairline")

        // One gutter: the header card, the cards, the Notetaker's column and its detail share the page edge (A2-01).
        check(KoncluiSpace.gutter == 28, "the gutter is 28")
        let heroLeading = KoncluiSpace.gutter
        let notesListLeading = KoncluiSpace.gutter
        let notesDetailLeading = KoncluiSpace.gutter
        check(notesListLeading == heroLeading, "the Notetaker's button starts on the header card's left edge")
        check(notesDetailLeading == heroLeading, "the Notetaker's detail pane starts on the gutter")
        // The record button keeps room for the longest word of the 14 languages in a 280 pt column.
        let buttonWidth = KoncluiSpace.notesColumn - KoncluiSpace.gutter - KoncluiSpace.notesColumnInner
        check(buttonWidth >= 230, "the Notetaker's button is \(buttonWidth) pt wide")

        // Radii nest: a control inside a card inside the panel gets smaller (inner is about outer minus padding).
        check(KoncluiRadius.panel > KoncluiRadius.band && KoncluiRadius.band > KoncluiRadius.card && KoncluiRadius.card > KoncluiRadius.control,
              "radii shrink from the panel to the control")

        // Motion: Reduce Motion or a hidden window draws once; a window that is not the front one draws at 30 Hz.
        check(KoncluiMotion.rate(visible: true, key: true, reduceMotion: false) == .live, "visible, front, motion on: live")
        check(KoncluiMotion.rate(visible: true, key: false, reduceMotion: false) == .eco, "visible, behind: 30 Hz")
        check(KoncluiMotion.rate(visible: true, key: true, reduceMotion: true) == .still, "Reduce Motion: still")
        check(KoncluiMotion.rate(visible: false, key: true, reduceMotion: false) == .still, "hidden: still")
        check(KoncluiMotionRate.live.minimumInterval == nil && KoncluiMotionRate.eco.minimumInterval == 1.0 / 30, "intervals")
        check(KoncluiMotionRate.still.paused && !KoncluiMotionRate.live.paused && !KoncluiMotionRate.eco.paused, "only still pauses")
        // Only the Ditado band has particles, and never under Reduce Motion.
        check(KoncluiMotion.bandIsLive(page: "dictation", rate: .live), "the Ditado band is live")
        check(!KoncluiMotion.bandIsLive(page: "dictation", rate: .still), "Reduce Motion stills even the Ditado band")
        for page in ["notes", "insights", "dictionary", "snippets", "styles", "settings", "general", "pills", "agents", "chat", "integrations", "voice", "shortcuts"] {
            check(!KoncluiMotion.bandIsLive(page: page, rate: .live), "\(page) band is a still wash")
        }

        if failures == 0 { print("KoncluiThemeTests: all passed") }
        exit(failures == 0 ? 0 : 1)
    }
}
