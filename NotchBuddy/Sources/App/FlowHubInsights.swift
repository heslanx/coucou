#if !APPSTORE
import SwiftUI

/// Coucou Flow → Statistics: what you dictated, how fast, and where.
struct HubInsightsPage: View {
    @ObservedObject private var store = FlowStore.shared
    @ObservedObject private var flow = FlowDictation.shared   // Koncluí: the empty chart leads to turning dictation on
    @State private var period: Period = .month

    enum Period: String, CaseIterable, Identifiable {
        case week, month, all
        var id: String { rawValue }
        var label: String {
            switch self {
            case .week:  return String(localized: "hub.period.week")
            case .month: return String(localized: "hub.period.month")
            case .all:   return String(localized: "hub.period.all")
            }
        }
        /// Days shown in the chart.
        var chartDays: Int { self == .week ? 7 : 30 }
        var start: Date? {
            let today = Calendar.current.startOfDay(for: Date())
            switch self {
            case .week:  return Calendar.current.date(byAdding: .day, value: -6, to: today)
            case .month: return Calendar.current.date(byAdding: .day, value: -29, to: today)
            case .all:   return nil
            }
        }
    }

    var body: some View {
        let totals = store.totals(since: period.start)
        HubPageScaffold(title: String(localized: "hub.page.insights"),
                        subtitle: String(localized: "hub.insights-sub")) {
            Picker("", selection: $period) {
                ForEach(Period.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .koncluiSegmented()   // Koncluí
            .labelsHidden()
            .fixedSize()
        } content: {
            // Koncluí: every number is a door to the days behind it (KoncluiStatDoor), and speed reads "unavailable" until
            // there is a dictation to measure (UX.md 2.1, 3).
            HStack(spacing: 14) {
                HubStatCard(kind: .words, label: String(localized: "hub.stat.words"),
                            value: FlowText.shortCount(totals.words), note: nil, period: period)
                HubStatCard(kind: .saved, label: String(localized: "hub.stat.saved"),
                            value: Self.duration(minutes: FlowText.minutesSaved(words: totals.words, seconds: totals.seconds)),
                            note: String(localized: "hub.stat.saved-note"), period: period)
                HubStatCard(kind: .speed, label: String(localized: "hub.stat.speed"),
                            value: KoncluiStats.speed(words: totals.words, seconds: totals.seconds).map { "\($0)" },
                            note: String(localized: "hub.wpm"), period: period)
                HubStatCard(kind: .dictations, label: String(localized: "hub.stat.dictations"),
                            value: "\(totals.dictations)", note: nil, period: period)
            }
            HStack(alignment: .top, spacing: 14) {
                HubCard(padding: 20) {
                    Text("hub.stat.per-day").font(.system(size: 14, weight: .bold))
                    let days = store.dailyWords(last: period.chartDays)
                    if days.allSatisfy({ $0.words == 0 }) {
                        chartEmpty
                    } else {
                        HubBars(days: days)
                            .frame(height: 200)
                    }
                }
                .frame(maxWidth: .infinity)
                HubCard(padding: 20) {
                    Text("hub.stat.apps").font(.system(size: 14, weight: .bold))
                    HubAppBars(apps: store.stats.apps)
                }
                .frame(width: 300)
            }
            Text("hub.insights-privacy")
                .font(.system(size: 12))
                .foregroundColor(HubTheme.muted)
        }
        .koncluiUndoBar()
    }

    /// Koncluí: an empty chart says why and leads to the next step: turn dictation on, give it the permission, or dictate (A1-24).
    private var chartEmpty: some View {
        VStack(spacing: 4) {
            HubEmptyState(text: String(localized: "konclui.stat.none"))
            if flow.koncluiState == .ready {
                Text(String(format: String(localized: "konclui.stat.next-on %@"), flow.key.label))
                    .koncluiType(.detail)
                    .foregroundColor(HubTheme.secondary)
                    .multilineTextAlignment(.center)
            } else {
                KoncluiDictationNextStep(prominent: true)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
    }

    /// "3 h 52" or "18 min".
    static func duration(minutes: Double) -> String {
        let total = Int(minutes.rounded())
        if total < 60 { return String(format: String(localized: "hub.minutes %lld"), total) }
        return String(format: String(localized: "hub.hours %lld %lld"), total / 60, total % 60)
    }
}

private struct HubStatCard: View {
    let kind: KoncluiStatKind
    let label: String
    /// nil reads "unavailable".
    let value: String?
    let note: String?
    let period: HubInsightsPage.Period

    var body: some View {
        let shown = value ?? String(localized: "konclui.stat.unavailable")
        KoncluiStatDoor(kind: kind, value: shown, label: label, period: period.label, since: period.start, cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(HubTheme.secondary)
                    .padding(.trailing, 14)
                Text(shown)
                    .font(value == nil ? .system(size: 15, weight: .semibold) : .system(size: 28, weight: .bold))
                    .foregroundColor(value == nil ? KoncluiTheme.textSecondary : HubTheme.text)
                    .tracking(value == nil ? 0 : -0.6)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(minHeight: 34, alignment: .leading)
                // Two lines kept for the note, so a longer language never cuts it mid-word and the four cards stay level.
                Text(note ?? " ")
                    .font(.system(size: 12))
                    .foregroundColor(HubTheme.secondary)
                    .lineLimit(2, reservesSpace: true)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(HubTheme.card))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(HubTheme.line))
        }
    }
}

/// Words per day, today in full orange.
private struct HubBars: View {
    let days: [(date: Date, words: Int)]

    var body: some View {
        let top = max(1, days.map(\.words).max() ?? 1)
        let labelEvery = days.count > 10 ? 5 : 1
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: days.count > 10 ? 4 : 10) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    let isToday = index == days.count - 1
                    VStack(spacing: 7) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isToday ? HubTheme.accent : HubTheme.accent.opacity(0.35))
                            .frame(height: max(day.words > 0 ? 4 : 2, (geo.size.height - 24) * CGFloat(day.words) / CGFloat(top)))
                            .help("\(day.words)")
                        Text(index % labelEvery == 0 || isToday ? Self.label(day.date, short: days.count > 10) : " ")
                            .font(.system(size: 10.5, weight: isToday ? .bold : .regular))
                            .foregroundColor(isToday ? HubTheme.text : HubTheme.muted)
                            .lineLimit(1)
                            .fixedSize()
                            .frame(height: 14)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    static func label(_ date: Date, short: Bool) -> String {
        short ? date.formatted(.dateTime.day()) : date.formatted(.dateTime.weekday(.narrow))
    }
}

/// The apps where you dictate the most.
private struct HubAppBars: View {
    let apps: [String: Int]

    var body: some View {
        let total = max(1, apps.values.reduce(0, +))
        let top = apps.sorted { $0.value > $1.value }.prefix(6)
        if top.isEmpty {
            Text("hub.stat.apps-empty")
                .font(.system(size: 13))
                .foregroundColor(HubTheme.secondary)
        }
        ForEach(Array(top), id: \.key) { app in
            let share = Double(app.value) / Double(total)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(app.key).font(.system(size: 13)).lineLimit(1)
                    Spacer()
                    Text(share.formatted(.percent.precision(.fractionLength(0))))
                        .font(.system(size: 13))
                        .foregroundColor(HubTheme.secondary)
                        .monospacedDigit()
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.06))
                        Capsule().fill(HubTheme.accent).frame(width: max(4, geo.size.width * share))
                    }
                }
                .frame(height: 6)
            }
        }
    }
}
#endif
