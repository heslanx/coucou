#if !APPSTORE
import AppKit
import SwiftUI

// Koncluí: what the Flow pages need to know about dictation, in one place. The pages say what to do next from the state
// (off, needs the permission, ready) instead of promising "Segure ⌥" while nothing listens (docs/konclui/UX.md 1.1, 1.3).

extension FlowDictation {
    var koncluiState: KoncluiDictationState {
        #if DEBUG
        if let simulated = KoncluiFlowDebug.dictation { return simulated.state }
        #endif
        return .resolve(enabled: isEnabled, trusted: trusted)
    }

    /// Whether macOS trusts this app for Accessibility right now.
    var koncluiTrusted: Bool {
        #if DEBUG
        if let simulated = KoncluiFlowDebug.dictation { return simulated.state != .needsAccess }
        #endif
        return trusted
    }
}

enum KoncluiDictation {
    @MainActor static func turnOn() {
        #if DEBUG
        if KoncluiFlowDebug.dictation != nil { return }   // a simulated state never changes the real setting
        #endif
        FlowDictation.shared.isEnabled = true
    }
}

/// Whether macOS ever trusted this app for Accessibility, so "remove it from the list and add it again" is offered only to
/// someone it can help (A3-24): the entry exists, and macOS no longer trusts it.
enum KoncluiAccessibilityMemory {
    private static let key = "konclui.flow.accessibilityWasTrusted"

    static var wasTrusted: Bool {
        #if DEBUG
        if let simulated = KoncluiFlowDebug.dictation { return simulated.wasTrusted }
        #endif
        return UserDefaults.standard.bool(forKey: key)
    }

    static func note(trusted: Bool) {
        if trusted && !UserDefaults.standard.bool(forKey: key) { UserDefaults.standard.set(true, forKey: key) }
    }

    @MainActor static func suggestsRemoveAndAdd(for flow: FlowDictation) -> Bool {
        KoncluiAccessibilityAdvice.suggestsRemoveAndAdd(wasTrusted: wasTrusted, trusted: flow.koncluiTrusted)
    }
}

/// The empty states of the Flow pages end here: whatever stops dictation from working is one button away.
struct KoncluiDictationNextStep: View {
    /// The page's own primary action, or a quiet button beside the page's own job (the Dictionary, the Snippets).
    var prominent = false
    /// Centered under an empty state; the band of the Ditado page places it itself.
    var centered = false
    @ObservedObject private var flow = FlowDictation.shared

    var body: some View {
        HStack {
            if centered { Spacer(minLength: 0) }
            switch flow.koncluiState {
            case .off:
                Button(String(localized: "hub.setup-enable")) { KoncluiDictation.turnOn() }
                    .buttonStyle(HubButtonStyle(primary: prominent))
            case .needsAccess:
                Button(String(localized: "flow.accessibility-open")) { flow.openAccessibilitySettings() }
                    .buttonStyle(HubButtonStyle(primary: prominent))
            case .ready:
                EmptyView()
            }
            if centered { Spacer(minLength: 0) }
        }
    }
}

#if DEBUG
/// Launch arguments for the states that are hard to reach (docs: `open Koncluí.app --args …`). They live in the argument
/// domain, so they are never saved, and the sample data is never written to the person's files.
///   -konclui.debug.dictation off | access | access-stale | ready
///   -konclui.debug.flow-data empty | sample
enum KoncluiFlowDebug {
    struct Dictation {
        let state: KoncluiDictationState
        let wasTrusted: Bool
    }

    static var dictation: Dictation? {
        switch UserDefaults.standard.string(forKey: "konclui.debug.dictation") {
        case "off":          return Dictation(state: .off, wasTrusted: false)
        case "access":       return Dictation(state: .needsAccess, wasTrusted: false)
        case "access-stale": return Dictation(state: .needsAccess, wasTrusted: true)
        case "ready":        return Dictation(state: .ready, wasTrusted: true)
        default:             return nil
        }
    }

    static var data: (history: [FlowEntry], stats: FlowStats)? {
        switch UserDefaults.standard.string(forKey: "konclui.debug.flow-data") {
        case "empty":  return ([], FlowStats())
        case "sample": return sample()
        default:       return nil
        }
    }

    /// 40 days with gaps, ending today, and the last dictations of today and yesterday.
    private static func sample() -> (history: [FlowEntry], stats: FlowStats) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var stats = FlowStats()
        for back in [0, 1, 2, 3, 5, 6, 9, 10, 11, 14, 15, 16, 17, 22, 25, 30, 33] {
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { continue }
            let words = 80 + (back * 37) % 220
            stats.days[FlowText.dayKey(day)] = FlowDayStats(words: words, seconds: Double(words) / 110 * 60, dictations: 2 + back % 5)
        }
        stats.apps = ["Slack": 640, "Mail": 410, "Terminal": 260, "Claude": 190]
        let lines = ["Preciso revisar o contrato antes das três da tarde.", "Manda o relatório para o time hoje, por favor.",
                     "Vamos marcar a reunião para quinta de manhã.", "Lembrar de comprar café e pão na volta."]
        let history = lines.enumerated().map { index, text in
            FlowEntry(date: Date().addingTimeInterval(-Double(index) * 5_400), text: text, app: index % 2 == 0 ? "Slack" : "Mail",
                      words: FlowText.wordCount(text), seconds: 6)
        }
        return (history, stats)
    }
}
#endif
#endif
