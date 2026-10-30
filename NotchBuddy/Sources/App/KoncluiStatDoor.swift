#if !APPSTORE
import SwiftUI

// Koncluí: a number is a door (docs/konclui/UX.md 3, "Every number is clickable, zero included"). Clicking a statistic opens a
// sheet with where the number comes from, how it is calculated, and the days behind it, so a person can audit it alone. The
// records are the days kept in `FlowStats` (they outlive the history), so the sheet is right even when the history is off.

struct KoncluiStatDoor<Content: View>: View {
    let kind: KoncluiStatKind
    /// The number as the card shows it ("1.234", "18 min", "indisponível").
    let value: String
    /// What the number counts, as the card says it.
    let label: String
    /// The period's name, and the first day it covers (nil: since the beginning).
    let period: String
    let since: Date?
    var cornerRadius: CGFloat = KoncluiRadius.control
    @ViewBuilder var content: () -> Content

    @ObservedObject private var store = FlowStore.shared
    @State private var open = false
    @State private var hover = false

    var body: some View {
        Button { open.toggle() } label: {
            content()
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Color.white.opacity(hover ? 0.04 : 0)).allowsHitTesting(false))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(KoncluiTheme.textTertiary)
                        .padding(10)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .koncluiPointer()
        .accessibilityHint(Text("konclui.stat.hint"))
        .popover(isPresented: $open, arrowEdge: .bottom) {
            KoncluiStatSheet(kind: kind, value: value, label: label, period: period, records: records)
        }
    }

    private var records: [KoncluiDayRecord] {
        let days = store.stats.days.map { KoncluiDayRecord(key: $0.key, words: $0.value.words, seconds: $0.value.seconds, dictations: $0.value.dictations) }
        return KoncluiStats.records(for: kind, days: days, since: since.map { FlowText.dayKey($0) }, today: Date())
    }
}

struct KoncluiStatSheet: View {
    let kind: KoncluiStatKind
    let value: String
    let label: String
    let period: String
    let records: [KoncluiDayRecord]
    @Environment(\.colorSchemeContrast) private var contrast

    private enum Column { case words, dictations, speaking }

    /// The columns the number is made of, drawn in the primary text colour.
    private var emphasis: Set<Column> {
        switch kind {
        case .words:      return [.words]
        case .dictations: return [.dictations]
        case .speed, .saved: return [.words, .speaking]
        case .streak:     return []
        }
    }

    private var calculation: String {
        switch kind {
        case .words:      return String(localized: "konclui.stat.words-how")
        case .dictations: return String(localized: "konclui.stat.dictations-how")
        case .speed:      return String(localized: "konclui.stat.speed-how")
        case .saved:      return String(localized: "konclui.stat.saved-how")
        case .streak:     return String(localized: "konclui.stat.streak-how")
        }
    }

    private var none: String {
        switch kind {
        case .streak: return String(localized: "konclui.stat.streak-none")
        case .speed:  return String(localized: "konclui.stat.speed-none")
        default:      return String(localized: "konclui.stat.none")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(period).koncluiType(.label).foregroundColor(KoncluiTheme.textTertiary)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(value).koncluiType(.metric)
                    Text(label).koncluiType(.body).foregroundColor(KoncluiTheme.secondary(contrast))
                }
            }
            Text(calculation)
                .koncluiType(.detail)
                .foregroundColor(KoncluiTheme.textBody)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(KoncluiTheme.hairline(contrast)).frame(height: 1)
            if records.isEmpty {
                Text(none)
                    .koncluiType(.detail)
                    .foregroundColor(KoncluiTheme.secondary(contrast))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                table
            }
        }
        .padding(16)
        .frame(width: 380, alignment: .leading)
        .koncluiTheme()
    }

    private var table: some View {
        VStack(alignment: .leading, spacing: 8) {
            line(Text("konclui.stat.col-day"), Text("konclui.stat.col-words"), Text("hub.stat.dictations"), Text("konclui.stat.col-speaking"))
                .foregroundColor(KoncluiTheme.textTertiary)
            ScrollView {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(records, id: \.key) { record in
                        line(Text(Self.day(record.key)).foregroundColor(KoncluiTheme.textBody),
                             cell(FlowText.shortCount(record.words), .words),
                             cell("\(record.dictations)", .dictations),
                             cell(Self.speaking(record.seconds), .speaking))
                    }
                }
            }
            .frame(height: min(CGFloat(records.count) * 24 + 4, 200))
            if kind != .streak && records.count > 1 {
                Rectangle().fill(KoncluiTheme.hairline(contrast)).frame(height: 1)
                line(Text("konclui.stat.total").foregroundColor(KoncluiTheme.textBody),
                     cell(FlowText.shortCount(records.reduce(0) { $0 + $1.words }), .words),
                     cell("\(records.reduce(0) { $0 + $1.dictations })", .dictations),
                     cell(Self.speaking(records.reduce(0) { $0 + $1.seconds }), .speaking))
            }
        }
    }

    /// One row of the table: the day, then three numbers in columns of one width, so the header lines up with the rows.
    private func line(_ first: Text, _ words: Text, _ dictations: Text, _ speaking: Text) -> some View {
        HStack(spacing: 10) {
            first.frame(maxWidth: .infinity, alignment: .leading)
            words.frame(width: Self.numberWidth, alignment: .trailing)
            dictations.frame(width: Self.numberWidth, alignment: .trailing)
            speaking.frame(width: Self.numberWidth, alignment: .trailing)
        }
        .koncluiType(.detail)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func cell(_ text: String, _ column: Column) -> Text {
        let strong = emphasis.contains(column)
        return Text(text)
            .fontWeight(strong ? .semibold : .regular)
            .foregroundColor(strong ? KoncluiTheme.textPrimary : KoncluiTheme.secondary(contrast))
    }

    private static let numberWidth: CGFloat = 64

    private static func day(_ key: String) -> String {
        guard let date = KoncluiStats.date(fromKey: key) else { return key }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private static func speaking(_ seconds: Double) -> String {
        HubInsightsPage.duration(minutes: seconds / 60)
    }
}
#endif
